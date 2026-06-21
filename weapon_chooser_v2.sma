/*
 * ╔══════════════════════════════════════════════════════════════╗
 * ║       Weapon Chooser  v2  —  CS 1.6 AMXX Plugin             ║
 * ╠══════════════════════════════════════════════════════════════╣
 * ║  Each round every player picks one of two loadouts:          ║
 * ║    Option 1 : AK-47  + Desert Eagle + HE + Smoke            ║
 * ║    Option 2 : M4A1   + Desert Eagle + HE + Smoke            ║
 * ║                                                              ║
 * ║  ★  ONLY ACTIVE ON:   de_dust   and   de_dust2              ║
 * ║     On any other map the plugin does nothing at all.         ║
 * ║                                                              ║
 * ║  ★ Requires modules: cstrike, hamsandwich                   ║
 * ║  ★ Compile: amxxpc weapon_chooser_v2.sma                    ║
 * ╚══════════════════════════════════════════════════════════════╝
 *
 *  
 *
 *  Author  : AC1D
 *  Version : 2.0
 */

#include <amxmodx>
#include <amxmisc>
#include <cstrike>
#include <fun>
#include <hamsandwich>

/* ─────────────────────────────────────────────────────────────────
 *  PLUGIN INFO
 * ───────────────────────────────────────────────────────────────── */
#define PLUGIN   "Weapon Chooser v2"
#define VERSION  "2.0"
#define AUTHOR   "AC1D"

/* ─────────────────────────────────────────────────────────────────
 *  ★  ALLOWED MAPS
 *  Add or remove map names here to control where plugin is active.
 *  Names are case-insensitive (compared in lowercase).
 * ───────────────────────────────────────────────────────────────── */
new const g_szAllowedMaps[][] =
{
    "de_dust",
    "de_dust2"
}
#define ALLOWED_MAP_COUNT  sizeof(g_szAllowedMaps)

/* ─────────────────────────────────────────────────────────────────
 *  AMMO AMOUNTS
 * ───────────────────────────────────────────────────────────────── */
#define AK47_AMMO    90
#define M4A1_AMMO    90
#define DEAGLE_AMMO  35

/* ─────────────────────────────────────────────────────────────────
 *  GLOBALS
 * ───────────────────────────────────────────────────────────────── */
new bool:g_bAllowedMap   = false   // true only when current map is allowed
new bool:g_bPickedWeapon[33]       // did this player already pick this round?

/* ─────────────────────────────────────────────────────────────────
 *  PLUGIN INIT
 * ───────────────────────────────────────────────────────────────── */
public plugin_init()
{
    register_plugin(PLUGIN, VERSION, AUTHOR)

    // Detect round start to show menus
    register_event("HLTV", "Event_RoundStart", "a", "1=0", "2=0")

    // Re-apply on individual player spawn (handles late joiners)
    RegisterHam(Ham_Spawn, "player", "FW_PlayerSpawn_Post", 1)

    // Check map immediately on init
    CheckCurrentMap()
}

/* ─────────────────────────────────────────────────────────────────
 *  MAP CHECK HELPERS
 * ───────────────────────────────────────────────────────────────── */

// Called once at startup — sets g_bAllowedMap flag
CheckCurrentMap()
{
    new szMap[32]
    get_mapname(szMap, charsmax(szMap))

    // Lowercase the map name for safe comparison
    strtolower(szMap)

    g_bAllowedMap = false

    for(new i = 0; i < ALLOWED_MAP_COUNT; i++)
    {
        if(equal(szMap, g_szAllowedMaps[i]))
        {
            g_bAllowedMap = true
            break
        }
    }

    if(g_bAllowedMap)
    {
        server_print("[Weapon Chooser v2] Active on map: %s", szMap)
    }
    else
    {
        server_print("[Weapon Chooser v2] Disabled on map: %s (not in allowed list)", szMap)
    }
}

/* ─────────────────────────────────────────────────────────────────
 *  CLIENT EVENTS
 * ───────────────────────────────────────────────────────────────── */
public client_putinserver(id)
{
    g_bPickedWeapon[id] = false
}

public client_disconnect(id)
{
    g_bPickedWeapon[id] = false
}

/* ─────────────────────────────────────────────────────────────────
 *  ROUND START  — show menu to all alive players
 * ───────────────────────────────────────────────────────────────── */
public Event_RoundStart()
{
    // Do nothing if this map is not in the allowed list
    if(!g_bAllowedMap) return

    // Reset pick-tracking for the new round
    for(new i = 1; i <= 32; i++)
        g_bPickedWeapon[i] = false

    // Show menu to every alive player (1-second delay lets the game settle)
    new iPlayers[32], iNum
    get_players(iPlayers, iNum, "a")   // "a" = alive only

    for(new i = 0; i < iNum; i++)
        set_task(1.0, "Task_ShowMenu", iPlayers[i])
}

