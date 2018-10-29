/*
	GCO
	Units
	Gedemon (2018)
*/
 


-----------------------------------------------
-- Casualties Modifiers
-----------------------------------------------

-- Anti-Personnel (default = 50)
--UPDATE Units SET AntiPersonnel = 10 Where UnitType = "UNIT_SCOUT"; 
--UPDATE Units SET AntiPersonnel = 25 Where UnitType = "UNIT_SLINGER"; 


-----------------------------------------------
-- Units Requirements
-----------------------------------------------


/* no civ-specific units */
UPDATE Units SET TraitType = NULL WHERE TraitType != 'TRAIT_BARBARIAN';

DELETE FROM UnitReplaces;

/* Air */
UPDATE Units SET Personnel = 75, 	PrereqTech = NULL 	Where UnitType = "UNIT_BIPLANE" OR UnitType = "UNIT_FIGHTER" OR UnitType = "UNIT_AMERICAN_P51" OR UnitType = "UNIT_JET_FIGHTER";
UPDATE Units SET Personnel = 160, 	PrereqTech = NULL 	Where UnitType = "UNIT_BOMBER" OR UnitType = "UNIT_JET_BOMBER";
                                    
/* Recon */                         
UPDATE Units SET Personnel = 200 	Where UnitType = "UNIT_SCOUT";
UPDATE Units SET Personnel = 200, 	PrereqTech = NULL  Where UnitType = "UNIT_RANGER";
                                    
/* Civilian */                      
--UPDATE Units SET Personnel = 1500	Where UnitType = "UNIT_SETTLER";
--UPDATE Units SET Personnel = 300	Where UnitType = "UNIT_BUILDER";

/* Land Ranged */
UPDATE Units SET Personnel = 500	Where UnitType = "UNIT_SLINGER";
UPDATE Units SET Personnel = 600,	PrereqTech = NULL 	Where UnitType = "UNIT_ARCHER";
UPDATE Units SET Personnel = 1200,	PrereqTech = NULL 	Where UnitType = "UNIT_CROSSBOWMAN";
UPDATE Units SET Personnel = 500 	Where UnitType = "UNIT_AT_CREW" OR UnitType = "UNIT_MACHINE_GUN" OR UnitType = "UNIT_MODERN_AT";
UPDATE Units SET Personnel = 100, 	PrereqTech = NULL  Where UnitType = "UNIT_CATAPULT";
UPDATE Units SET Personnel = 100, 	PrereqTech = NULL  Where UnitType = "UNIT_BOMBARD" OR UnitType = "UNIT_FIELD_CANNON";
UPDATE Units SET Personnel = 100, 	PrereqTech = NULL  Where UnitType = "UNIT_ARTILLERY";
UPDATE Units SET Personnel = 100 	Where UnitType = "UNIT_ANTIAIR_GUN";

/* Land infantry */
UPDATE Units SET Personnel = 800	Where UnitType = "UNIT_WARRIOR" OR UnitType = "UNIT_AZTEC_EAGLE_WARRIOR";
UPDATE Units SET Personnel = 900,	PrereqTech = NULL 	Where UnitType = "UNIT_SPEARMAN" OR UnitType = "UNIT_GREEK_HOPLITE";
UPDATE Units SET Personnel = 1000,	PrereqTech = NULL	Where UnitType = "UNIT_SWORDSMAN" OR UnitType= "UNIT_ROMAN_LEGION" OR UnitType= "UNIT_KONGO_SHIELD_BEARER";
UPDATE Units SET Personnel = 2000,	PrereqTech = NULL 	Where UnitType = "UNIT_PIKEMAN";
UPDATE Units SET Personnel = 4000,	PrereqTech = NULL 	Where UnitType = "UNIT_MUSKETMAN" OR UnitType = "UNIT_SPANISH_CONQUISTADOR";
UPDATE Units SET Personnel = 10000,	PrereqTech = NULL 	Where UnitType = "UNIT_INFANTRY";

