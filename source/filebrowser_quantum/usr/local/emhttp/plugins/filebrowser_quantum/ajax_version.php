<?PHP
// 引入基础路径
require_once "base.php";

// 强制清理缓冲区
while (ob_get_level() > 0) { ob_end_clean(); }

if (isset($_POST['branch'])) {
    $new_branch = $_POST['branch'];
    // 写入分支标记
    if ($new_branch == "1") { 
        @unlink($BETA_MARKER); 
    } else { 
        @touch($BETA_MARKER); 
    }
    
    // 执行脚本获取最新版本号
    exec('/usr/local/emhttp/plugins/filebrowser_quantum/Daemon.sh "VERSION"');
    
    // 读取结果
    $latest = @exec("head -n 1 $LATEST_MARKER") ?: "Unknown";
    
    // 只输出结果并退出
    header('Content-Type: text/plain');
    echo trim($latest);
    exit;
}
?>
