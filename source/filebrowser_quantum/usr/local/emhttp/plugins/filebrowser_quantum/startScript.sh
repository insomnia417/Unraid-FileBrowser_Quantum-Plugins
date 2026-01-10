#!/bin/bash
NAME="filebrowser_quantum"

# 确保脚本权限
chmod 755 /usr/local/emhttp/plugins/$NAME/*.sh
chmod 755 /usr/sbin/$NAME-orig

# 执行启动
/usr/local/emhttp/plugins/$NAME/webuiScript.sh "true"
