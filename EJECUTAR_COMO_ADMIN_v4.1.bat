@echo off
:: ================================================================
::  LANZADOR - Optimizador Inteligente de Windows v4.1
::  Coloca este .bat en la misma carpeta que optimizar_windows.ps1
::  NUEVAS FUNCIONES:
::    - Opcion de arranque sin GUI integrada
::    - Descarga desde GitHub personalizado
:: ================================================================
title Optimizador de Windows v4.1

echo.
echo  ================================================================
echo   OPTIMIZADOR INTELIGENTE DE WINDOWS v4.1
echo   Servicios + Registro + Red + Bloatware + Visual + Limpieza
echo   + Descarga GitHub + Arranque sin GUI
echo  ================================================================
echo.

:: Verificar si ya es administrador
openfiles >nul 2>&1
if %errorlevel% NEQ 0 (
    echo  Solicitando permisos de administrador...
    powershell -Command "Start-Process '%~f0' -Verb RunAs"
    exit /b
)

:: ================================================================
::  MENU PRINCIPAL
:: ================================================================
:MENU
cls
echo.
echo  ================================================================
echo   OPTIMIZADOR DE WINDOWS v4.1 - MENU PRINCIPAL
echo  ================================================================
echo.
echo   [1] Ejecutar script completo de optimizacion
echo   [2] Solo habilitar arranque sin GUI (rapido)
echo   [3] Descargar y ejecutar script desde GitHub
echo   [4] Ver informacion del sistema
echo   [0] Salir
echo.
set /p "opcion=  Selecciona una opcion (0-4): "

if "%opcion%"=="1" goto OPTIMIZAR
if "%opcion%"=="2" goto NOGUI
if "%opcion%"=="3" goto GITHUB
if "%opcion%"=="4" goto SYSINFO
if "%opcion%"=="0" exit /b
goto MENU

:: ================================================================
::  OPCION 1: OPTIMIZACION COMPLETA
:: ================================================================
:OPTIMIZAR
echo.
echo  Iniciando optimizacion completa...
echo.

:: Habilitar ejecucion de scripts PS para esta sesion
powershell -Command "Set-ExecutionPolicy -Scope Process -ExecutionPolicy Bypass -Force" >nul 2>&1

:: Buscar el .ps1 en la misma carpeta
set "SCRIPT=%~dp0optimizar_windows.ps1"

if not exist "%SCRIPT%" (
    echo.
    echo  [ERROR] No se encontro optimizar_windows.ps1
    echo  Asegurate de que el .bat y el .ps1 esten en la misma carpeta.
    echo.
    pause
    goto MENU
)

powershell -ExecutionPolicy Bypass -NoProfile -File "%SCRIPT%"
pause
goto MENU

:: ================================================================
::  OPCION 2: SOLO ARRANQUE SIN GUI
:: ================================================================
:NOGUI
echo.
echo  ================================================================
echo   HABILITAR ARRANQUE SIN GUI
echo  ================================================================
echo.
echo  Esta opcion deshabilitara la animacion de inicio de Windows,
echo  acelerando el arranque del sistema.
echo.
set /p "confirmar=  Deseas continuar? (S/N): "

if /i not "%confirmar%"=="S" goto MENU

echo.
echo  Aplicando cambios...
echo.

powershell -Command "bcdedit /set '{current}' bootmenupolicy legacy" >nul 2>&1
powershell -Command "bcdedit /set '{current}' quietboot on" >nul 2>&1

if %errorlevel% EQU 0 (
    echo  [OK] Arranque sin GUI habilitado correctamente.
    echo  [INFO] El sistema arrancara mas rapido sin animaciones.
    echo  [INFO] Reinicia para aplicar los cambios.
) else (
    echo  [ERROR] No se pudo aplicar la configuracion.
    echo  [INFO] Verifica que tengas permisos de administrador.
)

echo.
pause
goto MENU

:: ================================================================
::  OPCION 3: DESCARGAR DESDE GITHUB
:: ================================================================
:GITHUB
echo.
echo  ================================================================
echo   DESCARGAR Y EJECUTAR SCRIPT DESDE GITHUB
echo  ================================================================
echo.
echo  Ingresa los datos de tu repositorio de GitHub:
echo.

set /p "git_user=  Usuario de GitHub (ej: tunombre): "
set /p "git_repo=  Nombre del repositorio (ej: mi-repo): "
set /p "git_file=  Nombre del archivo (ej: script.ps1): "

if "%git_user%"=="" goto MENU
if "%git_repo%"=="" goto MENU
if "%git_file%"=="" goto MENU

echo.
echo  Descargando desde GitHub...
echo  URL: https://raw.githubusercontent.com/%git_user%/%git_repo%/main/%git_file%
echo.

set "download_url=https://raw.githubusercontent.com/%git_user%/%git_repo%/main/%git_file%"
set "temp_file=%TEMP%\%git_file%"

powershell -Command "(New-Object System.Net.WebClient).DownloadFile('%download_url%', '%temp_file%')"

if exist "%temp_file%" (
    echo  [OK] Archivo descargado correctamente.
    echo  [INFO] Ubicacion: %temp_file%
    echo.
    
    set /p "ejecutar=  Deseas ejecutarlo ahora? (S/N): "
    
    if /i "%ejecutar%"=="S" (
        echo.
        echo  Ejecutando archivo...
        
        :: Detectar extension y ejecutar apropiadamente
        if /i "%git_file:~-4%"==".ps1" (
            powershell -ExecutionPolicy Bypass -File "%temp_file%"
        ) else if /i "%git_file:~-4%"==".bat" (
            call "%temp_file%"
        ) else if /i "%git_file:~-4%"==".exe" (
            start "" "%temp_file%"
        ) else (
            start "" "%temp_file%"
        )
    )
) else (
    echo  [ERROR] No se pudo descargar el archivo.
    echo  [INFO] Verifica que la URL sea correcta y que tengas internet.
)

echo.
pause
goto MENU

:: ================================================================
::  OPCION 4: INFORMACION DEL SISTEMA
:: ================================================================
:SYSINFO
echo.
echo  ================================================================
echo   INFORMACION DEL SISTEMA
echo  ================================================================
echo.

:: Obtener informacion basica
for /f "tokens=2 delims==" %%a in ('wmic os get Caption /value') do set "os_name=%%a"
for /f "tokens=2 delims==" %%a in ('wmic os get Version /value') do set "os_version=%%a"
for /f "tokens=2 delims==" %%a in ('wmic computersystem get totalphysicalmemory /value') do set "ram=%%a"
for /f "tokens=2 delims==" %%a in ('wmic cpu get name /value') do set "cpu=%%a"

:: Calcular RAM en GB
set /a "ram_gb=%ram:~0,-9%"

echo  Sistema Operativo: %os_name%
echo  Version:           %os_version%
echo  Procesador:        %cpu%
echo  RAM:               %ram_gb% GB
echo.

:: Verificar si el arranque sin GUI esta activo
bcdedit | findstr /C:"quietboot" /C:"Yes" >nul 2>&1
if %errorlevel% EQU 0 (
    echo  [INFO] Arranque sin GUI: HABILITADO
) else (
    echo  [INFO] Arranque sin GUI: DESHABILITADO
)

echo.
pause
goto MENU

exit /b
