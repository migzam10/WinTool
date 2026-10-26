function Invoke-OptimizeDrive {
    Write-Host "`n[INFO] Detectando tipo de disco..." -ForegroundColor Cyan
    $vol = Get-Volume -DriveLetter C -ErrorAction SilentlyContinue
    
    if ($vol) {
        $type = $vol.MediaType
        switch ($type) {
            "SSD" {
                Write-Host "  [WARN] SSD detectado. Ejecutando TRIM..." -ForegroundColor Yellow
                Optimize-Volume -DriveLetter C -ReTrim -Verbose
                Write-Host "  [ OK ] TRIM completado." -ForegroundColor Green
            }
            "HDD" {
                Write-Host "  [INFO] HDD detectado. Desfragmentando..." -ForegroundColor Cyan
                Optimize-Volume -DriveLetter C -Defrag -Verbose
                Write-Host "  [ OK ] Desfragmentación completada." -ForegroundColor Green
            }
            default {
                Write-Host "  [WARN] Tipo de disco no determinado ($type). Ejecutando optimización genérica..." -ForegroundColor Yellow
                Optimize-Volume -DriveLetter C -Verbose
                Write-Host "  [ OK ] Optimización completada." -ForegroundColor Green
            }
        }
    } else {
        Write-Host "  [INFO] Consultando defrag.exe nativo..." -ForegroundColor Cyan
        defrag.exe C: /U /V
        Write-Host "  [ OK ] Optimización completada." -ForegroundColor Green
    }
    Read-Host "`nPresiona Enter para cerrar"
}

function Invoke-SFC {
    Write-Host "`n[INFO] Ejecutando SFC /scannow..." -ForegroundColor Cyan
    sfc /scannow
    if ($LASTEXITCODE -eq 0) {
        Write-Host "  [ OK ] SFC completado sin errores." -ForegroundColor Green
    } else {
        Write-Host "  [WARN] SFC finalizó o reportó novedades. Log: C:\Windows\Logs\CBS\CBS.log" -ForegroundColor Yellow
    }
    Read-Host "`nPresiona Enter para cerrar"
}

function Invoke-DISM {
    Write-Host "`n[INFO] Paso 1/3 - CheckHealth..." -ForegroundColor Cyan
    DISM /Online /Cleanup-Image /CheckHealth

    Write-Host "`n[INFO] Paso 2/3 - ScanHealth..." -ForegroundColor Cyan
    DISM /Online /Cleanup-Image /ScanHealth

    Write-Host "`n[INFO] Paso 3/3 - RestoreHealth..." -ForegroundColor Cyan
    DISM /Online /Cleanup-Image /RestoreHealth

    if ($LASTEXITCODE -eq 0) {
        Write-Host "  [ OK ] DISM completado exitosamente." -ForegroundColor Green
    } else {
        Write-Host "  [FAIL] DISM reportó errores. Código: $LASTEXITCODE" -ForegroundColor Red
    }
    Read-Host "`nPresiona Enter para cerrar"
}

function Invoke-RepairWindowsUpdate {
    Write-Host "`n[INFO] Iniciando reparación de componentes de Windows Update..." -ForegroundColor Cyan
    
    $services = @("wuauserv", "cryptSvc", "bits", "msiserver")
    Write-Host "  [1/4] Deteniendo servicios de actualización..." -ForegroundColor Yellow
    foreach ($svc in $services) {
        Stop-Service -Name $svc -Force -ErrorAction SilentlyContinue
    }
    
    Write-Host "  [2/4] Purgando caché de descargas de SoftwareDistribution..." -ForegroundColor Yellow
    $dlPath = "$env:SystemRoot\SoftwareDistribution\Download"
    if (Test-Path $dlPath) {
        Get-ChildItem -Path $dlPath -Recurse -Force -ErrorAction SilentlyContinue | Remove-Item -Recurse -Force -ErrorAction SilentlyContinue
    }
    
    Write-Host "  [3/4] Renombrando catroot2 antiguo..." -ForegroundColor Yellow
    $catroot = "$env:SystemRoot\System32\catroot2"
    if (Test-Path $catroot) {
        Rename-Item -Path $catroot -NewName "catroot2.old_$([DateTime]::Now.Ticks)" -ErrorAction SilentlyContinue
    }

    Write-Host "  [4/4] Reiniciando servicios de actualización..." -ForegroundColor Yellow
    foreach ($svc in $services) {
        Start-Service -Name $svc -ErrorAction SilentlyContinue
    }

    Write-Host "`n  [ OK ] Windows Update ha sido restablecido exitosamente." -ForegroundColor Green
    Read-Host "`nPresiona Enter para cerrar"
}

function Invoke-CreateRestorePoint {
    Write-Host "`n[INFO] Verificando Protección del Sistema..." -ForegroundColor Cyan
    try {
        Enable-ComputerRestore -Drive "C:\" -ErrorAction SilentlyContinue
        
        Write-Host "  [INFO] Creando Punto de Restauración 'WinTool_Respaldo'..." -ForegroundColor Yellow
        Set-ItemProperty -Path "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\SystemRestore" -Name "SystemRestorePointCreationFrequency" -Value 0 -Type DWord -ErrorAction SilentlyContinue
        
        Checkpoint-Computer -Description "WinTool_Respaldo" -RestorePointType "MODIFY_SETTINGS" -ErrorAction Stop
        Write-Host "`n  [ OK ] Punto de Restauración creado con éxito." -ForegroundColor Green
    } catch {
        Write-Host "`n  [FAIL] No se pudo crear el punto de restauración: $($_.Exception.Message)" -ForegroundColor Red
        Write-Host "  Asegúrate de tener espacio disponible y la Protección del Sistema habilitada en C:." -ForegroundColor Yellow
    }
    Read-Host "`nPresiona Enter para cerrar"
}
