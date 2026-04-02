// Arquivo: lib/screens/cliente/product_details_screen.dart

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../providers/cart_provider.dart';
import '../../models/cart_item_model.dart';
import 'cart_screen.dart';
import 'loja_perfil_screen.dart';

const Color diPertinRoxo = Color(0xFF6A1B9A);
const Color diPertinLaranja = Color(0xFFFF8F00);

class ProductDetailsScreen extends StatefulWidget {
  final Map<String, dynamic> produto;

  const ProductDetailsScreen({super.key, required this.produto});

  @override
  State<ProductDetailsScreen> createState() => _ProductDetailsScreenState();
}

class _ProductDetailsScreenState extends State<ProductDetailsScreen> {
  Map<String, dynamic>? _dadosLojista;

  final NumberFormat _fmtMoeda = NumberFormat.currency(
    locale: 'pt_BR',
    symbol: r'R$',
    decimalDigits: 2,
  );

  @override
  void initState() {
    super.initState();
    _carregarDadosLojista();
  }

  Future<void> _carregarDadosLojista() async {
    String? lojistaId = widget.produto['lojista_id'] ?? widget.produto['loja_id'];
    if (lojistaId != null) {
      try {
        DocumentSnapshot doc = await FirebaseFirestore.instance
            .collection('users')
            .doc(lojistaId)
            .get();
        if (doc.exists && mounted) {
          setState(() {
            _dadosLojista = doc.data() as Map<String, dynamic>;
          });
        }
      } catch (e) {
        debugPrint("Erro ao carregar dados da loja: $e");
      }
    }
  }

