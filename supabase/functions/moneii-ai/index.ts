import { createClient } from 'https://esm.sh/@supabase/supabase-js@2.49.8';

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers':
    'authorization, x-client-info, apikey, content-type',
};

const OPENAI_API_KEY = Deno.env.get('OPENAI_API_KEY') ?? '';
const SUPABASE_URL = Deno.env.get('SUPABASE_URL') ?? '';
const SUPABASE_ANON_KEY = Deno.env.get('SUPABASE_ANON_KEY') ?? '';
const SUPABASE_SERVICE_ROLE_KEY = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') ?? '';
const SUPABASE_KEY = SUPABASE_SERVICE_ROLE_KEY || SUPABASE_ANON_KEY;

const PREMIUM_DAILY_LIMIT = 5;
const PREMIUM_PLUS_DAILY_LIMIT = 50;

type PlanTier = 'free' | 'premium' | 'premium_plus';

// ---------------------------------------------------------------------------
// Schema description sent to GPT for SQL generation.
// Tables are pre-filtered CTEs — GPT must only reference these names.
// ---------------------------------------------------------------------------
const SCHEMA_DESCRIPTION = `
You have access to these pre-filtered tables (already scoped to the current user and allowed date range):

1. filtered_expenses
   - amount (numeric)
   - currency (text)
   - transaction_type: 'expense' | 'income' | 'transfer' | 'credit_card_payment'
   - payment_source: 'cash' | 'bank_account' | 'credit_card' | 'wallet'
   - description (text, nullable)
   - expense_date (DATE, YYYY-MM-DD)
   - category_name (text) — top-level category name, always one of the known values below
   - subcategory_name (text, nullable) — specific subcategory chosen by the user, e.g. 'Groceries'

   Known category_name values (EXACT spelling, case-sensitive):
   Expense categories: 'Food & Dining', 'Transport', 'Entertainment', 'Shopping',
     'Bills & Utilities', 'Health & Fitness', 'Education', 'Travel', 'Personal', 'Other'
   Income categories: 'Salary', 'Business', 'Freelance', 'Investment', 'Bonus', 'Gifts'

   Subcategories by parent (for subcategory_name):
   'Food & Dining': 'Groceries', 'Restaurants', 'Coffee & Tea', 'Fast Food', 'Desserts', 'Alcohol & Bars', 'Meal Delivery'
   'Transport': 'Fuel/Gas', 'Public Transit', 'Ride Share', 'Parking', 'Car Maintenance', 'Flights'
   'Entertainment': 'Movies & TV', 'Music & Concerts', 'Gaming', 'Sports', 'Nightlife', 'Streaming Subscriptions'
   'Shopping': 'Clothing & Fashion', 'Electronics', 'Home & Decor', 'Beauty & Personal Care', 'Gifts', 'Online Shopping'
   'Bills & Utilities': 'Rent/Mortgage', 'Electricity', 'Water', 'Internet & WiFi', 'Phone', 'Insurance', 'Subscriptions'
   'Health & Fitness': 'Gym & Fitness', 'Doctor & Hospital', 'Pharmacy/Medicine', 'Mental Health', 'Supplements'
   'Education': 'Books', 'Courses & Online Learning', 'Tuition', 'Stationery', 'Software & Tools'
   'Travel': 'Hotels', 'Flights', 'Activities', 'Travel Food', 'Travel Shopping'
   'Personal': 'Haircut & Grooming', 'Laundry', 'Donations & Charity', 'Pets'

   IMPORTANT filtering rules:
   - "food", "eating", "dining" → WHERE category_name = 'Food & Dining'
   - "groceries" → WHERE subcategory_name = 'Groceries'
   - "income", "salary", "earnings" → WHERE transaction_type = 'income'
   - "expenses", "spending" (generic) → WHERE transaction_type = 'expense'
   - brand/app/store name (e.g. "amazon", "swiggy", "zomato", "netflix") → use description ILIKE '%amazon%'
   - combine filters when appropriate: e.g. "amazon orders" → WHERE category_name = 'Shopping' AND description ILIKE '%amazon%'

   OVERSPEND / BUDGET rules (CRITICAL):
   - "overspend", "over budget", "spent too much" → ALWAYS filter transaction_type = 'expense'. NEVER include income categories.
   - Income categories (Salary, Business, Freelance, Investment, Bonus, Gifts) MUST NEVER appear in any spending, overspend, or budget analysis.
   - "Overspent" means actual expenses > budget amount. To find overspent categories:
     JOIN filtered_budgets ON category_name = (SELECT name FROM all_categories WHERE id = filtered_budgets.category_id)
     and compare SUM(amount) WHERE transaction_type = 'expense' against the budget amount.
   - If no budget data exists, just show top expense categories by spend (still filter transaction_type = 'expense').
   - Always add WHERE transaction_type = 'expense' (or AND transaction_type = 'expense') when the user asks about spending, overspending, or what categories cost the most.

2. filtered_accounts
   - name (text)
   - account_type: 'bank_account' | 'credit_card' | 'wallet'
   - current_balance (numeric)
   - credit_limit (numeric) — only meaningful for credit_card type
   - utilized_amount (numeric) — only meaningful for credit_card type
   - is_default (boolean)

3. filtered_budgets
   - category_id (integer)
   - amount (numeric) — monthly budget amount for the category
   - currency (text)
   - is_active (boolean)
   - Use all_categories to resolve names: JOIN all_categories ON all_categories.id = filtered_budgets.category_id

4. filtered_goals
   - name (text)
   - target_amount (numeric)
   - current_amount (numeric)
   - deadline (date, nullable)
   - is_completed (boolean)
   - currency (text)

5. all_categories
   - id (integer)
   - name (text)
   - Use ONLY to resolve category names for filtered_budgets. Do NOT use for filtering filtered_expenses.

Rules:
- Return ONLY a valid PostgreSQL SELECT query. No explanation. No markdown. No code fences. No semicolon at end.
- Use only the table names listed above. Never reference raw tables like expenses, financial_accounts, budgets, savings_goals, profiles, etc.
- filtered_expenses already has category_name and subcategory_name — do NOT join categories for expenses.
- Do not add any LIMIT clause unless the user explicitly asks for a specific number of results.
- If the question cannot be answered from these tables (e.g. general advice, weather, etc.), return exactly: NOT_SQL
`.trim();

