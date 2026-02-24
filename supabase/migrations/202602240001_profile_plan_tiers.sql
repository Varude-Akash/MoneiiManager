alter table public.profiles
  add column if not exists plan_tier text;

do $$
begin
  if not exists (
    select 1
    from pg_constraint
    where conname = 'profiles_plan_tier_check'
  ) then
    alter table public.profiles
      add constraint profiles_plan_tier_check
      check (plan_tier in ('free', 'premium', 'premium_plus'));
  end if;
end
$$;

update public.profiles
set plan_tier = case
  when is_premium = true then 'premium'
  else 'free'
end
where plan_tier is null;

alter table public.profiles
  alter column plan_tier set default 'free';

alter table public.profiles
  alter column plan_tier set not null;

create or replace function public.sync_profile_plan_flags()
returns trigger
language plpgsql
as $$
begin
  if new.plan_tier is null then
    new.plan_tier := case when coalesce(new.is_premium, false) then 'premium' else 'free' end;
  end if;

  new.is_premium := new.plan_tier <> 'free';
  return new;
end;
$$;

drop trigger if exists sync_profile_plan_flags_trigger on public.profiles;
create trigger sync_profile_plan_flags_trigger
before insert or update on public.profiles
for each row execute function public.sync_profile_plan_flags();
