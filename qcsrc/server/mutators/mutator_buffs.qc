#include "../../common/effects.qh"
#include "../../common/buffs.qh"
#include "../round_handler.qh"

float buffs_BuffModel_Customize()
{
	entity player, myowner;
	float same_team;

	player = WaypointSprite_getviewentity(other);
	myowner = self.owner;
	same_team = (SAME_TEAM(player, myowner) || SAME_TEAM(player, myowner));

	if(myowner.alpha <= 0.5 && !same_team && myowner.alpha != 0)
		return false;

	if(cvar("g_piggyback"))
	if(player.pbhost == myowner || myowner.piggybacker)
		return false; // don't show to piggybacker's carrier, and don't show if carrier is carrying someone else

	if(player == myowner || (IS_SPEC(other) && other.enemy == myowner))
	{
		// somewhat hide the model, but keep the glow
		self.effects = 0;
		self.alpha = -1;
	}
	else
	{
		self.effects = EF_FULLBRIGHT | EF_LOWPRECISION;
		self.alpha = 1;
	}
	return true;
}

vector buff_GlowColor(entity buff)
{
	//if(buff.team) { return Team_ColorRGB(buff.team); }
	return buff.color;
}

// buff item
float buff_Waypoint_visible_for_player(entity plr)
{
    if(!self.owner.buff_active && !self.owner.buff_activetime)
        return false;

	if(plr.buffs)
	{
		if(plr.cvar_cl_buffs_autoreplace)
		{
			if(plr.buffs == self.owner.buffs)
				return false;
		}
		else
			return false;
	}

    return WaypointSprite_visible_for_player(plr);
}

void buff_Waypoint_Spawn(entity e)
{
    WaypointSprite_Spawn(Buff_Sprite(e.buffs), 0, autocvar_g_buffs_waypoint_distance, e, '0 0 1' * e.maxs.z, world, e.team, e, buff_waypoint, true, RADARICON_POWERUP, e.glowmod);
    WaypointSprite_UpdateTeamRadar(e.buff_waypoint, RADARICON_POWERUP, e.glowmod);
    e.buff_waypoint.waypointsprite_visible_for_player = buff_Waypoint_visible_for_player;
}

void buff_SetCooldown(float cd)
{
	cd = max(0, cd);

	if(!self.buff_waypoint)
		buff_Waypoint_Spawn(self);

	WaypointSprite_UpdateBuildFinished(self.buff_waypoint, time + cd);
	self.buff_activetime = cd;
	self.buff_active = !cd;
}

void buff_Respawn(entity ent)
{
	if(gameover) { return; }

	vector oldbufforigin = ent.origin;

	if(!MoveToRandomMapLocation(ent, DPCONTENTS_SOLID | DPCONTENTS_CORPSE | DPCONTENTS_PLAYERCLIP, DPCONTENTS_SLIME | DPCONTENTS_LAVA | DPCONTENTS_SKY | DPCONTENTS_BODY | DPCONTENTS_DONOTENTER, Q3SURFACEFLAG_SKY, ((autocvar_g_buffs_random_location_attempts > 0) ? autocvar_g_buffs_random_location_attempts : 10), 1024, 256))
	{
		entity spot = SelectSpawnPoint(true);
		setorigin(ent, ((spot.origin + '0 0 200') + (randomvec() * 300)));
		ent.angles = spot.angles;
	}

	tracebox(ent.origin, ent.mins * 1.5, self.maxs * 1.5, ent.origin, MOVE_NOMONSTERS, ent);

	setorigin(ent, trace_endpos); // attempt to unstick

	ent.movetype = MOVETYPE_TOSS;

	makevectors(ent.angles);
	ent.velocity = '0 0 200';
	ent.angles = '0 0 0';
	if(autocvar_g_buffs_random_lifetime > 0)
		ent.lifetime = time + autocvar_g_buffs_random_lifetime;

	Send_Effect(EFFECT_ELECTRO_COMBO, oldbufforigin + ((ent.mins + ent.maxs) * 0.5), '0 0 0', 1);
	Send_Effect(EFFECT_ELECTRO_COMBO, CENTER_OR_VIEWOFS(ent), '0 0 0', 1);

	WaypointSprite_Ping(ent.buff_waypoint);

	sound(ent, CH_TRIGGER, "keepaway/respawn.wav", VOL_BASE, ATTEN_NONE); // ATTEN_NONE (it's a sound intended to be heard anywhere)
}

