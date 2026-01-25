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

    $syntax = isValidYamlSyntax($newContent);
    if ($syntax !== true) sendResponse(false, [], $syntax);
    
    $schema = validateConfigSchema($newContent);
    if ($schema !== true) sendResponse(false, [], $schema);

    if (file_put_contents($CONFIG_YAML, $newContent) === false) sendResponse(false, [], 'Write failed');

    $is_enabled = getSettingValue('filebrowser_ENABLED', 'false') == 'true';
    $pid = exec('pgrep -f "' . basename($BINARY) . '"');
    
    $restarted = false;
    if ($is_enabled || !empty($pid)) {
         exec("bash $DAEMON_SCRIPT 'false' > /dev/null 2>&1");
         sleep(1);
         exec("bash $DAEMON_SCRIPT 'true' > /dev/null 2>&1");
         $restarted = true;
    }
    sendResponse(true, ['restarted' => $restarted], 'Saved successfully' . ($restarted ? ' and restarted' : ''));
}

// === 获取状态 ===
if ($action == 'get_status') {
    $is_enabled = getSettingValue('filebrowser_ENABLED', 'false') == 'true' ? 'true' : 'false';
    
    $port = exec($DAEMON_SCRIPT . ' "GET_PORT"');
    $pid = exec('pgrep -f "' . basename($BINARY) . '"');
    
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
    
    if ($target_state !== 'true' && $target_state !== 'false') {
        sendResponse(false, [], 'Invalid state');
    }

    shell_exec($DAEMON_SCRIPT . ' ' . escapeshellarg($target_state) . " > /dev/null 2>&1 &");
    
    sendResponse(true, ['target' => $target_state], 'Command sent');
}

// === 检查更新 ===
if ($action == 'check_update') {
    if ($_SERVER['REQUEST_METHOD'] !== 'POST') sendResponse(false, [], 'Method Not Allowed');
    
    $branch = $_POST['branch'] ?? '';
    
    // 1 = stable, 2 = beta
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

// === YAML 验证函数 ===

function isValidYamlSyntax($content) {
    if (function_exists('yaml_parse')) {
        $parsed = @yaml_parse($content);
        if ($parsed === false) return "YAML Syntax Error: Use a validator to check your structure.";
        
        if (!is_array($parsed)) {
            return "YAML Error: Root element must be a dictionary/array (e.g. 'key: value'), not a simple string.";
        }
        return true;
    }

    $lines = explode("\n", $content);
    foreach ($lines as $i => $line) {
        $trim = trim($line);
        if (empty($trim)) continue;
        
        if ($trim[0] === '#') continue;
        if ($trim[0] === '-') continue;
        if (strpos($trim, ':') !== false) continue;

        return "YAML Error (Line " . ($i + 1) . "): Line '$trim' is invalid. Must be 'key: value', list item ('- value'), or comment.";
    }
    
    if (strpos($content, "\t") !== false) return "YAML Error: Tabs are not allowed.";
    
    return true;
}

function validateConfigSchema($content) {
    if (preg_match('/exclude\.(filePaths|folderPaths|fileNames|folderNames|fileEndsWith|folderEndsWith|fileStartsWith|folderStartsWith|hidden|ignoreZeroSizeFolders)/', $content)) {
        return "Schema Error: You are using the OLD exclusion rule format. Please migrate to the new 'rules' list format.";
    }
    
    if (preg_match_all('/<<:\s*\*([a-zA-Z0-9_]+)/', $content, $matches)) {
        foreach ($matches[1] as $anchorName) {
            if (strpos($content, '&' . $anchorName) === false) {
                return "Schema Error: Undefined anchor reference '*$anchorName'.";
            }
        }
    }
    
    if (function_exists('yaml_parse')) {
        $parsed = @yaml_parse($content);
        if (is_array($parsed) && !isset($parsed['server'])) {
             return "Schema Error: Missing required top-level section 'server:'.";
        }
    } else {
        if (strpos($content, 'server:') === false) return "Schema Error: Missing required top-level section 'server:'.";
    }

    return true;
}
?>
