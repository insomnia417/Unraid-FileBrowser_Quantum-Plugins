<?PHP
/* 动态从 config.yaml 读取日志路径并输出日志内容 */
// 1. 定义配置文件路径
$config_file = "/boot/config/plugins/filebrowser_quantum/config.yaml";
$logfile = "/var/log/filebrowser_quantum.log"; // 默认保底路径
// 2. 从 YAML 中解析实际的日志路径
if (file_exists($config_file)) {
    $config_content = file_get_contents($config_file);
    // 使用正则表达式匹配 logging 节点下的 output 路径
    if (preg_match('/output:\s*["\']?([^"\']+)["\']?/', $config_content, $matches)) {
        $logfile = trim($matches[1]);
    }
}
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
