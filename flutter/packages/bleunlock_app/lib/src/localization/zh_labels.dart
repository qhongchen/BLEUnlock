String zhDisplayText(String text) {
  final trimmed = text.trim();
  if (trimmed.isEmpty) {
    return text;
  }

  final exact = _exactLabels[trimmed];
  if (exact != null) {
    return exact;
  }

  final lastSeenPrefix = 'Last seen ';
  if (trimmed.startsWith(lastSeenPrefix)) {
    return '最后出现 ${trimmed.substring(lastSeenPrefix.length)}';
  }

  final latestEventPrefix = 'latest event ';
  if (trimmed.startsWith(latestEventPrefix)) {
    return '最新事件 ${trimmed.substring(latestEventPrefix.length)}';
  }

  final latestScanPrefix = 'latest scan ';
  if (trimmed.startsWith(latestScanPrefix)) {
    return '最新扫描 ${trimmed.substring(latestScanPrefix.length)}';
  }

  final devicePrefix = 'device ';
  if (trimmed.startsWith(devicePrefix)) {
    return '设备 ${trimmed.substring(devicePrefix.length)}';
  }

  final logsMatch = RegExp(r'^logs (\d+)$').firstMatch(trimmed);
  if (logsMatch != null) {
    return '日志 ${logsMatch.group(1)}';
  }

  final scansMatch = RegExp(r'^scans (\d+)$').firstMatch(trimmed);
  if (scansMatch != null) {
    return '扫描 ${scansMatch.group(1)}';
  }

  final progressMatch = RegExp(r'^(\d+)/(\d+) captured$').firstMatch(trimmed);
  if (progressMatch != null) {
    return '已捕获 ${progressMatch.group(1)}/${progressMatch.group(2)}';
  }

  final avgRssiMatch = RegExp(r'^(-?\d+) dBm avg$').firstMatch(trimmed);
  if (avgRssiMatch != null) {
    return '${avgRssiMatch.group(1)} dBm 平均';
  }

  final rssiRangeMatch =
      RegExp(r'^(-?\d+) to (-?\d+) dBm$').firstMatch(trimmed);
  if (rssiRangeMatch != null) {
    return '${rssiRangeMatch.group(1)} 至 ${rssiRangeMatch.group(2)} dBm';
  }

  final avgIntervalPrefix = 'avg interval ';
  if (trimmed.startsWith(avgIntervalPrefix)) {
    return '平均间隔 ${trimmed.substring(avgIntervalPrefix.length)}';
  }

  final longestSilencePrefix = 'longest silence ';
  if (trimmed.startsWith(longestSilencePrefix)) {
    return '最长静默 ${trimmed.substring(longestSilencePrefix.length)}';
  }

  final scanPrefix = 'Scan ';
  if (trimmed.startsWith(scanPrefix)) {
    return '扫描 ${trimmed.substring(scanPrefix.length)}';
  }

  final decisionPrefix = 'Decision ';
  if (trimmed.startsWith(decisionPrefix)) {
    return '判定 ${trimmed.substring(decisionPrefix.length)}';
  }

  final runtimeMissingPrefix = 'Runtime evidence missing: ';
  if (trimmed.startsWith(runtimeMissingPrefix)) {
    return '缺少运行证据：'
        '${zhDisplayText(trimmed.substring(runtimeMissingPrefix.length))}';
  }

  final externalPendingPrefix = 'External gate pending: ';
  if (trimmed.startsWith(externalPendingPrefix)) {
    return '外部门禁待验证：'
        '${zhDisplayText(trimmed.substring(externalPendingPrefix.length))}';
  }

  final externalFailedPrefix = 'External gate failed: ';
  if (trimmed.startsWith(externalFailedPrefix)) {
    return '外部门禁失败：'
        '${zhDisplayText(trimmed.substring(externalFailedPrefix.length))}';
  }

  const trayHintPrefix = 'Use the tray menu to ';
  const trayHintSuffix = ' and confirm each action log appears.';
  if (trimmed.startsWith(trayHintPrefix) && trimmed.endsWith(trayHintSuffix)) {
    final actions = trimmed
        .substring(
            trayHintPrefix.length, trimmed.length - trayHintSuffix.length)
        .split(', ')
        .map((action) => _trayActionLabels[action] ?? action)
        .join('、');
    return '使用托盘菜单执行 $actions，并确认每个动作日志都出现。';
  }

  return text;
}