void buff_Touch()
{
	if(gameover) { return; }

	if(ITEM_TOUCH_NEEDKILL())
	{
		buff_Respawn(self);
		return;
	}

	if((self.team && DIFF_TEAM(other, self))
	|| (Player_Trapped(other))
	|| (other.vehicle)
	|| (!IS_PLAYER(other))
	|| (!self.buff_active)
	)
	{
		// can't touch this
		return;
	}

	if(IS_MONSTER(other))
	if(cvar("g_piggyback"))
	if(other.piggybacker)
		other = other.piggybacker;

	if(cvar("g_piggyback"))
	if(other.buffs)
	if(other.buffs == self.buffs || !other.cvar_cl_buffs_autoreplace)
	{
		entity p = other;
		while(p.piggybacker)
		{
			if(!p.buffs || (!p.piggybacker && (p.cvar_cl_buffs_autoreplace || p.buffs != self.buffs)))
			{
				other = p;
				break;
			}
			p = p.piggybacker;
		}
	}

	if(other.buffs)
	{
		if(other.cvar_cl_buffs_autoreplace && other.buffs != self.buffs)
		{
			//Send_Notification(NOTIF_ONE, other, MSG_MULTI, ITEM_BUFF_DROP, other.buffs);
			Send_Notification(NOTIF_ALL, world, MSG_INFO, INFO_ITEM_BUFF_LOST, other.netname, other.buffs);

			other.buffs = 0;
			//sound(other, CH_TRIGGER, "relics/relic_effect.wav", VOL_BASE, ATTN_NORM);
		}
		else { return; } // do nothing
	}

	self.owner = other;
	self.buff_active = false;
	self.lifetime = 0;

	Send_Notification(NOTIF_ONE, other, MSG_MULTI, ITEM_BUFF_GOT, self.buffs);
	Send_Notification(NOTIF_ALL_EXCEPT, other, MSG_INFO, INFO_ITEM_BUFF, other.netname, self.buffs);

	Send_Effect(EFFECT_ITEM_PICKUP, CENTER_OR_VIEWOFS(self), '0 0 0', 1);
	sound(other, CH_TRIGGER, "misc/shield_respawn.wav", VOL_BASE, ATTN_NORM);
	other.buffs |= (self.buffs);
}

float buff_Available(float buffid)
{
	if(buffid == BUFF_AMMO && ((start_items & IT_UNLIMITED_WEAPON_AMMO) || (start_items & IT_UNLIMITED_AMMO) || (cvar("g_melee_only"))))
		return false;

	if(buffid == BUFF_VAMPIRE && cvar("g_vampire"))
		return false;

	if(!cvar(strcat("g_buffs_", Buff_Name(buffid))))
		return false;

	return true;
}

void buff_NewType(entity ent, float cb)
{
	entity e;
	RandomSelection_Init();
	for(e = Buff_Type_first; e; e = e.enemy)
	if(buff_Available(e.items))
	{
		RandomSelection_Add(world, e.items, string_null, 1, 1 / e.count); // if it's already been chosen, give it a lower priority
		e.count += 1;
	}
	ent.buffs = RandomSelection_chosen_float;
}

