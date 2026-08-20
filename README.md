# Kanto Rework Suite 🎮

[![Validate & Test](https://github.com/alex61194/kanto-rework-suite/actions/workflows/validate.yml/badge.svg)](https://github.com/alex61194/kanto-rework-suite/actions/workflows/validate.yml)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](LICENSE)
[![Language: ES / EN](https://img.shields.io/badge/Language-ES%20%7C%20EN-blue.svg)](docs/LOCALIZATION.md)

**A complete UI, UX, Quality-of-Life, and Accessibility overhaul for Pokémon Red running on Gen1Recomp (LÖVE 2D).**

> ### 📢 Credits & Attribution / Créditos y Autoría Original
>
> 🌟 **Original Mod, UI Design & Resources by [Faendra](https://github.com/Faendra)**
> - **Original Repository**: [https://github.com/Faendra/kanto-rework-suite](https://github.com/Faendra/kanto-rework-suite)
> - **Discord Thread / Discussion**: Mod showcase & updates in the official Gen1Recomp Discord (`#pkmn-mods` / `#pkmn-releases`).
>
> ℹ️ **Notice / Aviso**:
> This repository is a community fork maintained by **[alex61194](https://github.com/alex61194)** specifically dedicated to providing the **Spanish translation (traducción y localización al español)** and localized QoL / mobile compatibility. **All original UI designs, artwork, layouts, and core resources belong entirely to [Faendra](https://github.com/Faendra).** Please visit and star the original repository!

---

## 🧩 Paquetes de la Suite

| Paquete | Rol | Estado |
|---|---|---|
| [`packages/kanto_rework_core`](packages/kanto_rework_core) | Base de datos de tipos/movimientos/objetos, internacionalización (i18n), layout adaptable, puntero unificado y guardado atómico. | ✅ Activo |
| [`packages/kanto_rework_ui`](packages/kanto_rework_ui) | Presenters de alta resolución: Resumen de Pokémon (DVs/Stat Exp), Mochila en 8 bolsillos y HUD de combate con efectividades. | ✅ Activo |
| [`packages/kanto_rework_compat`](packages/kanto_rework_compat) | Gestor de Mods (Mods Manager), selector de proveedores de sprites (Clásico, Kanto Ascendant, Voxel) y accesibilidad. | ✅ Activo |

---

## ✨ Características y Funciones Nuevas

### 🌐 Traducción e Internacionalización Exhaustiva (100% Español / English)
- **Tipos Elementales**: Fuego, Agua, Planta, Eléctrico, Hielo, Lucha, Veneno, Tierra, Volador, Psíquico, Bicho, Roca, Fantasma, Dragón y Normal con insignias de color.
- **Movimientos de Combate**: Catálogo completo de movimientos con potencia, precisión, PP y descripciones detalladas del efecto en español.
- **Mochila en 8 Bolsillos**: Medicinas, Poké Balls, Combate, Bayas, Otros Objetos, MTs y MOs, Tesoros y Objetos Clave.
- **Estadísticas y Estados**: PS, Ataque, Defensa, Velocidad, Especial, Precisión y Evasión, además de estados alterados (Dormido, Envenenado, Quemado, Congelado, Paralizado, Debilitado, Confuso).
- **Gestor de Mods**: Interfaz de configuración de mods de terceros traducida al español.

### 📊 Resumen Detallado de Pokémon
- Muestra los **DVs (0-15)** para cada estadística.
- Barras de progreso visual para la **Stat Experience (0-65535)** de 1.ª generación.
- Visualización de movimientos con tipo, PP actuales/máximos y descripción contextual.

### ⚔️ HUD de Combate Mejorado
- Indicadores visuales de modificadores de estadísticas en combate (`ATK +2`, `VEL -1`, etc.).
- Cálculo automático de **efectividad de tipos** contra el rival (*"¡Es muy eficaz!"*, *"No es muy eficaz..."*, *"¡No le afecta!"*).
- Barra de PS con transición de color dinámica.

### 📐 Soporte Multi-Resolución
- **16:9** (Widescreen PC)
- **16:10** (Steam Deck y consolas portátiles)
- **21:9** (Monitores Ultrawide con centrado inteligente)
- **4:3 / 10:9** (Pantallas retro)
- **9:16** (Dispositivos móviles / pantallas táctiles)

### 🎨 4 Temas Visuales
1. 🤍 **Field Journal**: Estilo pergamino cálido con acentos carmesí.
2. 🖤 **Graphite**: Oscuro contemporáneo con acentos azul eléctrico.
3. 💜 **Purple Night**: Violeta profundo y contraste neón.
4. 🕹️ **Retro DMG**: Paleta clásica inspirada en la Game Boy original.

---

## 🤝 Agradecimientos & Acknowledgements
- **[Faendra](https://github.com/Faendra)**: Author and creator of the original Kanto Rework Suite, all UI designs, layout systems, and artistic direction.
- **Gen1Recomp Community**: All modders and contributors on the official Discord.

---

## 📄 Licencia

Distribuido bajo la Licencia MIT. Consulta [LICENSE](LICENSE) para más detalles.
