// Arquivo: lib/services/biometria_service.dart
//
// Serviço responsável por autenticação biométrica local (digital/face)
// e persistência segura do vínculo por dispositivo (nunca em texto puro).
//
// Fluxo:
//   1. Primeiro acesso SEMPRE por e-mail/senha ou Google (nunca só biometria).
//   2. Após login bem-sucedido, o app consulta [podeOferecerAtivacao] —
//      só oferece se o dispositivo suporta biometria e há digital cadastrada.
//   3. Ao ativar, chama [ativarParaConta] passando método, email e (opcional)
//      senha cifrada. Dados ficam em [FlutterSecureStorage] (AES + Keystore).
//   4. Em acessos futuros, [autenticarComBiometria] abre o prompt nativo.
//      Se validado, [lerVinculo] devolve os dados para re-login real no
//      Firebase (email/senha ou Google silencioso).
//
// Regras de segurança:
//   • Se `getAvailableBiometrics()` estiver vazio, o vínculo é limpo
//     automaticamente (usuário removeu as biometrias do aparelho).
//   • Senha nunca trafega em texto puro: só entra no secure storage.
//   • Troca de senha no app → chamar [desativar] (fluxo de `AlterarSenhaScreen`).
//   • Logout padrão mantém a biometria; apenas nova autenticação é exigida.

import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:local_auth/local_auth.dart';
import 'package:local_auth_android/local_auth_android.dart';

/// Método de login associado ao vínculo biométrico.
enum BiometriaMetodoLogin {
  emailSenha,
  google,
}

extension BiometriaMetodoLoginX on BiometriaMetodoLogin {
  String get codigo {
    switch (this) {
      case BiometriaMetodoLogin.emailSenha:
        return 'email_senha';
      case BiometriaMetodoLogin.google:
        return 'google';
    }
  }

  static BiometriaMetodoLogin? tryParse(String? v) {
    switch (v) {
      case 'email_senha':
        return BiometriaMetodoLogin.emailSenha;
      case 'google':
        return BiometriaMetodoLogin.google;
    }
    return null;
  }
}

/// Dados mínimos persistidos por dispositivo para re-login rápido.
class BiometriaVinculo {
  final String uid;
  final String email;
  final BiometriaMetodoLogin metodo;

  /// Senha cifrada pelo secure storage nativo. Só para [metodo]=email_senha.
  /// NUNCA é persistida em texto puro fora do storage seguro do sistema.
  final String? senhaSegura;

  /// Carimbado em ISO8601 para auditoria local.
  final DateTime ativadoEm;

  BiometriaVinculo({
    required this.uid,
    required this.email,
    required this.metodo,
    required this.ativadoEm,
    this.senhaSegura,
  });

  Map<String, dynamic> toMap() => {
        'uid': uid,
        'email': email,
        'metodo': metodo.codigo,
        'ativado_em': ativadoEm.toIso8601String(),
        if (senhaSegura != null) 'senha_segura': senhaSegura,
      };

  static BiometriaVinculo? tryFromMap(Map<String, dynamic> m) {
    final uid = m['uid']?.toString();
    final email = m['email']?.toString();
    final metodo = BiometriaMetodoLoginX.tryParse(m['metodo']?.toString());
    if (uid == null || uid.isEmpty) return null;
    if (email == null || email.isEmpty) return null;
    if (metodo == null) return null;
    DateTime ativadoEm;
    try {
      ativadoEm = DateTime.parse(m['ativado_em']?.toString() ?? '');
    } catch (_) {
      ativadoEm = DateTime.now();
    }
    return BiometriaVinculo(
      uid: uid,
      email: email,
      metodo: metodo,
      senhaSegura: m['senha_segura']?.toString(),
      ativadoEm: ativadoEm,
    );
  }
}

/// Estado consolidado de disponibilidade da biometria no aparelho.
class BiometriaDisponibilidade {
  final bool dispositivoSuporta;
  final bool algumaBiometriaCadastrada;
  final bool temDigital;
  final bool temFacial;
  final bool temIris;
  final bool temFraca;

  const BiometriaDisponibilidade({
    required this.dispositivoSuporta,
    required this.algumaBiometriaCadastrada,
    required this.temDigital,
    required this.temFacial,
    required this.temIris,
    required this.temFraca,
  });

  bool get disponivelParaUso =>
      dispositivoSuporta && algumaBiometriaCadastrada;