void buff_Think()
{
	if(self.buffs != self.oldbuffs)
	{
		self.color = Buff_Color(self.buffs);
		self.glowmod = buff_GlowColor(self);
		self.skin = Buff_Skin(self.buffs);

		setmodel(self, "models/relics/relic.md3");

		if(self.buff_waypoint)
		{
			//WaypointSprite_Disown(self.buff_waypoint, 1);
			WaypointSprite_Kill(self.buff_waypoint);
			buff_Waypoint_Spawn(self);
			if(self.buff_activetime)
				WaypointSprite_UpdateBuildFinished(self.buff_waypoint, time + self.buff_activetime - frametime);
		}

		self.oldbuffs = self.buffs;
	}

	if(!gameover)
	if((round_handler_IsActive() && !round_handler_IsRoundStarted()) || time >= game_starttime)
	if(!self.buff_activetime_updated)
	{
		buff_SetCooldown(self.buff_activetime);
		self.buff_activetime_updated = true;
    }

	if(!self.buff_active && !self.buff_activetime)
	if(!self.owner || Player_Trapped(self.owner) || !self.owner.iscreature || !(self.owner.buffs & self.buffs))
	{
		buff_SetCooldown(autocvar_g_buffs_cooldown_respawn + frametime);
		self.owner = world;
		if(autocvar_g_buffs_randomize)
			buff_NewType(self, self.buffs);

		if(autocvar_g_buffs_random_location || (self.spawnflags & 1))
			buff_Respawn(self);
	}

	if(self.buff_activetime)
	if(!gameover)
	if((round_handler_IsActive() && !round_handler_IsRoundStarted()) || time >= game_starttime)
	{
		self.buff_activetime = max(0, self.buff_activetime - frametime);

		if(!self.buff_activetime)
		{
			self.buff_active = true;
			sound(self, CH_TRIGGER, "misc/strength_respawn.wav", VOL_BASE, ATTN_NORM);
			Send_Effect(EFFECT_ITEM_RESPAWN, CENTER_OR_VIEWOFS(self), '0 0 0', 1);
		}
	}

	if(self.buff_active)
	{
		if(self.team && !self.buff_waypoint)
			buff_Waypoint_Spawn(self);

		if(self.lifetime)
		if(time >= self.lifetime)
			buff_Respawn(self);
	}

	self.nextthink = time;
	//self.angles_y = time * 110.1;
}

void buff_Waypoint_Reset()
{
	WaypointSprite_Kill(self.buff_waypoint);

	if(self.buff_activetime) { buff_Waypoint_Spawn(self); }
}

void buff_Reset()
{
	if(autocvar_g_buffs_randomize)
		buff_NewType(self, self.buffs);
	self.owner = world;
	buff_SetCooldown(autocvar_g_buffs_cooldown_activate);
	buff_Waypoint_Reset();
	self.buff_activetime_updated = false;

	if(autocvar_g_buffs_random_location || (self.spawnflags & 1))
		buff_Respawn(self);
}

float buff_Customize()
{
	entity player = WaypointSprite_getviewentity(other);
	if(!self.buff_active || (self.team && DIFF_TEAM(player, self)))
	{
		self.alpha = 0.3;
		if(self.effects & EF_FULLBRIGHT) { self.effects &= ~(EF_FULLBRIGHT); }
		self.pflags = 0;
	}
	else
	{
		self.alpha = 1;
		if(!(self.effects & EF_FULLBRIGHT)) { self.effects |= EF_FULLBRIGHT; }
		self.light_lev = 220 + 36 * sin(time);
		self.pflags = PFLAGS_FULLDYNAMIC;
	}
	return true;
}

void buff_Init(entity ent)
{
	if(!cvar("g_buffs")) { remove(self); return; }

	if(!teamplay && self.team) { self.team = 0; }

	entity oldself = self;
	self = ent;
	if(!self.buffs || buff_Available(self.buffs))
		buff_NewType(self, 0);

	self.classname = "item_buff";
	self.solid = SOLID_TRIGGER;
	self.flags = FL_ITEM;
	self.think = buff_Think;
	self.touch = buff_Touch;
	self.reset = buff_Reset;
	self.nextthink = time + 0.1;
	self.gravity = 1;
	self.movetype = MOVETYPE_TOSS;
	self.scale = 1;
	self.skin = Buff_Skin(self.buffs);
	self.effects = EF_FULLBRIGHT | EF_STARDUST | EF_NOSHADOW;
	self.dphitcontentsmask = DPCONTENTS_SOLID | DPCONTENTS_BODY;
	self.customizeentityforclient = buff_Customize;
	//self.gravity = 100;
	self.color = Buff_Color(self.buffs);
	self.glowmod = buff_GlowColor(self);
	buff_SetCooldown(autocvar_g_buffs_cooldown_activate + game_starttime);
	self.buff_active = !self.buff_activetime;
	self.pflags = PFLAGS_FULLDYNAMIC;

	if(self.noalign)
		self.movetype = MOVETYPE_NONE; // reset by random location

	setmodel(self, "models/relics/relic.md3");
	setsize(self, BUFF_MIN, BUFF_MAX);

	if(cvar("g_buffs_random_location") || (self.spawnflags & 1))
		buff_Respawn(self);

	self = oldself;
}

