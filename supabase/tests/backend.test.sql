-- Pruebas del backend (RLS, funciones de grupo, triggers y borrado de cuenta).
-- Se ejecutan contra un Supabase LOCAL en CI (workflow backend-tests) y se revierten al final:
--   psql "$DB_URL" -v ON_ERROR_STOP=1 -f supabase/tests/backend.test.sql
-- Cualquier comprobación fallida lanza una excepción y el job falla.
begin;

create function pg_temp.expect(label text, actual bigint, expected bigint) returns void
language plpgsql as $$
begin
  if actual is distinct from expected then
    raise exception 'FALLO [%]: esperado %, obtenido %', label, expected, actual;
  end if;
  raise notice 'ok  [%] = %', label, actual;
end $$;

create function pg_temp.act_as(uid uuid) returns void
language plpgsql as $$
begin
  execute 'reset role';
  perform set_config('request.jwt.claims', json_build_object('sub', uid, 'role', 'authenticated')::text, true);
  perform set_config('request.jwt.claim.sub', uid::text, true);
  execute 'set local role authenticated';
end $$;

do $$
declare
  u1 uuid := gen_random_uuid(); u2 uuid := gen_random_uuid(); u3 uuid := gen_random_uuid();
  g family_groups; l uuid; i uuid; it list_items; n bigint; code text; failed boolean;
