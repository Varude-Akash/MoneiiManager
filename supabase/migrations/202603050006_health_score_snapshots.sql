-- Weekly health score snapshots: one row per user per week
CREATE TABLE health_score_snapshots (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  total_score INTEGER NOT NULL CHECK (total_score BETWEEN 0 AND 100),
  savings_score INTEGER NOT NULL,
  budget_score INTEGER NOT NULL,
  credit_score INTEGER NOT NULL,
  consistency_score INTEGER NOT NULL,
  coverage_score INTEGER NOT NULL,
  week_start DATE NOT NULL,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  UNIQUE(user_id, week_start)
);

ALTER TABLE health_score_snapshots ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Users manage own health score snapshots"
  ON health_score_snapshots FOR ALL
  USING (auth.uid() = user_id)
  WITH CHECK (auth.uid() = user_id);

CREATE INDEX idx_health_score_snapshots_user ON health_score_snapshots(user_id, week_start DESC);