void buff_Init_Compat(entity ent, float replacement)
{
	if(ent.spawnflags & 2)
		ent.team = NUM_TEAM_1;
	else if(ent.spawnflags & 4)
		ent.team = NUM_TEAM_2;

	ent.buffs = replacement;

	buff_Init(ent);
}

void buff_SpawnReplacement(entity ent, entity old)
{
	setorigin(ent, old.origin);
	ent.angles = old.angles;
	ent.noalign = old.noalign;

	buff_Init(ent);
}

#ifdef MONTY
void buff_Blessed_Foot_Touch()
{
	if(other.iscreature && other.takedamage && other.health > 0)
	{
		int mydamage = 9999;
		if(other == self.realowner)
			mydamage = 5; // but spammed
		Damage (other, self, world, mydamage, DEATH_FOOT, other.origin, '0 0 0');
	}
}

void buff_Blessed_Foot_Think()
{
	self.nextthink = time;
	if(self.buff_blessed_time)
	if(time >= self.buff_blessed_time)
	{
		remove(self);
		return;
	}
	if(self.origin_z <= self.buff_blessed_bottom_z)
	{
		if(!self.buff_blessed_soundplayed)
		{
			self.buff_blessed_time = time + 1;
			self.velocity = '0 0 0';
			setorigin(self, self.buff_blessed_bottom);
			//sound(self, CH_TRIGGER_SINGLE, "monty/foot.wav", VOL_BASE, ATTEN_MAX);
			sound(self, CH_TRIGGER_SINGLE, "monty/foot.wav", VOL_BASEVOICE, ATTEN_MIN);
			self.buff_blessed_soundplayed = true;
		}
	}
	else
	{
		self.velocity = '0 0 -1500';
		//setorigin(self, self.origin - '0 0 10');
	}
}

void buff_Blessed_SpawnFoot(entity player)
{
	makevectors(player.angles);
	vector org = player.origin + (v_forward * 220) + ('0 0 1' * 32);
	vector bottom;
	vector top;
	entity foot = spawn();

	foot.realowner = player; // don't set owner, as we want this to crush owner
	foot.classname = "montyfoot";
	foot.solid = SOLID_TRIGGER;
	foot.touch = buff_Blessed_Foot_Touch;
	foot.think = buff_Blessed_Foot_Think;
	foot.nextthink = time;
	foot.movetype = MOVETYPE_NOCLIP;
	foot.scale = 6;

	setmodel(foot, "models/monty/foot.iqm");
	setsize(foot, '-150 -150 0', '150 150 250');

	//tracebox(org, foot.mins, foot.maxs, org + '0 0 800', MOVE_NORMAL, foot);
	top = org + '0 0 800';
	foot.dphitcontentsmask = DPCONTENTS_SOLID;
	tracebox(org, foot.mins, foot.maxs, org - '0 0 2000', MOVE_WORLDONLY, foot);
	foot.dphitcontentsmask = DPCONTENTS_LAVA;
	bottom = trace_endpos;

	foot.buff_blessed_bottom = bottom;
	foot.buff_blessed_top = top;
	setorigin(foot, top);

	sound(player, CH_TRIGGER_SINGLE, "monty/ni.wav", VOL_BASEVOICE, ATTEN_NORM);
}
#endif

// mutator hooks
MUTATOR_HOOKFUNCTION(buffs_PlayerDamage_SplitHealthArmor)
{
	if(frag_deathtype == DEATH_BUFF) { return false; }

	if(frag_target.buffs & BUFF_RESISTANCE)
	{
		float blockpercent = autocvar_g_buffs_resistance_blockpercent;
#ifdef CHAOS
		if(DEATH_ISWEAPON(frag_deathtype, WEP_LIGHTSABRE) && autocvar_g_buffs_resistance_blockpercent > 0) { blockpercent *= 0.3; }
#endif
		vector v = healtharmor_applydamage(50, blockpercent, frag_deathtype, frag_damage, autocvar_g_balance_armor_block_bycount);
		damage_take = v_x;
		damage_save = v_y;
	}

	return false;
}

void buff_Vengeance_DelayedDamage()
{
	if(self.enemy)
		Damage(self.enemy, self.owner, self.owner, self.dmg, DEATH_BUFF, self.enemy.origin, '0 0 0');

	remove(self);
	return;
}

