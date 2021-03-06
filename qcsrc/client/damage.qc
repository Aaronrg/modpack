#if defined(CSQC)
	#include "../dpdefs/csprogsdefs.qh"
	#include "defs.qh"
	#include "../common/constants.qh"
	#include "../common/util.qh"
	#include "../common/weapons/weapons.qh"
	#include "autocvars.qh"
	#include "../common/deathtypes.qh"
	#include "damage.qh"
	#include "movetypes.qh"
	#include "prandom.qh"
	#include "../common/vehicles/cl_vehicles.qh"
#elif defined(MENUQC)
#elif defined(SVQC)
#endif

void DamageEffect_Think()
{
	// if particle distribution is enabled, slow ticrate by total number of damages
	if(autocvar_cl_damageeffect_distribute)
		self.nextthink = time + autocvar_cl_damageeffect_ticrate * self.owner.total_damages;
	else
		self.nextthink = time + autocvar_cl_damageeffect_ticrate;

	if(time >= self.cnt || !self.owner || !self.owner.modelindex || !self.owner.drawmask)
	{
		// time is up or the player got gibbed / disconnected
		self.owner.total_damages = max(0, self.owner.total_damages - 1);
		remove(self);
		return;
	}
	if(self.state && !self.owner.csqcmodel_isdead)
	{
		// if the player was dead but is now alive, it means he respawned
		// if so, clear his damage effects, or damages from his dead body will be copied back
		self.owner.total_damages = max(0, self.owner.total_damages - 1);
		remove(self);
		return;
	}
	self.state = self.owner.csqcmodel_isdead;
	if(self.owner.isplayermodel && (self.owner.entnum == player_localentnum) && !autocvar_chase_active)
		return; // if we aren't using a third person camera, hide our own effects

	// now generate the particles
	vector org;
	org = gettaginfo(self, 0); // origin at attached location
	pointparticles(self.team, org, '0 0 0', 1);
}

void DamageEffect(vector hitorg, float dmg, int type, int specnum)
{
	// particle effects for players and objects damaged by weapons (eg: flames coming out of victims shot with rockets)

	int nearestbone = 0;
	float life;
	string specstr, effectname;
	entity e;

	if(!autocvar_cl_damageeffect || autocvar_cl_gentle || autocvar_cl_gentle_damage)
		return;
	if(!self || !self.modelindex || !self.drawmask)
		return;

	// if this is a rigged mesh, the effect will show on the bone where damage was dealt
	// we do this by choosing the skeletal bone closest to the impact, and attaching our entity to it
	// if there's no skeleton, object origin will automatically be selected
	FOR_EACH_TAG(self)
	{
		if(!tagnum)
			continue; // skip empty bones
		// blacklist bones positioned outside the mesh, or the effect will be floating
		// TODO: Do we have to do it this way? Why do these bones exist at all?
		if(gettaginfo_name == "master" || gettaginfo_name == "knee_L" || gettaginfo_name == "knee_R" || gettaginfo_name == "leg_L" || gettaginfo_name == "leg_R")
			continue; // player model bone blacklist

		// now choose the bone closest to impact origin
		if(nearestbone == 0 || vlen(hitorg - gettaginfo(self, tagnum)) <= vlen(hitorg - gettaginfo(self, nearestbone)))
			nearestbone = tagnum;
	}
	gettaginfo(self, nearestbone); // set gettaginfo_name

	// return if we reached our damage effect limit or damages are disabled
	// TODO: When the limit is reached, it would be better if the oldest damage was removed instead of not adding a new one
	if(nearestbone)
	{
		if(self.total_damages >= autocvar_cl_damageeffect_bones)
			return; // allow multiple damages on skeletal models
	}
	else
	{
		if(autocvar_cl_damageeffect < 2 || self.total_damages)
			return; // allow a single damage on non-skeletal models
	}

	life = bound(autocvar_cl_damageeffect_lifetime_min, dmg * autocvar_cl_damageeffect_lifetime, autocvar_cl_damageeffect_lifetime_max);

	effectname = get_weaponinfo(DEATH_WEAPONOF(type)).netname;

	if(substring(effectname, strlen(effectname) - 5, 5) == "BLOOD")
	{
		if(self.isplayermodel)
		{
			specstr = species_prefix(specnum);
			specstr = substring(specstr, 0, strlen(specstr) - 1);
			effectname = strreplace("BLOOD", specstr, effectname);
		}
		else { return; } // objects don't bleed
	}

	e = spawn();
	setmodel(e, "null"); // necessary to attach and read origin
	setattachment(e, self, gettaginfo_name); // attach to the given bone
	e.classname = "damage";
	e.owner = self;
	e.cnt = time + life;
	e.team = particleeffectnum(effectname);
	e.think = DamageEffect_Think;
	e.nextthink = time;
	self.total_damages += 1;
}

