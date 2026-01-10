#!/bin/bash
NAME="filebrowser_quantum"

# 修复可能的权限丢失
chmod 755 /usr/local/emhttp/plugins/$NAME/*.sh
if [ -f "/usr/sbin/$NAME-orig" ]; then
    chmod 755 "/usr/sbin/$NAME-orig"
fi

# 启动
/usr/local/emhttp/plugins/$NAME/webuiScript.sh "true"
