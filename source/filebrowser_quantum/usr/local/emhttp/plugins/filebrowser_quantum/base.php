<?PHP
// 插件路径
$PLG_PATH = "/boot/config/plugins/filebrowser_quantum";
// config.yaml路径
$CONFIG_YAML = "$PLG_PATH/config.yaml";
// 插件附属配置文件
$SETTINGS_FILE = "$PLG_PATH/settings.cfg";
// 插件包下载路径
$INSTALL_PATH = "$PLG_PATH/install";
// 其他变量
$LATEST_FILE = "$INSTALL_PATH/latest";
$BETA_MARKER = "$INSTALL_PATH/beta";

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
