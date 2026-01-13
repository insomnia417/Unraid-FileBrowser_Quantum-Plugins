#!/bin/bash
# Version: v2.5

# 1. 【变量与环境复用】
# 强制定义插件基础路径，确保在 at 或 openBox 异步环境下也能找到 base.php
PLUGIN_PATH="/usr/local/emhttp/plugins/filebrowser_quantum"
eval $(php -r "require_once '$PLUGIN_PATH/base.php'; echo \"BETA_MARKER=\$BETA_MARKER\nLATEST_FILE=\$LATEST_FILE\n\";")

DAEMON_SCRIPT="$PLUGIN_PATH/Daemon.sh"
RUNNING_BINARY="/usr/sbin/filebrowser_quantumorig"
# 确保安装目录变量准确
INSTALL_DIR="/boot/config/plugins/filebrowser_quantum/install"

# 2. 【获取目标】
current_version=$(head -n 1 "$LATEST_FILE" 2>/dev/null)
[ -z "$current_version" ] && echo "错误：无法获取目标版本号" && exit 1

INSTALLED_BINARY="$INSTALL_DIR/filebrowser_quantum-$current_version"
DOWNLOAD_URL="https://github.com/gtsteffaniak/filebrowser/releases/download/$current_version/linux-amd64-filebrowser"

echo "-------------------------------------------------------------------"
echo "正在执行更新流程..."
echo "目标版本: $current_version"
echo "-------------------------------------------------------------------"

# 3. 【下载与替换】
if ping -q -c1 github.com >/dev/null; then
    # 即使文件存在也重新下载，确保文件完整性
    echo "正在下载二进制文件..."
    curl --connect-timeout 15 --retry 3 --retry-delay 2 -L -o "$INSTALLED_BINARY" --create-dirs "$DOWNLOAD_URL"
    
    # 【关键】停止服务并强制杀死进程，确保文件不被占用
    echo "正在停止服务..."
    bash "$DAEMON_SCRIPT" "false" >/dev/null 2>&1
    pkill -9 -f "filebrowser_quantumorig" >/dev/null 2>&1
    sleep 2

    # 执行覆盖
    echo "正在覆盖系统二进制文件..."
    cp -f "$INSTALLED_BINARY" "$RUNNING_BINARY"
    chown root:root "$RUNNING_BINARY"
    chmod 755 "$RUNNING_BINARY"

    # 启动服务
    echo "正在重启服务..."
    bash "$DAEMON_SCRIPT" "true" >/dev/null 2>&1
else
    echo "<font color='red'>网络错误：无法连接 GitHub</font>"
    exit 1
fi

# 4. 【验证逻辑修正】
# 不再直接拿 Daemon 的输出比对，因为 version 输出有多行
# 我们手动执行提取，确保拿到的只是 "v1.1.6-beta" 这一串字符
installed_ver_now=$($RUNNING_BINARY version | grep "Version" | cut -d':' -f2 | tr -d ' ')

if [ "$installed_ver_now" == "$current_version" ]; then
    echo ""
    echo "-------------------------------------------------------------------"
    echo "验证成功：filebrowser_quantum 已更新为 $installed_ver_now"
    echo "-------------------------------------------------------------------"
else
    echo ""
    echo "-------------------------------------------------------------------"
    echo "<font color='red'>验证失败：</font>"
    echo "期望: $current_version"
    echo "实际: $installed_ver_now"
    echo "-------------------------------------------------------------------"
    exit 1
fi
