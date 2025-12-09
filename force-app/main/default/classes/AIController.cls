public with sharing class AIController {
    
    @AuraEnabled
    public static String askAI(String prompt) {
        if(String.isBlank(prompt)) {
            throw new AuraHandledException('Prompt vazio');
        }
        
        Http http = new Http();
        HttpRequest req = new HttpRequest();
        
        req.setEndpoint('callout:LLM_CONNECTOR/chat');
        req.setMethod('POST');
        req.setHeader('Content-Type', 'application/json');
        req.setTimeout(30000);
        
        Map<String, Object> body = new Map<String, Object>{
            'prompt' => prompt,
            'max_tokens' => 250
        };
        
        req.setBody(JSON.serialize(body));
        
        try {
            HttpResponse res = http.send(req);
            Integer status = res.getStatusCode();
            
            if(status >= 200 && status < 300) {
                return res.getBody();
            } else {
                throw new AuraHandledException('Erro no connector: ' + status + ' - ' + res.getBody());
            }
        } catch(Exception ex) {
            throw new AuraHandledException('Callout falhou: ' + ex.getMessage());
        }
    }
    
    @AuraEnabled
    public static String getRecordContext(String recordId, String objectName) {
        if(String.isBlank(recordId) || String.isBlank(objectName)) {
            return '';
        }
        
        try {
            // Busca todos os campos do registro usando describe
            Schema.SObjectType objType = Schema.getGlobalDescribe().get(objectName);
            if(objType == null) {
                return objectName + ' (ID: ' + recordId + ') - Objeto não encontrado';
            }
            
            Schema.DescribeSObjectResult objDescribe = objType.getDescribe();
            Map<String, Schema.SObjectField> fieldMap = objDescribe.fields.getMap();
            
            // Constrói query dinâmica com todos os campos acessíveis
            Set<String> fieldNamesSet = new Set<String>(); // Usa Set para evitar duplicatas
            List<String> fieldNames = new List<String>();
            
            // Adiciona Id primeiro (sempre necessário)
            fieldNamesSet.add('Id');
            fieldNames.add('Id');
            
            // Adiciona campos padrão importantes
            if(fieldMap.containsKey('Name') && !fieldNamesSet.contains('Name')) {
                fieldNamesSet.add('Name');
                fieldNames.add('Name');
            }
            
            // Adiciona campos relacionados comuns
            Set<String> relationshipFields = new Set<String>();
            if(objectName == 'Contact' || objectName == 'Case' || objectName == 'Opportunity') {
                if(fieldMap.containsKey('AccountId')) {
                    relationshipFields.add('Account');
                }
            }
            if(objectName == 'Case') {
                if(fieldMap.containsKey('ContactId')) {
                    relationshipFields.add('Contact');
                }
            }
            
            // Adiciona todos os campos acessíveis (limitado a 80 para evitar erro)
            Integer fieldCount = 0;
            for(String fieldName : fieldMap.keySet()) {
                // Pula Id e Name que já foram adicionados
                if(fieldName == 'Id' || fieldName == 'Name') {
                    continue;
                }
                
                Schema.SObjectField field = fieldMap.get(fieldName);
                Schema.DescribeFieldResult fieldDescribe = field.getDescribe();
                
                // Ignora campos que não podem ser consultados ou são muito grandes
                if(fieldDescribe.isAccessible() && 
                   !fieldDescribe.isCalculated() &&
                   fieldDescribe.getType() != Schema.DisplayType.BASE64 &&
                   fieldDescribe.getType() != Schema.DisplayType.ADDRESS &&
                   fieldDescribe.getType() != Schema.DisplayType.LOCATION) {
                    
                    if(!fieldNamesSet.contains(fieldName) && fieldCount < 80) {
                        fieldNamesSet.add(fieldName);
                        fieldNames.add(fieldName);
                        fieldCount++;
                    }
                }
            }
            
            // Adiciona relacionamentos
            for(String relField : relationshipFields) {
                if(fieldMap.containsKey(relField + 'Id')) {
                    String relName = relField + '.Name';
                    String relId = relField + '.Id';
                    if(!fieldNamesSet.contains(relName)) {
                        fieldNamesSet.add(relName);
                        fieldNames.add(relName);
                    }
                    if(!fieldNamesSet.contains(relId)) {
                        fieldNamesSet.add(relId);
                        fieldNames.add(relId);
                    }
                }
            }
            
            // Constrói e executa query
            String query = 'SELECT ' + String.join(fieldNames, ', ') + 
                         ' FROM ' + objectName + 
                         ' WHERE Id = :recordId LIMIT 1';
            
            List<SObject> records = Database.query(query);
            
            if(records.isEmpty()) {
                return objectName + ' (ID: ' + recordId + ') - Registro não encontrado';
            }
            
            SObject record = records[0];
            String context = '=== REGISTRO SALESFORCE ===\n';
            context += 'Tipo: ' + objDescribe.getLabel() + ' (' + objectName + ')\n';
            context += 'ID: ' + recordId + '\n\n';
            context += '=== CAMPOS DO REGISTRO ===\n';
            
            // Formata todos os campos preenchidos
            for(String fieldName : fieldNames) {
                try {
                    Object fieldValue = null;
                    
                    // Trata campos de relacionamento
                    if(fieldName.contains('.')) {
                        String[] parts = fieldName.split('\\.');
                        SObject relatedObj = record.getSObject(parts[0]);
                        if(relatedObj != null) {
                            fieldValue = relatedObj.get(parts[1]);
                        }
                    } else {
                        fieldValue = record.get(fieldName);
                    }
                    
                    if(fieldValue != null) {
                        Schema.SObjectField field = fieldMap.get(fieldName.split('\\.')[0]);
                        if(field != null) {
                            String label = field.getDescribe().getLabel();
                            context += label + ' (' + fieldName + '): ' + String.valueOf(fieldValue) + '\n';
                        } else {
                            context += fieldName + ': ' + String.valueOf(fieldValue) + '\n';
                        }
                    }
                } catch(Exception e) {
                    // Ignora campos que não podem ser acessados
                }
            }
            
            // Busca registros relacionados
            context += '\n=== REGISTROS RELACIONADOS ===\n';
            
            if(objectName == 'Account') {
                // Contacts relacionados
                List<Contact> contacts = [SELECT Id, Name, Email, Phone, Title 
                                         FROM Contact 
                                         WHERE AccountId = :recordId 
                                         LIMIT 5];
                if(!contacts.isEmpty()) {
                    context += '\nContatos (' + contacts.size() + '):\n';
                    for(Contact c : contacts) {
                        context += '- ' + c.Name;
                        if(c.Email != null) context += ' (' + c.Email + ')';
                        if(c.Title != null) context += ' - ' + c.Title;
                        context += '\n';
                    }
                }
                
                // Opportunities relacionadas
                List<Opportunity> opps = [SELECT Id, Name, Amount, StageName, CloseDate 
                                         FROM Opportunity 
                                         WHERE AccountId = :recordId 
                                         LIMIT 5];
                if(!opps.isEmpty()) {
                    context += '\nOportunidades (' + opps.size() + '):\n';
                    for(Opportunity o : opps) {
                        context += '- ' + o.Name;
                        if(o.Amount != null) context += ' - R$ ' + o.Amount;
                        if(o.StageName != null) context += ' (' + o.StageName + ')';
                        context += '\n';
                    }
                }
                
                // Cases relacionados
                List<Case> cases = [SELECT Id, Subject, Status, Priority 
                                   FROM Case 
                                   WHERE AccountId = :recordId 
                                   LIMIT 5];
                if(!cases.isEmpty()) {
                    context += '\nCasos (' + cases.size() + '):\n';
                    for(Case c : cases) {
                        context += '- ' + (c.Subject != null ? c.Subject : 'Sem assunto');
                        if(c.Status != null) context += ' [' + c.Status + ']';
                        context += '\n';
                    }
                }
            } else if(objectName == 'Opportunity') {
                // Products relacionados (OpportunityLineItems)
                List<OpportunityLineItem> items = [SELECT Id, Product2.Name, Quantity, UnitPrice, TotalPrice 
                                                   FROM OpportunityLineItem 
                                                   WHERE OpportunityId = :recordId 
                                                   LIMIT 10];
                if(!items.isEmpty()) {
                    context += '\nProdutos (' + items.size() + '):\n';
                    for(OpportunityLineItem item : items) {
                        context += '- ' + item.Product2.Name;
                        if(item.Quantity != null) context += ' (Qtd: ' + item.Quantity + ')';
                        if(item.TotalPrice != null) context += ' - R$ ' + item.TotalPrice;
                        context += '\n';
                    }
                }
            } else if(objectName == 'Case') {
                // Tasks relacionadas
                List<Task> tasks = [SELECT Id, Subject, Status, Priority, ActivityDate 
                                    FROM Task 
                                    WHERE WhatId = :recordId 
                                    LIMIT 5];
                if(!tasks.isEmpty()) {
                    context += '\nTarefas (' + tasks.size() + '):\n';
                    for(Task t : tasks) {
                        context += '- ' + (t.Subject != null ? t.Subject : 'Sem assunto');
                        if(t.Status != null) context += ' [' + t.Status + ']';
                        context += '\n';
                    }
                }
            }
            
            return context;
        } catch(Exception ex) {
            System.debug('Erro ao buscar contexto: ' + ex.getMessage());
            System.debug('Stack trace: ' + ex.getStackTraceString());
            return objectName + ' (ID: ' + recordId + ') - Erro: ' + ex.getMessage();
        }
    }
}

