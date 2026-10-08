# --- Stage 1: install production dependencies ------------------------------
FROM node:24-alpine AS deps
WORKDIR /app
COPY package*.json ./
RUN if [ -f package-lock.json ]; then npm ci --omit=dev; else npm install --omit=dev; fi \
    && npm cache clean --force

# --- Stage 2: minimal runtime image ----------------------------------------
FROM node:24-alpine AS runtime

ENV NODE_ENV=production \
    PORT=4000

WORKDIR /app

# Run as an unprivileged user (never as root).
RUN addgroup -S app && adduser -S app -G app

COPY --from=deps /app/node_modules ./node_modules
COPY package.json server.js ./
COPY src ./src

USER app

EXPOSE 4000

HEALTHCHECK --interval=30s --timeout=3s --start-period=5s --retries=3 \
  CMD node -e "require('http').get('http://127.0.0.1:'+(process.env.PORT||4000)+'/healthz',r=>process.exit(r.statusCode===200?0:1)).on('error',()=>process.exit(1))"

CMD ["node", "server.js"]
