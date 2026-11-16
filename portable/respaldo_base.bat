@echo off
setlocal
set "ROOT=%~dp0"
set /p "PGPASSWORD="<"%ROOT%config\db_password.txt"
for /f "tokens=1-3 delims=/- " %%a in ('date /t') do set "FECHA=%%c%%b%%a"
"%ROOT%postgres\bin\pg_dump.exe" -h 127.0.0.1 -p 5432 -U postgres -Fc sistema_nutricion > "%ROOT%backups\sistema_nutricion_%FECHA%.dump"
if errorlevel 1 (echo Error al crear el respaldo.) else (echo Respaldo creado en backups.)
pause
endlocal
