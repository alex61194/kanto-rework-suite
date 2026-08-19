# Guía de Contribución / Contributing Guide 🎮

¡Gracias por tu interés en colaborar con **Kanto Rework Suite**!

Este proyecto es una suite modular de rediseño de interfaz (UI), experiencia de usuario (UX) y calidad de vida (QoL) para Pokémon Rojo ejecutándose en el motor **Gen1Recomp** (LÖVE 2D).

---

## 🛠️ Entorno de Desarrollo Local

### Requisitos previos
- **Python 3.9+** (para scripts de validación, construcción y empaquetado).
- **Lua 5.1 / Luajit / LÖVE 11.x** (para pruebas locales de scripts).
- **Git**

### Estructura de Paquetes
Los módulos se encuentran organizados dentro del directorio `packages/`:
- `packages/kanto_rework_core`: Núcleo de diseño, tokens, layout responsivo, sistema de entrada (ratón/táctil), internacionalización (i18n) y almacenamiento de perfiles.
- `packages/kanto_rework_ui`: Presenters de menús, pantallas y modales de alta resolución.
- `packages/kanto_rework_gameplay`: Ranuras de guardado, atajos de inventario y acciones de campo.
- `packages/kanto_rework_compat`: Adaptadores de compatibilidad con mods de terceros.

---

## 🧪 Ejecución de Pruebas y Validación

Antes de enviar un Pull Request o crear un commit, ejecuta las herramientas de validación:

```bash
# Validar estructura de paquetes y sintaxis
python tools/validate_package.py

# Construir y empaquetar paquetes distribuibles
python tools/build_suite.py
```

Para ejecutar las pruebas en Lua (si tienes LÖVE o Lua instalado):
```bash
lua tests/p0_runtime_smoke.lua
lua tests/p0_battle_pointer_smoke.lua
lua tests/test_i18n.lua
```

---

## 🌐 Internacionalización (i18n)

Para añadir o modificar textos en español u otros idiomas:
1. Revisa `packages/kanto_rework_core/locales/es.lua` y `locales/en.lua`.
2. Asegúrate de que todas las claves existentes estén presentes en el nuevo idioma.
3. Consulta `docs/LOCALIZATION.md` para más información.

---

## 📋 Reglas de Calidad y Convenciones

1. **No mezclar código con binarios**: No subir archivos `.zip` o `.sav` pesados directamente al repositorio de Git; utiliza GitHub Actions y Releases.
2. **Compatibilidad hacia atrás**: Mantener siempre el mecanismo de *fallback* a la interfaz nativa cuando un estado no sea reconocido.
3. **Mensajes de Commit claros**: Utiliza la convención convencional (`feat:`, `fix:`, `docs:`, `chore:`, `refactor:`).
