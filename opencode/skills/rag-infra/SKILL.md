---
name: rag-infra
description: Use ONLY when the user asks about the RAG backend, vector database, n8n webhooks, or the Node/Express API at /home/juanferca/rag/. Covers postgres-ia, rag.items, app_user, rag-backend, and the two n8n workflows for PDF ingestion and semantic search.
---

# RAG Infrastructure & Backend

## Project Location
- Backend: `/home/juanferca/rag/`
- Docker compose: `docker-compose.example.yml` (template, renombrar a `docker-compose.yml` y ajustar)
- Dockerfile: `/home/juanferca/rag/backend/Dockerfile`
- Workflows JSON: `/tmp/opencode/rag-n8n/` (backup)

## Server Architecture
```
Internet
  ↓
Cloudflare (TLS termination)
  ↓
Cloudflare Tunnel → http://192.168.1.134:80
  ↓
Traefik (port 80, entrypoints=web)
  ↓
Docker containers (internal network)
```

- No se exponen servicios directamente por IP pública
- No se abren puertos en el host para servicios web
- Todo pasa por Cloudflare Tunnel → Traefik → Docker
- Cloudflare también maneja los certificados TLS

## Docker Networks
- `withpostgres_default` (bridge, 172.18.0.0/16) — red principal
- El backend NO necesita estar en la red `traefik`. Traefik descubre servicios en `withpostgres_default`
- El contenedor no debe exponer `ports:` — Traefik accede por red interna Docker

## Domain & Traefik
- Subdominio: `api.juanferca.com`
- En Cloudflare Tunnel: apunta a `http://192.168.1.134:80` (como el resto)
- Router Traefik: `Host(`api.juanferca.com`) && PathPrefix(`/api`)`
- Entrypoint: `web` (puerto 80, sin TLS — Cloudflare lo maneja)
- NO usar `entrypoints=websecure`, NO usar `tls.certresolver`
- No se requiere registro DNS A, solo Cloudflare Tunnel

## Vector Database: postgres-ia
- Image: `pgvector/pgvector:pg16`
- Container: `postgres-ia`
- Port: 5432 (internal)
- DB: `ecosistema_ia`
- User: `juanferca`
- Password: `change-me`
- Extension: `vector` 0.8.2 (pgvector)

### Relevant Tables

**rag.items** — main vector store
- `id` UUID PK (gen_random_uuid)
- `project_id` text NOT NULL
- `source` text (filename)
- `content` text NOT NULL (chunk text)
- `metadata` jsonb DEFAULT '{}'
- `embedding` vector(1536) NOT NULL
- `namespace` text DEFAULT 'default'
- `source_id` text (nullable, used for upsert dedup)
- `created_at` / `updated_at` timestamptz
- Index: `hnsw` on embedding (vector_cosine_ops)
- Unique constraint: (project_id, namespace, source_id) WHERE source_id IS NOT NULL

**app_user** — authentication
- `id` UUID PK
- `email` text UNIQUE NOT NULL
- `pass_salt` text (base64)
- `pass_iters` integer (210000)
- `pass_hash` text (base64, PBKDF2-SHA256, 32 bytes)
- `role` text DEFAULT 'user'
- `is_active` boolean DEFAULT true
- User: `juan@test.com` (contraseña temporal (preguntar al usuario), pendiente de cambio)

## n8n
- URL: https://n8n.juanferca.com
- Container: `withpostgres-n8n-1`
- Internal: http://n8n:5678
- Version: 2.17.7

### Webhooks (solo query)
| Path | Auth | Method | Purpose |
|------|------|--------|---------|
| `/webhook/rag-query` | Header Auth (X-Webhook-Key) | POST JSON | Semantic search |

> El webhook `/webhook/rag-ingest` **ya no se usa**. El backend maneja la ingestión directamente (extracción, chunking, embedding, inserción). El workflow en n8n puede eliminarse o dejarse como respaldo.