void Ent_DamageInfo(float isNew)
{
	float dmg, rad, edge, thisdmg;
	bool hitplayer = false;
	int species, forcemul;
	vector force, thisforce;
	entity oldself;

	oldself = self;

	w_deathtype = ReadShort();
	w_issilent = (w_deathtype & 0x8000);
	w_deathtype = (w_deathtype & 0x7FFF);

	w_org.x = ReadCoord();
	w_org.y = ReadCoord();
	w_org.z = ReadCoord();

	dmg = ReadByte();
	rad = ReadByte();
	edge = ReadByte();
	force = decompressShortVector(ReadShort());
	species = ReadByte();

	if (!isNew)
		return;

	if(rad < 0)
	{
		rad = -rad;
		forcemul = -1;
	}
	else
		forcemul = 1;

	for(self = findradius(w_org, rad + MAX_DAMAGEEXTRARADIUS); self; self = self.chain)
	{
		// attached ents suck
		if(self.tag_entity)
			continue;

		vector nearest = NearestPointOnBox(self, w_org);
		if(rad)
		{
			thisdmg = ((vlen (nearest - w_org) - bound(MIN_DAMAGEEXTRARADIUS, self.damageextraradius, MAX_DAMAGEEXTRARADIUS)) / rad);
			if(thisdmg >= 1)
				continue;
			if(thisdmg < 0)
				thisdmg = 0;
			if(dmg)
			{
				thisdmg = dmg + (edge - dmg) * thisdmg;
				thisforce = forcemul * vlen(force) * (thisdmg / dmg) * normalize(self.origin - w_org);
			}
			else
			{
				thisdmg = 0;
				thisforce = forcemul * vlen(force) * normalize(self.origin - w_org);
			}
		}
		else
		{
			if(vlen(nearest - w_org) > bound(MIN_DAMAGEEXTRARADIUS, self.damageextraradius, MAX_DAMAGEEXTRARADIUS))
				continue;

			thisdmg = dmg;
			thisforce = forcemul * force;
		}

		if(self.damageforcescale)
			if(vlen(thisforce))
			{
				self.move_velocity = self.move_velocity + damage_explosion_calcpush(self.damageforcescale * thisforce, self.move_velocity, autocvar_g_balance_damagepush_speedfactor);
				self.move_flags &= ~FL_ONGROUND;
			}

		if(w_issilent)
			self.silent = 1;

		if(self.event_damage)
			self.event_damage(thisdmg, w_deathtype, w_org, thisforce);

		DamageEffect(w_org, thisdmg, w_deathtype, species);

		if(self.isplayermodel)
			hitplayer = true; // this impact damaged a player
	}

	self = oldself;

	if(DEATH_ISVEHICLE(w_deathtype))
	{
		traceline(w_org - normalize(force) * 16, w_org + normalize(force) * 16, MOVE_NOMONSTERS, world);
		if(trace_plane_normal != '0 0 0')
			w_backoff = trace_plane_normal;
		else
			w_backoff = -1 * normalize(w_org - (w_org + normalize(force) * 16));

		setorigin(self, w_org + w_backoff * 2); // for sound() calls

		switch(w_deathtype)
		{
			case DEATH_VH_CRUSH:
				break;

			// spiderbot
			case DEATH_VH_SPID_MINIGUN:
				string _snd;
				_snd = strcat("weapons/ric", ftos(1 + rint(random() * 2)), ".waw");
				sound(self, CH_SHOTS, _snd, VOL_BASE, ATTEN_NORM);
				pointparticles(particleeffectnum("spiderbot_minigun_impact"), self.origin, w_backoff * 1000, 1);
				break;
			case DEATH_VH_SPID_ROCKET:
				sound(self, CH_SHOTS, "weapons/rocket_impact.wav", VOL_BASE, ATTEN_NORM);
				pointparticles(particleeffectnum("spiderbot_rocket_explode"), self.origin, w_backoff * 1000, 1);
				break;
			case DEATH_VH_SPID_DEATH:
				sound(self, CH_SHOTS, "weapons/rocket_impact.wav", VOL_BASE, ATTEN_MIN);
				pointparticles(particleeffectnum("explosion_big"), self.origin, w_backoff * 1000, 1);
				break;

			case DEATH_VH_WAKI_GUN:
				sound(self, CH_SHOTS, "weapons/laserimpact.wav", VOL_BASE, ATTEN_NORM);
				pointparticles(particleeffectnum("wakizashi_gun_impact"), self.origin, w_backoff * 1000, 1);
				break;
			case DEATH_VH_WAKI_ROCKET:
				sound(self, CH_SHOTS, "weapons/rocket_impact.wav", VOL_BASE, ATTEN_NORM);
				pointparticles(particleeffectnum("wakizashi_rocket_explode"), self.origin, w_backoff * 1000, 1);
				break;
			case DEATH_VH_WAKI_DEATH:
				sound(self, CH_SHOTS, "weapons/rocket_impact.wav", VOL_BASE, ATTEN_MIN);
				pointparticles(particleeffectnum("explosion_big"), self.origin, w_backoff * 1000, 1);
				break;
			case DEATH_VH_TANK_DEATH:
			case DEATH_VH_TANKLL48:
				sound(self, CH_SHOTS, "weapons/rocket_impact.wav", VOL_BASE, ATTEN_MIN);
				pointparticles(particleeffectnum("explosion_big"), self.origin, w_backoff * 1000, 1);
				break;

			case DEATH_VH_RAPT_CANNON:
				sound(self, CH_SHOTS, "weapons/laserimpact.wav", VOL_BASE, ATTEN_NORM);
				pointparticles(particleeffectnum("raptor_cannon_impact"), self.origin, w_backoff * 1000, 1);
				break;
			case DEATH_VH_RAPT_FRAGMENT:
				float i;
				vector ang, vel;
				for(i = 1; i < 4; ++i)
				{
					vel = normalize(w_org - (w_org + normalize(force) * 16)) + randomvec() * 128;
					ang = vectoangles(vel);
					RaptorCBShellfragToss(w_org, vel, ang + '0 0 1' * (120 * i));
				}
				sound(self, CH_SHOTS, "weapons/rocket_impact.wav", VOL_BASE, ATTEN_NORM);
				pointparticles(particleeffectnum("raptor_bomb_spread"), self.origin, w_backoff * 1000, 1);
				break;
			case DEATH_VH_RAPT_BOMB:
				sound(self, CH_SHOTS, "weapons/rocket_impact.wav", VOL_BASE, ATTEN_NORM);
				pointparticles(particleeffectnum("raptor_bomb_impact"), self.origin, w_backoff * 1000, 1);
				break;
			case DEATH_VH_RAPT_DEATH:
				sound(self, CH_SHOTS, "weapons/laserimpact.wav", VOL_BASE, ATTEN_MIN);
				pointparticles(particleeffectnum("explosion_big"), self.origin, w_backoff * 1000, 1);
				break;
			case DEATH_VH_BUMB_GUN:
				sound(self, CH_SHOTS, "weapons/fireball_impact2.wav", VOL_BASE, ATTEN_NORM);
				pointparticles(particleeffectnum("bigplasma_impact"), self.origin, w_backoff * 1000, 1);
				break;
		}
	}


	if(DEATH_ISTURRET(w_deathtype))
	{
		string _snd;
		traceline(w_org - normalize(force) * 16, w_org + normalize(force) * 16, MOVE_NOMONSTERS, world);
		if(trace_plane_normal != '0 0 0')
			w_backoff = trace_plane_normal;
		else
			w_backoff = -1 * normalize(w_org - (w_org + normalize(force) * 16));

		setorigin(self, w_org + w_backoff * 2); // for sound() calls

		switch(w_deathtype)
		{
			 case DEATH_TURRET_EWHEEL:
				sound(self, CH_SHOTS, "weapons/laserimpact.wav", VOL_BASE, ATTEN_MIN);
				pointparticles(particleeffectnum("laser_impact"), self.origin, w_backoff * 1000, 1);
				break;

			 case DEATH_TURRET_FLAC:
				pointparticles(particleeffectnum("hagar_explode"), w_org, '0 0 0', 1);
				_snd = strcat("weapons/hagexp", ftos(1 + rint(random() * 2)), ".waw");
				sound(self, CH_SHOTS, _snd, VOL_BASE, ATTEN_NORM);
				break;

			 case DEATH_TURRET_MLRS:
			 case DEATH_TURRET_HK:
			 case DEATH_TURRET_WALK_ROCKET:
			 case DEATH_TURRET_HELLION:
				sound(self, CH_SHOTS, "weapons/rocket_impact.wav", VOL_BASE, ATTEN_MIN);
				pointparticles(particleeffectnum("rocket_explode"), self.origin, w_backoff * 1000, 1);
				break;

			 case DEATH_TURRET_MACHINEGUN:
			 case DEATH_TURRET_WALK_GUN:
				_snd = strcat("weapons/ric", ftos(1 + rint(random() * 2)), ".waw");
				sound(self, CH_SHOTS, _snd, VOL_BASE, ATTEN_NORM);
				pointparticles(particleeffectnum("machinegun_impact"), self.origin, w_backoff * 1000, 1);
				break;

			 case DEATH_TURRET_PLASMA:
				sound(self, CH_SHOTS, "weapons/electro_impact.wav", VOL_BASE, ATTEN_MIN);
				pointparticles(particleeffectnum("electro_impact"), self.origin, w_backoff * 1000, 1);
				break;

			 case DEATH_TURRET_WALK_MELEE:
				sound(self, CH_SHOTS, "weapons/ric1.wav", VOL_BASE, ATTEN_MIN);
				pointparticles(particleeffectnum("TE_SPARK"), self.origin, w_backoff * 1000, 1);
				break;

			 case DEATH_TURRET_PHASER:
				break;

			 case DEATH_TURRET_TESLA:
				te_smallflash(self.origin);
				break;

		}
	}

	// TODO spawn particle effects and sounds based on w_deathtype
	if(!DEATH_ISSPECIAL(w_deathtype))
	if(!hitplayer || rad) // don't show ground impacts for hitscan weapons if a player was hit
	{
		int hitwep = DEATH_WEAPONOFWEAPONDEATH(w_deathtype);
		w_random = prandom();

		traceline(w_org - normalize(force) * 16, w_org + normalize(force) * 16, MOVE_NOMONSTERS, world);
		if(trace_fraction < 1 && hitwep != WEP_VORTEX && hitwep != WEP_VAPORIZER)
			w_backoff = trace_plane_normal;
		else
			w_backoff = -1 * normalize(force);
		setorigin(self, w_org + w_backoff * 2); // for sound() calls

		if(!(trace_dphitq3surfaceflags & Q3SURFACEFLAG_SKY)) { WEP_ACTION(hitwep, WR_IMPACTEFFECT); }
	}
}
