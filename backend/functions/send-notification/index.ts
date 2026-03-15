import { serve } from "https://deno.land/std@0.168.0/http/server.ts"

const ONESIGNAL_APP_ID = Deno.env.get("ONESIGNAL_APP_ID")
const ONESIGNAL_REST_API_KEY = Deno.env.get("ONESIGNAL_REST_API_KEY")

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
}

serve(async (req) => {
  // Handle CORS preflight requests
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders })
  }

  try {
    const { playerIds, companyId, title, message, data, color, sendAfter, filters } = await req.json()

    if (!title || !message) {
      throw new Error("Title and message are required")
    }

    const body: any = {
      app_id: ONESIGNAL_APP_ID,
      headings: { en: title },
      contents: { en: message },
      data,
      android_accent_color: color || "FFD4A237",
      small_icon: "ic_launcher",
      large_icon: "ic_launcher",
      priority: 10,
      android_visibility: 1,
      ios_sound: "default",
    }

    if (playerIds) {
      body.include_external_user_ids = playerIds
    } else if (filters) {
      body.filters = filters
    } else if (companyId) {
      body.filters = [
        { field: "tag", key: "company_id", relation: "=", value: companyId },
        { operator: "AND" },
        { field: "tag", key: "role", relation: "=", value: "staff" },
      ]
    }

    if (sendAfter) {
      body.send_after = sendAfter
    }

    const response = await fetch("https://onesignal.com/api/v1/notifications", {
      method: "POST",
      headers: {
        "Content-Type": "application/json; charset=utf-8",
        "Authorization": `Basic ${ONESIGNAL_REST_API_KEY}`,
      },
      body: JSON.stringify(body),
    })

    const result = await response.json()
    return new Response(JSON.stringify(result), {
      headers: { ...corsHeaders, "Content-Type": "application/json" },
      status: response.status,
    })
  } catch (error) {
    return new Response(JSON.stringify({ error: error.message }), {
      headers: { ...corsHeaders, "Content-Type": "application/json" },
      status: 400,
    })
  }
})
