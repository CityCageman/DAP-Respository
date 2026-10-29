@echo off
chcp 65001 >nul
title DataAsset Platform - Backend (8080)
echo 启动后端 Spring Boot（端口 8080）...
cd /d "%~dp0backend"
if not exist "target\asset-platform-1.0.0.jar" (
  echo 未找到 jar，先执行打包...
  call set JAVA_HOME=D:\Program\JavaProgram\jdk-21
  call D:\Program\JavaProgram\maven-3.9.16\bin\mvn.cmd -B -DskipTests package
)
"D:\Program\JavaProgram\jdk-21\bin\java.exe" -Dserver.port=8080 -jar "target\asset-platform-1.0.0.jar"
pause
