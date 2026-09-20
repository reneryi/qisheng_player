import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:qisheng_player/app_preference.dart';
import 'package:qisheng_player/app_settings.dart';
import 'package:qisheng_player/component/ui/modern_dialog.dart';
import 'package:qisheng_player/src/rust/api/utils.dart';
import 'package:qisheng_player/utils.dart';
import 'package:flutter/material.dart';
import 'package:flutter_markdown_plus/flutter_markdown_plus.dart';
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
  bool operator <(ReleaseVersion other) => compareTo(other) < 0;
  bool operator >=(ReleaseVersion other) => compareTo(other) >= 0;
  bool operator <=(ReleaseVersion other) => compareTo(other) <= 0;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ReleaseVersion &&
          major == other.major &&
          minor == other.minor &&
          patch == other.patch;

  @override
  int get hashCode => Object.hash(major, minor, patch);

  @override
  String toString() => '$major.$minor.$patch';
}

Stream<Release> fetchReleases() {
  return AppSettings.github.repositories.listReleases(
    RepositorySlug(
      AppSettings.releaseRepoOwner,
      AppSettings.releaseRepoName,
    ),
  );
}

@visibleForTesting
bool isQishengRelease(Release release) {
  final name = release.name?.trim().toLowerCase() ?? '';
  final tagName = release.tagName?.trim().toLowerCase() ?? '';

  // 1. 精确拦截历史 fork 库残留 (coriander_player)
  if (name.contains('coriander') || tagName.contains('coriander')) {
    return false;
  }
  final assets = release.assets ?? const <ReleaseAsset>[];
  if (assets.any((a) => (a.name?.toLowerCase() ?? '').contains('coriander'))) {
    return false;
  }

  // 2. 匹配栖声专属标志 (标题、Tag 或资产包含 qisheng 或 栖声 或 歧声)
  if (name.contains('qisheng') || name.contains('栖声') || name.contains('歧声')) return true;
  if (tagName.contains('qisheng') || tagName.contains('栖声') || tagName.contains('歧声')) return true;
  if (assets.any((a) {
    final an = a.name?.toLowerCase() ?? '';
    return an.contains('qisheng') || an.contains('栖声') || an.contains('歧声');
  })) {
    return true;
  }

  // 3. 放宽语义版本过滤：只要无历史 fork 污染且符合语义版本规则即视为有效
  if (ReleaseVersion.parse(release.tagName) != null) {
    return true;
  }

  return false;
}

bool _isQishengRelease(Release release) => isQishengRelease(release);

String _unescapeXml(String text) {
  return text
      .replaceAll('&amp;', '&')
      .replaceAll('&lt;', '<')
      .replaceAll('&gt;', '>')
      .replaceAll('&quot;', '"')
      .replaceAll('&#39;', "'")
      .replaceAll('&apos;', "'");
}

String _cleanXmlText(String text) {
  var result = text.trim();
  if (result.startsWith('<![CDATA[') && result.endsWith(']]>')) {
    result = result.substring(9, result.length - 3).trim();
  }
  return _unescapeXml(result);
}

String _htmlToMarkdown(String html) {
  var text = _cleanXmlText(html).replaceAll('&nbsp;', ' ');
  text = text.replaceAllMapped(
    RegExp(r'<h[1-6][^>]*>(.*?)</h[1-6]>', caseSensitive: false, dotAll: true),
    (m) => '\n\n## ${m[1]?.trim()}\n\n',
  );
  text = text.replaceAllMapped(
    RegExp(r'<li[^>]*>(.*?)</li>', caseSensitive: false, dotAll: true),
    (m) => '- ${m[1]?.trim()}\n',
  );
  text = text.replaceAllMapped(
    RegExp(r'<code[^>]*>(.*?)</code>', caseSensitive: false, dotAll: true),
    (m) => '`${m[1]?.trim()}`',
  );
  text = text.replaceAllMapped(
    RegExp(r'<a[^>]+href="([^"]+)"[^>]*>(.*?)</a>', caseSensitive: false, dotAll: true),
    (m) => '[${m[2]?.trim()}](${m[1]})',
  );
  text = text.replaceAll(RegExp(r'</?(?:ul|ol|p|div|span|article|section)[^>]*>', caseSensitive: false), '\n');
  text = text.replaceAll(RegExp(r'<br\s*/?>', caseSensitive: false), '\n');
  text = text.replaceAll(RegExp(r'<[^>]+>'), '');
  text = text.replaceAll(RegExp(r'\n{3,}'), '\n\n');
  return text.trim();
}

