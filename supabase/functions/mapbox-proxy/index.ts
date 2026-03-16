import { serve } from "https://deno.land/std@0.168.0/http/server.ts"

const MAPBOX_ACCESS_TOKEN = Deno.env.get("MAPBOX_ACCESS_TOKEN")

serve(async (req) => {
  const url = new URL(req.url)
  const path = url.pathname.replace('/mapbox-proxy', '')
  
  if (!MAPBOX_ACCESS_TOKEN) {
    return new Response(JSON.stringify({ error: "Missing Mapbox Token" }), { status: 500 })
  }

  // Forwarding to Mapbox Static Images API or Tile API
  const mapboxUrl = `https://api.mapbox.com${path}${url.search}&access_token=${MAPBOX_ACCESS_TOKEN}`
  
  try {
    const response = await fetch(mapboxUrl)
    const data = await response.arrayBuffer()
    
    return new Response(data, {
      headers: {
        "Content-Type": response.headers.get("Content-Type") || "image/png",
        "Cache-Control": "public, max-age=86400"
      }
    })
  } catch (e) {
    return new Response(JSON.stringify({ error: e.message }), { status: 500 })
  }
})
