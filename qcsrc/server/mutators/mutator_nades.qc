#include "../../common/effects.qh"
#include "../round_handler.qh"

.entity nade_spawnloc;

void nade_timer_think()
{
	self.skin = 8 - (self.owner.wait - time) / (autocvar_g_nades_nade_lifetime / 10);
	self.nextthink = time;
	if(!self.owner || wasfreed(self.owner))
		remove(self);
}

void nade_burn_spawn(entity _nade)
{
	CSQCProjectile(_nade, true, Nade_ProjectileFromID(_nade.nade_type, true), true);
}

void nade_spawn(entity _nade)
{
	entity timer = spawn();
	setmodel(timer, "models/ok_nade_counter/ok_nade_counter.md3");
	setattachment(timer, _nade, "");
	timer.classname = "nade_timer";
	timer.colormap = _nade.colormap;
	timer.glowmod = _nade.glowmod;
	timer.think = nade_timer_think;
	timer.nextthink = time;
	timer.wait = _nade.wait;
	timer.owner = _nade;
	timer.skin = 10;

	_nade.effects |= EF_LOWPRECISION;

	CSQCProjectile(_nade, true, Nade_ProjectileFromID(_nade.nade_type, false), true);
}

void napalm_damage(float dist, float damage, float edgedamage, float burntime)
{
	entity e;
	float d;
	vector p;

	if ( damage < 0 )
		return;

	RandomSelection_Init();
	for(e = WarpZone_FindRadius(self.origin, dist, true); e; e = e.chain)
		if(e.takedamage == DAMAGE_AIM)
		if(self.realowner != e || autocvar_g_nades_napalm_selfdamage)
		if(!IS_PLAYER(e) || !self.realowner || DIFF_TEAM(e, self))
		if(!e.frozen)
		{
			p = e.origin;
			p.x += e.mins.x + random() * (e.maxs.x - e.mins.x);
			p.y += e.mins.y + random() * (e.maxs.y - e.mins.y);
			p.z += e.mins.z + random() * (e.maxs.z - e.mins.z);
			d = vlen(WarpZone_UnTransformOrigin(e, self.origin) - p);
			if(d < dist)
			{
				e.fireball_impactvec = p;
				RandomSelection_Add(e, 0, string_null, 1 / (1 + d), !Fire_IsBurning(e));
			}
		}
	if(RandomSelection_chosen_ent)
	{
		d = vlen(WarpZone_UnTransformOrigin(RandomSelection_chosen_ent, self.origin) - RandomSelection_chosen_ent.fireball_impactvec);
		d = damage + (edgedamage - damage) * (d / dist);
		Fire_AddDamage(RandomSelection_chosen_ent, self.realowner, d * burntime, burntime, self.projectiledeathtype | HITTYPE_BOUNCE);
		Send_Effect(EFFECT_FIREBALL_LASER, self.origin, RandomSelection_chosen_ent.fireball_impactvec - self.origin, 1);
	}
}


void napalm_ball_think()
{
	if(round_handler_IsActive())
	if(!round_handler_IsRoundStarted())
	{
		remove(self);
		return;
	}

	if(time > self.pushltime)
	{
		remove(self);
		return;
	}

	vector midpoint = ((self.absmin + self.absmax) * 0.5);
	if(pointcontents(midpoint) == CONTENT_WATER)
	{
		self.velocity = self.velocity * 0.5;

		if(pointcontents(midpoint + '0 0 16') == CONTENT_WATER)
			{ self.velocity_z = 200; }
	}

	self.angles = vectoangles(self.velocity);

	napalm_damage(autocvar_g_nades_napalm_ball_radius,autocvar_g_nades_napalm_ball_damage,
				  autocvar_g_nades_napalm_ball_damage,autocvar_g_nades_napalm_burntime);

	self.nextthink = time + 0.1;
}


void nade_napalm_ball()
{
	entity proj;
	vector kick;

	spamsound(self, CH_SHOTS, W_Sound("fireball_fire"), VOL_BASE, ATTEN_NORM);

	proj = spawn ();
	proj.owner = self.owner;
	proj.realowner = self.realowner;
	proj.team = self.owner.team;
	proj.classname = "grenade";
	proj.bot_dodge = true;
	proj.bot_dodgerating = autocvar_g_nades_napalm_ball_damage;
	proj.movetype = MOVETYPE_BOUNCE;
	proj.projectiledeathtype = DEATH_NADE_NAPALM;
	PROJECTILE_MAKETRIGGER(proj);
	setmodel(proj, "null");
	proj.scale = 1;//0.5;
	setsize(proj, '-4 -4 -4', '4 4 4');
	setorigin(proj, self.origin);
	proj.think = napalm_ball_think;
	proj.nextthink = time;
	proj.damageforcescale = autocvar_g_nades_napalm_ball_damageforcescale;
	proj.effects = EF_LOWPRECISION | EF_FLAME;

	kick.x =(random() - 0.5) * 2 * autocvar_g_nades_napalm_ball_spread;
	kick.y = (random() - 0.5) * 2 * autocvar_g_nades_napalm_ball_spread;
	kick.z = (random()/2+0.5) * autocvar_g_nades_napalm_ball_spread;
	proj.velocity = kick;

	proj.pushltime = time + autocvar_g_nades_napalm_ball_lifetime;

	proj.angles = vectoangles(proj.velocity);
	proj.flags = FL_PROJECTILE;
	proj.missile_flags = MIF_SPLASH | MIF_PROXY | MIF_ARC;

	//CSQCProjectile(proj, true, PROJECTILE_NAPALM_FIRE, true);
}