begin
  insert into auth.users (id, email, raw_user_meta_data) values
    (u1, 'u1@test.local', '{"name":"Uno"}'), (u2, 'u2@test.local', '{"name":"Dos"}'), (u3, 'u3@test.local', '{}');
  perform pg_temp.expect('trigger crea perfiles', (select count(*) from profiles where id in (u1,u2,u3)), 3);

  -- grupos
  perform pg_temp.act_as(u1);
  g := create_family_group('Fam');
  code := g.invite_code;
  perform pg_temp.expect('código de 6 caracteres', length(code), 6);
  perform pg_temp.expect('u1 asignado al grupo', (select count(*) from profiles where id = u1 and family_group_id = g.id), 1);
  failed := false; begin perform create_family_group('Otra'); exception when others then failed := true; end;
  perform pg_temp.expect('no se puede crear un 2º grupo', failed::int, 1);

  -- listas
  insert into shopping_lists (name, family_group_id, created_by_id) values ('Mercado', g.id, u1) returning id into l;
  failed := false; begin insert into shopping_lists (name, family_group_id, created_by_id) values ('X', g.id, u2); exception when others then failed := true; end;
  perform pg_temp.expect('no se puede falsear created_by', failed::int, 1);

  -- u2 se une y trabaja
  perform pg_temp.act_as(u2);
  failed := false; begin perform join_family_group('ZZZZZZ'); exception when others then failed := true; end;
  perform pg_temp.expect('código falso rechazado', failed::int, 1);
  perform join_family_group(lower(code));
  perform pg_temp.expect('u2 ve las listas del grupo', (select count(*) from shopping_lists), 1);
  perform pg_temp.expect('u2 ve los perfiles del grupo', (select count(*) from profiles), 2);
  insert into list_items (shopping_list_id, name, quantity, category) values (l, 'Leche', '2 L', 'LACTEOS_HUEVOS') returning id into i;
  select * into it from list_items where id = i;
  perform pg_temp.expect('added_by = u2', (it.added_by_id = u2)::int, 1);
  update list_items set is_purchased = true where id = i;
  select * into it from list_items where id = i;
  perform pg_temp.expect('purchased_by y purchased_at', (it.purchased_by_id = u2 and it.purchased_at is not null)::int, 1);
  update list_items set is_purchased = false where id = i;
  select * into it from list_items where id = i;
  perform pg_temp.expect('desmarcar limpia comprador', (it.purchased_by_id is null and it.purchased_at is null)::int, 1);

  -- aislamiento: u3 no tiene grupo
  perform pg_temp.act_as(u3);
  perform pg_temp.expect('u3 no ve listas', (select count(*) from shopping_lists), 0);
  perform pg_temp.expect('u3 no ve artículos', (select count(*) from list_items), 0);
  perform pg_temp.expect('u3 solo ve su perfil', (select count(*) from profiles), 1);
  perform pg_temp.expect('u3 no ve grupos', (select count(*) from family_groups), 0);
  failed := false; begin insert into shopping_lists (name, family_group_id, created_by_id) values ('Hack', g.id, u3); exception when others then failed := true; end;
  perform pg_temp.expect('u3 no crea listas en un grupo ajeno', failed::int, 1);
  failed := false; begin update profiles set family_group_id = g.id where id = u3; exception when others then failed := true; end;
  perform pg_temp.expect('u3 no se asigna grupo directamente', failed::int, 1);
  update profiles set name = 'Hack' where id = u1;
  get diagnostics n = row_count;
  perform pg_temp.expect('u3 no cambia el nombre de otro', n, 0);
  delete from shopping_lists where id = l;
  get diagnostics n = row_count;
  perform pg_temp.expect('u3 no borra listas ajenas', n, 0);

  -- artículos con nota, urgente y responsable; listas con icono, tienda y fijada
  perform pg_temp.act_as(u1);
  update list_items set note = 'Sin lactosa', is_urgent = true, assigned_to_id = u2 where id = i;
  select * into it from list_items where id = i;
  perform pg_temp.expect('nota, urgente y responsable', (it.note = 'Sin lactosa' and it.is_urgent and it.assigned_to_id = u2)::int, 1);
  failed := false; begin update list_items set assigned_to_id = u3 where id = i; exception when others then failed := true; end;
  perform pg_temp.expect('no se asigna a alguien de fuera del grupo', failed::int, 1);
  failed := false; begin update list_items set note = repeat('x', 281) where id = i; exception when others then failed := true; end;
  perform pg_temp.expect('la nota tiene límite', failed::int, 1);
  update shopping_lists set icon = 'PARTY', store = 'Mercadona', is_pinned = true where id = l;
  perform pg_temp.expect('icono, tienda y fijada', (select count(*) from shopping_lists where id = l and icon = 'PARTY' and store = 'Mercadona' and is_pinned), 1);
  failed := false; begin update shopping_lists set icon = 'NADA'::list_icon where id = l; exception when others then failed := true; end;
  perform pg_temp.expect('icono desconocido rechazado', failed::int, 1);

  -- roles: u1 crea el grupo (propietario) y u2 se unió (editor)
  perform pg_temp.expect('el creador es propietario', (select count(*) from profiles where id = u1 and role = 'OWNER'), 1);
  perform pg_temp.expect('quien se une es editor', (select count(*) from profiles where id = u2 and role = 'EDITOR'), 1);
  perform set_member_role(u2, 'VIEWER');
  perform pg_temp.expect('el propietario cambia roles', (select count(*) from profiles where id = u2 and role = 'VIEWER'), 1);
  failed := false; begin perform set_member_role(u1, 'EDITOR'); exception when others then failed := true; end;
  perform pg_temp.expect('el propietario no se puede cambiar', failed::int, 1);
  failed := false; begin perform set_member_role(u2, 'OWNER'); exception when others then failed := true; end;
  perform pg_temp.expect('nadie más puede ser propietario', failed::int, 1);
  failed := false; begin update profiles set role = 'OWNER' where id = u2; exception when others then failed := true; end;
  perform pg_temp.expect('el rol no se cambia a mano', failed::int, 1);

  -- lector: ve, pero no escribe
  perform pg_temp.act_as(u2);
  perform pg_temp.expect('el lector ve las listas', (select count(*) from shopping_lists), 1);
  perform pg_temp.expect('el lector ve los artículos', (select count(*) from list_items), 1);
  failed := false; begin insert into list_items (shopping_list_id, name) values (l, 'Nada'); exception when others then failed := true; end;
  perform pg_temp.expect('el lector no añade artículos', failed::int, 1);
  failed := false; begin update list_items set is_purchased = true where id = i; exception when others then failed := true; end;
  perform pg_temp.expect('el lector no marca artículos', failed::int, 1);
  failed := false; begin insert into shopping_lists (name, family_group_id, created_by_id) values ('X', g.id, u2); exception when others then failed := true; end;
  perform pg_temp.expect('el lector no crea listas', failed::int, 1);
  failed := false; begin update shopping_lists set name = 'Hack' where id = l; exception when others then failed := true; end;
  perform pg_temp.expect('el lector no edita listas', failed::int, 1);
  delete from list_items where id = i;
  get diagnostics n = row_count;
  perform pg_temp.expect('el lector no borra artículos', n, 0);
  failed := false; begin perform set_member_role(u2, 'EDITOR'); exception when others then failed := true; end;
  perform pg_temp.expect('el lector no cambia roles', failed::int, 1);

  -- administrador: gestiona editores y lectores, pero no administradores ni al propietario
  perform pg_temp.act_as(u3);
  perform join_family_group(code);
  perform pg_temp.act_as(u1);
  perform set_member_role(u2, 'ADMIN');
  perform pg_temp.act_as(u2);
  perform set_member_role(u3, 'VIEWER');
  perform pg_temp.expect('el administrador cambia a un editor', (select count(*) from profiles where id = u3 and role = 'VIEWER'), 1);
  failed := false; begin perform set_member_role(u1, 'EDITOR'); exception when others then failed := true; end;
  perform pg_temp.expect('el administrador no toca al propietario', failed::int, 1);
  failed := false; begin perform set_member_role(u3, 'ADMIN'); exception when others then failed := true; end;
  perform pg_temp.expect('el administrador no crea administradores', failed::int, 1);

  -- si se va el propietario, hereda el administrador; quien se va vuelve a ser editor
  perform pg_temp.act_as(u1);
  perform leave_family_group();
  execute 'reset role';
  perform pg_temp.expect('hereda el administrador', (select count(*) from profiles where id = u2 and role = 'OWNER'), 1);
  perform pg_temp.expect('quien se va vuelve a ser editor', (select count(*) from profiles where id = u1 and role = 'EDITOR' and family_group_id is null), 1);
  perform pg_temp.act_as(u3);
  perform leave_family_group();

  -- borrado de cuenta: u1 se va y u2 conserva grupo y lista
  perform pg_temp.act_as(u1);
  perform delete_my_account();
  execute 'reset role';
  perform pg_temp.expect('usuario u1 borrado', (select count(*) from auth.users where id = u1), 0);
  perform pg_temp.expect('perfil de u1 borrado', (select count(*) from profiles where id = u1), 0);
  perform pg_temp.expect('el grupo sigue existiendo', (select count(*) from family_groups where id = g.id), 1);
  perform pg_temp.expect('la lista conserva datos con autor nulo', (select count(*) from shopping_lists where id = l and created_by_id is null), 1);
  perform pg_temp.expect('u2 sigue en el grupo', (select count(*) from profiles where id = u2 and family_group_id = g.id), 1);

  -- el último miembro borra su cuenta: desaparece el grupo en cascada
  perform pg_temp.act_as(u2);
  perform delete_my_account();
  execute 'reset role';
  perform pg_temp.expect('grupo borrado con el último miembro', (select count(*) from family_groups where id = g.id), 0);
  perform pg_temp.expect('listas borradas en cascada', (select count(*) from shopping_lists where id = l), 0);
  perform pg_temp.expect('artículos borrados en cascada', (select count(*) from list_items where id = i), 0);
  perform pg_temp.expect('usuario u2 borrado', (select count(*) from auth.users where id = u2), 0);

  -- sin sesión no se puede borrar una cuenta
  execute 'set local role anon';
  failed := false; begin perform delete_my_account(); exception when others then failed := true; end;
  perform pg_temp.expect('anon no puede borrar cuentas', failed::int, 1);
  execute 'reset role';
end $$;

rollback;
