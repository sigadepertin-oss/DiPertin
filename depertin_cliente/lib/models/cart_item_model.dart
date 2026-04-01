// Arquivo: lib/models/cart_item_model.dart

class CartItemModel {
  final String id;
  final String nome;
  final double preco;
  final String lojaId;
  final String lojaNome;
  final String imagem;
  int quantidade;

  CartItemModel({
    required this.id,
    required this.nome,
    required this.preco,
    required this.lojaId,
    required this.lojaNome,
    required this.imagem,
    this.quantidade = 1,
  });

  // 1. Transforma o Produto em formato JSON (Texto) para salvar no celular
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'nome': nome,
      'preco': preco,
      'lojaId': lojaId,
      'lojaNome': lojaNome,
      'imagem': imagem,
      'quantidade': quantidade,
    };
  }

  // 2. Lê o JSON (Texto) do celular e recria o Produto Mágico
  factory CartItemModel.fromJson(Map<String, dynamic> json) {
    return CartItemModel(
      id: json['id'],
      nome: json['nome'],
      preco: (json['preco'] as num)
          .toDouble(), // Garante que o preço sempre seja double
      lojaId: json['lojaId'],
      lojaNome: json['lojaNome'],
      imagem: json['imagem'],
      quantidade: json['quantidade'],
    );
  }
}
