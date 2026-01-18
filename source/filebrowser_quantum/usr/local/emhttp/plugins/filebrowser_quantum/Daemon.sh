#!/bin/bash
# ===========================================================
# FileBrowser Quantum Daemon Script
# 安全加固版本 - 引入路径验证与命令注入防护
# ===========================================================

# --- 0. 安全预检与变量验证 ---
CONF_FILE="/usr/local/emhttp/plugins/filebrowser_quantum/paths.conf"

# 验证配置文件存在且可读
if [ ! -f "$CONF_FILE" ] || [ ! -r "$CONF_FILE" ]; then
    echo "错误：配置文件不存在或无权读取: $CONF_FILE" >&2
    exit 1
fi

# 引入全局变量路径
source "$CONF_FILE"

# 定义安全的路径白名单前缀
ALLOWED_BINARY_PREFIX="/usr/sbin/filebrowser_quantum"
ALLOWED_PLG_PREFIX="/boot/config/plugins/filebrowser_quantum"
ALLOWED_EMHTTP_PREFIX="/usr/local/emhttp/plugins/filebrowser_quantum"

# 验证函数：检查路径是否以允许的前缀开头
validate_path() {
    local path="$1"
    local prefix="$2"
    local var_name="$3"
    
    # 规范化路径（去除末尾斜杠，解析相对路径）
    local normalized_path
    normalized_path=$(realpath -m "$path" 2>/dev/null) || normalized_path="$path"
    
    if [[ ! "$normalized_path" =~ ^${prefix} ]]; then
        echo "安全错误：$var_name 路径验证失败 ($normalized_path 不匹配 $prefix)" | logger -t "FileBrowser-Security"
        exit 1
    fi
}

# 验证关键路径变量
validate_path "$BINARY" "$ALLOWED_BINARY_PREFIX" "BINARY"
validate_path "$CONFIG_YAML" "$ALLOWED_PLG_PREFIX" "CONFIG_YAML"
validate_path "$SETTINGS_FILE" "$ALLOWED_PLG_PREFIX" "SETTINGS_FILE"
validate_path "$INSTALL_PATH" "$ALLOWED_PLG_PREFIX" "INSTALL_PATH"
validate_path "$DAEMON_SCRIPT" "$ALLOWED_EMHTTP_PREFIX" "DAEMON_SCRIPT"

# 安全提取二进制文件名（避免命令注入）
# 仅允许字母、数字、下划线和点
BINARY_NAME=$(basename "$BINARY")
if [[ ! "$BINARY_NAME" =~ ^[a-zA-Z0-9._-]+$ ]]; then
    echo "安全错误：BINARY 文件名包含非法字符: $BINARY_NAME" | logger -t "FileBrowser-Security"
    exit 1
fi

# --- 统一日志函数 ---
# 用法: log_msg "级别" "消息"
# 级别: info, warn, error, success
log_msg() {
    local level="${1:-info}"
    local msg="$2"
    local color=""
    local prefix=""
    
    case "$level" in
        info)    prefix="[INFO]";    color="" ;;
        warn)    prefix="[WARN]";    color="\e[33m" ;;
        error)   prefix="[ERROR]";   color="\e[41m" ;;
        success) prefix="[OK]";      color="\e[32m" ;;
        *)       prefix="[LOG]";     color="" ;;
    esac
    
    # 输出到终端（带颜色）和 syslog
    if [ -n "$color" ]; then
        echo -e "${color}${prefix} ${msg}\e[0m" | tee >(logger -t "$TAG" -p "local0.${level}")
    else
        echo "${prefix} ${msg}" | tee >(logger -t "$TAG")
    fi
    else
        echo "${prefix} ${msg}" | tee >(logger -t "$TAG")
    fi
}

# 辅助函数：获取配置端口
get_config_port() {
    if [ -f "$CONFIG_YAML" ]; then
        local port=$(grep -E '^port:|^  port:' "$CONFIG_YAML" | head -n 1 | awk -F: '{print $2}' | tr -d '" ' | tr -d "'")
        echo "${port:-${DEFAULT_PORT:-8081}}"
    else
        echo "${DEFAULT_PORT:-8081}"
    fi
}