  const BiometriaDisponibilidade.indisponivel()
      : dispositivoSuporta = false,
        algumaBiometriaCadastrada = false,
        temDigital = false,
        temFacial = false,
        temIris = false,
        temFraca = false;
}

/// Resultado de uma tentativa de autenticação biométrica.
enum BiometriaResultado {
  sucesso,

  /// Usuário cancelou, encerrou o prompt ou atingiu o limite de tentativas.
  cancelado,

  /// Falhou a validação (digital não reconhecida, por exemplo).
  falhou,

  /// Aparelho removeu todas as biometrias / não suporta mais.
  indisponivel,

  erro,
}

class BiometriaService {
  BiometriaService._();
  static final BiometriaService instancia = BiometriaService._();

  static const _kChaveVinculo = 'dipertin_biometria_vinculo_v1';

  final LocalAuthentication _localAuth = LocalAuthentication();

  final FlutterSecureStorage _storage = const FlutterSecureStorage(
    aOptions: AndroidOptions(
      encryptedSharedPreferences: true,
    ),
    iOptions: IOSOptions(
      accessibility: KeychainAccessibility.first_unlock_this_device,
    ),
  );

  BiometriaDisponibilidade? _cacheDisponibilidade;

  /// Platform support. Não significa que há digital cadastrada.
  Future<bool> dispositivoSuportaBiometria() async {
    if (kIsWeb) return false;
    try {
      final suporte = await _localAuth.isDeviceSupported();
      final pode = await _localAuth.canCheckBiometrics;
      return suporte && pode;
    } catch (e) {
      debugPrint('BiometriaService.dispositivoSuportaBiometria: $e');
      return false;
    }
  }

  /// Consulta completa: suporte + lista de biometrias cadastradas.
  Future<BiometriaDisponibilidade> consultarDisponibilidade(
      {bool forcarRefresh = false}) async {
    if (!forcarRefresh && _cacheDisponibilidade != null) {
      return _cacheDisponibilidade!;
    }
    if (kIsWeb) {
      return _cacheDisponibilidade = const BiometriaDisponibilidade.indisponivel();
    }
    try {
      final suporte = await dispositivoSuportaBiometria();
      if (!suporte) {
        return _cacheDisponibilidade =
            const BiometriaDisponibilidade.indisponivel();
      }
      final lista = await _localAuth.getAvailableBiometrics();
      final temDigital = lista.contains(BiometricType.fingerprint) ||
          lista.contains(BiometricType.strong);
      final temFacial = lista.contains(BiometricType.face);
      final temIris = lista.contains(BiometricType.iris);
      final temFraca = lista.contains(BiometricType.weak);
      final alguma = lista.isNotEmpty;
      return _cacheDisponibilidade = BiometriaDisponibilidade(
        dispositivoSuporta: true,
        algumaBiometriaCadastrada: alguma,
        temDigital: temDigital,
        temFacial: temFacial,
        temIris: temIris,
        temFraca: temFraca,
      );
    } catch (e) {
      debugPrint('BiometriaService.consultarDisponibilidade: $e');
      return _cacheDisponibilidade =
          const BiometriaDisponibilidade.indisponivel();
    }
  }

  /// Útil para a tela de login decidir se mostra o botão "Acessar por Digital".
  /// Só retorna true se: há biometria disponível + vínculo salvo no device.
  Future<bool> podeUsarLoginBiometrico() async {
    final disp = await consultarDisponibilidade();
    if (!disp.disponivelParaUso) {
      // Aparelho sem biometria cadastrada → se tínhamos vínculo, expira.
      final havia = await estaAtivada();
      if (havia) {
        await desativar();
      }
      return false;
    }
    return estaAtivada();
  }

  /// Útil para decidir se oferece a ativação após o primeiro login.
  Future<bool> podeOferecerAtivacao() async {
    final disp = await consultarDisponibilidade();
    return disp.disponivelParaUso;
  }

