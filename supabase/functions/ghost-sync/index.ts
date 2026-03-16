import { serve } from "https://deno.land/std@0.168.0/http/server.ts"

interface ActivityPoint {
  time_s: number;
  dist_m: number;
  lat?: number;
  lng?: number;
}

interface GhostMatchRequest {
  user_elapsed_s: number;
  user_dist_m: number;
  ghost_stream: ActivityPoint[];
}

serve(async (req) => {
  try {
    const { user_elapsed_s, user_dist_m, ghost_stream }: GhostMatchRequest = await req.json()

    if (!ghost_stream || ghost_stream.length === 0) {
      return new Response(JSON.stringify({ error: "Ghost stream is empty" }), { 
        status: 400, 
        headers: { "Content-Type": "application/json" } 
      })
    }

    // Sort stream by time to be safe
    const stream = ghost_stream.sort((a, b) => a.time_s - b.time_s)
    let ghost_dist = 0
    let status = "ahead"

    // Check if ghost is finished
    if (user_elapsed_s >= stream[stream.length - 1].time_s) {
      ghost_dist = stream[stream.length - 1].dist_m
      status = "finished"
    } else {
      // Find the bounding interval for interpolation
      let p1 = stream[0]
      let p2 = stream[stream.length - 1]

      for (let i = 0; i < stream.length - 1; i++) {
        if (stream[i].time_s <= user_elapsed_s && user_elapsed_s < stream[i + 1].time_s) {
          p1 = stream[i]
          p2 = stream[i + 1]
          break
        }
      }

      if (p2.time_s === p1.time_s) {
        ghost_dist = p1.dist_m
      } else {
        const time_ratio = (user_elapsed_s - p1.time_s) / (p2.time_s - p1.time_s)
        ghost_dist = p1.dist_m + time_ratio * (p2.dist_m - p1.dist_m)
      }
      
      status = ghost_dist > user_dist_m ? "ahead" : "behind"
    }

    const gap = ghost_dist - user_dist_m

    return new Response(
      JSON.stringify({
        ghost_dist_m: parseFloat(ghost_dist.toFixed(1)),
        gap_m: parseFloat(gap.toFixed(1)),
        status: status
      }),
      { headers: { "Content-Type": "application/json" } }
    )
  } catch (error) {
    return new Response(JSON.stringify({ error: error.message }), { 
      status: 500, 
      headers: { "Content-Type": "application/json" } 
    })
  }
})
