// Arquivo: lib/screens/cliente/cart_screen.dart

import 'package:depertin_cliente/screens/auth/login_screen.dart';
import 'checkout_pagamento_screen.dart'; // NOVO IMPORT DA NOSSA TELA DE PAGAMENTO!
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'dart:math' show Random, max, min;
import '../../providers/cart_provider.dart';
import '../../models/cart_item_model.dart';

const Color diPertinRoxo = Color(0xFF6A1B9A);
const Color diPertinLaranja = Color(0xFFFF8F00);

class CartScreen extends StatefulWidget {
  const CartScreen({super.key});

  @override
  State<CartScreen> createState() => _CartScreenState();
}

class _CartScreenState extends State<CartScreen> {
  final TextEditingController _enderecoController = TextEditingController();
  String _formaPagamento = 'PIX';
  bool _processandoPedido = false;
  bool _retirarNaLoja = false;

  // Variáveis para o saldo
  double _saldoCliente = 0.0;
  bool _usarSaldo = false;

  final double _taxaBase = 5.00;

  double get _taxaEntregaReal => _retirarNaLoja ? 0.0 : _taxaBase;

  @override
  void initState() {
    super.initState();
    _carregarDadosCliente();
  }

  Future<void> _carregarDadosCliente() async {
    User? user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      try {
        var doc = await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .get();
        if (doc.exists) {
          var dados = doc.data() as Map<String, dynamic>;
          setState(() {
            _saldoCliente = (dados['saldo'] ?? 0.0).toDouble();

            if (dados.containsKey('endereco_entrega_padrao') &&
                dados['endereco_entrega_padrao'] is Map) {
              var end = dados['endereco_entrega_padrao'];
              String rua = end['rua'] ?? '';
              String num = end['numero'] ?? '';
              String bairro = end['bairro'] ?? '';
              String cidade = end['cidade'] ?? '';
              String compl = end['complemento'] ?? '';

              String enderecoMontado = "$rua, $num, $bairro, $cidade";
              if (compl.isNotEmpty) enderecoMontado += " - $compl";

              _enderecoController.text = enderecoMontado;
            } else if (dados['endereco'] != null &&
                dados['endereco'].toString().isNotEmpty) {
              _enderecoController.text = dados['endereco'].toString();
            }
          });
        }
      } catch (e) {
        debugPrint("Erro ao carregar dados: $e");
      }
    }
  }

  // === NOVA FUNÇÃO: DECIDE SE VAI PARA O CHECKOUT OU SALVA DIRETO ===
  Future<void> _avancarParaPagamento(CartProvider cart) async {
    User? user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Você precisa fazer login para finalizar o pedido!'),
          backgroundColor: diPertinRoxo,
        ),
      );
      Navigator.push(
        context,
        MaterialPageRoute(builder: (context) => const LoginScreen()),
      );
      return;
    }

    if (!_retirarNaLoja && _enderecoController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Por favor, informe o endereço de entrega!'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    double subtotal = cart.totalAmount;
    double totalParcial = subtotal + _taxaEntregaReal;
    double valorDesconto = _usarSaldo ? min(_saldoCliente, totalParcial) : 0.0;
    double totalFinal = totalParcial - valorDesconto;

    // Se for Dinheiro ou Saldo Total, pula a tela do Mercado Pago!
    if (totalFinal <= 0 || _formaPagamento == 'Dinheiro') {
      await _salvarPedidoNoBanco(
        cart,
        user.uid,
        subtotal,
        valorDesconto,
        totalFinal,
      );
    } else {
      // Abre a nova tela de Pagamento Seguro!
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => CheckoutPagamentoScreen(
            valorTotal: totalFinal,
            metodoPreSelecionado: _formaPagamento,
            onPagamentoAprovado: () {
              Navigator.pop(context); // Fecha a tela de Checkout após aprovar
              _salvarPedidoNoBanco(
                cart,
                user.uid,
                subtotal,
                valorDesconto,
                totalFinal,
              ); // Salva o pedido!
            },
          ),
        ),
      );
    }
  }

  // === ANTIGA FUNÇÃO DE FINALIZAR PEDIDO (AGORA APENAS SALVA NO BANCO) ===
  Future<void> _salvarPedidoNoBanco(
    CartProvider cart,
    String clienteId,
    double subtotal,
    double valorDesconto,
    double totalFinal,
  ) async {
    setState(() => _processandoPedido = true);

    try {
      List<CartItemModel> listaItens = cart.items;
      List<Map<String, dynamic>> itensParaSalvar = listaItens.map((item) {
        return {
          'id_produto': item.id,
          'nome': item.nome,
          'preco': item.preco,
          'quantidade': item.quantidade,
          'imagem': item.imagem,
        };
      }).toList();

      String lojaId = listaItens.isNotEmpty ? listaItens.first.lojaId : '';
      String lojaNome = listaItens.isNotEmpty ? listaItens.first.lojaNome : '';

      String enderecoDaLoja = 'Endereço não cadastrado';
      if (lojaId.isNotEmpty) {
        var lojaDoc = await FirebaseFirestore.instance
            .collection('users')
            .doc(lojaId)
            .get();
        if (lojaDoc.exists) {
          enderecoDaLoja =
              lojaDoc.data()?['endereco']?.toString() ??
              'Endereço não cadastrado';
        }
      }

      String tokenGerado = (Random().nextInt(900000 + 100000).toString());

      if (!_retirarNaLoja) {
        await FirebaseFirestore.instance.collection('users').doc(clienteId).set(
          {'endereco': _enderecoController.text.trim()},
          SetOptions(merge: true),
        );
      }

      // Salva o Pedido
      await FirebaseFirestore.instance.collection('pedidos').add({
        'cliente_id': clienteId,
        'loja_id': lojaId,
        'loja_nome': lojaNome,
        'loja_endereco': enderecoDaLoja,
        'token_entrega': tokenGerado,
        'itens': itensParaSalvar,
        'subtotal': subtotal,
        'taxa_entrega': _taxaEntregaReal,
        'desconto_saldo': valorDesconto,
        'total': totalFinal,
        'tipo_entrega': _retirarNaLoja ? 'retirada' : 'entrega',
        'endereco_entrega': _retirarNaLoja
            ? 'Retirada no Balcão'
            : _enderecoController.text.trim(),
        'forma_pagamento': totalFinal == 0.0 ? 'Saldo do App' : _formaPagamento,
        'status': 'pendente',
        'data_pedido': FieldValue.serverTimestamp(),
      });

      // Deduz o saldo do cliente
      if (valorDesconto > 0) {
        await FirebaseFirestore.instance
            .collection('users')
            .doc(clienteId)
            .update({'saldo': FieldValue.increment(-valorDesconto)});
      }

      cart.clearCart();

      if (mounted) {
        Navigator.pop(context); // Fecha o Carrinho
        _mostrarSucesso();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Erro ao salvar pedido: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _processandoPedido = false);
    }
  }

  void _mostrarSucesso() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.check_circle, color: Colors.green, size: 80),
            const SizedBox(height: 20),
            const Text(
              "Pedido Confirmado!",
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.bold,
                color: diPertinRoxo,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              _retirarNaLoja
                  ? "A loja já recebeu o seu pedido. Aguarde a confirmação para ir buscar!"
                  : "A loja já recebeu o seu pedido. Acompanhe a entrega pelo app!",
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.grey),
            ),
            const SizedBox(height: 20),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: diPertinLaranja,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              onPressed: () => Navigator.pop(context),
              child: const Text(
                "Entendi",
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  static const double _alturaBarraCheckout = 56;
  /// Padding vertical do `bottomSheet` (14 acima + 14 abaixo do botão).
  static const double _paddingVerticalFaixaCheckout = 28;
  /// Espaço extra entre o card do total e a faixa laranja ao rolar até o fim.
  static const double _folgaEntreConteudoEBarra = 36;

  @override
  Widget build(BuildContext context) {
    final cart = context.watch<CartProvider>();
    bool carrinhoVazio = cart.items.isEmpty;
    final mq = MediaQuery.of(context);
    final bottomPad = max(mq.padding.bottom, mq.viewPadding.bottom);
    final scrollBottomPad = _folgaEntreConteudoEBarra +
        _paddingVerticalFaixaCheckout +
        _alturaBarraCheckout +
        bottomPad;

    double subtotal = cart.totalAmount;
    double totalParcial = subtotal + _taxaEntregaReal;
    double valorDesconto = _usarSaldo ? min(_saldoCliente, totalParcial) : 0.0;
    double totalFinal = totalParcial - valorDesconto;

    return Scaffold(
      backgroundColor: const Color(0xFFF3F4F6),
      appBar: AppBar(
        title: const Text(
          "Meu Carrinho",
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        backgroundColor: diPertinRoxo,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: carrinhoVazio
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.remove_shopping_cart,
                    size: 80,
                    color: Colors.grey[400],
                  ),
                  const SizedBox(height: 20),
                  const Text(
                    "Sua sacola está vazia",
                    style: TextStyle(fontSize: 20, color: Colors.grey),
                  ),
                  const SizedBox(height: 20),
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: diPertinLaranja,
                    ),
                    onPressed: () => Navigator.pop(context),
                    child: const Text(
                      "Voltar às Compras",
                      style: TextStyle(color: Colors.white),
                    ),
                  ),
                ],
              ),
            )
          : SingleChildScrollView(
              padding: EdgeInsets.fromLTRB(20, 20, 20, scrollBottomPad),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.06),
                          blurRadius: 12,
                          offset: const Offset(0, 4),
                        ),
                      ],
                      border: Border.all(color: diPertinRoxo.withOpacity(0.12)),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: GestureDetector(
                            onTap: () => setState(() => _retirarNaLoja = false),
                            child: Container(
                              padding: const EdgeInsets.symmetric(vertical: 15),
                              decoration: BoxDecoration(
                                color: !_retirarNaLoja
                                    ? diPertinRoxo
                                    : Colors.transparent,
                                borderRadius: const BorderRadius.horizontal(
                                  left: Radius.circular(14),
                                ),
                              ),
                              child: Column(
                                children: [
                                  Icon(
                                    Icons.two_wheeler,
                                    color: !_retirarNaLoja
                                        ? Colors.white
                                        : Colors.grey,
                                  ),
                                  const SizedBox(height: 5),
                                  Text(
                                    "Entregar",
                                    style: TextStyle(
                                      color: !_retirarNaLoja
                                          ? Colors.white
                                          : Colors.grey,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                        Expanded(
                          child: GestureDetector(
                            onTap: () => setState(() => _retirarNaLoja = true),
                            child: Container(
                              padding: const EdgeInsets.symmetric(vertical: 15),
                              decoration: BoxDecoration(
                                color: _retirarNaLoja
                                    ? diPertinLaranja
                                    : Colors.transparent,
                                borderRadius: const BorderRadius.horizontal(
                                  right: Radius.circular(14),
                                ),
                              ),
                              child: Column(
                                children: [
                                  Icon(
                                    Icons.storefront,
                                    color: _retirarNaLoja
                                        ? Colors.white
                                        : Colors.grey,
                                  ),
                                  const SizedBox(height: 5),
                                  Text(
                                    "Retirar na Loja",
                                    style: TextStyle(
                                      color: _retirarNaLoja
                                          ? Colors.white
                                          : Colors.grey,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 28),

                  Text(
                    "Itens do pedido",
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: Colors.grey[900],
                      letterSpacing: -0.3,
                    ),
                  ),
                  const SizedBox(height: 12),

                  Container(
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.05),
                          blurRadius: 10,
                          offset: const Offset(0, 2),
                        ),
                      ],
                      border: Border.all(color: Colors.grey.shade200),
                    ),
                    child: ListView.separated(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: cart.items.length,
                      separatorBuilder: (context, index) =>
                          const Divider(height: 1),
                      itemBuilder: (context, index) {
                        var item = cart.items[index];
                        return Padding(
                          padding: const EdgeInsets.all(12.0),
                          child: Row(
                            children: [
                              ClipRRect(
                                borderRadius: BorderRadius.circular(8),
                                child: Image.network(
                                  item.imagem.isNotEmpty
                                      ? item.imagem
                                      : 'https://via.placeholder.com/50',
                                  width: 60,
                                  height: 60,
                                  fit: BoxFit.cover,
                                  errorBuilder: (c, e, s) => Container(
                                    width: 60,
                                    height: 60,
                                    color: Colors.grey[300],
                                    child: const Icon(
                                      Icons.fastfood,
                                      color: Colors.grey,
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 15),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      item.nome,
                                      style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 14,
                                      ),
                                      maxLines: 2,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    const SizedBox(height: 5),
                                    Text(
                                      "R\$ ${(item.preco * item.quantidade).toStringAsFixed(2)}",
                                      style: const TextStyle(
                                        color: diPertinLaranja,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 10),
                              Container(
                                decoration: BoxDecoration(
                                  border: Border.all(color: Colors.grey[300]!),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Row(
                                  children: [
                                    InkWell(
                                      onTap: () =>
                                          cart.decrementarQuantidade(item.id),
                                      child: const Padding(
                                        padding: EdgeInsets.symmetric(
                                          horizontal: 10,
                                          vertical: 8,
                                        ),
                                        child: Icon(
                                          Icons.remove,
                                          size: 16,
                                          color: diPertinRoxo,
                                        ),
                                      ),
                                    ),
                                    Text(
                                      '${item.quantidade}',
                                      style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 14,
                                      ),
                                    ),
                                    InkWell(
                                      onTap: () =>
                                          cart.incrementarQuantidade(item.id),
                                      child: const Padding(
                                        padding: EdgeInsets.symmetric(
                                          horizontal: 10,
                                          vertical: 8,
                                        ),
                                        child: Icon(
                                          Icons.add,
                                          size: 16,
                                          color: diPertinRoxo,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                  ),
                  const SizedBox(height: 28),

                  if (!_retirarNaLoja) ...[
                    Text(
                      "Onde devemos entregar?",
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: Colors.grey[900],
                        letterSpacing: -0.3,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Container(
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.05),
                            blurRadius: 10,
                            offset: const Offset(0, 2),
                          ),
                        ],
                        border: Border.all(color: Colors.grey.shade200),
                      ),
                      padding: const EdgeInsets.fromLTRB(16, 16, 16, 14),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Container(
                                padding: const EdgeInsets.all(10),
                                decoration: BoxDecoration(
                                  color: diPertinLaranja.withValues(alpha: 0.12),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: const Icon(
                                  Icons.location_on_rounded,
                                  color: diPertinLaranja,
                                  size: 22,
                                ),
                              ),
                              const SizedBox(width: 14),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      'Endereço completo',
                                      style: TextStyle(
                                        fontWeight: FontWeight.w700,
                                        fontSize: 15,
                                        color: Colors.grey[900],
                                        letterSpacing: -0.2,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      'Inclua rua, número, bairro e cidade. '
                                      'Ponto de referência ajuda na entrega.',
                                      style: TextStyle(
                                        fontSize: 12.5,
                                        height: 1.35,
                                        color: Colors.grey[600],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          TextField(
                            controller: _enderecoController,
                            keyboardType: TextInputType.streetAddress,
                            textCapitalization: TextCapitalization.sentences,
                            minLines: 2,
                            maxLines: 4,
                            style: TextStyle(
                              fontSize: 15,
                              height: 1.4,
                              color: Colors.grey[900],
                            ),
                            decoration: InputDecoration(
                              isDense: true,
                              alignLabelWithHint: true,
                              hintText:
                                  'Ex.: Rua das Flores, 120, Centro, Toledo — apto 302',
                              hintStyle: TextStyle(
                                fontSize: 14,
                                color: Colors.grey[400],
                                height: 1.4,
                              ),
                              filled: true,
                              fillColor: const Color(0xFFF8F9FA),
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 14,
                                vertical: 14,
                              ),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: BorderSide(color: Colors.grey.shade300),
                              ),
                              enabledBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: BorderSide(color: Colors.grey.shade300),
                              ),
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(12),
                                borderSide: const BorderSide(
                                  color: diPertinRoxo,
                                  width: 1.5,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 12),
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Icon(
                                Icons.info_outline_rounded,
                                size: 18,
                                color: Colors.grey[500],
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  'Alterações aqui valem para este pedido. '
                                  'Para definir o endereço padrão da conta, '
                                  'use a tela inicial do app.',
                                  style: TextStyle(
                                    fontSize: 12,
                                    height: 1.35,
                                    color: Colors.grey[600],
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 28),
                  ],

                  if (_saldoCliente > 0) ...[
                    Container(
                      decoration: BoxDecoration(
                        color: Colors.green[50],
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: Colors.green[200]!),
                      ),
                      child: CheckboxListTile(
                        activeColor: Colors.green,
                        title: const Text(
                          "Usar Saldo da Carteira",
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Colors.green,
                          ),
                        ),
                        subtitle: Text(
                          "Você tem R\$ ${_saldoCliente.toStringAsFixed(2)} disponíveis.",
                        ),
                        value: _usarSaldo,
                        onChanged: (val) =>
                            setState(() => _usarSaldo = val ?? false),
                      ),
                    ),
                    const SizedBox(height: 28),
                  ],

                  if (totalFinal > 0) ...[
                    Text(
                      "Como quer pagar o restante?",
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: Colors.grey[900],
                        letterSpacing: -0.3,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Container(
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.05),
                            blurRadius: 10,
                            offset: const Offset(0, 2),
                          ),
                        ],
                        border: Border.all(color: Colors.grey.shade200),
                      ),
                      child: Column(
                        children: [
                          RadioListTile(
                            title: const Text("PIX (Pelo App)"),
                            activeColor: diPertinRoxo,
                            value: 'PIX',
                            groupValue: _formaPagamento,
                            onChanged: (val) => setState(
                              () => _formaPagamento = val.toString(),
                            ),
                          ),
                          RadioListTile(
                            title: const Text("Cartão de Crédito"),
                            activeColor: diPertinRoxo,
                            value: 'Cartão',
                            groupValue: _formaPagamento,
                            onChanged: (val) => setState(
                              () => _formaPagamento = val.toString(),
                            ),
                          ),
                          RadioListTile(
                            title: const Text("Dinheiro na Entrega"),
                            activeColor: diPertinRoxo,
                            value: 'Dinheiro',
                            groupValue: _formaPagamento,
                            onChanged: (val) => setState(
                              () => _formaPagamento = val.toString(),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 28),
                  ],

                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 18,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: diPertinRoxo.withOpacity(0.08),
                          blurRadius: 14,
                          offset: const Offset(0, 4),
                        ),
                      ],
                      border: Border.all(color: diPertinRoxo.withOpacity(0.15)),
                    ),
                    child: Column(
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text(
                              "Subtotal",
                              style: TextStyle(color: Colors.grey),
                            ),
                            Text(
                              "R\$ ${subtotal.toStringAsFixed(2)}",
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 10),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              _retirarNaLoja
                                  ? "Taxa (Retirada)"
                                  : "Taxa de Entrega",
                              style: const TextStyle(color: Colors.grey),
                            ),
                            Text(
                              "R\$ ${_taxaEntregaReal.toStringAsFixed(2)}",
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                color: _retirarNaLoja
                                    ? Colors.green
                                    : Colors.black87,
                              ),
                            ),
                          ],
                        ),
                        if (_usarSaldo && valorDesconto > 0) ...[
                          const SizedBox(height: 10),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text(
                                "Desconto (Saldo)",
                                style: TextStyle(color: Colors.green),
                              ),
                              Text(
                                "- R\$ ${valorDesconto.toStringAsFixed(2)}",
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  color: Colors.green,
                                ),
                              ),
                            ],
                          ),
                        ],
                        Divider(height: 28, color: Colors.grey.shade200),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text(
                              "TOTAL",
                              style: TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                                color: diPertinRoxo,
                              ),
                            ),
                            Text(
                              "R\$ ${totalFinal.toStringAsFixed(2)}",
                              style: const TextStyle(
                                fontSize: 22,
                                fontWeight: FontWeight.bold,
                                color: diPertinLaranja,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
      bottomSheet: carrinhoVazio
          ? null
          : Material(
              elevation: 12,
              color: Colors.white,
              shadowColor: Colors.black26,
              child: Padding(
                padding: EdgeInsets.fromLTRB(20, 14, 20, 14 + bottomPad),
                child: SizedBox(
                  width: double.infinity,
                  height: _alturaBarraCheckout,
                  child: ElevatedButton(
                    onPressed: _processandoPedido
                        ? null
                        : () => _avancarParaPagamento(cart),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: diPertinLaranja,
                      elevation: 0,
                      shadowColor: Colors.transparent,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    child: _processandoPedido
                        ? const SizedBox(
                            height: 24,
                            width: 24,
                            child: CircularProgressIndicator(
                              color: Colors.white,
                              strokeWidth: 2.5,
                            ),
                          )
                        : const Text(
                            "FINALIZAR PEDIDO",
                            style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 0.6,
                              color: Colors.white,
                            ),
                          ),
                  ),
                ),
              ),
            ),
    );
  }
}
