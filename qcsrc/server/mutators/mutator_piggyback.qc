.float cvar_cl_nocarry;

entity pb_TailOf(entity p)
{
	while(p.piggybacker)
		p = p.piggybacker;
	return p;
}

entity pb_RootOf(entity p)
{
	while(p.pbhost)
		p = p.pbhost;
	return p;
}

.float pb_oldmoveflags;
.float pb_oldverticalfly;
void pb_Attach(entity host, entity slave)
{
	entity root = pb_RootOf(host);
	host = pb_TailOf(host);
	
	if(host == slave || root == slave || host == slave.piggybacker || slave == host.piggybacker)
		return;
	
	host.piggybacker = slave;
	slave.movetype = MOVETYPE_FOLLOW;
	slave.aiment = host.pbent;
	slave.pbhost = host;
	slave.pb_oldsolid = slave.solid;
	slave.solid = SOLID_CORPSE;
	slave.pb_canattach = 0;

	if(IS_MONSTER(host))
	{
		host.pb_oldmoveflags = host.monster_moveflags;
		host.pb_oldverticalfly = (host.spawnflags & MONSTERFLAG_FLY_VERTICAL);
		host.spawnflags |= MONSTERFLAG_FLY_VERTICAL;
		host.monster_moveflags = MONSTER_MOVE_NOMOVE;
	}
	
	RemoveGrapplingHook(slave);
	
	Send_Notification(NOTIF_ONE, slave, MSG_CENTER, CENTER_PIGGYBACK_RIDING, (IS_MONSTER(host)) ? host.monster_name : host.netname);
	if(IS_PLAYER(host))
		Send_Notification(NOTIF_ONE, host, MSG_CENTER, CENTER_PIGGYBACK_CARRYING, slave.netname);
}

void pb_Detach(entity host)
{
	entity slave = host.piggybacker;
	
	if(!slave)
		return;
	
	slave.aiment = world;
	slave.pbhost = world;

	if(IS_MONSTER(host))
	{
		host.monster_moveto = '0 0 0';
		host.monster_moveflags = host.pb_oldmoveflags;
		if(!host.pb_oldverticalfly) { host.spawnflags &= ~MONSTERFLAG_FLY_VERTICAL; }
	}
	
	if(IS_PLAYER(slave))
	{
		// this doesn't happen when we're fixing a broken reference
		
		if(slave.movetype == MOVETYPE_FOLLOW) // don't reset if player was killed
			slave.movetype = MOVETYPE_WALK;
		slave.velocity = '0 0 0';
		slave.solid = slave.pb_oldsolid;
		
		tracebox(host.origin, slave.mins, slave.maxs, slave.origin, MOVE_NOMONSTERS, slave);
		
		if(trace_fraction < 1)
			setorigin(slave, trace_endpos); // fix player glitching out of the world
		
		Kill_Notification(NOTIF_ONE, slave, MSG_CENTER_CPID, CPID_PIGGYBACK);
		if(IS_PLAYER(host))
			Kill_Notification(NOTIF_ONE, host, MSG_CENTER_CPID, CPID_PIGGYBACK);
	}
	
	host.piggybacker = world;
}

void pb_PBEntThink()
{
	setorigin(self, self.owner.origin + '0 0 0.82' * self.owner.maxs_z);
	self.nextthink = time;
}

void pb_FixPBEnt(entity p)
{
	entity e = spawn();
	e.owner = p;
	e.classname = "pb_ent";
	e.think = pb_PBEntThink;
	e.nextthink = time;
	p.pbent = e;
}

#define BROKEN_PBREF(e) ((e).piggybacker && ((e).piggybacker.pbhost != (e) || (e).piggybacker.movetype != MOVETYPE_FOLLOW))

MUTATOR_HOOKFUNCTION(pb_MatchEnd)
{
	entity head;
	FOR_EACH_PLAYER(head) { pb_Detach(head); }
	FOR_EACH_MONSTER(head) { pb_Detach(head); }
	return false;
}

MUTATOR_HOOKFUNCTION(pb_PlayerUseKey)
{
	if(MUTATOR_RETURNVALUE || gameover) { return false; }
	
	if(self.pbhost)
	{
		pb_Detach(self.pbhost);
		return true;
	}
	if(self.piggybacker)
	{
		pb_Detach(self);
		return true;
	}

	if(!self.vehicle)
	if(!Player_Trapped(self))
	{
		entity head, closest_target = world;

		head = WarpZone_FindRadius(self.origin, autocvar_g_vehicles_enter_radius, true);
		while(head)
		{
			if(IS_PLAYER(head) || (IS_MONSTER(head) && ((get_monsterinfo(head.monsterid)).spawnflags & MON_FLAG_RIDE)))
			if(SAME_TEAM(head, self) || autocvar_g_piggyback_ride_enemies || (IS_MONSTER(head) && head.realowner == self))
			if(head != self)
			if(!head.cvar_cl_nocarry)
			if(head.deadflag == DEAD_NO) // we check for trapped status here, but better to be safe than sorry, considering the madness happening
			if(!head.vehicle)
			if((!Player_Trapped(head) && !Player_Trapped(self)) || (Player_Trapped(head) || Player_Trapped(self)))
			{
				if(closest_target)
				{
					if(vlen(self.origin - head.origin) < vlen(self.origin - closest_target.origin))
					{ closest_target = head; }
				}
				else { closest_target = head; }
			}
			
			head = head.chain;
		}

		if(closest_target)
		if(IS_BOT_CLIENT(closest_target)) { pb_Attach(self, closest_target); return true; }
		else { pb_Attach(closest_target, self); return true; }
	}

	return false;
}

