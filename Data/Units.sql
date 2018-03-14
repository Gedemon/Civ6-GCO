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
UPDATE Units SET Personnel = 75 	Where UnitType = "UNIT_BIPLANE" OR UnitType = "UNIT_FIGHTER" OR UnitType = "UNIT_AMERICAN_P51" OR UnitType = "UNIT_JET_FIGHTER";
UPDATE Units SET Personnel = 160 	Where UnitType = "UNIT_BOMBER" OR UnitType = "UNIT_JET_BOMBER";
                                    
/* Recon */                         
UPDATE Units SET Personnel = 200 	Where UnitType = "UNIT_SCOUT";
UPDATE Units SET Personnel = 200, 	PrereqTech = NULL  Where UnitType = "UNIT_RANGER";
                                    
/* Civilian */                      
UPDATE Units SET Personnel = 1500	Where UnitType = "UNIT_SETTLER";
UPDATE Units SET Personnel = 300	Where UnitType = "UNIT_BUILDER";

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
UPDATE Units SET Personnel = 400, 	PrereqTech = NULL 	Where UnitType = "UNIT_MISSILE_CRUISER";

/* Moar Units */
UPDATE Units SET PrereqTech = NULL 	Where UnitType = "UNIT_LONGBOWMAN";
UPDATE Units SET PrereqTech = NULL 	Where UnitType = "UNIT_TREBUCHET";
UPDATE Units SET PrereqTech = NULL 	Where UnitType = "UNIT_MEDIEVAL_HORSEMAN";
UPDATE Units SET PrereqTech = NULL 	Where UnitType = "UNIT_MACEMAN";
UPDATE Units SET PrereqTech = NULL 	Where UnitType = "UNIT_EXPLORER";
UPDATE Units SET PrereqTech = NULL 	Where UnitType = "UNIT_TERCIO";
UPDATE Units SET PrereqTech = NULL 	Where UnitType = "UNIT_RIFLEMAN";
UPDATE Units SET PrereqTech = NULL 	Where UnitType = "UNIT_CUIRASSIER";
UPDATE Units SET PrereqTech = NULL 	Where UnitType = "UNIT_SNIPER";
UPDATE Units SET PrereqTech = NULL 	Where UnitType = "UNIT_MODERN_SNIPER";
