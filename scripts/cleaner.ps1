function Format-SizeString {
    param([double]$Bytes)
    if ($Bytes -ge 1GB) {
        return "{0:N2} GB" -f ($Bytes / 1GB)
    } elseif ($Bytes -ge 1MB) {
        return "{0:N2} MB" -f ($Bytes / 1MB)
    } elseif ($Bytes -ge 1KB) {
        return "{0:N1} KB" -f ($Bytes / 1KB)
    } else {
        return "$Bytes B"
    }
}

function Get-FolderSizeBytes {
    param([string]$Path)
    if (-not (Test-Path $Path)) { return 0 }
    try {
        $measure = Get-ChildItem -Path $Path -Recurse -Force -File -ErrorAction SilentlyContinue |
                   Measure-Object -Property Length -Sum -ErrorAction SilentlyContinue
        if ($measure -and $measure.Sum) {
            return [double]$measure.Sum
        }
    } catch {}
    return 0
}

function Get-CleanableSizes {
    $sizes = @{}

    # 1. Temporales de Usuario
    $userTempPath = [System.IO.Path]::GetTempPath()
    $sizes["UserTemp"] = Get-FolderSizeBytes -Path $userTempPath

    # 2. Temporales de Windows
    $winTempPath = "$env:SystemRoot\Temp"
    $sizes["WinTemp"] = Get-FolderSizeBytes -Path $winTempPath

    # 3. Caché de descargas de Windows Update
    $updateDlPath = "$env:SystemRoot\SoftwareDistribution\Download"
    $sizes["UpdateCache"] = Get-FolderSizeBytes -Path $updateDlPath

    # 4. Papelera de reciclaje
    $recycleBytes = 0
    try {
        $recycleDrives = Get-PSDrive -PSProvider FileSystem | Where-Object { $_.Free -gt 0 }
        foreach ($d in $recycleDrives) {
            $rPath = "$($d.Root)`$Recycle.Bin"
            if (Test-Path $rPath) {
                $recycleBytes += Get-FolderSizeBytes -Path $rPath
            }
        }
    } catch {}
    $sizes["RecycleBin"] = $recycleBytes

    # 5. Miniaturas y reportes WER
    $thumbBytes = 0
    $werPath = "$env:LOCALAPPDATA\Microsoft\Windows\WER"
    if (Test-Path $werPath) {
        $thumbBytes += Get-FolderSizeBytes -Path $werPath
    }
    $thumbPath = "$env:LOCALAPPDATA\Microsoft\Windows\Explorer"
    if (Test-Path $thumbPath) {
        try {
            $measure = Get-ChildItem -Path $thumbPath -Filter "thumbcache_*.db" -Force -File -ErrorAction SilentlyContinue |
                       Measure-Object -Property Length -Sum
            if ($measure -and $measure.Sum) { $thumbBytes += [double]$measure.Sum }
        } catch {}
    }
    $sizes["ThumbCache"] = $thumbBytes

    # 6. Caché DNS
    $sizes["DnsCache"] = 0
    try {
        $dnsCount = (Get-DnsClientCache -ErrorAction SilentlyContinue | Measure-Object).Count
        $sizes["DnsCache"] = $dnsCount * 1024 # Estimación simbólica (1KB por registro)
    } catch {}

    return $sizes
}

