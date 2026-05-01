import 'dart:async';

import 'package:qisheng_player/app_preference.dart';
import 'package:qisheng_player/app_settings.dart';
import 'package:qisheng_player/src/rust/api/utils.dart';
import 'package:qisheng_player/utils.dart';
import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:github/github.dart';
import 'package:material_symbols_icons/symbols.dart';

Future<Release> fetchLatestRelease() {
  return AppSettings.github.repositories
      .listReleases(
        RepositorySlug(
          AppSettings.releaseRepoOwner,
          AppSettings.releaseRepoName,
        ),
      )
      .first;
}

int _versionValue(String version) {
  final normalized = version.trim().replaceFirst(RegExp(r'^[vV]'), '');
  final parts = normalized.split('.');
  final major = parts.isNotEmpty ? int.tryParse(parts[0]) ?? 0 : 0;
  final minor = parts.length > 1 ? int.tryParse(parts[1]) ?? 0 : 0;
  final patch = parts.length > 2 ? int.tryParse(parts[2]) ?? 0 : 0;
  return major * 1000000 + minor * 1000 + patch;
}

bool isNewerRelease(Release release) {
  final tag = release.tagName;
  if (tag == null || tag.trim().isEmpty) return false;
  return _versionValue(tag) > _versionValue(AppSettings.version);
}

Future<Release?> checkForNewRelease() async {
  final release = await fetchLatestRelease();
  return isNewerRelease(release) ? release : null;
}

class StartupUpdatePrompt extends StatefulWidget {
  const StartupUpdatePrompt({super.key, required this.child});

  final Widget child;

  @override
  State<StartupUpdatePrompt> createState() => _StartupUpdatePromptState();
}

class _StartupUpdatePromptState extends State<StartupUpdatePrompt> {
  bool _checked = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_checked) return;
    _checked = true;
    unawaited(_check());
  }

  Future<void> _check() async {
    try {
      final release = await checkForNewRelease();
      if (release == null) return;
      if (release.tagName == AppPreference.instance.ignoredUpdateTag) return;
      if (!mounted) return;
      await showDialog(
        context: context,
        builder: (context) => NewestUpdateView(
          release: release,
          showIgnoreAction: true,
          onIgnore: () async {
            AppPreference.instance.ignoredUpdateTag = release.tagName;
            await AppPreference.instance.save();
          },
        ),
      );
    } catch (err, trace) {
      LOGGER.e("[update check] $err", stackTrace: trace);
    }
  }

  @override
  Widget build(BuildContext context) => widget.child;
}

class CheckForUpdate extends StatefulWidget {
  const CheckForUpdate({super.key});

  @override
  State<CheckForUpdate> createState() => _CheckForUpdateState();
}

class _CheckForUpdateState extends State<CheckForUpdate> {
  bool isChecking = false;
  @override
  Widget build(BuildContext context) {
    return Row(children: [
      FilledButton.icon(
        icon: const Icon(Symbols.update),
        label: const Text("检查更新"),
        onPressed: isChecking
            ? null
            : () async {
                setState(() {
                  isChecking = true;
                });

                try {
                  final newest = await checkForNewRelease();
                  if (newest != null) {
                    if (context.mounted) {
                      showDialog(
                        context: context,
                        builder: (context) => NewestUpdateView(release: newest),
                      );
                    }
                  } else {
                    if (context.mounted) {
                      showTextOnSnackBar("无新版本");
                    }
                  }
                } catch (err, trace) {
                  LOGGER.e(err, stackTrace: trace);
                  if (context.mounted) {
                    showTextOnSnackBar("网络异常");
                  }
                  setState(() {
                    isChecking = false;
                  });
                }

                setState(() {
                  isChecking = false;
                });
              },
      ),
      const Padding(
        padding: EdgeInsets.symmetric(horizontal: 8.0),
        child: Text("当前版本 ${AppSettings.version}"),
      ),
      if (isChecking)
        const Padding(
          padding: EdgeInsets.only(left: 16.0),
          child: SizedBox(
            width: 16.0,
            height: 16.0,
            child: CircularProgressIndicator(),
          ),
        ),
    ]);
  }
}

class NewestUpdateView extends StatelessWidget {
  const NewestUpdateView({
    super.key,
    required this.release,
    this.showIgnoreAction = false,
    this.onIgnore,
  });

  final Release release;
  final bool showIgnoreAction;
  final Future<void> Function()? onIgnore;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.only(bottom: 16.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    release.name ?? "新版本",
                    style: TextStyle(
                      color: scheme.onSurface,
                      fontSize: 18.0,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(width: 16.0),
                  Text(
                    "${release.tagName}\n${release.publishedAt}",
                    style: TextStyle(color: scheme.onSurface),
                  ),
                ],
              ),
            ),
            Expanded(
              child: Markdown(
                data: release.body ?? "",
                onTapLink: (text, href, title) {
                  if (href != null) {
                    launchInBrowser(uri: href);
                  }
                },
                padding: EdgeInsets.zero,
                styleSheet: MarkdownStyleSheet.fromTheme(Theme.of(context)),
              ),
            ),
            Padding(
              padding: const EdgeInsets.only(top: 16.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () {
                      Navigator.pop(context);
                    },
                    child: const Text("取消"),
                  ),
                  if (showIgnoreAction) ...[
                    const SizedBox(width: 16.0),
                    TextButton(
                      onPressed: () async {
                        await onIgnore?.call();
                        if (context.mounted) {
                          Navigator.pop(context);
                        }
                      },
                      child: const Text("不再提示此版本"),
                    ),
                  ],
                  const SizedBox(width: 16.0),
                  TextButton.icon(
                    onPressed: () {
                      if (release.htmlUrl != null) {
                        launchInBrowser(uri: release.htmlUrl!);
                      }

                      Navigator.pop(context);
                    },
                    icon: const Icon(Symbols.arrow_outward),
                    label: const Text("获取更新"),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
