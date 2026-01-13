<?PHP
// v1.0.1
require_once "base.php";

$logfile = getLogPath($CONFIG_FILE);

$log_level = isset($_GET['log_level']) ? $_GET['log_level'] : 'all';
$grep_cmd = ($log_level !== 'all') ? " | grep -i " . escapeshellarg($log_level) : "";

header('Content-Type: text/plain; charset=utf-8');

if (file_exists($logfile)) {
    $output = shell_exec("tail -n 100 $logfile $grep_cmd 2>&1");
    echo htmlspecialchars($output) ?: "日志文件为空...";
} else {
    echo "找不到日志文件: " . htmlspecialchars($logfile);
}
?>