function Invoke-SystemCleaning {
    param(
        [string[]]$Targets = @('UserTemp', 'WinTemp', 'UpdateCache', 'RecycleBin', 'ThumbCache', 'DnsCache')
    )

    Write-Host "`n=======================================================" -ForegroundColor Cyan
    Write-Host "       WinTool - Limpieza Profunda de Sistema" -ForegroundColor White
    Write-Host "=======================================================" -ForegroundColor Cyan

    $totalFreed = 0
    $filesCount = 0

    # Helper para borrar archivos de una carpeta
    function Remove-SafeFiles {
        param([string]$Path, [string]$Title)
        if (-not (Test-Path $Path)) { return 0 }
        Write-Host "`n[INFO] Limpiando: $Title..." -ForegroundColor Cyan
        $freedHere = 0
        $countHere = 0
        $items = Get-ChildItem -Path $Path -Force -ErrorAction SilentlyContinue
        foreach ($item in $items) {
            try {
                if ($item.PSIsContainer) {
                    $itemSize = (Get-ChildItem -Path $item.FullName -Recurse -Force -File -ErrorAction SilentlyContinue |
                                 Measure-Object -Property Length -Sum).Sum
                    Remove-Item -Path $item.FullName -Recurse -Force -ErrorAction Stop
                    if ($itemSize) { $freedHere += $itemSize }
                    $countHere++
                } else {
                    $itemSize = $item.Length
                    Remove-Item -Path $item.FullName -Force -ErrorAction Stop
                    if ($itemSize) { $freedHere += $itemSize }
                    $countHere++
                }
            } catch {
                # Archivo o carpeta en uso por el sistema o alguna aplicación activa, se omite de forma segura
            }
        }
        $formatted = Format-SizeString -Bytes $freedHere
        Write-Host "  [ OK ] $Title limpio: $formatted liberados ($countHere elementos eliminados)." -ForegroundColor Green
        $script:totalFreed += $freedHere
        $script:filesCount += $countHere
    }

    if ($Targets -contains "UserTemp") {
        Remove-SafeFiles -Path ([System.IO.Path]::GetTempPath()) -Title "Archivos Temporales de Usuario"
    }

    if ($Targets -contains "WinTemp") {
        Remove-SafeFiles -Path "$env:SystemRoot\Temp" -Title "Archivos Temporales de Windows"
    }

    if ($Targets -contains "UpdateCache") {
        Stop-Service -Name "wuauserv" -Force -ErrorAction SilentlyContinue
        Remove-SafeFiles -Path "$env:SystemRoot\SoftwareDistribution\Download" -Title "Caché de descargas de Windows Update"
        Start-Service -Name "wuauserv" -ErrorAction SilentlyContinue
    }

    if ($Targets -contains "RecycleBin") {
        Write-Host "`n[INFO] Vaciando Papelera de Reciclaje..." -ForegroundColor Cyan
        try {
            Clear-RecycleBin -Force -ErrorAction SilentlyContinue
            Write-Host "  [ OK ] Papelera de reciclaje vaciada correctamente." -ForegroundColor Green
        } catch {
            Write-Host "  [WARN] No se pudo vaciar la papelera por completo: $($_.Exception.Message)" -ForegroundColor Yellow
        }
    }

    if ($Targets -contains "ThumbCache") {
        Remove-SafeFiles -Path "$env:LOCALAPPDATA\Microsoft\Windows\WER" -Title "Reportes de Error de Windows (WER)"
        Write-Host "`n[INFO] Limpiando Caché de Miniaturas..." -ForegroundColor Cyan
        try {
            Get-ChildItem -Path "$env:LOCALAPPDATA\Microsoft\Windows\Explorer" -Filter "thumbcache_*.db" -Force -ErrorAction SilentlyContinue |
                Remove-Item -Force -ErrorAction SilentlyContinue
            Write-Host "  [ OK ] Caché de miniaturas depurada." -ForegroundColor Green
        } catch {}
    }

    if ($Targets -contains "DnsCache") {
        Write-Host "`n[INFO] Limpiando Caché DNS del Sistema..." -ForegroundColor Cyan
        try {
            Clear-DnsClientCache -ErrorAction SilentlyContinue
            ipconfig /flushdns | Out-Null
            Write-Host "  [ OK ] Caché DNS limpiada exitosamente." -ForegroundColor Green
        } catch {
            ipconfig /flushdns | Out-Null
            Write-Host "  [ OK ] Caché DNS limpiada." -ForegroundColor Green
        }
    }

    $totalFormatted = Format-SizeString -Bytes $totalFreed
    Write-Host "`n=======================================================" -ForegroundColor Cyan
    Write-Host " RESUMEN FINAL: Se liberaron $totalFormatted en total." -ForegroundColor White
    Write-Host " Total de elementos eliminados: $filesCount" -ForegroundColor Gray
    Write-Host "=======================================================" -ForegroundColor Cyan

    Read-Host "`nPresiona Enter para cerrar"
}