MUTATOR_HOOKFUNCTION(buffs_PlayerDamage_Calculate)
{
	if(frag_deathtype == DEATH_BUFF) { return false; }

	if(frag_target.buffs & BUFF_SPEED)
	if(frag_target != frag_attacker)
		frag_damage *= autocvar_g_buffs_speed_damage_take;

	if(frag_target.buffs & BUFF_MEDIC)
	if((frag_target.health - frag_damage) <= 0)
	if(!ITEM_DAMAGE_NEEDKILL(frag_deathtype))
	if(frag_attacker)
	if(random() <= autocvar_g_buffs_medic_survive_chance)
	if(frag_target.health - autocvar_g_buffs_medic_survive_health > 0) // not if the final result would be less than 0, medic must get health
		frag_damage = frag_target.health - autocvar_g_buffs_medic_survive_health;

	if(frag_target.buffs & BUFF_VENGEANCE)
	if(frag_attacker)
	if(frag_attacker != frag_target)
	if(!ITEM_DAMAGE_NEEDKILL(frag_deathtype))
	{
		entity dmgent = spawn();

		dmgent.dmg = frag_damage * autocvar_g_buffs_vengeance_damage_multiplier;
		dmgent.enemy = frag_attacker;
		dmgent.owner = frag_target;
		dmgent.think = buff_Vengeance_DelayedDamage;
		dmgent.nextthink = time + 0.1;
	}

	if(frag_target.buffs & BUFF_BASH)
	if(frag_attacker != frag_target)
	if(vlen(frag_force))
		frag_force = '0 0 0';

	if(frag_attacker.buffs & BUFF_BASH)
	if(vlen(frag_force))
	if(frag_attacker == frag_target)
		frag_force *= autocvar_g_buffs_bash_force_self;
	else
		frag_force *= autocvar_g_buffs_bash_force;

	if(frag_attacker.buffs & BUFF_DISABILITY)
	if(frag_target != frag_attacker)
		frag_target.buff_disability_time = time + autocvar_g_buffs_disability_time;

	if(frag_attacker.buffs & BUFF_MEDIC)
	if(DEATH_WEAPONOF(frag_deathtype) != WEP_ARC)
	if(SAME_TEAM(frag_attacker, frag_target))
	if(frag_attacker != frag_target)
	{
		frag_target.health = min(g_pickup_healthmega_max, frag_target.health + frag_damage);
		frag_damage = 0;
	}

	// this... is ridiculous (TODO: fix!)
	if(frag_attacker.buffs & BUFF_VAMPIRE)
	if(!frag_target.vehicle)
	if(DEATH_WEAPONOF(frag_deathtype) != WEP_ARC)
	if(!ITEM_DAMAGE_NEEDKILL(frag_deathtype))
	if(IS_PLAYER(frag_target) || IS_MONSTER(frag_target))
	if(frag_attacker != frag_target)
	if(frag_target.takedamage)
	if(!Player_Trapped(frag_target))
	if(DIFF_TEAM(frag_attacker, frag_target))
		frag_attacker.health = bound(0, frag_attacker.health + bound(0, frag_damage * autocvar_g_buffs_vampire_damage_steal, frag_target.health), g_pickup_healthsmall_max);

	return false;
}

MUTATOR_HOOKFUNCTION(buffs_PlayerSpawn)
{
	self.buffs = 0;
	// reset timers here to prevent them continuing after re-spawn
	self.buff_disability_time = 0;
	self.buff_disability_effect_time = 0;
	return false;
}

MUTATOR_HOOKFUNCTION(buffs_PlayerPhysics)
{
	if(self.buffs & BUFF_SPEED)
	{
		self.stat_sv_maxspeed *= autocvar_g_buffs_speed_speed;
		self.stat_sv_airspeedlimit_nonqw *= autocvar_g_buffs_speed_speed;
	}

	if(time < self.buff_disability_time)
	{
		self.stat_sv_maxspeed *= autocvar_g_buffs_disability_speed;
		self.stat_sv_airspeedlimit_nonqw *= autocvar_g_buffs_disability_speed;
	}

	if(self.buffs & BUFF_JUMP)
	{
		// automatically reset, no need to worry
		self.stat_sv_jumpvelocity = autocvar_g_buffs_jump_height;
	}

	return false;
}

MUTATOR_HOOKFUNCTION(buffs_PlayerJump)
{
	if(self.buffs & BUFF_JUMP)
		player_jumpheight = autocvar_g_buffs_jump_height;

	return false;
}

