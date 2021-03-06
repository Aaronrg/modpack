#include "particles.qh"

void Draw_PointParticles()
{
	float n, i, fail;
	vector p;
	vector sz;
	vector o;
	o = self.origin;
	sz = self.maxs - self.mins;
	n = BGMScript(self);
	if(self.absolute == 2)
	{
		if(n >= 0)
			n = self.just_toggled ? self.impulse : 0;
		else
			n = self.impulse * drawframetime;
	}
	else
	{
		n *= self.impulse * drawframetime;
		if(self.just_toggled)
			if(n < 1)
				n = 1;
	}
	if(n == 0)
		return;
	fail = 0;
	for(i = random(); i <= n && fail <= 64*n; ++i)
	{
		p = o + self.mins;
		p.x += random() * sz.x;
		p.y += random() * sz.y;
		p.z += random() * sz.z;
		if(WarpZoneLib_BoxTouchesBrush(p, p, self, world))
		{
			if(self.movedir != '0 0 0')
			{
				traceline(p, p + normalize(self.movedir) * 4096, 0, world);
				p = trace_endpos;
				pointparticles(self.cnt, p, trace_plane_normal * vlen(self.movedir) + self.velocity + randomvec() * self.waterlevel, self.count);
			}
			else
			{
				pointparticles(self.cnt, p, self.velocity + randomvec() * self.waterlevel, self.count);
			}
			if(self.noise != "")
			{
				setorigin(self, p);
				sound(self, CH_AMBIENT, self.noise, VOL_BASE * self.volume, self.atten);
			}
			self.just_toggled = 0;
		}
		else if(self.absolute)
		{
			++fail;
			--i;
		}
	}
	setorigin(self, o);
}

void Ent_PointParticles_Remove()
{
	if(self.noise)
		strunzone(self.noise);
	self.noise = string_null;
	if(self.bgmscript)
		strunzone(self.bgmscript);
	self.bgmscript = string_null;
}

void Ent_PointParticles()
{
	float i;
	vector v;
	int f = ReadByte();
	if(f & 2)
	{
		i = ReadCoord(); // density (<0: point, >0: volume)
		if(i && !self.impulse && self.cnt) // self.cnt check is so it only happens if the ent already existed
			self.just_toggled = 1;
		self.impulse = i;
	}
	if(f & 4)
	{
		self.origin_x = ReadCoord();
		self.origin_y = ReadCoord();
		self.origin_z = ReadCoord();
	}
	if(f & 1)
	{
		self.modelindex = ReadShort();
		if(f & 0x80)
		{
			if(self.modelindex)
			{
				self.mins_x = ReadCoord();
				self.mins_y = ReadCoord();
				self.mins_z = ReadCoord();
				self.maxs_x = ReadCoord();
				self.maxs_y = ReadCoord();
				self.maxs_z = ReadCoord();
			}
			else
			{
				self.mins    = '0 0 0';
				self.maxs_x = ReadCoord();
				self.maxs_y = ReadCoord();
				self.maxs_z = ReadCoord();
			}
		}
		else
		{
			self.mins = self.maxs = '0 0 0';
		}

		self.cnt = ReadShort(); // effect number

		if(f & 0x20)
		{
			self.velocity = decompressShortVector(ReadShort());
			self.movedir = decompressShortVector(ReadShort());
		}
		else
		{
			self.velocity = self.movedir = '0 0 0';
		}
		if(f & 0x40)
		{
			self.waterlevel = ReadShort() / 16.0;
			self.count = ReadByte() / 16.0;
		}
		else
		{
			self.waterlevel = 0;
			self.count = 1;
		}
		if(self.noise)
			strunzone(self.noise);
		if(self.bgmscript)
			strunzone(self.bgmscript);
		self.noise = strzone(ReadString());
		if(self.noise != "")
		{
			self.atten = ReadByte() / 64.0;
			self.volume = ReadByte() / 255.0;
		}
		self.bgmscript = strzone(ReadString());
		if(self.bgmscript != "")
		{
			self.bgmscriptattack = ReadByte() / 64.0;
			self.bgmscriptdecay = ReadByte() / 64.0;
			self.bgmscriptsustain = ReadByte() / 255.0;
			self.bgmscriptrelease = ReadByte() / 64.0;
		}
		BGMScript_InitEntity(self);
	}

	if(f & 2)
	{
		self.absolute = (self.impulse >= 0);
		if(!self.absolute)
		{
			v = self.maxs - self.mins;
			self.impulse *= -v.x * v.y * v.z / 262144; // relative: particles per 64^3 cube
		}
	}

	if(f & 0x10)
		self.absolute = 2;

	setorigin(self, self.origin);
	setsize(self, self.mins, self.maxs);
	self.solid = SOLID_NOT;
	self.draw = Draw_PointParticles;
	self.entremove = Ent_PointParticles_Remove;
}

