#!/bin/bash
NAME="filebrowser_quantum"
YAML="/boot/config/plugins/$NAME/config.yaml"
DAEMON="/usr/sbin/$NAME-orig"

case "$1" in
    'true')
        # 启动逻辑
        if ! pgrep -f "$NAME-orig.*-c $YAML" > /dev/null; then
            $DAEMON -c $YAML > /dev/null 2>&1 &
        fi
    ;;
    'false')
        # 停止逻辑
        KILL_PID="$(pgrep -f "$NAME-orig.*-c $YAML")"
        [ ! -z "$KILL_PID" ] && kill -SIGINT $KILL_PID
    ;;
    'VERSION')
        # 输出本地版本
        if [ -f "$DAEMON" ]; then
            $DAEMON version | head -n 1 | awk '{print $NF}'
        fi
        # 异步更新远程版本号到 /tmp
        (
            REMOTE=$(curl -s https://api.github.com/repos/gtsteffaniak/filebrowser/releases/latest | grep '"tag_name":' | sed -E 's/.*"([^"]+)".*/\1/')
            echo "$REMOTE" > /tmp/${NAME}_newest_version
        ) &
    ;;
esac
