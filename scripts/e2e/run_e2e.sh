#!/usr/bin/env bash
# =============================================================================
# PEMTREE / Comunidad USAC · Runner para pruebas E2E (Flutter integration_test)
# =============================================================================
# Ejecuta cada archivo de integration_test/ en su PROPIO proceso 'flutter test'.
#
# ¿Por qué archivo por archivo? En Linux desktop, encadenar varios archivos en
# una sola invocación ('flutter test integration_test') suele fallar al lanzar
# la app con: "Error waiting for a debug connection: The log reader stopped
# unexpectedly". Correr cada archivo en un proceso separado es determinista.
#
# Variables de entorno:
#   SUPABASE_URL       (default: http://127.0.0.1:54321)
#   SUPABASE_ANON_KEY  (requerida)
#   FLUTTER_DEVICE     (default: linux)
# =============================================================================
set -euo pipefail

RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; BLUE='\033[0;34m'; NC='\033[0m'
info()    { echo -e "${BLUE}[INFO]${NC} $*"; }
success() { echo -e "${GREEN}[OK]${NC} $*"; }
warn()    { echo -e "${YELLOW}[WARN]${NC} $*"; }
error()   { echo -e "${RED}[ERROR]${NC} $*" >&2; }

SUPABASE_URL="${SUPABASE_URL:-http://127.0.0.1:54321}"
SUPABASE_ANON_KEY="${SUPABASE_ANON_KEY:-}"
FLUTTER_DEVICE="${FLUTTER_DEVICE:-linux}"

if [[ -z "$SUPABASE_ANON_KEY" ]]; then
    error "Falta SUPABASE_ANON_KEY. Exportala o pásala como variable de entorno."
    error "  supabase status   # copia la 'anon key'"
    exit 1
fi

if ! command -v flutter >/dev/null 2>&1; then
    error "Flutter no está instalado o no está en el PATH."
    exit 1
fi

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
APP_DIR="$ROOT_DIR/comunidad_universitaria"
cd "$APP_DIR"

if [[ ! -d integration_test ]]; then
    error "No se encontró '$APP_DIR/integration_test'."
    exit 1
fi

FILES=()
while IFS= read -r f; do
    FILES+=("$f")
done < <(find integration_test -maxdepth 1 -name '*_test.dart' | sort)

if [[ ${#FILES[@]} -eq 0 ]]; then
    error "No se encontraron archivos *_test.dart en integration_test/."
    exit 1
fi

info "Ejecutando ${#FILES[@]} archivos E2E en '$FLUTTER_DEVICE' contra $SUPABASE_URL"
FAILED=0
for f in "${FILES[@]}"; do
    info "== $f =="
    if flutter test "$f" -d "$FLUTTER_DEVICE" \
        --dart-define=SUPABASE_URL="$SUPABASE_URL" \
        --dart-define=SUPABASE_ANON_KEY="$SUPABASE_ANON_KEY"; then
        success "$f"
    else
        error "$f FALLÓ"
        FAILED=1
    fi
done

if [[ "$FAILED" -ne 0 ]]; then
    error "Una o más suites E2E fallaron."
    exit 1
fi
success "¡Todas las suites E2E pasaron!"
