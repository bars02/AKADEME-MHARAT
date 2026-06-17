import { supabase } from './supabase.js';

export const aiService = {
    /**
     * Send a prompt to Supabase Edge Function (ai-chat)
     * @param {string} userMessage - The user's question
     * @param {string} agentType - 'main', 'medical', or 'pathology'
     * @returns {Promise<string>} - The AI response
     */
    async ask(userMessage, agentType = 'main') {
        try {
            const { data, error } = await supabase.functions.invoke('ai-chat', {
                body: { message: userMessage, agentType }
            });

            if (error) {
                console.error('Supabase Function Error:', error);
                throw new Error(error.message);
            }

            return data?.reply || "حدث خطأ غير متوقع.";
            
        } catch (error) {
            console.error('AI Service Error:', error);
            return "أواجه مشكلة في الاتصال بالخادم حالياً. يرجى المحاولة بعد قليل.";
        }
    }
};
