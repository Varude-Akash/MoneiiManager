-- Monthly wrapped: stores generated personality for each user-month
CREATE TABLE monthly_wrapped (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  month INTEGER NOT NULL CHECK (month BETWEEN 1 AND 12),
  year INTEGER NOT NULL,
  personality_key TEXT NOT NULL,
  personality_title TEXT NOT NULL,
  total_expenses NUMERIC(12,2),
  total_income NUMERIC(12,2),
  savings_rate NUMERIC(5,2),
  top_category TEXT,
  top_category_pct NUMERIC(5,2),
  weekend_pct NUMERIC(5,2),
  ai_narrative TEXT,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  UNIQUE(user_id, month, year)
);

ALTER TABLE monthly_wrapped ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Users manage own monthly wrapped"
  ON monthly_wrapped FOR ALL
  USING (auth.uid() = user_id)
  WITH CHECK (auth.uid() = user_id);

CREATE INDEX idx_monthly_wrapped_user ON monthly_wrapped(user_id, year DESC, month DESC);
