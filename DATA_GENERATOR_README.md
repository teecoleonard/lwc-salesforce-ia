# Gerador de Massa de Dados para Salesforce

Sistema completo para gerar massas de dados de teste no Salesforce, sem depender do Inspector. Suporta geração de **Leads** e **Accounts** com dados realistas.

## 📋 Funcionalidades

### ✅ Geração de Dados
- **Leads**: Gera leads com dados completos incluindo:
  - Nome, sobrenome, empresa
  - Email, telefone, celular
  - Origem do lead, status, indústria
  - Título, receita anual, número de funcionários
  - Website, descrição, fax (opcionais)
  
- **Accounts**: Gera contas com dados completos incluindo:
  - Nome da conta
  - Telefone, fax
  - Indústria, tipo
  - Receita anual, número de funcionários
  - Website, descrição
  - Endereço de cobrança e entrega
  - Número da conta (opcional)

### 🗑️ Exclusão de Dados
- Exclui registros de teste criados nos últimos X dias
- Filtra apenas registros criados pelo usuário atual
- Suporta exclusão de Leads e Accounts

## 🚀 Como Usar

### 1. Deploy do Sistema

Execute o deploy usando o Salesforce CLI:

```powershell
# Deploy da classe Apex
sf project deploy start -d force-app/main/default/classes/DataGeneratorController.cls -o sua-org

# Deploy do componente LWC
sf project deploy start -d lwc/dataGenerator -o sua-org
```

Ou use o script PowerShell existente (ajustando para incluir os novos arquivos).

### 2. Adicionar o Componente a uma Página

1. Acesse **Setup** → **App Builder**
2. Crie uma nova **App Page** ou edite uma existente
3. Arraste o componente **dataGenerator** para a página
4. Salve e ative a página

### 3. Gerar Dados

1. Acesse a página onde o componente foi adicionado
2. Selecione o tipo de objeto (Lead ou Account)
3. Informe a quantidade desejada (1 a 1000)
4. Clique em **Gerar Dados**
5. Aguarde o processamento e veja o resultado

### 4. Excluir Dados de Teste

1. Clique em **Mostrar Exclusão**
2. Selecione o tipo de objeto
3. Informe quantos dias atrás os registros foram criados
4. Clique em **Excluir Dados**

## 📊 Campos Gerados

### Lead
- ✅ Nome completo (FirstName, LastName)
- ✅ Empresa (Company) - obrigatório
- ✅ Email - obrigatório
- ✅ Telefone e Celular
- ✅ Origem do Lead (LeadSource)
- ✅ Status do Lead (Status)
- ✅ Indústria (Industry)
- ✅ Título (Title)
- ✅ Receita Anual (AnnualRevenue) - 50% de chance
- ✅ Número de Funcionários (NumberOfEmployees) - 40% de chance
- ✅ Website - 30% de chance
- ✅ Descrição - 30% de chance
- ✅ Fax - 20% de chance

### Account
- ✅ Nome da Conta (Name) - obrigatório
- ✅ Telefone (Phone)
- ✅ Indústria (Industry)
- ✅ Tipo (Type) - 60% de chance
- ✅ Receita Anual (AnnualRevenue) - 50% de chance
- ✅ Número de Funcionários (NumberOfEmployees) - 50% de chance
- ✅ Website - 40% de chance
- ✅ Descrição - 40% de chance
- ✅ Fax - 30% de chance
- ✅ Endereço de Cobrança completo - 30% de chance
- ✅ Endereço de Entrega completo - 20% de chance
- ✅ Número da Conta (AccountNumber) - 20% de chance

## 🔧 Configurações Técnicas

### Classe Apex: `DataGeneratorController`

**Métodos disponíveis:**
- `generateLeads(Integer quantity)` - Gera leads
- `generateAccounts(Integer quantity)` - Gera accounts
- `deleteTestData(String objectType, Integer daysOld)` - Exclui dados de teste

**Limitações:**
- Máximo de 1000 registros por operação
- Exclusão limitada a 10.000 registros por vez
- Apenas registros criados pelo usuário atual são excluídos

### Componente LWC: `dataGenerator`

**Propriedades:**
- Interface visual moderna com Lightning Design System
- Validação de entrada
- Feedback visual com spinners e toasts
- Seção de exclusão colapsável

## 📝 Notas Importantes

1. **Permissões**: Certifique-se de que o usuário tem permissões para criar/editar Leads e Accounts
2. **Limites**: Respeite os limites de API do Salesforce (10.000 registros por transação)
3. **Dados Realistas**: Os dados são gerados aleatoriamente mas seguem padrões realistas brasileiros
4. **Segurança**: A exclusão só remove registros criados pelo próprio usuário

## 🎯 Próximos Passos

Para expandir o sistema, você pode:
- Adicionar suporte para outros objetos (Contact, Opportunity, etc.)
- Criar templates de dados personalizados
- Adicionar validações mais específicas
- Integrar com fluxos de automação

## 🐛 Troubleshooting

**Erro: "Quantidade deve ser entre 1 e 1000"**
- Verifique se o número está dentro do intervalo permitido

**Erro: "Erro ao gerar leads/accounts"**
- Verifique as permissões do usuário
- Verifique se os campos obrigatórios estão configurados corretamente
- Verifique os logs de debug no Salesforce

**Componente não aparece**
- Verifique se o deploy foi concluído com sucesso
- Verifique se o componente está exposto (isExposed=true no .js-meta.xml)

