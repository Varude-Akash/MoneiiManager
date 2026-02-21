update public.expenses
set payment_source = 'bank_account'
where payment_source = 'upi';

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

alter table public.financial_accounts
  drop constraint if exists financial_accounts_account_type_check;

alter table public.financial_accounts
  add constraint financial_accounts_account_type_check
  check (account_type in ('bank_account', 'credit_card', 'wallet'));