### Workflow: Query
1. Webhook → receives JSON { query, project_id, top_k }
2. Code node → validate input
3. HTTP Request → OpenAI /v1/embeddings
4. Code node → format embedding
5. PostgreSQL → SELECT cosine similarity, ORDER BY, LIMIT
6. Respond → results array

### Required n8n Credentials
- PostgreSQL: host=postgres-ia, db=ecosistema_ia, user=juanferca
- OpenAI: Header Auth (Authorization: Bearer sk-...)

## Backend API (Node/Express)
- Container: `rag-backend`
- Internal port: 3000
- URL pública: https://api.juanferca.com/api/
- No tiene puerto expuesto en el host
- Dockerfile base: `node:22-alpine` con `poppler-utils` instalado (para `pdftotext`)

### Endpoints

| Method | Path | Auth | Description |
|--------|------|------|-------------|
| POST | `/api/auth/login` | No | { email, password } → { token, user } |
| GET | `/api/health` | No | { status, uptime } |
| GET | `/api/health/db` | No | { db, alive } |
| POST | `/api/rag/query` | JWT | { query, project_id, top_k } → { results[] } |
| POST | `/api/rag/ingest` | JWT | multipart (file + project_id) → { success, ... } |
| GET | `/api/rag/projects` | JWT | { projects[] } |

### Ingest Flow (backend directo, no pasa por n8n)
1. Backend recibe PDF + project_id (multipart)
2. Escribe PDF a `/tmp/` temporal
3. `pdftotext archivo.pdf -` (extrae texto a stdout)
4. Elimina PDF temporal
5. Chunking: división por palabras cada 500 tokens, solapamiento 50
6. Por cada chunk: llama a OpenAI embedding → INSERT directo en `rag.items`
7. Responde con resumen

> **IMPORTANTE:** `project_id` debe enviarse como texto plano sin comillas. Si se envía `"test"` (con comillas), se guarda literalmente incluyendo las comillas y no coincidirá en las queries.

### Auth Flow
- Login: PBKDF2-SHA256 (210000 iters, base64 salt/hash) against app_user
- JWT: signed with config.jwt.secret, 24h expiry
- Protected routes: Bearer token in Authorization header

### .env Configuration
```
PORT=3000
PG_HOST=postgres-ia
PG_PORT=5432
PG_USER=juanferca
PG_PASSWORD=change-me
PG_DB=ecosistema_ia
OPENAI_API_KEY=sk-...
N8N_URL=http://n8n:5678
N8N_WEBHOOK_SECRET=change-me
JWT_SECRET=<random>
JWT_EXPIRES_IN=24h
```

### Key npm Dependencies
- express, cors, helmet (web server)
- jsonwebtoken (JWT auth)
- pg (PostgreSQL client)
- openai (OpenAI API)
- multer (multipart file upload)
- form-data + node-fetch (proxy a n8n webhooks — solo query)

## PDF Extraction
- Método: `pdftotext` (poppler-utils) vía `child_process.execSync`
- Instalado en Dockerfile: `apk add --no-cache poppler-utils`
- Alternativas probadas y descartadas:
  - `pdf-parse` (npm): sandbox de n8n lo bloquea, extracción pobre
  - `pdfjs-dist` (npm): problemas de workers ES modules con CommonJS
- `pdftotext` es el más fiable y soporta la mayoría de formatos PDF

## Embedding Model
- OpenAI `text-embedding-3-small` (1536 dimensions)

## Security
- Backend es el ÚNICO componente con credenciales de BD y API key de OpenAI
- n8n webhooks requieren `X-Webhook-Key` header (shared secret)
- Frontend Angular nunca ve credenciales
- JWT expira en 24h
- Endpoints protegidos excepto `/api/auth/login` y `/api/health`
- No ports expuestos en host — Traefik accede por red interna Docker

## Startup
```bash
cd /home/juanferca/rag && docker compose up -d --build
```

## Future Frontend
- Angular app (planned)
- Conecta a `https://api.juanferca.com/api/`
- JWT en localStorage, enviado vía HTTP interceptor
- Auth guard redirect a login si no hay token