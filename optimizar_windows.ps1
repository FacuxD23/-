# ================================================================
# OPTIMIZADOR PROFESIONAL DE WINDOWS v5.0 ULTRA
#  Servicios * Registro * Red * Bloatware * Visual * Limpieza
#  Compatible: Windows 10 / 11 - Home y Pro
#  Requiere: Ejecutar como Administrador
# ================================================================

Set-StrictMode -Off
$ErrorActionPreference = "SilentlyContinue"
$ProgressPreference    = "SilentlyContinue"

# ================================================================
# FUNCIONES DE UI
function Write-Header { param([string]$Letter, [string]$Title)
    Write-Host ""
    Write-Host " ================================================================"
    Write-Host " [$Letter] $Title"
    Write-Host " ================================================================"
}
function Write-OK   { param([string]$M); Write-Host " [OK]  $M"; }
function Write-WARN { param([string]$M); Write-Host " [!]   $M"; }

function Ask-YN { param([string]$Q, [string]$Default = "n")
    $def = if ($Default -eq "s") { "(S/n)" } else { "(s/N)" }
    $r = Read-Host " >> $Q $def"
    if ($r -eq "") { $r = $Default }
    return ($r -eq "s" -or $r -eq "S")
}

# ================================================================
# DETECCION DE SISTEMA
function Get-SystemInfo {
    $reg     = Get-ItemProperty "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion"
    $display = if ($reg.DisplayVersion) { $reg.DisplayVersion } else { $reg.ReleaseId }
    $build   = [int]$reg.CurrentBuildNumber

    $cpu = (Get-CimInstance Win32_Processor -EA SilentlyContinue | Select-Object -First 1).Name
    if (-not $cpu) { $cpu = "No detectado" }

    $ramBytes = (Get-CimInstance Win32_ComputerSystem -EA SilentlyContinue).TotalPhysicalMemory
    $ramGB    = if ($ramBytes) { [math]::Round($ramBytes/1GB, 1) } else { "?" }

    $diskType = "Desconocido"; $isHDD = $false
    try {
        $diskNum = (Get-Partition -DriveLetter C -EA SilentlyContinue).DiskNumber
        if ($null -ne $diskNum) {
            $mt = (Get-PhysicalDisk -EA SilentlyContinue | Where-Object { $_.DeviceId -eq $diskNum }).MediaType
            if ($mt -match "SSD") { $diskType = "SSD"; $isHDD = $false }
            elseif ($mt -match "HDD") { $diskType = "HDD (disco mecanico)"; $isHDD = $true }
            else { $diskType = if ($mt) { $mt } else { "No especificado" } }
        }
    } catch {}

    $gpu = (Get-CimInstance Win32_VideoController -EA SilentlyContinue |
            Where-Object { $_.Name -notmatch "Microsoft Basic|Remote" } |
            Select-Object -First 1).Name
    if (-not $gpu) { $gpu = "No detectado" }

    return [PSCustomObject]@{
        WinName   = "$($reg.ProductName) $display"
        Build     = $build
        CPU       = $cpu.Trim()
        RAM       = "$ramGB GB"
        Disk      = $diskType
        IsHDD     = $isHDD
        GPU       = $gpu.Trim()
    }
}

# ================================================================
# BANNER Y DETECCION
Clear-Host
Write-Host " ================================================================"
Write-Host " OPTIMIZADOR PROFESIONAL DE WINDOWS v5.0 ULTRA EDITION"
Write-Host " ================================================================"
$sys = Get-SystemInfo
Write-Host " Sistema detectado:"
Write-Host "  - RAM: $($sys.RAM)"
Write-Host " ================================================================"

# ================================================================
# MENÚ PRINCIPAL
function Main-Menu {
    Write-Header "M" "MENU PRINCIPAL"
    Write-Host " [1] OPTIMIZACION COMPLETA - Todo en uno (Recomendado)"
    # Opción Chris Titus eliminada
    Write-Host " [2] INFORMACION SISTEMA - Ver detalles completos"
    Write-Host " [0] SALIR - Cerrar programa"

    $op = Read-Host " >> Selecciona una opcion (0-2)"
    switch ($op) {
        1 { Write-OK "Ejecutando optimización completa..." }
        2 { 
            Write-Host ""
            Write-Host " Detalles del sistema:"
            Write-Host "  SO: $($sys.WinName)"
            Write-Host "  CPU: $($sys.CPU)"
            Write-Host "  RAM: $($sys.RAM)"
            Write-Host "  Disco: $($sys.Disk)"
            Write-Host "  GPU: $($sys.GPU)"
        }
        0 { exit }
        default { Write-WARN "Opción inválida" }
    }
}

# ================================================================
# EJECUTAR MENÚ PRINCIPAL
Main-Menu


# ================================================================
#  PASO 1: GAMA
# ================================================================
Write-Header "1" "GAMA DE LA PC"
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

# ================================================================
#  PASO 2: USO
# ================================================================
Write-Header "2" "USO PRINCIPAL DE LA PC"
Write-Host ""
Write-Host "   [1] OFICINA    - Word, Excel, navegador, correo" -ForegroundColor Cyan
Write-Host "   [2] GAMING     - Juegos, alto rendimiento" -ForegroundColor Magenta
Write-Host "   [3] STREAMING  - OBS, grabacion, edicion de video" -ForegroundColor Blue
Write-Host "   [4] MIXTO      - Varios usos" -ForegroundColor White
Write-Host ""
do { $ui = Read-Host "  Selecciona 1, 2, 3 o 4" } while ($ui -notmatch "^[1234]$")
$uso    = [int]$ui
$usoStr = @{1="OFICINA"; 2="GAMING"; 3="STREAMING"; 4="MIXTO"}[$uso]

Write-Host ""
Write-Host "  Perfil: Gama $gamaStr | Uso $usoStr" -ForegroundColor White
Write-Host "  Iniciando optimizacion..." -ForegroundColor Green
Start-Sleep -Seconds 1

# ================================================================
#  A. SERVICIOS BASE
# ================================================================
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

Write-Header "A" "SERVICIOS - XBOX LIVE"
Disable-Svc "XblAuthManager"      "Autenticacion Xbox Live"
Disable-Svc "XblGameSave"         "Guardado Xbox Live"
Disable-Svc "XboxGipSvc"          "Xbox Accessory Management"
Disable-Svc "XboxNetApiSvc"       "Red Xbox Live"

Write-Header "A" "SERVICIOS - ACCESO REMOTO"
Disable-Svc "RemoteRegistry"      "Registro remoto" "Reactivar si necesitas acceso remoto al registro"
Disable-Svc "RemoteAccess"        "Enrutamiento y acceso remoto"
Disable-Svc "RasAuto"             "Conexiones automaticas RAS"
Disable-Svc "RasMan"              "Administrador conexiones RAS"
Disable-Svc "SstpSvc"             "Protocolo tunel SSTP"
Disable-Svc "seclogon"            "Inicio sesion secundario" "Algunos instaladores lo requieren"
Disable-Svc "SessionEnv"          "Configuracion Escritorio remoto"
Disable-Svc "UmRdpService"        "Redirector puerto RDP"

