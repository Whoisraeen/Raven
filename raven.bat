@echo off
REM raven.bat — Windows wrapper for the Raven CLI
REM Prefers Node.js CLI, falls back to bash script

setlocal
set "SCRIPT_DIR=%~dp0"

REM Prefer Node.js CLI (works natively on Windows without bash)
where node >nul 2>&1
if %errorlevel% equ 0 (
    if exist "%SCRIPT_DIR%cli\bin\raven.js" (
        node "%SCRIPT_DIR%cli\bin\raven.js" %*
        exit /b %errorlevel%
    )
)

REM Fallback: try Git Bash
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

echo Error: Neither Node.js nor bash found. Install Node.js or Git for Windows.
exit /b 1
