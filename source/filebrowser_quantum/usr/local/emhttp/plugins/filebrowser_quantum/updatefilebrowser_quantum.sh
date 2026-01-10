#!/bin/bash
NAME="filebrowser_quantum"
INSTALL_DIR="/boot/config/plugins/$NAME/install"
# 定义下载地址（指向官方最新编译的二进制）
URL="https://github.com/gtsteffaniak/filebrowser/releases/latest/download/linux-amd64-filebrowser"

# 1. 停止当前服务
/usr/local/emhttp/plugins/$NAME/webuiScript.sh "false"

# 2. 下载新文件
echo "Downloading newest binary from GitHub..."
curl --connect-timeout 15 --retry 3 -L -o "$INSTALL_DIR/$NAME.new" "$URL"

# 3. 校验并替换
if [ $? -eq 0 ] && [ -s "$INSTALL_DIR/$NAME.new" ]; then
    mv "$INSTALL_DIR/$NAME.new" "$INSTALL_DIR/$NAME"
    cp "$INSTALL_DIR/$NAME" "/usr/sbin/$NAME-orig"
    chmod 755 "/usr/sbin/$NAME-orig"
    echo "Update completed successfully."
else
    echo "Update failed: Download error or file empty."
fi

# 4. 重新启动服务
/usr/local/emhttp/plugins/$NAME/webuiScript.sh "true"
