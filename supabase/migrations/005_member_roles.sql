-- Roles de miembro: propietario, administrador, editor y solo lectura.
--   OWNER   crea el grupo y gestiona a todos los demás.
--   ADMIN   gestiona editores y lectores.
--   EDITOR  añade, edita y marca artículos y listas (el rol de quien se une).
--   VIEWER  solo consulta: las políticas RLS le impiden escribir.
-- El rol vive en `profiles` (cada persona pertenece a un solo grupo) y solo se cambia con `set_member_role`.

create type member_role as enum ('OWNER', 'ADMIN', 'EDITOR', 'VIEWER');

alter table profiles add column role member_role not null default 'EDITOR';

-- Los grupos que ya existen: el creador es el propietario…
update profiles p set role = 'OWNER'
from family_groups g
where g.id = p.family_group_id and g.created_by_id = p.id;

-- …y si el creador ya no está en el grupo, hereda quien lleva más tiempo.
update profiles set role = 'OWNER'
where id in (
  select distinct on (family_group_id) id
  from profiles
  where family_group_id is not null
    and family_group_id not in (select family_group_id from profiles where role = 'OWNER' and family_group_id is not null)
  order by family_group_id, created_at, id);

create function current_member_role() returns member_role
language sql stable security definer set search_path = public as $$
  select role from profiles where id = auth.uid()
$$;
revoke all on function current_member_role() from public, anon;
grant execute on function current_member_role() to authenticated;

-- ---------- Funciones de grupo con roles ----------

create or replace function create_family_group(group_name text) returns family_groups
language plpgsql security definer set search_path = public as $$
declare g family_groups;
begin
  if auth.uid() is null then raise exception 'No autenticado'; end if;
  if current_group_id() is not null then raise exception 'Ya perteneces a un grupo'; end if;
  if length(trim(group_name)) = 0 then raise exception 'El nombre es obligatorio'; end if;
  insert into family_groups (name, invite_code, created_by_id)
  values (trim(group_name), gen_invite_code(), auth.uid()) returning * into g;
  update profiles set family_group_id = g.id, role = 'OWNER' where id = auth.uid();
  return g;
end $$;

create or replace function join_family_group(code text) returns family_groups
language plpgsql security definer set search_path = public as $$
declare g family_groups;
begin
  if auth.uid() is null then raise exception 'No autenticado'; end if;
  if current_group_id() is not null then raise exception 'Ya perteneces a un grupo'; end if;
  select * into g from family_groups where invite_code = upper(trim(code));
  if not found then raise exception 'Código de invitación no válido'; end if;
  update profiles set family_group_id = g.id, role = 'EDITOR' where id = auth.uid();
  return g;
end $$;

-- Si el último miembro sale, el grupo se borra. Si sale el propietario, hereda el grupo un administrador
-- o, si no hay, quien lleva más tiempo.
create or replace function leave_family_group() returns void
language plpgsql security definer set search_path = public as $$
declare gid uuid := current_group_id(); was_owner boolean;
begin
  if auth.uid() is null then raise exception 'No autenticado'; end if;
  if gid is null then return; end if;
  select role = 'OWNER' into was_owner from profiles where id = auth.uid();
  update profiles set family_group_id = null, role = 'EDITOR' where id = auth.uid();
  if not exists (select 1 from profiles where family_group_id = gid) then
    delete from family_groups where id = gid;
  elsif was_owner then
    update profiles set role = 'OWNER'
    where id = (select id from profiles where family_group_id = gid
                order by (role = 'ADMIN') desc, created_at, id limit 1);
  end if;
end $$;

-- Cambia el rol de otro miembro. El propietario no cambia; los administradores solo gestionan editores y lectores.
create function set_member_role(member_id uuid, new_role member_role) returns void
language plpgsql security definer set search_path = public as $$
declare my_role member_role := current_member_role(); target profiles;
begin
  if auth.uid() is null then raise exception 'No autenticado'; end if;
  if my_role is null or my_role not in ('OWNER', 'ADMIN') then
    raise exception 'No tienes permiso para cambiar roles.';
  end if;
  select * into target from profiles where id = member_id and family_group_id = current_group_id();
  if not found then raise exception 'Esa persona no pertenece a tu grupo.'; end if;
  if target.role = 'OWNER' or new_role = 'OWNER' then raise exception 'El propietario no se puede cambiar.'; end if;
  if my_role = 'ADMIN' and (target.role = 'ADMIN' or new_role = 'ADMIN') then
    raise exception 'Solo el propietario gestiona a los administradores.';
  end if;
  update profiles set role = new_role where id = member_id;
end $$;
revoke all on function set_member_role(uuid, member_role) from public, anon;
grant execute on function set_member_role(uuid, member_role) to authenticated;

-- ---------- RLS: los lectores no escriben ----------
-- En UPDATE, `using` solo mira el grupo (el lector ve la fila) y `with check` exige poder editar:
-- así el intento de un lector falla con un error 42501 en lugar de «0 filas».

drop policy lists_insert on shopping_lists;
drop policy lists_update on shopping_lists;
drop policy lists_delete on shopping_lists;

create policy lists_insert on shopping_lists for insert to authenticated
  with check (family_group_id = current_group_id() and created_by_id = auth.uid()
              and current_member_role() <> 'VIEWER');
create policy lists_update on shopping_lists for update to authenticated
  using (family_group_id = current_group_id())
  with check (family_group_id = current_group_id() and current_member_role() <> 'VIEWER');
create policy lists_delete on shopping_lists for delete to authenticated
  using (family_group_id = current_group_id() and current_member_role() <> 'VIEWER');

drop policy items_all on list_items;

create policy items_select on list_items for select to authenticated
  using (exists (select 1 from shopping_lists l
                 where l.id = shopping_list_id and l.family_group_id = current_group_id()));
create policy items_insert on list_items for insert to authenticated
  with check (current_member_role() <> 'VIEWER'
              and exists (select 1 from shopping_lists l
                          where l.id = shopping_list_id and l.family_group_id = current_group_id()));
create policy items_update on list_items for update to authenticated
  using (exists (select 1 from shopping_lists l
                 where l.id = shopping_list_id and l.family_group_id = current_group_id()))
  with check (current_member_role() <> 'VIEWER'
              and exists (select 1 from shopping_lists l
                          where l.id = shopping_list_id and l.family_group_id = current_group_id()));
create policy items_delete on list_items for delete to authenticated
  using (current_member_role() <> 'VIEWER'
         and exists (select 1 from shopping_lists l
                     where l.id = shopping_list_id and l.family_group_id = current_group_id()));
