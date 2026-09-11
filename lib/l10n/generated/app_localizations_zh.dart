// ignore: unused_import
import 'package:intl/intl.dart' as intl;

import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Chinese (`zh`).
class AppLocalizationsZh extends AppLocalizations {
  AppLocalizationsZh([String locale = 'zh']) : super(locale);

  @override
  String get appTitle => 'SubDock';

  @override
  String get manage => '管理';

  @override
  String get runtimeStatus => '运行状态';

  @override
  String get logs => '日志';

  @override
  String get settings => '设置';

  @override
  String get start => '启动';

  @override
  String get stop => '停止';

  @override
  String get restart => '重启';

  @override
  String get save => '保存';

  @override
  String get ready => '就绪';

  @override
  String get unavailable => '不可用';

  @override
  String get processing => '处理中';

  @override
  String get stopped => '已停止';

  @override
  String get starting => '正在启动';

  @override
  String get running => '运行中';

  @override
  String get stopping => '正在停止';

  @override
  String get unhealthy => '不健康';

  @override
  String get crashed => '已崩溃';

  @override
  String get themeFollowSystem => '跟随系统';

  @override
  String get themeLight => '浅色';

  @override
  String get themeDark => '深色';

  @override
  String get themeTooltip => '主题';

  @override
  String get operationInProgress => '已有操作正在进行';

  @override
  String get minimizeTooltip => '最小化';

  @override
  String get toggleFullscreenTooltip => '切换全屏';

  @override
  String get closeToTrayTooltip => '关闭到托盘';

  @override
  String get webView2Missing => '未检测到 Microsoft Edge WebView2 Runtime。请安装后重试。';

  @override
  String openSystemBrowserFailed(Object uri) {
    return '系统浏览器无法打开 $uri';
  }

  @override
  String downloadFailedHttp(Object statusCode) {
    return '下载失败：HTTP $statusCode';
  }

  @override
  String get blobExportInvalid => 'Blob 导出数据格式无效';

  @override
  String get blobExportTooLarge => 'Blob 导出超过 16 MiB 限制';

  @override
  String get openWebView2DownloadFailed => '系统浏览器无法打开 WebView2 下载页面';

  @override
  String get backendNotRunning => 'Backend 未运行';

  @override
  String get viewRuntimeStatus => '查看运行状态';

  @override
  String get fixConfiguration => '修复配置';

  @override
  String get openWebView2DownloadPage => '打开 WebView2 官方下载页';

  @override
  String get httpMetaDisabled => '已禁用';

  @override
  String get httpMetaUnavailable => '不可用';

  @override
  String httpMetaUnavailableDetail(Object message) {
    return '不可用：$message';
  }

  @override
  String get httpMetaStarting => '启动中';

  @override
  String httpMetaRunning(Object port, Object version) {
    return '运行中，端口 $port，版本 $version';
  }

  @override
  String get httpMetaDegraded => '已降级';

  @override
  String httpMetaDegradedDetail(Object message) {
    return '已降级：$message';
  }

  @override
  String get httpMetaStopped => '已停止';

  @override
  String get noLogs => '暂无日志';

  @override
  String get confirmExternalCors => '允许外部 origin 会使其能够访问 Backend API。是否继续保存？';

  @override
  String get confirmNonLoopback =>
      'Backend 没有鉴权；非回环地址会让同一网络中的设备访问全部 API。是否继续保存？';

  @override
  String get configSavedNoRestart => 'SubDock 配置已保存；不会自动重启服务。';

  @override
  String get savedRestartToApply => '已保存；重启 Backend 后生效。';

  @override
  String get restartNow => '立即重启';

  @override
  String get cancel => '取消';

  @override
  String get continueAction => '继续';

  @override
  String componentUpdatedTo(Object version) {
    return '已更新到 $version';
  }

  @override
  String get componentPackageVersion => '安装包版本';

  @override
  String get componentRolledBack => '已回滚到上一版本';

  @override
  String get componentReadingVersion => '正在读取已安装版本…';

  @override
  String componentCurrentWithPrevious(Object current, Object previous) {
    return '当前 $current，上一版 $previous';
  }

  @override
  String componentUpdateAvailable(
    Object available,
    Object current,
    Object previous,
  ) {
    return '当前 $current，可更新到 $available，上一版 $previous';
  }

  @override
  String componentUpToDate(Object current, Object previous) {
    return '当前 $current 已是最新版本，上一版 $previous';
  }

  @override
  String get subdockConfigHeading => 'SubDock 配置';

  @override
  String configurationInvalid(Object error) {
    return '配置文件无效：$error';
  }

  @override
  String get resetSubdockConfig => '重置 SubDock 配置';

  @override
  String get enableHttpMeta => '启用 HTTP-META';

  @override
  String get enableHttpMetaSubtitle => '辅助启动失败时 Backend 仍会继续运行';

  @override
  String get saveSubdockConfig => '保存 SubDock 配置';

  @override
  String get backendConfigHeading => 'Backend 配置';

  @override
  String get mergeMode => '合并模式';

  @override
  String get advancedRawEnv => '高级原始 ENV';

  @override
  String get advancedRawEnvSubtitle => '直接编辑完整 Backend 环境变量';

  @override
  String lineNumber(Object line) {
    return '第 $line 行：';
  }

  @override
  String get checkForUpdates => '检查更新';

  @override
  String get update => '更新';

  @override
  String get rollback => '回滚';
}
