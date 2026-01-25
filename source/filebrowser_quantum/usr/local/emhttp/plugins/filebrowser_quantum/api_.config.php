<?php
require_once "base.php";

// Set headers for JSON response
header('Content-Type: application/json');
// Disable caching
header("Cache-Control: no-store, no-cache, must-revalidate, max-age=0");
header("Cache-Control: post-check=0, pre-check=0", false);
header("Pragma: no-cache");

// Helper to send JSON response and exit
function sendResponse($success, $data = [], $message = '') {
    echo json_encode([
        'success' => $success,
        'data' => $data,
        'message' => $message
    ]);
    exit;
}

// Helper: Basic YAML Syntax Check (using yaml_parse if available, else simple check)
function isValidYamlSyntax($content) {
    // If yaml extension exists, use it
    if (function_exists('yaml_parse')) {
        // Suppress warnings to catch them
        $parsed = @yaml_parse($content);
        if ($parsed === false) {
             return "YAML Syntax Error: The content is not valid YAML.";
        }
        return true;
    }
    
    // Fallback: Check for basic structural errors (very basic)
    // For now, we assume if no PHP YAML ext, we trust the file structure unless it's obviously broken
    // But checking for tab characters is a good start as YAML forbids tabs for indentation
    if (strpos($content, "\t") !== false) {
        return "YAML Syntax Error: Tabs are not allowed in YAML. Use spaces for indentation.";
    }
    
    return true;
}

// Helper: Strict Schema Validation
function validateConfigSchema($content) {
    // 1. Check Exclusion Rules Format (Strict check for old format)
    if (preg_match('/exclude\.(filePaths|folderPaths|fileNames|folderNames|fileEndsWith|folderEndsWith|fileStartsWith|folderStartsWith|hidden|ignoreZeroSizeFolders)/', $content)) {
        return "Validation Error: You are using the OLD exclusion rule format (e.g., exclude.filePaths). Please migrate to the new 'rules' list format as per v0.8.9+ documentation.";
    }

    // 2. Check for 'rules' array if exclusion is intended (heuristic)
    // If content contains "rules:", it should likely be a list
    if (strpos($content, 'rules:') !== false) {
        if (!preg_match('/rules:\s*(\n\s*-|\s*\[)/', $content)) { 
            // This is a loose check, but catching "rules: something" that isn't a list
             // valid: rules:\n  - ... OR rules: []
        }
    }
    
    // 3. Check for Anchor Usage
    // If there is a merge key <<: *anchor, the anchor must be defined
    if (preg_match_all('/<<:\s*\*([a-zA-Z0-9_]+)/', $content, $matches)) {
        foreach ($matches[1] as $anchorName) {
            if (strpos($content, '&' . $anchorName) === false) {
                return "Validation Error: Undefined anchor reference '*$anchorName'. Make sure '&" . $anchorName . "' is defined.";
            }
        }
    }

    return true;
}

$action = $_GET['action'] ?? '';

