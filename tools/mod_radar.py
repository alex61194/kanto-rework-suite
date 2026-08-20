"""
Gen1Recomp Mod Radar & Community Tracker
Rastreador automático de mods de la comunidad Gen1Recomp (Discord / GitHub / Mod Index).
"""

import os
import sys
import json
import urllib.request
import urllib.error
import subprocess
import re
from datetime import datetime

PC_MODS_DIR = r"C:\Games\gen1recomp-win64\mods"
ANDROID_MODS_DIR = "/sdcard/Android/data/com.theboisclub.pokemonred/files/save/pokemon-love2d/mods"
INDEX_URLS = [
    "https://bryanthaboi.github.io/gen1recomp-mod-index/data/index.json",
    "https://raw.githubusercontent.com/bryanthaboi/gen1recomp-mod-index/gh-pages/data/index.json"
]

HEADERS = {
    "User-Agent": "Gen1Recomp-Mod-Radar/1.0 (Mozilla/5.0)",
    "Accept": "application/json"
}

def get_installed_pc_mods():
    pc_mods = {}
    if not os.path.exists(PC_MODS_DIR):
        return pc_mods
    for entry in os.listdir(PC_MODS_DIR):
        full_path = os.path.join(PC_MODS_DIR, entry)
        if os.path.isdir(full_path):
            manifest_path = os.path.join(full_path, "manifest.json")
            version = "Desconocida"
            name = entry
            author = ""
            mod_id = entry
            if os.path.exists(manifest_path):
                try:
                    with open(manifest_path, "r", encoding="utf-8", errors="ignore") as f:
                        mdata = json.load(f)
                        version = str(mdata.get("version", "Desconocida")).lstrip('v')
                        name = mdata.get("name", entry)
                        author = mdata.get("author") or mdata.get("authors", "")
                        mod_id = mdata.get("id", entry)
                except Exception:
                    pass
            pc_mods[mod_id] = {
                "folder": entry,
                "id": mod_id,
                "name": name,
                "version": version,
                "author": author,
                "path": full_path
            }
    return pc_mods

def get_installed_android_mods():
    android_mods = {}
    cmd = f'adb shell "find {ANDROID_MODS_DIR} -name manifest.json 2>/dev/null"'
    try:
        res = subprocess.run(cmd, capture_output=True, text=True, shell=True, timeout=5)
        for path in res.stdout.splitlines():
            path = path.strip()
            if not path:
                continue
            folder = path.split('/')[-2]
            read_cmd = f'adb shell "cat \'{path}\'"'
            mres = subprocess.run(read_cmd, capture_output=True, text=True, shell=True, timeout=5)
            try:
                j = json.loads(mres.stdout)
                mod_id = j.get('id', folder)
                v = str(j.get('version', 'Desconocida')).lstrip('v')
                name = j.get('name', folder)
                android_mods[mod_id] = {"id": mod_id, "folder": folder, "name": name, "version": v}
            except Exception:
                android_mods[folder] = {"id": folder, "folder": folder, "name": folder, "version": "Desconocida"}
    except Exception:
        pass
    return android_mods

def fetch_community_catalog():
    print("[+] Descargando catalogo actualizado de la comunidad...")
    for url in INDEX_URLS:
        try:
            req = urllib.request.Request(url, headers=HEADERS)
            with urllib.request.urlopen(req, timeout=15) as resp:
                data = json.loads(resp.read().decode('utf-8'))
                return data.get("mods", [])
        except Exception:
            pass
    print("[-] No se pudo conectar al indice en linea.")
    return []

def version_to_tuple(v):
    if not v or v in ("N/A", "Desconocida", "Sin manifest", "-"):
        return ()
    cleaned = re.sub(r'[^0-9\.]', '', str(v).split('-')[0])
    parts = [int(p) for p in cleaned.split('.') if p.isdigit()]
    return tuple(parts) if parts else ()

def check_discord_channel(channel_id, token):
    """Consulta la API de Discord para leer los últimos mensajes de un canal o foro de mods"""
    url = f"https://discord.com/api/v10/channels/{channel_id}/messages?limit=25"
    req = urllib.request.Request(url, headers={
        "Authorization": f"Bot {token}" if not token.startswith("Bearer ") else token,
        "User-Agent": "Gen1Recomp-Radar/1.0"
    })
    try:
        with urllib.request.urlopen(req, timeout=10) as r:
            return json.loads(r.read().decode('utf-8'))
    except Exception as e:
        print(f"[-] Error consultando Discord API: {e}")
        return []

def run_radar():
    pc_mods = get_installed_pc_mods()
    android_mods = get_installed_android_mods()
    catalog = fetch_community_catalog()
    
    print("\n" + "="*80)
    print(" [RADAR] MODS GEN1RECOMP - ESTADO DE LA COMUNIDAD")
    print("="*80)
    
    updates_available = []
    catalog_map = {}
    for m in catalog:
        mid = m.get("id") or m.get("name")
        catalog_map[mid] = m
        catalog_map[mid.lower()] = m

    for mod_id, pc_data in pc_mods.items():
        cat_mod = catalog_map.get(mod_id) or catalog_map.get(mod_id.lower()) or catalog_map.get(pc_data["name"].lower())
        android_data = android_mods.get(mod_id) or android_mods.get(mod_id.lower())
        
        pc_v = pc_data["version"]
        and_v = android_data["version"] if android_data else "-"
        cat_v = (cat_mod.get("version") or cat_mod.get("tag") or "N/A") if cat_mod else "N/A"
        
        p_t = version_to_tuple(pc_v)
        c_t = version_to_tuple(cat_v)
        
        has_update = (c_t > p_t) if (c_t and p_t) else False
        if has_update:
            updates_available.append({
                "id": mod_id,
                "name": pc_data["name"],
                "installed": pc_v,
                "latest": cat_v,
                "url": cat_mod.get("github") or (cat_mod.get("zip") and cat_mod["zip"].get("url")) or ""
            })

    print(f"\n[i] Total mods analizados en PC: {len(pc_mods)}")
    print(f"[i] Total mods detectados en Android: {len(android_mods)}")
    print(f"[i] Total mods en el archivo de la comunidad: {len(catalog)}")
    
    if updates_available:
        print("\n[*] ACTUALIZACIONES ENCONTRADAS:")
        for u in updates_available:
            print(f"  * {u['name']} ({u['id']}): v{u['installed']} -> Nueva version v{u['latest']}")
            if u['url']:
                print(f"    Descarga/Repo: {u['url']}")
    else:
        print("\n[OK] Todos tus mods instalados estan al dia o en versiones superiores a la lista publica.")
        
    print("\n" + "="*80)

if __name__ == "__main__":
    run_radar()
