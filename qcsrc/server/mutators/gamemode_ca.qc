#include "../round_handler.qh"

float total_players;
float redalive, bluealive, yellowalive, pinkalive;
.float redalive_stat, bluealive_stat, yellowalive_stat, pinkalive_stat;
float ca_teams;
float allowed_to_spawn;

const float ST_CA_ROUNDS = 1;
void ca_ScoreRules(float teams)
{
	ScoreRules_basics(teams, SFL_SORT_PRIO_PRIMARY, 0, true);
	ScoreInfo_SetLabel_TeamScore(ST_CA_ROUNDS, "rounds", SFL_SORT_PRIO_PRIMARY);
	ScoreRules_basics_end();
}

void CA_count_alive_players()
{
	entity e;
	total_players = redalive = bluealive = yellowalive = pinkalive = 0;
	FOR_EACH_PLAYER(e)
	{
		switch(e.team)
		{
			case NUM_TEAM_1: if(e.health >= 1) ++redalive; ++total_players; break;
			case NUM_TEAM_2: if(e.health >= 1) ++bluealive; ++total_players; break;
			case NUM_TEAM_3: if(e.health >= 1) ++yellowalive; ++total_players; break;
			case NUM_TEAM_4: if(e.health >= 1) ++pinkalive; ++total_players; break;
		}
	}
	FOR_EACH_REALCLIENT(e)
	{
		e.redalive_stat = redalive;
		e.bluealive_stat = bluealive;
		e.yellowalive_stat = yellowalive;
		e.pinkalive_stat = pinkalive;
	}
}

float CA_GetWinnerTeam()
{
	float winner_team = 0;
	if(redalive >= 1)
		winner_team = NUM_TEAM_1;
	if(bluealive >= 1)
	{
		if(winner_team) return 0;
		winner_team = NUM_TEAM_2;
	}
	if(yellowalive >= 1)
	{
		if(winner_team) return 0;
		winner_team = NUM_TEAM_3;
	}
	if(pinkalive >= 1)
	{
		if(winner_team) return 0;
		winner_team = NUM_TEAM_4;
	}
	if(winner_team)
		return winner_team;
	return -1; // no player left
}

#define CA_ALIVE_TEAMS() ((redalive > 0) + (bluealive > 0) + (yellowalive > 0) + (pinkalive > 0))
#define CA_ALIVE_TEAMS_OK() (CA_ALIVE_TEAMS() == ca_teams)
float CA_CheckWinner()
{
	if(round_handler_GetEndTime() > 0 && round_handler_GetEndTime() - time <= 0)
	{
		Send_Notification(NOTIF_ALL, world, MSG_CENTER, CENTER_ROUND_OVER);
		Send_Notification(NOTIF_ALL, world, MSG_INFO, INFO_ROUND_OVER);
		allowed_to_spawn = false;
		round_handler_Init(5, autocvar_g_ca_warmup, autocvar_g_ca_round_timelimit);
		nades_Clear(world, true);
		return 1;
	}

	CA_count_alive_players();
	if(CA_ALIVE_TEAMS() > 1)
		return 0;

	float winner_team = CA_GetWinnerTeam();
	if(winner_team > 0)
	{
		Send_Notification(NOTIF_ALL, world, MSG_CENTER, APP_TEAM_NUM_4(winner_team, CENTER_ROUND_TEAM_WIN_));
		Send_Notification(NOTIF_ALL, world, MSG_INFO, APP_TEAM_NUM_4(winner_team, INFO_ROUND_TEAM_WIN_));
		TeamScore_AddToTeam(winner_team, ST_CA_ROUNDS, +1);
	}
	else if(winner_team == -1)
	{
		Send_Notification(NOTIF_ALL, world, MSG_CENTER, CENTER_ROUND_TIED);
		Send_Notification(NOTIF_ALL, world, MSG_INFO, INFO_ROUND_TIED);
	}

	allowed_to_spawn = false;
	round_handler_Init(5, autocvar_g_ca_warmup, autocvar_g_ca_round_timelimit);

	nades_Clear(world, true);

	return 1;
}

