#!/bin/bash
# Version: v2.4

# 1. 【变量复用】引入 base.php 定义，确保路径统一
eval $(php -r '
    require_once "/usr/local/emhttp/plugins/filebrowser_quantum/base.php";
    echo "BETA_MARKER=$BETA_MARKER\n";
    echo "LATEST_FILE=$LATEST_FILE\n";
')

DAEMON_SCRIPT="/usr/local/emhttp/plugins/filebrowser_quantum/Daemon.sh"
RUNNING_BINARY="/usr/sbin/filebrowser_quantumorig"
INSTALL_DIR="/boot/config/plugins/filebrowser_quantum/install"

# 2. 【逻辑复用】直接从 Daemon 维护的 latest 文件获取目标版本
# 这是在 WebUI 切换分支时已经由 ajax_version.php 更新过的
current_version=$(head -n 1 "$LATEST_FILE")

if [ -z "$current_version" ]; then
    echo "错误：无法从 $LATEST_FILE 获取目标版本号"
    exit 1
fi

INSTALLED_BINARY="$INSTALL_DIR/filebrowser_quantum-$current_version"
DOWNLOAD_URL="https://github.com/gtsteffaniak/filebrowser/releases/download/$current_version/linux-amd64-filebrowser"

echo "-------------------------------------------------------------------"
echo "正在准备更新至: $current_version"
echo "-------------------------------------------------------------------"

# 3. 执行更新
if ping -q -c1 github.com >/dev/null; then
    # 下载新版本
    if [ ! -f "$INSTALLED_BINARY" ]; then
        echo "正在下载..."
        curl --connect-timeout 15 --retry 3 --retry-delay 2 -L -o "$INSTALLED_BINARY" --create-dirs "$DOWNLOAD_URL"
    fi

    # 【核心修正】调用 Daemon.sh 停止服务，解除文件占用
    echo "正在停止服务..."
    $DAEMON_SCRIPT "false" >/dev/null 2>&1
    sleep 2

    # 替换文件
    echo "应用二进制文件..."
    cp -f "$INSTALLED_BINARY" "$RUNNING_BINARY"
    chown root:root "$RUNNING_BINARY"
    chmod 755 "$RUNNING_BINARY"

    # 调用 Daemon.sh 重启服务
    echo "正在重启服务..."
    $DAEMON_SCRIPT "true" >/dev/null 2>&1
else
    echo "<font color='red'>无法连接网络</font>"
    exit 1
fi

# 4. 【验证复用】直接调用 Daemon.sh 的 GET_LOCAL_VER 逻辑
# 这是最稳妥的，因为 Daemon 已经处理好了所有空格和前缀
installed_ver_now=$($DAEMON_SCRIPT "GET_LOCAL_VER")

if [ "$installed_ver_now" == "$current_version" ]; then
    echo ""
    echo "-------------------------------------------------------------------"
    echo "验证成功：当前运行版本为 $installed_ver_now"
    echo "-------------------------------------------------------------------"
else
    echo ""
    echo "-------------------------------------------------------------------"
    echo "<font color='red'>验证失败：</font>"
    echo "目标版本: $current_version"
    echo "实际运行: $installed_ver_now"
    echo "-------------------------------------------------------------------"
    exit 1
fi
