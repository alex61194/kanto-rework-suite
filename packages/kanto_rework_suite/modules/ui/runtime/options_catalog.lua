local Catalog = {}

local DATA = {
  textSpeed = { category="JUGABILIDAD", control="multi", description="Elige la velocidad a la que se muestra el texto en los diálogos." },
  speed = { category="JUGABILIDAD", control="multi", description="Modifica la velocidad lógica del juego manteniendo el ritmo de la música y efectos." },

  animations = { category="COMBATE", control="toggle", description="Activa o desactiva las animaciones de los ataques en combate." },
  battleStyle = { category="COMBATE", control="multi", description="Elige el estilo de combate entre CAMBIO o MANTENER." },
  battleLayout = { category="COMBATE", control="multi", description="Elige entre la vista clásica original o la vista panorámica 16:9." },
  battleFit = { category="COMBATE", control="multi", description="Elige entre escalado entero fijo o llenado vertical de la arena de combate." },
  battleBg = { category="COMBATE", control="multi", description="Elige el fondo ilustrado mostrado alrededor y detrás del combate." },
  ruleset = { category="COMBATE", control="multi", description="Elige uno de los conjuntos de reglas de combate registrados." },

  uiLayout = { category="GRÁFICOS", control="multi", description="Elige la posición de la interfaz: clásica centrada o anclada dinámicamente a la pantalla." },
  performance = { category="GRÁFICOS", control="multi", description="Ajusta el nivel de rendimiento para limitar o potenciar los efectos visuales complejos." },
  colors = { category="GRÁFICOS", control="multi", description="Elige el modo de presentación de color del juego." },
  krsTheme = { category="GRÁFICOS", control="multi", description="Elige entre Crema, Grafito, Noche Púrpura o Retro para la interfaz de Kanto Rework." },
  tilt = { category="GRÁFICOS", control="stepper", description="Ajusta la inclinación de perspectiva del mundo." },
  gbcfx = { category="GRÁFICOS", control="stepper", description="Ajusta el nivel de efectos visuales de Game Boy Color." },
  zoom = { category="GRÁFICOS", control="stepper", description="Ajusta el nivel de zoom en el mapa según la resolución actual." },
  voidFill = { category="GRÁFICOS", control="multi", description="Elige cómo rellenar el espacio exterior más allá de los límites del mapa." },

  musicVol = { category="AUDIO", control="stepper", description="Ajusta el volumen de la música." },
  sfxVol = { category="AUDIO", control="stepper", description="Ajusta el volumen de los efectos de sonido." },
  pikaVol = { category="AUDIO", control="stepper", description="Ajusta el volumen de la voz de Pikachu (solo en versiones compatibles)." },
  musicFilter = { category="AUDIO", control="multi", description="Elige el filtro de paso bajo para la música." },

  videoMode = { category="SISTEMA", control="multi", description="Elige el modo de pantalla: VENTANA, PANTALLA COMPLETA o SIN BORDES." },
  orientation = { category="SISTEMA", control="multi", description="Bloqueo de orientación de pantalla (disponible en Android)." },
  faithfulRes = { category="SISTEMA", control="multi", disabled=true, description="La resolución original clásica no está disponible en la interfaz panorámica de Kanto Rework." },
  fpsCap = { category="SISTEMA", control="stepper", description="Establece el límite máximo de fotogramas por segundo (FPS)." },
  controls = { category="CONTROLES", control="submenu", description="Abre la pantalla de configuración y asignación de controles." },
  touchControls = { category="CONTROLES", control="toggle", description="Activa o desactiva la botonera táctil en pantalla en dispositivos compatibles." },
  haptics = { category="CONTROLES", control="multi", description="Ajusta la intensidad de vibración háptica al tocar los controles." },
}

local ORDER = { "JUGABILIDAD", "COMBATE", "GRÁFICOS", "AUDIO", "SISTEMA", "CONTROLES" }

local function infer(row)
  if type(row.category) == "string" and row.category ~= "" then
    local c = row.category:upper()
    if c == "GAMEPLAY" then return "JUGABILIDAD"
    elseif c == "BATTLE" then return "COMBATE"
    elseif c == "GRAPHICS" then return "GRÁFICOS"
    elseif c == "SYSTEM" then return "SISTEMA"
    elseif c == "CONTROLES" or c == "CONTROLS" then return "CONTROLES"
    end
    return c
  end
  local id = tostring(row.id or ""):lower()
  if id:find("colorblind", 1, true) or (id:find("color",1,true) and id:find("blind",1,true)) then
    return "GRÁFICOS"
  end
  if id:find("overlay", 1, true) then return "SISTEMA" end
  return "OTROS"
end

function Catalog.meta(row)
  local meta = DATA[row.id]
  if meta then return meta end
  local control = row.activate and "submenu" or "multi"
  if type(row.type) == "string" then
    if row.type == "toggle" then control = "toggle"
    elseif row.type == "number" then control = "stepper"
    elseif row.type == "choice" then control = "multi" end
  end
  local id = tostring(row.id or ""):lower()
  if id:find("colorblind",1,true) then control = "multi" end
  return {
    category = infer(row), control = control,
    description = type(row.description) == "string" and row.description or "No hay descripción disponible para este ajuste.",
  }
end

function Catalog.visible(row)
  return row and row.id ~= "mods"
end

function Catalog.categories(rows)
  local present, extra = {}, {}
  for _, row in ipairs(rows or {}) do
    if Catalog.visible(row) then
    local cat = Catalog.meta(row).category
    present[cat] = true
    if cat ~= "JUGABILIDAD" and cat ~= "COMBATE" and cat ~= "GRÁFICOS" and cat ~= "AUDIO" and cat ~= "CONTROLES" and cat ~= "SISTEMA" then extra[cat] = true end
    end
  end
  local out = {}
  for _, cat in ipairs(ORDER) do if present[cat] then out[#out+1] = cat end end
  local extras = {}
  for cat in pairs(extra) do extras[#extras+1] = cat end
  table.sort(extras)
  for _, cat in ipairs(extras) do out[#out+1] = cat end
  return out
end

function Catalog.rows(rows, category)
  local out = {}
  for _, row in ipairs(rows or {}) do
    if Catalog.visible(row) and Catalog.meta(row).category == category then out[#out+1] = row end
  end
  return out
end

return Catalog
