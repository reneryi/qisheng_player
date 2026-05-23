import 'dart:async';

import 'package:qisheng_player/app_preference.dart';
import 'package:qisheng_player/app_settings.dart';
import 'package:qisheng_player/src/rust/api/utils.dart';
import 'package:qisheng_player/utils.dart';
import 'package:flutter/material.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import 'package:github/github.dart';
import 'package:material_symbols_icons/symbols.dart';

class ReleaseVersion implements Comparable<ReleaseVersion> {
  const ReleaseVersion(this.major, this.minor, this.patch);

  final int major;
  final int minor;
  final int patch;

  static final _versionPattern = RegExp(r'^[vV]?(\d+)\.(\d+)\.(\d+)$');

  static ReleaseVersion? parse(String? raw) {
    final value = raw?.trim();
    if (value == null || value.isEmpty) return null;
    final match = _versionPattern.firstMatch(value);
    if (match == null) return null;
    return ReleaseVersion(
      int.parse(match.group(1)!),
      int.parse(match.group(2)!),
      int.parse(match.group(3)!),
    );
  }

  @override
  int compareTo(ReleaseVersion other) {
    final majorCompare = major.compareTo(other.major);
    if (majorCompare != 0) return majorCompare;
    final minorCompare = minor.compareTo(other.minor);
    if (minorCompare != 0) return minorCompare;
    return patch.compareTo(other.patch);
  }

  bool operator >(ReleaseVersion other) => compareTo(other) > 0;
}

Stream<Release> fetchReleases() {
  return AppSettings.github.repositories.listReleases(
    RepositorySlug(
      AppSettings.releaseRepoOwner,
      AppSettings.releaseRepoName,
    ),
  );
}

bool _isQishengRelease(Release release) {
  final name = release.name?.trim().toLowerCase() ?? '';
  if (name.startsWith('qisheng player')) return true;

  final assets = release.assets ?? const <ReleaseAsset>[];
  return assets.any((asset) {
    final assetName = asset.name?.trim().toLowerCase() ?? '';
    return assetName.startsWith('qisheng-player-v');
  });
}

@visibleForTesting
Release? findLatestStableRelease(
  Iterable<Release> releases, {
  String currentVersion = AppSettings.version,
}) {
  final current = ReleaseVersion.parse(currentVersion);
  if (current == null) {
    LOGGER.w('[update check] invalid current version: $currentVersion');
    return null;
  }

  Release? latest;
  ReleaseVersion? latestVersion;
  for (final release in releases) {
    if (release.isDraft == true || release.isPrerelease == true) continue;
    if (!_isQishengRelease(release)) {
      LOGGER.w('[update check] ignore non-qisheng release: ${release.tagName}');
      continue;
    }
    final version = ReleaseVersion.parse(release.tagName);
    if (version == null) {
      LOGGER.w('[update check] ignore invalid release tag: ${release.tagName}');
      continue;
    }
    if (version.compareTo(current) <= 0) continue;
    if (latestVersion == null || version > latestVersion) {
      latest = release;
      latestVersion = version;
    }
  }
  return latest;
}

bool isNewerRelease(Release release) {
  if (release.isDraft == true || release.isPrerelease == true) return false;
  if (!_isQishengRelease(release)) return false;
  final releaseVersion = ReleaseVersion.parse(release.tagName);
  final currentVersion = ReleaseVersion.parse(AppSettings.version);
  if (releaseVersion == null || currentVersion == null) return false;
  return releaseVersion > currentVersion;
}

Future<Release?> checkForNewRelease() async {
  final releases = await fetchReleases().toList();
  return findLatestStableRelease(releases);
}

class StartupUpdatePrompt extends StatefulWidget {
  const StartupUpdatePrompt({
    super.key,
    required this.child,
    this.checkForRelease = checkForNewRelease,
  });

  final Widget child;
  final Future<Release?> Function() checkForRelease;

  @override
  State<StartupUpdatePrompt> createState() => _StartupUpdatePromptState();
}

class _StartupUpdatePromptState extends State<StartupUpdatePrompt> {
  static const _maxCheckAttempts = 3;
  static const _retryDelay = Duration(milliseconds: 800);

  bool _checked = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_checked) return;
    _checked = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        unawaited(_check());
      }
    });
  }

  Future<void> _check() async {
    for (var attempt = 1; attempt <= _maxCheckAttempts; attempt++) {
      try {
        final release = await widget.checkForRelease();
        if (!mounted) return;
        await _showReleaseIfNeeded(release);
        return;
      } catch (err, trace) {
        LOGGER.e("[update check] attempt $attempt failed: $err",
            stackTrace: trace);
        if (attempt >= _maxCheckAttempts) return;
        await Future<void>.delayed(_retryDelay);
        if (!mounted) return;
      }
    }
  }

  Future<void> _showReleaseIfNeeded(Release? release) async {
    if (release == null) return;
    if (release.tagName == AppPreference.instance.ignoredUpdateTag) return;
    if (!mounted) return;
    final hasDialogContext = await _waitForDialogContext();
    if (!hasDialogContext || !mounted) {
      LOGGER.w('[update check] navigator context unavailable');
      return;
    }
    final dialogContext = _dialogContext;
    if (dialogContext == null || !dialogContext.mounted) return;
    await showDialog(
      context: dialogContext,
      builder: (context) => NewestUpdateView(
        release: release,
        showIgnoreAction: true,
        onIgnore: () async {
          AppPreference.instance.ignoredUpdateTag = release.tagName;
          await AppPreference.instance.save();
        },
      ),
    );
  }

  Future<bool> _waitForDialogContext() async {
    for (var i = 0; i < 6; i++) {
      if (_dialogContext != null) return true;
      await Future<void>.delayed(const Duration(milliseconds: 120));
      if (!mounted) return false;
    }
    return false;
  }

  BuildContext? get _dialogContext {
    final overlayContext = ROUTER_KEY.currentState?.overlay?.context;
    if (overlayContext != null) return overlayContext;
    if (Navigator.maybeOf(context) != null) return context;
    return null;
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
