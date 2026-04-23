"use strict";

/**
 * Quando o cadastro do entregador é aprovado (entregador_status transita
 * para "aprovado" / "aprovada" / "ativo"), a selfie de verificação
 * (url_selfie_entregador) — tirada pela câmera no app — é promovida
 * automaticamente a foto de perfil (foto_perfil) e travada para sempre
 * (selfie_bloqueada = true). A partir daí o usuário não pode mais trocar
 * a própria foto de perfil: a verificação garante que a pessoa que aparece
 * no app é o titular da conta (medida antifraude).
 *
 * Idempotente: uma vez travada, a função não sobrescreve mais nada.
 */

const functions = require("firebase-functions/v1");
const admin = require("firebase-admin");

const STATUS_APROVADO = new Set(["aprovado", "aprovada", "ativo"]);

function normalizar(status) {
    return String(status || "").trim().toLowerCase();
}

exports.onEntregadorAprovadoPromoverSelfie = functions
    .region("us-central1")
    .firestore.document("users/{uid}")
    .onUpdate(async (change, context) => {
        const antes = change.before.data() || {};
        const depois = change.after.data() || {};
        const uid = context.params.uid;

        const statusAntes = normalizar(antes.entregador_status);
        const statusDepois = normalizar(depois.entregador_status);

        // Só age quando entra em "aprovado/ativo" agora.
        const viraAprovado =
            !STATUS_APROVADO.has(statusAntes) &&
            STATUS_APROVADO.has(statusDepois);
        if (!viraAprovado) return null;

        // Já travada? Nada a fazer — idempotência.
        if (depois.selfie_bloqueada === true) {
            console.log(
                `[selfie] ${uid} já está com selfie bloqueada — ignorando.`
            );
            return null;
        }

        const urlSelfie =
            String(depois.url_selfie_entregador || "").trim();
        if (!urlSelfie) {
            console.log(
                `[selfie] ${uid} aprovado sem url_selfie_entregador — ignorando.`
            );
            return null;
        }

        try {
            await admin.firestore().collection("users").doc(uid).update({
                foto_perfil: urlSelfie,
                selfie_status: "aprovada",
                selfie_bloqueada: true,
                selfie_aprovada_em:
                    admin.firestore.FieldValue.serverTimestamp(),
            });
            console.log(
                `[selfie] ${uid} selfie promovida a foto_perfil e travada.`
            );
        } catch (err) {
            console.error(
                `[selfie] falha ao promover selfie do entregador ${uid}:`,
                err
            );
        }
        return null;
    });