void napalm_fountain_think()
{

	if(round_handler_IsActive())
	if(!round_handler_IsRoundStarted())
	{
		remove(self);
		return;
	}

	if(time >= self.ltime)
	{
		remove(self);
		return;
	}

	vector midpoint = ((self.absmin + self.absmax) * 0.5);
	if(pointcontents(midpoint) == CONTENT_WATER)
	{
		self.velocity = self.velocity * 0.5;

		if(pointcontents(midpoint + '0 0 16') == CONTENT_WATER)
			{ self.velocity_z = 200; }

		UpdateCSQCProjectile(self);
	}

	napalm_damage(autocvar_g_nades_napalm_fountain_radius, autocvar_g_nades_napalm_fountain_damage,
		autocvar_g_nades_napalm_fountain_edgedamage, autocvar_g_nades_napalm_burntime);

	self.nextthink = time + 0.1;
	if(time >= self.nade_special_time)
	{
		self.nade_special_time = time + autocvar_g_nades_napalm_fountain_delay;
		nade_napalm_ball();
	}
}

void nade_napalm_boom()
{
	entity fountain;
	int c;
	for (c = 0; c < autocvar_g_nades_napalm_ball_count; c++)
		nade_napalm_ball();


	fountain = spawn();
	fountain.owner = self.owner;
	fountain.realowner = self.realowner;
	fountain.origin = self.origin;
	setorigin(fountain, fountain.origin);
	fountain.think = napalm_fountain_think;
	fountain.nextthink = time;
	fountain.ltime = time + autocvar_g_nades_napalm_fountain_lifetime;
	fountain.pushltime = fountain.ltime;
	fountain.team = self.team;
	fountain.movetype = MOVETYPE_TOSS;
	fountain.projectiledeathtype = DEATH_NADE_NAPALM;
	fountain.bot_dodge = true;
	fountain.bot_dodgerating = autocvar_g_nades_napalm_fountain_damage;
	fountain.nade_special_time = time;
	setsize(fountain, '-16 -16 -16', '16 16 16');
	CSQCProjectile(fountain, true, PROJECTILE_NAPALM_FOUNTAIN, true);
}

void nade_ice_freeze(entity freezefield, entity frost_target, float freeze_time)
{
	frost_target.frozen_by = freezefield.realowner;
	Send_Effect(EFFECT_ELECTRO_IMPACT, frost_target.origin, '0 0 0', 1);
	Freeze(frost_target, 1/freeze_time, 3, false);
	if(frost_target.ballcarried)
	if(g_keepaway) { ka_DropEvent(frost_target); }
	else { DropBall(frost_target.ballcarried, frost_target.origin, frost_target.velocity);}
	if(frost_target.flagcarried) { ctf_Handle_Throw(frost_target, world, DROP_THROW); }
	if(frost_target.nade) { toss_nade(frost_target, '0 0 0', time + 0.05); }
	
	entity key;
	KH_FOR_EACH_KEY(key) if(key.owner == frost_target) { kh_Handle_Throw(frost_target, world, key, DROP_THROW); }
}

void nade_ice_think()
{

	if(round_handler_IsActive())
	if(!round_handler_IsRoundStarted())
	{
		remove(self);
		return;
	}

	if(time >= self.ltime)
	{
		if ( autocvar_g_nades_ice_explode )
		{
			float expef;
			switch(self.realowner.team)
			{
				case NUM_TEAM_1: expef = EFFECT_NADE_RED_EXPLODE; break;
				case NUM_TEAM_2: expef = EFFECT_NADE_BLUE_EXPLODE; break;
				case NUM_TEAM_3: expef = EFFECT_NADE_YELLOW_EXPLODE; break;
				case NUM_TEAM_4: expef = EFFECT_NADE_PINK_EXPLODE; break;
				default:		 expef = EFFECT_NADE_NEUTRAL_EXPLODE; break;
			}
			Send_Effect(expef, self.origin + '0 0 1', '0 0 0', 1);
			sound(self, CH_SHOTS, W_Sound("rocket_impact"), VOL_BASE, ATTEN_NORM);

			RadiusDamage(self, self.realowner, autocvar_g_nades_nade_damage, autocvar_g_nades_nade_edgedamage,
				autocvar_g_nades_nade_radius, self, world, autocvar_g_nades_nade_force, self.projectiledeathtype, self.enemy);
			Damage_DamageInfo(self.origin, autocvar_g_nades_nade_damage, autocvar_g_nades_nade_edgedamage,
				autocvar_g_nades_nade_radius, '1 1 1' * autocvar_g_nades_nade_force, self.projectiledeathtype, 0, self);
		}
		remove(self);
		return;
	}


	self.nextthink = time+0.1;

	// gaussian
	float randomr;
	randomr = random();
	randomr = exp(-5*randomr*randomr)*autocvar_g_nades_nade_radius;
	float randomw;
	randomw = random()*M_PI*2;
	vector randomp;
	randomp.x = randomr*cos(randomw);
	randomp.y = randomr*sin(randomw);
	randomp.z = 1;
	Send_Effect(EFFECT_ELECTRO_MUZZLEFLASH, self.origin + randomp, '0 0 0', 1);

	if(time >= self.nade_special_time)
	{
		self.nade_special_time = time+0.7;

		Send_Effect(EFFECT_ELECTRO_IMPACT, self.origin, '0 0 0', 1);
		Send_Effect(EFFECT_ICEFIELD, self.origin, '0 0 0', 1);
	}


	float current_freeze_time = self.ltime - time - 0.1;

	entity e;
	for(e = findradius(self.origin, autocvar_g_nades_nade_radius); e; e = e.chain)
	if(e != self)
	if(!autocvar_g_nades_ice_teamcheck || (DIFF_TEAM(e, self.realowner) || e == self.realowner))
	if(e.takedamage)
	if(e.health > 0)
	if(!Player_Trapped(e))
	if(!e.revival_time || ((time - e.revival_time) >= 1.5))
	if(current_freeze_time > 0)
		nade_ice_freeze(self, e, current_freeze_time);
}

