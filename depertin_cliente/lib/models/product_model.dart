// Arquivo: lib/models/product_model.dart

class ProductModel {
  String id;
  String nome;
  String descricao;
  double precoOriginal;
  double precoOferta; // Para dar destaque aos descontos [cite: 37]
  String imagemUrl;
  String categoria;
  String lojaId; // Para sabermos quem está vendendo
  String cityId; // Para filtrar pela cidade do cliente [cite: 14]

  ProductModel({
    required this.id,
    required this.nome,
    required this.descricao,
    required this.precoOriginal,
    required this.precoOferta,
    required this.imagemUrl,
    required this.categoria,
    required this.lojaId,
    required this.cityId,
  });

  // Transforma os dados do Firebase para o formato do App
  factory ProductModel.fromMap(Map<String, dynamic> map, String documentId) {
    return ProductModel(
      id: documentId,
      nome: map['nome'] ?? '',
      descricao: map['descricao'] ?? '',
      precoOriginal: (map['precoOriginal'] ?? 0.0).toDouble(),
      precoOferta: (map['precoOferta'] ?? 0.0).toDouble(),
      imagemUrl: map['imagemUrl'] ?? '',
      categoria: map['categoria'] ?? '',
      lojaId: map['lojaId'] ?? '',
      cityId: map['cityId'] ?? '',
    );
  }

  // Transforma os dados do App para salvar no Firebase
  Map<String, dynamic> toMap() {
    return {
      'nome': nome,
      'descricao': descricao,
      'precoOriginal': precoOriginal,
      'precoOferta': precoOferta,
      'imagemUrl': imagemUrl,
      'categoria': categoria,
      'lojaId': lojaId,
      'cityId': cityId,
    };
  }
}
