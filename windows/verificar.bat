@echo off
rem AGHUse - executa verificar.ps1 como Administrador
setlocal
net session >nul 2>&1
if not errorlevel 1 goto ADMIN
if not "%~1"=="" goto PRECISA_ADMIN
echo Solicitando permissao de administrador...
powershell.exe -NoProfile -Command "Start-Process powershell.exe -Verb RunAs -ArgumentList '-NoProfile -ExecutionPolicy Bypass -NoExit -File \"%~dp0verificar.ps1\"'"
exit /b
:PRECISA_ADMIN
echo Execute este comando em um Prompt de Comando aberto como Administrador.
exit /b 1
:ADMIN
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0verificar.ps1" %*
exit /b %ERRORLEVEL%
