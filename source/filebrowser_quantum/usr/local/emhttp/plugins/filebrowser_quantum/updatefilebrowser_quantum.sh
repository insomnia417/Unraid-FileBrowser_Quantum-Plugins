#!/bin/bash
# Version: v2.3

# 1. 【变量复用】直接引入 base.php 中的变量定义
# 我们通过 PHP 解析 base.php 获取变量，确保路径与插件全局统一
eval $(php -r '
    require_once "/usr/local/emhttp/plugins/filebrowser_quantum/base.php";
    echo "BETA_MARKER=$BETA_MARKER\n";
    echo "LATEST_FILE=$LATEST_FILE\n";
    echo "INSTALL_DIR=/boot/config/plugins/filebrowser_quantum/install\n";
')

# 定义二进制路径 (对应你 plg 中的路径)
RUNNING_BINARY="/usr/sbin/filebrowser_quantumorig"
DAEMON_SCRIPT="/usr/local/emhttp/plugins/filebrowser_quantum/Daemon.sh"

# 2. 【逻辑复用】根据当前分支标记判断目标版本
# 这样保证了 update 脚本看的分支和 WebUI 看到的分支永远一致
if [ -f "$BETA_MARKER" ]; then
    BRANCH_TYPE="beta"
    ARG_BRANCH="2"
else
    BRANCH_TYPE="stable"
    ARG_BRANCH="1"
fi

# 从 LATEST_FILE 获取版本号 (这是由 WebUI 或 Daemon 提前抓取好的)
# 如果文件不存在，则现场抓取一次
if [ ! -f "$LATEST_FILE" ]; then
    $DAEMON_SCRIPT "VERSION"
fi
current_version=$(head -n 1 "$LATEST_FILE")

# 容错处理
[ -z "$current_version" ] && echo "无法获取版本号" && exit 1

INSTALLED_BINARY="$INSTALL_DIR/filebrowser_quantum-$current_version"
DOWNLOAD_URL="https://github.com/gtsteffaniak/filebrowser/releases/download/$current_version/linux-amd64-filebrowser"

echo "-------------------------------------------------------------------"
echo "目标版本: $current_version (分支: $BRANCH_TYPE)"
echo "-------------------------------------------------------------------"

# 3. 【核心执行】解决文件占用问题
if ping -q -c1 github.com >/dev/null; then
    # 下载
    if [ ! -f "$INSTALLED_BINARY" ]; then
        echo "正在下载新版本..."
        curl --connect-timeout 15 --retry 3 --retry-delay 2 -L -o "$INSTALLED_BINARY" --create-dirs "$DOWNLOAD_URL"
    fi

    # 【关键修改】必须先彻底停止服务！
    echo "正在停止服务以解除文件锁定..."
    $DAEMON_SCRIPT "false" >/dev/null 2>&1
    # 强制杀死残留进程
    PID=$(pgrep -f "filebrowser_quantumorig")
    [ ! -z "$PID" ] && kill -9 $PID && sleep 1

    # 替换文件
    echo "正在覆盖二进制文件..."
    cp -f "$INSTALLED_BINARY" "$RUNNING_BINARY"
    chown root:root "$RUNNING_BINARY"
    chmod 755 "$RUNNING_BINARY"

    # 重新启动服务
    echo "正在重启服务..."
    $DAEMON_SCRIPT "true" >/dev/null 2>&1
else
    echo "<font color='red'>错误：无法连接 GitHub</font>"
    exit 1
fi

# 4. 【严谨验证】精确匹配完整版本号字符串
# 注意：你的 version 输出有多行，我们需要提取出包含 vX.X.X 的那一部分
installed_ver_now=$($RUNNING_BINARY version | grep -oE 'v[0-9]+\.[0-9]+\.[0-9]+(-beta|-stable)?' | head -n 1)

if [ "$installed_ver_now" == "$current_version" ]; then
    echo ""
    echo "-------------------------------------------------------------------"
    echo "验证成功：filebrowser_quantum 已更新为 $installed_ver_now"
    echo "-------------------------------------------------------------------"
    echo ""
else
    echo ""
    echo "-------------------------------------------------------------------"
    echo "<font color='red'>验证失败：</font>"
    echo "期待版本: $current_version"
    echo "实际运行: $installed_ver_now"
    echo "-------------------------------------------------------------------"
    exit 1
fi