/* ─────────────────────────────────────────────────────────────────
 *  PLAYER SPAWN HOOK — catch late-joiners and reconnections
 * ───────────────────────────────────────────────────────────────── */
public FW_PlayerSpawn_Post(id)
{
    if(!g_bAllowedMap)       return
    if(!is_user_alive(id))   return
    if(g_bPickedWeapon[id])  return   // already picked this round

    set_task(0.5, "Task_ShowMenu", id)
}

/* ─────────────────────────────────────────────────────────────────
 *  BUILD & SHOW WEAPON MENU
 * ───────────────────────────────────────────────────────────────── */
public Task_ShowMenu(id)
{
    if(!g_bAllowedMap)       return
    if(!is_user_alive(id))   return
    if(g_bPickedWeapon[id])  return

    new hMenu = menu_create("\r[Weapon Chooser]\w  Pick your loadout:", "CB_WeaponMenu")

    menu_additem(hMenu, "\yOption 1 \w| AK-47  + Deagle + HE + Smoke", "1", 0)
    menu_additem(hMenu, "\yOption 2 \w| M4A1   + Deagle + HE + Smoke", "2", 0)

    // Force the player to choose — no exit button
    menu_setprop(hMenu, MPROP_EXIT, MEXIT_NEVER)

    menu_display(id, hMenu, 0)
}

/* ─────────────────────────────────────────────────────────────────
 *  MENU CALLBACK
 * ───────────────────────────────────────────────────────────────── */
public CB_WeaponMenu(id, hMenu, iItem)
{
    // Player died while menu was open
    if(!is_user_alive(id))
    {
        menu_destroy(hMenu)
        return PLUGIN_HANDLED
    }

    // Retrieve item data ("1" or "2")
    new szData[4], szName[64]
    new iAccess, iCallback
    menu_item_getinfo(hMenu, iItem, iAccess,
        szData, charsmax(szData),
        szName, charsmax(szName), iCallback)

    new iChoice = str_to_num(szData)

    GiveWeapons(id, iChoice)
    g_bPickedWeapon[id] = true

    menu_destroy(hMenu)
    return PLUGIN_HANDLED
}

/* ─────────────────────────────────────────────────────────────────
 *  GIVE WEAPONS
 * ───────────────────────────────────────────────────────────────── */
GiveWeapons(id, iChoice)
{
    // ── 1. Strip everything ───────────────────────────────────────
    strip_user_weapons(id)

    // ── 2. Always: Knife + Desert Eagle + HE + Smoke ─────────────
    give_item(id, "weapon_knife")

    give_item(id, "weapon_deagle")
    cs_set_user_bpammo(id, CSW_DEAGLE, DEAGLE_AMMO)

    give_item(id, "weapon_hegrenade")
    give_item(id, "weapon_smokegrenade")

    // ── 3. Primary weapon based on choice ────────────────────────
    switch(iChoice)
    {
        case 1:   // AK-47
        {
            give_item(id, "weapon_ak47")
            cs_set_user_bpammo(id, CSW_AK47, AK47_AMMO)

            client_print(id, print_chat,
                "* [Weapons] AK-47 | Deagle | HE | Smoke — Good luck!")
        }
        case 2:   // M4A1
        {
            give_item(id, "weapon_m4a1")
            cs_set_user_bpammo(id, CSW_M4A1, M4A1_AMMO)

            client_print(id, print_chat,
                "* [Weapons] M4A1  | Deagle | HE | Smoke — Good luck!")
        }
        default:  // Fallback (should never happen)
        {
            give_item(id, "weapon_ak47")
            cs_set_user_bpammo(id, CSW_AK47, AK47_AMMO)
        }
    }
}

/* ─────────────────────────────────────────────────────────────────
 *  END OF PLUGIN
 * ─────────────────────────────────────────────────────────────────
 *
 *        "de_dust",       ← keep these
 *        "de_dust2",      ← keep these
 *        "de_inferno",    ← example: add any extra map like this
 *        "cs_assault"     ← example: add any extra map like this
 *    }
 *
 *  Then update:   #define ALLOWED_MAP_COUNT  sizeof(g_szAllowedMaps)
 *  (This is calculated automatically — no manual count needed.)
 *
 *  INSTALLATION
 *  ─────────────
 *  [ ] 1. Compile:  amxxpc weapon_chooser_v2.sma
 *  [ ] 2. Copy weapon_chooser_v2.amxx  →  addons/amxmodx/plugins/
 *  [ ] 3. Add to addons/amxmodx/configs/plugins.ini:
 *              weapon_chooser_v2.amxx
 *  [ ] 4. Enable modules in modules.ini:
 *              cstrike
 *              hamsandwich
 *  
 *
 * ───────────────────────────────────────────────────────────────── */