  /// Dispara o prompt biométrico nativo.
  /// [razao] é a string que aparece no prompt (pt-BR).
  Future<BiometriaResultado> autenticarComBiometria({
    required String razao,
  }) async {
    try {
      final disp = await consultarDisponibilidade(forcarRefresh: true);
      if (!disp.disponivelParaUso) {
        return BiometriaResultado.indisponivel;
      }
      final ok = await _localAuth.authenticate(
        localizedReason: razao,
        authMessages: const [
          AndroidAuthMessages(
            signInTitle: 'Autenticação biométrica',
            biometricHint: 'Aproxime o dedo do sensor',
            biometricNotRecognized: 'Digital não reconhecida. Tente novamente.',
            biometricSuccess: 'Tudo certo!',
            biometricRequiredTitle: 'Biometria necessária',
            cancelButton: 'Cancelar',
            deviceCredentialsRequiredTitle:
                'Cadastre uma digital no aparelho',
            deviceCredentialsSetupDescription:
                'Abra as Configurações do sistema para cadastrar sua digital e tente novamente.',
            goToSettingsButton: 'Abrir configurações',
            goToSettingsDescription:
                'Sua conta ficará mais segura. Configure uma digital no aplicativo para continuar.',
          ),
        ],
        options: const AuthenticationOptions(
          biometricOnly: true,
          stickyAuth: true,
          useErrorDialogs: true,
        ),
      );
      return ok ? BiometriaResultado.sucesso : BiometriaResultado.falhou;
    } on PlatformException catch (e, s) {
      debugPrint(
        'BiometriaService.autenticar → PlatformException '
        'code=${e.code} message=${e.message} details=${e.details}\n$s',
      );
      switch (e.code) {
        case 'NotAvailable':
        case 'NotEnrolled':
        case 'PasscodeNotSet':
          return BiometriaResultado.indisponivel;
        case 'LockedOut':
        case 'PermanentlyLockedOut':
          return BiometriaResultado.falhou;
        case 'UserCancel':
        case 'auth_in_progress':
          return BiometriaResultado.cancelado;
        case 'no_fragment_activity':
          // Configuração do app Android não foi atualizada: MainActivity
          // ainda é FlutterActivity e o plugin exige FlutterFragmentActivity.
          // Cai em [erro] para não enganar o usuário dizendo que não tem
          // biometria no aparelho.
          return BiometriaResultado.erro;
      }
      return BiometriaResultado.erro;
    } catch (e, s) {
      debugPrint('BiometriaService.autenticar → erro: $e\n$s');
      return BiometriaResultado.erro;
    }
  }

  /// Salva o vínculo biométrico local após o primeiro login autorizado.
  Future<void> ativarParaConta({
    required String uid,
    required String email,
    required BiometriaMetodoLogin metodo,
    String? senhaEmTextoPuro,
  }) async {
    assert(
      metodo != BiometriaMetodoLogin.emailSenha || senhaEmTextoPuro != null,
      'email_senha exige senha para re-login biométrico',
    );
    final vinculo = BiometriaVinculo(
      uid: uid,
      email: email.trim().toLowerCase(),
      metodo: metodo,
      senhaSegura: senhaEmTextoPuro,
      ativadoEm: DateTime.now(),
    );
    final jsonStr = jsonEncode(vinculo.toMap());
    await _storage.write(key: _kChaveVinculo, value: jsonStr);
  }

  /// Atualiza a senha cifrada (após alteração bem-sucedida).
  Future<void> atualizarSenhaVinculo(String novaSenha) async {
    final atual = await lerVinculo();
    if (atual == null || atual.metodo != BiometriaMetodoLogin.emailSenha) {
      return;
    }
    await ativarParaConta(
      uid: atual.uid,
      email: atual.email,
      metodo: atual.metodo,
      senhaEmTextoPuro: novaSenha,
    );
  }

  Future<bool> estaAtivada() async {
    final v = await _storage.read(key: _kChaveVinculo);
    return (v ?? '').isNotEmpty;
  }

  Future<BiometriaVinculo?> lerVinculo() async {
    try {
      final raw = await _storage.read(key: _kChaveVinculo);
      if (raw == null || raw.isEmpty) return null;
      final map = jsonDecode(raw);
      if (map is! Map) return null;
      return BiometriaVinculo.tryFromMap(Map<String, dynamic>.from(map));
    } catch (e) {
      debugPrint('BiometriaService.lerVinculo: $e');
      return null;
    }
  }

  /// Remove o vínculo (ex.: usuário desativa no painel ou login inconsistente).
  Future<void> desativar() async {
    try {
      await _storage.delete(key: _kChaveVinculo);
    } catch (e) {
      debugPrint('BiometriaService.desativar: $e');
    }
  }

  /// Limpa o cache de disponibilidade (chamado quando voltamos do
  /// foreground, por exemplo).
  void invalidarCache() {
    _cacheDisponibilidade = null;
  }
}
