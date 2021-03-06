#ifdef REGISTER_WEAPON
REGISTER_WEAPON(
/* WEP_##id  */ MINE_LAYER,
/* function  */ W_MineLayer,
/* ammotype  */ ammo_rockets,
/* impulse   */ 4,
/* flags     */ WEP_FLAG_MUTATORBLOCKED | WEP_FLAG_RELOADABLE | WEP_TYPE_SPLASH,
/* rating    */ BOT_PICKUP_RATING_HIGH,
/* color     */ '0.75 1 0',
/* modelname */ "minelayer",
/* simplemdl */ "foobar",
/* crosshair */ "gfx/crosshairminelayer 0.9",
/* wepimg    */ "weaponminelayer",
/* refname   */ "minelayer",
/* wepname   */ _("Mine Layer")
);

#define MINELAYER_SETTINGS(w_cvar,w_prop) MINELAYER_SETTINGS_LIST(w_cvar, w_prop, MINE_LAYER, minelayer)
#define MINELAYER_SETTINGS_LIST(w_cvar,w_prop,id,sn) \
	w_cvar(id, sn, NONE, ammo) \
	w_cvar(id, sn, NONE, animtime) \
	w_cvar(id, sn, NONE, damage) \
	w_cvar(id, sn, NONE, damageforcescale) \
	w_cvar(id, sn, NONE, detonatedelay) \
	w_cvar(id, sn, NONE, edgedamage) \
	w_cvar(id, sn, NONE, force) \
	w_cvar(id, sn, NONE, health) \
	w_cvar(id, sn, NONE, lifetime) \
	w_cvar(id, sn, NONE, lifetime_countdown) \
	w_cvar(id, sn, NONE, limit) \
	w_cvar(id, sn, NONE, protection) \
	w_cvar(id, sn, NONE, proximityradius) \
	w_cvar(id, sn, NONE, radius) \
	w_cvar(id, sn, NONE, refire) \
	w_cvar(id, sn, NONE, remote_damage) \
	w_cvar(id, sn, NONE, remote_edgedamage) \
	w_cvar(id, sn, NONE, remote_force) \
	w_cvar(id, sn, NONE, remote_radius) \
	w_cvar(id, sn, NONE, speed) \
	w_cvar(id, sn, NONE, time) \
	w_prop(id, sn, float,  reloading_ammo, reload_ammo) \
	w_prop(id, sn, float,  reloading_time, reload_time) \
	w_prop(id, sn, float,  switchdelay_raise, switchdelay_raise) \
	w_prop(id, sn, float,  switchdelay_drop, switchdelay_drop) \
	w_prop(id, sn, string, weaponreplace, weaponreplace) \
	w_prop(id, sn, float,  weaponstart, weaponstart) \
	w_prop(id, sn, float,  weaponstartoverride, weaponstartoverride) \
	w_prop(id, sn, float,  weaponthrowable, weaponthrowable)

#ifdef SVQC
MINELAYER_SETTINGS(WEP_ADD_CVAR, WEP_ADD_PROP)
void W_MineLayer_Think(void);
.float minelayer_detonate, mine_explodeanyway;
.float mine_time;
.vector mine_orientation;
#endif
#else
#ifdef SVQC
#include "../effects.qh"

void spawnfunc_weapon_minelayer(void) { weapon_defaultspawnfunc(WEP_MINE_LAYER); }

