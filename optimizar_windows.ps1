# ════════════════════════════════════════════════════════════════
#  OPTIMIZADOR PROFESIONAL DE WINDOWS v6.0 PRO EDITION
#  Servicios · Registro · Red · Bloatware · Tweaks Avanzados
#  Compatible: Windows 10 (1903+) / Windows 11
#  Requiere: PowerShell 5.1+ · Ejecutar como Administrador
# ════════════════════════════════════════════════════════════════
#  Autor: yo
#  GitHub: https://github.com/FacuxD23/-
#  Licencia: MIT
# ════════════════════════════════════════════════════════════════
#
#  PARÁMETROS DE LÍNEA DE COMANDO:
#  .\optimizar_windows.ps1 -Gaming          # Perfil gaming
#  .\optimizar_windows.ps1 -Privacy         # Perfil privacidad
#  .\optimizar_windows.ps1 -Performance     # Perfil rendimiento
#  .\optimizar_windows.ps1 -Safe            # Modo seguro
#  .\optimizar_windows.ps1 -Aggressive      # Modo agresivo
#  .\optimizar_windows.ps1 -Restore         # Restaurar cambios
#  .\optimizar_windows.ps1 -Silent          # Sin preguntas
#
# ════════════════════════════════════════════════════════════════

#Requires -RunAsAdministrator

[CmdletBinding()]
param(
    [Parameter(HelpMessage="Perfil gaming (FPS máximo, latencia mínima)")]
    [switch]$Gaming,
    
    [Parameter(HelpMessage="Perfil privacidad (telemetría off, anti-tracking)")]
    [switch]$Privacy,
    
    [Parameter(HelpMessage="Perfil rendimiento puro (CPU/RAM optimizado)")]
    [switch]$Performance,
    
    [Parameter(HelpMessage="Modo seguro (solo tweaks reversibles)")]
    [switch]$Safe,
    
    [Parameter(HelpMessage="Modo agresivo (máxima optimización, más riesgo)")]
    [switch]$Aggressive,
    
    [Parameter(HelpMessage="Restaurar cambios previos del optimizador")]
    [switch]$Restore,
    
    [Parameter(HelpMessage="Modo silencioso (sin preguntas, usa defaults)")]
    [switch]$Silent,
    
    [Parameter(HelpMessage="Crear backup completo antes de aplicar")]
    [switch]$Backup
)

# ════════════════════════════════════════════════════════════════
#  MODO RESTORE
# ════════════════════════════════════════════════════════════════

if ($Restore) {
    Write-Host ""
    Write-Host "  ════════════════════════════════════════════════════════════════" -ForegroundColor Cyan
    Write-Host "  MODO RESTAURACIÓN - Revertir cambios del optimizador" -ForegroundColor Cyan
    Write-Host "  ════════════════════════════════════════════════════════════════" -ForegroundColor Cyan
    Write-Host ""
    
    # Buscar backups de registro
    $backups = Get-ChildItem "C:\OptimizadorBackup_*.reg" -EA SilentlyContinue
    
    if ($backups.Count -eq 0) {
        Write-Host "  [!] No se encontraron backups de registro" -ForegroundColor Yellow
    } else {
        Write-Host "  Backups encontrados: $($backups.Count)" -ForegroundColor Green
        foreach ($b in $backups) {
            Write-Host "  - $($b.Name)" -ForegroundColor Gray
        }
        Write-Host ""
        $restore = Read-Host "  Restaurar todos los backups? (s/N)"
        if ($restore -eq "s") {
            foreach ($b in $backups) {
                reg import $b.FullName 2>&1 | Out-Null
                Write-Host "  [✓] Restaurado: $($b.Name)" -ForegroundColor Green
            }
        }
    }
    
    # Buscar puntos de restauración
    Write-Host ""
    Write-Host "  Puntos de restauración disponibles:" -ForegroundColor Cyan
    Get-ComputerRestorePoint | Where-Object { $_.Description -like "*Optimizador*" } | ForEach-Object {
        Write-Host "  - $($_.Description) - $($_.CreationTime)" -ForegroundColor Gray
    }
    
    Write-Host ""
    Write-Host "  Para restaurar desde punto de restauración:" -ForegroundColor Yellow
    Write-Host "  1. Abre 'Crear punto de restauración' desde el menú Inicio" -ForegroundColor Gray
    Write-Host "  2. Click en 'Restaurar sistema'" -ForegroundColor Gray
    Write-Host "  3. Selecciona el punto 'Optimizador Windows v6.0'" -ForegroundColor Gray
    Write-Host ""
    Read-Host "  Presiona ENTER para salir"
    exit 0
}

# ════════════════════════════════════════════════════════════════
#  CONFIGURACIÓN INICIAL
# ════════════════════════════════════════════════════════════════

# Modo estricto
Set-StrictMode -Version 2.0
$ErrorActionPreference = "Stop"
$ProgressPreference = "SilentlyContinue"

# Variables script-level
$script:TempParaLimpiar = New-Object System.Collections.Generic.List[string]
$script:Riesgos = New-Object System.Collections.Generic.List[string]
$script:Aplicados = 0
$script:Omitidos = 0
$script:LogFile = "$env:ProgramData\OptimizadorWindows_v6.log"
$script:Stopwatch = [System.Diagnostics.Stopwatch]::StartNew()
$script:BackupFolder = "C:\OptimizadorBackups"

# Constantes de registro
$script:HKLM_System = "HKLM:\SYSTEM\CurrentControlSet"
$script:HKLM_Software = "HKLM:\SOFTWARE"
$script:HKCU_Software = "HKCU:\Software"
$script:HKCU_Explorer = "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer"

# Determinar modo de operación según parámetros
$script:ModoSeguro = $Safe
$script:ModoAgresivo = $Aggressive
$script:ModoSilencioso = $Silent

# Si no se especificó modo, usar interactivo normal
if (-not $Safe -and -not $Aggressive) {
    $script:ModoSeguro = $false
    $script:ModoAgresivo = $false
}

# ════════════════════════════════════════════════════════════════
#  VERIFICACIONES INICIALES
# ════════════════════════════════════════════════════════════════

# Verificar PowerShell 5.1+
if ($PSVersionTable.PSVersion.Major -lt 5) {
    Write-Host ""
    Write-Host "  ════════════════════════════════════════════════════════════════" -ForegroundColor Red
    Write-Host "  [✗] ERROR: PowerShell 5.1 o superior requerido" -ForegroundColor Red
    Write-Host "  Tu version: $($PSVersionTable.PSVersion)" -ForegroundColor Yellow
    Write-Host "  Descarga: https://aka.ms/powershell" -ForegroundColor Cyan
    Write-Host "  ════════════════════════════════════════════════════════════════" -ForegroundColor Red
    Write-Host ""
    Read-Host "  Presiona ENTER para salir"
    exit 1
}

# Verificar que NO sea Windows Server
$osInfo = Get-CimInstance -ClassName Win32_OperatingSystem
if ($osInfo.ProductType -ne 1) {
    Write-Host ""
    Write-Host "  ════════════════════════════════════════════════════════════════" -ForegroundColor Red
    Write-Host "  [✗] ERROR: Este script NO debe usarse en Windows Server" -ForegroundColor Red
    Write-Host "  ════════════════════════════════════════════════════════════════" -ForegroundColor Red
    Write-Host ""
    Read-Host "  Presiona ENTER para salir"
    exit 1
}

# Verificar que sea Windows 10 o 11
$buildNumber = [int](Get-ItemProperty "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion").CurrentBuildNumber
if ($buildNumber -lt 10240) {
    Write-Host ""
    Write-Host "  ════════════════════════════════════════════════════════════════" -ForegroundColor Red
    Write-Host "  [✗] ERROR: Este script requiere Windows 10 (build 10240+) o Windows 11" -ForegroundColor Red
    Write-Host "  Tu build: $buildNumber" -ForegroundColor Yellow
    Write-Host "  ════════════════════════════════════════════════════════════════" -ForegroundColor Red
    Write-Host ""
    Read-Host "  Presiona ENTER para salir"
    exit 1
}

# ════════════════════════════════════════════════════════════════
#  FUNCIONES DE LOGGING
# ════════════════════════════════════════════════════════════════

function Write-Log {
    param([string]$Message, [string]$Level = "INFO")
    try {
        $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
        $logLine = "[$timestamp] [$Level] $Message"
        Add-Content -Path $script:LogFile -Value $logLine -EA Stop
    } catch {
        # Si falla el log, no romper el script
    }
}

# ════════════════════════════════════════════════════════════════
#  FUNCIONES DE UI
# ════════════════════════════════════════════════════════════════

function Write-Banner {
    Clear-Host
    Write-Host ""
    Write-Host "  ════════════════════════════════════════════════════════════════" -ForegroundColor Cyan
    Write-Host "    ██╗    ██╗██╗███╗   ██╗   ██████╗  ██████╗  ████████╗" -ForegroundColor White
    Write-Host "    ██║    ██║██║████╗  ██║  ██╔═══██ ╗██╔══██╗ ╚══██╔══╝" -ForegroundColor White
    Write-Host "    ██║ █╗ ██║██║██╔██╗ ██  ║██║   ██ ║██████╔╝   ██║   " -ForegroundColor White
    Write-Host "    ██║███╗██║██║██║╚██╗██  ║██║   ██ ║██╔═══╝    ██║   " -ForegroundColor White
    Write-Host "    ╚███╔███╔╝██║██║ ╚████  ║╚██████╔╝██║        ██║   " -ForegroundColor White
    Write-Host "     ╚══╝╚══╝ ╚═╝╚═╝  ╚═══╝ ╚═════╝ ╚═╝         ╚═╝   " -ForegroundColor White
    Write-Host ""
    Write-Host "         mi optimizador" -ForegroundColor Cyan
    Write-Host "    Tweaks Avanzados · Kernel · Red · Gaming · Limpieza" -ForegroundColor DarkCyan
    
    # Mostrar modo activo
    if ($script:ModoSeguro) {
        Write-Host "                    [MODO SEGURO ACTIVADO]" -ForegroundColor Green
    } elseif ($script:ModoAgresivo) {
        Write-Host "                  [MODO AGRESIVO ACTIVADO]" -ForegroundColor Red
    }
    
    Write-Host "  ════════════════════════════════════════════════════════════════" -ForegroundColor Cyan
    Write-Host ""
}

function Write-Header {
    param([string]$Letter, [string]$Title, [string]$Color = "Cyan")
    Write-Host ""
    Write-Host "  ════════════════════════════════════════════════════════════════" -ForegroundColor $Color
    Write-Host "  [$Letter] $Title" -ForegroundColor $Color
    Write-Host "  ════════════════════════════════════════════════════════════════" -ForegroundColor $Color
}

function Write-Sub {
    param([string]$T)
    Write-Host ""
    Write-Host "  ─── $T ───" -ForegroundColor DarkCyan
}

function Write-OK   { 
    param([string]$M)
    Write-Host "  [✓]  $M" -ForegroundColor Green
    Write-Log $M "OK"
    $script:Aplicados++
}

function Write-OFF  { 
    param([string]$M)
    Write-Host "  [■]  $M" -ForegroundColor Green
    Write-Log $M "OFF"
    $script:Aplicados++
}

function Write-MAN  { 
    param([string]$M)
    Write-Host "  [~]  $M" -ForegroundColor Yellow
    Write-Log $M "MANUAL"
    $script:Aplicados++
}

function Write-SKIP { 
    param([string]$M)
    Write-Host "  [─]  $M" -ForegroundColor DarkGray
    Write-Log $M "SKIP"
    $script:Omitidos++
}

function Write-WARN { 
    param([string]$M)
    Write-Host "  [!]  $M" -ForegroundColor Yellow
    Write-Log $M "WARN"
}

function Write-ERR  { 
    param([string]$M)
    Write-Host "  [✗]  $M" -ForegroundColor Red
    Write-Log $M "ERROR"
}

function Write-INFO { 
    param([string]$M)
    Write-Host "  [i]  $M" -ForegroundColor Cyan
    Write-Log $M "INFO"
}

function Ask-YN {
    param([string]$Q, [string]$Default = "n")
    
    # Si modo silencioso, usar default siempre
    if ($script:ModoSilencioso) {
        return ($Default -eq "s")
    }
    
    $def = if ($Default -eq "s") { "(S/n)" } else { "(s/N)" }
    $r = Read-Host "  >> $Q $def"
    if ($r -eq "") { $r = $Default }
    return ($r -eq "s" -or $r -eq "S")
}

# ════════════════════════════════════════════════════════════════
#  CONFIGURACIÓN INICIAL
# ════════════════════════════════════════════════════════════════

Set-StrictMode -Version 2.0
$ErrorActionPreference = "Stop"
$ProgressPreference    = "SilentlyContinue"

# Variables script-level
$script:TempParaLimpiar = New-Object System.Collections.Generic.List[string]
$script:Riesgos         = New-Object System.Collections.Generic.List[string]
$script:Aplicados       = 0
$script:Omitidos        = 0
$script:LogFile         = "$env:ProgramData\OptimizadorWindows_v6_PRO.log"
$script:Stopwatch       = [System.Diagnostics.Stopwatch]::StartNew()
$script:BackupDir       = "C:\OptimizadorBackups"

# Modos de operación
$script:ModoSeguro    = $Safe
$script:ModoAgresivo  = $Aggressive
$script:ModoSilencio  = $Silent

# Perfil seleccionado
$script:PerfilActivo = if ($Gaming) { "Gaming" } 
                       elseif ($Privacy) { "Privacy" }
                       elseif ($Performance) { "Performance" }
                       else { "Interactive" }

# Constantes de registro
$script:HKLM_System   = "HKLM:\SYSTEM\CurrentControlSet"
$script:HKLM_Software = "HKLM:\SOFTWARE"
$script:HKCU_Software = "HKCU:\SOFTWARE"
$script:HKCU_Explorer = "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer"

# ════════════════════════════════════════════════════════════════
#  VERIFICACIONES PRE-EJECUCIÓN
# ════════════════════════════════════════════════════════════════

# PowerShell 5.1+
if ($PSVersionTable.PSVersion.Major -lt 5) {
    Write-Host "[✗] Se requiere PowerShell 5.1 o superior" -ForegroundColor Red
    exit 1
}

# NO Windows Server
$osInfo = Get-CimInstance -ClassName Win32_OperatingSystem
if ($osInfo.ProductType -ne 1) {
    Write-Host "[✗] Este script NO debe usarse en Windows Server" -ForegroundColor Red
    exit 1
}

# Windows 10 build 10240+ o Windows 11
$buildNumber = [int](Get-ItemProperty "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion").CurrentBuildNumber
if ($buildNumber -lt 10240) {
    Write-Host "[✗] Se requiere Windows 10 (build 10240+) o Windows 11" -ForegroundColor Red
    Write-Host "Tu build: $buildNumber" -ForegroundColor Yellow
    exit 1
}

# Crear directorio de backups
if ($Backup -and -not (Test-Path $script:BackupDir)) {
    try {
        New-Item -Path $script:BackupDir -ItemType Directory -Force | Out-Null
    } catch {
        Write-Host "[!] No se pudo crear directorio de backups: $script:BackupDir" -ForegroundColor Yellow
    }
}

# ════════════════════════════════════════════════════════════════
#  FUNCIONES DE SISTEMA
# ════════════════════════════════════════════════════════════════

function Disable-Svc {
    param([string]$Name, [string]$Desc, [string]$Riesgo = "")
    
    try {
        $svc = Get-Service -Name $Name -ErrorAction SilentlyContinue
        if ($svc) {
            if ($svc.Status -ne "Stopped") {
                Stop-Service -Name $Name -Force -ErrorAction SilentlyContinue | Out-Null
            }
            Set-Service -Name $Name -StartupType Disabled -ErrorAction SilentlyContinue
            Write-OFF "$Desc ($Name)"
            if ($Riesgo) { 
                $riesgoMsg = "  [!] " + $Desc + ": " + $Riesgo
                $script:Riesgos.Add($riesgoMsg)
            }
        } else {
            Write-SKIP "Servicio no encontrado: $Name"
        }
    } catch {
        Write-ERR "Error al deshabilitar $Name: $($_.Exception.Message)"
    }
}

function Set-Manual {
    param([string]$Name, [string]$Desc)
    
    try {
        $svc = Get-Service -Name $Name -ErrorAction SilentlyContinue
        if ($svc) {
            Set-Service -Name $Name -StartupType Manual -ErrorAction SilentlyContinue
            Write-MAN "$Desc ($Name)"
        } else {
            Write-SKIP "Servicio no encontrado: $Name"
        }
    } catch {
        Write-ERR "Error al configurar $Name: $($_.Exception.Message)"
    }
}

function Set-Reg {
    param([string]$Path, [string]$Name, $Value, [string]$Type = "DWord")
    
    try {
        if (-not (Test-Path $Path)) {
            New-Item -Path $Path -Force | Out-Null
        }
        
        $current = Get-ItemProperty -Path $Path -Name $Name -EA SilentlyContinue
        if ($current.$Name -ne $Value) {
            Set-ItemProperty -Path $Path -Name $Name -Value $Value -Type $Type -EA Stop
            Write-Log "Registry: $Path\$Name = $Value" "REG"
            return $true
        }
        return $false
    } catch {
        Write-Log "Error registry $Path\$Name : $($_.Exception.Message)" "ERROR"
        return $false
    }

# ════════════════════════════════════════════════════════════════
#  LÓGICA DE PERFILES - APLICAR SEGÚN MODO
# ════════════════════════════════════════════════════════════════

# Determinar gama y uso según perfil
if ($script:PerfilActivo -eq "Gaming") {
    $gama = if ($sys.RAM -ge 16 -and ($sys.IsSSD -or $sys.IsNVMe)) { 1 } elseif ($sys.RAM -ge 8) { 2 } else { 3 }
    $uso = 2  # Gaming
    $gamaStr = @{1="ALTA"; 2="MEDIA"; 3="BAJA"}[$gama]
    $usoStr = "GAMING"
    Write-INFO "Perfil Gaming detectado automáticamente: Gama $gamaStr"
    
} elseif ($script:PerfilActivo -eq "Privacy") {
    $gama = 2  # Media por defecto
    $uso = 4   # Mixto
    $gamaStr = "MEDIA"
    $usoStr = "PRIVACIDAD"
    Write-INFO "Perfil Privacy: se priorizará desactivar telemetría"
    
} elseif ($script:PerfilActivo -eq "Performance") {
    $gama = if ($sys.RAM -ge 16) { 1 } else { 2 }
    $uso = 4  # Mixto
    $gamaStr = @{1="ALTA"; 2="MEDIA"}[$gama]
    $usoStr = "PERFORMANCE"
    Write-INFO "Perfil Performance: máxima optimización CPU/RAM"
    
} else {
    # Modo interactivo - preguntar como siempre
    if (-not $script:ModoSilencio) {
        Write-Header "1" "PERFIL: GAMA DE LA PC"
        Write-Host ""
        Write-Host "   [1] ALTA   - i7/i9/Ryzen 7-9, 16GB+ RAM, SSD NVMe" -ForegroundColor Green
        Write-Host "   [2] MEDIA  - i5/Ryzen 5, 8-16GB RAM, SSD o HDD" -ForegroundColor Yellow
        Write-Host "   [3] BAJA   - i3/Celeron/Pentium, 4-8GB, HDD" -ForegroundColor Red
        Write-Host ""
        do { $gi = Read-Host "  Selecciona 1, 2 o 3" } while ($gi -notmatch "^[123]$")
        $gama = [int]$gi
        $gamaStr = @{1="ALTA"; 2="MEDIA"; 3="BAJA"}[$gama]
        
        Write-Header "2" "PERFIL: USO PRINCIPAL"
        Write-Host ""
        Write-Host "   [1] OFICINA    - Word, Excel, navegador, correo" -ForegroundColor Cyan
        Write-Host "   [2] GAMING     - Juegos, alto rendimiento, baja latencia" -ForegroundColor Magenta
        Write-Host "   [3] STREAMING  - OBS, grabacion, edicion de video" -ForegroundColor Blue
        Write-Host "   [4] MIXTO      - Varios usos" -ForegroundColor White
        Write-Host ""
        do { $ui = Read-Host "  Selecciona 1, 2, 3 o 4" } while ($ui -notmatch "^[1234]$")
        $uso = [int]$ui
        $usoStr = @{1="OFICINA"; 2="GAMING"; 3="STREAMING"; 4="MIXTO"}[$uso]
    } else {
        # Modo silencioso - auto-detectar
        $gama = if ($sys.RAM -ge 16 -and ($sys.IsSSD -or $sys.IsNVMe)) { 1 } elseif ($sys.RAM -ge 8) { 2 } else { 3 }
        $uso = 4
        $gamaStr = @{1="ALTA"; 2="MEDIA"; 3="BAJA"}[$gama]
        $usoStr = "MIXTO"
    }
}

Write-Host ""
Write-Host "  ════════════════════════════════════════════════════════════════" -ForegroundColor Cyan
Write-Host "  Perfil configurado: Gama $gamaStr | Uso $usoStr" -ForegroundColor White
Write-Host "  ════════════════════════════════════════════════════════════════" -ForegroundColor Cyan
Write-Host ""
Start-Sleep -Seconds 1

    $diskType = $disk.MediaType
    
    $isHDD = $diskType -eq "HDD"
    $isSSD = $diskType -eq "SSD"
    $isNVMe = $diskType -eq "SCM" -or $diskModel -like "*NVMe*" -or $diskModel -like "*PCIe*"
    
    # Si no detectó bien, usar método alternativo
    if (-not $isHDD -and -not $isSSD -and -not $isNVMe) {
        $busType = $disk.BusType
        if ($busType -eq "NVMe") {
            $isNVMe = $true
            $isSSD = $false
        } elseif ($busType -eq "SATA" -or $busType -eq "SAS") {
            # Asumir SSD si tiene TRIM
            $vol = Get-Volume -DriveLetter C -EA SilentlyContinue
            if ($vol -and $vol.FileSystemType -eq "NTFS") {
                $isSSD = $true
            } else {
                $isHDD = $true
            }
        }
    }
    
    $diskStr = if ($isNVMe) { "NVMe SSD" } elseif ($isSSD) { "SSD" } else { "HDD" }
    
    # GPU
    $gpu = Get-CimInstance Win32_VideoController | 
           Where-Object { $_.Name -notlike "*Microsoft*" -and $_.Name -notlike "*Basic*" } |
           Select-Object -First 1
    $gpuName = if ($gpu) { $gpu.Name.Trim() } else { "Integrada" }
    
    # Laptop vs Desktop - Detección mejorada
    $chassis = Get-CimInstance Win32_SystemEnclosure | Select-Object -First 1
    $chassisTypes = $chassis.ChassisTypes
    
    # ChassisTypes:
    # 3 = Desktop, 4 = Low Profile Desktop, 5 = Pizza Box, 6 = Mini Tower, 7 = Tower
    # 8 = Portable, 9 = Laptop, 10 = Notebook, 11 = Hand Held, 14 = Sub Notebook, 30 = Tablet, 31 = Convertible
    $laptopTypes = @(8, 9, 10, 11, 14, 30, 31)
    $isLaptop = $chassisTypes | Where-Object { $laptopTypes -contains $_ }
    $isDesktop = -not $isLaptop
    
    # Verificación adicional: batería
    $battery = Get-CimInstance Win32_Battery -EA SilentlyContinue
    if ($battery) { $isLaptop = $true; $isDesktop = $false }
    
    $formFactor = if ($isLaptop) { "Laptop" } else { "Desktop" }
    
    # Espacio en disco
    $vol = Get-Volume -DriveLetter C
    $freeGB = [math]::Round($vol.SizeRemaining / 1GB, 1)
    $totalGB = [math]::Round($vol.Size / 1GB, 1)
    $usedGB = $totalGB - $freeGB
    
    # Uptime
    $uptime = (Get-Date) - $osInfo.LastBootUpTime
    $uptimeStr = "{0}d {1}h {2}m" -f $uptime.Days, $uptime.Hours, $uptime.Minutes
    
    # Crear objeto con toda la info
    $sysInfo = [PSCustomObject]@{
        WinName = $osInfo.Caption
        WinVer = $winVer.DisplayVersion
        Build = $build
        UBR = $ubr
        BuildStr = "$build.$ubr"
        IsWin11 = $isWin11
        IsWin10 = $isWin10
        
        CPU = $cpuName
        CPUCores = $cpuCores
        CPUThreads = $cpuThreads
        
        RAM = $ramGB
        RAMStr = "$ramGB GB"
        
        Disk = $diskModel
        IsHDD = $isHDD
        IsSSD = $isSSD
        IsNVMe = $isNVMe
        DiskType = $diskStr
        
        GPU = $gpuName
        
        IsLaptop = $isLaptop
        IsDesktop = $isDesktop
        FormFactor = $formFactor
        
        Uptime = $uptimeStr
        FreeGB = $freeGB
        UsedGB = $usedGB
        TotalGB = $totalGB
    }
    
    # Mostrar panel de sistema
    Write-Host "  ╔══════════════════════════════════════════════════════════════╗" -ForegroundColor Cyan
    Write-Host "  ║  INFORMACIÓN DEL SISTEMA                                     ║" -ForegroundColor Cyan
    Write-Host "  ╠══════════════════════════════════════════════════════════════╣" -ForegroundColor Cyan
    Write-Host "  ║  OS:          $($sysInfo.WinName.PadRight(47)) ║" -ForegroundColor White
    Write-Host "  ║  Build:       $($sysInfo.BuildStr.PadRight(47)) ║" -ForegroundColor White
    Write-Host "  ║  Form Factor: $($sysInfo.FormFactor.PadRight(47)) ║" -ForegroundColor $(if($isLaptop){"Yellow"}else{"Green"})
    Write-Host "  ║" -ForegroundColor Cyan
    Write-Host "  ║  CPU:         $($sysInfo.CPU.PadRight(47)) ║" -ForegroundColor White
    Write-Host "  ║  Cores:       $($cpuCores) cores / $($cpuThreads) threads".PadRight(60) + "║" -ForegroundColor White
    Write-Host "  ║  RAM:         $($sysInfo.RAMStr.PadRight(47)) ║" -ForegroundColor White
    Write-Host "  ║  Disco:       $($diskStr) - $($diskModel.Substring(0, [Math]::Min(40, $diskModel.Length))).PadRight(40) ║" -ForegroundColor $(if($isNVMe){"Green"}elseif($isSSD){"Yellow"}else{"Red"})
    Write-Host "  ║  GPU:         $($sysInfo.GPU.Substring(0, [Math]::Min(47, $sysInfo.GPU.Length)).PadRight(47)) ║" -ForegroundColor White
    Write-Host "  ║" -ForegroundColor Cyan
    Write-Host "  ║  Uptime:      $($sysInfo.Uptime.PadRight(47)) ║" -ForegroundColor Gray
    Write-Host "  ║  Disco C:     $($freeGB) GB libres / $($totalGB) GB total".PadRight(60) + "║" -ForegroundColor Gray
    Write-Host "  ╚══════════════════════════════════════════════════════════════╝" -ForegroundColor Cyan
    Write-Host ""
    
    # Advertencias basadas en hardware
    if ($isHDD) {
        Write-Host "  [!] HDD detectado: algunos tweaks se ajustaran automaticamente" -ForegroundColor Yellow
    }
    
    if ($isLaptop) {
        Write-Host "  [!] Laptop detectado: tweaks de energia se ajustaran" -ForegroundColor Yellow
        Write-Host "  [!] Algunos tweaks agresivos se saltaran automaticamente" -ForegroundColor Yellow
    }
    
    if ($ramGB -lt 8) {
        Write-Host "  [!] RAM baja (<8GB): Memory Compression se mantendra activa" -ForegroundColor Yellow
    }
    
    if ($build -lt 19041) {
        Write-Host "  [!] Build antiguo: actualiza a Windows 10 20H1 o superior" -ForegroundColor Yellow
    }
    
    Write-Host ""
    Start-Sleep -Seconds 2
    
    return $sysInfo
}


# ════════════════════════════════════════════════════════════════
#  INICIO DEL SCRIPT
# ════════════════════════════════════════════════════════════════

# Detección de sistema
$sys = Get-SystemInfo

# ════════════════════════════════════════════════════════════════
#  MANEJO DE PERFILES DE LÍNEA DE COMANDO
# ════════════════════════════════════════════════════════════════

