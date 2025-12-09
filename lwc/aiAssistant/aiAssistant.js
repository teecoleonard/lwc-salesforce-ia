import { LightningElement, track, api, wire } from 'lwc';
import { CurrentPageReference } from 'lightning/navigation';
import askAI from '@salesforce/apex/AIController.askAI';
import getRecordContext from '@salesforce/apex/AIController.getRecordContext';

export default class AiAssistant extends LightningElement {
    @api recordId;
    @api objectApiName;
    
    @wire(CurrentPageReference)
    pageRef;
    
    @track prompt = '';
    @track response = '';
    @track loading = false;
    @track error = '';
    @track recordContext = '';

    // Busca contexto do registro quando o componente é carregado
    connectedCallback() {
        // Log bem visível para debug
        console.warn('=== AI ASSISTANT CONECTADO ===');
        console.warn('recordId:', this.recordId);
        console.warn('objectApiName:', this.objectApiName);
        console.warn('pageRef:', this.pageRef);
        
        // Se não tem recordId/objectApiName, tenta obter da página atual
        if (!this.recordId || !this.objectApiName) {
            console.warn('Sem recordId/objectApiName, tentando obter da página...');
            this.getCurrentPageContext();
        } else {
            console.warn('Tem recordId/objectApiName, carregando contexto...');
            this.loadRecordContext();
        }
    }
    
    // Tenta obter o contexto da página atual (útil para Utility Bar e páginas customizadas)
    getCurrentPageContext() {
        console.warn('=== TENTANDO OBTER CONTEXTO DA PÁGINA ===');
        console.warn('pageRef completo:', JSON.stringify(this.pageRef, null, 2));
        
        // Tenta obter da URL atual
        const currentUrl = window.location.href;
        console.warn('URL atual:', currentUrl);
        
        // Extrai recordId da URL (formato: /lightning/r/001XXXXXXXXXXXXXXX/view)
        const urlMatch = currentUrl.match(/\/lightning\/r\/([a-zA-Z0-9]{15,18})/);
        if (urlMatch && urlMatch[1]) {
            this.recordId = urlMatch[1];
            console.warn('RecordId extraído da URL:', this.recordId);
            
            // Identifica o tipo de objeto pelo prefixo do ID
            const prefix = this.recordId.substring(0, 3);
            const prefixMap = {
                '001': 'Account',
                '003': 'Contact',
                '00Q': 'Lead',
                '006': 'Opportunity',
                '500': 'Case',
                'a00': 'Custom Object (a00)',
                'a01': 'Custom Object (a01)',
                'a02': 'Custom Object (a02)'
            };
            
            this.objectApiName = prefixMap[prefix] || null;
            console.warn('ObjectApiName identificado:', this.objectApiName);
            
            if (this.recordId && this.objectApiName) {
                this.loadRecordContext();
                return;
            }
        }
        
        // Tenta obter do pageRef.state
        if (this.pageRef && this.pageRef.state) {
            console.warn('pageRef.state:', this.pageRef.state);
            
            // Procura por recordId em diferentes formatos
            const possibleRecordId = this.pageRef.state.recordId || 
                                    this.pageRef.state.c__recordId ||
                                    this.pageRef.state.id;
            
            if (possibleRecordId) {
                this.recordId = possibleRecordId;
                this.objectApiName = this.pageRef.state.objectApiName || 
                                   this.pageRef.state.c__objectApiName ||
                                   this.pageRef.state.type;
                
                console.warn('Contexto obtido do pageRef.state:', this.recordId, this.objectApiName);
                this.loadRecordContext();
                return;
            }
        }
        
        // Tenta obter do pageRef.attributes
        if (this.pageRef && this.pageRef.attributes) {
            console.warn('pageRef.attributes:', this.pageRef.attributes);
            
            if (this.pageRef.attributes.recordId) {
                this.recordId = this.pageRef.attributes.recordId;
                this.objectApiName = this.pageRef.attributes.objectApiName;
                console.warn('Contexto obtido dos attributes:', this.recordId, this.objectApiName);
                this.loadRecordContext();
                return;
            }
        }
        
        console.warn('=== NÃO FOI POSSÍVEL OBTER CONTEXTO ===');
        console.warn('O componente funcionará, mas sem contexto do registro.');
        console.warn('Você pode fazer perguntas gerais ou informar o ID do registro manualmente.');
    }
    
    // Também tenta carregar quando recordId ou objectApiName mudam
    renderedCallback() {
        // Tenta obter contexto da página se ainda não tem
        if ((!this.recordId || !this.objectApiName) && this.pageRef) {
            this.getCurrentPageContext();
        }
        
        if (this.recordId && this.objectApiName && !this.recordContext) {
            this.loadRecordContext();
        }
    }

