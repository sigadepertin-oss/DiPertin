// Arquivo: lib/screens/entregador/configuracoes/meus_documentos_screen.dart

import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';

import '../../../services/permissoes_app_service.dart';

const Color _roxo = Color(0xFF6A1B9A);
const Color _laranja = Color(0xFFFF8F00);

/// Lista todos os documentos do entregador que já foram enviados à plataforma
/// (CNH, CRLV do veículo ativo e selfie de verificação) com o status atual
/// (aprovado, em análise, reprovado) e um botão "Trocar" por documento para
/// permitir atualização sem sair da tela.
///
/// A selfie, uma vez aprovada, é travada (`selfie_bloqueada=true`) porque
/// substitui a foto de perfil como medida antifraude — por isso não oferece
/// botão de troca, apenas indica o status.
class MeusDocumentosScreen extends StatefulWidget {
  const MeusDocumentosScreen({super.key});

  @override
  State<MeusDocumentosScreen> createState() => _MeusDocumentosScreenState();
}

class _MeusDocumentosScreenState extends State<MeusDocumentosScreen> {
  bool _enviandoCnh = false;
  bool _enviandoCrlv = false;

  String? get _uid => FirebaseAuth.instance.currentUser?.uid;

  DocumentReference<Map<String, dynamic>>? _docCnh() {
    final uid = _uid;
    if (uid == null) return null;
    return FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .collection('documentos')
        .doc('cnh');
  }

  Future<void> _anexarCnh() async {
    final uid = _uid;
    final ref = _docCnh();
    if (uid == null || ref == null) return;

    final pr = await PermissoesAppService.garantirLeituraArquivosAnexos();
    if (!mounted) return;
    if (pr != ResultadoPermissao.concedida) {
      PermissoesFeedback.arquivosAnexos(context, pr);
      return;
    }
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['jpg', 'jpeg', 'png', 'pdf'],
    );
    if (result == null || result.files.single.path == null) return;

    setState(() => _enviandoCnh = true);
    try {
      final file = File(result.files.single.path!);
      final ext = file.path.split('.').last.toLowerCase();
      final ts = DateTime.now().millisecondsSinceEpoch;
      final storageRef = FirebaseStorage.instance
          .ref()
          .child('documentos_entregadores/$uid/cnh_$ts.$ext');
      final snap = await storageRef.putFile(file);
      final url = await snap.ref.getDownloadURL();

      await ref.set({
        'url': url,
        'status': 'pendente',
        'motivo_reprovacao': FieldValue.delete(),
        'atualizado_em': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('CNH enviada. Aguarde a aprovação da equipe.'),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erro ao enviar: $e')),
      );
    } finally {
      if (mounted) setState(() => _enviandoCnh = false);
    }
  }

  Future<void> _anexarCrlv(String veiculoId) async {
    final uid = _uid;
    if (uid == null) return;

    final pr = await PermissoesAppService.garantirLeituraArquivosAnexos();
    if (!mounted) return;
    if (pr != ResultadoPermissao.concedida) {
      PermissoesFeedback.arquivosAnexos(context, pr);
      return;
    }
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['jpg', 'jpeg', 'png', 'pdf'],
    );
    if (result == null || result.files.single.path == null) return;

