import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:github/github.dart';
import 'package:go_router/go_router.dart';
import 'package:material_symbols_icons/symbols.dart';
import 'package:qisheng_player/app_paths.dart' as app_paths;
import 'package:qisheng_player/app_settings.dart';
import 'package:qisheng_player/component/cp/cp_components.dart';
import 'package:qisheng_player/component/settings_tile.dart';
import 'package:qisheng_player/hotkeys_helper.dart';
import 'package:qisheng_player/page/page_scaffold.dart';
import 'package:qisheng_player/page/settings_page/cpfeedback_key.dart';
import 'package:qisheng_player/src/rust/api/utils.dart';
import 'package:qisheng_player/utils.dart';

class CreateIssueTile extends StatelessWidget {
  const CreateIssueTile({super.key});

  @override
  Widget build(BuildContext context) {
    return SettingsTile(
      description: "报告问题",
      action: FilledButton.icon(
        onPressed: () => context.push(app_paths.SETTINGS_ISSUE_PAGE),
        label: const Text("创建问题"),
        icon: const Icon(Symbols.bug_report_rounded),
      ),
    );
  }
}

class SettingsIssuePage extends StatefulWidget {
  const SettingsIssuePage({
    super.key,
    this.onLaunchUrl,
  });

  /// 可选的外部链接跳转回调（在测试中用于拦截验证生成的网页 URL）。
  final Future<bool> Function({required String uri})? onLaunchUrl;

  @override
  State<SettingsIssuePage> createState() => _SettingsIssuePageState();
}

class _SettingsIssuePageState extends State<SettingsIssuePage> {
  final _titleController = TextEditingController();
  final _descController = TextEditingController();
  final _logController = TextEditingController();
  final _scrollController = ScrollController();
  bool _submitting = false;