// ---------------------------------------------------------------------------
// Tables that must never appear in GPT-generated SQL
// ---------------------------------------------------------------------------
const BLOCKED_TABLE_PATTERNS = [
  'expenses',
  'financial_accounts',
  'budgets',
  'savings_goals',
  'profiles',
  'auth\\.users',
  'information_schema',
  'pg_catalog',
  'pg_',
];

const DANGEROUS_KEYWORDS = [
  'INSERT', 'UPDATE', 'DELETE', 'DROP', 'CREATE', 'ALTER',
  'TRUNCATE', 'GRANT', 'REVOKE', 'EXECUTE', 'EXEC', 'COPY',
  'VACUUM', 'ANALYZE', 'IMPORT', 'LOAD', 'RESET',
];

// ---------------------------------------------------------------------------
// Main handler
// ---------------------------------------------------------------------------
Deno.serve(async (req) => {
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders });
  }

  if (req.method !== 'POST') {
    return json({ error: 'Method not allowed' }, 405);
  }

  if (!OPENAI_API_KEY || !SUPABASE_URL || !SUPABASE_KEY) {
    return json({ error: 'Server is not configured correctly.' }, 500);
  }

  const authHeader = req.headers.get('Authorization');
  if (!authHeader) {
    return json({ error: 'Missing authorization header.' }, 401);
  }

  const supabase = createClient(SUPABASE_URL, SUPABASE_KEY, {
    global: { headers: { Authorization: authHeader } },
  });

  const {
    data: { user },
    error: authError,
  } = await supabase.auth.getUser();
  if (authError || !user) {
    return json({ error: authError?.message || 'Unauthorized user.' }, 401);
  }

  const body = await parseBody(req);
  const prompt = body?.prompt?.trim();
  if (!prompt) {
    return json({ error: 'Prompt is required.' }, 400);
  }
  if (prompt.length > 500) {
    return json({ error: 'Prompt is too long. Keep it under 500 characters.' }, 400);
  }

  const profileResult = await supabase
    .from('profiles')
    .select('plan_tier, is_premium, currency_preference')
    .eq('id', user.id)
    .single();

  const profile = profileResult.data;
  const planTier = resolvePlanTier(profile?.plan_tier, profile?.is_premium);

  if (planTier === 'free') {
    return json(
      {
        error:
          'Moneii AI is available on Premium plans. Upgrade to ask personalized finance questions.',
      },
      403,
    );
  }

  const now = new Date();
  const { dayStartIso, dayEndIso } = resolveDayRangeUtc(body?.tz_offset_minutes);
  const retentionStart = new Date(
    Date.UTC(now.getUTCFullYear(), now.getUTCMonth() - 2, 1),
  );

  // Keep only recent 3-month chat records per user.
  await supabase
    .from('ai_assistant_requests')
    .delete()
    .eq('user_id', user.id)
    .lt('created_at', retentionStart.toISOString());

  const dailyCountResult = await supabase
    .from('ai_assistant_requests')
    .select('id', { count: 'exact', head: true })
    .eq('user_id', user.id)
    .gte('created_at', dayStartIso)
    .lt('created_at', dayEndIso);

  const dailyUsed = dailyCountResult.count ?? 0;
  const dailyLimit =
    planTier === 'premium' ? PREMIUM_DAILY_LIMIT : PREMIUM_PLUS_DAILY_LIMIT;

  if (dailyUsed >= dailyLimit) {
    return json({ error: 'Daily Moneii AI limit reached for your plan.' }, 429);
  }

  let requestId: number | null = null;
  const insertResult = await supabase
    .from('ai_assistant_requests')
    .insert({ user_id: user.id, prompt, status: 'started' })
    .select('id')
    .single();

  requestId = insertResult.data?.id ?? null;

  try {
    const daysBack = planTier === 'premium_plus' ? 365 : 90;
    const today = now.toISOString().slice(0, 10);
    const dateFrom = new Date(Date.now() - daysBack * 24 * 60 * 60 * 1000)
      .toISOString()
      .slice(0, 10);
    const currencyPreference = profile?.currency_preference ?? 'USD';

    const answer = await answerWithSqlOrFallback(
      supabase,
      user.id,
      prompt,
      today,
      dateFrom,
      daysBack,
      currencyPreference,
      planTier,
    );

    if (requestId != null) {
      await supabase
        .from('ai_assistant_requests')
        .update({ status: 'success', response: answer })
        .eq('id', requestId)
        .eq('user_id', user.id);
    }

    return json({
      answer,
      usage: {
        plan_tier: planTier,
        daily_used: dailyUsed + 1,
        daily_limit: dailyLimit,
        monthly_used: 0,
        monthly_limit: null,
      },
    });
  } catch (error) {
    if (requestId != null) {
      await supabase
        .from('ai_assistant_requests')
        .update({ status: 'failed' })
        .eq('id', requestId)
        .eq('user_id', user.id);
    }
    const message =
      error instanceof Error ? error.message : 'Moneii AI could not answer right now.';
    return json({ error: message }, 500);
  }
});

