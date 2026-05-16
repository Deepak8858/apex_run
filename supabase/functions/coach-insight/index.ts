// Apex Run — coach-insight Edge Function
//
// Returns a freeform 2-3 sentence coaching insight from recent activities.
// All Gemini calls happen server-side. Per-user daily quota enforced via
// public.check_and_increment_ai_quota('coach-insight', limit).
//
// Required secrets:
//   GEMINI_API_KEY            — server-only Gemini key
//   GEMINI_MODEL              — optional (default gemini-2.0-flash)
//   SUPABASE_URL              — auto-set
//   SUPABASE_ANON_KEY         — auto-set
//
// Invoke from Flutter:
//   await Supabase.instance.client.functions.invoke('coach-insight',
//     body: { recent_activities: [...] });

import { createClient } from 'https://esm.sh/@supabase/supabase-js@2.45.4';

const GEMINI_API_KEY = Deno.env.get('GEMINI_API_KEY') ?? '';
const GEMINI_MODEL = Deno.env.get('GEMINI_MODEL') ?? 'gemini-2.0-flash';
const SUPABASE_URL = Deno.env.get('SUPABASE_URL') ?? '';
const SUPABASE_ANON_KEY = Deno.env.get('SUPABASE_ANON_KEY') ?? '';
const DAILY_LIMIT = 25;

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Methods': 'POST, OPTIONS',
  'Access-Control-Allow-Headers': 'authorization, content-type',
};

interface ActivitySummary {
  name: string;
  distance_km: number;
  duration_min: number;
  pace: string;
  type?: string;
}

Deno.serve(async (req: Request) => {
  if (req.method === 'OPTIONS') {
    return new Response(null, { headers: corsHeaders });
  }
  if (req.method !== 'POST') {
    return json({ error: 'method not allowed' }, 405);
  }

  const authHeader = req.headers.get('Authorization');
  if (!authHeader) return json({ error: 'missing authorization' }, 401);

  const userClient = createClient(SUPABASE_URL, SUPABASE_ANON_KEY, {
    global: { headers: { Authorization: authHeader } },
  });

  const { data: { user }, error: userErr } = await userClient.auth.getUser();
  if (userErr || !user) return json({ error: 'invalid token' }, 401);

  // Rate limit
  const { data: quota, error: quotaErr } = await userClient
    .rpc('check_and_increment_ai_quota', {
      p_endpoint: 'coach-insight',
      p_daily_limit: DAILY_LIMIT,
    });

  if (quotaErr) {
    console.error('quota check failed:', quotaErr);
    return json({ error: 'quota check failed' }, 500);
  }

  const row = Array.isArray(quota) ? quota[0] : quota;
  if (!row?.allowed) {
    return json(
      { error: 'daily quota exceeded', remaining: 0 },
      429,
    );
  }

  // Parse + sanitize body
  let body: { recent_activities?: ActivitySummary[] };
  try {
    body = await req.json();
  } catch {
    return json({ error: 'invalid json' }, 400);
  }
  const activities = (body.recent_activities ?? []).slice(0, 20);

  // Empty input → return a deterministic onboarding nudge, don't burn quota
  if (activities.length === 0) {
    return json({
      insight:
        'Start with three easy 20-30 minute runs this week. Keep the pace conversational — build the base before adding intensity.',
      remaining: row.remaining,
    });
  }

  // Build prompt + call Gemini
  if (!GEMINI_API_KEY) {
    return json({ error: 'gemini not configured' }, 500);
  }

  const summary = activities
    .map((a) =>
      `- ${a.name}: ${a.distance_km.toFixed(1)} km, ${a.duration_min} min, pace ${a.pace}`
    )
    .join('\n');

  const prompt = `You are a running coach.
Provide 2-3 brief, specific, actionable insights from this runner's last 7 days.
Be specific with numbers. Avoid clichés. Plain prose, no JSON, no markdown.

Activities:
${summary}`;

  try {
    const geminiResp = await fetch(
      `https://generativelanguage.googleapis.com/v1beta/models/${GEMINI_MODEL}:generateContent?key=${GEMINI_API_KEY}`,
      {
        method: 'POST',
        headers: { 'content-type': 'application/json' },
        body: JSON.stringify({
          contents: [{ role: 'user', parts: [{ text: prompt }] }],
          generationConfig: { temperature: 0.7, maxOutputTokens: 200 },
        }),
      },
    );

    if (!geminiResp.ok) {
      console.error('gemini error:', geminiResp.status, await geminiResp.text());
      return json({ error: 'model call failed' }, 502);
    }

    const data = await geminiResp.json();
    const text: string =
      data?.candidates?.[0]?.content?.parts?.[0]?.text ?? '';

    if (!text) return json({ error: 'empty model response' }, 502);

    return json({ insight: text.trim(), remaining: row.remaining });
  } catch (e) {
    console.error('coach-insight uncaught:', e);
    return json({ error: 'internal error' }, 500);
  }
});

function json(body: unknown, status: number): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: { ...corsHeaders, 'content-type': 'application/json' },
  });
}
