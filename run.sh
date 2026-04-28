#!/bin/bash
set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
CONFIG_FILE="$SCRIPT_DIR/.env"
VENV_DIR="$SCRIPT_DIR/.venv"

# ========== Python 版本检测 ==========

# 获取 Python 解释器的版本号，返回 "major.minor" 或空字符串
get_python_version() {
    local py="$1"
    "$py" -c "import sys; print(f'{sys.version_info.major}.{sys.version_info.minor}')" 2>/dev/null || echo ""
}

# 比较版本号，返回 0 表示 >= 目标版本
version_gte() {
    [ "$(printf '%s\n' "$1" "$2" | sort -V | head -n1)" = "$2" ]
}

# 查找所有可用的 Python 3.10+ 解释器
find_python_interpreters() {
    local candidates=("python3" "python3.10" "python3.11" "python3.12" "python3.13" "python3.14")
    local found=()

    for py in "${candidates[@]}"; do
        if command -v "$py" &>/dev/null; then
            local ver
            ver=$(get_python_version "$py")
            if [ -n "$ver" ] && version_gte "$ver" "3.10"; then
                found+=("$py|$ver")
            fi
        fi
    done

    echo "${found[@]}"
}

# 选择 Python 解释器
select_python() {
    # 如果已有配置，直接使用
    if [ -f "$CONFIG_FILE" ] && grep -q "^PYTHON_CMD=" "$CONFIG_FILE"; then
        PYTHON_CMD=$(grep "^PYTHON_CMD=" "$CONFIG_FILE" | cut -d'=' -f2 | tr -d '"' | tr -d "'")
        if command -v "$PYTHON_CMD" &>/dev/null; then
            local ver
            ver=$(get_python_version "$PYTHON_CMD")
            echo "使用已配置的 Python: $PYTHON_CMD ($ver)"
            return 0
        else
            echo "已配置的 Python '$PYTHON_CMD' 不可用，重新选择..."
        fi
    fi

    echo ""
    echo "  正在检测 Python 版本（需要 3.10 以上）..."
    echo ""

    local interpreters
    interpreters=($(find_python_interpreters))

    if [ ${#interpreters[@]} -eq 0 ]; then
        echo "错误: 未找到 Python 3.10+ 解释器"
        echo "请先安装 Python 3.10 或更高版本"
        echo "  brew install python@3.11"
        echo "  或从 https://www.python.org/downloads/ 下载"
        exit 1
    fi

    local chosen=""

    if [ ${#interpreters[@]} -eq 1 ]; then
        # 只有一个选项，自动选择
        local entry="${interpreters[0]}"
        local py="${entry%%|*}"
        local ver="${entry##*|}"
        echo "  检测到 Python: $py ($ver)"
        chosen="$py"
    else
        # 多个选项，让用户选择
        echo "  检测到多个 Python 版本："
        echo ""
        local i=1
        for entry in "${interpreters[@]}"; do
            local py="${entry%%|*}"
            local ver="${entry##*|}"
            local path
            path=$(command -v "$py")
            echo "    [$i] $py  (Python $ver)  →  $path"
            ((i++))
        done
        echo ""
        read -rp "  请选择编号 [1]: " choice
        choice=${choice:-1}

        if [ "$choice" -ge 1 ] && [ "$choice" -le ${#interpreters[@]} ]; then
            local entry="${interpreters[$((choice-1))]}"
            chosen="${entry%%|*}"
        else
            echo "无效选择，使用第一个选项"
            chosen="${interpreters[0]%%|*}"
        fi
    fi

    PYTHON_CMD="$chosen"

    # 保存配置
    echo "PYTHON_CMD=$PYTHON_CMD" > "$CONFIG_FILE"
    echo ""
    echo "  已选择: $PYTHON_CMD ($(get_python_version "$PYTHON_CMD"))"
    echo "  配置已保存到 .env，下次运行将自动使用"
}

# ========== 主流程 ==========

select_python

# 自动创建虚拟环境
if [ ! -f "$VENV_DIR/bin/python" ]; then
    echo ""
    echo "  首次运行，正在创建虚拟环境..."
    "$PYTHON_CMD" -m venv "$VENV_DIR"
fi

VENV_PYTHON="$VENV_DIR/bin/python"
VENV_PIP="$VENV_DIR/bin/pip"

# 自动安装依赖
if ! "$VENV_PYTHON" -c "import flask" 2>/dev/null; then
    echo "  正在安装依赖（首次可能需要几分钟）..."
    "$VENV_PIP" install -r "$SCRIPT_DIR/requirements.txt"
fi

PORT="${PORT:-5001}"
URL="http://localhost:$PORT"

echo ""
echo "========================================="
echo "  MarkItDown Web Converter"
echo "  $URL"
echo "========================================="
echo ""

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
