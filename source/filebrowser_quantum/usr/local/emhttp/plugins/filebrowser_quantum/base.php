<?PHP
// v1.0.0 - 共享路径定义
$PLG_PATH = "/boot/config/plugins/filebrowser_quantum";
$CONFIG_FILE = "$PLG_PATH/config.yaml";
$SETTINGS_FILE = "$PLG_PATH/settings.cfg";
$INSTALL_PATH = "$PLG_PATH/install";

// 统一的日志提取逻辑
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
?>
