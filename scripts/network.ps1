function Invoke-RepairNetwork {
    Write-Host "`n=======================================================" -ForegroundColor Cyan
    Write-Host "       WinTool - Reparación y Restablecimiento de Red" -ForegroundColor White
    Write-Host "=======================================================" -ForegroundColor Cyan

    Write-Host "`n[1/5] Vaciando caché de resolución DNS (Flush DNS)..." -ForegroundColor Yellow
    ipconfig /flushdns
    Write-Host "  [ OK ] Caché DNS vaciada." -ForegroundColor Green

    Write-Host "`n[2/5] Renovando registro de nombres NetBIOS y DNS..." -ForegroundColor Yellow
    ipconfig /registerdns
    Write-Host "  [ OK ] Registro solicitado." -ForegroundColor Green

    Write-Host "`n[3/5] Liberando y renovando concesión de dirección IP..." -ForegroundColor Yellow
    ipconfig /release | Out-Null
    ipconfig /renew
    Write-Host "  [ OK ] Concesión IP actualizada." -ForegroundColor Green

    Write-Host "`n[4/5] Restableciendo catálogo de Winsock..." -ForegroundColor Yellow
    netsh winsock reset
    Write-Host "  [ OK ] Catálogo Winsock restablecido." -ForegroundColor Green

    Write-Host "`n[5/5] Restableciendo pila TCP/IP..." -ForegroundColor Yellow
    netsh int ip reset
    Write-Host "  [ OK ] Pila TCP/IP restablecida." -ForegroundColor Green

    Write-Host "`n=======================================================" -ForegroundColor Green
    Write-Host " [ OK ] Reparación de red completada exitosamente." -ForegroundColor White
    Write-Host " Nota: Si experimentas problemas persistentes, reinicia tu PC." -ForegroundColor Yellow
    Write-Host "=======================================================" -ForegroundColor Green
    Read-Host "`nPresiona Enter para cerrar"
}

function Invoke-GetWlanProfiles {
    Write-Host "`n=======================================================" -ForegroundColor Cyan
    Write-Host "       WinTool - Extractor de Perfiles Wi-Fi (Offline)" -ForegroundColor White
    Write-Host "=======================================================" -ForegroundColor Cyan

    Write-Host "`n[INFO] Escaneando interfaces y redes guardadas en este equipo..." -ForegroundColor Cyan

    $rawProfiles = netsh wlan show profiles
    $profileNames = @()

    foreach ($line in $rawProfiles) {
        if ($line -match ':\s*(.+)$') {
            $name = $matches[1].Trim()
            # Omitir cabeceras estándar
            if ($name -and $name -notmatch '^-' -and $name -notmatch 'User profiles|Perfiles de usuario|Interface|Interfaz') {
                $profileNames += $name
            }
        }
    }

    if ($profileNames.Count -eq 0) {
        Write-Host "  [WARN] No se encontraron perfiles de Wi-Fi guardados en este equipo." -ForegroundColor Yellow
        Read-Host "`nPresiona Enter para cerrar"
        return
    }

    $results = @()
    $desktopPath = [System.IO.Path]::Combine($env:USERPROFILE, "Desktop")
    $exportFile = Join-Path $desktopPath "WiFi-Passwords.txt"
    $fileLines = @(
        "=======================================================",
        " WinTool - Perfiles y Contraseñas Wi-Fi Guardadas",
        " Fecha: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')",
        "=======================================================",
        ""
    )

    Write-Host "`nRedes encontradas ($($profileNames.Count)):`n" -ForegroundColor Cyan

    foreach ($p in $profileNames) {
        $details = netsh wlan show profile name="$p" key=clear
        $pass = "<Sin contraseña / Abierta>"
        $auth = "Desconocida"

        foreach ($dLine in $details) {
            # Contenido de la clave / Key Content
            if ($dLine -match 'Contenido de la clave\s*:\s*(.+)$|Key Content\s*:\s*(.+)$') {
                $pass = if ($matches[1]) { $matches[1].Trim() } else { $matches[2].Trim() }
            }
            # Autenticación / Authentication
            if ($dLine -match 'Autenticaci[oó]n\s*:\s*(.+)$|Authentication\s*:\s*(.+)$') {
                $auth = if ($matches[1]) { $matches[1].Trim() } else { $matches[2].Trim() }
            }
        }

        $obj = [PSCustomObject]@{
            "Red (SSID)" = $p
            "Seguridad"  = $auth
            "Contraseña" = $pass
        }
        $results += $obj

        Write-Host " 📶 SSID: $p" -ForegroundColor White
        Write-Host "    Seguridad : $auth" -ForegroundColor Gray
        Write-Host "    Clave     : $pass" -ForegroundColor Yellow
        Write-Host " ----------------------------------------------------" -ForegroundColor DarkGray

        $fileLines += "SSID       : $p"
        $fileLines += "Seguridad  : $auth"
        $fileLines += "Contraseña : $pass"
        $fileLines += "-------------------------------------------------------"
    }

    try {
        $fileLines | Out-File -FilePath $exportFile -Encoding UTF8 -Force
        Write-Host "`n[ OK ] Se exportó una copia a tu Escritorio:" -ForegroundColor Green
        Write-Host "  $exportFile" -ForegroundColor Cyan
    } catch {
        Write-Host "`n[WARN] No se pudo escribir en el Escritorio: $($_.Exception.Message)" -ForegroundColor Yellow
    }

    Read-Host "`nPresiona Enter para cerrar"
}

function Test-NetworkConnectivity {
    Write-Host "`n[INFO] Comprobando conectividad a internet..." -ForegroundColor Cyan
    $pingOk = Test-Connection -ComputerName 1.1.1.1 -Count 2 -Quiet -ErrorAction SilentlyContinue
    if (-not $pingOk) {
        $pingOk = Test-Connection -ComputerName 8.8.8.8 -Count 2 -Quiet -ErrorAction SilentlyContinue
    }
    
    if ($pingOk) {
        Write-Host "  [ OK ] Conexión a Internet activa (Ping exitoso a DNS público)." -ForegroundColor Green
        return $true
    } else {
        Write-Host "  [FAIL] Sin salida a Internet o paquetes bloqueados." -ForegroundColor Red
        return $false
    }
}