Write-Header "A" "SERVICIOS - ACTUALIZADORES DE NAVEGADORES"
Disable-Svc "edgeupdate"                    "Microsoft Edge Update"
Disable-Svc "edgeupdatem"                   "Microsoft Edge Update (m)"
Disable-Svc "MicrosoftEdgeElevationService" "Edge Elevation Service"
Disable-Svc "GoogleUpdaterInternalService"  "Google Updater interno"
Disable-Svc "GoogleUpdaterService"          "Google Updater"
Disable-Svc "GoogleChromeElevationService"  "Chrome Elevation Service"
Disable-Svc "brave"                         "Brave Update"
Disable-Svc "bravem"                        "Brave Update (m)"
Disable-Svc "BraveElevationService"         "Brave Elevation Service"

Write-Header "A" "SERVICIOS - MISCELANEOS"
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
Disable-Svc "UevAgentService"     "Virtualizacion experiencia usuario"
Disable-Svc "wcncsvc"             "Registrador config Wi-Fi (WCN)"
Disable-Svc "AppVClient"          "Microsoft App-V Client"
Disable-Svc "NetTcpPortSharing"   "Uso compartido puertos Net.Tcp"
Disable-Svc "NcdAutoSetup"        "Config automatica dispositivos red"
Disable-Svc "QWAVE"               "Calidad audio/video QWAVE"
Disable-Svc "CscService"          "Archivos sin conexion"
Disable-Svc "CertPropSvc"         "Propagacion de certificados"
Disable-Svc "ScDeviceEnum"        "Enumeracion tarjetas inteligentes"
Disable-Svc "TapiSrv"             "Telefonia TAPI"
Disable-Svc "icssvc"              "Zona activa inalambrica movil"
Disable-Svc "workfolderssvc"      "Carpetas de trabajo"
Disable-Svc "WManSvc"             "Administracion de Windows"
Disable-Svc "StiSvc"              "Adquisicion de imagenes Windows"
Disable-Svc "dot3svc"             "Config 802.1X cableado automatico"
Disable-Svc "WFDSConMgrSvc"       "Administrador Wi-Fi Direct"
Disable-Svc "lltdsvc"             "Asignador topologia de red"
Disable-Svc "SharedAccess"        "Conexion compartida ICS"
Disable-Svc "SNMPTrap"            "Captura SNMP"
Disable-Svc "KtmRm"               "KTMRM para DTC"
Disable-Svc "ssh-agent"           "OpenSSH Authentication Agent"
Disable-Svc "PeerDistSvc"         "BranchCache"
Disable-Svc "WMPNetworkSvc"       "Uso compartido red WMP"
Disable-Svc "EFS"                 "Cifrado de archivos EFS"
Disable-Svc "wlpasvc"             "Asistente perfil local"
Disable-Svc "EpicGamesUpdater"    "Epic Games Updater"
Disable-Svc "EpicOnlineServices"  "Epic Online Services"
Disable-Svc "DisplayEnhancementService" "Mejora de visualizacion"
Disable-Svc "WwanSvc"             "Configuracion automatica WWAN"
Disable-SvcReg "CDPUserSvc"       "Connected Devices Platform User"
Disable-SvcReg "OneSyncSvc"       "Sincronizar host"

Write-Sub "Servicios en Manual"
Set-Manual "wuauserv"             "Windows Update"
Set-Manual "BITS"                 "Transferencia inteligente"
Set-Manual "DoSvc"                "Optimizacion de distribucion"
Set-Manual "WaaSMedicSvc"         "WaaS Medic"
Set-Manual "sppsvc"               "Proteccion de software"
Set-Manual "NlaSvc"               "Reconocimiento ubicacion de red"
Set-Manual "AppXSvc"              "Implementacion AppX"
Set-Manual "ClipSVC"              "Licencia de cliente"
Set-Manual "TroubleshootingSvc"   "Solucion de problemas recomendada"
Set-Manual "PolicyAgent"          "Agente directiva IPsec"
Set-Manual "smphost"              "SMP Espacios de almacenamiento"
Set-Manual "CDPSvc"               "Connected Devices Platform"
Set-Manual "DusmSvc"              "Uso de datos"
Set-Manual "CldFlt"               "Filtro nube (OneDrive)"
Set-Manual "InstallService"       "Servicio instalacion Microsoft Store"
Set-Manual "LicenseManager"       "Administrador de licencias"

# ================================================================
#  BLOQUE GAMA
# ================================================================
Write-Header "A" "SERVICIOS - PERFIL GAMA $gamaStr"

if ($gama -eq 3) {
    if ($sys.IsHDD) {
        Set-Manual "SysMain"      "SysMain/Superfetch (Manual - util en HDD)"
    } else {
        Disable-Svc "SysMain"     "SysMain/Superfetch" "Innecesario en SSD"
    }
    Disable-Svc "WSearch"         "Busqueda de Windows" "Instalar 'Everything' como reemplazo"
    Disable-Svc "defragsvc"       "Desfragmentador programado"
    Disable-Svc "TabletInputService" "Panel teclado tactil"
    Disable-Svc "WbioSrvc"        "Biometrico Windows" "Reactivar si usa huella digital"
    Disable-Svc "NgcSvc"          "Microsoft Passport" "Verificar PIN tras reinicio"
    Disable-Svc "NgcCtnrSvc"      "Contenedor Microsoft Passport"
    Disable-Svc "NaturalAuthentication" "Autenticacion natural"
    $global:Riesgos += "  [!] Gama Baja: WSearch off - usar Everything como buscador"
    $global:Riesgos += "  [!] Gama Baja: NgcSvc off - verificar PIN de Windows al reiniciar"
} elseif ($gama -eq 2) {
    if ($sys.IsHDD) {
        Set-Manual "SysMain"      "SysMain (Manual - util en HDD)"
    } else {
        Set-Manual "SysMain"      "SysMain (Manual - SSD no lo necesita activo)"
    }
    Set-Manual "WSearch"          "Busqueda de Windows"
    Disable-Svc "defragsvc"       "Desfragmentador programado"
    Disable-Svc "TabletInputService" "Panel teclado tactil"
    Disable-Svc "WbioSrvc"        "Biometrico Windows" "Reactivar si usa huella digital"
} else {
    Set-Manual "SysMain"          "SysMain (Manual)"
    Set-Manual "WSearch"          "Busqueda de Windows (Manual)"
    Disable-Svc "defragsvc"       "Desfragmentador programado"
    Disable-Svc "TabletInputService" "Panel teclado tactil"
}

# ================================================================
#  BLOQUE USO
# ================================================================
Write-Header "A" "SERVICIOS - PERFIL $usoStr"

