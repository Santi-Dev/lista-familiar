-- Artículos con nota, urgente y responsable; listas con icono temático, tienda y «fijada».
-- Las columnas nuevas tienen valor por defecto, así que las versiones anteriores de la app siguen funcionando.

create type list_icon as enum ('CART', 'FOOD', 'PHARMACY', 'PARTY', 'CLEANING', 'HOME');

alter table list_items
  add column note           text check (note is null or char_length(note) <= 280),
  add column is_urgent      boolean not null default false,
  add column assigned_to_id uuid references profiles(id) on delete set null;
create index on list_items (assigned_to_id);

alter table shopping_lists
  add column icon      list_icon not null default 'CART',
  add column store     text check (store is null or char_length(store) <= 40),
  add column is_pinned boolean not null default false;

-- Igual que antes (quién añade y quién compra) y, además, la persona asignada tiene que ser del grupo de la lista.
create or replace function item_before_write() returns trigger
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
  if new.assigned_to_id is not null
     and (tg_op = 'INSERT' or new.assigned_to_id is distinct from old.assigned_to_id) then
    if not exists (select 1
                   from profiles p
                   join shopping_lists l on l.id = new.shopping_list_id
                   where p.id = new.assigned_to_id and p.family_group_id = l.family_group_id) then
      raise exception 'La persona asignada no pertenece al grupo.';
    end if;
  end if;
  return new;
end $$;
