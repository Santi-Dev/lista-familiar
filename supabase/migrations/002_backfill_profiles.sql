-- Corrección puntual: las cuentas creadas antes de 001_init.sql no tienen perfil
-- (el trigger on_auth_user_created aún no existía) y quedaron sin confirmar.

insert into profiles (id, name)
select u.id, coalesce(nullif(trim(u.raw_user_meta_data->>'name'), ''), split_part(u.email, '@', 1))
from auth.users u
on conflict (id) do nothing;

update auth.users set email_confirmed_at = now() where email_confirmed_at is null;
