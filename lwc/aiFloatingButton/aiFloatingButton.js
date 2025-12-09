import { LightningElement, track, api, wire } from 'lwc';
import { CurrentPageReference } from 'lightning/navigation';
import USER_ID from '@salesforce/user/Id';
import USER_NAME from '@salesforce/schema/User.Name';
import USER_SMALL_PHOTO_URL from '@salesforce/schema/User.SmallPhotoUrl';
import USER_MEDIUM_PHOTO_URL from '@salesforce/schema/User.MediumPhotoUrl';
import { getRecord } from 'lightning/uiRecordApi';
import askAI from '@salesforce/apex/AIController.askAI';
import getRecordContext from '@salesforce/apex/AIController.getRecordContext';

// ============================================
// CONSTANTES
// ============================================
const FIELDS = [USER_NAME, USER_SMALL_PHOTO_URL, USER_MEDIUM_PHOTO_URL];
const PREFIX_MAP = {
    '001': 'Account',
    '003': 'Contact',
    '00Q': 'Lead',
    '006': 'Opportunity',
    '500': 'Case',
    'a00': 'Custom Object (a00)',
    'a01': 'Custom Object (a01)',
    'a02': 'Custom Object (a02)'
};
const MAX_CHAT_HISTORY = 50;
const STORAGE_KEY = 'aiChatHistory';

// ============================================
// CLASSE PRINCIPAL
// ============================================
export default class AiFloatingButton extends LightningElement {
    // ============================================
    // PROPRIEDADES PÚBLICAS (API)
    // ============================================
    @api recordId;
    @api objectApiName;
    
    // ============================================
    // WIRES E DEPENDÊNCIAS
    // ============================================
    @wire(CurrentPageReference)
    pageRef;
    
    userId = USER_ID;
    @wire(getRecord, { recordId: '$userId', fields: FIELDS })
    user;
    
    // ============================================
    // PROPRIEDADES DE ESTADO
    // ============================================
    @track prompt = '';
    @track response = '';
    @track loading = false;
    @track error = '';
    @track recordContext = '';
    @track isOpen = false;
    @track iconName = 'utility:bot';
    @track manualRecordId = '';
    @track showManualInput = false;
    @track chatHistory = [];
    @track currentChatId = null;
    @track messages = [];
    @track showHistoryModal = false;
    
    // ============================================
    // COMPUTED PROPERTIES
    // ============================================
    get userName() {
        return this.user?.data?.fields?.Name?.value || 'Usuário Salesforce';
    }
    
    get hasUserData() {
        return this.user && this.user.data && this.user.data.fields && this.user.data.fields.Name;
    }
    
    get userPhotoUrl() {
        // Retorna a foto média, ou pequena, ou null
        if (this.user?.data?.fields?.MediumPhotoUrl?.value) {
            return this.user.data.fields.MediumPhotoUrl.value;
        }
        if (this.user?.data?.fields?.SmallPhotoUrl?.value) {
            return this.user.data.fields.SmallPhotoUrl.value;
        }
        return null;
    }
    
    get userIdForAvatar() {
        // Retorna o ID do usuário para usar no lightning-avatar
        return this.userId;
    }
    

    // ============================================
    // LIFECYCLE HOOKS
    // ============================================
    connectedCallback() {
        console.warn('=== AI FLOATING BUTTON: CONECTADO ===');
        console.warn('recordId:', this.recordId);
        console.warn('objectApiName:', this.objectApiName);
        console.warn('pageRef:', this.pageRef);
        console.warn('userId:', this.userId);
        
        this.loadChatHistory();
        
        if (!this.recordId || !this.objectApiName) {
            console.warn('Sem recordId/objectApiName, tentando obter da página...');
            this.getCurrentPageContext();
        } else {
            console.warn('Tem recordId/objectApiName, carregando contexto...');
            this.loadRecordContext();
        }
    }
    
    renderedCallback() {
        if ((!this.recordId || !this.objectApiName) && this.pageRef) {
            this.getCurrentPageContext();
        }
        
        if (this.recordId && this.objectApiName && !this.recordContext) {
            this.loadRecordContext();
        }
    }

