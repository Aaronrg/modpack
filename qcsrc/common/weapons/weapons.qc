#ifndef WEAPONS_C
#define WEAPONS_C

#include "weapons.qh"

#if defined(CSQC)
	#include "../../dpdefs/csprogsdefs.qh"
	#include "../../client/defs.qh"
	#include "../constants.qh"
	#include "../stats.qh"
	#include "../../warpzonelib/anglestransform.qh"
	#include "../../warpzonelib/mathlib.qh"
	#include "../../warpzonelib/common.qh"
	#include "../../warpzonelib/client.qh"
	#include "../util.qh"
	#include "../buffs.qh"
	#include "../../client/autocvars.qh"
	#include "../deathtypes.qh"
	#include "../../csqcmodellib/interpolate.qh"
	#include "../../client/movetypes.qh"
	#include "../../client/main.qh"
	#include "../../csqcmodellib/cl_model.qh"
#elif defined(MENUQC)
#elif defined(SVQC)
	#include "../../dpdefs/progsdefs.qh"
    #include "../../dpdefs/dpextensions.qh"
    #include "../../warpzonelib/anglestransform.qh"
    #include "../../warpzonelib/mathlib.qh"
    #include "../../warpzonelib/common.qh"
    #include "../../warpzonelib/util_server.qh"
    #include "../../warpzonelib/server.qh"
    #include "../constants.qh"
    #include "../stats.qh"
    #include "../teams.qh"
    #include "../util.qh"
    #include "../buffs.qh"
    #include "../monsters/monsters.qh"
    #include "config.qh"
    #include "../../server/weapons/csqcprojectile.qh"
    #include "../../server/weapons/tracing.qh"
    #include "../../server/t_items.qh"
    #include "../../server/autocvars.qh"
    #include "../../server/constants.qh"
    #include "../../server/defs.qh"
    #include "../notifications.qh"
    #include "../deathtypes.qh"
    #include "../../server/mutators/mutators_include.qh"
    #include "../mapinfo.qh"
    #include "../../server/command/common.qh"
    #include "../../csqcmodellib/sv_model.qh"
    #include "../../server/portals.qh"
    #include "../../server/g_hook.qh"
#endif
#ifndef MENUQC
#include "calculations.qc"
#endif
#include "all.qh"

// WEAPON PLUGIN SYSTEM
entity weapon_info[WEP_MAXCOUNT];
entity dummy_weapon_info;

#if WEP_MAXCOUNT > 72
# error Kein Weltraum links auf dem Gerät
#endif

WepSet WepSet_FromWeapon(float a) {
	a -= WEP_FIRST;
#if WEP_MAXCOUNT > 24
	if(a >= 24) {
		a -= 24;
#if WEP_MAXCOUNT > 48
		if(a >= 24) {
			a -= 24;
			return '0 0 1' * power2of(a);
		}
#endif
		return '0 1 0' * power2of(a);
	}
#endif
	return '1 0 0' * power2of(a);
}
#ifdef SVQC
void WepSet_AddStat()
{
	addstat(STAT_WEAPONS, AS_INT, weapons_x);
#if WEP_MAXCOUNT > 24
	addstat(STAT_WEAPONS2, AS_INT, weapons_y);
#if WEP_MAXCOUNT > 48
	addstat(STAT_WEAPONS3, AS_INT, weapons_z);
#endif
#endif
}
void WepSet_AddStat_InMap()
{
	addstat(STAT_WEAPONSINMAP, AS_INT, weaponsinmap_x);
#if WEP_MAXCOUNT > 24
	addstat(STAT_WEAPONSINMAP2, AS_INT, weaponsinmap_y);
#if WEP_MAXCOUNT > 48
	addstat(STAT_WEAPONSINMAP3, AS_INT, weaponsinmap_z);
#endif
#endif
}
void WriteWepSet(float dst, WepSet w)
{
#if WEP_MAXCOUNT > 48
	WriteInt72_t(dst, w);
#elif WEP_MAXCOUNT > 24
	WriteInt48_t(dst, w);
#else
	WriteInt24_t(dst, w.x);
#endif
}
#endif
#ifdef CSQC
WepSet WepSet_GetFromStat()
{
	WepSet w = '0 0 0';
	w.x = getstati(STAT_WEAPONS);
#if WEP_MAXCOUNT > 24
	w.y = getstati(STAT_WEAPONS2);
#if WEP_MAXCOUNT > 48
	w.z = getstati(STAT_WEAPONS3);
#endif
#endif
	return w;
}
WepSet WepSet_GetFromStat_InMap()
{
	WepSet w = '0 0 0';
	w_x = getstati(STAT_WEAPONSINMAP);
#if WEP_MAXCOUNT > 24
	w_y = getstati(STAT_WEAPONSINMAP2);
#if WEP_MAXCOUNT > 48
	w_z = getstati(STAT_WEAPONSINMAP3);
#endif
#endif
	return w;
}
WepSet ReadWepSet()
{
#if WEP_MAXCOUNT > 48
	return ReadInt72_t();
#elif WEP_MAXCOUNT > 24
	return ReadInt48_t();
#else
	return ReadInt24_t() * '1 0 0';
#endif
}
#endif

