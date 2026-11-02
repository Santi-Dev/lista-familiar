-- Lista Familiar: esquema inicial para Supabase (Postgres + Auth + RLS + Realtime).
-- Equivale a nodejs_space/prisma/schema.prisma; las reglas del backend NestJS pasan a RLS y RPC.

create type item_category as enum (
  'FRUTAS_VERDURAS', 'LACTEOS_HUEVOS', 'CARNES_PESCADO', 'PANADERIA',
  'LIMPIEZA', 'BEBIDAS', 'DESPENSA', 'OTROS'
);

-- ---------- Tablas ----------

create table family_groups (
  id            uuid primary key default gen_random_uuid(),
  name          text not null,
  invite_code   text not null unique,
  created_by_id uuid,
  created_at    timestamptz not null default now(),
  updated_at    timestamptz not null default now()
);

create table profiles (
  id              uuid primary key references auth.users(id) on delete cascade,
  name            text not null,
  family_group_id uuid references family_groups(id) on delete set null,
  created_at      timestamptz not null default now(),
  updated_at      timestamptz not null default now()
);
create index on profiles (family_group_id);

alter table family_groups
  add constraint family_groups_created_by_fk
  foreign key (created_by_id) references profiles(id) on delete set null;

create table shopping_lists (
  id              uuid primary key default gen_random_uuid(),
  name            text not null,
  family_group_id uuid not null references family_groups(id) on delete cascade,
  created_by_id   uuid references profiles(id) on delete set null,
  is_archived     boolean not null default false,
  created_at      timestamptz not null default now(),
  updated_at      timestamptz not null default now()
);
create index on shopping_lists (family_group_id, is_archived, updated_at);

create table list_items (
  id                uuid primary key default gen_random_uuid(),
  shopping_list_id  uuid not null references shopping_lists(id) on delete cascade,
  name              text not null,
  quantity          text,
  category          item_category not null default 'OTROS',
  is_purchased      boolean not null default false,
  purchased_by_id   uuid references profiles(id) on delete set null,
  purchased_at      timestamptz,
  added_by_id       uuid references profiles(id) on delete set null,
  created_at        timestamptz not null default now(),
  updated_at        timestamptz not null default now()
);
create index on list_items (shopping_list_id, category, is_purchased, created_at);

-- ---------- Triggers ----------

create function set_updated_at() returns trigger language plpgsql as $$
begin new.updated_at = now(); return new; end $$;

create trigger trg_profiles_upd before update on profiles for each row execute function set_updated_at();
create trigger trg_groups_upd   before update on family_groups for each row execute function set_updated_at();
create trigger trg_lists_upd    before update on shopping_lists for each row execute function set_updated_at();
create trigger trg_items_upd    before update on list_items for each row execute function set_updated_at();

-- Perfil automático al registrarse (nombre en raw_user_meta_data.name).
create function handle_new_user() returns trigger
language plpgsql security definer set search_path = public as $$
begin
  insert into profiles (id, name)
  values (new.id, coalesce(nullif(trim(new.raw_user_meta_data->>'name'), ''), split_part(new.email, '@', 1)));
  return new;
end $$;

create trigger on_auth_user_created after insert on auth.users
  for each row execute function handle_new_user();

-- Quién y cuándo compró un artículo; tocar un artículo actualiza la lista.
create function item_before_write() returns trigger
language plpgsql security definer set search_path = public as $$
begin
  if tg_op = 'INSERT' then
    new.added_by_id := auth.uid();
  end if;
  if new.is_purchased and (tg_op = 'INSERT' or not old.is_purchased) then
    new.purchased_by_id := auth.uid();
    new.purchased_at := now();
  elsif not new.is_purchased then
    new.purchased_by_id := null;
    new.purchased_at := null;
  end if;
  return new;
end $$;

create trigger trg_item_before before insert or update on list_items
  for each row execute function item_before_write();

create function item_touch_list() returns trigger
language plpgsql security definer set search_path = public as $$
begin
  update shopping_lists set updated_at = now()
  where id = coalesce(new.shopping_list_id, old.shopping_list_id);
  return null;
end $$;

create trigger trg_item_touch after insert or update or delete on list_items
  for each row execute function item_touch_list();

-- ---------- Funciones auxiliares ----------