void CA_RoundStart()
{
	if(warmup_stage)
		allowed_to_spawn = true;
	else
		allowed_to_spawn = false;
}

float CA_CheckTeams()
{
	static float prev_missing_teams_mask;
	allowed_to_spawn = true;
	CA_count_alive_players();
	if(CA_ALIVE_TEAMS_OK())
	{
		if(prev_missing_teams_mask > 0)
			Kill_Notification(NOTIF_ALL, world, MSG_CENTER_CPID, CPID_MISSING_TEAMS);
		prev_missing_teams_mask = -1;
		return 1;
	}
	if(total_players == 0)
	{
		if(prev_missing_teams_mask > 0)
			Kill_Notification(NOTIF_ALL, world, MSG_CENTER_CPID, CPID_MISSING_TEAMS);
		prev_missing_teams_mask = -1;
		return 0;
	}
	float missing_teams_mask = (!redalive) + (!bluealive) * 2;
	if(ca_teams >= 3) missing_teams_mask += (!yellowalive) * 4;
	if(ca_teams >= 4) missing_teams_mask += (!pinkalive) * 8;
	if(prev_missing_teams_mask != missing_teams_mask)
	{
		Send_Notification(NOTIF_ALL, world, MSG_CENTER, CENTER_MISSING_TEAMS, missing_teams_mask);
		prev_missing_teams_mask = missing_teams_mask;
	}
	return 0;
}

float ca_isEliminated(entity e)
{
	if(e.caplayer == 1 && (e.deadflag != DEAD_NO || e.frags == FRAGS_LMS_LOSER))
		return true;
	if(e.caplayer == 0.5)
		return true;
	return false;
}

MUTATOR_HOOKFUNCTION(ca_PlayerSpawn)
{
	self.caplayer = 1;
	if(!warmup_stage)
		eliminatedPlayers.SendFlags |= 1;
	return 1;
}

MUTATOR_HOOKFUNCTION(ca_PutClientInServer)
{
	if(!allowed_to_spawn)
	if(IS_PLAYER(self)) // this is true even when player is trying to join
	{
		self.classname = "observer";
		if(self.jointime != time) //not when connecting
		if(!self.caplayer)
		{
			self.caplayer = 0.5;
			if(IS_REAL_CLIENT(self))
				Send_Notification(NOTIF_ONE_ONLY, self, MSG_INFO, INFO_CA_JOIN_LATE);
		}
	}
	return 1;
}

MUTATOR_HOOKFUNCTION(ca_reset_map_players)
{
	FOR_EACH_CLIENT(self)
	{
		self.killcount = 0;
		if(!self.caplayer && IS_BOT_CLIENT(self))
		{
			self.team = -1;
			self.caplayer = 1;
		}
		if(self.caplayer)
		{
			self.classname = "player";
			self.caplayer = 1;
			PutClientInServer();
		}
	}
	return 1;
}

MUTATOR_HOOKFUNCTION(ca_ClientConnect)
{
	self.classname = "observer";
	return 1;
}

MUTATOR_HOOKFUNCTION(ca_reset_map_global)
{
	allowed_to_spawn = true;
	return 1;
}

MUTATOR_HOOKFUNCTION(ca_GetTeamCount)
{
	ret_float = ca_teams;
	return 0;
}

entity ca_LastPlayerForTeam()
{
	entity pl, last_pl = world;
	FOR_EACH_PLAYER(pl)
	{
		if(pl.health >= 1)
		if(pl != self)
		if(pl.team == self.team)
		if(!last_pl)
			last_pl = pl;
		else
			return world;
	}
	return last_pl;
}

