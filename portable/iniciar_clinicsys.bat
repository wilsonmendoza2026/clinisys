@echo off
setlocal EnableExtensions
set "ROOT=%~dp0"
set "JAVA_HOME=%ROOT%runtime\java17"
set "JRE_HOME=%JAVA_HOME%"
set "CATALINA_HOME=%ROOT%tomcat"
set "CATALINA_BASE=%ROOT%tomcat"
set "PATH=%JAVA_HOME%\bin;%ROOT%postgres\bin;%PATH%"
if not exist "%ROOT%data\pgdata\PG_VERSION" (
  echo Primero ejecute preparar_clinicsys.bat.
  pause
  exit /b 1
)
"%ROOT%postgres\bin\pg_ctl.exe" -D "%ROOT%data\pgdata" -l "%ROOT%logs\postgresql.log" start
if errorlevel 1 (
  echo No se pudo iniciar PostgreSQL. Puede que ya este iniciado.
)
timeout /t 3 /nobreak >nul
call "%CATALINA_HOME%\bin\startup.bat"
timeout /t 5 /nobreak >nul
start "ClinicSys" "http://127.0.0.1:8084/ProyectoTURNOn2026/"
endlocal
