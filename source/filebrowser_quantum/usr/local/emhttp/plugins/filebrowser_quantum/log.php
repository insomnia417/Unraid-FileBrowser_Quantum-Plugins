<?PHP
// v1.0.1
// 1. 引入共享基础定义（包含路径变量和 getLogPath 函数）
require_once "base.php";

// 2. 直接调用函数获取日志路径，不再需要在这里写正则匹配
$logfile = getLogPath($CONFIG_YAML);

// 3. 获取过滤参数
$log_level = isset($_GET['log_level']) ? $_GET['log_level'] : 'all';
$grep_cmd = ($log_level !== 'all') ? " | grep -i " . escapeshellarg($log_level) : "";

// 4. 设置纯文本输出头
header('Content-Type: text/plain; charset=utf-8');

// 5. 执行读取逻辑
if (file_exists($logfile)) {
    $output = shell_exec("tail -n 100 $logfile $grep_cmd 2>&1");
    echo htmlspecialchars($output) ?: "日志文件为空...";
} else {
    echo "找不到日志文件: " . htmlspecialchars($logfile);
}
?>
