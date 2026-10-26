FROM node:20-alpine

# Metadados
LABEL maintainer="kindle-dashboard"
LABEL description="Dashboard para Kindle e-ink rodando via KOReader"

WORKDIR /app

# Instala dependências
COPY backend/package.json ./
RUN npm install --omit=dev

# Copia código
COPY backend/server.js ./
COPY frontend/ ./frontend/

# Porta padrão
EXPOSE 3000

# Healthcheck interno
HEALTHCHECK --interval=60s --timeout=5s --retries=3 \
  CMD wget -qO- http://localhost:3000/api/health || exit 1

CMD ["node", "server.js"]
