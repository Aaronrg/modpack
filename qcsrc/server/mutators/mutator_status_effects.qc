float GetStatusDeathtype(float eff)
{
	switch(eff)
	{
		case STATUS_EFFECT_FIRE: return DEATH_STATUS_FIRE;
		case STATUS_EFFECT_BLEEDING: return DEATH_STATUS_BLOODLOSS;
		case STATUS_EFFECT_POISON: return DEATH_STATUS_POISON;
	}
	
	return DEATH_ROT;
}

MUTATOR_HOOKFUNCTION(status_PlayerStatus)
{
	float eff = self.status_effects;
	self.effects &= ~(EF_FLAME);
	self.modelflags &= ~(MF_ZOMGIB);
	
	if(eff & STATUS_EFFECT_FIRE)
		self.effects |= EF_FLAME;
	if(eff & STATUS_EFFECT_BLEEDING)
		self.modelflags |= MF_ZOMGIB;

	return FALSE;
}

MUTATOR_HOOKFUNCTION(status_PlayerThink)
{
	if(time >= self.status_effects_delay)
	{
		self.status_enabled = autocvar_g_status_effects;
		
		float eff = self.status_effects, do_damage = 0;
		
		if(eff & STATUS_EFFECT_FIRE)
			do_damage = 2;
		if(eff & STATUS_EFFECT_BLEEDING)
			do_damage = 1;
			
		if(do_damage)
			self.event_damage(self, self, do_damage, GetStatusDeathtype(eff), self.origin, '0 0 0');
			
		self.status_effects_delay = time + 0.5;
	}
	
	return FALSE;
}

MUTATOR_HOOKFUNCTION(status_SpectateCopy)
{
	self.status_effects = other.status_effects;
	return FALSE;
}

MUTATOR_HOOKFUNCTION(status_RemoveEffects)
{
	self.status_effects = 0;
	return FALSE;
}

void status_Initialize()
{
	addstat(STAT_STATUS_ENABLED, AS_INT, status_enabled);
	addstat(STAT_STATUS, AS_INT, status_effects);
}

MUTATOR_DEFINITION(mutator_status_effects)
{
	MUTATOR_HOOK(PlayerPowerups, status_PlayerStatus, CBC_ORDER_ANY);
	MUTATOR_HOOK(PlayerPreThink, status_PlayerThink, CBC_ORDER_ANY);
	MUTATOR_HOOK(SpectateCopy, status_SpectateCopy, CBC_ORDER_ANY);
	MUTATOR_HOOK(PlayerDies, status_RemoveEffects, CBC_ORDER_ANY);
	MUTATOR_HOOK(MakePlayerObserver, status_RemoveEffects, CBC_ORDER_ANY);
	MUTATOR_HOOK(ClientDisconnect, status_RemoveEffects, CBC_ORDER_ANY);
	
	MUTATOR_ONADD
	{
		status_Initialize();
	}

	return FALSE;
}
