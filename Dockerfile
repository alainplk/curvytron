# Stage 1: Build the application
FROM node:24-alpine AS builder

WORKDIR /app

# Install dependencies
COPY package*.json ./
RUN npm ci

# Copy source files and build client, server, styles and views
COPY . .
RUN npm run build

# Remove development dependencies to keep the production layer minimal
RUN npm prune --omit=dev

# Stage 2: Production runtime
FROM node:24-alpine AS runner

WORKDIR /app

ENV NODE_ENV=production

# Install security updates, dumb-init for clean signal & PID 1 management,
# and remove npm/corepack from runner to eliminate unnecessary attack surface & bundled vulnerabilities
RUN apk update && apk upgrade --no-cache && \
    apk add --no-cache dumb-init && \
    rm -rf /usr/local/lib/node_modules/npm /usr/local/bin/npm /usr/local/bin/npx /usr/local/bin/corepack /root/.npm

# Copy package metadata and production dependencies
COPY --chown=node:node --from=builder /app/package.json ./package.json
COPY --chown=node:node --from=builder /app/node_modules ./node_modules

# Copy built server bundle and web assets
COPY --chown=node:node --from=builder /app/bin ./bin
COPY --chown=node:node --from=builder /app/web ./web
COPY --chown=node:node --from=builder /app/config.json.sample ./config.json.sample

# Run as non-root user
USER node

# Expose default Curvytron port
EXPOSE 8020

# Health check to ensure the HTTP server is responsive
HEALTHCHECK --interval=30s --timeout=5s --start-period=5s --retries=3 \
  CMD node -e "require('http').get('http://localhost:8020', (res) => { process.exit(res.statusCode === 200 ? 0 : 1); }).on('error', () => process.exit(1));"

# Use dumb-init as init system to reap zombies and forward SIGTERM/SIGINT cleanly
ENTRYPOINT ["dumb-init", "--"]

# Start server directly with Node (avoiding npm as PID 1)
CMD ["node", "bin/curvytron.cjs"]

