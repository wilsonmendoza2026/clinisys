@echo off
setlocal
set "ROOT=%~dp0"
set "JAVA_HOME=%ROOT%runtime\java17"
set "CATALINA_HOME=%ROOT%tomcat"
set "CATALINA_BASE=%ROOT%tomcat"
call "%CATALINA_HOME%\bin\shutdown.bat"
timeout /t 5 /nobreak >nul
"%ROOT%postgres\bin\pg_ctl.exe" -D "%ROOT%data\pgdata" stop -m fast
endlocal
