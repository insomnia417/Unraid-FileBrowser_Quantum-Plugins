<?PHP
// 引入基础路径
require_once "base.php";

// 强制清理缓冲区
while (ob_get_level() > 0) { ob_end_clean(); }

// --- 关键：获取前端传来的分支参数 ---
if (isset($_POST['branch'])) {
    $new_branch = $_POST['branch'];
    
    // 1. 处理分支标记（保留你的逻辑：1 为 stable，其他为 beta）
    if ($new_branch == "1") { 
        @unlink($BETA_MARKER); 
    } else { 
        @touch($BETA_MARKER); 
    }

    // 2. 调用 Daemon.sh 执行 VERSION 逻辑
    // 这里的 shell_exec 会捕获 Daemon.sh 最后的 echo "$LAT_V"
    $latest = trim(shell_exec($DAEMON_SCRIPT . ' "VERSION"')) ?: "Unknown";

    // 3. 直接输出给前端 AJAX
    header('Content-Type: text/plain');
    echo $latest;
    exit;
}

// 如果没有收到 branch 参数，可以输出当前已知的 LATEST 作为兜底
$current_lat = trim(shell_exec($DAEMON_SCRIPT . ' "VERSION"')) ?: "Unknown";
echo $current_lat;
?>