void W_MineLayer_Stick(entity to)
{
	spamsound(self, CH_SHOTS, W_Sound("mine_stick"), VOL_BASE, ATTN_NORM);

	// in order for mines to face properly when sticking to the ground, they must be a server side entity rather than a csqc projectile

	entity newmine;
	newmine = spawn();
	newmine.classname = self.classname;

	newmine.bot_dodge = self.bot_dodge;
	newmine.bot_dodgerating = self.bot_dodgerating;

	newmine.owner = self.owner;
	newmine.realowner = self.realowner;
	setsize(newmine, '-4 -4 -4', '4 4 4');
	setorigin(newmine, self.origin);
	setmodel(newmine, "models/mine.md3");
	newmine.angles = vectoangles(-trace_plane_normal); // face against the surface

	newmine.mine_orientation = -trace_plane_normal;

	newmine.takedamage = self.takedamage;
	newmine.damageforcescale = self.damageforcescale;
	newmine.health = self.health;
	newmine.event_damage = self.event_damage;
	newmine.spawnshieldtime = self.spawnshieldtime;
	newmine.damagedbycontents = true;

	newmine.movetype = MOVETYPE_NONE; // lock the mine in place
	newmine.projectiledeathtype = self.projectiledeathtype;

	newmine.mine_time = self.mine_time;

	newmine.touch = func_null;
	newmine.think = W_MineLayer_Think;
	newmine.nextthink = time;
	newmine.cnt = self.cnt;
	newmine.flags = self.flags;

	remove(self);
	self = newmine;

	if(to)
		SetMovetypeFollow(self, to);
}

void W_MineLayer_Explode(void)
{
	if(other.takedamage == DAMAGE_AIM)
		if(IS_PLAYER(other))
			if(DIFF_TEAM(self.realowner, other))
				if(other.deadflag == DEAD_NO)
					if(IsFlying(other))
						Send_Notification(NOTIF_ONE, self.realowner, MSG_ANNCE, ANNCE_ACHIEVEMENT_AIRSHOT);

	self.event_damage = func_null;
	self.takedamage = DAMAGE_NO;

	RadiusDamage(self, self.realowner, WEP_CVAR(minelayer, damage), WEP_CVAR(minelayer, edgedamage), WEP_CVAR(minelayer, radius), world, world, WEP_CVAR(minelayer, force), self.projectiledeathtype, other);

	if(self.realowner.weapon == WEP_MINE_LAYER)
	{
		entity oldself;
		oldself = self;
		self = self.realowner;
		if(!WEP_ACTION(WEP_MINE_LAYER, WR_CHECKAMMO1))
		{
			self.cnt = WEP_MINE_LAYER;
			ATTACK_FINISHED(self) = time;
			self.switchweapon = w_getbestweapon(self);
		}
		self = oldself;
	}
	self.realowner.minelayer_mines -= 1;
	remove(self);
}

void W_MineLayer_DoRemoteExplode(void)
{
	self.event_damage = func_null;
	self.takedamage = DAMAGE_NO;

	if(self.movetype == MOVETYPE_NONE || self.movetype == MOVETYPE_FOLLOW)
		self.velocity = self.mine_orientation; // particle fx and decals need .velocity

	RadiusDamage(self, self.realowner, WEP_CVAR(minelayer, remote_damage), WEP_CVAR(minelayer, remote_edgedamage), WEP_CVAR(minelayer, remote_radius), world, world, WEP_CVAR(minelayer, remote_force), self.projectiledeathtype | HITTYPE_BOUNCE, world);

	if(self.realowner.weapon == WEP_MINE_LAYER)
	{
		entity oldself;
		oldself = self;
		self = self.realowner;
		if(!WEP_ACTION(WEP_MINE_LAYER, WR_CHECKAMMO1))
		{
			self.cnt = WEP_MINE_LAYER;
			ATTACK_FINISHED(self) = time;
			self.switchweapon = w_getbestweapon(self);
		}
		self = oldself;
	}
	self.realowner.minelayer_mines -= 1;
	remove(self);
}

void W_MineLayer_RemoteExplode(void)
{
	if(self.realowner.deadflag == DEAD_NO)
		if((self.spawnshieldtime >= 0)
			? (time >= self.spawnshieldtime) // timer
			: (vlen(NearestPointOnBox(self.realowner, self.origin) - self.origin) > WEP_CVAR(minelayer, remote_radius)) // safety device
		)
		{
			W_MineLayer_DoRemoteExplode();
		}
}

