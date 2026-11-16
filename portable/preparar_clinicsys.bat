@echo off
setlocal EnableExtensions
set "ROOT=%~dp0"
set "PGROOT=%ROOT%postgres"
set "PGDATA=%ROOT%data\pgdata"
set "PATH=%PGROOT%\bin;%PATH%"
set /p "DBPASS="<"%ROOT%config\db_password.txt"
set "PGPASSWORD=%DBPASS%"
if exist "%PGDATA%\PG_VERSION" (
  echo La base local ya esta inicializada.
  pause
  exit /b 0
)
if not exist "%ROOT%backups\sistema_nutricion_inicial.dump" (
  echo No se encontro el respaldo inicial.
  pause
  exit /b 1
)
mkdir "%PGDATA%" 2>nul
>"%ROOT%config\postgres_pw.tmp" echo %DBPASS%
"%PGROOT%\bin\initdb.exe" -D "%PGDATA%" -U postgres -A scram-sha-256 --pwfile="%ROOT%config\postgres_pw.tmp" -E UTF8
if errorlevel 1 goto :error
 del /q "%ROOT%config\postgres_pw.tmp" 2>nul
(
  echo listen_addresses = '127.0.0.1'
  echo port = 5432
) >> "%PGDATA%\postgresql.conf"
(
  echo host all all 127.0.0.1/32 scram-sha-256
  echo host all all ::1/128 scram-sha-256
) >> "%PGDATA%\pg_hba.conf"
"%PGROOT%\bin\pg_ctl.exe" -D "%PGDATA%" -l "%ROOT%logs\postgresql.log" start
if errorlevel 1 goto :error
:wait
"%PGROOT%\bin\pg_isready.exe" -h 127.0.0.1 -p 5432 >nul 2>&1
if errorlevel 1 (timeout /t 1 /nobreak >nul & goto :wait)
"%PGROOT%\bin\createdb.exe" -h 127.0.0.1 -p 5432 -U postgres sistema_nutricion
if errorlevel 1 goto :error
"%PGROOT%\bin\pg_restore.exe" -h 127.0.0.1 -p 5432 -U postgres -d sistema_nutricion --no-owner --no-privileges "%ROOT%backups\sistema_nutricion_inicial.dump"
if errorlevel 1 goto :error
"%PGROOT%\bin\pg_ctl.exe" -D "%PGDATA%" stop -m fast
if errorlevel 1 goto :error
echo ClinicSys fue preparado correctamente.
pause
exit /b 0
:error
echo No se pudo preparar la base. Revise logs\postgresql.log.
pause
exit /b 1
