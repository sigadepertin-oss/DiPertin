/**
 * Painel web — aba "Atualizações" (Gestão de Entregadores).
 *
 * Lista CNH/CRLV com status pendente para entregadores JÁ APROVADOS que
 * enviaram uma nova versão pelo app (troca de veículo, renovação de CNH/CRLV).
 *
 * Abordagem (sem collection group, sem índices frágeis):
 *   1. Busca `users` com role=entregador e entregador_status=aprovado
 *      (índice composto já existente).
 *   2. Para cada entregador aprovado, em paralelo:
 *        - lê users/{uid}/documentos/cnh
 *        - lista users/{uid}/veiculos e, para cada, veiculos/{vid}/documentos/crlv
 *   3. Filtra apenas docs com status == "pendente" e devolve.
 *
 * Essa implementação evita FAILED_PRECONDITION por índice de collection group
 * ausente (raiz do erro "INTERNAL" na aba Atualizações do painel).
 */
const functions = require("firebase-functions/v1");
const admin = require("firebase-admin");

/** Serialização defensiva para Timestamps/GeoPoints/DocumentReferences aninhados. */
function dadoParaJson(val) {
    if (val == null) return val;
    if (val instanceof admin.firestore.Timestamp) {
        return val.toDate().toISOString();
    }
    if (val instanceof admin.firestore.DocumentReference) {
        return val.path;
    }
    if (val instanceof admin.firestore.GeoPoint) {
        return { latitude: val.latitude, longitude: val.longitude };
    }
    if (Array.isArray(val)) {
        return val.map((x) => dadoParaJson(x));
    }
    if (typeof val === "object") {
        if (typeof val.toDate === "function") {
            try {
                return val.toDate().toISOString();
            } catch (_) {
                // continua
            }
        }
        if (val._seconds != null) {
            return new admin.firestore.Timestamp(
                val._seconds,
                val._nanoseconds || 0
            )
                .toDate()
                .toISOString();
        }
        const o = {};
        for (const [k, v] of Object.entries(val)) {
            o[k] = dadoParaJson(v);
        }
        return o;
    }
    return val;
}

function normRole(d) {
    return String(d?.role || d?.tipoUsuario || d?.tipo || "")
        .trim()
        .toLowerCase();
}

function isStaffUser(d) {
    const r = normRole(d);
    return (
        r === "master" ||
        r === "superadmin" ||
        r === "super_admin" ||
        r === "master_city"
    );
}

function isPendente(status) {
    return String(status || "").trim().toLowerCase() === "pendente";
}

/** Executa promessas em lotes para não estourar limite de conexões do Firestore. */
async function emLotes(itens, tamanhoLote, fn) {
    const resultados = [];
    for (let i = 0; i < itens.length; i += tamanhoLote) {
        const fatia = itens.slice(i, i + tamanhoLote);
        const r = await Promise.all(fatia.map(fn));
        resultados.push(...r);
    }
    return resultados;
}

async function coletarPendentesDoEntregador(db, uid, userData) {
    const itens = [];
    const cidade = String(userData?.cidade || "").trim();

    const cnhRef = db
        .collection("users")
        .doc(uid)
        .collection("documentos")
        .doc("cnh");
    const veiculosRef = db
        .collection("users")
        .doc(uid)
        .collection("veiculos");

    const [cnhSnap, veiculosSnap] = await Promise.all([
        cnhRef.get().catch(() => null),
        veiculosRef.get().catch(() => null),
    ]);

    if (cnhSnap && cnhSnap.exists) {
        const d = cnhSnap.data() || {};
        if (isPendente(d.status)) {
            itens.push({
                documentPath: cnhSnap.ref.path,
                uid,
                tipoDoc: "cnh",
                veiculoId: null,
                cidade,
                data: dadoParaJson(d),
            });
        }
    }

    if (veiculosSnap && !veiculosSnap.empty) {
        const veiculoIds = veiculosSnap.docs.map((x) => x.id);
        const crlvs = await emLotes(veiculoIds, 10, async (vid) => {
            const crlvRef = veiculosRef
                .doc(vid)
                .collection("documentos")
                .doc("crlv");
            const s = await crlvRef.get().catch(() => null);
            if (!s || !s.exists) return null;
            const d = s.data() || {};
            if (!isPendente(d.status)) return null;
            return {
                documentPath: s.ref.path,
                uid,
                tipoDoc: "crlv",
                veiculoId: vid,
                cidade,
                data: dadoParaJson(d),
            };
        });
        for (const x of crlvs) {
            if (x) itens.push(x);
        }
    }

    return itens;
}