void nade_ice_boom()
{
	entity fountain;
	fountain = spawn();
	fountain.owner = self.owner;
	fountain.realowner = self.realowner;
	fountain.origin = self.origin;
	setorigin(fountain, fountain.origin);
	fountain.think = nade_ice_think;
	fountain.nextthink = time;
	fountain.ltime = time + autocvar_g_nades_ice_freeze_time;
	fountain.pushltime = fountain.wait = fountain.ltime;
	fountain.team = self.team;
	fountain.movetype = MOVETYPE_TOSS;
	fountain.projectiledeathtype = DEATH_NADE_ICE;
	fountain.bot_dodge = false;
	setsize(fountain, '-16 -16 -16', '16 16 16');
	fountain.nade_special_time = time+0.3;
	fountain.angles = self.angles;

	if ( autocvar_g_nades_ice_explode )
	{
		setmodel(fountain, "models/grenademodel.md3");
		entity timer = spawn();
		setmodel(timer, "models/ok_nade_counter/ok_nade_counter.md3");
		setattachment(timer, fountain, "");
		timer.classname = "nade_timer";
		timer.colormap = self.colormap;
		timer.glowmod = self.glowmod;
		timer.think = nade_timer_think;
		timer.nextthink = time;
		timer.wait = fountain.ltime;
		timer.owner = fountain;
		timer.skin = 10;
	}
	else
		setmodel(fountain, "null");
}

void nade_translocate_boom()
{
	if(self.realowner.vehicle)
		return;

	vector locout = self.origin + '0 0 1' * (1 - self.realowner.mins.z - 24);
	tracebox(locout, self.realowner.mins, self.realowner.maxs, locout, MOVE_NOMONSTERS, self.realowner);
	locout = trace_endpos;

	makevectors(self.realowner.angles);

	entity oldself = self;
	self = self.realowner;
	MUTATOR_CALLHOOK(PortalTeleport);
	self.realowner = self;
	self = oldself;

	TeleportPlayer(self, self.realowner, locout, self.realowner.mangle, v_forward * vlen(self.realowner.velocity), '0 0 0', '0 0 0', TELEPORT_FLAGS_TELEPORTER);
}

void nade_spawn_boom()
{
	entity spawnloc = spawn();
	setorigin(spawnloc, self.origin);
	setsize(spawnloc, self.realowner.mins, self.realowner.maxs);
	spawnloc.movetype = MOVETYPE_NONE;
	spawnloc.solid = SOLID_NOT;
	spawnloc.drawonlytoclient = self.realowner;
	spawnloc.effects = EF_STARDUST;
	spawnloc.cnt = autocvar_g_nades_spawn_count;

	if(self.realowner.nade_spawnloc)
	{
		remove(self.realowner.nade_spawnloc);
		self.realowner.nade_spawnloc = world;
	}

	self.realowner.nade_spawnloc = spawnloc;
}

void nade_heal_think()
{
	if(time >= self.ltime)
	{
		remove(self);
		return;
	}

	self.nextthink = time;

	if(time >= self.nade_special_time)
	{
		self.nade_special_time = time+0.25;
		self.nade_show_particles = 1;
	}
	else
		self.nade_show_particles = 0;
}

void nade_heal_touch()
{
	float maxhealth;
	float health_factor;
	if(IS_PLAYER(other) || IS_MONSTER(other))
	if(other.deadflag == DEAD_NO)
	if(!other.frozen)
	{
		health_factor = autocvar_g_nades_heal_rate*frametime/2;
		if ( other != self.realowner )
		{
			if ( SAME_TEAM(other,self) )
				health_factor *= autocvar_g_nades_heal_friend;
			else
				health_factor *= autocvar_g_nades_heal_foe;
		}
		if ( health_factor > 0 )
		{
			maxhealth = (IS_MONSTER(other)) ? other.max_health : 200; // TODO: find a good limiter that works across all modes and mutators
			if ( other.health < maxhealth )
			{
				if ( self.nade_show_particles )
					Send_Effect(EFFECT_HEALING, other.origin, '0 0 0', 1);
				other.health = min(other.health+health_factor, maxhealth);
			}
			other.pauserothealth_finished = max(other.pauserothealth_finished, time + autocvar_g_balance_pause_health_rot);
		}
		else if ( health_factor < 0 )
		{
			Damage(other,self,self.realowner,-health_factor,DEATH_NADE_HEAL,other.origin,'0 0 0');
		}

	}
	
	if ( IS_REAL_CLIENT(other) || IS_VEHICLE(other) )
	{
		entity show_red = IS_VEHICLE(other) ? other.owner : other;
		show_red.stat_healing_orb = time+0.1;
		show_red.stat_healing_orb_alpha = 0.75 * (self.ltime - time) / self.healer_lifetime;
	}
}

void nade_heal_boom()
{
	entity healer;
	healer = spawn();
	healer.owner = self.owner;
	healer.realowner = self.realowner;
	setorigin(healer, self.origin);
	healer.healer_lifetime = autocvar_g_nades_heal_time; // save the cvar
	healer.ltime = time + healer.healer_lifetime;
	healer.team = self.realowner.team;
	healer.bot_dodge = false;
	healer.solid = SOLID_TRIGGER;
	healer.touch = nade_heal_touch;

	setmodel(healer, "models/ctf/shield.md3");
	healer.healer_radius = autocvar_g_nades_nade_radius;
	vector size = '1 1 1' * healer.healer_radius / 2;
	setsize(healer,-size,size);

	Net_LinkEntity(healer, true, 0, healer_send);

	healer.think = nade_heal_think;
	healer.nextthink = time;
	healer.SendFlags |= 1;
}

void nade_monster_boom()
{
	entity e = spawnmonster(self.pokenade_type, 0, self.realowner, self.realowner, self.origin, false, false, 1);

	if(autocvar_g_nades_pokenade_monster_lifetime > 0)
		e.monster_lifetime = time + autocvar_g_nades_pokenade_monster_lifetime;
	e.monster_skill = MONSTER_SKILL_INSANE;
}