if ($uso -eq 2) {
    Disable-Svc "NgcSvc"          "Microsoft Passport" "Verificar PIN tras reinicio"
    Disable-Svc "NgcCtnrSvc"      "Contenedor Passport"
    Set-Reg "HKCU:\Software\Microsoft\GameBar" "AllowAutoGameMode" 1
    Set-Reg "HKCU:\Software\Microsoft\GameBar" "AutoGameModeEnabled" 1
    Set-Reg "HKCU:\Software\Microsoft\Windows\CurrentVersion\GameDVR" "AppCaptureEnabled" 0
    Set-Reg "HKLM:\SOFTWARE\Policies\Microsoft\Windows\GameDVR" "AllowGameDVR" 0
    Write-OK "Modo Juego activado + Xbox Game Bar desactivada"
    $global:Riesgos += "  [!] Gaming: NgcSvc off - verificar PIN de Windows"
} elseif ($uso -eq 1) {
    Disable-Svc "EasyAntiCheat_EOS" "Easy Anti-Cheat (EOS)" "Afecta juegos que lo requieran"
    Disable-Svc "NgcSvc"            "Microsoft Passport" "Verificar PIN tras reinicio"
    Disable-Svc "NgcCtnrSvc"        "Contenedor Passport"
    Disable-Svc "WbioSrvc"          "Biometrico Windows" "Reactivar si usa huella digital"
    Set-Manual "WSearch"            "Busqueda de Windows"
    $global:Riesgos += "  [!] Oficina: NgcSvc off - verificar PIN de Windows"
} elseif ($uso -eq 3) {
    Disable-Svc "NgcSvc"            "Microsoft Passport"
    Disable-Svc "NgcCtnrSvc"        "Contenedor Passport"
    Set-Manual "WSearch"            "Busqueda de Windows"
    Write-INFO "Servicios de audio y GPU conservados para OBS/streaming"
} else {
    Set-Manual "NgcSvc"             "Microsoft Passport"
    Set-Manual "WSearch"            "Busqueda de Windows"
    Set-Manual "SysMain"            "SysMain"
}

# ================================================================
#  B. BLUETOOTH
# ================================================================
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

# ================================================================
#  C. IMPRESORAS
# ================================================================
Write-Header "C" "IMPRESORAS"
if (Ask-YN "El cliente USA impresora?" "s") {
    Write-SKIP "Servicios de impresion conservados"
} else {
    Disable-Svc "Spooler"             "Cola de impresion (Spooler)"
    Disable-Svc "PrintNotify"         "Notificaciones de impresora"
    Disable-Svc "PrintDeviceConfig"   "Config dispositivo impresion"
    Disable-Svc "PrintScanBroker"     "Print/Scan Broker"
}

# ================================================================
#  D. HYPER-V
# ================================================================
Write-Header "D" "HYPER-V / MAQUINAS VIRTUALES"
if (Ask-YN "El cliente usa maquinas virtuales?" "n") {
    Write-SKIP "Hyper-V conservado"
} else {
    "vmicguestinterface","vmicheartbeat","vmickvpexchange","vmicrdv",
    "vmicshutdown","vmictimesync","vmicvmsession","vmicvss","HvHost" | ForEach-Object {
        Disable-Svc $_ "Hyper-V: $_"
    }
}

# ================================================================
#  E. WI-FI
# ================================================================
Write-Header "E" "WI-FI"
if (Ask-YN "El cliente usa Wi-Fi?" "s") {
    Write-SKIP "Wi-Fi conservado"
} else {
    Disable-Svc "WlanSvc" "Configuracion automatica WLAN" "La PC no podra usar Wi-Fi"
    $global:Riesgos += "  [!] WlanSvc off: solo funciona Ethernet"
}

# ================================================================
#  F. ONEDRIVE
# ================================================================
Write-Header "F" "ONEDRIVE"
if (Ask-YN "El cliente usa OneDrive?" "n") {
    Write-SKIP "OneDrive conservado"
} else {
    reg delete "HKCU\Software\Microsoft\Windows\CurrentVersion\Run" /v "OneDrive" /f 2>$null
    schtasks /Delete /TN "\Microsoft\Windows\OneDrive\OneDrive Standalone Update Task v2" /F 2>$null
    Write-OK "OneDrive removido del autoarranque y tareas programadas"
}

# ================================================================
#  G. PLAN DE ENERGIA
# ================================================================
Write-Header "G" "PLAN DE ENERGIA"
Write-Host ""
Write-Host "   [1] Alto rendimiento   - recomendado para PC de escritorio" -ForegroundColor Green
Write-Host "   [2] Ultimate Perf.     - maximo posible (no recomendado en laptops)" -ForegroundColor Magenta
Write-Host "   [3] Equilibrado        - dejar como esta" -ForegroundColor Yellow
Write-Host "   [4] Ahorro de energia  - laptops viejas / bajo consumo" -ForegroundColor Cyan
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
                Write-OK "Plan: Alto rendimiento activado (Ultimate no disponible)"
            }
        } else {
            powercfg /setactive 8c5e7fda-e8bf-4a96-9a85-a6e23a8c635c 2>$null
            Write-OK "Plan: Alto rendimiento activado (Ultimate no disponible)"
        }
        $global:Riesgos += "  [!] Ultimate Performance: mayor consumo electrico, no usar en laptops"
    }
    "3" { Write-SKIP "Plan de energia sin cambios" }
    "4" {
        powercfg /setactive a1841308-3541-4fab-bc81-f71556f20b4a 2>$null
        Write-OK "Plan: Ahorro de energia activado"
    }
}

