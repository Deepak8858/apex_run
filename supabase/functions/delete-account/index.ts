// Apex Run — delete-account Edge Function
//
// Hard-deletes the caller's account. Two-step:
//   1. Verify caller via their JWT, then call public.delete_my_account()
//      which clears all owned application rows (RLS enforces ownership).
//   2. Using the service-role key, call auth.admin.deleteUser(uid) to
//      remove the auth.users row.
//
// Required secrets (Supabase → Project Settings → Edge Functions → Secrets):
//   SUPABASE_URL              auto-set
//   SUPABASE_ANON_KEY         auto-set
//   SUPABASE_SERVICE_ROLE_KEY auto-set (NEVER expose to clients)
//
// Invoke from Flutter:
//   await Supabase.instance.client.functions.invoke('delete-account');

import { createClient } from 'https://esm.sh/@supabase/supabase-js@2.45.4';

const SUPABASE_URL = Deno.env.get('SUPABASE_URL')!;
const SUPABASE_ANON_KEY = Deno.env.get('SUPABASE_ANON_KEY')!;
const SUPABASE_SERVICE_ROLE_KEY = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!;

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Methods': 'POST, OPTIONS',
  'Access-Control-Allow-Headers': 'authorization, content-type',
};

Deno.serve(async (req: Request) => {
  if (req.method === 'OPTIONS') {
    return new Response(null, { headers: corsHeaders });
  }

  try {
    const authHeader = req.headers.get('Authorization');
    if (!authHeader) {
      return json({ error: 'missing authorization header' }, 401);
    }

    // Client #1: caller's JWT — validates identity & runs RPC under their auth.uid().
    const userClient = createClient(SUPABASE_URL, SUPABASE_ANON_KEY, {
      global: { headers: { Authorization: authHeader } },
    });

    const { data: { user }, error: getUserErr } = await userClient.auth.getUser();
    if (getUserErr || !user) {
      return json({ error: 'invalid token' }, 401);
    }

    // 1. Clean up owned rows via RLS-safe RPC.
    const { error: rpcErr } = await userClient.rpc('delete_my_account');
    if (rpcErr) {
      console.error('delete_my_account RPC failed:', rpcErr);
      return json({ error: 'application data deletion failed', detail: rpcErr.message }, 500);
    }

    // 2. Delete the auth.users row with the service role.
    const adminClient = createClient(SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY);
    const { error: deleteUserErr } = await adminClient.auth.admin.deleteUser(user.id);
    if (deleteUserErr) {
      console.error('auth.admin.deleteUser failed:', deleteUserErr);
      // Application rows already gone; the auth row will be cleaned by retry/cron.
      return json({ error: 'auth user deletion failed', detail: deleteUserErr.message }, 500);
    }

    return new Response(null, { status: 204, headers: corsHeaders });
  } catch (e) {
    console.error('delete-account uncaught:', e);
    return json({ error: 'internal error' }, 500);
  }
});

function json(body: unknown, status: number): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: { ...corsHeaders, 'content-type': 'application/json' },
  });
}
