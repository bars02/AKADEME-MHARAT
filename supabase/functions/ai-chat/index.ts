import { serve } from "https://deno.land/std@0.168.0/http/server.ts"

// Groq API - Works globally, Free tier: 14,400 requests/day
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
    const { message, agentType = 'main', course } = await req.json()

    if (!message) {
      return new Response(JSON.stringify({ error: 'Message is required' }), {
        headers: { ...corsHeaders, 'Content-Type': 'application/json' },
        status: 400,
      })
    }

    // Determine which API key to use based on agentType
    let GROQ_API_KEY = Deno.env.get('GROQ_API_KEY_MAIN');
    if (agentType === 'medical') {
      GROQ_API_KEY = Deno.env.get('GROQ_API_KEY_MEDICAL') || GROQ_API_KEY;
    } else if (agentType === 'pathology') {
      GROQ_API_KEY = Deno.env.get('GROQ_API_KEY_PATHOLOGY') || GROQ_API_KEY;
    }

    if (!GROQ_API_KEY) {
      throw new Error(`API Key for ${agentType} is missing in Supabase Secrets.`);
    }

    // System Prompts for each agent
    const SYSTEM_PROMPTS: Record<string, string> = {
        main: `أنت المساعد الذكي الرسمي لمنصة "أكاديمية مهارات" (Maharat Academy).
مهمتك: مساعدة الزوار في فهم المنصة وشرح أقسامها (الأجهزة الطبية، والتحليلات المرضية) وتوجيههم لإنشاء حساب.
شخصيتك: مهني، مرحب، وداعم.
تعليمات هامة: 
1. أجب بإيجاز (سطرين إلى ثلاثة كحد أقصى).
2. لا تخترع معلومات غير موجودة عن المنصة.
3. إذا سألك المستخدم عن كيفية التسجيل، وجهه لزر "إنشاء حساب" (Create Account) في الصفحة.`,
        
        medical: `أنت خبير محترف في صيانة وتشغيل "الأجهزة الطبية".
مهمتك: الإجابة على أسئلة المهندسين والطلاب حول الأجهزة الطبية والمحاكاة.
شخصيتك: دقيق، علمي، وعملي.
تعليمات هامة: أجب بشكل مختصر ودقيق جداً (لا تتجاوز 3 أسطر). التركيز فقط على الجانب الهندسي والطبي للأجهزة.`,
        
        pathology: `أنت طبيب خبير في "التحليلات المرضية والمختبرات".
مهمتك: شرح كيفية تحليل العينات وقراءة المؤشرات الحيوية للطلاب.
شخصيتك: أكاديمي، دقيق، وطبي.
تعليمات هامة: أجب بشكل مختصر وعلمي (لا تتجاوز 3 أسطر). لا تقم بتشخيص طبي للمرضى.`
    };

    const systemPrompt = SYSTEM_PROMPTS[agentType] || SYSTEM_PROMPTS['main'];

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
        max_tokens: 150,
        temperature: 0.5,
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
