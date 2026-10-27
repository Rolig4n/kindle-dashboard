FROM node:20-alpine

LABEL maintainer="kindle-dashboard"
LABEL description="Dashboard para Kindle e-ink rodando via KOReader"

WORKDIR /app

# Instala Chromium e fontes necessárias para o Puppeteer
RUN apk add --no-cache \
    chromium \
    nss \
    freetype \
    harfbuzz \
    ca-certificates \
    ttf-freefont \
    font-noto

# Diz ao Puppeteer para usar o Chromium do sistema em vez de baixar o próprio
ENV PUPPETEER_SKIP_CHROMIUM_DOWNLOAD=true
ENV CHROMIUM_PATH=/usr/bin/chromium-browser

# Instala dependências Node
COPY backend/package.json ./
RUN npm install --omit=dev

# Copia backend e frontend
COPY backend/server.js ./
COPY frontend/public/ ./frontend/public/

EXPOSE 3000

HEALTHCHECK --interval=60s --timeout=10s --retries=3 \
  CMD wget -qO- http://localhost:3000/api/health || exit 1

CMD ["node", "server.js"]
