#!/bin/sh
# ──────────────────────────────────────────────────────────────────────────────
# dashboard.sh — Kindle Dashboard Updater
# Roda no Kindle (jailbreak + KOReader). Busca o PNG do servidor e exibe
# na tela usando eips (framebuffer nativo do Kindle).
#
# Instalação:
#   1. Copie este arquivo para /mnt/us/dashboard/dashboard.sh no Kindle
#   2. chmod +x /mnt/us/dashboard/dashboard.sh
#   3. Configure o cron via KOReader (veja GUIA.md)
# ──────────────────────────────────────────────────────────────────────────────

SERVER_IP="192.168.0.7"
SERVER_PORT="3000"
DASHBOARD_DIR="/mnt/us/dashboard"
IMG_PATH="$DASHBOARD_DIR/dashboard.png"
IMG_TMP="$DASHBOARD_DIR/dashboard_tmp.png"
LOG_FILE="$DASHBOARD_DIR/dashboard.log"
BUSINESS_START=8
BUSINESS_END=22

log() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') $1" >> "$LOG_FILE"
}

is_business_hours() {
    hour=$(date '+%H' | sed 's/^0//')
    [ "$hour" -ge "$BUSINESS_START" ] && [ "$hour" -lt "$BUSINESS_END" ]
}

show_image() {
    eips -c
    eips -g "$IMG_PATH"
}

mkdir -p "$DASHBOARD_DIR"

if [ -f "$LOG_FILE" ] && [ "$(wc -l < "$LOG_FILE")" -gt 100 ]; then
    tail -50 "$LOG_FILE" > "$LOG_FILE.tmp" && mv "$LOG_FILE.tmp" "$LOG_FILE"
fi

log "Iniciando atualizacao"

if ! is_business_hours; then
    log "Fora do horario comercial - exibindo galeria do servidor"
fi

URL="http://$SERVER_IP:$SERVER_PORT/screenshot"
log "Buscando screenshot em $URL"

wget --timeout=25 --tries=2 --quiet -O "$IMG_TMP" "$URL"
WGET_STATUS=$?

if [ $WGET_STATUS -ne 0 ]; then
    log "ERRO: wget falhou com codigo $WGET_STATUS"
    if [ -f "$IMG_PATH" ]; then
        log "Mantendo imagem anterior"
        show_image
    fi
    exit 1
fi

MAGIC=$(dd if="$IMG_TMP" bs=1 count=4 2>/dev/null | od -A n -t x1 | tr -d ' ')
if [ "$MAGIC" != "89504e47" ]; then
    log "ERRO: arquivo baixado nao e um PNG valido"
    rm -f "$IMG_TMP"
    exit 1
fi

mv "$IMG_TMP" "$IMG_PATH"
log "PNG atualizado com sucesso ($(wc -c < "$IMG_PATH") bytes)"

show_image
log "Imagem exibida"

exit 0