void nade_boom()
{
	float expef;
	float nade_blast = 1;

	switch ( self.nade_type )
	{
		case NADE_TYPE_NAPALM:
			nade_blast = autocvar_g_nades_napalm_blast;
			expef = EFFECT_EXPLOSION_MEDIUM;
			break;
		case NADE_TYPE_ICE:
			nade_blast = 0;
			expef = EFFECT_ELECTRO_COMBO; // hookbomb_explode electro_combo bigplasma_impact
			break;
		case NADE_TYPE_TRANSLOCATE:
			nade_blast = 0;
			expef = 0;
			break;
		case NADE_TYPE_MONSTER:
		case NADE_TYPE_SPAWN:
			nade_blast = 0;
			switch(self.realowner.team)
			{
				case NUM_TEAM_1: expef = EFFECT_SPAWN_RED; break;
				case NUM_TEAM_2: expef = EFFECT_SPAWN_BLUE; break;
				case NUM_TEAM_3: expef = EFFECT_SPAWN_YELLOW; break;
				case NUM_TEAM_4: expef = EFFECT_SPAWN_PINK; break;
				default: expef = EFFECT_SPAWN_NEUTRAL; break;
			}
			break;
		case NADE_TYPE_HEAL:
			nade_blast = 0;
			expef = EFFECT_SPAWN_RED;
			break;

		default:
		case NADE_TYPE_NORMAL:
			switch(self.realowner.team)
			{
				case NUM_TEAM_1: expef = EFFECT_NADE_RED_EXPLODE; break;
				case NUM_TEAM_2: expef = EFFECT_NADE_BLUE_EXPLODE; break;
				case NUM_TEAM_3: expef = EFFECT_NADE_YELLOW_EXPLODE; break;
				case NUM_TEAM_4: expef = EFFECT_NADE_PINK_EXPLODE; break;
				default:		 expef = EFFECT_NADE_NEUTRAL_EXPLODE; break;
			}
	}

	if(expef) { Send_Effect(expef, self.origin + '0 0 1', '0 0 0', 1); }

	sound(self, CH_SHOTS_SINGLE, "misc/null.wav", VOL_BASE, ATTEN_NORM);
	sound(self, CH_SHOTS, W_Sound("rocket_impact"), VOL_BASE, ATTEN_NORM);

	self.event_damage = func_null; // prevent somehow calling damage in the next call

	if(nade_blast)
	{
		RadiusDamage(self, self.realowner, autocvar_g_nades_nade_damage, autocvar_g_nades_nade_edgedamage,
				 autocvar_g_nades_nade_radius, self, world, autocvar_g_nades_nade_force, self.projectiledeathtype, self.enemy);
		Damage_DamageInfo(self.origin, autocvar_g_nades_nade_damage, autocvar_g_nades_nade_edgedamage, autocvar_g_nades_nade_radius, '1 1 1' * autocvar_g_nades_nade_force, self.projectiledeathtype, 0, self);
	}

	if(self.takedamage)
	switch ( self.nade_type )
	{
		case NADE_TYPE_NAPALM: nade_napalm_boom(); break;
		case NADE_TYPE_ICE: nade_ice_boom(); break;
		case NADE_TYPE_TRANSLOCATE: nade_translocate_boom(); break;
		case NADE_TYPE_SPAWN: nade_spawn_boom(); break;
		case NADE_TYPE_HEAL: nade_heal_boom(); break;
		case NADE_TYPE_MONSTER: nade_monster_boom(); break;
	}

	entity head;
	for(head = world; (head = find(head, classname, "grapplinghook")); )
	if(head.aiment == self)
		RemoveGrapplingHook(head.realowner);

	remove(self);
}

void nade_touch()
{
	/*float is_weapclip = 0;
	if(trace_dphitq3surfaceflags & Q3SURFACEFLAG_NODRAW)
	if (!(trace_dphitq3surfaceflags & Q3SURFACEFLAG_NONSOLID))
	if (!(trace_dphitcontents & DPCONTENTS_OPAQUE))
		is_weapclip = 1;*/
	if(ITEM_TOUCH_NEEDKILL()) // || is_weapclip)
	{
		remove(self);
		return;
	}

	PROJECTILE_TOUCH;

	//setsize(self, '-2 -2 -2', '2 2 2');
	//UpdateCSQCProjectile(self);
	if(self.health == self.max_health)
	{
		spamsound(self, CH_SHOTS, W_Sound(strcat("grenade_bounce", ftos(1 + rint(random() * 5)))), VOL_BASE, ATTEN_NORM);
		return;
	}

	self.enemy = other;
	nade_boom();
}

void nade_beep()
{
	sound(self, CH_SHOTS_SINGLE, "overkill/grenadebip.ogg", VOL_BASE, 0.5 *(ATTEN_LARGE + ATTEN_MAX));
	self.think = nade_boom;
	self.nextthink = max(self.wait, time);
}

