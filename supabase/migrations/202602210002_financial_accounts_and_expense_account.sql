create table if not exists public.financial_accounts (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  name text not null,
  account_type text not null check (account_type in ('bank_account', 'credit_card', 'wallet')),
  is_default boolean not null default false,
  created_at timestamptz not null default timezone('utc'::text, now()),
  updated_at timestamptz not null default timezone('utc'::text, now())
);

create index if not exists financial_accounts_user_type_idx
  on public.financial_accounts(user_id, account_type, is_default desc);

drop trigger if exists set_financial_accounts_updated_at on public.financial_accounts;
create trigger set_financial_accounts_updated_at
before update on public.financial_accounts
for each row execute function public.set_updated_at();

alter table public.financial_accounts enable row level security;

do $$
begin
  if not exists (
    select 1 from pg_policies
    where schemaname = 'public'
      and tablename = 'financial_accounts'
      and policyname = 'financial_accounts_select_own'
  ) then
    create policy "financial_accounts_select_own"
      on public.financial_accounts for select
      using (auth.uid() = user_id);
  end if;
end
$$;

do $$
begin
  if not exists (
    select 1 from pg_policies
    where schemaname = 'public'
      and tablename = 'financial_accounts'
      and policyname = 'financial_accounts_insert_own'
  ) then
    create policy "financial_accounts_insert_own"
      on public.financial_accounts for insert
      with check (auth.uid() = user_id);
  end if;
end
$$;

do $$
begin
  if not exists (
    select 1 from pg_policies
    where schemaname = 'public'
      and tablename = 'financial_accounts'
      and policyname = 'financial_accounts_update_own'
  ) then
    create policy "financial_accounts_update_own"
      on public.financial_accounts for update
      using (auth.uid() = user_id)
      with check (auth.uid() = user_id);
  end if;
end
$$;

do $$
begin
  if not exists (
    select 1 from pg_policies
    where schemaname = 'public'
      and tablename = 'financial_accounts'
      and policyname = 'financial_accounts_delete_own'
  ) then
    create policy "financial_accounts_delete_own"
      on public.financial_accounts for delete
      using (auth.uid() = user_id);
  end if;
end
$$;

alter table public.expenses
  add column if not exists account_id uuid references public.financial_accounts(id) on delete set null;

update public.expenses
set payment_source = 'bank_account'
where payment_source = 'debit_card';

alter table public.expenses
  drop constraint if exists expenses_payment_source_check;

alter table public.expenses
  add constraint expenses_payment_source_check
  check (
    payment_source in (
      'cash',
      'bank_account',
      'credit_card',
      'wallet'
    )
  );
