#ifdef REGISTER_TURRET
REGISTER_TURRET(
/* TUR_##id   */ PLASMA,
/* function   */ t_plasma,
/* spawnflags */ TUR_FLAG_SPLASH | TUR_FLAG_MEDPROJ | TUR_FLAG_PLAYER,
/* mins,maxs  */ '-32 -32 0', '32 32 64',
/* model	  */ "base.md3",
/* head_model */ "plasma.md3",
/* netname	  */ "plasma",
/* fullname   */ _("Plasma Cannon")
);
#else
#ifdef SVQC
#include "../../effects.qh"

void spawnfunc_turret_plasma() { if(!turret_initialize(TUR_PLASMA)) remove(self); }

float t_plasma(float req)
{
	switch(req)
	{
		case TR_ATTACK:
		{
			if(g_instagib)
			{
				float flying;
				flying = IsFlying(self); // do this BEFORE to make the trace values from FireRailgunBullet last

				FireRailgunBullet (self.tur_shotorg, self.tur_shotorg + self.tur_shotdir_updated * MAX_SHOT_DISTANCE, 10000000000,
								   800, 0, 0, 0, 0, DEATH_TURRET_PLASMA);

				Send_Effect(EFFECT_VORTEX_MUZZLEFLASH, self.tur_shotorg, self.tur_shotdir_updated * 1000, 1);

				// teamcolor / hit beam effect
				vector v;
				float f;
				v = WarpZone_UnTransformOrigin(WarpZone_trace_transform, trace_endpos);
				switch(self.team)
				{
					case NUM_TEAM_1: f = (damage_goodhits) ? EFFECT_VAPORIZER_RED_HIT : EFFECT_VAPORIZER_RED; break;
					case NUM_TEAM_2: f = (damage_goodhits) ? EFFECT_VAPORIZER_BLUE_HIT : EFFECT_VAPORIZER_BLUE; break;
					case NUM_TEAM_3: f = (damage_goodhits) ? EFFECT_VAPORIZER_YELLOW_HIT : EFFECT_VAPORIZER_YELLOW; break;
					case NUM_TEAM_4: f = (damage_goodhits) ? EFFECT_VAPORIZER_PINK_HIT : EFFECT_VAPORIZER_PINK; break;
					default:		 f = (damage_goodhits) ? EFFECT_VAPORIZER_NEUTRAL_HIT : EFFECT_VAPORIZER_NEUTRAL; break;
				}
				
				Send_Effect(f, self.tur_shotorg, v, 0);
				
				if (self.tur_head.frame == 0)
					self.tur_head.frame = 1;
			}
			else
			{
				entity missile = turret_projectile(W_Sound("hagar_fire"), 1, 0, DEATH_TURRET_PLASMA, PROJECTILE_ELECTRO_BEAM, true, true);
				missile.missile_flags = MIF_SPLASH;

				Send_Effect(EFFECT_LASER_MUZZLEFLASH, self.tur_shotorg, self.tur_shotdir_updated * 1000, 1);
				if (self.tur_head.frame == 0)
					self.tur_head.frame = 1;
			}

			return true;
		}
		case TR_THINK:
		{
			if (self.tur_head.frame != 0)
				self.tur_head.frame = self.tur_head.frame + 1;

			if (self.tur_head.frame > 5)
				self.tur_head.frame = 0;

			return true;
		}
		case TR_DEATH:
		{
			return true;
		}
		case TR_SETUP:
		{
			self.ammo_flags = TFL_AMMO_ENERGY | TFL_AMMO_RECHARGE | TFL_AMMO_RECIEVE;
			self.damage_flags |= TFL_DMG_HEADSHAKE;
			self.firecheck_flags |= TFL_FIRECHECK_AFF;
			self.aim_flags = TFL_AIM_LEAD | TFL_AIM_SHOTTIMECOMPENSATE | TFL_AIM_SPLASH;
			
			turret_do_updates(self);

			return true;
		}
		case TR_PRECACHE:
		{
			precache_model ("models/turrets/base.md3");
			precache_model ("models/turrets/plasma.md3");
			return true;
		}
	}

	return true;
}

#endif // SVQC
#ifdef CSQC
float t_plasma(float req)
{
	switch(req)
	{
		case TR_SETUP:
		{
			return true;
		}
		case TR_PRECACHE:
		{
			return true;
		}
	}

	return true;
}

#endif // CSQC
#endif // REGISTER_TURRET
