alter table public.financial_accounts
  add column if not exists initial_balance numeric(14,2) not null default 0,
  add column if not exists current_balance numeric(14,2) not null default 0;

update public.financial_accounts
set current_balance = coalesce(current_balance, 0)
where current_balance is null;