# ================================================================
#  H. MICROSOFT STORE
# ================================================================
Write-Header "H" "MICROSOFT STORE"
if (Ask-YN "Instalar Microsoft Store? (util en Windows LTSC/sin Store)" "n") {
    Write-INFO "Descargando repositorio de instalacion..."
    $storeZip  = "$env:TEMP\MicrosoftStore.zip"
    $storeDest = "$env:TEMP\LTSC-Store"
    $repoUrl   = "https://github.com/FacuxD23/microsoft-store-download/archive/refs/heads/main.zip"
    try {
        (New-Object System.Net.WebClient).DownloadFile($repoUrl, $storeZip)
        if (Test-Path $storeZip) {
            Write-OK "Descarga completada"
            Write-INFO "Extrayendo archivos..."
            if (Test-Path $storeDest) { Remove-Item $storeDest -Recurse -Force }
            Expand-Archive -Path $storeZip -DestinationPath $storeDest -Force
            Remove-Item $storeZip -Force -EA SilentlyContinue
            $addStore = "$storeDest\microsoft-store-download-main\LTSC-Add-MicrosoftStore-master\Add-Store.cmd"
            if (Test-Path $addStore) {
                Write-INFO "Ejecutando Add-Store.cmd..."
                Start-Process -FilePath "cmd.exe" -ArgumentList "/c `"$addStore`"" -Verb RunAs -Wait
                Write-OK "Microsoft Store instalada"
                # Marcar para limpieza automatica al reinicio
                $global:TempParaLimpiar += $storeDest
                Write-INFO "Archivos temporales de Store se eliminaran al reiniciar"
            } else {
                Write-ERR "No se encontro Add-Store.cmd en el repositorio"
                $global:TempParaLimpiar += $storeDest
            }
        } else {
            Write-ERR "No se pudo descargar el repositorio (verifica la conexion)"
        }
    } catch {
        Write-ERR "Error al instalar Store: $($_.Exception.Message)"
        if (Test-Path $storeDest) { $global:TempParaLimpiar += $storeDest }
    }
} else {
    Write-SKIP "Instalacion de Microsoft Store omitida"
}

# ================================================================
#  I. TWEAKS DE REGISTRO
# ================================================================
Write-Header "I" "TWEAKS DE REGISTRO - PRIVACIDAD Y RENDIMIENTO"
if (Ask-YN "Aplicar tweaks de privacidad y rendimiento en registro?" "s") {

    Write-Sub "Privacidad"
    Set-Reg "HKCU:\Software\Microsoft\Windows\CurrentVersion\AdvertisingInfo" "Enabled" 0
    $cdm = "HKCU:\Software\Microsoft\Windows\CurrentVersion\ContentDeliveryManager"
    "SubscribedContent-338388Enabled","SubscribedContent-338389Enabled",
    "SubscribedContent-353698Enabled","SystemPaneSuggestionsEnabled",
    "SoftLandingEnabled","OemPreInstalledAppsEnabled",
    "PreInstalledAppsEnabled","SilentInstalledAppsEnabled" | ForEach-Object {
        Set-Reg $cdm $_ 0
    }
    Set-Reg "HKLM:\SOFTWARE\Policies\Microsoft\Windows\DataCollection"               "AllowTelemetry" 0
    Set-Reg "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\DataCollection" "AllowTelemetry" 0
    Write-OK "Publicidad personalizada y telemetria desactivadas"

    Write-Sub "Rendimiento de memoria y CPU"
    powercfg /h off 2>$null
    $ramGBRound = [math]::Round((Get-CimInstance Win32_ComputerSystem).TotalPhysicalMemory/1GB, 0)
    Write-OK "Hibernacion desactivada (libera ~$ramGBRound GB en disco)"
    Set-Reg "HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager\Memory Management\PrefetchParameters" "EnableSuperfetch" 0
    Set-Reg "HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager\Memory Management\PrefetchParameters" "EnablePrefetcher"  0
    Set-Reg "HKLM:\SYSTEM\CurrentControlSet\Control\PriorityControl" "Win32PrioritySeparation" 38
    Set-Reg "HKLM:\SYSTEM\CurrentControlSet\Control\CrashControl"    "CrashDumpEnabled" 0
    Set-Reg "HKLM:\SYSTEM\CurrentControlSet\Control\CrashControl"    "AutoReboot"       1
    Write-OK "Prioridad CPU primer plano optimizada, crash dumps reducidos"

    Write-Sub "Explorador de archivos"
    Set-Reg "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced" "HideFileExt"     0
    Set-Reg "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced" "Hidden"          1
    Set-Reg "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced" "EnableBalloonTips" 0
    Set-Reg "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced" "LaunchTo"        1
    Set-Reg "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced" "ShowSyncProviderNotifications" 0
    Write-OK "Extensiones visibles, archivos ocultos, Este equipo como inicio del Explorer"

    Write-Sub "Busqueda web / Bing / Cortana"
    Set-Reg "HKCU:\Software\Microsoft\Windows\CurrentVersion\Search" "BingSearchEnabled" 0
    Set-Reg "HKCU:\Software\Microsoft\Windows\CurrentVersion\Search" "CortanaConsent"    0
    Set-Reg "HKLM:\SOFTWARE\Policies\Microsoft\Windows\Windows Search" "DisableWebSearch"      1
    Set-Reg "HKLM:\SOFTWARE\Policies\Microsoft\Windows\Windows Search" "ConnectedSearchUseWeb" 0
    Write-OK "Bing y Cortana desactivados en barra de busqueda"

    if ($sys.IsWin11) {
        Write-Sub "Windows 11 - Tweaks especificos"
        Set-Reg "HKCU:\Software\Classes\CLSID\{86ca1aa0-34aa-4e8b-a509-50c905bae2a2}\InprocServer32" "(Default)" "" "String"
        Write-OK "Menu contextual clasico restaurado (reiniciar Explorer para aplicar)"
        $global:Riesgos += "  [!] Win11: menu contextual cambiado al clasico"

        if (Ask-YN "Mover iconos de barra de tareas a la izquierda (estilo Win10)?" "n") {
            Set-Reg "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced" "TaskbarAl" 0
            Write-OK "Barra de tareas alineada a la izquierda"
        }

        Set-Reg "HKLM:\SOFTWARE\Policies\Microsoft\Dsh" "AllowNewsAndInterests" 0
        Write-OK "Widgets de Windows 11 desactivados"
    }

    if ($uso -ne 2) {
        powercfg /change monitor-timeout-ac 10 2>$null
        powercfg /change monitor-timeout-dc 5  2>$null
        Write-OK "Pantalla: apagado a 10min (enchufado) / 5min (bateria)"
    }
}

# ================================================================
# ================================================================
#  I. OPTIMIZACION DE RED COMPLETA
# ================================================================
function OPT_InternetPro {
    Write-Host ""
    Write-Host "  --- Verificando conectividad ---" -ForegroundColor DarkCyan
    try {
        $tieneInternet = Test-Connection -ComputerName 8.8.8.8 -Count 1 -Quiet -ErrorAction Stop
    } catch { $tieneInternet = $false }

    if (-not $tieneInternet) {
        Write-WARN "Sin internet. Se aplican solo tweaks locales."
    } else {
        Write-OK "Internet detectado"
    }

    if ($tieneInternet) {
        $bp = Test-Connection "8.8.8.8" -Count 4 -EA SilentlyContinue
        $avgBefore = [math]::Round(($bp | Measure-Object ResponseTime -Average).Average, 2)
        Write-INFO "Ping ANTES: $avgBefore ms"
    }

    Write-Sub "TCP/IP tweaks"
    netsh int tcp set global autotuninglevel=normal | Out-Null
    netsh int tcp set global rss=enabled            | Out-Null
    netsh int tcp set global chimney=enabled        | Out-Null
    netsh int tcp set global dca=enabled            | Out-Null
    netsh int tcp set global netdma=enabled         | Out-Null
    netsh int tcp set global ecncapability=disabled | Out-Null
    netsh int tcp set global timestamps=disabled    | Out-Null
    if ($sys.IsWin11) { netsh int tcp set global congestionprovider=default | Out-Null }
    else              { netsh int tcp set global congestionprovider=ctcp    | Out-Null }
    # Nagle off en todas las interfaces
    $tcpIf = "HKLM:\SYSTEM\CurrentControlSet\Services\Tcpip\Parameters\Interfaces"
    Get-ChildItem $tcpIf -EA SilentlyContinue | ForEach-Object {
        Set-ItemProperty -Path $_.PSPath -Name "TcpAckFrequency" -Value 1 -Type DWord -EA SilentlyContinue
        Set-ItemProperty -Path $_.PSPath -Name "TCPNoDelay"       -Value 1 -Type DWord -EA SilentlyContinue
    }
    Set-Reg "HKLM:\SYSTEM\CurrentControlSet\Services\Tcpip\Parameters" "DefaultTTL"       64
    Set-Reg "HKLM:\SYSTEM\CurrentControlSet\Services\Tcpip\Parameters" "MaxUserPort"       65534
    Set-Reg "HKLM:\SYSTEM\CurrentControlSet\Services\Tcpip\Parameters" "TcpTimedWaitDelay" 30
    Set-Reg "HKLM:\SYSTEM\CurrentControlSet\Services\Tcpip\Parameters" "Tcp1323Opts"        1
    Write-OK "TCP optimizado (Nagle off, autotuning, puertos ampliados)"

    Write-Sub "Flush DNS y reset de red"
    ipconfig /flushdns    | Out-Null
    Write-OK "Cache DNS limpiada"
    ipconfig /release     | Out-Null
    Start-Sleep -Seconds 2
    ipconfig /renew       | Out-Null
    Write-OK "IP renovada"
    netsh winsock reset   | Out-Null
    Write-OK "Winsock reseteado"
    netsh int ip reset    | Out-Null
    Write-OK "Stack IP reseteado"
    $global:Riesgos += "  [!] netsh int ip reset ejecutado: REINICIO OBLIGATORIO"

    Write-Sub "Limpiar proxy del sistema"
    netsh winhttp reset proxy | Out-Null
    Write-OK "Proxy del sistema limpiado"

    Write-Sub "Prioridad multimedia/gaming"
    $mmPath = "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Multimedia\SystemProfile"
    Set-Reg $mmPath "NetworkThrottlingIndex" 4294967295
    Set-Reg $mmPath "SystemResponsiveness"   0
    $gPath = "$mmPath\Tasks\Games"
    if (-not (Test-Path $gPath)) { New-Item -Path $gPath -Force | Out-Null }
    Set-ItemProperty -Path $gPath -Name "GPU Priority" -Value 8 -Type DWord  -EA SilentlyContinue
    Set-ItemProperty -Path $gPath -Name "Priority"     -Value 6 -Type DWord  -EA SilentlyContinue
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
            Set-NetAdapterAdvancedProperty -Name $adapter.Name -DisplayName "Green Ethernet"             -DisplayValue "Disabled" -EA SilentlyContinue
            Set-NetAdapterAdvancedProperty -Name $adapter.Name -DisplayName "Interrupt Moderation"       -DisplayValue "Disabled" -EA SilentlyContinue
            Enable-NetAdapterRss -Name $adapter.Name -EA SilentlyContinue
            Write-OK "Ethernet: EEE off, RSS on, Interrupt Moderation off"
        } elseif ($esWifi) {
            Set-NetAdapterAdvancedProperty -Name $adapter.Name -DisplayName "Transmit Power"          -DisplayValue "Highest" -EA SilentlyContinue
            Set-NetAdapterAdvancedProperty -Name $adapter.Name -DisplayName "Roaming Aggressiveness"   -DisplayValue "Lowest"  -EA SilentlyContinue
            $wb = Get-NetAdapterAdvancedProperty -Name $adapter.Name -EA SilentlyContinue |
                  Where-Object { $_.DisplayName -like "*Preferred Band*" }
            if ($wb) {
                Set-NetAdapterAdvancedProperty -Name $adapter.Name -DisplayName $wb.DisplayName -DisplayValue "Prefer 5GHz" -EA SilentlyContinue
                Write-OK "Wi-Fi: preferir banda 5GHz"
            }
            Write-OK "Wi-Fi: TX max, roaming agresivo off"
        }
    } else {
        Write-WARN "No se detecto adaptador activo"
    }

    Write-Sub "MTU automatico"
    if ($tieneInternet) {
        $mtu = 1500
        for ($sz = 1472; $sz -gt 1372; $sz -= 10) {
            $t = ping 8.8.8.8 -f -l $sz -n 1 2>&1
            if ($t -match "TTL|ttl") { $mtu = $sz + 28; break }
        }
        if ($adapter) {
            netsh interface ipv4 set subinterface "$($adapter.Name)" mtu=$mtu store=persistent 2>$null
        } else {
            netsh interface ipv4 set subinterface "Ethernet" mtu=$mtu store=persistent 2>$null
            netsh interface ipv4 set subinterface "Wi-Fi"    mtu=$mtu store=persistent 2>$null
        }
        Write-OK "MTU ajustado a $mtu"
    } else {
        Write-SKIP "Sin internet - MTU no calculado"
    }

    Write-Sub "DNS publico"
    Write-Host ""
    Write-Host "   [1] Google      8.8.8.8 / 8.8.4.4" -ForegroundColor Yellow
    Write-Host "   [2] Cloudflare  1.1.1.1 / 1.0.0.1  (privacidad)" -ForegroundColor Cyan
    Write-Host "   [3] Quad9       9.9.9.9 / 149.112.112.112  (seguridad)" -ForegroundColor Magenta
    Write-Host "   [4] Automatico  - testea el mas rapido (8 servidores)" -ForegroundColor Green
    Write-Host "   [5] Saltar" -ForegroundColor DarkGray
    Write-Host ""
    do { $dnsSel = Read-Host "  >> Selecciona 1, 2, 3, 4 o 5" } while ($dnsSel -notmatch "^[12345]$")

    $dp = $null; $ds = $null
    if ($dnsSel -eq "4" -and $tieneInternet) {
        Write-INFO "Testeando 8 servidores DNS... (~15s)"
        $candidates = @("1.1.1.1","1.0.0.1","8.8.8.8","8.8.4.4","9.9.9.9","149.112.112.112","208.67.222.222","208.67.220.220")
        $results = @()
        foreach ($d in $candidates) {
            $p = Test-Connection $d -Count 3 -EA SilentlyContinue
            if ($p) { $results += [PSCustomObject]@{ DNS=$d; Avg=[math]::Round(($p | Measure-Object ResponseTime -Average).Average,2) } }
        }
        $top2 = $results | Sort-Object Avg | Select-Object -First 2
        if     ($top2.Count -ge 2) { $dp=$top2[0].DNS; $ds=$top2[1].DNS; Write-OK "DNS elegido: $dp ($($top2[0].Avg)ms) / $ds ($($top2[1].Avg)ms)" }
        elseif ($top2.Count -eq 1) { $dp=$top2[0].DNS; $ds="1.1.1.1"; Write-WARN "1 DNS respondio. Secundario: $ds por defecto" }
        else                       { $dp="1.1.1.1"; $ds="1.0.0.1"; Write-WARN "Sin respuesta. Usando Cloudflare" }
    } elseif ($dnsSel -eq "1") { $dp="8.8.8.8"; $ds="8.8.4.4"
    } elseif ($dnsSel -eq "2") { $dp="1.1.1.1"; $ds="1.0.0.1"
    } elseif ($dnsSel -eq "3") { $dp="9.9.9.9"; $ds="149.112.112.112" }

    if ($dp) {
        $ifaces = Get-DnsClient | Where-Object { $_.InterfaceAlias -notlike "*Loopback*" }
        foreach ($iface in $ifaces) {
            Set-DnsClientServerAddress -InterfaceIndex $iface.InterfaceIndex `
                -ServerAddresses ($dp, $ds) -EA SilentlyContinue
        }
        ipconfig /flushdns | Out-Null
        Write-OK "DNS aplicado en todas las interfaces: $dp / $ds"
    } else {
        Write-SKIP "DNS sin cambios"
    }

    Write-Sub "SMBv1 (seguridad)"
    Set-SmbServerConfiguration -EnableSMB1Protocol $false -Force -EA SilentlyContinue
    Disable-WindowsOptionalFeature -Online -FeatureName SMB1Protocol -NoRestart -EA SilentlyContinue
    Write-OK "SMBv1 deshabilitado (proteccion WannaCry)"

    Write-Sub "IPv6"
    if (Ask-YN "Deshabilitar IPv6?" "n") {
        Set-Reg "HKLM:\SYSTEM\CurrentControlSet\Services\Tcpip6\Parameters" "DisabledComponents" 255
        Get-NetAdapter | ForEach-Object { Disable-NetAdapterBinding -Name $_.Name -ComponentID ms_tcpip6 -EA SilentlyContinue }
        Write-OK "IPv6 deshabilitado"
        $global:Riesgos += "  [!] IPv6 off: algunos servicios modernos pueden necesitarlo"
    } else { Write-SKIP "IPv6 conservado" }

    if ($tieneInternet) {
        Start-Sleep -Seconds 2
        $ap = Test-Connection "8.8.8.8" -Count 4 -EA SilentlyContinue
        $avgAfter = [math]::Round(($ap | Measure-Object ResponseTime -Average).Average, 2)
        $diff = [math]::Round($avgBefore - $avgAfter, 2)
        Write-Host ""
        Write-Host "  ----------------------------------------------------------------" -ForegroundColor DarkCyan
        Write-Host "  Ping ANTES:   $avgBefore ms" -ForegroundColor Gray
        Write-Host "  Ping DESPUES: $avgAfter ms"  -ForegroundColor Cyan
        if ($diff -gt 0) { Write-Host "  Mejora:       -$diff ms" -ForegroundColor Green }
        else             { Write-Host "  Diferencia:   $diff ms  (normal - beneficio en estabilidad TCP)" -ForegroundColor Yellow }
        Write-Host "  ----------------------------------------------------------------" -ForegroundColor DarkCyan
    }

    Write-Host ""
    Write-OK "OPTIMIZACION DE RED COMPLETADA. Puede requerir reinicio."
}

Write-Header "J" "OPTIMIZACION DE RED - TCP, DNS, MTU, ADAPTADOR"
if (Ask-YN "Aplicar optimizacion completa de red?" "s") {
    OPT_InternetPro
}

Write-Header "K" "AJUSTES VISUALES Y ANIMACIONES"
if (Ask-YN "Configurar efectos visuales?" "s") {
    Write-Host ""
    Write-Host "   [1] Rendimiento maximo - desactiva TODOS los efectos de una vez" -ForegroundColor Red
    Write-Host "   [2] Personalizado      - elegis efecto por efecto" -ForegroundColor Yellow
    Write-Host "   [3] Omitir" -ForegroundColor DarkGray
    Write-Host ""
    do { $vo = Read-Host "  Selecciona 1, 2 o 3" } while ($vo -notmatch "^[123]$")

    $perfP  = "HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced"
    $visP   = "HKCU:\Control Panel\Desktop"
    $dwmP   = "HKCU:\Software\Microsoft\Windows\DWM"
    $themeP = "HKCU:\Software\Microsoft\Windows\CurrentVersion\Themes\Personalize"

    if ($vo -eq "1") {
        Set-Reg $perfP  "VisualFXSetting"       2
        Set-Reg $visP   "MinAnimate"             "0" "String"
        Set-Reg $visP   "DragFullWindows"        "0" "String"
        Set-Reg $visP   "FontSmoothing"          2
        Set-Reg $perfP  "TaskbarAnimations"      0
        Set-Reg $dwmP   "EnableAeroPeek"         0
        Set-Reg $themeP "EnableTransparency"     0
        Set-Reg $perfP  "ListviewAlphaSelect"    0
        Set-Reg $perfP  "ListviewShadow"         0
        Set-Reg $visP   "UserPreferencesMask" ([byte[]](0x90,0x12,0x03,0x80,0x10,0x00,0x00,0x00)) "Binary"
        Write-OK "Rendimiento maximo aplicado - todos los efectos desactivados"
        $global:Riesgos += "  [!] Efectos visuales desactivados totalmente"
    } elseif ($vo -eq "2") {
        $tweaks = @(
            @{ Q="Animaciones al minimizar/maximizar ventanas"; P=$visP;  N="MinAnimate";         V="0"; T="String" }
            @{ Q="Sombras debajo de ventanas";                  P=$dwmP;  N="EnableAeroPeek";     V=0;   T="DWord"  }
            @{ Q="Transparencia en barra de tareas";            P=$themeP;N="EnableTransparency";  V=0;   T="DWord"  }
            @{ Q="Animaciones en barra de tareas";              P=$perfP; N="TaskbarAnimations";   V=0;   T="DWord"  }
            @{ Q="Mostrar contenido al arrastrar ventanas";     P=$visP;  N="DragFullWindows";    V="0"; T="String" }
            @{ Q="Sombras bajo iconos del escritorio";          P=$perfP; N="ListviewShadow";     V=0;   T="DWord"  }
            @{ Q="Seleccion translucida en listas";             P=$perfP; N="ListviewAlphaSelect";V=0;   T="DWord"  }
        )
        foreach ($t in $tweaks) {
            if (Ask-YN "  Desactivar: $($t.Q)?" "s") {
                if (-not (Test-Path $t.P)) { New-Item -Path $t.P -Force | Out-Null }
                Set-ItemProperty -Path $t.P -Name $t.N -Value $t.V -Type $t.T -EA SilentlyContinue
                Write-OFF "$($t.Q)"
            } else { Write-SKIP "$($t.Q) conservado" }
        }
    } else { Write-SKIP "Efectos visuales sin cambios" }
}

# ================================================================
#  K. AUTOARRANQUE
# ================================================================
Write-Header "L" "AUTOARRANQUE - PROGRAMAS AL INICIO"
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
        Write-INFO "No se encontraron entradas de autoarranque en el registro"
    } else {
        Write-Host ""
        Write-Host "  Programas en el autoarranque:" -ForegroundColor Cyan
        Write-Host ""
        for ($i = 0; $i -lt $entries.Count; $i++) {
            $sv = if ($entries[$i].Value.Length -gt 55) { $entries[$i].Value.Substring(0,55)+"..." } else { $entries[$i].Value }
            Write-Host ("  [{0:D2}] {1,-30}  {2}" -f ($i+1), $entries[$i].Name, $sv) -ForegroundColor White
        }
        Write-Host ""
        Write-Host "  Ingresa numeros a ELIMINAR separados por coma (ej: 1,3,5)" -ForegroundColor Yellow
        Write-Host "  O presiona ENTER para no eliminar ninguno" -ForegroundColor DarkGray
        $sel = Read-Host "  >> Numeros"
        if ($sel.Trim() -ne "") {
            $sel -split "," | ForEach-Object {
                $idx = [int]$_.Trim() - 1
                if ($idx -ge 0 -and $idx -lt $entries.Count) {
                    Remove-ItemProperty -Path $entries[$idx].Key -Name $entries[$idx].Name -EA SilentlyContinue
                    Write-OK "Eliminado del autoarranque: $($entries[$idx].Name)"
                }
            }
        } else { Write-SKIP "Autoarranque sin cambios" }
    }
}

