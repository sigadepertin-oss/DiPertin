import 'package:flutter/material.dart';
import 'painel_nav_controller.dart';
import 'painel_routes.dart';

class PainelNavigationScope extends InheritedNotifier<PainelNavController> {
  const PainelNavigationScope({
    super.key,
    required PainelNavController notifier,
    required super.child,
  }) : super(notifier: notifier);

  static PainelNavController? maybeOf(BuildContext context) {
    return context
        .dependOnInheritedWidgetOfExactType<PainelNavigationScope>()
        ?.notifier;
  }

  static PainelNavController of(BuildContext context) {
    final n = maybeOf(context);
    assert(n != null, 'PainelNavigationScope não encontrado');
    return n!;
  }
}

extension NavegacaoPainelX on BuildContext {
  /// Troca só o painel central (shell); fora do shell cai em [pushReplacementNamed].
  void navegarPainel(String rota) {
    final nav = PainelNavigationScope.maybeOf(this);
    if (nav != null && PainelRoutes.isShellRoute(rota)) {
      nav.navigateTo(rota);
    } else {
      Navigator.pushReplacementNamed(this, rota);
    }
  }
}
