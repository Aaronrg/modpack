#include "../round_handler.qh"

.float freezetag_frozen_time;
.float freezetag_frozen_timeout;
const float ICE_MAX_ALPHA = 1;
const float ICE_MIN_ALPHA = 0.1;
float freezetag_teams;

const float SP_FREEZETAG_REVIVALS = 4;
void freezetag_ScoreRules(float teams)
{
	ScoreRules_basics(teams, SFL_SORT_PRIO_PRIMARY, SFL_SORT_PRIO_PRIMARY, true); // SFL_SORT_PRIO_PRIMARY
	ScoreInfo_SetLabel_PlayerScore(SP_FREEZETAG_REVIVALS, "revivals", 0);
	ScoreRules_basics_end();
}

void freezetag_count_alive_players()
{
	entity e;
	total_players = redalive = bluealive = yellowalive = pinkalive = 0;
	FOR_EACH_PLAYER(e)
	{
		switch(e.team)
		{
			case NUM_TEAM_1: ++total_players; if(e.health >= 1 && e.frozen != 1) ++redalive; break;
			case NUM_TEAM_2: ++total_players; if(e.health >= 1 && e.frozen != 1) ++bluealive; break;
			case NUM_TEAM_3: ++total_players; if(e.health >= 1 && e.frozen != 1) ++yellowalive; break;
			case NUM_TEAM_4: ++total_players; if(e.health >= 1 && e.frozen != 1) ++pinkalive; break;
		}
	}
	FOR_EACH_REALCLIENT(e)
	{
		e.redalive_stat = redalive;
		e.bluealive_stat = bluealive;
		e.yellowalive_stat = yellowalive;
		e.pinkalive_stat = pinkalive;
	}

	eliminatedPlayers.SendFlags |= 1;
}
#define FREEZETAG_ALIVE_TEAMS() ((redalive > 0) + (bluealive > 0) + (yellowalive > 0) + (pinkalive > 0))
#define FREEZETAG_ALIVE_TEAMS_OK() (FREEZETAG_ALIVE_TEAMS() == freezetag_teams)

float freezetag_CheckTeams()
{
	freezetag_count_alive_players();

	static float prev_missing_teams_mask;
	if(FREEZETAG_ALIVE_TEAMS_OK())
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
	if(freezetag_teams >= 3) missing_teams_mask += (!yellowalive) * 4;
	if(freezetag_teams >= 4) missing_teams_mask += (!pinkalive) * 8;
	if(prev_missing_teams_mask != missing_teams_mask)
	{
		Send_Notification(NOTIF_ALL, world, MSG_CENTER, CENTER_MISSING_TEAMS, missing_teams_mask);
		prev_missing_teams_mask = missing_teams_mask;
	}
	return 0;
}

float freezetag_getWinnerTeam()
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

float ft_EnemyWaypoint_Customize()
{
	if(self.owner.frozen || self.owner.deadflag) { return false; }

	entity e = WaypointSprite_getviewentity(other);

	if(SAME_TEAM(self.owner, e)) { return false; }

	return true;
}

void ft_EnemyWaypoints(entity player)
{
	WaypointSprite_Spawn("enemy", 0, 0, player, ENEMY_WAYPOINT_OFFSET, world, 0, player, wps_enemy, true, RADARICON_FLAG, WPCOLOR_ENEMY(player.team));
	WaypointSprite_UpdateMaxHealth(player.wps_enemy, '1 0 0' * healtharmor_maxdamage(start_health, start_armorvalue, autocvar_g_balance_armor_blockpercent, DEATH_WEAPON) * 2);
	WaypointSprite_UpdateHealth(player.wps_enemy, '1 0 0' * healtharmor_maxdamage(player.health, player.armorvalue, autocvar_g_balance_armor_blockpercent, DEATH_WEAPON));
	WaypointSprite_UpdateTeamRadar(player.wps_enemy, RADARICON_FLAGCARRIER, WPCOLOR_ENEMY(player.team));
	
	player.wps_enemy.customizeentityforclient = ft_EnemyWaypoint_Customize;
}

