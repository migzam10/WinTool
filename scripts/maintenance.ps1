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
        Write-Host "  [FAIL] No se pudo obtener la información de la unidad C." -ForegroundColor Red
    }
    Read-Host "`nPresiona Enter para cerrar"
}

function Invoke-SFC {
    Write-Host "`n[INFO] Ejecutando SFC /scannow..." -ForegroundColor Cyan
    sfc /scannow
    if ($LASTEXITCODE -eq 0) {
        Write-Host "  [ OK ] SFC completado." -ForegroundColor Green
    } else {
        Write-Host "  [FAIL] SFC reportó problemas. Log: C:\Windows\Logs\CBS\CBS.log" -ForegroundColor Red
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