void W_MineLayer_ProximityExplode(void)
{
	// make sure no friend is in the mine's radius. If there is any, explosion is delayed until he's at a safe distance
	if(WEP_CVAR(minelayer, protection) && self.mine_explodeanyway == 0)
	{
		entity head;
		head = findradius(self.origin, WEP_CVAR(minelayer, radius));
		while(head)
		{
			if(head == self.realowner || SAME_TEAM(head, self.realowner))
				return;
			head = head.chain;
		}
	}

	self.mine_time = 0;
	W_MineLayer_Explode();
}

float W_MineLayer_Count(entity e)
{
	float minecount = 0;
	entity mine;
	for(mine = world; (mine = find(mine, classname, "mine")); ) if(mine.realowner == e)
		minecount += 1;

	return minecount;
}

void W_MineLayer_Think(void)
{
	entity head;

	self.nextthink = time;

	if(self.movetype == MOVETYPE_FOLLOW)
	{
		if(LostMovetypeFollow(self))
		{
			UnsetMovetypeFollow(self);
			self.movetype = MOVETYPE_NONE;
		}
	}

	// our lifetime has expired, it's time to die - mine_time just allows us to play a sound for this
	// TODO: replace this mine_trigger.wav sound with a real countdown
	if((time > self.cnt) && (!self.mine_time) && (self.cnt > 0))
	{
		if(WEP_CVAR(minelayer, lifetime_countdown) > 0)
			spamsound(self, CH_SHOTS, W_Sound("mine_trigger"), VOL_BASE, ATTN_NORM);
		self.mine_time = time + WEP_CVAR(minelayer, lifetime_countdown);
		self.mine_explodeanyway = 1; // make the mine super aggressive -- Samual: Rather, make it not care if a team mate is near.
	}

	// a player's mines shall explode if he disconnects or dies
	// TODO: Do this on team change too -- Samual: But isn't a player killed when they switch teams?
	if(!IS_PLAYER(self.realowner) || Player_Trapped(self.realowner))
	{
		other = world;
		self.projectiledeathtype |= HITTYPE_BOUNCE;
		W_MineLayer_Explode();
		return;
	}

	// set the mine for detonation when a foe gets close enough
	head = findradius(self.origin, WEP_CVAR(minelayer, proximityradius));
	while(head)
	{
		if(IS_PLAYER(head) && !Player_Trapped(head))
		if(head != self.realowner && DIFF_TEAM(head, self.realowner)) // don't trigger for team mates
		if(!self.mine_time)
		{
			spamsound(self, CH_SHOTS, W_Sound("mine_trigger"), VOL_BASE, ATTN_NORM);
			self.mine_time = time + WEP_CVAR(minelayer, time);
		}
		head = head.chain;
	}

	// explode if it's time to
	if(self.mine_time && time >= self.mine_time)
	{
		W_MineLayer_ProximityExplode();
		return;
	}

	// remote detonation
	if(self.realowner.weapon == WEP_MINE_LAYER)
	if(self.realowner.deadflag == DEAD_NO)
	if(self.minelayer_detonate)
		W_MineLayer_RemoteExplode();
}

void W_MineLayer_Touch(void)
{
	if(self.movetype == MOVETYPE_NONE || self.movetype == MOVETYPE_FOLLOW)
		return; // we're already a stuck mine, why do we get called? TODO does this even happen?

	if(WarpZone_Projectile_Touch())
	{
		if(wasfreed(self))
			self.realowner.minelayer_mines -= 1;
		return;
	}

	if(other && IS_PLAYER(other) && other.deadflag == DEAD_NO)
	{
		// hit a player
		// don't stick
	}
	else
	{
		W_MineLayer_Stick(other);
	}
}

void W_MineLayer_Damage(entity inflictor, entity attacker, float damage, float deathtype, vector hitloc, vector force)
{
	if(self.health <= 0)
		return;

	float is_from_enemy = (inflictor.realowner != self.realowner);

	if(!W_CheckProjectileDamage(inflictor.realowner, self.realowner, deathtype, (is_from_enemy ? 1 : -1)))
		return; // g_projectiles_damage says to halt

	self.health = self.health - damage;
	self.angles = vectoangles(self.velocity);

	if(self.health <= 0)
		W_PrepareExplosionByDamage(attacker, W_MineLayer_Explode);
}

