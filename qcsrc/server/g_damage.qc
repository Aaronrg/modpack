#include "g_damage.qh"

#if defined(CSQC)
#elif defined(MENUQC)
#elif defined(SVQC)
    #include "../warpzonelib/common.qh"
    #include "../common/constants.qh"
    #include "../common/buffs.qh"
    #include "../common/teams.qh"
    #include "../common/util.qh"
    #include "../common/weapons/weapons.qh"
    #include "weapons/accuracy.qh"
    #include "weapons/csqcprojectile.qh"
    #include "weapons/selection.qh"
    #include "t_items.qh"
    #include "autocvars.qh"
    #include "constants.qh"
    #include "defs.qh"
	#include "../common/effects.qh"
    #include "../common/notifications.qh"
    #include "../common/deathtypes.qh"
    #include "mutators/mutators_include.qh"
    #include "../common/turrets/sv_turrets.qh"
    #include "../common/vehicles/sv_vehicles.qh"
    #include "../csqcmodellib/sv_model.qh"
    #include "../common/playerstats.qh"
    #include "g_hook.qh"
    #include "scores.qh"
    #include "spawnpoints.qh"
#endif

float Damage_DamageInfo_SendEntity(entity to, float sf)
{
	WriteByte(MSG_ENTITY, ENT_CLIENT_DAMAGEINFO);
	WriteShort(MSG_ENTITY, self.projectiledeathtype);
	WriteCoord(MSG_ENTITY, floor(self.origin.x));
	WriteCoord(MSG_ENTITY, floor(self.origin.y));
	WriteCoord(MSG_ENTITY, floor(self.origin.z));
	WriteByte(MSG_ENTITY, bound(1, self.dmg, 255));
	WriteByte(MSG_ENTITY, bound(0, self.dmg_radius, 255));
	WriteByte(MSG_ENTITY, bound(1, self.dmg_edge, 255));
	WriteShort(MSG_ENTITY, self.oldorigin.x);
	WriteByte(MSG_ENTITY, self.species);
	return true;
}

void Damage_DamageInfo(vector org, float coredamage, float edgedamage, float rad, vector force, float deathtype, float bloodtype, entity dmgowner)
{
	// TODO maybe call this from non-edgedamage too?
	// TODO maybe make the client do the particle effects for the weapons and the impact sounds using this info?

	entity e;

	if(!sound_allowed(MSG_BROADCAST, dmgowner))
		deathtype |= 0x8000;

	e = spawn();
	setorigin(e, org);
	e.projectiledeathtype = deathtype;
	e.dmg = coredamage;
	e.dmg_edge = edgedamage;
	e.dmg_radius = rad;
	e.dmg_force = vlen(force);
	e.velocity = force;
	e.oldorigin_x = compressShortVector(e.velocity);
	e.species = bloodtype;

	Net_LinkEntity(e, false, 0.2, Damage_DamageInfo_SendEntity);
}

float IsFlying(entity a)
{
	if(a.flags & FL_ONGROUND)
		return 0;
	if(a.waterlevel >= WATERLEVEL_SWIMMING)
		return 0;
	traceline(a.origin, a.origin - '0 0 48', MOVE_NORMAL, a);
	if(trace_fraction < 1)
		return 0;
	return 1;
}

void UpdateFrags(entity player, float f)
{
	PlayerTeamScore_AddScore(player, f);
}

void GiveFrags (entity attacker, entity targ, float f, float deathtype)
{
	// TODO route through PlayerScores instead
	if(gameover) return;

	if(f < 0)
	{
		if(targ == attacker)
		{
			// suicide
			PlayerScore_Add(attacker, SP_SUICIDES, 1);
		}
		else
		{
			// teamkill
			PlayerScore_Add(attacker, SP_KILLS, -1); // or maybe add a teamkills field?
		}
	}
	else
	{
		// regular frag
		PlayerScore_Add(attacker, SP_KILLS, 1);
		if(targ.playerid)
			PS_GR_P_ADDVAL(attacker, sprintf("kills-%d", targ.playerid), 1);
	}

	PlayerScore_Add(targ, SP_DEATHS, 1);

	if(targ != attacker) // not for suicides
	if(g_weaponarena_random)
	{
		// after a frag, exchange the current weapon (or the culprit, if detectable) by a new random weapon
		float culprit;
		culprit = DEATH_WEAPONOF(deathtype);
		if(!culprit)
			culprit = attacker.weapon;
		else if(!(attacker.weapons & WepSet_FromWeapon(culprit)))
			culprit = attacker.weapon;

		if(g_weaponarena_random_with_blaster && culprit == WEP_BLASTER) // WEAPONTODO: Shouldn't this be in a mutator?
		{
			// no exchange
		}
		else
		{
			if(!GiveFrags_randomweapons)
			{
				GiveFrags_randomweapons = spawn();
				GiveFrags_randomweapons.classname = "GiveFrags_randomweapons";
			}

			if(warmup_stage)
				GiveFrags_randomweapons.weapons = WARMUP_START_WEAPONS;
			else
				GiveFrags_randomweapons.weapons = start_weapons;

			// all others (including the culprit): remove
			GiveFrags_randomweapons.weapons &= ~attacker.weapons;
			GiveFrags_randomweapons.weapons &= ~WepSet_FromWeapon(culprit);

			// among the remaining ones, choose one by random
			W_RandomWeapons(GiveFrags_randomweapons, 1);

			if(GiveFrags_randomweapons.weapons)
			{
				attacker.weapons |= GiveFrags_randomweapons.weapons;
				attacker.weapons &= ~WepSet_FromWeapon(culprit);
			}
		}

		// after a frag, choose another random weapon set
		if (!(attacker.weapons & WepSet_FromWeapon(attacker.weapon)))
			W_SwitchWeapon_Force(attacker, w_getbestweapon(attacker));
	}

	// FIXME fix the mess this is (we have REAL points now!)
	entity oldself;
	oldself = self;
	self = attacker;
	frag_attacker = attacker;
	frag_target = targ;
	frag_score = f;
	if(MUTATOR_CALLHOOK(GiveFragsForKill))
	{
		f = frag_score;
		self = oldself;
	}
	else
	{
		self = oldself;
	}

	attacker.totalfrags += f;

	if(f)
		UpdateFrags(attacker, f);
}

