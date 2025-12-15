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

# Verifica se o componente existe
if (-not (Test-Path "lwc\dataGenerator")) {
    Write-Host "ERRO: Componente dataGenerator nao encontrado!" -ForegroundColor Red
    exit 1
} else {
    Write-Host "Componente dataGenerator encontrado" -ForegroundColor Green
}

if (-not (Test-Path "force-app\main\default\classes\DataGeneratorController.cls")) {
    Write-Host "ERRO: Classe DataGeneratorController nao encontrada!" -ForegroundColor Red
    Write-Host "O componente dataGenerator nao funcionara sem a classe Apex." -ForegroundColor Yellow
    exit 1
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

# Faz o deploy da classe Apex primeiro
Write-Host ""
Write-Host "Fazendo deploy da classe Apex DataGeneratorController..." -ForegroundColor Yellow
$apexDeployOutput = sf project deploy start -d force-app/main/default/classes/DataGeneratorController.cls -o $OrgName 2>&1

$apexDeploySuccess = $false
if ($LASTEXITCODE -eq 0) {
    Write-Host "Classe DataGeneratorController deployada com sucesso!" -ForegroundColor Green
    $apexDeploySuccess = $true
    # Aguarda um pouco para garantir que a classe esteja disponível
    Write-Host "Aguardando processamento da classe..." -ForegroundColor Yellow
    Start-Sleep -Seconds 3
} else {
    Write-Host "ERRO no deploy da classe DataGeneratorController." -ForegroundColor Red
    Write-Host $apexDeployOutput -ForegroundColor Red
}

# Faz o deploy do componente LWC apenas se a classe foi deployada com sucesso
$lwcDeploySuccess = $false
if ($apexDeploySuccess) {
    Write-Host ""
    Write-Host "Fazendo deploy do componente dataGenerator..." -ForegroundColor Yellow
    $lwcDeployOutput = sf project deploy start -d lwc/dataGenerator -o $OrgName 2>&1
    
    if ($LASTEXITCODE -eq 0) {
        Write-Host "Componente dataGenerator deployado com sucesso!" -ForegroundColor Green
        $lwcDeploySuccess = $true
    } else {
        Write-Host "ERRO no deploy do componente dataGenerator." -ForegroundColor Red
        Write-Host $lwcDeployOutput -ForegroundColor Red
    }
} else {
    Write-Host ""
    Write-Host "Pulando deploy do componente LWC porque a classe Apex falhou." -ForegroundColor Yellow
}

$deploySuccess = $apexDeploySuccess -and $lwcDeploySuccess

# Resumo final
Write-Host ""
if ($deploySuccess) {
    Write-Host "Deploy concluido com sucesso!" -ForegroundColor Green
    Write-Host ""
    Write-Host "Proximos passos:" -ForegroundColor Cyan
    Write-Host "   1. Acesse: https://curious-raccoon-h5tx8a-dev-ed.trailblaze.lightning.force.com" -ForegroundColor White
    Write-Host "   2. Va para: Setup -> Custom Code -> Lightning Components" -ForegroundColor White
    Write-Host "   3. Verifique se 'dataGenerator' aparece na lista" -ForegroundColor White
    Write-Host "   4. Adicione o componente a uma pagina no App Builder (App Page, Record Page, etc.)" -ForegroundColor White
    Write-Host "   5. Use o componente para gerar massas de dados (Leads e Accounts)" -ForegroundColor White
    Write-Host ""
    Write-Host "Abrir org no navegador? (S/N)" -ForegroundColor Yellow
    $open = Read-Host
    if ($open -eq "S" -or $open -eq "s") {
        Start-Process "https://curious-raccoon-h5tx8a-dev-ed.trailblaze.lightning.force.com"
    }
} else {
    Write-Host ""
    Write-Host "Deploy concluido com erros. Verifique os logs acima." -ForegroundColor Yellow
    Write-Host "Alguns componentes podem nao estar funcionais." -ForegroundColor Yellow
}


#Script em PowerSheel gerado por IA para deploy dentro do ambiente
