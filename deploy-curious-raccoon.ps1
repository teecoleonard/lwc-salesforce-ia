# Script PowerShell para fazer deploy do componente LWC na org curious-raccoon
# Uso: .\deploy-curious-raccoon.ps1

$OrgName = "curious-raccoon-dev"
$OrgUsername = "curious-raccoon-h5tx8a-dev-ed.trailblaze"
# Para orgs do Trailhead (Developer Edition), use login.salesforce.com
$OrgUrl = "https://login.salesforce.com"

Write-Host "Deploy para org: curious-raccoon-dev" -ForegroundColor Cyan
Write-Host "URL: $OrgUrl" -ForegroundColor Cyan
Write-Host ""

# Verifica se o Salesforce CLI esta instalado
if (-not (Get-Command sf -ErrorAction SilentlyContinue)) {
    Write-Host "ERRO: Salesforce CLI nao encontrado!" -ForegroundColor Red
    Write-Host "Instale em: https://developer.salesforce.com/tools/salesforcecli" -ForegroundColor Yellow
    exit 1
}

# Verifica se as pastas existem
if (-not (Test-Path "lwc\aiFloatingButton")) {
    Write-Host "ERRO: Pasta lwc\aiFloatingButton nao encontrada!" -ForegroundColor Red
    exit 1
}

if (-not (Test-Path "force-app\main\default\classes\AIController.cls")) {
    Write-Host "AVISO: Classe AIController nao encontrada!" -ForegroundColor Yellow
    Write-Host "O componente pode nao funcionar sem a classe Apex." -ForegroundColor Yellow
}

# Verifica se esta autorizado
Write-Host "Verificando autorizacao da org..." -ForegroundColor Yellow
try {
    $orgListOutput = sf org list --json 2>&1
    $orgList = $orgListOutput | ConvertFrom-Json
    
    $orgExists = $false
    if ($orgList.result -and $orgList.result.nonScratchOrgs) {
        foreach ($org in $orgList.result.nonScratchOrgs) {
            if ($org.alias -eq $OrgName -or $org.username -like "*curious-raccoon*") {
                $orgExists = $true
                break
            }
        }
    }
    
    if (-not $orgExists) {
        Write-Host "Org nao autorizada. Autorizando agora..." -ForegroundColor Yellow
        Write-Host "IMPORTANTE: Esta e uma org do Trailhead (Developer Edition)" -ForegroundColor Cyan
        Write-Host "Org: $OrgUsername" -ForegroundColor Cyan
        Write-Host ""
        Write-Host "1. O navegador vai abrir" -ForegroundColor White
        Write-Host "2. Faca login com suas credenciais do Trailhead" -ForegroundColor White
        Write-Host "3. Selecione a org: $OrgUsername" -ForegroundColor White
        Write-Host ""
        sf org login web -a $OrgName -r $OrgUrl
    } else {
        Write-Host "Org ja autorizada" -ForegroundColor Green
    }
} catch {
    Write-Host "Nao foi possivel verificar orgs. Tentando autorizar..." -ForegroundColor Yellow
    Write-Host "IMPORTANTE: Esta e uma org do Trailhead (Developer Edition)" -ForegroundColor Cyan
    Write-Host "Org: $OrgUsername" -ForegroundColor Cyan
    Write-Host "Faca login quando o navegador abrir e selecione a org correta" -ForegroundColor White
    sf org login web -a $OrgName -r $OrgUrl
}

# Verifica se existe sfdx-project.json, se nao, cria um basico
if (-not (Test-Path "sfdx-project.json")) {
    Write-Host "Criando arquivo sfdx-project.json..." -ForegroundColor Yellow
    $projectJson = @{
        packageDirectories = @(
            @{
                path = "force-app"
                default = $true
            },
            @{
                path = "lwc"
                default = $false
            }
        )
        name = "salesforce-llm-backend"
        namespace = ""
        sfdcLoginUrl = "https://login.salesforce.com"
        sourceApiVersion = "58.0"
    } | ConvertTo-Json -Depth 10
    $projectJson | Out-File -FilePath "sfdx-project.json" -Encoding UTF8
}

# Faz o deploy da classe Apex primeiro (se existir)
if (Test-Path "force-app\main\default\classes\AIController.cls") {
    Write-Host ""
    Write-Host "Fazendo deploy da classe Apex AIController..." -ForegroundColor Yellow
    sf project deploy start -d force-app/main/default/classes/AIController.cls -o $OrgName
    
    if ($LASTEXITCODE -ne 0) {
        Write-Host "ERRO no deploy da classe Apex. Continuando com o componente LWC..." -ForegroundColor Yellow
    }
}

# Faz o deploy do componente LWC
Write-Host ""
Write-Host "Fazendo deploy do componente aiFloatingButton..." -ForegroundColor Yellow
sf project deploy start -d lwc/aiFloatingButton -o $OrgName

if ($LASTEXITCODE -eq 0) {
    Write-Host ""
    Write-Host "Deploy concluido com sucesso!" -ForegroundColor Green
    Write-Host ""
    Write-Host "Proximos passos:" -ForegroundColor Cyan
    Write-Host "   1. Acesse: https://curious-raccoon-h5tx8a-dev-ed.trailblaze.lightning.force.com" -ForegroundColor White
    Write-Host "   2. Va para: Setup -> Custom Code -> Lightning Components" -ForegroundColor White
    Write-Host "   3. Verifique se 'aiFloatingButton' aparece na lista" -ForegroundColor White
    Write-Host "   4. Adicione o componente a uma pagina no App Builder (App Page, Record Page, etc.)" -ForegroundColor White
    Write-Host "   5. Configure o Named Credential 'LLM_CONNECTOR' apontando para sua API" -ForegroundColor White
    Write-Host ""
    Write-Host "Abrir org no navegador? (S/N)" -ForegroundColor Yellow
    $open = Read-Host
    if ($open -eq "S" -or $open -eq "s") {
        Start-Process "https://curious-raccoon-h5tx8a-dev-ed.trailblaze.lightning.force.com"
    }
} else {
    Write-Host ""
    Write-Host "ERRO no deploy. Verifique os logs acima." -ForegroundColor Red
    exit 1
}


#Script em PowerSheel gerado por IA para deploy dentro do ambiente
