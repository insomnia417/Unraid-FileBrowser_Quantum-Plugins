#!/bin/bash
GITHUB_REPO="gtsteffaniak/filebrowser"
TAG_LIST=$(curl -s "https://api.github.com/repos/$GITHUB_REPO/tags" | grep '"name":' | head -n 10)

if [ "$1" = "2" ]; then
   current_version=$(echo "$TAG_LIST" | grep -oE 'v[0-9]+\.[0-9]+\.[0-9]+-beta' | head -n 1)
else
   current_version=$(echo "$TAG_LIST" | grep -oE 'v[0-9]+\.[0-9]+\.[0-9]+-stable' | head -n 1)
fi;

# 容错处理：万一没抓到版本，给个保底值
if [ -z "$current_version" ]; then
    current_version="v1.1.0-stable"
fi

INSTALLED_BINARY="/boot/config/plugins/filebrowser_quantum/install/filebrowser_quantum-$current_version"
filebrowser_quantumurl="https://github.com/$GITHUB_REPO/releases/download/$current_version/linux-amd64-filebrowser"

version=`filebrowser_quantumorig version | head -n 1`
  echo "-------------------------------------------------------------------"
  echo "联网查询中..."
  echo "-------------------------------------------------------------------"
ping -q -c3 github.com >/dev/null
if [ $? -eq 0 ]; then
    if [ -f "$INSTALLED_BINARY" ] && [[ "$version" == *"$current_version"* ]]; then
    echo "Local filebrowser_quantum binary ($current_version) up-to-date"  
    echo "本地已存在 ($current_version) "  
    else
	echo "-----------------------------------------------------------"
    echo "New version found: $current_version.Downloading and installing filebrowser_quantum binary"
    echo "发现新版本 : $current_version 下载安装中..."
	echo "-----------------------------------------------------------"
    curl --connect-timeout 15 --retry 3 --retry-delay 2 -L -o "$INSTALLED_BINARY" --create-dirs "$filebrowser_quantumurl"
    cp "$INSTALLED_BINARY" /usr/sbin/filebrowser_quantumorig
    chown root:root /usr/sbin/filebrowser_quantumorig
    chmod 755 /usr/sbin/filebrowser_quantumorig
    fi;
else
  echo ""
  echo "-------------------------------------------------------------------"
  echo "<font color='red'> 连接错误 - 无法访问 filebrowser_quantum 下载地址 </font>"
  echo "-------------------------------------------------------------------"
  echo ""
  exit 1
fi;

# 获取安装动作执行后的实际版本号
installed_ver_now=`/usr/sbin/filebrowser_quantumorig version | head -n 1 2>/dev/null`

# 判断：实际安装的版本 是否包含 我们从 GitHub 抓取的目标版本号
if [[ "$installed_ver_now" == *"$current_version"* ]]; then
  echo ""
  echo "-------------------------------------------------------------------"
  echo "验证成功：filebrowser_quantum 已更新/保持为 $current_version"
  echo "-------------------------------------------------------------------"
  echo ""
else
  echo ""
  echo "-------------------------------------------------------------------"
  echo "<font color='red'> 升级失败：当前版本 ($installed_ver_now) 与目标版本 ($current_version) 不符 </font>"
  echo "-------------------------------------------------------------------"
  echo ""
  exit 1
fi;

echo ""
echo "-------------------------------------------------------------------"
echo "filebrowser_quantum 已成功更新"
echo "-------------------------------------------------------------------"
echo ""
