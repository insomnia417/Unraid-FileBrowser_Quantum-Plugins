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
  KILL_PID=$(pgrep "filebrowser_quantumorig")
  echo "停止 FileBrowser , 请稍后..." | tee >(logger -t "$TAG")
  [ ! -z "$KILL_PID" ] && kill $KILL_PID
  # 修改配置文件中的使能开关 (filebrowser_ENABLED=false)
  sed -i "/filebrowser_ENABLED=/c\filebrowser_ENABLED=${1}" "$SETTINGS"
  echo "FileBrowser 已停止" | tee >(logger -t "$TAG")
  exit 0

# --- GET config.yaml PORT ---
elif [ "${1}" == "GET_PORT" ]; then
  # 1. 检查配置文件是否存在
  if [ -f "$CONF_DIR/config.yaml" ]; then
    # 2. 优雅解析：查找 port: 开头的行，提取数字，并去掉可能的引号或空格
    # 使用 awk '{print $2}' 获取冒号后的值，tr -d ' "' 去掉双引号和空格
    PORT=$(grep '^port:' "$CONF_DIR/config.yaml" | awk '{print $2}' | tr -d '" ' )
    
    # 3. 如果解析结果为空（比如配置文件格式错乱），则给一个保底端口
    echo "${PORT:-8081}"
  else
    # 配置文件不存在时，返回默认端口
    echo "8081"
  fi
  exit 0

elif [ "${1}" == "GET_LOCAL_VER" ]; then
    if [ -f "/usr/sbin/filebrowser_quantumorig" ]; then
        # 逻辑：
        # 1. 找到包含 "Version" 的行
        # 2. 用冒号 ":" 分割，取后半部分
        # 3. 去掉空格和字符 'v'
        /usr/sbin/filebrowser_quantumorig version | grep "Version" | cut -d':' -f2 | tr -d ' v'
    else
        echo "not installed"
    fi
    exit 0

elif [ "${1}" == "VERSION" ]; then
    # 1. 确保目录存在
    [ ! -d "$CONF_DIR/install" ] && mkdir -p "$CONF_DIR/install"

    # 2. 获取 GitHub 所有的标签列表 (假设你之前定义了 TAG_LIST，如果没有，用下面这行获取)
    TAG_LIST=$(wget -qO- https://api.github.com/repos/filebrowser/filebrowser/releases | jq -r '.[].tag_name')

    # 3. 套用你 PLG 里的逻辑来决定获取哪个版本
    if [ -f "$CONF_DIR/install/beta" ]; then
        # 提取最新的 beta 版本号
        LAT_V=$(echo "$TAG_LIST" | grep -oE '[0-9]+\.[0-9]+\.[0-9]+-beta' | head -n 1)
    else
        # 提取最新的 stable 版本号
        LAT_V=$(echo "$TAG_LIST" | grep -oE '[0-9]+\.[0-9]+\.[0-9]+-stable' | head -n 1)
    fi

    # 4. 写入文件供 .page 读取
    if [ ! -z "$LAT_V" ] && [ "$LAT_V" != "null" ]; then
        echo "$LAT_V" > "$CONF_DIR/install/latest"
        exit 0
    else
        exit 1
    fi
fi
echo "正在启动FileBrowser..." | tee >(logger -t "$TAG")
# 【关键修改】：移除了 rclone 特有的参数，改为 filebrowser 启动格式
# -c 指定配置文件。at now 确保在后台持续运行。
echo "$BINARY -c $CONF_DIR/config.yaml" | at now -M > /dev/null 2>&1

sleep 2

# 最终检查
if pgrep "filebrowser_quantumorig" > /dev/null 2>&1 ; then
  echo
  echo " FileBrowser 启动成功 ! " | tee >(logger -t "$TAG")
else
  echo
  echo " FileBrowser 启动失败 , 请检查设置和日志 . " | tee >(logger -t "$TAG")
fi