@visibleForTesting
List<Release> parseReleasesFromAtom(String xmlContent) {
  final releases = <Release>[];
  final entryMatches = RegExp(r'<entry>([\s\S]*?)</entry>').allMatches(xmlContent);

  for (final entryMatch in entryMatches) {
    final entry = entryMatch.group(1) ?? '';

    final titleMatch = RegExp(r'<title[^>]*>([\s\S]*?)</title>').firstMatch(entry);
    final title = titleMatch != null ? _cleanXmlText(titleMatch.group(1)!) : null;

    final linkMatch = RegExp(r'<link[^>]+href="([^"]+)"').firstMatch(entry);
    final htmlUrl = linkMatch?.group(1);

    String? tagName;
    if (htmlUrl != null) {
      final tagMatch = RegExp(r'/releases/tag/([^/?#"\s]+)').firstMatch(htmlUrl);
      if (tagMatch != null) {
        tagName = Uri.decodeComponent(tagMatch.group(1)!);
      }
    }
    if (tagName == null || tagName.isEmpty) {
      final idMatch = RegExp(r'<id[^>]*>[\s\S]*?/([^/<\s]+)</id>').firstMatch(entry);
      if (idMatch != null) {
        tagName = Uri.decodeComponent(idMatch.group(1)!);
      }
    }
    tagName ??= title;
    if (tagName == null || tagName.isEmpty) continue;

    DateTime? publishedAt;
    final updatedMatch = RegExp(r'<updated>([\s\S]*?)</updated>').firstMatch(entry);
    if (updatedMatch != null) {
      publishedAt = DateTime.tryParse(updatedMatch.group(1)!.trim());
    }

    final contentMatch = RegExp(r'<content[^>]*>([\s\S]*?)</content>').firstMatch(entry);
    final rawContent = contentMatch?.group(1);
    final summaryMatch = RegExp(r'<summary[^>]*>([\s\S]*?)</summary>').firstMatch(entry);
    final rawSummary = summaryMatch?.group(1);

    final body = rawContent != null
        ? _htmlToMarkdown(rawContent)
        : (rawSummary != null ? _htmlToMarkdown(rawSummary) : null);

    releases.add(Release(
      tagName: tagName,
      name: title ?? tagName,
      htmlUrl: htmlUrl,
      body: body,
      publishedAt: publishedAt,
      isDraft: false,
      isPrerelease: tagName.contains('-') || (title?.contains('-') ?? false),
    ));
  }

  return releases;
}

@visibleForTesting
Future<List<Release>> fetchReleasesFromAtom({
  String owner = AppSettings.releaseRepoOwner,
  String repo = AppSettings.releaseRepoName,
  HttpClient? client,
}) async {
  final httpClient = client ?? (HttpClient()..connectionTimeout = const Duration(seconds: 10));
  try {
    final uri = Uri.https('github.com', '/$owner/$repo/releases.atom');
    final request = await httpClient.getUrl(uri);
    request.headers.set(HttpHeaders.userAgentHeader, 'QishengPlayer');
    final response = await request.close();
    if (response.statusCode != HttpStatus.ok) {
      throw HttpException('Atom feed HTTP ${response.statusCode}', uri: uri);
    }
    final content = await utf8.decodeStream(response);
    return parseReleasesFromAtom(content);
  } finally {
    if (client == null) {
      httpClient.close();
    }
  }
}

@visibleForTesting
Future<Release?> fetchLatestReleaseFromRedirect({
  String owner = AppSettings.releaseRepoOwner,
  String repo = AppSettings.releaseRepoName,
  HttpClient? client,
}) async {
  final httpClient = client ?? (HttpClient()..connectionTimeout = const Duration(seconds: 10));
  try {
    final uri = Uri.https('github.com', '/$owner/$repo/releases/latest');
    final request = await httpClient.getUrl(uri);
    request.followRedirects = false;
    request.headers.set(HttpHeaders.userAgentHeader, 'QishengPlayer');
    final response = await request.close();
    await response.drain();

    String? location = response.headers.value(HttpHeaders.locationHeader);
    if ((location == null || location.isEmpty) && response.redirects.isNotEmpty) {
      location = response.redirects.last.location.toString();
    }

    if (location != null && location.isNotEmpty) {
      final match = RegExp(r'/releases/tag/([^/?#"\s]+)').firstMatch(location);
      final tag = match != null ? Uri.decodeComponent(match.group(1)!) : null;
      if (tag != null && tag.isNotEmpty) {
        return Release(
          tagName: tag,
          name: tag,
          htmlUrl: location.startsWith('http')
              ? location
              : 'https://github.com/$owner/$repo/releases/tag/$tag',
          body: '发现新版本 $tag，点击“获取更新”前往发布页面下载更新。',
          isDraft: false,
          isPrerelease: false,
          publishedAt: DateTime.now(),
        );
      }
    }
    return null;
  } finally {
    if (client == null) {
      httpClient.close();
    }
  }
}

