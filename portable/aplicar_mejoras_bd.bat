@echo off
setlocal EnableExtensions
set "ROOT=%~dp0"
set "PATH=%ROOT%postgres\bin;%PATH%"
set /p "DBPASS="<"%ROOT%config\db_password.txt"
set "PGPASSWORD=%DBPASS%"
echo Aplicando mejoras de datos (PostgreSQL debe estar iniciado: ejecute antes iniciar_clinicsys.bat)...
"%ROOT%postgres\bin\psql.exe" -h 127.0.0.1 -p 5432 -U postgres -d sistema_nutricion -v ON_ERROR_STOP=1 -f "%ROOT%mejoras_bd.sql"
if errorlevel 1 (echo Hubo un error. Nada fue modificado.) else (echo Listo.)
pause
