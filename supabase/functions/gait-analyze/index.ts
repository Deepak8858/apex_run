import { serve } from "https://deno.land/std@0.168.0/http/server.ts"

serve(async (req) => {
  const { ground_contact_time_ms, vertical_oscillation_cm, stiffness_index, peak_knee_flexion } = await req.json()
  
  let verdict = "Optimal"
  let advice = "Maintain current form."
  
  if (stiffness_index < 3.0) {
    verdict = "Low Elasticity"
    advice = "Focus on plyometric drills (pogo jumps) to improve stiffness."
  }
  
  if (peak_knee_flexion < 158) {
    verdict = "Excessive Flexion"
    advice = "Strengthen quads and focus on a 'tall' posture to prevent knee collapse."
  }
  
  return new Response(JSON.stringify({
    verdict,
    advice,
    stiffness_score: Math.round(stiffness_index * 100) / 100,
    flexion_score: Math.round(peak_knee_flexion * 10) / 10
  }), { headers: { "Content-Type": "application/json" } })
})
