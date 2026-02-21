alter table public.financial_accounts
  add column if not exists credit_limit numeric(14,2) not null default 0,
  add column if not exists initial_utilized_amount numeric(14,2) not null default 0,
  add column if not exists utilized_amount numeric(14,2) not null default 0;

update public.financial_accounts
set
  initial_utilized_amount = coalesce(initial_utilized_amount, 0),
  utilized_amount = coalesce(utilized_amount, 0)
where account_type = 'credit_card';

update public.financial_accounts
set current_balance = credit_limit - utilized_amount
where account_type = 'credit_card';

