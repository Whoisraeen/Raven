@echo off
REM raven.bat — Windows wrapper for the Raven CLI
REM Delegates to the bash script via Git Bash

setlocal
set "SCRIPT_DIR=%~dp0"

REM Try Git Bash first
where bash >nul 2>&1
if %errorlevel% equ 0 (
    bash "%SCRIPT_DIR%raven" %*
    exit /b %errorlevel%
)

REM Fallback: try WSL
where wsl >nul 2>&1
if %errorlevel% equ 0 (
    wsl bash "%SCRIPT_DIR%raven" %*
    exit /b %errorlevel%
)

echo Error: bash not found. Install Git for Windows or WSL.
exit /b 1
