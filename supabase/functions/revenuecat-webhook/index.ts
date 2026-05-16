// Apex Run — revenuecat-webhook Edge Function
//
// Endpoint receives RevenueCat server-to-server events and mirrors entitlement
// state into `public.subscriptions`. Uses the service role key so it can bypass
// RLS and write on behalf of users.
//
// Required secrets:
//   SUPABASE_URL              auto-set
//   SUPABASE_SERVICE_ROLE_KEY auto-set (NEVER expose to clients)
//   RC_WEBHOOK_AUTH_TOKEN     RevenueCat → Project → Integrations → Webhooks → Auth header
//
// Configure in RevenueCat dashboard:
//   URL    https://<project-ref>.supabase.co/functions/v1/revenuecat-webhook
//   Header Authorization: Bearer <RC_WEBHOOK_AUTH_TOKEN>
//
// Event handling: any non-cancellation event upserts active state; cancellation
// or expiration sets status accordingly. Tier is derived from product entitlement.

import { createClient } from 'https://esm.sh/@supabase/supabase-js@2.45.4';

const SUPABASE_URL = Deno.env.get('SUPABASE_URL')!;
const SUPABASE_SERVICE_ROLE_KEY = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!;
const RC_WEBHOOK_AUTH_TOKEN = Deno.env.get('RC_WEBHOOK_AUTH_TOKEN') ?? '';

interface RcEvent {
  type: string;
  app_user_id: string;
  product_id?: string;
  entitlement_ids?: string[];
  entitlement_id?: string;
  expiration_at_ms?: number;
}

interface RcEnvelope {
  event: RcEvent;
}

Deno.serve(async (req: Request) => {
  if (req.method !== 'POST') {
    return new Response('method not allowed', { status: 405 });
  }

  const auth = req.headers.get('Authorization');
  if (!RC_WEBHOOK_AUTH_TOKEN || auth !== `Bearer ${RC_WEBHOOK_AUTH_TOKEN}`) {
    return new Response('unauthorized', { status: 401 });
  }

  let payload: RcEnvelope;
  try {
    payload = await req.json();
  } catch {
    return new Response('invalid json', { status: 400 });
  }

  const ev = payload?.event;
  if (!ev?.app_user_id) {
    return new Response('missing app_user_id', { status: 400 });
  }

  const tier = pickTier(ev);
  const status = pickStatus(ev.type);
  const expiresAt = ev.expiration_at_ms ? new Date(ev.expiration_at_ms).toISOString() : null;

  const admin = createClient(SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY);
  const { error } = await admin.from('subscriptions').upsert({
    user_id: ev.app_user_id,
    tier,
    status,
    revenue_cat_app_user_id: ev.app_user_id,
    product_id: ev.product_id ?? null,
    current_period_ends_at: expiresAt,
    updated_at: new Date().toISOString(),
  }, { onConflict: 'user_id' });

  if (error) {
    console.error('upsert failed:', error);
    return new Response('db error', { status: 500 });
  }

  return new Response(null, { status: 204 });
});

function pickTier(ev: RcEvent): 'free' | 'pro' | 'pro_plus' {
  const entitlements = ev.entitlement_ids ?? (ev.entitlement_id ? [ev.entitlement_id] : []);
  if (entitlements.includes('pro_plus')) return 'pro_plus';
  if (entitlements.includes('pro')) return 'pro';
  return 'free';
}

function pickStatus(eventType: string):
  'inactive' | 'trial' | 'active' | 'in_grace' | 'cancelled' | 'expired' {
  switch (eventType) {
    case 'INITIAL_PURCHASE':
    case 'RENEWAL':
    case 'PRODUCT_CHANGE':
    case 'UNCANCELLATION':
      return 'active';
    case 'TRIAL_STARTED':
    case 'TRIAL_CONVERTED':
      return 'trial';
    case 'BILLING_ISSUE':
      return 'in_grace';
    case 'CANCELLATION':
    case 'SUBSCRIPTION_PAUSED':
      return 'cancelled';
    case 'EXPIRATION':
      return 'expired';
    default:
      return 'active';
  }
}
