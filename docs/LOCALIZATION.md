# Sistema de Internacionalización (i18n)

Kanto Rework Suite cuenta con un sistema centralizado de internacionalización que permite alternar dinámicamente entre múltiples idiomas sin reiniciar el juego.

## Idiomas soportados actualmente
- 🇪🇸 **Español (`es`)**
- 🇬🇧 **English (`en`)**

---

## Estructura de Archivos de Idioma

Los diccionarios se ubican en `packages/kanto_rework_core/locales/`:
- `packages/kanto_rework_core/locales/es.lua`
- `packages/kanto_rework_core/locales/en.lua`

Cada archivo exporta una tabla Lua con las claves y valores traducidos:

```lua
return {
  app_name = "Diario de Campo",
  region_name = "Kanto",
  entries_count = "%02d ENTRADAS",
  companion_title = "COMPAÑERO DE KANTO",
  overlay_edit_mode = "MODO EDICIÓN DE OVERLAY",
  party_summary = "EQUIPO %d/6     ¥%d     %s",
  edit_hint = "ARRASTRA EL ENCABEZADO ROJO - F9 PARA FIJAR",
  shortcut_hint = "F8 OCULTAR - F9 EDITAR",
  action_hint_mouse = "CLICK CONFIRMAR - CLICK DERECHO VOLVER - RUEDA SCROLL",
  action_hint_keyboard = "A CONFIRMAR - B VOLVER - FLECHAS MOVER",
  action_hint_controller = "A CONFIRMAR - B VOLVER - D-PAD MOVER",
  pokedex = "POKéDEX",
  pokemon = "POKéMON",
  item = "OBJETOS",
  trainer = "ENTRENADOR",
  save = "GUARDAR",
  option = "OPCIONES",
}
```

---

## Cómo agregar un nuevo idioma

1. Crea un nuevo archivo en `packages/kanto_rework_core/locales/[código].lua` (ej. `fr.lua`, `de.lua`, `ja.lua`).
2. Copia todas las claves de `en.lua` y traduce sus valores.
3. Registra el nuevo idioma en `packages/kanto_rework_core/main.lua` dentro de las opciones del mod:
```lua
{ key = "language", label = "IDIOMA / LANGUAGE", type = "choice",
  default = "es",
  choices = {
    { "ESPAÑOL", "es" },
    { "ENGLISH", "en" },
    { "FRANÇAIS", "fr" },
  },
  description = "Selecciona el idioma de la interfaz / Select UI language." }
```
4. Ejecuta `python tools/validate_package.py` para asegurar que todas las claves requeridas están presentes.
