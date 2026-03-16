import { serve } from "https://deno.land/std@0.168.0/http/server.ts"

serve(async (req) => {
  const { hrv_rmssd, sleep_score, resting_heart_rate, yesterday_training_load, user_id } = await req.json()
  
  // Logic from ml-service/main.py
  let score = (hrv_rmssd * 0.4) + (sleep_score * 0.4) - (resting_heart_rate * 0.2)
  score = Math.max(0, Math.min(100, score))
  
  let status = "Optimal"
  let modifier = 1.0
  let recommendation = "You are ready for your planned workout."
  
  if (score < 50) {
    status = "Fatigued"
    modifier = 0.7
    recommendation = "Recovery focus today. Keep intensity low."
  }
  
  return new Response(JSON.stringify({
    user_id,
    recovery_score: score,
    recovery_status: status,
    workout_modifier: modifier,
    recommendation
  }), { headers: { "Content-Type": "application/json" } })
})
