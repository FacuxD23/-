@echo off
chcp 65001 >nul 2>&1
color 0A
mode con: cols=100 lines=40
title Optimizador Windows v5.0 ULTRA
setlocal enabledelayedexpansion

:: Escalar fuente al ~110% via registro
reg add "HKCU\Console\Optimizador Windows v5.0 ULTRA" /v FontSize /t REG_DWORD /d 1048576 /f >nul 2>&1
reg add "HKCU\Console\Optimizador Windows v5.0 ULTRA" /v FaceName /t REG_SZ    /d "Consolas" /f >nul 2>&1

:: Escalar fuente en la sesion ACTUAL via PowerShell
powershell -NoProfile -ExecutionPolicy Bypass -Command "$s='using System;using System.Runtime.InteropServices;public class CF{[StructLayout(LayoutKind.Sequential,CharSet=CharSet.Unicode)]public struct FX{public uint z;public uint n;public short x;public short y;public int f;public int w;[MarshalAs(UnmanagedType.ByValTStr,SizeConst=32)]public string fn;}[DllImport(\"kernel32.dll\")]public static extern IntPtr GetStdHandle(int n);[DllImport(\"kernel32.dll\")]public static extern bool GetCurrentConsoleFontEx(IntPtr h,bool b,ref FX i);[DllImport(\"kernel32.dll\")]public static extern bool SetCurrentConsoleFontEx(IntPtr h,bool b,ref FX i);}';Add-Type -TypeDefinition $s -EA SilentlyContinue;$h=[CF]::GetStdHandle(-11);$i=New-Object CF+FX;$i.z=60;[CF]::GetCurrentConsoleFontEx($h,$false,[ref]$i)|Out-Null;$ny=[math]::Round($i.y*1.10);if($ny-lt 16){$ny=16};if($ny-gt 28){$ny=28};$i.y=[short]$ny;$i.x=0;if(-not $i.fn){$i.fn='Consolas'};[CF]::SetCurrentConsoleFontEx($h,$false,[ref]$i)|Out-Null" >nul 2>&1

:: Verificar admin
openfiles >nul 2>&1
if %errorlevel% NEQ 0 (
    powershell -Command "Start-Process -FilePath '%~f0' -Verb RunAs"
    exit /b
)

:: ----------------------------------------------------------------
::  DETECTAR HARDWARE via PowerShell (compatible Win10/11)
:: ----------------------------------------------------------------
for /f "usebackq delims=" %%a in (`powershell -NoProfile -Command "(Get-CimInstance Win32_OperatingSystem).Caption"`) do set "SO=%%a"
for /f "usebackq delims=" %%a in (`powershell -NoProfile -Command "(Get-CimInstance Win32_OperatingSystem).Version"`) do set "WIN_VER=%%a"
for /f "usebackq delims=" %%a in (`powershell -NoProfile -Command "(Get-CimInstance Win32_Processor | Select-Object -First 1).Name.Trim()"`) do set "CPU=%%a"
for /f "usebackq delims=" %%a in (`powershell -NoProfile -Command "[math]::Round((Get-CimInstance Win32_ComputerSystem).TotalPhysicalMemory/1GB,1)"`) do set "RAM=%%a"
for /f "usebackq delims=" %%a in (`powershell -NoProfile -Command "(Get-CimInstance Win32_VideoController | Where-Object { $_.Name -notmatch 'Microsoft Basic|Remote' } | Select-Object -First 1).Name"`) do set "GPU=%%a"
for /f "usebackq delims=" %%a in (`powershell -NoProfile -Command "(Get-CimInstance Win32_DiskDrive | ForEach-Object { [math]::Round($_.Size/1GB,0).ToString() + 'GB' }) -join ', '"`) do set "DISCOS=%%a"
for /f "usebackq delims=" %%a in (`powershell -NoProfile -Command "[math]::Round((Get-PSDrive C).Free/1GB,1)"`) do set "LIBRE=%%a"

:MENU
cls
echo.
echo  ================================================================================
echo  ==                                                                            ==
echo  ==      OPTIMIZADOR PROFESIONAL DE WINDOWS v5.0 ULTRA EDITION                ==
echo  ==      Maxima Velocidad ^| Maxima Seguridad ^| Maxima Limpieza               ==
echo  ==                                                                            ==
echo  ================================================================================
echo.
echo  --------------------------------------------------------------------------------
echo   SISTEMA DETECTADO:
echo  --------------------------------------------------------------------------------
echo   SO:     %SO%
echo   CPU:    %CPU%
echo   GPU:    %GPU%
echo   RAM:    %RAM% GB
echo   DISCO:  %DISCOS%  ^|  Libre C:\: %LIBRE% GB
echo  --------------------------------------------------------------------------------
echo.
echo  ================================================================================
echo                               MENU PRINCIPAL
echo  ================================================================================
echo.
echo   [1] OPTIMIZACION COMPLETA  -  Todo en uno (Recomendado)
echo.
echo   [2] INFORMACION SISTEMA    -  Ver detalles completos
echo.
echo   [0] SALIR                  -  Cerrar programa
echo.
echo  ================================================================================
echo.
echo   CONSEJO: Asegurate de tener un punto de restauracion antes de optimizar
echo.
set /p "opcion=  Selecciona una opcion (0-2): "

if "%opcion%"=="1" goto OPTIMIZAR
if "%opcion%"=="2" goto SYSINFO
if "%opcion%"=="0" exit /b
goto MENU

:OPTIMIZAR
cls
echo.
echo  ================================================================================
echo                           INICIANDO OPTIMIZACION
echo  ================================================================================
echo.
echo  --------------------------------------------------------------------------------
echo   SISTEMA DETECTADO:
echo  --------------------------------------------------------------------------------
echo   SO:     %SO%
echo   CPU:    %CPU%
echo   GPU:    %GPU%
echo   RAM:    %RAM% GB
echo   DISCO:  %DISCOS%  ^|  Libre C:\: %LIBRE% GB
echo  --------------------------------------------------------------------------------
echo.
echo   Descargando y ejecutando optimizador desde GitHub...
echo.

powershell -ExecutionPolicy Bypass -NoProfile -Command "irm 'https://raw.githubusercontent.com/FacuxD23/-/main/optimizar_windows.ps1' | iex"

echo.
echo  ================================================================================
echo                          OPTIMIZACION COMPLETADA
echo  ================================================================================
echo.
echo   Podes cerrar esta ventana o presionar ENTER para volver al menu.
echo.
pause
goto MENU

:SYSINFO
cls
echo.
echo  ================================================================================
echo                         INFORMACION DEL SISTEMA
echo  ================================================================================
echo.
echo   SISTEMA OPERATIVO:
echo   ------------------
echo   Nombre:        %SO%
echo   Version:       %WIN_VER%
for /f "usebackq delims=" %%a in (`powershell -NoProfile -Command "(Get-CimInstance Win32_OperatingSystem).OSArchitecture"`) do echo   Arquitectura:  %%a
echo.
echo   HARDWARE:
echo   ---------
echo   CPU:           %CPU%
echo   GPU:           %GPU%
echo   RAM Total:     %RAM% GB
echo   Discos:        %DISCOS%
echo   Libre en C:\:  %LIBRE% GB
echo.
echo   RED:
echo   ----
for /f "usebackq delims=" %%a in (`powershell -NoProfile -Command "(Get-NetIPAddress -AddressFamily IPv4 | Where-Object { $_.IPAddress -notmatch '^127' } | Select-Object -First 1).IPAddress"`) do echo   IP Local:      %%a
echo.
echo  ================================================================================
echo.
pause
goto MENU
