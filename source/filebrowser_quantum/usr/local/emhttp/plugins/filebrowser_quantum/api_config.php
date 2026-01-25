<?PHP
require_once "base.php";

while (ob_get_level() > 0) { ob_end_clean(); }
header('Content-Type: application/json');

function sendResponse($success, $data = [], $message = '') {
    $data = json_decode(json_encode($data, JSON_INVALID_UTF8_IGNORE), true);
    $out = [
        'success' => $success,
        'data' => $data,
        'message' => (string)$message
    ];
    $json = json_encode($out);
    if ($json === false) {
        $json = json_encode(['success'=>false, 'message'=>'JSON Encode Failed: ' . json_last_error_msg()]);
    }
    echo $json;
    exit;
}

$action = $_GET['action'] ?? '';

// === 获取配置 ===
if ($action == 'get_config') {
    $content = file_exists($CONFIG_YAML) ? file_get_contents($CONFIG_YAML) : "";
    sendResponse(true, ['content' => $content], 'Loaded');
}

// === 保存配置 ===
if ($action == 'save_config') {
    if ($_SERVER['REQUEST_METHOD'] !== 'POST') sendResponse(false, [], 'Method Not Allowed');
    
    $newContent = $_POST['content'] ?? '';
    if (empty($newContent) && !empty(file_get_contents('php://input'))) {
         $input = json_decode(file_get_contents('php://input'), true);
         $newContent = $input['content'] ?? '';
    }
    
    if (empty($newContent)) sendResponse(false, [], 'Content cannot be empty');

    // yq 校验
    $syntax = isValidYamlSyntax($newContent);
    if ($syntax !== true) sendResponse(false, [], $syntax);
    
    // Schema 检查：至少保留核心 server 块检查
    if (strpos($newContent, 'server:') === false) sendResponse(false, [], "Schema Error: Missing required 'server:' section.");

    if (file_put_contents($CONFIG_YAML, $newContent) === false) sendResponse(false, [], 'Write failed');

    if (file_put_contents($CONFIG_YAML, $newContent) === false) sendResponse(false, [], 'Write failed');

    $is_enabled = getSettingValue('filebrowser_ENABLED', 'false') == 'true';
    $binary_base = basename($BINARY);
    $is_running = exec("pgrep -f \"$binary_base\"") !== '';
    
    $restarted = false;
    $error_output = '';
    if ($is_enabled || $is_running) {
         exec("bash $DAEMON_SCRIPT 'false' > /dev/null 2>&1");
         $wait_limit = 5;
         while ($wait_limit > 0 && exec("pgrep -f \"$binary_base\"") !== '') {
             usleep(500000);
             $wait_limit--;
         }
         exec("bash $DAEMON_SCRIPT 'true' > /dev/null 2>&1");
         sleep(2);
         if (exec("pgrep -f \"$binary_base\"") !== '') {
             $restarted = true;
         } else {
             $logfile = getLogPath($CONFIG_YAML);
             if (file_exists($logfile)) {
                 $error_output = shell_exec("tail -n 15 " . escapeshellarg($logfile));
                 $error_output = preg_replace('/\x1b\[[0-9;]*m/', '', $error_output);
             }
             sendResponse(false, ['restarted' => false, 'log' => $error_output], 'Config saved, but Service failed to start. Check log details below.');
         }
    }
    sendResponse(true, ['restarted' => $restarted], 'Saved successfully' . ($restarted ? ' and restarted' : ''));
}

// === [新增] yq 实时校验接口 ===
if ($action == 'validate_config') {
    if ($_SERVER['REQUEST_METHOD'] !== 'POST') sendResponse(false, [], 'Method Not Allowed');
    $content = $_POST['content'] ?? '';
    
    $result = isValidYamlSyntax($content);
    if ($result === true) {
        // 进一步进行业务逻辑校验
        if (strpos($content, 'server:') === false) {
            sendResponse(false, [], "Missing core 'server:' section");
        }
        sendResponse(true, [], 'Valid YAML');
    } else {
        sendResponse(false, [], $result);
    }
}

