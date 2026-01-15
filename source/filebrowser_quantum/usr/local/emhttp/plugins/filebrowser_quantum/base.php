<?PHP
// 插件路径
$paths = parse_ini_file("paths.conf");

$PLG_PATH      = $paths['PLG_PATH'];
$CONFIG_YAML   = $paths['CONFIG_YAML'];
$SETTINGS_FILE = $paths['SETTINGS_FILE'];
$INSTALL_PATH  = $paths['INSTALL_PATH'];
$LATEST_FILE   = $paths['LATEST_FILE'];
$BETA_MARKER   = $paths['BETA_MARKER'];

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

/**
 * 动态提取日志等级列表
 */
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
