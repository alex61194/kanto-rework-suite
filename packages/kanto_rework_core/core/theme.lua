local Theme = {}

local THEMES = {
  field_journal = {
    id = "field_journal",
    name = "Field Journal",
    backdrop = { 0.12, 0.11, 0.10, 0.72 },
    paper = { 0.96, 0.94, 0.90, 1.0 },
    border = { 0.32, 0.28, 0.24, 0.85 },
    ink = { 0.15, 0.14, 0.13, 1.0 },
    subtle = { 0.45, 0.42, 0.38, 1.0 },
    muted = { 0.58, 0.55, 0.50, 1.0 },
    accent = { 0.82, 0.22, 0.20, 1.0 },
    accentDark = { 0.56, 0.14, 0.13, 1.0 },
    accentSoft = { 0.82, 0.22, 0.20, 0.15 },
    onAccent = { 1.0, 1.0, 1.0, 1.0 },
    shadow = { 0.0, 0.0, 0.0, 0.35 },
    night = { 0.14, 0.14, 0.16, 0.94 },
    nightText = { 0.95, 0.95, 0.96, 1.0 },
    nightMuted = { 0.65, 0.65, 0.70, 1.0 },
  },
  graphite = {
    id = "graphite",
    name = "Graphite",
    backdrop = { 0.05, 0.05, 0.07, 0.80 },
    paper = { 0.16, 0.17, 0.20, 0.98 },
    border = { 0.28, 0.30, 0.36, 0.90 },
    ink = { 0.95, 0.96, 0.98, 1.0 },
    subtle = { 0.65, 0.68, 0.75, 1.0 },
    muted = { 0.48, 0.50, 0.56, 1.0 },
    accent = { 0.20, 0.60, 0.95, 1.0 },
    accentDark = { 0.12, 0.42, 0.70, 1.0 },
    accentSoft = { 0.20, 0.60, 0.95, 0.20 },
    onAccent = { 1.0, 1.0, 1.0, 1.0 },
    shadow = { 0.0, 0.0, 0.0, 0.50 },
    night = { 0.10, 0.11, 0.13, 0.96 },
    nightText = { 0.95, 0.96, 0.98, 1.0 },
    nightMuted = { 0.60, 0.62, 0.68, 1.0 },
  },
  purple_night = {
    id = "purple_night",
    name = "Purple Night",
    backdrop = { 0.06, 0.04, 0.10, 0.82 },
    paper = { 0.15, 0.12, 0.22, 0.98 },
    border = { 0.35, 0.28, 0.48, 0.90 },
    ink = { 0.96, 0.94, 1.0, 1.0 },
    subtle = { 0.72, 0.66, 0.82, 1.0 },
    muted = { 0.52, 0.46, 0.62, 1.0 },
    accent = { 0.68, 0.32, 0.95, 1.0 },
    accentDark = { 0.46, 0.18, 0.72, 1.0 },
    accentSoft = { 0.68, 0.32, 0.95, 0.20 },
    onAccent = { 1.0, 1.0, 1.0, 1.0 },
    shadow = { 0.0, 0.0, 0.0, 0.55 },
    night = { 0.10, 0.08, 0.15, 0.96 },
    nightText = { 0.96, 0.94, 1.0, 1.0 },
    nightMuted = { 0.68, 0.62, 0.76, 1.0 },
  },
  retro = {
    id = "retro",
    name = "Retro DMG",
    backdrop = { 0.18, 0.24, 0.12, 0.80 },
    paper = { 0.76, 0.84, 0.42, 1.0 },
    border = { 0.30, 0.40, 0.18, 1.0 },
    ink = { 0.10, 0.18, 0.08, 1.0 },
    subtle = { 0.24, 0.34, 0.14, 1.0 },
    muted = { 0.38, 0.48, 0.22, 1.0 },
    accent = { 0.30, 0.48, 0.16, 1.0 },
    accentDark = { 0.18, 0.32, 0.10, 1.0 },
    accentSoft = { 0.30, 0.48, 0.16, 0.25 },
    onAccent = { 0.88, 0.94, 0.62, 1.0 },
    shadow = { 0.05, 0.10, 0.02, 0.40 },
    night = { 0.14, 0.22, 0.10, 0.96 },
    nightText = { 0.84, 0.92, 0.54, 1.0 },
    nightMuted = { 0.52, 0.64, 0.32, 1.0 },
  },
}

function Theme.get(id)
  return THEMES[id] or THEMES.field_journal
end

function Theme.setColor(color)
  if not (love and love.graphics and color) then return end
  love.graphics.setColor(color[1] or 1, color[2] or 1, color[3] or 1, color[4] or 1)
end

function Theme.list()
  local out = {}
  for id, theme in pairs(THEMES) do
    out[#out + 1] = { id = id, name = theme.name }
  end
  return out
end

return Theme
