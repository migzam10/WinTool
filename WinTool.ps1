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
            "-NoProfile", "-ExecutionPolicy", "Bypass", "-Command", "[Net.ServicePointManager]::SecurityProtocol = [Net.ServicePointManager]::SecurityProtocol -bor 3072; irm $url | iex"
        )
    }
    exit
}

# 1. Modo de ejecución (Local vs Online)
$isLocal = $false

if ([bool]$PSScriptRoot -and (Test-Path "$PSScriptRoot\MainWindow.xaml")) {
    $isLocal = $true
    $script:baseUrl = $PSScriptRoot
    Write-Host "Iniciando WinTool en modo LOCAL..." -ForegroundColor Cyan
} else {
    $script:baseUrl = "https://raw.githubusercontent.com/migzam10/WinTool/main"
    Write-Host "Iniciando WinTool en modo ONLINE..." -ForegroundColor Cyan
}

# 2. Cargar interfaz XAML
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
        "No se pudo cargar la interfaz gráfica.`n`nDetalle: $_",
        "WinTool - Error", "OK", "Error"
    )
    exit 1
}

$reader = [System.Xml.XmlNodeReader]::new($xaml)
$window = [Windows.Markup.XamlReader]::Load($reader)

# 3. Helpers Unificados
function Get-ScriptPath {
    param([string]$ScriptName)
    if ($isLocal) {
        return "$script:baseUrl\scripts\$ScriptName"
    } else {
        $tmp = "$env:TEMP\mwt_$ScriptName"
        $client = New-Object Net.WebClient
        $client.Encoding = [System.Text.Encoding]::UTF8
        $content = $client.DownloadString("$script:baseUrl/scripts/$ScriptName")
        $content | Out-File -FilePath $tmp -Encoding UTF8 -Force
        return $tmp
    }
}

function Invoke-ToolFunction {
    param([string]$ScriptName, [string]$FunctionCall)
    $scriptPath = Get-ScriptPath -ScriptName $ScriptName
    $cmd = "[Net.ServicePointManager]::SecurityProtocol = [Net.ServicePointManager]::SecurityProtocol -bor 3072; . '$scriptPath'; $FunctionCall"
    Start-Process powershell -Verb RunAs -ArgumentList @(
        "-NoExit", "-NoProfile", "-ExecutionPolicy", "Bypass", "-Command", $cmd
    )
}

$consoleBox = $window.FindName("txtConsoleOutput")

function Log-Message {
    param([string]$Message)
    if ($consoleBox) {
        $time = (Get-Date).ToString("HH:mm:ss")
        $consoleBox.AppendText("[$time] $Message`n")
        $consoleBox.ScrollToEnd()
    }
}

# 4. Información del Sistema (SysInfo Dashboard)
function Update-DashboardInfo {
    try {
        $sysScript = Get-ScriptPath -ScriptName "sysinfo.ps1"
        . "$sysScript"
        $info = Get-SystemDashboardInfo

        $window.FindName("txtSysOS").Text = $info["OS"]
        $window.FindName("txtSysCPU").Text = $info["CPU"]
        $window.FindName("txtSysRAM").Text = $info["RAM"]
        $window.FindName("txtSysDisk").Text = $info["DiskC"]
    } catch {
        Log-Message "Aviso: No se pudo cargar toda la información del hardware: $_"
    }
}

Update-DashboardInfo

$window.FindName("btnRefreshSysInfo").Add_Click({
    Update-DashboardInfo
    Log-Message "Información del sistema actualizada."
})

# 5. Asignación Tab 1: Mantenimiento
$window.FindName("btnOptimizeDrive").Add_Click({
    Log-Message "[Mantenimiento] Iniciando optimización de unidad..."
    Invoke-ToolFunction -ScriptName "maintenance.ps1" -FunctionCall "Invoke-OptimizeDrive"
})

$window.FindName("btnSFC").Add_Click({
    Log-Message "[Mantenimiento] Iniciando SFC Scannow..."
    Invoke-ToolFunction -ScriptName "maintenance.ps1" -FunctionCall "Invoke-SFC"
})

