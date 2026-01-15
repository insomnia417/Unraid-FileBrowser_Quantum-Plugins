#!/bin/bash
# Version: v4.0 (Enhanced Stability)

# --- 1. 防呆检查 (第3点详细描述) ---
CONF_PATH="/usr/local/emhttp/plugins/filebrowser_quantum/paths.conf"

# 检查仓库文件是否存在
if [ ! -f "$CONF_PATH" ]; then
    echo "<font color='red'>错误：找不到关键配置文件 $CONF_PATH</font>"
    echo "请重新安装插件或检查文件系统。"
    exit 1
fi

# 引入paths.conf变量
source "$CONF_PATH"
# --------------------------------

# 【逻辑复用】从最新的版本记录文件中获取目标版本号,该文件由 WebUI 触发更新分支时自动生成
current_version=$(head -n 1 "$LATEST_MARKER" 2>/dev/null)

# 获取目标版本号. 容错：如果获取不到版本号则退出
if [ -z "$current_version" ]; then
    echo "<font color='red'>错误：无法读取目标版本号，请检查 $LATEST_MARKER</font>"
    exit 1
fi

INSTALLED_BINARY="$INSTALL_PATH/filebrowser_quantum-$current_version"
DOWNLOAD_URL="https://github.com/gtsteffaniak/filebrowser/releases/download/$current_version/linux-amd64-filebrowser"

echo "-------------------------------------------------------------------"
echo "正在执行更新：$current_version"
echo "-------------------------------------------------------------------"

# 3. 【执行安装】
if ping -q -c1 github.com >/dev/null; then
    # 如果本地没有该版本的备份，则下载
    if [ ! -f "$INSTALLED_BINARY" ]; then
        echo "正在从 GitHub 下载新版本..."
        curl --connect-timeout 15 --retry 3 --retry-delay 2 -L -o "$INSTALLED_BINARY" --create-dirs "$DOWNLOAD_URL"
    fi

    # 【关键】先停止服务，解决“Text file busy”文件锁定问题
    echo "正在停止服务并替换文件..."
    # 极致优化：精确等待进程退出，最多等5秒
    MAX_WAIT=5
    while [ $MAX_WAIT -gt 0 ] && pgrep -f "$(basename "$BINARY")" >/dev/null; do
        sleep 1
        ((MAX_WAIT--))
    done
    # 暴力清理残留进程（保险措施）
    pkill -9 -f "$(basename "$BINARY")" >/dev/null 2>&1

    # 获取旧二进制文件的权限和归属（如果存在的话）
    if [ -f "$BINARY" ]; then
        OLD_PERM=$(stat -c "%a" "$BINARY")
        OLD_OWNER=$(stat -c "%U:%G" "$BINARY")
    else
        OLD_PERM="755"
        OLD_OWNER="root:root"
    fi
    
    # 执行替换
    cp -f "$INSTALLED_BINARY" "$BINARY"
    
    # 还原（或设置）权限和归属
    chown $OLD_OWNER "$BINARY"
    chmod $OLD_PERM "$BINARY"

    # 重新启动服务
    echo "更新完成，正在重启服务..."
    bash "$DAEMON_SCRIPT" "true" >/dev/null 2>&1
else
    echo "<font color='red'>网络错误：无法连接 GitHub</font>"
    exit 1
fi

# 4. 【验证复用】直接调用 Daemon.sh 中你写好的 GET_LOCAL_VER 逻辑
# 这样能保证 WebUI 上的显示和升级日志里的校验完全一致
installed_ver_now=$(bash "$DAEMON_SCRIPT" "GET_LOCAL_VER")

if [ "$installed_ver_now" == "$current_version" ]; then
    echo ""
    echo "-------------------------------------------------------------------"
    echo "验证成功：filebrowser_quantum 已成功更新为 $installed_ver_now"
    echo "-------------------------------------------------------------------"
else
    echo ""
    echo "-------------------------------------------------------------------"
    echo "<font color='red'>验证失败：</font>"
    echo "期待版本: $current_version"
    echo "实际运行: $installed_ver_now"
    echo "-------------------------------------------------------------------"
    exit 1
fi
