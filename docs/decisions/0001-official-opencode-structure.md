# 0001 — Usar la estructura oficial de OpenCode

## Problema

Necesitamos organizar agentes, Skills y configuración sin crear convenciones propias innecesarias.

## Decisión

La plataforma utilizará las rutas oficiales de proyecto:

- `.opencode/opencode.jsonc`
- `.opencode/agents/`
- `.opencode/skills/`

La instalación local de OpenCode seguirá viviendo en `~/.config/opencode`.

## Motivo

Esto permite trabajar con OpenCode sin adaptadores ni capas de compatibilidad y evita mezclar la plataforma versionada con credenciales, dependencias y estado local.

## Alternativas descartadas

- Carpetas `agents/` y `skills/` en la raíz: no son las rutas oficiales de proyecto.
- Copiar completamente `~/.config/opencode`: incluiría instalación y estado local.
- Crear desde ahora carpetas para MCP y perfiles: todavía no resuelven una necesidad validada.
