#ifdef REGISTER_TURRET
REGISTER_TURRET(
/* TUR_##id   */ MACHINEGUN,
/* function   */ t_machinegun,
/* spawnflags */ TUR_FLAG_PLAYER,
/* mins,maxs  */ '-32 -32 0', '32 32 64',
/* model	  */ "base.md3",
/* head_model */ "machinegun.md3",
/* netname	  */ "machinegun",
/* fullname   */ _("Machinegun Turret")
);

#define MACHINEGUN_SETTINGS(turret) 


#ifdef SVQC
MACHINEGUN_SETTINGS(machinegun)
#endif // SVQC
#else
#ifdef SVQC

void spawnfunc_turret_machinegun() { if not(turret_initialize(TUR_MACHINEGUN)) remove(self); }

float t_machinegun(float req)
{
	switch(req)
	{
		case TR_ATTACK:
		{
			fireBallisticBullet (self.tur_shotorg, self.tur_shotdir_updated,self.shot_spread, self.shot_speed, 5, self.shot_dmg, self.shot_force, DEATH_TURRET_MACHINEGUN, 0, 1, autocvar_g_balance_uzi_bulletconstant);
			endFireBallisticBullet();

			UziFlash();
			setattachment(self.muzzle_flash, self.tur_head, "tag_fire");

			return TRUE;
		}
		case TR_THINK:
		{
			return TRUE;
		}
		case TR_DEATH:
		{
			return TRUE;
		}
		case TR_SETUP:
		{
			self.damage_flags |= TFL_DMG_HEADSHAKE;
			self.target_select_flags = TFL_TARGETSELECT_PLAYERS | TFL_TARGETSELECT_RANGELIMITS | TFL_TARGETSELECT_TEAMCHECK;
			self.ammo_flags = TFL_AMMO_BULLETS | TFL_AMMO_RECHARGE | TFL_AMMO_RECIEVE;
			self.aim_flags = TFL_AIM_LEAD | TFL_AIM_SHOTTIMECOMPENSATE;
			
			if not(autocvar_g_antilag_bullets)
				self.turret_flags |= TUR_FLAG_HITSCAN;

			return TRUE;
		}
		case TR_PRECACHE:
		{
			precache_model ("models/turrets/base.md3");
			precache_model ("models/turrets/machinegun.md3");
			precache_sound ("weapons/uzi_fire.wav");
			return TRUE;
		}
		case TR_CONFIG:
		{
			TUR_CONFIG_SETTINGS(MACHINEGUN_SETTINGS(machinegun))
			return TRUE;
		}
	}

	return TRUE;
}

#endif // SVQC
#ifdef CSQC
float t_machinegun(float req)
{
	switch(req)
	{
		case TR_SETUP:
		{
			return TRUE;
		}
		case TR_PRECACHE:
		{
			precache_model ("models/turrets/base.md3");
			precache_model ("models/turrets/machinegun.md3");
			return TRUE;
		}
	}

	return TRUE;
}

#endif // CSQC
#endif // REGISTER_TURRET