string AppendItemcodes(string s, entity player)
{
	float w;
	w = player.weapon;
	//if(w == 0)
	//	w = player.switchweapon;
	if(w == 0)
		w = player.cnt; // previous weapon!
	s = strcat(s, ftos(w));
	if(player.flagcarried != world)
		s = strcat(s, "F");
	if(player.BUTTON_CHAT)
		s = strcat(s, "T");
	return s;
}

void LogDeath(string mode, float deathtype, entity killer, entity killed)
{
	string s;
	if(!autocvar_sv_eventlog)
		return;
	s = strcat(":kill:", mode);
	s = strcat(s, ":", ftos(killer.playerid));
	s = strcat(s, ":", ftos(killed.playerid));
	s = strcat(s, ":type=", Deathtype_Name(deathtype));
	s = strcat(s, ":items=");
	s = AppendItemcodes(s, killer);
	if(killed != killer)
	{
		s = strcat(s, ":victimitems=");
		s = AppendItemcodes(s, killed);
	}
	GameLogEcho(s);
}

void Obituary_SpecialDeath(
	entity notif_target,
	float murder,
	float deathtype,
	string s1, string s2, string s3,
	float f1, float f2, float f3)
{
	if(DEATH_ISSPECIAL(deathtype))
	{
		entity deathent = deathtypes[(deathtype - DT_FIRST)];
		if (!deathent) { backtrace("Obituary_SpecialDeath: Could not find deathtype entity!\n"); return; }

		if(murder)
		{
			if(deathent.death_msgmurder)
			{
				Send_Notification_WOCOVA(
					NOTIF_ONE,
					notif_target,
					MSG_MULTI,
					deathent.death_msgmurder.nent_id,
					s1, s2, s3, "",
					f1, f2, f3, 0
				);
				Send_Notification_WOCOVA(
					NOTIF_ALL_EXCEPT,
					notif_target,
					MSG_INFO,
					deathent.death_msgmurder.nent_msginfo.nent_id,
					s1, s2, s3, "",
					f1, f2, f3, 0
				);
			}
		}
		else
		{
			if(deathent.death_msgself)
			{
				Send_Notification_WOCOVA(
					NOTIF_ONE,
					notif_target,
					MSG_MULTI,
					deathent.death_msgself.nent_id,
					s1, s2, s3, "",
					f1, f2, f3, 0
				);
				Send_Notification_WOCOVA(
					NOTIF_ALL_EXCEPT,
					notif_target,
					MSG_INFO,
					deathent.death_msgself.nent_msginfo.nent_id,
					s1, s2, s3, "",
					f1, f2, f3, 0
				);
			}
		}
	}
	else { backtrace("Obituary_SpecialDeath called without a special deathtype?\n"); return; }
}

float Obituary_WeaponDeath(
	entity notif_target,
	float murder,
	float deathtype,
	string s1, string s2, string s3,
	float f1, float f2)
{
	float death_weapon = DEATH_WEAPONOF(deathtype);
	if(death_weapon)
	{
		w_deathtype = deathtype;
		float death_message = WEP_ACTION(death_weapon, ((murder) ? WR_KILLMESSAGE : WR_SUICIDEMESSAGE));
		w_deathtype = false;

		if(death_message)
		{
			Send_Notification_WOCOVA(
				NOTIF_ONE,
				notif_target,
				MSG_MULTI,
				death_message,
				s1, s2, s3, "",
				f1, f2, 0, 0
			);
			Send_Notification_WOCOVA(
				NOTIF_ALL_EXCEPT,
				notif_target,
				MSG_INFO,
				msg_multi_notifs[death_message - 1].nent_msginfo.nent_id,
				s1, s2, s3, "",
				f1, f2, 0, 0
			);
		}
		else
		{
			dprintf(
				"Obituary_WeaponDeath(): ^1Deathtype ^7(%d)^1 has no notification for weapon %d!\n",
				deathtype,
				death_weapon
			);
		}

		return true;
	}
	return false;
}