float freezetag_CheckWinner()
{
	entity e;

	if(!ft_stalemate)
	if(round_handler_GetEndTime() > 0 && round_handler_GetEndTime() - time <= 0)
	{
		ft_stalemate = true;
		Send_Notification(NOTIF_ALL, world, MSG_CENTER, CENTER_FREEZETAG_STALEMATE);
		FOR_EACH_PLAYER(e)
		{
			ft_EnemyWaypoints(e);
		}
	}

	freezetag_count_alive_players();

	if(FREEZETAG_ALIVE_TEAMS() > 1)
		return 0;

	float winner_team;
	winner_team = freezetag_getWinnerTeam();
	if(winner_team > 0)
	{
		Send_Notification(NOTIF_ALL, world, MSG_CENTER, APP_TEAM_NUM_4(winner_team, CENTER_ROUND_TEAM_WIN_));
		Send_Notification(NOTIF_ALL, world, MSG_INFO, APP_TEAM_NUM_4(winner_team, INFO_ROUND_TEAM_WIN_));
		TeamScore_AddToTeam(winner_team, ST_SCORE, +1);
	}
	else if(winner_team == -1)
	{
		Send_Notification(NOTIF_ALL, world, MSG_CENTER, CENTER_ROUND_TIED);
		Send_Notification(NOTIF_ALL, world, MSG_INFO, INFO_ROUND_TIED);
	}

	ft_stalemate = false;
	FOR_EACH_PLAYER(e)
	{
		e.freezetag_frozen_timeout = 0;
		e.revive_progress = 0;
		WaypointSprite_Kill(e.wps_enemy);
	}

	nades_Clear(world, true);

	round_handler_Init(5, autocvar_g_freezetag_warmup, autocvar_g_freezetag_round_timelimit);
	return 1;
}

entity freezetag_LastPlayerForTeam()
{
	entity pl, last_pl = world;
	FOR_EACH_PLAYER(pl)
	{
		if(pl.health >= 1)
		if(!pl.frozen)
		if(pl != self)
		if(pl.team == self.team)
		if(!last_pl)
			last_pl = pl;
		else
			return world;
	}
	return last_pl;
}

void freezetag_LastPlayerForTeam_Notify()
{
	if(round_handler_IsActive())
	if(round_handler_IsRoundStarted())
	{
		entity pl = freezetag_LastPlayerForTeam();
		if(pl)
			Send_Notification(NOTIF_ONE, pl, MSG_CENTER, CENTER_ALONE);
	}
}

void freezetag_Add_Score(entity attacker)
{
	if(attacker == self)
	{
		// you froze your own dumb self
		// counted as "suicide" already
		PlayerScore_Add(self, SP_SCORE, -1);
	}
	else if(IS_PLAYER(attacker))
	{
		// got frozen by an enemy
		// counted as "kill" and "death" already
		PlayerScore_Add(self, SP_SCORE, -1);
		PlayerScore_Add(attacker, SP_SCORE, +1);
	}
	// else nothing - got frozen by the game type rules themselves
}

void freezetag_Freeze(entity attacker)
{
	if(self.frozen)
		return;

	if(autocvar_g_freezetag_frozen_maxtime > 0)
		self.freezetag_frozen_timeout = time + autocvar_g_freezetag_frozen_maxtime;

	Freeze(self, 0, 1, true);

	freezetag_count_alive_players();

	freezetag_Add_Score(attacker);
}

void freezetag_Unfreeze(entity attacker)
{
	self.freezetag_frozen_time = 0;
	self.freezetag_frozen_timeout = 0;

	Unfreeze(self);

	self.health = autocvar_g_freezetag_revive_health;
}

float freezetag_isEliminated(entity e)
{
	if(IS_PLAYER(e) && (e.frozen == 1 || e.deadflag != DEAD_NO))
		return true;
	return false;
}


// ================
// Bot player logic
// ================

void() havocbot_role_ft_freeing;
void() havocbot_role_ft_offense;

void havocbot_goalrating_freeplayers(float ratingscale, vector org, float sradius)
{
	entity head;
	float distance;

	FOR_EACH_PLAYER(head)
	{
		if ((head != self) && (head.team == self.team))
		{
			if (head.frozen == 1)
			{
				distance = vlen(head.origin - org);
				if (distance > sradius)
					continue;
				navigation_routerating(head, ratingscale, 2000);
			}
			else
			{
				// If teamate is not frozen still seek them out as fight better
				// in a group.
				navigation_routerating(head, ratingscale/3, 2000);
			}
		}
	}
}

