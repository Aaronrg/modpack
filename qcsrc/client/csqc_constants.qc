// MenuQC redefines world, change define it here to be safe
#define world world

// Mask Constants (set .drawmask on entities; use R_AddEntities to add all entities based on mask)
const int		MASK_ENGINE						= 1;
const int		MASK_ENGINEVIEWMODELS			= 2;
const int		MASK_NORMAL						= 4;

// Renderflag Constants (used for CSQC entities)
const int		RF_VIEWMODEL					= 1;
const int		RF_EXTERNALMODEL				= 2;
const int		RF_DEPTHHACK					= 4;
const int		RF_ADDITIVE						= 8;
const int		RF_USEAXIS						= 16;

// Viewflag Constants (use with R_SetView)
const int		VF_MIN							= 1;	//(vector)
const int		VF_MIN_X						= 2;	//(float)
const int		VF_MIN_Y						= 3;	//(float)
const int		VF_SIZE							= 4;	//(vector) (viewport size)
const int		VF_SIZE_Y						= 5;	//(float)
const int		VF_SIZE_X						= 6;	//(float)
const int		VF_VIEWPORT						= 7;	//(vector, vector)
const int		VF_FOV							= 8;	//(vector)
const int		VF_FOVX							= 9;	//(float)
const int		VF_FOVY							= 10;	//(float)
const int		VF_ORIGIN						= 11;	//(vector)
const int		VF_ORIGIN_X						= 12;	//(float)
const int		VF_ORIGIN_Y						= 13;	//(float)
const int		VF_ORIGIN_Z						= 14;	//(float)
const int		VF_ANGLES						= 15;	//(vector)
const int		VF_ANGLES_X						= 16;	//(float)
const int		VF_ANGLES_Y						= 17;	//(float)
const int		VF_ANGLES_Z						= 18;	//(float)
const int		VF_DRAWWORLD					= 19;	//(float)
const int		VF_DRAWENGINEHUD				= 20;	//(float)
const int		VF_DRAWCROSSHAIR				= 21;	//(float)
const int		VF_PERSPECTIVE					= 200;	//(float)

const int		VF_CL_VIEWANGLES				= 33;	//(vector)
const int		VF_CL_VIEWANGLES_X				= 34;	//(float)
const int		VF_CL_VIEWANGLES_Y				= 35;	//(float)
const int		VF_CL_VIEWANGLES_Z				= 36;	//(float)

// Quake-style Point Contents
const int		CONTENT_EMPTY					= -1;
const int		CONTENT_SOLID					= -2;
const int		CONTENT_WATER					= -3;
const int		CONTENT_SLIME					= -4;
const int		CONTENT_LAVA					= -5;
const int		CONTENT_SKY						= -6;

// Vector / Hull Constants
const vector	VEC_1							= '1 1 1';
const vector	VEC_0							= '0 0 0';
const vector	VEC_M1							= '-1 -1 -1';

const vector	VEC_HULL_MIN 					= '-16 -16 -24';
const vector	VEC_HULL_MAX 					= '16 16 32';

// Effect Constants
const int 	EF_NODRAW						= 16;
const int 	EF_ADDITIVE						= 32;
const int 	EF_BLUE							= 64;
const int 	EF_RED							= 128;
const int 	EF_FULLBRIGHT					= 512;
const int 	EF_FLAME						= 1024;
const int 	EF_STARDUST						= 2048;
const int 	EF_NOSHADOW						= 4096;
const int 	EF_NODEPTHTEST					= 8192;

// Quake Player Flag Constants
const int 	PFL_ONGROUND					= 1;
const int 	PFL_CROUCH						= 2;
const int 	PFL_DEAD						= 4;
const int 	PFL_GIBBED						= 8;

// Quake Temporary Entity Constants
const int		TE_SPIKE						= 0;
const int		TE_SUPERSPIKE					= 1;
const int		TE_GUNSHOT						= 2;
const int		TE_EXPLOSION					= 3;
const int		TE_TAREXPLOSION					= 4;
const int		TE_LIGHTNING1					= 5;
const int		TE_LIGHTNING2					= 6;
const int		TE_WIZSPIKE						= 7;
const int		TE_KNIGHTSPIKE					= 8;
const int		TE_LIGHTNING3					= 9;
const int		TE_LAVASPLASH					= 10;
const int		TE_TELEPORT						= 11;
const int 	TE_EXPLOSION2					= 12;
// Darkplaces Additions
const int 	TE_EXPLOSIONRGB					= 53;
const int		TE_GUNSHOTQUAD					= 57;
const int		TE_EXPLOSIONQUAD 				= 70;

// Math Constants
const int 	EXTRA_LOW 						= -99999999;
const int 	EXTRA_HIGH 						= 99999999;

// Frik File Constants
const int		FILE_READ						= 0;
const int		FILE_APPEND						= 1;
const int		FILE_WRITE						= 2;

// Button values used by input_buttons
const int BUTTON_ATTACK = 1;
const int BUTTON_JUMP = 2;
const int BUTTON_3 = 4;
const int BUTTON_4 = 8;
const int BUTTON_5 = 16;
const int BUTTON_6 = 32;
const int BUTTON7 = 64;
const int BUTTON8 = 128;
const int BUTTON_USE = 256;
const int BUTTON_CHAT = 512;
const int BUTTON_PRYDONCURSOR = 1024;
const int BUTTON_9 = 2048;
const int BUTTON_10 = 4096;
const int BUTTON_11 = 8192;
const int BUTTON_12 = 16384;
const int BUTTON_13 = 32768;
const int BUTTON_14 = 65536;
const int BUTTON_15 = 131072;
const int BUTTON_16 = 262144;

const int SOLID_NOT 		= 0; // no interaction with other objects
const int SOLID_TRIGGER 	= 1; // touch on edge, but not blocking
const int SOLID_BBOX 		= 2; // touch on edge, block
const int SOLID_SLIDEBOX 	= 3; // touch on edge, but not an onground
const int SOLID_BSP 		= 4; // bsp clip, touch on edge, block
const int SOLID_CORPSE 	= 5; // same as SOLID_BBOX, except it behaves as SOLID_NOT against SOLID_SLIDEBOX objects (players/monsters)

const int MOVE_NORMAL = 0; // same as false
const int MOVE_NOMONSTERS = 1; // same as true
const int MOVE_MISSILE = 2; // save as movement with .movetype == MOVETYPE_FLYMISSILE
const int MOVE_HITMODEL = 4;
const int MOVE_WORLDONLY = 3;

const int CAMERA_FREE = 1;
const int CAMERA_CHASE = 2;

const int EF_NOMODELFLAGS = 8388608;