// ---------------------------------------------------------------------------
// Text-to-SQL pipeline with fallback to context stuffing
// ---------------------------------------------------------------------------
async function answerWithSqlOrFallback(
  supabase: ReturnType<typeof createClient>,
  userId: string,
  prompt: string,
  today: string,
  dateFrom: string,
  daysBack: number,
  currencyPreference: string,
  planTier: PlanTier,
): Promise<string> {
  try {
    // Step 1: Ask GPT to generate a SQL query for this prompt.
    const rawSql = await generateSql(prompt, today, currencyPreference);
    // Strip trailing semicolons GPT sometimes appends.
    const cleanSql = rawSql.trim().replace(/;+$/, '');
    console.log('[moneii-ai] clean SQL:', cleanSql);

    // Step 2: GPT signals the question can't be answered from DB data.
    if (cleanSql === 'NOT_SQL') {
      console.log('[moneii-ai] NOT_SQL — falling back');
      throw new Error('NOT_SQL');
    }

    // Step 3: Validate the SQL for safety before touching the DB.
    const validation = validateSql(cleanSql);
    if (!validation.valid) {
      console.log('[moneii-ai] validation failed:', validation.error);
      throw new Error(`SQL validation: ${validation.error}`);
    }

    // Step 4: Wrap in user-scoped CTEs (enforces user_id + date range).
    const securedSql = buildSecuredQuery(cleanSql, userId, dateFrom);

    // Step 5: Execute against the database.
    const rows = await executeAiQuery(supabase, securedSql);
    console.log('[moneii-ai] query returned', rows.length, 'rows:', JSON.stringify(rows));

    // Step 6: Ask GPT to turn the raw rows into a natural language answer.
    return await generateAnswerFromRows(prompt, rows, today, currencyPreference);
  } catch (err) {
    console.log('[moneii-ai] error, using fallback:', err instanceof Error ? err.message : err);
    // On any failure (bad SQL, DB error, GPT error, NOT_SQL) fall back to
    // the original context-stuffing approach so the user always gets an answer.
    const context = await buildUserContext(supabase, userId, {
      currencyPreference,
      daysBack,
      maxTransactions: planTier === 'premium_plus' ? 1500 : 300,
    });
    return await askModel(prompt, context);
  }
}