MUTATOR_HOOKFUNCTION(pb_PlayerThink)
{
	if(BROKEN_PBREF(self)) { pb_Detach(self); }
	
	if(!self.pbent)
		pb_FixPBEnt(self);

	if(IS_MONSTER(self.pbhost))
	if(self.movement || self.BUTTON_JUMP || self.BUTTON_CROUCH)
	//if(!self.pbhost.enemy) // if player is trying to move, don't override
	{
		float forw, rit, updown = 0;
		vector wishvel = '0 0 0';

		makevectors(self.angles);
		if(self.BUTTON_JUMP)
			updown = 300;
		else if(self.BUTTON_CROUCH)
			updown = -300;

		if(self.movement)
		{
			forw = self.movement_x * 500;
			rit = self.movement_y * 500;
			//updown = self.movement_z * 100;
			
			wishvel = v_forward * forw + v_right * rit;
		}
		
		//vector wishvel = normalize(('10 0 0' + v_forward * self.movement_x) + ('0 10 0' + v_right * self.movement_y) + ('0 0 1' * self.movement_z));
		//print(vtos(self.origin), vtos(self.origin + wishvel), "\n");
		self.pbhost.monster_moveto = self.origin + wishvel;
		self.pbhost.monster_moveto_z = v_up_z * updown;
	}

	return false;
}

MUTATOR_HOOKFUNCTION(pb_MonsterThink)
{
	if(BROKEN_PBREF(self)) { pb_Detach(self); }
	
	if(!self.pbent)
		pb_FixPBEnt(self);

	return false;
}

MUTATOR_HOOKFUNCTION(pb_ResetMap)
{
	FOR_EACH_PLAYER(self) { pb_Detach(self); }
	return false;
}

MUTATOR_HOOKFUNCTION(pb_RemovePlayer)
{
	if(self.piggybacker)
	{
		self.piggybacker.pb_canattach = 1;
		pb_Detach(self);
	}
	
	if(self.pbhost)
		pb_Detach(self.pbhost);
	self.pb_canattach = 0;

	return false;
}

MUTATOR_HOOKFUNCTION(pb_PlayerDies)
{
	if(!self.pbhost && self.pb_canattach)
		self.pb_canattach = 0;
		
	if(self.piggybacker)
	{
		self.piggybacker.pb_canattach = 1;
		pb_Detach(self);
	}
	
	if(self.pbhost)
		pb_Detach(self.pbhost);
	self.pb_canattach = 0;
	
	return false;
}

MUTATOR_HOOKFUNCTION(pb_ItemTouch)
{
	entity p = other;
	if(self.weapon)
	if(other.piggybacker)
	if(other.weapons & self.weapons)
	{
		p = other;
		while(p.piggybacker)
		{
			p = p.piggybacker;
			if(!(p.weapons & self.weapons))
			{
				other = p;
				break;
			}
		}
	}

	if(self.health || self.armorvalue)
	if(other.piggybacker)
	{
		if(self.health)
		if(other.health > start_health)
		{
			p = other;
			while(p.piggybacker)
			{
				p = p.piggybacker;
				if(p.health < start_health)
				{
					other = p;
					break;
				}
			}
		}

		if(self.armorvalue)
		if(other.armorvalue > 50) // can't use start value here, as players don't start with armor
		{
			p = other;
			while(p.piggybacker)
			{
				p = p.piggybacker;
				if(p.armorvalue < 50)
				{
					other = p;
					break;
				}
			}
		}
	}

	return false;
}

MUTATOR_HOOKFUNCTION(pb_GetCvars)
{
	GetCvars_handleFloat(get_cvars_s, get_cvars_f, cvar_cl_nocarry, "cl_nocarry");
	return false;
}

MUTATOR_DEFINITION(mutator_piggyback)
{
	MUTATOR_HOOK(MatchEnd, pb_MatchEnd, CBC_ORDER_ANY);
	MUTATOR_HOOK(PlayerUseKey, pb_PlayerUseKey, CBC_ORDER_LAST);
	MUTATOR_HOOK(PlayerPreThink, pb_PlayerThink, CBC_ORDER_ANY);
	MUTATOR_HOOK(MonsterMove, pb_MonsterThink, CBC_ORDER_ANY);
	MUTATOR_HOOK(reset_map_players, pb_ResetMap, CBC_ORDER_FIRST);
	MUTATOR_HOOK(MakePlayerObserver, pb_RemovePlayer, CBC_ORDER_ANY);
	MUTATOR_HOOK(ClientDisconnect, pb_RemovePlayer, CBC_ORDER_ANY);
	MUTATOR_HOOK(PlayerDies, pb_PlayerDies, CBC_ORDER_ANY);
	MUTATOR_HOOK(MonsterDies, pb_PlayerDies, CBC_ORDER_ANY);
	MUTATOR_HOOK(MonsterRemove, pb_RemovePlayer, CBC_ORDER_ANY);
	MUTATOR_HOOK(ItemTouch, pb_ItemTouch, CBC_ORDER_ANY);
	MUTATOR_HOOK(GetCvars, pb_GetCvars, CBC_ORDER_ANY);

	return false;
}