# --- 1. 处理启动逻辑 (true 或 START_ONLY) ---
if [ "${1}" == "true" ] || [ "${1}" == "START_ONLY" ]; then
    echo "FileBrowser 准备启动" | tee >(logger -t "$TAG")
    
    # 只有当参数是用户手动触发的 "true" 时，才修改配置文件
    if [ "${1}" == "true" ]; then
            sed -i "/filebrowser_ENABLED=/c\filebrowser_ENABLED=true" "$SETTINGS_FILE"
        fi
    
    # 检查进程是否已在运行，防止重复启动
    if pgrep -f "$(basename "$BINARY")" > /dev/null 2>&1 ; then
        echo "FileBrowser 已经在运行！" | tee >(logger -t "$TAG")
        exit 0
    fi

    echo "FileBrowser 正在启动中..." | tee >(logger -t "$TAG")
    echo "$BINARY -c $CONFIG_YAML" | at now -M > /dev/null 2>&1

    # 循环检测启动结果（使用 paths.conf 中的常量）
    for i in $(seq 1 ${STARTUP_CHECK_RETRIES:-5}); do
        sleep ${STARTUP_CHECK_INTERVAL:-1}
        if pgrep -f "$(basename "$BINARY")" > /dev/null 2>&1 ; then
            echo "FileBrowser 启动成功！" | tee >(logger -t "$TAG")
            exit 0
        fi
    done
    echo ""
    echo -e "\e[41m FileBrowser 启动失败 , 请检查设置和日志 . \e[0m" | tee >(logger -t "$TAG")
    exit 1

# --- 2. 处理停止逻辑 (false 或 STOP_ONLY) ---
elif [ "${1}" == "false" ] || [ "${1}" == "STOP_ONLY" ]; then
    echo "正在停止 FileBrowser..." | tee >(logger -t "$TAG")
    
    # 停止进程
    pkill -9 -f "$(basename "$BINARY")"
    
    # 只有当参数是用户手动触发的 "false" 时，才将使能设为禁用
    if [ "${1}" == "false" ]; then
        echo "用户手动关闭服务，正在更新配置..." | tee >(logger -t "$TAG")
        sed -i "/filebrowser_ENABLED=/c\filebrowser_ENABLED=false" "$SETTINGS_FILE"
    fi
    
  echo "FileBrowser 已停止" | tee >(logger -t "$TAG")
  exit 0

# --- 3. 获取端口 (供 WebUI 按钮使用) ---
elif [ "${1}" == "GET_PORT" ]; then
    get_config_port
    exit 0

# --- 3.1 健康检查 ---
elif [ "${1}" == "HEALTH_CHECK" ]; then
    PORT=$(get_config_port)
    # 尝试访问根路径，只检查 HTTP 状态码是否为 200-399
    # -s: 静默模式
    # -o /dev/null: 丢弃输出
    # -w "%{http_code}": 只输出状态码
    HTTP_CODE=$(curl -s -o /dev/null -w "%{http_code}" "http://127.0.0.1:$PORT")
    
    if [[ "$HTTP_CODE" =~ ^2[0-9][0-9]$ ]] || [[ "$HTTP_CODE" =~ ^3[0-9][0-9]$ ]]; then
        echo "Healthy (HTTP $HTTP_CODE)"
        exit 0
    else
        echo "Unhealthy (HTTP $HTTP_CODE)"
        exit 1
    fi

# --- 4. 获取本地版本号 ---
elif [ "${1}" == "GET_LOCAL_VER" ]; then
    if [ -f "$BINARY" ]; then
        "$BINARY" version | grep "Version" | cut -d':' -f2 | tr -d ' '
    else
        echo "not installed"
    fi
    exit 0

# --- 5. 获取远程版本号并更新缓存 ---
elif [ "${1}" == "VERSION" ]; then
    [ ! -d "$INSTALL_PATH" ] && mkdir -p "$INSTALL_PATH"
    TAG_LIST=$(curl -s "https://api.github.com/repos/$GITHUB_REPO/tags" | grep '"name":' | head -n 10)
    # 3. 获取具体版本号 beta/stable
    if [ -f "$BETA_MARKER" ]; then
        LAT_V=$(echo "$TAG_LIST" | grep -oE 'v[0-9]+\.[0-9]+\.[0-9]+-beta' | head -n 1)
    else
        LAT_V=$(echo "$TAG_LIST" | grep -oE 'v[0-9]+\.[0-9]+\.[0-9]+-stable' | head -n 1)
    fi
    # 4. 写入到latest文件
    if [ -n "$LAT_V" ]; then
        echo "$LAT_V" > "$LATEST_MARKER"
        
        # 同时同步到 settings.cfg 缓存 (这是为了配合 page 页面的初次加载优化)
        # 修正：如果 settings.cfg 里还没这一行，sed 会失败。这里先检查。
        [ ! -f "$SETTINGS_FILE" ] && touch "$SETTINGS_FILE"
        if grep -q "filebrowser_LATEST=" "$SETTINGS_FILE"; then
            sed -i "/filebrowser_LATEST=/c\filebrowser_LATEST=\"${LAT_V}\"" "$SETTINGS_FILE"
        else
            echo "filebrowser_LATEST=\"${LAT_V}\"" >> "$SETTINGS_FILE"
        fi

        # --- 核心：这是给 ajax_version.php 看的 ---
        echo "$LAT_V"
        exit 0
    else
        # 必须输出 Unknown，否则 PHP 的 trim(shell_exec()) 会拿到空，从而触发兜底逻辑
        echo "Unknown"
        exit 1
    fi
fi
