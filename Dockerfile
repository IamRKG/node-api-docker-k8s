# ------------ Base Image ------------
    FROM node:18.20.2-alpine AS base
    WORKDIR /app
    ENV PATH /app/node_modules/.bin:$PATH
    
    # ------------ Dependencies Stage ------------
    FROM base AS deps
    COPY package*.json ./
    RUN npm ci --omit=dev
    
    # ------------ Builder Stage ------------
    FROM base AS builder
    
    ARG NODE_ENV=production
    ENV NODE_ENV=$NODE_ENV
    
    COPY --from=deps /app/node_modules ./node_modules
    COPY . .
    
    # Optional: load .env.[env] before build if needed
    # RUN cp .env.$NODE_ENV .env
    
    RUN npm run build
    
    # ------------ Final Runtime Stage ------------
    FROM node:18.20.2-alpine AS runner
    
    WORKDIR /app
    
    # Optional non-root user (security best practice)
    RUN addgroup -S app && adduser -S app -G app
    USER app
    
    # Only copy the output of `next build` + static assets
    COPY --from=builder /app/.next/standalone ./
    COPY --from=builder /app/.next/static ./.next/static
    COPY --from=builder /app/public ./public
    
    # Environment variables
    ENV NODE_ENV=production
    ENV PORT=3000
    ENV HOSTNAME=0.0.0.0
    
    EXPOSE 3000
    
    # Optional healthcheck for Kubernetes or Docker
    HEALTHCHECK --interval=30s --timeout=5s \
      CMD wget --no-verbose --tries=1 --spider http://localhost:3000/ || exit 1
    
    # Start the app
    CMD ["node", "server.js"]
    