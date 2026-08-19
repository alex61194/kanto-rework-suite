-- Direct Controls category model for the Wide Kanto Options screen.
--
-- Native GB bindings are read through Core.inputBinding, so the UI reflects
-- Gen1Recomp's effective keyboard/controller map instead of maintaining a
-- second binding table. Kanto actions come from Core.inputActions.
return function(runtime)
  local Core=assert(runtime.Core)
  local Model={}

  local NATIVE={
    {id="up",label="ARRIBA",description="Mueve al jugador o el cursor hacia arriba."},
    {id="down",label="ABAJO",description="Mueve al jugador o el cursor hacia abajo."},
    {id="left",label="IZQUIERDA",description="Mueve al jugador o el cursor hacia la izquierda."},
    {id="right",label="DERECHA",description="Mueve al jugador o el cursor hacia la derecha."},
    {id="a",label="A / CONFIRMAR",description="Interactúa o confirma la acción seleccionada."},
    {id="b",label="B / CANCELAR",description="Cancela o vuelve al menú anterior."},
    {id="start",label="START / PAUSA",description="Abre el menú principal de pausa."},
    {id="select",label="SELECT",description="Acción secundaria o reordenar elementos."},
  }

  local function keyLabel(raw)
    if runtime.Footer and runtime.Footer.physicalLabel then
      return runtime.Footer.physicalLabel(raw or "SIN ASIGNAR","keyboard")
    end
    return tostring(raw or "SIN ASIGNAR"):upper()
  end
  local function padLabel(raw)
    if runtime.Footer and runtime.Footer.physicalLabel then
      return runtime.Footer.physicalLabel(raw or "SIN ASIGNAR","controller")
    end
    return tostring(raw or "SIN ASIGNAR"):upper()
  end
  local function nativeBinding(game,action,kind)
    if type(Core.inputBinding)=="function" then
      local ok,v=pcall(Core.inputBinding,action,kind)
      if ok then return v end
    end
    return nil
  end
  local function attachValue(row)
    row.keyLabel=keyLabel(row.key)
    row.padLabel=padLabel(row.pad)
    row.value=function()
      return "TECLA "..row.keyLabel.."  ·  MANDO "..row.padLabel
    end
    return row
  end

  function Model.rows(game)
    local rows={}
    for _,def in ipairs(NATIVE) do
      rows[#rows+1]=attachValue({
        kind="native_action",
        id="GB_"..def.id:upper(),
        nativeAction=def.id,
        label=def.label,
        group="CONTROLES DE GAME BOY",
        description=def.description,
        key=nativeBinding(game,def.id,"keyboard"),
        pad=nativeBinding(game,def.id,"controller"),
      })
    end
    local actions=Core.inputActions and Core.inputActions.list and Core.inputActions.list() or {}
    for _,a in ipairs(actions) do
      rows[#rows+1]=attachValue({
        kind="action",
        id=a.id,
        action=a,
        label=a.label,
        group=tostring(a.group or "ACCIONES DE KANTO REWORK"):upper(),
        description=a.description or "Acción configurable de Kanto Rework.",
        key=a.key,
        pad=a.pad,
      })
    end
    return rows
  end

  function Model.meta(row)
    return {
      category="CONTROLES",
      control="binding",
      description=row and row.description or "Asignación de control configurable.",
      disabled=false,
    }
  end

  return Model
end
