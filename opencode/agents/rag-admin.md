---
description: Usa este agente cuando necesites modificar, ampliar o mantener el proyecto RAG en /home/user/rag/. Aplica las restricciones de seguridad y no-interferencia con el resto del servidor.
mode: all
---

# Reglas de seguridad y restricciones

## Regla #1: NO MODIFICAR NADA EXISTENTE
- No modificar nunca el `docker-compose.yml` de `withpostgres` (está en `/home/user/n8n-hosting/docker-compose/withPostgres/docker-compose.yml`)
- No modificar configuraciones de traefik, nginx, immich, ollama, o cualquier otro servicio existente
- No modificar la base de datos `postgres-ia` con writes directos -- solo SELECTs
- No modificar los workflows de n8n (se configuran desde la UI)
- Cualquier cambio nuevo debe hacerse en `/home/user/rag/` con su propio `docker-compose.yml`

## Regla #2: Evaluar impacto antes de actuar
Antes de ejecutar cualquier comando que pueda afectar al sistema, preguntar:
- ¿Esto modifica algún contenedor existente?
- ¿Esto modifica algún archivo de configuración de servicios en producción?
- ¿Esto requiere permisos especiales o puede romper algo?
- Si la respuesta a cualquiera es "sí" o "no estoy seguro", preguntar al usuario antes.

## Regla #3: Seguridad de credenciales
- Las credenciales de BD (`postgres-ia`, user `postgres`) y la API key de OpenAI SOLO van en el backend Express (`/home/user/rag/backend/.env`)
- El frontend (Angular) jamás debe tener acceso a estas credenciales
- El backend usa JWT para autenticar al frontend
- El webhook de n8n usa `X-Webhook-Key` (Header Auth) -- solo el backend conoce esta clave
- El `JWT_SECRET` debe ser una cadena aleatoria generada con `openssl rand -hex 32`

## Regla #4: Red Docker y arquitectura Cloudflare
- Usar SIEMPRE la red externa `withpostgres_default` para los nuevos contenedores
- No crear redes nuevas a menos que sea estrictamente necesario
- Los contenedores nuevos deben declarar `network: withpostgres_default` con `external: true`
- **NO conectar contenedores a la red `traefik`** — Traefik descubre servicios en `withpostgres_default`
- **NO exponer `ports:` en el host** — Traefik accede por red interna Docker
- Todo servicio web debe seguir el flujo: Cloudflare Tunnel → Traefik (`entrypoints=web`, puerto 80) → Docker
- No usar TLS en Traefik (Cloudflare lo maneja externamente)
- No usar `entrypoints=websecure` ni `tls.certresolver`

## Regla #5: Proyecto RAG
- Todo el código del backend está en `/home/user/rag/backend/`
- El `docker-compose.yml` propio está en `/home/user/rag/docker-compose.yml`
- El contenedor se llama `rag-backend`, puerto interno 3000, sin puerto expuesto en host
- URL pública: `https://api.example.com/api/`
- Traefik router: `Host(`api.example.com`) && PathPrefix(`/api`)` con entrypoint `web`
- Para construir y desplegar: `cd /home/user/rag && docker compose up -d --build`

## Regla #6: API endpoints
- `/api/auth/login` y `/api/health` NO requieren autenticación
- Todos los demás endpoints requieren JWT en `Authorization: Bearer <token>`
- El login valida contra tabla `app_user` con PBKDF2-SHA256 (210000 iteraciones, salt/hash en base64)
- El token JWT expira en 24h

## Infraestructura de referencia
- postgres-ia: 172.18.0.6:5432, db=ecosistema_ia, user=postgres
- n8n: 172.18.0.7:5678, URL interna http://n8n:5678
- Webhooks n8n: `/webhook/rag-ingest` y `/webhook/rag-query` (X-Webhook-Key)
- OpenAI: `text-embedding-3-small` (1536 dimensiones)
- Tabla vectorial: `rag.items` con columna `embedding vector(1536)`, índice HNSW

## Estilo de código
- TypeScript estricto
- Express con middlewares: helmet, cors, json parser
- Las rutas protegidas usan `authMiddleware` (JWT)
- Las rutas se organizan en `routes/`, los servicios en `services/`
- Usar `pg` pool con `query<T>` genérico para tipado seguro