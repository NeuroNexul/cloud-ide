ARG NODE_VERSION=20.18

# Alpine Linux with Node.js
FROM node:${NODE_VERSION}-alpine3.19 as alpine
RUN apk update
RUN apk add --no-cache libc6-compat python3 build-base

# Setup pnpm and turbo on the alpine base
FROM alpine as base
RUN npm install pnpm turbo --global
RUN pnpm config set store-dir ~/.pnpm-store

# Prune projects
FROM base AS pruner
ARG PROJECT

WORKDIR /app
COPY . .
RUN turbo prune --scope=${PROJECT} --docker

# Build the project
FROM base AS builder
ARG PROJECT

WORKDIR /app

# Copy lockfile and package.json's of isolated subworkspace
COPY --from=pruner /app/out/pnpm-lock.yaml ./pnpm-lock.yaml
COPY --from=pruner /app/out/pnpm-workspace.yaml ./pnpm-workspace.yaml
COPY --from=pruner /app/out/json/ .

# First install the dependencies (as they change less often)
RUN --mount=type=cache,id=pnpm,target=~/.pnpm-store pnpm install --frozen-lockfile

# Copy source code of isolated subworkspace
COPY --from=pruner /app/out/full/ .

RUN turbo build --filter=${PROJECT}
RUN --mount=type=cache,id=pnpm,target=~/.pnpm-store pnpm prune --prod --no-optional
RUN rm -rf ./**/*/src

# Final image
FROM alpine AS runner
ARG PROJECT

# Create a non-root user & a seperate directory for the user
RUN addgroup --system --gid 1001 nodejs
RUN adduser --system --uid 1001 nodejs
RUN mkdir -p /home/repl
RUN chown -R nodejs:nodejs /home/repl
USER nodejs

WORKDIR /app
COPY --from=builder --chown=nodejs:nodejs /app .
WORKDIR /app/apps/${PROJECT}

ARG PORT=8080
ENV PORT=${PORT}
ENV NODE_ENV=production
ENV CLIENT_URL=http://localhost:3000
ENV PROCESS_GID=1001
ENV PROCESS_UID=1001
ENV PROCESS_HOME=/home/repl
EXPOSE ${PORT}

# CMD node dist/main
CMD ["npm", "run", "start"]





# FROM base as builder

# WORKDIR /usr/src/app

# # Copy root package.json and lockfile
# COPY package.json ./
# COPY package-lock.json ./