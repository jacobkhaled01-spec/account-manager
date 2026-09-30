import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_theme.dart';
import '../../batch_import/presentation/smart_import_screen.dart';
import '../../dashboard/presentation/dashboard_screen.dart';
import '../../financial_engine/domain/models/batch_record.dart';
import '../../incoming_remittances/presentation/incoming_screen.dart';
import '../../outgoing_transfers/presentation/outgoing_screen.dart';
import '../../settings/presentation/settings_screen.dart';

class HomeShell extends ConsumerStatefulWidget {
  const HomeShell({super.key});

  @override
  ConsumerState<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends ConsumerState<HomeShell> {
  int _currentIndex = 0;

  void _navigateToIndex(int index) {
    setState(() => _currentIndex = index);
  }

  @override
  Widget build(BuildContext context) {
    final screens = [
      DashboardScreen(
        onNavigateToImport: () => _navigateToIndex(2),
        onNavigateToIncoming: () => _navigateToIndex(1),
      ),
      const IncomingScreen(),
      SmartImportScreen(
        onSuccessImport: (type) => _navigateToIndex(type == BatchType.outgoing ? 3 : 1),
      ),
      const OutgoingScreen(),
      const SettingsScreen(),
    ];

    return Scaffold(
      body: IndexedStack(
        index: _currentIndex,
        children: screens,
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _currentIndex,
        onDestinationSelected: _navigateToIndex,
        labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.dashboard_outlined),
            selectedIcon: Icon(Icons.dashboard_rounded, color: AppTheme.primaryEmerald),
            label: 'الرئيسية',
          ),
          NavigationDestination(
            icon: Icon(Icons.call_received_outlined),
            selectedIcon: Icon(Icons.call_received_rounded, color: AppTheme.primaryEmerald),
            label: 'الوارد',
          ),
          NavigationDestination(
            icon: Icon(Icons.file_download_outlined),
            selectedIcon: Icon(Icons.file_download_rounded, color: AppTheme.primaryEmerald),
            label: 'الاستيراد',
          ),
          NavigationDestination(
            icon: Icon(Icons.call_made_outlined),
            selectedIcon: Icon(Icons.call_made_rounded, color: AppTheme.primaryEmerald),
            label: 'الصادر',
          ),
          NavigationDestination(
            icon: Icon(Icons.settings_outlined),
            selectedIcon: Icon(Icons.settings_rounded, color: AppTheme.primaryEmerald),
            label: 'الإعدادات',
          ),
        ],
      ),
    );
  }
}
