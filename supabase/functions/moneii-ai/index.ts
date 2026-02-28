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
    return json(
      { error: authError?.message || 'Unauthorized user.' },
      401,
    );
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
  const dayStart = new Date(
    Date.UTC(now.getUTCFullYear(), now.getUTCMonth(), now.getUTCDate()),
  );
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
    .gte('created_at', dayStart.toISOString());

  const dailyUsed = dailyCountResult.count ?? 0;
  const dailyLimit =
    planTier === 'premium' ? PREMIUM_DAILY_LIMIT : PREMIUM_PLUS_DAILY_LIMIT;

  if (dailyUsed >= dailyLimit) {
    return json(
      { error: 'Daily Moneii AI limit reached for your plan.' },
      429,
    );
  }

  let requestId: number | null = null;
  const insertResult = await supabase
    .from('ai_assistant_requests')
    .insert({
      user_id: user.id,
      prompt,
      status: 'started',
    })
    .select('id')
    .single();

  requestId = insertResult.data?.id ?? null;

  try {
    const context = await buildUserContext(supabase, user.id, {
      currencyPreference: profile?.currency_preference ?? 'USD',
    });
    const answer = await askModel(prompt, context);

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

async function buildUserContext(
  supabase: ReturnType<typeof createClient>,
  userId: string,
  options: { currencyPreference: string },
) {
  const now = new Date();
  const from90Days = new Date(now);
  from90Days.setUTCDate(now.getUTCDate() - 90);

  const expensesResult = await supabase
    .from('expenses')
    .select(
      'amount, currency, transaction_type, payment_source, category_id, description, expense_date',
    )
    .eq('user_id', userId)
    .gte('expense_date', from90Days.toISOString().slice(0, 10))
    .order('expense_date', { ascending: false })
    .limit(300);

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

  const totals90d = {
    expense: 0,
    income: 0,
    transfer: 0,
    credit_card_payment: 0,
  };
  const categorySpend = new Map<string, number>();
  const recent = [];

  for (const entry of expenses) {
    const amount = Number(entry.amount ?? 0);
    const type = (entry.transaction_type ?? 'expense') as keyof typeof totals90d;
    if (type in totals90d) {
      totals90d[type] += amount;
    }
    if (type === 'expense') {
      const category = categories.get(entry.category_id) ?? 'Other';
      categorySpend.set(category, (categorySpend.get(category) ?? 0) + amount);
    }
    if (recent.length < 20) {
      recent.push({
        date: entry.expense_date,
        type: entry.transaction_type,
        amount,
        currency: entry.currency,
        category: categories.get(entry.category_id) ?? 'Other',
        note: entry.description,
      });
    }
  }

  const topCategories = [...categorySpend.entries()]
    .sort((a, b) => b[1] - a[1])
    .slice(0, 5)
    .map(([name, amount]) => ({ name, amount }));

  return {
    generated_at: new Date().toISOString(),
    currency_preference: options.currencyPreference,
    totals_90d: totals90d,
    top_expense_categories_90d: topCategories,
    recent_transactions: recent,
    account_snapshot: accountsResult.data ?? [],
  };
}

async function askModel(prompt: string, userContext: unknown): Promise<string> {
  const systemPrompt =
    'You are Moneii AI, a personal finance assistant. ' +
    'Use ONLY the provided user data context. ' +
    'If data is missing, say exactly what is missing. ' +
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

function resolvePlanTier(
  planTierRaw: unknown,
  isPremiumRaw: unknown,
): PlanTier {
  if (planTierRaw === 'premium_plus') return 'premium_plus';
  if (planTierRaw === 'premium') return 'premium';
  if (planTierRaw === 'free') return 'free';
  return isPremiumRaw === true ? 'premium' : 'free';
}

async function parseBody(req: Request): Promise<{ prompt?: string } | null> {
  try {
    const body = await req.json();
    if (!body || typeof body !== 'object') return null;
    return body as { prompt?: string };
  } catch (_) {
    return null;
  }
}

function json(data: unknown, status = 200) {
  return new Response(JSON.stringify(data), {
    status,
    headers: { ...corsHeaders, 'Content-Type': 'application/json' },
  });
}

function countWords(text: string): number {
  const words = text.trim().split(/\s+/).filter((word) => word.length > 0);
  return words.length;
}

function enforceMaxWords(text: string, maxWords: number): string {
  const words = text.trim().split(/\s+/).filter((word) => word.length > 0);
  if (words.length <= maxWords) return text.trim();
  return `${words.slice(0, maxWords).join(' ').trim()}.`;
}