String zhDetailLabel(String detail) {
  return detail.split(' ').map((part) {
    final separator = part.indexOf('=');
    if (separator <= 0) {
      return zhDisplayText(part);
    }
    final key = part.substring(0, separator);
    final value = part.substring(separator + 1);
    return '${_detailKeyLabels[key] ?? key}=${zhDisplayText(value)}';
  }).join(' ');
}

String zhStatusValue(String value) => zhDisplayText(value);

String zhChecklistStatus(String status) {
  switch (status) {
    case 'observed':
    case 'captured':
      return '已捕获';
    case 'unsupported':
      return '不支持';
    case 'not required':
      return '不要求';
    case 'none':
    case 'clear':
      return '无错误';
    case 'ready':
      return '就绪';
    case 'incomplete':
      return '未完成';
    case 'missing':
      return '缺失';
    default:
      return zhDisplayText(status);
  }
}

String zhExternalGateStatus(String status) {
  switch (status) {
    case 'passed':
      return '已通过';
    case 'failed':
      return '失败';
    case 'manual required':
    case 'manualRequired':
      return '待验证';
    default:
      return zhDisplayText(status);
  }
}

String zhProgressLabel({
  required int completed,
  required int required,
  DateTime? latestEvidenceAt,
}) {
  final base = '已捕获 $completed/$required';
  if (latestEvidenceAt == null) {
    return base;
  }
  return '$base · 最新 ${zhTimeLabel(latestEvidenceAt)}';
}

String zhEvidenceCountLabel(int count, DateTime? latestEvidenceAt) {
  if (latestEvidenceAt == null) {
    return '$count 条证据';
  }
  return '$count 条证据 · 最新 ${zhTimeLabel(latestEvidenceAt)}';
}

String zhTimeLabel(DateTime timestamp) {
  final hour = timestamp.hour.toString().padLeft(2, '0');
  final minute = timestamp.minute.toString().padLeft(2, '0');
  final second = timestamp.second.toString().padLeft(2, '0');
  return '$hour:$minute:$second';
}

String zhTrayRunbookHint(String hint) {
  final exact = _exactLabels[hint];
  if (exact != null) {
    return exact;
  }

  const prefix = 'Use the tray menu to ';
  const suffix = ' and confirm each action log appears.';
  if (hint.startsWith(prefix) && hint.endsWith(suffix)) {
    final actions = hint
        .substring(prefix.length, hint.length - suffix.length)
        .split(', ')
        .map((action) => _trayActionLabels[action] ?? action)
        .join('、');
    return '使用托盘菜单执行 $actions，并确认每个动作日志都出现。';
  }

  return zhDisplayText(hint);
}