    setState(() => _enviandoCrlv = true);
    try {
      final file = File(result.files.single.path!);
      final ext = file.path.split('.').last.toLowerCase();
      final ts = DateTime.now().millisecondsSinceEpoch;
      final storageRef = FirebaseStorage.instance
          .ref()
          .child('documentos_entregadores/$uid/crlv_${veiculoId}_$ts.$ext');
      final snap = await storageRef.putFile(file);
      final url = await snap.ref.getDownloadURL();

      final docRef = FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .collection('veiculos')
          .doc(veiculoId)
          .collection('documentos')
          .doc('crlv');
      await docRef.set({
        'url': url,
        'status': 'pendente',
        'motivo_reprovacao': FieldValue.delete(),
        'atualizado_em': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('CRLV enviado. Aguarde a aprovação da equipe.'),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Erro ao enviar: $e')),
      );
    } finally {
      if (mounted) setState(() => _enviandoCrlv = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final uid = _uid;
    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F7),
      appBar: AppBar(
        title: const Text(
          'Meus documentos',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        backgroundColor: _roxo,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: uid == null
          ? const Center(child: Text('Você precisa estar autenticado.'))
          : StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
              stream: FirebaseFirestore.instance
                  .collection('users')
                  .doc(uid)
                  .snapshots(),
              builder: (context, userSnap) {
                final userData = userSnap.data?.data() ?? {};
                final veiculoAtivoId =
                    (userData['veiculo_ativo_id'] ?? '').toString().trim();

                return ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    _construirCardCnh(userData),
                    const SizedBox(height: 12),
                    _construirCardCrlv(uid, veiculoAtivoId, userData),
                    const SizedBox(height: 12),
                    _construirCardSelfie(userData),
                    const SizedBox(height: 14),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: _roxo.withValues(alpha: 0.06),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(Icons.info_outline, color: _roxo, size: 18),
                          SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              'Ao enviar um novo arquivo, o documento volta para "Em análise" até ser aprovado pela equipe.',
                              style: TextStyle(
                                color: Colors.black54,
                                fontSize: 12,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                );
              },
            ),
    );
  }

  Widget _construirCardCnh(Map<String, dynamic> userData) {
    final ref = _docCnh();
    if (ref == null) return const SizedBox.shrink();
    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: ref.snapshots(),
      builder: (context, snap) {
        Map<String, dynamic>? data = snap.data?.data();
        if (data == null || (data['url'] ?? '').toString().isEmpty) {
          final urlLegado = (userData['url_doc_pessoal'] ?? '').toString();
          if (urlLegado.isNotEmpty) {
            data = {
              'url': urlLegado,
              'status': 'pendente',
              'origem': 'cadastro_entregador',
            };
          }
        }
        return _CardDocumento(
          titulo: 'CNH (Carteira Nacional de Habilitação)',
          descricao:
              'Usada para identificação e autorização de direção. Atualize assim que mudar sua habilitação.',
          data: data,
          enviando: _enviandoCnh,
          rotuloBotao: 'Trocar',
          onTrocar: _anexarCnh,
        );
      },
    );
  }

  Widget _construirCardCrlv(
    String uid,
    String veiculoAtivoId,
    Map<String, dynamic> userData,
  ) {
    // Quando não há veículo ativo, caímos no fallback legado (users.url_crlv)
    // só para exibir o que foi enviado no cadastro inicial — sem botão de
    // troca, já que a troca depende de um veículo cadastrado.
    if (veiculoAtivoId.isEmpty) {
      final urlLegado = (userData['url_crlv'] ?? '').toString().trim();
      final dataFallback = urlLegado.isNotEmpty
          ? <String, dynamic>{
              'url': urlLegado,
              'status': 'pendente',
              'origem': 'cadastro_entregador',
            }
          : null;
      return _CardDocumento(
        titulo: 'CRLV (Documento do veículo)',
        descricao:
            'Cadastre um veículo em Configurações → Veículo para poder trocar o CRLV por aqui.',
        data: dataFallback,
        enviando: false,
        rotuloBotao: 'Cadastrar veículo',
        onTrocar: null,
      );
    }

    final ref = FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .collection('veiculos')
        .doc(veiculoAtivoId)
        .collection('documentos')
        .doc('crlv');

    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: ref.snapshots(),
      builder: (context, snap) {
        Map<String, dynamic>? data = snap.data?.data();
        if (data == null || (data['url'] ?? '').toString().isEmpty) {
          final urlLegado = (userData['url_crlv'] ?? '').toString().trim();
          if (urlLegado.isNotEmpty) {
            data = {
              'url': urlLegado,
              'status': 'pendente',
              'origem': 'cadastro_entregador',
            };
          }
        }
        return _CardDocumento(
          titulo: 'CRLV (Documento do veículo)',
          descricao:
              'Documento do veículo ativo. Atualize quando renovar o licenciamento anual.',
          data: data,
          enviando: _enviandoCrlv,
          rotuloBotao: 'Trocar',
          onTrocar: () => _anexarCrlv(veiculoAtivoId),
        );
      },
    );
  }

  Widget _construirCardSelfie(Map<String, dynamic> userData) {
    final url = (userData['url_selfie_entregador'] ?? '').toString().trim();
    final selfieBloqueada = userData['selfie_bloqueada'] == true;
    final selfieStatus =
        (userData['selfie_status'] ?? '').toString().toLowerCase();

    // Ainda sem envio — a selfie foi introduzida depois do cadastro de alguns
    // entregadores, então não faz sentido forçar o card se não há URL.
    if (url.isEmpty) return const SizedBox.shrink();

    final status = selfieBloqueada
        ? 'aprovado'
        : (selfieStatus.isEmpty ? 'pendente' : selfieStatus);

    return _CardDocumento(
      titulo: 'Selfie de verificação',
      descricao: selfieBloqueada
          ? 'Serve como sua foto de perfil e não pode ser alterada. É usada para validar que você é o titular da conta.'
          : 'Foto enviada para confirmar que você é o titular da conta. Após aprovação, vira sua foto de perfil.',
      data: <String, dynamic>{'url': url, 'status': status},
      enviando: false,
      bloqueado: selfieBloqueada,
      rotuloBotao: selfieBloqueada ? 'Bloqueada' : null,
      onTrocar: null,
    );
  }
}

