import 'package:flutter/foundation.dart';
import 'package:flutter/scheduler.dart';
import 'painel_routes.dart';

/// Estado da aba/rota ativa no painel (sem [Navigator.pushReplacement]).
class PainelNavController extends ChangeNotifier {
  PainelNavController({String? initial})
      : _route = PainelRoutes.normalize(initial ?? '/dashboard');

  String _route;
  bool _showSkeleton = false;
  bool _disposed = false;
  int _navGen = 0;

  String get currentRoute => _route;

  /// Overlay de skeleton durante a troca de menu.
  bool get isShowingSkeleton => _showSkeleton;

  /// Duração mínima do skeleton (percepção fluida + tempo do 1º frame).
  static const Duration _skeletonMin = Duration(milliseconds: 420);

  void navigateTo(String route) {
    final r = PainelRoutes.normalize(route);
    if (_route == r) return;

    _showSkeleton = true;
    notifyListeners();

    _route = r;
    notifyListeners();

    final gen = ++_navGen;
    final t0 = DateTime.now();

    void tryHide() {
      if (_disposed || gen != _navGen) return;
      final elapsed = DateTime.now().difference(t0);
      final remaining = _skeletonMin - elapsed;
      if (remaining <= Duration.zero) {
        if (_disposed || gen != _navGen) return;
        _showSkeleton = false;
        notifyListeners();
        return;
      }
      Future<void>.delayed(remaining, () {
        if (_disposed || gen != _navGen) return;
        _showSkeleton = false;
        notifyListeners();
      });
    }

    SchedulerBinding.instance.addPostFrameCallback((_) {
      SchedulerBinding.instance.addPostFrameCallback((_) => tryHide());
    });
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}