const Map<String, String> _exactLabels = {
  'Monitoring': '监听中',
  'Scanning': '扫描中',
  'Idle': '空闲',
  'None': '无',
  'Pending plugin': '等待插件',
  'supported': '支持',
  'unsupported': '不支持',
  'permission denied': '权限被拒绝',
  'temporarily unavailable': '暂时不可用',
  'Credential Provider component is not installed': 'Credential Provider 组件未安装',
  'powered off': '蓝牙已关闭',
  'missing secret': '缺少密码',
  'stillLocked': '仍处于锁定状态',
  'manualLock': '主动锁屏',
  'unlockFailed': '解锁失败',
  'autoUnlockSuppressedForRetry': '自动解锁已暂停',
  'failed': '失败',
  'unknown': '未知',
  'enabled': '已开启',
  'disabled': '已关闭',
  'configured': '已配置',
  'missing': '缺失',
  'Close': '靠近',
  'Away': '远离',
  'Lost': '丢失',
  'Visible': '可见',
  'Locked': '已锁定',
  'Stable identity': '身份稳定',
  'Identity changed': '身份变化',
  'Unknown device': '未知设备',
  'No address hint': '无地址提示',
  'No data': '无数据',
  'No scan events': '无扫描事件',
  'BLE scan observed': '已观测到 BLE 扫描',
  'scan': '扫描',
  'decision': '判定',
  'action': '动作',
  'error': '错误',
  'info': '信息',
  'unlocked': '未锁定',
  'locked': '已锁定',
  'displaySleep': '显示器休眠',
  'displayWake': '显示器唤醒',
  'systemSleep': '系统休眠',
  'systemWake': '系统唤醒',
  'Settings loaded': '设置已加载',
  'Bluetooth scanning unavailable': '蓝牙扫描不可用',
  'Auto lock unavailable': '自动锁屏不可用',
  'Select a device first': '请先选择设备',
  'Select one or more devices in Devices before starting monitoring.':
      '请先在设备列表中选择一个或多个设备，再开始监听。',
  'Select one or more devices before starting monitoring.':
      '请先选择一个或多个设备，再开始监听。',
  'Monitoring started': '监听已开始',
  'Monitoring paused': '监听已暂停',
  'Device selected': '设备已选择',
  'Device unselected': '设备已取消选择',
  'Auto unlock unavailable': '自动解锁不可用',
  'Auto unlock confirmation required': '需要确认自动解锁风险',
  'Rules updated': '规则已更新',
  'Startup unavailable': '开机启动不可用',
  'Startup enabled': '开机启动已开启',
  'Startup disabled': '开机启动已关闭',
  'Accessibility settings unavailable': '辅助功能设置不可用',
  'Accessibility settings opened': '已打开辅助功能设置',
  'Secure store unavailable': '安全存储不可用',
  'Auto unlock password saved': '自动解锁密码已保存',
  'Auto unlock password save failed': '自动解锁密码保存失败',
  'Auto unlock password cleared': '自动解锁密码已清除',
  'Auto unlock password clear failed': '自动解锁密码清除失败',
  'Auto unlock password status unavailable': '自动解锁密码状态不可用',
  'Lock unavailable': '锁屏不可用',
  'Locked screen': '已锁屏',
  'Lock failed': '锁屏失败',
  'Open settings requested': '已请求打开设置',
  'Quit requested': '已请求退出',
  'Lock skipped': '已跳过锁屏',
  'Lock unsupported': '不支持锁屏',
  'Wake unsupported': '不支持唤醒',
  'Wake requested': '已请求唤醒',
  'Wake failed': '唤醒失败',
  'Unlock skipped': '已跳过解锁',
  'Unlock unsupported': '不支持解锁',
  'Unlocked session': '会话已解锁',
  'Unlock failed': '解锁失败',
  'Auto unlock suspended': '已暂停自动解锁',
  'Unlock retry scheduled': '已安排解锁重试',
  'Unlock retry skipped': '已跳过解锁重试',
  'Session lock state unavailable': '会话锁定状态不可用',
  'Session locked': '会话已锁定',
  'Session unlocked': '会话已解锁',
  'Display sleep': '显示器休眠',
  'Display wake': '显示器唤醒',
  'System sleep': '系统休眠',
  'System wake': '系统唤醒',
  'No recent devices': '暂无最近设备',
  'Real BLE scan': '真实 BLE 扫描',
  'Locked-session BLE scan': '锁屏 BLE 扫描',
  'Proximity decision': '距离判定',
  'Auto lock action': '自动锁屏动作',
  'Wake action': '唤醒动作',
  'macOS auto unlock action': 'macOS 自动解锁动作',
  'Tray/menu action': '托盘/菜单动作',
  'Tray open settings': '托盘打开设置',
  'Tray start monitoring': '托盘开始监听',
  'Tray pause monitoring': '托盘暂停监听',
  'Tray lock now': '托盘立即锁屏',
  'Tray quit': '托盘退出',
  'Startup action': '开机启动动作',
  'Startup enable': '开启开机启动',
  'Startup disable': '关闭开机启动',
  'Errors': '错误',
  'BLE scan': 'BLE 扫描',
  'Lock and wake': '锁屏与唤醒',
  'macOS auto unlock': 'macOS 自动解锁',
  'Tray menu': '托盘菜单',
  'Startup at login': '开机启动',
  'Windows Credential Provider component': 'Windows Credential Provider 组件',
  'Windows Credential Provider component ready':
      'Windows Credential Provider 组件已就绪',
  'Windows Credential Provider component missing':
      'Windows Credential Provider 组件未安装',
  'Windows Credential Provider component pending':
      'Windows Credential Provider 组件待接入',
  'Windows build verification': 'Windows 构建验证',
  'Lock-screen scan continuity': '锁屏扫描连续性',
  'macOS Accessibility unlock': 'macOS 辅助功能解锁',
  'Tray actions': '托盘动作',
  'Startup at login actions': '开机启动动作',
  'Run flutter build windows on a Windows host.':
      '在 Windows 主机上运行 flutter build windows。',
  'Run the desktop app with a real BLE device and capture scan logs.':
      '使用真实 BLE 设备运行桌面应用，并捕获扫描日志。',
  'Lock the desktop session and confirm scan evidence continues.':
      '锁定桌面会话，并确认扫描证据仍在持续。',
  'Grant Accessibility permission and validate automatic unlock.':
      '授予辅助功能权限，并验证自动解锁。',
  'Use every tray/menu action and confirm action logs.': '使用每个托盘/菜单动作，并确认动作日志。',
  'Toggle startup at login on and off and confirm action logs.':
      '依次开启和关闭开机启动，并确认动作日志。',
  'Scan nearby selected BLE devices': '扫描附近已选择的 BLE 设备',
  'Trigger automatic lock and wake': '触发自动锁屏与唤醒',
  'Validate macOS automatic unlock': '验证 macOS 自动解锁',
  'Check Windows Credential Provider component':
      '检查 Windows Credential Provider 组件',
  'Use every tray menu action': '使用每个托盘菜单动作',
  'Toggle startup at login': '切换开机启动',
  'Capture runtime evidence': '捕获运行证据',
  'Real BLE scan, locked scan, decision': '真实 BLE 扫描、锁屏扫描、距离判定',
  'Auto lock action, wake action': '自动锁屏动作、唤醒动作',
  'Windows Credential Provider component state':
      'Windows Credential Provider 组件状态',
  'Tray open settings, start monitoring, pause monitoring, lock now, quit':
      '托盘打开设置、开始监听、暂停监听、立即锁屏、退出',
  'Startup enable and disable actions': '开启和关闭开机启动动作',
  'Required runtime evidence': '必需运行证据',
  'Start monitoring with a selected BLE device, then lock the session and wait for scan plus decision logs.':
      '选择 BLE 设备后开始监听，然后锁定会话并等待扫描和判定日志。',
  'Move the selected device away until automatic lock is logged, then bring it close again to trigger wake.':
      '将已选择设备移远，直到记录自动锁屏日志；再将设备靠近以触发唤醒。',
  'Enable macOS automatic unlock, grant Accessibility permission, save the password, lock the session, then bring the selected device close.':
      '开启 macOS 自动解锁，授予辅助功能权限，保存密码，锁定会话后再将已选择设备靠近。',
  'Install and register the Windows Credential Provider component before requiring Windows automatic unlock evidence.':
      '先安装并注册 Windows Credential Provider 组件，再要求 Windows 自动解锁证据。',
  'Use each missing tray menu item and confirm the action log appears.':
      '使用每个缺失的托盘菜单项，并确认对应动作日志出现。',
  'Toggle startup at login on and off, then confirm both startup change logs appear.':
      '依次开启和关闭开机启动，并确认两条启动变更日志都出现。',
  'Enable startup at login and confirm the startup enable log appears.':
      '开启开机启动，并确认开启日志出现。',
  'Disable startup at login and confirm the startup disable log appears.':
      '关闭开机启动，并确认关闭日志出现。',
  'Toggle startup at login and confirm the missing startup log appears.':
      '切换开机启动，并确认缺失的启动日志出现。',
  'Capture the missing required evidence for this validation step.':
      '补齐这个验证步骤缺失的必需证据。',
  'Unknown external gate': '未知外部门禁',
};

const Map<String, String> _detailKeyLabels = {
  'level': '级别',
  'platform': '平台',
  'name': '名称',
  'address': '地址',
  'device': '设备',
  'rssi': 'RSSI',
  'reason': '原因',
  'session': '会话',
};

const Map<String, String> _trayActionLabels = {
  'open settings': '打开设置',
  'start monitoring': '开始监听',
  'pause monitoring': '暂停监听',
  'lock now': '立即锁屏',
  'quit': '退出',
};