class _CardDocumento extends StatelessWidget {
  final String titulo;
  final String descricao;
  final Map<String, dynamic>? data;
  final bool enviando;
  final bool bloqueado;
  final String? rotuloBotao;
  final VoidCallback? onTrocar;

  const _CardDocumento({
    required this.titulo,
    required this.descricao,
    required this.data,
    required this.enviando,
    this.bloqueado = false,
    this.rotuloBotao,
    this.onTrocar,
  });

  @override
  Widget build(BuildContext context) {
    final status = (data?['status'] ?? '').toString();
    final motivo = (data?['motivo_reprovacao'] ?? '').toString();
    final url = (data?['url'] ?? '').toString();

    Color cor;
    IconData icone;
    String rotulo;
    switch (status.toLowerCase()) {
      case 'aprovado':
      case 'aprovada':
        cor = Colors.green;
        icone = Icons.check_circle;
        rotulo = 'Aprovado';
        break;
      case 'reprovado':
      case 'recusado':
        cor = Colors.red;
        icone = Icons.cancel;
        rotulo = 'Reprovado';
        break;
      case 'pendente':
        cor = Colors.orange;
        icone = Icons.schedule;
        rotulo = 'Em análise';
        break;
      default:
        cor = Colors.grey;
        icone = Icons.upload_file;
        rotulo = 'Não enviado';
    }

    final temAcao = onTrocar != null && !bloqueado;
    final textoBotao = rotuloBotao ?? (url.isEmpty ? 'Anexar' : 'Trocar');

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            titulo,
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              color: _roxo,
              fontSize: 15,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            descricao,
            style: const TextStyle(color: Colors.black54, fontSize: 12),
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: cor.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: cor.withValues(alpha: 0.3)),
            ),
            child: Row(
              children: [
                Icon(icone, color: cor),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        rotulo,
                        style: TextStyle(
                          color: cor,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      if (motivo.isNotEmpty)
                        Text(
                          'Motivo: $motivo',
                          style: TextStyle(color: cor, fontSize: 12),
                        ),
                    ],
                  ),
                ),
                if (bloqueado)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.green.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(20),
                      border:
                          Border.all(color: Colors.green.withValues(alpha: 0.4)),
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.lock, size: 14, color: Colors.green),
                        SizedBox(width: 4),
                        Text(
                          'Bloqueada',
                          style: TextStyle(
                            color: Colors.green,
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  )
                else if (temAcao)
                  ElevatedButton(
                    onPressed: enviando ? null : onTrocar,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: _laranja,
                      foregroundColor: Colors.white,
                    ),
                    child: enviando
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                              color: Colors.white,
                              strokeWidth: 2,
                            ),
                          )
                        : Text(textoBotao),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
