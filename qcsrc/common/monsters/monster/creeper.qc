#ifdef REGISTER_MONSTER
REGISTER_MONSTER(
/* MON_##id   */ CREEPER,
/* functions  */ M_Creeper, M_Creeper_Attack,
/* spawnflags */ MON_FLAG_MELEE | MON_FLAG_RIDE,
/* mins,maxs  */ '-18 -18 -25', '18 18 40',
/* model      */ "creeper.dpm",
/* netname    */ "creeper",
/* fullname   */ _("Creeper")
);

#else
#ifdef SVQC
float autocvar_g_monster_creeper_health;
var float autocvar_g_monster_creeper_damageforcescale = 0.0001; // hehehe
float autocvar_g_monster_creeper_attack_explode_damage;
float autocvar_g_monster_creeper_attack_explode_edgedamage;
float autocvar_g_monster_creeper_attack_explode_radius;
float autocvar_g_monster_creeper_attack_explode_force;
float autocvar_g_monster_creeper_attack_explode_prime_delay;
float autocvar_g_monster_creeper_speed_stop;
float autocvar_g_monster_creeper_speed_walk;
float autocvar_g_monster_creeper_speed_run;

const float creeper_anim_idle = 0;
const float creeper_anim_walk = 1;
const float creeper_anim_die = 2;

.float creeper_primed;

float M_Creeper_Attack(float attack_type)
{
	switch(attack_type)
	{
		case MONSTER_ATTACK_MELEE:
		{
			if(self.creeper_primed)
			{
				pointparticles(particleeffectnum("explosion_medium"), self.origin, '0 0 0', 1);
				sound(self, CH_SHOTS, W_Sound("rocket_impact"), VOL_BASE, ATTEN_NORM);

				RadiusDamage (self, self, (autocvar_g_monster_creeper_attack_explode_damage), (autocvar_g_monster_creeper_attack_explode_edgedamage), (autocvar_g_monster_creeper_attack_explode_radius), world, world, (autocvar_g_monster_creeper_attack_explode_force), DEATH_MONSTER_CREEPER, other);

				//Monster_Sound(monstersound_attack, 0, false, CH_SHOTS);
				Damage (self, world, world, self.health + self.max_health + 200, DEATH_KILL, self.origin, '0 0 0'); // killing monster should be reliable enough
				self.event_damage = func_null;
				self.frame = creeper_anim_idle;
			}
			else
			{
				Monster_Sound(monstersound_ranged, 0, false, CH_VOICE);
				self.creeper_primed = true;

				self.colormod = '1 0 0';
				self.frame = creeper_anim_idle;
				self.velocity_x = 0;
				self.velocity_y = 0;
				self.state = MONSTER_ATTACK_MELEE;
				self.attack_finished_single = time + (autocvar_g_monster_creeper_attack_explode_prime_delay);
			}
			return true;
		}
		case MONSTER_ATTACK_RANGED:
		{
			// creeper has no ranged attacks
			return false;
		}
	}

	return false;
}

void spawnfunc_monster_creeper() { Monster_Spawn(MON_CREEPER); }

float M_Creeper(float req)
{
	switch(req)
	{
		case MR_THINK:
		{
			if(self.creeper_primed)
			if(vlen(self.origin - self.enemy.origin) >= self.attack_range * 2)
				self.creeper_primed = false;
			if(self.health > 0 && time > self.attack_finished_single) { self.colormod = '1 1 1'; }
			return true;
		}
		case MR_PAIN:
		{
			return true;
		}
		case MR_DEATH:
		{
			self.frame = creeper_anim_die;
			return true;
		}
		case MR_SETUP:
		{
			if(!self.health) self.health = (autocvar_g_monster_creeper_health);
			if(!self.wander_delay) self.wander_delay = 10;
			if(!self.wander_distance) self.wander_distance = 200;
			if(!self.speed) { self.speed = (autocvar_g_monster_creeper_speed_walk); }
			if(!self.speed2) { self.speed2 = (autocvar_g_monster_creeper_speed_run); }
			if(!self.stopspeed) { self.stopspeed = (autocvar_g_monster_creeper_speed_stop); }
			if(!self.damageforcescale) { self.damageforcescale = (autocvar_g_monster_creeper_damageforcescale); }

			self.m_anim_walk = creeper_anim_walk;
			self.m_anim_run = creeper_anim_walk;
			self.m_anim_idle = creeper_anim_idle;
			self.monster_loot = spawnfunc_ammo_rockets;
			self.frame = creeper_anim_idle;
			self.colormod = '1 1 1';

			return true;
		}
		case MR_PRECACHE:
		{
			return true;
		}
	}

	return true;
}

#endif // SVQC
#endif // REGISTER_MONSTER
