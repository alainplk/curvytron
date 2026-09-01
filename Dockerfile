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

# Start server
CMD ["npm", "start"]
