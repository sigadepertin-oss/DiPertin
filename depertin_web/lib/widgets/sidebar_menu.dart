import 'package:depertin_web/navigation/painel_routes.dart';
import 'package:depertin_web/theme/painel_admin_theme.dart';
import 'package:depertin_web/utils/admin_perfil.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_fonts/google_fonts.dart';

class SidebarMenu extends StatefulWidget {
  final String rotaAtual;
  /// Quando preenchido, troca só o conteúdo do shell (sem [Navigator]).
  final void Function(String route)? onNavegarPainel;

  const SidebarMenu({
    super.key,
    required this.rotaAtual,
    this.onNavegarPainel,
  });

  @override
  State<SidebarMenu> createState() => _SidebarMenuState();
}

class _SidebarMenuState extends State<SidebarMenu> {
  static const double _largura = 272;

  String _tipoUsuario = 'carregando';

  @override
  void initState() {
    super.initState();
    _buscarPermissoes();
  }

  Future<void> _buscarPermissoes() async {
    User? user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      try {
        final docSnap = await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .get();

        if (docSnap.exists) {
          var dados = docSnap.data()!;
          if (mounted) {
            setState(() {
              _tipoUsuario = perfilAdministrativo(dados);
            });
          }
        }
      } catch (e) {
        debugPrint("Erro ao carregar permissão: $e");
      }
    }
  }

  Widget _navTile(
    BuildContext context, {
    required IconData icon,
    required String label,
    required String rotaDestino,
  }) {
    final selected = widget.rotaAtual == rotaDestino;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () {
            if (selected) return;
            final fn = widget.onNavegarPainel;
            if (fn != null && PainelRoutes.isShellRoute(rotaDestino)) {
              fn(rotaDestino);
            } else {
              Navigator.pushReplacementNamed(context, rotaDestino);
            }
          },
          borderRadius: BorderRadius.circular(12),
          hoverColor: Colors.white.withOpacity(0.08),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            curve: Curves.easeOutCubic,
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              color: selected ? Colors.white.withOpacity(0.14) : null,
              border: Border(
                left: BorderSide(
                  color: selected
                      ? PainelAdminTheme.laranjaSuave
                      : Colors.transparent,
                  width: 3,
                ),
              ),
            ),
            child: Row(
              children: [
                Icon(
                  icon,
                  size: 22,
                  color: selected
                      ? Colors.white
                      : Colors.white.withOpacity(0.85),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    label,
                    style: GoogleFonts.plusJakartaSans(
                      color: Colors.white,
                      fontSize: 14.5,
                      fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
                      letterSpacing: 0.2,
                    ),
                  ),
                ),
                if (selected)
                  Icon(
                    Icons.chevron_right_rounded,
                    size: 20,
                    color: Colors.white.withOpacity(0.7),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_tipoUsuario == 'carregando') {
      return Container(
        width: _largura,
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              PainelAdminTheme.roxoEscuro,
              PainelAdminTheme.roxo,
              PainelAdminTheme.roxoSidebarFim,
            ],
          ),
        ),
        child: const Center(
          child: CircularProgressIndicator(
            color: Colors.white,
            strokeWidth: 2,
          ),
        ),
      );
    }

    return Container(
      width: _largura,
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            PainelAdminTheme.roxoEscuro,
            PainelAdminTheme.roxo,
            PainelAdminTheme.roxoSidebarFim,
          ],
        ),
        boxShadow: [
          BoxShadow(
            color: Color(0x33000000),
            blurRadius: 24,
            offset: Offset(8, 0),
          ),
        ],
      ),
      child: Column(
        children: [
          const SizedBox(height: 36),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.1),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: Colors.white.withOpacity(0.15)),
            ),
            child: Image.asset(
              'assets/logo.png',
              height: 56,
              errorBuilder: (c, e, s) => const Icon(
                Icons.admin_panel_settings_rounded,
                size: 52,
                color: Colors.white,
              ),
            ),
          ),
          const SizedBox(height: 20),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.black.withOpacity(0.18),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: Colors.white.withOpacity(0.12)),
            ),
            child: Text(
              _tipoUsuario.toUpperCase(),
              style: GoogleFonts.plusJakartaSans(
                color: PainelAdminTheme.laranjaSuave,
                fontSize: 10,
                fontWeight: FontWeight.w700,
                letterSpacing: 1.2,
              ),
            ),
          ),
          const SizedBox(height: 28),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.only(bottom: 8),
              children: [
                _navTile(
                  context,
                  icon: Icons.dashboard_rounded,
                  label: 'Dashboard',
                  rotaDestino: '/dashboard',
                ),
                if (perfilPodeGestaoLojasEntregadoresBanners(_tipoUsuario)) ...[
                  const SizedBox(height: 6),
                  _navTile(
                    context,
                    icon: Icons.storefront_rounded,
                    label: 'Lojas',
                    rotaDestino: '/lojas',
                  ),
                  _navTile(
                    context,
                    icon: Icons.two_wheeler_rounded,
                    label: 'Entregadores',
                    rotaDestino: '/entregadores',
                  ),
                  _navTile(
                    context,
                    icon: Icons.view_carousel_rounded,
                    label: 'Banners Vitrine',
                    rotaDestino: '/banners',
                  ),
                ],
                if (_tipoUsuario == 'lojista') ...[
                  _navTile(
                    context,
                    icon: Icons.shopping_bag_rounded,
                    label: 'Meus Pedidos',
                    rotaDestino: '/meus_pedidos',
                  ),
                  _navTile(
                    context,
                    icon: Icons.restaurant_menu_rounded,
                    label: 'Meu Cardápio',
                    rotaDestino: '/meu_cardapio',
                  ),
                  _navTile(
                    context,
                    icon: Icons.account_balance_wallet_rounded,
                    label: 'Minha Carteira',
                    rotaDestino: '/carteira_loja',
                  ),
                ],
                if (perfilPodeMenuChefe(_tipoUsuario)) ...[
                  Padding(
                    padding:
                        const EdgeInsets.fromLTRB(20, 20, 20, 10),
                    child: Row(
                      children: [
                        Expanded(
                          child: Divider(
                            color: Colors.white.withOpacity(0.2),
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 8),
                          child: Text(
                            'GESTÃO',
                            style: GoogleFonts.plusJakartaSans(
                              color: Colors.white.withOpacity(0.45),
                              fontSize: 10,
                              fontWeight: FontWeight.w600,
                              letterSpacing: 1.4,
                            ),
                          ),
                        ),
                        Expanded(
                          child: Divider(
                            color: Colors.white.withOpacity(0.2),
                          ),
                        ),
                      ],
                    ),
                  ),
                  _navTile(
                    context,
                    icon: Icons.admin_panel_settings_rounded,
                    label: 'AdminCity',
                    rotaDestino: '/admincity',
                  ),
                  _navTile(
                    context,
                    icon: Icons.campaign_rounded,
                    label: 'Anúncios & Util.',
                    rotaDestino: '/utilidades',
                  ),
                  _navTile(
                    context,
                    icon: Icons.payments_rounded,
                    label: 'Financeiro Geral',
                    rotaDestino: '/financeiro',
                  ),
                  _navTile(
                    context,
                    icon: Icons.tune_rounded,
                    label: 'Configurações',
                    rotaDestino: '/configuracoes',
                  ),
                ],
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
            child: Divider(color: Colors.white.withOpacity(0.15)),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 0, 12, 24),
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: () async {
                  await FirebaseAuth.instance.signOut();
                  if (context.mounted) {
                    Navigator.pushReplacementNamed(context, '/login');
                  }
                },
                borderRadius: BorderRadius.circular(12),
                hoverColor: Colors.white.withOpacity(0.08),
                child: Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                  child: Row(
                    children: [
                      Icon(
                        Icons.logout_rounded,
                        color: Colors.white.withOpacity(0.9),
                        size: 22,
                      ),
                      const SizedBox(width: 12),
                      Text(
                        'Sair',
                        style: GoogleFonts.plusJakartaSans(
                          color: Colors.white,
                          fontSize: 14.5,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
