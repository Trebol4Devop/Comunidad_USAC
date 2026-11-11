# Moderation Worker (Edge Function)

Worker automatizado para el procesamiento asíncrono y concurrente de la cola `public.moderation_jobs`, diseñado para la prevención de ciberdelitos (Art. 13/16) y cumplimiento de privacidad (Art. 12).

## Arquitectura de Moderación en Dos Capas

### Capa 1 — Detección Determinista (Regex)
Evalúa de manera inmediata patrones críticos con alta certeza (`confidence >= 0.90`), teniendo precedencia sobre la capa semántica:
- **`DOXXING_PII`**:
  - Números de teléfono de Guatemala (8 dígitos: `\b[2-7]\d{3}[-\s]?\d{4}\b`).
  - Códigos Únicos de Identificación (CUI / DPI de 13 dígitos: `\b\d{4}[-\s]?\d{5}[-\s]?\d{4}\b`).
  - Carnés universitarios USAC expuestos.
  - *Nota*: En `marketplace_items`, los campos de contacto autorizados (`contact_whatsapp`, `contact_telegram`) están exentos de escaneo.
- **`ACCESS_ABUSE_PIRACY`**:
  - Credenciales en texto claro (`password :=`, `contraseña`, `usuario:`).
  - Enlaces con acortadores ofuscados (`bit.ly`, `tinyurl.com`, `t.co`, `goo.gl`, `cutt.ly`).
  - Herramientas de hacking, cracks, dumps y explotación (`crack`, `keygen`, `dump sql`, `contraseña wifi`, `cuenta hackeada`, `acceso ilegal`, `base de datos filtrada`, `serial`, `activador`).

### Capa 2 — Clasificador Semántico (LLM con Fallback Heurístico Local)
- **Modo LLM**: Si `MODERATION_LLM_URL` y `MODERATION_LLM_API_KEY` están configurados, invoca un modelo compatible con OpenAI Chat Completions exigiendo formato JSON estructurado `{ label, confidence, reason }`.
- **Modo Heurístico Local**: Si no hay LLM configurado o la llamada de red falla, se activa automáticamente un clasificador determinista local basado en palabras clave y normalización léxica sin acentos.

### Veredictos y Estados de Moderación
| Etiqueta | Confianza | Moderation Status | Acción |
| :--- | :--- | :--- | :--- |
| `SAFE_CAMPUS_HUMOR` | Cualquier | `0` (Visible) | Trabajo marcado como completado (`done`). |
| Cualquier categoría de riesgo | `0.50 <= conf < 0.80` | `1` (En Revisión) | Cola humana de moderación. Contenido original inalterado. |
| Cualquier categoría de riesgo | `conf >= 0.80` | `2` (Oculto) | Ocultamiento automático. Registro obligatorio en `moderation_audit_log`. |
| `SEVERE_THREAT_FRAUD` o `ACCESS_ABUSE_PIRACY` | `conf >= 0.80` | `2` (Oculto) | Además se activa `is_legal_hold = true` (bloqueo legal inmutable). |

> [!IMPORTANT]
> El worker **NUNCA** modifica el contenido original (`title`, `content`, `description`). Únicamente actualiza columnas de moderación y retención legal.

## Variables de Entorno

| Variable | Requerida | Descripción |
| :--- | :--- | :--- |
| `WORKER_SECRET` | Sí (fail-closed) | Token secreto para autorizar invocaciones al endpoint. Si falta, el worker responde 500 y no procesa. |
| `SUPABASE_URL` | Sí | URL del proyecto Supabase. |
| `SUPABASE_SERVICE_ROLE_KEY` | Sí | Clave service_role para reclamar jobs y actualizar entidades con bypass RLS. |
| `MODERATION_LLM_URL` | Opcional | Endpoint OpenAI compatible para clasificación semántica. |
| `MODERATION_LLM_API_KEY` | Opcional | API Key para el LLM externo. |

## Concurrencia y Resiliencia
- Reclamo atómico mediante la función RPC `public.claim_moderation_jobs(p_worker_id, p_limit)` utilizando `FOR UPDATE SKIP LOCKED`.
- Reintentos con backoff proporcional al número de intentos (`attempts * 1 minute`).
- Desbloqueo automático de jobs huérfanos o colgados con más de 10 minutos en estado `processing`.
