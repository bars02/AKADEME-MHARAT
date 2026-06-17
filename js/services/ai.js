/*
  Maharat AI Service - Multi-Agent Architecture
  Handles communication with Groq API for different platform assistants.
*/

const GROQ_KEYS = {
    main: import.meta.env.VITE_GROQ_API_KEY_MAIN,
    medical: import.meta.env.VITE_GROQ_API_KEY_MEDICAL,
    pathology: import.meta.env.VITE_GROQ_API_KEY_PATHOLOGY
};

// System Prompts for each agent
const SYSTEM_PROMPTS = {
    main: `أنت المساعد الذكي الرسمي لمنصة "أكاديمية مهارات" (Maharat Academy).
مهمتك: مساعدة الزوار في فهم المنصة وشرح أقسامها (الأجهزة الطبية، والتحليلات المرضية) وتوجيههم لإنشاء حساب.
شخصيتك: مهني، مرحب، وداعم.
تعليمات هامة: 
1. أجب بإيجاز (سطلرين إلى ثلاثة كحد أقصى).
2. لا تخترع معلومات غير موجودة عن المنصة.
3. إذا سألك المستخدم عن كيفية التسجيل، وجهه لزر "إنشاء حساب" (Create Account) في الصفحة.`,
    
    medical: `أنت خبير محترف في صيانة وتشغيل "الأجهزة الطبية".
مهمتك: الإجابة على أسئلة المهندسين والطلاب حول الأجهزة الطبية والمحاكاة.
شخصيتك: دقيق، علمي، وعملي.
تعليمات هامة: أجب بشكل مختصر ودقيق جداً (لا تتجاوز 3 أسطر).`,
    
    pathology: `أنت طبيب خبير في "التحليلات المرضية والمختبرات".
مهمتك: شرح كيفية تحليل العينات وقراءة المؤشرات الحيوية للطلاب.
شخصيتك: أكاديمي، دقيق، وطبي.
تعليمات هامة: أجب بشكل مختصر وعلمي (لا تتجاوز 3 أسطر).`
};

export const aiService = {
    /**
     * Send a prompt to Groq API
     * @param {string} userMessage - The user's question
     * @param {string} agentType - 'main', 'medical', or 'pathology'
     * @returns {Promise<string>} - The AI response
     */
    async ask(userMessage, agentType = 'main') {
        // Try requested key -> main key -> medical key -> pathology key
        const apiKey = GROQ_KEYS[agentType] || GROQ_KEYS.main || GROQ_KEYS.medical || GROQ_KEYS.pathology; 
        
        if (!apiKey) {
            console.error(`AI Error: No API Key found for agent '${agentType}'`);
            return "عذراً، المساعد الذكي غير متصل حالياً. يرجى التأكد من إعداد مفتاح API الخاص بالقسم.";
        }

        try {
            const response = await fetch('https://api.groq.com/openai/v1/chat/completions', {
                method: 'POST',
                headers: {
                    'Authorization': `Bearer ${apiKey}`,
                    'Content-Type': 'application/json'
                },
                body: JSON.stringify({
                    model: 'llama-3.3-70b-versatile', // Fast and capable model
                    messages: [
                        { role: 'system', content: SYSTEM_PROMPTS[agentType] || SYSTEM_PROMPTS.main },
                        { role: 'user', content: userMessage }
                    ],
                    temperature: 0.5,
                    max_tokens: 150
                })
            });

            if (!response.ok) {
                const errorData = await response.json();
                throw new Error(errorData.error?.message || 'API Error');
            }

            const data = await response.json();
            return data.choices[0]?.message?.content || "حدث خطأ غير متوقع.";
            
        } catch (error) {
            console.error('Groq API Error:', error);
            return "أواجه مشكلة في الاتصال بالخادم حالياً. يرجى المحاولة بعد قليل.";
        }
    }
};
