@echo off
chcp 65001 >nul
title DataAsset Platform - Frontend (5173)
echo 启动前端 Vite（端口 5173）...
cd /d "%~dp0frontend"
if not exist "node_modules" (
  echo 首次运行，安装依赖...
  call npm install --registry=https://registry.npmmirror.com --no-audit --no-fund
)
call npm run dev
pause
