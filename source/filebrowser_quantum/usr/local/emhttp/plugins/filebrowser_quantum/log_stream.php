<?php
// v2.0.2 - SSE Backend with Filter
require_once "base.php";

set_time_limit(0);
ignore_user_abort(false);

header('Content-Type: text/event-stream');
header('Cache-Control: no-cache');
header('X-Accel-Buffering: no');
header('Connection: keep-alive');

$logfile = getLogPath($CONFIG_YAML);
$level = $_GET['level'] ?? 'all';

// 如果文件不存在，发送错误消息并退出
if (!file_exists($logfile)) {
    echo "data: <b style='color:red;'>[System] 日志文件不存在，请检查配置。</b>\n\n";
    flush();
    exit;
}

// 构建命令：如果不是 all，则增加 grep 过滤
$cmd = "stdbuf -oL tail -n 50 -f " . escapeshellarg($logfile);

if ($level !== 'all') {
    // 强制 grep 也不要缓存
    $cmd .= " | stdbuf -oL grep -i --line-buffered " . escapeshellarg($level);
}

$descriptorspec = [1 => ["pipe", "w"], 2 => ["pipe", "w"]];
$process = proc_open($cmd, $descriptorspec, $pipes);

if (is_resource($process)) {
    stream_set_blocking($pipes[1], 0);

    while (!connection_aborted()) {
        $line = fgets($pipes[1]);
        if ($line) {
            echo "data: " . htmlspecialchars(trim($line)) . "\n\n";
            flush();
        } else {
            // 心跳，防止某些反代超时
            echo ": heartbeat\n\n";
            flush();
            usleep(200000); 
        }
    }

    // 彻底清理
    fclose($pipes[1]);
    fclose($pipes[2]);
    proc_terminate($process, 9);
    proc_close($process);
}
?>
