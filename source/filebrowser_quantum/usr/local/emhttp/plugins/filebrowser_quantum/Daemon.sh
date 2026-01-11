#!/bin/bash

# --- 变量定义：请根据你的插件目录名确认 ---
TAG="FileBrowser-Plugin"
PLUGIN_NAME="filebrowser_quantum"
CONF_DIR="/boot/config/plugins/$PLUGIN_NAME"
SETTINGS="$CONF_DIR/settings.cfg"
GITHUB_REPO="gtsteffaniak/filebrowser"
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

echo "FileBrowser正在启动中..." | tee >(logger -t "$TAG")
echo "$BINARY -c $CONF_DIR/config.yaml" | at now -M > /dev/null 2>&1

# 循环检测启动结果
for i in {1..5}; do
    sleep 1
    if pgrep -f "filebrowser_quantumorig" > /dev/null 2>&1 ; then
        echo "FileBrowser启动成功" | tee >(logger -t "$TAG")
        exit 0
    fi
done
echo ""
echo -e "\e[41m FileBrowser 启动失败 , 请检查设置和日志 . \e[0m" | tee >(logger -t "$TAG")
exit 1

elif [ "${1}" == "false" ]; then
  echo "停止 FileBrowser , 请稍后..." | tee >(logger -t "$TAG")
  pkill -9 -f "filebrowser_quantumorig"
  # 修改配置文件中的使能开关 (filebrowser_ENABLED=false)
  sed -i "/filebrowser_ENABLED=/c\filebrowser_ENABLED=${1}" "$SETTINGS"
  echo "FileBrowser 已停止" | tee >(logger -t "$TAG")
  exit 0

# 3. 获取端口 (供 WebUI 按钮使用)
elif [ "${1}" == "GET_PORT" ]; then
    if [ -f "$CONF_DIR/config.yaml" ]; then
        # 匹配 port: 行，过滤掉空格和各种引号
        PORT=$(grep -E '^port:|^  port:' "$CONF_DIR/config.yaml" | head -n 1 | awk -F: '{print $2}' | tr -d '" ' | tr -d "'")
        echo "${PORT:-8081}"
    else
        echo "8081"
    fi
    exit 0

elif [ "${1}" == "GET_LOCAL_VER" ]; then
    if [ -f "/usr/sbin/filebrowser_quantumorig" ]; then
        # 逻辑：
        # 1. 找到包含 "Version" 的行
        # 2. 用冒号 ":" 分割，取后半部分
        # 3. 去掉空格和字符 'v'
        /usr/sbin/filebrowser_quantumorig version | grep "Version" | cut -d':' -f2 | tr -d ' '
    else
        echo "not installed"
    fi
    exit 0

elif [ "${1}" == "VERSION" ]; then
    # 1. 确保目录存在
    [ ! -d "$CONF_DIR/install" ] && mkdir -p "$CONF_DIR/install"

    # 2. 获取 GitHub 所有的标签列表 (假设你之前定义了 TAG_LIST，如果没有，用下面这行获取)
    TAG_LIST=$(curl -s "https://api.github.com/repos/$GITHUB_REPO/tags" | grep '"name":' | head -n 10)

    # 3. 套用你 PLG 里的逻辑来决定获取哪个版本
    if [ -f "$CONF_DIR/install/beta" ]; then
        # 提取带 v 的最新 beta 版本号
        LAT_V=$(echo "$TAG_LIST" | grep -oE 'v[0-9]+\.[0-9]+\.[0-9]+-beta' | head -n 1)
    else
        # 提取带 v 的最新 stable 版本号
        LAT_V=$(echo "$TAG_LIST" | grep -oE 'v[0-9]+\.[0-9]+\.[0-9]+-stable' | head -n 1)
    fi

    # 4. 写入文件供 .page 读取
    if [ ! -z "$LAT_V" ]; then
        echo "$LAT_V" > "$CONF_DIR/install/latest"
        exit 0
    else
        exit 1
    fi
fi
