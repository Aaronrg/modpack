#if defined(CSQC)
#elif defined(MENUQC)
#elif defined(SVQC)
	#include "../../dpdefs/progsdefs.qh"
    #include "../../dpdefs/dpextensions.qh"
    #include "../../common/weapons/weapons.qh"
    #include "hitplot.qh"
    #include "../autocvars.qh"
    #include "../defs.qh"
    #include "../antilag.qh"
#endif

vector W_HitPlotUnnormalizedUntransform(vector screenforward, vector screenright, vector screenup, vector v)
{
	vector ret;
	ret.x = screenright * v;
	ret.y = screenup * v;
	ret.z = screenforward * v;
	return ret;
}

vector W_HitPlotNormalizedUntransform(vector org, entity targ, vector screenforward, vector screenright, vector screenup, vector v)
{
	float i, j, k;
	vector mi, ma, thisv, myv, ret;

	myv = W_HitPlotUnnormalizedUntransform(screenforward, screenright, screenup, org);

	// x = 0..1 relative to hitbox; y = 0..1 relative to hitbox; z = distance

	mi = ma = targ.origin + 0.5 * (targ.mins + targ.maxs);
	for(i = 0; i < 2; ++i) for(j = 0; j < 2; ++j) for(k = 0; k < 2; ++k)
	{
		thisv = targ.origin;
		if(i) thisv.x += targ.maxs.x; else thisv.x += targ.mins.x;
		if(j) thisv.y += targ.maxs.y; else thisv.y += targ.mins.y;
		if(k) thisv.z += targ.maxs.z; else thisv.z += targ.mins.z;
		thisv = W_HitPlotUnnormalizedUntransform(screenforward, screenright, screenup, thisv);
		if(i || j || k)
		{
			if(mi.x > thisv.x) mi.x = thisv.x; if(ma.x < thisv.x) ma.x = thisv.x;
			if(mi.y > thisv.y) mi.y = thisv.y; if(ma.y < thisv.y) ma.y = thisv.y;
			//if(mi_z > thisv_z) mi_z = thisv_z; if(ma_z < thisv_z) ma_y = thisv_z;
		}
		else
		{
			// first run
			mi = ma = thisv;
		}
	}

	thisv = W_HitPlotUnnormalizedUntransform(screenforward, screenright, screenup, v);
	ret.x = (thisv.x - mi.x) / (ma.x - mi.x);
	ret.y = (thisv.y - mi.y) / (ma.y - mi.y);
	ret.z = thisv.z - myv.z;
	return ret;
}

void W_HitPlotAnalysis(entity player, vector screenforward, vector screenright, vector screenup)
{
	vector hitplot;
	vector org;
	float lag;

	if(player.hitplotfh >= 0)
	{
		lag = ANTILAG_LATENCY(player);
		if(lag < 0.001)
			lag = 0;
		if(!IS_REAL_CLIENT(player))
			lag = 0; // only antilag for clients

		org = player.origin + player.view_ofs;
		traceline_antilag_force(player, org, org + screenforward * MAX_SHOT_DISTANCE, MOVE_NORMAL, player, lag);
		if(IS_CLIENT(trace_ent) || IS_MONSTER(trace_ent))
		{
			antilag_takeback(trace_ent, time - lag);
			hitplot = W_HitPlotNormalizedUntransform(org, trace_ent, screenforward, screenright, screenup, trace_endpos);
			antilag_restore(trace_ent);
			fputs(player.hitplotfh, strcat(ftos(hitplot.x), " ", ftos(hitplot.y), " ", ftos(hitplot.z), " ", ftos(player.switchweapon), "\n"));
			//print(strcat(ftos(hitplot_x), " ", ftos(hitplot_y), " ", ftos(hitplot_z), "\n"));
		}
	}
}

void W_HitPlotOpen(entity player)
{
	if(autocvar_g_hitplots || strstrofs(strcat(" ", autocvar_g_hitplots_individuals, " "), strcat(" ", player.netaddress, " "), 0) >= 0)
	{
		player.hitplotfh = fopen(strcat("hits-", matchid, "-", player.netaddress, "-", ftos(player.playerid), ".plot"), FILE_WRITE);
		fputs(player.hitplotfh, strcat("#name ", player.netname, "\n"));
	}
	else { player.hitplotfh = -1; }
}

void W_HitPlotClose(entity player)
{
	if(player.hitplotfh >= 0)
	{
		fclose(player.hitplotfh);
		player.hitplotfh = -1;
	}
}