$window.FindName("btnDISM").Add_Click({
    Log-Message "[Mantenimiento] Iniciando DISM RestoreHealth..."
    Invoke-ToolFunction -ScriptName "maintenance.ps1" -FunctionCall "Invoke-DISM"
})

$window.FindName("btnRepairWU").Add_Click({
    Log-Message "[Mantenimiento] Reparando componentes de Windows Update..."
    Invoke-ToolFunction -ScriptName "maintenance.ps1" -FunctionCall "Invoke-RepairWindowsUpdate"
})

$window.FindName("btnCreateRestorePoint").Add_Click({
    Log-Message "[Mantenimiento] Creando punto de restauración del sistema..."
    Invoke-ToolFunction -ScriptName "maintenance.ps1" -FunctionCall "Invoke-CreateRestorePoint"
})

# 6. Asignación Tab 2: Limpieza de Sistema
$chkUserTemp = $window.FindName("chkUserTemp")
$chkWinTemp = $window.FindName("chkWinTemp")
$chkUpdateCache = $window.FindName("chkUpdateCache")
$chkRecycleBin = $window.FindName("chkRecycleBin")
$chkThumbCache = $window.FindName("chkThumbCache")
$chkDnsCache = $window.FindName("chkDnsCache")

$window.FindName("btnSelectAll").Add_Click({
    $chkUserTemp.IsChecked = $true
    $chkWinTemp.IsChecked = $true
    $chkUpdateCache.IsChecked = $true
    $chkRecycleBin.IsChecked = $true
    $chkThumbCache.IsChecked = $true
    $chkDnsCache.IsChecked = $true
})

$window.FindName("btnDeselectAll").Add_Click({
    $chkUserTemp.IsChecked = $false
    $chkWinTemp.IsChecked = $false
    $chkUpdateCache.IsChecked = $false
    $chkRecycleBin.IsChecked = $false
    $chkThumbCache.IsChecked = $false
    $chkDnsCache.IsChecked = $false
})

$window.FindName("btnAnalyzeClean").Add_Click({
    Log-Message "[Limpieza] Analizando tamaños de archivos y componentes..."
    $cleanerScript = Get-ScriptPath -ScriptName "cleaner.ps1"
    . "$cleanerScript"
    
    $sizes = Get-CleanableSizes
    $total = 0
    foreach ($v in $sizes.Values) { $total += $v }

    $window.FindName("lblSizeUserTemp").Text = Format-SizeString -Bytes $sizes["UserTemp"]
    $window.FindName("lblSizeWinTemp").Text = Format-SizeString -Bytes $sizes["WinTemp"]
    $window.FindName("lblSizeUpdateCache").Text = Format-SizeString -Bytes $sizes["UpdateCache"]
    $window.FindName("lblSizeRecycleBin").Text = Format-SizeString -Bytes $sizes["RecycleBin"]
    $window.FindName("lblSizeThumbCache").Text = Format-SizeString -Bytes $sizes["ThumbCache"]
    $window.FindName("lblSizeDnsCache").Text = "Caché activa"

    $totalFormatted = Format-SizeString -Bytes $total
    $window.FindName("lblCleanStatus").Text = "Análisis completado."
    $window.FindName("lblTotalCleanable").Text = "Espacio total recuperable estimado: $totalFormatted"

    Log-Message "[Limpieza] Análisis finalizado. Espacio recuperable: $totalFormatted."
})

$window.FindName("btnExecuteClean").Add_Click({
    $targets = @()
    if ($chkUserTemp.IsChecked) { $targets += "'UserTemp'" }
    if ($chkWinTemp.IsChecked) { $targets += "'WinTemp'" }
    if ($chkUpdateCache.IsChecked) { $targets += "'UpdateCache'" }
    if ($chkRecycleBin.IsChecked) { $targets += "'RecycleBin'" }
    if ($chkThumbCache.IsChecked) { $targets += "'ThumbCache'" }
    if ($chkDnsCache.IsChecked) { $targets += "'DnsCache'" }

    if ($targets.Count -eq 0) {
        [System.Windows.MessageBox]::Show(
            "Selecciona al menos una casilla para realizar la limpieza.",
            "WinTool - Limpieza", "OK", "Information"
        )
        return
    }

    $targetArgs = $targets -join ","
    Log-Message "[Limpieza] Iniciando limpieza de $($targets.Count) componentes seleccionados..."
    Invoke-ToolFunction -ScriptName "cleaner.ps1" -FunctionCall "Invoke-SystemCleaning -Targets @($targetArgs)"
})