    // ============================================
    // MÉTODOS DE CONTEXTO E REGISTRO
    // ============================================
    getCurrentPageContext() {
        console.warn('=== TENTANDO OBTER CONTEXTO DA PÁGINA ===');
        console.warn('pageRef completo:', JSON.stringify(this.pageRef, null, 2));
        
        const currentUrl = window.location.href;
        console.warn('URL atual:', currentUrl);
        
        // Tenta extrair da URL (formato: /lightning/r/001XXXXXXXXXXXXXXX/view)
        const urlMatch = currentUrl.match(/\/lightning\/r\/([a-zA-Z0-9]{15,18})/);
        if (urlMatch && urlMatch[1]) {
            this.recordId = urlMatch[1];
            this.objectApiName = this.identifyObjectType(this.recordId);
            
            if (this.recordId && this.objectApiName) {
                console.warn('Contexto obtido da URL:', this.recordId, this.objectApiName);
                this.loadRecordContext();
                return;
            }
        }
        
        // Tenta extrair de parâmetros de query string
        const urlParams = new URLSearchParams(window.location.search);
        const recordIdParam = urlParams.get('recordId') || urlParams.get('id');
        if (recordIdParam && recordIdParam.length >= 15) {
            this.recordId = recordIdParam;
            this.objectApiName = this.identifyObjectType(this.recordId);
            
            if (this.recordId && this.objectApiName) {
                console.warn('Contexto obtido dos parâmetros:', this.recordId, this.objectApiName);
                this.loadRecordContext();
                return;
            }
        }
        
        // Tenta obter do pageRef.state
        if (this.pageRef && this.pageRef.state) {
            const possibleRecordId = this.pageRef.state.recordId || 
                                    this.pageRef.state.c__recordId ||
                                    this.pageRef.state.id;
            
            if (possibleRecordId) {
                this.recordId = possibleRecordId;
                this.objectApiName = this.pageRef.state.objectApiName || 
                                   this.pageRef.state.c__objectApiName ||
                                   this.pageRef.state.type ||
                                   this.identifyObjectType(this.recordId);
                
                if (this.recordId && this.objectApiName) {
                    console.warn('Contexto obtido do pageRef.state:', this.recordId, this.objectApiName);
                    this.loadRecordContext();
                    return;
                }
            }
        }
        
        // Tenta obter do pageRef.attributes
        if (this.pageRef && this.pageRef.attributes) {
            if (this.pageRef.attributes.recordId) {
                this.recordId = this.pageRef.attributes.recordId;
                this.objectApiName = this.pageRef.attributes.objectApiName || 
                                   this.identifyObjectType(this.recordId);
                
                if (this.recordId && this.objectApiName) {
                    console.warn('Contexto obtido dos attributes:', this.recordId, this.objectApiName);
                    this.loadRecordContext();
                    return;
                }
            }
        }
        
        console.warn('=== NÃO FOI POSSÍVEL OBTER CONTEXTO ===');
        this.showManualInput = true;
    }
    
    identifyObjectType(recordId) {
        if (!recordId || recordId.length < 3) return null;
        const prefix = recordId.substring(0, 3);
        return PREFIX_MAP[prefix] || null;
    }
    
    loadRecordContext() {
        if (!this.recordId) {
            console.warn('aiFloatingButton: Sem recordId');
            return;
        }
        
        let objectName = this.objectApiName;
        if (!objectName && this.recordId) {
            objectName = this.identifyObjectType(this.recordId);
            if (objectName) {
                this.objectApiName = objectName;
            }
        }
        
        if (!objectName) {
            console.warn('aiFloatingButton: Não foi possível identificar o tipo de objeto');
            return;
        }
        
        console.warn('=== AI FLOATING BUTTON: CARREGANDO CONTEXTO ===');
        console.warn('recordId:', this.recordId);
        console.warn('objectApiName:', objectName);
        
        getRecordContext({ 
            recordId: this.recordId, 
            objectName: objectName 
        })
        .then(context => {
            console.warn('=== AI FLOATING BUTTON: CONTEXTO CARREGADO ===');
            console.warn('Tamanho do contexto:', context ? context.length : 0);
            if (context) {
                this.recordContext = context;
            }
        })
        .catch(error => {
            console.error('=== AI FLOATING BUTTON: ERRO AO CARREGAR CONTEXTO ===');
            console.error('Erro completo:', error);
            console.error('Erro body:', error.body);
        });
    }
    
    handleManualRecordIdChange(event) {
        this.manualRecordId = event.target.value;
        if (this.manualRecordId && this.manualRecordId.length >= 15) {
            this.recordId = this.manualRecordId;
            this.objectApiName = this.identifyObjectType(this.recordId);
            
            console.warn('=== RECORD ID INFORMADO MANUALMENTE ===');
            console.warn('recordId:', this.recordId);
            console.warn('objectApiName:', this.objectApiName);
            
            if (this.objectApiName) {
                this.loadRecordContext();
            }
        }
    }

    // ============================================
    // MÉTODOS DE CHAT E HISTÓRICO
    // ============================================
    loadChatHistory() {
        try {
            const stored = localStorage.getItem(STORAGE_KEY);
            if (stored) {
                this.chatHistory = JSON.parse(stored);
                console.warn('Histórico carregado:', this.chatHistory.length, 'conversas');
            }
        } catch (e) {
            console.error('Erro ao carregar histórico:', e);
            this.chatHistory = [];
        }
    }
    