-- Grupo del usuario actual (security definer evita recursión en las políticas RLS).
create function current_group_id() returns uuid
language sql stable security definer set search_path = public as $$
  select family_group_id from profiles where id = auth.uid()
$$;

create function gen_invite_code() returns text
language plpgsql as $$
declare
  chars constant text := 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
  code text;
begin
  loop
    code := '';
    for i in 1..6 loop
      code := code || substr(chars, 1 + floor(random() * length(chars))::int, 1);
    end loop;
    exit when not exists (select 1 from family_groups where invite_code = code);
  end loop;
  return code;
end $$;

-- ---------- RPC: grupos familiares ----------

create function create_family_group(group_name text) returns family_groups
language plpgsql security definer set search_path = public as $$
declare g family_groups;
begin
  if auth.uid() is null then raise exception 'No autenticado'; end if;
  if current_group_id() is not null then raise exception 'Ya perteneces a un grupo'; end if;
  if length(trim(group_name)) = 0 then raise exception 'El nombre es obligatorio'; end if;
  insert into family_groups (name, invite_code, created_by_id)
  values (trim(group_name), gen_invite_code(), auth.uid()) returning * into g;
  update profiles set family_group_id = g.id where id = auth.uid();
  return g;
end $$;

create function join_family_group(code text) returns family_groups
language plpgsql security definer set search_path = public as $$
declare g family_groups;
begin
  if auth.uid() is null then raise exception 'No autenticado'; end if;
  if current_group_id() is not null then raise exception 'Ya perteneces a un grupo'; end if;
  select * into g from family_groups where invite_code = upper(trim(code));
  if not found then raise exception 'Código de invitación no válido'; end if;
  update profiles set family_group_id = g.id where id = auth.uid();
  return g;
end $$;

-- Si el último miembro sale, el grupo se borra (cascada a listas y artículos).
create function leave_family_group() returns void
language plpgsql security definer set search_path = public as $$
declare gid uuid := current_group_id();
begin
  if auth.uid() is null then raise exception 'No autenticado'; end if;
  if gid is null then return; end if;
  update profiles set family_group_id = null where id = auth.uid();
  if not exists (select 1 from profiles where family_group_id = gid) then
    delete from family_groups where id = gid;
  end if;
end $$;

revoke all on function create_family_group(text), join_family_group(text), leave_family_group() from public, anon;
grant execute on function create_family_group(text), join_family_group(text), leave_family_group() to authenticated;
revoke all on function current_group_id(), gen_invite_code() from public, anon;
grant execute on function current_group_id() to authenticated;

-- ---------- RLS ----------

alter table profiles       enable row level security;
alter table family_groups  enable row level security;
alter table shopping_lists enable row level security;
alter table list_items     enable row level security;

-- profiles: ves el tuyo y los de tu grupo; solo puedes cambiar tu nombre.
create policy profiles_select on profiles for select to authenticated
  using (id = auth.uid() or family_group_id = current_group_id());
create policy profiles_update on profiles for update to authenticated
  using (id = auth.uid()) with check (id = auth.uid());
revoke update on profiles from authenticated;
grant update (name) on profiles to authenticated;

-- family_groups: solo lectura de tu grupo; escritura únicamente vía RPC.
create policy groups_select on family_groups for select to authenticated
  using (id = current_group_id());

-- shopping_lists: todo dentro de tu grupo.
create policy lists_select on shopping_lists for select to authenticated
  using (family_group_id = current_group_id());
create policy lists_insert on shopping_lists for insert to authenticated
  with check (family_group_id = current_group_id() and created_by_id = auth.uid());
create policy lists_update on shopping_lists for update to authenticated
  using (family_group_id = current_group_id()) with check (family_group_id = current_group_id());
create policy lists_delete on shopping_lists for delete to authenticated
  using (family_group_id = current_group_id());

-- list_items: todo si la lista es de tu grupo.
create policy items_all on list_items for all to authenticated
  using (exists (select 1 from shopping_lists l
                 where l.id = shopping_list_id and l.family_group_id = current_group_id()))
  with check (exists (select 1 from shopping_lists l
                      where l.id = shopping_list_id and l.family_group_id = current_group_id()));

-- ---------- Realtime ----------

alter publication supabase_realtime add table shopping_lists, list_items;