    loadRecordContext() {
        if (!this.recordId) {
            console.log('aiAssistant: Sem recordId');
            return;
        }
        
        // Se não tem objectApiName, tenta descobrir
        if (!this.objectApiName) {
            console.log('aiAssistant: Sem objectApiName, tentando descobrir...');
            // Pode tentar descobrir pelo recordId (primeiros 3 caracteres indicam o tipo)
            // Mas é melhor ter o objectApiName, então vamos tentar sem ele primeiro
        }
        
        console.log('aiAssistant: Carregando contexto para', this.objectApiName || 'desconhecido', this.recordId);
        
        // Se não tem objectApiName, tenta descobrir pelo recordId
        let objectName = this.objectApiName;
        if (!objectName && this.recordId) {
            // Tenta identificar pelo prefixo do ID
            const prefix = this.recordId.substring(0, 3);
            const prefixMap = {
                '001': 'Account',
                '003': 'Contact',
                '00Q': 'Lead',
                '006': 'Opportunity',
                '500': 'Case'
            };
            objectName = prefixMap[prefix];
            if (objectName) {
                this.objectApiName = objectName;
                console.log('aiAssistant: Tipo de objeto identificado pelo prefixo:', objectName);
            }
        }
        
        if (!objectName) {
            console.log('aiAssistant: Não foi possível identificar o tipo de objeto');
            return;
        }
        
        getRecordContext({ 
            recordId: this.recordId, 
            objectName: objectName 
        })
        .then(context => {
            console.log('aiAssistant: Contexto carregado:', context ? context.substring(0, 200) + '...' : 'vazio');
            if (context) {
                this.recordContext = context;
            }
        })
        .catch(error => {
            console.error('aiAssistant: Erro ao carregar contexto:', error);
            this.error = 'Erro ao carregar contexto: ' + (error.body?.message || error.message || 'Erro desconhecido');
        });
    }

    handleChange(event) {
        this.prompt = event.target.value;
        this.error = '';
    }

    handleQuickAction(event) {
        const action = event.detail.value;
        let quickPrompt = '';

        switch(action) {
            case 'summarize':
                quickPrompt = `Resuma as informações principais deste registro ${this.objectApiName} ${this.recordId ? 'com ID ' + this.recordId : ''}.`;
                break;
            case 'nextSteps':
                quickPrompt = `Quais são os próximos passos recomendados para este registro ${this.objectApiName}?`;
                break;
            case 'relatedRecords':
                quickPrompt = `Liste os registros relacionados a este ${this.objectApiName} e explique a relação.`;
                break;
            case 'suggestions':
                quickPrompt = `Dê sugestões de melhorias ou ações para este registro ${this.objectApiName}.`;
                break;
            default:
                quickPrompt = this.prompt;
        }

        this.prompt = quickPrompt;
        this.send();
    }

    async send() {
        console.warn('=== AI ASSISTANT: ENVIANDO PERGUNTA ===');
        console.warn('Prompt:', this.prompt);
        
        if (!this.prompt || this.prompt.trim().length === 0) {
            this.error = 'Por favor, preencha uma pergunta.';
            return;
        }

        this.loading = true;
        this.response = '';
        this.error = '';

        try {
            console.warn('aiAssistant: Enviando pergunta. recordId:', this.recordId, 'objectApiName:', this.objectApiName);
            
            // Adiciona contexto do registro se disponível
            let fullPrompt = this.prompt;
            if (this.recordId && this.objectApiName) {
                // Se ainda não carregou o contexto, tenta carregar agora
                if (!this.recordContext) {
                    console.log('aiAssistant: Contexto não carregado, tentando carregar agora...');
                    await this.loadRecordContext();
                }
                
                // Se temos contexto do registro, inclui no prompt
                if (this.recordContext) {
                    fullPrompt = `Contexto do registro Salesforce:\n${this.recordContext}\n\nPergunta: ${this.prompt}\n\nPor favor, responda considerando as informações do registro acima.`;
                    console.log('aiAssistant: Prompt com contexto (primeiros 500 chars):', fullPrompt.substring(0, 500));
                } else {
                    fullPrompt = `Contexto: Estou trabalhando com um registro do tipo ${this.objectApiName} (ID: ${this.recordId}). ${this.prompt}`;
                    console.log('aiAssistant: Prompt sem contexto detalhado');
                }
            } else {
                console.log('aiAssistant: Sem recordId ou objectApiName, enviando prompt simples');
            }

            console.warn('aiAssistant: Chamando askAI...');
            console.warn('Full prompt (primeiros 500 chars):', fullPrompt.substring(0, 500));
            
            const res = await askAI({ prompt: fullPrompt });
            console.warn('=== RESPOSTA RECEBIDA ===');
            console.warn('Resposta (primeiros 500 chars):', res ? res.substring(0, 500) : 'vazia');
            console.warn('Tipo da resposta:', typeof res);
            
            // Parse da resposta
            try {
                const parsed = JSON.parse(res);
                
                if (parsed.choices && Array.isArray(parsed.choices) && parsed.choices.length > 0) {
                    const choice = parsed.choices[0];
                    if (choice.message && choice.message.content) {
                        this.response = choice.message.content;
                    } else if (choice.text) {
                        this.response = choice.text;
                    }
                } else if (parsed.generated_text) {
                    this.response = parsed.generated_text;
                } else if (parsed.answer) {
                    this.response = parsed.answer;
                } else if (parsed.content) {
                    this.response = parsed.content;
                } else if (typeof parsed === 'string') {
                    this.response = parsed;
                } else {
                    this.response = JSON.stringify(parsed, null, 2);
                }
            } catch(e) {
                this.response = res;
            }
        } catch(err) {
            console.error('=== ERRO NO AI ASSISTANT ===');
            console.error('Erro completo:', err);
            console.error('Erro body:', err.body);
            console.error('Erro message:', err.message);
            console.error('Erro stack:', err.stack);
            
            let errorMessage = 'Erro ao processar requisição.';
            if (err.body) {
                if (err.body.message) {
                    errorMessage = err.body.message;
                } else if (typeof err.body === 'string') {
                    errorMessage = err.body;
                } else {
                    errorMessage = JSON.stringify(err.body);
                }
            } else if (err.message) {
                errorMessage = err.message;
            }
            
            this.error = errorMessage;
        } finally {
            this.loading = false;
        }
    }

    clear() {
        this.prompt = '';
        this.response = '';
        this.error = '';
    }
}

