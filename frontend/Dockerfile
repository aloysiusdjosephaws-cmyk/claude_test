# Stage 1: Build Angular app
# NG_CONFIG=production  → uses environment.prod.ts (OCI API Gateway URL)
# NG_CONFIG=development → uses environment.ts     (relative /api paths, for K8s/local)
ARG NG_CONFIG=production
FROM node:20-alpine AS build
ARG NG_CONFIG
WORKDIR /app
COPY package.json package-lock.json* ./
RUN npm ci --legacy-peer-deps
COPY . .
RUN npx ng build --configuration=${NG_CONFIG}

# Stage 2: Serve with Nginx
FROM nginx:alpine
COPY --from=build /app/dist/frontend-client/browser /usr/share/nginx/html
COPY nginx.conf /etc/nginx/conf.d/default.conf
EXPOSE 80
