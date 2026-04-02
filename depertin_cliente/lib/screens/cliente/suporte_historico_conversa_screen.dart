// Leitura do histórico de um protocolo (somente conversa encerrada ou antiga).

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

const Color _roxo = Color(0xFF6A1B9A);
const Color _laranja = Color(0xFFFF8F00);

class SuporteHistoricoConversaScreen extends StatelessWidget {
  const SuporteHistoricoConversaScreen({super.key, required this.ticketId});

  final String ticketId;

  @override
  Widget build(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser?.uid;

    return Scaffold(
      backgroundColor: const Color(0xFFECEFF1),
      appBar: AppBar(
        title: const Text('Conversa do protocolo'),
        backgroundColor: _roxo,
        foregroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
      ),
      body: SafeArea(
        top: false,
        bottom: true,
        left: true,
        right: true,
        child: uid == null
            ? const Center(child: Text('Faça login.'))
            : StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
                stream: FirebaseFirestore.instance
                    .collection('support_tickets')
                    .doc(ticketId)
                    .snapshots(),
                builder: (context, snap) {
                  if (!snap.hasData) {
                    return const Center(
                      child: CircularProgressIndicator(color: _roxo),
                    );
                  }
                  final doc = snap.data!;
                  if (!doc.exists) {
                    return const Center(child: Text('Chamado não encontrado.'));
                  }
                  final d = doc.data()!;
                  if (d['user_id']?.toString() != uid) {
                    return const Center(
                      child: Text('Você não tem acesso a este chamado.'),
                    );
                  }
                  final protocolo =
                      (d['protocol_number'] ?? '').toString().padLeft(8, '0');
                  final st = d['status']?.toString() ?? '';

                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Padding(
                        padding: const EdgeInsets.fromLTRB(12, 12, 12, 8),
                        child: Material(
                          elevation: 1,
                          borderRadius: BorderRadius.circular(12),
                          color: Colors.white,
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 14,
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Icon(
                                      Icons.verified_outlined,
                                      size: 22,
                                      color: _roxo.withValues(alpha: 0.85),
                                    ),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: Text(
                                        'Protocolo $protocolo',
                                        style: const TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 17,
                                          color: Color(0xFF263238),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 6),
                                Text(
                                  _rotuloStatus(st),
                                  style: TextStyle(
                                    fontSize: 13,
                                    color: Colors.grey[700],
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  'Somente leitura — histórico da conversa.',
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontStyle: FontStyle.italic,
                                    color: Colors.grey[600],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                      Expanded(
                        child: Container(
                          margin: const EdgeInsets.fromLTRB(8, 0, 8, 8),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(12),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.06),
                                blurRadius: 8,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          clipBehavior: Clip.antiAlias,
                          child: StreamBuilder<
                              QuerySnapshot<Map<String, dynamic>>>(
                            stream: FirebaseFirestore.instance
                                .collection('support_tickets')
                                .doc(ticketId)
                                .collection('mensagens')
                                .orderBy('created_at', descending: true)
                                .snapshots(),
                            builder: (context, snapMsg) {
                              if (!snapMsg.hasData) {
                                return const Center(
                                  child: CircularProgressIndicator(
                                    color: _roxo,
                                  ),
                                );
                              }
                              final msgs = snapMsg.data!.docs;
                              if (msgs.isEmpty) {
                                return const Center(
                                  child: Padding(
                                    padding: EdgeInsets.all(24),
                                    child: Text(
                                      'Nenhuma mensagem neste chamado.',
                                      style: TextStyle(color: Colors.black54),
                                    ),
                                  ),
                                );
                              }
                              return ListView.builder(
                                reverse: true,
                                padding: const EdgeInsets.fromLTRB(14, 14, 14, 24),
                                itemCount: msgs.length,
                                itemBuilder: (context, index) {
                                  final msg = msgs[index].data();
                                  final tipo =
                                      msg['sender_type']?.toString() ?? '';
                                  final texto =
                                      msg['mensagem']?.toString() ?? '';
                                  if (tipo == 'system') {
                                    return Padding(
                                      padding: const EdgeInsets.symmetric(
                                        vertical: 8,
                                      ),
                                      child: Center(
                                        child: Container(
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 14,
                                            vertical: 8,
                                          ),
                                          decoration: BoxDecoration(
                                            color: Colors.grey[200],
                                            borderRadius:
                                                BorderRadius.circular(20),
                                          ),
                                          child: Text(
                                            texto,
                                            textAlign: TextAlign.center,
                                            style: TextStyle(
                                              fontSize: 12,
                                              fontWeight: FontWeight.w600,
                                              color: Colors.grey[800],
                                            ),
                                          ),
                                        ),
                                      ),
                                    );
                                  }
                                  final souCliente = tipo == 'client';
                                  return Align(
                                    alignment: souCliente
                                        ? Alignment.centerRight
                                        : Alignment.centerLeft,
                                    child: Container(
                                      margin: const EdgeInsets.only(bottom: 10),
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 14,
                                        vertical: 10,
                                      ),
                                      constraints: BoxConstraints(
                                        maxWidth:
                                            MediaQuery.sizeOf(context).width *
                                                0.82,
                                      ),
                                      decoration: BoxDecoration(
                                        color: souCliente ? _roxo : _laranja,
                                        borderRadius: BorderRadius.only(
                                          topLeft:
                                              const Radius.circular(16),
                                          topRight:
                                              const Radius.circular(16),
                                          bottomLeft: souCliente
                                              ? const Radius.circular(16)
                                              : const Radius.circular(4),
                                          bottomRight: souCliente
                                              ? const Radius.circular(4)
                                              : const Radius.circular(16),
                                        ),
                                        boxShadow: [
                                          BoxShadow(
                                            color: Colors.black
                                                .withValues(alpha: 0.08),
                                            blurRadius: 4,
                                            offset: const Offset(0, 1),
                                          ),
                                        ],
                                      ),
                                      child: Text(
                                        texto,
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontSize: 15,
                                          height: 1.35,
                                        ),
                                      ),
                                    ),
                                  );
                                },
                              );
                            },
                          ),
                        ),
                      ),
                    ],
                  );
                },
              ),
      ),
    );
  }

  static String _rotuloStatus(String s) {
    switch (s) {
      case 'waiting':
        return 'Aguardando';
      case 'in_progress':
        return 'Em atendimento';
      case 'cancelled':
        return 'Encerrado por você';
      case 'closed':
        return 'Encerrado pelo suporte';
      case 'finished':
        return 'Finalizado';
      default:
        return s;
    }
  }
}
