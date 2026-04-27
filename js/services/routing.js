import { supabase } from './supabase.js';

export const routing = {
    async checkAccess(requiredRoles = []) {
        const { data: { user } } = await supabase.auth.getUser();
        
        const pathPrefix = window.location.pathname.includes('/dashboard/') || window.location.pathname.includes('/pages/') ? '../' : './';
        const loginPath = `${pathPrefix}login.html`;
        const waitingPath = `${pathPrefix}pages/waiting-approval.html`;

        if (!user) {
            window.location.href = loginPath;
            return null;
        }

        const { data: profile, error } = await supabase
            .from('profiles')
            .select('role, status, department_id, name')
            .eq('id', user.id)
            .single();

        if (error || !profile) {
            console.error('Profile not found:', error);
            window.location.href = loginPath;
            return null;
        }

        // 1. Check Approval Status
        if (profile.status !== 'approved') {
            if (!window.location.pathname.includes('waiting-approval.html')) {
                window.location.href = waitingPath;
            }
            return profile;
        }

        // 2. Check Role Requirements
        if (requiredRoles.length > 0 && !requiredRoles.includes(profile.role)) {
            window.location.href = `${pathPrefix}dashboard/${profile.role}.html`;
            return profile;
        }

        return profile;
    },

    async logout() {
        await supabase.auth.signOut();
        const pathPrefix = window.location.pathname.includes('/dashboard/') || window.location.pathname.includes('/pages/') ? '../' : './';
        window.location.href = `${pathPrefix}login.html`;
    }
};
