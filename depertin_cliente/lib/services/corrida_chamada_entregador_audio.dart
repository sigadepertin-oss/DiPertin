import 'dart:io';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';

import 'alerta_corrida_nativo.dart';
import 'android_nav_intent.dart';
import 'corrida_foreground_notificacao.dart';

/// Player único para o ringtone de oferta de corrida (FCM em primeiro plano + radar).
/// Garante que aceitar/recusar no dashboard pare todo o áudio da chamada.
class CorridaChamadaEntregadorAudio {
  CorridaChamadaEntregadorAudio._();

  static final AudioPlayer _player = AudioPlayer();

  /// Para TUDO: áudio MP3, vibração em padrão e flash LED. Usar quando o
  /// usuário interage com a oferta (aceitar/recusar/expirar) ou na dispose —
  /// momentos em que queremos silêncio imediato.
  static Future<void> parar() async {
    try {
      await _player.stop();
      await _player.seek(Duration.zero);
    } catch (e) {
      debugPrint('[CorridaChamadaEntregadorAudio.parar] $e');
    }
    if (!kIsWeb && Platform.isAndroid) {
      await AlertaCorridaNativo.cancelarVibracao();
      await AlertaCorridaNativo.desligarFlash();
    }
  }

  /// Para SOMENTE o áudio MP3 tocado pelo Flutter (iOS/web ou fallback).
  /// Não mexe em vibração e LED, que continuam sendo alertas de
  /// acessibilidade legítimos mesmo com a tela oficial visível.
  static Future<void> pararSomenteAudio() async {
    try {
      await _player.stop();
      await _player.seek(Duration.zero);
    } catch (e) {
      debugPrint('[CorridaChamadaEntregadorAudio.pararSomenteAudio] $e');
    }
  }

  /// Chamada quando a `IncomingDeliveryActivity` nativa assume a chamada.
  ///
  /// Remove a notificação local (foreground) e a heads-up nativa de corrida
  /// e encerra o áudio MP3 — mas **preserva vibração e flash LED**, porque
  /// esses são os canais de acessibilidade que o entregador escolheu
  /// explicitamente (ex.: usuário surdo, celular no bolso). Eles se encerram
  /// naturalmente ao fim do ciclo de pulsações ou quando o usuário tocar em
  /// aceitar/recusar (aí sim, `parar()` é chamado no dashboard).
  static Future<void> silenciarAlertaCorridaCompleto(String pedidoId) async {
    await pararSomenteAudio();
    final id = pedidoId.trim();
    if (id.isEmpty) return;
    await CorridaForegroundNotificacao.cancelarPedido(id);
    if (!kIsWeb && Platform.isAndroid) {
      await AndroidNavIntent.cancelIncomingCorridaNotification(id);
    }
  }

  static Future<void> tocarChamada() async {
    // No Android, a `IncomingDeliveryActivity` nativa e o canal de notificação
    // `corrida_chamada` já executam o toque (MediaPlayer em loop + som do
    // canal). Tocar aqui também gera o efeito de "toque duplicado" relatado
    // pelos entregadores. Mantemos o MP3 apenas para iOS/web ou quando a
    // tela nativa não pode ser aberta.
    if (!kIsWeb && Platform.isAndroid) {
      return;
    }
    try {
      await _player.stop();
      await _player.play(AssetSource('sond/ChamadaEntregador.mp3'));
    } catch (e) {
      debugPrint('[CorridaChamadaEntregadorAudio.tocarChamada] $e');
    }
  }
}