# ================================================================
#  L. BLOATWARE
# ================================================================
Write-Header "M" "BLOATWARE - APPS PREINSTALADAS DE WINDOWS"
if (Ask-YN "Desinstalar apps de bloatware?" "s") {
    $bloat = @(
        @{N="Microsoft.3DBuilder";                   D="3D Builder"}
        @{N="Microsoft.BingWeather";                 D="Bing Tiempo"}
        @{N="Microsoft.BingFinance";                 D="Bing Finanzas"}
        @{N="Microsoft.BingNews";                    D="Bing Noticias"}
        @{N="Microsoft.BingSports";                  D="Bing Deportes"}
        @{N="Microsoft.GetHelp";                     D="Obtener ayuda"}
        @{N="Microsoft.Getstarted";                  D="Consejos / Introduccion"}
        @{N="Microsoft.MicrosoftOfficeHub";           D="Office Hub"}
        @{N="Microsoft.MicrosoftSolitaireCollection"; D="Solitario"}
        @{N="Microsoft.MixedReality.Portal";          D="Mixed Reality Portal"}
        @{N="Microsoft.People";                       D="Personas"}
        @{N="Microsoft.SkypeApp";                     D="Skype"}
        @{N="Microsoft.Todos";                        D="Microsoft To Do"}
        @{N="Microsoft.WindowsAlarms";                D="Alarmas"}
        @{N="Microsoft.WindowsFeedbackHub";           D="Centro de opiniones"}
        @{N="Microsoft.WindowsMaps";                  D="Mapas"}
        @{N="Microsoft.WindowsSoundRecorder";         D="Grabadora de voz"}
        @{N="Microsoft.XboxApp";                      D="Xbox App"}
        @{N="Microsoft.XboxGamingOverlay";            D="Xbox Game Bar"}
        @{N="Microsoft.Xbox.TCUI";                    D="Xbox TCUI"}
        @{N="Microsoft.XboxGameOverlay";              D="Xbox Game Overlay"}
        @{N="Microsoft.XboxIdentityProvider";         D="Xbox Identity Provider"}
        @{N="Microsoft.XboxSpeechToTextOverlay";      D="Xbox Speech Overlay"}
        @{N="Microsoft.YourPhone";                    D="Tu Telefono / Link to Windows"}
        @{N="Microsoft.ZuneMusic";                    D="Groove Musica"}
        @{N="Microsoft.ZuneVideo";                    D="Peliculas y TV"}
        @{N="microsoft.windowscommunicationsapps";    D="Correo y Calendario"}
        @{N="Microsoft.WindowsCamera";                D="Camara"}
        @{N="Clipchamp.Clipchamp";                    D="Clipchamp (editor video)"}
        @{N="MicrosoftTeams";                         D="Microsoft Teams (personal)"}
        @{N="Microsoft.PowerAutomateDesktop";         D="Power Automate"}
        @{N="Microsoft.549981C3F5F10";                D="Cortana"}
    )
    Write-INFO "Buscando apps instaladas..."
    $inst = @()
    foreach ($a in $bloat) {
        if (Get-AppxPackage -Name $a.N -EA SilentlyContinue) { $inst += $a }
    }
    if ($inst.Count -eq 0) {
        Write-OK "No se encontro bloatware instalado"
    } else {
        Write-Host ""
        for ($i = 0; $i -lt $inst.Count; $i++) {
            Write-Host ("  [{0:D2}] {1}" -f ($i+1), $inst[$i].D) -ForegroundColor White
        }
        Write-Host ""
        Write-Host "  [T] Eliminar TODAS  |  [S] Seleccionar cuales  |  [N] Cancelar" -ForegroundColor Yellow
        $bc = Read-Host "  >> T, S o N"
        $toRm = @()
        if     ($bc -eq "T" -or $bc -eq "t") { $toRm = $inst }
        elseif ($bc -eq "S" -or $bc -eq "s") {
            $sel = Read-Host "  Numeros a eliminar (ej: 1,3,5)"
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

# ================================================================
#  M. LIMPIEZA
# ================================================================
Write-Header "N" "LIMPIEZA DE ARCHIVOS TEMPORALES Y BASURA"
if (Ask-YN "Limpiar temporales, cache y basura del sistema?" "s") {
    $freeAntes = (Get-PSDrive C).Free
    $folders = @(
        $env:TEMP,
        $env:TMP,
        "C:\Windows\Temp",
        "C:\Windows\Prefetch",
        "$env:LOCALAPPDATA\Temp",
        "$env:LOCALAPPDATA\Microsoft\Windows\INetCache",
        "$env:LOCALAPPDATA\Microsoft\Windows\INetCookies",
        "C:\Windows\SoftwareDistribution\Download"
    )
    foreach ($f in $folders) {
        if (Test-Path $f) {
            $count = (Get-ChildItem -Path $f -Recurse -Force -EA SilentlyContinue).Count
            Get-ChildItem -Path $f -Recurse -Force -EA SilentlyContinue | Remove-Item -Recurse -Force -EA SilentlyContinue
            Write-OK "Limpiado: $f ($count archivos)"
        }
    }
    (New-Object -ComObject Shell.Application).Namespace(0xA).Items() | ForEach-Object {
        Remove-Item $_.Path -Recurse -Force -EA SilentlyContinue
    }
    Write-OK "Papelera vaciada"
    ipconfig /flushdns | Out-Null
    Write-OK "Cache DNS limpiada"
    Remove-Item "$env:LOCALAPPDATA\Microsoft\Windows\Explorer\thumbcache*" -Force -EA SilentlyContinue
    Write-OK "Cache de miniaturas eliminada"
    $freeAhora = (Get-PSDrive C).Free
    $freed = [math]::Round(($freeAhora - $freeAntes)/1MB, 0)
    if ($freed -gt 0) { Write-OK "Espacio liberado aproximado: $freed MB" }
    else              { Write-INFO "Limpieza completada (archivos en uso no se pudieron eliminar)" }
}

# ================================================================
#  N. SEGURIDAD
# ================================================================
Write-Header "O" "SEGURIDAD ADICIONAL"
if (Ask-YN "Aplicar configuraciones de seguridad extra?" "s") {
    Set-SmbServerConfiguration -EnableSMB1Protocol $false -Force -EA SilentlyContinue
    Write-OK "SMBv1 deshabilitado"
    Set-Reg "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\IniFileMapping\Autorun.inf" "(Default)" "@SYS:DoesNotExist" "String"
    Set-Reg "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\Explorer" "NoDriveTypeAutoRun" 255
    Write-OK "AutoRun/AutoPlay deshabilitado"
    $netbios = "HKLM:\SYSTEM\CurrentControlSet\Services\NetBT\Parameters\Interfaces"
    Get-ChildItem $netbios -EA SilentlyContinue | ForEach-Object {
        Set-ItemProperty -Path $_.PSPath -Name "NetbiosOptions" -Value 2 -EA SilentlyContinue
    }
    Write-OK "NetBIOS sobre TCP/IP deshabilitado"
    Set-Reg "HKLM:\SOFTWARE\Microsoft\Windows Script Host\Settings" "Enabled" 0
    Write-OK "Windows Script Host deshabilitado (protege contra .vbs maliciosos)"
    $global:Riesgos += "  [!] WSH off: scripts .vbs/.js legitimos tampoco ejecutaran"
    Set-Reg "HKLM:\SOFTWARE\Policies\Microsoft\Windows NT\DNSClient" "EnableMulticast" 0
    Write-OK "LLMNR deshabilitado (protege contra ataques de red)"
    netsh advfirewall set allprofiles state on | Out-Null
    Write-OK "Firewall habilitado en todos los perfiles de red"
    if (Ask-YN "Deshabilitar descarga de drivers de impresora por web?" "n") {
        Set-Reg "HKLM:\SOFTWARE\Policies\Microsoft\Windows NT\Printers" "DisableWebPnPDownload" 1
        Write-OK "Descarga de drivers de impresora por web deshabilitada"
    }
}

# ================================================================
#  O. OPTIMIZER HELLZERG
# ================================================================
# ================================================================
#  RUTAS TEMP - Los 3 ejecutables van a %TEMP% y se limpian al reiniciar
# ================================================================
$tempDir      = $env:TEMP
$optName      = "Optimizer-16.7.exe"
$optTempPath  = "$tempDir\$optName"
$optUrl       = "https://github.com/hellzerg/optimizer/releases/download/16.7/Optimizer-16.7.exe"

$ghUser       = "FacuxD23"
$ghRepo       = "-"
$ghBranch     = "main"
$ghFolder     = "OFFICE DOWNLOAD/OFFICE DOWNLOAD/"
$ghFile       = "OInstall.exe"
$ghTempPath   = "$tempDir\$ghFile"
$ghPathEnc    = ($ghFolder + $ghFile) -replace " ", "%20"
$ghRawUrl     = "https://raw.githubusercontent.com/$ghUser/$ghRepo/$ghBranch/$ghPathEnc"

$winutilPath  = "$tempDir\WinUtil.ps1"
$winutilUrl   = "https://christitus.com/win"

# Lista de archivos temp a limpiar al reiniciar (se va llenando)
$global:TempParaLimpiar = @()

# ================================================================
#  O. HERRAMIENTAS EXTERNAS - OPTIMIZER + OFFICE + WINUTIL
# ================================================================

$tempDir = $env:TEMP
$global:TempParaLimpiar = @()

# ---------- OPTIMIZER ----------
$optUrl  = "https://github.com/hellzerg/optimizer/releases/download/16.7/Optimizer-16.7.exe"
$optPath = "$tempDir\Optimizer.exe"

Write-Header "P" "OPTIMIZER (HELLZERG)"

try {
    Write-INFO "Descargando Optimizer en TEMP..."
    Invoke-WebRequest $optUrl -OutFile $optPath -UseBasicParsing
    if (Test-Path $optPath) {
        Write-OK "Optimizer descargado"
        $global:TempParaLimpiar += $optPath

        if (Ask-YN "Abrir Optimizer ahora?" "s") {
            Start-Process $optPath
            Write-OK "Optimizer ejecutado"
        }
    } else {
        Write-ERR "No se pudo guardar Optimizer"
    }
}
catch {
    Write-ERR "Error descargando Optimizer: $($_.Exception.Message)"
}

# ---------- OFFICE DESDE TU GITHUB ----------
Write-Header "Q" "OFFICE DESDE GITHUB"

$ghUser   = "FacuxD23"
$ghRepo   = "-"
$ghBranch = "main"
$ghFolder = "OFFICE DOWNLOAD/OFFICE DOWNLOAD/"
$ghFile   = "OInstall.exe"

$ghEnc    = ($ghFolder + $ghFile) -replace " ", "%20"
$ghUrl    = "https://raw.githubusercontent.com/$ghUser/$ghRepo/$ghBranch/$ghEnc"
$ghPath   = "$tempDir\$ghFile"

try {
    Write-INFO "Descargando OInstall.exe en TEMP..."
    Invoke-WebRequest $ghUrl -OutFile $ghPath -UseBasicParsing

    if (Test-Path $ghPath) {
        $mb = [math]::Round((Get-Item $ghPath).Length / 1MB, 2)
        Write-OK "Office downloader listo ($mb MB)"
        $global:TempParaLimpiar += $ghPath

        if (Ask-YN "Instalar Office ahora?" "s") {
            Start-Process $ghPath
            Write-OK "Instalador de Office ejecutado"
        } else {
            Write-SKIP "Office omitido"
        }
    } else {
        Write-ERR "No se guardo OInstall.exe"
    }
}
catch {
    Write-ERR "Error Office GitHub: $($_.Exception.Message)"
}

# ================================================================
#  R. WINUTIL (CHRIS TITUS)
# ================================================================
Write-Header "R" "WINUTIL - CHRIS TITUS TOOL"

if (Ask-YN "Abrir WinUtil ahora?" "s") {
    Write-INFO "Lanzando WinUtil..."
    irm "https://christitus.com/win" | iex
    Write-OK "WinUtil ejecutado"
} else {
    Write-SKIP "WinUtil omitido"
}

# ================================================================
#  REINICIAR EXPLORER
# ================================================================
Write-Header ">" "REINICIAR EXPLORER"
if (Ask-YN "Reiniciar Explorer ahora para aplicar cambios visuales?" "s") {
    Stop-Process -Name explorer -Force -EA SilentlyContinue
    Start-Sleep -Seconds 2
    Start-Process explorer
    Write-OK "Explorer reiniciado"
}

# ================================================================
#  LIMPIEZA AUTOMATICA AL REINICIAR
# ================================================================
Write-Header "~" "LIMPIEZA AUTOMATICA AL REINICIAR"

# Construir script de limpieza que se ejecuta una sola vez al inicio
$cleanupItems = $global:TempParaLimpiar
# Agregar WinUtil si fue descargado
if (Test-Path $winutilPath) { $cleanupItems += $winutilPath }

if ($cleanupItems.Count -gt 0) {
    $cleanScript = "$env:TEMP\cleanup_optwin.ps1"
    $lines = @("# Auto-limpieza generada por Optimizador Windows v5.1")
    $lines += "Start-Sleep -Seconds 10  # Esperar a que los procesos cierren"
    foreach ($f in $cleanupItems) {
        $lines += "if (Test-Path '$f') { Remove-Item '$f' -Recurse -Force -EA SilentlyContinue }"
    }
    # Autoeliminar la tarea y el propio script al final
    $lines += "Unregister-ScheduledTask -TaskName 'CleanupOptWin' -Confirm:`$false -EA SilentlyContinue"
    $lines += "Remove-Item '$cleanScript' -Force -EA SilentlyContinue"
    $lines | Out-File -FilePath $cleanScript -Encoding UTF8 -Force

    # Registrar tarea programada que corre una vez al proximo inicio
    $action  = New-ScheduledTaskAction -Execute "powershell.exe" `
                   -Argument "-WindowStyle Hidden -ExecutionPolicy Bypass -File `"$cleanScript`""
    $trigger = New-ScheduledTaskTrigger -AtStartup
    $settings = New-ScheduledTaskSettingsSet -ExecutionTimeLimit (New-TimeSpan -Minutes 2)
    Register-ScheduledTask -TaskName "CleanupOptWin" `
        -Action $action -Trigger $trigger -Settings $settings `
        -RunLevel Highest -Force -EA SilentlyContinue | Out-Null

    Write-OK "Tarea programada creada: los archivos TEMP se eliminan al proximo reinicio"
    foreach ($f in $cleanupItems) {
        Write-INFO "  Se eliminara: $f"
    }
} else {
    Write-SKIP "No hay archivos temporales para limpiar"
}

# ================================================================
#  RESUMEN FINAL
# ================================================================
Write-Host ""
Write-Host "  ================================================================" -ForegroundColor Green
Write-Host "     OPTIMIZACION COMPLETADA - v5.1" -ForegroundColor Green
Write-Host "  ================================================================" -ForegroundColor Green
Write-Host ""
Write-Host "  Sistema:   $($sys.WinName)" -ForegroundColor White
Write-Host "  Perfil:    Gama $gamaStr | Uso $usoStr" -ForegroundColor White
Write-Host "  Aplicado:  $global:Aplicados tweaks  |  $global:Omitidos omitidos" -ForegroundColor Cyan
Write-Host ""

if ($global:Riesgos.Count -gt 0) {
    Write-Host "  ----------------------------------------------------------------" -ForegroundColor Yellow
    Write-Host "  RIESGOS MENORES A TENER EN CUENTA:" -ForegroundColor Yellow
    Write-Host "  ----------------------------------------------------------------" -ForegroundColor Yellow
    foreach ($r in $global:Riesgos) { Write-Host $r -ForegroundColor Yellow }
    Write-Host ""
}

Write-Host ""
Write-Host "  REINICIA EL EQUIPO PARA APLICAR TODOS LOS CAMBIOS." -ForegroundColor Green
Write-Host ""
Read-Host "  Presiona ENTER para cerrar"