void Draw_Rain()
{
    te_particlerain(self.origin + self.mins, self.origin + self.maxs, self.velocity, floor(self.count * drawframetime + random()), self.glow_color);
}

void Draw_Snow()
{
    te_particlesnow(self.origin + self.mins, self.origin + self.maxs, self.velocity, floor(self.count * drawframetime + random()), self.glow_color);
}

void Ent_RainOrSnow()
{
	self.impulse = ReadByte(); // Rain, Snow, or Whatever
	self.origin_x = ReadCoord();
	self.origin_y = ReadCoord();
	self.origin_z = ReadCoord();
	self.maxs_x = ReadCoord();
	self.maxs_y = ReadCoord();
	self.maxs_z = ReadCoord();
	self.velocity = decompressShortVector(ReadShort());
	self.count = ReadShort() * 10;
	self.glow_color = ReadByte(); // color

	self.mins    = -0.5 * self.maxs;
	self.maxs    =  0.5 * self.maxs;
	self.origin  = self.origin - self.mins;

	setorigin(self, self.origin);
	setsize(self, self.mins, self.maxs);
	self.solid = SOLID_NOT;
	if(self.impulse)
		self.draw = Draw_Rain;
	else
		self.draw = Draw_Snow;
}

void Net_ReadVortexBeamParticle()
{
	vector shotorg, endpos;
	float charge;
	shotorg.x = ReadCoord(); shotorg.y = ReadCoord(); shotorg.z = ReadCoord();
	endpos.x = ReadCoord(); endpos.y = ReadCoord(); endpos.z = ReadCoord();
	charge = ReadByte() / 255.0;

	pointparticles(particleeffectnum("nex_muzzleflash"), shotorg, normalize(endpos - shotorg) * 1000, 1);

	//draw either the old v2.3 beam or the new beam
	charge = sqrt(charge); // divide evenly among trail spacing and alpha
	particles_alphamin = particles_alphamax = particles_fade = charge;

	string s = ((charge >= 0.95 && particleeffectnum("nex_beam_charged") >= 0) ? "nex_beam_charged" : "nex_beam");

	if(autocvar_cl_particles_newvortexbeam && (getstati(STAT_ALLOW_OLDVORTEXBEAM) || isdemo()))
		WarpZone_TrailParticles_WithMultiplier(world, particleeffectnum("nex_beam_new"), shotorg, endpos, 1, PARTICLES_USEALPHA | PARTICLES_USEFADE);
	else if(autocvar_cl_particles_oldvortexbeam && (getstati(STAT_ALLOW_OLDVORTEXBEAM) || isdemo()))
		WarpZone_TrailParticles_WithMultiplier(world, particleeffectnum("TE_TEI_G3NEUTRAL"), shotorg, endpos, 1, PARTICLES_USEALPHA | PARTICLES_USEFADE);
	else
		WarpZone_TrailParticles_WithMultiplier(world, particleeffectnum(s), shotorg, endpos, 1, PARTICLES_USEALPHA | PARTICLES_USEFADE);
}
