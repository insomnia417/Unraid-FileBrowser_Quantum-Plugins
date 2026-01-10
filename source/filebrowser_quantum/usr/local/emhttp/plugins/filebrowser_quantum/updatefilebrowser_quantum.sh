#!/bin/bash
NAME="filebrowser_quantum"
INSTALL_DIR="/boot/config/plugins/$NAME/install"
# 官方最新下载地址
URL="https://github.com/gtsteffaniak/filebrowser/releases/latest/download/linux-amd64-filebrowser"

# 1. 停止服务
/usr/local/emhttp/plugins/$NAME/webuiScript.sh "false"

# 2. 执行更新下载
echo "Downloading binary..."
curl --connect-timeout 15 --retry 3 -L -o "$INSTALL_DIR/$NAME.new" "$URL"

# 3. 部署新二进制
if [ -f "$INSTALL_DIR/$NAME.new" ]; then
    mv "$INSTALL_DIR/$NAME.new" "$INSTALL_DIR/$NAME"
    cp "$INSTALL_DIR/$NAME" "/usr/sbin/$NAME-orig"
    chmod 755 "/usr/sbin/$NAME-orig"
    echo "Update Success"
else
    echo "Update Failed"
fi

# 4. 重新启动
/usr/local/emhttp/plugins/$NAME/webuiScript.sh "true"