void nade_damage(entity inflictor, entity attacker, float damage, float deathtype, vector hitloc, vector force)
{
	if(ITEM_DAMAGE_NEEDKILL(deathtype))
	{
		self.takedamage = DAMAGE_NO;
		nade_boom();
		return;
	}

	if(self.nade_type == NADE_TYPE_TRANSLOCATE || self.nade_type == NADE_TYPE_SPAWN)
		return;

	if(DEATH_ISWEAPON(deathtype, WEP_BLASTER))
	{
		force *= 1.5;
		damage = 0;
	}

	if(DEATH_ISWEAPON(deathtype, WEP_VAPORIZER) && (deathtype & HITTYPE_SECONDARY))
	{
		force *= 0.5; // too much
		frag_damage = 0;
	}

	if(DEATH_ISWEAPON(deathtype, WEP_VORTEX) || DEATH_ISWEAPON(deathtype, WEP_VAPORIZER))
	{
		force *= 6;
		damage = self.max_health * 0.55;
	}

	if(DEATH_ISWEAPON(deathtype, WEP_MACHINEGUN) || DEATH_ISWEAPON(deathtype, WEP_HMG))
		damage = self.max_health * 0.1;

	if(DEATH_ISWEAPON(deathtype, WEP_SHOCKWAVE) || DEATH_ISWEAPON(deathtype, WEP_SHOTGUN)) // WEAPONTODO
	if(deathtype & HITTYPE_SECONDARY)
	{
		damage = self.max_health * 0.1;
		force *= 10;
	}
	else
		damage = self.max_health * 1.15;

	self.velocity += force;
	UpdateCSQCProjectile(self);

	if(damage <= 0 || ((self.flags & FL_ONGROUND) && IS_PLAYER(attacker)))
		return;

	if(self.health == self.max_health)
	{
		sound(self, CH_SHOTS_SINGLE, "misc/null.wav", VOL_BASE, 0.5 *(ATTEN_LARGE + ATTEN_MAX));
		self.nextthink = max(time + autocvar_g_nades_nade_lifetime, time);
		self.think = nade_beep;
	}

	self.health -= damage;

	if ( self.nade_type != NADE_TYPE_HEAL || IS_PLAYER(attacker) )
		self.realowner = attacker;

	if(self.health <= 0)
		W_PrepareExplosionByDamage(attacker, nade_boom);
	else
		nade_burn_spawn(self);
}

void toss_nade(entity e, vector _velocity, float _time)
{
	if(e.nade == world)
		return;

	entity _nade = e.nade;
	e.nade = world;

	remove(e.fake_nade);
	e.fake_nade = world;

	makevectors(e.v_angle);

	W_SetupShot(e, false, false, "", CH_WEAPON_A, 0);

	Kill_Notification(NOTIF_ONE_ONLY, e, MSG_CENTER_CPID, CPID_NADES);

	setorigin(_nade, w_shotorg + (v_right * 25) * -1);
	//setmodel(_nade, "models/weapons/v_ok_grenade.md3");
	//setattachment(_nade, world, "");
	PROJECTILE_MAKETRIGGER(_nade);
	setsize(_nade, '-16 -16 -16', '16 16 16');
	_nade.movetype = MOVETYPE_BOUNCE;

	tracebox(_nade.origin, _nade.mins, _nade.maxs, _nade.origin, false, _nade);
	if (trace_startsolid)
		setorigin(_nade, e.origin);

	if(self.v_angle.x >= 70 && self.v_angle.x <= 110)
		_nade.velocity = '0 0 100';
	else if(autocvar_g_nades_nade_newton_style == 1)
		_nade.velocity = e.velocity + _velocity;
	else if(autocvar_g_nades_nade_newton_style == 2)
		_nade.velocity = _velocity;
	else
		_nade.velocity = W_CalculateProjectileVelocity(e.velocity, _velocity, true);

	_nade.touch = nade_touch;
	_nade.health = autocvar_g_nades_nade_health;
	_nade.max_health = _nade.health;
	_nade.takedamage = DAMAGE_AIM;
	_nade.event_damage = nade_damage;
	_nade.customizeentityforclient = func_null;
	_nade.exteriormodeltoclient = world;
	_nade.traileffectnum = 0;
	_nade.teleportable = true;
	_nade.pushable = true;
	_nade.gravity = 1;
	_nade.missile_flags = MIF_SPLASH | MIF_ARC;
	_nade.damagedbycontents = true;
	_nade.angles = vectoangles(_nade.velocity);
	_nade.flags = FL_PROJECTILE;
	_nade.projectiledeathtype = DEATH_NADE;
	_nade.toss_time = time;
	//_nade.solid = SOLID_TRIGGER; //((_nade.nade_type == NADE_TYPE_TRANSLOCATE) ? SOLID_CORPSE : SOLID_BBOX);

	if(_nade.nade_type == NADE_TYPE_TRANSLOCATE || _nade.nade_type == NADE_TYPE_SPAWN)
		_nade.dphitcontentsmask = DPCONTENTS_SOLID | DPCONTENTS_PLAYERCLIP | DPCONTENTS_BOTCLIP;
	else
		_nade.dphitcontentsmask = DPCONTENTS_SOLID | DPCONTENTS_BODY;

	nade_spawn(_nade);

	if(_time)
	{
		_nade.think = nade_boom;
		_nade.nextthink = _time;
	}

	e.nade_refire = time + autocvar_g_nades_nade_refire;
	e.nade_timer = 0;
}

void nades_GiveBonus(entity player, float score)
{
	if (autocvar_g_nades)
	if (autocvar_g_nades_bonus)
	if (IS_REAL_CLIENT(player))
	if (IS_PLAYER(player) && player.bonus_nades < autocvar_g_nades_bonus_max)
	if (player.frozen == 0)
	if (player.deadflag == DEAD_NO)
	{
		if ( player.bonus_nade_score < 1 )
			player.bonus_nade_score += score/autocvar_g_nades_bonus_score_max;

		if ( player.bonus_nade_score >= 1 )
		{
			Send_Notification(NOTIF_ONE, player, MSG_CENTER, CENTER_NADE_BONUS);
			Send_Notification(NOTIF_ONE, player, MSG_ANNCE, ANNCE_BONUSNADE);
			play2(player,"kh/alarm.wav");
			player.bonus_nades++;
			player.bonus_nade_score -= 1;
		}
	}
}

void nades_RemoveBonus(entity player)
{
	player.bonus_nades = player.bonus_nade_score = 0;
}

