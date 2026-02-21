alter table public.expenses
  add column if not exists destination_account_id uuid
    references public.financial_accounts(id) on delete set null;

