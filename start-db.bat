@echo off
chcp 65001 >nul
title DataAsset Platform - PostgreSQL
echo [1/1] 启动 PostgreSQL 17.11（端口 5432）...
"D:\Program\JavaProgram\pgsql-17.11\bin\pg_ctl.exe" -D "D:\Program\JavaProgram\pgdata" -l "D:\Program\JavaProgram\pgdata\server.log" -o "-p 5432" start
if %errorlevel%==0 (
  echo.
  echo PostgreSQL 已在后台运行，日志: D:\Program\JavaProgram\pgdata\server.log
  echo 本窗口可以关闭。
) else (
  echo 启动失败，请查看日志。
  pause
)
