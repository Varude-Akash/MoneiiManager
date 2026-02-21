alter table public.expenses
  add column if not exists transaction_type text not null default 'expense',
  add column if not exists payment_source text not null default 'cash';

do $$
begin
  if not exists (
    select 1
    from pg_constraint
    where conname = 'expenses_transaction_type_check'
  ) then
    alter table public.expenses
      add constraint expenses_transaction_type_check
      check (
        transaction_type in (
          'expense',
          'income',
          'transfer',
          'credit_card_payment'
        )
      );
  end if;
end
$$;

do $$
begin
  if not exists (
    select 1
    from pg_constraint
    where conname = 'expenses_payment_source_check'
  ) then
    alter table public.expenses
      add constraint expenses_payment_source_check
      check (
        payment_source in (
          'cash',
          'bank_account',
          'upi',
          'credit_card',
          'wallet'
        )
      );
  end if;
end
$$;
