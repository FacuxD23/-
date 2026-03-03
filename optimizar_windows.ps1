# ════════════════════════════════════════════════════════════════
#  OPTIMIZADOR PROFESIONAL DE WINDOWS v6.0 ULTIMATE
#  Servicios · Registro · Red · Bloatware · Tweaks Avanzados
#  Compatible: Windows 10 (1903+) / Windows 11
#  Requiere: PowerShell 5.1+ · Ejecutar como Administrador
# ════════════════════════════════════════════════════════════════
#  Autor: FacuxD23
#  GitHub: https://github.com/FacuxD23/-
#  Licencia: MIT
# ════════════════════════════════════════════════════════════════

#Requires -RunAsAdministrator

# ════════════════════════════════════════════════════════════════
#  CONFIGURACIÓN INICIAL
# ════════════════════════════════════════════════════════════════

# Modo estricto moderado (no Latest para evitar romper compatibilidad)
Set-StrictMode -Version 2.0
$ErrorActionPreference = "Continue"  # No Stop para no cortar el flujo
$ProgressPreference    = "SilentlyContinue"

# Variables script-level (mejor práctica que global)
$script:TempParaLimpiar = New-Object System.Collections.Generic.List[string]
$script:Riesgos         = New-Object System.Collections.Generic.List[string]
$script:Aplicados       = 0
$script:Omitidos        = 0
$script:LogFile         = "C:\OptimizadorWindows_v6.log"
$script:Stopwatch       = [System.Diagnostics.Stopwatch]::StartNew()

# Constantes de registro (evitar magic strings)
$script:HKLM_System    = "HKLM:\SYSTEM\CurrentControlSet"
$script:HKLM_Software  = "HKLM:\SOFTWARE"
$script:HKCU_Software  = "HKCU:\Software"
$script:HKCU_Explorer  = "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer"

# ════════════════════════════════════════════════════════════════
#  VERIFICACIONES INICIALES
# ════════════════════════════════════════════════════════════════

# Verificar PowerShell 5.1+
if ($PSVersionTable.PSVersion.Major -lt 5) {
    Write-Host ""
    Write-Host "  ════════════════════════════════════════════════════════════" -ForegroundColor Red
    Write-Host "  [✗] ERROR: PowerShell 5.1 o superior requerido" -ForegroundColor Red
    Write-Host "  Tu version: $($PSVersionTable.PSVersion)" -ForegroundColor Yellow
    Write-Host "  Descarga: https://aka.ms/powershell" -ForegroundColor Cyan
    Write-Host "  ════════════════════════════════════════════════════════════" -ForegroundColor Red
    Write-Host ""
    Read-Host "  Presiona ENTER para salir"
    exit 1
}

# Verificar que NO sea Windows Server
$osInfo = Get-CimInstance -ClassName Win32_OperatingSystem
if ($osInfo.ProductType -ne 1) {
    Write-Host ""
    Write-Host "  ════════════════════════════════════════════════════════════" -ForegroundColor Red
    Write-Host "  [✗] ERROR: Este script NO debe usarse en Windows Server" -ForegroundColor Red
    Write-Host "  ════════════════════════════════════════════════════════════" -ForegroundColor Red
    Write-Host ""
    Read-Host "  Presiona ENTER para salir"
    exit 1
}

# ════════════════════════════════════════════════════════════════
#  FUNCIONES DE LOGGING
# ════════════════════════════════════════════════════════════════

function Write-Log {
    param([string]$Message, [string]$Level = "INFO")
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $logLine = "[$timestamp] [$Level] $Message"
    Add-Content -Path $script:LogFile -Value $logLine -ErrorAction SilentlyContinue
}

# ════════════════════════════════════════════════════════════════
#  FUNCIONES DE UI MEJORADAS
# ════════════════════════════════════════════════════════════════

