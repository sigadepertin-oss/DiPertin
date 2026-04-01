// lib/widgets/botao_suporte_flutuante.dart

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
      var snap = await FirebaseFirestore.instance
          .collection('users')
          .where('email', isEqualTo: user.email)
          .get();
      if (snap.docs.isNotEmpty) {
        var dados = snap.docs.first.data();
        setState(() {
          _tipoUsuario =
              (dados['role'] ??
                      dados['tipo'] ??
                      dados['tipoUsuario'] ??
                      'cliente')
                  .toString()
                  .toLowerCase();
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
        .collection('suporte')
        .where('status', isEqualTo: 'aguardando_admin');

    // Se for AdminCity, só vê chamados da cidade dele
    if (_tipoUsuario == 'admin_city') {
      query = query
          .where('cidade', isEqualTo: _minhaCidade)
          .where('escalado_superadmin', isEqualTo: false);
    }
    // Se for SuperAdmin, vê chamados escalados ou de cidades sem admin
    else if (_tipoUsuario == 'superadmin') {
      // (A lógica de filtro do SuperAdmin faremos dentro da tela depois, aqui contamos o total)
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
            FloatingActionButton(
              backgroundColor: const Color(0xFFFF8F00), // Laranja
              onPressed: () =>
                  Navigator.pushNamed(context, '/atendimento_suporte'),
              child: const Icon(
                Icons.support_agent,
                color: Colors.white,
                size: 30,
              ),
            ),
            if (novosChamados > 0)
              Positioned(
                top: -5,
                right: -5,
                child: Container(
                  padding: const EdgeInsets.all(6),
                  decoration: const BoxDecoration(
                    color: Colors.red,
                    shape: BoxShape.circle,
                  ),
                  child: Text(
                    novosChamados.toString(),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
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
