#!/bin/bash
NAME="filebrowser_quantum"
YAML="/boot/config/plugins/$NAME/config.yaml"
DAEMON="/usr/sbin/$NAME-orig"

case "$1" in
    'true')
        # 启动逻辑：确保不重复启动
        if ! pgrep -f "$NAME-orig.*-c $YAML" > /dev/null; then
            echo "Starting $NAME..."
            $DAEMON -c $YAML > /dev/null 2>&1 &
        fi
    ;;
    'false')
        # 停止逻辑：精准杀掉对应配置的进程
        echo "Stopping $NAME..."
        KILL_PID="$(pgrep -f "$NAME-orig.*-c $YAML")"
        [ ! -z "$KILL_PID" ] && kill -SIGINT $KILL_PID
    ;;
    'VERSION')
        # 1. 输出本地版本供 PHP 直接调用显示
        if [ -f "$DAEMON" ]; then
            $DAEMON version | head -n 1 | awk '{print $NF}'
        fi
        
        # 2. 异步获取 GitHub 远程最新 Tag 并存入 /tmp
        (
            REMOTE_TAG=$(curl -s https://api.github.com/repos/gtsteffaniak/filebrowser/releases/latest | grep '"tag_name":' | sed -E 's/.*"([^"]+)".*/\1/')
            echo "$REMOTE_TAG" > /tmp/${NAME}_newest_version
        ) &
    ;;
esac
