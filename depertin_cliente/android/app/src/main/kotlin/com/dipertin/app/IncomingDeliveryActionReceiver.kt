package com.dipertin.app

import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent

class IncomingDeliveryActionReceiver : BroadcastReceiver() {
    override fun onReceive(context: Context, intent: Intent?) {
        if (intent == null) return
        val orderId = intent.getStringExtra(IncomingDeliveryContract.EXTRA_ORDER_ID).orEmpty()
        if (orderId.isBlank()) return
        val requestId = intent.getStringExtra(IncomingDeliveryContract.EXTRA_REQUEST_ID)
            ?.trim()
            .orEmpty()
            .ifBlank { IncomingDeliveryContract.requestId(orderId, null) }

        val pendingResult = goAsync()
        when (intent.action) {
            IncomingDeliveryContract.ACTION_ACCEPT -> {
                // Responde imediatamente: cancela a notificação, marca aceito
                // e abre o radar. A callable roda em background — o
                // Firestore stream mostra a verdade quando processar.
                NotificationUtils.cancelIncomingNotification(context, orderId)
                IncomingDeliveryFlowState.markAccepted(requestId)
                val openIntent = Intent(context, MainActivity::class.java).apply {
                    flags = Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP
                    putExtra(MainActivity.EXTRA_ABRIR_ENTREGADOR, true)
                    putExtra(MainActivity.EXTRA_ORDER_ID, orderId)
                }
                context.startActivity(openIntent)
                IncomingDeliveryRepository.aceitar(orderId) { ok, _ ->
                    if (!ok) {
                        IncomingDeliveryFlowState.markCancelled(requestId)
                    }
                    pendingResult.finish()
                }
            }
            IncomingDeliveryContract.ACTION_REJECT -> {
                NotificationUtils.cancelIncomingNotification(context, orderId)
                IncomingDeliveryFlowState.markRejected(requestId)
                IncomingDeliveryRepository.recusar(orderId) { ok, _ ->
                    if (!ok) {
                        IncomingDeliveryFlowState.markCancelled(requestId)
                    }
                    pendingResult.finish()
                }
            }
            else -> pendingResult.finish()
        }
    }
}

