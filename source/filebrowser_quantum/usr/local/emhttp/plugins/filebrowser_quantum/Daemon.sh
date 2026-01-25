#!/bin/bash
# 引入全局变量路径
source /usr/local/emhttp/plugins/filebrowser_quantum/paths.conf

# === 辅助函数：读取 settings.cfg 的值 ===
get_setting() {
    local key="$1"
    local default="$2"
    if [ -f "$SETTINGS_FILE" ]; then
        local val=$(grep "^${key}=" "$SETTINGS_FILE" | cut -d'=' -f2 | tr -d '"')
        echo "${val:-$default}"
    else
        echo "$default"
    fi
}

# === 辅助函数：写入 settings.cfg 的值 ===
set_setting() {
    local key="$1"
    local value="$2"
    [ ! -f "$SETTINGS_FILE" ] && touch "$SETTINGS_FILE"
    
    if grep -q "^${key}=" "$SETTINGS_FILE"; then
        sed -i "/^${key}=/c\\${key}=\"${value}\"" "$SETTINGS_FILE"
    else
        echo "${key}=\"${value}\"" >> "$SETTINGS_FILE"
    fi
}

# --- 1. 处理启动逻辑 (true 或 START_ONLY) ---
if [ "${1}" == "true" ] || [ "${1}" == "START_ONLY" ]; then
    echo "FileBrowser 准备启动" | tee >(logger -t "$TAG")
    
    # 修改使能配置
    if [ "${1}" == "true" ]; then
        set_setting "filebrowser_ENABLED" "true"
    fi
    
    # 检查进程：使用精准命令名匹配，杜绝匹配脚本名
    if /usr/bin/pgrep -x "$(basename "$BINARY")" > /dev/null 2>&1 ; then
        echo "FileBrowser 已经在运行！" | tee >(logger -t "$TAG")
        exit 0
    fi

    echo "FileBrowser 正在启动中..." | tee >(logger -t "$TAG")
    echo "$BINARY -c $CONFIG_YAML" | at now -M > /dev/null 2>&1

    # 5秒检测循环
    for i in {1..5}; do
        sleep 1
        if /usr/bin/pgrep -x "$(basename "$BINARY")" > /dev/null 2>&1 ; then
            # 找到进程后，额外等待 2 秒确认其没有瞬间崩溃 (针对 YAML 报错场景)
            sleep 2
            if /usr/bin/pgrep -x "$(basename "$BINARY")" > /dev/null 2>&1 ; then
                echo "FileBrowser 启动成功并通过稳定性检查！" | tee >(logger -t "$TAG")
                exit 0
            fi
        fi
    done
    
    echo -e "\e[41m FileBrowser 启动失败 , 请检查设置和日志 . \e[0m" | tee >(logger -t "$TAG")
    exit 1

# --- 2. 处理停止逻辑 (false 或 STOP_ONLY) ---
elif [ "${1}" == "false" ] || [ "${1}" == "STOP_ONLY" ]; then
    echo "正在停止 FileBrowser..." | tee >(logger -t "$TAG")
    
    # 物理停止：精准打击
    /usr/bin/pkill -9 -x "$(basename "$BINARY")" > /dev/null 2>&1
    
    # 等待消失 (最多 3 秒)
    for i in {1..6}; do
        if ! /usr/bin/pgrep -x "$(basename "$BINARY")" > /dev/null 2>&1 ; then
            break
        fi
        sleep 0.5
    done
    
    if [ "${1}" == "false" ]; then
        set_setting "filebrowser_ENABLED" "false"
    fi
    exit 0

# --- 3. 获取端口 ---
elif [ "${1}" == "GET_PORT" ]; then
    if [ -f "$CONFIG_YAML" ]; then
        PORT=$(grep -E '^port:|^  port:' "$CONFIG_YAML" | head -n 1 | awk -F: '{print $2}' | tr -d '" ' | tr -d "'")
        echo "${PORT:-8081}"
    else
        echo "8081"
    fi
    exit 0

# --- 4. 获取本地版本号 ---
elif [ "${1}" == "GET_LOCAL_VER" ]; then
    if [ -f "$BINARY" ]; then
        "$BINARY" version | grep "Version" | cut -d':' -f2 | tr -d ' ' 2>/dev/null
    else
        echo "not installed"
    fi
    exit 0

# --- 5. 获取远程版本号并更新缓存 ---
elif [ "${1}" == "VERSION" ]; then
    [ ! -d "$INSTALL_PATH" ] && mkdir -p "$INSTALL_PATH"
    TAG_LIST=$(curl -s "https://api.github.com/repos/$GITHUB_REPO/tags" | grep '"name":' | head -n 10)
    
    BRANCH=$(get_setting "filebrowser_BRANCH" "stable")
    
    if [ "$BRANCH" == "beta" ]; then
        LAT_V=$(echo "$TAG_LIST" | grep -oE 'v[0-9]+\.[0-9]+\.[0-9]+-beta' | head -n 1)
    else
        LAT_V=$(echo "$TAG_LIST" | grep -oE 'v[0-9]+\.[0-9]+\.[0-9]+-stable' | head -n 1)
    fi
    
    if [ -n "$LAT_V" ]; then
        set_setting "filebrowser_LATEST" "$LAT_V"
        echo "$LAT_V"
        exit 0
    else
        echo "Unknown"
        exit 1
    fi

# --- 6. 设置分支 ---
elif [ "${1}" == "SET_BRANCH" ]; then
    if [ "${2}" == "beta" ] || [ "${2}" == "stable" ]; then
        set_setting "filebrowser_BRANCH" "${2}"
        exit 0
    else
        exit 1
    fi

# --- 7. 获取分支 ---
elif [ "${1}" == "GET_BRANCH" ]; then
    get_setting "filebrowser_BRANCH" "stable"
    exit 0

# --- 7. 获取状态 (全插件统一接口) ---
elif [ "${1}" == "CHECK" ]; then
    if /usr/bin/pgrep -f "^$BINARY" > /dev/null 2>&1 ; then
        echo "running"
        exit 0
    else
        echo "stopped"
        exit 1
    fi

# --- 8. 重启服务 (用于 SAVE 操作) ---
elif [ "${1}" == "RESTART" ]; then
    # 不调用 $0，直接调用内部逻辑分支更可靠
    /bin/bash "$DAEMON_SCRIPT" "STOP_ONLY"
    /bin/bash "$DAEMON_SCRIPT" "START_ONLY"
    exit $?

fi
