import 'package:coriander_player/component/main_layout_frame.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('resolveMainLayoutDockInset reserves dock space only when needed', () {
    expect(
      resolveMainLayoutDockInset(
        reserveDockSpace: true,
        hasOverlay: true,
        dockHeight: 90,
        shellGap: 24,
      ),
      138,
    );

    expect(
      resolveMainLayoutDockInset(
        reserveDockSpace: false,
        hasOverlay: true,
        dockHeight: 90,
        shellGap: 24,
      ),
      0,
    );

    expect(
      resolveMainLayoutDockInset(
        reserveDockSpace: true,
        hasOverlay: false,
        dockHeight: 90,
        shellGap: 24,
      ),
      0,
    );
  });
}
