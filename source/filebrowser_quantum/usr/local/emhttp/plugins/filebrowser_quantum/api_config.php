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
         $target_enabled = $input['enabled'] ?? '';
    } else {
         $target_enabled = $_POST['enabled'] ?? '';
    }
    
    if (empty($newContent)) sendResponse(false, [], 'Content cannot be empty');

    $syntax = isValidYamlSyntax($newContent);
    if ($syntax !== true) sendResponse(false, [], $syntax);
    
    $schema = validateConfigSchema($newContent);
    if ($schema !== true) sendResponse(false, [], $schema);

    // 1. Save YAML content
    if (file_put_contents($CONFIG_YAML, $newContent) === false) sendResponse(false, [], 'Write failed');

    // 2. Sync 'Enabled/Disabled' radio state if provided
    if ($target_enabled !== '') {
        setSettingValue('filebrowser_ENABLED', $target_enabled);
    }
    
    $is_enabled = ($target_enabled !== '') ? ($target_enabled == 'true') : (getSettingValue('filebrowser_ENABLED', 'false') == 'true');
    $restarted = false;
    
    // 3. Delegate Lifecycle to Daemon.sh
    if ($is_enabled) {
         // RESTART command handles STOP-WAIT-START-VERIFY (5s loop)
         exec("bash $DAEMON_SCRIPT 'RESTART' 2>&1", $shell_out, $return_var);
         
         if ($return_var === 0) {
             $restarted = true;
         } else {
             // Startup FAILED (due to invalid config value like 'downloa: t')
             $logfile = getLogPath($CONFIG_YAML);
             $log_snippet = "";
             if (file_exists($logfile)) {
                 $log_snippet = shell_exec("tail -n 20 " . escapeshellarg($logfile));
                 $log_snippet = preg_replace('/\x1b\[[0-9;]*m/', '', $log_snippet);
             }
             $shell_msg = implode("\n", $shell_out);
             $combined_err = "--- [Binary Log] ---\n" . ($log_snippet ?: "No logs.") . "\n\n--- [Daemon Output] ---\n" . ($shell_msg ?: "No output.");
             
             // CRITICAL: Return success: false to signal failure to UI
             sendResponse(false, ['restarted' => false, 'log' => $combined_err], 'Config saved, but Service failed to stay alive. Check YAML values.');
         }
    } else {
         // If user saves while Disabled, just ensure it's stopped
         exec("bash $DAEMON_SCRIPT 'STOP_ONLY' > /dev/null 2>&1");
    }
    sendResponse(true, ['restarted' => $restarted], 'Saved successfully' . ($restarted ? ' and restarted' : ''));
}

// === 获取状态 ===
if ($action == 'get_status') {
    $is_enabled = getSettingValue('filebrowser_ENABLED', 'false') == 'true' ? 'true' : 'false';
    
    $port = exec($DAEMON_SCRIPT . ' "GET_PORT"');
    
    // Delegation: Use specialized CHECK command for process status
    $running_output = trim(shell_exec("bash $DAEMON_SCRIPT 'CHECK'"));
    $running = ($running_output === 'running');
    
    $local_ver = exec($DAEMON_SCRIPT . ' "GET_LOCAL_VER"');
    $latest_ver = getSettingValue('filebrowser_LATEST', 'Unknown');
    
    $branch = getSettingValue('filebrowser_BRANCH', 'stable');
    $logfile = getLogPath($CONFIG_YAML);

    sendResponse(true, [
        'enabled' => $is_enabled,
        'running' => $running,
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
        if ($parsed === false) return "YAML Syntax Error: Specific structure issues detected.";
        
        if (!is_array($parsed)) {
            return "YAML Error: Root element must be a dictionary/array (e.g. 'key: value'), not a simple string.";
        }
    }

    $lines = explode("\n", $content);
    foreach ($lines as $i => $line) {
        $trim = trim($line);
        if (empty($trim)) continue;
        
        if ($trim[0] === '#') continue;
        if ($trim[0] === '-') continue;
        
        // YAML Key-Value check
        if (strpos($trim, ':') !== false) {
             // Enhanced: Catch boolean typos (like 't', 'tr', 'f', 'fa', 'ye', 'no')
             // 1. Matches "key: value" (with space)
             if (preg_match('/:\s+([^#\s]+)/', $trim, $matches)) {
                 $val = strtolower($matches[1]);
                 $valid_standard = ['true', 'false', 'yes', 'no', 'on', 'off'];
                 
                 // Catch any keyword that starts like a boolean but isn't one
                 if (preg_match('/^(t|f|y|n)/', $val) && !in_array($val, $valid_standard)) {
                     return "YAML Error (Line " . ($i + 1) . "): Invalid keyword '$val'. Did you mean 'true' or 'false'?";
                 }
             } 
             // 2. Matches "key:value" (Missing space)
             elseif (preg_match('/:([^\s#]+)/', $trim, $matches)) {
                 $val = $matches[1];
                 if (in_array(strtolower($val), ['true', 'false', 'yes', 'no'])) {
                     return "YAML Error (Line " . ($i + 1) . "): Missing space after colon. YAML requires 'key: $val'.";
                 }
             }
             continue;
        }

        return "YAML Error (Line " . ($i + 1) . "): Invalid formatting. Check line structure.";
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
