#!/bin/bash

# --- 变量定义：请根据你的插件目录名确认 ---
TAG="FileBrowser-Plugin"
PLUGIN_NAME="filebrowser_quantum"
CONF_DIR="/boot/config/plugins/$PLUGIN_NAME"
SETTINGS="$CONF_DIR/settings.cfg"
# 真正执行的二进制文件路径
BINARY="/usr/sbin/filebrowser_quantumorig"

# --- 1. 处理传入参数 ---
if [ "${1}" == "true" ]; then
  echo "Enabling FileBrowser..." | tee >(logger -t "$TAG")
  # 修改配置文件中的使能开关 (filebrowser_ENABLED=true)
  sed -i "/filebrowser_ENABLED=/c\filebrowser_ENABLED=${1}" "$SETTINGS"
  
  # 检查进程是否已在运行，防止重复启动
  if pgrep -f "filebrowser_quantumorig" > /dev/null 2>&1 ; then
    echo
    echo "FileBrowser 已经在运行!"  | tee >(logger -t "$TAG")
    exit 0
  fi

elif [ "${1}" == "false" ]; then
  # 停止进程
  KILL_PID="$(pgrep -f "filebrowser_quantumorig")"
  echo "停止 FileBrowser , 请稍后..." | tee >(logger -t "$TAG")
  [ ! -z "$KILL_PID" ] && kill -SIGINT $KILL_PID
  # 修改配置文件中的使能开关 (filebrowser_ENABLED=false)
  sed -i "/filebrowser_ENABLED=/c\filebrowser_ENABLED=${1}" "$SETTINGS"
  echo "FileBrowser 已停止" | tee >(logger -t "$TAG")
  exit 0

elif [ "${1}" == "VERSION" ]; then
  # VERSION 逻辑：原脚本用于通过 API 获取 GitHub 最新版并记录到文件
  [ ! -d "$CONF_DIR/webui" ] && mkdir -p "$CONF_DIR/webui"
  [ -f "$CONF_DIR/webui/latest" ] && rm -f "$CONF_DIR/webui/latest"
  
  # 获取 FileBrowser 官方仓库的最新 Release 标签
  API_RESULT="$(wget -qO- https://api.github.com/repos/filebrowser/filebrowser/releases/latest)"
  # 记录版本号到 latest 文件第一行
  echo "${API_RESULT}" | jq -r '.tag_name' | sed 's/^v//' > "$CONF_DIR/webui/latest"
  # 记录下载链接到 latest 文件第二行（这里保留逻辑，你可以改写为下载特定的资源包）
  echo "${API_RESULT}" | jq -r '.assets[].browser_download_url' >> "$CONF_DIR/webui/latest"
  
  LAT_V="$(cat "$CONF_DIR/webui/latest" | head -1)"
  if [ -z "${LAT_V}" ] || [ "${LAT_V}" == "null" ]; then
    rm -f "$CONF_DIR/webui/latest"
  else
    exit 0
  fi
else
  echo "Error: Unknown parameter ${1}"
  exit 1
fi


# --- 3. 核心启动逻辑 ---
# 从配置文件读取启动参数
START_PARAMS="$(cat "$SETTINGS" | grep -n "^START_PARAMS=" | cut -d '=' -f2- | sed 's/\"//g')"

echo "正在启动FileBrowser" | tee >(logger -t "$TAG")
# 【关键修改】：移除了 rclone 特有的参数，改为 filebrowser 启动格式
# -c 指定配置文件。at now 确保在后台持续运行。
echo "$BINARY -c $CONF_DIR/config.yaml ${START_PARAMS}" | at now -M > /dev/null 2>&1

sleep 2

# 最终检查
if pgrep -f "filebrowser_quantumorig" > /dev/null 2>&1 ; then
  echo
  echo "FileBrowser 启动成功!" | tee >(logger -t "$TAG")
else
  echo
  echo "FileBrowser 启动失败 , 请检查设置和日志 . " | tee >(logger -t "$TAG")
fi
