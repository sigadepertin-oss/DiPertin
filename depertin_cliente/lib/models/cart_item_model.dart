// Arquivo: lib/models/cart_item_model.dart

class CartItemModel {
  final String id;
  final String nome;
  final double preco;
  final String lojaId;
  final String lojaNome;
  final String imagem;
  int quantidade;

  /// Marca produtos que NÃO cabem em moto/bike (volumosos, frágeis grandes,
  /// cargas maiores). Se qualquer item do grupo de uma loja estiver marcado,
  /// o frete dessa loja é calculado pela tabela "carro". Caso contrário,
  /// usa sempre a tabela "padrão" (moto/bike).
  final bool requerVeiculoGrande;

  CartItemModel({
    required this.id,
    required this.nome,
    required this.preco,
    required this.lojaId,
    required this.lojaNome,
    required this.imagem,
    this.quantidade = 1,
    this.requerVeiculoGrande = false,
  });

  Map<String, dynamic> toJson() {
    // Proteção contra hot-reload: instâncias antigas podem não ter o slot
    // de `requerVeiculoGrande` e acessá-lo lança TypeError. Se falhar,
    // assume padrão (moto/bike).
    bool veiculoGrande = false;
    try {
      veiculoGrande = requerVeiculoGrande;
    } catch (_) {}
    return {
      'id': id,
      'nome': nome,
      'preco': preco,
      'lojaId': lojaId,
      'lojaNome': lojaNome,
      'imagem': imagem,
      'quantidade': quantidade,
      'requerVeiculoGrande': veiculoGrande,
    };
  }

  factory CartItemModel.fromJson(Map<String, dynamic> json) {
    return CartItemModel(
      id: json['id'],
      nome: json['nome'],
      preco: (json['preco'] as num).toDouble(),
      lojaId: json['lojaId'],
      lojaNome: json['lojaNome'],
      imagem: json['imagem'],
      quantidade: json['quantidade'],
      requerVeiculoGrande: json['requerVeiculoGrande'] == true,
    );
  }
}
