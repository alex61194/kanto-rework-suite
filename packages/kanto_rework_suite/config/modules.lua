return {
  { id="core", legacyId="kanto_rework_core", name="Kanto Rework Core", version="0.1.44", schema=1, dir="core", entry="main.lua", required=true, enabled=true, dependencies={}, restartRequired=false },
  { id="graphics", legacyId="kanto_rework_graphics", name="Kanto Rework Graphics", version="0.3.6", schema=1, dir="graphics", entry="main.lua", required=false, enabled=true, dependencies={"core"}, restartRequired=false },
  { id="gameplay", legacyId="kanto_rework_gameplay", name="Kanto Rework Gameplay", version="0.3.18", schema=1, dir="gameplay", entry="main.lua", required=false, enabled=true, dependencies={"core"}, restartRequired=false },
  { id="compatibility", legacyId="kanto_rework_compat", name="Kanto Rework Compatibility", version="0.4.20", schema=1, dir="compatibility", entry="main.lua", required=false, enabled=true, dependencies={"core"}, restartRequired=false },
  { id="battle_animations", legacyId="kanto_rework_battle_anims", name="Kanto Rework Battle Animations", version="0.1.7", schema=1, dir="battle_animations", entry="entry.lua", required=false, enabled=true, dependencies={"graphics"}, restartRequired=false },
  { id="ui", legacyId="kanto_rework_ui", name="Kanto Rework UI", version="0.8.58", schema=1, dir="ui", entry="main.lua", required=false, enabled=true, dependencies={"core","graphics"}, restartRequired=false },
  { id="dev_tools", legacyId="kanto_rework_dev", name="Kanto Rework Dev Tools", version="0.2.5", schema=1, dir="dev_tools", entry="main.lua", required=false, enabled=false, dependencies={"core"}, conflicts={"krs_qa_battle"}, restartRequired=true }
}
