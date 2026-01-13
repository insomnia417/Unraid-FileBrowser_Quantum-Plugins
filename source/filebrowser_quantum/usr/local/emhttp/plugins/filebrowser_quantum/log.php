<?PHP
// 1. 定义日志路径
$logfile = "/var/log/filebrowser_quantum.log";
// 2. 获取过滤参数
$log_level = isset($_GET['log_level']) ? $_GET['log_level'] : 'all';
// 3. 构建安全的安全过滤指令
// 使用 escapeshellarg 防止命令注入攻击
$grep_cmd = "";
if ($log_level !== 'all') {
    $grep_cmd = " | grep -i " . escapeshellarg($log_level);
}
// 4. 设置 Header 告知浏览器这是纯文本，不要按 HTML 解析
header('Content-Type: text/plain; charset=utf-8');
// 5. 执行命令并输出
// tail -n 100 读取最后 100 行，2>&1 确保错误信息也能看到
$output = shell_exec("tail -n 100 $logfile $grep_cmd 2>&1");
echo $output ?: "暂无日志或日志文件不存在...";
?>
