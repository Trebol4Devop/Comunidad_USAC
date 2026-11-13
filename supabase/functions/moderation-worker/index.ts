import { createClient, type SupabaseClient } from "https://esm.sh/@supabase/supabase-js@2";

export type ModerationLabel =
  | "IMPERSONATION"
  | "SEVERE_THREAT_FRAUD"
  | "DOXXING_PII"
  | "ACCESS_ABUSE_PIRACY"
  | "SAFE_CAMPUS_HUMOR";

export interface ModerationVerdict {
  label: ModerationLabel;
  confidence: number;
  reason: string;
}

export interface ModerationJob {
  id: string;
  entity_table: "posts" | "comments" | "student_groups" | "marketplace_items";
  entity_id: string;
  content_hash: string;
  has_image: boolean;
  priority: number;
  status: "pending" | "processing" | "done" | "failed";
  attempts: number;
  max_attempts: number;
  run_after: string;
  locked_by: string | null;
  locked_at: string | null;
  last_error: string | null;
  created_at: string;
  updated_at: string;
}

export interface WorkerBatchResult {
  claimed: number;
  processed: number;
  failed: number;
  details: Array<{
    jobId: string;
    entityTable: string;
    entityId: string;
    status: "done" | "failed";
    verdict?: ModerationVerdict;
    error?: string;
  }>;
}

/**
 * Capa 1: Reglas deterministas basadas en expresiones regulares.
 * Prevalece sobre el análisis semántico cuando detecta evidencia inequívoca
 * de exposición de datos personales (PII) o infracciones del Art. 13/16 (Ciberdelitos).
 */