    saveChatHistory() {
        try {
            localStorage.setItem(STORAGE_KEY, JSON.stringify(this.chatHistory));
        } catch (e) {
            console.error('Erro ao salvar histórico:', e);
        }
    }
    
    newChat() {
        this.prompt = '';
        this.response = '';
        this.error = '';
        this.currentChatId = null;
        this.messages = [];
        console.warn('Novo chat iniciado');
    }
    
    loadChatFromHistory(event) {
        const chatId = event.currentTarget.dataset.chatId;
        const chat = this.chatHistory.find(c => c.id === chatId);
        
        if (chat && chat.messages && chat.messages.length > 0) {
            this.currentChatId = chatId;
            this.messages = chat.messages.map(msg => ({
                ...msg,
                isUser: msg.role === 'user' || msg.isUser === true
            }));
            this.prompt = '';
            this.response = '';
            
            if (chat.recordId) {
                this.recordId = chat.recordId;
                this.objectApiName = chat.objectApiName;
                this.loadRecordContext();
            }
            
            this.showHistoryModal = false;
            this.scrollToBottom();
        }
    }
    
    updateChatHistory(userPrompt, responseText) {
        if (!this.currentChatId) {
            this.currentChatId = Date.now().toString();
        }
        
        const existingIndex = this.chatHistory.findIndex(c => c.id === this.currentChatId);
        const chatEntry = {
            id: this.currentChatId,
            title: userPrompt.substring(0, 50) + (userPrompt.length > 50 ? '...' : ''),
            timestamp: new Date().toISOString(),
            messages: this.messages,
            recordId: this.recordId,
            objectApiName: this.objectApiName
        };
        
        if (existingIndex >= 0) {
            this.chatHistory[existingIndex] = chatEntry;
        } else {
            this.chatHistory.unshift(chatEntry);
        }
        
        if (this.chatHistory.length > MAX_CHAT_HISTORY) {
            this.chatHistory = this.chatHistory.slice(0, MAX_CHAT_HISTORY);
        }
        
        this.saveChatHistory();
    }

    // ============================================
    // MÉTODOS DE UI E INTERAÇÃO
    // ============================================
    togglePanel() {
        this.isOpen = !this.isOpen;
        this.iconName = 'utility:bot';
        
        if (this.isOpen && this.recordId && this.objectApiName && !this.recordContext) {
            this.loadRecordContext();
        }
    }
    
    toggleHistoryModal() {
        this.showHistoryModal = !this.showHistoryModal;
    }
    
    stopPropagation(event) {
        event.stopPropagation();
    }
    
    handleChange(event) {
        this.prompt = event.target.value || event.detail.value || '';
        this.error = '';
    }
    
    handleSendClick() {
        console.warn('=== AI FLOATING BUTTON: BOTÃO ENVIAR CLICADO ===');
        this.send();
    }
    
    handleQuickAction(event) {
        console.warn('=== AI FLOATING BUTTON: AÇÃO RÁPIDA SELECIONADA ===');
        
        let action = null;
        if (event.detail && event.detail.value) {
            action = event.detail.value;
        } else if (event.currentTarget && event.currentTarget.value) {
            action = event.currentTarget.value;
        } else if (event.target && event.target.value) {
            action = event.target.value;
        } else if (event.detail) {
            action = event.detail;
        }
        
        if (!action) {
            console.error('Não foi possível identificar a ação selecionada');
            return;
        }
        
        const quickPrompts = {
            'summarize': `Resuma as informações principais deste registro ${this.objectApiName || ''} ${this.recordId ? 'com ID ' + this.recordId : ''}.`,
            'nextSteps': `Quais são os próximos passos recomendados para este registro ${this.objectApiName || ''}?`,
            'relatedRecords': `Liste os registros relacionados a este ${this.objectApiName || 'registro'} e explique a relação.`,
            'suggestions': `Dê sugestões de melhorias ou ações para este registro ${this.objectApiName || ''}.`
        };
        
        const quickPrompt = quickPrompts[String(action)] || this.prompt || 'Por favor, descreva o que você precisa.';
        
        console.warn('Prompt gerado:', quickPrompt);
        this.prompt = quickPrompt;
        
        requestAnimationFrame(() => {
            this.send(quickPrompt);
        });
    }
    
    scrollToBottom() {
        requestAnimationFrame(() => {
            const messagesContainer = this.template.querySelector('.messages-section');
            if (messagesContainer) {
                messagesContainer.scrollTop = messagesContainer.scrollHeight;
            }
        });
    }

