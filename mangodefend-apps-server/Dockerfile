# Multi-stage Dockerfile for NestJS (mangodefend-apps-server)

# ------------------------------------------------------------------------------
# Stage 1: Build Stage
# ------------------------------------------------------------------------------
FROM node:22-alpine AS builder

WORKDIR /app

# Enable Corepack and pnpm@10
RUN corepack enable && corepack prepare pnpm@10 --activate

# Copy dependency manifests
COPY package.json pnpm-lock.yaml ./
COPY tsconfig*.json nest-cli.json ./

# Install all dependencies (including devDependencies for TypeScript compilation)
RUN pnpm install --frozen-lockfile

# Copy source code
COPY src ./src

# Build the NestJS application
RUN pnpm run build

# ------------------------------------------------------------------------------
# Stage 2: Production Runner Stage
# ------------------------------------------------------------------------------
FROM node:22-alpine AS runner

WORKDIR /app

ENV NODE_ENV=production
ENV PORT=4000

# Enable Corepack and pnpm@10
RUN corepack enable && corepack prepare pnpm@10 --activate

# Copy package manifests
COPY package.json pnpm-lock.yaml ./

# Install ONLY production dependencies
RUN pnpm install --prod --frozen-lockfile

# Copy compiled JavaScript from builder stage
COPY --from=builder /app/dist ./dist

# Expose port
EXPOSE 4000

# Run NestJS production entrypoint
CMD ["node", "dist/main.js"]
