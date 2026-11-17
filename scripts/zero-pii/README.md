# Purga de Objetos Legacy en Cloudflare R2 (Modelo Zero-PII)

Este directorio contiene las herramientas y el procedimiento operativo para auditar y purgar definitivamente todos los objetos de almacenamiento vinculados a identificadores personales (PII) o documentos legacy de verificación (DPI frente, DPI reverso, constancias y carnés físicos) almacenados en Cloudflare R2.

---

## 1. Exportación previa de claves R2

Antes de ejecutar la migración destructiva o purga de la base de datos, exporte las referencias a los objetos existentes ejecutando el script `00_export_r2_keys.sql`:

```bash
# Conectado a la base de datos de producción o staging:
psql "$DATABASE_URL" -f scripts/zero-pii/00_export_r2_keys.sql > r2_legacy_keys.csv
```

El archivo resultante `r2_legacy_keys.csv` tendrá el siguiente encabezado y formato:

```csv
r2_key,source_table,request_id
pending/merchant/88000000-.../dpi_front.jpg,merchant_verification_requests,88000000-...
pending/merchant/88000000-.../dpi_back.jpg,merchant_verification_requests,88000000-...
pending/77000000-.../doc.jpg,verification_requests,77000000-...
```

---

## 2. Requisitos previos para la purga en Cloudflare R2

1. **Wrangler CLI** instalado y autenticado:
   ```bash
   npx wrangler login
   # O mediante token de API en variables de entorno:
   export CLOUDFLARE_ACCOUNT_ID="<tu_account_id>"
   export CLOUDFLARE_API_TOKEN="<tu_api_token>"
   ```
2. **Nombre del bucket de R2**:
   ```bash
   export R2_BUCKET_NAME="comunidad-usac-verification"
   ```

---

## 3. Ejecución de la purga de objetos

### Opción A: Script Bash automatizado

Ejecute el siguiente bloque en su terminal para iterar y eliminar cada objeto registrado en el CSV:

```bash
#!/usr/bin/env bash
set -euo pipefail

CSV_FILE="r2_legacy_keys.csv"
BUCKET="${R2_BUCKET_NAME:-comunidad-usac-verification}"

if [ ! -f "$CSV_FILE" ]; then
    echo "Error: No se encontró $CSV_FILE"
    exit 1
fi

echo "Iniciando purga de objetos R2 en el bucket: $BUCKET"

# Omitir el encabezado del CSV y procesar la primera columna (r2_key)
tail -n +2 "$CSV_FILE" | cut -d',' -f1 | while IFS= read -r key; do
    # Limpiar retornos de carro o espacios
    key=$(echo "$key" | tr -d '\r\n[:space:]')
    if [ -n "$key" ]; then
        echo "Purgando objeto: $BUCKET/$key"
        npx wrangler r2 object delete "$BUCKET/$key" || echo "Aviso: no se pudo eliminar $key (posiblemente ya no existe)"
    fi
done

echo "Purga de objetos R2 finalizada exitosamente."
```

### Opción B: Purga individual

Para eliminar un objeto específico manualmente:

```bash
npx wrangler r2 object delete "<BUCKET_NAME>/<r2_key>"
```

Ejemplo:
```bash
npx wrangler r2 object delete comunidad-usac-verification/pending/merchant/88000000-0000-0000-0000-000000000001/88000000-0000-0000-0000-000000000001/dpi_front.jpg
```

---

## 4. Invariantes del Modelo Zero-PII en Almacenamiento

- **DPI**: Se prohíbe terminantemente la subida y retención de fotografías de documentos nacionales de identidad (DPI) en cualquier bucket o ruta.
- **Establecimientos comerciales**: Solo se almacena `establishment_key` durante la revisión manual, y se limpia a `NULL` tras la decisión mediante el RPC `public.admin_clear_merchant_keys(uuid)`.
- **Estudiantes**: Las constancias de inscripción y carnés con auto-aprobación nunca persisten claves en R2 (`r2_object_key = NULL`). En caso de revisión manual, se borran tras la resolución.
