<?PHP
// 1. 找到唯一的来源
$conf = "/usr/local/emhttp/plugins/filebrowser_quantum/paths.conf";
$paths = file_exists($conf) ? parse_ini_file($conf) : [];

// 2. 变量同步（将 Bash 变量名转为 PHP 变量名，兼容旧代码）
$BINARY        = $paths['BINARY']        ?? "/usr/sbin/filebrowser_quantumorig";
$PLG_PATH      = $paths['PLG_PATH']      ?? "/boot/config/plugins/filebrowser_quantum";
$CONFIG_YAML   = $paths['CONFIG_YAML']   ?? "$PLG_PATH/config.yaml";
$SETTINGS_FILE = $paths['SETTINGS_FILE'] ?? "$PLG_PATH/settings.cfg";
$INSTALL_PATH  = $paths['INSTALL_PATH']  ?? "$PLG_PATH/install";
$BETA_MARKER   = $paths['BETA_MARKER']   ?? "$INSTALL_PATH/beta";
$LATEST_MARKER = $paths['LATEST_MARKER'] ?? "$INSTALL_PATH/latest";

// 提取日志文件路径
function getLogPath($configFile) {
    $default = "/var/log/filebrowser_quantum.log";
    if (file_exists($configFile)) {
        $content = file_get_contents($configFile);
        if (preg_match('/output:\s*["\']?([^"\']+)["\']?/', $content, $matches)) {
            return trim($matches[1]);
        }
    }
    return $default;
}

// 动态提取日志等级列表
function getLogLevels($configFile) {
    if (file_exists($configFile)) {
        $content = file_get_contents($configFile);
        // 匹配 config.yaml 中的 levels: "info|debug|warning|error"
        if (preg_match('/levels:\s*["\']?([^"\']+)["\']?/', $content, $matches)) {
            // 拆分并清理两端空格
            $levels = explode('|', trim($matches[1]));
            return array_map('trim', array_filter($levels));
        }
    }
    return ['info', 'error']; // 保底
}
?>
