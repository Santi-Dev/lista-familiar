-- Tipos de lista: «Mercado» (la de siempre) y «Viaje», cada uno con sus categorías de artículo.
-- Todo con valor por defecto o valores nuevos de enum, así que las versiones anteriores de la app siguen funcionando.

create type list_kind as enum ('MARKET', 'TRIP');

alter table shopping_lists
  add column kind list_kind not null default 'MARKET';

-- Icono para las listas de viaje.
alter type list_icon add value if not exists 'TRIP';

-- Categorías de las listas de viaje (las de mercado no cambian; OTROS vale para los dos tipos).
alter type item_category add value if not exists 'ROPA';
alter type item_category add value if not exists 'TECNOLOGIA';
alter type item_category add value if not exists 'ASEO';
alter type item_category add value if not exists 'DOCUMENTOS';
alter type item_category add value if not exists 'BOTIQUIN';
alter type item_category add value if not exists 'OCIO';
