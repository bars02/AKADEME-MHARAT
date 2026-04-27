/* 
  Global UI Service
  - Toast notifications
  - Modals
  - Loading states
*/

export const ui = {
    toast(message, type = 'success') {
        let container = document.getElementById('toast-container');
        if (!container) {
            container = document.createElement('div');
            container.id = 'toast-container';
            container.className = 'toast-container';
            document.body.appendChild(container);
        }

        const el = document.createElement('div');
        el.className = `toast ${type}`;
        el.innerHTML = `
            <div class="toast-content">${message}</div>
        `;
        
        container.appendChild(el);

        // Auto remove
        setTimeout(() => {
            el.style.opacity = '0';
            el.style.transform = 'translateY(-20px)';
            setTimeout(() => el.remove(), 500);
        }, 4000);
    },

    setLoading(btn, isLoading, originalText) {
        if (isLoading) {
            btn.disabled = true;
            btn.dataset.original = btn.innerHTML;
            btn.innerHTML = '<span class="loading-spinner"></span>';
        } else {
            btn.disabled = false;
            btn.innerHTML = btn.dataset.original || originalText;
        }
    }
};