// === 获取状态 ===
if ($action == 'get_status') {
    $is_enabled = getSettingValue('filebrowser_ENABLED', 'false') == 'true' ? 'true' : 'false';
    
    $port = exec($DAEMON_SCRIPT . ' "GET_PORT"');
    $binary_base = basename($BINARY);
    $pid = exec("pgrep -f \"$binary_base\"");
    
    $local_ver = exec($DAEMON_SCRIPT . ' "GET_LOCAL_VER"');
    $latest_ver = getSettingValue('filebrowser_LATEST', 'Unknown');
    
    if ($latest_ver == "Unknown") {
        $latest_ver = exec($DAEMON_SCRIPT . ' "VERSION"');
    }
    
    $branch = getSettingValue('filebrowser_BRANCH', 'stable');
    $logfile = getLogPath($CONFIG_YAML);

    sendResponse(true, [
        'enabled' => $is_enabled,
        'running' => !empty($pid),
        'port' => $port,
        'branch' => $branch == 'beta' ? '2' : '1',
        'local_version' => trim($local_ver),
        'latest_version' => trim($latest_ver),
        'log_exists' => file_exists($logfile)
    ], 'Status fetched');
}

// === 设置服务状态 ===
if ($action == 'set_state') {
    if ($_SERVER['REQUEST_METHOD'] !== 'POST') sendResponse(false, [], 'Method Not Allowed');
    
    $target_state = $_POST['enabled'] ?? '';
    if ($target_state !== 'true' && $target_state !== 'false') sendResponse(false, [], 'Invalid state');

    shell_exec($DAEMON_SCRIPT . ' ' . escapeshellarg($target_state) . " > /dev/null 2>&1 &");
    sendResponse(true, ['target' => $target_state], 'Command sent');
}

// === 检查更新 ===
if ($action == 'check_update') {
    if ($_SERVER['REQUEST_METHOD'] !== 'POST') sendResponse(false, [], 'Method Not Allowed');
    $branch = $_POST['branch'] ?? '';
    $branchName = ($branch === '2') ? 'beta' : 'stable';
    setSettingValue('filebrowser_BRANCH', $branchName);
    $latest = trim(shell_exec($DAEMON_SCRIPT . ' "VERSION"')) ?: "Unknown";
    sendResponse(true, ['latest_version' => $latest], 'Version checked');
}

// === 清空日志 ===
if ($action == 'clear_log') {
    $logfile = getLogPath($CONFIG_YAML);
    if (file_exists($logfile)) {
        file_put_contents($logfile, '');
        sendResponse(true, [], 'Log cleared');
    } else {
        sendResponse(false, [], 'Log file not found');
    }
}

sendResponse(false, [], 'Invalid action: ' . $action);

// === yq 核心验证函数 ===

function isValidYamlSyntax($content) {
    global $YQ_BINARY;
    
    if (!file_exists($YQ_BINARY)) {
        return "Validator Error: yq binary not found at $YQ_BINARY";
    }

    $descriptorspec = [
        0 => ["pipe", "r"], // stdin
        1 => ["pipe", "w"], // stdout
        2 => ["pipe", "w"]  // stderr
    ];

    $process = proc_open("$YQ_BINARY eval '.' -", $descriptorspec, $pipes);

    if (is_resource($process)) {
        fwrite($pipes[0], $content);
        fclose($pipes[0]);

        $stdout = stream_get_contents($pipes[1]);
        $stderr = stream_get_contents($pipes[2]);
        
        fclose($pipes[1]);
        fclose($pipes[2]);

        $return_value = proc_close($process);

        if ($return_value !== 0) {
            // 清理 yq 报错前缀，只保留有用信息
            $error = trim($stderr);
            $error = preg_replace('/^.*?error:\s*/i', '', $error);
            return "YAML Error: " . $error;
        }
        return true;
    }
    return "Validator Error: Failed to execute yq";
}
?>