void register_weapon(
	int id,
	WepSet bit,
	float(float) func,
	.float ammotype,
	float i,
	float weapontype,
	float pickupbasevalue,
	vector clr,
	string modelname,
	string simplemdl,
	string crosshair,
	string wepimg,
	string refname,
	string wepname)
{
	entity e;
	weapon_info[id - 1] = e = spawn();
	e.classname = "weapon_info";
	e.weapon = id;
	e.weapons = bit;
	e.weapon_func = func;
	e.ammo_field = ammotype;
	e.impulse = i;
	e.spawnflags = weapontype;
	e.bot_pickupbasevalue = pickupbasevalue;
	e.wpcolor = clr;
	e.wpmodel = strzone(strcat("wpn-", ftos(id)));
	e.mdl = modelname;
#ifdef CSQC
	e.model = strzone(strcat("models/weapons/g_", modelname, ".md3"));
#elif defined(SVQC)
	e.model = strzone(W_Model(strcat("g_", modelname, ".md3")));
#endif
	e.w_simplemdl = strzone(simplemdl); // simpleitems weapon model/image
	e.w_crosshair = strzone(car(crosshair));
	string s = cdr(crosshair);
	e.w_crosshair_size = ((s != "") ? stof(s) : 1); // so that we can scale the crosshair from code (for compat)
	e.model2 = strzone(wepimg);
	e.netname = refname;
	e.message = wepname;

	#ifdef CSQC
	func(WR_INIT);
	#endif
}
float w_null(float dummy)
{
	return 0;
}
void register_weapons_done()
{
	dummy_weapon_info = spawn();
	dummy_weapon_info.classname = "weapon_info";
	dummy_weapon_info.weapon = 0; // you can recognize dummies by this
	dummy_weapon_info.weapons = '0 0 0';
	dummy_weapon_info.netname = "";
	dummy_weapon_info.message = "AOL CD Thrower";
	dummy_weapon_info.weapon_func = w_null;
	dummy_weapon_info.wpmodel = "";
	dummy_weapon_info.mdl = "";
	dummy_weapon_info.model = "";
	dummy_weapon_info.spawnflags = 0;
	dummy_weapon_info.impulse = -1;
	dummy_weapon_info.bot_pickupbasevalue = 0;
	dummy_weapon_info.ammo_field = ammo_none;

	dummy_weapon_info.w_crosshair = "gfx/crosshair1";
	dummy_weapon_info.w_crosshair_size = 1;
	dummy_weapon_info.model2 = "";

	int i;
	weaponorder_byid = "";
	for(i = WEP_MAXCOUNT; i >= 1; --i)
		if(weapon_info[i-1])
			weaponorder_byid = strcat(weaponorder_byid, " ", ftos(i));
	weaponorder_byid = strzone(substring(weaponorder_byid, 1, strlen(weaponorder_byid) - 1));
}
entity get_weaponinfo(int id)
{
	entity w;
	if(id < WEP_FIRST || id > WEP_LAST)
		return dummy_weapon_info;
	w = weapon_info[id - 1];
	if(w)
		return w;
	return dummy_weapon_info;
}
string W_FixWeaponOrder(string order, float complete)
{
	return fixPriorityList(order, WEP_FIRST, WEP_LAST, 230 - WEP_FIRST, complete);
}
string W_NameWeaponOrder_MapFunc(string s)
{
	entity wi;
	if(s == "0" || stof(s))
	{
		wi = get_weaponinfo(stof(s));
		if(wi != dummy_weapon_info)
			return wi.netname;
	}
	return s;
}

