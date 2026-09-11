// ignore: unused_import
import 'package:intl/intl.dart' as intl;

import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get appTitle => 'SubDock';

  @override
  String get manage => 'Manage';

  @override
  String get runtimeStatus => 'Runtime Status';

  @override
  String get logs => 'Logs';

  @override
  String get settings => 'Settings';

  @override
  String get start => 'Start';

  @override
  String get stop => 'Stop';

  @override
  String get restart => 'Restart';

  @override
  String get save => 'Save';

  @override
  String get ready => 'Ready';

  @override
  String get unavailable => 'Unavailable';

  @override
  String get processing => 'Processing';

  @override
  String get stopped => 'Stopped';

  @override
  String get starting => 'Starting';

  @override
  String get running => 'Running';

  @override
  String get stopping => 'Stopping';

  @override
  String get unhealthy => 'Unhealthy';

  @override
  String get crashed => 'Crashed';

  @override
  String get themeFollowSystem => 'Follow system';

  @override
  String get themeLight => 'Light';

  @override
  String get themeDark => 'Dark';

  @override
  String get themeTooltip => 'Theme';

  @override
  String get operationInProgress => 'An operation is already in progress';

  @override
  String get minimizeTooltip => 'Minimize';

  @override
  String get toggleFullscreenTooltip => 'Toggle fullscreen';

  @override
  String get closeToTrayTooltip => 'Close to tray';

  @override
  String get webView2Missing =>
      'Microsoft Edge WebView2 Runtime was not detected. Install it and try again.';

  @override
  String openSystemBrowserFailed(Object uri) {
    return 'The system browser could not open $uri';
  }

  @override
  String downloadFailedHttp(Object statusCode) {
    return 'Download failed: HTTP $statusCode';
  }

  @override
  String get blobExportInvalid => 'Blob export data is invalid';

  @override
  String get blobExportTooLarge => 'Blob export exceeds the 16 MiB limit';

  @override
  String get openWebView2DownloadFailed =>
      'The system browser could not open the WebView2 download page';

  @override
  String get backendNotRunning => 'Backend is not running';

  @override
  String get viewRuntimeStatus => 'View runtime status';

  @override
  String get fixConfiguration => 'Fix configuration';

  @override
  String get openWebView2DownloadPage =>
      'Open the official WebView2 download page';

  @override
  String get httpMetaDisabled => 'Disabled';

  @override
  String get httpMetaUnavailable => 'Unavailable';

  @override
  String httpMetaUnavailableDetail(Object message) {
    return 'Unavailable: $message';
  }

  @override
  String get httpMetaStarting => 'Starting';

  @override
  String httpMetaRunning(Object port, Object version) {
    return 'Running on port $port, version $version';
  }

  @override
  String get httpMetaDegraded => 'Degraded';

  @override
  String httpMetaDegradedDetail(Object message) {
    return 'Degraded: $message';
  }

  @override
  String get httpMetaStopped => 'Stopped';

  @override
  String get noLogs => 'No logs yet';

  @override
  String get confirmExternalCors =>
      'Allowing an external origin lets it reach the Backend API. Save anyway?';

  @override
  String get confirmNonLoopback =>
      'The Backend has no authentication; a non-loopback address lets other devices on the network reach every API. Save anyway?';

  @override
  String get configSavedNoRestart =>
      'SubDock configuration saved; the service will not restart automatically.';

  @override
  String get savedRestartToApply =>
      'Saved; takes effect after the Backend restarts.';

  @override
  String get restartNow => 'Restart now';

  @override
  String get cancel => 'Cancel';

  @override
  String get continueAction => 'Continue';

  @override
  String componentUpdatedTo(Object version) {
    return 'Updated to $version';
  }

  @override
  String get componentPackageVersion => 'Package version';

  @override
  String get componentRolledBack => 'Rolled back to the previous version';

  @override
  String get componentReadingVersion => 'Reading the installed version…';

  @override
  String componentCurrentWithPrevious(Object current, Object previous) {
    return 'Current $current, previous $previous';
  }

  @override
  String componentUpdateAvailable(
    Object available,
    Object current,
    Object previous,
  ) {
    return 'Current $current, can update to $available, previous $previous';
  }

  @override
  String componentUpToDate(Object current, Object previous) {
    return 'Current $current is the latest version, previous $previous';
  }

  @override
  String get subdockConfigHeading => 'SubDock Configuration';

  @override
  String configurationInvalid(Object error) {
    return 'Invalid configuration file: $error';
  }

  @override
  String get resetSubdockConfig => 'Reset SubDock configuration';

  @override
  String get enableHttpMeta => 'Enable HTTP-META';

  @override
  String get enableHttpMetaSubtitle =>
      'The Backend keeps running even if the auxiliary start fails';

  @override
  String get saveSubdockConfig => 'Save SubDock configuration';

  @override
  String get backendConfigHeading => 'Backend Configuration';

  @override
  String get mergeMode => 'Merge mode';

  @override
  String get advancedRawEnv => 'Advanced raw ENV';

  @override
  String get advancedRawEnvSubtitle =>
      'Edit the full Backend environment variables directly';

  @override
  String lineNumber(Object line) {
    return 'Line $line:';
  }

  @override
  String get checkForUpdates => 'Check for updates';

  @override
  String get update => 'Update';

  @override
  String get rollback => 'Rollback';
}
