import { aiService } from './services/ai.js';
import { esc } from './services/ui.js';

export function initAIWidget() {
    if (document.getElementById('aiWidgetContainer')) return; // Prevent double init
    
    // 1. Inject Widget HTML into DOM
    const widgetHTML = `
        <div id="aiWidgetContainer" class="ai-widget-container">
            <!-- Chat Window (Hidden by default) -->
            <div id="aiChatWindow" class="ai-chat-window hidden">
                <div class="ai-chat-header">
                    <div class="ai-avatar">
                        <i class="fas fa-robot"></i>
                    </div>
                    <div>
                        <h3 class="font-bold text-sm m-0">Maharat AI</h3>
                        <span class="text-xs text-blue-200">Online Assistant</span>
                    </div>
                    <button id="aiCloseBtn" class="ai-close-btn">
                        <i class="fas fa-times"></i>
                    </button>
                </div>
                <div id="aiChatMessages" class="ai-chat-messages">
                    <div class="ai-msg ai">مرحباً! أنا المساعد الذكي لأكاديمية مهارات. كيف يمكنني مساعدتك اليوم؟</div>
                </div>
                <div class="ai-chat-input-area">
                    <input type="text" id="aiChatInput" placeholder="اكتب سؤالك هنا..." autocomplete="off">
                    <button id="aiSendBtn" class="ai-send-btn">
                        <i class="fas fa-paper-plane"></i>
                    </button>
                </div>
            </div>

            <!-- Floating Toggle Button -->
            <button id="aiToggleBtn" class="ai-toggle-btn">
                <i class="fas fa-comment-dots"></i>
            </button>
        </div>

        <style>
            .ai-widget-container {
                position: fixed;
                bottom: 30px;
                right: 30px;
                z-index: 9999;
                font-family: inherit;
            }
            [dir="rtl"] .ai-widget-container {
                right: auto;
                left: 30px;
            }

            .ai-toggle-btn {
                width: 60px;
                height: 60px;
                border-radius: 50%;
                background: linear-gradient(135deg, var(--primary), var(--accent));
                color: white;
                border: none;
                font-size: 1.5rem;
                cursor: pointer;
                box-shadow: 0 10px 25px rgba(37, 99, 235, 0.4);
                transition: transform 0.3s cubic-bezier(0.68, -0.55, 0.265, 1.55);
                display: flex;
                align-items: center;
                justify-content: center;
            }
            .ai-toggle-btn:hover {
                transform: scale(1.1) translateY(-5px);
            }

            .ai-chat-window {
                position: absolute;
                bottom: 80px;
                right: 0;
                width: 350px;
                height: 500px;
                max-height: 80vh;
                background: rgba(255, 255, 255, 0.95);
                backdrop-filter: blur(16px);
                -webkit-backdrop-filter: blur(16px);
                border: 1px solid rgba(255, 255, 255, 0.4);
                border-radius: 24px;
                box-shadow: 0 20px 40px rgba(0, 0, 0, 0.15);
                display: flex;
                flex-direction: column;
                overflow: hidden;
                transform-origin: bottom right;
                transition: transform 0.3s cubic-bezier(0.68, -0.55, 0.265, 1.55), opacity 0.3s;
            }
            [dir="rtl"] .ai-chat-window {
                right: auto;
                left: 0;
                transform-origin: bottom left;
            }
            .ai-chat-window.hidden {
                opacity: 0;
                pointer-events: none;
                transform: scale(0.5) translateY(20px);
            }

            .ai-chat-header {
                background: linear-gradient(135deg, var(--primary), var(--accent));
                color: white;
                padding: 15px 20px;
                display: flex;
                align-items: center;
                gap: 12px;
            }
            .ai-avatar {
                width: 40px;
                height: 40px;
                background: rgba(255,255,255,0.2);
                border-radius: 50%;
                display: flex;
                align-items: center;
                justify-content: center;
                font-size: 1.2rem;
            }
            .ai-close-btn {
                margin-left: auto;
                background: none;
                border: none;
                color: rgba(255,255,255,0.8);
                cursor: pointer;
                font-size: 1.2rem;
                transition: 0.2s;
            }
            [dir="rtl"] .ai-close-btn { margin-left: 0; margin-right: auto; }
            .ai-close-btn:hover { color: white; transform: rotate(90deg); }

            .ai-chat-messages {
                flex: 1;
                padding: 20px;
                overflow-y: auto;
                display: flex;
                flex-direction: column;
                gap: 12px;
                background: #f8fafc;
            }
            .ai-msg {
                max-width: 85%;
                padding: 12px 16px;
                border-radius: 18px;
                font-size: 0.9rem;
                line-height: 1.5;
                animation: aiMsgIn 0.3s ease-out forwards;
            }
            @keyframes aiMsgIn {
                from { opacity: 0; transform: translateY(10px); }
                to { opacity: 1; transform: translateY(0); }
            }
            .ai-msg.user {
                align-self: flex-end;
                background: var(--primary);
                color: white;
                border-bottom-right-radius: 4px;
            }
            [dir="rtl"] .ai-msg.user {
                border-bottom-right-radius: 18px;
                border-bottom-left-radius: 4px;
            }
            .ai-msg.ai {
                align-self: flex-start;
                background: white;
                color: var(--text-dark);
                border: 1px solid var(--border);
                border-bottom-left-radius: 4px;
                box-shadow: var(--shadow-sm);
            }
            [dir="rtl"] .ai-msg.ai {
                border-bottom-left-radius: 18px;
                border-bottom-right-radius: 4px;
            }

            .ai-chat-input-area {
                padding: 15px;
                background: white;
                border-top: 1px solid var(--border);
                display: flex;
                gap: 10px;
            }
            #aiChatInput {
                flex: 1;
                padding: 12px 16px;
                border: 1px solid var(--border);
                border-radius: 20px;
                outline: none;
                transition: 0.2s;
            }
            #aiChatInput:focus {
                border-color: var(--primary);
            }
            .ai-send-btn {
                width: 45px;
                height: 45px;
                border-radius: 50%;
                background: var(--primary);
                color: white;
                border: none;
                cursor: pointer;
                display: flex;
                align-items: center;
                justify-content: center;
                transition: 0.2s;
            }
            .ai-send-btn:hover { background: var(--accent); }
            
            .ai-typing {
                display: flex;
                gap: 4px;
                padding: 16px !important;
            }
            .ai-dot {
                width: 6px;
                height: 6px;
                background: var(--text-muted);
                border-radius: 50%;
                animation: typingBounce 1.4s infinite ease-in-out both;
            }
            .ai-dot:nth-child(1) { animation-delay: -0.32s; }
            .ai-dot:nth-child(2) { animation-delay: -0.16s; }
            @keyframes typingBounce {
                0%, 80%, 100% { transform: scale(0); }
                40% { transform: scale(1); }
            }
            
            /* Responsive */
            @media (max-width: 480px) {
                .ai-chat-window {
                    width: calc(100vw - 40px);
                    right: -10px;
                    bottom: 70px;
                }
                [dir="rtl"] .ai-chat-window { right: auto; left: -10px; }
            }
        </style>
    `;

    document.body.insertAdjacentHTML('beforeend', widgetHTML);

    // 2. Logic & Interactions
    const toggleBtn = document.getElementById('aiToggleBtn');
    const closeBtn = document.getElementById('aiCloseBtn');
    const chatWindow = document.getElementById('aiChatWindow');
    const sendBtn = document.getElementById('aiSendBtn');
    const input = document.getElementById('aiChatInput');
    const messagesContainer = document.getElementById('aiChatMessages');

    function toggleChat() {
        chatWindow.classList.toggle('hidden');
        if (!chatWindow.classList.contains('hidden')) {
            input.focus();
        }
    }

    toggleBtn.addEventListener('click', toggleChat);
    closeBtn.addEventListener('click', toggleChat);

    async function sendMessage() {
        const text = input.value.trim();
        if (!text) return;

        // Add User Message
        appendMessage(text, 'user');
        input.value = '';

        // Add Typing Indicator
        const typingId = 'typing-' + Date.now();
        messagesContainer.insertAdjacentHTML('beforeend', `
            <div id="${typingId}" class="ai-msg ai ai-typing">
                <div class="ai-dot"></div>
                <div class="ai-dot"></div>
                <div class="ai-dot"></div>
            </div>
        `);
        scrollToBottom();

        // Call Groq API
        const responseText = await aiService.ask(text, 'main');

        // Remove Typing Indicator & Add AI Response
        const typingEl = document.getElementById(typingId);
        if (typingEl) typingEl.remove();
        appendMessage(responseText, 'ai');
    }

    function appendMessage(text, sender) {
        // use 'esc' to prevent XSS
        const safeText = sender === 'user' ? esc(text) : text; 
        
        messagesContainer.insertAdjacentHTML('beforeend', `
            <div class="ai-msg ${sender}">${safeText}</div>
        `);
        scrollToBottom();
    }

    function scrollToBottom() {
        messagesContainer.scrollTop = messagesContainer.scrollHeight;
    }

    sendBtn.addEventListener('click', sendMessage);
    input.addEventListener('keypress', (e) => {
        if (e.key === 'Enter') sendMessage();
    });
}
