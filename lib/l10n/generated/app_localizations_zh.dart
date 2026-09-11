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
}
