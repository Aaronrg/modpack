#ifdef REGISTER_MONSTER
REGISTER_MONSTER(
/* MON_##id   */ ROTTWEILER,
/* functions  */ M_Rottweiler, M_Rottweiler_Attack,
/* spawnflags */ MON_FLAG_MELEE | MONSTER_SIZE_BROKEN | MON_FLAG_RIDE,
/* mins,maxs  */ '-16 -16 -24', '16 16 12',
/* model      */ "dog.mdl",
/* netname    */ "rottweiler",
/* fullname   */ _("Rottweiler")
);

#else
#ifdef SVQC
float autocvar_g_monster_rottweiler_health;
var float autocvar_g_monster_rottweiler_damageforcescale = 0.7;
float autocvar_g_monster_rottweiler_attack_melee_damage;
float autocvar_g_monster_rottweiler_attack_melee_delay;
float autocvar_g_monster_rottweiler_speed_stop;
float autocvar_g_monster_rottweiler_speed_run;
float autocvar_g_monster_rottweiler_speed_walk;

const float rottweiler_anim_attack1		= 0;
const float rottweiler_anim_death1		= 1;
const float rottweiler_anim_death2		= 2;
const float rottweiler_anim_attack2		= 3;
const float rottweiler_anim_pain		= 4;
const float rottweiler_anim_run			= 5;
const float rottweiler_anim_leap		= 6;
const float rottweiler_anim_idle		= 7;
const float rottweiler_anim_walk		= 8;

float M_Rottweiler_Attack(float attack_type)
{
	switch(attack_type)
	{
		case MONSTER_ATTACK_MELEE:
		{
			return Monster_Attack_Melee(self.enemy, (autocvar_g_monster_rottweiler_attack_melee_damage), ((random() >= 0.5) ? rottweiler_anim_attack1 : rottweiler_anim_attack2), self.attack_range, (autocvar_g_monster_rottweiler_attack_melee_delay), DEATH_MONSTER_ROTTWEILER, true);
		}
		case MONSTER_ATTACK_RANGED:
		{
			// rottweiler has no ranged attack yet!
			return false;
		}
	}

	return false;
}

void spawnfunc_monster_rottweiler() { Monster_Spawn(MON_ROTTWEILER); }

float M_Rottweiler(float req)
{
	switch(req)
	{
		case MR_THINK:
		{
			return true;
		}
		case MR_PAIN:
		{
			if(random() <= 0.3)
			{
				self.pain_finished = time + 1.5;
				self.frame = rottweiler_anim_pain;
			}
			return true;
		}
		case MR_DEATH:
		{
			self.frame = (random() >= 0.5) ? rottweiler_anim_death1 : rottweiler_anim_death2;
			return true;
		}
		case MR_SETUP:
		{
			if(!self.health) self.health = (autocvar_g_monster_rottweiler_health);
			if(!self.speed) { self.speed = (autocvar_g_monster_rottweiler_speed_walk); }
			if(!self.speed2) { self.speed2 = (autocvar_g_monster_rottweiler_speed_run); }
			if(!self.stopspeed) { self.stopspeed = (autocvar_g_monster_rottweiler_speed_stop); }
			if(!self.damageforcescale) { self.damageforcescale = (autocvar_g_monster_rottweiler_damageforcescale); }

			self.m_anim_walk = rottweiler_anim_walk;
			self.m_anim_run = rottweiler_anim_run;
			self.m_anim_idle = rottweiler_anim_idle;

			self.monster_loot = spawnfunc_item_health_small;
			self.frame = rottweiler_anim_idle;

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
