#!/usr/bin/env bash
# =============================================================================
# PEMTREE / Comunidad USAC · Runner para pruebas de integración pgTAP (DB)
# =============================================================================
set -euo pipefail

# Colores para salida de terminal
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

info() {
    echo -e "${BLUE}[INFO]${NC} $*"
}

success() {
    echo -e "${GREEN}[OK]${NC} $*"
}

warn() {
    echo -e "${YELLOW}[WARN]${NC} $*"
}

error() {
    echo -e "${RED}[ERROR]${NC} $*" >&2
}

show_help() {
    cat << EOF
Uso: $0 [OPCIONES]

Ejecuta el conjunto de pruebas pgTAP en 'supabase/tests/' contra el stack local de Supabase.

Opciones:
  --reset       Ejecuta 'supabase db reset' antes de correr las pruebas para asegurar
                un esquema limpio con todas las migraciones aplicadas.
  --file <path> Ejecuta únicamente el archivo de prueba especificado.
  -h, --help    Muestra esta ayuda y finaliza.

Requisitos previos:
  - Docker daemon en ejecución.
  - Supabase CLI instalado (https://supabase.com/docs/guides/cli).
  - Stack local iniciado previamente con 'supabase start' (o usar --reset).

Ejemplos:
  $0
  $0 --reset
  $0 --file supabase/tests/posts_rls_test.sql
EOF
}

DO_RESET=false
TARGET_FILE=""

while [[ $# -gt 0 ]]; do
    case "$1" in
        --reset)
            DO_RESET=true
            shift
            ;;
        --file)
            if [[ -z "${2:-}" ]]; then
                error "La opción --file requiere una ruta de archivo."
                exit 1
            fi
            TARGET_FILE="$2"
            shift 2
            ;;
        -h|--help)
            show_help
            exit 0
            ;;
        *)
            error "Opción no reconocida: $1"
            show_help
            exit 1
            ;;
    esac
done

info "Iniciando verificaciones de entorno para pgTAP..."

# 1. Validar Docker
if ! command -v docker >/dev/null 2>&1; then
    error "Docker no está instalado o no se encuentra en el PATH del sistema."
    error "Por favor instala Docker Desktop / Engine: https://docs.docker.com/engine/install/"
    exit 1
fi

if ! docker info >/dev/null 2>&1; then
    error "El daemon de Docker no está activo o el usuario no tiene permisos suficientes."
    error "Verifica que el servicio de Docker esté corriendo ('sudo systemctl status docker')."
    exit 1
fi
success "Docker está disponible y en ejecución."

# 2. Validar Supabase CLI
if ! command -v supabase >/dev/null 2>&1; then
    error "Supabase CLI no está instalado en el sistema."
    error "Puedes instalarlo siguiendo: https://supabase.com/docs/guides/cli"
    error "  En Linux: brew install supabase/tap/supabase o curl -fsSL https://get.supabase.com | sh"
    exit 1
fi
success "Supabase CLI está instalado: $(supabase --version)"

# 3. Ubicarse en la raíz del repositorio
ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$ROOT_DIR"

if [[ ! -d "supabase/tests" ]]; then
    error "No se encontró el directorio de pruebas 'supabase/tests' en $ROOT_DIR."
    exit 1
fi

# 4. Reset condicional del esquema
if [ "$DO_RESET" = true ]; then
    info "Reiniciando base de datos local y reaplicando migraciones con 'supabase db reset'..."
    supabase db reset
    success "Esquema local reiniciado y sincronizado con éxito."
fi

# 5. Ejecución de pruebas pgTAP
info "Ejecutando pruebas pgTAP con 'supabase test db'..."

if [[ -n "$TARGET_FILE" ]]; then
    info "Ejecutando archivo individual: $TARGET_FILE"
    # supabase test db admite pasar archivos individuales o flags adicionales
    supabase test db --debug || {
        error "Las pruebas en $TARGET_FILE fallaron."
        exit 1
    }
else
    supabase test db || {
        error "Una o más pruebas de integración pgTAP fallaron."
        exit 1
    }
fi

success "¡Todas las pruebas pgTAP completaron exitosamente!"