# 7. Asignación Tab 3: Red y Wi-Fi
$window.FindName("btnWlanProfiles").Add_Click({
    Log-Message "[Wi-Fi] Obteniendo perfiles y contraseñas guardadas en modo offline..."
    Invoke-ToolFunction -ScriptName "network.ps1" -FunctionCall "Invoke-GetWlanProfiles"
})

$window.FindName("btnNetworkRepair").Add_Click({
    Log-Message "[Red] Iniciando restablecimiento de adaptadores y Flush DNS..."
    Invoke-ToolFunction -ScriptName "network.ps1" -FunctionCall "Invoke-RepairNetwork"
})

$window.FindName("btnPingCheck").Add_Click({
    Log-Message "[Red] Comprobando salida a Internet y latencia..."
    $netScript = Get-ScriptPath -ScriptName "network.ps1"
    . "$netScript"
    $ok = Test-NetworkConnectivity
    if ($ok) {
        Log-Message "[Red] Conexión a Internet comprobada exitosamente."
    } else {
        Log-Message "[Red] Alerta: No se pudo contactar servidores públicos."
    }
})

# 8. Asignación Tab 4: Utilidades Externas
function Test-HasInternet {
    try {
        return (Test-Connection -ComputerName 1.1.1.1 -Count 1 -Quiet -ErrorAction SilentlyContinue)
    } catch {
        return $false
    }
}

$window.FindName("btnWinUtil").Add_Click({
    Log-Message "[WinUtil] Comprobando conexión a Internet..."
    if (-not (Test-HasInternet)) {
        Log-Message "[ERROR] Se requiere conexión a Internet para Chris Titus WinUtil."
        [System.Windows.MessageBox]::Show(
            "No se detectó conexión a Internet. Chris Titus WinUtil requiere conexión activa.",
            "WinTool - Sin Internet", "OK", "Warning"
        )
        return
    }
    Log-Message "[WinUtil] Lanzando utilitario de Chris Titus Tech..."
    Start-Process powershell -Verb RunAs -ArgumentList @(
        "-NoProfile", "-ExecutionPolicy", "Bypass", "-Command", "[Net.ServicePointManager]::SecurityProtocol = [Net.ServicePointManager]::SecurityProtocol -bor 3072; irm christitus.com/win | iex"
    )
})

$window.FindName("btnActivarWin").Add_Click({
    Log-Message "[Massgrave] Comprobando conexión a Internet..."
    if (-not (Test-HasInternet)) {
        Log-Message "[ERROR] Se requiere conexión a Internet para Massgrave."
        [System.Windows.MessageBox]::Show(
            "No se detectó conexión a Internet. La herramienta de activación requiere conexión activa.",
            "WinTool - Sin Internet", "OK", "Warning"
        )
        return
    }
    Log-Message "[Massgrave] Lanzando utilitario de activación de Massgrave..."
    Start-Process powershell -Verb RunAs -ArgumentList @(
        "-NoProfile", "-ExecutionPolicy", "Bypass", "-Command", "[Net.ServicePointManager]::SecurityProtocol = [Net.ServicePointManager]::SecurityProtocol -bor 3072; irm https://get.activated.win | iex"
    )
})

# 9. Consola integrada
$window.FindName("btnClearConsole").Add_Click({
    $consoleBox.Text = "[$((Get-Date).ToString('HH:mm:ss'))] Registro limpiado.`n"
})

$window.FindName("btnCopyConsole").Add_Click({
    if ($consoleBox.Text) {
        [System.Windows.Clipboard]::SetText($consoleBox.Text)
        [System.Windows.MessageBox]::Show(
            "Registro copiado al portapapeles.",
            "WinTool", "OK", "Information"
        )
    }
})

# 10. Iniciar Aplicación
$window.ShowDialog() | Out-Null
