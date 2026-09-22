import 'package:flutter/widgets.dart';

import 'account_store.dart';

/// Makes the [AccountStore] available down the tree, and rebuilds dependents
/// whenever it notifies.
///
/// An [InheritedNotifier] rather than a state-management package: there is one
/// store, and this is twelve lines.
class AccountScope extends InheritedNotifier<AccountStore> {
  const AccountScope({
    super.key,
    required AccountStore store,
    required super.child,
  }) : super(notifier: store);

  static AccountStore of(BuildContext context) {
    final scope = context.dependOnInheritedWidgetOfExactType<AccountScope>();
    assert(scope != null, 'No AccountScope found above this widget.');
    return scope!.notifier!;
  }
}
