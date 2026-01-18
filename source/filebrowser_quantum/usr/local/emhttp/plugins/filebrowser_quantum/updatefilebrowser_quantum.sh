#!/bin/bash

# --- 1. 防呆检查 (第3点详细描述) ---
CONF_PATH="/usr/local/emhttp/plugins/filebrowser_quantum/paths.conf"

# 检查仓库文件是否存在
if [ ! -f "$CONF_PATH" ]; then
    echo "<font color='red'>错误：找不到关键配置文件 $CONF_PATH</font>"
    echo "请重新安装插件或检查文件系统。"
    exit 1
fi

# 引入paths.conf变量
source "$CONF_PATH"
# --------------------------------

# --- 2. 核心函数定义 ---

# 获取最新版本信息
get_target_version() {
    echo "正在获取目标版本信息..."
    TARGET_VER=$(bash "$DAEMON_SCRIPT" "VERSION" | tail -n 1)
    
    if [ -z "$TARGET_VER" ] || [ "$TARGET_VER" == "Unknown" ]; then
        echo "<font color='red'>错误：无法获取有效版本号。请检查 GitHub 联网状态。</font>"
        exit 1
    fi
    echo "目标版本: $TARGET_VER"
}

# 下载并验证
download_and_verify() {
    local version="$1"
    local binary_path="$2"
    local url="https://github.com/$GITHUB_REPO/releases/download/$version/$ARCH_TYPE"
    
    echo "-------------------------------------------------------------------"
    echo "正在执行更新：$version ($ARCH_TYPE)"
    echo "-------------------------------------------------------------------"
    
    # 检查网络
    if ! ping -q -c1 github.com >/dev/null; then
         echo "<font color='red'>网络错误：无法连接 GitHub</font>"
         return 1
    fi

    # 如果本地已有该版本缓存，跳过下载
    if [ -f "$binary_path" ]; then
        echo "发现本地缓存，跳过下载。"
        return 0
    fi

    echo "正在下载新版本..."
    curl --connect-timeout 15 --retry 3 --retry-delay 2 -f -L -o "$binary_path" --create-dirs "$url"
    if [ $? -ne 0 ]; then
        echo "<font color='red'>错误：下载过程中止</font>"
        rm -f "$binary_path"
        return 1
    fi

    # SHA256 校验
    echo "正在校验 SHA256..."
    API_URL="https://api.github.com/repos/$GITHUB_REPO/releases/tags/$version"
    RELEASE_DATA=$(curl -sL -H "Accept: application/vnd.github.v3+json" -A "$TAG" "$API_URL")
    EXPECTED_HASH=$(echo "$RELEASE_DATA" | tr -d '\n' | grep -oP "{\"url\":.*?\"name\":\"$ARCH_TYPE\".*?\"digest\":\"sha256:\K[a-fA-F0-9]{64}")

    if [ -n "$EXPECTED_HASH" ]; then
        echo "SHA256: $EXPECTED_HASH"
        ACTUAL_HASH=$(sha256sum "$binary_path" | awk '{print $1}')
        if [ "$EXPECTED_HASH" != "$ACTUAL_HASH" ]; then
            echo "<font color='red'>错误：SHA256 校验不通过！</font>"
            rm -f "$binary_path"
            return 1
        fi
        echo "SHA256 校验通过。"
    else
        echo "<font color='orange'>警告：未找到版本哈希值，执行文件体积保底检查...</font>"
        # 使用 paths.conf 中的 MIN_BINARY_SIZE 常量
        if [ "$(stat -c%s "$binary_path")" -lt "${MIN_BINARY_SIZE:-$((15 * 1024 * 1024))}" ]; then
            echo "<font color='red'>错误：文件体积异常，下载可能不完整。</font>"
            rm -f "$binary_path"
            return 1
        fi
    fi
}

# 停止服务
stop_service() {
    echo "正在停止服务..."
    bash "$DAEMON_SCRIPT" "false" >/dev/null 2>&1
    
    local wait_count=${MAX_SHUTDOWN_WAIT:-10}
    # 使用安全的进程名查找
    local safe_pname=$(basename "$BINARY")
    while [ $wait_count -gt 0 ] && pgrep -x "$safe_pname" >/dev/null; do
        sleep 1
        ((wait_count--))
    done
    pkill -9 -f "$safe_pname" >/dev/null 2>&1
}

# 替换文件
replace_binary() {
    local source_file="$1"
    local target_file="$2"
    
    echo "正在替换二进制文件..."
    
    # 备份原有权限
    local old_perm="755"
    local old_owner="root:root"
    if [ -f "$target_file" ]; then
        old_perm=$(stat -c "%a" "$target_file")
        old_owner=$(stat -c "%U:%G" "$target_file")
    fi
    
    cp -f "$source_file" "$target_file"
    chown "$old_owner" "$target_file"
    chmod "$old_perm" "$target_file"
}

# 验证更新结果
verify_result() {
    local expected_ver="$1"
    
    echo "正在同步版本信息..."
    bash "$DAEMON_SCRIPT" "VERSION" >/dev/null 2>&1
    local installed_ver_now=$(bash "$DAEMON_SCRIPT" "GET_LOCAL_VER")

    echo ""
    echo "-------------------------------------------------------------------"
    if [ "$installed_ver_now" == "$expected_ver" ]; then
        echo "验证成功：$PLUGIN_NAME 已成功更新为 $installed_ver_now"
        echo "-------------------------------------------------------------------"
        exit 0
    else
        echo "<font color='red'>验证失败：</font>"
        echo "云端版本: $expected_ver"
        echo "已安装: $installed_ver_now"
        echo "-------------------------------------------------------------------"
        exit 1
    fi
}

# --- 3. 主流程 ---
main() {
    get_target_version
    
    local install_pkg="$INSTALL_PATH/$PLUGIN_NAME-$TARGET_VER"
    
    download_and_verify "$TARGET_VER" "$install_pkg" || exit 1
    
    stop_service
    replace_binary "$install_pkg" "$BINARY"
    
    echo "更新完成，正在重启服务..."
    bash "$DAEMON_SCRIPT" "true" >/dev/null 2>&1
    
    verify_result "$TARGET_VER"
}

main "$@"
