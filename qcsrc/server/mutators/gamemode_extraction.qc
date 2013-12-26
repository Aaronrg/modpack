MUTATOR_HOOKFUNCTION(ex_PlayerUseKey)
{
	if(MUTATOR_RETURNVALUE || gameover) { return FALSE; }
	
	// ex_DropEggs();
	
	return FALSE;
}

MUTATOR_HOOKFUNCTION(ex_PlayerDies)
{
	return FALSE;
}

void spawnfunc_extraction_egg()
{
	if(!g_extraction) { remove(self); return; }
		ex_egg_count += 1;
		ex_egg[ex_egg_count] = self;
}

void spawnfunc_extraction_basket()
{
	if(!g_extraction) { remove(self); return; }
}

MUTATOR_DEFINITION(gamemode_extraction)
{
	MUTATOR_HOOK(PlayerDies, ex_PlayerDies, CBC_ORDER_ANY);
	MUTATOR_HOOK(PlayerUseKey, ex_PlayerUseKey, CBC_ORDER_ANY);

	MUTATOR_ONADD
	{
		if(time > 1) // game loads at time 1
			error("This is a game type and it cannot be added at runtime.");
	}

	MUTATOR_ONREMOVE
	{
		print("This is a game type and it cannot be removed at runtime.");
		return -1;
	}

	return 0;
}
