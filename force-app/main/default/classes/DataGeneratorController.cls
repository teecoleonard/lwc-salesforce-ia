public with sharing class DataGeneratorController {
    
    // Arrays de dados para geração realista
    private static final List<String> FIRST_NAMES = new List<String>{
        'João', 'Maria', 'Pedro', 'Ana', 'Carlos', 'Fernanda', 'Ricardo', 'Juliana',
        'Paulo', 'Camila', 'Lucas', 'Mariana', 'Rafael', 'Beatriz', 'Bruno', 'Gabriela',
        'Felipe', 'Larissa', 'Thiago', 'Isabela', 'André', 'Patrícia', 'Marcos', 'Renata',
        'Daniel', 'Vanessa', 'Rodrigo', 'Amanda', 'Eduardo', 'Carolina', 'Gustavo', 'Tatiana'
    };
    
    private static final List<String> LAST_NAMES = new List<String>{
        'Silva', 'Santos', 'Oliveira', 'Souza', 'Rodrigues', 'Ferreira', 'Alves', 'Pereira',
        'Lima', 'Costa', 'Ribeiro', 'Martins', 'Carvalho', 'Almeida', 'Lopes', 'Soares',
        'Fernandes', 'Vieira', 'Barbosa', 'Rocha', 'Dias', 'Monteiro', 'Cardoso', 'Mendes',
        'Araújo', 'Nunes', 'Moreira', 'Freitas', 'Gomes', 'Moraes', 'Cavalcanti', 'Ramos'
    };
    
    private static final List<String> COMPANIES = new List<String>{
        'Tech Solutions', 'Inovação Digital', 'Sistemas Avançados', 'Consultoria Empresarial',
        'Global Services', 'Mega Corp', 'Smart Business', 'Future Tech', 'Prime Solutions',
        'Elite Consulting', 'Advanced Systems', 'Digital Innovations', 'Business Partners',
        'Strategic Solutions', 'Enterprise Group', 'Modern Solutions', 'Proactive Services',
        'Innovation Labs', 'Tech Partners', 'Digital Solutions', 'Business Intelligence',
        'Cloud Services', 'Data Analytics', 'Software Solutions', 'IT Consulting'
    };
    
    private static final List<String> INDUSTRIES = new List<String>{
        'Tecnologia', 'Consultoria', 'Varejo', 'Manufatura', 'Saúde', 'Educação',
        'Financeiro', 'Energia', 'Telecomunicações', 'Transporte', 'Construção',
        'Alimentação', 'Automotivo', 'Farmacêutico', 'Imobiliário'
    };
    
    private static final List<String> LEAD_SOURCES = new List<String>{
        'Web', 'Telefone', 'Email', 'Parceiro', 'Evento', 'Referência', 'Publicidade',
        'LinkedIn', 'Facebook', 'Twitter', 'Outro'
    };
    
    private static final List<String> LEAD_STATUSES = new List<String>{
        'Aberto - Não Contactado', 'Trabalhando - Contactado', 'Qualificado - Interessado',
        'Qualificado - Não Interessado', 'Convertido', 'Desqualificado'
    };
    
    private static final List<String> ACCOUNT_TYPES = new List<String>{
        'Cliente', 'Prospecto', 'Parceiro', 'Concorrente', 'Outro'
    };
    
    private static final List<String> TITLES = new List<String>{
        'CEO', 'Diretor', 'Gerente', 'Coordenador', 'Analista', 'Especialista',
        'Consultor', 'Supervisor', 'Assistente', 'Vice-Presidente', 'Presidente'
    };
    
    @AuraEnabled
    public static String generateLeads(Integer quantity) {
        if(quantity == null || quantity <= 0 || quantity > 1000) {
            throw new AuraHandledException('Quantidade deve ser entre 1 e 1000');
        }
        
        List<Lead> leads = new List<Lead>();
        Integer successCount = 0;
        Integer errorCount = 0;
        List<String> errors = new List<String>();
        
        try {
            // Busca o usuário atual para OwnerId
            Id currentUserId = UserInfo.getUserId();
            
            for(Integer i = 0; i < quantity; i++) {
                try {
                    Lead lead = createRandomLead(currentUserId);
                    leads.add(lead);
                } catch(Exception e) {
                    errorCount++;
                    errors.add('Erro ao criar lead ' + (i + 1) + ': ' + e.getMessage());
                }
            }
            
            if(!leads.isEmpty()) {
                Database.SaveResult[] results = Database.insert(leads, false);
                
                for(Integer i = 0; i < results.size(); i++) {
                    if(results[i].isSuccess()) {
                        successCount++;
                    } else {
                        errorCount++;
                        String errorMsg = 'Lead ' + (i + 1) + ': ';
                        for(Database.Error err : results[i].getErrors()) {
                            errorMsg += err.getMessage() + ' ';
                        }
                        errors.add(errorMsg);
                    }
                }
            }
            
            String result = 'Leads gerados: ' + successCount;
            if(errorCount > 0) {
                result += ' | Erros: ' + errorCount;
            }
            if(!errors.isEmpty() && errors.size() <= 10) {
                result += '\n\nErros:\n' + String.join(errors, '\n');
            }
            
            return result;
            
        } catch(Exception e) {
            throw new AuraHandledException('Erro ao gerar leads: ' + e.getMessage());
        }
    }
    
    @AuraEnabled
    public static String generateAccounts(Integer quantity) {
        if(quantity == null || quantity <= 0 || quantity > 1000) {
            throw new AuraHandledException('Quantidade deve ser entre 1 e 1000');
        }
        
        List<Account> accounts = new List<Account>();
        Integer successCount = 0;
        Integer errorCount = 0;
        List<String> errors = new List<String>();
        
        try {
            // Busca o usuário atual para OwnerId
            Id currentUserId = UserInfo.getUserId();
            
            for(Integer i = 0; i < quantity; i++) {
                try {
                    Account account = createRandomAccount(currentUserId);
                    accounts.add(account);
                } catch(Exception e) {
                    errorCount++;
                    errors.add('Erro ao criar account ' + (i + 1) + ': ' + e.getMessage());
                }
            }
            
            if(!accounts.isEmpty()) {
                Database.SaveResult[] results = Database.insert(accounts, false);
                
                for(Integer i = 0; i < results.size(); i++) {
                    if(results[i].isSuccess()) {
                        successCount++;
                    } else {
                        errorCount++;
                        String errorMsg = 'Account ' + (i + 1) + ': ';
                        for(Database.Error err : results[i].getErrors()) {
                            errorMsg += err.getMessage() + ' ';
                        }
                        errors.add(errorMsg);
                    }
                }
            }
            
            String result = 'Accounts gerados: ' + successCount;
            if(errorCount > 0) {
                result += ' | Erros: ' + errorCount;
            }
            if(!errors.isEmpty() && errors.size() <= 10) {
                result += '\n\nErros:\n' + String.join(errors, '\n');
            }
            
            return result;
            
        } catch(Exception e) {
            throw new AuraHandledException('Erro ao gerar accounts: ' + e.getMessage());
        }
    }
    
    @AuraEnabled
    public static String deleteTestData(String objectType, Integer daysOld) {
        if(String.isBlank(objectType)) {
            throw new AuraHandledException('Tipo de objeto é obrigatório');
        }
        
        if(daysOld == null || daysOld < 0) {
            daysOld = 7; // Padrão: 7 dias
        }
        
        Date cutoffDate = Date.today().addDays(-daysOld);
        Integer deletedCount = 0;
        
        try {
            if(objectType == 'Lead') {
                List<Lead> leadsToDelete = [
                    SELECT Id FROM Lead 
                    WHERE CreatedDate >= :cutoffDate 
                    AND CreatedBy.Id = :UserInfo.getUserId()
                    LIMIT 10000
                ];
                deletedCount = leadsToDelete.size();
                delete leadsToDelete;
            } else if(objectType == 'Account') {
                List<Account> accountsToDelete = [
                    SELECT Id FROM Account 
                    WHERE CreatedDate >= :cutoffDate 
                    AND CreatedBy.Id = :UserInfo.getUserId()
                    LIMIT 10000
                ];
                deletedCount = accountsToDelete.size();
                delete accountsToDelete;
            } else {
                throw new AuraHandledException('Tipo de objeto inválido: ' + objectType);
            }
            
            return 'Registros deletados: ' + deletedCount;
            
        } catch(Exception e) {
            throw new AuraHandledException('Erro ao deletar dados: ' + e.getMessage());
        }
    }
    
    private static Lead createRandomLead(Id ownerId) {
        String firstName = getRandomElement(FIRST_NAMES);
        String lastName = getRandomElement(LAST_NAMES);
        String company = getRandomElement(COMPANIES) + ' ' + getRandomNumber(100, 9999);
        
        Lead lead = new Lead();
        lead.FirstName = firstName;
        lead.LastName = lastName;
        lead.Company = company;
        lead.Email = generateEmail(firstName, lastName);
        lead.Phone = generatePhone();
        lead.MobilePhone = generatePhone();
        lead.LeadSource = getRandomElement(LEAD_SOURCES);
        lead.Status = getRandomElement(LEAD_STATUSES);
        lead.Industry = getRandomElement(INDUSTRIES);
        lead.Title = getRandomElement(TITLES);
        lead.OwnerId = ownerId;
        
        // Campos opcionais com probabilidade
        if(Math.random() > 0.5) {
            lead.AnnualRevenue = getRandomNumber(100000, 10000000);
        }
        if(Math.random() > 0.6) {
            lead.NumberOfEmployees = getRandomNumber(10, 5000);
        }
        if(Math.random() > 0.7) {
            lead.Website = 'https://www.' + company.toLowerCase().replace(' ', '') + '.com.br';
        }
        if(Math.random() > 0.7) {
            lead.Description = 'Lead gerado automaticamente para testes. Empresa: ' + company;
        }
        if(Math.random() > 0.8) {
            lead.Fax = generatePhone();
        }
        
        return lead;
    }
    
    private static Account createRandomAccount(Id ownerId) {
        String company = getRandomElement(COMPANIES) + ' ' + getRandomNumber(100, 9999);
        
        Account account = new Account();
        account.Name = company;
        account.Phone = generatePhone();
        account.Industry = getRandomElement(INDUSTRIES);
        account.OwnerId = ownerId;
        
        // Campos opcionais com probabilidade
        if(Math.random() > 0.4) {
            account.Type = getRandomElement(ACCOUNT_TYPES);
        }
        if(Math.random() > 0.5) {
            account.AnnualRevenue = getRandomNumber(500000, 50000000);
        }
        if(Math.random() > 0.5) {
            account.NumberOfEmployees = getRandomNumber(50, 10000);
        }
        if(Math.random() > 0.6) {
            account.Website = 'https://www.' + company.toLowerCase().replace(' ', '') + '.com.br';
        }
        if(Math.random() > 0.6) {
            account.Description = 'Conta gerada automaticamente para testes. Empresa: ' + company;
        }
        if(Math.random() > 0.7) {
            account.Fax = generatePhone();
        }
        if(Math.random() > 0.7) {
            account.BillingStreet = 'Rua ' + getRandomElement(LAST_NAMES) + ', ' + getRandomNumber(100, 9999);
            account.BillingCity = getRandomCity();
            account.BillingState = getRandomState();
            account.BillingPostalCode = String.valueOf(getRandomNumber(10000, 99999)) + '-' + String.valueOf(getRandomNumber(100, 999));
            account.BillingCountry = 'Brasil';
        }
        if(Math.random() > 0.8) {
            account.ShippingStreet = account.BillingStreet;
            account.ShippingCity = account.BillingCity;
            account.ShippingState = account.BillingState;
            account.ShippingPostalCode = account.BillingPostalCode;
            account.ShippingCountry = account.BillingCountry;
        }
        if(Math.random() > 0.8) {
            account.AccountNumber = 'ACC-' + String.valueOf(getRandomNumber(100000, 999999));
        }
        
        return account;
    }
    
    private static String getRandomElement(List<String> list) {
        Integer index = (Integer)(Math.random() * list.size());
        return list[index];
    }
    
    private static Integer getRandomNumber(Integer min, Integer max) {
        return (Integer)(Math.random() * (max - min + 1)) + min;
    }
    
    private static String generateEmail(String firstName, String lastName) {
        String[] domains = new String[]{'gmail.com', 'hotmail.com', 'outlook.com', 'yahoo.com.br', 'empresa.com.br'};
        String domain = getRandomElement(domains);
        String number = String.valueOf(getRandomNumber(1, 999));
        return firstName.toLowerCase() + '.' + lastName.toLowerCase() + number + '@' + domain;
    }
    
    private static String generatePhone() {
        // Formato brasileiro: (XX) XXXXX-XXXX
        String ddd = String.valueOf(getRandomNumber(11, 99));
        String firstPart = String.valueOf(getRandomNumber(1000, 9999));
        String secondPart = String.valueOf(getRandomNumber(1000, 9999));
        return '(' + ddd + ') ' + firstPart + '-' + secondPart;
    }
    
    private static String getRandomCity() {
        List<String> cities = new List<String>{
            'São Paulo', 'Rio de Janeiro', 'Belo Horizonte', 'Brasília', 'Salvador',
            'Curitiba', 'Fortaleza', 'Recife', 'Porto Alegre', 'Manaus',
            'Belém', 'Goiânia', 'Guarulhos', 'Campinas', 'São Luís'
        };
        return getRandomElement(cities);
    }
    
    private static String getRandomState() {
        List<String> states = new List<String>{
            'SP', 'RJ', 'MG', 'RS', 'PR', 'SC', 'BA', 'GO', 'PE', 'CE',
            'DF', 'ES', 'MT', 'MS', 'PA', 'PB', 'AM', 'RN', 'AL', 'PI'
        };
        return getRandomElement(states);
    }
}

