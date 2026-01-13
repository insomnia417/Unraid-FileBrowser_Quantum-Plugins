#!/bin/bash
# Version: v2.9

# --- 前面下载和 cp 的逻辑保持不变 ---

# --- 4. 验证逻辑 (v2.9 强化脱水版) ---

# 1. 尝试通过 Daemon 获取
# 2. 【关键】使用 tr -dc 处理，只保留字母、数字、点、横杠，彻底过滤不可见字符
installed_ver_now=$(bash "$DAEMON_SCRIPT" "GET_LOCAL_VER" 2>/dev/null | tr -dc '[:alnum:].-')

# 3. 如果 Daemon 没抓到，直接现场抓取并脱水
if [ -z "$installed_ver_now" ]; then
    installed_ver_now=$($RUNNING_BINARY version 2>/dev/null | grep "Version" | cut -d':' -f2 | tr -dc '[:alnum:].-')
fi

# 4. 对目标版本也进行一次脱水，防止 $LATEST_FILE 里有换行符干扰比对
target_ver_clean=$(echo "$current_version" | tr -dc '[:alnum:].-')

echo "DEBUG: 目标版本为 [$target_ver_clean]"
echo "DEBUG: 实际提取为 [$installed_ver_now]"

if [ "$installed_ver_now" == "$target_ver_clean" ]; then
    echo "-------------------------------------------------------------------"
    echo "验证成功：已成功更新为 $installed_ver_now"
    echo "-------------------------------------------------------------------"
else
    echo "<font color='red'>验证失败：</font>"
    echo "期望: $target_ver_clean"
    echo "实际: $installed_ver_now"
    
    # 最后的救命稻草：如果字符串长度还是不对，说明有不可见字符
    echo "DEBUG: 期望长度: ${#target_ver_clean}"
    echo "DEBUG: 实际长度: ${#installed_ver_now}"
    exit 1
fi
