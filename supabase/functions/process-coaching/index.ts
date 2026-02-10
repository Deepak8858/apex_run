// Supabase Edge Function: process-coaching
// Moves Gemini AI coaching calls server-side to eliminate API key exposure on client.
//
// Input:  { user_id, current_hrv?, last_7_days_load, recent_activities }
// Output: { workout_type, description, target_distance_meters, target_duration_minutes, coaching_rationale }

// Deno runtime type declarations for VS Code compatibility
declare const Deno: {
  env: { get(key: string): string | undefined };
  serve(handler: (req: Request) => Promise<Response> | Response): void;
};

const GEMINI_API_KEY = Deno.env.get("GEMINI_API_KEY") ?? "";
const GEMINI_MODEL = Deno.env.get("GEMINI_MODEL") ?? "gemini-2.5-flash";
const GEMINI_URL = `https://generativelanguage.googleapis.com/v1beta/models/${GEMINI_MODEL}:generateContent?key=${GEMINI_API_KEY}`;

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers":
    "authorization, x-client-info, apikey, content-type",
};

interface CoachingRequest {
  user_id: string;
  current_hrv?: number;
  last_7_days_load: {
    total_distance_km: number;
    total_duration_min: number;
    run_count: number;
    avg_pace: string;
  };
  recent_activities: Array<{
    name: string;
    distance_km: number;
    duration_min: number;
    pace: string;
    type: string;
  }>;
}

Deno.serve(async (req: Request) => {
  // Handle CORS preflight
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  try {
    // Validate API key is configured
    if (!GEMINI_API_KEY) {
      return new Response(
        JSON.stringify({ error: "GEMINI_API_KEY not configured" }),
        {
          status: 500,
          headers: { ...corsHeaders, "Content-Type": "application/json" },
        }
      );
    }

    const body: CoachingRequest = await req.json();

    // Build prompt for Gemini
    const activitiesSummary = body.recent_activities
      .map(
        (a) =>
          `- ${a.name}: ${a.distance_km}km, ${a.duration_min}min, pace ${a.pace}, type: ${a.type}`
      )
      .join("\n");

    const prompt = `You are an elite marathon coach specializing in data-driven training.
Analyze this runner's data and generate ONE workout for today.

Weekly Load (last 7 days):
- Runs: ${body.last_7_days_load.run_count}
- Total Distance: ${body.last_7_days_load.total_distance_km} km
- Total Duration: ${body.last_7_days_load.total_duration_min} min
- Average Pace: ${body.last_7_days_load.avg_pace}
${body.current_hrv ? `- Current HRV: ${body.current_hrv}` : ""}

Recent Activities:
${activitiesSummary || "No recent activities"}

Respond ONLY with a JSON object (no markdown, no code blocks):
{
  "workout_type": "easy|tempo|intervals|long_run|recovery|race",
  "description": "Specific workout instructions",
  "target_distance_meters": 5000,
  "target_duration_minutes": 30,
  "coaching_rationale": "Why this workout is recommended"
}`;

    // Call Gemini API
    const geminiResponse = await fetch(GEMINI_URL, {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({
        contents: [
          {
            parts: [{ text: prompt }],
          },
        ],
        generationConfig: {
          temperature: 0.7,
          maxOutputTokens: 1024,
        },
        systemInstruction: {
          parts: [
            {
              text: "You are an elite running coach. Always respond in valid JSON format when generating workouts. Base recommendations on physiological principles and the runner's recent training load.",
            },
          ],
        },
      }),
    });

    if (!geminiResponse.ok) {
      const errText = await geminiResponse.text();
      console.error("Gemini API error:", errText);
      return new Response(
        JSON.stringify({
          error: "Gemini API call failed",
          details: errText,
        }),
        {
          status: 502,
          headers: { ...corsHeaders, "Content-Type": "application/json" },
        }
      );
    }

    const geminiData = await geminiResponse.json();
    const generatedText =
      geminiData?.candidates?.[0]?.content?.parts?.[0]?.text ?? "";

    // Parse response — strip markdown fences if present
    let cleaned = generatedText.trim();
    if (cleaned.startsWith("```")) {
      cleaned = cleaned.replace(/^```\w*\n?/, "").replace(/\n?```$/, "");
    }

    let workout;
    try {
      workout = JSON.parse(cleaned.trim());
    } catch {
      // Fallback if JSON parsing fails
      workout = {
        workout_type: "easy",
        description: "Easy recovery run at comfortable pace",
        target_distance_meters: 5000,
        target_duration_minutes: 30,
        coaching_rationale:
          "Default recommendation (AI response could not be parsed)",
      };
    }

    return new Response(JSON.stringify(workout), {
      headers: { ...corsHeaders, "Content-Type": "application/json" },
    });
  } catch (error: unknown) {
    console.error("Edge function error:", error);
    const message = error instanceof Error ? error.message : "Unknown error";
    return new Response(
      JSON.stringify({
        error: "Internal server error",
        message,
      }),
      {
        status: 500,
        headers: { ...corsHeaders, "Content-Type": "application/json" },
      }
    );
  }
});