/* Cavalry */
UPDATE Units SET Personnel = 400,	PrereqTech = NULL 	Where UnitType = "UNIT_HEAVY_CHARIOT" or UnitType = "UNIT_EGYPTIAN_CHARIOT_ARCHER";
UPDATE Units SET Personnel = 300	Where UnitType = "UNIT_BARBARIAN_HORSE_ARCHER";
UPDATE Units SET Personnel = 300,	PrereqTech = NULL 	Where UnitType = "UNIT_HORSEMAN" OR UnitType = "UNIT_BARBARIAN_HORSEMAN";
UPDATE Units SET Personnel = 300,	PrereqTech = NULL 	Where UnitType = "UNIT_KNIGHT" OR UnitType = "UNIT_ARABIAN_MAMLUK" OR UnitType = "UNIT_POLISH_HUSSAR";
UPDATE Units SET Personnel = 300,	PrereqTech = NULL 	Where UnitType = "UNIT_CAVALRY" OR UnitType = "UNIT_RUSSIAN_COSSACK";

/* Mechanized */
UPDATE Units SET Personnel = 800, 	PrereqTech = NULL 	Where UnitType = "UNIT_TANK" OR UnitType = "UNIT_MODERN_ARMOR";
UPDATE Units SET Personnel = 2500 	Where UnitType = "UNIT_MECHANIZED_INFANTRY";
UPDATE Units SET Personnel = 100, 	PrereqTech = NULL 	Where UnitType = "UNIT_ROCKET_ARTILLERY";
UPDATE Units SET Personnel = 100	Where UnitType = "UNIT_MOBILE_SAM";
UPDATE Units SET Personnel = 150 	Where UnitType = "UNIT_HELICOPTER";

/* Sea */

UPDATE Units SET Personnel = 200 	Where UnitType = "UNIT_BARBARIAN_RAIDER" or UnitType = "UNIT_NORWEGIAN_LONGSHIP";
UPDATE Units SET Personnel = 200, 	PrereqTech = NULL 	Where UnitType = "UNIT_GALLEY";
UPDATE Units SET Personnel = 300, 	PrereqTech = NULL 	Where UnitType = "UNIT_QUADRIREME";
UPDATE Units SET Personnel = 150, 	PrereqTech = NULL 	Where UnitType = "UNIT_CARAVEL";
UPDATE Units SET Personnel = 400, 	PrereqTech = NULL	Where UnitType = "UNIT_FRIGATE";
UPDATE Units SET Personnel = 400, 	PrereqCivic = NULL 	Where UnitType = "UNIT_PRIVATEER" or UnitType = "UNIT_ENGLISH_SEADOG";
UPDATE Units SET Personnel = 150, 	PrereqTech = NULL 	Where UnitType = "UNIT_IRONCLAD";
UPDATE Units SET Personnel = 2000, 	PrereqTech = NULL 	Where UnitType = "UNIT_BATTLESHIP";
UPDATE Units SET Personnel = 2000, 	Combat=55, RangedCombat = 60, PrereqCivic=NULL, PrereqTech = NULL  Where UnitType = "UNIT_BRAZILIAN_MINAS_GERAES";
UPDATE Units SET Personnel = 150, 	PrereqTech = NULL 	Where UnitType = "UNIT_SUBMARINE" or UnitType = "UNIT_GERMAN_UBOAT";
UPDATE Units SET Personnel = 2500, 	PrereqTech = NULL 	Where UnitType = "UNIT_AIRCRAFT_CARRIER";
UPDATE Units SET Personnel = 250, 	PrereqTech = NULL 	Where UnitType = "UNIT_DESTROYER";
UPDATE Units SET Personnel = 250, 	PrereqTech = NULL 	Where UnitType = "UNIT_NUCLEAR_SUBMARINE";
UPDATE Units SET Personnel = 400, 	PrereqTech = NULL 	Where UnitType = "UNIT_MISSILE_CRUISER";

/* Moar Units */
UPDATE Units SET PrereqTech = NULL 	Where UnitType = "UNIT_LONGBOWMAN";
UPDATE Units SET PrereqTech = NULL 	Where UnitType = "UNIT_PELTAST";
UPDATE Units SET PrereqTech = NULL 	Where UnitType = "UNIT_PHALANX";
UPDATE Units SET PrereqTech = NULL 	Where UnitType = "UNIT_LANDSKNECHT";
UPDATE Units SET PrereqTech = NULL 	Where UnitType = "UNIT_TREBUCHET";
UPDATE Units SET PrereqTech = NULL 	Where UnitType = "UNIT_MEDIEVAL_HORSEMAN";
UPDATE Units SET PrereqTech = NULL 	Where UnitType = "UNIT_MACEMAN";
UPDATE Units SET PrereqTech = NULL 	Where UnitType = "UNIT_EXPLORER";
UPDATE Units SET PrereqTech = NULL 	Where UnitType = "UNIT_TERCIO";
UPDATE Units SET PrereqTech = NULL 	Where UnitType = "UNIT_RIFLEMAN";
UPDATE Units SET PrereqTech = NULL 	Where UnitType = "UNIT_CUIRASSIER";
UPDATE Units SET PrereqTech = NULL 	Where UnitType = "UNIT_SNIPER";
UPDATE Units SET PrereqTech = NULL 	Where UnitType = "UNIT_MODERN_SNIPER";

