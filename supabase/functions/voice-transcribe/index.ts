import { createClient } from 'https://esm.sh/@supabase/supabase-js@2.49.8';

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers':
    'authorization, x-client-info, apikey, content-type',
};

const OPENAI_API_KEY = Deno.env.get('OPENAI_API_KEY') ?? '';
const SUPABASE_URL = Deno.env.get('SUPABASE_URL') ?? '';
const SUPABASE_ANON_KEY = Deno.env.get('SUPABASE_ANON_KEY') ?? '';

const FREE_DAILY_LIMIT = 3;
const FREE_TRIAL_DAYS = 30;
const FREE_TRIAL_TOTAL_LIMIT = 90;
const PREMIUM_DAILY_LIMIT = 10;
// Premium+ is product-unlimited for voice, but keep a hard backend safety cap.
const VOICE_DAILY_HARD_SAFETY_LIMIT = 200;
const MAX_AUDIO_BYTES = 5 * 1024 * 1024;
type PlanTier = 'free' | 'premium' | 'premium_plus';

Deno.serve(async (req) => {
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders });
  }

  if (req.method !== 'POST') {
    return json({ error: 'Method not allowed' }, 405);
  }

  if (!OPENAI_API_KEY || !SUPABASE_URL || !SUPABASE_ANON_KEY) {
    return json({ error: 'Server is not configured correctly.' }, 500);
  }

  const authHeader = req.headers.get('Authorization');
  if (!authHeader) {
    return json({ error: 'Missing authorization header.' }, 401);
  }

  const supabase = createClient(SUPABASE_URL, SUPABASE_ANON_KEY, {
    global: { headers: { Authorization: authHeader } },
  });

  const {
    data: { user },
    error: authError,
  } = await supabase.auth.getUser();
  if (authError || !user) {
    return json({ error: 'Unauthorized user.' }, 401);
  }

  const profileResult = await supabase
    .from('profiles')
    .select('plan_tier, is_premium')
    .eq('id', user.id)
    .single();
  const planTier = resolvePlanTier(
    profileResult.data?.plan_tier,
    profileResult.data?.is_premium,
  );
  const dailyLimit =
    planTier === 'free'
      ? FREE_DAILY_LIMIT
      : planTier === 'premium'
      ? PREMIUM_DAILY_LIMIT
      : null;

  const now = new Date();
  const dayStart = new Date(
    Date.UTC(now.getUTCFullYear(), now.getUTCMonth(), now.getUTCDate()),
  );

  // Confirmed usage should be counted from the ledger that is written only
  // after a transaction is successfully saved from voice input.
  const confirmedDailyCountResult = await supabase
    .from('voice_entry_ledger')
    .select('id', { count: 'exact', head: true })
    .eq('user_id', user.id)
    .gte('created_at', dayStart.toISOString());

  const confirmedDailyUsed = confirmedDailyCountResult.count ?? 0;

  // Keep a separate hard safety guard for raw transcription requests.
  const attemptDailyCountResult = await supabase
    .from('ai_voice_requests')
    .select('id', { count: 'exact', head: true })
    .eq('user_id', user.id)
    .gte('created_at', dayStart.toISOString());

  const attemptDailyUsed = attemptDailyCountResult.count ?? 0;
  let freeTrialUsed = 0;
  let freeTrialEnd: Date | null = null;

  if (planTier === 'free') {
    const signupAt = user.created_at ? new Date(user.created_at) : now;
    freeTrialEnd = new Date(signupAt);
    freeTrialEnd.setUTCDate(freeTrialEnd.getUTCDate() + FREE_TRIAL_DAYS);

    if (now > freeTrialEnd) {
      return json(
        {
          error: 'Free voice trial ended. Upgrade to continue voice entries.',
        },
        429,
      );
    }

    const freeTrialCountResult = await supabase
      .from('voice_entry_ledger')
      .select('id', { count: 'exact', head: true })
      .eq('user_id', user.id)
      .gte('created_at', signupAt.toISOString())
      .lt('created_at', freeTrialEnd.toISOString());
    freeTrialUsed = freeTrialCountResult.count ?? 0;

    if (freeTrialUsed >= FREE_TRIAL_TOTAL_LIMIT) {
      return json(
        {
          error: 'Free voice trial limit reached. Upgrade to continue voice entries.',
        },
        429,
      );
    }
  }

  if (attemptDailyUsed >= VOICE_DAILY_HARD_SAFETY_LIMIT) {
    return json(
      {
        error:
          'Daily voice AI safety limit reached. Please contact support if this is unexpected.',
      },
      429,
    );
  }

  if (dailyLimit != null && confirmedDailyUsed >= dailyLimit) {
    return json(
      {
        error: 'Daily voice AI limit reached for your plan.',
      },
      429,
    );
  }

  const formData = await req.formData();
  const file = formData.get('file');
  if (!(file instanceof File)) {
    return json({ error: 'Audio file is required.' }, 400);
  }

  if (file.size <= 0) {
    return json({ error: 'Audio file is empty.' }, 400);
  }

  if (file.size > MAX_AUDIO_BYTES) {
    return json(
      { error: 'Audio file is too large. Keep it under 5 MB.' },
      413,
    );
  }

  let requestId: number | null = null;
  const requestInsert = await supabase
    .from('ai_voice_requests')
    .insert({ user_id: user.id, status: 'started' })
    .select('id')
    .single();

  requestId = requestInsert.data?.id ?? null;

  try {
    const transcript = await transcribeWithFallback(file);
    if (!transcript) {
      throw new Error('No audio transcript detected. Please try again.');
    }

    const description = await summarizeDescription(transcript);

    if (requestId != null) {
      await supabase
        .from('ai_voice_requests')
        .update({ status: 'success' })
        .eq('id', requestId)
        .eq('user_id', user.id);
    }

    return json({
      transcript,
      description,
      usage: {
        daily_used: confirmedDailyUsed,
        daily_limit: dailyLimit,
        monthly_used: planTier === 'free' ? freeTrialUsed : 0,
        monthly_limit: planTier === 'free' ? FREE_TRIAL_TOTAL_LIMIT : null,
        trial_days: planTier === 'free' ? FREE_TRIAL_DAYS : null,
        trial_ends_at: freeTrialEnd?.toISOString() ?? null,
      },
    });
  } catch (error) {
    if (requestId != null) {
      await supabase
        .from('ai_voice_requests')
        .update({ status: 'failed' })
        .eq('id', requestId)
        .eq('user_id', user.id);
    }

    const message =
      error instanceof Error
        ? error.message
        : 'Failed to transcribe voice note.';
    return json({ error: message }, 500);
  }
});