void havocbot_role_ft_offense()
{
	entity head;
	float unfrozen;

	if(self.deadflag != DEAD_NO)
		return;

	if (!self.havocbot_role_timeout)
		self.havocbot_role_timeout = time + random() * 10 + 20;

	// Count how many players on team are unfrozen.
	unfrozen = 0;
	FOR_EACH_PLAYER(head)
	{
		if ((head.team == self.team) && (head.frozen != 1))
			unfrozen++;
	}

	// If only one left on team or if role has timed out then start trying to free players.
	if (((unfrozen == 0) && (!self.frozen)) || (time > self.havocbot_role_timeout))
	{
		dprint("changing role to freeing\n");
		self.havocbot_role = havocbot_role_ft_freeing;
		self.havocbot_role_timeout = 0;
		return;
	}

	if (time > self.bot_strategytime)
	{
		self.bot_strategytime = time + autocvar_bot_ai_strategyinterval;

		navigation_goalrating_start();
		havocbot_goalrating_items(10000, self.origin, 10000);
		havocbot_goalrating_enemyplayers(20000, self.origin, 10000);
		havocbot_goalrating_freeplayers(9000, self.origin, 10000);
		//havocbot_goalrating_waypoints(1, self.origin, 1000);
		navigation_goalrating_end();
	}
}

void havocbot_role_ft_freeing()
{
	if(self.deadflag != DEAD_NO)
		return;

	if (!self.havocbot_role_timeout)
		self.havocbot_role_timeout = time + random() * 10 + 20;

	if (time > self.havocbot_role_timeout)
	{
		dprint("changing role to offense\n");
		self.havocbot_role = havocbot_role_ft_offense;
		self.havocbot_role_timeout = 0;
		return;
	}

	if (time > self.bot_strategytime)
	{
		self.bot_strategytime = time + autocvar_bot_ai_strategyinterval;

		navigation_goalrating_start();
		havocbot_goalrating_items(8000, self.origin, 10000);
		havocbot_goalrating_enemyplayers(10000, self.origin, 10000);
		havocbot_goalrating_freeplayers(20000, self.origin, 10000);
		//havocbot_goalrating_waypoints(1, self.origin, 1000);
		navigation_goalrating_end();
	}
}


// ==============
// Hook Functions
// ==============

MUTATOR_HOOKFUNCTION(freezetag_RemovePlayer)
{
	self.health = 0; // neccessary to update correctly alive stats
	if(!self.frozen)
		freezetag_LastPlayerForTeam_Notify();
	freezetag_Unfreeze(world);
	return 1;
}

MUTATOR_HOOKFUNCTION(freezetag_PlayerDies)
{
	if(round_handler_IsActive())
	if(round_handler_CountdownRunning())
	{
		if(self.frozen)
			freezetag_Unfreeze(world);
		return 1; // let the player die so that he can respawn whenever he wants
	}

	// Cases DEATH_TEAMCHANGE and DEATH_AUTOTEAMCHANGE are needed to fix a bug whe
	// you succeed changing team through the menu: you both really die (gibbing) and get frozen
	if(ITEM_DAMAGE_NEEDKILL(frag_deathtype)
		|| frag_deathtype == DEATH_TEAMCHANGE || frag_deathtype == DEATH_AUTOTEAMCHANGE)
	{
		// let the player die, he will be automatically frozen when he respawns
		if(self.frozen != 1)
		{
			freezetag_Add_Score(frag_attacker);
			freezetag_LastPlayerForTeam_Notify();
		}
		else
			freezetag_Unfreeze(world); // remove ice
		self.health = 0; // Unfreeze resets health
		self.freezetag_frozen_timeout = -2; // freeze on respawn
		return 1;
	}

	if(self.frozen)
		return 1;

	if(g_instagib)
		frag_target.ammo_cells = start_ammo_cells; // we need more ammo in instagib, otherwise the player will defrost & die again

	freezetag_Freeze(frag_attacker);
	freezetag_LastPlayerForTeam_Notify();

	if(frag_attacker == frag_target || frag_attacker == world)
	{
		if(IS_PLAYER(frag_target))
			Send_Notification(NOTIF_ONE, frag_target, MSG_CENTER, CENTER_FREEZETAG_SELF);
		Send_Notification(NOTIF_ALL, world, MSG_INFO, INFO_FREEZETAG_SELF, frag_target.netname);
	}
	else
	{
		if(IS_PLAYER(frag_target))
			Send_Notification(NOTIF_ONE, frag_target, MSG_CENTER, CENTER_FREEZETAG_FROZEN, frag_attacker.netname);
		if(IS_PLAYER(frag_attacker))
			Send_Notification(NOTIF_ONE, frag_attacker, MSG_CENTER, CENTER_FREEZETAG_FREEZE, frag_target.netname);
		Send_Notification(NOTIF_ALL, world, MSG_INFO, INFO_FREEZETAG_FREEZE, frag_target.netname, frag_attacker.netname);
	}

	return 1;
}