/* Unit Table (Short Names) */
INSERT INTO UnitsShort
--
--																			AntiAirCombat	Stackable			CanCapture															ADVISOR_	YIELD_	PSEUDOYIELD_UNIT_
--								Cost		Combat	RangedCombat	CanTargetAir		IgnoreMoves		ZoneOfControl		DOMAIN_	FORMATION_CLASS_					DISTRICT_	AdvisorType			PseudoYieldType
--	'UNIT_'					BaseMoves	Maintenance	|	Range	Bombard		|	AirSlots			BaseSightRange	WMDCapable						PROMOTION_CLASS_	PrereqDistrict			PurchaseYield
	(UnitType,				BM,	Cs,		Mt,	Cb,		RC,	Rg,		Bd,	CTA,	AAC,AiS,	IM,	Stk,	SR,	ZOC,	Cpt,WMD,	Domain,	FormationClass,	PromotionClass,		District,	Advisor,	PurYld,	PsYld			)
VALUES                              	        	        	        	        	        	        	        	                
	('MOTORISED_INFANTRY',	4,	540,	7,	78,		0,	0,		0,	'0',	0,	0,		'0','0',	2,	'1',	'1','0',	'LAND',	'LAND_COMBAT',	'MELEE',			null,		'CONQUEST',	'GOLD',	null			),
	('COMPOSITE_BOWMAN',	2,	85,		2,	22,		32,	2,		0,	'0',	0,	0,		'0','0',	2,	'0',	'1','0',	'LAND',	'LAND_COMBAT',	'RANGED',			null,		'CONQUEST',	'GOLD',	null			),
	('CULVERIN',			2,	230,	4,	40,		50,	2,		0,	'0',	0,	0,		'0','0',	2,	'0',	'1','0',	'LAND',	'LAND_COMBAT',	'RANGED',			null,		'CONQUEST',	'GOLD',	null			),
	('FIELD_GUN',			2,	420,	6,	58,		68,	2,		0,	'0',	0,	0,		'0','0',	2,	'0',	'1','0',	'LAND',	'LAND_COMBAT',	'RANGED',			null,		'CONQUEST',	'GOLD',	null			),
	('ASSAULT_GUN',			4,	530,	7,	65,		75,	2,		0,	'0',	0,	0,		'0','0',	2,	'0',	'1','0',	'LAND',	'LAND_COMBAT',	'RANGED',			null,		'CONQUEST',	'GOLD',	null			),
	('SP_GUN',				4,	640,	8,	72,		82,	2,		0,	'0',	0,	0,		'0','0',	2,	'0',	'1','0',	'LAND',	'LAND_COMBAT',	'RANGED',			null,		'CONQUEST',	'GOLD',	null			),
	('HEAVY_INFANTRY',		2,	95,		2,	33,		0,	0,		0,	'0',	0,	0,		'0','0',	2,	'1',	'1','0',	'LAND',	'LAND_COMBAT',	'ANTI_CAVALRY',		null,		'CONQUEST',	'GOLD',	null			),
	('TANK_DESTROYER',		4,	490,	6,	76,		0,	0,		0,	'0',	0,	0,		'0','0',	2,	'1',	'1','0',	'LAND',	'LAND_COMBAT',	'ANTI_CAVALRY',		null,		'CONQUEST',	'GOLD',	null			),
	('LANCER',				5,	210,	3,	53,		0,	0,		0,	'0',	0,	0,		'0','0',	2,	'1',	'1','0',	'LAND',	'LAND_COMBAT',	'LIGHT_CAVALRY',	null,		'CONQUEST',	'GOLD',	null			),
	('ARMORED_CAVALRY',		5,	390,	5,	68,		0,	0,		0,	'0',	0,	0,		'0','0',	2,	'1',	'1','0',	'LAND',	'LAND_COMBAT',	'LIGHT_CAVALRY',	null,		'CONQUEST',	'GOLD',	null			),
	('GUNSHIP',				4,	600,	7,	82,		0,	0,		0,	'1',	0,	0,		'0','0',	2,	'0',	'1','0',	'LAND',	'LAND_COMBAT',	'LIGHT_CAVALRY',	null,		'CONQUEST',	'GOLD',	null			),
	('ARMORED_HORSEMAN',	4,	100,	2,	40,		0,	0,		0,	'0',	0,	0,		'0','0',	2,	'1',	'1','0',	'LAND',	'LAND_COMBAT',	'HEAVY_CAVALRY',	null,		'CONQUEST',	'GOLD',	null			),
	('REITER',				4,	240,	4,	58,		0,	0,		0,	'0',	0,	0,		'0','0',	2,	'1',	'1','0',	'LAND',	'LAND_COMBAT',	'HEAVY_CAVALRY',	null,		'CONQUEST',	'GOLD',	null			),
	('LANDSHIP',			4,	420,	6,	73,		0,	0,		0,	'0',	0,	0,		'0','0',	2,	'1',	'1','0',	'LAND',	'LAND_COMBAT',	'HEAVY_CAVALRY',	null,		'CONQUEST',	'GOLD',	null			),
	('WW1_BOMBER',			7,	450,	6,	50,		0,	7,		70,	'1',	0,	0,		'1','1',	4,	'0',	'0','0',	'AIR',	'AIR',			'AIR_BOMBER',		'AERODROME','CONQUEST',	'GOLD',	'AIR_COMBAT'	),
	('STEALTH_BOMBER',		15,	720,	8,	70,		0,	15,		100,'1',	0,	0,		'1','1',	5,	'0',	'0','1',	'AIR',	'AIR',			'AIR_BOMBER',		'AERODROME','CONQUEST',	'GOLD',	'AIR_COMBAT'	),
	('STEALTH_FIGHTER',		10,	670,	8,	90,		85,	10,		0,	'1',	0,	0,		'1','1',	5,	'0',	'0','0',	'AIR',	'AIR',			'AIR_FIGHTER',		'AERODROME','CONQUEST',	'GOLD',	'AIR_COMBAT'	),
	('WW1_GROUND_ATTACK',	5,	440,	6,	55,		60,	5,		0,	'1',	0,	0,		'1','1',	4,	'0',	'0','0',	'AIR',	'AIR',			'AIR_ATTACK',		'AERODROME','CONQUEST',	'GOLD',	'AIR_COMBAT'	),
	('GROUND_ATTACK',		8,	540,	7,	72,		85,	8,		0,	'1',	0,	0,		'1','1',	4,	'0',	'0','0',	'AIR',	'AIR',			'AIR_ATTACK',		'AERODROME','CONQUEST',	'GOLD',	'AIR_COMBAT'	),
	('JET_GROUND_ATTACK',	10,	675,	8,	85,		90,	10,		0,	'1',	0,	0,		'1','1',	5,	'0',	'0','0',	'AIR',	'AIR',			'AIR_ATTACK',		'AERODROME','CONQUEST',	'GOLD',	'AIR_COMBAT'	),
	('STEALTH_ATTACK',		10,	700,	8,	85,		95,	10,		0,	'1',	0,	0,		'1','1',	5,	'0',	'0','1',	'AIR',	'AIR',			'AIR_ATTACK',		'AERODROME','CONQUEST',	'GOLD',	'AIR_COMBAT'	),
	('CORVETTE',			4,	260,	4,	50,		0,	0,		0,	'0',	0,	0,		'0','0',	3,	'1',	'1','0',	'SEA',	'NAVAL',		'NAVAL_MELEE',		null,		'CONQUEST',	'GOLD',	'NAVAL_COMBAT'  ),
	('MISSILE_DESTROYER',	5,	660,	8,	90,		0,	0,		0,	'1',	85,	0,		'0','0',	3,	'1',	'1','0',	'SEA',	'NAVAL',		'NAVAL_MELEE',		null,		'CONQUEST',	'GOLD',	'NAVAL_COMBAT'	),
	('SUPERCARRIER',		5,	680,	8,	80,		0,	0,		0,	'0',	0,	5,		'0','0',	2,	'1',	'1','0',	'SEA',	'NAVAL',		'NAVAL_CARRIER',	null,		'CONQUEST',	'GOLD',	'NAVAL_COMBAT'	),
	('GALLEASS',			4,	240,	3,	35,		45,	2,		0,	'0',	0,	0,		'0','0',	2,	'1',	'1','0',	'SEA',	'NAVAL',		'NAVAL_RANGED',		null,		'CONQUEST',	'GOLD',	'NAVAL_COMBAT'	),
	('ARMORED_CRUISER',		5,	400,	5,	55,		65,	2,		0,	'0',	0,	0,		'0','0',	2,	'1',	'1','0',	'SEA',	'NAVAL',		'NAVAL_RANGED',		null,		'CONQUEST',	'GOLD',	'NAVAL_COMBAT'	),
	('BATTLECRUISER',		5,	560,	6,	65,		75,	2,		0,	'1',	75,	0,		'0','0',	2,	'1',	'1','0',	'SEA',	'NAVAL',		'NAVAL_RANGED',		null,		'CONQUEST',	'GOLD',	'NAVAL_COMBAT'	),
	('GALLEON',				3,	280,	4,	40,		0,	3,		50,	'0',	0,	0,		'0','0',	2,	'1',	'1','0',	'SEA',	'NAVAL',		'NAVAL_BOMBARD',	null,		'CONQUEST',	'GOLD',	'NAVAL_COMBAT'	),
	('SHIP_OF_THE_LINE',	3,	320,	4,	50,		0,	3,		60,	'0',	0,	0,		'0','0',	2,	'1',	'1','0',	'SEA',	'NAVAL',		'NAVAL_BOMBARD',	null,		'CONQUEST',	'GOLD',	'NAVAL_COMBAT'	),
	('PRE_DREADNOUGHT',		4,	440,	5,	60,		0,	3,		70,	'0',	0,	0,		'0','0',	2,	'1',	'1','0',	'SEA',	'NAVAL',		'NAVAL_BOMBARD',	null,		'CONQUEST',	'GOLD',	'NAVAL_COMBAT'	),
	('ATTACK_SUBMARINE',	4,	680,	8,	85,		0,	0,		0,	'0',	0,	0,		'0','0',	2,	'0',	'1','0',	'SEA',	'NAVAL',		'NAVAL_MELEE',		null,		'CONQUEST',	'GOLD',	'NAVAL_COMBAT'	),
	('INDUSTRIAL_MARINE',	2,	350,	3,	61,		0,	0,		0,	'0',	0,	0,		'0','0',	2,	'1',	'1','0',	'LAND',	'LAND_COMBAT',	'MARINE',			null,		'CONQUEST',	'GOLD',	null			),
	('WW2_MARINE',			2,	430,	5,	67,		0,	0,		0,	'0',	0,	0,		'0','0',	2,	'1',	'1','0',	'LAND',	'LAND_COMBAT',	'MARINE',			null,		'CONQUEST',	'GOLD',	null			),
	('MODERN_MARINE',		4,	650,	7,	82,		0,	0,		0,	'0',	0,	0,		'0','0',	2,	'1',	'1','0',	'LAND',	'LAND_COMBAT',	'MARINE',			null,		'CONQUEST',	'GOLD',	null			),
	('FIELD_HOWITZER',		2,	360,	5,	53,		0,	2,		65,	'0',	0,	0,		'0','0',	2,	'0',	'1','0',	'LAND',	'LAND_COMBAT',	'SIEGE',			null,		'CONQUEST',	'GOLD',	null			),
	('SP_HVY_ATILLERY',		3,	560,	7,	72,		0,	3,		88,	'0',	0,	0,		'0','0',	2,	'0',	'1','0',	'LAND',	'LAND_COMBAT',	'SIEGE',			null,		'CONQUEST',	'GOLD',	null			),
	('UAV',					4,	700,	7,	60,		80,	1,		0,	'1',	0,	0,		'0','0',	5,	'0',	'1','0',	'LAND',	'LAND_COMBAT',	'RANGED',			null,		'CONQUEST',	'GOLD',	null			),
	('END_OF_INSERT',		null, null,	null, null, null, null, null, null, null, null, null, null, null, null, null, null, null,	null,			null,				null,		null,		null,	null			);

-- Remove "END_OF_INSERT" entry 
DELETE from UnitsShort WHERE UnitType ='END_OF_INSERT';