float nade_customize()
{
	//if(IS_SPEC(other)) { return false; }
	if(other == self.realowner || (IS_SPEC(other) && other.enemy == self.realowner))
	{
		// somewhat hide the model, but keep the glow
		//self.effects = 0;
		if(self.traileffectnum)
			self.traileffectnum = 0;
		self.alpha = -1;
	}
	else
	{
		//self.effects = EF_ADDITIVE | EF_FULLBRIGHT | EF_LOWPRECISION;
		if(!self.traileffectnum)
			self.traileffectnum = particleeffectnum(Nade_TrailEffect(Nade_ProjectileFromID(self.nade_type, false), self.team));
		self.alpha = 1;
	}

	return true;
}

void nade_prime()
{
	if(autocvar_g_nades_bonus_only)
	if(!self.bonus_nades)
		return; // only allow bonus nades

	if(self.nade)
		remove(self.nade);

	if(self.fake_nade)
		remove(self.fake_nade);

	entity n = spawn(), fn = spawn();

	n.classname = "nade";
	fn.classname = "fake_nade";

	if (self.bonus_nades >= 1)
	{
		n.nade_type = self.nade_type;
		n.pokenade_type = self.pokenade_type;
		self.bonus_nades -= 1;
	}
	else
	{
		n.nade_type = ((autocvar_g_nades_client_select) ? self.cvar_cl_nade_type : autocvar_g_nades_nade_type);
		n.pokenade_type = ((autocvar_g_nades_client_select) ? self.cvar_cl_pokenade_type : autocvar_g_nades_pokenade_monster_type);
	}

	n.nade_type = bound(1, n.nade_type, NADE_TYPE_LAST);

	setmodel(n, "models/weapons/v_ok_grenade.md3");
	//setattachment(n, self, "bip01 l hand");
	n.exteriormodeltoclient = self;
	n.customizeentityforclient = nade_customize;
	n.traileffectnum = particleeffectnum(Nade_TrailEffect(Nade_ProjectileFromID(n.nade_type, false), self.team));
	n.colormod = Nade_Color(n.nade_type);
	n.realowner = self;
	n.colormap = self.colormap;
	n.glowmod = self.glowmod;
	n.wait = time + autocvar_g_nades_nade_lifetime;
	n.lifetime = time;
	n.think = nade_beep;
	n.nextthink = max(n.wait - 3, time);
	n.projectiledeathtype = DEATH_NADE;

	setmodel(fn, "models/weapons/h_ok_grenade.iqm");
	setattachment(fn, self.weaponentity, "");
	fn.realowner = fn.owner = self;
	fn.colormod = Nade_Color(n.nade_type);
	fn.colormap = self.colormap;
	fn.glowmod = self.glowmod;
	fn.think = SUB_Remove;
	fn.nextthink = n.wait;

	self.nade = n;
	self.fake_nade = fn;
}

float CanThrowNade()
{
	if(self.vehicle)
		return false;

	if(gameover)
		return false;

	if(self.deadflag != DEAD_NO)
		return false;

	if (!autocvar_g_nades)
		return false; // allow turning them off mid match

	if(forbidWeaponUse(self))
		return false;

	if (!IS_PLAYER(self))
		return false;

	return true;
}

void nades_CheckThrow()
{
	if(!CanThrowNade())
		return;

	if(!self.nade)
	{
		if(self.nade_refire < time)
		{
			Send_Notification(NOTIF_ONE, self, MSG_CENTER, CENTER_NADE_THROW);
			nade_prime();
			self.nade_refire = time + autocvar_g_nades_nade_refire;
		}
	}
	else
	{
		if(time - self.nade.lifetime >= 1)
		{
			makevectors(self.v_angle);
			float _force = time - self.nade.lifetime;
			_force /= autocvar_g_nades_nade_lifetime;
			_force = autocvar_g_nades_nade_minforce + (_force * (autocvar_g_nades_nade_maxforce - autocvar_g_nades_nade_minforce));
			toss_nade(self, (v_forward * 0.75 + v_up * 0.2 + v_right * 0.05) * _force, 0);
		}
	}
}

void nades_Clear(entity player, float allplayers)
{
	if(allplayers)
	{
		entity head;
		FOR_EACH_PLAYER(head) if(head != player)
		{
			if(head.nade) { remove(head.nade); }
			if(head.fake_nade) { remove(head.fake_nade); }
			head.nade = head.fake_nade = world;
			head.nade_timer = 0;
		}

		return;
	}
	
	if(!player) { return; }

	if(player.nade) { remove(player.nade); }
	if(player.fake_nade) { remove(player.fake_nade); }

	player.nade = player.fake_nade = world;
	player.nade_timer = 0;
}

MUTATOR_HOOKFUNCTION(nades_CheckThrow)
{
	if(MUTATOR_RETURNVALUE) { nades_CheckThrow(); }
	return false;
}

MUTATOR_HOOKFUNCTION(nades_VehicleEnter)
{
	if(vh_player.nade)
		toss_nade(vh_player, '0 0 100', max(vh_player.nade.wait, time + 0.05));

	return false;
}

