-- Net worth snapshots: one row per user per day, captured when user views net worth screen
CREATE TABLE net_worth_snapshots (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  net_worth NUMERIC(14,2) NOT NULL,
  assets NUMERIC(14,2) NOT NULL,
  liabilities NUMERIC(14,2) NOT NULL,
  snapshot_date DATE NOT NULL,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  UNIQUE(user_id, snapshot_date)
);

ALTER TABLE net_worth_snapshots ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Users manage own net worth snapshots"
  ON net_worth_snapshots FOR ALL
  USING (auth.uid() = user_id)
  WITH CHECK (auth.uid() = user_id);

CREATE INDEX idx_net_worth_snapshots_user_date ON net_worth_snapshots(user_id, snapshot_date DESC);