    // ============================================
    // MÉTODOS DE COMUNICAÇÃO COM API
    // ============================================
    async send(customPrompt = null) {
        const promptToUse = customPrompt !== null ? customPrompt : this.prompt;
        
        console.warn('=== AI FLOATING BUTTON: MÉTODO SEND CHAMADO ===');
        console.warn('promptToUse:', promptToUse);
        
        if (!promptToUse || String(promptToUse).trim().length === 0) {
            this.error = 'Por favor, preencha uma pergunta.';
            console.warn('ERRO: Prompt vazio!');
            return;
        }

        this.loading = true;
        const userPrompt = promptToUse;
        this.response = '';
        this.error = '';
        
        if (customPrompt) {
            this.prompt = customPrompt;
        }

        try {
            console.warn('=== AI FLOATING BUTTON: ENVIANDO PERGUNTA ===');
            console.warn('recordId:', this.recordId);
            console.warn('objectApiName:', this.objectApiName);
            console.warn('initialPrompt:', userPrompt);
            
            const userName = this.userName;
            console.warn('Usuário:', userName);
            
            // Constrói o prompt completo com contexto
            let fullPrompt = this.buildFullPrompt(userName, userPrompt);
            console.warn('Prompt completo (primeiros 500 chars):', fullPrompt.substring(0, 500));

            // Chama a API
            console.warn('aiFloatingButton: Chamando askAI...');
            const res = await askAI({ prompt: fullPrompt });
            console.warn('=== AI FLOATING BUTTON: RESPOSTA RECEBIDA (primeiros 200 chars) ===', res ? res.substring(0, 200) : 'vazia');
            
            // Parse da resposta
            const responseText = this.parseAIResponse(res);
            this.response = responseText;
            
            // Adiciona mensagens ao chat
            this.addMessageToChat('user', userPrompt);
            this.addMessageToChat('assistant', responseText);
            
            // Scroll e atualiza histórico
            this.scrollToBottom();
            this.updateChatHistory(userPrompt, responseText);
            
            // Limpa o prompt após enviar
            this.prompt = '';
            
        } catch(err) {
            console.error('=== ERRO NO AI FLOATING BUTTON ===');
            console.error('Erro completo:', err);
            console.error('Erro body:', err.body);
            
            const errorMessage = this.extractErrorMessage(err);
            this.error = errorMessage;
            this.addMessageToChat('error', errorMessage);
            this.scrollToBottom();
        } finally {
            this.loading = false;
        }
    }
    
    buildFullPrompt(userName, userPrompt) {
        let fullPrompt = `Você está conversando com ${userName}, um usuário do Salesforce.\n\n`;
        
        if (this.recordId && this.objectApiName) {
            if (!this.recordContext) {
                console.warn('aiFloatingButton: Contexto não carregado, tentando carregar agora...');
                // Nota: loadRecordContext é assíncrono, mas não podemos usar await aqui facilmente
                // O contexto será carregado na próxima interação
            }
            
            if (this.recordContext) {
                fullPrompt += `Contexto do registro Salesforce:\n${this.recordContext}\n\n`;
            } else {
                fullPrompt += `Contexto: ${userName} está trabalhando com um registro do tipo ${this.objectApiName} (ID: ${this.recordId}).\n\n`;
            }
        }
        
        fullPrompt += `Pergunta de ${userName}: ${userPrompt}\n\nPor favor, responda considerando as informações acima e seja útil e profissional.`;
        
        return fullPrompt;
    }
    
    parseAIResponse(res) {
        try {
            const parsed = JSON.parse(res);
            
            if (parsed.choices && Array.isArray(parsed.choices) && parsed.choices.length > 0) {
                const choice = parsed.choices[0];
                if (choice.message && choice.message.content) {
                    return choice.message.content;
                } else if (choice.text) {
                    return choice.text;
                }
            } else if (parsed.generated_text) {
                return parsed.generated_text;
            } else if (parsed.answer) {
                return parsed.answer;
            } else if (parsed.content) {
                return parsed.content;
            } else if (typeof parsed === 'string') {
                return parsed;
            } else {
                return JSON.stringify(parsed, null, 2);
            }
        } catch(e) {
            return res;
        }
    }
    
    addMessageToChat(role, content) {
        const message = {
            id: Date.now().toString() + '-' + role,
            role: role,
            isUser: role === 'user',
            content: content,
            timestamp: new Date().toISOString()
        };
        
        this.messages.push(message);
    }
    
    extractErrorMessage(err) {
        if (err.body) {
            if (err.body.message) {
                return err.body.message;
            } else if (typeof err.body === 'string') {
                return err.body;
            } else {
                return JSON.stringify(err.body);
            }
        } else if (err.message) {
            return err.message;
        } else {
            return 'Erro ao processar requisição. Verifique a conexão.';
        }
    }
}
