/* 
  Supabase Service - Clean & Optimized
  - Using real project credentials provided by user.
*/

import { createClient } from 'https://cdn.jsdelivr.net/npm/@supabase/supabase-js/+esm';

// Supabase Project Credentials
const SUPABASE_URL = 'https://qthzqwkoeqyoevmtysts.supabase.co';
const SUPABASE_KEY = 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InF0aHpxd2tvZXF5b2V2bXR5c3RzIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzY0MzMxNjcsImV4cCI6MjA5MjAwOTE2N30.AXBPk5xjqhahRWtryi1vJGwJQvlkH9VJJfK379h5DZw';

export const supabase = createClient(SUPABASE_URL, SUPABASE_KEY);

// Auth helper
export const auth = {
    async user() {
        try {
            const { data: { user } } = await supabase.auth.getUser();
            return user;
        } catch (e) {
            return null;
        }
    },
    async profile() {
        try {
            const u = await this.user();
            if (!u) return null;
            const { data, error } = await supabase.from('profiles').select('*').eq('id', u.id).single();
            if (error) throw error;
            return data;
        } catch (e) {
            console.error('Profile fetch error:', e);
            return null;
        }
    }
};
