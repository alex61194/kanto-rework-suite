# Kanto Rework Suite 🎮

[![Validate & Test](https://github.com/alex61194/kanto-rework-suite/actions/workflows/validate.yml/badge.svg)](https://github.com/alex61194/kanto-rework-suite/actions/workflows/validate.yml)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](LICENSE)
[![Language: ES / EN](https://img.shields.io/badge/Language-ES%20%7C%20EN-blue.svg)](docs/LOCALIZATION.md)

**A complete UI, UX, Quality-of-Life, and Accessibility overhaul for Pokémon Red running on Gen1Recomp (LÖVE 2D).**

> 🇪🇸 **Edición con traducción completa al Español**: Todos los menús, tipos elementales, descripciones de movimientos, objetos clasificados en 8 bolsillos, modificadores de combate en tiempo real, gestor de mods y soporte multi-pantalla (16:9, Steam Deck 16:10, Ultrawide 21:9 y 4:3).

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

## 🛠️ Instalación

1. Descarga los archivos `.zip` desde [Releases](https://github.com/alex61194/kanto-rework-suite/releases).
2. Coloca los paquetes dentro de la carpeta `mods/` de tu **Gen1Recomp**.
3. Actívalos desde el menú de mods del juego.

---

## 📄 Licencia

Distribuido bajo la Licencia MIT. Consulta [LICENSE](LICENSE) para más detalles.