function Write-Banner {
    Clear-Host
    Write-Host ""
    Write-Host "  ════════════════════════════════════════════════════════════════" -ForegroundColor Cyan
    Write-Host "    ██╗    ██╗██╗███╗   ██╗ ██████╗ ██████╗ ████████╗" -ForegroundColor White
    Write-Host "    ██║    ██║██║████╗  ██║██╔═══██╗██╔══██╗╚══██╔══╝" -ForegroundColor White
    Write-Host "    ██║ █╗ ██║██║██╔██╗ ██║██║   ██║██████╔╝   ██║   " -ForegroundColor White
    Write-Host "    ██║███╗██║██║██║╚██╗██║██║   ██║██╔═══╝    ██║   " -ForegroundColor White
    Write-Host "    ╚███╔███╔╝██║██║ ╚████║╚██████╔╝██║        ██║   " -ForegroundColor White
    Write-Host "     ╚══╝╚══╝ ╚═╝╚═╝  ╚═══╝ ╚═════╝ ╚═╝        ╚═╝   " -ForegroundColor White
    Write-Host ""
    Write-Host "         OPTIMIZADOR PROFESIONAL v6.0 ULTIMATE" -ForegroundColor Cyan
    Write-Host "    Tweaks Avanzados · Kernel · Red · Gaming · Limpieza" -ForegroundColor DarkCyan
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
    $def = if ($Default -eq "s") { "(S/n)" } else { "(s/N)" }
    $r = Read-Host "  >> $Q $def"
    if ($r -eq "") { $r = $Default }
    return ($r -eq "s" -or $r -eq "S")
}

function Write-ProgressBar {
    param([int]$Current, [int]$Total, [string]$Activity)
    $percent = [math]::Round(($Current / $Total) * 100)
    $completed = [math]::Floor($percent / 5)
    $remaining = 20 - $completed
    $bar = "█" * $completed + "░" * $remaining
    Write-Host "`r  [$bar] $percent% - $Activity" -NoNewline -ForegroundColor Cyan
    if ($Current -eq $Total) { Write-Host "" }
}

# ════════════════════════════════════════════════════════════════
#  FUNCIONES DE SERVICIOS MEJORADAS
# ════════════════════════════════════════════════════════════════

function Disable-Svc {
    param([string]$Name, [string]$Desc, [string]$Riesgo = "")
    
    $svc = Get-Service -Name $Name -ErrorAction SilentlyContinue
    if ($svc) {
        if ($svc.Status -ne "Stopped") {
            Stop-Service -Name $Name -Force -ErrorAction SilentlyContinue | Out-Null
        }
        Set-Service -Name $Name -StartupType Disabled -ErrorAction SilentlyContinue
        Write-OFF "$Desc ($Name)"
        if ($Riesgo) { 
            $script:Riesgos.Add("  [!] $Desc: $Riesgo")
        }
    } else {
        Write-SKIP "Servicio no encontrado: $Name"
    }
}

function Set-Manual {
    param([string]$Name, [string]$Desc)
    
    $svc = Get-Service -Name $Name -ErrorAction SilentlyContinue
    if ($svc) {
        Set-Service -Name $Name -StartupType Manual -ErrorAction SilentlyContinue
        Write-MAN "$Desc ($Name)"
    } else {
        Write-SKIP "Servicio no encontrado: $Name"
    }
}

# ════════════════════════════════════════════════════════════════
#  FUNCIONES DE REGISTRO MEJORADAS
# ════════════════════════════════════════════════════════════════

function Set-Reg {
    param(
        [string]$Path,
        [string]$Name,
        $Value,
        [string]$Type = "DWord"
    )
    
    try {
        # Crear ruta si no existe
        if (-not (Test-Path $Path)) {
            New-Item -Path $Path -Force -ErrorAction Stop | Out-Null
        }
        
        # Verificar si ya tiene el valor correcto (evitar escrituras innecesarias)
        $current = Get-ItemProperty -Path $Path -Name $Name -ErrorAction SilentlyContinue
        
        if ($null -eq $current -or $current.$Name -ne $Value) {
            Set-ItemProperty -Path $Path -Name $Name -Value $Value -Type $Type -Force -ErrorAction Stop
            return $true
        }
        return $false
    } catch {
        Write-Log "Error en Set-Reg: $Path\$Name = $Value - $($_.Exception.Message)" "ERROR"
        return $false
    }
}

function Backup-RegistryKey {
    param([string]$Path, [string]$BackupName)
    
    $backupPath = "C:\OptimizadorBackup_$BackupName.reg"
    try {
        $regPath = $Path -replace "HKLM:\\", "HKLM\" -replace "HKCU:\\", "HKCU\"
        reg export $regPath $backupPath /y 2>&1 | Out-Null
        Write-INFO "Backup creado: $backupPath"
        return $true
    } catch {
        Write-WARN "No se pudo crear backup de $Path"
        return $false
    }
}

