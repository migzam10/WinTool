Set-StrictMode -Version Latest
[Net.ServicePointManager]::SecurityProtocol = [Net.ServicePointManager]::SecurityProtocol -bor 3072
Add-Type -AssemblyName PresentationFramework

$isAdmin = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)

if (-not $isAdmin) {
    
    if ($PSCommandPath) {
        Start-Process powershell -Verb RunAs -ArgumentList @(
            "-NoProfile", "-ExecutionPolicy", "Bypass", "-File", "`"$PSCommandPath`""
        )
    } else {
        $url = "https://raw.githubusercontent.com/migzam10/WinTool/main/WinTool.ps1"
        Start-Process powershell -Verb RunAs -ArgumentList @(
            "-NoProfile", "-ExecutionPolicy", "Bypass", "-Command", "irm $url | iex"
        )
    }
    exit
}

#1. (Local vs Online)
$isLocal = $false

if ([bool]$PSScriptRoot -and (Test-Path "$PSScriptRoot\MainWindow.xaml")) {
    $isLocal = $true
    $script:baseUrl = $PSScriptRoot
    Write-Host "Iniciando WinTool en modo LOCAL..." -ForegroundColor Cyan
} else {
    $script:baseUrl = "https://raw.githubusercontent.com/migzam10/WinTool/main"
    Write-Host "Iniciando WinTool en modo ONLINE..." -ForegroundColor Cyan
}

#2. Cargar la interfaz XAML
try {
    if ($isLocal) {
        [xml]$xaml = Get-Content "$script:baseUrl\MainWindow.xaml" -Raw -Encoding UTF8
    } else {
        $webClient = New-Object Net.WebClient
        $webClient.Encoding = [System.Text.Encoding]::UTF8
        [xml]$xaml = $webClient.DownloadString("$script:baseUrl/MainWindow.xaml")
    }
} catch {
    [System.Windows.MessageBox]::Show(
        "No se pudo cargar la interfaz.`n`nDetalle: $_",
        "WinTool - Error", "OK", "Error"
    )
    exit 1
}

$reader = [System.Xml.XmlNodeReader]::new($xaml)
$window = [Windows.Markup.XamlReader]::Load($reader)

#3. Helpers Unificados 
function Invoke-ToolFunction {
    param([string]$ScriptName, [string]$FunctionCall)
    
    if ($isLocal) {
        $cmd = ". '$script:baseUrl\scripts\$ScriptName'; $FunctionCall"
        Start-Process powershell -Verb RunAs -ArgumentList @(
            "-NoExit", "-NoProfile", "-ExecutionPolicy", "Bypass", "-Command", $cmd
        )
    } else {
        #forzando UTF8
        $tmp = "$env:TEMP\mwt_$(Get-Random).ps1"
        $client = New-Object Net.WebClient
        $client.Encoding = [System.Text.Encoding]::UTF8
        $content = $client.DownloadString("$script:baseUrl/scripts/$ScriptName")
        $content | Out-File -FilePath $tmp -Encoding UTF8
        
        $cmd = ". '$tmp'; $FunctionCall"
        Start-Process powershell -Verb RunAs -ArgumentList @(
            "-NoExit", "-NoProfile", "-ExecutionPolicy", "Bypass", "-Command", $cmd
        )
    }
}

# Ejecuta un script externo completo (AV Safe)
function Invoke-ExternalScript {
    param([string]$Url)
    
    $tmp = "$env:TEMP\mwt_ext_$(Get-Random).ps1"
    $client = New-Object Net.WebClient
    $client.Encoding = [System.Text.Encoding]::UTF8
    $content = $client.DownloadString($Url)
    $content | Out-File -FilePath $tmp -Encoding UTF8
    
    # Se usa -File en lugar de -Command para evitar bloqueos del antivirus
    Start-Process powershell -Verb RunAs -ArgumentList @(
        "-NoProfile", "-ExecutionPolicy", "Bypass", "-File", "`"$tmp`""
    )
}

#4. Asignación de Botones 

$window.FindName("btnOptimizeDrive").Add_Click({
    Invoke-ToolFunction -ScriptName "maintenance.ps1" -FunctionCall "Invoke-OptimizeDrive"
})

$window.FindName("btnSFC").Add_Click({
    Invoke-ToolFunction -ScriptName "maintenance.ps1" -FunctionCall "Invoke-SFC"
})

$window.FindName("btnDISM").Add_Click({
    Invoke-ToolFunction -ScriptName "maintenance.ps1" -FunctionCall "Invoke-DISM"
})

$window.FindName("btnWlanProfiles").Add_Click({
    
    Invoke-ExternalScript -Url "https://raw.githubusercontent.com/migzam10/Get-WlanProfiles/main/On-Get-WlanProfiles.ps1"
    Invoke-ExternalScript -Url "https://raw.githubusercontent.com/migzam10/Get-WlanProfiles/main/Extras/extra1.ps1"
})

$window.FindName("btnWinUtil").Add_Click({
    # Chris Titus Tech WinUtil
    Start-Process powershell -Verb RunAs -ArgumentList @(
        "-NoProfile", "-ExecutionPolicy", "Bypass", "-Command", "[Net.ServicePointManager]::SecurityProtocol = [Net.ServicePointManager]::SecurityProtocol -bor 3072; irm christitus.com/win | iex"
    )
})

$window.FindName("btnActivarWin").Add_Click({
    Start-Process powershell -Verb RunAs -ArgumentList @(
        "-NoProfile", "-ExecutionPolicy", "Bypass", "-Command", "[Net.ServicePointManager]::SecurityProtocol = [Net.ServicePointManager]::SecurityProtocol -bor 3072; irm https://get.activated.win | iex"
    )
})

#5. Iniciar Aplicación
$window.ShowDialog() | Out-Null