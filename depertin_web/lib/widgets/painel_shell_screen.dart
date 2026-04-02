import 'package:flutter/material.dart';
import '../navigation/painel_nav_controller.dart';
import '../navigation/painel_navigation_scope.dart';
import '../navigation/painel_routes.dart';
import '../theme/painel_admin_theme.dart';
import 'painel_content_skeleton.dart';
import 'sidebar_menu.dart';
import '../screens/dashboard_screen.dart';
import '../screens/lojas_screen.dart';
import '../screens/entregadores_screen.dart';
import '../screens/banners_screen.dart';
import '../screens/admin_city_screen.dart';
import '../screens/utilidades_screen.dart';
import '../screens/financeiro_screen.dart';
import '../screens/configuracoes_screen.dart';
import '../screens/atendimento_suporte_screen.dart';

/// Layout persistente: menu fixo + [IndexedStack] (sem recriar a árvore inteira).
class PainelShellScreen extends StatefulWidget {
  const PainelShellScreen({super.key, this.initialRoute = '/dashboard'});

  final String initialRoute;

  @override
  State<PainelShellScreen> createState() => _PainelShellScreenState();
}

class _PainelShellScreenState extends State<PainelShellScreen> {
  late final PainelNavController _nav;

  @override
  void initState() {
    super.initState();
    _nav = PainelNavController(initial: widget.initialRoute);
  }

  @override
  void dispose() {
    _nav.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: _nav,
      builder: (context, _) {
        return PainelNavigationScope(
          notifier: _nav,
          child: ColoredBox(
            color: PainelAdminTheme.fundoCanvas,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                SidebarMenu(
                  rotaAtual: _nav.currentRoute,
                  onNavegarPainel: _nav.navigateTo,
                ),
                Expanded(
                  child: ClipRect(
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        IndexedStack(
                          index: PainelRoutes.indexOf(_nav.currentRoute),
                          sizing: StackFit.expand,
                          children: [
                            const DashboardScreen(),
                            LojasScreen(),
                            EntregadoresScreen(),
                            BannersScreen(),
                            AdminCityScreen(),
                            UtilidadesScreen(),
                            FinanceiroScreen(),
                            ConfiguracoesScreen(),
                            AtendimentoSuporteScreen(),
                          ],
                        ),
                        if (_nav.isShowingSkeleton)
                          const Positioned.fill(
                            child: PainelContentSkeleton(),
                          ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
