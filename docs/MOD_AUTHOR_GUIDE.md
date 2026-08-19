# Guía para Autores de Mods (Mod Author Guide)

Esta guía explica cómo integrar mods de terceros con el ecosistema de **Kanto Rework Suite** utilizando la API de compatibilidad (`kanto_rework_compat`).

---

## 🧩 Principios de Integración

1. **No Invasión**: Kanto Rework no sobrescribe el código de mods de terceros.
2. **Proveedores de Contenido (Providers)**: Los mods pueden registrarse como proveedores de recursos específicos:
   - Sprites de combate (Battle Sprites: Classic, Voxel, High-Res).
   - Fondos de batalla (Battle Backgrounds).
   - Datos adicionales de Pokédex / Tipos.
3. **Fallback Seguro**: Si una pantalla o modal no está registrado, Kanto Rework mantiene visible la interfaz nativa original de Gen1Recomp.

---

## 🔗 Registro de un Adaptador

Para registrar un adaptador de compatibilidad, expón un módulo con la siguiente firma:

```lua
-- En tu mod: compat/my_mod_adapter.lua
local Adapter = {}

Adapter.id = "my_custom_sprites"
Adapter.name = "My Custom Sprites Provider"
Adapter.version = "1.0.0"

function Adapter.provides()
  return { "battle_sprites", "battle_backgrounds" }
end

function Adapter.getSprite(pokemonId, isShiny, isBack)
  -- Devolver LÖVE Image o nil para usar fallback
  return myLoadedImage
end

return Adapter
```

---

## 🛠️ Buenas Prácticas

- Utiliza la API oficial `input.pointer` si tu mod implementa controles por ratón.
- Evita sobrescribir variables globales `_G` sin un espacio de nombres único.
- Respeta los perfiles de color y tokens semánticos definidos en `kanto_rework_core/core/theme.lua`.
