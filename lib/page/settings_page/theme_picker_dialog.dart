import 'package:qisheng_player/app_settings.dart';
import 'package:qisheng_player/component/ui/modern_dialog.dart';
import 'package:qisheng_player/utils.dart';
import 'package:qisheng_player/hotkeys_helper.dart';
import 'package:flex_color_picker/flex_color_picker.dart';
import 'package:flutter/material.dart';

class ThemePickerDialog extends StatefulWidget {
  const ThemePickerDialog({super.key});

  @override
  State<ThemePickerDialog> createState() => _ThemePickerDialogState();
}

class _ThemePickerDialogState extends State<ThemePickerDialog> {
  var selectedColor = Color(AppSettings.instance.defaultTheme);
  late final rgbHexTextEditingController = TextEditingController(
    text: selectedColor.toRGBHexString(),
  );

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return ModernDialogFrame(
      maxWidth: 390,
      padding: const EdgeInsets.all(22.0),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
          Padding(
            padding: const EdgeInsets.only(bottom: 16.0),
            child: Row(
              children: [
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: scheme.primary.withValues(alpha: 0.14),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(
                    Icons.palette_rounded,
                    size: 20,
                    color: scheme.primary,
                  ),
                ),
                const SizedBox(width: 12),
                Text(
                  "主题选择器",
                  style: TextStyle(
                    color: scheme.onSurface,
                    fontSize: 18.0,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
          Focus(
            onFocusChange: HotkeysHelper.onFocusChanges,
            child: TextField(
              autofocus: true,
              controller: rgbHexTextEditingController,
              onChanged: (value) {
                final c = fromRGBHexString(value);
                if (c != null) {
                  setState(() {
                    selectedColor = c;
                  });
                }
              },
              decoration: const InputDecoration(
                labelText: "十六进制 RGB",
                border: OutlineInputBorder(),
              ),
            ),
          ),
          const SizedBox(height: 16.0),
          SizedBox(
            height: 380,
            child: ColorWheelPicker(
              color: selectedColor,
              onChanged: (color) {
                setState(() {
                  selectedColor = color;
                });
                rgbHexTextEditingController.text = color.toRGBHexString();
              },
              onWheel: (isWheel) {},
            ),
          ),
          const SizedBox(height: 16.0),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text("取消"),
              ),
              const SizedBox(width: 8.0),
              FilledButton(
                onPressed: () {
                  Navigator.pop(context, selectedColor);
                },
                child: const Text("确定"),
              ),
            ],
          ),
        ],
      ),
    ),
  );
}
}