MUTATOR_HOOKFUNCTION(buffs_MonsterMove)
{
	if(time < self.buff_disability_time)
	{
		monster_speed_walk *= autocvar_g_buffs_disability_speed;
		monster_speed_run *= autocvar_g_buffs_disability_speed;
	}

	return false;
}

MUTATOR_HOOKFUNCTION(buffs_PlayerDies)
{
	if(self.buffs)
	{
		Send_Notification(NOTIF_ALL_EXCEPT, self, MSG_INFO, INFO_ITEM_BUFF_LOST, self.netname, self.buffs);
		self.buffs = 0;

		if(self.buff_model)
		{
			remove(self.buff_model);
			self.buff_model = world;
		}
	}
	return false;
}

MUTATOR_HOOKFUNCTION(buffs_PlayerUseKey)
{
	if(MUTATOR_RETURNVALUE || gameover) { return false; }
	if(self.buffs)
	{
		Send_Notification(NOTIF_ONE, self, MSG_MULTI, ITEM_BUFF_DROP, self.buffs);
		Send_Notification(NOTIF_ALL_EXCEPT, self, MSG_INFO, INFO_ITEM_BUFF_LOST, self.netname, self.buffs);

		self.buffs = 0;
		sound(self, CH_TRIGGER, "relics/relic_effect.wav", VOL_BASE, ATTN_NORM);
		return true;
	}
	return false;
}

MUTATOR_HOOKFUNCTION(buffs_RemovePlayer)
{
	if(self.buff_model)
	{
		remove(self.buff_model);
		self.buff_model = world;
	}

	// also reset timers here to prevent them continuing after spectating
	self.buff_disability_time = 0;
	self.buff_disability_effect_time = 0;

	return false;
}

MUTATOR_HOOKFUNCTION(buffs_CustomizeWaypoint)
{
	entity e = WaypointSprite_getviewentity(other);

	// if you have the invisibility powerup, sprites ALWAYS are restricted to your team
	// but only apply this to real players, not to spectators
	if((self.owner.flags & FL_CLIENT) && (self.owner.buffs & BUFF_INVISIBLE) && (e == other))
	if(DIFF_TEAM(self.owner, e))
		return true;

	return false;
}

MUTATOR_HOOKFUNCTION(buffs_OnEntityPreSpawn)
{
	if(autocvar_g_buffs_replace_powerups)
	switch(self.classname)
	{
		case "item_strength":
		case "item_invincible":
		{
			entity e = spawn();
			buff_SpawnReplacement(e, self);
			self.classname = "item_removing";
			return true;
		}
	}
	return false;
}

MUTATOR_HOOKFUNCTION(buffs_WeaponRate)
{
	if(self.buffs & BUFF_SPEED)
		weapon_rate *= autocvar_g_buffs_speed_rate;

	if(time < self.buff_disability_time)
		weapon_rate *= autocvar_g_buffs_disability_rate;

	return false;
}

