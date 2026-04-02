// Central de Ajuda — support_tickets + mensagens em tempo real

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:depertin_cliente/screens/cliente/suporte_historico_conversa_screen.dart';
import 'package:depertin_cliente/services/support_ticket_service.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

const Color diPertinRoxo = Color(0xFF6A1B9A);
const Color diPertinLaranja = Color(0xFFFF8F00);

class ChatSuporteScreen extends StatefulWidget {
  const ChatSuporteScreen({super.key});

  @override
  State<ChatSuporteScreen> createState() => _ChatSuporteScreenState();
}

class _ChatSuporteScreenState extends State<ChatSuporteScreen> {
  final TextEditingController _mensagemController = TextEditingController();
  final SupportTicketService _svc = SupportTicketService.instance;

  bool _criandoTicket = false;
  bool _enviando = false;
  String? _statusAnterior;
  String? _ticketIdRastreado;
  bool _jaAvisouAgente = false;
  bool _jaMostrouFilaSucesso = false;
  /// Avaliação acabou de ser enviada (reforço visual antes do stream autorizado).
  final Set<String> _ticketIdComAvaliacaoEnviada = {};

  @override
  void dispose() {
    _mensagemController.dispose();
    super.dispose();
  }

  void _abrirConversaHistorico(BuildContext context, String ticketId) {
    Navigator.push<void>(
      context,
      MaterialPageRoute<void>(
        builder: (ctx) => SuporteHistoricoConversaScreen(ticketId: ticketId),
      ),
    );
  }

  void _sincronizarRastreioTicket(String ticketId) {
    if (_ticketIdRastreado != ticketId) {
      _ticketIdRastreado = ticketId;
      _statusAnterior = null;
      _jaAvisouAgente = false;
      _jaMostrouFilaSucesso = false;
    }
  }

