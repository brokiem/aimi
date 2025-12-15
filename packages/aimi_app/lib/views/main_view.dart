import 'package:aimi_app/views/history_view.dart';
import 'package:aimi_app/views/home_view.dart';
import 'package:aimi_app/views/search_view.dart';
import 'package:aimi_app/views/settings_view.dart';
import 'package:flutter/material.dart';

class MainView extends StatefulWidget {
  const MainView({super.key});

  @override
  State<MainView> createState() => _MainViewState();
}

class _MainViewState extends State<MainView> {
  int _selectedIndex = 0;

  final _navItems = [
    _NavigationItem(label: 'Home', icon: Icons.home_outlined, selectedIcon: Icons.home, view: const HomeView()),
    _NavigationItem(
      label: 'History',
      icon: Icons.history_outlined,
      selectedIcon: Icons.history,
      view: const HistoryView(),
    ),
    _NavigationItem(label: 'Settings', icon: Icons.settings, selectedIcon: Icons.settings, view: const SettingsView()),
  ];

  void _onDestinationSelected(int index) {
    setState(() => _selectedIndex = index);
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final isMobile = constraints.maxWidth < 640;
        final currentItem = _navItems[_selectedIndex];

        final railDestinations = _navItems.map((item) {
          return NavigationRailDestination(
            icon: Icon(item.icon),
            selectedIcon: Icon(item.selectedIcon),
            label: Text(item.label),
          );
        }).toList();

        final barDestinations = _navItems.map((item) {
          return NavigationDestination(icon: Icon(item.icon), selectedIcon: Icon(item.selectedIcon), label: item.label);
        }).toList();

        if (isMobile) {
          return Scaffold(
            appBar: AppBar(title: Text(currentItem.label), shadowColor: Theme.of(context).colorScheme.shadow),
            body: _buildBody(),
            bottomNavigationBar: NavigationBar(
              selectedIndex: _selectedIndex,
              onDestinationSelected: _onDestinationSelected,
              destinations: barDestinations,
            ),
            floatingActionButton: FloatingActionButton(
              onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const SearchView())),
              child: const Icon(Icons.search),
            ),
          );
        } else {
          return Row(
            children: [
              NavigationRail(
                selectedIndex: _selectedIndex,
                groupAlignment: 0,
                onDestinationSelected: _onDestinationSelected,
                labelType: NavigationRailLabelType.all,
                leading: FloatingActionButton(
                  elevation: 0,
                  onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (context) => const SearchView())),
                  child: const Icon(Icons.search),
                ),
                backgroundColor: Theme.of(context).colorScheme.surfaceContainer,
                destinations: railDestinations,
              ),
              Expanded(
                child: Scaffold(
                  appBar: AppBar(title: Text(currentItem.label), shadowColor: Theme.of(context).colorScheme.shadow),
                  body: _buildBody(),
                ),
              ),
            ],
          );
        }
      },
    );
  }

  Widget _buildBody() {
    return IndexedStack(index: _selectedIndex, children: _navItems.map((e) => e.view).toList());
  }
}

class _NavigationItem {
  final String label;
  final IconData icon;
  final IconData selectedIcon;
  final Widget view;

  const _NavigationItem({required this.label, required this.icon, required this.selectedIcon, required this.view});
}