MUTATOR_HOOKFUNCTION(buffs_PlayerThink)
{
	if(gameover || self.deadflag != DEAD_NO) { return false; }

	if(time < self.buff_disability_time)
	if(time >= self.buff_disability_effect_time)
	{
		Send_Effect(EFFECT_SMOKING, self.origin + ((self.mins + self.maxs) * 0.5), '0 0 0', 1);
		self.buff_disability_effect_time = time + 0.5;
	}

	if(Player_Trapped(self))
	{
		if(self.buffs)
		{
			Send_Notification(NOTIF_ALL_EXCEPT, self, MSG_INFO, INFO_ITEM_BUFF_LOST, self.netname, self.buffs);
			self.buffs = 0;
		}
	}

#ifdef MONTY
	if(!self.crouch)
		self.buff_blessed_crouch_held = false;

	if(self.buffs & BUFF_BLESSED)
	if(time >= self.buff_blessed_time)
	if(self.crouch && !self.buff_blessed_crouch_held)
	{
		buff_Blessed_SpawnFoot(self);
		self.buff_blessed_time = time + 0.5;
		self.buff_blessed_crouch_held = true;
	}
#endif

	if((self.buffs & BUFF_INVISIBLE) && (self.oldbuffs & BUFF_INVISIBLE))
	if(self.alpha != autocvar_g_buffs_invisible_alpha)
		self.alpha = autocvar_g_buffs_invisible_alpha;

	if(self.buffs != self.oldbuffs)
	{
		if(self.oldbuffs & BUFF_AMMO)
		{
			if(self.buff_ammo_prev_infitems)
				self.items |= IT_UNLIMITED_WEAPON_AMMO;
			else
				self.items &= ~IT_UNLIMITED_WEAPON_AMMO;
		}
		else if(self.buffs & BUFF_AMMO)
		{
			self.buff_ammo_prev_infitems = (self.items & IT_UNLIMITED_WEAPON_AMMO);
			self.items |= IT_UNLIMITED_WEAPON_AMMO;
			if(!self.ammo_shells) { self.ammo_shells = 20; }
			if(!self.ammo_cells) { self.ammo_cells = 20; }
			if(!self.ammo_rockets) { self.ammo_rockets = 20; }
			if(!self.ammo_nails) { self.ammo_nails = 20; }
			if(!self.ammo_fuel) { self.ammo_fuel = 20; }
		}

		if(self.oldbuffs & BUFF_INVISIBLE)
		{
			self.alpha = self.buff_invisible_prev_alpha;
		}
		else if(self.buffs & BUFF_INVISIBLE)
		{
			self.buff_invisible_prev_alpha = self.alpha;
			self.alpha = autocvar_g_buffs_invisible_alpha;
		}

		if(self.oldbuffs & BUFF_FLIGHT)
			self.gravity = self.buff_flight_prev_gravity;
		else if(self.buffs & BUFF_FLIGHT)
		{
			self.buff_flight_prev_gravity = self.gravity;
			self.gravity = autocvar_g_buffs_flight_gravity;
		}

		self.oldbuffs = self.buffs;
		if(self.buffs)
		{
			if(!self.buff_model)
			{
				self.buff_model = spawn();
				setmodel(self.buff_model, "models/relics/relic.md3");
				setsize(self.buff_model, '0 0 -40', '0 0 40');
				setattachment(self.buff_model, self, "");
				setorigin(self.buff_model, '0 0 1' * (self.buff_model.maxs.z * 1));
				self.buff_model.owner = self;
				self.buff_model.scale = 0.7;
				self.buff_model.pflags = PFLAGS_FULLDYNAMIC;
				self.buff_model.light_lev = 200;
				self.buff_model.customizeentityforclient = buffs_BuffModel_Customize;
			}
			self.buff_model.color = Buff_Color(self.buffs);
			self.buff_model.glowmod = buff_GlowColor(self.buff_model);
			self.buff_model.skin = Buff_Skin(self.buffs);

			self.effects |= EF_NOSHADOW;
		}
		else
		{
			remove(self.buff_model);
			self.buff_model = world;

			self.effects &= ~(EF_NOSHADOW);
		}
	}

	if(self.buff_model)
	{
		self.buff_model.effects = self.effects;
		self.buff_model.effects |= EF_LOWPRECISION;
		self.buff_model.effects = self.buff_model.effects & EFMASK_CHEAP; // eat performance

		self.buff_model.alpha = self.alpha;
	}

	return false;
}

MUTATOR_HOOKFUNCTION(buffs_SpectateCopy)
{
	self.buffs = other.buffs;
	return false;
}

MUTATOR_HOOKFUNCTION(buffs_VehicleEnter)
{
	vh_vehicle.buffs = vh_player.buffs;
	vh_player.buffs = 0;
	return false;
}

MUTATOR_HOOKFUNCTION(buffs_VehicleExit)
{
	vh_player.buffs = vh_vehicle.buffs;
	vh_vehicle.buffs = 0;
	return false;
}

MUTATOR_HOOKFUNCTION(buffs_PlayerRegen)
{
	if(self.buffs & BUFF_MEDIC)
	{
		regen_mod_rot = autocvar_g_buffs_medic_rot;
		regen_mod_limit = regen_mod_max = autocvar_g_buffs_medic_max;
		regen_mod_regen = autocvar_g_buffs_medic_regen;
	}

	if(self.buffs & BUFF_SPEED)
		regen_mod_regen = autocvar_g_buffs_speed_regen;

	return false;
}

MUTATOR_HOOKFUNCTION(buffs_GetCvars)
{
	GetCvars_handleFloat(get_cvars_s, get_cvars_f, cvar_cl_buffs_autoreplace, "cl_buffs_autoreplace");
	return false;
}

