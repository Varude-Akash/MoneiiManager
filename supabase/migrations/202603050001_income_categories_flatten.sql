-- Flatten income categories to top-level categories (no subcategories).

-- Some environments were seeded with explicit IDs; ensure identity sequence
-- is moved past current max before inserts without explicit IDs.
select setval(
  pg_get_serial_sequence('public.categories', 'id'),
  coalesce((select max(id) from public.categories), 1),
  true
);

insert into public.categories (name, icon, color, parent_id)
select category_name, icon_name, color_hex, null
from (
  values
    ('Salary', 'wallet', '#34D399'),
    ('Business', 'wallet', '#22C55E'),
    ('Freelance', 'wallet', '#16A34A'),
    ('Investment', 'wallet', '#10B981'),
    ('Bonus', 'wallet', '#059669'),
    ('Gifts', 'wallet', '#34D399')
) as t(category_name, icon_name, color_hex)
where not exists (
  select 1
  from public.categories c
  where c.parent_id is null
    and lower(c.name) = lower(t.category_name)
);
