// Arquivo: lib/screens/auth/ativacao_biometria_screen.dart
//
// Modal full-screen premium oferecido logo após o primeiro login bem-sucedido.
// Chama [BiometriaService.ativarParaConta] caso o usuário aceite.
//
// Não é obrigatório — o botão "Agora não" fecha a tela sem ativar. O app
// pode voltar a oferecer no próximo login (controle via cooldown na
// LoginScreen — ver `_marcarConviteMostrado`).

import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../services/biometria_service.dart';

const Color _diPertinRoxo = Color(0xFF6A1B9A);
const Color _diPertinLaranja = Color(0xFFFF8F00);

/// Resultado da ativação (retornado via [Navigator.pop]).
class AtivacaoBiometriaResultado {
  final bool ativou;
  final bool declinou;
  final String? erro;

  const AtivacaoBiometriaResultado.ativou()
      : ativou = true,
        declinou = false,
        erro = null;
  const AtivacaoBiometriaResultado.declinou()
      : ativou = false,
        declinou = true,
        erro = null;
  const AtivacaoBiometriaResultado.falhou(String this.erro)
      : ativou = false,
        declinou = false;
}

class AtivacaoBiometriaScreen extends StatefulWidget {
  const AtivacaoBiometriaScreen({
    super.key,
    required this.uid,
    required this.email,
    required this.metodo,
    this.senhaParaVinculo,
  });

  final String uid;
  final String email;
  final BiometriaMetodoLogin metodo;

  /// Obrigatório quando [metodo] = email_senha. Será persistido de forma
  /// segura (EncryptedSharedPreferences / Keychain).
  final String? senhaParaVinculo;

  @override
  State<AtivacaoBiometriaScreen> createState() =>
      _AtivacaoBiometriaScreenState();
}

