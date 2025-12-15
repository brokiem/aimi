import 'package:aimi_app/services/theme_service.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

class SettingsView extends StatelessWidget {
  const SettingsView({super.key});

  @override
  Widget build(BuildContext context) {
    return ListView(padding: const EdgeInsets.all(24), children: [_buildAppearanceSection(context)]);
  }

  Widget _buildAppearanceSection(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Appearance', style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 16),
        _buildThemeModeSelector(context),
        const SizedBox(height: 24),
        _buildColorThemeSelector(context),
      ],
    );
  }

  Widget _buildThemeModeSelector(BuildContext context) {
    final themeService = Provider.of<ThemeService>(context);

    return SegmentedButton<ThemeMode>(
      segments: const [
        ButtonSegment<ThemeMode>(value: ThemeMode.system, label: Text('System'), icon: Icon(Icons.brightness_auto)),
        ButtonSegment<ThemeMode>(value: ThemeMode.light, label: Text('Light'), icon: Icon(Icons.light_mode)),
        ButtonSegment<ThemeMode>(value: ThemeMode.dark, label: Text('Dark'), icon: Icon(Icons.dark_mode)),
      ],
      selected: {themeService.themeMode},
      onSelectionChanged: (Set<ThemeMode> newSelection) {
        themeService.setThemeMode(newSelection.first);
      },
    );
  }

  Widget _buildColorThemeSelector(BuildContext context) {
    final themeService = Provider.of<ThemeService>(context);

    // Predefined Material 3 seed colors
    final colors = [
      Colors.teal,
      Colors.blue,
      Colors.indigo,
      Colors.deepPurple,
      Colors.purple,
      Colors.pink,
      Colors.red,
      Colors.orange,
      Colors.amber,
      Colors.yellow,
      Colors.lime,
      Colors.lightGreen,
      Colors.green,
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Theme Color', style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 12),
        Wrap(
          spacing: 12,
          runSpacing: 12,
          children: colors.map((color) {
            final isSelected = themeService.seedColor.value == color.value;
            return GestureDetector(
              onTap: () => themeService.setSeedColor(color),
              child: Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: color,
                  shape: BoxShape.circle,
                  border: isSelected ? Border.all(color: Theme.of(context).colorScheme.onSurface, width: 3) : null,
                ),
                child: isSelected ? Icon(Icons.check, color: _getContrastingColor(color)) : null,
              ),
            );
          }).toList(),
        ),
      ],
    );
  }

  Color _getContrastingColor(Color color) {
    return ThemeData.estimateBrightnessForColor(color) == Brightness.dark ? Colors.white : Colors.black;
  }
}
