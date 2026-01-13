#!/bin/bash
# Version: v2.7

# 1. 【变量复用】通过 php 加载 base.php 确保路径和 WebUI 严格一致
PLUGIN_PATH="/usr/local/emhttp/plugins/filebrowser_quantum"
eval $(php -r "require_once '$PLUGIN_PATH/base.php'; echo \"LATEST_FILE=\$LATEST_FILE\n\";")

DAEMON_SCRIPT="$PLUGIN_PATH/Daemon.sh"
RUNNING_BINARY="/usr/sbin/filebrowser_quantumorig"
INSTALL_DIR="/boot/config/plugins/filebrowser_quantum/install"

# 2. 【获取目标版本】从 latest 文件读取
current_version=$(head -n 1 "$LATEST_FILE" 2>/dev/null)
if [ -z "$current_version" ]; then
    echo "错误：无法读取目标版本号，请检查 $LATEST_FILE"
    exit 1
fi

INSTALLED_BINARY="$INSTALL_DIR/filebrowser_quantum-$current_version"
DOWNLOAD_URL="https://github.com/gtsteffaniak/filebrowser/releases/download/$current_version/linux-amd64-filebrowser"

echo "-------------------------------------------------------------------"
echo "发现新版本: $current_version 下载安装中..."
echo "-------------------------------------------------------------------"

# 3. 【核心安装逻辑】
if ping -q -c1 github.com >/dev/null; then
    # 下载文件 (如果不存在)
    if [ ! -f "$INSTALLED_BINARY" ]; then
        curl --connect-timeout 15 --retry 3 --retry-delay 2 -L -o "$INSTALLED_BINARY" --create-dirs "$DOWNLOAD_URL"
    fi

    # 【关键：解除锁定】先调用 Daemon 停止，再强行杀掉残留进程
    echo "停止服务并解除文件锁定..."
    bash "$DAEMON_SCRIPT" "false" >/dev/null 2>&1
    pkill -9 -f "filebrowser_quantumorig" >/dev/null 2>&1
    sleep 2

    # 执行物理替换
    cp -f "$INSTALLED_BINARY" "$RUNNING_BINARY"
    chown root:root "$RUNNING_BINARY"
    chmod 755 "$RUNNING_BINARY"

    # 重新启动服务
    echo "正在重启服务..."
    bash "$DAEMON_SCRIPT" "true" >/dev/null 2>&1
else
    echo "<font color='red'>网络连接失败，无法访问 GitHub</font>"
    exit 1
fi

# 4. 【验证逻辑修正：核心所在】
# 不能直接用 head -n 1，必须用 grep 定位到包含 "Version" 的那一行
# 我们直接复用你 Daemon.sh 里的逻辑，确保两边提取结果一致
installed_ver_now=$($RUNNING_BINARY version 2>/dev/null | grep "Version" | cut -d':' -f2 | tr -d ' ')

if [ "$installed_ver_now" == "$current_version" ]; then
    echo ""
    echo "-------------------------------------------------------------------"
    echo "验证成功：filebrowser_quantum 已成功更新为 $installed_ver_now"
    echo "-------------------------------------------------------------------"
else
    echo ""
    echo "-------------------------------------------------------------------"
    echo "<font color='red'>升级失败：当前版本 ($installed_ver_now) 与目标版本 ($current_version) 不符</font>"
    echo "-------------------------------------------------------------------"
    # 如果是因为提取到的变量依然带杂质，可以在这里输出所有行进行调试
    # $RUNNING_BINARY version
    exit 1
fi
