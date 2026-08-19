# Kanto Rework Suite 🎮

[![Validate & Test](https://github.com/alex61194/kanto-rework-suite/actions/workflows/validate.yml/badge.svg)](https://github.com/alex61194/kanto-rework-suite/actions/workflows/validate.yml)
[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)
[![Language: ES / EN](https://img.shields.io/badge/Language-ES%20%7C%20EN-blue.svg)](docs/LOCALIZATION.md)

**A complete UI, UX, Quality-of-Life, and Accessibility overhaul for Pokémon Red running on Gen1Recomp (LÖVE 2D).**

> 🇪🇸 **Edición con soporte nativo en Español**: Menús traducidos dinámicamente, diario de campo, perfiles de guardado atómico, navegación híbrida por ratón y adaptación a múltiples resoluciones (16:9, Steam Deck 16:10, Ultrawide 21:9 y 4:3).

---

## 🧩 Arquitectura Modular

El proyecto se estructura en submódulos desacoplados y probados independientemente:

| Paquete | Rol | Estado |
|---|---|---|
| `packages/kanto_rework_core` | Tokens de diseño, internacionalización (i18n), layout adaptable, puntero unificado, almacenamiento de perfiles y guardado atómico. | ✅ Activo |
| `packages/kanto_rework_ui` | Presenters de menús, Diario de Campo (Start Menu), mochila categorizada y modales. | 🚧 En desarrollo |
| `packages/kanto_rework_companion` | Widget móvil de acompañante (F8 alternar, F9 modo edición). | ✅ Activo |
| `packages/kanto_rework_gameplay` | Atajos de objetos (`CTRL+1` a `9`), favoritos, 4 ranuras de guardado y acciones de campo. | 🚧 Planificado |
| `packages/kanto_rework_compat` | Adaptadores para mods de terceros (sprites de combate, fondos 3D/Voxel). | ✅ En pruebas |

---

## ✨ Características Principales

### 🌐 Internacionalización Completa (i18n)
- Soporte nativo para **Español (`es`)** e **Inglés (`en`)**.
- Selección de idioma directamente desde las opciones del mod sin necesidad de reiniciar el juego.
- Más información en [docs/LOCALIZATION.md](docs/LOCALIZATION.md).

### 📐 Compatibilidad con Múltiples Resoluciones
- **Widescreen (16:9)**: Optimizado para monitores de PC modernos.
- **Steam Deck & Handhelds (16:10)**: Adaptación automática de cajas de texto y márgenes de seguridad.
- **Ultrawide (21:9)**: Centrado y dimensionado proporcional sin deformar el área de juego.
- **Classic (4:3 & 10:9)**: Modo adaptado para pantallas retro y dispositivos compactos.
- **Portrait (9:16)**: Disposición vertical para pantallas táctiles y smartphones.

### 🎨 Temas Visuales
1. 🤍 **Field Journal**: Estilo cálido tipo diario pergamino con acentos carmesí.
2. 🖤 **Graphite**: Tema oscuro moderno con acentos azul eléctrico.
3. 💜 **Purple Night**: Violeta profundo con detalles de alto contraste.
4. 🕹️ **Retro DMG**: Paleta clásica nostálgica inspirada en la Game Boy original.

### 🖱️ Control Semántico con Ratón y Táctil
- **Click Izquierdo / Tap**: Seleccionar y confirmar elementos.
- **Click Derecho**: Volver atrás / cancelar (equivalente al botón B).
- **Rueda del Ratón**: Desplazamiento fluido en listas, mochilas y menús.
- **Drag & Drop**: Arrastre intuitivo del widget de acompañante en modo edición (`F9`).

### 💾 Ranuras de Guardado Seguras y Atómicas
- Guardado atómico mediante archivo temporal `.sav.tmp` y respaldo automático en `.sav.bak` para prevenir la corrupción de partidas ante cierres inesperados.

---

## 🚀 Instalación y Uso

1. Descarga la última versión empaquetada desde [Releases](https://github.com/alex61194/kanto-rework-suite/releases).
2. Extrae el archivo `.zip` del módulo deseado (ej. `kanto_rework_core-0.1.0.zip`) dentro de la carpeta `mods/` de tu instalación de **Gen1Recomp**.
3. Inicia el juego y activa los módulos desde el menú de mods.

---

## 🛠️ Desarrollo y Pruebas

Para validar los paquetes y ejecutar la suite de pruebas localmente:

```bash
# Validar estructura y manifiestos
python tools/validate_package.py

# Construir paquetes ZIP distribuidos y sumas SHA-256
python tools/build_suite.py
```

---

## 📄 Licencia

Este proyecto está bajo la Licencia MIT. Consulta el archivo [LICENSE](LICENSE) para más detalles.