# ════════════════════════════════════════════════════════════════
#  DETECCIÓN DE SISTEMA MEJORADA
# ════════════════════════════════════════════════════════════════

function Get-SystemInfo {
    $reg = Get-ItemProperty "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion"
    $display = if ($reg.DisplayVersion) { $reg.DisplayVersion } else { $reg.ReleaseId }
    $build = [int]$reg.CurrentBuildNumber
    $ubr = $reg.UBR
    
    # Detectar Windows 10 vs 11
    $isWin11 = $build -ge 22000
    $winVer = if ($isWin11) { "Windows 11" } else { "Windows 10" }
    
    # CPU
    $cpuObj = Get-CimInstance Win32_Processor -EA SilentlyContinue | Select-Object -First 1
    $cpu = if ($cpuObj) { $cpuObj.Name.Trim() } else { "No detectado" }
    $cpuCores = if ($cpuObj) { $cpuObj.NumberOfCores } else { 0 }
    $cpuThreads = if ($cpuObj) { $cpuObj.NumberOfLogicalProcessors } else { 0 }
    
    # RAM
    $ramBytes = (Get-CimInstance Win32_ComputerSystem -EA SilentlyContinue).TotalPhysicalMemory
    $ramGB = if ($ramBytes) { [math]::Round($ramBytes/1GB, 1) } else { 0 }
    
    # Disco C: tipo y espacio
    $diskType = "Desconocido"
    $isHDD = $false
    $isSSD = $false
    $isNVMe = $false
    
    try {
        $diskNum = (Get-Partition -DriveLetter C -EA SilentlyContinue).DiskNumber
        if ($null -ne $diskNum) {
            $physDisk = Get-PhysicalDisk -EA SilentlyContinue | Where-Object { $_.DeviceId -eq $diskNum }
            if ($physDisk) {
                $mt = $physDisk.MediaType
                $busType = $physDisk.BusType
                
                if ($mt -match "SSD") {
                    $isSSD = $true
                    if ($busType -eq "NVMe") {
                        $diskType = "SSD NVMe"
                        $isNVMe = $true
                    } else {
                        $diskType = "SSD SATA"
                    }
                } elseif ($mt -match "HDD") {
                    $diskType = "HDD (mecanico)"
                    $isHDD = $true
                } else {
                    $diskType = if ($mt) { $mt } else { "No especificado" }
                }
            }
        }
    } catch {}
    
    # GPU
    $gpu = (Get-CimInstance Win32_VideoController -EA SilentlyContinue |
            Where-Object { $_.Name -notmatch "Microsoft Basic|Remote" } |
            Select-Object -First 1).Name
    if (-not $gpu) { $gpu = "No detectado" }
    
    # Uptime
    $uptime = (Get-Date) - (Get-CimInstance Win32_OperatingSystem).LastBootUpTime
    $uptimeStr = "{0}d {1}h {2}m" -f [int]$uptime.TotalDays, $uptime.Hours, $uptime.Minutes
    
    # Espacio libre
    $drive = Get-PSDrive C -EA SilentlyContinue
    $freeGB = if ($drive) { [math]::Round($drive.Free / 1GB, 1) } else { 0 }
    $usedGB = if ($drive) { [math]::Round($drive.Used / 1GB, 1) } else { 0 }
    
    return [PSCustomObject]@{
        WinName    = "$($reg.ProductName) $display"
        WinVer     = $winVer
        Build      = $build
        UBR        = $ubr
        BuildStr   = "$build.$ubr"
        IsWin11    = $isWin11
        IsWin10    = -not $isWin11
        CPU        = $cpu
        CPUCores   = $cpuCores
        CPUThreads = $cpuThreads
        RAM        = $ramGB
        RAMStr     = "$ramGB GB"
        Disk       = $diskType
        IsHDD      = $isHDD
        IsSSD      = $isSSD
        IsNVMe     = $isNVMe
        GPU        = $gpu
        Uptime     = $uptimeStr
        FreeGB     = $freeGB
        UsedGB     = $usedGB
    }
}

# ════════════════════════════════════════════════════════════════
#  BANNER Y DETECCIÓN
# ════════════════════════════════════════════════════════════════

