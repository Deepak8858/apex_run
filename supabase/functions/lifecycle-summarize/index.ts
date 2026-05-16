import { serve } from "https://deno.land/std@0.168.0/http/server.ts"

serve(async (req) => {
  const { distance_km, duration_mins, avg_hr, intensity_score, user_id } = await req.json()
  
  const intensity = intensity_score < 4 ? "low" : intensity_score < 7 ? "moderate" : "high"
  const summary = `Solid ${distance_km}km run. You maintained an average HR of ${avg_hr} bpm over ${duration_mins} minutes.`
  const impact = `This ${intensity} intensity session contributes to your aerobic base.`
  const rest = Math.round(intensity_score * 4)

  return new Response(JSON.stringify({
    summary,
    impact_on_goal: impact,
    suggested_rest_hours: rest,
    stiffness_index: null,
    knee_flexion: null
  }), { headers: { "Content-Type": "application/json" } })
})
