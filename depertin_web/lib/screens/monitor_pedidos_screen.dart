import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../theme/painel_admin_theme.dart';
import '../widgets/botao_suporte_flutuante.dart';

class MonitorPedidosScreen extends StatefulWidget {
  const MonitorPedidosScreen({super.key});

  @override
  State<MonitorPedidosScreen> createState() => _MonitorPedidosScreenState();
}

class _MonitorPedidosScreenState extends State<MonitorPedidosScreen> {
  static const _ink = Color(0xFF1E1B4B);
  static const _muted = Color(0xFF64748B);
  static const _border = Color(0xFFE2E8F0);
  static const _bg = Color(0xFFF8FAFC);

  static const _todosStatus = [
    'aguardando_pagamento',
    'pendente',
    'aceito',
    'em_preparo',
    'aguardando_entregador',
    'entregador_indo_loja',
    'saiu_entrega',
    'em_rota',
    'a_caminho',
    'entregue',
    'cancelado',
  ];

  String _filtro = 'hoje';
  String _janela = '24h';
  final _buscaC = TextEditingController();

  @override
  void dispose() {
    _buscaC.dispose();
    super.dispose();
  }

  String _labelStatus(String s) => switch (s) {
        'aguardando_pagamento' => 'Aguard. pgto',
        'pendente' => 'Pendente',
        'aceito' => 'Aceito',
        'em_preparo' => 'Preparando',
        'aguardando_entregador' => 'Aguard. coleta',
        'entregador_indo_loja' => 'Em coleta',
        'saiu_entrega' || 'em_rota' || 'a_caminho' => 'Em rota',
        'entregue' => 'Entregue',
        'cancelado' => 'Cancelado',
        _ => s,
      };

  Color _corStatus(String s) => switch (s) {
        'aguardando_pagamento' => const Color(0xFF64748B),
        'pendente' => const Color(0xFFD97706),
        'aceito' => const Color(0xFF2563EB),
        'em_preparo' => PainelAdminTheme.roxo,
        'aguardando_entregador' => const Color(0xFF0EA5E9),
        'entregador_indo_loja' => const Color(0xFF0891B2),
        'saiu_entrega' || 'em_rota' || 'a_caminho' => const Color(0xFF059669),
        'entregue' => const Color(0xFF16A34A),
        'cancelado' => const Color(0xFFDC2626),
        _ => _muted,
      };

  IconData _iconeStatus(String s) => switch (s) {
        'aguardando_pagamento' => Icons.payments_outlined,
        'pendente' => Icons.schedule_rounded,
        'aceito' => Icons.thumb_up_alt_outlined,
        'em_preparo' => Icons.restaurant_rounded,
        'aguardando_entregador' => Icons.inventory_2_outlined,
        'entregador_indo_loja' => Icons.directions_bike_outlined,
        'saiu_entrega' || 'em_rota' || 'a_caminho' =>
          Icons.delivery_dining_rounded,
        'entregue' => Icons.check_circle_rounded,
        'cancelado' => Icons.cancel_rounded,
        _ => Icons.circle_outlined,
      };

  bool _isFinal(String s) => s == 'entregue' || s == 'cancelado';

  bool _passaFiltro(String s) {
    if (_filtro == 'hoje' || _filtro == 'todos') return true;
    if (_filtro == 'coleta') {
      return s == 'aguardando_entregador' || s == 'entregador_indo_loja';
    }
    if (_filtro == 'rota') {
      return s == 'saiu_entrega' || s == 'em_rota' || s == 'a_caminho';
    }
    return s == _filtro;
  }

  bool _passaFiltroHoje(Timestamp? ts) {
    if (_filtro != 'hoje') return true;
    if (ts == null) return false;
    final dt = ts.toDate();
    final agora = DateTime.now();
    return dt.year == agora.year &&
        dt.month == agora.month &&
        dt.day == agora.day;
  }

