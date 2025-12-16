import 'package:aimi_app/services/settings_service.dart';
import 'package:aimi_app/services/theme_service.dart';
import 'package:aimi_app/utils/title_helper.dart';
import 'package:aimi_app/viewmodels/settings_viewmodel.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:scroll_animator/scroll_animator.dart';

/// Settings screen following MVVM architecture.
///
/// Displays settings options and delegates all business logic to [SettingsViewModel].
class SettingsView extends StatelessWidget {
  const SettingsView({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Consumer<SettingsViewModel>(
        builder: (context, viewModel, child) {
          // Show messages if any
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (viewModel.successMessage != null) {
              ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(viewModel.successMessage!)));
              viewModel.clearMessages();
            } else if (viewModel.errorMessage != null) {
              ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(viewModel.errorMessage!)));
              viewModel.clearMessages();
            }
          });

          return AnimatedPrimaryScrollController(
            animationFactory: const ChromiumEaseInOut(),
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                _buildAppearanceSection(context),
                const SizedBox(height: 24),
                _buildAnimationsSection(context),
                const SizedBox(height: 24),
                _buildPreferencesSection(context),
                const SizedBox(height: 24),
                _buildDataManagementSection(context, viewModel),
                const SizedBox(height: 24),
                _buildStorageManagementSection(context, viewModel),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildAnimationsSection(BuildContext context) {
    return Consumer<SettingsService>(
      builder: (context, settingsService, child) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Animations', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 16),
            SwitchListTile(
              secondary: const Icon(Icons.animation),
              title: const Text('Hero animations'),
              subtitle: const Text('Enable animated transitions between pages'),
              value: settingsService.enableHeroAnimation,
              onChanged: settingsService.setEnableHeroAnimation,
            ),
          ],
        );
      },
    );
  }

  Widget _buildPreferencesSection(BuildContext context) {
    return Consumer<SettingsService>(
      builder: (context, settingsService, child) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Preferences', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 16),
            ListTile(
              leading: const Icon(Icons.translate),
              title: const Text('Title language'),
              subtitle: Text(_getTitleLanguageLabel(settingsService.titleLanguagePreference)),
              trailing: DropdownButton<TitleLanguage>(
                value: settingsService.titleLanguagePreference,
                underline: const SizedBox.shrink(),
                onChanged: (value) {
                  if (value != null) settingsService.setTitleLanguagePreference(value);
                },
                items: const [
                  DropdownMenuItem(value: TitleLanguage.english, child: Text('English')),
                  DropdownMenuItem(value: TitleLanguage.romaji, child: Text('Romaji')),
                  DropdownMenuItem(value: TitleLanguage.native, child: Text('Native')),
                ],
              ),
            ),
          ],
        );
      },
    );
  }

  String _getTitleLanguageLabel(TitleLanguage language) {
    switch (language) {
      case TitleLanguage.english:
        return 'Prefer English titles when available';
      case TitleLanguage.romaji:
        return 'Prefer romanized Japanese titles';
      case TitleLanguage.native:
        return 'Prefer native Japanese titles';
    }
  }

  Widget _buildDataManagementSection(BuildContext context, SettingsViewModel viewModel) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Data Management', style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 16),
        ListTile(
          leading: const Icon(Icons.upload_file),
          title: const Text('Export data'),
          subtitle: const Text('Backup your settings and watch history to a file'),
          trailing: viewModel.isExporting ? const CircularProgressIndicator() : null,
          onTap: viewModel.isExporting ? null : () => viewModel.exportData(),
        ),
        ListTile(
          leading: const Icon(Icons.download),
          title: const Text('Import data'),
          subtitle: const Text('Restore from a backup file'),
          trailing: viewModel.isImporting ? const CircularProgressIndicator() : null,
          onTap: viewModel.isImporting ? null : () => _confirmImport(context, viewModel),
        ),
      ],
    );
  }

  Widget _buildStorageManagementSection(BuildContext context, SettingsViewModel viewModel) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Storage Management', style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 16),
        ListTile(
          leading: const Icon(Icons.cleaning_services),
          title: const Text('Clear cache'),
          subtitle: const Text('Remove temporary cached data'),
          onTap: () => _confirmClearCache(context, viewModel),
        ),
        ListTile(
          leading: const Icon(Icons.delete_forever),
          title: const Text('Reset storage'),
          subtitle: const Text('Delete all watch history and progress'),
          onTap: () => _confirmResetStorage(context, viewModel),
        ),
      ],
    );
  }

  Widget _buildAppearanceSection(BuildContext context) {
    return Consumer<ThemeService>(
      builder: (context, themeService, child) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Appearance', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 16),
            const Text('Theme Mode'),
            const SizedBox(height: 12),
            _buildThemeModeSelector(context, themeService),
            const SizedBox(height: 24),
            const Text('Color Theme'),
            const SizedBox(height: 12),
            _buildColorThemeSelector(context, themeService),
          ],
        );
      },
    );
  }

  Widget _buildThemeModeSelector(BuildContext context, ThemeService themeService) {
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

  Widget _buildColorThemeSelector(BuildContext context, ThemeService themeService) {
    final colors = [
      Colors.teal,
      Colors.blue,
      Colors.indigo,
      Colors.deepPurple,
      Colors.purple,
      Colors.pink,
      Colors.red,
      Colors.orange,
      Colors.yellow,
      Colors.green,
    ];

    return Wrap(
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
    );
  }

  Color _getContrastingColor(Color color) {
    return ThemeData.estimateBrightnessForColor(color) == Brightness.dark ? Colors.white : Colors.black;
  }

  Future<void> _confirmImport(BuildContext context, SettingsViewModel viewModel) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Import Data'),
        content: const Text('This will replace your current settings and data. Continue?'),
        actions: [
          TextButton(onPressed: () => Navigator.of(context).pop(false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.of(context).pop(true), child: const Text('Import')),
        ],
      ),
    );

    if (confirmed == true) {
      await viewModel.importData();
    }
  }

  Future<void> _confirmClearCache(BuildContext context, SettingsViewModel viewModel) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        constraints: const BoxConstraints(maxWidth: 500),
        title: const Text('Clear Cache'),
        content: const Text(
          'This will remove all temporary cached data. Your watch history and settings will not be affected.',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(context).pop(false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.of(context).pop(true), child: const Text('Clear')),
        ],
      ),
    );

    if (confirmed == true) {
      await viewModel.clearCache();
    }
  }

  Future<void> _confirmResetStorage(BuildContext context, SettingsViewModel viewModel) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        constraints: const BoxConstraints(maxWidth: 500),
        title: const Text('Reset Storage'),
        content: const Text(
          '⚠️ This will permanently delete:\n'
          '• Watch history\n'
          '• Search history\n'
          '• Watch progress\n'
          '• Saved anime details\n\n'
          'Your preferences (theme, settings) will be preserved.\n\n'
          'Are you sure you want to continue?',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(context).pop(false), child: const Text('Cancel')),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: FilledButton.styleFrom(backgroundColor: Theme.of(context).colorScheme.errorContainer),
            child: const Text('Reset', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await viewModel.resetStorage();
    }
  }
}