MUTATOR_HOOKFUNCTION(nades_PlayerPreThink)
{
	if(!IS_PLAYER(self)) { return false; }

	float key_pressed = self.BUTTON_HOOK;
	float time_score;

	if(g_grappling_hook || client_hasweapon(self, WEP_HOOK, false, false) || (weaponsInMap & WEPSET_HOOK))
		key_pressed = self.button16; // if hook is enabled, use an alternate key

	if(self.nade)
	{
		self.nade_timer = bound(0, (time - self.nade.lifetime) / autocvar_g_nades_nade_lifetime, 1);
		//print(sprintf("%d %d\n", self.nade_timer, time - self.nade.lifetime));
		makevectors(self.angles);
		self.nade.velocity = self.velocity;

		setorigin(self.nade, self.origin + self.view_ofs + v_forward * 8 + v_right * -8 + v_up * 0);
		self.nade.angles_y = self.angles.y;
	}

	if(self.nade)
	if(self.nade.wait - 0.1 <= time)
		toss_nade(self, '0 0 0', time + 0.05);

	if(CanThrowNade())
	if(self.nade_refire < time)
	{
		if(key_pressed)
		{
			if(!self.nade)
				nade_prime();
		}
		else if(time - self.nade.lifetime >= 1)
		{
			if(self.nade)
			{
				makevectors(self.v_angle);
				float _force = time - self.nade.lifetime;
				_force /= autocvar_g_nades_nade_lifetime;
				_force = autocvar_g_nades_nade_minforce + (_force * (autocvar_g_nades_nade_maxforce - autocvar_g_nades_nade_minforce));
				toss_nade(self, (v_forward * 0.7 + v_up * 0.2 + v_right * 0.1) * _force, 0);
			}
		}
	}

	if(IS_PLAYER(self))
	{
		if ( autocvar_g_nades_bonus && autocvar_g_nades )
		{
			entity key;
			float key_count = 0;
			KH_FOR_EACH_KEY(key) if(key.owner == self) { ++key_count; }

			if(self.flagcarried || self.isvip || self.ballcarried) // this player is important
				time_score = autocvar_g_nades_bonus_score_time_flagcarrier;
			else
				time_score = autocvar_g_nades_bonus_score_time;

			if(key_count)
				time_score = autocvar_g_nades_bonus_score_time_flagcarrier * key_count; // multiply by the number of keys the player is holding

			if(autocvar_g_nades_bonus_client_select)
			{
				self.nade_type = self.cvar_cl_nade_type;
				self.pokenade_type = self.cvar_cl_pokenade_type;
			}
			else
			{
				self.nade_type = autocvar_g_nades_bonus_type;
				self.pokenade_type = autocvar_g_nades_pokenade_monster_type;
			}

			self.nade_type = bound(1, self.nade_type, NADE_TYPE_LAST);

			if(self.bonus_nade_score >= 0 && autocvar_g_nades_bonus_score_max)
				nades_GiveBonus(self, time_score / autocvar_g_nades_bonus_score_max);
		}
		else
		{
			self.bonus_nades = self.bonus_nade_score = 0;
		}
	}

	float n = 0;
	entity o = world;
	if(self.freezetag_frozen_timeout > 0 && time >= self.freezetag_frozen_timeout)
		n = -1;
	else
	{
		vector revive_extra_size = '1 1 1' * autocvar_g_freezetag_revive_extra_size;
		n = 0;
		FOR_EACH_PLAYER(other) if(self != other)
		{
			if(other.deadflag == DEAD_NO)
			if(other.frozen == 0)
			if(SAME_TEAM(other, self))
			if(boxesoverlap(self.absmin - revive_extra_size, self.absmax + revive_extra_size, other.absmin, other.absmax))
			{
				if(!o)
					o = other;
				if(self.frozen == 1)
					other.reviving = true;
				++n;
			}
		}
	}

	if(n && self.frozen == 3) // OK, there is at least one teammate reviving us
	{
		self.revive_progress = bound(0, self.revive_progress + frametime * max(1/60, autocvar_g_freezetag_revive_speed), 1);
		self.health = max(1, self.revive_progress * start_health);

		if(self.revive_progress >= 1)
		{
			Unfreeze(self);

			Send_Notification(NOTIF_ONE, self, MSG_CENTER, CENTER_FREEZETAG_REVIVED, o.netname);
			Send_Notification(NOTIF_ONE, o, MSG_CENTER, CENTER_FREEZETAG_REVIVE, self.netname);
		}

		FOR_EACH_PLAYER(other) if(other.reviving)
		{
			other.revive_progress = self.revive_progress;
			other.reviving = false;
		}
	}

	return false;
}

MUTATOR_HOOKFUNCTION(nades_PlayerSpawn)
{
	if(autocvar_g_nades_spawn)
		self.nade_refire = time + autocvar_g_spawnshieldtime;
	else
		self.nade_refire  = time + autocvar_g_nades_nade_refire;

	if(autocvar_g_nades_bonus_client_select)
		self.nade_type = self.cvar_cl_nade_type;

	self.nade_timer = 0;

	if(self.nade_spawnloc)
	if(!Player_Trapped(self))
	{
		setorigin(self, self.nade_spawnloc.origin);
		self.nade_spawnloc.cnt -= 1;

		if(self.nade_spawnloc.cnt <= 0)
		{
			remove(self.nade_spawnloc);
			self.nade_spawnloc = world;
		}
	}

	return false;
}

MUTATOR_HOOKFUNCTION(nades_PlayerDies)
{
	if(frag_target.nade)
	if(!frag_target.frozen || !autocvar_g_freeze_revive_nade)
		toss_nade(frag_target, '0 0 100', max(frag_target.nade.wait, time + 0.05));

	float killcount_bonus = ((frag_attacker.killcount >= 1) ? bound(0, autocvar_g_nades_bonus_score_minor * frag_attacker.killcount, autocvar_g_nades_bonus_score_medium) : autocvar_g_nades_bonus_score_minor);

	if(IS_PLAYER(frag_attacker))
	{
		if (SAME_TEAM(frag_attacker, frag_target) || frag_attacker == frag_target)
			nades_RemoveBonus(frag_attacker);
		else if(frag_target.flagcarried)
			nades_GiveBonus(frag_attacker, autocvar_g_nades_bonus_score_medium);
		else if(autocvar_g_nades_bonus_score_spree && frag_attacker.killcount > 1)
		{
			#define SPREE_ITEM(counta,countb,center,normal,gentle) \
				case counta: { nades_GiveBonus(frag_attacker, autocvar_g_nades_bonus_score_spree); break; }
			switch(frag_attacker.killcount)
			{
				KILL_SPREE_LIST
				default: nades_GiveBonus(frag_attacker, autocvar_g_nades_bonus_score_minor); break;
			}
			#undef SPREE_ITEM
		}
		else
			nades_GiveBonus(frag_attacker, killcount_bonus);
	}

	nades_RemoveBonus(frag_target);

	return false;
}

