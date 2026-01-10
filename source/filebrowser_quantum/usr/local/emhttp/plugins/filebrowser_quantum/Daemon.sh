#!/bin/bash

# --- 基础路径定义 ---
CONF_DIR="/boot/config/plugins/filebrowser_quantum"
SETTINGS="$CONF_DIR/settings.cfg"
BINARY="/usr/sbin/filebrowser_quantumorig"

# --- 1. 处理启动指令 (true) ---
if [ "${1}" == "true" ]; then
  echo "正在启动 FileBrowser..."
  
  # 使用 sed 修改配置文件，确保状态同步为 true
  sed -i "/filebrowser_ENABLED=/c\filebrowser_ENABLED=${1}" "$SETTINGS"
  
  # 检查进程是否已在运行 (pgrep -f 匹配进程名)
  if pgrep -f "filebrowser_quantumorig" > /dev/null 2>&1 ; then
    echo "FileBrowser 已经在运行中！"
    exit 0
  fi
  
  # 读取用户定义的端口（如果 settings.cfg 里有定义，没有则默认 8080）
  PORT=$(grep "^PORT=" "$SETTINGS" | cut -d'=' -f2 | sed 's/"//g')
  PORT=${PORT:-8080}

  # 【核心启动命令】
  # 使用 'at now' 让程序在后台独立运行，不随脚本结束而关闭
  # -c 指定配置文件，-p 指定端口
  echo "$BINARY -c $CONF_DIR/config.yaml -p $PORT" | at now -M > /dev/null 2>&1
  
  sleep 2
  # 验证是否启动成功
  if pgrep -f "filebrowser_quantumorig" > /dev/null 2>&1 ; then
    echo "FileBrowser 启动成功！端口：$PORT"
  else
    echo "启动失败，请检查日志。"
  fi

# --- 2. 处理停止指令 (false) ---
elif [ "${1}" == "false" ]; then
  echo "正在停止 FileBrowser..."
  
  # 获取进程 PID 并杀死
  KILL_PID="$(pgrep -f "filebrowser_quantumorig")"
  if [ ! -z "$KILL_PID" ]; then
    kill -SIGINT $KILL_PID
  fi
  
  # 修改配置文件状态为 false
  sed -i "/filebrowser_ENABLED=/c\filebrowser_ENABLED=${1}" "$SETTINGS"
  echo "FileBrowser 已关闭。"
  exit 0

# --- 3. 处理版本显示指令 (VERSION) ---
elif [ "${1}" == "VERSION" ]; then
  # 创建版本信息临时文件给 Unraid 网页界面读取
  # 运行二进制文件的 version 命令并截取第一行
  if [ -f "$BINARY" ]; then
    $BINARY version | head -n 1 > /tmp/filebrowser_quantum_version
  else
    echo "未知版本" > /tmp/filebrowser_quantum_version
  fi
  exit 0

# --- 4. 错误处理 ---
else
  echo "未知参数: ${1}. 请使用 true, false 或 VERSION。"
  exit 1
fi
