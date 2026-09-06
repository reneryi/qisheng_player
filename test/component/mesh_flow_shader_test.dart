import 'dart:ui' as ui;

import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('mesh flow shader asset compiles, uniforms 0..42 match, and canvas draws', (tester) async {
    final program = await tester.runAsync(
      () => ui.FragmentProgram.fromAsset('shaders/mesh_flow.frag'),
    );
    expect(program, isNotNull);
    final shader = program!.fragmentShader();
    // Test setting all 43 floats (indices 0..42)
    for (int i = 0; i <= 42; i++) {
      shader.setFloat(i, 0.5);
    }
    // Strict boundary test: setting index 43 must throw ArgumentError / RangeError
    expect(() => shader.setFloat(43, 0.5), throwsA(isA<ArgumentError>()));

    // Verify canvas execution with the shader
    final recorder = ui.PictureRecorder();
    final canvas = ui.Canvas(recorder);
    final paint = ui.Paint()..shader = shader;
    canvas.drawRect(const ui.Rect.fromLTWH(0, 0, 800, 600), paint);
    final picture = recorder.endRecording();
    picture.dispose();
  });

  testWidgets('water ripple shader asset compiles', (tester) async {
    final program = await tester.runAsync(
      () => ui.FragmentProgram.fromAsset('shaders/water_ripple.frag'),
    );
    expect(program, isNotNull);
  });

  testWidgets('lens glass shader asset compiles', (tester) async {
    final program = await tester.runAsync(
      () => ui.FragmentProgram.fromAsset('shaders/lens_glass.frag'),
    );
    expect(program, isNotNull);
  });
}