string W_UndeprecateName(string s)
{
	switch ( s )
	{
		case "nex"            : return "vortex";
		case "rocketlauncher" : return "devastator";
		case "laser"          : return "blaster";
		case "minstanex"      : return "vaporizer";
		case "grenadelauncher": return "mortar";
		case "uzi"            : return "machinegun";
		default               : return s;
	}
}
string W_NameWeaponOrder(string order)
{
	return mapPriorityList(order, W_NameWeaponOrder_MapFunc);
}
string W_NumberWeaponOrder_MapFunc(string s)
{
	float i;
	if(s == "0" || stof(s))
		return s;
	s = W_UndeprecateName(s);
	for(i = WEP_FIRST; i <= WEP_LAST; ++i)
		if(s == get_weaponinfo(i).netname)
			return ftos(i);
	return s;
}
string W_NumberWeaponOrder(string order)
{
	return mapPriorityList(order, W_NumberWeaponOrder_MapFunc);
}

float W_FixWeaponOrder_BuildImpulseList_buf[WEP_MAXCOUNT];
string W_FixWeaponOrder_BuildImpulseList_order;
void W_FixWeaponOrder_BuildImpulseList_swap(int i, int j, entity pass)
{
	float h;
	h = W_FixWeaponOrder_BuildImpulseList_buf[i];
	W_FixWeaponOrder_BuildImpulseList_buf[i] = W_FixWeaponOrder_BuildImpulseList_buf[j];
	W_FixWeaponOrder_BuildImpulseList_buf[j] = h;
}
float W_FixWeaponOrder_BuildImpulseList_cmp(int i, int j, entity pass)
{
	entity e1, e2;
	float d;
	e1 = get_weaponinfo(W_FixWeaponOrder_BuildImpulseList_buf[i]);
	e2 = get_weaponinfo(W_FixWeaponOrder_BuildImpulseList_buf[j]);
	d = (e1.impulse + 9) % 10 - (e2.impulse + 9) % 10;
	if(d != 0)
		return -d; // high impulse first!
	return
		strstrofs(strcat(" ", W_FixWeaponOrder_BuildImpulseList_order, " "), sprintf(" %d ", W_FixWeaponOrder_BuildImpulseList_buf[i]), 0)
		-
		strstrofs(strcat(" ", W_FixWeaponOrder_BuildImpulseList_order, " "), sprintf(" %d ", W_FixWeaponOrder_BuildImpulseList_buf[j]), 0)
		; // low char index first!
}
string W_FixWeaponOrder_BuildImpulseList(string o)
{
	int i;
	W_FixWeaponOrder_BuildImpulseList_order = o;
	for(i = WEP_FIRST; i <= WEP_LAST; ++i)
		W_FixWeaponOrder_BuildImpulseList_buf[i - WEP_FIRST] = i;
	heapsort(WEP_LAST - WEP_FIRST + 1, W_FixWeaponOrder_BuildImpulseList_swap, W_FixWeaponOrder_BuildImpulseList_cmp, world);
	o = "";
	for(i = WEP_FIRST; i <= WEP_LAST; ++i)
		o = strcat(o, " ", ftos(W_FixWeaponOrder_BuildImpulseList_buf[i - WEP_FIRST]));
	W_FixWeaponOrder_BuildImpulseList_order = string_null;
	return substring(o, 1, -1);
}