class UpdateException implements Exception {
  final String message;
  final Object? cause;
  const UpdateException(this.message, [this.cause]);

  @override
  String toString() => message;
}

class RateLimitException extends UpdateException {
  const RateLimitException([super.message = 'GitHub 访问频率超限，请稍后再试', super.cause]);
}

class NetworkOfflineException extends UpdateException {
  const NetworkOfflineException([super.message = '网络连接不可用', super.cause]);
}

class UpdateCheckState {
  static bool lastCheckUsedFallback = false;
  static bool lastCheckEncounteredRateLimit = false;
}

bool _isRateLimitError(Object? error) {
  if (error == null) return false;
  if (error is RateLimitHit || error is AccessForbidden) return true;
  if (error is GitHubError) {
    final msg = error.message?.toLowerCase() ?? '';
    if (msg.contains('rate limit') || msg.contains('403') || msg.contains('forbidden')) {
      return true;
    }
  }
  if (error is HttpException) {
    final msg = error.message.toLowerCase();
    if (msg.contains('403') || msg.contains('rate limit')) return true;
  }
  final errStr = error.toString().toLowerCase();
  return errStr.contains('rate limit') ||
      errStr.contains('ratelimithit') ||
      errStr.contains('403 forbidden') ||
      errStr.contains('api rate limit exceeded');
}