if ($Gaming -or $Privacy -or $Performance) {
    Write-Host "  ════════════════════════════════════════════════════════════════" -ForegroundColor Magenta
    Write-Host "  MODO PERFIL ACTIVADO" -ForegroundColor Magenta
    Write-Host "  ════════════════════════════════════════════════════════════════" -ForegroundColor Magenta
    Write-Host ""
    
    if ($Gaming) {
        Write-Host "  [✓] Perfil GAMING activado" -ForegroundColor Green
        Write-Host "      - Optimizaciones de latencia" -ForegroundColor Gray
        Write-Host "      - Prioridad GPU/CPU maxima" -ForegroundColor Gray
        Write-Host "      - Network tweaks agresivos" -ForegroundColor Gray
        Write-Host "      - Game Mode ON" -ForegroundColor Gray
        $gama = 1  # Alta
        $uso = 2   # Gaming
    }
    
    if ($Privacy) {
        Write-Host "  [✓] Perfil PRIVACIDAD activado" -ForegroundColor Cyan
        Write-Host "      - Telemetria OFF" -ForegroundColor Gray
        Write-Host "      - Cortana/Bing OFF" -ForegroundColor Gray
        Write-Host "      - Publicidad OFF" -ForegroundColor Gray
        Write-Host "      - Rastreo OFF" -ForegroundColor Gray
        $gama = 2  # Media (por defecto)
        $uso = 1   # Oficina
    }
    
    if ($Performance) {
        Write-Host "  [✓] Perfil RENDIMIENTO activado" -ForegroundColor Yellow
        Write-Host "      - CPU/RAM optimizado" -ForegroundColor Gray
        Write-Host "      - Servicios minimizados" -ForegroundColor Gray
        Write-Host "      - Efectos visuales OFF" -ForegroundColor Gray
        Write-Host "      - Plan de energia Ultimate" -ForegroundColor Gray
        $gama = 1  # Alta
        $uso = 4   # Mixto
    }
    
    Write-Host ""
    $gamaStr = @{1="ALTA"; 2="MEDIA"; 3="BAJA"}[$gama]
    $usoStr = @{1="OFICINA"; 2="GAMING"; 3="STREAMING"; 4="MIXTO"}[$uso]
    
} else {
# ════════════════════════════════════════════════════════════════
#  PUNTO DE RESTAURACIÓN
# ════════════════════════════════════════════════════════════════

Write-Header "0" "PUNTO DE RESTAURACION DEL SISTEMA" "Yellow"
Write-Host ""
Write-Host "  Creando punto de restauracion del sistema..." -ForegroundColor Yellow
Write-Host "  Esto permite revertir cambios si algo sale mal." -ForegroundColor Gray
Write-Host ""

try {
    Write-INFO "Creando punto de restauracion (obligatorio)..."
    $restoreDesc = "Optimizador Windows v6.0 - $(Get-Date -Format 'yyyy-MM-dd HH:mm')"
    Checkpoint-Computer -Description $restoreDesc -RestorePointType "MODIFY_SETTINGS" -ErrorAction Stop
    Write-OK "Punto de restauracion creado correctamente"
    Write-Host ""
    Start-Sleep -Seconds 2
} catch {
    Write-Host ""
    Write-Host "  ════════════════════════════════════════════════════════════════" -ForegroundColor Red
    Write-Host "  [!] ADVERTENCIA: No se pudo crear punto de restauracion" -ForegroundColor Yellow
    Write-Host "  Razon: $($_.Exception.Message)" -ForegroundColor Gray
    Write-Host ""
    Write-Host "  Posibles causas:" -ForegroundColor Yellow
    Write-Host "  - System Restore deshabilitado en Windows" -ForegroundColor Gray
    Write-Host "  - Disco sin espacio suficiente" -ForegroundColor Gray
    Write-Host "  - Servicio VSS detenido" -ForegroundColor Gray
    Write-Host "  ════════════════════════════════════════════════════════════════" -ForegroundColor Red
    Write-Host ""
    Write-Host "  ╔══════════════════════════════════════════════════════════════╗" -ForegroundColor Red
    Write-Host "  ║  ⚠ SIN PUNTO DE RESTAURACION NO PODRAS REVERTIR CAMBIOS     ║" -ForegroundColor Red
    Write-Host "  ║  ⚠ TODOS LOS TWEAKS SERAN PERMANENTES                       ║" -ForegroundColor Red
    Write-Host "  ║  ⚠ CONTINUAS BAJO TU PROPIO RIESGO                          ║" -ForegroundColor Red
    Write-Host "  ╚══════════════════════════════════════════════════════════════╝" -ForegroundColor Red
    Write-Host ""
    $script:Riesgos.Add("  [!] CRITICO: NO se creo punto de restauracion - cambios irreversibles")
    Write-WARN "Continuando SIN punto de restauracion..."
    Start-Sleep -Seconds 3
}

# ════════════════════════════════════════════════════════════════
#  SELECCIÓN DE PERFIL
# ════════════════════════════════════════════════════════════════

Write-Header "1" "PERFIL: GAMA DE LA PC"
Write-Host ""
Write-Host "   [1] ALTA   - i7/i9/Ryzen 7-9, 16GB+ RAM, SSD NVMe" -ForegroundColor Green
Write-Host "   [2] MEDIA  - i5/Ryzen 5, 8-16GB RAM, SSD o HDD" -ForegroundColor Yellow
Write-Host "   [3] BAJA   - i3/Celeron/Pentium, 4-8GB, HDD" -ForegroundColor Red
Write-Host ""
do { $gi = Read-Host "  Selecciona 1, 2 o 3" } while ($gi -notmatch "^[123]$")
$gama    = [int]$gi
$gamaStr = @{1="ALTA"; 2="MEDIA"; 3="BAJA"}[$gama]
$gamaCol = @{1="Green"; 2="Yellow"; 3="Red"}[$gama]
Write-Host "  -> Gama $gamaStr seleccionada." -ForegroundColor $gamaCol
Write-Log "Gama seleccionada: $gamaStr" "INFO"

Write-Header "2" "PERFIL: USO PRINCIPAL"
Write-Host ""
Write-Host "   [1] OFICINA    - Word, Excel, navegador, correo" -ForegroundColor Cyan
Write-Host "   [2] GAMING     - Juegos, alto rendimiento, baja latencia" -ForegroundColor Magenta
Write-Host "   [3] STREAMING  - OBS, grabacion, edicion de video" -ForegroundColor Blue
Write-Host "   [4] MIXTO      - Varios usos" -ForegroundColor White
Write-Host ""
do { $ui = Read-Host "  Selecciona 1, 2, 3 o 4" } while ($ui -notmatch "^[1234]$")
$uso    = [int]$ui
$usoStr = @{1="OFICINA"; 2="GAMING"; 3="STREAMING"; 4="MIXTO"}[$uso]
Write-Log "Uso seleccionado: $usoStr" "INFO"

Write-Host ""
Write-Host "  ════════════════════════════════════════════════════════════════" -ForegroundColor Cyan
Write-Host "  Perfil configurado: Gama $gamaStr | Uso $usoStr" -ForegroundColor White
Write-Host "  ════════════════════════════════════════════════════════════════" -ForegroundColor Cyan
Write-Host ""
Start-Sleep -Seconds 1

# ════════════════════════════════════════════════════════════════
#  A. SERVICIOS BASE - TELEMETRÍA Y DIAGNÓSTICOS
# ════════════════════════════════════════════════════════════════

Write-Header "A" "SERVICIOS - TELEMETRIA Y DIAGNOSTICOS"
Disable-Svc "DiagTrack"           "Telemetria y experiencias del usuario"
Disable-Svc "WerSvc"              "Informe de errores de Windows"
Disable-Svc "wercplsupport"       "Soporte panel de errores"
Disable-Svc "wuqisvc"             "Insights de calidad Microsoft"
Disable-Svc "dmwappushservice"    "Mensajes WAP/push"
Disable-Svc "wisvc"               "Windows Insider Service"
Disable-Svc "diagnosticshub.standardcollector.service" "Diagnostics Hub Collector"
Disable-Svc "RetailDemo"          "Modo demo comercial"
Disable-Svc "GraphicsPerfSvc"     "Monitor rendimiento grafico"
Disable-Svc "PcaSvc"              "Asistente compatibilidad programas"
Set-Manual   "DPS"                "Directivas de diagnostico"
Set-Manual   "WdiSystemHost"      "Host sistema diagnostico"

Write-Sub "Xbox Live"
Disable-Svc "XblAuthManager"      "Autenticacion Xbox Live"
Disable-Svc "XblGameSave"         "Guardado Xbox Live"
Disable-Svc "XboxGipSvc"          "Xbox Accessory Management"
Disable-Svc "XboxNetApiSvc"       "Red Xbox Live"

Write-Sub "Acceso Remoto"
Disable-Svc "RemoteRegistry"      "Registro remoto" "Reactivar si necesitas acceso remoto al registro"
Disable-Svc "RemoteAccess"        "Enrutamiento y acceso remoto"
Disable-Svc "RasAuto"             "Conexiones automaticas RAS"
Disable-Svc "RasMan"              "Administrador conexiones RAS"
Disable-Svc "SstpSvc"             "Protocolo tunel SSTP"
Disable-Svc "seclogon"            "Inicio sesion secundario" "Algunos instaladores lo requieren"
Disable-Svc "SessionEnv"          "Configuracion Escritorio remoto"
Disable-Svc "UmRdpService"        "Redirector puerto RDP"

Write-Sub "Actualizadores de Navegadores"
Disable-Svc "edgeupdate"                    "Microsoft Edge Update"
Disable-Svc "edgeupdatem"                   "Microsoft Edge Update (m)"
Disable-Svc "MicrosoftEdgeElevationService" "Edge Elevation Service"
Disable-Svc "GoogleUpdaterInternalService"  "Google Updater interno"
Disable-Svc "GoogleUpdaterService"          "Google Updater"
Disable-Svc "GoogleChromeElevationService"  "Chrome Elevation Service"
Disable-Svc "brave"                         "Brave Update"
Disable-Svc "bravem"                        "Brave Update (m)"
Disable-Svc "BraveElevationService"         "Brave Elevation Service"

Write-Sub "Miscelaneos"
Disable-Svc "SSDPSRV"             "Deteccion SSDP (UPnP)"
Disable-Svc "upnphost"            "Host UPnP"
Disable-Svc "MapsBroker"          "Mapas descargados"
Disable-Svc "lfsvc"               "Geolocalizacion"
Disable-Svc "WalletService"       "Wallet Service"
Disable-Svc "SEMgrSvc"            "Pagos y NFC/SE"
Disable-Svc "WpcMonSvc"           "Control parental"
Disable-Svc "TrkWks"              "Seguimiento vinculos distribuidos"
Disable-Svc "Fax"                 "Servicio de Fax"
Disable-Svc "PhoneSvc"            "Servicio telefonico"
Disable-Svc "SmsRouter"           "Enrutador SMS"
Disable-Svc "shpamsvc"            "Shared PC Account Manager"
Disable-Svc "tzautoupdate"        "Actualizador zona horaria automatico"
Set-Manual   "wuauserv"           "Windows Update"
Set-Manual   "BITS"               "Transferencia inteligente"
Set-Manual   "DoSvc"              "Optimizacion de distribucion"

# ════════════════════════════════════════════════════════════════
#  SERVICIOS - PERFIL GAMA
# ════════════════════════════════════════════════════════════════

Write-Header "A" "SERVICIOS - PERFIL GAMA $gamaStr"

if ($gama -eq 3) {
    # Gama BAJA
    if ($sys.IsHDD) {
        Set-Manual "SysMain" "SysMain/Superfetch (Manual - util en HDD)"
    } else {
        Disable-Svc "SysMain" "SysMain/Superfetch" "Innecesario en SSD"
    }
    Disable-Svc "WSearch"         "Busqueda de Windows" "Instalar 'Everything' como reemplazo"
    Disable-Svc "defragsvc"       "Desfragmentador programado"
    $script:Riesgos.Add("  [!] Gama Baja: WSearch off - usar Everything como buscador")
    
} elseif ($gama -eq 2) {
    # Gama MEDIA
    if ($sys.IsHDD) {
        Set-Manual "SysMain" "SysMain (Manual - util en HDD)"
    } else {
        Set-Manual "SysMain" "SysMain (Manual - SSD no lo necesita activo)"
    }
    Set-Manual "WSearch"  "Busqueda de Windows"
    Disable-Svc "defragsvc" "Desfragmentador programado"
    
} else {
    # Gama ALTA
    Set-Manual "SysMain"  "SysMain (Manual)"
    Set-Manual "WSearch"  "Busqueda de Windows (Manual)"
    Disable-Svc "defragsvc" "Desfragmentador programado"
}

# ════════════════════════════════════════════════════════════════
#  SERVICIOS - PERFIL USO
# ════════════════════════════════════════════════════════════════

Write-Header "A" "SERVICIOS - PERFIL $usoStr"

if ($uso -eq 2) {
    # GAMING
    Set-Reg "$script:HKCU_Software\Microsoft\GameBar" "AllowAutoGameMode" 1
    Set-Reg "$script:HKCU_Software\Microsoft\GameBar" "AutoGameModeEnabled" 1
    Set-Reg "$script:HKCU_Software\Microsoft\Windows\CurrentVersion\GameDVR" "AppCaptureEnabled" 0
    Set-Reg "$script:HKLM_Software\Policies\Microsoft\Windows\GameDVR" "AllowGameDVR" 0
    Write-OK "Modo Juego activado + Xbox Game Bar desactivada"
    
} elseif ($uso -eq 1) {
    # OFICINA
    Disable-Svc "EasyAntiCheat_EOS" "Easy Anti-Cheat (EOS)" "Afecta juegos que lo requieran"
    
} elseif ($uso -eq 3) {
    # STREAMING
    Write-INFO "Servicios de audio y GPU conservados para OBS/streaming"
}

# ════════════════════════════════════════════════════════════════
#  B-F. PREGUNTAS USUARIO (Bluetooth, Impresoras, Hyper-V, WiFi, OneDrive)
# ════════════════════════════════════════════════════════════════

Write-Header "B" "BLUETOOTH"
if (Ask-YN "El cliente USA Bluetooth?" "s") {
    Write-SKIP "Bluetooth conservado"
} else {
    Disable-Svc "BluetoothUserService" "Soporte Bluetooth usuario"
    Disable-Svc "BTAGService"          "Audio Bluetooth"
    Disable-Svc "BthAvctpSvc"          "Servicio AVCTP"
    Disable-Svc "bthserv"              "Compatibilidad Bluetooth"
    Disable-Svc "RmSvc"                "Administracion de radio"
}

Write-Header "C" "IMPRESORAS"
if (Ask-YN "El cliente USA impresora?" "s") {
    Write-SKIP "Servicios de impresion conservados"
} else {
    Disable-Svc "Spooler"             "Cola de impresion (Spooler)"
    Disable-Svc "PrintNotify"         "Notificaciones de impresora"
    Disable-Svc "PrintDeviceConfig"   "Config dispositivo impresion"
    Disable-Svc "PrintScanBroker"     "Print/Scan Broker"
}

Write-Header "D" "HYPER-V / MAQUINAS VIRTUALES"
if (Ask-YN "El cliente usa maquinas virtuales?" "n") {
    Write-SKIP "Hyper-V conservado"
} else {
    "vmicguestinterface","vmicheartbeat","vmickvpexchange","vmicrdv",
    "vmicshutdown","vmictimesync","vmicvmsession","vmicvss","HvHost",
    "vmcompute","vmms" | ForEach-Object {
        Disable-Svc $_ "Hyper-V: $_"
    }
}

Write-Header "E" "WI-FI"
if (Ask-YN "El cliente usa Wi-Fi?" "s") {
    Write-SKIP "Wi-Fi conservado"
} else {
    Disable-Svc "WlanSvc" "Configuracion automatica WLAN" "La PC no podra usar Wi-Fi"
    $script:Riesgos.Add("  [!] WlanSvc off: solo funciona Ethernet")
}

Write-Header "F" "ONEDRIVE"
if (Ask-YN "El cliente usa OneDrive?" "n") {
    Write-SKIP "OneDrive conservado"
} else {
    reg delete "HKCU\Software\Microsoft\Windows\CurrentVersion\Run" /v "OneDrive" /f 2>$null
    schtasks /Delete /TN "\Microsoft\Windows\OneDrive\OneDrive Standalone Update Task v2" /F 2>$null
    Write-OK "OneDrive removido del autoarranque"
}

# ════════════════════════════════════════════════════════════════
#  G. PLAN DE ENERGIA
# ════════════════════════════════════════════════════════════════

Write-Header "G" "PLAN DE ENERGIA"
Write-Host ""
Write-Host "   [1] Alto rendimiento   - recomendado para PC de escritorio" -ForegroundColor Green
Write-Host "   [2] Ultimate Perf.     - maximo posible (no en laptops)" -ForegroundColor Magenta
Write-Host "   [3] Equilibrado        - dejar como esta" -ForegroundColor Yellow
Write-Host "   [4] Ahorro de energia  - laptops / bajo consumo" -ForegroundColor Cyan
Write-Host ""
do { $pe = Read-Host "  Selecciona 1, 2, 3 o 4" } while ($pe -notmatch "^[1234]$")

switch ($pe) {
    "1" {
        powercfg /setactive 8c5e7fda-e8bf-4a96-9a85-a6e23a8c635c 2>$null
        Write-OK "Plan: Alto rendimiento activado"
    }
    "2" {
        powercfg -duplicatescheme e9a42b02-d5df-448d-aa00-03f14749eb61 2>$null
        $uidLine = powercfg /list | Select-String -Pattern "Ultimate|Ultimo" | Select-Object -First 1
        if ($uidLine) {
            $uid = ([regex]::Match($uidLine, "([0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12})")).Value
            if ($uid) {
                powercfg /setactive $uid 2>$null
                Write-OK "Plan: Ultimate Performance activado"
            } else {
                powercfg /setactive 8c5e7fda-e8bf-4a96-9a85-a6e23a8c635c 2>$null
                Write-OK "Plan: Alto rendimiento (Ultimate no disponible)"
            }
        }
        $script:Riesgos.Add("  [!] Ultimate Performance: mayor consumo, no usar en laptops")
    }
    "3" { Write-SKIP "Plan de energia sin cambios" }
    "4" {
        powercfg /setactive a1841308-3541-4fab-bc81-f71556f20b4a 2>$null
        Write-OK "Plan: Ahorro de energia activado"
    }
}


# ════════════════════════════════════════════════════════════════
#  H. TWEAKS DE REGISTRO - PRIVACIDAD Y RENDIMIENTO
# ════════════════════════════════════════════════════════════════

Write-Header "H" "TWEAKS DE REGISTRO - PRIVACIDAD Y RENDIMIENTO"
if (Ask-YN "Aplicar tweaks de privacidad y rendimiento en registro?" "s") {

    Write-Sub "Privacidad"
    Set-Reg "$script:HKCU_Software\Microsoft\Windows\CurrentVersion\AdvertisingInfo" "Enabled" 0
    
    $cdm = "$script:HKCU_Software\Microsoft\Windows\CurrentVersion\ContentDeliveryManager"
    "SubscribedContent-338388Enabled","SubscribedContent-338389Enabled",
    "SubscribedContent-353698Enabled","SystemPaneSuggestionsEnabled",
    "SoftLandingEnabled","OemPreInstalledAppsEnabled",
    "PreInstalledAppsEnabled","SilentInstalledAppsEnabled" | ForEach-Object {
        Set-Reg $cdm $_ 0
    }
    
    Set-Reg "$script:HKLM_Software\Policies\Microsoft\Windows\DataCollection" "AllowTelemetry" 0
    Write-OK "Publicidad personalizada y telemetria desactivadas"

    Write-Sub "Rendimiento de memoria y CPU"
    powercfg /h off 2>$null
    Write-OK "Hibernacion desactivada (libera ~$([math]::Round($sys.RAM, 0)) GB)"
    
    Set-Reg "$script:HKLM_System\Control\Session Manager\Memory Management\PrefetchParameters" "EnableSuperfetch" 0
    Set-Reg "$script:HKLM_System\Control\Session Manager\Memory Management\PrefetchParameters" "EnablePrefetcher" 0
    Set-Reg "$script:HKLM_System\Control\PriorityControl" "Win32PrioritySeparation" 38
    Set-Reg "$script:HKLM_System\Control\CrashControl" "CrashDumpEnabled" 0
    Set-Reg "$script:HKLM_System\Control\CrashControl" "AutoReboot" 1
    Write-OK "Prioridad CPU primer plano optimizada"

    Write-Sub "Explorador de archivos"
    $adv = "$script:HKCU_Explorer\Advanced"
    Set-Reg $adv "HideFileExt" 0
    Set-Reg $adv "Hidden" 1
    Set-Reg $adv "EnableBalloonTips" 0
    Set-Reg $adv "LaunchTo" 1
    Set-Reg $adv "ShowSyncProviderNotifications" 0
    Write-OK "Extensiones visibles, Este equipo como inicio"

    Write-Sub "Busqueda web / Bing / Cortana"
    Set-Reg "$script:HKCU_Software\Microsoft\Windows\CurrentVersion\Search" "BingSearchEnabled" 0
    Set-Reg "$script:HKCU_Software\Microsoft\Windows\CurrentVersion\Search" "CortanaConsent" 0
    Set-Reg "$script:HKLM_Software\Policies\Microsoft\Windows\Windows Search" "DisableWebSearch" 1
    Set-Reg "$script:HKLM_Software\Policies\Microsoft\Windows\Windows Search" "ConnectedSearchUseWeb" 0
    Write-OK "Bing y Cortana desactivados"

    if ($sys.IsWin11) {
        Write-Sub "Windows 11 - Tweaks especificos"
        
        # Widgets
        Set-Reg "$script:HKLM_Software\Policies\Microsoft\Dsh" "AllowNewsAndInterests" 0
        Write-OK "Widgets desactivados"
        
        # Recall (Copilot+)
        Set-Reg "$script:HKCU_Software\Policies\Microsoft\Windows\WindowsAI" "DisableAIDataAnalysis" 1
        Set-Reg "$script:HKLM_Software\Policies\Microsoft\Windows\WindowsAI" "DisableAIDataAnalysis" 1
        Write-OK "Recall/AI desactivado"
        
        # Copilot
        Set-Reg "$script:HKCU_Software\Policies\Microsoft\Windows\WindowsCopilot" "TurnOffWindowsCopilot" 1
        Write-OK "Copilot desactivado"
        
        # Taskbar alignment
        if (Ask-YN "Mover iconos de barra de tareas a la izquierda (estilo Win10)?" "n") {
            Set-Reg $adv "TaskbarAl" 0
            Write-OK "Barra de tareas alineada a la izquierda"
        }
    }
}


# ════════════════════════════════════════════════════════════════
#  I. OPTIMIZACIÓN DE RED COMPLETA
# ════════════════════════════════════════════════════════════════

Write-Header "I" "OPTIMIZACION DE RED - TCP, DNS, MTU, ADAPTADOR"
if (Ask-YN "Aplicar optimizacion completa de red?" "s") {

    Write-Sub "Verificando conectividad"
    try {
        $tieneInternet = Test-Connection -ComputerName 8.8.8.8 -Count 1 -Quiet -ErrorAction Stop
    } catch { $tieneInternet = $false }
    
    if ($tieneInternet) {
        Write-OK "Internet detectado"
        $bp = Test-Connection "8.8.8.8" -Count 4 -EA SilentlyContinue
        $avgBefore = [math]::Round(($bp | Measure-Object ResponseTime -Average).Average, 2)
        Write-INFO "Ping ANTES: $avgBefore ms"
    } else {
        Write-WARN "Sin internet - se saltan MTU y test DNS automatico"
    }

    Write-Sub "TCP/IP tweaks"
    netsh int tcp set global autotuninglevel=normal  | Out-Null
    netsh int tcp set global rss=enabled             | Out-Null
    netsh int tcp set global chimney=enabled         | Out-Null
    netsh int tcp set global dca=enabled             | Out-Null
    netsh int tcp set global netdma=enabled          | Out-Null
    netsh int tcp set global ecncapability=disabled  | Out-Null
    netsh int tcp set global timestamps=disabled     | Out-Null
    
    # Congestion Provider - el mejor según la versión de Windows
    if ($sys.IsWin11 -or ($sys.IsWin10 -and $sys.Build -ge 22000)) {
        # Windows 11: CUBIC es el mejor (predeterminado y optimizado)
        netsh int tcp set global congestionprovider=cubic | Out-Null
        Write-INFO "Congestion Provider: CUBIC (Win11)"
    } elseif ($sys.Build -ge 16299) {
        # Win10 1709+: CUBIC disponible
        netsh int tcp set global congestionprovider=cubic | Out-Null
        Write-INFO "Congestion Provider: CUBIC (Win10 1709+)"
    } elseif ($sys.Build -ge 14393) {
        # Win10 1607 (Anniversary): CTCP disponible
        netsh int tcp set global congestionprovider=ctcp | Out-Null
        Write-INFO "Congestion Provider: CTCP (Win10 1607+)"
    } else {
        # Win10 anterior: usar default
        netsh int tcp set global congestionprovider=default | Out-Null
        Write-INFO "Congestion Provider: Default (Win10 antiguo)"
    }
    
    # Nagle off en todas las interfaces
    $tcpIf = "$script:HKLM_System\Services\Tcpip\Parameters\Interfaces"
    Get-ChildItem $tcpIf -EA SilentlyContinue | ForEach-Object {
        Set-ItemProperty -Path $_.PSPath -Name "TcpAckFrequency" -Value 1 -Type DWord -EA SilentlyContinue
        Set-ItemProperty -Path $_.PSPath -Name "TCPNoDelay" -Value 1 -Type DWord -EA SilentlyContinue
    }
    
    Set-Reg "$script:HKLM_System\Services\Tcpip\Parameters" "DefaultTTL" 64
    Set-Reg "$script:HKLM_System\Services\Tcpip\Parameters" "MaxUserPort" 65534
    Set-Reg "$script:HKLM_System\Services\Tcpip\Parameters" "TcpTimedWaitDelay" 30
    Set-Reg "$script:HKLM_System\Services\Tcpip\Parameters" "Tcp1323Opts" 1
    Write-OK "TCP optimizado (Nagle off, autotuning, puertos ampliados)"

    Write-Sub "Flush DNS y reset de red"
    ipconfig /flushdns    | Out-Null
    ipconfig /release     | Out-Null
    Start-Sleep -Seconds 2
    ipconfig /renew       | Out-Null
    netsh winsock reset   | Out-Null
    netsh int ip reset    | Out-Null
    netsh winhttp reset proxy | Out-Null
    Write-OK "DNS, Winsock, IP stack y proxy reseteados"
    $script:Riesgos.Add("  [!] netsh int ip reset ejecutado: REINICIO OBLIGATORIO")

    Write-Sub "Prioridad multimedia/gaming"
    $mmPath = "$script:HKLM_Software\Microsoft\Windows NT\CurrentVersion\Multimedia\SystemProfile"
    Set-Reg $mmPath "NetworkThrottlingIndex" 4294967295
    Set-Reg $mmPath "SystemResponsiveness" 0
    $gPath = "$mmPath\Tasks\Games"
    if (-not (Test-Path $gPath)) { New-Item -Path $gPath -Force | Out-Null }
    Set-ItemProperty -Path $gPath -Name "GPU Priority" -Value 8 -Type DWord -EA SilentlyContinue
    Set-ItemProperty -Path $gPath -Name "Priority" -Value 6 -Type DWord -EA SilentlyContinue
    Set-ItemProperty -Path $gPath -Name "Scheduling Category" -Value "High" -Type String -EA SilentlyContinue
    Write-OK "Prioridad multimedia/gaming configurada"

    Write-Sub "Desactivar ahorro energia en adaptadores"
    Get-NetAdapter | Where-Object { $_.Status -eq "Up" } | ForEach-Object {
        $adapterName = $_.Name
        
        # Metodo 1: Via Device Manager properties (lo que mostraste en la captura)
        $deviceID = (Get-NetAdapter -Name $adapterName).PnPDeviceID
        if ($deviceID) {
            # Deshabilitar "Permitir que el equipo apague este dispositivo para ahorrar energía"
            $powerMgmt = Get-CimInstance -ClassName MSPower_DeviceEnable -Namespace root/wmi -EA SilentlyContinue |
                         Where-Object { $_.InstanceName -like "*$deviceID*" }
            if ($powerMgmt) {
                Set-CimInstance -InputObject $powerMgmt -Property @{Enable = $false} -EA SilentlyContinue
            }
            
            # También via registro
            $regPath = "HKLM:\SYSTEM\CurrentControlSet\Control\Class\{4d36e972-e325-11ce-bfc1-08002be10318}"
            Get-ChildItem $regPath -EA SilentlyContinue | ForEach-Object {
                $driverDesc = (Get-ItemProperty $_.PSPath -Name "DriverDesc" -EA SilentlyContinue).DriverDesc
                if ($driverDesc -like "*$adapterName*") {
                    Set-ItemProperty -Path $_.PSPath -Name "PnPCapabilities" -Value 24 -Type DWord -EA SilentlyContinue
                }
            }
        }
        
        # Metodo 2: Disable-NetAdapterPowerManagement (si existe el cmdlet)
        Disable-NetAdapterPowerManagement -Name $adapterName -EA SilentlyContinue
    }
    Write-OK "Gestion de energia de adaptadores desactivada (Device Manager + PowerShell)"

    Write-Sub "Perfil del adaptador activo"
    $adapter = Get-NetAdapter | Where-Object {
        $_.Status -eq "Up" -and $_.HardwareInterface -eq $true
    } | Select-Object -First 1

    if ($adapter) {
        $esEthernet = ($adapter.NdisPhysicalMedium -eq 14) -or ($adapter.PhysicalMediaType -eq "802.3")
        $esWifi     = ($adapter.NdisPhysicalMedium -eq 9)  -or ($adapter.PhysicalMediaType -like "*802.11*")
        $tipoAdap   = if ($esEthernet) { "Ethernet" } elseif ($esWifi) { "Wi-Fi" } else { "Otro" }
        Write-INFO "Adaptador: $($adapter.Name) [$tipoAdap]"

        if ($esEthernet) {
            Write-INFO "Configurando tweaks avanzados de Ethernet..."
            
            # Helper function para setear propiedades
            $SetNicProp = {
                param($DisplayName, $Value)
                Set-NetAdapterAdvancedProperty -Name $adapter.Name -DisplayName $DisplayName -DisplayValue $Value -EA SilentlyContinue
            }
            
            # Energy Efficient Ethernet (EEE) - OFF
            & $SetNicProp "Energy Efficient Ethernet" "Disabled"
            & $SetNicProp "Advanced EEE" "Disabled"
            & $SetNicProp "EEE" "Disabled"
            & $SetNicProp "Green Ethernet" "Disabled"
            & $SetNicProp "Gigabit Lite" "Disabled"
            & $SetNicProp "Power Saving Mode" "Disabled"
            
            # Flow Control - OFF
            & $SetNicProp "Flow Control" "Disabled"
            
            # Auto Disable Gigabit - OFF
            & $SetNicProp "Auto Disable Gigabit" "Disabled"
            & $SetNicProp "Gigabit Auto Powerdown" "Disabled"
            
            # ARP Offload - ON (dejar activado)
            & $SetNicProp "ARP Offload" "Enabled"
            
            # IPv4 Checksum Offload - ON (dejar activado)
            & $SetNicProp "IPv4 Checksum Offload" "Rx & Tx Enabled"
            
            # Large Send Offload v2 - OFF
            & $SetNicProp "Large Send Offload V2 (IPv4)" "Disabled"
            & $SetNicProp "Large Send Offload V2 (IPv6)" "Disabled"
            & $SetNicProp "Large Send Offload v2 (IPv4)" "Disabled"
            & $SetNicProp "Large Send Offload v2 (IPv6)" "Disabled"
            
            # TCP/UDP Checksum Offload - TODAS ACTIVADAS (Rx & Tx)
            & $SetNicProp "TCP Checksum Offload (IPv4)" "Rx & Tx Enabled"
            & $SetNicProp "TCP Checksum Offload (IPv6)" "Rx & Tx Enabled"
            & $SetNicProp "UDP Checksum Offload (IPv4)" "Rx & Tx Enabled"
            & $SetNicProp "UDP Checksum Offload (IPv6)" "Rx & Tx Enabled"
            
            # Receive Segment Coalescing - OFF
            & $SetNicProp "Recv Segment Coalescing (IPv4)" "Disabled"
            & $SetNicProp "Recv Segment Coalescing (IPv6)" "Disabled"
            & $SetNicProp "Receive Segment Coalescing" "Disabled"
            
            # Receive Side Scaling - ON
            & $SetNicProp "Receive Side Scaling" "Enabled"
            Enable-NetAdapterRss -Name $adapter.Name -EA SilentlyContinue
            
            # RSS tuning basado en cores
            if ($sys.CPUCores -ge 4) {
                $maxProc = [math]::Min($sys.CPUCores - 1, 4)
                Set-NetAdapterRss -Name $adapter.Name -MaxProcessors $maxProc -EA SilentlyContinue
            }
            
            # Wake on Pattern Match - Disabled
            & $SetNicProp "Wake on Pattern Match" "Disabled"
            & $SetNicProp "Wake on Magic Packet" "Disabled"
            & $SetNicProp "Wake on Link" "Disabled"
            
            # WOL & Shutdown Link Speed - No Speed Down
            & $SetNicProp "WOL & Shutdown Link Speed" "Not Speed Down"
            & $SetNicProp "Shutdown Wake-On-Lan" "Disabled"
            
            # Interrupt Moderation - Disabled
            & $SetNicProp "Interrupt Moderation" "Disabled"
            
            # Speed & Duplex - Maxima posible (Auto Negotiation o 1.0 Gbps Full Duplex)
            $speedOptions = Get-NetAdapterAdvancedProperty -Name $adapter.Name -EA SilentlyContinue |
                            Where-Object { $_.RegistryKeyword -eq "SpeedDuplex" }
            if ($speedOptions) {
                # Intentar setear a 1Gbps Full Duplex si está disponible
                $maxSpeed = $speedOptions.ValidDisplayValues | Where-Object { 
                    $_ -match "1\.0 Gbps Full Duplex|1000 Mbps Full Duplex" 
                } | Select-Object -First 1
                
                if ($maxSpeed) {
                    & $SetNicProp "Speed & Duplex" $maxSpeed
                } else {
                    & $SetNicProp "Speed & Duplex" "Auto Negotiation"
                }
            }
            
            Write-OK "Ethernet: Tweaks avanzados aplicados"
            Write-INFO "  - EEE/Green/Power Saving: OFF"
            Write-INFO "  - Flow Control: OFF"
            Write-INFO "  - LSO v2: OFF"
            Write-INFO "  - TCP/UDP Checksum Offload: ON (Rx & Tx)"
            Write-INFO "  - RSC: OFF"
            Write-INFO "  - RSS: ON ($maxProc cores)"
            Write-INFO "  - Interrupt Moderation: OFF"
            Write-INFO "  - Wake on LAN: OFF"
            
        } elseif ($esWifi) {
            Set-NetAdapterAdvancedProperty -Name $adapter.Name -DisplayName "Transmit Power" -DisplayValue "Highest" -EA SilentlyContinue
            Set-NetAdapterAdvancedProperty -Name $adapter.Name -DisplayName "Roaming Aggressiveness" -DisplayValue "Lowest" -EA SilentlyContinue
            $wb = Get-NetAdapterAdvancedProperty -Name $adapter.Name -EA SilentlyContinue |
                  Where-Object { $_.DisplayName -like "*Preferred Band*" }
            if ($wb) {
                Set-NetAdapterAdvancedProperty -Name $adapter.Name -DisplayName $wb.DisplayName -DisplayValue "Prefer 5GHz" -EA SilentlyContinue
            }
            Write-OK "Wi-Fi: TX max, roaming agresivo off, preferir 5GHz"
        }
    }

    Write-Sub "MTU automatico"
    if ($tieneInternet -and $adapter) {
        $mtu = 1500
        for ($sz = 1472; $sz -gt 1372; $sz -= 10) {
            $t = ping 8.8.8.8 -f -l $sz -n 1 2>&1
            if ($t -match "TTL|ttl") { $mtu = $sz + 28; break }
        }
        netsh interface ipv4 set subinterface "$($adapter.Name)" mtu=$mtu store=persistent 2>$null
        Write-OK "MTU ajustado a $mtu"
    } else {
        Write-SKIP "Sin internet o adaptador - MTU no calculado"
    }

    Write-Sub "DNS publico"
    Write-Host ""
    Write-Host "   [1] Google      8.8.8.8 / 8.8.4.4" -ForegroundColor Yellow
    Write-Host "   [2] Cloudflare  1.1.1.1 / 1.0.0.1" -ForegroundColor Cyan
    Write-Host "   [3] Quad9       9.9.9.9 / 149.112.112.112" -ForegroundColor Magenta
    Write-Host "   [4] Automatico  - testea el mas rapido" -ForegroundColor Green
    Write-Host "   [5] Saltar" -ForegroundColor DarkGray
    Write-Host ""
    do { $dnsSel = Read-Host "  >> Selecciona 1-5" } while ($dnsSel -notmatch "^[12345]$")

    $dp = $null; $ds = $null
    if ($dnsSel -eq "4" -and $tieneInternet) {
        Write-INFO "Testeando 8 servidores DNS..."
        $candidates = @("1.1.1.1","1.0.0.1","8.8.8.8","8.8.4.4","9.9.9.9","149.112.112.112","208.67.222.222","208.67.220.220")
        $results = @()
        foreach ($d in $candidates) {
            $p = Test-Connection $d -Count 3 -EA SilentlyContinue
            if ($p) { 
                $results += [PSCustomObject]@{ 
                    DNS=$d
                    Avg=[math]::Round(($p | Measure-Object ResponseTime -Average).Average,2)
                }
            }
        }
        $top2 = $results | Sort-Object Avg | Select-Object -First 2
        if ($top2.Count -ge 2) { 
            $dp=$top2[0].DNS; $ds=$top2[1].DNS
            Write-OK "DNS elegido: $dp ($($top2[0].Avg)ms) / $ds ($($top2[1].Avg)ms)"
        } else {
            $dp="1.1.1.1"; $ds="1.0.0.1"
            Write-WARN "Fallback: Cloudflare"
        }
    } elseif ($dnsSel -eq "1") { $dp="8.8.8.8"; $ds="8.8.4.4"
    } elseif ($dnsSel -eq "2") { $dp="1.1.1.1"; $ds="1.0.0.1"
    } elseif ($dnsSel -eq "3") { $dp="9.9.9.9"; $ds="149.112.112.112" }

    if ($dp) {
        $ifaces = Get-DnsClient | Where-Object { $_.InterfaceAlias -notlike "*Loopback*" }
        foreach ($iface in $ifaces) {
            Set-DnsClientServerAddress -InterfaceIndex $iface.InterfaceIndex -ServerAddresses ($dp, $ds) -EA SilentlyContinue
        }
        ipconfig /flushdns | Out-Null
        Write-OK "DNS aplicado: $dp / $ds"
    }

    Write-Sub "IPv6"
    if (Ask-YN "Deshabilitar IPv6?" "n") {
        Set-Reg "$script:HKLM_System\Services\Tcpip6\Parameters" "DisabledComponents" 255
        Get-NetAdapter | ForEach-Object { 
            Disable-NetAdapterBinding -Name $_.Name -ComponentID ms_tcpip6 -EA SilentlyContinue 
        }
        Write-OK "IPv6 deshabilitado"
        $script:Riesgos.Add("  [!] IPv6 off: algunos servicios modernos pueden necesitarlo")
    }

    if ($tieneInternet) {
        Start-Sleep -Seconds 2
        $ap = Test-Connection "8.8.8.8" -Count 4 -EA SilentlyContinue
        $avgAfter = [math]::Round(($ap | Measure-Object ResponseTime -Average).Average, 2)
        $diff = [math]::Round($avgBefore - $avgAfter, 2)
        Write-Host ""
        Write-Host "  ────────────────────────────────────────────────────" -ForegroundColor DarkCyan
        Write-Host "  Ping ANTES:   $avgBefore ms" -ForegroundColor Gray
        Write-Host "  Ping DESPUES: $avgAfter ms" -ForegroundColor Cyan
        if ($diff -gt 0) { 
            Write-Host "  Mejora:       -$diff ms" -ForegroundColor Green 
        } else { 
            Write-Host "  Diferencia:   $diff ms" -ForegroundColor Yellow 
        }
        Write-Host "  ────────────────────────────────────────────────────" -ForegroundColor DarkCyan
    }
}


# ════════════════════════════════════════════════════════════════
#  J. AJUSTES VISUALES
# ════════════════════════════════════════════════════════════════

Write-Header "J" "AJUSTES VISUALES Y ANIMACIONES"
if (Ask-YN "Configurar efectos visuales?" "s") {
    Write-Host ""
    Write-Host "   [1] Rendimiento maximo - desactiva TODOS los efectos" -ForegroundColor Red
    Write-Host "   [2] Personalizado      - elegis efecto por efecto" -ForegroundColor Yellow
    Write-Host "   [3] Omitir" -ForegroundColor DarkGray
    Write-Host ""
    do { $vo = Read-Host "  >> Selecciona 1-3" } while ($vo -notmatch "^[123]$")

    $perfP  = "$script:HKCU_Explorer\Advanced"
    $visP   = "HKCU:\Control Panel\Desktop"
    $dwmP   = "$script:HKCU_Software\Microsoft\Windows\DWM"
    $themeP = "$script:HKCU_Software\Microsoft\Windows\CurrentVersion\Themes\Personalize"

    if ($vo -eq "1") {
        Set-Reg $perfP  "VisualFXSetting" 2
        Set-Reg $visP   "MinAnimate" "0" "String"
        Set-Reg $visP   "DragFullWindows" "0" "String"
        Set-Reg $visP   "FontSmoothing" 2
        Set-Reg $perfP  "TaskbarAnimations" 0
        Set-Reg $dwmP   "EnableAeroPeek" 0
        Set-Reg $themeP "EnableTransparency" 0
        Set-Reg $perfP  "ListviewAlphaSelect" 0
        Set-Reg $perfP  "ListviewShadow" 0
        Set-Reg $visP   "UserPreferencesMask" ([byte[]](0x90,0x12,0x03,0x80,0x10,0x00,0x00,0x00)) "Binary"
        Write-OK "Rendimiento maximo aplicado"
    } elseif ($vo -eq "2") {
        $tweaks = @(
            @{ Q="Animaciones al minimizar/maximizar"; P=$visP;  N="MinAnimate"; V="0"; T="String" }
            @{ Q="Sombras debajo de ventanas"; P=$dwmP;  N="EnableAeroPeek"; V=0; T="DWord" }
            @{ Q="Transparencia en barra de tareas"; P=$themeP; N="EnableTransparency"; V=0; T="DWord" }
            @{ Q="Animaciones en barra de tareas"; P=$perfP; N="TaskbarAnimations"; V=0; T="DWord" }
            @{ Q="Mostrar contenido al arrastrar"; P=$visP;  N="DragFullWindows"; V="0"; T="String" }
        )
        foreach ($t in $tweaks) {
            if (Ask-YN "Desactivar: $($t.Q)?" "s") {
                if (-not (Test-Path $t.P)) { New-Item -Path $t.P -Force | Out-Null }
                Set-ItemProperty -Path $t.P -Name $t.N -Value $t.V -Type $t.T -EA SilentlyContinue
                Write-OFF "$($t.Q)"
            } else {
                Write-SKIP "$($t.Q) conservado"
            }
        }
    }
}

# ════════════════════════════════════════════════════════════════
#  K. AUTOARRANQUE
# ════════════════════════════════════════════════════════════════

Write-Header "K" "AUTOARRANQUE - PROGRAMAS AL INICIO"
if (Ask-YN "Revisar programas que inician con Windows?" "s") {
    $startKeys = @(
        "HKCU:\Software\Microsoft\Windows\CurrentVersion\Run",
        "HKLM:\Software\Microsoft\Windows\CurrentVersion\Run",
        "HKLM:\Software\WOW6432Node\Microsoft\Windows\CurrentVersion\Run"
    )
    $entries = @()
    foreach ($k in $startKeys) {
        if (Test-Path $k) {
            (Get-ItemProperty -Path $k -EA SilentlyContinue).PSObject.Properties |
            Where-Object { $_.Name -notmatch "^PS" } | ForEach-Object {
                $entries += [PSCustomObject]@{ Key=$k; Name=$_.Name; Value=$_.Value }
            }
        }
    }
    if ($entries.Count -eq 0) {
        Write-INFO "No se encontraron entradas de autoarranque"
    } else {
        Write-Host ""
        for ($i = 0; $i -lt $entries.Count; $i++) {
            $sv = if ($entries[$i].Value.Length -gt 50) { $entries[$i].Value.Substring(0,50)+"..." } else { $entries[$i].Value }
            Write-Host ("  [{0:D2}] {1,-30} {2}" -f ($i+1), $entries[$i].Name, $sv) -ForegroundColor White
        }
        Write-Host ""
        Write-Host "  Ingresa numeros a ELIMINAR (ej: 1,3,5) o ENTER para omitir" -ForegroundColor Yellow
        $sel = Read-Host "  >>"
        if ($sel.Trim() -ne "") {
            $sel -split "," | ForEach-Object {
                $idx = [int]$_.Trim() - 1
                if ($idx -ge 0 -and $idx -lt $entries.Count) {
                    Remove-ItemProperty -Path $entries[$idx].Key -Name $entries[$idx].Name -EA SilentlyContinue
                    Write-OK "Eliminado: $($entries[$idx].Name)"
                }
            }
        } else {
            Write-SKIP "Autoarranque sin cambios"
        }
    }
}

# ════════════════════════════════════════════════════════════════
#  L. BLOATWARE
# ════════════════════════════════════════════════════════════════

Write-Header "L" "BLOATWARE - APPS PREINSTALADAS"
if (Ask-YN "Desinstalar apps de bloatware?" "s") {
    $bloat = @(
        @{N="Microsoft.3DBuilder"; D="3D Builder"}
        @{N="Microsoft.BingWeather"; D="Bing Tiempo"}
        @{N="Microsoft.BingNews"; D="Bing Noticias"}
        @{N="Microsoft.GetHelp"; D="Obtener ayuda"}
        @{N="Microsoft.Getstarted"; D="Introduccion"}
        @{N="Microsoft.MicrosoftOfficeHub"; D="Office Hub"}
        @{N="Microsoft.MicrosoftSolitaireCollection"; D="Solitario"}
        @{N="Microsoft.People"; D="Personas"}
        @{N="Microsoft.SkypeApp"; D="Skype"}
        @{N="Microsoft.WindowsAlarms"; D="Alarmas"}
        @{N="Microsoft.WindowsFeedbackHub"; D="Centro de opiniones"}
        @{N="Microsoft.WindowsMaps"; D="Mapas"}
        @{N="Microsoft.XboxApp"; D="Xbox App"}
        @{N="Microsoft.XboxGamingOverlay"; D="Xbox Game Bar"}
        @{N="Microsoft.YourPhone"; D="Tu Telefono"}
        @{N="Microsoft.ZuneMusic"; D="Groove Musica"}
        @{N="Microsoft.ZuneVideo"; D="Peliculas y TV"}
        @{N="microsoft.windowscommunicationsapps"; D="Correo y Calendario"}
        @{N="Clipchamp.Clipchamp"; D="Clipchamp"}
        @{N="MicrosoftTeams"; D="Microsoft Teams"}
        @{N="Microsoft.549981C3F5F10"; D="Cortana"}
    )
    
    Write-INFO "Buscando bloatware instalado..."
    $inst = @()
    foreach ($a in $bloat) {
        if (Get-AppxPackage -Name $a.N -EA SilentlyContinue) { $inst += $a }
    }
    
    if ($inst.Count -eq 0) {
        Write-OK "No se encontro bloatware"
    } else {
        Write-Host ""
        Write-Host "  Apps encontradas ($($inst.Count)):" -ForegroundColor Cyan
        for ($i = 0; $i -lt $inst.Count; $i++) {
            Write-Host ("  [{0:D2}] {1}" -f ($i+1), $inst[$i].D) -ForegroundColor White
        }
        Write-Host ""
        Write-Host "  [T] Todas  |  [S] Seleccionar  |  [N] Cancelar" -ForegroundColor Yellow
        $bc = Read-Host "  >>"
        
        $toRm = @()
        if     ($bc -eq "T" -or $bc -eq "t") { $toRm = $inst }
        elseif ($bc -eq "S" -or $bc -eq "s") {
            $sel = Read-Host "  Numeros (ej: 1,3,5)"
            $sel -split "," | ForEach-Object {
                $idx = [int]$_.Trim() - 1
                if ($idx -ge 0 -and $idx -lt $inst.Count) { $toRm += $inst[$idx] }
            }
        }
        
        foreach ($a in $toRm) {
            Get-AppxPackage -Name $a.N | Remove-AppxPackage -EA SilentlyContinue
            Get-AppxProvisionedPackage -Online | Where-Object { $_.PackageName -like "*$($a.N)*" } |
                Remove-AppxProvisionedPackage -Online -EA SilentlyContinue
            Write-OK "Desinstalado: $($a.D)"
        }
    }
}

# ════════════════════════════════════════════════════════════════
#  M. LIMPIEZA
# ════════════════════════════════════════════════════════════════

Write-Header "M" "LIMPIEZA DE ARCHIVOS TEMPORALES"
if (Ask-YN "Limpiar temporales y cache del sistema?" "s") {
    $freeAntes = (Get-PSDrive C).Free
    
    $folders = @(
        $env:TEMP,
        $env:TMP,
        "C:\Windows\Temp",
        "$env:LOCALAPPDATA\Temp",
        "$env:LOCALAPPDATA\Microsoft\Windows\INetCache",
        "C:\Windows\SoftwareDistribution\Download"
    )
    
    foreach ($f in $folders) {
        if (Test-Path $f) {
            $items = @(Get-ChildItem -Path $f -Recurse -Force -EA SilentlyContinue)
            $count = $items.Count
            $items | Remove-Item -Recurse -Force -EA SilentlyContinue
            Write-OK "Limpiado: $f ($count archivos)"
        }
    }
    
    # Papelera
    (New-Object -ComObject Shell.Application).Namespace(0xA).Items() | ForEach-Object {
        Remove-Item $_.Path -Recurse -Force -EA SilentlyContinue
    }
    Write-OK "Papelera vaciada"
    
    # Cache thumbnails
    Remove-Item "$env:LOCALAPPDATA\Microsoft\Windows\Explorer\thumbcache*" -Force -EA SilentlyContinue
    Write-OK "Cache de miniaturas eliminada"
    
    # DNS cache
    ipconfig /flushdns | Out-Null
    Write-OK "Cache DNS limpiada"
    
    $freeAhora = (Get-PSDrive C).Free
    $freed = [math]::Round(($freeAhora - $freeAntes)/1MB, 0)
    if ($freed -gt 0) { Write-OK "Espacio liberado: $freed MB" }
}

# ════════════════════════════════════════════════════════════════
#  N. SEGURIDAD
# ════════════════════════════════════════════════════════════════

Write-Header "N" "SEGURIDAD ADICIONAL"
if (Ask-YN "Aplicar configuraciones de seguridad extra?" "s") {
    
    # SMBv1
    Set-SmbServerConfiguration -EnableSMB1Protocol $false -Force -EA SilentlyContinue
    Disable-WindowsOptionalFeature -Online -FeatureName SMB1Protocol -NoRestart -EA SilentlyContinue
    Write-OK "SMBv1 deshabilitado (proteccion WannaCry)"
    
    # AutoRun/AutoPlay
    Set-Reg "$script:HKLM_Software\Microsoft\Windows NT\CurrentVersion\IniFileMapping\Autorun.inf" "(Default)" "@SYS:DoesNotExist" "String"
    Set-Reg "$script:HKLM_Software\Microsoft\Windows\CurrentVersion\Policies\Explorer" "NoDriveTypeAutoRun" 255
    Write-OK "AutoRun/AutoPlay deshabilitado"
    
    # NetBIOS
    $netbios = "$script:HKLM_System\Services\NetBT\Parameters\Interfaces"
    Get-ChildItem $netbios -EA SilentlyContinue | ForEach-Object {
        Set-ItemProperty -Path $_.PSPath -Name "NetbiosOptions" -Value 2 -EA SilentlyContinue
    }
    Write-OK "NetBIOS sobre TCP/IP deshabilitado"
    
    # LLMNR
    Set-Reg "$script:HKLM_Software\Policies\Microsoft\Windows NT\DNSClient" "EnableMulticast" 0
    Write-OK "LLMNR deshabilitado"
    
    # Firewall
    netsh advfirewall set allprofiles state on | Out-Null
    Write-OK "Firewall habilitado en todos los perfiles"
}


# ════════════════════════════════════════════════════════════════
#  SECCIÓN DE APLICACIONES
# ════════════════════════════════════════════════════════════════

# Variables para apps
$tempDir = $env:TEMP
$ghUser  = "FacuxD23"
$ghRepo  = "-"
$ghBranch = "main"

# ════════════════════════════════════════════════════════════════
#  S. MICROSOFT STORE OFFLINE
# ════════════════════════════════════════════════════════════════

Write-Header "S" "MICROSOFT STORE - INSTALADOR OFFLINE"
if (Ask-YN "Instalar Microsoft Store offline?" "s") {
    $zipUrl = "https://github.com/FacuxD23/microsoft-store-download/archive/refs/heads/main.zip"
    $zipPath = "$tempDir\msstore.zip"
    
    Write-INFO "Descargando instalador (ZIP)..."
    try {
        Invoke-WebRequest -Uri $zipUrl -OutFile $zipPath
        if (Test-Path $zipPath) {
            $sizeMB = [math]::Round((Get-Item $zipPath).Length / 1MB, 2)
            Write-OK "Descargado: $sizeMB MB"
            
            Write-INFO "Extrayendo archivos..."
            Expand-Archive -Path $zipPath -DestinationPath "$tempDir" -Force
            
            # Verificar estructura de carpetas
            $extractedBase = "$tempDir\microsoft-store-download-main"
            $storeFolder = "$extractedBase\LTSC-Add-MicrosoftStore-master"
            
            if (Test-Path "$storeFolder\Add-Store.cmd") {
                Write-OK "Archivos extraidos correctamente"
                $script:TempParaLimpiar.Add($zipPath)
                $script:TempParaLimpiar.Add($extractedBase)
                
                Write-INFO "Ejecutando instalador de Microsoft Store..."
                Write-WARN "Si aparece 'Required files missing': cierra la ventana y continua"
                Start-Process cmd.exe -ArgumentList "/c cd /d `"$storeFolder`" && Add-Store.cmd" -Wait
                Write-OK "Proceso de instalacion completado"
            } else {
                Write-ERR "Add-Store.cmd no encontrado en $storeFolder"
            }
        }
    } catch {
        Write-ERR "Error: $($_.Exception.Message)"
    }
} else {
    Write-SKIP "Microsoft Store omitida"
}

# ════════════════════════════════════════════════════════════════
#   WINDOWS ACTIVATION
# ════════════════════════════════════════════════════════════════

Write-Header "R" "MASSGRAVE - WINDOWS AND OFFICE ACTIVATION"

if (Ask-YN "Abrir Massgrave ahora?" "s") {
    Write-INFO "Lanzando Massgrave..."
   irm https://get.activated.win | iex
    Write-OK "massgrave ejecutado"
} else {
    Write-SKIP "massgrave omitido"
}
# ════════════════════════════════════════════════════════════════
#  Q. OFFICE
# ════════════════════════════════════════════════════════════════

Write-Header "Q" "OFFICE DESDE GITHUB"
$ghFile = "OInstall.exe"
$ghFolder = "OFFICE DOWNLOAD/OFFICE DOWNLOAD/"
$ghPath = "$ghFolder$ghFile"
$ghPathEnc = $ghPath -replace " ", "%20"
$ghRawUrl = "https://raw.githubusercontent.com/$ghUser/$ghRepo/$ghBranch/$ghPathEnc"
$ghTempPath = "$tempDir\$ghFile"

if (Ask-YN "Descargar e instalar Office?" "s") {
    try {
        Write-INFO "Descargando OInstall.exe..."
        Invoke-WebRequest $ghRawUrl -OutFile $ghTempPath
        if (Test-Path $ghTempPath) {
            $mb = [math]::Round((Get-Item $ghTempPath).Length / 1MB, 2)
            Write-OK "Office descargado ($mb MB)"
            $script:TempParaLimpiar.Add($ghTempPath)
            Start-Process $ghTempPath
            Write-OK "Instalador ejecutado"
        }
    } catch {
        Write-ERR "Error: $($_.Exception.Message)"
    }
} else {
    Write-SKIP "Office omitido"
}

# ════════════════════════════════════════════════════════════════
#  P. OPTIMIZER
# ════════════════════════════════════════════════════════════════

Write-Header "P" "OPTIMIZER (HELLZERG)"
$optUrl = "https://github.com/hellzerg/optimizer/releases/download/16.7/Optimizer-16.7.exe"
$optPath = "$tempDir\Optimizer.exe"

if (Ask-YN "Descargar Optimizer?" "s") {
    try {
        Write-INFO "Descargando Optimizer..."
        Invoke-WebRequest $optUrl -OutFile $optPath
        if (Test-Path $optPath) {
            Write-OK "Optimizer descargado"
            $script:TempParaLimpiar.Add($optPath)
            Start-Process $optPath
            Write-OK "Optimizer ejecutado"
        }
    } catch {
        Write-ERR "Error: $($_.Exception.Message)"
    }
} else {
    Write-SKIP "Optimizer omitido"
}

# ════════════════════════════════════════════════════════════════
#  R. WINUTIL
# ════════════════════════════════════════════════════════════════

Write-Header "R" "WINUTIL - CHRIS TITUS TOOL"
if (Ask-YN "Abrir WinUtil en ventana separada?" "s") {
    Write-INFO "Abriendo WinUtil..."
    Start-Process powershell -ArgumentList "-ExecutionPolicy Bypass -NoProfile -Command `"irm 'https://christitus.com/win' | iex`""
    Write-OK "WinUtil abierto en ventana separada"
} else {
    Write-SKIP "WinUtil omitido"
}

# ════════════════════════════════════════════════════════════════
#  T. RYTUNEX
# ════════════════════════════════════════════════════════════════

Write-Header "T" "RYTUNEX - OPTIMIZADOR WINDOWS"
if (Ask-YN "Instalar Rytunex?" "s") {
    $wingetAvailable = Get-Command winget -EA SilentlyContinue
    if ($wingetAvailable) {
        Write-INFO "Instalando Rytunex via winget..."
        try {
            winget install --id Rayen.RyTuneX --accept-package-agreements --accept-source-agreements --silent 2>&1 | Out-Null
            if ($LASTEXITCODE -eq 0) {
                Write-OK "Rytunex instalado"
                if (Ask-YN "Abrir Rytunex?" "s") {
                    Start-Sleep -Seconds 2
                    $rytunexPaths = @(
                        "$env:LOCALAPPDATA\Programs\RyTuneX\RyTuneX.exe",
                        "$env:ProgramFiles\RyTuneX\RyTuneX.exe"
                    )
                    $found = $false
                    foreach ($path in $rytunexPaths) {
                        if (Test-Path $path) {
                            Start-Process $path
                            Write-OK "Rytunex ejecutado"
                            $found = $true
                            break
                        }
                    }
                    if (-not $found) {
                        Write-WARN "Ejecutable no encontrado - abrelo desde el menu Inicio"
                    }
                }
            } else {
                Write-ERR "Error en instalacion de Rytunex"
            }
        } catch {
            Write-ERR "Fallo: $($_.Exception.Message)"
        }
    } else {
        Write-ERR "Winget no disponible - instala App Installer desde Microsoft Store"
        Write-INFO "O descarga desde: https://aka.ms/getwinget"
    }
} else {
    Write-SKIP "Rytunex omitido"
}

# ════════════════════════════════════════════════════════════════
#  U. WINHANCER
# ════════════════════════════════════════════════════════════════

Write-Header "U" "WINHANCER"
if (Ask-YN "Instalar Winhancer?" "s") {
    $url = "https://raw.githubusercontent.com/$ghUser/$ghRepo/$ghBranch/Winhance.Installer.exe"
    $path = "$tempDir\Winhance.Installer.exe"
    try {
        Write-INFO "Descargando Winhancer..."
        Invoke-WebRequest -Uri $url -OutFile $path
        if (Test-Path $path) {
            Write-OK "Winhancer descargado"
            $script:TempParaLimpiar.Add($path)
            if (Ask-YN "Abrir instalador?" "s") {
                Start-Process $path
                Write-OK "Winhancer ejecutado"
            }
        }
    } catch {
        Write-ERR "Error: $($_.Exception.Message)"
    }
} else {
    Write-SKIP "Winhancer omitido"
}

# ════════════════════════════════════════════════════════════════
#  V. WINTWEAKS
# ════════════════════════════════════════════════════════════════

Write-Header "V" "WINTWEAKS"
if (Ask-YN "Instalar WinTweaks?" "s") {
    $url = "https://raw.githubusercontent.com/$ghUser/$ghRepo/$ghBranch/Setup_WinTweaks_2.1.exe"
    $path = "$tempDir\Setup_WinTweaks_2.1.exe"
    try {
        Write-INFO "Descargando WinTweaks..."
        Invoke-WebRequest -Uri $url -OutFile $path
        if (Test-Path $path) {
            Write-OK "WinTweaks descargado"
            $script:TempParaLimpiar.Add($path)
            if (Ask-YN "Abrir instalador?" "s") {
                Start-Process $path
                Write-OK "WinTweaks ejecutado"
            }
        }
    } catch {
        Write-ERR "Error: $($_.Exception.Message)"
    }
} else {
    Write-SKIP "WinTweaks omitido"
}

# ════════════════════════════════════════════════════════════════
#  W. WINTOYS
# ════════════════════════════════════════════════════════════════

Write-Header "W" "WINTOYS"
if (Ask-YN "Instalar Wintoys?" "s") {
    $wingetAvailable = Get-Command winget -EA SilentlyContinue
    if ($wingetAvailable) {
        Write-INFO "Instalando Wintoys..."
        try {
            winget install --id 9P8LTPGCBZXD --accept-package-agreements --accept-source-agreements --silent 2>&1 | Out-Null
            if ($LASTEXITCODE -eq 0) {
                Write-OK "Wintoys instalado"
                if (Ask-YN "Abrir Wintoys?" "s") {
                    Start-Sleep -Seconds 2
                    $wintoys = Get-AppxPackage | Where-Object { $_.Name -like "*Wintoys*" }
                    if ($wintoys) {
                        Start-Process "shell:AppsFolder\$($wintoys.PackageFamilyName)!App"
                        Write-OK "Wintoys ejecutado"
                    } else {
                        Write-WARN "Wintoys no detectado - abrelo desde el menu Inicio"
                    }
                }
            } else {
                Write-ERR "Error en instalacion de Wintoys"
            }
        } catch {
            Write-ERR "Fallo: $($_.Exception.Message)"
        }
    } else {
        Write-ERR "Winget no disponible - instala App Installer desde Microsoft Store"
        Write-INFO "O descarga desde: https://aka.ms/getwinget"
    }
} else {
    Write-SKIP "Wintoys omitido"
}


# ════════════════════════════════════════════════════════════════
#  SECCIONES TÉCNICAS AVANZADAS
# ════════════════════════════════════════════════════════════════

# ════════════════════════════════════════════════════════════════
#  X. CPU / SCHEDULER TWEAKS AVANZADOS
# ════════════════════════════════════════════════════════════════

Write-Header "X" "CPU / SCHEDULER - TWEAKS AVANZADOS" "Magenta"
if (Ask-YN "Aplicar tweaks avanzados de CPU/Scheduler?" "s") {
    
    Write-Sub "Prioridad de procesos foreground"
    Set-Reg "$script:HKLM_System\Control\PriorityControl" "Win32PrioritySeparation" 26
    Write-OK "Prioridad foreground optimizada (valor 26)"
    
    Write-Sub "Dynamic Tick"
    Write-Host ""
    Write-Host "  Dynamic Tick reduce microstutters en algunos sistemas" -ForegroundColor Gray
    Write-Host "  Advertencia: puede empeorar latencia en CPUs muy modernos" -ForegroundColor Yellow
    Write-Host ""
    if (Ask-YN "Deshabilitar Dynamic Tick?" "n") {
        bcdedit /set disabledynamictick yes | Out-Null
        Write-OK "Dynamic Tick deshabilitado"
        $script:Riesgos.Add("  [!] Dynamic Tick off: REINICIO REQUERIDO")
    } else {
        Write-SKIP "Dynamic Tick sin cambios"
    }
    
    Write-Sub "HPET / Platform Clock"
    if (Ask-YN "Eliminar configuracion forzada de HPET/Platform Clock?" "s") {
        bcdedit /deletevalue useplatformclock 2>$null | Out-Null
        bcdedit /deletevalue useplatformtick 2>$null | Out-Null
        Write-OK "HPET forzado eliminado (sistema usara default)"
    }
    
    Write-Sub "Core Parking"
    Set-Reg "$script:HKLM_System\Control\Power" "CsEnabled" 0
    Write-OK "Core Parking deshabilitado (todos los cores activos)"
}

# ════════════════════════════════════════════════════════════════
#  Y. MEMORIA / RAM - TWEAKS AVANZADOS
# ════════════════════════════════════════════════════════════════

Write-Header "Y" "MEMORIA / RAM - TWEAKS AVANZADOS" "Magenta"
if (Ask-YN "Aplicar tweaks de memoria?" "s") {
    
    if ($sys.RAM -ge 16) {
        Write-Sub "Memory Compression (RAM 16GB+)"
        Write-Host ""
        Write-Host "  Memory Compression usa CPU para comprimir RAM" -ForegroundColor Gray
        Write-Host "  Con 16GB+ es mejor deshabilitarla" -ForegroundColor Yellow
        Write-Host ""
        if (Ask-YN "Deshabilitar Memory Compression?" "s") {
            try {
                Disable-MMAgent -MemoryCompression -EA Stop
                Write-OK "Memory Compression deshabilitada"
            } catch {
                Write-WARN "No se pudo deshabilitar: $($_.Exception.Message)"
            }
        }
    } else {
        Write-INFO "RAM < 16GB: Memory Compression se conserva"
    }
    
    Write-Sub "Page File (archivo de paginacion)"
    Write-Host ""
    Write-Host "  Page File manual evita fragmentacion" -ForegroundColor Gray
    Write-Host "  Recomendado: 4GB-8GB fijos" -ForegroundColor Yellow
    Write-Host ""
    if (Ask-YN "Configurar Page File manual (4GB fijo)?" "n") {
        wmic computersystem where name="%computername%" set AutomaticManagedPagefile=False 2>$null
        wmic pagefileset where name="C:\\pagefile.sys" set InitialSize=4096,MaximumSize=4096 2>$null
        Write-OK "Page File configurado: 4GB fijo"
        $script:Riesgos.Add("  [!] PageFile manual: ajustar segun RAM disponible")
    }
    
    Write-Sub "Large System Cache"
    Write-Host ""
    Write-Host "  Large System Cache prioriza cache de archivos sobre apps" -ForegroundColor Gray
    Write-Host "  Solo recomendado en workstations/servidores de archivos" -ForegroundColor Yellow
    Write-Host ""
    if (Ask-YN "Activar Large System Cache?" "n") {
        Set-Reg "$script:HKLM_System\Control\Session Manager\Memory Management" "LargeSystemCache" 1
        Write-OK "Large System Cache activado"
        $script:Riesgos.Add("  [!] LargeSystemCache: puede reducir RAM para apps")
    }
}

# ════════════════════════════════════════════════════════════════
#  Z. DISCO / NTFS - TWEAKS AVANZADOS
# ════════════════════════════════════════════════════════════════

Write-Header "Z" "DISCO / NTFS - TWEAKS AVANZADOS" "Magenta"
if (Ask-YN "Aplicar tweaks de disco/NTFS?" "s") {
    
    Write-Sub "NTFS - 8.3 Filenames"
    Write-INFO "Deshabilitando creacion de nombres 8.3 (legacy DOS)..."
    fsutil behavior set disable8dot3 1 | Out-Null
    Write-OK "Nombres 8.3 deshabilitados (menos overhead NTFS)"
    
    Write-Sub "NTFS - Last Access Time"
    Write-INFO "Deshabilitando actualizacion de ultimo acceso..."
    fsutil behavior set disablelastaccess 1 | Out-Null
    Write-OK "Last Access Time deshabilitado (menos escrituras)"
    
    if ($sys.IsSSD -or $sys.IsNVMe) {
        Write-Sub "SSD - TRIM Optimization"
        Write-INFO "Ejecutando TRIM en disco C:..."
        Optimize-Volume -DriveLetter C -ReTrim -Verbose *>&1 | Out-Null
        Write-OK "TRIM ejecutado en SSD"
        
        Write-Sub "SSD - Prefetch/Superfetch"
        Set-Reg "$script:HKLM_System\Control\Session Manager\Memory Management\PrefetchParameters" "EnablePrefetcher" 0
        Set-Reg "$script:HKLM_System\Control\Session Manager\Memory Management\PrefetchParameters" "EnableSuperfetch" 0
        Write-OK "Prefetch/Superfetch deshabilitados (innecesario en SSD)"
    } else {
        Write-INFO "HDD detectado: Prefetch/Superfetch conservados"
    }
    
    Write-Sub "Storage Sense"
    Set-Reg "$script:HKCU_Software\Microsoft\Windows\CurrentVersion\StorageSense\Parameters\StoragePolicy" "01" 0
    Write-OK "Storage Sense deshabilitado (limpieza manual mejor)"
    
    Write-Sub "WinSxS Component Cleanup"
    if (Ask-YN "Compactar WinSxS? (libera varios GB, lento)" "n") {
        Write-INFO "Limpiando WinSxS (puede tardar 5-10 min)..."
        Dism.exe /online /Cleanup-Image /StartComponentCleanup /ResetBase | Out-Null
        Write-OK "WinSxS compactado"
    }
}

# ════════════════════════════════════════════════════════════════
#  AA. TCP/IP STACK - TWEAKS AVANZADOS
# ════════════════════════════════════════════════════════════════

Write-Header "AA" "TCP/IP STACK - LATENCIA EXTREMA" "Magenta"
if (Ask-YN "Aplicar tweaks extremos de TCP/IP para latencia minima?" "n") {
    
    Write-WARN "Estos tweaks son para gamers competitivos/streaming"
    Write-Host ""
    
    Write-Sub "Nagle Algorithm OFF (ya aplicado antes)"
    Write-INFO "Nagle ya fue deshabilitado en seccion I (Red)"
    
    Write-Sub "USB Selective Suspend OFF"
    powercfg -setacvalueindex SCHEME_CURRENT SUB_USB USBSELECTIVESUSPEND 0 | Out-Null
    powercfg -setdcvalueindex SCHEME_CURRENT SUB_USB USBSELECTIVESUSPEND 0 | Out-Null
    powercfg -setactive SCHEME_CURRENT | Out-Null
    Write-OK "USB Selective Suspend deshabilitado (reduce input lag)"
    
    Write-Sub "Network Throttling Index"
    Set-Reg "$script:HKLM_Software\Microsoft\Windows NT\CurrentVersion\Multimedia\SystemProfile" "NetworkThrottlingIndex" 4294967295
    Write-OK "Network Throttling deshabilitado completamente"
    
    Write-Sub "TCP Optimizer - MaxUserPort"
    Set-Reg "$script:HKLM_System\Services\Tcpip\Parameters" "MaxUserPort" 65534
    Set-Reg "$script:HKLM_System\Services\Tcpip\Parameters" "TcpTimedWaitDelay" 30
    Write-OK "Puertos TCP ampliados (65534) y TIME_WAIT reducido"
    
    Write-Sub "Power Throttling OFF"
    Set-Reg "$script:HKLM_System\Control\Power\PowerThrottling" "PowerThrottlingOff" 1
    Write-OK "Power Throttling deshabilitado (Win10 1709+)"
}

# ════════════════════════════════════════════════════════════════
#  AB. KERNEL TWEAKS - VBS / HVCI / SPECTRE
# ════════════════════════════════════════════════════════════════

Write-Header "AB" "KERNEL TWEAKS - VBS / HVCI / MITIGACIONES" "Red"
Write-Host ""
Write-Host "  ═══════════════════════════════════════════════════════════════" -ForegroundColor Red
Write-Host "  ADVERTENCIA: Estos tweaks mejoran rendimiento CPU" -ForegroundColor Yellow
Write-Host "  pero REDUCEN SEGURIDAD contra ataques especulativos" -ForegroundColor Yellow
Write-Host "  Solo aplicar en PCs gaming/personales, NO en empresas" -ForegroundColor Yellow
Write-Host "  ═══════════════════════════════════════════════════════════════" -ForegroundColor Red
Write-Host ""

if (Ask-YN "Aplicar kernel tweaks? (AVANZADO)" "n") {
    
    Write-Sub "VBS / HVCI / Core Isolation"
    Write-Host ""
    Write-Host "  VBS (Virtualization Based Security) usa CPU extra" -ForegroundColor Gray
    Write-Host "  Impacto: 5-15% rendimiento segun CPU" -ForegroundColor Yellow
    Write-Host ""
    if (Ask-YN "Deshabilitar VBS/HVCI?" "s") {
        Set-Reg "$script:HKLM_System\Control\DeviceGuard" "EnableVirtualizationBasedSecurity" 0
        Set-Reg "$script:HKLM_System\Control\DeviceGuard" "RequirePlatformSecurityFeatures" 0
        Set-Reg "$script:HKLM_System\Control\Lsa" "LsaCfgFlags" 0
        Set-Reg "$script:HKLM_System\Control\DeviceGuard\Scenarios\HypervisorEnforcedCodeIntegrity" "Enabled" 0
        bcdedit /set hypervisorlaunchtype off | Out-Null
        Write-OK "VBS/HVCI deshabilitado"
        $script:Riesgos.Add("  [!] VBS/HVCI off: REINICIO REQUERIDO, seguridad reducida")
    }
    
    Write-Sub "Mitigaciones Spectre/Meltdown"
    Write-Host ""
    Write-Host "  Deshabilitar mitigaciones mejora CPU ~5-10%" -ForegroundColor Gray
    Write-Host "  Riesgo: vulnerable a ataques especulativos" -ForegroundColor Red
    Write-Host ""
    if (Ask-YN "Deshabilitar mitigaciones Spectre/Meltdown?" "n") {
        Set-Reg "$script:HKLM_System\Control\Session Manager\Memory Management" "FeatureSettingsOverride" 3
        Set-Reg "$script:HKLM_System\Control\Session Manager\Memory Management" "FeatureSettingsOverrideMask" 3
        Write-OK "Mitigaciones Spectre/Meltdown deshabilitadas"
        $script:Riesgos.Add("  [!] Spectre/Meltdown off: REINICIO REQUERIDO, SEGURIDAD REDUCIDA")
    }
    
    Write-Sub "Hyper-V Hypervisor"
    if (Ask-YN "Deshabilitar Hypervisor completamente?" "n") {
        bcdedit /set hypervisorlaunchtype off | Out-Null
        Disable-Svc "vmcompute" "VM Compute"
        Disable-Svc "vmms" "Hyper-V Management"
        Write-OK "Hypervisor deshabilitado"
        $script:Riesgos.Add("  [!] Hypervisor off: VMs no funcionaran, WSL2 afectado")
    }
}

# ════════════════════════════════════════════════════════════════
#  AC. GAMING EXTREMO - MMCSS / GPU / DWM
# ════════════════════════════════════════════════════════════════

Write-Header "AC" "GAMING EXTREMO - MMCSS / GPU PRIORITY / DWM" "Green"
if (Ask-YN "Aplicar optimizaciones gaming extremas?" "s") {
    
    Write-Sub "MMCSS - Multimedia Class Scheduler"
    $mmPath = "$script:HKLM_Software\Microsoft\Windows NT\CurrentVersion\Multimedia\SystemProfile"
    Set-Reg $mmPath "SystemResponsiveness" 0
    Write-OK "SystemResponsiveness = 0 (prioridad maxima juegos)"
    
    $gamePath = "$mmPath\Tasks\Games"
    if (-not (Test-Path $gamePath)) { New-Item -Path $gamePath -Force | Out-Null }
    Set-ItemProperty -Path $gamePath -Name "GPU Priority" -Value 8 -Type DWord -EA SilentlyContinue
    Set-ItemProperty -Path $gamePath -Name "Priority" -Value 6 -Type DWord -EA SilentlyContinue
    Set-ItemProperty -Path $gamePath -Name "Scheduling Category" -Value "High" -Type String -EA SilentlyContinue
    Set-ItemProperty -Path $gamePath -Name "SFIO Priority" -Value "High" -Type String -EA SilentlyContinue
    Write-OK "GPU Priority = 8, Scheduling = High"
    
    Write-Sub "Game Bar / Game DVR"
    Set-Reg "$script:HKCU_Software\Microsoft\Windows\CurrentVersion\GameDVR" "AppCaptureEnabled" 0
    Set-Reg "$script:HKCU_Software\Microsoft\GameBar" "ShowStartupPanel" 0
    Set-Reg "$script:HKCU_Software\Microsoft\GameBar" "UseNexusForGameBarEnabled" 0
    Set-Reg "$script:HKLM_Software\Policies\Microsoft\Windows\GameDVR" "AllowGameDVR" 0
    Write-OK "Game Bar/DVR deshabilitado completamente"
    
    Write-Sub "Hardware Accelerated GPU Scheduling"
    if ($sys.IsWin10 -and $sys.Build -ge 19041) {
        if (Ask-YN "Activar Hardware GPU Scheduling (Win10 2004+)?" "s") {
            Set-Reg "$script:HKLM_System\Control\GraphicsDrivers" "HwSchMode" 2
            Write-OK "Hardware GPU Scheduling activado"
            $script:Riesgos.Add("  [!] HwSchMode: REINICIO REQUERIDO para aplicar")
        }
    } elseif ($sys.IsWin11) {
        Set-Reg "$script:HKLM_System\Control\GraphicsDrivers" "HwSchMode" 2
        Write-OK "Hardware GPU Scheduling activado (Win11)"
    }
    
    Write-Sub "TDR Delay (GPU timeout)"
    Write-Host ""
    Write-Host "  TDR Delay evita micro-freezes de GPU" -ForegroundColor Gray
    Write-Host "  Valor 10 = 10 segundos antes de reset" -ForegroundColor Yellow
    Write-Host ""
    if (Ask-YN "Configurar TDR Delay = 10?" "s") {
        Set-Reg "$script:HKLM_System\Control\GraphicsDrivers" "TdrDelay" 10
        Set-Reg "$script:HKLM_System\Control\GraphicsDrivers" "TdrDdiDelay" 10
        Write-OK "TDR Delay configurado"
    }
    
    Write-Sub "DWM (Desktop Window Manager)"
    if (Ask-YN "Optimizar DWM para gaming?" "s") {
        Set-Reg "$script:HKCU_Software\Microsoft\Windows\DWM" "UseDpiScaling" 0
        Set-Reg "$script:HKCU_Software\Microsoft\Windows\DWM" "EnableAeroPeek" 0
        Set-Reg "$script:HKCU_Software\Microsoft\Windows\DWM" "AlwaysHibernateThumbnails" 0
        Write-OK "DWM optimizado (Aero Peek off, DPI scaling off)"
    }
}

# ════════════════════════════════════════════════════════════════
#  AD. TAREAS PROGRAMADAS - DESHABILITAR TELEMETRÍA
# ════════════════════════════════════════════════════════════════

Write-Header "AD" "TAREAS PROGRAMADAS - TELEMETRIA Y DIAGNOSTICOS" "Yellow"
if (Ask-YN "Deshabilitar tareas programadas de telemetria?" "s") {
    
    $taskPaths = @(
        "\Microsoft\Windows\Application Experience\*",
        "\Microsoft\Windows\Autochk\*",
        "\Microsoft\Windows\Customer Experience Improvement Program\*",
        "\Microsoft\Windows\DiskDiagnostic\*",
        "\Microsoft\Windows\Maintenance\*",
        "\Microsoft\Windows\PI\*",
        "\Microsoft\Windows\Power Efficiency Diagnostics\*",
        "\Microsoft\Windows\Windows Error Reporting\*"
    )
    
    $disabled = 0
    foreach ($path in $taskPaths) {
        Get-ScheduledTask -TaskPath $path -EA SilentlyContinue | ForEach-Object {
            Disable-ScheduledTask -TaskName $_.TaskName -TaskPath $_.TaskPath -EA SilentlyContinue | Out-Null
            $disabled++
        }
    }
    
    Write-OK "Tareas deshabilitadas: $disabled"
    
    # Tareas específicas importantes
    $criticalTasks = @(
        "\Microsoft\Windows\Application Experience\Microsoft Compatibility Appraiser",
        "\Microsoft\Windows\Application Experience\ProgramDataUpdater",
        "\Microsoft\Windows\Autochk\Proxy",
        "\Microsoft\Windows\Customer Experience Improvement Program\Consolidator",
        "\Microsoft\Windows\Customer Experience Improvement Program\UsbCeip",
        "\Microsoft\Windows\DiskDiagnostic\Microsoft-Windows-DiskDiagnosticDataCollector"
    )
    
    foreach ($task in $criticalTasks) {
        Disable-ScheduledTask -TaskName $task -EA SilentlyContinue | Out-Null
    }
    
    Write-OK "Tareas criticas de telemetria deshabilitadas"
}


# ════════════════════════════════════════════════════════════════
#  REINICIAR EXPLORER
# ════════════════════════════════════════════════════════════════

Write-Header ">" "REINICIAR EXPLORER"
if (Ask-YN "Reiniciar Explorer para aplicar cambios visuales?" "s") {
    Write-INFO "Reiniciando Explorer..."
    Get-Process explorer -EA SilentlyContinue | Stop-Process -Force -EA SilentlyContinue
    Start-Sleep -Seconds 2
    Start-Process explorer.exe
    Write-OK "Explorer reiniciado"
}

# ════════════════════════════════════════════════════════════════
#  LIMPIEZA AUTOMATICA AL REINICIAR
# ════════════════════════════════════════════════════════════════

Write-Header "~" "LIMPIEZA AUTOMATICA AL REINICIAR"

if ($script:TempParaLimpiar.Count -gt 0) {
    $cleanScript = "$env:TEMP\cleanup_optwin_v6.ps1"
    
    $lines = @("# Auto-limpieza generada por Optimizador Windows v6.0")
    $lines += "Start-Sleep -Seconds 10  # Esperar a que los procesos cierren"
    
    foreach ($f in $script:TempParaLimpiar) {
        $lines += "if (Test-Path '$f') { Remove-Item '$f' -Recurse -Force -EA SilentlyContinue }"
    }
    
    # Autoeliminar la tarea y el propio script al final
    $lines += "Unregister-ScheduledTask -TaskName 'CleanupOptWin_v6' -Confirm:`$false -EA SilentlyContinue"
    $lines += "Remove-Item '$cleanScript' -Force -EA SilentlyContinue"
    
    $lines | Out-File -FilePath $cleanScript -Encoding UTF8 -Force
    
    # Registrar tarea programada que corre una vez al proximo inicio
    $action = New-ScheduledTaskAction -Execute "powershell.exe" `
        -Argument "-WindowStyle Hidden -ExecutionPolicy Bypass -File `"$cleanScript`""
    $trigger = New-ScheduledTaskTrigger -AtStartup
    $settings = New-ScheduledTaskSettingsSet -ExecutionTimeLimit (New-TimeSpan -Minutes 2)
    
    Register-ScheduledTask -TaskName "CleanupOptWin_v6" `
        -Action $action -Trigger $trigger -Settings $settings `
        -RunLevel Highest -Force -EA SilentlyContinue | Out-Null
    
    Write-OK "Tarea de limpieza programada para el proximo reinicio"
    Write-INFO "Archivos a eliminar: $($script:TempParaLimpiar.Count)"
} else {
    Write-SKIP "No hay archivos temporales para limpiar"
}

# ════════════════════════════════════════════════════════════════
#  RESUMEN FINAL
# ════════════════════════════════════════════════════════════════

$script:Stopwatch.Stop()
$elapsed = $script:Stopwatch.Elapsed
$timeStr = "{0:D2}m {1:D2}s" -f $elapsed.Minutes, $elapsed.Seconds

Clear-Host
Write-Host ""
Write-Host "  ════════════════════════════════════════════════════════════════" -ForegroundColor Green
Write-Host "     ✓ OPTIMIZACIÓN COMPLETADA - Windows v6.0 ULTIMATE" -ForegroundColor Green
Write-Host "  ════════════════════════════════════════════════════════════════" -ForegroundColor Green
Write-Host ""

# Panel de información
Write-Host "  ╔══════════════════════════════════════════════════════════════╗" -ForegroundColor Cyan
Write-Host "  ║  INFORMACIÓN DEL SISTEMA                                     ║" -ForegroundColor Cyan
Write-Host "  ╠══════════════════════════════════════════════════════════════╣" -ForegroundColor Cyan
Write-Host "  ║  OS:      $($sys.WinName.PadRight(49)) ║" -ForegroundColor White
Write-Host "  ║  Build:   $($sys.BuildStr.PadRight(49)) ║" -ForegroundColor White
Write-Host "  ║  Perfil:  Gama $gamaStr | Uso $($usoStr.PadRight(34)) ║" -ForegroundColor White
Write-Host "  ╚══════════════════════════════════════════════════════════════╝" -ForegroundColor Cyan
Write-Host ""

# Tabla de estadísticas
Write-Host "  ╔══════════════════════════════════════════════════════════════╗" -ForegroundColor Yellow
Write-Host "  ║  ESTADÍSTICAS                                                ║" -ForegroundColor Yellow
Write-Host "  ╠══════════════════════════════════════════════════════════════╣" -ForegroundColor Yellow
Write-Host "  ║  Tweaks aplicados:    $($script:Aplicados.ToString().PadRight(38)) ║" -ForegroundColor Green
Write-Host "  ║  Tweaks omitidos:     $($script:Omitidos.ToString().PadRight(38)) ║" -ForegroundColor Gray
Write-Host "  ║  Tiempo total:        $($timeStr.PadRight(38)) ║" -ForegroundColor Cyan
Write-Host "  ║  Log generado:        C:\OptimizadorWindows_v6.log$(" ".PadRight(13)) ║" -ForegroundColor White
Write-Host "  ╚══════════════════════════════════════════════════════════════╝" -ForegroundColor Yellow
Write-Host ""

# Riesgos y advertencias
if ($script:Riesgos.Count -gt 0) {
    Write-Host "  ╔══════════════════════════════════════════════════════════════╗" -ForegroundColor Red
    Write-Host "  ║  ⚠ ADVERTENCIAS Y CONSIDERACIONES                            ║" -ForegroundColor Red
    Write-Host "  ╠══════════════════════════════════════════════════════════════╣" -ForegroundColor Red
    foreach ($r in $script:Riesgos) {
        $rClean = $r -replace "^\s*\[!\]\s*", ""
        $lines = [System.Text.RegularExpressions.Regex]::Split($rClean, "(.{1,56})")
        foreach ($line in $lines) {
            if ($line.Trim()) {
                Write-Host "  ║  $($line.PadRight(60)) ║" -ForegroundColor Yellow
            }
        }
    }
    Write-Host "  ╚══════════════════════════════════════════════════════════════╝" -ForegroundColor Red
    Write-Host ""
}

# Recomendaciones finales
Write-Host "  ════════════════════════════════════════════════════════════════" -ForegroundColor Magenta
Write-Host "   PRÓXIMOS PASOS RECOMENDADOS:" -ForegroundColor Magenta
Write-Host "  ════════════════════════════════════════════════════════════════" -ForegroundColor Magenta
Write-Host ""

$needReboot = $false
foreach ($r in $script:Riesgos) {
    if ($r -match "REINICIO") { $needReboot = $true; break }
}

if ($needReboot) {
    Write-Host "  [1] REINICIAR EL EQUIPO" -ForegroundColor Red
    Write-Host "      Los cambios de kernel, VBS, red y servicios requieren reinicio" -ForegroundColor Gray
    Write-Host ""
}

Write-Host "  [2] Revisar el log completo" -ForegroundColor Cyan
Write-Host "      C:\OptimizadorWindows_v6.log" -ForegroundColor Gray
Write-Host ""

Write-Host "  [3] Probar rendimiento" -ForegroundColor Green
Write-Host "      - Benchmark CPU/GPU antes y despues" -ForegroundColor Gray
Write-Host "      - Medir latencia de red (ping, jitter)" -ForegroundColor Gray
Write-Host "      - Revisar uso de RAM/CPU en reposo" -ForegroundColor Gray
Write-Host ""

Write-Host "  [4] Si algo falla:" -ForegroundColor Yellow
Write-Host "      - Restaurar punto creado al inicio" -ForegroundColor Gray
Write-Host "      - Revisar backups de registro en C:\" -ForegroundColor Gray
Write-Host ""

Write-Host "  ════════════════════════════════════════════════════════════════" -ForegroundColor Magenta
Write-Host ""

# Exportar configuración aplicada
Write-Host "  >> Exportar resumen de cambios a archivo? (s/N): " -NoNewline -ForegroundColor Cyan
$exportar = Read-Host
if ($exportar -eq "s" -or $exportar -eq "S") {
    $reportPath = "$env:USERPROFILE\Desktop\OptimizadorReport_v6.txt"
    $report = @"
═════════════════════════════════════════════════════════════════
OPTIMIZADOR WINDOWS v6.0 ULTIMATE - REPORTE DE EJECUCIÓN
═════════════════════════════════════════════════════════════════

Fecha: $(Get-Date -Format "yyyy-MM-dd HH:mm:ss")
Usuario: $env:USERNAME
Computadora: $env:COMPUTERNAME

SISTEMA:
--------
OS: $($sys.WinName)
Build: $($sys.BuildStr)
CPU: $($sys.CPU)
RAM: $($sys.RAMStr)
Disco: $($sys.Disk)
GPU: $($sys.GPU)

PERFIL SELECCIONADO:
--------------------
Gama: $gamaStr
Uso: $usoStr

ESTADÍSTICAS:
-------------
Tweaks aplicados: $($script:Aplicados)
Tweaks omitidos: $($script:Omitidos)
Tiempo de ejecución: $timeStr

ADVERTENCIAS:
-------------
$($script:Riesgos -join "`n")

LOG COMPLETO:
-------------
Ver: C:\OptimizadorWindows_v6.log

═════════════════════════════════════════════════════════════════
Script desarrollado por FacuxD23
GitHub: https://github.com/FacuxD23/-
═════════════════════════════════════════════════════════════════
"@
    
    $report | Out-File -FilePath $reportPath -Encoding UTF8
    Write-OK "Reporte exportado: $reportPath"
}

Write-Host ""
Write-Host "  ════════════════════════════════════════════════════════════════" -ForegroundColor Green
Write-Host ""

if ($needReboot) {
    Write-Host "  >> REINICIAR AHORA? (s/N): " -NoNewline -ForegroundColor Red
    $rb = Read-Host
    if ($rb -eq "s" -or $rb -eq "S") {
        Write-Host ""
        Write-Host "  Reiniciando en 10 segundos..." -ForegroundColor Yellow
        Write-Host "  Presiona Ctrl+C para cancelar" -ForegroundColor Gray
        Start-Sleep -Seconds 10
        Restart-Computer -Force
    }
}

Write-Host ""
Write-Host "  Presiona ENTER para cerrar..." -ForegroundColor Gray
Read-Host

# FIN DEL SCRIPT
# ════════════════════════════════════════════════════════════════
#  FUNCIONES CORE
# ════════════════════════════════════════════════════════════════

function Write-Log {
    param([string]$Message, [string]$Level = "INFO")
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    try {
        "$timestamp [$Level] $Message" | Out-File -FilePath $script:LogFile -Append -Encoding UTF8
    } catch {}
}

function Ask-YN {
    param([string]$Question, [string]$Default = "s")
    if ($script:ModoSilencio) { return ($Default -eq "s") }
    $response = Read-Host "  >> $Question (S/n)"
    return ($response -eq "" -and $Default -eq "s") -or ($response -eq "s" -or $response -eq "S")
}

function Write-Banner {
    param([string]$Text)
    Write-Host ""
    Write-Host "  ════════════════════════════════════════════════════════════════" -ForegroundColor Cyan
    Write-Host "  $Text" -ForegroundColor White
    Write-Host "  ════════════════════════════════════════════════════════════════" -ForegroundColor Cyan
    Write-Host ""
}

function Write-Header {
    param([string]$Section, [string]$Title, [string]$Color = "Cyan")
    Write-Host ""
    Write-Host "  ════════════════════════════════════════════════════════════════" -ForegroundColor $Color
    Write-Host "  [$Section] $Title" -ForegroundColor White
    Write-Host "  ════════════════════════════════════════════════════════════════" -ForegroundColor $Color
    Write-Host ""
}

function Write-Sub {
    param([string]$Text)
    Write-Host "  ─── $Text ───" -ForegroundColor DarkCyan
}

function Write-OK    { param([string]$T) Write-Host "  [✓]  $T" -ForegroundColor Green;      $script:Aplicados++; Write-Log $T "OK" }
function Write-OFF   { param([string]$T) Write-Host "  [■]  $T" -ForegroundColor DarkGray;   $script:Aplicados++; Write-Log $T "OFF" }
function Write-MAN   { param([string]$T) Write-Host "  [~]  $T" -ForegroundColor Yellow;     $script:Aplicados++; Write-Log $T "MANUAL" }
function Write-SKIP  { param([string]$T) Write-Host "  [─]  $T" -ForegroundColor DarkGray;   $script:Omitidos++;  Write-Log $T "SKIP" }
function Write-WARN  { param([string]$T) Write-Host "  [!]  $T" -ForegroundColor Yellow;     Write-Log $T "WARN" }
function Write-ERR   { param([string]$T) Write-Host "  [✗]  $T" -ForegroundColor Red;        Write-Log $T "ERROR" }
function Write-INFO  { param([string]$T) Write-Host "  [i]  $T" -ForegroundColor Cyan;       Write-Log $T "INFO" }

function Disable-Svc {
    param([string]$Name, [string]$Desc, [string]$Riesgo = "")
    try {
        $svc = Get-Service -Name $Name -ErrorAction Stop
        if ($svc.Status -ne "Stopped") {
            Stop-Service -Name $Name -Force -ErrorAction SilentlyContinue
        }
        Set-Service -Name $Name -StartupType Disabled -ErrorAction Stop
        Write-OFF "$Desc ($Name)"
        if ($Riesgo) { 
            $riesgoMsg = "  [!] " + $Desc + ": " + $Riesgo
            $script:Riesgos.Add($riesgoMsg)
        }
    } catch {
        Write-SKIP "Servicio no encontrado: $Name"
    }
}

function Set-Manual {
    param([string]$Name, [string]$Desc)
    try {
        $svc = Get-Service -Name $Name -ErrorAction Stop
        Set-Service -Name $Name -StartupType Manual -ErrorAction Stop
        Write-MAN "$Desc ($Name)"
    } catch {
        Write-SKIP "Servicio no encontrado: $Name"
    }
}

function Set-Reg {
    param(
        [string]$Path,
        [string]$Name,
        $Value,
        [string]$Type = "DWord"
    )
    try {
        if (-not (Test-Path $Path)) {
            New-Item -Path $Path -Force -ErrorAction Stop | Out-Null
        }
        
        $current = (Get-ItemProperty -Path $Path -Name $Name -EA SilentlyContinue).$Name
        if ($current -ne $Value) {
            Set-ItemProperty -Path $Path -Name $Name -Value $Value -Type $Type -ErrorAction Stop
            return $true
        }
        return $false
    } catch {
        Write-Log "Error en Set-Reg: $Path\$Name - $($_.Exception.Message)" "ERROR"
        return $false
    }
}

function Backup-RegistryKey {
    param([string]$Path, [string]$Name)
    if (-not $script:Backup) { return }
    
    try {
        $timestamp = Get-Date -Format "yyyyMMdd_HHmmss"
        $safeName = $Name -replace '[\\/:*?"<>|]', '_'
        $backupFile = "$script:BackupDir\${safeName}_$timestamp.reg"
        $regPath = $Path -replace "HKLM:", "HKEY_LOCAL_MACHINE" -replace "HKCU:", "HKEY_CURRENT_USER"
        reg export $regPath $backupFile /y 2>&1 | Out-Null
        Write-Log "Backup creado: $backupFile" "BACKUP"
    } catch {
        Write-Log "Error creando backup de $Name" "ERROR"
    }
}

# ════════════════════════════════════════════════════════════════
#  DETECCIÓN AVANZADA DE HARDWARE
# ════════════════════════════════════════════════════════════════

function Get-SystemInfo {
    $cs = Get-CimInstance Win32_ComputerSystem
    $os = Get-CimInstance Win32_OperatingSystem
    $cpu = Get-CimInstance Win32_Processor | Select-Object -First 1
    $bios = Get-CimInstance Win32_BIOS
    
    # Detección de tipo de dispositivo
    $isLaptop = $false
    $chassisTypes = @(8, 9, 10, 11, 12, 14, 18, 21, 30, 31, 32)  # Laptop/Portable chassis
    try {
        $chassis = (Get-CimInstance Win32_SystemEnclosure).ChassisTypes[0]
        $isLaptop = $chassisTypes -contains $chassis
    } catch {
        # Fallback: detectar batería
        $battery = Get-CimInstance Win32_Battery -EA SilentlyContinue
        $isLaptop = $null -ne $battery
    }
    
    # Detección de disco
    $disk = Get-PhysicalDisk | Where-Object { $_.DeviceID -eq 0 } | Select-Object -First 1
    $isHDD = $disk.MediaType -eq "HDD"
    $isSSD = $disk.MediaType -eq "SSD"
    $isNVMe = $disk.BusType -eq "NVMe"
    
    # RAM
    $ramGB = [math]::Round($cs.TotalPhysicalMemory / 1GB, 2)
    
    # GPU
    $gpu = (Get-CimInstance Win32_VideoController | Where-Object { $_.Name -notlike "*Microsoft*" } | Select-Object -First 1).Name
    
    # Build info
    $build = $os.BuildNumber
    $ubr = (Get-ItemProperty "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion").UBR
    $isWin11 = $build -ge 22000
    $isWin10 = $build -ge 10240 -and $build -lt 22000
    
    return [PSCustomObject]@{
        WinName     = $os.Caption
        WinVer      = $os.Version
        Build       = [int]$build
        UBR         = $ubr
        BuildStr    = "$build.$ubr"
        IsWin11     = $isWin11
        IsWin10     = $isWin10
        IsLaptop    = $isLaptop
        IsDesktop   = -not $isLaptop
        CPU         = $cpu.Name
        CPUCores    = $cpu.NumberOfCores
        CPUThreads  = $cpu.NumberOfLogicalProcessors
        RAM         = $ramGB
        RAMStr      = "${ramGB}GB"
        Disk        = $disk.FriendlyName
        IsHDD       = $isHDD
        IsSSD       = $isSSD
        IsNVMe      = $isNVMe
        GPU         = $gpu
        Uptime      = [math]::Round((Get-Date) - $os.LastBootUpTime).TotalHours, 2)
        Manufacturer = $cs.Manufacturer
        Model       = $cs.Model
    }
}

$sys = Get-SystemInfo

# ════════════════════════════════════════════════════════════════
#  BANNER Y INFO DEL SISTEMA
# ════════════════════════════════════════════════════════════════

Clear-Host
Write-Host ""
Write-Host "  ╔══════════════════════════════════════════════════════════════╗" -ForegroundColor Cyan
Write-Host "  ║                                                              ║" -ForegroundColor Cyan
Write-Host "  ║   OPTIMIZADOR WINDOWS v6.0 PRO EDITION                       ║" -ForegroundColor White
Write-Host "  ║   Servicios · Registro · Red · Bloatware · Tweaks Avanzados ║" -ForegroundColor Gray
Write-Host "  ║                                                              ║" -ForegroundColor Cyan
Write-Host "  ╚══════════════════════════════════════════════════════════════╝" -ForegroundColor Cyan
Write-Host ""

Write-Host "  ╔══════════════════════════════════════════════════════════════╗" -ForegroundColor Yellow
Write-Host "  ║  INFORMACIÓN DEL SISTEMA                                     ║" -ForegroundColor Yellow
Write-Host "  ╠══════════════════════════════════════════════════════════════╣" -ForegroundColor Yellow
Write-Host "  ║  OS:          $($sys.WinName.PadRight(45)) ║" -ForegroundColor White
Write-Host "  ║  Build:       $($sys.BuildStr.PadRight(45)) ║" -ForegroundColor White
Write-Host "  ║  Tipo:        $(if($sys.IsLaptop){'Laptop'}else{'Desktop'}).PadRight(45)) ║" -ForegroundColor White
Write-Host "  ║  CPU:         $($sys.CPU.Substring(0,[Math]::Min(45,$sys.CPU.Length)).PadRight(45)) ║" -ForegroundColor White
Write-Host "  ║  Cores/THR:   $("$($sys.CPUCores)C / $($sys.CPUThreads)T".PadRight(45)) ║" -ForegroundColor White
Write-Host "  ║  RAM:         $($sys.RAMStr.PadRight(45)) ║" -ForegroundColor White
Write-Host "  ║  Disco:       $(if($sys.IsNVMe){'NVMe SSD'}elseif($sys.IsSSD){'SSD'}else{'HDD'}).PadRight(45)) ║" -ForegroundColor White
Write-Host "  ║  GPU:         $($sys.GPU.Substring(0,[Math]::Min(45,$sys.GPU.Length)).PadRight(45)) ║" -ForegroundColor White
Write-Host "  ╚══════════════════════════════════════════════════════════════╝" -ForegroundColor Yellow
Write-Host ""

# Modo de operación
Write-Host "  ╔══════════════════════════════════════════════════════════════╗" -ForegroundColor Magenta
Write-Host "  ║  MODO DE OPERACIÓN                                           ║" -ForegroundColor Magenta
Write-Host "  ╠══════════════════════════════════════════════════════════════╣" -ForegroundColor Magenta
Write-Host "  ║  Perfil:      $($script:PerfilActivo.PadRight(45)) ║" -ForegroundColor White
Write-Host "  ║  Seguro:      $(if($script:ModoSeguro){'✓ SI'}else{'✗ NO'}).PadRight(45)) ║" -ForegroundColor $(if($script:ModoSeguro){'Green'}else{'Gray'})
Write-Host "  ║  Agresivo:    $(if($script:ModoAgresivo){'✓ SI'}else{'✗ NO'}).PadRight(45)) ║" -ForegroundColor $(if($script:ModoAgresivo){'Red'}else{'Gray'})
Write-Host "  ║  Silencioso:  $(if($script:ModoSilencio){'✓ SI'}else{'✗ NO'}).PadRight(45)) ║" -ForegroundColor $(if($script:ModoSilencio){'Yellow'}else{'Gray'})
Write-Host "  ║  Backup:      $(if($Backup){'✓ SI'}else{'✗ NO'}).PadRight(45)) ║" -ForegroundColor $(if($Backup){'Green'}else{'Gray'})
Write-Host "  ╚══════════════════════════════════════════════════════════════╝" -ForegroundColor Magenta
Write-Host ""

# Advertencias basadas en hardware
if ($sys.IsLaptop) {
    Write-Host "  [!] LAPTOP DETECTADO - Se deshabilitarán tweaks agresivos de energía" -ForegroundColor Yellow
}
if ($sys.IsHDD) {
    Write-Host "  [!] HDD DETECTADO - Se conservarán servicios de indexación" -ForegroundColor Yellow
}
if ($sys.RAM -lt 8) {
    Write-Host "  [!] RAM BAJA (<8GB) - Se conservarán servicios de compresión" -ForegroundColor Yellow
}
if ($sys.Build -lt 19041) {
    Write-Host "  [!] Windows 10 antiguo - Algunos tweaks no disponibles" -ForegroundColor Yellow
}

Write-Host ""
if (-not $script:ModoSilencio) {
    Read-Host "  Presiona ENTER para continuar"
}


# ════════════════════════════════════════════════════════════════
#  TWEAKS ADAPTATIVOS SEGÚN HARDWARE
# ════════════════════════════════════════════════════════════════

# Esta sección se ejecuta DESPUÉS de todos los tweaks base
# y aplica ajustes específicos según el hardware detectado

Write-Header "AE" "AJUSTES ADAPTATIVOS - HARDWARE SPECIFIC" "Magenta"

if ($sys.IsLaptop) {
    Write-Sub "Ajustes para Laptop"
    
    # NO deshabilitar hibernación en laptops
    powercfg /h on 2>$null | Out-Null
    Write-INFO "Hibernacion conservada (Laptop)"
    
    # Plan de energia: Equilibrado en vez de Ultimate
    if (-not $script:ModoAgresivo) {
        powercfg /setactive 381b4222-f694-41f0-9685-ff5bb260df2e 2>$null
        Write-INFO "Plan de energia: Equilibrado (Laptop)"
    }
    
    # NO deshabilitar Conectividad en modo espera
    Set-Reg "$script:HKLM_System\Control\Power" "CsEnabled" 1
    Write-INFO "Connected Standby conservado (Laptop)"
    
    # Conservar servicios de batería
    Write-INFO "Servicios de bateria conservados"
    
} else {
    Write-Sub "Ajustes para Desktop"
    
    # Deshabilitar hibernación (libera RAM GB de espacio)
    if ($script:ModoAgresivo -or (Ask-YN "Deshabilitar hibernacion? (libera $([math]::Round($sys.RAM, 0)) GB)" "s")) {
        powercfg /h off 2>$null | Out-Null
        Write-OK "Hibernacion deshabilitada (Desktop)"
    }
    
    # Plan Ultimate Performance si está disponible
    if ($script:ModoAgresivo -or $Performance) {
        powercfg -duplicatescheme e9a42b02-d5df-448d-aa00-03f14749eb61 2>$null
        $uidLine = powercfg /list | Select-String -Pattern "Ultimate|Ultimo" | Select-Object -First 1
        if ($uidLine) {
            $uid = ([regex]::Match($uidLine, "([0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12})")).Value
            if ($uid) {
                powercfg /setactive $uid 2>$null
                Write-OK "Plan: Ultimate Performance (Desktop)"
            }
        }
    }
}

if ($sys.IsHDD) {
    Write-Sub "Ajustes para HDD"
    
    # Mantener Superfetch en HDD
    Set-Manual "SysMain" "SysMain conservado (util en HDD)"
    
    # Desfragmentación programada
    Set-Manual "defragsvc" "Desfragmentador conservado (HDD)"
    
    # NO deshabilitar prefetch
    Write-INFO "Prefetch/Superfetch conservados para HDD"
    
} elseif ($sys.IsNVMe) {
    Write-Sub "Ajustes para NVMe SSD"
    
    # Tweaks agresivos para NVMe
    Disable-Svc "SysMain" "SysMain/Superfetch (innecesario en NVMe)"
    Disable-Svc "defragsvc" "Desfragmentador (perjudicial en SSD)"
    
    # StorNVMe optimizations
    Set-Reg "$script:HKLM_System\Services\stornvme\Parameters\Device" "FUA_Support" 0
    Write-OK "NVMe: FUA Support deshabilitado (mejor rendimiento)"
    
} else {
    Write-Sub "Ajustes para SSD SATA"
    
    Disable-Svc "SysMain" "SysMain/Superfetch (innecesario en SSD)"
    Disable-Svc "defragsvc" "Desfragmentador programado"
}

if ($sys.RAM -lt 8) {
    Write-Sub "Ajustes para RAM baja (<8GB)"
    
    # Mantener Memory Compression
    Write-INFO "Memory Compression conservada (RAM < 8GB)"
    
    # Page File más grande
    Write-INFO "PageFile: se recomienda manual 2x RAM"
    
} elseif ($sys.RAM -ge 16) {
    Write-Sub "Ajustes para RAM alta (16GB+)"
    
    # Deshabilitar Memory Compression
    if ($script:ModoAgresivo -or (Ask-YN "Deshabilitar Memory Compression? (RAM 16GB+)" "s")) {
        try {
            Disable-MMAgent -MemoryCompression -EA Stop
            Write-OK "Memory Compression deshabilitada"
        } catch {
            Write-WARN "No se pudo deshabilitar: $($_.Exception.Message)"
        }
    }
}


# ════════════════════════════════════════════════════════════════
#  PUNTO DE RESTAURACIÓN
# ════════════════════════════════════════════════════════════════

Write-Header "0" "PUNTO DE RESTAURACION DEL SISTEMA" "Yellow"
Write-Host ""
Write-Host "  Creando punto de restauracion del sistema..." -ForegroundColor Yellow
Write-Host "  Esto permite revertir cambios si algo sale mal." -ForegroundColor Gray
Write-Host ""

try {
    Write-INFO "Creando punto de restauracion (obligatorio)..."
    $restoreDesc = "Optimizador Windows v6.0 - $(Get-Date -Format 'yyyy-MM-dd HH:mm')"
    Checkpoint-Computer -Description $restoreDesc -RestorePointType "MODIFY_SETTINGS" -ErrorAction Stop
    Write-OK "Punto de restauracion creado correctamente"
    Write-Host ""
    Start-Sleep -Seconds 2
} catch {
    Write-Host ""
    Write-Host "  ════════════════════════════════════════════════════════════════" -ForegroundColor Red
    Write-Host "  [!] ADVERTENCIA: No se pudo crear punto de restauracion" -ForegroundColor Yellow
    Write-Host "  Razon: $($_.Exception.Message)" -ForegroundColor Gray
    Write-Host ""
    Write-Host "  Posibles causas:" -ForegroundColor Yellow
    Write-Host "  - System Restore deshabilitado en Windows" -ForegroundColor Gray
    Write-Host "  - Disco sin espacio suficiente" -ForegroundColor Gray
    Write-Host "  - Servicio VSS detenido" -ForegroundColor Gray
    Write-Host "  ════════════════════════════════════════════════════════════════" -ForegroundColor Red
    Write-Host ""
    Write-Host "  ╔══════════════════════════════════════════════════════════════╗" -ForegroundColor Red
    Write-Host "  ║  ⚠ SIN PUNTO DE RESTAURACION NO PODRAS REVERTIR CAMBIOS     ║" -ForegroundColor Red
    Write-Host "  ║  ⚠ TODOS LOS TWEAKS SERAN PERMANENTES                       ║" -ForegroundColor Red
    Write-Host "  ║  ⚠ CONTINUAS BAJO TU PROPIO RIESGO                          ║" -ForegroundColor Red
    Write-Host "  ╚══════════════════════════════════════════════════════════════╝" -ForegroundColor Red
    Write-Host ""
    $script:Riesgos.Add("  [!] CRITICO: NO se creo punto de restauracion - cambios irreversibles")
    Write-WARN "Continuando SIN punto de restauracion..."
    Start-Sleep -Seconds 3
}

# ════════════════════════════════════════════════════════════════
#  SELECCIÓN DE PERFIL
# ════════════════════════════════════════════════════════════════

Write-Header "1" "PERFIL: GAMA DE LA PC"
Write-Host ""
Write-Host "   [1] ALTA   - i7/i9/Ryzen 7-9, 16GB+ RAM, SSD NVMe" -ForegroundColor Green
Write-Host "   [2] MEDIA  - i5/Ryzen 5, 8-16GB RAM, SSD o HDD" -ForegroundColor Yellow
Write-Host "   [3] BAJA   - i3/Celeron/Pentium, 4-8GB, HDD" -ForegroundColor Red
Write-Host ""
do { $gi = Read-Host "  Selecciona 1, 2 o 3" } while ($gi -notmatch "^[123]$")
$gama    = [int]$gi
$gamaStr = @{1="ALTA"; 2="MEDIA"; 3="BAJA"}[$gama]
$gamaCol = @{1="Green"; 2="Yellow"; 3="Red"}[$gama]
Write-Host "  -> Gama $gamaStr seleccionada." -ForegroundColor $gamaCol
Write-Log "Gama seleccionada: $gamaStr" "INFO"

Write-Header "2" "PERFIL: USO PRINCIPAL"
Write-Host ""
Write-Host "   [1] OFICINA    - Word, Excel, navegador, correo" -ForegroundColor Cyan
Write-Host "   [2] GAMING     - Juegos, alto rendimiento, baja latencia" -ForegroundColor Magenta
Write-Host "   [3] STREAMING  - OBS, grabacion, edicion de video" -ForegroundColor Blue
Write-Host "   [4] MIXTO      - Varios usos" -ForegroundColor White
Write-Host ""
do { $ui = Read-Host "  Selecciona 1, 2, 3 o 4" } while ($ui -notmatch "^[1234]$")
$uso    = [int]$ui
$usoStr = @{1="OFICINA"; 2="GAMING"; 3="STREAMING"; 4="MIXTO"}[$uso]
Write-Log "Uso seleccionado: $usoStr" "INFO"

Write-Host ""
Write-Host "  ════════════════════════════════════════════════════════════════" -ForegroundColor Cyan
Write-Host "  Perfil configurado: Gama $gamaStr | Uso $usoStr" -ForegroundColor White
Write-Host "  ════════════════════════════════════════════════════════════════" -ForegroundColor Cyan
Write-Host ""
Start-Sleep -Seconds 1

# ════════════════════════════════════════════════════════════════
#  A. SERVICIOS BASE - TELEMETRÍA Y DIAGNÓSTICOS
# ════════════════════════════════════════════════════════════════

Write-Header "A" "SERVICIOS - TELEMETRIA Y DIAGNOSTICOS"
Disable-Svc "DiagTrack"           "Telemetria y experiencias del usuario"
Disable-Svc "WerSvc"              "Informe de errores de Windows"
Disable-Svc "wercplsupport"       "Soporte panel de errores"
Disable-Svc "wuqisvc"             "Insights de calidad Microsoft"
Disable-Svc "dmwappushservice"    "Mensajes WAP/push"
Disable-Svc "wisvc"               "Windows Insider Service"
Disable-Svc "diagnosticshub.standardcollector.service" "Diagnostics Hub Collector"
Disable-Svc "RetailDemo"          "Modo demo comercial"
Disable-Svc "GraphicsPerfSvc"     "Monitor rendimiento grafico"
Disable-Svc "PcaSvc"              "Asistente compatibilidad programas"
Set-Manual   "DPS"                "Directivas de diagnostico"
Set-Manual   "WdiSystemHost"      "Host sistema diagnostico"

Write-Sub "Xbox Live"
Disable-Svc "XblAuthManager"      "Autenticacion Xbox Live"
Disable-Svc "XblGameSave"         "Guardado Xbox Live"
Disable-Svc "XboxGipSvc"          "Xbox Accessory Management"
Disable-Svc "XboxNetApiSvc"       "Red Xbox Live"

Write-Sub "Acceso Remoto"
Disable-Svc "RemoteRegistry"      "Registro remoto" "Reactivar si necesitas acceso remoto al registro"
Disable-Svc "RemoteAccess"        "Enrutamiento y acceso remoto"
Disable-Svc "RasAuto"             "Conexiones automaticas RAS"
Disable-Svc "RasMan"              "Administrador conexiones RAS"
Disable-Svc "SstpSvc"             "Protocolo tunel SSTP"
Disable-Svc "seclogon"            "Inicio sesion secundario" "Algunos instaladores lo requieren"
Disable-Svc "SessionEnv"          "Configuracion Escritorio remoto"
Disable-Svc "UmRdpService"        "Redirector puerto RDP"

Write-Sub "Actualizadores de Navegadores"
Disable-Svc "edgeupdate"                    "Microsoft Edge Update"
Disable-Svc "edgeupdatem"                   "Microsoft Edge Update (m)"
Disable-Svc "MicrosoftEdgeElevationService" "Edge Elevation Service"
Disable-Svc "GoogleUpdaterInternalService"  "Google Updater interno"
Disable-Svc "GoogleUpdaterService"          "Google Updater"
Disable-Svc "GoogleChromeElevationService"  "Chrome Elevation Service"
Disable-Svc "brave"                         "Brave Update"
Disable-Svc "bravem"                        "Brave Update (m)"
Disable-Svc "BraveElevationService"         "Brave Elevation Service"

Write-Sub "Miscelaneos"
Disable-Svc "SSDPSRV"             "Deteccion SSDP (UPnP)"
Disable-Svc "upnphost"            "Host UPnP"
Disable-Svc "MapsBroker"          "Mapas descargados"
Disable-Svc "lfsvc"               "Geolocalizacion"
Disable-Svc "WalletService"       "Wallet Service"
Disable-Svc "SEMgrSvc"            "Pagos y NFC/SE"
Disable-Svc "WpcMonSvc"           "Control parental"
Disable-Svc "TrkWks"              "Seguimiento vinculos distribuidos"
Disable-Svc "Fax"                 "Servicio de Fax"
Disable-Svc "PhoneSvc"            "Servicio telefonico"
Disable-Svc "SmsRouter"           "Enrutador SMS"
Disable-Svc "shpamsvc"            "Shared PC Account Manager"
Disable-Svc "tzautoupdate"        "Actualizador zona horaria automatico"
Set-Manual   "wuauserv"           "Windows Update"
Set-Manual   "BITS"               "Transferencia inteligente"
Set-Manual   "DoSvc"              "Optimizacion de distribucion"

# ════════════════════════════════════════════════════════════════
#  SERVICIOS - PERFIL GAMA
# ════════════════════════════════════════════════════════════════

Write-Header "A" "SERVICIOS - PERFIL GAMA $gamaStr"

if ($gama -eq 3) {
    # Gama BAJA
    if ($sys.IsHDD) {
        Set-Manual "SysMain" "SysMain/Superfetch (Manual - util en HDD)"
    } else {
        Disable-Svc "SysMain" "SysMain/Superfetch" "Innecesario en SSD"
    }
    Disable-Svc "WSearch"         "Busqueda de Windows" "Instalar 'Everything' como reemplazo"
    Disable-Svc "defragsvc"       "Desfragmentador programado"
    $script:Riesgos.Add("  [!] Gama Baja: WSearch off - usar Everything como buscador")
    
} elseif ($gama -eq 2) {
    # Gama MEDIA
    if ($sys.IsHDD) {
        Set-Manual "SysMain" "SysMain (Manual - util en HDD)"
    } else {
        Set-Manual "SysMain" "SysMain (Manual - SSD no lo necesita activo)"
    }
    Set-Manual "WSearch"  "Busqueda de Windows"
    Disable-Svc "defragsvc" "Desfragmentador programado"
    
} else {
    # Gama ALTA
    Set-Manual "SysMain"  "SysMain (Manual)"
    Set-Manual "WSearch"  "Busqueda de Windows (Manual)"
    Disable-Svc "defragsvc" "Desfragmentador programado"
}

# ════════════════════════════════════════════════════════════════
#  SERVICIOS - PERFIL USO
# ════════════════════════════════════════════════════════════════

Write-Header "A" "SERVICIOS - PERFIL $usoStr"

if ($uso -eq 2) {
    # GAMING
    Set-Reg "$script:HKCU_Software\Microsoft\GameBar" "AllowAutoGameMode" 1
    Set-Reg "$script:HKCU_Software\Microsoft\GameBar" "AutoGameModeEnabled" 1
    Set-Reg "$script:HKCU_Software\Microsoft\Windows\CurrentVersion\GameDVR" "AppCaptureEnabled" 0
    Set-Reg "$script:HKLM_Software\Policies\Microsoft\Windows\GameDVR" "AllowGameDVR" 0
    Write-OK "Modo Juego activado + Xbox Game Bar desactivada"
    
} elseif ($uso -eq 1) {
    # OFICINA
    Disable-Svc "EasyAntiCheat_EOS" "Easy Anti-Cheat (EOS)" "Afecta juegos que lo requieran"
    
} elseif ($uso -eq 3) {
    # STREAMING
    Write-INFO "Servicios de audio y GPU conservados para OBS/streaming"
}

# ════════════════════════════════════════════════════════════════
#  B-F. PREGUNTAS USUARIO (Bluetooth, Impresoras, Hyper-V, WiFi, OneDrive)
# ════════════════════════════════════════════════════════════════

Write-Header "B" "BLUETOOTH"
if (Ask-YN "El cliente USA Bluetooth?" "s") {
    Write-SKIP "Bluetooth conservado"
} else {
    Disable-Svc "BluetoothUserService" "Soporte Bluetooth usuario"
    Disable-Svc "BTAGService"          "Audio Bluetooth"
    Disable-Svc "BthAvctpSvc"          "Servicio AVCTP"
    Disable-Svc "bthserv"              "Compatibilidad Bluetooth"
    Disable-Svc "RmSvc"                "Administracion de radio"
}

Write-Header "C" "IMPRESORAS"
if (Ask-YN "El cliente USA impresora?" "s") {
    Write-SKIP "Servicios de impresion conservados"
} else {
    Disable-Svc "Spooler"             "Cola de impresion (Spooler)"
    Disable-Svc "PrintNotify"         "Notificaciones de impresora"
    Disable-Svc "PrintDeviceConfig"   "Config dispositivo impresion"
    Disable-Svc "PrintScanBroker"     "Print/Scan Broker"
}

Write-Header "D" "HYPER-V / MAQUINAS VIRTUALES"
if (Ask-YN "El cliente usa maquinas virtuales?" "n") {
    Write-SKIP "Hyper-V conservado"
} else {
    "vmicguestinterface","vmicheartbeat","vmickvpexchange","vmicrdv",
    "vmicshutdown","vmictimesync","vmicvmsession","vmicvss","HvHost",
    "vmcompute","vmms" | ForEach-Object {
        Disable-Svc $_ "Hyper-V: $_"
    }
}

Write-Header "E" "WI-FI"
if (Ask-YN "El cliente usa Wi-Fi?" "s") {
    Write-SKIP "Wi-Fi conservado"
} else {
    Disable-Svc "WlanSvc" "Configuracion automatica WLAN" "La PC no podra usar Wi-Fi"
    $script:Riesgos.Add("  [!] WlanSvc off: solo funciona Ethernet")
}

Write-Header "F" "ONEDRIVE"
if (Ask-YN "El cliente usa OneDrive?" "n") {
    Write-SKIP "OneDrive conservado"
} else {
    reg delete "HKCU\Software\Microsoft\Windows\CurrentVersion\Run" /v "OneDrive" /f 2>$null
    schtasks /Delete /TN "\Microsoft\Windows\OneDrive\OneDrive Standalone Update Task v2" /F 2>$null
    Write-OK "OneDrive removido del autoarranque"
}

# ════════════════════════════════════════════════════════════════
#  G. PLAN DE ENERGIA
# ════════════════════════════════════════════════════════════════

Write-Header "G" "PLAN DE ENERGIA"
Write-Host ""
Write-Host "   [1] Alto rendimiento   - recomendado para PC de escritorio" -ForegroundColor Green
Write-Host "   [2] Ultimate Perf.     - maximo posible (no en laptops)" -ForegroundColor Magenta
Write-Host "   [3] Equilibrado        - dejar como esta" -ForegroundColor Yellow
Write-Host "   [4] Ahorro de energia  - laptops / bajo consumo" -ForegroundColor Cyan
Write-Host ""
do { $pe = Read-Host "  Selecciona 1, 2, 3 o 4" } while ($pe -notmatch "^[1234]$")

switch ($pe) {
    "1" {
        powercfg /setactive 8c5e7fda-e8bf-4a96-9a85-a6e23a8c635c 2>$null
        Write-OK "Plan: Alto rendimiento activado"
    }
    "2" {
        powercfg -duplicatescheme e9a42b02-d5df-448d-aa00-03f14749eb61 2>$null
        $uidLine = powercfg /list | Select-String -Pattern "Ultimate|Ultimo" | Select-Object -First 1
        if ($uidLine) {
            $uid = ([regex]::Match($uidLine, "([0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12})")).Value
            if ($uid) {
                powercfg /setactive $uid 2>$null
                Write-OK "Plan: Ultimate Performance activado"
            } else {
                powercfg /setactive 8c5e7fda-e8bf-4a96-9a85-a6e23a8c635c 2>$null
                Write-OK "Plan: Alto rendimiento (Ultimate no disponible)"
            }
        }
        $script:Riesgos.Add("  [!] Ultimate Performance: mayor consumo, no usar en laptops")
    }
    "3" { Write-SKIP "Plan de energia sin cambios" }
    "4" {
        powercfg /setactive a1841308-3541-4fab-bc81-f71556f20b4a 2>$null
        Write-OK "Plan: Ahorro de energia activado"
    }
}


# ════════════════════════════════════════════════════════════════
#  H. TWEAKS DE REGISTRO - PRIVACIDAD Y RENDIMIENTO
# ════════════════════════════════════════════════════════════════

Write-Header "H" "TWEAKS DE REGISTRO - PRIVACIDAD Y RENDIMIENTO"
if (Ask-YN "Aplicar tweaks de privacidad y rendimiento en registro?" "s") {

    Write-Sub "Privacidad"
    Set-Reg "$script:HKCU_Software\Microsoft\Windows\CurrentVersion\AdvertisingInfo" "Enabled" 0
    
    $cdm = "$script:HKCU_Software\Microsoft\Windows\CurrentVersion\ContentDeliveryManager"
    "SubscribedContent-338388Enabled","SubscribedContent-338389Enabled",
    "SubscribedContent-353698Enabled","SystemPaneSuggestionsEnabled",
    "SoftLandingEnabled","OemPreInstalledAppsEnabled",
    "PreInstalledAppsEnabled","SilentInstalledAppsEnabled" | ForEach-Object {
        Set-Reg $cdm $_ 0
    }
    
    Set-Reg "$script:HKLM_Software\Policies\Microsoft\Windows\DataCollection" "AllowTelemetry" 0
    Write-OK "Publicidad personalizada y telemetria desactivadas"

    Write-Sub "Rendimiento de memoria y CPU"
    powercfg /h off 2>$null
    Write-OK "Hibernacion desactivada (libera ~$([math]::Round($sys.RAM, 0)) GB)"
    
    Set-Reg "$script:HKLM_System\Control\Session Manager\Memory Management\PrefetchParameters" "EnableSuperfetch" 0
    Set-Reg "$script:HKLM_System\Control\Session Manager\Memory Management\PrefetchParameters" "EnablePrefetcher" 0
    Set-Reg "$script:HKLM_System\Control\PriorityControl" "Win32PrioritySeparation" 38
    Set-Reg "$script:HKLM_System\Control\CrashControl" "CrashDumpEnabled" 0
    Set-Reg "$script:HKLM_System\Control\CrashControl" "AutoReboot" 1
    Write-OK "Prioridad CPU primer plano optimizada"

    Write-Sub "Explorador de archivos"
    $adv = "$script:HKCU_Explorer\Advanced"
    Set-Reg $adv "HideFileExt" 0
    Set-Reg $adv "Hidden" 1
    Set-Reg $adv "EnableBalloonTips" 0
    Set-Reg $adv "LaunchTo" 1
    Set-Reg $adv "ShowSyncProviderNotifications" 0
    Write-OK "Extensiones visibles, Este equipo como inicio"

    Write-Sub "Busqueda web / Bing / Cortana"
    Set-Reg "$script:HKCU_Software\Microsoft\Windows\CurrentVersion\Search" "BingSearchEnabled" 0
    Set-Reg "$script:HKCU_Software\Microsoft\Windows\CurrentVersion\Search" "CortanaConsent" 0
    Set-Reg "$script:HKLM_Software\Policies\Microsoft\Windows\Windows Search" "DisableWebSearch" 1
    Set-Reg "$script:HKLM_Software\Policies\Microsoft\Windows\Windows Search" "ConnectedSearchUseWeb" 0
    Write-OK "Bing y Cortana desactivados"

    if ($sys.IsWin11) {
        Write-Sub "Windows 11 - Tweaks especificos"
        
        # Widgets
        Set-Reg "$script:HKLM_Software\Policies\Microsoft\Dsh" "AllowNewsAndInterests" 0
        Write-OK "Widgets desactivados"
        
        # Recall (Copilot+)
        Set-Reg "$script:HKCU_Software\Policies\Microsoft\Windows\WindowsAI" "DisableAIDataAnalysis" 1
        Set-Reg "$script:HKLM_Software\Policies\Microsoft\Windows\WindowsAI" "DisableAIDataAnalysis" 1
        Write-OK "Recall/AI desactivado"
        
        # Copilot
        Set-Reg "$script:HKCU_Software\Policies\Microsoft\Windows\WindowsCopilot" "TurnOffWindowsCopilot" 1
        Write-OK "Copilot desactivado"
        
        # Taskbar alignment
        if (Ask-YN "Mover iconos de barra de tareas a la izquierda (estilo Win10)?" "n") {
            Set-Reg $adv "TaskbarAl" 0
            Write-OK "Barra de tareas alineada a la izquierda"
        }
    }
}


# ════════════════════════════════════════════════════════════════
#  I. OPTIMIZACIÓN DE RED COMPLETA
# ════════════════════════════════════════════════════════════════

Write-Header "I" "OPTIMIZACION DE RED - TCP, DNS, MTU, ADAPTADOR"
if (Ask-YN "Aplicar optimizacion completa de red?" "s") {

    Write-Sub "Verificando conectividad"
    try {
        $tieneInternet = Test-Connection -ComputerName 8.8.8.8 -Count 1 -Quiet -ErrorAction Stop
    } catch { $tieneInternet = $false }
    
    if ($tieneInternet) {
        Write-OK "Internet detectado"
        $bp = Test-Connection "8.8.8.8" -Count 4 -EA SilentlyContinue
        $avgBefore = [math]::Round(($bp | Measure-Object ResponseTime -Average).Average, 2)
        Write-INFO "Ping ANTES: $avgBefore ms"
    } else {
        Write-WARN "Sin internet - se saltan MTU y test DNS automatico"
    }

    Write-Sub "TCP/IP tweaks"
    netsh int tcp set global autotuninglevel=normal  | Out-Null
    netsh int tcp set global rss=enabled             | Out-Null
    netsh int tcp set global chimney=enabled         | Out-Null
    netsh int tcp set global dca=enabled             | Out-Null
    netsh int tcp set global netdma=enabled          | Out-Null
    netsh int tcp set global ecncapability=disabled  | Out-Null
    netsh int tcp set global timestamps=disabled     | Out-Null
    
    # Congestion Provider - el mejor según la versión de Windows
    if ($sys.IsWin11 -or ($sys.IsWin10 -and $sys.Build -ge 22000)) {
        # Windows 11: CUBIC es el mejor (predeterminado y optimizado)
        netsh int tcp set global congestionprovider=cubic | Out-Null
        Write-INFO "Congestion Provider: CUBIC (Win11)"
    } elseif ($sys.Build -ge 16299) {
        # Win10 1709+: CUBIC disponible
        netsh int tcp set global congestionprovider=cubic | Out-Null
        Write-INFO "Congestion Provider: CUBIC (Win10 1709+)"
    } elseif ($sys.Build -ge 14393) {
        # Win10 1607 (Anniversary): CTCP disponible
        netsh int tcp set global congestionprovider=ctcp | Out-Null
        Write-INFO "Congestion Provider: CTCP (Win10 1607+)"
    } else {
        # Win10 anterior: usar default
        netsh int tcp set global congestionprovider=default | Out-Null
        Write-INFO "Congestion Provider: Default (Win10 antiguo)"
    }
    
    # Nagle off en todas las interfaces
    $tcpIf = "$script:HKLM_System\Services\Tcpip\Parameters\Interfaces"
    Get-ChildItem $tcpIf -EA SilentlyContinue | ForEach-Object {
        Set-ItemProperty -Path $_.PSPath -Name "TcpAckFrequency" -Value 1 -Type DWord -EA SilentlyContinue
        Set-ItemProperty -Path $_.PSPath -Name "TCPNoDelay" -Value 1 -Type DWord -EA SilentlyContinue
    }
    
    Set-Reg "$script:HKLM_System\Services\Tcpip\Parameters" "DefaultTTL" 64
    Set-Reg "$script:HKLM_System\Services\Tcpip\Parameters" "MaxUserPort" 65534
    Set-Reg "$script:HKLM_System\Services\Tcpip\Parameters" "TcpTimedWaitDelay" 30
    Set-Reg "$script:HKLM_System\Services\Tcpip\Parameters" "Tcp1323Opts" 1
    Write-OK "TCP optimizado (Nagle off, autotuning, puertos ampliados)"

    Write-Sub "Flush DNS y reset de red"
    ipconfig /flushdns    | Out-Null
    ipconfig /release     | Out-Null
    Start-Sleep -Seconds 2
    ipconfig /renew       | Out-Null
    netsh winsock reset   | Out-Null
    netsh int ip reset    | Out-Null
    netsh winhttp reset proxy | Out-Null
    Write-OK "DNS, Winsock, IP stack y proxy reseteados"
    $script:Riesgos.Add("  [!] netsh int ip reset ejecutado: REINICIO OBLIGATORIO")

    Write-Sub "Prioridad multimedia/gaming"
    $mmPath = "$script:HKLM_Software\Microsoft\Windows NT\CurrentVersion\Multimedia\SystemProfile"
    Set-Reg $mmPath "NetworkThrottlingIndex" 4294967295
    Set-Reg $mmPath "SystemResponsiveness" 0
    $gPath = "$mmPath\Tasks\Games"
    if (-not (Test-Path $gPath)) { New-Item -Path $gPath -Force | Out-Null }
    Set-ItemProperty -Path $gPath -Name "GPU Priority" -Value 8 -Type DWord -EA SilentlyContinue
    Set-ItemProperty -Path $gPath -Name "Priority" -Value 6 -Type DWord -EA SilentlyContinue
    Set-ItemProperty -Path $gPath -Name "Scheduling Category" -Value "High" -Type String -EA SilentlyContinue
    Write-OK "Prioridad multimedia/gaming configurada"

    Write-Sub "Desactivar ahorro energia en adaptadores"
    Get-NetAdapter | Where-Object { $_.Status -eq "Up" } | ForEach-Object {
        $adapterName = $_.Name
        
        # Metodo 1: Via Device Manager properties (lo que mostraste en la captura)
        $deviceID = (Get-NetAdapter -Name $adapterName).PnPDeviceID
        if ($deviceID) {
            # Deshabilitar "Permitir que el equipo apague este dispositivo para ahorrar energía"
            $powerMgmt = Get-CimInstance -ClassName MSPower_DeviceEnable -Namespace root/wmi -EA SilentlyContinue |
                         Where-Object { $_.InstanceName -like "*$deviceID*" }
            if ($powerMgmt) {
                Set-CimInstance -InputObject $powerMgmt -Property @{Enable = $false} -EA SilentlyContinue
            }
            
            # También via registro
            $regPath = "HKLM:\SYSTEM\CurrentControlSet\Control\Class\{4d36e972-e325-11ce-bfc1-08002be10318}"
            Get-ChildItem $regPath -EA SilentlyContinue | ForEach-Object {
                $driverDesc = (Get-ItemProperty $_.PSPath -Name "DriverDesc" -EA SilentlyContinue).DriverDesc
                if ($driverDesc -like "*$adapterName*") {
                    Set-ItemProperty -Path $_.PSPath -Name "PnPCapabilities" -Value 24 -Type DWord -EA SilentlyContinue
                }
            }
        }
        
        # Metodo 2: Disable-NetAdapterPowerManagement (si existe el cmdlet)
        Disable-NetAdapterPowerManagement -Name $adapterName -EA SilentlyContinue
    }
    Write-OK "Gestion de energia de adaptadores desactivada (Device Manager + PowerShell)"

    Write-Sub "Perfil del adaptador activo"
    $adapter = Get-NetAdapter | Where-Object {
        $_.Status -eq "Up" -and $_.HardwareInterface -eq $true
    } | Select-Object -First 1

    if ($adapter) {
        $esEthernet = ($adapter.NdisPhysicalMedium -eq 14) -or ($adapter.PhysicalMediaType -eq "802.3")
        $esWifi     = ($adapter.NdisPhysicalMedium -eq 9)  -or ($adapter.PhysicalMediaType -like "*802.11*")
        $tipoAdap   = if ($esEthernet) { "Ethernet" } elseif ($esWifi) { "Wi-Fi" } else { "Otro" }
        Write-INFO "Adaptador: $($adapter.Name) [$tipoAdap]"

        if ($esEthernet) {
            Write-INFO "Configurando tweaks avanzados de Ethernet..."
            
            # Helper function para setear propiedades
            $SetNicProp = {
                param($DisplayName, $Value)
                Set-NetAdapterAdvancedProperty -Name $adapter.Name -DisplayName $DisplayName -DisplayValue $Value -EA SilentlyContinue
            }
            
            # Energy Efficient Ethernet (EEE) - OFF
            & $SetNicProp "Energy Efficient Ethernet" "Disabled"
            & $SetNicProp "Advanced EEE" "Disabled"
            & $SetNicProp "EEE" "Disabled"
            & $SetNicProp "Green Ethernet" "Disabled"
            & $SetNicProp "Gigabit Lite" "Disabled"
            & $SetNicProp "Power Saving Mode" "Disabled"
            
            # Flow Control - OFF
            & $SetNicProp "Flow Control" "Disabled"
            
            # Auto Disable Gigabit - OFF
            & $SetNicProp "Auto Disable Gigabit" "Disabled"
            & $SetNicProp "Gigabit Auto Powerdown" "Disabled"
            
            # ARP Offload - ON (dejar activado)
            & $SetNicProp "ARP Offload" "Enabled"
            
            # IPv4 Checksum Offload - ON (dejar activado)
            & $SetNicProp "IPv4 Checksum Offload" "Rx & Tx Enabled"
            
            # Large Send Offload v2 - OFF
            & $SetNicProp "Large Send Offload V2 (IPv4)" "Disabled"
            & $SetNicProp "Large Send Offload V2 (IPv6)" "Disabled"
            & $SetNicProp "Large Send Offload v2 (IPv4)" "Disabled"
            & $SetNicProp "Large Send Offload v2 (IPv6)" "Disabled"
            
            # TCP/UDP Checksum Offload - TODAS ACTIVADAS (Rx & Tx)
            & $SetNicProp "TCP Checksum Offload (IPv4)" "Rx & Tx Enabled"
            & $SetNicProp "TCP Checksum Offload (IPv6)" "Rx & Tx Enabled"
            & $SetNicProp "UDP Checksum Offload (IPv4)" "Rx & Tx Enabled"
            & $SetNicProp "UDP Checksum Offload (IPv6)" "Rx & Tx Enabled"
            
            # Receive Segment Coalescing - OFF
            & $SetNicProp "Recv Segment Coalescing (IPv4)" "Disabled"
            & $SetNicProp "Recv Segment Coalescing (IPv6)" "Disabled"
            & $SetNicProp "Receive Segment Coalescing" "Disabled"
            
            # Receive Side Scaling - ON
            & $SetNicProp "Receive Side Scaling" "Enabled"
            Enable-NetAdapterRss -Name $adapter.Name -EA SilentlyContinue
            
            # RSS tuning basado en cores
            if ($sys.CPUCores -ge 4) {
                $maxProc = [math]::Min($sys.CPUCores - 1, 4)
                Set-NetAdapterRss -Name $adapter.Name -MaxProcessors $maxProc -EA SilentlyContinue
            }
            
            # Wake on Pattern Match - Disabled
            & $SetNicProp "Wake on Pattern Match" "Disabled"
            & $SetNicProp "Wake on Magic Packet" "Disabled"
            & $SetNicProp "Wake on Link" "Disabled"
            
            # WOL & Shutdown Link Speed - No Speed Down
            & $SetNicProp "WOL & Shutdown Link Speed" "Not Speed Down"
            & $SetNicProp "Shutdown Wake-On-Lan" "Disabled"
            
            # Interrupt Moderation - Disabled
            & $SetNicProp "Interrupt Moderation" "Disabled"
            
            # Speed & Duplex - Maxima posible (Auto Negotiation o 1.0 Gbps Full Duplex)
            $speedOptions = Get-NetAdapterAdvancedProperty -Name $adapter.Name -EA SilentlyContinue |
                            Where-Object { $_.RegistryKeyword -eq "SpeedDuplex" }
            if ($speedOptions) {
                # Intentar setear a 1Gbps Full Duplex si está disponible
                $maxSpeed = $speedOptions.ValidDisplayValues | Where-Object { 
                    $_ -match "1\.0 Gbps Full Duplex|1000 Mbps Full Duplex" 
                } | Select-Object -First 1
                
                if ($maxSpeed) {
                    & $SetNicProp "Speed & Duplex" $maxSpeed
                } else {
                    & $SetNicProp "Speed & Duplex" "Auto Negotiation"
                }
            }
            
            Write-OK "Ethernet: Tweaks avanzados aplicados"
            Write-INFO "  - EEE/Green/Power Saving: OFF"
            Write-INFO "  - Flow Control: OFF"
            Write-INFO "  - LSO v2: OFF"
            Write-INFO "  - TCP/UDP Checksum Offload: ON (Rx & Tx)"
            Write-INFO "  - RSC: OFF"
            Write-INFO "  - RSS: ON ($maxProc cores)"
            Write-INFO "  - Interrupt Moderation: OFF"
            Write-INFO "  - Wake on LAN: OFF"
            
        } elseif ($esWifi) {
            Set-NetAdapterAdvancedProperty -Name $adapter.Name -DisplayName "Transmit Power" -DisplayValue "Highest" -EA SilentlyContinue
            Set-NetAdapterAdvancedProperty -Name $adapter.Name -DisplayName "Roaming Aggressiveness" -DisplayValue "Lowest" -EA SilentlyContinue
            $wb = Get-NetAdapterAdvancedProperty -Name $adapter.Name -EA SilentlyContinue |
                  Where-Object { $_.DisplayName -like "*Preferred Band*" }
            if ($wb) {
                Set-NetAdapterAdvancedProperty -Name $adapter.Name -DisplayName $wb.DisplayName -DisplayValue "Prefer 5GHz" -EA SilentlyContinue
            }
            Write-OK "Wi-Fi: TX max, roaming agresivo off, preferir 5GHz"
        }
    }

    Write-Sub "MTU automatico"
    if ($tieneInternet -and $adapter) {
        $mtu = 1500
        for ($sz = 1472; $sz -gt 1372; $sz -= 10) {
            $t = ping 8.8.8.8 -f -l $sz -n 1 2>&1
            if ($t -match "TTL|ttl") { $mtu = $sz + 28; break }
        }
        netsh interface ipv4 set subinterface "$($adapter.Name)" mtu=$mtu store=persistent 2>$null
        Write-OK "MTU ajustado a $mtu"
    } else {
        Write-SKIP "Sin internet o adaptador - MTU no calculado"
    }

    Write-Sub "DNS publico"
    Write-Host ""
    Write-Host "   [1] Google      8.8.8.8 / 8.8.4.4" -ForegroundColor Yellow
    Write-Host "   [2] Cloudflare  1.1.1.1 / 1.0.0.1" -ForegroundColor Cyan
    Write-Host "   [3] Quad9       9.9.9.9 / 149.112.112.112" -ForegroundColor Magenta
    Write-Host "   [4] Automatico  - testea el mas rapido" -ForegroundColor Green
    Write-Host "   [5] Saltar" -ForegroundColor DarkGray
    Write-Host ""
    do { $dnsSel = Read-Host "  >> Selecciona 1-5" } while ($dnsSel -notmatch "^[12345]$")

    $dp = $null; $ds = $null
    if ($dnsSel -eq "4" -and $tieneInternet) {
        Write-INFO "Testeando 8 servidores DNS..."
        $candidates = @("1.1.1.1","1.0.0.1","8.8.8.8","8.8.4.4","9.9.9.9","149.112.112.112","208.67.222.222","208.67.220.220")
        $results = @()
        foreach ($d in $candidates) {
            $p = Test-Connection $d -Count 3 -EA SilentlyContinue
            if ($p) { 
                $results += [PSCustomObject]@{ 
                    DNS=$d
                    Avg=[math]::Round(($p | Measure-Object ResponseTime -Average).Average,2)
                }
            }
        }
        $top2 = $results | Sort-Object Avg | Select-Object -First 2
        if ($top2.Count -ge 2) { 
            $dp=$top2[0].DNS; $ds=$top2[1].DNS
            Write-OK "DNS elegido: $dp ($($top2[0].Avg)ms) / $ds ($($top2[1].Avg)ms)"
        } else {
            $dp="1.1.1.1"; $ds="1.0.0.1"
            Write-WARN "Fallback: Cloudflare"
        }
    } elseif ($dnsSel -eq "1") { $dp="8.8.8.8"; $ds="8.8.4.4"
    } elseif ($dnsSel -eq "2") { $dp="1.1.1.1"; $ds="1.0.0.1"
    } elseif ($dnsSel -eq "3") { $dp="9.9.9.9"; $ds="149.112.112.112" }

    if ($dp) {
        $ifaces = Get-DnsClient | Where-Object { $_.InterfaceAlias -notlike "*Loopback*" }
        foreach ($iface in $ifaces) {
            Set-DnsClientServerAddress -InterfaceIndex $iface.InterfaceIndex -ServerAddresses ($dp, $ds) -EA SilentlyContinue
        }
        ipconfig /flushdns | Out-Null
        Write-OK "DNS aplicado: $dp / $ds"
    }

    Write-Sub "IPv6"
    if (Ask-YN "Deshabilitar IPv6?" "n") {
        Set-Reg "$script:HKLM_System\Services\Tcpip6\Parameters" "DisabledComponents" 255
        Get-NetAdapter | ForEach-Object { 
            Disable-NetAdapterBinding -Name $_.Name -ComponentID ms_tcpip6 -EA SilentlyContinue 
        }
        Write-OK "IPv6 deshabilitado"
        $script:Riesgos.Add("  [!] IPv6 off: algunos servicios modernos pueden necesitarlo")
    }

    if ($tieneInternet) {
        Start-Sleep -Seconds 2
        $ap = Test-Connection "8.8.8.8" -Count 4 -EA SilentlyContinue
        $avgAfter = [math]::Round(($ap | Measure-Object ResponseTime -Average).Average, 2)
        $diff = [math]::Round($avgBefore - $avgAfter, 2)
        Write-Host ""
        Write-Host "  ────────────────────────────────────────────────────" -ForegroundColor DarkCyan
        Write-Host "  Ping ANTES:   $avgBefore ms" -ForegroundColor Gray
        Write-Host "  Ping DESPUES: $avgAfter ms" -ForegroundColor Cyan
        if ($diff -gt 0) { 
            Write-Host "  Mejora:       -$diff ms" -ForegroundColor Green 
        } else { 
            Write-Host "  Diferencia:   $diff ms" -ForegroundColor Yellow 
        }
        Write-Host "  ────────────────────────────────────────────────────" -ForegroundColor DarkCyan
    }
}


# ════════════════════════════════════════════════════════════════
#  J. AJUSTES VISUALES
# ════════════════════════════════════════════════════════════════

Write-Header "J" "AJUSTES VISUALES Y ANIMACIONES"
if (Ask-YN "Configurar efectos visuales?" "s") {
    Write-Host ""
    Write-Host "   [1] Rendimiento maximo - desactiva TODOS los efectos" -ForegroundColor Red
    Write-Host "   [2] Personalizado      - elegis efecto por efecto" -ForegroundColor Yellow
    Write-Host "   [3] Omitir" -ForegroundColor DarkGray
    Write-Host ""
    do { $vo = Read-Host "  >> Selecciona 1-3" } while ($vo -notmatch "^[123]$")

    $perfP  = "$script:HKCU_Explorer\Advanced"
    $visP   = "HKCU:\Control Panel\Desktop"
    $dwmP   = "$script:HKCU_Software\Microsoft\Windows\DWM"
    $themeP = "$script:HKCU_Software\Microsoft\Windows\CurrentVersion\Themes\Personalize"

    if ($vo -eq "1") {
        Set-Reg $perfP  "VisualFXSetting" 2
        Set-Reg $visP   "MinAnimate" "0" "String"
        Set-Reg $visP   "DragFullWindows" "0" "String"
        Set-Reg $visP   "FontSmoothing" 2
        Set-Reg $perfP  "TaskbarAnimations" 0
        Set-Reg $dwmP   "EnableAeroPeek" 0
        Set-Reg $themeP "EnableTransparency" 0
        Set-Reg $perfP  "ListviewAlphaSelect" 0
        Set-Reg $perfP  "ListviewShadow" 0
        Set-Reg $visP   "UserPreferencesMask" ([byte[]](0x90,0x12,0x03,0x80,0x10,0x00,0x00,0x00)) "Binary"
        Write-OK "Rendimiento maximo aplicado"
    } elseif ($vo -eq "2") {
        $tweaks = @(
            @{ Q="Animaciones al minimizar/maximizar"; P=$visP;  N="MinAnimate"; V="0"; T="String" }
            @{ Q="Sombras debajo de ventanas"; P=$dwmP;  N="EnableAeroPeek"; V=0; T="DWord" }
            @{ Q="Transparencia en barra de tareas"; P=$themeP; N="EnableTransparency"; V=0; T="DWord" }
            @{ Q="Animaciones en barra de tareas"; P=$perfP; N="TaskbarAnimations"; V=0; T="DWord" }
            @{ Q="Mostrar contenido al arrastrar"; P=$visP;  N="DragFullWindows"; V="0"; T="String" }
        )
        foreach ($t in $tweaks) {
            if (Ask-YN "Desactivar: $($t.Q)?" "s") {
                if (-not (Test-Path $t.P)) { New-Item -Path $t.P -Force | Out-Null }
                Set-ItemProperty -Path $t.P -Name $t.N -Value $t.V -Type $t.T -EA SilentlyContinue
                Write-OFF "$($t.Q)"
            } else {
                Write-SKIP "$($t.Q) conservado"
            }
        }
    }
}

# ════════════════════════════════════════════════════════════════
#  K. AUTOARRANQUE
# ════════════════════════════════════════════════════════════════

Write-Header "K" "AUTOARRANQUE - PROGRAMAS AL INICIO"
if (Ask-YN "Revisar programas que inician con Windows?" "s") {
    $startKeys = @(
        "HKCU:\Software\Microsoft\Windows\CurrentVersion\Run",
        "HKLM:\Software\Microsoft\Windows\CurrentVersion\Run",
        "HKLM:\Software\WOW6432Node\Microsoft\Windows\CurrentVersion\Run"
    )
    $entries = @()
    foreach ($k in $startKeys) {
        if (Test-Path $k) {
            (Get-ItemProperty -Path $k -EA SilentlyContinue).PSObject.Properties |
            Where-Object { $_.Name -notmatch "^PS" } | ForEach-Object {
                $entries += [PSCustomObject]@{ Key=$k; Name=$_.Name; Value=$_.Value }
            }
        }
    }
    if ($entries.Count -eq 0) {
        Write-INFO "No se encontraron entradas de autoarranque"
    } else {
        Write-Host ""
        for ($i = 0; $i -lt $entries.Count; $i++) {
            $sv = if ($entries[$i].Value.Length -gt 50) { $entries[$i].Value.Substring(0,50)+"..." } else { $entries[$i].Value }
            Write-Host ("  [{0:D2}] {1,-30} {2}" -f ($i+1), $entries[$i].Name, $sv) -ForegroundColor White
        }
        Write-Host ""
        Write-Host "  Ingresa numeros a ELIMINAR (ej: 1,3,5) o ENTER para omitir" -ForegroundColor Yellow
        $sel = Read-Host "  >>"
        if ($sel.Trim() -ne "") {
            $sel -split "," | ForEach-Object {
                $idx = [int]$_.Trim() - 1
                if ($idx -ge 0 -and $idx -lt $entries.Count) {
                    Remove-ItemProperty -Path $entries[$idx].Key -Name $entries[$idx].Name -EA SilentlyContinue
                    Write-OK "Eliminado: $($entries[$idx].Name)"
                }
            }
        } else {
            Write-SKIP "Autoarranque sin cambios"
        }
    }
}

# ════════════════════════════════════════════════════════════════
#  L. BLOATWARE
# ════════════════════════════════════════════════════════════════

Write-Header "L" "BLOATWARE - APPS PREINSTALADAS"
if (Ask-YN "Desinstalar apps de bloatware?" "s") {
    $bloat = @(
        @{N="Microsoft.3DBuilder"; D="3D Builder"}
        @{N="Microsoft.BingWeather"; D="Bing Tiempo"}
        @{N="Microsoft.BingNews"; D="Bing Noticias"}
        @{N="Microsoft.GetHelp"; D="Obtener ayuda"}
        @{N="Microsoft.Getstarted"; D="Introduccion"}
        @{N="Microsoft.MicrosoftOfficeHub"; D="Office Hub"}
        @{N="Microsoft.MicrosoftSolitaireCollection"; D="Solitario"}
        @{N="Microsoft.People"; D="Personas"}
        @{N="Microsoft.SkypeApp"; D="Skype"}
        @{N="Microsoft.WindowsAlarms"; D="Alarmas"}
        @{N="Microsoft.WindowsFeedbackHub"; D="Centro de opiniones"}
        @{N="Microsoft.WindowsMaps"; D="Mapas"}
        @{N="Microsoft.XboxApp"; D="Xbox App"}
        @{N="Microsoft.XboxGamingOverlay"; D="Xbox Game Bar"}
        @{N="Microsoft.YourPhone"; D="Tu Telefono"}
        @{N="Microsoft.ZuneMusic"; D="Groove Musica"}
        @{N="Microsoft.ZuneVideo"; D="Peliculas y TV"}
        @{N="microsoft.windowscommunicationsapps"; D="Correo y Calendario"}
        @{N="Clipchamp.Clipchamp"; D="Clipchamp"}
        @{N="MicrosoftTeams"; D="Microsoft Teams"}
        @{N="Microsoft.549981C3F5F10"; D="Cortana"}
    )
    
    Write-INFO "Buscando bloatware instalado..."
    $inst = @()
    foreach ($a in $bloat) {
        if (Get-AppxPackage -Name $a.N -EA SilentlyContinue) { $inst += $a }
    }
    
    if ($inst.Count -eq 0) {
        Write-OK "No se encontro bloatware"
    } else {
        Write-Host ""
        Write-Host "  Apps encontradas ($($inst.Count)):" -ForegroundColor Cyan
        for ($i = 0; $i -lt $inst.Count; $i++) {
            Write-Host ("  [{0:D2}] {1}" -f ($i+1), $inst[$i].D) -ForegroundColor White
        }
        Write-Host ""
        Write-Host "  [T] Todas  |  [S] Seleccionar  |  [N] Cancelar" -ForegroundColor Yellow
        $bc = Read-Host "  >>"
        
        $toRm = @()
        if     ($bc -eq "T" -or $bc -eq "t") { $toRm = $inst }
        elseif ($bc -eq "S" -or $bc -eq "s") {
            $sel = Read-Host "  Numeros (ej: 1,3,5)"
            $sel -split "," | ForEach-Object {
                $idx = [int]$_.Trim() - 1
                if ($idx -ge 0 -and $idx -lt $inst.Count) { $toRm += $inst[$idx] }
            }
        }
        
        foreach ($a in $toRm) {
            Get-AppxPackage -Name $a.N | Remove-AppxPackage -EA SilentlyContinue
            Get-AppxProvisionedPackage -Online | Where-Object { $_.PackageName -like "*$($a.N)*" } |
                Remove-AppxProvisionedPackage -Online -EA SilentlyContinue
            Write-OK "Desinstalado: $($a.D)"
        }
    }
}

# ════════════════════════════════════════════════════════════════
#  M. LIMPIEZA
# ════════════════════════════════════════════════════════════════

Write-Header "M" "LIMPIEZA DE ARCHIVOS TEMPORALES"
if (Ask-YN "Limpiar temporales y cache del sistema?" "s") {
    $freeAntes = (Get-PSDrive C).Free
    
    $folders = @(
        $env:TEMP,
        $env:TMP,
        "C:\Windows\Temp",
        "$env:LOCALAPPDATA\Temp",
        "$env:LOCALAPPDATA\Microsoft\Windows\INetCache",
        "C:\Windows\SoftwareDistribution\Download"
    )
    
    foreach ($f in $folders) {
        if (Test-Path $f) {
            $items = @(Get-ChildItem -Path $f -Recurse -Force -EA SilentlyContinue)
            $count = $items.Count
            $items | Remove-Item -Recurse -Force -EA SilentlyContinue
            Write-OK "Limpiado: $f ($count archivos)"
        }
    }
    
    # Papelera
    (New-Object -ComObject Shell.Application).Namespace(0xA).Items() | ForEach-Object {
        Remove-Item $_.Path -Recurse -Force -EA SilentlyContinue
    }
    Write-OK "Papelera vaciada"
    
    # Cache thumbnails
    Remove-Item "$env:LOCALAPPDATA\Microsoft\Windows\Explorer\thumbcache*" -Force -EA SilentlyContinue
    Write-OK "Cache de miniaturas eliminada"
    
    # DNS cache
    ipconfig /flushdns | Out-Null
    Write-OK "Cache DNS limpiada"
    
    $freeAhora = (Get-PSDrive C).Free
    $freed = [math]::Round(($freeAhora - $freeAntes)/1MB, 0)
    if ($freed -gt 0) { Write-OK "Espacio liberado: $freed MB" }
}

# ════════════════════════════════════════════════════════════════
#  N. SEGURIDAD
# ════════════════════════════════════════════════════════════════

Write-Header "N" "SEGURIDAD ADICIONAL"
if (Ask-YN "Aplicar configuraciones de seguridad extra?" "s") {
    
    # SMBv1
    Set-SmbServerConfiguration -EnableSMB1Protocol $false -Force -EA SilentlyContinue
    Disable-WindowsOptionalFeature -Online -FeatureName SMB1Protocol -NoRestart -EA SilentlyContinue
    Write-OK "SMBv1 deshabilitado (proteccion WannaCry)"
    
    # AutoRun/AutoPlay
    Set-Reg "$script:HKLM_Software\Microsoft\Windows NT\CurrentVersion\IniFileMapping\Autorun.inf" "(Default)" "@SYS:DoesNotExist" "String"
    Set-Reg "$script:HKLM_Software\Microsoft\Windows\CurrentVersion\Policies\Explorer" "NoDriveTypeAutoRun" 255
    Write-OK "AutoRun/AutoPlay deshabilitado"
    
    # NetBIOS
    $netbios = "$script:HKLM_System\Services\NetBT\Parameters\Interfaces"
    Get-ChildItem $netbios -EA SilentlyContinue | ForEach-Object {
        Set-ItemProperty -Path $_.PSPath -Name "NetbiosOptions" -Value 2 -EA SilentlyContinue
    }
    Write-OK "NetBIOS sobre TCP/IP deshabilitado"
    
    # LLMNR
    Set-Reg "$script:HKLM_Software\Policies\Microsoft\Windows NT\DNSClient" "EnableMulticast" 0
    Write-OK "LLMNR deshabilitado"
    
    # Firewall
    netsh advfirewall set allprofiles state on | Out-Null
    Write-OK "Firewall habilitado en todos los perfiles"
}


# ════════════════════════════════════════════════════════════════
#  SECCIÓN DE APLICACIONES
# ════════════════════════════════════════════════════════════════

# Variables para apps
$tempDir = $env:TEMP
$ghUser  = "FacuxD23"
$ghRepo  = "-"
$ghBranch = "main"

# ════════════════════════════════════════════════════════════════
#  S. MICROSOFT STORE OFFLINE
# ════════════════════════════════════════════════════════════════

Write-Header "S" "MICROSOFT STORE - INSTALADOR OFFLINE"
if (Ask-YN "Instalar Microsoft Store offline?" "s") {
    $zipUrl = "https://github.com/FacuxD23/microsoft-store-download/archive/refs/heads/main.zip"
    $zipPath = "$tempDir\msstore.zip"
    
    Write-INFO "Descargando instalador (ZIP)..."
    try {
        Invoke-WebRequest -Uri $zipUrl -OutFile $zipPath
        if (Test-Path $zipPath) {
            $sizeMB = [math]::Round((Get-Item $zipPath).Length / 1MB, 2)
            Write-OK "Descargado: $sizeMB MB"
            
            Write-INFO "Extrayendo archivos..."
            Expand-Archive -Path $zipPath -DestinationPath "$tempDir" -Force
            
            # Verificar estructura de carpetas
            $extractedBase = "$tempDir\microsoft-store-download-main"
            $storeFolder = "$extractedBase\LTSC-Add-MicrosoftStore-master"
            
            if (Test-Path "$storeFolder\Add-Store.cmd") {
                Write-OK "Archivos extraidos correctamente"
                $script:TempParaLimpiar.Add($zipPath)
                $script:TempParaLimpiar.Add($extractedBase)
                
                Write-INFO "Ejecutando instalador de Microsoft Store..."
                Write-WARN "Si aparece 'Required files missing': cierra la ventana y continua"
                Start-Process cmd.exe -ArgumentList "/c cd /d `"$storeFolder`" && Add-Store.cmd" -Wait
                Write-OK "Proceso de instalacion completado"
            } else {
                Write-ERR "Add-Store.cmd no encontrado en $storeFolder"
            }
        }
    } catch {
        Write-ERR "Error: $($_.Exception.Message)"
    }
} else {
    Write-SKIP "Microsoft Store omitida"
}

# ════════════════════════════════════════════════════════════════
#  Q. OFFICE
# ════════════════════════════════════════════════════════════════

Write-Header "Q" "OFFICE DESDE GITHUB"
$ghFile = "OInstall.exe"
$ghFolder = "OFFICE DOWNLOAD/OFFICE DOWNLOAD/"
$ghPath = "$ghFolder$ghFile"
$ghPathEnc = $ghPath -replace " ", "%20"
$ghRawUrl = "https://raw.githubusercontent.com/$ghUser/$ghRepo/$ghBranch/$ghPathEnc"
$ghTempPath = "$tempDir\$ghFile"

if (Ask-YN "Descargar e instalar Office?" "s") {
    try {
        Write-INFO "Descargando OInstall.exe..."
        Invoke-WebRequest $ghRawUrl -OutFile $ghTempPath
        if (Test-Path $ghTempPath) {
            $mb = [math]::Round((Get-Item $ghTempPath).Length / 1MB, 2)
            Write-OK "Office descargado ($mb MB)"
            $script:TempParaLimpiar.Add($ghTempPath)
            Start-Process $ghTempPath
            Write-OK "Instalador ejecutado"
        }
    } catch {
        Write-ERR "Error: $($_.Exception.Message)"
    }
} else {
    Write-SKIP "Office omitido"
}

# ════════════════════════════════════════════════════════════════
#  P. OPTIMIZER
# ════════════════════════════════════════════════════════════════

Write-Header "P" "OPTIMIZER (HELLZERG)"
$optUrl = "https://github.com/hellzerg/optimizer/releases/download/16.7/Optimizer-16.7.exe"
$optPath = "$tempDir\Optimizer.exe"

if (Ask-YN "Descargar Optimizer?" "s") {
    try {
        Write-INFO "Descargando Optimizer..."
        Invoke-WebRequest $optUrl -OutFile $optPath
        if (Test-Path $optPath) {
            Write-OK "Optimizer descargado"
            $script:TempParaLimpiar.Add($optPath)
            Start-Process $optPath
            Write-OK "Optimizer ejecutado"
        }
    } catch {
        Write-ERR "Error: $($_.Exception.Message)"
    }
} else {
    Write-SKIP "Optimizer omitido"
}

# ════════════════════════════════════════════════════════════════
#  R. WINUTIL
# ════════════════════════════════════════════════════════════════

Write-Header "R" "WINUTIL - CHRIS TITUS TOOL"
if (Ask-YN "Abrir WinUtil en ventana separada?" "s") {
    Write-INFO "Abriendo WinUtil..."
    Start-Process powershell -ArgumentList "-ExecutionPolicy Bypass -NoProfile -Command `"irm 'https://christitus.com/win' | iex`""
    Write-OK "WinUtil abierto en ventana separada"
} else {
    Write-SKIP "WinUtil omitido"
}

# ════════════════════════════════════════════════════════════════
#  T. RYTUNEX
# ════════════════════════════════════════════════════════════════

Write-Header "T" "RYTUNEX - OPTIMIZADOR WINDOWS"
if (Ask-YN "Instalar Rytunex?" "s") {
    $wingetAvailable = Get-Command winget -EA SilentlyContinue
    if ($wingetAvailable) {
        Write-INFO "Instalando Rytunex via winget..."
        try {
            winget install --id Rayen.RyTuneX --accept-package-agreements --accept-source-agreements --silent 2>&1 | Out-Null
            if ($LASTEXITCODE -eq 0) {
                Write-OK "Rytunex instalado"
                if (Ask-YN "Abrir Rytunex?" "s") {
                    Start-Sleep -Seconds 2
                    $rytunexPaths = @(
                        "$env:LOCALAPPDATA\Programs\RyTuneX\RyTuneX.exe",
                        "$env:ProgramFiles\RyTuneX\RyTuneX.exe"
                    )
                    $found = $false
                    foreach ($path in $rytunexPaths) {
                        if (Test-Path $path) {
                            Start-Process $path
                            Write-OK "Rytunex ejecutado"
                            $found = $true
                            break
                        }
                    }
                    if (-not $found) {
                        Write-WARN "Ejecutable no encontrado - abrelo desde el menu Inicio"
                    }
                }
            } else {
                Write-ERR "Error en instalacion de Rytunex"
            }
        } catch {
            Write-ERR "Fallo: $($_.Exception.Message)"
        }
    } else {
        Write-ERR "Winget no disponible - instala App Installer desde Microsoft Store"
        Write-INFO "O descarga desde: https://aka.ms/getwinget"
    }
} else {
    Write-SKIP "Rytunex omitido"
}

# ════════════════════════════════════════════════════════════════
#  U. WINHANCER
# ════════════════════════════════════════════════════════════════

Write-Header "U" "WINHANCER"
if (Ask-YN "Instalar Winhancer?" "s") {
    $url = "https://raw.githubusercontent.com/$ghUser/$ghRepo/$ghBranch/Winhance.Installer.exe"
    $path = "$tempDir\Winhance.Installer.exe"
    try {
        Write-INFO "Descargando Winhancer..."
        Invoke-WebRequest -Uri $url -OutFile $path
        if (Test-Path $path) {
            Write-OK "Winhancer descargado"
            $script:TempParaLimpiar.Add($path)
            if (Ask-YN "Abrir instalador?" "s") {
                Start-Process $path
                Write-OK "Winhancer ejecutado"
            }
        }
    } catch {
        Write-ERR "Error: $($_.Exception.Message)"
    }
} else {
    Write-SKIP "Winhancer omitido"
}

# ════════════════════════════════════════════════════════════════
#  V. WINTWEAKS
# ════════════════════════════════════════════════════════════════

Write-Header "V" "WINTWEAKS"
if (Ask-YN "Instalar WinTweaks?" "s") {
    $url = "https://raw.githubusercontent.com/$ghUser/$ghRepo/$ghBranch/Setup_WinTweaks_2.1.exe"
    $path = "$tempDir\Setup_WinTweaks_2.1.exe"
    try {
        Write-INFO "Descargando WinTweaks..."
        Invoke-WebRequest -Uri $url -OutFile $path
        if (Test-Path $path) {
            Write-OK "WinTweaks descargado"
            $script:TempParaLimpiar.Add($path)
            if (Ask-YN "Abrir instalador?" "s") {
                Start-Process $path
                Write-OK "WinTweaks ejecutado"
            }
        }
    } catch {
        Write-ERR "Error: $($_.Exception.Message)"
    }
} else {
    Write-SKIP "WinTweaks omitido"
}

# ════════════════════════════════════════════════════════════════
#  W. WINTOYS
# ════════════════════════════════════════════════════════════════

Write-Header "W" "WINTOYS"
if (Ask-YN "Instalar Wintoys?" "s") {
    $wingetAvailable = Get-Command winget -EA SilentlyContinue
    if ($wingetAvailable) {
        Write-INFO "Instalando Wintoys..."
        try {
            winget install --id 9P8LTPGCBZXD --accept-package-agreements --accept-source-agreements --silent 2>&1 | Out-Null
            if ($LASTEXITCODE -eq 0) {
                Write-OK "Wintoys instalado"
                if (Ask-YN "Abrir Wintoys?" "s") {
                    Start-Sleep -Seconds 2
                    $wintoys = Get-AppxPackage | Where-Object { $_.Name -like "*Wintoys*" }
                    if ($wintoys) {
                        Start-Process "shell:AppsFolder\$($wintoys.PackageFamilyName)!App"
                        Write-OK "Wintoys ejecutado"
                    } else {
                        Write-WARN "Wintoys no detectado - abrelo desde el menu Inicio"
                    }
                }
            } else {
                Write-ERR "Error en instalacion de Wintoys"
            }
        } catch {
            Write-ERR "Fallo: $($_.Exception.Message)"
        }
    } else {
        Write-ERR "Winget no disponible - instala App Installer desde Microsoft Store"
        Write-INFO "O descarga desde: https://aka.ms/getwinget"
    }
} else {
    Write-SKIP "Wintoys omitido"
}


# ════════════════════════════════════════════════════════════════
#  SECCIONES TÉCNICAS AVANZADAS
# ════════════════════════════════════════════════════════════════

# ════════════════════════════════════════════════════════════════
#  X. CPU / SCHEDULER TWEAKS AVANZADOS
# ════════════════════════════════════════════════════════════════

Write-Header "X" "CPU / SCHEDULER - TWEAKS AVANZADOS" "Magenta"
if (Ask-YN "Aplicar tweaks avanzados de CPU/Scheduler?" "s") {
    
    Write-Sub "Prioridad de procesos foreground"
    Set-Reg "$script:HKLM_System\Control\PriorityControl" "Win32PrioritySeparation" 26
    Write-OK "Prioridad foreground optimizada (valor 26)"
    
    Write-Sub "Dynamic Tick"
    Write-Host ""
    Write-Host "  Dynamic Tick reduce microstutters en algunos sistemas" -ForegroundColor Gray
    Write-Host "  Advertencia: puede empeorar latencia en CPUs muy modernos" -ForegroundColor Yellow
    Write-Host ""
    if (Ask-YN "Deshabilitar Dynamic Tick?" "n") {
        bcdedit /set disabledynamictick yes | Out-Null
        Write-OK "Dynamic Tick deshabilitado"
        $script:Riesgos.Add("  [!] Dynamic Tick off: REINICIO REQUERIDO")
    } else {
        Write-SKIP "Dynamic Tick sin cambios"
    }
    
    Write-Sub "HPET / Platform Clock"
    if (Ask-YN "Eliminar configuracion forzada de HPET/Platform Clock?" "s") {
        bcdedit /deletevalue useplatformclock 2>$null | Out-Null
        bcdedit /deletevalue useplatformtick 2>$null | Out-Null
        Write-OK "HPET forzado eliminado (sistema usara default)"
    }
    
    Write-Sub "Core Parking"
    Set-Reg "$script:HKLM_System\Control\Power" "CsEnabled" 0
    Write-OK "Core Parking deshabilitado (todos los cores activos)"
}

# ════════════════════════════════════════════════════════════════
#  Y. MEMORIA / RAM - TWEAKS AVANZADOS
# ════════════════════════════════════════════════════════════════

Write-Header "Y" "MEMORIA / RAM - TWEAKS AVANZADOS" "Magenta"
if (Ask-YN "Aplicar tweaks de memoria?" "s") {
    
    if ($sys.RAM -ge 16) {
        Write-Sub "Memory Compression (RAM 16GB+)"
        Write-Host ""
        Write-Host "  Memory Compression usa CPU para comprimir RAM" -ForegroundColor Gray
        Write-Host "  Con 16GB+ es mejor deshabilitarla" -ForegroundColor Yellow
        Write-Host ""
        if (Ask-YN "Deshabilitar Memory Compression?" "s") {
            try {
                Disable-MMAgent -MemoryCompression -EA Stop
                Write-OK "Memory Compression deshabilitada"
            } catch {
                Write-WARN "No se pudo deshabilitar: $($_.Exception.Message)"
            }
        }
    } else {
        Write-INFO "RAM < 16GB: Memory Compression se conserva"
    }
    
    Write-Sub "Page File (archivo de paginacion)"
    Write-Host ""
    Write-Host "  Page File manual evita fragmentacion" -ForegroundColor Gray
    Write-Host "  Recomendado: 4GB-8GB fijos" -ForegroundColor Yellow
    Write-Host ""
    if (Ask-YN "Configurar Page File manual (4GB fijo)?" "n") {
        wmic computersystem where name="%computername%" set AutomaticManagedPagefile=False 2>$null
        wmic pagefileset where name="C:\\pagefile.sys" set InitialSize=4096,MaximumSize=4096 2>$null
        Write-OK "Page File configurado: 4GB fijo"
        $script:Riesgos.Add("  [!] PageFile manual: ajustar segun RAM disponible")
    }
    
    Write-Sub "Large System Cache"
    Write-Host ""
    Write-Host "  Large System Cache prioriza cache de archivos sobre apps" -ForegroundColor Gray
    Write-Host "  Solo recomendado en workstations/servidores de archivos" -ForegroundColor Yellow
    Write-Host ""
    if (Ask-YN "Activar Large System Cache?" "n") {
        Set-Reg "$script:HKLM_System\Control\Session Manager\Memory Management" "LargeSystemCache" 1
        Write-OK "Large System Cache activado"
        $script:Riesgos.Add("  [!] LargeSystemCache: puede reducir RAM para apps")
    }
}

# ════════════════════════════════════════════════════════════════
#  Z. DISCO / NTFS - TWEAKS AVANZADOS
# ════════════════════════════════════════════════════════════════

Write-Header "Z" "DISCO / NTFS - TWEAKS AVANZADOS" "Magenta"
if (Ask-YN "Aplicar tweaks de disco/NTFS?" "s") {
    
    Write-Sub "NTFS - 8.3 Filenames"
    Write-INFO "Deshabilitando creacion de nombres 8.3 (legacy DOS)..."
    fsutil behavior set disable8dot3 1 | Out-Null
    Write-OK "Nombres 8.3 deshabilitados (menos overhead NTFS)"
    
    Write-Sub "NTFS - Last Access Time"
    Write-INFO "Deshabilitando actualizacion de ultimo acceso..."
    fsutil behavior set disablelastaccess 1 | Out-Null
    Write-OK "Last Access Time deshabilitado (menos escrituras)"
    
    if ($sys.IsSSD -or $sys.IsNVMe) {
        Write-Sub "SSD - TRIM Optimization"
        Write-INFO "Ejecutando TRIM en disco C:..."
        Optimize-Volume -DriveLetter C -ReTrim -Verbose *>&1 | Out-Null
        Write-OK "TRIM ejecutado en SSD"
        
        Write-Sub "SSD - Prefetch/Superfetch"
        Set-Reg "$script:HKLM_System\Control\Session Manager\Memory Management\PrefetchParameters" "EnablePrefetcher" 0
        Set-Reg "$script:HKLM_System\Control\Session Manager\Memory Management\PrefetchParameters" "EnableSuperfetch" 0
        Write-OK "Prefetch/Superfetch deshabilitados (innecesario en SSD)"
    } else {
        Write-INFO "HDD detectado: Prefetch/Superfetch conservados"
    }
    
    Write-Sub "Storage Sense"
    Set-Reg "$script:HKCU_Software\Microsoft\Windows\CurrentVersion\StorageSense\Parameters\StoragePolicy" "01" 0
    Write-OK "Storage Sense deshabilitado (limpieza manual mejor)"
    
    Write-Sub "WinSxS Component Cleanup"
    if (Ask-YN "Compactar WinSxS? (libera varios GB, lento)" "n") {
        Write-INFO "Limpiando WinSxS (puede tardar 5-10 min)..."
        Dism.exe /online /Cleanup-Image /StartComponentCleanup /ResetBase | Out-Null
        Write-OK "WinSxS compactado"
    }
}

# ════════════════════════════════════════════════════════════════
#  AA. TCP/IP STACK - TWEAKS AVANZADOS
# ════════════════════════════════════════════════════════════════

Write-Header "AA" "TCP/IP STACK - LATENCIA EXTREMA" "Magenta"
if (Ask-YN "Aplicar tweaks extremos de TCP/IP para latencia minima?" "n") {
    
    Write-WARN "Estos tweaks son para gamers competitivos/streaming"
    Write-Host ""
    
    Write-Sub "Nagle Algorithm OFF (ya aplicado antes)"
    Write-INFO "Nagle ya fue deshabilitado en seccion I (Red)"
    
    Write-Sub "USB Selective Suspend OFF"
    powercfg -setacvalueindex SCHEME_CURRENT SUB_USB USBSELECTIVESUSPEND 0 | Out-Null
    powercfg -setdcvalueindex SCHEME_CURRENT SUB_USB USBSELECTIVESUSPEND 0 | Out-Null
    powercfg -setactive SCHEME_CURRENT | Out-Null
    Write-OK "USB Selective Suspend deshabilitado (reduce input lag)"
    
    Write-Sub "Network Throttling Index"
    Set-Reg "$script:HKLM_Software\Microsoft\Windows NT\CurrentVersion\Multimedia\SystemProfile" "NetworkThrottlingIndex" 4294967295
    Write-OK "Network Throttling deshabilitado completamente"
    
    Write-Sub "TCP Optimizer - MaxUserPort"
    Set-Reg "$script:HKLM_System\Services\Tcpip\Parameters" "MaxUserPort" 65534
    Set-Reg "$script:HKLM_System\Services\Tcpip\Parameters" "TcpTimedWaitDelay" 30
    Write-OK "Puertos TCP ampliados (65534) y TIME_WAIT reducido"
    
    Write-Sub "Power Throttling OFF"
    Set-Reg "$script:HKLM_System\Control\Power\PowerThrottling" "PowerThrottlingOff" 1
    Write-OK "Power Throttling deshabilitado (Win10 1709+)"
}

# ════════════════════════════════════════════════════════════════
#  AB. KERNEL TWEAKS - VBS / HVCI / SPECTRE
# ════════════════════════════════════════════════════════════════

Write-Header "AB" "KERNEL TWEAKS - VBS / HVCI / MITIGACIONES" "Red"
Write-Host ""
Write-Host "  ═══════════════════════════════════════════════════════════════" -ForegroundColor Red
Write-Host "  ADVERTENCIA: Estos tweaks mejoran rendimiento CPU" -ForegroundColor Yellow
Write-Host "  pero REDUCEN SEGURIDAD contra ataques especulativos" -ForegroundColor Yellow
Write-Host "  Solo aplicar en PCs gaming/personales, NO en empresas" -ForegroundColor Yellow
Write-Host "  ═══════════════════════════════════════════════════════════════" -ForegroundColor Red
Write-Host ""

if (Ask-YN "Aplicar kernel tweaks? (AVANZADO)" "n") {
    
    Write-Sub "VBS / HVCI / Core Isolation"
    Write-Host ""
    Write-Host "  VBS (Virtualization Based Security) usa CPU extra" -ForegroundColor Gray
    Write-Host "  Impacto: 5-15% rendimiento segun CPU" -ForegroundColor Yellow
    Write-Host ""
    if (Ask-YN "Deshabilitar VBS/HVCI?" "s") {
        Set-Reg "$script:HKLM_System\Control\DeviceGuard" "EnableVirtualizationBasedSecurity" 0
        Set-Reg "$script:HKLM_System\Control\DeviceGuard" "RequirePlatformSecurityFeatures" 0
        Set-Reg "$script:HKLM_System\Control\Lsa" "LsaCfgFlags" 0
        Set-Reg "$script:HKLM_System\Control\DeviceGuard\Scenarios\HypervisorEnforcedCodeIntegrity" "Enabled" 0
        bcdedit /set hypervisorlaunchtype off | Out-Null
        Write-OK "VBS/HVCI deshabilitado"
        $script:Riesgos.Add("  [!] VBS/HVCI off: REINICIO REQUERIDO, seguridad reducida")
    }
    
    Write-Sub "Mitigaciones Spectre/Meltdown"
    Write-Host ""
    Write-Host "  Deshabilitar mitigaciones mejora CPU ~5-10%" -ForegroundColor Gray
    Write-Host "  Riesgo: vulnerable a ataques especulativos" -ForegroundColor Red
    Write-Host ""
    if (Ask-YN "Deshabilitar mitigaciones Spectre/Meltdown?" "n") {
        Set-Reg "$script:HKLM_System\Control\Session Manager\Memory Management" "FeatureSettingsOverride" 3
        Set-Reg "$script:HKLM_System\Control\Session Manager\Memory Management" "FeatureSettingsOverrideMask" 3
        Write-OK "Mitigaciones Spectre/Meltdown deshabilitadas"
        $script:Riesgos.Add("  [!] Spectre/Meltdown off: REINICIO REQUERIDO, SEGURIDAD REDUCIDA")
    }
    
    Write-Sub "Hyper-V Hypervisor"
    if (Ask-YN "Deshabilitar Hypervisor completamente?" "n") {
        bcdedit /set hypervisorlaunchtype off | Out-Null
        Disable-Svc "vmcompute" "VM Compute"
        Disable-Svc "vmms" "Hyper-V Management"
        Write-OK "Hypervisor deshabilitado"
        $script:Riesgos.Add("  [!] Hypervisor off: VMs no funcionaran, WSL2 afectado")
    }
}

# ════════════════════════════════════════════════════════════════
#  AC. GAMING EXTREMO - MMCSS / GPU / DWM
# ════════════════════════════════════════════════════════════════

Write-Header "AC" "GAMING EXTREMO - MMCSS / GPU PRIORITY / DWM" "Green"
if (Ask-YN "Aplicar optimizaciones gaming extremas?" "s") {
    
    Write-Sub "MMCSS - Multimedia Class Scheduler"
    $mmPath = "$script:HKLM_Software\Microsoft\Windows NT\CurrentVersion\Multimedia\SystemProfile"
    Set-Reg $mmPath "SystemResponsiveness" 0
    Write-OK "SystemResponsiveness = 0 (prioridad maxima juegos)"
    
    $gamePath = "$mmPath\Tasks\Games"
    if (-not (Test-Path $gamePath)) { New-Item -Path $gamePath -Force | Out-Null }
    Set-ItemProperty -Path $gamePath -Name "GPU Priority" -Value 8 -Type DWord -EA SilentlyContinue
    Set-ItemProperty -Path $gamePath -Name "Priority" -Value 6 -Type DWord -EA SilentlyContinue
    Set-ItemProperty -Path $gamePath -Name "Scheduling Category" -Value "High" -Type String -EA SilentlyContinue
    Set-ItemProperty -Path $gamePath -Name "SFIO Priority" -Value "High" -Type String -EA SilentlyContinue
    Write-OK "GPU Priority = 8, Scheduling = High"
    
    Write-Sub "Game Bar / Game DVR"
    Set-Reg "$script:HKCU_Software\Microsoft\Windows\CurrentVersion\GameDVR" "AppCaptureEnabled" 0
    Set-Reg "$script:HKCU_Software\Microsoft\GameBar" "ShowStartupPanel" 0
    Set-Reg "$script:HKCU_Software\Microsoft\GameBar" "UseNexusForGameBarEnabled" 0
    Set-Reg "$script:HKLM_Software\Policies\Microsoft\Windows\GameDVR" "AllowGameDVR" 0
    Write-OK "Game Bar/DVR deshabilitado completamente"
    
    Write-Sub "Hardware Accelerated GPU Scheduling"
    if ($sys.IsWin10 -and $sys.Build -ge 19041) {
        if (Ask-YN "Activar Hardware GPU Scheduling (Win10 2004+)?" "s") {
            Set-Reg "$script:HKLM_System\Control\GraphicsDrivers" "HwSchMode" 2
            Write-OK "Hardware GPU Scheduling activado"
            $script:Riesgos.Add("  [!] HwSchMode: REINICIO REQUERIDO para aplicar")
        }
    } elseif ($sys.IsWin11) {
        Set-Reg "$script:HKLM_System\Control\GraphicsDrivers" "HwSchMode" 2
        Write-OK "Hardware GPU Scheduling activado (Win11)"
    }
    
    Write-Sub "TDR Delay (GPU timeout)"
    Write-Host ""
    Write-Host "  TDR Delay evita micro-freezes de GPU" -ForegroundColor Gray
    Write-Host "  Valor 10 = 10 segundos antes de reset" -ForegroundColor Yellow
    Write-Host ""
    if (Ask-YN "Configurar TDR Delay = 10?" "s") {
        Set-Reg "$script:HKLM_System\Control\GraphicsDrivers" "TdrDelay" 10
        Set-Reg "$script:HKLM_System\Control\GraphicsDrivers" "TdrDdiDelay" 10
        Write-OK "TDR Delay configurado"
    }
    
    Write-Sub "DWM (Desktop Window Manager)"
    if (Ask-YN "Optimizar DWM para gaming?" "s") {
        Set-Reg "$script:HKCU_Software\Microsoft\Windows\DWM" "UseDpiScaling" 0
        Set-Reg "$script:HKCU_Software\Microsoft\Windows\DWM" "EnableAeroPeek" 0
        Set-Reg "$script:HKCU_Software\Microsoft\Windows\DWM" "AlwaysHibernateThumbnails" 0
        Write-OK "DWM optimizado (Aero Peek off, DPI scaling off)"
    }
}

# ════════════════════════════════════════════════════════════════
#  AD. TAREAS PROGRAMADAS - DESHABILITAR TELEMETRÍA
# ════════════════════════════════════════════════════════════════

Write-Header "AD" "TAREAS PROGRAMADAS - TELEMETRIA Y DIAGNOSTICOS" "Yellow"
if (Ask-YN "Deshabilitar tareas programadas de telemetria?" "s") {
    
    $taskPaths = @(
        "\Microsoft\Windows\Application Experience\*",
        "\Microsoft\Windows\Autochk\*",
        "\Microsoft\Windows\Customer Experience Improvement Program\*",
        "\Microsoft\Windows\DiskDiagnostic\*",
        "\Microsoft\Windows\Maintenance\*",
        "\Microsoft\Windows\PI\*",
        "\Microsoft\Windows\Power Efficiency Diagnostics\*",
        "\Microsoft\Windows\Windows Error Reporting\*"
    )
    
    $disabled = 0
    foreach ($path in $taskPaths) {
        Get-ScheduledTask -TaskPath $path -EA SilentlyContinue | ForEach-Object {
            Disable-ScheduledTask -TaskName $_.TaskName -TaskPath $_.TaskPath -EA SilentlyContinue | Out-Null
            $disabled++
        }
    }
    
    Write-OK "Tareas deshabilitadas: $disabled"
    
    # Tareas específicas importantes
    $criticalTasks = @(
        "\Microsoft\Windows\Application Experience\Microsoft Compatibility Appraiser",
        "\Microsoft\Windows\Application Experience\ProgramDataUpdater",
        "\Microsoft\Windows\Autochk\Proxy",
        "\Microsoft\Windows\Customer Experience Improvement Program\Consolidator",
        "\Microsoft\Windows\Customer Experience Improvement Program\UsbCeip",
        "\Microsoft\Windows\DiskDiagnostic\Microsoft-Windows-DiskDiagnosticDataCollector"
    )
    
    foreach ($task in $criticalTasks) {
        Disable-ScheduledTask -TaskName $task -EA SilentlyContinue | Out-Null
    }
    
    Write-OK "Tareas criticas de telemetria deshabilitadas"
}


# ════════════════════════════════════════════════════════════════
#  REINICIAR EXPLORER
# ════════════════════════════════════════════════════════════════

Write-Header ">" "REINICIAR EXPLORER"
if (Ask-YN "Reiniciar Explorer para aplicar cambios visuales?" "s") {
    Write-INFO "Reiniciando Explorer..."
    Get-Process explorer -EA SilentlyContinue | Stop-Process -Force -EA SilentlyContinue
    Start-Sleep -Seconds 2
    Start-Process explorer.exe
    Write-OK "Explorer reiniciado"
}

# ════════════════════════════════════════════════════════════════
#  LIMPIEZA AUTOMATICA AL REINICIAR
# ════════════════════════════════════════════════════════════════

Write-Header "~" "LIMPIEZA AUTOMATICA AL REINICIAR"

if ($script:TempParaLimpiar.Count -gt 0) {
    $cleanScript = "$env:TEMP\cleanup_optwin_v6.ps1"
    
    $lines = @("# Auto-limpieza generada por Optimizador Windows v6.0")
    $lines += "Start-Sleep -Seconds 10  # Esperar a que los procesos cierren"
    
    foreach ($f in $script:TempParaLimpiar) {
        $lines += "if (Test-Path '$f') { Remove-Item '$f' -Recurse -Force -EA SilentlyContinue }"
    }
    
    # Autoeliminar la tarea y el propio script al final
    $lines += "Unregister-ScheduledTask -TaskName 'CleanupOptWin_v6' -Confirm:`$false -EA SilentlyContinue"
    $lines += "Remove-Item '$cleanScript' -Force -EA SilentlyContinue"
    
    $lines | Out-File -FilePath $cleanScript -Encoding UTF8 -Force
    
    # Registrar tarea programada que corre una vez al proximo inicio
    $action = New-ScheduledTaskAction -Execute "powershell.exe" `
        -Argument "-WindowStyle Hidden -ExecutionPolicy Bypass -File `"$cleanScript`""
    $trigger = New-ScheduledTaskTrigger -AtStartup
    $settings = New-ScheduledTaskSettingsSet -ExecutionTimeLimit (New-TimeSpan -Minutes 2)
    
    Register-ScheduledTask -TaskName "CleanupOptWin_v6" `
        -Action $action -Trigger $trigger -Settings $settings `
        -RunLevel Highest -Force -EA SilentlyContinue | Out-Null
    
    Write-OK "Tarea de limpieza programada para el proximo reinicio"
    Write-INFO "Archivos a eliminar: $($script:TempParaLimpiar.Count)"
} else {
    Write-SKIP "No hay archivos temporales para limpiar"
}

# ════════════════════════════════════════════════════════════════
#  RESUMEN FINAL
# ════════════════════════════════════════════════════════════════

$script:Stopwatch.Stop()
$elapsed = $script:Stopwatch.Elapsed
$timeStr = "{0:D2}m {1:D2}s" -f $elapsed.Minutes, $elapsed.Seconds

Clear-Host
Write-Host ""
Write-Host "  ════════════════════════════════════════════════════════════════" -ForegroundColor Green
Write-Host "     ✓ OPTIMIZACIÓN COMPLETADA - Windows v6.0 ULTIMATE" -ForegroundColor Green
Write-Host "  ════════════════════════════════════════════════════════════════" -ForegroundColor Green
Write-Host ""

# Panel de información
Write-Host "  ╔══════════════════════════════════════════════════════════════╗" -ForegroundColor Cyan
Write-Host "  ║  INFORMACIÓN DEL SISTEMA                                     ║" -ForegroundColor Cyan
Write-Host "  ╠══════════════════════════════════════════════════════════════╣" -ForegroundColor Cyan
Write-Host "  ║  OS:      $($sys.WinName.PadRight(49)) ║" -ForegroundColor White
Write-Host "  ║  Build:   $($sys.BuildStr.PadRight(49)) ║" -ForegroundColor White
Write-Host "  ║  Perfil:  Gama $gamaStr | Uso $($usoStr.PadRight(34)) ║" -ForegroundColor White
Write-Host "  ╚══════════════════════════════════════════════════════════════╝" -ForegroundColor Cyan
Write-Host ""

# Tabla de estadísticas
Write-Host "  ╔══════════════════════════════════════════════════════════════╗" -ForegroundColor Yellow
Write-Host "  ║  ESTADÍSTICAS                                                ║" -ForegroundColor Yellow
Write-Host "  ╠══════════════════════════════════════════════════════════════╣" -ForegroundColor Yellow
Write-Host "  ║  Tweaks aplicados:    $($script:Aplicados.ToString().PadRight(38)) ║" -ForegroundColor Green
Write-Host "  ║  Tweaks omitidos:     $($script:Omitidos.ToString().PadRight(38)) ║" -ForegroundColor Gray
Write-Host "  ║  Tiempo total:        $($timeStr.PadRight(38)) ║" -ForegroundColor Cyan
Write-Host "  ║  Log generado:        C:\OptimizadorWindows_v6.log$(" ".PadRight(13)) ║" -ForegroundColor White
Write-Host "  ╚══════════════════════════════════════════════════════════════╝" -ForegroundColor Yellow
Write-Host ""

# Riesgos y advertencias
if ($script:Riesgos.Count -gt 0) {
    Write-Host "  ╔══════════════════════════════════════════════════════════════╗" -ForegroundColor Red
    Write-Host "  ║  ⚠ ADVERTENCIAS Y CONSIDERACIONES                            ║" -ForegroundColor Red
    Write-Host "  ╠══════════════════════════════════════════════════════════════╣" -ForegroundColor Red
    foreach ($r in $script:Riesgos) {
        $rClean = $r -replace "^\s*\[!\]\s*", ""
        $lines = [System.Text.RegularExpressions.Regex]::Split($rClean, "(.{1,56})")
        foreach ($line in $lines) {
            if ($line.Trim()) {
                Write-Host "  ║  $($line.PadRight(60)) ║" -ForegroundColor Yellow
            }
        }
    }
    Write-Host "  ╚══════════════════════════════════════════════════════════════╝" -ForegroundColor Red
    Write-Host ""
}

# Recomendaciones finales
Write-Host "  ════════════════════════════════════════════════════════════════" -ForegroundColor Magenta
Write-Host "   PRÓXIMOS PASOS RECOMENDADOS:" -ForegroundColor Magenta
Write-Host "  ════════════════════════════════════════════════════════════════" -ForegroundColor Magenta
Write-Host ""

$needReboot = $false
foreach ($r in $script:Riesgos) {
    if ($r -match "REINICIO") { $needReboot = $true; break }
}

if ($needReboot) {
    Write-Host "  [1] REINICIAR EL EQUIPO" -ForegroundColor Red
    Write-Host "      Los cambios de kernel, VBS, red y servicios requieren reinicio" -ForegroundColor Gray
    Write-Host ""
}

Write-Host "  [2] Revisar el log completo" -ForegroundColor Cyan
Write-Host "      C:\OptimizadorWindows_v6.log" -ForegroundColor Gray
Write-Host ""

Write-Host "  [3] Probar rendimiento" -ForegroundColor Green
Write-Host "      - Benchmark CPU/GPU antes y despues" -ForegroundColor Gray
Write-Host "      - Medir latencia de red (ping, jitter)" -ForegroundColor Gray
Write-Host "      - Revisar uso de RAM/CPU en reposo" -ForegroundColor Gray
Write-Host ""

Write-Host "  [4] Si algo falla:" -ForegroundColor Yellow
Write-Host "      - Restaurar punto creado al inicio" -ForegroundColor Gray
Write-Host "      - Revisar backups de registro en C:\" -ForegroundColor Gray
Write-Host ""

Write-Host "  ════════════════════════════════════════════════════════════════" -ForegroundColor Magenta
Write-Host ""

# Exportar configuración aplicada
Write-Host "  >> Exportar resumen de cambios a archivo? (s/N): " -NoNewline -ForegroundColor Cyan
$exportar = Read-Host
if ($exportar -eq "s" -or $exportar -eq "S") {
    $reportPath = "$env:USERPROFILE\Desktop\OptimizadorReport_v6.txt"
    $report = @"
═════════════════════════════════════════════════════════════════
OPTIMIZADOR WINDOWS v6.0 ULTIMATE - REPORTE DE EJECUCIÓN
═════════════════════════════════════════════════════════════════

Fecha: $(Get-Date -Format "yyyy-MM-dd HH:mm:ss")
Usuario: $env:USERNAME
Computadora: $env:COMPUTERNAME

SISTEMA:
--------
OS: $($sys.WinName)
Build: $($sys.BuildStr)
CPU: $($sys.CPU)
RAM: $($sys.RAMStr)
Disco: $($sys.Disk)
GPU: $($sys.GPU)

PERFIL SELECCIONADO:
--------------------
Gama: $gamaStr
Uso: $usoStr

ESTADÍSTICAS:
-------------
Tweaks aplicados: $($script:Aplicados)
Tweaks omitidos: $($script:Omitidos)
Tiempo de ejecución: $timeStr

ADVERTENCIAS:
-------------
$($script:Riesgos -join "`n")

LOG COMPLETO:
-------------
Ver: C:\OptimizadorWindows_v6.log

═════════════════════════════════════════════════════════════════
Script desarrollado por FacuxD23
GitHub: https://github.com/FacuxD23/-
═════════════════════════════════════════════════════════════════
"@
    
    $report | Out-File -FilePath $reportPath -Encoding UTF8
    Write-OK "Reporte exportado: $reportPath"
}

Write-Host ""
Write-Host "  ════════════════════════════════════════════════════════════════" -ForegroundColor Green
Write-Host ""

if ($needReboot) {
    Write-Host "  >> REINICIAR AHORA? (s/N): " -NoNewline -ForegroundColor Red
    $rb = Read-Host
    if ($rb -eq "s" -or $rb -eq "S") {
        Write-Host ""
        Write-Host "  Reiniciando en 10 segundos..." -ForegroundColor Yellow
        Write-Host "  Presiona Ctrl+C para cancelar" -ForegroundColor Gray
        Start-Sleep -Seconds 10
        Restart-Computer -Force
    }
}

Write-Host ""
Write-Host "  Presiona ENTER para cerrar..." -ForegroundColor Gray
Read-Host

# FIN DEL SCRIPT

# ════════════════════════════════════════════════════════════════
#  RESUMEN FINAL PRO
# ════════════════════════════════════════════════════════════════

$script:Stopwatch.Stop()
$elapsed = $script:Stopwatch.Elapsed
$timeStr = "{0:D2}m {1:D2}s" -f $elapsed.Minutes, $elapsed.Seconds

Clear-Host
Write-Host ""
Write-Host "  ════════════════════════════════════════════════════════════════" -ForegroundColor Green
Write-Host "     ✓ OPTIMIZACIÓN COMPLETADA  -ForegroundColor Green
Write-Host "  ════════════════════════════════════════════════════════════════" -ForegroundColor Green
Write-Host ""

# Panel de información
Write-Host "  ╔══════════════════════════════════════════════════════════════╗" -ForegroundColor Cyan
Write-Host "  ║  INFORMACIÓN DEL SISTEMA                                     ║" -ForegroundColor Cyan
Write-Host "  ╠══════════════════════════════════════════════════════════════╣" -ForegroundColor Cyan
Write-Host "  ║  OS:          $($sys.WinName.PadRight(45)) ║" -ForegroundColor White
Write-Host "  ║  Build:       $($sys.BuildStr.PadRight(45)) ║" -ForegroundColor White
Write-Host "  ║  Form Factor: $($sys.FormFactor.PadRight(45)) ║" -ForegroundColor White
Write-Host "  ║  Disco:       $($sys.DiskType.PadRight(45)) ║" -ForegroundColor White

if ($Gaming -or $Privacy -or $Performance) {
    $perfil = if($Gaming){"GAMING"}elseif($Privacy){"PRIVACY"}else{"PERFORMANCE"}
    Write-Host "  ║  Perfil:      $($perfil.PadRight(45)) ║" -ForegroundColor Yellow
}

if ($script:ModoSeguro) {
    Write-Host "  ║  Modo:        SEGURO (tweaks reversibles)".PadRight(60) + "║" -ForegroundColor Green
} elseif ($script:ModoAgresivo) {
    Write-Host "  ║  Modo:        AGRESIVO (maxima optimizacion)".PadRight(60) + "║" -ForegroundColor Red
}

Write-Host "  ╚══════════════════════════════════════════════════════════════╝" -ForegroundColor Cyan
Write-Host ""

# Tabla de estadísticas
Write-Host "  ╔══════════════════════════════════════════════════════════════╗" -ForegroundColor Yellow
Write-Host "  ║  ESTADÍSTICAS                                                ║" -ForegroundColor Yellow
Write-Host "  ╠══════════════════════════════════════════════════════════════╣" -ForegroundColor Yellow
Write-Host "  ║  Tweaks aplicados:    $($script:Aplicados.ToString().PadRight(38)) ║" -ForegroundColor Green
Write-Host "  ║  Tweaks omitidos:     $($script:Omitidos.ToString().PadRight(38)) ║" -ForegroundColor Gray
Write-Host "  ║  Tiempo total:        $($timeStr.PadRight(38)) ║" -ForegroundColor Cyan
Write-Host "  ║  Log:                 $($script:LogFile.PadRight(38)) ║" -ForegroundColor White
Write-Host "  ║  Backups:             $($script:BackupFolder.PadRight(38)) ║" -ForegroundColor White
Write-Host "  ╚══════════════════════════════════════════════════════════════╝" -ForegroundColor Yellow
Write-Host ""

# Riesgos y advertencias
if ($script:Riesgos.Count -gt 0) {
    Write-Host "  ╔══════════════════════════════════════════════════════════════╗" -ForegroundColor Red
    Write-Host "  ║  ⚠ ADVERTENCIAS Y CONSIDERACIONES                            ║" -ForegroundColor Red
    Write-Host "  ╠══════════════════════════════════════════════════════════════╣" -ForegroundColor Red
    foreach ($r in $script:Riesgos) {
        $rClean = $r -replace "^\s*\[!\]\s*", ""
        $lines = [System.Text.RegularExpressions.Regex]::Split($rClean, "(.{1,56})")
        foreach ($line in $lines) {
            if ($line.Trim()) {
                Write-Host "  ║  $($line.PadRight(60)) ║" -ForegroundColor Yellow
            }
        }
    }
    Write-Host "  ╚══════════════════════════════════════════════════════════════╝" -ForegroundColor Red
    Write-Host ""
}

# Recomendaciones finales
Write-Host "  ════════════════════════════════════════════════════════════════" -ForegroundColor Magenta
Write-Host "   PRÓXIMOS PASOS RECOMENDADOS:" -ForegroundColor Magenta
Write-Host "  ════════════════════════════════════════════════════════════════" -ForegroundColor Magenta
Write-Host ""

$needReboot = $false
foreach ($r in $script:Riesgos) {
    if ($r -match "REINICIO") { $needReboot = $true; break }
}

if ($needReboot) {
    Write-Host "  [1] REINICIAR EL EQUIPO (OBLIGATORIO)" -ForegroundColor Red
    Write-Host "      Los cambios de kernel, VBS, red y servicios requieren reinicio" -ForegroundColor Gray
    Write-Host ""
}

Write-Host "  [2] Revisar el log completo" -ForegroundColor Cyan
Write-Host "      $($script:LogFile)" -ForegroundColor Gray
Write-Host ""

Write-Host "  [3] Backups de registro disponibles en:" -ForegroundColor Green
Write-Host "      $($script:BackupFolder)" -ForegroundColor Gray
Write-Host ""

Write-Host "  [4] Para revertir cambios en el futuro:" -ForegroundColor Yellow
Write-Host "      .\optimizar_windows_v6_PRO.ps1 -Restore" -ForegroundColor Gray
Write-Host ""

Write-Host "  [5] Probar rendimiento" -ForegroundColor Green
Write-Host "      - Benchmark CPU/GPU antes y despues" -ForegroundColor Gray
Write-Host "      - Medir latencia de red (ping, jitter)" -ForegroundColor Gray
Write-Host "      - Revisar uso de RAM/CPU en reposo" -ForegroundColor Gray
Write-Host ""

Write-Host "  ════════════════════════════════════════════════════════════════" -ForegroundColor Magenta
Write-Host ""

# Exportar configuración aplicada
if (-not $Silent) {
    Write-Host "  >> Exportar resumen de cambios a archivo? (s/N): " -NoNewline -ForegroundColor Cyan
    $exportar = Read-Host
} else {
    $exportar = "s"
}

if ($exportar -eq "s" -or $exportar -eq "S") {
    $reportPath = "$env:USERPROFILE\Desktop\OptimizadorReport_v6_PRO_$(Get-Date -Format 'yyyyMMdd_HHmmss').txt"
    
    $perfilInfo = ""
    if ($Gaming) { $perfilInfo += "`nPerfil: GAMING" }
    if ($Privacy) { $perfilInfo += "`nPerfil: PRIVACY" }
    if ($Performance) { $perfilInfo += "`nPerfil: PERFORMANCE" }
    if ($script:ModoSeguro) { $perfilInfo += "`nModo: SEGURO" }
    if ($script:ModoAgresivo) { $perfilInfo += "`nModo: AGRESIVO" }
    
    $report = @"
═════════════════════════════════════════════════════════════════
OPTIMIZADOR WINDOWS  - REPORTE DE EJECUCIÓN
═════════════════════════════════════════════════════════════════

Fecha: $(Get-Date -Format "yyyy-MM-dd HH:mm:ss")
Usuario: $env:USERNAME
Computadora: $env:COMPUTERNAME
$perfilInfo

SISTEMA:
--------
OS: $($sys.WinName)
Build: $($sys.BuildStr)
Form Factor: $($sys.FormFactor)
CPU: $($sys.CPU)
Cores/Threads: $($sys.CPUCores) / $($sys.CPUThreads)
RAM: $($sys.RAMStr)
Disco: $($sys.DiskType) - $($sys.Disk)
GPU: $($sys.GPU)

ESTADÍSTICAS:
-------------
Tweaks aplicados: $($script:Aplicados)
Tweaks omitidos: $($script:Omitidos)
Tiempo de ejecución: $timeStr

ADVERTENCIAS:
-------------
$($script:Riesgos -join "`n")

ARCHIVOS:
---------
Log completo: $($script:LogFile)
Backups registro: $($script:BackupFolder)

PARA REVERTIR:
--------------
.\optimizar_windows_v6_PRO.ps1 -Restore

═════════════════════════════════════════════════════════════════
Script desarrollado por yo
GitHub: https://github.com/FacuxD23/-
═════════════════════════════════════════════════════════════════
"@
    
    $report | Out-File -FilePath $reportPath -Encoding UTF8
    Write-OK "Reporte exportado: $reportPath"
}

Write-Host ""
Write-Host "  ════════════════════════════════════════════════════════════════" -ForegroundColor Green
Write-Host ""

if ($needReboot -and -not $Silent) {
    Write-Host "  >> REINICIAR AHORA? (s/N): " -NoNewline -ForegroundColor Red
    $rb = Read-Host
    if ($rb -eq "s" -or $rb -eq "S") {
        Write-Host ""
        Write-Host "  Reiniciando en 10 segundos..." -ForegroundColor Yellow
        Write-Host "  Presiona Ctrl+C para cancelar" -ForegroundColor Gray
        Start-Sleep -Seconds 10
        Restart-Computer -Force
    }
}

if (-not $Silent) {
    Write-Host ""
    Write-Host "  Presiona ENTER para cerrar..." -ForegroundColor Gray
    Read-Host
}

# FIN DEL SCRIPT

# ════════════════════════════════════════════════════════════════
#  RESUMEN  - ESTADÍSTICAS DETALLADAS
# ════════════════════════════════════════════════════════════════

$script:Stopwatch.Stop()
$elapsed = $script:Stopwatch.Elapsed
$timeStr = "{0:D2}m {1:D2}s" -f $elapsed.Minutes, $elapsed.Seconds

Clear-Host
Write-Host ""
Write-Host "  ╔══════════════════════════════════════════════════════════════╗" -ForegroundColor Green
Write-Host "  ║   ✓ OPTIMIZACIÓN COMPLETADA - Windows v6.0 PRO              ║" -ForegroundColor Green
Write-Host "  ╚══════════════════════════════════════════════════════════════╝" -ForegroundColor Green
Write-Host ""

# Panel de información
Write-Host "  ╔══════════════════════════════════════════════════════════════╗" -ForegroundColor Cyan
Write-Host "  ║  INFORMACIÓN DEL SISTEMA                                     ║" -ForegroundColor Cyan
Write-Host "  ╠══════════════════════════════════════════════════════════════╣" -ForegroundColor Cyan
Write-Host "  ║  OS:        $($sys.WinName.PadRight(47)) ║" -ForegroundColor White
Write-Host "  ║  Build:     $($sys.BuildStr.PadRight(47)) ║" -ForegroundColor White
Write-Host "  ║  Tipo:      $(if($sys.IsLaptop){'Laptop'}else{'Desktop'}).PadRight(47)) ║" -ForegroundColor White
Write-Host "  ║  Perfil:    $("$gamaStr | $usoStr".PadRight(47)) ║" -ForegroundColor White
Write-Host "  ║  Modo:      $(if($script:ModoSeguro){'SEGURO'}elseif($script:ModoAgresivo){'AGRESIVO'}else{'BALANCED'}).PadRight(47)) ║" -ForegroundColor White
Write-Host "  ╚══════════════════════════════════════════════════════════════╝" -ForegroundColor Cyan
Write-Host ""

# Estadísticas
Write-Host "  ╔══════════════════════════════════════════════════════════════╗" -ForegroundColor Yellow
Write-Host "  ║  ESTADÍSTICAS                                                ║" -ForegroundColor Yellow
Write-Host "  ╠══════════════════════════════════════════════════════════════╣" -ForegroundColor Yellow
Write-Host "  ║  Tweaks aplicados:     $($script:Aplicados.ToString().PadRight(36)) ║" -ForegroundColor Green
Write-Host "  ║  Tweaks omitidos:      $($script:Omitidos.ToString().PadRight(36)) ║" -ForegroundColor Gray
Write-Host "  ║  Tiempo total:         $($timeStr.PadRight(36)) ║" -ForegroundColor Cyan
Write-Host "  ║  Log:                  $($script:LogFile.PadRight(36)) ║" -ForegroundColor White
if ($Backup) {
    $backupCount = (Get-ChildItem "$script:BackupDir\*.reg" -EA SilentlyContinue).Count
    Write-Host "  ║  Backups creados:      $($backupCount.ToString().PadRight(36)) ║" -ForegroundColor Green
}
Write-Host "  ╚══════════════════════════════════════════════════════════════╝" -ForegroundColor Yellow
Write-Host ""

# Riesgos
if ($script:Riesgos.Count -gt 0) {
    Write-Host "  ╔══════════════════════════════════════════════════════════════╗" -ForegroundColor Red
    Write-Host "  ║  ⚠ ADVERTENCIAS Y CONSIDERACIONES                            ║" -ForegroundColor Red
    Write-Host "  ╠══════════════════════════════════════════════════════════════╣" -ForegroundColor Red
    foreach ($r in $script:Riesgos) {
        $rClean = $r -replace "^\s*\[!\]\s*", ""
        $lines = [regex]::Matches($rClean, ".{1,58}(\s|$)") | ForEach-Object { $_.Value.Trim() }
        foreach ($line in $lines) {
            if ($line) {
                Write-Host "  ║  $($line.PadRight(60)) ║" -ForegroundColor Yellow
            }
        }
    }
    Write-Host "  ╚══════════════════════════════════════════════════════════════╝" -ForegroundColor Red
    Write-Host ""
}

# Recomendaciones
Write-Host "  ════════════════════════════════════════════════════════════════" -ForegroundColor Magenta
Write-Host "   PRÓXIMOS PASOS:" -ForegroundColor Magenta
Write-Host "  ════════════════════════════════════════════════════════════════" -ForegroundColor Magenta
Write-Host ""

$needReboot = $false
foreach ($r in $script:Riesgos) {
    if ($r -match "REINICIO") { $needReboot = $true; break }
}

if ($needReboot) {
    Write-Host "  [1] REINICIAR AHORA (RECOMENDADO)" -ForegroundColor Red
    Write-Host ""
}

Write-Host "  [2] Para restaurar cambios en el futuro:" -ForegroundColor Cyan
Write-Host "      .\optimizar_windows_v6_PRO.ps1 -Restore" -ForegroundColor Gray
Write-Host ""

if ($Backup) {
    Write-Host "  [3] Backups guardados en:" -ForegroundColor Green
    Write-Host "      $script:BackupDir" -ForegroundColor Gray
    Write-Host ""
}

Write-Host "  [4] Revisar log completo:" -ForegroundColor Yellow
Write-Host "      $script:LogFile" -ForegroundColor Gray
Write-Host ""

Write-Host "  ════════════════════════════════════════════════════════════════" -ForegroundColor Magenta
Write-Host ""

# Exportar resumen
if (-not $script:ModoSilencio) {
    Write-Host "  >> Exportar resumen a Desktop? (s/N): " -NoNewline -ForegroundColor Cyan
    $exp = Read-Host
    if ($exp -eq "s") {
        $reportPath = "$env:USERPROFILE\Desktop\OptimizadorReport_PRO_$(Get-Date -Format 'yyyyMMdd_HHmmss').txt"
        $report = @"
═════════════════════════════════════════════════════════════════
OPTIMIZADOR WINDOWS - REPORTE
═════════════════════════════════════════════════════════════════

Fecha: $(Get-Date -Format "yyyy-MM-dd HH:mm:ss")
Usuario: $env:USERNAME
PC: $env:COMPUTERNAME

SISTEMA:
--------
OS: $($sys.WinName)
Build: $($sys.BuildStr)
Tipo: $(if($sys.IsLaptop){'Laptop'}else{'Desktop'})
CPU: $($sys.CPU)
RAM: $($sys.RAMStr)
Disco: $(if($sys.IsNVMe){'NVMe'}elseif($sys.IsSSD){'SSD'}else{'HDD'})
GPU: $($sys.GPU)

CONFIGURACIÓN:
--------------
Perfil: $($script:PerfilActivo)
Gama: $gamaStr
Uso: $usoStr
Modo Seguro: $(if($script:ModoSeguro){'SI'}else{'NO'})
Modo Agresivo: $(if($script:ModoAgresivo){'SI'}else{'NO'})
Backup: $(if($Backup){'SI'}else{'NO'})

ESTADÍSTICAS:
-------------
Tweaks aplicados: $($script:Aplicados)
Tweaks omitidos: $($script:Omitidos)
Tiempo: $timeStr

ADVERTENCIAS:
-------------
$($script:Riesgos -join "`n")

LOG: $($script:LogFile)
$(if($Backup){"BACKUPS: $script:BackupDir"}else{""})

═════════════════════════════════════════════════════════════════
Script PRO desarrollado por yo
GitHub: https://github.com/FacuxD23/-
═════════════════════════════════════════════════════════════════
"@
        $report | Out-File -FilePath $reportPath -Encoding UTF8
        Write-OK "Reporte exportado: $reportPath"
    }
}

Write-Host ""
if ($needReboot -and -not $script:ModoSilencio) {
    Write-Host "  >> REINICIAR AHORA? (s/N): " -NoNewline -ForegroundColor Red
    $rb = Read-Host
    if ($rb -eq "s") {
        Write-Host ""
        Write-Host "  Reiniciando en 10 segundos..." -ForegroundColor Yellow
        Start-Sleep -Seconds 10
        Restart-Computer -Force
    }
}

if (-not $script:ModoSilencio) {
    Write-Host ""
    Write-Host "  Presiona ENTER para cerrar..." -ForegroundColor Gray
    Read-Host
}

# FIN DEL SCRIPT 