string W_FixWeaponOrder_AllowIncomplete(string order)
{
	return W_FixWeaponOrder(order, 0);
}

string W_FixWeaponOrder_ForceComplete(string order)
{
	if(order == "")
		order = W_NumberWeaponOrder(cvar_defstring("cl_weaponpriority"));
	return W_FixWeaponOrder(order, 1);
}

void W_RandomWeapons(entity e, float n)
{
	float i, j;
	WepSet remaining;
	WepSet result;
	remaining = e.weapons;
	result = '0 0 0';
	for(i = 0; i < n; ++i)
	{
		RandomSelection_Init();
		for(j = WEP_FIRST; j <= WEP_LAST; ++j)
			if(remaining & WepSet_FromWeapon(j))
				RandomSelection_Add(world, j, string_null, 1, 1);
		result |= WepSet_FromWeapon(RandomSelection_chosen_float);
		remaining &= ~WepSet_FromWeapon(RandomSelection_chosen_float);
	}
	e.weapons = result;
}

string GetAmmoPicture(.float ammotype)
{
	switch(ammotype)
	{
		case ammo_shells:  return "ammo_shells";
		case ammo_nails:   return "ammo_bullets";
		case ammo_rockets: return "ammo_rockets";
		case ammo_cells:   return "ammo_cells";
		case ammo_plasma:  return "ammo_cells";
		case ammo_supercells: return "ammo_supercells";
		case ammo_fuel:    return "ammo_fuel";
		default: return ""; // wtf, no ammo type?
	}
}

#ifdef CSQC
.float GetAmmoFieldFromNum(int i)
{
	switch(i)
	{
		case 0: return ammo_shells;
		case 1: return ammo_nails;
		case 2: return ammo_rockets;
		case 3: return ammo_cells;
		case 4: return ammo_plasma;
		case 5: return ammo_supercells;
		case 6: return ammo_fuel;
		default: return ammo_none;
	}
}

int GetAmmoStat(.float ammotype)
{
	switch(ammotype)
	{
		case ammo_shells: return STAT_SHELLS;
		case ammo_nails: return STAT_NAILS;
		case ammo_rockets: return STAT_ROCKETS;
		case ammo_cells: return STAT_CELLS;
		case ammo_plasma: return STAT_PLASMA;
		case ammo_supercells: return STAT_SUPERCELLS;
		case ammo_fuel: return STAT_FUEL;
		default: return -1;
	}
}
#endif

#ifdef SVQC
string W_Sound(string w_snd)
{
	if(autocvar_sv_weapons_sounddir != "" && autocvar_sv_weapons_sounddir != "default")
	{
		string thesnd = sprintf("weapons_%s/%s", autocvar_sv_weapons_sounddir, w_snd);
		if(fexists(strcat("sound/", thesnd, ".ogg")))
			return strcat(thesnd, ".wav");

		if(fexists(strcat("sound/", thesnd, ".wav")))
			return strcat(thesnd, ".wav");

		if(fexists(strcat("sound/", thesnd, ".flac")))
			return strcat(thesnd, ".wav");
	}
	return strcat("weapons/", w_snd, ".wav");
}

string W_Model(string w_mdl)
{
	if(autocvar_sv_weapons_modeloverride != "" && autocvar_sv_weapons_modeloverride != "default")
	{
		string themdl = sprintf("models/weapons_%s/%s", autocvar_sv_weapons_modeloverride, w_mdl);
		if(fexists(themdl))
			return themdl;
	}
	return strcat("models/weapons/", w_mdl);
}

#endif

#endif