void W_MineLayer_Attack(void)
{
	entity mine;
	entity flash;

	// scan how many mines we placed, and return if we reached our limit
	if(WEP_CVAR(minelayer, limit))
	{
		if(self.minelayer_mines >= WEP_CVAR(minelayer, limit))
		{
			// the refire delay keeps this message from being spammed
			Send_Notification(NOTIF_ONE, self, MSG_MULTI, WEAPON_MINELAYER_LIMIT, WEP_CVAR(minelayer, limit));
			play2(self, W_Sound("unavailable"));
			return;
		}
	}

	W_DecreaseAmmo(WEP_CVAR(minelayer, ammo));

	W_SetupShot_ProjectileSize(self, '-4 -4 -4', '4 4 4', false, 5, W_Sound("mine_fire"), CH_WEAPON_A, WEP_CVAR(minelayer, damage));
	Send_Effect(EFFECT_ROCKET_MUZZLEFLASH, w_shotorg, w_shotdir * 1000, 1);

	mine = WarpZone_RefSys_SpawnSameRefSys(self);
	mine.owner = mine.realowner = self;
	if(WEP_CVAR(minelayer, detonatedelay) >= 0)
		mine.spawnshieldtime = time + WEP_CVAR(minelayer, detonatedelay);
	else
		mine.spawnshieldtime = -1;
	mine.classname = "mine";
	mine.bot_dodge = true;
	mine.bot_dodgerating = WEP_CVAR(minelayer, damage) * 2; // * 2 because it can detonate inflight which makes it even more dangerous

	mine.takedamage = DAMAGE_YES;
	mine.damageforcescale = WEP_CVAR(minelayer, damageforcescale);
	mine.health = WEP_CVAR(minelayer, health);
	mine.event_damage = W_MineLayer_Damage;
	mine.damagedbycontents = true;

	mine.movetype = MOVETYPE_TOSS;
	PROJECTILE_MAKETRIGGER(mine);
	mine.projectiledeathtype = WEP_MINE_LAYER;
	setsize(mine, '-4 -4 -4', '4 4 4'); // give it some size so it can be shot

	setorigin(mine, w_shotorg - v_forward * 4); // move it back so it hits the wall at the right point
	W_SetupProjVelocity_Basic(mine, WEP_CVAR(minelayer, speed), 0);
	mine.angles = vectoangles(mine.velocity);

	mine.touch = W_MineLayer_Touch;
	mine.think = W_MineLayer_Think;
	mine.nextthink = time;
	mine.cnt = (WEP_CVAR(minelayer, lifetime) - WEP_CVAR(minelayer, lifetime_countdown));
	mine.flags = FL_PROJECTILE;
	mine.missile_flags = MIF_SPLASH | MIF_ARC | MIF_PROXY;

	if(mine.cnt > 0) { mine.cnt += time; }

	CSQCProjectile(mine, true, PROJECTILE_MINE, true);

	// muzzle flash for 1st person view
	flash = spawn();
	setmodel(flash, "models/flash.md3"); // precision set below
	SUB_SetFade(flash, time, 0.1);
	flash.effects = EF_ADDITIVE | EF_FULLBRIGHT | EF_LOWPRECISION;
	W_AttachToShotorg(flash, '5 0 0');

	// common properties

	other = mine; MUTATOR_CALLHOOK(EditProjectile);

	self.minelayer_mines = W_MineLayer_Count(self);
}

float W_MineLayer_PlacedMines(float detonate)
{
	entity mine;
	float minfound = 0;

	for(mine = world; (mine = find(mine, classname, "mine")); ) if(mine.realowner == self)
	{
		if(detonate)
		{
			if(!mine.minelayer_detonate)
			{
				mine.minelayer_detonate = true;
				minfound = 1;
			}
		}
		else
			minfound = 1;
	}
	return minfound;
}

