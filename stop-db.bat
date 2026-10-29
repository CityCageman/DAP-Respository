@echo off
chcp 65001 >nul
echo 停止 PostgreSQL...
"D:\Program\JavaProgram\pgsql-17.11\bin\pg_ctl.exe" -D "D:\Program\JavaProgram\pgdata" -m fast stop
pause