Write-Banner
Write-INFO "Iniciando Optimizador Windows v6.0 Ultimate..."
Write-INFO "Detectando sistema y hardware..."
Write-Host ""

$sys = Get-SystemInfo

# Panel de sistema mejorado
Write-Host "  ╔══════════════════════════════════════════════════════════════╗" -ForegroundColor DarkCyan
Write-Host "  ║  SISTEMA DETECTADO                                           ║" -ForegroundColor DarkCyan
Write-Host "  ╠══════════════════════════════════════════════════════════════╣" -ForegroundColor DarkCyan
Write-Host "  ║  OS:    $($sys.WinName.PadRight(50)) ║" -ForegroundColor White
Write-Host "  ║  Build: $($sys.BuildStr.PadRight(50)) ║" -ForegroundColor White
Write-Host "  ║  CPU:   $($sys.CPU.PadRight(50)) ║" -ForegroundColor White
Write-Host "  ║         $("$($sys.CPUCores) cores / $($sys.CPUThreads) threads".PadRight(50)) ║" -ForegroundColor Gray
Write-Host "  ║  RAM:   $($sys.RAMStr.PadRight(50)) ║" -ForegroundColor White
Write-Host "  ║  Disco: $($sys.Disk.PadRight(50)) ║" -ForegroundColor $(if ($sys.IsHDD) { "Yellow" } else { "White" })
Write-Host "  ║         $("Libre: $($sys.FreeGB) GB  |  Usado: $($sys.UsedGB) GB".PadRight(50)) ║" -ForegroundColor Gray
Write-Host "  ║  GPU:   $($sys.GPU.PadRight(50)) ║" -ForegroundColor White
Write-Host "  ║  Uptime: $($sys.Uptime.PadRight(49)) ║" -ForegroundColor Gray
Write-Host "  ╚══════════════════════════════════════════════════════════════╝" -ForegroundColor DarkCyan
Write-Host ""

# Avisos importantes
if ($sys.Build -lt 19041) {
    Write-WARN "Build muy antiguo ($($sys.Build)). Actualizar Windows es recomendable."
    $script:Riesgos.Add("  [!] Build antiguo: algunos tweaks pueden no aplicar")
}

if ($sys.IsHDD) {
    Write-WARN "HDD detectado: algunos tweaks SSD se omitiran automaticamente"
}

if ($sys.RAM -lt 8) {
    Write-WARN "RAM baja ($($sys.RAM)GB): tweaks de memoria se ajustaran"
}

Write-Host ""
Start-Sleep -Seconds 2

# Continúa en próximo bloque...

# ════════════════════════════════════════════════════════════════
#  PUNTO DE RESTAURACIÓN
# ════════════════════════════════════════════════════════════════

Write-Header "0" "PUNTO DE RESTAURACION DEL SISTEMA" "Yellow"
Write-Host ""
Write-Host "  Se recomienda crear un punto de restauracion antes de continuar." -ForegroundColor Yellow
Write-Host "  Esto permite revertir cambios si algo sale mal." -ForegroundColor Gray
Write-Host ""

