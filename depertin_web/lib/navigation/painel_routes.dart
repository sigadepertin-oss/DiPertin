/// Rotas exibidas dentro do [PainelShellScreen] (menu persistente + IndexedStack).
abstract final class PainelRoutes {
  static const List<String> ordem = [
    '/dashboard',
    '/lojas',
    '/entregadores',
    '/banners',
    '/admincity',
    '/utilidades',
    '/financeiro',
    '/configuracoes',
    '/atendimento_suporte',
  ];

  static bool isShellRoute(String route) => ordem.contains(route);

  static String normalize(String route) {
    if (ordem.contains(route)) return route;
    return '/dashboard';
  }

  static int indexOf(String route) {
    final r = normalize(route);
    final i = ordem.indexOf(r);
    return i >= 0 ? i : 0;
  }
}
