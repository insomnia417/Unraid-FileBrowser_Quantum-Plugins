<?PHP
// 读取统一配置文件
$conf = "/usr/local/emhttp/plugins/filebrowser_quantum/paths.conf";
$paths = file_exists($conf) ? parse_ini_file($conf) : [];

// 核心路径变量
$DAEMON_SCRIPT = $paths['DAEMON_SCRIPT'] ?? "/usr/local/emhttp/plugins/filebrowser_quantum/Daemon.sh";
$BINARY        = $paths['BINARY']        ?? "/usr/sbin/filebrowser_quantumorig";
$PLG_PATH      = $paths['PLG_PATH']      ?? "/boot/config/plugins/filebrowser_quantum";
$CONFIG_YAML   = $paths['CONFIG_YAML']   ?? "$PLG_PATH/config.yaml";
$SETTINGS_FILE = $paths['SETTINGS_FILE'] ?? "$PLG_PATH/settings.cfg";
$INSTALL_PATH  = $paths['INSTALL_PATH']  ?? "$PLG_PATH/install";
$YQ_BINARY     = $paths['YQ_BINARY']     ?? "/usr/sbin/yq";

/**
 * 读取 settings.cfg 中的配置项
 */
function getSettingValue($key, $default = '') {
    global $SETTINGS_FILE;
    if (!file_exists($SETTINGS_FILE)) return $default;
    $settings = @parse_ini_file($SETTINGS_FILE);
    return $settings[$key] ?? $default;
}

/**
 * 写入 settings.cfg 中的配置项
 */
function setSettingValue($key, $value) {
    global $SETTINGS_FILE;
    if (!file_exists($SETTINGS_FILE)) touch($SETTINGS_FILE);
    
    $content = file_get_contents($SETTINGS_FILE);
    $pattern = "/^" . preg_quote($key, '/') . "=.*/m";
    $newLine = $key . '=' . (is_numeric($value) ? $value : '"' . $value . '"');
    
    if (preg_match($pattern, $content)) {
        $content = preg_replace($pattern, $newLine, $content);
    } else {
        $content .= "\n" . $newLine;
    }
    
    file_put_contents($SETTINGS_FILE, trim($content) . "\n");
}

/**
 * 提取日志文件路径
 */
function getLogPath($configFile, $content = null) {
    $default = "/var/log/filebrowser_quantum.log";
    if ($content === null && file_exists($configFile)) {
        $content = file_get_contents($configFile);
    }
    if ($content) {
        if (preg_match('/output:\s*["\']?([^"\']+)["\']?/', $content, $matches)) {
            return trim($matches[1]);
        }
    }
    return $default;
}

/**
 * 动态提取日志等级列表
 */
function getLogLevels($configFile, $content = null) {
    if ($content === null && file_exists($configFile)) {
        $content = file_get_contents($configFile);
    }
    if ($content) {
        if (preg_match('/levels:\s*["\']?([^"\']+)["\']?/', $content, $matches)) {
            $levels = explode('|', trim($matches[1]));
            return array_map('trim', array_filter($levels));
        }
    }
    return ['info', 'error'];
}