MUTATOR_HOOKFUNCTION(freezetag_PlayerSpawn)
{
	if(self.freezetag_frozen_timeout == -1) // if PlayerSpawn is called by reset_map_players
		return 1; // do nothing, round is starting right now

	if(ft_stalemate)
	if(!self.wps_enemy)
		ft_EnemyWaypoints(self);

	if(self.freezetag_frozen_timeout == -2) // player was dead
	{
		freezetag_Freeze(world);
		return 1;
	}

	if(round_handler_IsActive())
	if(round_handler_IsRoundStarted())
	{
		Send_Notification(NOTIF_ONE, self, MSG_CENTER, CENTER_FREEZETAG_SPAWN_LATE);
		freezetag_Freeze(world);
	}

	return 1;
}

MUTATOR_HOOKFUNCTION(freezetag_reset_map_players)
{
	FOR_EACH_PLAYER(self)
	{
		self.killcount = 0;
		self.freezetag_frozen_timeout = -1;
		PutClientInServer();
		self.freezetag_frozen_timeout = 0;
		WaypointSprite_Kill(self.wps_enemy);
	}
	return 1;
}

MUTATOR_HOOKFUNCTION(freezetag_ResetMap)
{
	ft_stalemate = false;
	return false;
}

MUTATOR_HOOKFUNCTION(freezetag_GiveFragsForKill)
{
	frag_score = 0; // no frags counted in Freeze Tag
	return 1;
}