  void _adicionarAoCarrinho(CartProvider cart) {
    if (widget.produto['loja_aberta'] == false) return;

    final productItem = CartItemModel(
      id: widget.produto['id_documento'] ?? '',
      nome: widget.produto['nome'] ?? 'Produto',
      preco:
          ((widget.produto['oferta'] ?? widget.produto['preco'] ?? 0.0) as num)
              .toDouble(),
      imagem:
          (widget.produto['imagens'] != null &&
              widget.produto['imagens'].isNotEmpty)
          ? widget.produto['imagens'][0]
          : widget.produto['imagem'] ?? '',
      lojaId: widget.produto['lojista_id'] ?? widget.produto['loja_id'] ?? '',
      lojaNome: widget.produto['loja_nome_vitrine'] ?? 'Loja Parceira',
    );

    cart.addItem(productItem);

    // === AJUSTE 1: MSG RÁPIDA (800ms) QUE NÃO ATRAPALHA O USUÁRIO ===
    ScaffoldMessenger.of(
      context,
    ).clearSnackBars(); // Limpa as anteriores para não acumular
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('${productItem.nome} adicionado à sacola!'),
        backgroundColor: Colors.green,
        duration: const Duration(milliseconds: 800), // Rápido, como no iFood
      ),
    );
  }

  // === AJUSTE 2: FUNÇÃO PARA MOSTRAR A FOTO COM ZOOM (INTERACTIVE VIEW) ===
  void _mostrarImagemFullScreen(String urlImagem) {
    showDialog(
      context: context,
      builder: (context) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: EdgeInsets.zero, // Tela cheia
        child: Stack(
          alignment: Alignment.center,
          children: [
            // InteractiveViewer permite dar pinça (zoom) e arrastar
            InteractiveViewer(
              panEnabled: true,
              minScale: 0.5,
              maxScale: 4.0,
              child: Image.network(
                urlImagem,
                fit: BoxFit.contain, // Garante que a foto toda apareça
                width: double.infinity,
                height: double.infinity,
              ),
            ),
            // Botão de fechar elegante no topo
            Positioned(
              top: MediaQuery.of(context).padding.top + 8,
              right: 16,
              child: IconButton(
                icon: const Icon(Icons.close, color: Colors.white, size: 30),
                onPressed: () => Navigator.pop(context),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    List<String> imagens = [];
    if (widget.produto['imagens'] != null &&
        widget.produto['imagens'] is List) {
      imagens = List<String>.from(widget.produto['imagens']);
    } else if (widget.produto['imagem'] != null &&
        widget.produto['imagem'].toString().isNotEmpty) {
      imagens = [widget.produto['imagem'].toString()];
    }

    bool lojaAberta = widget.produto['loja_aberta'] ?? true;
    final precoExibir =
        ((widget.produto['oferta'] ?? widget.produto['preco'] ?? 0.0) as num)
            .toDouble();
    final navBottom = MediaQuery.viewPaddingOf(context).bottom;

    return Scaffold(
      backgroundColor: const Color(0xFFF8F7FA),
      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            expandedHeight: 300,
            pinned: true,
            backgroundColor: diPertinRoxo,
            iconTheme: const IconThemeData(color: Colors.white),
            actions: [
              Stack(
                alignment: Alignment.center,
                children: [
                  IconButton(
                    icon: const Icon(Icons.shopping_cart, color: Colors.white),
                    onPressed: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const CartScreen(),
                      ),
                    ),
                  ),
                  Positioned(
                    right: 8,
                    top: 8,
                    child: Container(
                      padding: const EdgeInsets.all(2),
                      decoration: BoxDecoration(
                        color: diPertinLaranja,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      constraints: const BoxConstraints(
                        minWidth: 16,
                        minHeight: 16,
                      ),
                      child: Text(
                        context.watch<CartProvider>().itemCount.toString(),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(width: 10),
            ],
            flexibleSpace: FlexibleSpaceBar(
              background: imagens.isNotEmpty
                  ? PageView.builder(
                      itemCount: imagens.length,
                      itemBuilder: (context, index) {
                        // === AJUSTE 3: TORNA A FOTO CLICÁVEL PARA ZOOM ===
                        return GestureDetector(
                          onTap: () => _mostrarImagemFullScreen(imagens[index]),
                          child: Image.network(
                            imagens[index],
                            fit: BoxFit.cover,
                          ),
                        );
                      },
                    )
                  : Container(
                      color: Colors.grey[200],
                      child: const Icon(
                        Icons.image_not_supported,
                        size: 80,
                        color: Colors.grey,
                      ),
                    ),
            ),
          ),

          SliverList(
            delegate: SliverChildListDelegate([
              Padding(
                padding: EdgeInsets.fromLTRB(16, 20, 16, 24 + navBottom + 88),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.produto['nome'] ?? 'Produto sem nome',
                      style: const TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.4,
                        height: 1.2,
                        color: Color(0xFF1A1A2E),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      _fmtMoeda.format(precoExibir),
                      style: const TextStyle(
                        fontSize: 26,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.5,
                        color: diPertinLaranja,
                      ),
                    ),
                    const SizedBox(height: 18),
                    _buildInfoEncomendaEstoque(widget.produto),
                    const SizedBox(height: 20),
                    _cardSecao(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _buildLinkParaLoja(widget.produto, lojaAberta),
                          const SizedBox(height: 18),
                          _buildComentariosAvaliacoes(),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    _cardSecao(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Descrição',
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                              color: diPertinRoxo,
                              letterSpacing: -0.2,
                            ),
                          ),
                          const SizedBox(height: 10),
                          Text(
                            widget.produto['descricao'] ??
                                'Sem descrição disponível.',
                            style: TextStyle(
                              fontSize: 15,
                              color: Colors.grey.shade700,
                              height: 1.55,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ]),
          ),
        ],
      ),
      bottomNavigationBar: _buildBotaoFixoCarrinho(context, lojaAberta),
    );
  }

  Widget _cardSecao({required Widget child}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE8E6ED)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: child,
    );
  }

  // WIDGET HELPER: INFO DE ENCOMENDA OU ESTOQUE (TURBINADO)
  Widget _buildInfoEncomendaEstoque(Map<String, dynamic> prod) {
    // Usando os campos reais que você informou
    String tipoVenda =
        prod['tipo_venda'] ?? 'estoque'; // 'estoque' ou 'encomenda'
    int estoqueQtd = (prod['estoque_qtd'] ?? 0);
    String prazoEncomenda = prod['prazo_encomenda'] ?? '';

    if (tipoVenda == 'encomenda') {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: diPertinLaranja.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: diPertinLaranja.withValues(alpha: 0.45),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.inventory_2_rounded, color: diPertinLaranja, size: 22),
            const SizedBox(width: 10),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Produto sob encomenda',
                  style: TextStyle(
                    color: diPertinLaranja,
                    fontWeight: FontWeight.w800,
                    fontSize: 13,
                    letterSpacing: -0.2,
                  ),
                ),
                if (prazoEncomenda.isNotEmpty)
                  Text(
                    "Prazo de entrega: $prazoEncomenda",
                    style: const TextStyle(color: Colors.black87, fontSize: 11),
                  ),
              ],
            ),
          ],
        ),
      );
    } else {
      // É venda por estoque
      if (estoqueQtd > 0) {
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: Colors.green.shade50,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: Colors.green.shade200),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.check_circle_rounded,
                color: Colors.green.shade700,
                size: 16,
              ),
              const SizedBox(width: 6),
              Flexible(
                child: Text(
                  '$estoqueQtd unidades em estoque',
                  style: TextStyle(
                    color: Colors.green.shade800,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    height: 1.2,
                  ),
                ),
              ),
            ],
          ),
        );
      } else {
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: Colors.red.shade50,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: Colors.red.shade200),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.remove_shopping_cart_rounded,
                color: Colors.red.shade700,
                size: 16,
              ),
              const SizedBox(width: 6),
              Flexible(
                child: Text(
                  'Sem estoque no momento',
                  style: TextStyle(
                    color: Colors.red.shade800,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    height: 1.2,
                  ),
                ),
              ),
            ],
          ),
        );
      }
    }
  }

  Widget _buildLinkParaLoja(Map<String, dynamic> prod, bool aberta) {
    String nomeLoja = prod['loja_nome_vitrine'] ?? "Loja Parceira";

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Vendido por',
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: Colors.grey.shade600,
            letterSpacing: 0.2,
          ),
        ),
        const SizedBox(height: 8),
        GestureDetector(
          onTap: () {
            String? lid = widget.produto['lojista_id'] ?? widget.produto['loja_id'];
            if (_dadosLojista != null && lid != null) {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => LojaPerfilScreen(
                    lojistaData: _dadosLojista!,
                    lojistaId: lid,
                  ),
                ),
              );
            }
          },
          child: Row(
            children: [
              Flexible(
                child: Text(
                  nomeLoja,
                  style: const TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
                    color: diPertinRoxo,
                    letterSpacing: -0.2,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              if (!aberta)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 6,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.red[50],
                    borderRadius: BorderRadius.circular(5),
                  ),
                  child: const Text(
                    "FECHADA",
                    style: TextStyle(
                      color: Colors.red,
                      fontSize: 9,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildComentariosAvaliacoes() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Avaliações da loja',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: Colors.grey.shade700,
              ),
            ),
            Row(
              children: [
                Icon(Icons.star, color: Colors.amber, size: 18),
                SizedBox(width: 5),
                // Nível geral da LOJA (puxar do banco futuramente)
                const Text(
                  "4.8",
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                ),
                const Text(
                  " (23)",
                  style: TextStyle(color: Colors.grey, fontSize: 12),
                ),
              ],
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildBotaoFixoCarrinho(BuildContext context, bool aberta) {
    final cart = context.read<CartProvider>();
    final bottomInset = MediaQuery.viewPaddingOf(context).bottom;

    return Material(
      elevation: 12,
      shadowColor: Colors.black.withValues(alpha: 0.12),
      color: Colors.white,
      child: Padding(
        padding: EdgeInsets.fromLTRB(16, 12, 16, 12 + bottomInset),
        child: SizedBox(
          width: double.infinity,
          height: 52,
          child: FilledButton(
            onPressed: aberta ? () => _adicionarAoCarrinho(cart) : null,
            style: FilledButton.styleFrom(
              backgroundColor: aberta ? diPertinLaranja : Colors.red.shade400,
              disabledBackgroundColor: Colors.red.shade300,
              foregroundColor: Colors.white,
              elevation: aberta ? 2 : 0,
              shadowColor: diPertinLaranja.withValues(alpha: 0.4),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
            ),
            child: Text(
              aberta
                  ? 'Adicionar à sacola'
                  : 'Loja fechada — não aceitando pedidos',
              style: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w800,
                letterSpacing: 0.2,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
