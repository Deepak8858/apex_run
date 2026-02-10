// Supabase Edge Function: process-activity
// Post-activity processing: segment matching, training load update, ACWR calculation

import { createClient } from 'jsr:@supabase/supabase-js@2'

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
}

Deno.serve(async (req: Request) => {
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders })
  }

  try {
    const supabaseUrl = Deno.env.get('SUPABASE_URL')!
    const supabaseKey = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!
    const supabase = createClient(supabaseUrl, supabaseKey)

    const { activity_id, user_id, elapsed_seconds, avg_pace, avg_heart_rate, max_speed } = await req.json()

    if (!activity_id || !user_id) {
      return new Response(
        JSON.stringify({ error: 'activity_id and user_id are required' }),
        { status: 400, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
      )
    }

    // 1. Match segments for this activity
    const { data: matchedSegments, error: matchError } = await supabase
      .rpc('match_segments_for_activity', { p_activity_id: activity_id })

    if (matchError) {
      console.error('Segment matching error:', matchError)
    }

    // 2. Create segment efforts for matched segments
    let effortCount = 0
    if (matchedSegments && matchedSegments.length > 0) {
      const { data: efforts, error: effortError } = await supabase
        .rpc('process_segment_efforts', {
          p_activity_id: activity_id,
          p_user_id: user_id,
          p_elapsed_seconds: elapsed_seconds || 0,
          p_avg_pace: avg_pace || 0,
          p_avg_heart_rate: avg_heart_rate || null,
          p_max_speed: max_speed || null,
        })

      if (effortError) {
        console.error('Effort creation error:', effortError)
      } else {
        effortCount = efforts || 0
      }
    }

    // 3. Calculate ACWR
    const { data: acwr, error: acwrError } = await supabase
      .rpc('calculate_acwr', { p_user_id: user_id })

    if (acwrError) {
      console.error('ACWR calculation error:', acwrError)
    }

    // 4. Refresh leaderboard materialized view
    if (effortCount > 0) {
      await supabase.rpc('refresh_leaderboard')
    }

    return new Response(
      JSON.stringify({
        matched_segments: matchedSegments?.length || 0,
        efforts_created: effortCount,
        acwr: acwr?.[0] || null,
      }),
      { headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
    )
  } catch (error: unknown) {
    console.error('Process activity error:', error)
    const message = error instanceof Error ? error.message : 'Unknown error'
    return new Response(
      JSON.stringify({ error: 'Internal server error', message }),
      { status: 500, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
    )
  }
})
