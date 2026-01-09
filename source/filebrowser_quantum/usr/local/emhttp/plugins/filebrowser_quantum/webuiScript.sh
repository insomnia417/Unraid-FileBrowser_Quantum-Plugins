#!/bin/bash
# v3.0 - 移除 settings.cfg 依赖版本
# 路径定义
YAML="/boot/config/plugins/filebrowser_quantum/config.yaml"

if [ "${1}" == "true" ]; then
  echo "Enabling filebrowser_quantum, please wait..."
  
  # 【移除】：不再尝试 sed 修改 settings.cfg
  
  # 检查是否已在运行 (根据配置文件路径匹配)
  if pgrep -f "filebrowser_quantum-orig.*-c $YAML" > /dev/null 2>&1 ; then
    echo "filebrowser_quantum already started!"
    exit 0
  fi
  
  # 启动命令：完全依赖 config.yaml
  /usr/sbin/filebrowser_quantum-orig -c ${YAML} > /dev/null 2>&1 &
  echo "filebrowser_quantum started"

elif [ "${1}" == "false" ]; then
  echo "Disabling filebrowser_quantum..."
  
  # 【移除】：不再尝试 sed 修改 settings.cfg
  
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
