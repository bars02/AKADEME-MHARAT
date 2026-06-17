import{i}from"./i18n-DRKnIWRY.js";import{s as t}from"./supabase-CizyiV9c.js";import"https://cdn.jsdelivr.net/npm/@supabase/supabase-js/+esm";let o=null;async function n(){const{data:{user:e}}=await t.auth.getUser();if(!e){window.location.href="../login.html";return}o=e.id,await c();const s=t.channel(`approval-watch-${o}`).on("postgres_changes",{event:"UPDATE",schema:"public",table:"profiles",filter:`id=eq.${o}`},r=>{r.new.status==="approved"&&a(r.new.role)}).subscribe();document.getElementById("logoutBtn").addEventListener("click",async()=>{await s.unsubscribe(),await t.auth.signOut(),window.location.href="../login.html"}),i.updateDOM()}async function c(){const{data:e}=await t.from("profiles").select("status, role").eq("id",o).single();e&&e.status==="approved"&&a(e.role)}function a(e){const s=document.querySelector(".glass-card");s.innerHTML=`
                <div class="mb-6" style="color: var(--success); font-size: 4rem; animation: bounceIn 0.6s ease;">
                    <i class="fas fa-check-circle"></i>
                </div>
                <h2 style="color: var(--success); font-size: 1.5rem; font-weight: 800; margin-bottom: 1rem;">
                    ✅ Account Approved!
                </h2>
                <p style="color: var(--text-muted); margin-bottom: 2rem;">
                    Redirecting you to your dashboard...
                </p>
                <div style="width: 100%; height: 4px; background: var(--border); border-radius: 2px; overflow: hidden;">
                    <div style="height: 100%; background: var(--success); animation: progressBar 1.5s ease-out forwards;"></div>
                </div>
                <style>
                    @keyframes bounceIn { 0% { transform: scale(0); } 70% { transform: scale(1.2); } 100% { transform: scale(1); } }
                    @keyframes progressBar { from { width: 0; } to { width: 100%; } }
                </style>
            `,setTimeout(()=>{window.location.href=`../dashboard/${e}.html`},1600)}n();