MUTATOR_HOOKFUNCTION(nades_PlayerDamage)
{
	if(frag_target.frozen)
	if(autocvar_g_freeze_revive_nade)
	if(frag_attacker == frag_target)
	if(frag_deathtype == DEATH_NADE)
	if(time - frag_inflictor.toss_time <= 0.1)
	{
		Unfreeze(frag_target);
		frag_target.health = autocvar_g_freeze_revive_nade_health;
		Send_Effect(EFFECT_ICEORGLASS, frag_target.origin, '0 0 0', 3);
		frag_damage = 0;
		frag_force = '0 0 0';
		Send_Notification(NOTIF_ALL, world, MSG_INFO, INFO_FREEZETAG_REVIVED_NADE, frag_target.netname);
		Send_Notification(NOTIF_ONE, frag_target, MSG_CENTER, CENTER_FREEZETAG_REVIVE_SELF);
	}

	return false;
}

MUTATOR_HOOKFUNCTION(nades_MonsterDies)
{
	if(IS_PLAYER(frag_attacker))
	if(DIFF_TEAM(frag_attacker, self))
	if(!(self.spawnflags & MONSTERFLAG_SPAWNED))
		nades_GiveBonus(frag_attacker, autocvar_g_nades_bonus_score_minor);

	return false;
}

MUTATOR_HOOKFUNCTION(nades_RemovePlayer)
{
	nades_Clear(self, false);
	nades_RemoveBonus(self);
	return false;
}

MUTATOR_HOOKFUNCTION(nades_SpectateCopy)
{
	self.nade_timer = other.nade_timer;
	self.nade_type = other.nade_type;
	self.pokenade_type = other.pokenade_type;
	self.bonus_nades = other.bonus_nades;
	self.bonus_nade_score = other.bonus_nade_score;
	self.stat_healing_orb = other.stat_healing_orb;
	self.stat_healing_orb_alpha = other.stat_healing_orb_alpha;
	return false;
}

MUTATOR_HOOKFUNCTION(nades_GetCvars)
{
	GetCvars_handleFloat(get_cvars_s, get_cvars_f, cvar_cl_nade_type, "cl_nade_type");
	GetCvars_handleString(get_cvars_s, get_cvars_f, cvar_cl_pokenade_type, "cl_pokenade_type");

	return false;
}

MUTATOR_HOOKFUNCTION(nades_BuildMutatorsString)
{
	ret_string = strcat(ret_string, ":Nades");
	return false;
}

MUTATOR_HOOKFUNCTION(nades_BuildMutatorsPrettyString)
{
	ret_string = strcat(ret_string, ", Nades");
	return false;
}

void nades_Initialize()
{
	addstat(STAT_NADE_TIMER, AS_FLOAT, nade_timer);
	addstat(STAT_NADE_BONUS, AS_FLOAT, bonus_nades);
	addstat(STAT_NADE_BONUS_TYPE, AS_INT, nade_type);
	addstat(STAT_NADE_BONUS_SCORE, AS_FLOAT, bonus_nade_score);
	addstat(STAT_HEALING_ORB, AS_FLOAT, stat_healing_orb);
	addstat(STAT_HEALING_ORB_ALPHA, AS_FLOAT, stat_healing_orb_alpha);

	precache_model("models/ok_nade_counter/ok_nade_counter.md3");
	precache_model("models/weapons/h_ok_grenade.iqm");
	precache_model("models/weapons/v_ok_grenade.md3");
	precache_model("models/ctf/shield.md3");

	precache_sound(W_Sound("rocket_impact"));
	precache_sound(W_Sound("grenade_bounce1"));
	precache_sound(W_Sound("grenade_bounce2"));
	precache_sound(W_Sound("grenade_bounce3"));
	precache_sound(W_Sound("grenade_bounce4"));
	precache_sound(W_Sound("grenade_bounce5"));
	precache_sound(W_Sound("grenade_bounce6"));
	precache_sound("overkill/grenadebip.ogg");
}

MUTATOR_DEFINITION(mutator_nades)
{
	MUTATOR_HOOK(ForbidThrowCurrentWeapon, nades_CheckThrow, CBC_ORDER_LAST);
	MUTATOR_HOOK(VehicleEnter, nades_VehicleEnter, CBC_ORDER_ANY);
	MUTATOR_HOOK(PlayerPreThink, nades_PlayerPreThink, CBC_ORDER_ANY);
	MUTATOR_HOOK(PlayerSpawn, nades_PlayerSpawn, CBC_ORDER_ANY);
	MUTATOR_HOOK(PlayerDies, nades_PlayerDies, CBC_ORDER_LAST);
	MUTATOR_HOOK(PlayerDamage_Calculate, nades_PlayerDamage, CBC_ORDER_ANY);
	MUTATOR_HOOK(MonsterDies, nades_MonsterDies, CBC_ORDER_ANY);
	MUTATOR_HOOK(MakePlayerObserver, nades_RemovePlayer, CBC_ORDER_ANY);
	MUTATOR_HOOK(ClientDisconnect, nades_RemovePlayer, CBC_ORDER_ANY);
	MUTATOR_HOOK(SpectateCopy, nades_SpectateCopy, CBC_ORDER_ANY);
	MUTATOR_HOOK(GetCvars, nades_GetCvars, CBC_ORDER_ANY);
	MUTATOR_HOOK(reset_map_global, nades_RemovePlayer, CBC_ORDER_ANY);
	MUTATOR_HOOK(BuildMutatorsString, nades_BuildMutatorsString, CBC_ORDER_ANY);
	MUTATOR_HOOK(BuildMutatorsPrettyString, nades_BuildMutatorsPrettyString, CBC_ORDER_ANY);

	MUTATOR_ONADD
	{
		nades_Initialize();
	}

	return false;
}
