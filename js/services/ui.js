/* 
  Global UI Service v2.0
  - Premium Toast notifications with icons
  - Smooth loading states
  - Modal utilities
*/

// HTML sanitization helper — escapes user data before injecting via innerHTML (XSS protection).
// Quotes are also encoded so esc() is safe inside HTML attribute values.
export function esc(str) {
    const d = document.createElement('div');
    d.textContent = String(str ?? '');
    return d.innerHTML.replace(/"/g, '&quot;').replace(/'/g, '&#39;');
}

export const ui = {
    toast(message, type = 'success') {
        let container = document.getElementById('toastContainer');
        if (!container) {
            container = document.createElement('div');
            container.id = 'toastContainer';
            container.className = 'toast-container';
            document.body.appendChild(container);
        }

        const icons = {
            success: 'fa-check-circle',
            error: 'fa-exclamation-circle',
            warning: 'fa-exclamation-triangle',
            info: 'fa-info-circle'
        };

        const el = document.createElement('div');
        el.className = `toast ${type}`;
        el.style.animation = 'toastIn 0.5s cubic-bezier(0.68, -0.55, 0.265, 1.55) forwards';
        
        el.innerHTML = `
            <i class="fas ${icons[type] || icons.info}"></i>
            <div class="toast-content">${esc(message)}</div>
        `;
        
        container.appendChild(el);

        // Auto remove
        setTimeout(() => {
            el.style.animation = 'toastOut 0.5s ease-in forwards';
            setTimeout(() => el.remove(), 500);
        }, 4000);
    },

    setLoading(btn, isLoading, originalText) {
        if (!btn) return;
        if (isLoading) {
            btn.disabled = true;
            btn.dataset.original = btn.innerHTML;
            btn.innerHTML = `<i class="fas fa-circle-notch fa-spin"></i> ${originalText || 'Loading...'}`;
        } else {
            btn.disabled = false;
            btn.innerHTML = btn.dataset.original || originalText || 'Submit';
        }
    }
};
