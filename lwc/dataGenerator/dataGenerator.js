import { LightningElement, track } from 'lwc';
import generateLeads from '@salesforce/apex/DataGeneratorController.generateLeads';
import generateAccounts from '@salesforce/apex/DataGeneratorController.generateAccounts';
import deleteTestData from '@salesforce/apex/DataGeneratorController.deleteTestData';
import { ShowToastEvent } from 'lightning/platformShowToastEvent';

export default class DataGenerator extends LightningElement {
    @track quantity = 10;
    @track selectedObject = 'Lead';
    @track isGenerating = false;
    @track isDeleting = false;
    @track resultMessage = '';
    @track showDeleteSection = false;
    @track deleteDaysOld = 7;
    @track deleteObjectType = 'Lead';

    get objectOptions() {
        return [
            { label: 'Lead', value: 'Lead' },
            { label: 'Account', value: 'Account' }
        ];
    }

    get deleteObjectOptions() {
        return [
            { label: 'Lead', value: 'Lead' },
            { label: 'Account', value: 'Account' }
        ];
    }

    handleQuantityChange(event) {
        this.quantity = parseInt(event.target.value, 10);
    }

    handleObjectChange(event) {
        this.selectedObject = event.detail.value;
    }

    handleDeleteObjectChange(event) {
        this.deleteObjectType = event.detail.value;
    }

    handleDeleteDaysChange(event) {
        this.deleteDaysOld = parseInt(event.target.value, 10);
    }

    async handleGenerate() {
        if (!this.quantity || this.quantity < 1 || this.quantity > 1000) {
            this.showToast('Erro', 'Quantidade deve ser entre 1 e 1000', 'error');
            return;
        }

        this.isGenerating = true;
        this.resultMessage = '';

        try {
            let result;
            if (this.selectedObject === 'Lead') {
                result = await generateLeads({ quantity: this.quantity });
            } else {
                result = await generateAccounts({ quantity: this.quantity });
            }

            this.resultMessage = result;
            this.showToast('Sucesso', `${this.selectedObject}s gerados com sucesso!`, 'success');
        } catch (error) {
            this.resultMessage = 'Erro: ' + error.body.message;
            this.showToast('Erro', error.body.message, 'error');
        } finally {
            this.isGenerating = false;
        }
    }

    async handleDelete() {
        if (!this.deleteDaysOld || this.deleteDaysOld < 0) {
            this.showToast('Erro', 'Número de dias deve ser maior ou igual a 0', 'error');
            return;
        }

        this.isDeleting = true;
        this.resultMessage = '';

        try {
            const result = await deleteTestData({ 
                objectType: this.deleteObjectType, 
                daysOld: this.deleteDaysOld 
            });

            this.resultMessage = result;
            this.showToast('Sucesso', 'Dados deletados com sucesso!', 'success');
        } catch (error) {
            this.resultMessage = 'Erro: ' + error.body.message;
            this.showToast('Erro', error.body.message, 'error');
        } finally {
            this.isDeleting = false;
        }
    }

    toggleDeleteSection() {
        this.showDeleteSection = !this.showDeleteSection;
    }

    showToast(title, message, variant) {
        const evt = new ShowToastEvent({
            title: title,
            message: message,
            variant: variant,
            mode: 'dismissable'
        });
        this.dispatchEvent(evt);
    }
}

