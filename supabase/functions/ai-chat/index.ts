import { serve } from "https://deno.land/std@0.168.0/http/server.ts"

// Groq API - Works globally, Free tier: 14,400 requests/day
const GROQ_API_KEY = Deno.env.get('GROQ_API_KEY')
const GROQ_API_URL = "https://api.groq.com/openai/v1/chat/completions"
const GROQ_MODEL = "llama-3.3-70b-versatile" // Best free model on Groq

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
}

serve(async (req: Request) => {
  // Handle CORS
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders })
  }

  try {
    const { message, department, course } = await req.json()

    if (!message) {
      return new Response(JSON.stringify({ error: 'Message is required' }), {
        headers: { ...corsHeaders, 'Content-Type': 'application/json' },
        status: 400,
      })
    }

    const dept = department || 'General Medical Training';
    const courseName = course || 'General Course';

    const systemPrompt = `You are the "Maharat Academy AI Assistant", an expert medical tutor for the "${dept}" department, specifically for the "${courseName}" course.
    
    CRITICAL GUIDELINES:
    1. Be CONCISE. Provide short, direct, and factual answers (max 2-3 sentences unless absolutely necessary).
    2. TEXT ONLY. Never suggest downloading files, PDFs, or external links.
    3. NO IMAGES/MEDIA. Focus entirely on text-based explanation.
    4. Focus strictly on the medical/technical aspects of the current course.
    5. Match the user's language (Arabic/English).
    6. Never provide medical diagnoses for patients.`;

    const response = await fetch(GROQ_API_URL, {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        'Authorization': `Bearer ${GROQ_API_KEY}`,
      },
      body: JSON.stringify({
        model: GROQ_MODEL,
        messages: [
          { role: "system", content: systemPrompt },
          { role: "user", content: message }
        ],
        max_tokens: 800,
        temperature: 0.7,
      })
    })

    const data = await response.json()
    
    if (!response.ok) {
      throw new Error(`Groq API Error: ${data?.error?.message || JSON.stringify(data)}`)
    }

    const reply = data.choices?.[0]?.message?.content;
    
    if (!reply) {
      throw new Error(`No reply from Groq. Response: ${JSON.stringify(data)}`);
    }

    return new Response(JSON.stringify({ reply }), {
      headers: { ...corsHeaders, 'Content-Type': 'application/json' },
      status: 200,
    })

  } catch (err: any) {
    return new Response(JSON.stringify({ error: err.message || 'Internal Server Error' }), {
      headers: { ...corsHeaders, 'Content-Type': 'application/json' },
      status: 500,
    })
  }
})
