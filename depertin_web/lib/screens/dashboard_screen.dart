import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_fonts/google_fonts.dart';
import '../navigation/painel_navigation_scope.dart';
import '../theme/painel_admin_theme.dart';
import '../widgets/botao_suporte_flutuante.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  final Color diPertinRoxo = PainelAdminTheme.roxo;
  final Color diPertinLaranja = PainelAdminTheme.laranja;

  // Variáveis Operacionais (Pendências)
  int _lojasPendentes = 0;
  int _entregadoresPendentes = 0;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _carregarPendencias();
  }

  // === 1. BUSCA AS PENDÊNCIAS RÁPIDAS ===
  Future<void> _carregarPendencias() async {
    try {
      var db = FirebaseFirestore.instance;
      var lojasP = await db
          .collection('users')
          .where('role', isEqualTo: 'lojista')
          .where('status_loja', isEqualTo: 'pendente')
          .count()
          .get();
      var entregadoresP = await db
          .collection('users')
          .where('role', isEqualTo: 'entregador')
          .where('entregador_status', isEqualTo: 'pendente')
          .count()
          .get();

      if (mounted) {
        setState(() {
          _lojasPendentes = lojasP.count ?? 0;
          _entregadoresPendentes = entregadoresP.count ?? 0;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // === 2. STREAM PARA OS CARDS DE RANKING (Do seu código) ===
  Stream<QuerySnapshot> getUsuariosStream(String? tipo) {
    if (tipo == null) {
      return FirebaseFirestore.instance.collection('users').snapshots();
    }
    // Suportando 'role' ou 'tipoUsuario' dependendo de como está no seu banco
    return FirebaseFirestore.instance
        .collection('users')
        .where('role', isEqualTo: tipo)
        .snapshots();
  }

  // === 3. BUSCA CIDADES PARA O RANKING (Do seu código) ===
  Future<List<String>> getCidadesCadastradas(String? tipo) async {
    try {
      Query query = FirebaseFirestore.instance.collection('users');
      if (tipo != null) query = query.where('role', isEqualTo: tipo);

      QuerySnapshot snapshot = await query.get(
        const GetOptions(source: Source.server),
      );
      Set<String> cidades = {};

      for (var doc in snapshot.docs) {
        try {
          Map<String, dynamic>? dados = doc.data() as Map<String, dynamic>?;
          if (dados != null) {
            String? nomeCidade =
                dados['cidade']?.toString() ?? dados['Cidade']?.toString();
            if (nomeCidade != null && nomeCidade.trim().isNotEmpty) {
              String cidFormatada = nomeCidade.trim();
              cidFormatada =
                  cidFormatada[0].toUpperCase() +
                  cidFormatada.substring(1).toLowerCase();
              cidades.add(cidFormatada);
            }
          }
        } catch (e) {}
      }
      return cidades.toList()..sort();
    } catch (e) {
      return [];
    }
  }

  // === WIDGET: CARD DE PENDÊNCIA (Operacional) ===
  Widget _buildPendenciaCard(
    BuildContext context,
    String title,
    int count,
    IconData icon,
    Color color,
    String rota,
  ) {
    return Expanded(
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => context.navegarPainel(rota),
          borderRadius: BorderRadius.circular(16),
          child: Container(
            padding: const EdgeInsets.all(22),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              boxShadow: PainelAdminTheme.sombraCardSuave(),
              border: Border.all(color: color.withOpacity(0.12)),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Icon(icon, color: color, size: 26),
                ),
                const SizedBox(width: 18),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: GoogleFonts.plusJakartaSans(
                          color: PainelAdminTheme.textoSecundario,
                          fontWeight: FontWeight.w600,
                          fontSize: 13,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        count.toString(),
                        style: GoogleFonts.plusJakartaSans(
                          fontSize: 28,
                          fontWeight: FontWeight.w800,
                          color: color,
                          height: 1,
                          letterSpacing: -0.5,
                        ),
                      ),
                    ],
                  ),
                ),
                Icon(Icons.arrow_forward_ios_rounded,
                    size: 16, color: color.withOpacity(0.45)),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // === WIDGET: CARD DE RANKING (Do seu código) ===
  Widget _cardContadorRanking(String titulo, String? tipo, Color cor) {
    return Expanded(
      child: StreamBuilder<QuerySnapshot>(
        stream: getUsuariosStream(tipo),
        builder: (context, snapshot) {
          String total = snapshot.hasData
              ? snapshot.data!.docs.length.toString()
              : '…';
          return Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: () => _dialogSelecionarCidade(titulo, tipo),
              borderRadius: BorderRadius.circular(16),
              child: Container(
                padding: const EdgeInsets.fromLTRB(20, 22, 20, 20),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: PainelAdminTheme.sombraCardSuave(),
                  border: Border.all(color: const Color(0xFFE8E4F0)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      height: 4,
                      decoration: BoxDecoration(
                        color: cor,
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      titulo,
                      style: GoogleFonts.plusJakartaSans(
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
                        color: const Color(0xFF475569),
                        height: 1.25,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      total,
                      style: GoogleFonts.plusJakartaSans(
                        fontSize: 34,
                        color: cor,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -1,
                        height: 1,
                      ),
                    ),
                    const SizedBox(height: 14),
                    Row(
                      children: [
                        Text(
                          'Ver ranking',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: PainelAdminTheme.roxo,
                          ),
                        ),
                        const SizedBox(width: 4),
                        Icon(
                          Icons.arrow_outward_rounded,
                          size: 14,
                          color: PainelAdminTheme.roxo.withOpacity(0.8),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  // === DIÁLOGOS DE RANKING (Do seu código) ===
  void _dialogSelecionarCidade(String titulo, String? tipo) async {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(child: CircularProgressIndicator()),
    );
    List<String> cidades = await getCidadesCadastradas(tipo);
    if (!mounted) return;
    Navigator.pop(context);

    final tipoBusca = tipo ?? 'cliente';

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(
          "Filtrar $titulo",
          style: TextStyle(color: diPertinRoxo, fontWeight: FontWeight.bold),
        ),
        content: SizedBox(
          width: 350,
          height: 150,
          child: cidades.isEmpty
              ? const Text("Nenhuma cidade encontrada.")
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text("Selecione a cidade para ver o ranking:"),
                    const SizedBox(height: 20),
                    DropdownMenu<String>(
                      width: 320,
                      menuHeight: 250,
                      enableFilter: true,
                      requestFocusOnTap: true,
                      label: const Text('Pesquisar...'),
                      leadingIcon: const Icon(Icons.search),
                      inputDecorationTheme: InputDecorationTheme(
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                      dropdownMenuEntries: cidades
                          .map(
                            (String c) =>
                                DropdownMenuEntry<String>(value: c, label: c),
                          )
                          .toList(),
                      onSelected: (String? selecionada) {
                        if (selecionada != null) {
                          Navigator.pop(context);
                          _mostrarRanking(selecionada, tipoBusca);
                        }
                      },
                    ),
                  ],
                ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text("Cancelar"),
          ),
        ],
      ),
    );
  }

  void _mostrarRanking(String cidade, String tipo) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text(
            "Ranking de ${tipo.toUpperCase()}S - $cidade",
            style: TextStyle(color: diPertinRoxo, fontWeight: FontWeight.bold),
          ),
          content: SizedBox(
            width: 800,
            height: 500,
            child: FutureBuilder<QuerySnapshot>(
              future: FirebaseFirestore.instance
                  .collection('users')
                  .where('role', isEqualTo: tipo)
                  .get(const GetOptions(source: Source.server)),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                  return const Center(
                    child: Text("Nenhum usuário cadastrado."),
                  );
                }

                List<QueryDocumentSnapshot> usuarios = snapshot.data!.docs
                    .where((doc) {
                      try {
                        Map<String, dynamic> dados =
                            doc.data() as Map<String, dynamic>;
                        String? nomeCid = dados['cidade'] ?? dados['Cidade'];
                        if (nomeCid != null) {
                          return nomeCid.trim().toLowerCase() ==
                              cidade.toLowerCase();
                        }
                      } catch (e) {}
                      return false;
                    })
                    .toList();

                if (usuarios.isEmpty) {
                  return const Center(
                    child: Text("Nenhum usuário encontrado nesta cidade."),
                  );
                }

                usuarios.sort((a, b) {
                  int sA = 0, sB = 0;
                  try {
                    sA = a.get('totalConcluido');
                  } catch (e) {}
                  try {
                    sB = b.get('totalConcluido');
                  } catch (e) {}
                  return sB.compareTo(sA);
                });

                List<QueryDocumentSnapshot> top10 = usuarios.take(10).toList();
                List<QueryDocumentSnapshot> piores = usuarios
                    .where((doc) {
                      int s = 0;
                      try {
                        s = doc.get('totalConcluido');
                      } catch (e) {}
                      return s == 0;
                    })
                    .take(5)
                    .toList();

                return Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Card(
                        color: Colors.green[50],
                        child: Padding(
                          padding: const EdgeInsets.all(16.0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                "🏆 Top 10 Concluídos",
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.green,
                                ),
                              ),
                              const Divider(),
                              Expanded(
                                child: ListView.builder(
                                  itemCount: top10.length,
                                  itemBuilder: (context, index) {
                                    String nome = 'Sem Nome';
                                    int atv = 0;
                                    try {
                                      nome = top10[index].get('nome');
                                    } catch (e) {}
                                    try {
                                      atv = top10[index].get('totalConcluido');
                                    } catch (e) {}
                                    return ListTile(
                                      leading: CircleAvatar(
                                        child: Text("${index + 1}"),
                                      ),
                                      title: Text(nome),
                                      subtitle: Text("Atividades: $atv"),
                                    );
                                  },
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 20),
                    Expanded(
                      child: Card(
                        color: Colors.red[50],
                        child: Padding(
                          padding: const EdgeInsets.all(16.0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                "⚠️ Top 5 Inativos",
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.red,
                                ),
                              ),
                              const Divider(),
                              Expanded(
                                child: ListView.builder(
                                  itemCount: piores.length,
                                  itemBuilder: (context, index) {
                                    String nome = 'Sem Nome';
                                    try {
                                      nome = piores[index].get('nome');
                                    } catch (e) {}
                                    return ListTile(
                                      leading: const Icon(
                                        Icons.warning,
                                        color: Colors.red,
                                      ),
                                      title: Text(nome),
                                      subtitle: const Text("Zero atividades"),
                                    );
                                  },
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                );
              },
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text("Fechar"),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: PainelAdminTheme.fundoCanvas,
      body: _isLoading
          ? Center(
              child: CircularProgressIndicator(
                color: diPertinRoxo,
                strokeWidth: 2.5,
              ),
            )
          : SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(40, 40, 40, 100),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                        Text(
                          'CENTRO DE COMANDO',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 2,
                            color: PainelAdminTheme.textoSecundario,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Painel SuperAdmin',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 32,
                            fontWeight: FontWeight.w800,
                            color: const Color(0xFF1E1B4B),
                            letterSpacing: -0.8,
                            height: 1.1,
                          ),
                        ),
                        const SizedBox(height: 10),
                        Text(
                          'Bem-vindo ao centro de comando do DiPertin.',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 16,
                            color: PainelAdminTheme.textoSecundario,
                            height: 1.5,
                          ),
                        ),
                        const SizedBox(height: 36),

                        // === SEÇÃO 1: AVISOS E PENDÊNCIAS ===
                        if (_lojasPendentes > 0 ||
                            _entregadoresPendentes > 0) ...[
                          Container(
                            padding: const EdgeInsets.all(22),
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                colors: [
                                  const Color(0xFFFFF7ED),
                                  const Color(0xFFFFEDD5),
                                ],
                              ),
                              borderRadius: BorderRadius.circular(18),
                              border: Border.all(
                                color: const Color(0xFFFDBA74).withOpacity(0.6),
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: diPertinLaranja.withOpacity(0.08),
                                  blurRadius: 20,
                                  offset: const Offset(0, 8),
                                ),
                              ],
                            ),
                            child: Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.all(12),
                                  decoration: BoxDecoration(
                                    color: Colors.white.withOpacity(0.85),
                                    borderRadius: BorderRadius.circular(14),
                                  ),
                                  child: Icon(
                                    Icons.notifications_active_rounded,
                                    color: diPertinLaranja,
                                    size: 32,
                                  ),
                                ),
                                const SizedBox(width: 20),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'Atenção requerida',
                                        style: GoogleFonts.plusJakartaSans(
                                          color: const Color(0xFFC2410C),
                                          fontWeight: FontWeight.w700,
                                          fontSize: 17,
                                        ),
                                      ),
                                      const SizedBox(height: 6),
                                      Text(
                                        'Existem aprovações pendentes aguardando sua análise para entrarem no aplicativo.',
                                        style: GoogleFonts.plusJakartaSans(
                                          color: const Color(0xFF9A3412),
                                          fontSize: 14,
                                          height: 1.45,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 15),
                          Row(
                            children: [
                              if (_lojasPendentes > 0)
                                _buildPendenciaCard(
                                  context,
                                  "Lojas Pendentes",
                                  _lojasPendentes,
                                  Icons.store,
                                  Colors.red,
                                  '/lojas',
                                ),
                              if (_lojasPendentes > 0 &&
                                  _entregadoresPendentes > 0)
                                const SizedBox(width: 20),
                              if (_entregadoresPendentes > 0)
                                _buildPendenciaCard(
                                  context,
                                  "Entregadores Pendentes",
                                  _entregadoresPendentes,
                                  Icons.motorcycle,
                                  Colors.red,
                                  '/entregadores',
                                ),
                            ],
                          ),
                          const SizedBox(height: 40),
                        ],

                        // === SEÇÃO 2: RANKINGS E DESEMPENHO ===
                        Text(
                          'Desempenho e rankings',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                            color: const Color(0xFF1E1B4B),
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          'Visão consolidada de usuários por perfil.',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 13,
                            color: PainelAdminTheme.textoSecundario,
                          ),
                        ),
                        const SizedBox(height: 20),
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            _cardContadorRanking(
                              'Total Usuários',
                              null,
                              const Color(0xFF3B82F6),
                            ),
                            const SizedBox(width: 18),
                            _cardContadorRanking(
                              'Clientes',
                              'cliente',
                              const Color(0xFF10B981),
                            ),
                            const SizedBox(width: 18),
                            _cardContadorRanking(
                              'Lojistas',
                              'lojista',
                              diPertinLaranja,
                            ),
                            const SizedBox(width: 18),
                            _cardContadorRanking(
                              'Entregadores',
                              'entregador',
                              const Color(0xFFEF4444),
                            ),
                          ],
                        ),
                        const SizedBox(height: 44),

                        // === SEÇÃO 3: VISÃO FINANCEIRA ===
                        Text(
                          'Módulo financeiro',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                            color: const Color(0xFF1E1B4B),
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          'Receitas e movimentações do ecossistema.',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 13,
                            color: PainelAdminTheme.textoSecundario,
                          ),
                        ),
                        const SizedBox(height: 18),
                        Material(
                          color: Colors.transparent,
                          child: InkWell(
                            onTap: () => context.navegarPainel('/financeiro'),
                            borderRadius: BorderRadius.circular(18),
                            child: Ink(
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(18),
                                gradient: const LinearGradient(
                                  begin: Alignment.topLeft,
                                  end: Alignment.bottomRight,
                                  colors: [
                                    Color(0xFFECFDF5),
                                    Color(0xFFD1FAE5),
                                  ],
                                ),
                                border: Border.all(
                                  color: const Color(0xFF6EE7B7).withOpacity(0.65),
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: const Color(0xFF10B981).withOpacity(0.12),
                                    blurRadius: 24,
                                    offset: const Offset(0, 10),
                                  ),
                                ],
                              ),
                              child: Padding(
                                padding: const EdgeInsets.all(24),
                                child: Row(
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.all(14),
                                      decoration: BoxDecoration(
                                        color: Colors.white.withOpacity(0.9),
                                        borderRadius: BorderRadius.circular(16),
                                        boxShadow: [
                                          BoxShadow(
                                            color: const Color(0xFF10B981)
                                                .withOpacity(0.15),
                                            blurRadius: 12,
                                            offset: const Offset(0, 4),
                                          ),
                                        ],
                                      ),
                                      child: const Icon(
                                        Icons.account_balance_rounded,
                                        color: Color(0xFF059669),
                                        size: 32,
                                      ),
                                    ),
                                    const SizedBox(width: 22),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            'Visão financeira',
                                            style: GoogleFonts.plusJakartaSans(
                                              fontWeight: FontWeight.w800,
                                              fontSize: 18,
                                              color: const Color(0xFF047857),
                                            ),
                                          ),
                                          const SizedBox(height: 8),
                                          Text(
                                            'Gerencie receitas de destaques, vitrine, telefones premium e assinaturas.',
                                            style: GoogleFonts.plusJakartaSans(
                                              color: const Color(0xFF065F46),
                                              fontSize: 14,
                                              height: 1.5,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    Container(
                                      padding: const EdgeInsets.all(10),
                                      decoration: BoxDecoration(
                                        color: Colors.white.withOpacity(0.7),
                                        shape: BoxShape.circle,
                                      ),
                                      child: const Icon(
                                        Icons.arrow_forward_rounded,
                                        color: Color(0xFF059669),
                                        size: 22,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 50),
                      ],
                    ),
            ),
      floatingActionButton: const BotaoSuporteFlutuante(),
    );
  }
}