switch ($action) {
    case 'get_metadata':
        // Return dynamic data needed for the UI
        $port = exec('/usr/local/emhttp/plugins/filebrowser_quantum/Daemon.sh "GET_PORT"');
        $pid = exec('pgrep -f "' . basename($BINARY) . '"');
        
        // Read config once to extract log details
        $currentConfig = file_exists($CONFIG_YAML) ? file_get_contents($CONFIG_YAML) : "";
        $logLevels = getLogLevels($CONFIG_YAML, $currentConfig);
        
        sendResponse(true, [
            'port' => $port,
            'isRunning' => !empty($pid),
            'logLevels' => $logLevels
        ]);
        break;

    case 'get_config':
        $content = file_exists($CONFIG_YAML) ? file_get_contents($CONFIG_YAML) : "";
        sendResponse(true, ['content' => $content]);
        break;

    case 'get_version_info':
        // Fetch version info via simple PHP or shell commands
        // We reuse the logic from the original page but exposed as JSON
        // Note: Check branch first
        $betaMarker = $paths['BETA_MARKER'] ?? "$INSTALL_PATH/beta";
        $branch = file_exists($betaMarker) ? "2" : "1";
        
        $currentVersion = exec('/usr/local/emhttp/plugins/filebrowser_quantum/Daemon.sh "GET_LOCAL_VER"');
        
        // Return structured data
        sendResponse(true, [
            'currentVersion' => trim($currentVersion),
            'branch' => $branch
        ]);
        break;

    case 'toggle_service':
        $input = json_decode(file_get_contents('php://input'), true);
        $enabled = $input['enabled'] ?? '';
        
        if ($enabled !== 'true' && $enabled !== 'false') {
             sendResponse(false, [], 'Invalid status');
        }

        // Execute background daemon call
        shell_exec("/usr/local/emhttp/plugins/filebrowser_quantum/Daemon.sh " . escapeshellarg($enabled) . " > /dev/null 2>&1 &");
        
        sendResponse(true, [], 'Service status updated');
        break;

    case 'clear_log':
        // Reuse getLogPath logic (but with default content null, so it reads file to find path)
        // Note: getLogPath is from base.php
        $logfile = getLogPath($CONFIG_YAML);
        if (file_exists($logfile)) {
            file_put_contents($logfile, "");
            sendResponse(true, [], 'Log cleared');
        } else {
            sendResponse(false, [], 'Log file not found');
        }
        break;

    case 'set_branch':
        $input = json_decode(file_get_contents('php://input'), true);
        $branch = $input['branch'] ?? '';
        
        $betaMarker = $paths['BETA_MARKER'] ?? "$INSTALL_PATH/beta";
        
        if ($branch == "1") { 
            @unlink($betaMarker); 
        } elseif ($branch == "2") { 
            @touch($betaMarker); 
        } else {
            sendResponse(false, [], 'Invalid branch');
        }

        // Get latest version for this branch
        $latest = trim(shell_exec($DAEMON_SCRIPT . ' "VERSION"')) ?: "Unknown";
        
        // Return plain text or JSON? The old ajax returned plain text. 
        // But our API is JSON. We should return JSON.
        sendResponse(true, ['latestVersion' => $latest]);
        break;

    case 'save_config':
        if ($_SERVER['REQUEST_METHOD'] !== 'POST') {
            sendResponse(false, [], 'Method Not Allowed');
        }
        
        $input = json_decode(file_get_contents('php://input'), true);
        $newContent = $input['content'] ?? '';
        
        if (empty($newContent)) {
            sendResponse(false, [], 'Content cannot be empty');
        }

        // 1. Validate Syntax
        $syntaxCheck = isValidYamlSyntax($newContent);
        if ($syntaxCheck !== true) {
            sendResponse(false, [], $syntaxCheck);
        }

        // 2. Validate Schema
        $schemaCheck = validateConfigSchema($newContent);
        if ($schemaCheck !== true) {
            sendResponse(false, [], $schemaCheck);
        }

        // 3. Save
        if (file_put_contents($CONFIG_YAML, $newContent) === false) {
            sendResponse(false, [], 'Failed to write to config file');
        }

        // 4. Restart Service Logic
        $settings = @parse_ini_file($SETTINGS_FILE);
        $daemon_path = "/usr/local/emhttp/plugins/filebrowser_quantum/Daemon.sh";
        $pid = exec('pgrep -f "' . basename($BINARY) . '"');
        $is_enabled = ($settings['filebrowser_ENABLED'] ?? 'false') == 'true';
        $is_running = !empty($pid);

        if ($is_enabled || $is_running) {
             // Restart in background to avoid hanging the PHP request? 
             // The original code did strict execs with sleep. We'll replicate that but optimize if possible.
             // Original: exec("bash $daemon_path 'false' > /dev/null 2>&1"); sleep(2); exec("bash $daemon_path 'true'...");
             
             // We return success first, and maybe trigger restart via shell_exec in background?
             // Or we just do it synchronously as the user expects "Saving..." to verify restart.
             exec("bash $daemon_path 'false' > /dev/null 2>&1");
             sleep(1); 
             exec("bash $daemon_path 'true' > /dev/null 2>&1");
             
             sendResponse(true, ['restarted' => true], 'Configuration saved and service restarted.');
        } else {
             sendResponse(true, ['restarted' => false], 'Configuration saved.');
        }
        break;

    default:
        sendResponse(false, [], 'Invalid action');
}
?>