// ---------------------------------------------------------------------------
// Step 1: Generate SQL from the user's prompt
// ---------------------------------------------------------------------------
async function generateSql(
  prompt: string,
  today: string,
  currencyPreference: string,
): Promise<string> {
  const response = await fetch('https://api.openai.com/v1/chat/completions', {
    method: 'POST',
    headers: {
      Authorization: `Bearer ${OPENAI_API_KEY}`,
      'Content-Type': 'application/json',
    },
    body: JSON.stringify({
      model: 'gpt-4o-mini',
      temperature: 0,
      max_tokens: 400,
      messages: [
        {
          role: 'system',
          content:
            `You are a PostgreSQL query generator for a personal finance app.\n` +
            `Today is ${today}. User preferred currency: ${currencyPreference}.\n\n` +
            SCHEMA_DESCRIPTION,
        },
        { role: 'user', content: prompt },
      ],
    }),
  });

  if (!response.ok) {
    throw new Error('SQL generation request failed');
  }

  const data = (await response.json()) as {
    choices?: Array<{ message?: { content?: string } }>;
  };

  const raw = data.choices?.[0]?.message?.content?.trim() ?? '';

  // Strip markdown code fences if GPT wraps the query in them.
  return raw
    .replace(/^```sql\s*/i, '')
    .replace(/^```\s*/i, '')
    .replace(/\s*```$/i, '')
    .trim();
}

// ---------------------------------------------------------------------------
// Step 3: Validate the raw SQL for safety
// ---------------------------------------------------------------------------
function validateSql(sql: string): { valid: boolean; error?: string } {
  const trimmed = sql.trim();
  const upper = trimmed.toUpperCase();

  if (!upper.startsWith('SELECT')) {
    return { valid: false, error: 'Query must start with SELECT' };
  }

  // No multiple statements.
  if (trimmed.includes(';')) {
    return { valid: false, error: 'Semicolons are not allowed' };
  }

  // No dangerous DML / DDL keywords.
  for (const keyword of DANGEROUS_KEYWORDS) {
    if (new RegExp(`\\b${keyword}\\b`).test(upper)) {
      return { valid: false, error: `Disallowed keyword: ${keyword}` };
    }
  }

  // GPT must not reference raw protected tables directly.
  for (const pattern of BLOCKED_TABLE_PATTERNS) {
    if (new RegExp(`\\b${pattern}\\b`, 'i').test(trimmed)) {
      return { valid: false, error: `Direct table access not allowed: ${pattern}` };
    }
  }

  return { valid: true };
}

// ---------------------------------------------------------------------------
// Step 4: Wrap GPT's SELECT in user-scoped CTEs
// This is the primary security layer — user_id and date range are enforced
// here in TypeScript, not trusted to GPT.
// ---------------------------------------------------------------------------
function buildSecuredQuery(sql: string, userId: string, dateFrom: string): string {
  // Sanity-check both values (they come from our own code, but be explicit).
  if (!/^[0-9a-f-]{36}$/i.test(userId)) {
    throw new Error('Invalid userId format');
  }
  if (!/^\d{4}-\d{2}-\d{2}$/.test(dateFrom)) {
    throw new Error('Invalid dateFrom format');
  }

  return `
WITH
  filtered_expenses AS (
    SELECT
      e.amount,
      e.currency,
      e.transaction_type,
      e.payment_source,
      e.description,
      e.expense_date,
      COALESCE(cat.name, 'Other') AS category_name,
      sub.name AS subcategory_name
    FROM expenses e
    LEFT JOIN categories cat ON cat.id = e.category_id
    LEFT JOIN categories sub ON sub.id = e.subcategory_id
    WHERE e.user_id = '${userId}'
      AND e.expense_date >= '${dateFrom}'
  ),
  filtered_accounts AS (
    SELECT
      name,
      account_type,
      current_balance,
      credit_limit,
      utilized_amount,
      is_default
    FROM financial_accounts
    WHERE user_id = '${userId}'
  ),
  filtered_budgets AS (
    SELECT
      category_id,
      amount,
      currency,
      is_active
    FROM budgets
    WHERE user_id = '${userId}'
  ),
  filtered_goals AS (
    SELECT
      name,
      target_amount,
      current_amount,
      deadline,
      is_completed,
      currency
    FROM savings_goals
    WHERE user_id = '${userId}'
  ),
  all_categories AS (
    SELECT id, name FROM categories
  )
${sql}`.trim();
}

// ---------------------------------------------------------------------------
// Step 5: Execute the secured query via the run_ai_select DB function
// ---------------------------------------------------------------------------
async function executeAiQuery(
  supabase: ReturnType<typeof createClient>,
  sql: string,
): Promise<Record<string, unknown>[]> {
  const { data, error } = await supabase.rpc('run_ai_select', { query_sql: sql });
  if (error) throw new Error(`Query execution failed: ${error.message}`);
  if (!Array.isArray(data)) return [];
  return data as Record<string, unknown>[];
}

// ---------------------------------------------------------------------------
// Step 7: Turn raw query rows into a natural language answer
// ---------------------------------------------------------------------------
async function generateAnswerFromRows(
  prompt: string,
  rows: Record<string, unknown>[],
  today: string,
  currencyPreference: string,
): Promise<string> {
  const systemPrompt =
    'You are Moneii AI, a personal finance assistant. ' +
    `Today is ${today}. User preferred currency: ${currencyPreference}. ` +
    'Answer the user question using ONLY the provided query results. ' +
    'If results are empty, say no matching data was found — never invent numbers. ' +
    'Answer naturally in plain text. ' +
    'Do not use markdown symbols like **, #, or bullet markdown. ' +
    'Keep answers concise and never exceed 200 words.';

  const resultText =
    rows.length === 0
      ? 'No results found.'
      : `Query returned ${rows.length} row(s):\n${JSON.stringify(rows)}`;

  const response = await fetch('https://api.openai.com/v1/chat/completions', {
    method: 'POST',
    headers: {
      Authorization: `Bearer ${OPENAI_API_KEY}`,
      'Content-Type': 'application/json',
    },
    body: JSON.stringify({
      model: 'gpt-4o-mini',
      temperature: 0.2,
      max_tokens: 350,
      messages: [
        { role: 'system', content: systemPrompt },
        {
          role: 'user',
          content: `User question: ${prompt}\n\nQuery results:\n${resultText}`,
        },
      ],
    }),
  });

  if (!response.ok) {
    throw new Error('Answer generation failed');
  }

  const data = (await response.json()) as {
    choices?: Array<{ message?: { content?: string } }>;
  };
  const content = data.choices?.[0]?.message?.content?.trim();
  if (!content) throw new Error('Empty answer from model');

  return enforceMaxWords(content, 200);
}

// ---------------------------------------------------------------------------
// Fallback: original context-stuffing approach (used when SQL path fails)
// ---------------------------------------------------------------------------
async function buildUserContext(
  supabase: ReturnType<typeof createClient>,
  userId: string,
  options: { currencyPreference: string; daysBack: number; maxTransactions: number },
) {
  const now = new Date();
  const fromDate = new Date(now);
  fromDate.setUTCDate(now.getUTCDate() - options.daysBack);

  const currentMonthStart = new Date(
    Date.UTC(now.getUTCFullYear(), now.getUTCMonth(), 1),
  );
  const currentMonthStartStr = currentMonthStart.toISOString().slice(0, 10);
  const todayStr = now.toISOString().slice(0, 10);

  const expensesResult = await supabase
    .from('expenses')
    .select(
      'amount, currency, transaction_type, payment_source, category_id, description, expense_date',
    )
    .eq('user_id', userId)
    .gte('expense_date', fromDate.toISOString().slice(0, 10))
    .order('expense_date', { ascending: false })
    .limit(options.maxTransactions);

  const categoriesResult = await supabase.from('categories').select('id, name');

  const accountsResult = await supabase
    .from('financial_accounts')
    .select(
      'name, account_type, current_balance, credit_limit, utilized_amount, is_default',
    )
    .eq('user_id', userId)
    .order('account_type', { ascending: true });

  const expenses = (expensesResult.data ?? []) as Array<{
    amount: number;
    currency: string;
    transaction_type: string;
    payment_source: string;
    category_id: number;
    description: string | null;
    expense_date: string;
  }>;

  const categories = new Map<number, string>();
  for (const row of categoriesResult.data ?? []) {
    categories.set(row.id as number, (row.name as string) ?? 'Other');
  }

  type Totals = { expense: number; income: number; transfer: number; credit_card_payment: number };
  const emptyTotals = (): Totals => ({
    expense: 0,
    income: 0,
    transfer: 0,
    credit_card_payment: 0,
  });

  const currentMonthTotals = emptyTotals();
  const currentMonthCategorySpend = new Map<string, number>();
  const currentMonthTransactions: object[] = [];
  const monthlyMap = new Map<string, Totals>();

  for (const entry of expenses) {
    const amount = Number(entry.amount ?? 0);
    const type = (entry.transaction_type ?? 'expense') as keyof Totals;
    const category = categories.get(entry.category_id) ?? 'Other';
    const isCurrentMonth = entry.expense_date >= currentMonthStartStr;

    if (isCurrentMonth) {
      if (type in currentMonthTotals) currentMonthTotals[type] += amount;
      if (type === 'expense') {
        currentMonthCategorySpend.set(
          category,
          (currentMonthCategorySpend.get(category) ?? 0) + amount,
        );
      }
      if (currentMonthTransactions.length < 30) {
        currentMonthTransactions.push({
          date: entry.expense_date,
          type: entry.transaction_type,
          amount,
          currency: entry.currency,
          category,
          note: entry.description,
        });
      }
    } else {
      const monthKey = entry.expense_date.slice(0, 7);
      if (!monthlyMap.has(monthKey)) monthlyMap.set(monthKey, emptyTotals());
      const m = monthlyMap.get(monthKey)!;
      if (type in m) m[type] += amount;
    }
  }

  const currentMonthTopCategories = [...currentMonthCategorySpend.entries()]
    .sort((a, b) => b[1] - a[1])
    .slice(0, 5)
    .map(([name, amount]) => ({ name, amount }));

  const previousMonthsSummary = [...monthlyMap.entries()]
    .sort((a, b) => b[0].localeCompare(a[0]))
    .slice(0, 6)
    .map(([month, totals]) => ({ month, ...totals }));

  const monthNames = [
    'January', 'February', 'March', 'April', 'May', 'June',
    'July', 'August', 'September', 'October', 'November', 'December',
  ];
  const currentMonthLabel = `${monthNames[now.getUTCMonth()]} ${now.getUTCFullYear()}`;

  return {
    today: todayStr,
    current_month: currentMonthLabel,
    currency_preference: options.currencyPreference,
    current_month_totals: currentMonthTotals,
    current_month_top_expense_categories: currentMonthTopCategories,
    current_month_transactions: currentMonthTransactions,
    previous_months_summary: previousMonthsSummary,
    account_snapshot: accountsResult.data ?? [],
  };
}

async function askModel(prompt: string, userContext: unknown): Promise<string> {
  const systemPrompt =
    'You are Moneii AI, a personal finance assistant. ' +
    'Use ONLY the provided user data context. ' +
    'The context includes "today" (current date) and "current_month" so you always know what "this month" or "today" means. ' +
    'current_month_totals and current_month_transactions are for the CURRENT month only. ' +
    'previous_months_summary contains historical monthly totals. ' +
    'When the user asks about "this month", use current_month_totals and current_month_transactions. ' +
    'If current_month_totals shows zero expenses, say there are no expenses recorded yet this month. ' +
    'Never confuse previous months data with current month. ' +
    'If data is missing or zero, say so explicitly. ' +
    'Never claim external or real-time market facts. ' +
    'Answer naturally in plain text based on what the user asked. ' +
    'Do not force any fixed format or headings. ' +
    'Keep answers concise and never exceed 200 words. ' +
    'Do not use markdown symbols like **, #, or bullet markdown.';

  const response = await fetch('https://api.openai.com/v1/chat/completions', {
    method: 'POST',
    headers: {
      Authorization: `Bearer ${OPENAI_API_KEY}`,
      'Content-Type': 'application/json',
    },
    body: JSON.stringify({
      model: 'gpt-4o-mini',
      temperature: 0.2,
      max_tokens: 450,
      messages: [
        { role: 'system', content: systemPrompt },
        {
          role: 'user',
          content:
            `User question:\n${prompt}\n\n` +
            `User data context (JSON):\n${JSON.stringify(userContext)}`,
        },
      ],
    }),
  });

  if (!response.ok) {
    throw new Error('Moneii AI failed to generate a response. Please try again.');
  }

  const data = (await response.json()) as {
    choices?: Array<{ message?: { content?: string } }>;
  };
  const content = data.choices?.[0]?.message?.content?.trim();
  if (!content) {
    throw new Error('Moneii AI returned an empty response. Please retry.');
  }
  const wordCount = countWords(content);
  if (wordCount <= 200) return content;

  const rewriteResponse = await fetch(
    'https://api.openai.com/v1/chat/completions',
    {
      method: 'POST',
      headers: {
        Authorization: `Bearer ${OPENAI_API_KEY}`,
        'Content-Type': 'application/json',
      },
      body: JSON.stringify({
        model: 'gpt-4o-mini',
        temperature: 0.1,
        max_tokens: 300,
        messages: [
          {
            role: 'system',
            content:
              'Rewrite the answer in plain text under 200 words. Keep all important meaning. No markdown.',
          },
          { role: 'user', content },
        ],
      }),
    },
  );

  if (!rewriteResponse.ok) {
    return enforceMaxWords(content, 200);
  }
  const rewriteData = (await rewriteResponse.json()) as {
    choices?: Array<{ message?: { content?: string } }>;
  };
  const rewritten = rewriteData.choices?.[0]?.message?.content?.trim();
  if (!rewritten) return enforceMaxWords(content, 200);
  return enforceMaxWords(rewritten, 200);
}

// ---------------------------------------------------------------------------
// Shared helpers
// ---------------------------------------------------------------------------
function resolvePlanTier(planTierRaw: unknown, isPremiumRaw: unknown): PlanTier {
  if (planTierRaw === 'premium_plus') return 'premium_plus';
  if (planTierRaw === 'premium') return 'premium';
  if (planTierRaw === 'free') return 'free';
  return isPremiumRaw === true ? 'premium' : 'free';
}

async function parseBody(req: Request): Promise<{
  prompt?: string;
  tz_offset_minutes?: number | string;
} | null> {
  try {
    const body = await req.json();
    if (!body || typeof body !== 'object') return null;
    return body as { prompt?: string; tz_offset_minutes?: number | string };
  } catch (_) {
    return null;
  }
}

function resolveDayRangeUtc(tzOffsetRaw: unknown): {
  dayStartIso: string;
  dayEndIso: string;
} {
  const parsed =
    typeof tzOffsetRaw === 'number'
      ? Math.trunc(tzOffsetRaw)
      : typeof tzOffsetRaw === 'string'
      ? Number.parseInt(tzOffsetRaw, 10)
      : 0;
  const offsetMinutes = Number.isFinite(parsed)
    ? Math.max(-840, Math.min(840, parsed))
    : 0;

  const now = new Date();
  const localNowMs = now.getTime() + offsetMinutes * 60_000;
  const localNow = new Date(localNowMs);
  const localDayStartMs = Date.UTC(
    localNow.getUTCFullYear(),
    localNow.getUTCMonth(),
    localNow.getUTCDate(),
  );
  const dayStartUtcMs = localDayStartMs - offsetMinutes * 60_000;
  const dayEndUtcMs = dayStartUtcMs + 24 * 60 * 60 * 1000;

  return {
    dayStartIso: new Date(dayStartUtcMs).toISOString(),
    dayEndIso: new Date(dayEndUtcMs).toISOString(),
  };
}

function json(data: unknown, status = 200) {
  return new Response(JSON.stringify(data), {
    status,
    headers: { ...corsHeaders, 'Content-Type': 'application/json' },
  });
}

function countWords(text: string): number {
  return text.trim().split(/\s+/).filter((w) => w.length > 0).length;
}

function enforceMaxWords(text: string, maxWords: number): string {
  const words = text.trim().split(/\s+/).filter((w) => w.length > 0);
  if (words.length <= maxWords) return text.trim();
  return `${words.slice(0, maxWords).join(' ').trim()}.`;
}
