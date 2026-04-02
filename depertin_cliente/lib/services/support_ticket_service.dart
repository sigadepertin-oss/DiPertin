import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

/// Status do chamado (Central de Ajuda).
abstract class SuporteTicketStatus {
  static const waiting = 'waiting';
  static const inProgress = 'in_progress';
  static const finished = 'finished';
  static const cancelled = 'cancelled';
  static const closed = 'closed';
}

class SupportTicketService {
  SupportTicketService._();
  static final SupportTicketService instance = SupportTicketService._();

  final FirebaseFirestore _db = FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> get _tickets =>
      _db.collection('support_tickets');

  /// Protocolo numérico de 8 dígitos (10000000–99999999).
  ///
  /// Não consultamos o Firestore para checar colisão: uma query por
  /// `protocol_number` seria negada pelas regras (poderia retornar ticket de
  /// outro usuário). Unicidade é probabilística (~1 em 90M por sorteio).
  int gerarProtocoloNumerico() {
    return 10000000 + Random().nextInt(90000000);
  }

  Future<Map<String, dynamic>> dadosUsuarioAtual() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) throw Exception('Usuário não autenticado.');
    final doc = await _db.collection('users').doc(uid).get();
    final d = doc.data() ?? {};
    final cidade = (d['cidade'] ?? '').toString().trim().toLowerCase();
    return {
      'uid': uid,
      'nome': (d['nome'] ?? 'Cliente').toString(),
      'cidade': cidade.isEmpty ? '—' : cidade,
    };
  }

  /// Cria chamado em [waiting] sem mensagens (atendimento só após "Iniciar").
  Future<String> criarTicket() async {
    final u = await dadosUsuarioAtual();
    final protocol = gerarProtocoloNumerico();
    final ref = _tickets.doc();
    await ref.set({
      'protocol_number': protocol,
      'user_id': u['uid'],
      'user_nome': u['nome'],
      'cidade': u['cidade'],
      'agent_id': null,
      'agent_nome': null,
      'status': SuporteTicketStatus.waiting,
      'queue_position': null,
      'first_message_preview': '',
      'created_at': FieldValue.serverTimestamp(),
      'updated_at': FieldValue.serverTimestamp(),
      'started_at': null,
      'finished_at': null,
      'closed_by': null,
    });
    return ref.id;
  }

  Future<void> enviarMensagemCliente({
    required String ticketId,
    required String texto,
  }) async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) throw Exception('Não autenticado.');
    final t = texto.trim();
    if (t.isEmpty) return;

    final ticketRef = _tickets.doc(ticketId);
    final snap = await ticketRef.get();
    if (!snap.exists) throw Exception('Chamado não encontrado.');
    final st = snap.data()?['status']?.toString() ?? '';
    if (st != SuporteTicketStatus.waiting &&
        st != SuporteTicketStatus.inProgress) {
      throw Exception('Este atendimento já foi encerrado.');
    }

    final batch = _db.batch();
    final msgRef = ticketRef.collection('mensagens').doc();
    batch.set(msgRef, {
      'mensagem': t,
      'sender_id': uid,
      'sender_type': 'client',
      'is_read': false,
      'created_at': FieldValue.serverTimestamp(),
    });

    final preview = snap.data()?['first_message_preview']?.toString() ?? '';
    if (preview.isEmpty) {
      batch.update(ticketRef, {
        'first_message_preview': t.length > 120 ? '${t.substring(0, 120)}…' : t,
        'updated_at': FieldValue.serverTimestamp(),
      });
    } else {
      batch.update(ticketRef, {
        'updated_at': FieldValue.serverTimestamp(),
      });
    }
    await batch.commit();
  }

  Future<void> encerrarPeloCliente(String ticketId) async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;
    await _tickets.doc(ticketId).update({
      'status': SuporteTicketStatus.cancelled,
      'updated_at': FieldValue.serverTimestamp(),
      'finished_at': FieldValue.serverTimestamp(),
      'closed_by': 'client',
    });
  }

  /// Chamado mais recente do usuário (1 doc) ou null se nunca abriu ticket.
  Stream<QueryDocumentSnapshot<Map<String, dynamic>>?> streamUltimoTicket() {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) {
      return Stream.value(null);
    }
    return _tickets
        .where('user_id', isEqualTo: uid)
        .orderBy('created_at', descending: true)
        .limit(1)
        .snapshots()
        .map((s) => s.docs.isEmpty ? null : s.docs.first);
  }

  /// Histórico de chamados do usuário.
  Stream<QuerySnapshot<Map<String, dynamic>>> streamHistoricoUsuario() {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) {
      return const Stream.empty();
    }
    return _tickets
        .where('user_id', isEqualTo: uid)
        .orderBy('created_at', descending: true)
        .limit(30)
        .snapshots();
  }

  /// Posição na fila (1 = primeiro), apenas para [waiting] e mesma cidade.
  Stream<int> streamPosicaoFila({
    required String ticketId,
    required String cidadeNormalizada,
  }) {
    return _tickets
        .where('status', isEqualTo: SuporteTicketStatus.waiting)
        .where('cidade', isEqualTo: cidadeNormalizada)
        .orderBy('created_at', descending: false)
        .snapshots()
        .map((snap) {
      final i = snap.docs.indexWhere((d) => d.id == ticketId);
      return i >= 0 ? i + 1 : 0;
    });
  }
}
