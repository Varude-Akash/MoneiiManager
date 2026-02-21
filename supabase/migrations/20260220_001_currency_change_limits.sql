alter table public.profiles
  add column if not exists currency_change_count integer not null default 0,
  add column if not exists currency_change_year integer not null default extract(year from timezone('utc'::text, now()));
