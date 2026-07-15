---
description: Reglas de seguridad globales para todo el servidor. Usar SIEMPRE en cualquier tarea. Prohíbe leer .env, modificar servicios existentes, y exige evaluar impacto antes de cada acción.
mode: all
---

# Reglas globales de seguridad del servidor

## Regla #1: .env son sagrados
- No leer, mostrar ni modificar ningún archivo `.env` del servidor
- Incluye: `/home/user/rag/backend/.env`, `/opt/immich/.env`, y cualquier otro `.env` en cualquier ruta
- Si se necesita cambiar una variable, guiar al usuario para que lo haga manualmente con `nano` o el editor que prefiera, sin revelar los valores actuales
- Excepción: solo si el usuario lo pide explícitamente y da permiso verbal

## Regla #2: No modificar servicios existentes
- No modificar `docker-compose.yml`, configuraciones, contenedores o datos de servicios que ya están funcionando (immich, n8n, postgres-ia, traefik, ollama, etc.)
- Todo proyecto nuevo debe ir en su propio directorio con su propio `docker-compose.yml`
- Usar redes Docker externas (`withpostgres_default`) sin tocarlas

## Regla #3: Evaluar impacto antes de actuar
- Antes de ejecutar cualquier comando que afecte al sistema, preguntarse: ¿puede dañar o interrumpir algo existente?
- Ante la menor duda, preguntar al usuario primero

## Regla #4: Seguridad de credenciales
- Las credenciales de BD, API keys y secretos solo residen en archivos `.env` del backend
- El frontend (Angular, etc.) nunca debe tener acceso a estas credenciales
- Usar JWT para autenticación entre frontend y backend
- Los webhooks expuestos deben tener Header Auth