void ca_LastPlayerForTeam_Notify()
{
	if(round_handler_IsActive())
	if(round_handler_IsRoundStarted())
	{
		entity pl = ca_LastPlayerForTeam();
		if(pl)
			Send_Notification(NOTIF_ONE, pl, MSG_CENTER, CENTER_ALONE);
	}
}

MUTATOR_HOOKFUNCTION(ca_PlayerDies)
{
	ca_LastPlayerForTeam_Notify();
	if(!allowed_to_spawn)
		self.respawn_flags =  RESPAWN_SILENT;
	if(!warmup_stage)
		eliminatedPlayers.SendFlags |= 1;
	return 1;
}

MUTATOR_HOOKFUNCTION(ca_ClientDisconnect)
{
	if(self.caplayer == 1)
		ca_LastPlayerForTeam_Notify();
	return 1;
}

MUTATOR_HOOKFUNCTION(ca_ForbidPlayerScore_Clear)
{
	return 1;
}

MUTATOR_HOOKFUNCTION(ca_MakePlayerObserver)
{
	if(self.caplayer == 1)
		ca_LastPlayerForTeam_Notify();
	if(self.killindicator_teamchange == -2)
		self.caplayer = 0;
	if(self.caplayer)
		self.frags = FRAGS_LMS_LOSER;
	if(!warmup_stage)
		eliminatedPlayers.SendFlags |= 1;
	return 1;
}

MUTATOR_HOOKFUNCTION(ca_ForbidThrowCurrentWeapon)
{
	return 1;
}

MUTATOR_HOOKFUNCTION(ca_GiveFragsForKill)
{
	frag_score = 0; // score will be given to the winner team when the round ends
	return 1;
}

MUTATOR_HOOKFUNCTION(ca_SetStartItems)
{
	start_items &= ~IT_UNLIMITED_AMMO;
	start_health       = warmup_start_health       = cvar("g_lms_start_health");
	start_armorvalue   = warmup_start_armorvalue   = cvar("g_lms_start_armor");
	start_ammo_shells  = warmup_start_ammo_shells  = cvar("g_lms_start_ammo_shells");
	start_ammo_nails   = warmup_start_ammo_nails   = cvar("g_lms_start_ammo_nails");
	start_ammo_rockets = warmup_start_ammo_rockets = cvar("g_lms_start_ammo_rockets");
	start_ammo_cells   = warmup_start_ammo_cells   = cvar("g_lms_start_ammo_cells");
	start_ammo_plasma  = warmup_start_ammo_plasma  = cvar("g_lms_start_ammo_plasma");
	start_ammo_fuel    = warmup_start_ammo_fuel    = cvar("g_lms_start_ammo_fuel");

	return 0;
}

MUTATOR_HOOKFUNCTION(ca_PlayerDamage)
{
	if(IS_PLAYER(frag_target))
	if(frag_target.deadflag == DEAD_NO)
	if(frag_target == frag_attacker || SAME_TEAM(frag_target, frag_attacker) || frag_deathtype == DEATH_FALL)
		frag_damage = 0;

	frag_mirrordamage = 0;

	return false;
}

MUTATOR_HOOKFUNCTION(ca_FilterItem)
{
	if(autocvar_g_pickup_items <= 0)
		return true;

	return false;
}

MUTATOR_HOOKFUNCTION(ca_PlayerDamage_SplitHealthArmor)
{
	float excess = max(0, frag_damage - damage_take - damage_save);

	if(frag_target != frag_attacker && IS_PLAYER(frag_attacker))
		PlayerTeamScore_Add(frag_attacker, SP_SCORE, ST_SCORE, (frag_damage - excess) * autocvar_g_ca_damage2score_multiplier);

	return false;
}

MUTATOR_HOOKFUNCTION(ca_PlayerRegen)
{
	// no regeneration in CA
	return true;
}

MUTATOR_HOOKFUNCTION(ca_WantWeapon)
{
	if(other.spawnflags & WEP_FLAG_NORMAL)
		ret_float = true;
	else
		ret_float = false;

	return false;
}