MUTATOR_HOOKFUNCTION(buffs_BuildMutatorsString)
{
	ret_string = strcat(ret_string, ":Buffs");
	return false;
}

MUTATOR_HOOKFUNCTION(buffs_BuildMutatorsPrettyString)
{
	ret_string = strcat(ret_string, ", Buffs");
	return false;
}

void buffs_DelayedInit()
{
	if(autocvar_g_buffs_spawn_count > 0)
	if(find(world, classname, "item_buff") == world)
	{
		float i;
		for(i = 0; i < autocvar_g_buffs_spawn_count; ++i)
		{
			entity e = spawn();
			e.spawnflags |= 1; // always randomize
			e.velocity = randomvec() * 250; // this gets reset anyway if random location works
			buff_Init(e);
		}
	}
}

void buffs_Initialize()
{
	precache_model("models/monty/foot.iqm");
	precache_model("models/relics/relic.md3");
	precache_sound("misc/strength_respawn.wav");
	precache_sound("misc/shield_respawn.wav");
	precache_sound("relics/relic_effect.wav");
	precache_sound(W_Sound("rocket_impact"));
	precache_sound("keepaway/respawn.wav");
	precache_sound("monty/foot.wav");
	precache_sound("monty/ni.wav");

	addstat(STAT_BUFFS, AS_INT, buffs);

	InitializeEntity(world, buffs_DelayedInit, INITPRIO_FINDTARGET);
}

MUTATOR_DEFINITION(mutator_buffs)
{
	MUTATOR_HOOK(PlayerDamage_SplitHealthArmor, buffs_PlayerDamage_SplitHealthArmor, CBC_ORDER_ANY);
	MUTATOR_HOOK(PlayerDamage_Calculate, buffs_PlayerDamage_Calculate, CBC_ORDER_ANY);
	MUTATOR_HOOK(PlayerSpawn, buffs_PlayerSpawn, CBC_ORDER_ANY);
	MUTATOR_HOOK(PlayerPhysics, buffs_PlayerPhysics, CBC_ORDER_ANY);
	MUTATOR_HOOK(PlayerJump, buffs_PlayerJump, CBC_ORDER_ANY);
	MUTATOR_HOOK(MonsterMove, buffs_MonsterMove, CBC_ORDER_ANY);
	MUTATOR_HOOK(SpectateCopy, buffs_SpectateCopy, CBC_ORDER_ANY);
	MUTATOR_HOOK(VehicleEnter, buffs_VehicleEnter, CBC_ORDER_ANY);
	MUTATOR_HOOK(VehicleExit, buffs_VehicleExit, CBC_ORDER_ANY);
	MUTATOR_HOOK(PlayerRegen, buffs_PlayerRegen, CBC_ORDER_ANY);
	MUTATOR_HOOK(PlayerDies, buffs_PlayerDies, CBC_ORDER_ANY);
	MUTATOR_HOOK(PlayerUseKey, buffs_PlayerUseKey, CBC_ORDER_FIRST);
	MUTATOR_HOOK(MakePlayerObserver, buffs_RemovePlayer, CBC_ORDER_ANY);
	MUTATOR_HOOK(ClientDisconnect, buffs_RemovePlayer, CBC_ORDER_ANY);
	MUTATOR_HOOK(OnEntityPreSpawn, buffs_OnEntityPreSpawn, CBC_ORDER_LAST);
	MUTATOR_HOOK(CustomizeWaypoint, buffs_CustomizeWaypoint, CBC_ORDER_ANY);
	MUTATOR_HOOK(WeaponRateFactor, buffs_WeaponRate, CBC_ORDER_ANY);
	MUTATOR_HOOK(PlayerPreThink, buffs_PlayerThink, CBC_ORDER_ANY);
	MUTATOR_HOOK(GetCvars, buffs_GetCvars, CBC_ORDER_ANY);
	MUTATOR_HOOK(BuildMutatorsString, buffs_BuildMutatorsString, CBC_ORDER_ANY);
	MUTATOR_HOOK(BuildMutatorsPrettyString, buffs_BuildMutatorsPrettyString, CBC_ORDER_ANY);

	MUTATOR_ONADD
	{
		buffs_Initialize();
	}

	return false;
}
