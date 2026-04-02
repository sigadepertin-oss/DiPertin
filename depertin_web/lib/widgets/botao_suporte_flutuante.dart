// lib/widgets/botao_suporte_flutuante.dart

import 'package:depertin_web/navigation/painel_navigation_scope.dart';
import 'package:depertin_web/theme/painel_admin_theme.dart';
import 'package:depertin_web/utils/admin_perfil.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class BotaoSuporteFlutuante extends StatefulWidget {
  const BotaoSuporteFlutuante({super.key});

  @override
  State<BotaoSuporteFlutuante> createState() => _BotaoSuporteFlutuanteState();
}

class _BotaoSuporteFlutuanteState extends State<BotaoSuporteFlutuante> {
  String _tipoUsuario = 'carregando';
  String _minhaCidade = '';

  @override
  void initState() {
    super.initState();
    _buscarDadosAdmin();
  }

  Future<void> _buscarDadosAdmin() async {
    User? user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      final docSnap = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();
      if (docSnap.exists) {
        final dados = docSnap.data()!;
        setState(() {
          _tipoUsuario = perfilAdministrativo(dados);
          _minhaCidade = dados['cidade'] ?? '';
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_tipoUsuario == 'carregando') return const SizedBox.shrink();

    // Filtro Inteligente: Quem vê o quê?
    Query query = FirebaseFirestore.instance
        .collection('support_tickets')
        .where('status', isEqualTo: 'waiting');

    // MasterCity: só vê chamados da cidade dele
    if (_tipoUsuario == 'master_city') {
      final c = _minhaCidade.trim().toLowerCase();
      query = query.where('cidade', isEqualTo: c.isEmpty ? '—' : c);
    }
    // Master: visão global (sem filtro por cidade)
    else if (_tipoUsuario == 'master') {
      // (Detalhe do filtro na tela de suporte)
    }
    // Lojista não tem botão flutuante de admin, ele usa o app dele
    else {
      return const SizedBox.shrink();
    }

    return StreamBuilder<QuerySnapshot>(
      stream: query.snapshots(),
      builder: (context, snapshot) {
        int novosChamados = snapshot.hasData ? snapshot.data!.docs.length : 0;

        return Stack(
          clipBehavior: Clip.none,
          children: [
            Container(
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: PainelAdminTheme.laranja.withOpacity(0.45),
                    blurRadius: 20,
                    offset: const Offset(0, 8),
                  ),
                  BoxShadow(
                    color: PainelAdminTheme.roxo.withOpacity(0.15),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: FloatingActionButton(
                elevation: 0,
                highlightElevation: 0,
                backgroundColor: PainelAdminTheme.laranja,
                shape: const CircleBorder(),
                onPressed: () {
                  final nav = PainelNavigationScope.maybeOf(context);
                  if (nav != null) {
                    nav.navigateTo('/atendimento_suporte');
                  } else {
                    Navigator.pushNamed(context, '/atendimento_suporte');
                  }
                },
                child: const Icon(
                  Icons.support_agent_rounded,
                  color: Colors.white,
                  size: 28,
                ),
              ),
            ),
            if (novosChamados > 0)
              Positioned(
                top: -4,
                right: -4,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 7,
                    vertical: 4,
                  ),
                  constraints: const BoxConstraints(minWidth: 22, minHeight: 22),
                  decoration: BoxDecoration(
                    color: const Color(0xFFEF4444),
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white, width: 2),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.2),
                        blurRadius: 6,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  alignment: Alignment.center,
                  child: Text(
                    novosChamados > 9 ? '9+' : novosChamados.toString(),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}
