import 'package:flutter/material.dart';

import '../data/chat_inbox.dart';
import '../data/session_controller.dart';
import '../screens/community_screen.dart';
import '../screens/journal_screen.dart';
import '../screens/messages_screen.dart';
import '../screens/portfolio_screen.dart';
import '../screens/trade_screen.dart';
import '../theme/app_theme.dart';

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
    final s = context.s;
    // Conversations with something unread, as WhatsApp counts them — chats,
    // not messages, so ten messages from one person do not read as ten people.
    final unread = InboxScope.of(context)?.unreadChats ?? 0;

    return Scaffold(
      body: IndexedStack(
        index: _index,
        children: const [
          PortfolioScreen(),
          TradeScreen(),
          JournalScreen(),
          CommunityScreen(),
          MessagesScreen(),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (i) => setState(() => _index = i),
        destinations: [
          NavigationDestination(
            icon: const Icon(Icons.account_balance_wallet_outlined),
            selectedIcon: const Icon(Icons.account_balance_wallet),
            label: s.navPortfolio,
          ),
          NavigationDestination(
            icon: const Icon(Icons.candlestick_chart_outlined),
            selectedIcon: const Icon(Icons.candlestick_chart),
            label: s.navTrade,
          ),
          NavigationDestination(
            icon: const Icon(Icons.menu_book_outlined),
            selectedIcon: const Icon(Icons.menu_book),
            label: s.navJournal,
          ),
          NavigationDestination(
            icon: const Icon(Icons.groups_outlined),
            selectedIcon: const Icon(Icons.groups),
            label: s.navCommunity,
          ),
          NavigationDestination(
            icon: Badge(
              isLabelVisible: unread > 0,
              label: Text('$unread'),
              backgroundColor: AppColors.profit,
              textColor: AppColors.bg,
              child: const Icon(Icons.chat_bubble_outline_rounded),
            ),
            selectedIcon: Badge(
              isLabelVisible: unread > 0,
              label: Text('$unread'),
              backgroundColor: AppColors.profit,
              textColor: AppColors.bg,
              child: const Icon(Icons.chat_bubble_rounded),
            ),
            label: s.navMessages,
          ),
        ],
      ),
    );
  }
}