async function transcribeWithFallback(file: File): Promise<string> {
  const prompt =
    'Transcribe short personal finance statements with clear amounts and items.';

  const verbose = await callWhisper(file, {
    response_format: 'verbose_json',
    prompt,
  });

  let text = (verbose?.text as string | undefined)?.trim() ?? '';
  if (!text && Array.isArray(verbose?.segments)) {
    const segments = (verbose.segments as Array<{ text?: string }>)
      .map((segment) => segment.text?.trim() ?? '')
      .filter((value) => value.length > 0);
    text = segments.join(' ').trim();
  }

  if (text && !isKnownHallucination(text)) return text;

  const plain = await callWhisper(file, {
    response_format: 'text',
    prompt,
  });
  return String(plain ?? '').trim();
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

function isKnownHallucination(text: string): boolean {
  const lower = text.toLowerCase();
  return lower.includes('www.fema.gov') || lower.includes('for more information');
}

async function callWhisper(
  file: File,
  params: { response_format: 'verbose_json' | 'text'; prompt: string },
): Promise<unknown> {
  const form = new FormData();
  form.append('file', file, 'audio.m4a');
  form.append('model', 'whisper-1');
  form.append('language', 'en');
  form.append('temperature', '0');
  form.append('prompt', params.prompt);
  form.append('response_format', params.response_format);

  const response = await fetch('https://api.openai.com/v1/audio/transcriptions', {
    method: 'POST',
    headers: { Authorization: `Bearer ${OPENAI_API_KEY}` },
    body: form,
  });

  if (!response.ok) {
    throw new Error('Voice transcription failed. Please try again.');
  }

  if (params.response_format === 'text') {
    return await response.text();
  }
  return await response.json();
}

async function summarizeDescription(transcript: string): Promise<string | null> {
  const response = await fetch('https://api.openai.com/v1/chat/completions', {
    method: 'POST',
    headers: {
      Authorization: `Bearer ${OPENAI_API_KEY}`,
      'Content-Type': 'application/json',
    },
    body: JSON.stringify({
      model: 'gpt-4o-mini',
      temperature: 0.1,
      messages: [
        {
          role: 'system',
          content:
            'Convert voice finance transcripts into a short meaningful description. ' +
            'Return only 2-5 words, no quotes, no full sentence.',
        },
        {
          role: 'user',
          content: `Transcript: "${transcript}"`,
        },
      ],
    }),
  });

  if (!response.ok) return null;
  const jsonData = (await response.json()) as {
    choices?: Array<{ message?: { content?: string } }>;
  };
  const value = jsonData.choices?.[0]?.message?.content?.trim();
  if (!value) return null;
  return value
    .replaceAll(/["`]+/g, '')
    .replaceAll(/\s+/g, ' ')
    .replaceAll(/[.,;:!?]+$/g, '')
    .trim()
    .slice(0, 42);
}

function json(payload: Record<string, unknown>, status = 200): Response {
  return new Response(JSON.stringify(payload), {
    status,
    headers: { ...corsHeaders, 'Content-Type': 'application/json' },
  });
}
