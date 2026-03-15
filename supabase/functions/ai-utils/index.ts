import { createClient } from 'https://esm.sh/@supabase/supabase-js@2.49.8';

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers':
    'authorization, x-client-info, apikey, content-type',
};

const OPENAI_API_KEY = Deno.env.get('OPENAI_API_KEY') ?? '';
const SUPABASE_URL = Deno.env.get('SUPABASE_URL') ?? '';
const SUPABASE_ANON_KEY = Deno.env.get('SUPABASE_ANON_KEY') ?? '';

function json(data: unknown, status = 200) {
  return new Response(JSON.stringify(data), {
    status,
    headers: { ...corsHeaders, 'Content-Type': 'application/json' },
  });
}

Deno.serve(async (req) => {
  if (req.method === 'OPTIONS') return new Response('ok', { headers: corsHeaders });
  if (req.method !== 'POST') return json({ error: 'Method not allowed.' }, 405);

  if (!OPENAI_API_KEY || !SUPABASE_URL || !SUPABASE_ANON_KEY) {
    return json({ error: 'Server not configured.' }, 500);
  }

  const authHeader = req.headers.get('Authorization');
  if (!authHeader) return json({ error: 'Missing authorization header.' }, 401);

  const supabase = createClient(SUPABASE_URL, SUPABASE_ANON_KEY, {
    global: { headers: { Authorization: authHeader } },
  });

  const { data: { user }, error: authError } = await supabase.auth.getUser();
  if (authError || !user) return json({ error: 'Unauthorized.' }, 401);

  let body: Record<string, unknown>;
  try {
    body = await req.json();
  } catch {
    return json({ error: 'Invalid JSON body.' }, 400);
  }

  const action = body.action as string;

  if (action === 'budget-suggestions') {
    return handleBudgetSuggestions(body);
  }
  if (action === 'summarize-expense') {
    return handleSummarizeExpense(body);
  }

  return json({ error: 'Unknown action.' }, 400);
});

// ─── Budget Suggestions ───────────────────────────────────────────────────────

async function handleBudgetSuggestions(body: Record<string, unknown>) {
  const categoryAverages = body.categoryAverages as Array<Record<string, number>>;
  const monthlyIncomeAverage = body.monthlyIncomeAverage as number;
  const currency = body.currency as string;

  if (!categoryAverages || !monthlyIncomeAverage || !currency) {
    return json({ error: 'Missing required fields.' }, 400);
  }

  const categoryLines = categoryAverages
    .map((cat) => {
      const name = Object.keys(cat)[0];
      const avg = cat[name];
      return `- ${name}: ${avg.toFixed(2)} ${currency}/month (3-month avg)`;
    })
    .join('\n');

  const prompt = `You are a personal finance advisor. Based on the user's 3-month spending averages and income, suggest smart monthly budgets for each category.

Monthly Income Average: ${monthlyIncomeAverage.toFixed(2)} ${currency}

3-Month Category Averages:
${categoryLines}

Return a JSON array of budget suggestions. Each item must have these exact fields:
- category_name (string): same as provided
- suggested_amount (number): the recommended monthly budget in ${currency}
- reason (string): short, friendly Gen Z tone explanation (max 60 chars)
- difficulty (string): one of "easy", "medium", or "challenging"

Only return the JSON array, no other text.
Example:
[{"category_name":"Food","suggested_amount":400,"reason":"You typically spend 420 — small trim possible","difficulty":"easy"}]`;

  const response = await fetch('https://api.openai.com/v1/chat/completions', {
    method: 'POST',
    headers: {
      'Authorization': `Bearer ${OPENAI_API_KEY}`,
      'Content-Type': 'application/json',
    },
    body: JSON.stringify({
      model: 'gpt-4o-mini',
      messages: [{ role: 'user', content: prompt }],
      max_tokens: 500,
      temperature: 0.3,
    }),
  });

  if (!response.ok) {
    if (response.status === 429) {
      return json({ error: 'AI rate limit reached. Please try again.' }, 429);
    }
    return json({ error: 'AI request failed. Please try again.' }, 500);
  }

  const data = await response.json();
  const content = data?.choices?.[0]?.message?.content as string | undefined;
  if (!content) return json({ error: 'AI returned empty response.' }, 500);

  const clean = content.trim();
  const start = clean.indexOf('[');
  const end = clean.lastIndexOf(']');
  if (start === -1 || end === -1) {
    return json({ error: 'Could not parse AI response.' }, 500);
  }

  const suggestions = JSON.parse(clean.substring(start, end + 1));
  return json({ suggestions });
}

// ─── Summarize Expense ────────────────────────────────────────────────────────

async function handleSummarizeExpense(body: Record<string, unknown>) {
  const transcript = body.transcript as string;
  const fallbackDescription = body.fallbackDescription as string;

  if (!transcript) return json({ error: 'Missing transcript.' }, 400);

  const response = await fetch('https://api.openai.com/v1/chat/completions', {
    method: 'POST',
    headers: {
      'Authorization': `Bearer ${OPENAI_API_KEY}`,
      'Content-Type': 'application/json',
    },
    body: JSON.stringify({
      model: 'gpt-4o-mini',
      temperature: 0.1,
      messages: [
        {
          role: 'system',
          content:
            'You convert expense speech into short meaningful descriptions. ' +
            'Return only a short noun phrase (2-5 words), no emojis, no quotes, no full sentence.',
        },
        {
          role: 'user',
          content: `Transcript: "${transcript}"\nFallback description: "${fallbackDescription}"\nReturn only the cleaned short description.`,
        },
      ],
    }),
  });

  if (!response.ok) {
    return json({ description: fallbackDescription ?? '' });
  }

  const data = await response.json();
  const content = (data?.choices?.[0]?.message?.content as string | undefined)?.trim();
  if (!content) return json({ description: fallbackDescription ?? '' });

  const cleaned = content
    .split('\n')[0]
    .replace(/["`]+/g, '')
    .replace(/\s+/g, ' ')
    .trim()
    .replace(/[.,;:!?]+$/, '')
    .trim()
    .substring(0, 42)
    .trim();

  return json({ description: cleaned || fallbackDescription || '' });
}
