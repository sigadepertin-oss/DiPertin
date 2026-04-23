// Arquivo: lib/services/alerta_corrida_nativo.dart
//
// Ponte para os helpers nativos de vibração em padrão e flash da câmera
// (LED). Usados pelo alerta de nova corrida para reforçar o convite,
// mesmo com o celular bloqueado ou com som desligado.
//
// A vibração usa `VibrationEffect.createWaveform` (API 26+) — o resultado é
// uma vibração longa em padrão, tipo chamada recebida, muito mais forte que
// o `HapticFeedback.vibrate()` do Flutter, que dá só um toque curto.
//
// O flash usa `CameraManager.setTorchMode`, que pisca o LED mesmo com a tela
// bloqueada. Não precisa abrir preview da câmera.

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

class AlertaCorridaNativo {
  AlertaCorridaNativo._();

  static const MethodChannel _canal = MethodChannel('dipertin.android/nav');

  /// Dispara uma vibração em padrão longo simulando chamada recebida. Os
  /// intervalos estão em milissegundos: [pausa inicial, vibra, pausa, vibra,
  /// ...]. Retorna `true` se o dispositivo tem vibrador e o pedido foi
  /// aceito. Em iOS/web cai para `false` silenciosamente.
  static Future<bool> vibrarPadraoChamada() async {
    if (kIsWeb) return false;
    if (!(defaultTargetPlatform == TargetPlatform.android)) return false;
    try {
      final ok = await _canal.invokeMethod<bool>('vibratePattern', {
        'durations': <int>[
          0, 700, 350, 700, 350, 700, 350, 700, 350, 700, 350, 700,
        ],
        'repeat': -1,
      });
      return ok ?? false;
    } catch (e) {
      debugPrint('[AlertaCorridaNativo] vibrate falhou: $e');
      return false;
    }
  }

  static Future<void> cancelarVibracao() async {
    if (kIsWeb) return;
    if (!(defaultTargetPlatform == TargetPlatform.android)) return;
    try {
      await _canal.invokeMethod<void>('cancelVibrate');
    } catch (_) {}
  }

  /// Pisca o LED da câmera [times] vezes, [onMs] ligado e [offMs] desligado
  /// entre piscadas. Funciona com celular bloqueado. Retorna `false` se o
  /// dispositivo não tem flash ou a operação não foi possível.
  static Future<bool> piscarFlash({
    int times = 8,
    int onMs = 220,
    int offMs = 220,
  }) async {
    if (kIsWeb) return false;
    if (!(defaultTargetPlatform == TargetPlatform.android)) return false;
    try {
      final ok = await _canal.invokeMethod<bool>('torchBlink', {
        'onMs': onMs,
        'offMs': offMs,
        'times': times,
      });
      return ok ?? false;
    } catch (e) {
      debugPrint('[AlertaCorridaNativo] torchBlink falhou: $e');
      return false;
    }
  }

  static Future<void> desligarFlash() async {
    if (kIsWeb) return;
    if (!(defaultTargetPlatform == TargetPlatform.android)) return;
    try {
      await _canal.invokeMethod<void>('torchOff');
    } catch (_) {}
  }
}
