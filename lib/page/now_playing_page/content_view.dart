part of 'page.dart';

class NowPlayingContentView extends StatelessWidget {
  const NowPlayingContentView({
    super.key,
    required this.compact,
    required this.styleMode,
  });

  final bool compact;
  final NowPlayingStyleMode styleMode;

  @override
  Widget build(BuildContext context) {
    return compact
        ? const _ImmersiveModeView(
            compact: true,
          )
        : const _ImmersiveModeView(
            compact: false,
          );
  }
}