  @override
  void initState() {
    super.initState();
    _loadLogs();
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descController.dispose();
    _logController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  void _loadLogs() {
    final buffer = StringBuffer();
    buffer.writeln('=== 歧声播放器运行诊断日志 ===');
    buffer.writeln('版本: v${AppSettings.version}');
    buffer.writeln('系统: ${Platform.operatingSystem} ${Platform.operatingSystemVersion}');
    buffer.writeln('Dart: ${Platform.version.split(' ').first}');
    buffer.writeln('====================================');
    for (final event in LOGGER_MEMORY.buffer) {
      for (final line in event.lines) {
        buffer.writeln(line);
      }
    }
    _logController.text = buffer.toString();
  }

  Future<void> _copyLogs() async {
    final text = _logController.text;
    if (text.isEmpty) {
      showTextOnSnackBar("日志内容为空");
      return;
    }
    try {
      await Clipboard.setData(ClipboardData(text: text));
      showTextOnSnackBar("日志已复制到剪贴板");
    } catch (err, trace) {
      LOGGER.e("复制日志异常: $err", stackTrace: trace);
      showTextOnSnackBar("复制日志异常: $err");
    }
  }

  void _refreshLogs() {
    _loadLogs();
    showTextOnSnackBar("日志已刷新");
  }

  void _clearLogs() {
    _logController.clear();
    showTextOnSnackBar("日志已清空");
  }

  void _handleBack(BuildContext context) {
    try {
      if (context.canPop()) {
        context.pop();
        return;
      }
    } catch (_) {}
    if (Navigator.of(context).canPop()) {
      Navigator.of(context).pop();
      return;
    }
    try {
      context.go(app_paths.SETTINGS_PAGE);
    } catch (_) {
      Navigator.of(context).maybePop();
    }
  }

  Future<void> _launchUri(String uri) async {
    if (widget.onLaunchUrl != null) {
      await widget.onLaunchUrl!(uri: uri);
      return;
    }
    try {
      await launchInBrowser(uri: uri);
    } catch (e) {
      LOGGER.w("无法在外部浏览器中打开: $e");
      showTextOnSnackBar("无法在外部浏览器中打开链接");
    }
  }

  void _openInBrowser() {
    final title = _titleController.text.trim();
    final desc = _descController.text.trim();
    final log = _logController.text.trim();

    final String safeLog;
    if (log.length > 3000) {
      safeLog = '...（前略，已截取最新日志）...\n${log.substring(log.length - 3000)}';
    } else {
      safeLog = log;
    }

    final body = StringBuffer()
      ..writeln('## 问题描述')
      ..writeln(desc.isEmpty ? '（请在此详细描述遇到的问题与复现步骤）' : desc)
      ..writeln()
      ..writeln('## 运行环境')
      ..writeln('- 歧声播放器版本: ${AppSettings.version}')
      ..writeln('- 操作系统: ${Platform.operatingSystem} ${Platform.operatingSystemVersion}')
      ..writeln('- Dart 运行时: ${Platform.version.split(' ').first}')
      ..writeln()
      ..writeln('## 运行日志')
      ..writeln('```text')
      ..writeln(safeLog.isEmpty ? '（无日志）' : safeLog)
      ..writeln('```');

    final uri = Uri.https(
      'github.com',
      '/${AppSettings.releaseRepoOwner}/${AppSettings.releaseRepoName}/issues/new',
      {
        if (title.isNotEmpty) 'title': title,
        'body': body.toString(),
      },
    );

    _launchUri(uri.toString());
  }

  Future<void> _createIssueInApp() async {
    final title = _titleController.text.trim();
    if (title.isEmpty) {
      showTextOnSnackBar("请输入问题标题");
      return;
    }

    if (CPFEEDBACK_KEY.trim().isEmpty) {
      showTextOnSnackBar("应用内反馈 Token 未配置，请点击“在 GitHub 网页提交”");
      return;
    }

    setState(() => _submitting = true);

    final cpfeedback = GitHub(
      auth: const Authentication.withToken(CPFEEDBACK_KEY),
    );
    final issueBodyBuilder = StringBuffer()
      ..writeln("## 描述")
      ..writeln(_descController.text.trim())
      ..writeln()
      ..writeln("## 运行环境")
      ..writeln("- 歧声播放器版本: ${AppSettings.version}")
      ..writeln("- 操作系统: ${Platform.operatingSystem} ${Platform.operatingSystemVersion}")
      ..writeln()
      ..writeln("## 日志")
      ..writeln("```text")
      ..writeln(_logController.text.trim())
      ..writeln("```");

    final issue = IssueRequest(
      title: title,
      body: issueBodyBuilder.toString(),
    );

    try {
      await cpfeedback.issues.create(
        RepositorySlug(
          AppSettings.releaseRepoOwner,
          AppSettings.releaseRepoName,
        ),
        issue,
      );

      if (mounted) {
        showTextOnSnackBar("创建成功");
      }
    } catch (err, trace) {
      LOGGER.e(err, stackTrace: trace);
      if (mounted) {
        showTextOnSnackBar("创建失败: $err");
      }
    } finally {
      if (mounted) {
        setState(() => _submitting = false);
      }
      cpfeedback.dispose();
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return PageScaffold(
      title: '报告问题',
      subtitle: '提交软件缺陷、崩溃异常或改进建议，帮助歧声播放器变得更好。',
      titleAction: CpIconButton(
        tooltip: '返回设置',
        icon: const Icon(Symbols.arrow_back_rounded),
        onPressed: () => _handleBack(context),
      ),
      body: SingleChildScrollView(
        controller: _scrollController,
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 110),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 860),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _buildIssueCard(context, scheme),
                const SizedBox(height: 16),
                _buildLogCard(context, scheme),
                const SizedBox(height: 20),
                _buildActionBar(context, scheme),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildIssueCard(BuildContext context, ColorScheme scheme) {
    return CpSurface(
      tone: CpSurfaceTone.card,
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Symbols.bug_report_rounded, color: scheme.primary, size: 22),
              const SizedBox(width: 8),
              Text(
                '问题信息',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: scheme.onSurface,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Focus(
            onFocusChange: HotkeysHelper.onFocusChanges,
            child: TextField(
              controller: _titleController,
              autofocus: true,
              style: TextStyle(fontSize: 14.5, color: scheme.onSurface),
              decoration: InputDecoration(
                labelText: '问题标题',
                hintText: '简要概括遇到的问题或建议 (例如: 最小化托盘后无法唤出)',
                prefixIcon: const Icon(Symbols.title_rounded, size: 20),
                filled: true,
                fillColor:
                    scheme.surfaceContainerHighest.withValues(alpha: 0.35),
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(
                    color: scheme.outlineVariant.withValues(alpha: 0.4),
                  ),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(
                    color: scheme.outlineVariant.withValues(alpha: 0.4),
                  ),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: scheme.primary, width: 1.5),
                ),
              ),
            ),
          ),
          const SizedBox(height: 16),
          Focus(
            onFocusChange: HotkeysHelper.onFocusChanges,
            child: TextField(
              controller: _descController,
              minLines: 5,
              maxLines: 9,
              style: TextStyle(
                fontSize: 14,
                color: scheme.onSurface,
                height: 1.45,
              ),
              decoration: InputDecoration(
                labelText: '问题详细描述',
                hintText: '请详细描述您遇到的问题现象、复现步骤或改进建议：\n1. 现象描述：\n2. 复现步骤：\n3. 期望行为：',
                alignLabelWithHint: true,
                prefixIcon: const Padding(
                  padding: EdgeInsets.only(bottom: 80),
                  child: Icon(Symbols.description_rounded, size: 20),
                ),
                filled: true,
                fillColor:
                    scheme.surfaceContainerHighest.withValues(alpha: 0.35),
                contentPadding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(
                    color: scheme.outlineVariant.withValues(alpha: 0.4),
                  ),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(
                    color: scheme.outlineVariant.withValues(alpha: 0.4),
                  ),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide(color: scheme.primary, width: 1.5),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLogCard(BuildContext context, ColorScheme scheme) {
    return CpSurface(
      tone: CpSurfaceTone.card,
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Symbols.terminal_rounded, color: scheme.primary, size: 22),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  '运行日志与环境',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: scheme.onSurface,
                  ),
                ),
              ),
              Wrap(
                spacing: 6,
                children: [
                  TextButton.icon(
                    key: const ValueKey('copy-log-btn'),
                    onPressed: _copyLogs,
                    icon: const Icon(Symbols.content_copy_rounded, size: 16),
                    label: const Text('复制日志'),
                    style: TextButton.styleFrom(
                      visualDensity: VisualDensity.compact,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 6),
                    ),
                  ),
                  TextButton.icon(
                    key: const ValueKey('refresh-log-btn'),
                    onPressed: _refreshLogs,
                    icon: const Icon(Symbols.refresh_rounded, size: 16),
                    label: const Text('刷新'),
                    style: TextButton.styleFrom(
                      visualDensity: VisualDensity.compact,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 6),
                    ),
                  ),
                  TextButton.icon(
                    key: const ValueKey('clear-log-btn'),
                    onPressed: _clearLogs,
                    icon: const Icon(Symbols.delete_outline_rounded, size: 16),
                    label: const Text('清空'),
                    style: TextButton.styleFrom(
                      visualDensity: VisualDensity.compact,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 10, vertical: 6),
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            '日志包含系统环境与最近运行输出，您可以自由编辑或删除敏感内容。',
            style: TextStyle(
              fontSize: 12.5,
              color: scheme.onSurface.withValues(alpha: 0.62),
            ),
          ),
          const SizedBox(height: 12),
          Focus(
            onFocusChange: HotkeysHelper.onFocusChanges,
            child: CpSurface(
              tone: CpSurfaceTone.subtle,
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              child: TextField(
                controller: _logController,
                minLines: 6,
                maxLines: 12,
                style: TextStyle(
                  fontSize: 12,
                  fontFamily: 'monospace',
                  color: scheme.onSurface.withValues(alpha: 0.9),
                  height: 1.4,
                ),
                decoration: const InputDecoration(
                  hintText: '暂无运行日志',
                  border: InputBorder.none,
                  contentPadding: EdgeInsets.all(8),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionBar(BuildContext context, ColorScheme scheme) {
    return CpSurface(
      tone: CpSurfaceTone.card,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Wrap(
        alignment: WrapAlignment.spaceBetween,
        crossAxisAlignment: WrapCrossAlignment.center,
        spacing: 12,
        runSpacing: 12,
        children: [
          OutlinedButton.icon(
            key: const ValueKey('back-to-settings-btn'),
            onPressed: () => _handleBack(context),
            icon: const Icon(Symbols.arrow_back_rounded, size: 18),
            label: const Text('返回设置'),
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
          ),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              FilledButton.tonalIcon(
                key: const ValueKey('submit-github-btn'),
                onPressed: _openInBrowser,
                icon: const Icon(Symbols.open_in_new_rounded, size: 18),
                label: const Text('在 GitHub 网页提交'),
                style: FilledButton.styleFrom(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              ),
              FilledButton.icon(
                key: const ValueKey('submit-inapp-btn'),
                onPressed: _submitting ? null : _createIssueInApp,
                icon: const Icon(Symbols.send_rounded, size: 18),
                label: Text(_submitting ? '正在提交...' : '应用内提交'),
                style: FilledButton.styleFrom(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