void Obituary(entity attacker, entity inflictor, entity targ, float deathtype)
{
	// Sanity check
	if (!IS_PLAYER(targ)) { backtrace("Obituary called on non-player?!\n"); return; }

	// Declarations
	float notif_firstblood = false;
	float kill_count_to_attacker, kill_count_to_target;

	// Set final information for the death
	targ.death_origin = targ.origin;
	if(targ != attacker) { targ.killer_origin = attacker.origin; }
	string deathlocation = (autocvar_notification_server_allows_location ? NearestLocation(targ.death_origin) : "");

	#ifdef NOTIFICATIONS_DEBUG
	Debug_Notification(
		sprintf(
			"Obituary(%s, %s, %s, %s = %d);\n",
			attacker.netname,
			inflictor.netname,
			targ.netname,
			Deathtype_Name(deathtype),
			deathtype
		)
	);
	#endif

	// =======
	// SUICIDE
	// =======
	if(targ == attacker)
	{
		if(DEATH_ISSPECIAL(deathtype))
		{
			if(deathtype == DEATH_TEAMCHANGE || deathtype == DEATH_AUTOTEAMCHANGE)
			{
				Obituary_SpecialDeath(targ, false, deathtype, targ.netname, deathlocation, "", targ.team, 0, 0);
			}
			else
			{
				switch(deathtype)
				{
					case DEATH_MIRRORDAMAGE:
					{
						Obituary_SpecialDeath(targ, false, deathtype, targ.netname, deathlocation, "", targ.killcount, 0, 0);
						break;
					}

					default:
					{
						Obituary_SpecialDeath(targ, false, deathtype, targ.netname, deathlocation, "", targ.killcount, 0, 0);
						break;
					}
				}
			}
		}
		else if (!Obituary_WeaponDeath(targ, false, deathtype, targ.netname, deathlocation, "", targ.killcount, 0))
		{
			backtrace("SUICIDE: what the hell happened here?\n");
			return;
		}
		LogDeath("suicide", deathtype, targ, targ);
		GiveFrags(attacker, targ, -1, deathtype);
	}

	// ======
	// MURDER
	// ======
	else if(IS_PLAYER(attacker))
	{
		if(SAME_TEAM(attacker, targ))
		{
			LogDeath("tk", deathtype, attacker, targ);
			GiveFrags(attacker, targ, -1, deathtype);

			attacker.killcount = 0;

			Send_Notification(NOTIF_ONE, attacker, MSG_CENTER, CENTER_DEATH_TEAMKILL_FRAG, targ.netname);
			Send_Notification(NOTIF_ONE, targ, MSG_CENTER, CENTER_DEATH_TEAMKILL_FRAGGED, attacker.netname);
			Send_Notification(NOTIF_ALL, world, MSG_INFO, APP_TEAM_NUM_4(targ.team, INFO_DEATH_TEAMKILL_), targ.netname, attacker.netname, deathlocation, targ.killcount);

			// In this case, the death message will ALWAYS be "foo was betrayed by bar"
			// No need for specific death/weapon messages...
		}
		else
		{
			LogDeath("frag", deathtype, attacker, targ);
			GiveFrags(attacker, targ, 1, deathtype);

			attacker.taunt_soundtime = time + 1;
			attacker.killcount = attacker.killcount + 1;

			// sprees 2 and 8 are blocked by "" value, so no sending
			#define SPREE_ITEM(counta,countb,center,normal,gentle) \
				case counta: \
				{ \
					Send_Notification(NOTIF_ONE, attacker, MSG_ANNCE, ANNCE_KILLSTREAK_##countb); \
					PS_GR_P_ADDVAL(attacker, PLAYERSTATS_ACHIEVEMENT_KILL_SPREE_##counta, 1); \
					break; \
				}
			switch(attacker.killcount)
			{
				KILL_SPREE_LIST
				default: break;
			}
			#undef SPREE_ITEM

			if(!checkrules_firstblood)
			{
				checkrules_firstblood = true;
				notif_firstblood = true; // modify the current messages so that they too show firstblood information
				PS_GR_P_ADDVAL(attacker, PLAYERSTATS_ACHIEVEMENT_FIRSTBLOOD, 1);
				PS_GR_P_ADDVAL(targ, PLAYERSTATS_ACHIEVEMENT_FIRSTVICTIM, 1);

#ifdef JEFF
				Send_Notification(NOTIF_ALL, world, MSG_ANNCE, ANNCE_JEFF_FIRSTBLOOD);
#endif

				// tell spree_inf and spree_cen that this is a first-blood and first-victim event
				kill_count_to_attacker = -1;
				kill_count_to_target = -2;
			}
			else
			{
				kill_count_to_attacker = attacker.killcount;
				kill_count_to_target = 0;
			}

			if(targ.istypefrag)
			{
				Send_Notification(
					NOTIF_ONE,
					attacker,
					MSG_CHOICE,
					CHOICE_TYPEFRAG,
					targ.netname,
					kill_count_to_attacker,
					(IS_BOT_CLIENT(targ) ? NO_MSG : targ.ping)
				);
				Send_Notification(
					NOTIF_ONE,
					targ,
					MSG_CHOICE,
					CHOICE_TYPEFRAGGED,
					attacker.netname,
					kill_count_to_target,
					attacker.health,
					attacker.armorvalue,
					(IS_BOT_CLIENT(attacker) ? NO_MSG : attacker.ping)
				);
			}
			else
			{
				Send_Notification(
					NOTIF_ONE,
					attacker,
					MSG_CHOICE,
					CHOICE_FRAG,
					targ.netname,
					kill_count_to_attacker,
					(IS_BOT_CLIENT(targ) ? NO_MSG : targ.ping)
				);
				Send_Notification(
					NOTIF_ONE,
					targ,
					MSG_CHOICE,
					CHOICE_FRAGGED,
					attacker.netname,
					kill_count_to_target,
					attacker.health,
					attacker.armorvalue,
					(IS_BOT_CLIENT(attacker) ? NO_MSG : attacker.ping)
				);
			}

			float f3 = 0;
			if(deathtype == DEATH_BUFF)
				f3 = attacker.buffs;

			if (!Obituary_WeaponDeath(targ, true, deathtype, targ.netname, attacker.netname, deathlocation, targ.killcount, kill_count_to_attacker))
				Obituary_SpecialDeath(targ, true, deathtype, targ.netname, attacker.netname, deathlocation, targ.killcount, kill_count_to_attacker, f3);
		}
	}

	// =============
	// ACCIDENT/TRAP
	// =============
	else
	{
		switch(deathtype)
		{
			// For now, we're just forcing HURTTRIGGER to behave as "DEATH_VOID" and giving it no special options...
			// Later on you will only be able to make custom messages using DEATH_CUSTOM,
			// and there will be a REAL DEATH_VOID implementation which mappers will use.
			case DEATH_HURTTRIGGER:
			{
				Obituary_SpecialDeath(targ, false, deathtype,
					targ.netname,
					inflictor.message,
					deathlocation,
					targ.killcount,
					0,
					0);
				break;
			}

			case DEATH_CUSTOM:
			{
				Obituary_SpecialDeath(targ, false, deathtype,
					targ.netname,
					((strstrofs(deathmessage, "%", 0) < 0) ? strcat("%s ", deathmessage) : deathmessage),
					deathlocation,
					targ.killcount,
					0,
					0);
				break;
			}

			default:
			{
				Obituary_SpecialDeath(targ, false, deathtype, targ.netname, deathlocation, "", targ.killcount, 0, 0);
				break;
			}
		}

		LogDeath("accident", deathtype, targ, targ);
		GiveFrags(targ, targ, -1, deathtype);

		if(PlayerScore_Add(targ, SP_SCORE, 0) == -5)
		{
			Send_Notification(NOTIF_ONE, targ, MSG_ANNCE, ANNCE_ACHIEVEMENT_BOTLIKE);
			PS_GR_P_ADDVAL(attacker, PLAYERSTATS_ACHIEVEMENT_BOTLIKE, 1);
		}
	}

	// reset target kill count
	if(targ.killcount) { targ.killcount = 0; }
}

void Ice_Think()
{
	if(!self.owner.frozen || self.owner.iceblock != self)
	{
		remove(self);
		return;
	}
	setorigin(self, self.owner.origin - '0 0 16');
	self.nextthink = time;
}

void Freeze (entity targ, float freeze_time, float frozen_type, float show_waypoint)
{
	if(!IS_PLAYER(targ) && !IS_MONSTER(targ)) // only specified entities can be freezed
		return;

	if(targ.frozen)
		return;

	float targ_maxhealth = ((IS_MONSTER(targ)) ? targ.max_health : start_health);

	targ.frozen = frozen_type;
	targ.revive_progress = ((frozen_type == 3) ? 1 : 0);
	targ.health = ((frozen_type == 3) ? targ_maxhealth : 1);
	targ.revive_speed = freeze_time;

	entity ice, head;
	ice = spawn();
	ice.owner = targ;
	ice.classname = "ice";
	ice.scale = targ.scale;
	ice.think = Ice_Think;
	ice.nextthink = time;
	ice.frame = floor(random() * 21); // ice model has 20 different looking frames
	setmodel(ice, "models/ice/ice.md3");
	ice.alpha = 1;
	ice.colormod = Team_ColorRGB(targ.team);
	ice.glowmod = ice.colormod;
	targ.iceblock = ice;
	targ.revival_time = 0;

	entity oldself;
	oldself = self;
	self = ice;
	Ice_Think();
	self = oldself;

	RemoveGrapplingHook(targ);

	FOR_EACH_PLAYER(head)
	if(head.hook.aiment == targ)
		RemoveGrapplingHook(head);

	// add waypoint
	if(show_waypoint)
		WaypointSprite_Spawn("frozen", 0, 0, targ, '0 0 64', world, targ.team, targ, waypointsprite_attached, true, RADARICON_WAYPOINT, '0.25 0.90 1');
}

void Unfreeze (entity targ)
{
	if(targ.frozen && targ.frozen != 3) // only reset health if target was frozen
		targ.health = ((IS_PLAYER(targ)) ? start_health : targ.max_health);

	entity head;
	targ.frozen = 0;
	targ.revive_progress = 0;
	targ.revival_time = time;

	WaypointSprite_Kill(targ.waypointsprite_attached);

	FOR_EACH_PLAYER(head)
	if(head.hook.aiment == targ)
		RemoveGrapplingHook(head);

	// remove the ice block
	if(targ.iceblock)
		remove(targ.iceblock);
	targ.iceblock = world;
}

void Damage (entity targ, entity inflictor, entity attacker, float damage, float deathtype, vector hitloc, vector force)
{
	float mirrordamage;
	float mirrorforce;
	float complainteamdamage = 0;
	entity attacker_save;
	mirrordamage = 0;
	mirrorforce = 0;

	if (gameover || targ.killcount == -666)
		return;

	entity oldself;
	oldself = self;
	self = targ;
        damage_targ = targ;
        damage_inflictor = inflictor;
        damage_attacker = attacker;
		attacker_save = attacker;

	if(IS_PLAYER(targ))
		if(targ.hook)
			if(targ.hook.aiment)
				if(targ.hook.aiment == attacker)
					RemoveGrapplingHook(targ); // STOP THAT, you parasite!

	// special rule: gravity bomb does not hit team mates (other than for disconnecting the hook)
	if(DEATH_ISWEAPON(deathtype, WEP_HOOK) || DEATH_ISWEAPON(deathtype, WEP_TUBA))
	{
		if(IS_PLAYER(targ))
			if(SAME_TEAM(targ, attacker))
			{
				self = oldself;
				return;
			}
	}

	if(deathtype == DEATH_KILL || deathtype == DEATH_TEAMCHANGE || deathtype == DEATH_AUTOTEAMCHANGE)
	{
		// exit the vehicle before killing (fixes a crash)
		if(IS_PLAYER(targ) && targ.vehicle)
			vehicles_exit(VHEF_RELEASE);

		// These are ALWAYS lethal
		// No damage modification here
		// Instead, prepare the victim for his death...
		targ.armorvalue = 0;
		targ.spawnshieldtime = 0;
		targ.health = 0.9; // this is < 1
		targ.flags -= targ.flags & FL_GODMODE;
		damage = 100000;
	}
	else if(deathtype == DEATH_MIRRORDAMAGE || deathtype == DEATH_NOAMMO)
	{
		// no processing
	}
	else
	{
		// nullify damage if teamplay is on
		if(deathtype != DEATH_TELEFRAG)
		if(IS_PLAYER(attacker))
		{
			if(IS_PLAYER(targ) && targ != attacker && (IS_INDEPENDENT_PLAYER(attacker) || IS_INDEPENDENT_PLAYER(targ)))
			{
				damage = 0;
				force = '0 0 0';
			}
			else if(SAME_TEAM(attacker, targ))
			{
				if(autocvar_teamplay_mode == 1)
					damage = 0;
				else if(attacker != targ)
				{
					if(autocvar_teamplay_mode == 3)
						damage = 0;
					else if(autocvar_teamplay_mode == 4)
					{
						if(IS_PLAYER(targ) && targ.deadflag == DEAD_NO)
						{
							attacker.dmg_team = attacker.dmg_team + damage;
							complainteamdamage = attacker.dmg_team - autocvar_g_teamdamage_threshold;
							if(complainteamdamage > 0)
								mirrordamage = autocvar_g_mirrordamage * complainteamdamage;
							mirrorforce = autocvar_g_mirrordamage * vlen(force);
							damage = autocvar_g_friendlyfire * damage;
							// mirrordamage will be used LATER

							if(autocvar_g_mirrordamage_virtual)
							{
								vector v  = healtharmor_applydamage(attacker.armorvalue, autocvar_g_balance_armor_blockpercent, deathtype, mirrordamage, autocvar_g_balance_armor_block_bycount);
								attacker.dmg_take += v.x;
								attacker.dmg_save += v.y;
								attacker.dmg_inflictor = inflictor;
								mirrordamage = v.z;
								mirrorforce = 0;
							}

							if(autocvar_g_friendlyfire_virtual)
							{
								vector v = healtharmor_applydamage(targ.armorvalue, autocvar_g_balance_armor_blockpercent, deathtype, damage, autocvar_g_balance_armor_block_bycount);
								targ.dmg_take += v.x;
								targ.dmg_save += v.y;
								targ.dmg_inflictor = inflictor;
								damage = 0;
								if(!autocvar_g_friendlyfire_virtual_force)
									force = '0 0 0';
							}
						}
						else
							damage = 0;
					}
				}
			}
		}

		if (!DEATH_ISSPECIAL(deathtype))
		{
			damage *= g_weapondamagefactor;
			mirrordamage *= g_weapondamagefactor;
			complainteamdamage *= g_weapondamagefactor;
			force = force * g_weaponforcefactor;
			mirrorforce *= g_weaponforcefactor;
		}

		// should this be changed at all? If so, in what way?
		frag_attacker = attacker;
		frag_inflictor = inflictor;
		frag_target = targ;
		frag_damage = damage;
		frag_force = force;
		frag_deathtype = deathtype;
		frag_mirrordamage = mirrordamage;
		MUTATOR_CALLHOOK(PlayerDamage_Calculate);
		damage = frag_damage;
		mirrordamage = frag_mirrordamage;
		force = frag_force;

		if(targ.frozen)
		if(deathtype != DEATH_HURTTRIGGER && deathtype != DEATH_TEAMCHANGE && deathtype != DEATH_AUTOTEAMCHANGE)
		{
			if(autocvar_g_freeze_revive_falldamage > 0)
			if(deathtype == DEATH_FALL)
			if(damage >= autocvar_g_freeze_revive_falldamage)
			{
				Unfreeze(targ);
				targ.health = autocvar_g_freeze_revive_falldamage_health;
				Send_Effect(EFFECT_ICEORGLASS, targ.origin, '0 0 0', 3);
				Send_Notification(NOTIF_ALL, world, MSG_INFO, INFO_FREEZETAG_REVIVED_FALL, targ.netname);
				Send_Notification(NOTIF_ONE, targ, MSG_CENTER, CENTER_FREEZETAG_REVIVE_SELF);
			}

			damage = 0;
			force *= autocvar_g_freeze_frozen_force;
		}
		
		if(targ.frozen && deathtype == DEATH_HURTTRIGGER && !autocvar_g_freeze_frozen_damage_trigger)
		{
			Send_Effect(EFFECT_TELEPORT, targ.origin, '0 0 0', 1);

			entity oldself = self;
			self = targ;
			entity spot = SelectSpawnPoint (false);

			if(spot)
			{
				damage = 0;
				self.deadflag = DEAD_NO;

				self.angles = spot.angles;

				self.effects = 0;
				self.effects |= EF_TELEPORT_BIT;

				self.angles_z = 0; // never spawn tilted even if the spot says to
				self.fixangle = true; // turn this way immediately
				self.velocity = '0 0 0';
				self.avelocity = '0 0 0';
				self.punchangle = '0 0 0';
				self.punchvector = '0 0 0';
				self.oldvelocity = self.velocity;

				self.spawnorigin = spot.origin;
				setorigin (self, spot.origin + '0 0 1' * (1 - self.mins.z - 24));
				// don't reset back to last position, even if new position is stuck in solid
				self.oldorigin = self.origin;
				self.prevorigin = self.origin;

				Send_Effect(EFFECT_TELEPORT, self.origin, '0 0 0', 1);
			}

			self = oldself;
		}

		if (targ == attacker)
			damage = damage * autocvar_g_balance_selfdamagepercent;	// Partial damage if the attacker hits himself

		// count the damage
		if(attacker)
		if(!targ.deadflag)
		if(deathtype != DEATH_BUFF)
		if(targ.takedamage == DAMAGE_AIM)
		if(targ != attacker)
		{
			entity victim;
			if(IS_VEHICLE(targ) && targ.owner)
				victim = targ.owner;
			else
				victim = targ;

			if(IS_PLAYER(victim) || IS_TURRET(victim) || IS_MONSTER(victim) || victim.classname == "func_assault_destructible" || (victim.classname == "onslaught_generator" && !victim.isshielded) || (victim.classname == "onslaught_controlpoint_icon" && !victim.owner.isshielded))
			{
				if(DIFF_TEAM(victim, attacker) && !victim.frozen)
				{
					if(damage > 0)
					{
						if(deathtype != DEATH_FIRE)
						{
							if(victim.BUTTON_CHAT)
								attacker.typehitsound += 1;
							else
								attacker.damage_dealt += damage;
						}

						damage_goodhits += 1;
						damage_gooddamage += damage;

						if (!DEATH_ISSPECIAL(deathtype))
						{
							if(IS_PLAYER(targ)) // don't do this for vehicles
							if(IsFlying(victim))
								yoda = 1;
						}
					}
				}
				else
				{
					if(deathtype != DEATH_FIRE)
					{
						attacker.typehitsound += 1;
					}
					if(complainteamdamage > 0)
						if(time > attacker.teamkill_complain)
						{
							attacker.teamkill_complain = time + 5;
							attacker.teamkill_soundtime = time + 0.4;
							attacker.teamkill_soundsource = targ;
						}
				}
			}
		}
	}

	// apply push
	if (self.damageforcescale)
	if (vlen(force))
	if (!IS_PLAYER(self) || time >= self.spawnshieldtime || self == attacker)
	{
		vector farce = damage_explosion_calcpush(self.damageforcescale * force, self.velocity, autocvar_g_balance_damagepush_speedfactor);
		if(self.movetype == MOVETYPE_PHYSICS)
		{
			entity farcent;
			farcent = spawn();
			farcent.classname = "farce";
			farcent.enemy = self;
			farcent.movedir = farce * 10;
			if(self.mass)
				farcent.movedir = farcent.movedir * self.mass;
			farcent.origin = hitloc;
			farcent.forcetype = FORCETYPE_FORCEATPOS;
			farcent.nextthink = time + 0.1;
			farcent.think = SUB_Remove;
		}
		else
			self.velocity = self.velocity + farce;
		self.flags &= ~FL_ONGROUND;
		UpdateCSQCProjectile(self);
	}
	// apply damage
	if (damage != 0 || (self.damageforcescale && vlen(force)))
	if (self.event_damage)
		self.event_damage (inflictor, attacker, damage, deathtype, hitloc, force);
	self = oldself;

	// apply mirror damage if any
	if(mirrordamage > 0 || mirrorforce > 0)
	{
		attacker = attacker_save;

		force = normalize(attacker.origin + attacker.view_ofs - hitloc) * mirrorforce;
		Damage(attacker, inflictor, attacker, mirrordamage, DEATH_MIRRORDAMAGE, attacker.origin, force);
	}
}

float RadiusDamageForSource (entity inflictor, vector inflictororigin, vector inflictorvelocity, entity attacker, float coredamage, float edgedamage, float rad, entity cantbe, entity mustbe, float inflictorselfdamage, float forceintensity, float deathtype, entity directhitentity)
	// Returns total damage applies to creatures
{
	entity	targ;
	vector	force;
	float   total_damage_to_creatures;
	entity  next;
	float   tfloordmg;
	float   tfloorforce;

	float stat_damagedone;

	if(RadiusDamage_running)
	{
		backtrace("RadiusDamage called recursively! Expect stuff to go HORRIBLY wrong.");
		return 0;
	}

	RadiusDamage_running = 1;

	tfloordmg = autocvar_g_throughfloor_damage;
	tfloorforce = autocvar_g_throughfloor_force;

	total_damage_to_creatures = 0;

	if(deathtype != (WEP_HOOK | HITTYPE_SECONDARY | HITTYPE_BOUNCE)) // only send gravity bomb damage once
		if(DEATH_WEAPONOF(deathtype) != WEP_TUBA) // do not send tuba damage (bandwidth hog)
		{
			force = inflictorvelocity;
			if(vlen(force) == 0)
				force = '0 0 -1';
			else
				force = normalize(force);
			if(forceintensity >= 0)
				Damage_DamageInfo(inflictororigin, coredamage, edgedamage, rad, forceintensity * force, deathtype, 0, attacker);
			else
				Damage_DamageInfo(inflictororigin, coredamage, edgedamage, -rad, (-forceintensity) * force, deathtype, 0, attacker);
		}

	stat_damagedone = 0;

	targ = WarpZone_FindRadius (inflictororigin, rad + MAX_DAMAGEEXTRARADIUS, false);
	while (targ)
	{
		next = targ.chain;
		if ((targ != inflictor) || inflictorselfdamage)
		if (((cantbe != targ) && !mustbe) || (mustbe == targ))
		if (targ.takedamage)
		{
			vector nearest;
			vector diff;
			float power;

			// LordHavoc: measure distance to nearest point on target (not origin)
			// (this guarentees 100% damage on a touch impact)
			nearest = targ.WarpZone_findradius_nearest;
			diff = targ.WarpZone_findradius_dist;
			// round up a little on the damage to ensure full damage on impacts
			// and turn the distance into a fraction of the radius
			power = 1 - ((vlen (diff) - bound(MIN_DAMAGEEXTRARADIUS, targ.damageextraradius, MAX_DAMAGEEXTRARADIUS)) / rad);
			//bprint(" ");
			//bprint(ftos(power));
			//if (targ == attacker)
			//	print(ftos(power), "\n");
			if (power > 0)
			{
				float finaldmg;
				if (power > 1)
					power = 1;
				finaldmg = coredamage * power + edgedamage * (1 - power);
				if (finaldmg > 0)
				{
					float a;
					float c;
					vector hitloc;
					vector myblastorigin;
					vector center;

					myblastorigin = WarpZone_TransformOrigin(targ, inflictororigin);

					// if it's a player, use the view origin as reference
					center = CENTER_OR_VIEWOFS(targ);

					force = normalize(center - myblastorigin);
					force = force * (finaldmg / coredamage) * forceintensity;
					hitloc = nearest;

					if(deathtype & WEP_BLASTER)
						force *= WEP_CVAR_BOTH(blaster, !(deathtype & HITTYPE_SECONDARY), force_zscale);

					if(targ != directhitentity)
					{
						float hits;
						float total;
						float hitratio;
						float mininv_f, mininv_d;

						// test line of sight to multiple positions on box,
						// and do damage if any of them hit
						hits = 0;

						// we know: max stddev of hitratio = 1 / (2 * sqrt(n))
						// so for a given max stddev:
						// n = (1 / (2 * max stddev of hitratio))^2

						mininv_d = (finaldmg * (1-tfloordmg)) / autocvar_g_throughfloor_damage_max_stddev;
						mininv_f = (vlen(force) * (1-tfloorforce)) / autocvar_g_throughfloor_force_max_stddev;

						if(autocvar_g_throughfloor_debug)
							printf("THROUGHFLOOR: D=%f F=%f max(dD)=1/%f max(dF)=1/%f", finaldmg, vlen(force), mininv_d, mininv_f);


						total = 0.25 * pow(max(mininv_f, mininv_d), 2);

						if(autocvar_g_throughfloor_debug)
							printf(" steps=%f", total);


						if (IS_PLAYER(targ))
							total = ceil(bound(autocvar_g_throughfloor_min_steps_player, total, autocvar_g_throughfloor_max_steps_player));
						else
							total = ceil(bound(autocvar_g_throughfloor_min_steps_other, total, autocvar_g_throughfloor_max_steps_other));

						if(autocvar_g_throughfloor_debug)
							printf(" steps=%f dD=%f dF=%f", total, finaldmg * (1-tfloordmg) / (2 * sqrt(total)), vlen(force) * (1-tfloorforce) / (2 * sqrt(total)));

						for(c = 0; c < total; ++c)
						{
							//traceline(targ.WarpZone_findradius_findorigin, nearest, MOVE_NOMONSTERS, inflictor);
							WarpZone_TraceLine(inflictororigin, WarpZone_UnTransformOrigin(targ, nearest), MOVE_NOMONSTERS, inflictor);
							if (trace_fraction == 1 || trace_ent == targ)
							{
								++hits;
								if (hits > 1)
									hitloc = hitloc + nearest;
								else
									hitloc = nearest;
							}
							nearest.x = targ.origin.x + targ.mins.x + random() * targ.size.x;
							nearest.y = targ.origin.y + targ.mins.y + random() * targ.size.y;
							nearest.z = targ.origin.z + targ.mins.z + random() * targ.size.z;
						}

						nearest = hitloc * (1 / max(1, hits));
						hitratio = (hits / total);
						a = bound(0, tfloordmg + (1-tfloordmg) * hitratio, 1);
						finaldmg = finaldmg * a;
						a = bound(0, tfloorforce + (1-tfloorforce) * hitratio, 1);
						force = force * a;

						if(autocvar_g_throughfloor_debug)
							printf(" D=%f F=%f\n", finaldmg, vlen(force));
					}

					//if (targ == attacker)
					//{
					//	print("hits ", ftos(hits), " / ", ftos(total));
					//	print(" finaldmg ", ftos(finaldmg), " force ", vtos(force));
					//	print(" (", ftos(a), ")\n");
					//}
					if(finaldmg || vlen(force))
					{
						if(targ.iscreature)
						{
							total_damage_to_creatures += finaldmg;

							if(accuracy_isgooddamage(attacker, targ))
								stat_damagedone += finaldmg;
						}

						if(targ == directhitentity || DEATH_ISSPECIAL(deathtype))
							Damage (targ, inflictor, attacker, finaldmg, deathtype, nearest, force);
						else
							Damage (targ, inflictor, attacker, finaldmg, deathtype | HITTYPE_SPLASH, nearest, force);
					}
				}
			}
		}
		targ = next;
	}

	RadiusDamage_running = 0;

	if(!DEATH_ISSPECIAL(deathtype))
		accuracy_add(attacker, DEATH_WEAPONOFWEAPONDEATH(deathtype), 0, min(coredamage, stat_damagedone));

	return total_damage_to_creatures;
}

float RadiusDamage (entity inflictor, entity attacker, float coredamage, float edgedamage, float rad, entity cantbe, entity mustbe, float forceintensity, float deathtype, entity directhitentity)
{
	return RadiusDamageForSource (inflictor, (inflictor.origin + (inflictor.mins + inflictor.maxs) * 0.5), inflictor.velocity, attacker, coredamage, edgedamage, rad, cantbe, mustbe, false, forceintensity, deathtype, directhitentity);
}

float Fire_IsBurning(entity e)
{
	return (time < e.fire_endtime);
}

float Fire_AddDamage(entity e, entity o, float d, float t, float dt)
{
	float dps;
	float maxtime, mintime, maxdamage, mindamage, maxdps, mindps, totaldamage, totaltime;

	if(IS_PLAYER(e))
	{
		if(e.deadflag)
			return -1;
	}
	else
	{
		if(!e.fire_burner)
		{
			// print("adding a fire burner to ", e.classname, "\n");
			e.fire_burner = spawn();
			e.fire_burner.classname = "fireburner";
			e.fire_burner.think = fireburner_think;
			e.fire_burner.nextthink = time;
			e.fire_burner.owner = e;
		}
	}

	t = max(t, 0.1);
	dps = d / t;
	if(Fire_IsBurning(e))
	{
		mintime = e.fire_endtime - time;
		maxtime = max(mintime, t);

		mindps = max(0.1, e.fire_damagepersec);
		maxdps = max(mindps, dps);

		if(maxtime > mintime || maxdps > mindps)
		{
			// Constraints:

			// damage we have right now
			mindamage = mindps * mintime;

			// damage we want to get
			maxdamage = mindamage + d;

			// but we can't exceed maxtime * maxdps!
			totaldamage = min(maxdamage, maxtime * maxdps);

			// LEMMA:
			// Look at:
			// totaldamage = min(mindamage + d, maxtime * maxdps)
			// We see:
			// totaldamage <= maxtime * maxdps
			// ==> totaldamage / maxdps <= maxtime.
			// We also see:
			// totaldamage / mindps = min(mindamage / mindps + d, maxtime * maxdps / mindps)
			//                     >= min(mintime, maxtime)
			// ==> totaldamage / maxdps >= mintime.

			/*
			// how long do we damage then?
			// at least as long as before
			// but, never exceed maxdps
			totaltime = max(mintime, totaldamage / maxdps); // always <= maxtime due to lemma
			*/

			// alternate:
			// at most as long as maximum allowed
			// but, never below mindps
			totaltime = min(maxtime, totaldamage / mindps); // always >= mintime due to lemma

			// assuming t > mintime, dps > mindps:
			// we get d = t * dps = maxtime * maxdps
			// totaldamage = min(maxdamage, maxtime * maxdps) = min(... + d, maxtime * maxdps) = maxtime * maxdps
			// totaldamage / maxdps = maxtime
			// totaldamage / mindps > totaldamage / maxdps = maxtime
			// FROM THIS:
			// a) totaltime = max(mintime, maxtime) = maxtime
			// b) totaltime = min(maxtime, totaldamage / maxdps) = maxtime

			// assuming t <= mintime:
			// we get maxtime = mintime
			// a) totaltime = max(mintime, ...) >= mintime, also totaltime <= maxtime by the lemma, therefore totaltime = mintime = maxtime
			// b) totaltime = min(maxtime, ...) <= maxtime, also totaltime >= mintime by the lemma, therefore totaltime = mintime = maxtime

			// assuming dps <= mindps:
			// we get mindps = maxdps.
			// With this, the lemma says that mintime <= totaldamage / mindps = totaldamage / maxdps <= maxtime.
			// a) totaltime = max(mintime, totaldamage / maxdps) = totaldamage / maxdps
			// b) totaltime = min(maxtime, totaldamage / mindps) = totaldamage / maxdps

			e.fire_damagepersec = totaldamage / totaltime;
			e.fire_endtime = time + totaltime;
			if(totaldamage > 1.2 * mindamage)
			{
				e.fire_deathtype = dt;
				if(e.fire_owner != o)
				{
					e.fire_owner = o;
					e.fire_hitsound = false;
				}
			}
			if(accuracy_isgooddamage(o, e))
				accuracy_add(o, DEATH_WEAPONOFWEAPONDEATH(dt), 0, max(0, totaldamage - mindamage));
			return max(0, totaldamage - mindamage); // can never be negative, but to make sure
		}
		else
			return 0;
	}
	else
	{
		e.fire_damagepersec = dps;
		e.fire_endtime = time + t;
		e.fire_deathtype = dt;
		e.fire_owner = o;
		e.fire_hitsound = false;
		if(accuracy_isgooddamage(o, e))
			accuracy_add(o, DEATH_WEAPONOFWEAPONDEATH(dt), 0, d);
		return d;
	}
}

void Fire_ApplyDamage(entity e)
{
	float t, d, hi, ty;
	entity o;

	if (!Fire_IsBurning(e))
		return;

	for(t = 0, o = e.owner; o.owner && t < 16; o = o.owner, ++t);
	if(IS_NOT_A_CLIENT(o))
		o = e.fire_owner;

	// water and slime stop fire
	if(e.waterlevel)
	if(e.watertype != CONTENT_LAVA)
		e.fire_endtime = 0;

	// ice stops fire
	if(e.frozen)
		e.fire_endtime = 0;

	t = min(frametime, e.fire_endtime - time);
	d = e.fire_damagepersec * t;

	hi = e.fire_owner.damage_dealt;
	ty = e.fire_owner.typehitsound;
	Damage(e, e, e.fire_owner, d, e.fire_deathtype, e.origin, '0 0 0');
	if(e.fire_hitsound && e.fire_owner)
	{
		e.fire_owner.damage_dealt = hi;
		e.fire_owner.typehitsound = ty;
	}
	e.fire_hitsound = true;

	if(!IS_INDEPENDENT_PLAYER(e))
	if(!e.frozen)
	FOR_EACH_PLAYER(other) if(e != other)
	{
		if(IS_PLAYER(other))
		if(other.deadflag == DEAD_NO)
		if (!IS_INDEPENDENT_PLAYER(other))
		if(boxesoverlap(e.absmin, e.absmax, other.absmin, other.absmax))
		{
			t = autocvar_g_balance_firetransfer_time * (e.fire_endtime - time);
			d = autocvar_g_balance_firetransfer_damage * e.fire_damagepersec * t;
			Fire_AddDamage(other, o, d, t, DEATH_FIRE);
		}
	}
}

void Fire_ApplyEffect(entity e)
{
	if(Fire_IsBurning(e))
		e.effects |= EF_FLAME;
	else
		e.effects &= ~EF_FLAME;
}

void fireburner_think()
{
	// for players, this is done in the regular loop
	if(wasfreed(self.owner))
	{
		remove(self);
		return;
	}
	Fire_ApplyEffect(self.owner);
	if(!Fire_IsBurning(self.owner))
	{
		self.owner.fire_burner = world;
		remove(self);
		return;
	}
	Fire_ApplyDamage(self.owner);
	self.nextthink = time;
}