exports.painelEntregadoresAtualizacoesPendentes = functions
    .runWith({
        timeoutSeconds: 120,
        memory: "512MB",
        // Painel web chama via HTTP direto (sem App Check).
        enforceAppCheck: false,
    })
    .https.onCall(async (data, context) => {
        try {
            if (!context.auth) {
                throw new functions.https.HttpsError(
                    "unauthenticated",
                    "Autenticação necessária."
                );
            }
            const db = admin.firestore();
            const callerSnap = await db
                .collection("users")
                .doc(context.auth.uid)
                .get();
            if (!callerSnap.exists) {
                throw new functions.https.HttpsError(
                    "permission-denied",
                    "Perfil não encontrado."
                );
            }
            const caller = callerSnap.data();
            if (!isStaffUser(caller)) {
                throw new functions.https.HttpsError(
                    "permission-denied",
                    "Apenas equipe administrativa."
                );
            }

            const callerRole = normRole(caller);
            let cidadesGerente = [];
            if (callerRole === "master_city") {
                const raw = caller.cidades_gerenciadas;
                if (Array.isArray(raw)) {
                    cidadesGerente = raw
                        .map((x) => String(x || "").trim())
                        .filter(Boolean);
                }
            }

            // Entregadores já APROVADOS — índice role+entregador_status já existe.
            const entregadoresSnap = await db
                .collection("users")
                .where("role", "==", "entregador")
                .where("entregador_status", "==", "aprovado")
                .get();

            const entregadoresFiltrados = [];
            for (const doc of entregadoresSnap.docs) {
                const u = doc.data() || {};
                if (cidadesGerente.length > 0) {
                    const c = String(u.cidade || "").trim();
                    if (!cidadesGerente.includes(c)) continue;
                }
                entregadoresFiltrados.push({ uid: doc.id, userData: u });
            }

            // Paraleliza por entregador (20 por vez).
            const blocos = await emLotes(
                entregadoresFiltrados,
                20,
                ({ uid, userData }) =>
                    coletarPendentesDoEntregador(db, uid, userData)
            );

            const items = [];
            const vistos = new Set();
            for (const bloco of blocos) {
                for (const row of bloco) {
                    if (vistos.has(row.documentPath)) continue;
                    vistos.add(row.documentPath);
                    items.push(row);
                }
            }

            items.sort((a, b) => {
                const ta = a.data?.atualizado_em;
                const tb = b.data?.atualizado_em;
                if (typeof ta === "string" && typeof tb === "string") {
                    return tb.localeCompare(ta);
                }
                if (typeof ta === "string") return -1;
                if (typeof tb === "string") return 1;
                return 0;
            });

            return { ok: true, items, total: items.length };
        } catch (e) {
            if (e instanceof functions.https.HttpsError) {
                throw e;
            }
            const msg = (e && e.message) || String(e);
            console.error("painelEntregadoresAtualizacoesPendentes", e);
            if (
                /FAILED_PRECONDITION|index|requires an index|create_composite/i.test(
                    msg
                )
            ) {
                throw new functions.https.HttpsError(
                    "failed-precondition",
                    "Índice do Firestore ausente ou em construção. " +
                        "Implante `firestore.indexes.json` e aguarde os índices ativarem."
                );
            }
            throw new functions.https.HttpsError(
                "internal",
                "Falha ao listar atualizações: " + msg
            );
        }
    });
