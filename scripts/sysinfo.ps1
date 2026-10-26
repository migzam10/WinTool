function Get-SystemDashboardInfo {
    $info = [ordered]@{}

    # 1. Sistema Operativo
    try {
        $regNT = Get-ItemProperty -Path "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion" -ErrorAction SilentlyContinue
        $osName = $regNT.ProductName
        $dispVer = $regNT.DisplayVersion
        if (-not $dispVer) { $dispVer = $regNT.ReleaseId }
        $build = $regNT.CurrentBuildNumber
        
        # Windows 11 a veces se reporta como Windows 10 en ProductName para compatibilidad
        if ($build -ge 22000 -and $osName -match "Windows 10") {
            $osName = $osName -replace "Windows 10", "Windows 11"
        }
        
        $arch = if ([Environment]::Is64BitOperatingSystem) { "64-bit" } else { "32-bit" }
        $info["OS"] = "$osName $dispVer ($arch, Build $build)"
    } catch {
        $info["OS"] = "Windows ($([Environment]::OSVersion.VersionString))"
    }

    # 2. Procesador (CPU)
    try {
        $cpuReg = Get-ItemProperty -Path "HKLM:\HARDWARE\DESCRIPTION\System\CentralProcessor\0" -ErrorAction SilentlyContinue
        $cpuName = ($cpuReg.ProcessorNameString).Trim()
        # Limpiar espacios repetidos
        $cpuName = ($cpuName -replace '\s+', ' ')
        $info["CPU"] = $cpuName
    } catch {
        $info["CPU"] = "Procesador x86/x64"
    }

    # 3. Memoria RAM
    try {
        $osCim = Get-CimInstance Win32_OperatingSystem -ErrorAction SilentlyContinue
        if ($osCim) {
            $totalRamGB = [Math]::Round($osCim.TotalVisibleMemorySize / 1MB, 1)
            $freeRamGB = [Math]::Round($osCim.FreePhysicalMemory / 1MB, 1)
            $usedRamGB = [Math]::Round($totalRamGB - $freeRamGB, 1)
            $pctFree = [Math]::Round(($freeRamGB / $totalRamGB) * 100)
            $info["RAM"] = "$usedRamGB GB / $totalRamGB GB ($pctFree% libre)"
        } else {
            $info["RAM"] = "Memoria no determinada"
        }
    } catch {
        $info["RAM"] = "RAM del Sistema"
    }

    # 4. Almacenamiento en Disco C:
    try {
        $drive = [System.IO.DriveInfo]::new('C')
        if ($drive.IsReady) {
            $freeGB = [Math]::Round($drive.TotalFreeSpace / 1GB, 1)
            $totalGB = [Math]::Round($drive.TotalSize / 1GB, 1)
            $pctFree = [Math]::Round(($drive.TotalFreeSpace / $drive.TotalSize) * 100)
            $info["DiskC"] = "$freeGB GB libres de $totalGB GB ($pctFree% disp.)"
        } else {
            $info["DiskC"] = "Unidad C: no lista"
        }
    } catch {
        $info["DiskC"] = "Disco C:"
    }

    return $info
}