float W_MineLayer(float req)
{
	entity mine;
	float ammo_amount;
	switch(req)
	{
		case WR_AIM:
		{
			// aim and decide to fire if appropriate
			if(self.minelayer_mines >= WEP_CVAR(minelayer, limit))
				self.BUTTON_ATCK = false;
			else
				self.BUTTON_ATCK = bot_aim(WEP_CVAR(minelayer, speed), 0, WEP_CVAR(minelayer, lifetime), false);
			if(bot_skill >= 2) // skill 0 and 1 bots won't detonate mines!
			{
				// decide whether to detonate mines
				entity targetlist, targ;
				float edgedamage, coredamage, edgeradius, recipricoledgeradius, d;
				float selfdamage, teamdamage, enemydamage;
				edgedamage = WEP_CVAR(minelayer, edgedamage);
				coredamage = WEP_CVAR(minelayer, damage);
				edgeradius = WEP_CVAR(minelayer, radius);
				recipricoledgeradius = 1 / edgeradius;
				selfdamage = 0;
				teamdamage = 0;
				enemydamage = 0;
				targetlist = findchainfloat(bot_attack, true);
				mine = find(world, classname, "mine");
				while(mine)
				{
					if(mine.realowner != self)
					{
						mine = find(mine, classname, "mine");
						continue;
					}
					targ = targetlist;
					while(targ)
					{
						d = vlen(targ.origin + (targ.mins + targ.maxs) * 0.5 - mine.origin);
						d = bound(0, edgedamage + (coredamage - edgedamage) * sqrt(1 - d * recipricoledgeradius), 10000);
						// count potential damage according to type of target
						if(targ == self)
							selfdamage = selfdamage + d;
						else if(targ.team == self.team && teamplay)
							teamdamage = teamdamage + d;
						else if(bot_shouldattack(targ))
							enemydamage = enemydamage + d;
						targ = targ.chain;
					}
					mine = find(mine, classname, "mine");
				}
				float desirabledamage;
				desirabledamage = enemydamage;
				if(time > self.invincible_finished && time > self.spawnshieldtime)
					desirabledamage = desirabledamage - selfdamage * autocvar_g_balance_selfdamagepercent;
				if(teamplay && self.team)
					desirabledamage = desirabledamage - teamdamage;

				mine = find(world, classname, "mine");
				while(mine)
				{
					if(mine.realowner != self)
					{
						mine = find(mine, classname, "mine");
						continue;
					}
					makevectors(mine.v_angle);
					targ = targetlist;
					if(bot_skill > 9) // normal players only do this for the target they are tracking
					{
						targ = targetlist;
						while(targ)
						{
							if(
								(v_forward * normalize(mine.origin - targ.origin)< 0.1)
								&& desirabledamage > 0.1*coredamage
							)self.BUTTON_ATCK2 = true;
							targ = targ.chain;
						}
					}else{
						float distance; distance= bound(300,vlen(self.origin-self.enemy.origin),30000);
						//As the distance gets larger, a correct detonation gets near imposible
						//Bots are assumed to use the mine spawnfunc_light to see if the mine gets near a player
						if(v_forward * normalize(mine.origin - self.enemy.origin)< 0.1)
							if(IS_PLAYER(self.enemy))
								if(desirabledamage >= 0.1*coredamage)
									if(random()/distance*300 > frametime*bound(0,(10-bot_skill)*0.2,1))
										self.BUTTON_ATCK2 = true;
					//	dprint(ftos(random()/distance*300),">");dprint(ftos(frametime*bound(0,(10-skill)*0.2,1)),"\n");
					}

					mine = find(mine, classname, "mine");
				}
				// if we would be doing at X percent of the core damage, detonate it
				// but don't fire a new shot at the same time!
				if(desirabledamage >= 0.75 * coredamage) //this should do group damage in rare fortunate events
					self.BUTTON_ATCK2 = true;
				if((bot_skill > 6.5) && (selfdamage > self.health))
					self.BUTTON_ATCK2 = false;
				//if(self.BUTTON_ATCK2 == true)
				//	dprint(ftos(desirabledamage),"\n");
				if(self.BUTTON_ATCK2 == true) self.BUTTON_ATCK = false;
			}

			return true;
		}
		case WR_THINK:
		{
			if(autocvar_g_balance_minelayer_reload_ammo && self.clip_load < WEP_CVAR(minelayer, ammo)) // forced reload
			{
				// not if we're holding the minelayer without enough ammo, but can detonate existing mines
				if(!(W_MineLayer_PlacedMines(false) && self.WEP_AMMO(MINE_LAYER) < WEP_CVAR(minelayer, ammo)))
					WEP_ACTION(self.weapon, WR_RELOAD);
			}
			else if(self.BUTTON_ATCK)
			{
				if(weapon_prepareattack(0, WEP_CVAR(minelayer, refire)))
				{
					W_MineLayer_Attack();
					weapon_thinkf(WFRAME_FIRE1, WEP_CVAR(minelayer, animtime), w_ready);
				}
			}

			if(self.BUTTON_ATCK2)
			{
				if(W_MineLayer_PlacedMines(true))
					sound(self, CH_WEAPON_B, W_Sound("mine_det"), VOL_BASE, ATTN_NORM);
			}

			return true;
		}
		case WR_INIT:
		{
			precache_model("models/flash.md3");
			precache_model("models/mine.md3");
			precache_model(W_Model("g_minelayer.md3"));
			precache_model(W_Model("v_minelayer.md3"));
			precache_model(W_Model("h_minelayer.iqm"));
			precache_sound(W_Sound("mine_det"));
			precache_sound(W_Sound("mine_fire"));
			precache_sound(W_Sound("mine_stick"));
			precache_sound(W_Sound("mine_trigger"));
			MINELAYER_SETTINGS(WEP_SKIP_CVAR, WEP_SET_PROP)
			return true;
		}
		case WR_CHECKAMMO1:
		{
			// don't switch while placing a mine
			if(ATTACK_FINISHED(self) <= time || self.weapon != WEP_MINE_LAYER)
			{
				ammo_amount = self.WEP_AMMO(MINE_LAYER) >= WEP_CVAR(minelayer, ammo);
				ammo_amount += self.(weapon_load[WEP_MINE_LAYER]) >= WEP_CVAR(minelayer, ammo);
				return ammo_amount;
			}
			return true;
		}
		case WR_CHECKAMMO2:
		{
			if(W_MineLayer_PlacedMines(false))
				return true;
			else
				return false;
		}
		case WR_CONFIG:
		{
			MINELAYER_SETTINGS(WEP_CONFIG_WRITE_CVARS, WEP_CONFIG_WRITE_PROPS);
			return true;
		}
		case WR_RESETPLAYER:
		{
			self.minelayer_mines = 0;
			return true;
		}
		case WR_RELOAD:
		{
			W_Reload(WEP_CVAR(minelayer, ammo), W_Sound("reload"));
			return true;
		}
		case WR_SUICIDEMESSAGE:
		{
			return WEAPON_MINELAYER_SUICIDE;
		}
		case WR_KILLMESSAGE:
		{
			return WEAPON_MINELAYER_MURDER;
		}
	}
	return false;
}
#endif
#ifdef CSQC
float W_MineLayer(float req)
{
	switch(req)
	{
		case WR_IMPACTEFFECT:
		{
			vector org2;
			org2 = w_org + w_backoff * 12;
			pointparticles(particleeffectnum("rocket_explode"), org2, '0 0 0', 1);
			if(!w_issilent)
				sound(self, CH_SHOTS, "weapons/mine_exp.wav", VOL_BASE, ATTN_NORM);

			return true;
		}
		case WR_INIT:
		{
			precache_sound("weapons/mine_exp.wav");
			return true;
		}
		case WR_ZOOMRETICLE:
		{
			// no weapon specific image for this weapon
			return false;
		}
	}
	return false;
}
#endif
#endif
