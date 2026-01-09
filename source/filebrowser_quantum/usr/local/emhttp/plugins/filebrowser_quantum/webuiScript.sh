#!/bin/bash
# 路径定义
CFG="/boot/config/plugins/filebrowser_quantum/settings.cfg"
YAML="/boot/config/plugins/filebrowser_quantum/config.yaml"

# PORT=$(grep "WEBUI_PORT=" $CFG | cut -d'=' -f2 | sed 's/\"//g')
# START_PARAMS=$(grep "WEBUI_START_PARAMS=" $CFG | cut -d'=' -f2- | sed 's/\"//g')

if [ "${1}" == "true" ]; then
  echo "Enabling filebrowser_quantum, please wait..."
  sed -i "/WEBUI_ENABLED=/c\WEBUI_ENABLED=true" $CFG
  
  # 检查是否已在运行 (根据配置文件路径匹配)
  if pgrep -f "filebrowser_quantum-orig.*-c $YAML" > /dev/null 2>&1 ; then
    echo "filebrowser_quantum already started!"
    exit 0
  fi
  
  # 启动命令：使用内置 WebUI 参数
  # -c 配置文件
  /usr/sbin/filebrowser_quantum-orig -c ${YAML} > /dev/null 2>&1 &
  echo "filebrowser_quantum started"

elif [ "${1}" == "false" ]; then
  echo "Disabling filebrowser_quantum..."
  sed -i "/WEBUI_ENABLED=/c\WEBUI_ENABLED=false" $CFG
  # 找到并优雅停止进程
  KILL_PID="$(pgrep -f "filebrowser_quantum-orig.*-c $YAML")"
  if [ ! -z "$KILL_PID" ]; then
    kill -SIGINT $KILL_PID
  fi
  echo "filebrowser_quantum disabled"
  exit 0

elif [ "${1}" == "VERSION" ]; then
  # 既然不需要额外下载 WebUI，此分支直接退出
  exit 0
fi
