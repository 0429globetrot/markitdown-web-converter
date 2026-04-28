@echo off
chcp 65001 >nul 2>&1
setlocal enabledelayedexpansion

set "SCRIPT_DIR=%~dp0"
set "VENV_DIR=%SCRIPT_DIR%.venv"
set "CONFIG_FILE=%SCRIPT_DIR%.env"
set "REQ_FILE=%SCRIPT_DIR%requirements.txt"

:: ========== 读取已保存的 Python 配置 ==========
set "PYTHON_CMD="

if exist "%CONFIG_FILE%" (
    for /f "usebackq tokens=1,* delims==" %%a in ("%CONFIG_FILE%") do (
        if "%%a"=="PYTHON_CMD" set "PYTHON_CMD=%%b"
    )
    if defined PYTHON_CMD (
        echo 使用已配置的 Python: !PYTHON_CMD!
        goto :check_venv
    )
)

:: ========== 检测 Python 版本 ==========

echo.
echo   正在检测 Python 版本（需要 3.10 以上）...
echo.

:: 优先使用 py launcher (Windows 推荐方式)
where py >nul 2>&1
if !errorlevel!==0 (
    for /f "tokens=2 delims= " %%v in ('py -3.10 -c "import sys; print(sys.version)" 2^>nul') do (
        set "PYTHON_CMD=py -3.10"
        goto :found_python
    )
    for /f "tokens=2 delims= " %%v in ('py -3.11 -c "import sys; print(sys.version)" 2^>nul') do (
        set "PYTHON_CMD=py -3.11"
        goto :found_python
    )
    for /f "tokens=2 delims= " %%v in ('py -3.12 -c "import sys; print(sys.version)" 2^>nul') do (
        set "PYTHON_CMD=py -3.12"
        goto :found_python
    )
    for /f "tokens=2 delims= " %%v in ('py -3.13 -c "import sys; print(sys.version)" 2^>nul') do (
        set "PYTHON_CMD=py -3.13"
        goto :found_python
    )
    for /f "tokens=2 delims= " %%v in ('py -3 -c "import sys; print(sys.version)" 2^>nul') do (
        set "PYTHON_CMD=py -3"
        goto :found_python
    )
)

:: 尝试 python3 命令
where python3 >nul 2>&1
if !errorlevel!==0 (
    for /f "tokens=1,2 delims=." %%a in ('python3 -c "import sys; print(f"{sys.version_info.major}.{sys.version_info.minor}")" 2^>nul') do (
        if %%a GEQ 3 (
            if %%b GEQ 10 (
                set "PYTHON_CMD=python3"
                goto :found_python
            )
        )
    )
)

:: 尝试 python 命令
where python >nul 2>&1
if !errorlevel!==0 (
    for /f "tokens=1,2 delims=." %%a in ('python -c "import sys; print(f"{sys.version_info.major}.{sys.version_info.minor}")" 2^>nul') do (
        if %%a GEQ 3 (
            if %%b GEQ 10 (
                set "PYTHON_CMD=python"
                goto :found_python
            )
        )
    )
)

echo 错误: 未找到 Python 3.10+ 解释器
echo 请先安装 Python 3.10 或更高版本
echo 下载地址: https://www.python.org/downloads/
pause
exit /b 1

:found_python
echo   检测到: %PYTHON_CMD%
echo PYTHON_CMD=%PYTHON_CMD%>"%CONFIG_FILE%"
echo   配置已保存到 .env

:: ========== 创建虚拟环境 ==========
:check_venv

set "VENV_PYTHON=%VENV_DIR%\Scripts\python.exe"
set "VENV_PIP=%VENV_DIR%\Scripts\pip.exe"

if not exist "%VENV_PYTHON%" (
    echo.
    echo   首次运行，正在创建虚拟环境...
    %PYTHON_CMD% -m venv "%VENV_DIR%"
)

:: ========== 安装依赖 ==========
"%VENV_PYTHON%" -c "import flask" >nul 2>&1
if !errorlevel! NEQ 0 (
    echo   正在安装依赖（首次可能需要几分钟）...
    "%VENV_PIP%" install -r "%REQ_FILE%"
)

:: ========== 启动服务 ==========
set "PORT=5001"
if defined PORT set "PORT=%PORT%"
set "URL=http://localhost:%PORT%"

echo.
echo =========================================
echo   MarkItDown Web Converter
echo   %URL%
echo =========================================
echo.

start "" "%URL%"
"%VENV_PYTHON%" "%SCRIPT_DIR%app.py" --port %PORT%

pause