MUTATOR_HOOKFUNCTION(ca_CountFrags)
{
	// announce remaining frags
	return true;
}

void ca_Initialize()
{
	allowed_to_spawn = true;

	ca_teams = autocvar_g_ca_teams_override;
	if(ca_teams < 2)
		ca_teams = autocvar_g_ca_teams;
	ca_teams = bound(2, ca_teams, 4);
	ret_float = ca_teams;
	ca_ScoreRules(ca_teams);

	round_handler_Spawn(CA_CheckTeams, CA_CheckWinner, CA_RoundStart);
	round_handler_Init(5, autocvar_g_ca_warmup, autocvar_g_ca_round_timelimit);

	addstat(STAT_REDALIVE, AS_INT, redalive_stat);
	addstat(STAT_BLUEALIVE, AS_INT, bluealive_stat);
	addstat(STAT_YELLOWALIVE, AS_INT, yellowalive_stat);
	addstat(STAT_PINKALIVE, AS_INT, pinkalive_stat);

	EliminatedPlayers_Init(ca_isEliminated);
}

MUTATOR_DEFINITION(gamemode_ca)
{
	MUTATOR_HOOK(PlayerSpawn, ca_PlayerSpawn, CBC_ORDER_ANY);
	MUTATOR_HOOK(PutClientInServer, ca_PutClientInServer, CBC_ORDER_ANY);
	MUTATOR_HOOK(MakePlayerObserver, ca_MakePlayerObserver, CBC_ORDER_ANY);
	MUTATOR_HOOK(ClientConnect, ca_ClientConnect, CBC_ORDER_ANY);
	MUTATOR_HOOK(reset_map_global, ca_reset_map_global, CBC_ORDER_ANY);
	MUTATOR_HOOK(reset_map_players, ca_reset_map_players, CBC_ORDER_ANY);
	MUTATOR_HOOK(GetTeamCount, ca_GetTeamCount, CBC_ORDER_EXCLUSIVE);
	MUTATOR_HOOK(PlayerDies, ca_PlayerDies, CBC_ORDER_ANY);
	MUTATOR_HOOK(ClientDisconnect, ca_ClientDisconnect, CBC_ORDER_ANY);
	MUTATOR_HOOK(ForbidPlayerScore_Clear, ca_ForbidPlayerScore_Clear, CBC_ORDER_ANY);
	MUTATOR_HOOK(ForbidThrowCurrentWeapon, ca_ForbidThrowCurrentWeapon, CBC_ORDER_ANY);
	MUTATOR_HOOK(GiveFragsForKill, ca_GiveFragsForKill, CBC_ORDER_FIRST);
	MUTATOR_HOOK(SetStartItems, ca_SetStartItems, CBC_ORDER_ANY);
	MUTATOR_HOOK(PlayerDamage_Calculate, ca_PlayerDamage, CBC_ORDER_ANY);
	MUTATOR_HOOK(FilterItem, ca_FilterItem, CBC_ORDER_ANY);
	MUTATOR_HOOK(PlayerDamage_SplitHealthArmor, ca_PlayerDamage_SplitHealthArmor, CBC_ORDER_ANY);
	MUTATOR_HOOK(PlayerRegen, ca_PlayerRegen, CBC_ORDER_ANY);
	MUTATOR_HOOK(WantWeapon, ca_WantWeapon, CBC_ORDER_ANY);
	MUTATOR_HOOK(Scores_CountFragsRemaining, ca_CountFrags, CBC_ORDER_ANY);

	MUTATOR_ONADD
	{
		if(time > 1) // game loads at time 1
			error("This is a game type and it cannot be added at runtime.");
		ca_Initialize();
	}

	MUTATOR_ONREMOVE
	{
		print("This is a game type and it cannot be removed at runtime.");
		return -1;
	}

	return 0;
}