.float reviving; // temp var
MUTATOR_HOOKFUNCTION(freezetag_PlayerPreThink)
{
	float n;

	if(gameover)
		return 1;

	if(self.frozen == 1)
	{
		// keep health = 1
		self.pauseregen_finished = time + autocvar_g_balance_pause_health_regen;
	}

	if(round_handler_IsActive())
	if(!round_handler_IsRoundStarted())
		return 1;

	entity o;
	o = world;
	//if(self.frozen)
	//if(self.freezetag_frozen_timeout > 0 && time < self.freezetag_frozen_timeout)
		//self.iceblock.alpha = ICE_MIN_ALPHA + (ICE_MAX_ALPHA - ICE_MIN_ALPHA) * (self.freezetag_frozen_timeout - time) / (self.freezetag_frozen_timeout - self.freezetag_frozen_time);

	if(self.freezetag_frozen_timeout > 0 && time >= self.freezetag_frozen_timeout)
		n = -1;
	else
	{
		vector revive_extra_size = '1 1 1' * autocvar_g_freezetag_revive_extra_size;
		n = 0;
		FOR_EACH_PLAYER(other)
		if(self != other)
		if(other.frozen == 0)
		if(other.deadflag == DEAD_NO)
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

	if(n && self.frozen == 1) // OK, there is at least one teammate reviving us
	{
		self.revive_progress = bound(0, self.revive_progress + frametime * max(1/60, autocvar_g_freezetag_revive_speed), 1);
		self.health = max(1, self.revive_progress * ((warmup_stage) ? warmup_start_health : autocvar_g_freezetag_revive_health));

		if(self.revive_progress >= 1)
		{
			freezetag_Unfreeze(self);

			if(n == -1)
			{
				Send_Notification(NOTIF_ONE, self, MSG_CENTER, CENTER_FREEZETAG_AUTO_REVIVED, autocvar_g_freezetag_frozen_maxtime);
				Send_Notification(NOTIF_ALL, world, MSG_INFO, INFO_FREEZETAG_AUTO_REVIVED, self.netname, autocvar_g_freezetag_frozen_maxtime);
				return 1;
			}

			// EVERY team mate nearby gets a point (even if multiple!)
			FOR_EACH_PLAYER(other)
			{
				if(other.reviving)
				{
					PlayerScore_Add(other, SP_FREEZETAG_REVIVALS, +1);
					PlayerScore_Add(other, SP_SCORE, +1);

					nades_GiveBonus(other,autocvar_g_nades_bonus_score_low);
				}
			}

			Send_Notification(NOTIF_ONE, self, MSG_CENTER, CENTER_FREEZETAG_REVIVED, o.netname);
			Send_Notification(NOTIF_ONE, o, MSG_CENTER, CENTER_FREEZETAG_REVIVE, self.netname);
			Send_Notification(NOTIF_ALL, world, MSG_INFO, INFO_FREEZETAG_REVIVED, self.netname, o.netname);
		}

		FOR_EACH_PLAYER(other)
		{
			if(other.reviving)
			{
				other.revive_progress = self.revive_progress;
				other.reviving = false;
			}
		}
	}
	else if(!n && self.frozen == 1) // only if no teammate is nearby will we reset
	{
		self.revive_progress = bound(0, self.revive_progress - frametime * autocvar_g_freezetag_revive_clearspeed, 1);
		self.health = max(1, self.revive_progress * ((warmup_stage) ? warmup_start_health : autocvar_g_freezetag_revive_health));
	}
	else if(!n && !self.frozen)
	{
		self.revive_progress = 0; // thawing nobody
	}

	if(self.wps_enemy)
		WaypointSprite_UpdateHealth(self.wps_enemy, '1 0 0' * healtharmor_maxdamage(self.health, self.armorvalue, autocvar_g_balance_armor_blockpercent, DEATH_WEAPON));

	return 1;
}

MUTATOR_HOOKFUNCTION(freezetag_BotRoles)
{
	if (!self.deadflag)
	{
		if (random() < 0.5)
			self.havocbot_role = havocbot_role_ft_freeing;
		else
			self.havocbot_role = havocbot_role_ft_offense;
	}

	return true;
}

MUTATOR_HOOKFUNCTION(freezetag_GetTeamCount)
{
	ret_float = freezetag_teams;
	return false;
}

void freezetag_Initialize()
{
	freezetag_teams = autocvar_g_freezetag_teams_override;
	if(freezetag_teams < 2)
		freezetag_teams = autocvar_g_freezetag_teams;
	freezetag_teams = bound(2, freezetag_teams, 4);
	freezetag_ScoreRules(freezetag_teams);

	round_handler_Spawn(freezetag_CheckTeams, freezetag_CheckWinner, func_null);
	round_handler_Init(5, autocvar_g_freezetag_warmup, autocvar_g_freezetag_round_timelimit);

	addstat(STAT_REDALIVE, AS_INT, redalive_stat);
	addstat(STAT_BLUEALIVE, AS_INT, bluealive_stat);
	addstat(STAT_YELLOWALIVE, AS_INT, yellowalive_stat);
	addstat(STAT_PINKALIVE, AS_INT, pinkalive_stat);

	EliminatedPlayers_Init(freezetag_isEliminated);
}

MUTATOR_DEFINITION(gamemode_freezetag)
{
	MUTATOR_HOOK(MakePlayerObserver, freezetag_RemovePlayer, CBC_ORDER_ANY);
	MUTATOR_HOOK(ClientDisconnect, freezetag_RemovePlayer, CBC_ORDER_ANY);
	MUTATOR_HOOK(PlayerDies, freezetag_PlayerDies, CBC_ORDER_ANY);
	MUTATOR_HOOK(PlayerSpawn, freezetag_PlayerSpawn, CBC_ORDER_ANY);
	MUTATOR_HOOK(reset_map_players, freezetag_reset_map_players, CBC_ORDER_ANY);
	MUTATOR_HOOK(GiveFragsForKill, freezetag_GiveFragsForKill, CBC_ORDER_FIRST);
	MUTATOR_HOOK(PlayerPreThink, freezetag_PlayerPreThink, CBC_ORDER_FIRST);
	MUTATOR_HOOK(HavocBot_ChooseRole, freezetag_BotRoles, CBC_ORDER_ANY);
	MUTATOR_HOOK(GetTeamCount, freezetag_GetTeamCount, CBC_ORDER_EXCLUSIVE);

	MUTATOR_ONADD
	{
		if(time > 1) // game loads at time 1
			error("This is a game type and it cannot be added at runtime.");
		freezetag_Initialize();
	}

	MUTATOR_ONROLLBACK_OR_REMOVE
	{
		// we actually cannot roll back freezetag_Initialize here
		// BUT: we don't need to! If this gets called, adding always
		// succeeds.
	}

	MUTATOR_ONREMOVE
	{
		print("This is a game type and it cannot be removed at runtime.");
		return -1;
	}

	return 0;
}