class _AtivacaoBiometriaScreenState extends State<AtivacaoBiometriaScreen>
    with TickerProviderStateMixin {
  late final AnimationController _entradaCtrl;
  late final AnimationController _pulsoCtrl;
  late final Animation<double> _fadeIn;
  late final Animation<Offset> _slideUp;
  late final Animation<double> _logoScale;

  bool _processando = false;

  @override
  void initState() {
    super.initState();
    _entradaCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    );
    _pulsoCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2400),
    )..repeat(reverse: true);

    _fadeIn = CurvedAnimation(parent: _entradaCtrl, curve: Curves.easeOut);
    _slideUp = Tween<Offset>(
      begin: const Offset(0, 0.08),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _entradaCtrl,
      curve: Curves.easeOutCubic,
    ));
    _logoScale = Tween<double>(begin: 0.85, end: 1.0).animate(
      CurvedAnimation(
        parent: _entradaCtrl,
        curve: const Interval(0.0, 0.8, curve: Curves.easeOutBack),
      ),
    );

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _entradaCtrl.forward();
    });
  }

  @override
  void dispose() {
    _entradaCtrl.dispose();
    _pulsoCtrl.dispose();
    super.dispose();
  }

  Future<void> _ativar() async {
    if (_processando) return;
    setState(() => _processando = true);
    try {
      final resultado = await BiometriaService.instancia.autenticarComBiometria(
        razao:
            'Confirme sua digital para ativar o acesso rápido no DiPertin.',
      );
      if (!mounted) return;
      switch (resultado) {
        case BiometriaResultado.sucesso:
          await BiometriaService.instancia.ativarParaConta(
            uid: widget.uid,
            email: widget.email,
            metodo: widget.metodo,
            senhaEmTextoPuro: widget.senhaParaVinculo,
          );
          if (!mounted) return;
          Navigator.of(context)
              .pop(const AtivacaoBiometriaResultado.ativou());
          return;
        case BiometriaResultado.indisponivel:
          _mostrarErro(
            'Não encontramos biometria cadastrada no aparelho. '
            'Configure uma digital nas opções do sistema e tente novamente.',
          );
          break;
        case BiometriaResultado.cancelado:
          _mostrarErro('Ativação cancelada.');
          break;
        case BiometriaResultado.falhou:
          _mostrarErro(
            'Não conseguimos validar sua digital. Tente novamente.',
          );
          break;
        case BiometriaResultado.erro:
          _mostrarErro(
            'Não foi possível concluir agora. Tente novamente em instantes.',
          );
          break;
      }
    } finally {
      if (mounted) setState(() => _processando = false);
    }
  }

  void _mostrarErro(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: Colors.red.shade600,
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.fromLTRB(16, 0, 16, 20),
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }

  void _agoraNao() {
    if (_processando) return;
    Navigator.of(context).pop(const AtivacaoBiometriaResultado.declinou());
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    return Scaffold(
      backgroundColor: const Color(0xFFF9F7FC),
      body: Stack(
        children: [
          // Background decorativo com gradiente e círculos
          Positioned.fill(
            child: DecoratedBox(
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    Color(0xFFFDF9FF),
                    Color(0xFFF3ECF9),
                  ],
                ),
              ),
            ),
          ),
          Positioned(
            top: -80,
            right: -60,
            child: _borraRadial(size.width * 0.7, _diPertinLaranja, 0.18),
          ),
          Positioned(
            bottom: -120,
            left: -80,
            child: _borraRadial(size.width * 0.9, _diPertinRoxo, 0.22),
          ),

          SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: FadeTransition(
                opacity: _fadeIn,
                child: SlideTransition(
                  position: _slideUp,
                  child: Column(
                    children: [
                      const SizedBox(height: 8),
                      Align(
                        alignment: Alignment.centerRight,
                        child: TextButton(
                          onPressed: _processando ? null : _agoraNao,
                          style: TextButton.styleFrom(
                            foregroundColor: Colors.grey.shade700,
                            padding: const EdgeInsets.symmetric(
                                horizontal: 14, vertical: 10),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                          ),
                          child: const Text(
                            'Pular',
                            style: TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: 14,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      _bolhaBiometria(),
                      const SizedBox(height: 24),
                      ScaleTransition(
                        scale: _logoScale,
                        child: Image.asset(
                          'assets/logo.png',
                          height: 88,
                          fit: BoxFit.contain,
                          errorBuilder: (context, error, stackTrace) =>
                              const Icon(
                            Icons.storefront_rounded,
                            size: 64,
                            color: _diPertinRoxo,
                          ),
                        ),
                      ),
                      const SizedBox(height: 28),
                      const Text(
                        'Entre com mais segurança\ne praticidade',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.w800,
                          letterSpacing: -0.6,
                          height: 1.22,
                          color: Color(0xFF1A1A2E),
                        ),
                      ),
                      const SizedBox(height: 14),
                      Text(
                        'Ative o acesso por digital para entrar no app de forma rápida, segura e sem precisar digitar sua senha em cada acesso.',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 15,
                          height: 1.55,
                          color: Colors.grey.shade700,
                          letterSpacing: -0.1,
                        ),
                      ),
                      const SizedBox(height: 22),
                      _chipsBeneficios(),
                      const Spacer(),
                      _botaoPrincipal(),
                      const SizedBox(height: 12),
                      _botaoSecundario(),
                      const SizedBox(height: 18),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.lock_outline_rounded,
                            size: 14,
                            color: Colors.grey.shade500,
                          ),
                          const SizedBox(width: 6),
                          Flexible(
                            child: Text(
                              'Sua digital fica apenas no aparelho — nunca sai deste dispositivo.',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                fontSize: 11.5,
                                color: Colors.grey.shade500,
                                height: 1.4,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _borraRadial(double tamanho, Color cor, double opacidade) {
    return IgnorePointer(
      child: Container(
        width: tamanho,
        height: tamanho,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: RadialGradient(
            colors: [
              cor.withValues(alpha: opacidade),
              cor.withValues(alpha: 0),
            ],
          ),
        ),
      ),
    );
  }

  Widget _bolhaBiometria() {
    return AnimatedBuilder(
      animation: _pulsoCtrl,
      builder: (context, _) {
        final t = _pulsoCtrl.value;
        final escala1 = 1.0 + 0.18 * (math.sin(t * math.pi).abs());
        final escala2 = 1.0 + 0.30 * (math.sin(t * math.pi).abs());
        return SizedBox(
          width: 190,
          height: 190,
          child: Stack(
            alignment: Alignment.center,
            children: [
              Transform.scale(
                scale: escala2,
                child: Container(
                  width: 180,
                  height: 180,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: _diPertinRoxo.withValues(alpha: 0.06),
                  ),
                ),
              ),
              Transform.scale(
                scale: escala1,
                child: Container(
                  width: 140,
                  height: 140,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: _diPertinRoxo.withValues(alpha: 0.10),
                  ),
                ),
              ),
              Container(
                width: 110,
                height: 110,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: const LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [_diPertinRoxo, Color(0xFF8E24AA)],
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: _diPertinRoxo.withValues(alpha: 0.38),
                      blurRadius: 28,
                      spreadRadius: 2,
                      offset: const Offset(0, 10),
                    ),
                  ],
                ),
                child: const Icon(
                  Icons.fingerprint_rounded,
                  color: Colors.white,
                  size: 56,
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _chipsBeneficios() {
    return Wrap(
      alignment: WrapAlignment.center,
      spacing: 8,
      runSpacing: 8,
      children: const [
        _ChipBeneficio(
          icone: Icons.bolt_rounded,
          texto: 'Login em 1 toque',
        ),
        _ChipBeneficio(
          icone: Icons.shield_moon_rounded,
          texto: 'Mais seguro',
        ),
        _ChipBeneficio(
          icone: Icons.phonelink_lock_rounded,
          texto: 'Só neste aparelho',
        ),
      ],
    );
  }

  Widget _botaoPrincipal() {
    return AnimatedScale(
      scale: _processando ? 0.98 : 1.0,
      duration: const Duration(milliseconds: 180),
      child: DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: _diPertinLaranja.withValues(alpha: 0.38),
              blurRadius: 18,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: FilledButton(
          onPressed: _processando ? null : _ativar,
          style: FilledButton.styleFrom(
            backgroundColor: _diPertinLaranja,
            disabledBackgroundColor:
                _diPertinLaranja.withValues(alpha: 0.6),
            foregroundColor: Colors.white,
            minimumSize: const Size(double.infinity, 56),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
          ),
          child: _processando
              ? const SizedBox(
                  width: 22,
                  height: 22,
                  child: CircularProgressIndicator(
                    color: Colors.white,
                    strokeWidth: 2.5,
                  ),
                )
              : Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: const [
                    Icon(Icons.fingerprint_rounded, size: 22),
                    SizedBox(width: 10),
                    Text(
                      'Ativar Digital',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.2,
                      ),
                    ),
                  ],
                ),
        ),
      ),
    );
  }

  Widget _botaoSecundario() {
    return TextButton(
      onPressed: _processando ? null : _agoraNao,
      style: TextButton.styleFrom(
        foregroundColor: _diPertinRoxo,
        minimumSize: const Size(double.infinity, 48),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
        ),
      ),
      child: const Text(
        'Agora não',
        style: TextStyle(
          fontSize: 15,
          fontWeight: FontWeight.w700,
          letterSpacing: -0.1,
        ),
      ),
    );
  }
}

class _ChipBeneficio extends StatelessWidget {
  const _ChipBeneficio({required this.icone, required this.texto});

  final IconData icone;
  final String texto;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(30),
        border: Border.all(color: const Color(0xFFE8E0F3)),
        boxShadow: [
          BoxShadow(
            color: _diPertinRoxo.withValues(alpha: 0.05),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icone, size: 15, color: _diPertinRoxo),
          const SizedBox(width: 6),
          Text(
            texto,
            style: const TextStyle(
              color: Color(0xFF4A2A6B),
              fontWeight: FontWeight.w700,
              fontSize: 12.5,
              letterSpacing: -0.1,
            ),
          ),
        ],
      ),
    );
  }
}
