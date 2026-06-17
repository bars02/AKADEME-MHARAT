/* 
  Supabase Service - Clean & Optimized
  - Using real project credentials provided by user.
*/

import { createClient } from 'https://cdn.jsdelivr.net/npm/@supabase/supabase-js/+esm';

// Supabase Project Credentials
const SUPABASE_URL = (typeof import.meta !== 'undefined' && import.meta.env && import.meta.env.VITE_SUPABASE_URL) || 'https://qthzqwkoeqyoevmtysts.supabase.co';
const SUPABASE_KEY = (typeof import.meta !== 'undefined' && import.meta.env && import.meta.env.VITE_SUPABASE_ANON_KEY) || 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InF0aHpxd2tvZXF5b2V2bXR5c3RzIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzY0MzMxNjcsImV4cCI6MjA5MjAwOTE2N30.AXBPk5xjqhahRWtryi1vJGwJQvlkH9VJJfK379h5DZw';

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

const ALLOWED_TYPES = [
    'image/jpeg', 'image/png', 'image/webp', 'image/gif',
    'application/pdf',
    'video/mp4', 'video/webm',
    'application/vnd.openxmlformats-officedocument.wordprocessingml.document',
    'application/msword',
    'application/vnd.openxmlformats-officedocument.presentationml.presentation',
    'application/vnd.ms-powerpoint',
    'model/gltf-binary', 'model/gltf+json'
];
const MAX_FILE_SIZE = 50 * 1024 * 1024; // 50MB

export async function uploadFile(file, folder = 'media') {
    // Client-side validation (mirrors the storage bucket policy)
    if (file.size > MAX_FILE_SIZE) {
        throw new Error(`File too large. Maximum size is 50MB. Your file is ${(file.size / 1024 / 1024).toFixed(1)}MB.`);
    }
    if (!ALLOWED_TYPES.includes(file.type)) {
        throw new Error(`File type not allowed: ${file.type}. Please upload PDF, image, video, Word, or PowerPoint files.`);
    }
    const ext = file.name.split('.').pop().toLowerCase();
    const safeFolder = folder.replace(/[^a-zA-Z0-9_-]/g, ''); // sanitize folder name
    const path = `${safeFolder}/${Date.now()}-${Math.random().toString(36).slice(2)}.${ext}`;
    const { error } = await supabase.storage.from('media').upload(path, file);
    if (error) throw error;
    const { data: { publicUrl } } = supabase.storage.from('media').getPublicUrl(path);
    return publicUrl;
}
