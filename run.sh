#!/bin/bash
set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
VENV_DIR="$SCRIPT_DIR/.venv"
VENV_PYTHON="$VENV_DIR/bin/python"
VENV_PIP="$VENV_DIR/bin/pip"

# 自动创建虚拟环境
if [ ! -f "$VENV_PYTHON" ]; then
    echo "首次运行，正在创建虚拟环境..."
    python3 -m venv "$VENV_DIR"
fi

# 自动安装依赖
if ! "$VENV_PYTHON" -c "import flask" 2>/dev/null; then
    echo "正在安装依赖..."
    "$VENV_PIP" install -r "$SCRIPT_DIR/requirements.txt"
fi

PORT="${PORT:-5001}"
URL="http://localhost:$PORT"

echo "========================================="
echo "  MarkItDown Web Converter"
echo "  $URL"
echo "========================================="

# 后台启动 Flask 服务
"$VENV_PYTHON" "$SCRIPT_DIR/app.py" --port "$PORT" &
APP_PID=$!

# 等待服务就绪
sleep 1

# 自动打开浏览器 (macOS)
if command -v open &>/dev/null; then
    open "$URL"
fi

# 等待服务进程结束
wait $APP_PID
