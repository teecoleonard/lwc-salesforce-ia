import { LightningElement, track } from 'lwc';
import askAI from '@salesforce/apex/AIController.askAI';

export default class AiChat extends LightningElement {
  @track prompt = '';
  @track response = '';
  @track loading = false;

  handleChange(event) {
    this.prompt = event.target.value;
  }

  async send() {
    if(!this.prompt) {
      this.response = 'Preencha a pergunta.';
      return;
    }

    this.loading = true;
    this.response = '';

    try {
      const res = await askAI({ prompt: this.prompt });
      
      // res será o body JSON do backend; parse simples
      try {
        const parsed = JSON.parse(res);
        // O backend retorna a resposta do Hugging Face
        // Formato OpenAI-style: { choices: [{ message: { content: "..." } }] }
        if (parsed.choices && Array.isArray(parsed.choices) && parsed.choices.length > 0) {
          const choice = parsed.choices[0];
          if (choice.message && choice.message.content) {
            this.response = choice.message.content;
          } else if (choice.text) {
            this.response = choice.text;
          } else if (typeof choice === 'string') {
            this.response = choice;
          }
        } 
        // Formato Hugging Face Inference API
        else if (parsed.generated_text) {
          this.response = parsed.generated_text;
        } 
        // Outros formatos
        else if (parsed.answer) {
          this.response = parsed.answer;
        } else if (parsed.content) {
          this.response = parsed.content;
        } else if (typeof parsed === 'string') {
          this.response = parsed;
        } else {
          // Se não conseguir extrair, mostra o JSON formatado
          this.response = JSON.stringify(parsed, null, 2);
        }
      } catch(e) {
        // Se não for JSON, mostra a resposta como está
        this.response = res;
      }
    } catch(err) {
      this.response = 'Erro: ' + (err.body && err.body.message ? err.body.message : JSON.stringify(err));
    }

    this.loading = false;
  }

  clear() {
    this.prompt = '';
    this.response = '';
  }
}