  Future<void> _iniciarAtendimento() async {
    if (_criandoTicket) return;
    setState(() => _criandoTicket = true);
    try {
      await _svc.criarTicket();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Chamado aberto. Envie sua primeira mensagem para entrar na fila.',
            ),
            backgroundColor: diPertinRoxo,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Não foi possível abrir o chamado: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _criandoTicket = false);
    }
  }

  Future<void> _enviarMensagem(String ticketId) async {
    final texto = _mensagemController.text.trim();
    if (texto.isEmpty || _enviando) return;
    setState(() => _enviando = true);
    _mensagemController.clear();
    try {
      await _svc.enviarMensagemCliente(ticketId: ticketId, texto: texto);
      if (!mounted) return;
      if (!_jaMostrouFilaSucesso) {
        _jaMostrouFilaSucesso = true;
        await showDialog<void>(
          context: context,
          barrierDismissible: true,
          builder: (ctx) => AlertDialog(
            title: const Row(
              children: [
                Icon(Icons.check_circle, color: Colors.green),
                SizedBox(width: 8),
                Expanded(child: Text('Solicitação enviada')),
              ],
            ),
            content: const Text(
              'Sua mensagem foi registrada. Quando um atendente estiver disponível, '
              'você será atendido e verá o aviso aqui no chat.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('OK'),
              ),
            ],
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erro ao enviar: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _enviando = false);
    }
  }

  Future<void> _encerrarPeloCliente(String ticketId) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Encerrar atendimento?'),
        content: const Text(
          'Você pode abrir um novo chamado depois, se precisar.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Encerrar', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    try {
      await _svc.encerrarPeloCliente(ticketId);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erro: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  Future<void> _abrirAvaliacao({
    required String ticketId,
    required String protocolo,
  }) async {
    int estrelas = 5;
    final c = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setModal) {
          return AlertDialog(
            title: Text('Avaliar atendimento — $protocolo'),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: List.generate(5, (i) {
                      final n = i + 1;
                      return IconButton(
                        icon: Icon(
                          n <= estrelas ? Icons.star : Icons.star_border,
                          color: diPertinLaranja,
                          size: 36,
                        ),
                        onPressed: () => setModal(() => estrelas = n),
                      );
                    }),
                  ),
                  TextField(
                    controller: c,
                    maxLines: 3,
                    decoration: const InputDecoration(
                      labelText: 'Comentário (opcional)',
                      border: OutlineInputBorder(),
                    ),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('Fechar sem avaliar'),
              ),
              ElevatedButton(
                onPressed: () => Navigator.pop(ctx, true),
                style: ElevatedButton.styleFrom(backgroundColor: diPertinRoxo),
                child: const Text('Enviar'),
              ),
            ],
          );
        },
      ),
    );
    if (ok != true || !mounted) return;
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;
    try {
      await FirebaseFirestore.instance.collection('support_ratings').add({
        'ticket_id': ticketId,
        'user_id': uid,
        'rating': estrelas,
        'comment': c.text.trim(),
        'created_at': FieldValue.serverTimestamp(),
      });
      if (mounted) {
        setState(() => _ticketIdComAvaliacaoEnviada.add(ticketId));
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Obrigado pela avaliação!'),
            backgroundColor: Colors.green,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Erro: $e'), backgroundColor: Colors.red),
        );
      }
    }
  }

  void _detectarInicioAgente(String ticketId, Map<String, dynamic> d) {
    _sincronizarRastreioTicket(ticketId);
    final st = d['status']?.toString() ?? '';
    final nome = d['agent_nome']?.toString() ?? '';
    if (_statusAnterior == SuporteTicketStatus.waiting &&
        st == SuporteTicketStatus.inProgress &&
        nome.isNotEmpty &&
        !_jaAvisouAgente) {
      _jaAvisouAgente = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('$nome iniciou seu atendimento.'),
            backgroundColor: diPertinLaranja,
            duration: const Duration(seconds: 5),
          ),
        );
      });
    }
    _statusAnterior = st;
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;

    return Scaffold(
      backgroundColor: Colors.grey[200],
      appBar: AppBar(
        title: const Row(
          children: [
            Icon(Icons.support_agent, color: Colors.white, size: 24),
            SizedBox(width: 10),
            Expanded(
              child: Text(
                'Central de Ajuda',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 18,
                ),
              ),
            ),
          ],
        ),
        backgroundColor: diPertinRoxo,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: user == null
          ? const Center(child: Text('Faça login para usar o suporte.'))
          : StreamBuilder<QueryDocumentSnapshot<Map<String, dynamic>>?>(
              stream: _svc.streamUltimoTicket(),
              builder: (context, snapTicket) {
                if (snapTicket.connectionState == ConnectionState.waiting) {
                  return const Center(
                    child: CircularProgressIndicator(color: diPertinRoxo),
                  );
                }

                final doc = snapTicket.data;
                if (doc == null) {
                  return _painelInicial();
                }

                final d = doc.data();
                final st = d['status']?.toString() ?? '';

                if (st == SuporteTicketStatus.waiting ||
                    st == SuporteTicketStatus.inProgress) {
                  return _corpoChat(doc: doc, dados: d);
                }

                return _telaFinalizado(doc: doc, dados: d);
              },
            ),
    );
  }

  Widget _corpoChat({
    required QueryDocumentSnapshot<Map<String, dynamic>> doc,
    required Map<String, dynamic> dados,
  }) {
    final ticketId = doc.id;
    _detectarInicioAgente(ticketId, dados);

    final protocolo =
        (dados['protocol_number'] ?? '').toString().padLeft(8, '0');
    final cidade = dados['cidade']?.toString() ?? '—';
    final st = dados['status']?.toString() ?? '';

    return Column(
      children: [
        _cabecalhoProtocolo(
          protocolo: protocolo,
          status: st,
          encerrado: false,
          agentNome: dados['agent_nome']?.toString(),
        ),
        if (st == SuporteTicketStatus.waiting)
          _faixaFila(ticketId: ticketId, cidade: cidade),
        Expanded(
          child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
            stream: FirebaseFirestore.instance
                .collection('support_tickets')
                .doc(ticketId)
                .collection('mensagens')
                .orderBy('created_at', descending: true)
                .snapshots(),
            builder: (context, snapMsg) {
              if (!snapMsg.hasData) {
                return const Center(
                  child: CircularProgressIndicator(color: diPertinRoxo),
                );
              }
              final msgs = snapMsg.data!.docs;
              if (msgs.isEmpty) {
                return const Center(
                  child: Text(
                    'Descreva sua dúvida ou problema abaixo.',
                    style: TextStyle(
                      color: Colors.grey,
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                );
              }
              return ListView.builder(
                reverse: true,
                padding: const EdgeInsets.all(15),
                itemCount: msgs.length,
                itemBuilder: (context, index) {
                  final msg = msgs[index].data();
                  final tipo = msg['sender_type']?.toString() ?? '';
                  final texto = msg['mensagem']?.toString() ?? '';
                  if (tipo == 'system') {
                    return Center(
                      child: Container(
                        margin: const EdgeInsets.symmetric(vertical: 12),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 8,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.grey[300],
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          texto,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: Colors.black54,
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
                        horizontal: 15,
                        vertical: 10,
                      ),
                      constraints: BoxConstraints(
                        maxWidth: MediaQuery.of(context).size.width * 0.8,
                      ),
                      decoration: BoxDecoration(
                        color: souCliente ? diPertinRoxo : diPertinLaranja,
                        borderRadius: BorderRadius.only(
                          topLeft: const Radius.circular(15),
                          topRight: const Radius.circular(15),
                          bottomLeft: souCliente
                              ? const Radius.circular(15)
                              : const Radius.circular(0),
                          bottomRight: souCliente
                              ? const Radius.circular(0)
                              : const Radius.circular(15),
                        ),
                      ),
                      child: Text(
                        texto,
                        style: const TextStyle(color: Colors.white, fontSize: 15),
                      ),
                    ),
                  );
                },
              );
            },
          ),
        ),
        _rodapeDigitacao(
          ticketId: ticketId,
          status: st,
          onEncerrar: () => _encerrarPeloCliente(ticketId),
        ),
      ],
    );
  }

  Widget _telaFinalizado({
    required QueryDocumentSnapshot<Map<String, dynamic>> doc,
    required Map<String, dynamic> dados,
  }) {
    final ticketId = doc.id;
    final protocolo =
        (dados['protocol_number'] ?? '').toString().padLeft(8, '0');
    final st = dados['status']?.toString() ?? '';
    final podeAvaliar = st == SuporteTicketStatus.closed ||
        st == SuporteTicketStatus.finished;

    final blocoNovoAtendimentoEHistorico = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SizedBox(
          height: 48,
          child: ElevatedButton(
            onPressed: _criandoTicket ? null : _iniciarAtendimento,
            style: ElevatedButton.styleFrom(
              backgroundColor: diPertinLaranja,
              foregroundColor: Colors.white,
            ),
            child: _criandoTicket
                ? const SizedBox(
                    height: 22,
                    width: 22,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : const Text(
                    'Novo atendimento',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
          ),
        ),
        const SizedBox(height: 24),
        const Text(
          'Histórico',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 16,
            color: diPertinRoxo,
          ),
        ),
        StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
          stream: _svc.streamHistoricoUsuario(),
          builder: (context, snap) {
            if (!snap.hasData || snap.data!.docs.isEmpty) {
              return Text(
                'Nenhum outro chamado.',
                style: TextStyle(color: Colors.grey[600]),
              );
            }
            return Column(
              children: snap.data!.docs.map((d) {
                final x = d.data();
                final p = (x['protocol_number'] ?? '').toString().padLeft(
                  8,
                  '0',
                );
                final s = x['status']?.toString() ?? '';
                return ListTile(
                  dense: true,
                  title: Text('Protocolo $p'),
                  subtitle: Text(_labelStatus(s)),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => _abrirConversaHistorico(context, d.id),
                );
              }).toList(),
            );
          },
        ),
      ],
    );

    if (podeAvaliar) {
      final uid = FirebaseAuth.instance.currentUser?.uid;
      if (uid == null) {
        return SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: blocoNovoAtendimentoEHistorico,
        );
      }
      return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        // Precisa filtrar por user_id: as regras só permitem ler docs do próprio usuário.
        stream: FirebaseFirestore.instance
            .collection('support_ratings')
            .where('ticket_id', isEqualTo: ticketId)
            .where('user_id', isEqualTo: uid)
            .limit(1)
            .snapshots(),
        builder: (context, snap) {
          final jaAvaliou = _ticketIdComAvaliacaoEnviada.contains(ticketId) ||
              (snap.hasData && snap.data!.docs.isNotEmpty);
          return SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (!jaAvaliou) ...[
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        children: [
                          Icon(
                            Icons.assignment_turned_in,
                            size: 56,
                            color: Colors.green[600],
                          ),
                          const SizedBox(height: 12),
                          Text(
                            'Protocolo $protocolo',
                            style: const TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                              color: diPertinRoxo,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            _mensagemFinalizado(st),
                            textAlign: TextAlign.center,
                            style: TextStyle(color: Colors.grey[800]),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        children: [
                          const Text(
                            'Como foi seu atendimento?',
                            style: TextStyle(fontWeight: FontWeight.w600),
                          ),
                          const SizedBox(height: 12),
                          SizedBox(
                            width: double.infinity,
                            child: OutlinedButton(
                              onPressed: () => _abrirAvaliacao(
                                ticketId: ticketId,
                                protocolo: protocolo,
                              ),
                              child: const Text('Avaliar atendimento'),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                ],
                blocoNovoAtendimentoEHistorico,
              ],
            ),
          );
        },
      );
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                children: [
                  Icon(
                    Icons.assignment_turned_in,
                    size: 56,
                    color: Colors.green[600],
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Protocolo $protocolo',
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: diPertinRoxo,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _mensagemFinalizado(st),
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.grey[800]),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          blocoNovoAtendimentoEHistorico,
        ],
      ),
    );
  }

  String _mensagemFinalizado(String s) {
    switch (s) {
      case SuporteTicketStatus.cancelled:
        return 'Você encerrou este atendimento.';
      case SuporteTicketStatus.closed:
        return 'Este atendimento foi encerrado pelo suporte.';
      case SuporteTicketStatus.finished:
        return 'Atendimento finalizado.';
      default:
        return 'Atendimento encerrado.';
    }
  }

  Widget _painelInicial() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Card(
            elevation: 2,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                children: [
                  const Icon(Icons.headset_mic, size: 56, color: diPertinRoxo),
                  const SizedBox(height: 16),
                  const Text(
                    'Central de Ajuda',
                    style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                      color: diPertinRoxo,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'O atendimento só começa quando você clicar no botão abaixo. '
                    'Será gerado um protocolo de 8 dígitos e você poderá acompanhar a fila em tempo real.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.grey[800], height: 1.35),
                  ),
                  const SizedBox(height: 24),
                  SizedBox(
                    height: 52,
                    child: ElevatedButton(
                      onPressed: _criandoTicket ? null : _iniciarAtendimento,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: diPertinLaranja,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: _criandoTicket
                          ? const SizedBox(
                              height: 22,
                              width: 22,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Text(
                              'Iniciar atendimento',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 24),
          const Text(
            'Histórico recente',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              fontSize: 16,
              color: diPertinRoxo,
            ),
          ),
          const SizedBox(height: 8),
          StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
            stream: _svc.streamHistoricoUsuario(),
            builder: (context, snap) {
              if (!snap.hasData || snap.data!.docs.isEmpty) {
                return Text(
                  'Nenhum chamado anterior.',
                  style: TextStyle(color: Colors.grey[600]),
                );
              }
              return Column(
                children: snap.data!.docs.map((doc) {
                  final x = doc.data();
                  final p = (x['protocol_number'] ?? '').toString().padLeft(
                    8,
                    '0',
                  );
                  final s = x['status']?.toString() ?? '';
                  return ListTile(
                    tileColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                    title: Text('Protocolo $p'),
                    subtitle: Text(_labelStatus(s)),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () => _abrirConversaHistorico(context, doc.id),
                  );
                }).toList(),
              );
            },
          ),
        ],
      ),
    );
  }

  String _labelStatus(String s) {
    switch (s) {
      case SuporteTicketStatus.waiting:
        return 'Aguardando';
      case SuporteTicketStatus.inProgress:
        return 'Em atendimento';
      case SuporteTicketStatus.finished:
        return 'Finalizado';
      case SuporteTicketStatus.cancelled:
        return 'Encerrado por você';
      case SuporteTicketStatus.closed:
        return 'Encerrado pelo suporte';
      default:
        return s;
    }
  }

  Widget _cabecalhoProtocolo({
    required String protocolo,
    required String status,
    required bool encerrado,
    String? agentNome,
  }) {
    Color bg;
    IconData ic;
    String msg;
    if (encerrado) {
      bg = Colors.green[100]!;
      ic = Icons.check_circle_outline;
      msg = 'Este atendimento foi encerrado.';
    } else if (status == SuporteTicketStatus.waiting) {
      bg = Colors.amber[100]!;
      ic = Icons.hourglass_top;
      msg = 'Aguardando atendente';
    } else {
      bg = Colors.blue[50]!;
      ic = Icons.support_agent;
      msg = agentNome != null && agentNome.isNotEmpty
          ? 'Em atendimento com $agentNome'
          : 'Em atendimento';
    }
    return Material(
      color: bg,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(ic, color: Colors.black87, size: 22),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Protocolo $protocolo',
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    msg,
                    style: const TextStyle(fontSize: 12, color: Colors.black87),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _faixaFila({required String ticketId, required String cidade}) {
    return StreamBuilder<int>(
      stream: _svc.streamPosicaoFila(
        ticketId: ticketId,
        cidadeNormalizada: cidade,
      ),
      builder: (context, snap) {
        final pos = snap.data ?? 0;
        return Material(
          color: diPertinLaranja.withValues(alpha: 0.15),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            child: Row(
              children: [
                const Icon(Icons.queue, color: diPertinLaranja),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    pos > 0
                        ? 'Fila de espera: você é o $posº na sua região.'
                        : 'Na fila de espera — aguarde um atendente.',
                    style: const TextStyle(fontSize: 12, color: Colors.black87),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _rodapeDigitacao({
    required String ticketId,
    required String status,
    required VoidCallback onEncerrar,
  }) {
    return Container(
      padding: const EdgeInsets.all(10),
      color: Colors.white,
      child: SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Align(
              alignment: Alignment.centerRight,
              child: TextButton.icon(
                onPressed: onEncerrar,
                icon: const Icon(Icons.close, color: Colors.red, size: 20),
                label: const Text(
                  'Encerrar atendimento',
                  style: TextStyle(color: Colors.red),
                ),
              ),
            ),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _mensagemController,
                    enabled: !_enviando,
                    decoration: InputDecoration(
                      hintText: status == SuporteTicketStatus.waiting
                          ? 'Primeira mensagem ou detalhes...'
                          : 'Digite sua mensagem...',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(25),
                        borderSide: BorderSide.none,
                      ),
                      filled: true,
                      fillColor: Colors.grey[100],
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 10,
                      ),
                    ),
                    textCapitalization: TextCapitalization.sentences,
                    onSubmitted: (_) => _enviarMensagem(ticketId),
                  ),
                ),
                const SizedBox(width: 10),
                Container(
                  decoration: const BoxDecoration(
                    color: diPertinRoxo,
                    shape: BoxShape.circle,
                  ),
                  child: IconButton(
                    icon: _enviando
                        ? const SizedBox(
                            width: 22,
                            height: 22,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Icon(Icons.send, color: Colors.white),
                    onPressed: _enviando ? null : () => _enviarMensagem(ticketId),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
