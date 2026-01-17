#!/bin/bash
# 引入全局变量路径
source /usr/local/emhttp/plugins/filebrowser_quantum/paths.conf

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

    # 循环检测启动结果
    for i in {1..5}; do
        sleep 1
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
