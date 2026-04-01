// Arquivo: lib/models/banner_model.dart

class BannerModel {
  String id;
  String imageUrl; // Link da imagem hospedada na internet
  String urlDestino; // Link do WhatsApp ou site do anunciante
  String cityId; // Cidade onde o anúncio vai rodar
  bool ativo; // Se o anúncio está rodando ou foi pausado pelo Admin

  BannerModel({
    required this.id,
    required this.imageUrl,
    required this.urlDestino,
    required this.cityId,
    this.ativo = true,
  });

  factory BannerModel.fromMap(Map<String, dynamic> map, String documentId) {
    return BannerModel(
      id: documentId,
      imageUrl: map['imageUrl'] ?? '',
      urlDestino: map['urlDestino'] ?? '',
      cityId: map['cityId'] ?? '',
      ativo: map['ativo'] ?? true,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'imageUrl': imageUrl,
      'urlDestino': urlDestino,
      'cityId': cityId,
      'ativo': ativo,
    };
  }
}
