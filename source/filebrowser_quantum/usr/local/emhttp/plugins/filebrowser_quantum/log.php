<?PHP
// 极简日志接口 - 绝不加载 Unraid 模板
$logfile = "/var/log/filebrowser_quantum.log";
$log_level = isset($_GET['log_level']) ? $_GET['log_level'] : 'all';
$grep_cmd = ($log_level !== 'all') ? " | grep -i '" . escapeshellarg($log_level) . "'" : "";

header('Content-Type: text/plain; charset=utf-8');
echo htmlspecialchars(shell_exec("tail -n 100 $logfile $grep_cmd 2>&1")) ?: "暂无日志...";
?>