  bool _passaJanela(Timestamp? ts) {
    if (_janela == 'todos' || ts == null) return _janela == 'todos';
    final diff = DateTime.now().difference(ts.toDate());
    if (_janela == '24h') return diff.inHours <= 24;
    if (_janela == '7d') return diff.inDays <= 7;
    return true;
  }

  bool _passaBusca(QueryDocumentSnapshot doc, Map<String, dynamic> d) {
    final q = _buscaC.text.trim().toLowerCase();
    if (q.isEmpty) return true;
    return [
      doc.id,
      d['loja_nome'],
      d['cliente_nome'],
      d['cliente_id'],
      d['cidade'],
      d['forma_pagamento'],
      d['endereco_entrega'],
      d['entregador_nome'],
      d['entregador_id'],
      d['status'],
    ].map((v) => (v ?? '').toString().toLowerCase()).join(' ').contains(q);
  }

  int _contar(List<QueryDocumentSnapshot> docs, bool Function(String) test) =>
      docs
          .where((d) =>
              test((d.data() as Map<String, dynamic>)['status']?.toString() ??
                  ''))
          .length;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _bg,
      floatingActionButton: const BotaoSuporteFlutuante(),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('pedidos')
            .orderBy('data_pedido', descending: true)
            .limit(500)
            .snapshots(),
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting &&
              !snap.hasData) {
            return Center(
              child: CircularProgressIndicator(color: PainelAdminTheme.roxo),
            );
          }

          final todos = (snap.data?.docs ?? []).where((doc) {
            final d = doc.data() as Map<String, dynamic>;
            final st = d['status']?.toString() ?? '';
            return _todosStatus.contains(st) &&
                _passaJanela(d['data_pedido'] as Timestamp?);
          }).toList();

          final filtrados = todos.where((doc) {
            final d = doc.data() as Map<String, dynamic>;
            final st = d['status']?.toString() ?? '';
            return _passaFiltro(st) &&
                _passaFiltroHoje(d['data_pedido'] as Timestamp?) &&
                _passaBusca(doc, d);
          }).toList();

          return CustomScrollView(
            slivers: [
              SliverToBoxAdapter(child: _header()),
              SliverToBoxAdapter(child: _kpis(todos)),
              if (filtrados.isEmpty)
                SliverFillRemaining(child: _vazio())
              else
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(24, 8, 24, 40),
                  sliver: SliverList.separated(
                    itemCount: filtrados.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 10),
                    itemBuilder: (_, i) => _card(filtrados[i]),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }

  Widget _header() {
    return Container(
      color: Colors.white,
      padding: const EdgeInsets.fromLTRB(28, 28, 28, 22),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Monitor de Pedidos',
                      style: TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.w800,
                        color: _ink,
                        letterSpacing: -0.5,
                      ),
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      'Central de investigação operacional — dados ao vivo',
                      style: TextStyle(fontSize: 14, color: _muted),
                    ),
                  ],
                ),
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                decoration: BoxDecoration(
                  color: const Color(0xFFECFDF5),
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(color: const Color(0xFFA7F3D0)),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    DecoratedBox(
                      decoration: BoxDecoration(
                        color: Color(0xFF16A34A),
                        shape: BoxShape.circle,
                      ),
                      child: SizedBox(width: 8, height: 8),
                    ),
                    SizedBox(width: 7),
                    Text(
                      'Ao vivo',
                      style: TextStyle(
                        color: Color(0xFF16A34A),
                        fontWeight: FontWeight.w700,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _buscaC,
                  onChanged: (_) => setState(() {}),
                  style: const TextStyle(fontSize: 14),
                  decoration: InputDecoration(
                    hintText:
                        'Pesquisar pedido, loja, cliente, cidade, endereço...',
                    hintStyle:
                        const TextStyle(color: Color(0xFF94A3B8), fontSize: 14),
                    prefixIcon: const Icon(Icons.search_rounded,
                        color: Color(0xFF94A3B8)),
                    filled: true,
                    fillColor: _bg,
                    isDense: true,
                    contentPadding: const EdgeInsets.symmetric(vertical: 13),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: _border),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: const BorderSide(color: _border),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(
                          color: PainelAdminTheme.roxo, width: 1.5),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 14),
              _janelaBtn('24h', '24 h'),
              const SizedBox(width: 6),
              _janelaBtn('7d', '7 dias'),
              const SizedBox(width: 6),
              _janelaBtn('todos', 'Tudo'),
            ],
          ),
          const SizedBox(height: 16),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _chip('hoje', 'Hoje'),
                _chip('todos', 'Todos'),
                _chip('pendente', 'Pendente'),
                _chip('aceito', 'Aceito'),
                _chip('em_preparo', 'Preparando'),
                _chip('coleta', 'Pronto / coleta'),
                _chip('rota', 'Em rota'),
                _chip('entregue', 'Entregue'),
                _chip('cancelado', 'Cancelado'),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _janelaBtn(String val, String label) {
    final ativo = _janela == val;
    return Material(
      color: ativo ? const Color(0xFFEEF2FF) : Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
        side: BorderSide(color: ativo ? const Color(0xFFC7D2FE) : _border),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(10),
        onTap: () => setState(() => _janela = val),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
          child: Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: ativo ? const Color(0xFF4338CA) : _muted,
            ),
          ),
        ),
      ),
    );
  }

  Widget _chip(String val, String label) {
    final ativo = _filtro == val;
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: Material(
        color: ativo ? PainelAdminTheme.roxo : Colors.white,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(999),
          side: BorderSide(
              color: ativo ? PainelAdminTheme.roxo : const Color(0xFFCBD5E1)),
        ),
        child: InkWell(
          borderRadius: BorderRadius.circular(999),
          onTap: () => setState(() => _filtro = val),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Text(
              label,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: ativo ? Colors.white : const Color(0xFF475569),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _kpis(List<QueryDocumentSnapshot> docs) {
    final ativos = _contar(docs, (s) => !_isFinal(s));
    final pendentes = _contar(docs, (s) => s == 'pendente');
    final prep = _contar(docs, (s) => s == 'em_preparo');
    final coleta = _contar(docs,
        (s) => s == 'aguardando_entregador' || s == 'entregador_indo_loja');
    final rota = _contar(
        docs, (s) => s == 'saiu_entrega' || s == 'em_rota' || s == 'a_caminho');
    final entregues = _contar(docs, (s) => s == 'entregue');
    final cancelados = _contar(docs, (s) => s == 'cancelado');

    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 18, 24, 14),
      child: Wrap(
        spacing: 12,
        runSpacing: 12,
        children: [
          _kpi('Ativos', '$ativos', Icons.insights_rounded,
              PainelAdminTheme.roxo),
          _kpi('Pendentes', '$pendentes', Icons.schedule_rounded,
              const Color(0xFFD97706)),
          _kpi('Preparando', '$prep', Icons.restaurant_rounded,
              PainelAdminTheme.roxo),
          _kpi('Coleta', '$coleta', Icons.inventory_2_outlined,
              const Color(0xFF0891B2)),
          _kpi('Em rota', '$rota', Icons.delivery_dining_rounded,
              const Color(0xFF059669)),
          _kpi('Entregues', '$entregues', Icons.check_circle_rounded,
              const Color(0xFF16A34A)),
          _kpi('Cancelados', '$cancelados', Icons.cancel_rounded,
              const Color(0xFFDC2626)),
        ],
      ),
    );
  }

  Widget _kpi(String label, String valor, IconData icon, Color cor) {
    return Container(
      width: 155,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _border),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: cor.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, size: 20, color: cor),
          ),
          const SizedBox(width: 10),
          Flexible(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  valor,
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                    color: cor,
                    height: 1,
                  ),
                ),
                Text(
                  label,
                  style: const TextStyle(
                      fontSize: 11, color: _muted, fontWeight: FontWeight.w500),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _vazio() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.inbox_rounded,
              size: 56, color: _muted.withValues(alpha: 0.3)),
          const SizedBox(height: 14),
          const Text(
            'Nenhum pedido encontrado',
            style:
                TextStyle(fontSize: 16, color: _muted, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 6),
          const Text(
            'Ajuste os filtros, janela de tempo ou busca.',
            style: TextStyle(fontSize: 13, color: _muted),
          ),
        ],
      ),
    );
  }

  Widget _card(QueryDocumentSnapshot doc) {
    final d = doc.data() as Map<String, dynamic>;
    final st = d['status']?.toString() ?? '';
    final cor = _corStatus(st);
    final total = _num(d['total']);
    final prods = _num(d['total_produtos']) > 0
        ? _num(d['total_produtos'])
        : _num(d['subtotal']);
    final frete = _num(d['taxa_entrega']);
    final forma = d['forma_pagamento']?.toString() ?? '—';
    final ts = d['data_pedido'] as Timestamp?;
    final dtStr =
        ts != null ? DateFormat('dd/MM/yy  HH:mm').format(ts.toDate()) : '—';
    final loja = d['loja_nome']?.toString() ?? 'Loja';
    final cliente =
        d['cliente_nome']?.toString() ?? d['cliente_id']?.toString() ?? '—';
    final cidade = d['cidade']?.toString() ?? '';
    final endereco = d['endereco_entrega']?.toString() ?? '';
    final entregador = d['entregador_nome']?.toString() ??
        (d['entregador_id'] != null ? '(${d['entregador_id']})' : '—');
    final itens =
        ((d['itens'] as List?) ?? (d['items'] as List?) ?? const []).length;
    final idCurto = doc.id.length >= 5
        ? doc.id.substring(0, 5).toUpperCase()
        : doc.id.toUpperCase();

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _border),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () => _detalhe(doc),
          child: Padding(
            padding: const EdgeInsets.all(18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(9),
                      decoration: BoxDecoration(
                        color: cor.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(_iconeStatus(st), size: 20, color: cor),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '#$idCurto',
                            style: const TextStyle(
                              fontWeight: FontWeight.w800,
                              fontSize: 15,
                              color: _ink,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            '$loja  •  $cliente',
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: Color(0xFF475569),
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 5),
                      decoration: BoxDecoration(
                        color: cor.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(999),
                        border: Border.all(color: cor.withValues(alpha: 0.25)),
                      ),
                      child: Text(
                        _labelStatus(st),
                        style: TextStyle(
                          color: cor,
                          fontWeight: FontWeight.w700,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                Wrap(
                  spacing: 18,
                  runSpacing: 6,
                  children: [
                    _tag(Icons.calendar_today_rounded, dtStr),
                    if (cidade.isNotEmpty)
                      _tag(Icons.location_on_outlined, cidade),
                    _tag(Icons.shopping_bag_outlined, '$itens item(s)'),
                    _tag(Icons.credit_card_outlined, forma),
                    _tag(Icons.two_wheeler_rounded, entregador),
                  ],
                ),
                if (endereco.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Text(
                    endereco,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 12,
                      color: _muted,
                      height: 1.3,
                    ),
                  ),
                ],
                const Divider(height: 22, color: _border),
                Row(
                  children: [
                    _valorBox('Produtos', prods),
                    const SizedBox(width: 10),
                    _valorBox('Frete', frete),
                    const SizedBox(width: 10),
                    _valorBox('Total', total, destaque: true),
                    const Spacer(),
                    TextButton.icon(
                      onPressed: () => _detalhe(doc),
                      icon: const Icon(Icons.manage_search_rounded, size: 18),
                      label: const Text(
                        'Investigar',
                        style: TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 13,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _tag(IconData icon, String text) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 14, color: _muted),
        const SizedBox(width: 5),
        Text(
          text,
          style: const TextStyle(fontSize: 12, color: Color(0xFF475569)),
        ),
      ],
    );
  }

  Widget _valorBox(String label, double valor, {bool destaque = false}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: destaque
            ? PainelAdminTheme.roxo.withValues(alpha: 0.06)
            : _bg,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
            color: destaque
                ? PainelAdminTheme.roxo.withValues(alpha: 0.15)
                : _border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(
                fontSize: 10, color: _muted, fontWeight: FontWeight.w600),
          ),
          Text(
            'R\$ ${valor.toStringAsFixed(2)}',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w800,
              color: destaque ? PainelAdminTheme.roxo : _ink,
            ),
          ),
        ],
      ),
    );
  }

  void _detalhe(QueryDocumentSnapshot doc) {
    final d = doc.data() as Map<String, dynamic>;
    final st = d['status']?.toString() ?? '';
    final ts = d['data_pedido'] as Timestamp?;
    final rows = <MapEntry<String, String>>[
      MapEntry('Pedido ID', doc.id),
      MapEntry('Status', _labelStatus(st)),
      MapEntry(
          'Data / hora',
          ts != null
              ? DateFormat('dd/MM/yyyy  HH:mm:ss').format(ts.toDate())
              : '—'),
      MapEntry('Loja', d['loja_nome']?.toString() ?? '—'),
      MapEntry(
          'Loja ID', (d['loja_id'] ?? d['lojista_id'])?.toString() ?? '—'),
      MapEntry('Cliente', d['cliente_nome']?.toString() ?? '—'),
      MapEntry('Cliente ID', d['cliente_id']?.toString() ?? '—'),
      MapEntry('Entregador', d['entregador_nome']?.toString() ?? '—'),
      MapEntry('Entregador ID', d['entregador_id']?.toString() ?? '—'),
      MapEntry('Pagamento', d['forma_pagamento']?.toString() ?? '—'),
      MapEntry(
          'Produtos',
          'R\$ ${_num(d['total_produtos'] ?? d['subtotal']).toStringAsFixed(2)}'),
      MapEntry(
          'Frete', 'R\$ ${_num(d['taxa_entrega']).toStringAsFixed(2)}'),
      MapEntry('Total', 'R\$ ${_num(d['total']).toStringAsFixed(2)}'),
      MapEntry('Endereço', d['endereco_entrega']?.toString() ?? '—'),
      MapEntry('Cidade', d['cidade']?.toString() ?? '—'),
      MapEntry('Token entrega', d['token_entrega']?.toString() ?? '—'),
    ];

    showDialog<void>(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 680, maxHeight: 700),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 22, 16, 14),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: PainelAdminTheme.roxo.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(Icons.manage_search_rounded,
                          color: PainelAdminTheme.roxo, size: 24),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Investigação do pedido',
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.w800,
                              color: _ink,
                            ),
                          ),
                          Text(
                            '#${doc.id}',
                            style: const TextStyle(
                              fontSize: 12,
                              color: _muted,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      onPressed: () => Navigator.pop(ctx),
                      icon: const Icon(Icons.close_rounded),
                    ),
                  ],
                ),
              ),
              const Divider(height: 1),
              Expanded(
                child: ListView.separated(
                  padding: const EdgeInsets.fromLTRB(24, 14, 24, 24),
                  itemCount: rows.length,
                  separatorBuilder: (_, __) =>
                      Divider(height: 1, color: _border.withValues(alpha: 0.6)),
                  itemBuilder: (_, i) {
                    final item = rows[i];
                    return Padding(
                      padding: const EdgeInsets.symmetric(vertical: 11),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          SizedBox(
                            width: 140,
                            child: Text(
                              item.key,
                              style: const TextStyle(
                                fontSize: 13,
                                color: _muted,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: SelectableText(
                              item.value,
                              style: const TextStyle(
                                fontSize: 13.5,
                                color: _ink,
                                fontWeight: FontWeight.w600,
                                height: 1.4,
                              ),
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  double _num(dynamic v) {
    if (v == null) return 0;
    if (v is num) return v.toDouble();
    return double.tryParse(v.toString()) ?? 0;
  }
}
