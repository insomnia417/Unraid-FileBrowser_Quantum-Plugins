<?PHP
// 插件路径
$PLG_PATH = "/boot/config/plugins/filebrowser_quantum";
// config.yaml路径
$CONFIG_FILE = "$PLG_PATH/config.yaml";
// 插件附属配置文件
$SETTINGS_FILE = "$PLG_PATH/settings.cfg";
// 插件包下载路径
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
