import 'package:flutter/material.dart';

import '../screens/community_screen.dart';
import '../screens/journal_screen.dart';
import '../screens/portfolio_screen.dart';
import '../screens/trade_screen.dart';

/// Bottom navigation host.
///
/// Each tab keeps its state, so the half-filled order ticket on the trade tab
/// survives a trip to the journal to check what went wrong last time.
class AppShell extends StatefulWidget {
  const AppShell({super.key});

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  int _index = 0;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _index,
        children: const [
          PortfolioScreen(),
          TradeScreen(),
          JournalScreen(),
          CommunityScreen(),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (i) => setState(() => _index = i),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.account_balance_wallet_outlined),
            selectedIcon: Icon(Icons.account_balance_wallet),
            label: 'পোর্টফোলিও',
          ),
          NavigationDestination(
            icon: Icon(Icons.candlestick_chart_outlined),
            selectedIcon: Icon(Icons.candlestick_chart),
            label: 'ট্রেড',
          ),
          NavigationDestination(
            icon: Icon(Icons.menu_book_outlined),
            selectedIcon: Icon(Icons.menu_book),
            label: 'জার্নাল',
          ),
          NavigationDestination(
            icon: Icon(Icons.groups_outlined),
            selectedIcon: Icon(Icons.groups),
            label: 'কমিউনিটি',
          ),
        ],
      ),
    );
  }
}