bool _isNetworkOfflineError(Object? error) {
  if (error == null) return false;
  if (error is SocketException) return true;
  if (error is TimeoutException) return true;
  if (error is HandshakeException) return true;
  final errStr = error.toString().toLowerCase();
  return errStr.contains('socketexception') ||
      errStr.contains('timeoutexception') ||
      errStr.contains('network is unreachable') ||
      errStr.contains('connection refused') ||
      errStr.contains('connection timed out') ||
      errStr.contains('failed host lookup') ||
      errStr.contains('clientexception') ||
      errStr.contains('network offline');
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

@visibleForTesting
Release? findFirstNewerStableRelease(
  Iterable<Release> releases, {
  String currentVersion = AppSettings.version,
}) {
  final current = ReleaseVersion.parse(currentVersion);
  if (current == null) {
    LOGGER.w('[update check] invalid current version: $currentVersion');
    return null;
  }

  for (final release in releases) {
    if (isNewerReleaseForVersion(release, current)) {
      return release;
    }
  }
  return null;
}

@visibleForTesting
bool isNewerReleaseForVersion(Release release, ReleaseVersion currentVersion) {
  if (release.isDraft == true || release.isPrerelease == true) return false;
  if (!_isQishengRelease(release)) return false;
  final releaseVersion = ReleaseVersion.parse(release.tagName);
  if (releaseVersion == null) return false;
  return releaseVersion > currentVersion;
}

bool isNewerRelease(Release release) {
  final currentVersion = ReleaseVersion.parse(AppSettings.version);
  if (currentVersion == null) return false;
  return isNewerReleaseForVersion(release, currentVersion);
}

typedef ReleaseFetcher = Stream<Release> Function();
typedef AtomFetcher = Future<List<Release>> Function();
typedef LatestRedirectFetcher = Future<Release?> Function();

Future<Release?> checkForNewRelease({
  ReleaseFetcher? fetchApiReleases,
  AtomFetcher? fetchAtomReleases,
  LatestRedirectFetcher? fetchLatestRedirect,
}) async {
  final currentVersion = ReleaseVersion.parse(AppSettings.version);
  if (currentVersion == null) {
    LOGGER.w('[update check] invalid current version: ${AppSettings.version}');
    return null;
  }

  UpdateCheckState.lastCheckUsedFallback = false;
  UpdateCheckState.lastCheckEncounteredRateLimit = false;

  bool rateLimitHit = false;
  Object? firstError;
  Object? lastError;

  // Level 1: GitHub REST API
  try {
    final fetcher = fetchApiReleases ?? fetchReleases;
    await for (final release in fetcher()) {
      if (isNewerReleaseForVersion(release, currentVersion)) {
        LOGGER.i('[update check] Tier 1 found newer release: ${release.tagName}');
        return release;
      }
    }
    LOGGER.i('[update check] Tier 1 completed: current version is up to date.');
    return null;
  } catch (err, trace) {
    firstError = err;
    lastError = err;
    if (_isRateLimitError(err)) {
      rateLimitHit = true;
      UpdateCheckState.lastCheckEncounteredRateLimit = true;
      LOGGER.w('[update check] Tier 1 hit GitHub API rate limit: $err');
    } else {
      LOGGER.w('[update check] Tier 1 REST API failed: $err', stackTrace: trace);
    }
  }

  // Level 2: GitHub releases.atom RSS Feed
  try {
    UpdateCheckState.lastCheckUsedFallback = true;
    LOGGER.i('[update check] Tier 2: falling back to releases.atom RSS feed...');
    final atomFetcher = fetchAtomReleases ?? fetchReleasesFromAtom;
    final atomReleases = await atomFetcher();
    if (atomReleases.isNotEmpty) {
      for (final release in atomReleases) {
        if (isNewerReleaseForVersion(release, currentVersion)) {
          LOGGER.i('[update check] Tier 2 found newer release: ${release.tagName}');
          return release;
        }
      }
      LOGGER.i('[update check] Tier 2 completed: no newer release in atom feed.');
      return null;
    }
    LOGGER.w('[update check] Tier 2 atom feed was empty, proceeding to Tier 3...');
  } catch (err, trace) {
    lastError = err;
    if (_isRateLimitError(err)) {
      rateLimitHit = true;
      UpdateCheckState.lastCheckEncounteredRateLimit = true;
    }
    LOGGER.w('[update check] Tier 2 atom feed failed: $err', stackTrace: trace);
  }

  // Level 3: GitHub releases/latest HTTP 302 Redirect
  try {
    LOGGER.i('[update check] Tier 3: falling back to releases/latest redirect...');
    final redirectFetcher = fetchLatestRedirect ?? fetchLatestReleaseFromRedirect;
    final latestRelease = await redirectFetcher();
    if (latestRelease != null) {
      if (isNewerReleaseForVersion(latestRelease, currentVersion)) {
        LOGGER.i('[update check] Tier 3 found newer release: ${latestRelease.tagName}');
        return latestRelease;
      }
      LOGGER.i('[update check] Tier 3 completed: tag ${latestRelease.tagName} is not newer than current.');
      return null;
    }
  } catch (err, trace) {
    lastError = err;
    if (_isRateLimitError(err)) {
      rateLimitHit = true;
      UpdateCheckState.lastCheckEncounteredRateLimit = true;
    }
    LOGGER.w('[update check] Tier 3 latest redirect failed: $err', stackTrace: trace);
  }

  LOGGER.e('[update check] All update check channels failed. RateLimit=$rateLimitHit, lastError=$lastError');
  if (rateLimitHit) {
    throw RateLimitException('GitHub 访问频率超限，请稍后再试', firstError);
  }
  if (_isNetworkOfflineError(lastError) || _isNetworkOfflineError(firstError)) {
    throw NetworkOfflineException('网络连接不可用', lastError);
  }
  throw UpdateException('检查更新失败: $lastError', lastError);
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
    await showModernDialog(
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
        icon: const Icon(Symbols.update_rounded),
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
                      showModernDialog(
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

    return ModernDialogFrame(
      maxWidth: 520,
      padding: const EdgeInsets.fromLTRB(24, 22, 24, 20),
      child: SizedBox(
        height: 460,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: scheme.primary.withValues(alpha: 0.14),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(
                    Symbols.update_rounded,
                    size: 20,
                    color: scheme.primary,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        release.name ?? "新版本",
                        style: TextStyle(
                          color: scheme.onSurface,
                          fontSize: 18.0,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        "${release.tagName} · ${release.publishedAt?.toString().split('T').first ?? ''}",
                        style: TextStyle(
                          color: scheme.onSurfaceVariant.withValues(alpha: 0.8),
                          fontSize: 12.0,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  tooltip: "关闭",
                  icon: Icon(
                    Symbols.close_rounded,
                    size: 18,
                    color: scheme.onSurfaceVariant,
                  ),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
            const SizedBox(height: 14.0),
            Expanded(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12),
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
            ),
            const SizedBox(height: 14.0),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                TextButton(
                  onPressed: () {
                    Navigator.pop(context);
                  },
                  child: const Text("取消"),
                ),
                if (showIgnoreAction) ...[
                  const SizedBox(width: 8.0),
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
                const SizedBox(width: 8.0),
                FilledButton.icon(
                  onPressed: () {
                    if (release.htmlUrl != null) {
                      launchInBrowser(uri: release.htmlUrl!);
                    }

                    Navigator.pop(context);
                  },
                  icon: const Icon(Symbols.arrow_outward_rounded, size: 18),
                  label: const Text("获取更新"),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