if (Ask-YN "Crear punto de restauracion?" "s") {
    try {
        Write-INFO "Creando punto de restauracion..."
        $restoreDesc = "Optimizador Windows v6.0 - $(Get-Date -Format 'yyyy-MM-dd HH:mm')"
        Checkpoint-Computer -Description $restoreDesc -RestorePointType "MODIFY_SETTINGS" -ErrorAction Stop
        Write-OK "Punto de restauracion creado correctamente"
    } catch {
        Write-WARN "No se pudo crear punto de restauracion: $($_.Exception.Message)"
        Write-INFO "Continuando sin punto de restauracion..."
    }
} else {
    Write-SKIP "Punto de restauracion omitido"
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
        
        # Menu contextual clasico
        Set-Reg "HKCU:\Software\Classes\CLSID\{86ca1aa0-34aa-4e8b-a509-50c905bae2a2}\InprocServer32" "(Default)" "" "String"
        Write-OK "Menu contextual clasico restaurado"
        
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
    
    if ($sys.IsWin11) { 
        netsh int tcp set global congestionprovider=default | Out-Null
    } else {
        netsh int tcp set global congestionprovider=ctcp    | Out-Null
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
        Set-NetAdapterPowerManagement -Name $_.Name -AllowComputerToTurnOffDevice $false -EA SilentlyContinue
    }
    Write-OK "Gestion de energia de adaptadores desactivada"

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
            Set-NetAdapterAdvancedProperty -Name $adapter.Name -DisplayName "Energy Efficient Ethernet" -DisplayValue "Disabled" -EA SilentlyContinue
            Set-NetAdapterAdvancedProperty -Name $adapter.Name -DisplayName "Green Ethernet" -DisplayValue "Disabled" -EA SilentlyContinue
            Set-NetAdapterAdvancedProperty -Name $adapter.Name -DisplayName "Interrupt Moderation" -DisplayValue "Disabled" -EA SilentlyContinue
            Enable-NetAdapterRss -Name $adapter.Name -EA SilentlyContinue
            
            # RSS tuning basado en cores
            if ($sys.CPUCores -ge 4) {
                $maxProc = [math]::Min($sys.CPUCores - 1, 4)
                Set-NetAdapterRss -Name $adapter.Name -MaxProcessors $maxProc -EA SilentlyContinue
                Write-OK "Ethernet: EEE off, RSS on ($maxProc cores), Interrupt Mod off"
            } else {
                Write-OK "Ethernet: EEE off, RSS on, Interrupt Mod off"
            }
            
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
            $count = (Get-ChildItem -Path $f -Recurse -Force -EA SilentlyContinue).Count
            Get-ChildItem -Path $f -Recurse -Force -EA SilentlyContinue | 
                Remove-Item -Recurse -Force -EA SilentlyContinue
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
    
    # WSH
    Set-Reg "$script:HKLM_Software\Microsoft\Windows Script Host\Settings" "Enabled" 0
    Write-OK "Windows Script Host deshabilitado"
    $script:Riesgos.Add("  [!] WSH off: scripts .vbs/.js no ejecutaran")
    
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
            
            $extractedFolder = "$tempDir\microsoft-store-download-main\LTSC-Add-MicrosoftStore-master"
            if (Test-Path "$extractedFolder\Add-Store.cmd") {
                Write-OK "Archivos extraidos"
                $script:TempParaLimpiar.Add($zipPath)
                $script:TempParaLimpiar.Add("$tempDir\microsoft-store-download-main")
                
                Write-INFO "Ejecutando instalador..."
                Start-Process -FilePath "$extractedFolder\Add-Store.cmd" -WorkingDirectory $extractedFolder -Wait
                Write-OK "Microsoft Store instalada"
            } else {
                Write-ERR "Add-Store.cmd no encontrado"
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
    if (Get-Command winget -EA SilentlyContinue) {
        Write-INFO "Instalando Rytunex via winget..."
        winget install --id Rayen.RyTuneX --accept-package-agreements --accept-source-agreements --silent
        if ($LASTEXITCODE -eq 0) {
            Write-OK "Rytunex instalado"
            if (Ask-YN "Abrir Rytunex?" "s") {
                Start-Sleep -Seconds 2
                $rytunexPaths = @(
                    "$env:LOCALAPPDATA\Programs\RyTuneX\RyTuneX.exe",
                    "$env:ProgramFiles\RyTuneX\RyTuneX.exe"
                )
                foreach ($path in $rytunexPaths) {
                    if (Test-Path $path) {
                        Start-Process $path
                        Write-OK "Rytunex ejecutado"
                        break
                    }
                }
            }
        }
    } else {
        Write-WARN "Winget no disponible"
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
    if (Get-Command winget -EA SilentlyContinue) {
        Write-INFO "Instalando Wintoys..."
        winget install --id 9P8LTPGCBZXD --accept-package-agreements --accept-source-agreements --silent
        if ($LASTEXITCODE -eq 0) {
            Write-OK "Wintoys instalado"
            if (Ask-YN "Abrir Wintoys?" "s") {
                Start-Sleep -Seconds 2
                $wintoys = Get-AppxPackage | Where-Object { $_.Name -like "*Wintoys*" }
                if ($wintoys) {
                    Start-Process "shell:AppsFolder\$($wintoys.PackageFamilyName)!App"
                    Write-OK "Wintoys ejecutado"
                }
            }
        }
    } else {
        Write-WARN "Winget no disponible"
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