export function evaluateLayer1Regex(text: string): ModerationVerdict | null {
  if (!text || text.trim() === "") {
    return null;
  }

  // 1. DOXXING_PII
  // Teléfonos GT de 8 dígitos que inician con 2-7
  const phoneGtRegex = /\b[2-7]\d{3}[-\s]?\d{4}\b/;
  // CUI de 13 dígitos
  const cuiRegex = /\b\d{4}[-\s]?\d{5}[-\s]?\d{4}\b/;
  // Carné universitario USAC (5 a 10 dígitos)
  const carnetWithContextRegex = /\b(?:carn[eé]|carnet|registro|cui|dpi|no\.?|id|padron)?\s*[:#-]?\s*\b\d{5,10}\b/i;

  if (phoneGtRegex.test(text)) {
    return {
      label: "DOXXING_PII",
      confidence: 0.95,
      reason: "Capa 1: Detección determinista de número telefónico de Guatemala expuesto (PII)",
    };
  }

  if (cuiRegex.test(text)) {
    return {
      label: "DOXXING_PII",
      confidence: 0.95,
      reason: "Capa 1: Detección determinista de CUI de 13 dígitos expuesto (PII)",
    };
  }

  if (carnetWithContextRegex.test(text) && /\b\d{5,10}\b/.test(text)) {
    const hasCarnetContext = /\b(?:carn[eé]|carnet|estudiante|registro|matricula|sancarlista)\b/i.test(text);
    const hasYearFormat = /\b(19\d{2}|20\d{2})\d{5}\b/.test(text);
    if (hasCarnetContext || hasYearFormat) {
      return {
        label: "DOXXING_PII",
        confidence: 0.92,
        reason: "Capa 1: Detección determinista de carné universitario expuesto",
      };
    }
  }

  // 2. ACCESS_ABUSE_PIRACY (Art. 13/16)
  // Credenciales expuestas
  const credsRegex = /(?:password|contrase[ñn]a)\s*[:=]|usuario\s*:\s*\S+/i;
  if (credsRegex.test(text)) {
    return {
      label: "ACCESS_ABUSE_PIRACY",
      confidence: 0.95,
      reason: "Capa 1: Detección determinista de credenciales de acceso expuestas (Art. 13/16)",
    };
  }

  // Enlaces a servicios de acortadores
  const shortenersRegex = /\b(?:bit\.ly|tinyurl\.com|tinyurl|t\.co|goo\.gl|cutt\.ly)\/[a-zA-Z0-9_-]+/i;
  if (shortenersRegex.test(text)) {
    return {
      label: "ACCESS_ABUSE_PIRACY",
      confidence: 0.90,
      reason: "Capa 1: Enlace a acortador sospechoso detectado",
    };
  }

  // Herramientas de hacking, piratería y explotación
  const highRiskHackingRegex =
    /\b(crack|keygen|dump sql|contrase[ñn]a wifi|cuenta hackeada|acceso ilegal|base de datos filtrada|serial|activador)\b/i;
  if (highRiskHackingRegex.test(text)) {
    return {
      label: "ACCESS_ABUSE_PIRACY",
      confidence: 0.95,
      reason: "Capa 1: Detección de herramientas de explotación, acceso ilegal o piratería (Art. 13/16)",
    };
  }

  return null;
}

/**
 * Consulta a endpoint compatible con OpenAI chat/completions para clasificación semántica.
 */
async function queryLlmClassifier(
  text: string,
  url: string,
  apiKey: string,
): Promise<ModerationVerdict | null> {
  const prompt = `Analiza el siguiente texto de una plataforma universitaria sancarlista (USAC) y clasifícalo en exactamente una de estas categorías:
1. "IMPERSONATION": Suplantación de identidad de autoridades, docentes o estudiantes.
2. "SEVERE_THREAT_FRAUD": Amenazas de violencia física, venta de cursos/exámenes, estafas económicas, extorsión.
3. "DOXXING_PII": Publicación no consentida de información personal (teléfonos, CUI, carné, domicilios).
4. "ACCESS_ABUSE_PIRACY": Hacking, credenciales robadas, dumps SQL, cracks, keygens, vulneración de sistemas USAC.
5. "SAFE_CAMPUS_HUMOR": Humor estudiantil sano, anécdotas universitarias, dudas de cursos, memes, avisos legítimos.

Responde ÚNICAMENTE en JSON con la estructura:
{"label": "CATEGORIA", "confidence": 0.0 a 1.0, "reason": "breve justificacion en espanol"}

Texto:
"${text.replace(/"/g, '\\"')}"`;

  const response = await fetch(url, {
    method: "POST",
    headers: {
      "Content-Type": "application/json",
      Authorization: `Bearer ${apiKey}`,
    },
    body: JSON.stringify({
      messages: [
        {
          role: "system",
          content: "Eres un moderador de seguridad y cumplimiento legal para una comunidad universitaria.",
        },
        { role: "user", content: prompt },
      ],
      temperature: 0.1,
    }),
  });

  if (!response.ok) {
    throw new Error(`LLM API error: status ${response.status}`);
  }

  const data = await response.json();
  const rawContent = data.choices?.[0]?.message?.content;
  if (!rawContent || typeof rawContent !== "string") {
    return null;
  }

  const jsonMatch = rawContent.match(/\{[\s\S]*\}/);
  if (!jsonMatch) {
    return null;
  }

  const parsed = JSON.parse(jsonMatch[0]);
  const validLabels: ModerationLabel[] = [
    "IMPERSONATION",
    "SEVERE_THREAT_FRAUD",
    "DOXXING_PII",
    "ACCESS_ABUSE_PIRACY",
    "SAFE_CAMPUS_HUMOR",
  ];

  if (validLabels.includes(parsed.label) && typeof parsed.confidence === "number") {
    return {
      label: parsed.label,
      confidence: Math.max(0, Math.min(1, parsed.confidence)),
      reason: String(parsed.reason || "Clasificación semántica LLM"),
    };
  }

  return null;
}

/**
 * Clasificador heurístico local determinista de respaldo cuando no hay LLM configurado o falla.
 */
export function evaluateLocalHeuristic(text: string): ModerationVerdict {
  const norm = text.toLowerCase().normalize("NFD").replace(/[\u0300-\u036f]/g, "");

  // 1. Amenazas graves y fraudes
  const threatMatches = /\b(te voy a matar|moriras|sicario|secuestro|bomba|atentado|balazos|plomo)\b/i.test(norm);
  const fraudMatches =
    /\b(vender examen|vendo examen|ganar curso pagando|tramite de titulo|titulo falso|clonar tarjeta|deposito por adelantado|gana dinero facil|estafa piramidal)\b/i.test(
      norm,
    );

  if (threatMatches) {
    return {
      label: "SEVERE_THREAT_FRAUD",
      confidence: 0.95,
      reason: "Capa 2 (Heurística): Detección de amenaza grave contra la integridad física",
    };
  }
  if (fraudMatches) {
    return {
      label: "SEVERE_THREAT_FRAUD",
      confidence: 0.90,
      reason: "Capa 2 (Heurística): Detección de fraude académico o financiero",
    };
  }

  // 2. Suplantación de autoridades o docentes
  const impersonationMatches =
    /\b(soy el rector|cuenta oficial usac|junta directiva oficial|soy catedratico titular|administrador oficial|comunicado oficial de decanatura)\b/i.test(
      norm,
    );
  if (impersonationMatches) {
    return {
      label: "IMPERSONATION",
      confidence: 0.88,
      reason: "Capa 2 (Heurística): Patrón de suplantación de identidad docente o institucional",
    };
  }

  // 3. Ciberdelitos y abuso de acceso
  const accessMatches =
    /\b(hackear portal|vulnerabilidad siif|inyeccion sql|bot asignacion|script matricula|robar contrasena)\b/i.test(
      norm,
    );
  if (accessMatches) {
    return {
      label: "ACCESS_ABUSE_PIRACY",
      confidence: 0.85,
      reason: "Capa 2 (Heurística): Patrón de abuso de sistemas informáticos o hacking",
    };
  }

  // 4. Exposición de PII
  const doxxingMatches =
    /\b(direccion de su casa|vive en|aqui les dejo sus datos|numero privado|datos personales de)\b/i.test(
      norm,
    );
  if (doxxingMatches) {
    return {
      label: "DOXXING_PII",
      confidence: 0.85,
      reason: "Capa 2 (Heurística): Divulgación no autorizada de datos personales",
    };
  }

  // 5. Señales ambiguas o sospechosas que requieren revisión humana (0.50 <= conf < 0.80)
  const suspiciousMatches = /\b(examen resuelto|copia de parcial|hack|tramite sospechoso|pagar auxiliar)\b/i.test(
    norm,
  );
  if (suspiciousMatches) {
    return {
      label: "SEVERE_THREAT_FRAUD",
      confidence: 0.65,
      reason: "Capa 2 (Heurística): Contenido potencialmente riesgoso para revisión humana",
    };
  }

  // 6. Contenido estudiantil seguro por defecto
  return {
    label: "SAFE_CAMPUS_HUMOR",
    confidence: 0.95,
    reason: "Capa 2 (Heurística): Contenido clasificado como discurso estudiantil legítimo",
  };
}

/**
 * Capa 2: Clasificación semántica con LLM o fallback heurístico.
 */
export async function evaluateLayer2(text: string): Promise<ModerationVerdict> {
  const llmUrl = Deno.env.get("MODERATION_LLM_URL");
  const llmApiKey = Deno.env.get("MODERATION_LLM_API_KEY");

  if (llmUrl && llmApiKey) {
    try {
      const verdict = await queryLlmClassifier(text, llmUrl, llmApiKey);
      if (verdict) {
        return verdict;
      }
    } catch (err) {
      console.warn("Moderation LLM unreachable or failed, falling back to local heuristic:", err);
    }
  }

  return evaluateLocalHeuristic(text);
}

/**
 * Pipeline de procesamiento individual por job de moderación.
 */
async function processJob(supabase: SupabaseClient, job: ModerationJob): Promise<ModerationVerdict> {
  let text = "";

  if (job.entity_table === "posts") {
    const { data: post, error } = await supabase
      .from("posts")
      .select("title, content")
      .eq("id", job.entity_id)
      .maybeSingle();
    if (error) throw error;
    if (!post) {
      return {
        label: "SAFE_CAMPUS_HUMOR",
        confidence: 1.0,
        reason: "Entidad ya no existe en la base de datos (eliminada)",
      };
    }
    text = `${post.title || ""} ${post.content || ""}`;
  } else if (job.entity_table === "comments") {
    const { data: comment, error } = await supabase
      .from("comments")
      .select("content")
      .eq("id", job.entity_id)
      .maybeSingle();
    if (error) throw error;
    if (!comment) {
      return {
        label: "SAFE_CAMPUS_HUMOR",
        confidence: 1.0,
        reason: "Entidad ya no existe en la base de datos (eliminada)",
      };
    }
    text = comment.content || "";
  } else if (job.entity_table === "student_groups") {
    const { data: group, error } = await supabase
      .from("student_groups")
      .select("title, description, link, curso")
      .eq("id", job.entity_id)
      .maybeSingle();
    if (error) throw error;
    if (!group) {
      return {
        label: "SAFE_CAMPUS_HUMOR",
        confidence: 1.0,
        reason: "Entidad ya no existe en la base de datos (eliminada)",
      };
    }
    text = `${group.title || ""} ${group.description || ""} ${group.link || ""} ${group.curso || ""}`;
  } else if (job.entity_table === "marketplace_items") {
    const { data: item, error } = await supabase
      .from("marketplace_items")
      .select("title, description, video_url")
      .eq("id", job.entity_id)
      .maybeSingle();
    if (error) throw error;
    if (!item) {
      return {
        label: "SAFE_CAMPUS_HUMOR",
        confidence: 1.0,
        reason: "Entidad ya no existe en la base de datos (eliminada)",
      };
    }
    // REGLA: NO escanear contact_whatsapp ni contact_telegram
    text = `${item.title || ""} ${item.description || ""} ${item.video_url || ""}`;
  } else {
    throw new Error(`Tabla de entidad no soportada: ${job.entity_table}`);
  }

  // Evaluación Capa 1 vs Capa 2
  const layer1Verdict = evaluateLayer1Regex(text);
  let verdict: ModerationVerdict;

  if (layer1Verdict && layer1Verdict.confidence >= 0.90) {
    verdict = layer1Verdict;
  } else {
    verdict = await evaluateLayer2(text);
  }

  // Aplicación del veredicto según umbrales de confianza
  const nowIso = new Date().toISOString();
  let newModerationStatus = 0;
  let applyLegalHold = false;

  if (verdict.label === "SAFE_CAMPUS_HUMOR") {
    newModerationStatus = 1; // Aprobado
  } else if (verdict.confidence >= 0.50 && verdict.confidence < 0.80) {
    newModerationStatus = 3; // Cola de revisión humana
  } else if (verdict.confidence >= 0.80) {
    newModerationStatus = 2; // Ocultado automático
    if (verdict.label === "SEVERE_THREAT_FRAUD" || verdict.label === "ACCESS_ABUSE_PIRACY") {
      applyLegalHold = true;
    }
  } else {
    newModerationStatus = 0;
  }

  // NUNCA alterar title, content o description. Únicamente metadatos de moderación y legal hold.
  const updatePayload: Record<string, unknown> = {
    moderation_status: newModerationStatus,
    moderation_label: verdict.label,
    moderation_confidence: verdict.confidence,
    moderation_reason: verdict.reason,
    moderated_at: nowIso,
    updated_at: nowIso,
  };

  if (applyLegalHold) {
    updatePayload.is_legal_hold = true;
  }

  const { error: updateEntityErr } = await supabase
    .from(job.entity_table)
    .update(updatePayload)
    .eq("id", job.entity_id);

  if (updateEntityErr) {
    throw updateEntityErr;
  }

  // Si confidence >= 0.80, registrar auditoría automática obligatoria
  if (verdict.confidence >= 0.80 && verdict.label !== "SAFE_CAMPUS_HUMOR") {
    const { error: auditErr } = await supabase
      .from("moderation_audit_log")
      .insert({
        moderator_id: null,
        entity_table: job.entity_table,
        entity_id: job.entity_id,
        justification: verdict.reason,
        is_automated: true,
        moderation_label: verdict.label,
        confidence: verdict.confidence,
        created_at: nowIso,
      });

    if (auditErr) {
      console.error("Error al registrar entrada en moderation_audit_log:", auditErr);
    }
  }

  // Marcar trabajo como completado ('done')
  const { error: completeJobErr } = await supabase
    .from("moderation_jobs")
    .update({
      status: "done",
      locked_by: null,
      locked_at: null,
      updated_at: nowIso,
    })
    .eq("id", job.id);

  if (completeJobErr) {
    throw completeJobErr;
  }

  return verdict;
}

/**
 * Manejo de errores de jobs con backoff exponencial y registro del último error.
 */
async function handleJobFailure(
  supabase: SupabaseClient,
  job: ModerationJob,
  err: unknown,
): Promise<void> {
  const errorMsg = err instanceof Error ? err.message : String(err);
  const attempts = job.attempts;
  const maxAttempts = job.max_attempts || 5;
  const isFinalFailure = attempts >= maxAttempts;
  const now = Date.now();
  // Backoff: attempts * 1 minuto
  const backoffMs = attempts * 60 * 1000;
  const runAfter = new Date(now + backoffMs).toISOString();
  const nowIso = new Date(now).toISOString();

  await supabase
    .from("moderation_jobs")
    .update({
      status: isFinalFailure ? "failed" : "pending",
      last_error: errorMsg.slice(0, 1000),
      run_after: isFinalFailure ? job.run_after : runAfter,
      locked_by: null,
      locked_at: null,
      updated_at: nowIso,
    })
    .eq("id", job.id);
}

// Handler HTTP principal del Edge Function Worker
Deno.serve(async (req: Request) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", {
      headers: {
        "Access-Control-Allow-Origin": "*",
        "Access-Control-Allow-Headers": "authorization, x-worker-secret, content-type",
      },
    });
  }

  // 1. Verificación de seguridad (fail-closed)
  const expectedSecret = Deno.env.get("WORKER_SECRET") || "";
  const authHeader = req.headers.get("authorization") || "";
  const xSecretHeader = req.headers.get("x-worker-secret") || "";

  let bearerToken = "";
  if (authHeader.toLowerCase().startsWith("bearer ")) {
    bearerToken = authHeader.slice(7).trim();
  }

  // El endpoint nunca debe quedar abierto: sin secreto configurado no procesa.
  if (!expectedSecret) {
    return new Response(
      JSON.stringify({ error: "WORKER_SECRET is not configured; worker disabled" }),
      { status: 500, headers: { "Content-Type": "application/json" } },
    );
  }

  // 2. Cliente de Supabase con service_role
  const supabaseUrl = Deno.env.get("SUPABASE_URL") || "";
  const supabaseKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") || "";

  const isAuthorized = bearerToken === expectedSecret ||
    xSecretHeader === expectedSecret ||
    (supabaseKey.length > 0 && bearerToken === supabaseKey);
  if (!isAuthorized) {
    return new Response(JSON.stringify({ error: "Unauthorized" }), {
      status: 401,
      headers: { "Content-Type": "application/json" },
    });
  }
  if (!supabaseUrl || !supabaseKey) {
    return new Response(
      JSON.stringify({ error: "Missing SUPABASE_URL or SUPABASE_SERVICE_ROLE_KEY" }),
      {
        status: 500,
        headers: { "Content-Type": "application/json" },
      },
    );
  }

  const supabase = createClient(supabaseUrl, supabaseKey, {
    auth: { persistSession: false, autoRefreshToken: false },
  });

  // 3. Obtener límite opcional del cuerpo JSON
  let limit = 10;
  if (req.method === "POST") {
    try {
      const body = await req.json();
      if (typeof body?.limit === "number" && body.limit > 0) {
        limit = Math.min(body.limit, 100);
      }
    } catch {
      // Ignorar si el body está vacío o no es un JSON válido
    }
  }

  const workerId = `worker-${crypto.randomUUID()}`;

  // 4. Reclamar concurrentemente jobs pendientes
  const { data: claimedJobs, error: claimErr } = await supabase.rpc("claim_moderation_jobs", {
    p_worker_id: workerId,
    p_limit: limit,
  });

  if (claimErr) {
    return new Response(JSON.stringify({ error: "Failed to claim jobs", details: claimErr.message }), {
      status: 500,
      headers: { "Content-Type": "application/json" },
    });
  }

  const jobs = (claimedJobs || []) as ModerationJob[];
  const result: WorkerBatchResult = {
    claimed: jobs.length,
    processed: 0,
    failed: 0,
    details: [],
  };

  // 5. Procesamiento del lote
  for (const job of jobs) {
    try {
      const verdict = await processJob(supabase, job);
      result.processed += 1;
      result.details.push({
        jobId: job.id,
        entityTable: job.entity_table,
        entityId: job.entity_id,
        status: "done",
        verdict,
      });
    } catch (err) {
      result.failed += 1;
      await handleJobFailure(supabase, job, err);
      result.details.push({
        jobId: job.id,
        entityTable: job.entity_table,
        entityId: job.entity_id,
        status: "failed",
        error: err instanceof Error ? err.message : String(err),
      });
    }
  }

  return new Response(JSON.stringify(result), {
    status: 200,
    headers: { "Content-Type": "application/json" },
  });
});
