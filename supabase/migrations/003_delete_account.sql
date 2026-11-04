-- Borrado de cuenta iniciado por el usuario (App Store, guideline 5.1.1(v)).
-- Si es el último miembro de su grupo, el grupo y sus listas se borran (leave_family_group);
-- después se elimina el usuario de auth.users y, en cascada, su perfil.
create function delete_my_account() returns void
language plpgsql security definer set search_path = public, auth as $$
begin
  if auth.uid() is null then raise exception 'No autenticado'; end if;
  perform leave_family_group();
  delete from auth.users where id = auth.uid();
end $$;

revoke all on function delete_my_account() from public, anon;
grant execute on function delete_my_account() to authenticated;
