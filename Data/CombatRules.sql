/*
	Gedemon's Civilization Overhaul
	Combat Rules
	Gedemon (2017)
*/
 
/* New Parameters */
--INSERT OR REPLACE INTO GlobalParameters (Name, Value) VALUES ('CSO_VERSION', 'Alpha .1');

-----------------------------------------------
-- Units
-----------------------------------------------

/* # types of units per tile (some checks to prevent more than 1UPT seems harcoded) */
UPDATE GlobalParameters SET Value = 1 WHERE Name = 'PLOT_UNIT_LIMIT';	-- default = 1

/* More units on map */
UPDATE Units SET Cost = Cost * 0.75 WHERE Cost > 1 AND (Domain = 'DOMAIN_LAND' or Domain = 'DOMAIN_SEA') AND NOT FormationClass = 'FORMATION_CLASS_CIVILIAN';
UPDATE Units SET Cost = Cost * 0.85 WHERE Cost > 1 AND (Domain = 'DOMAIN_AIR');
-- Balance : Combat bonus is less required if AI can put twice more units in an area as it already has a production bonus from difficulty
DELETE FROM Modifiers WHERE ModifierId ='HIGH_DIFFICULTY_COMBAT_SCALING'; 

/* AT are ranged support */
UPDATE Units SET Range ='1', PromotionClass ='PROMOTION_CLASS_RANGED' WHERE UnitType = 'UNIT_AT_CREW' OR UnitType = 'UNIT_MODERN_AT';
UPDATE Units SET RangedCombat ='65', Combat ='60' WHERE UnitType = 'UNIT_AT_CREW'; 		-- default Combat = 70
UPDATE Units SET RangedCombat ='75', Combat ='70' WHERE UnitType = 'UNIT_MODERN_AT';	-- default Combat = 80

/* Create new formation classes */
-- Need DLL access to really link FORMATION CLASS to a stacking class ?
INSERT INTO Types (Type, Kind) VALUES ('FORMATION_CLASS_RANGED', 'KIND_FORMATION_CLASS');
INSERT INTO UnitFormationClasses (FormationClassType, Name) VALUES ('FORMATION_CLASS_RANGED', 'Ranged');

INSERT INTO Types (Type, Kind) VALUES ('FORMATION_CLASS_RECON', 'KIND_FORMATION_CLASS');
INSERT INTO UnitFormationClasses (FormationClassType, Name) VALUES ('FORMATION_CLASS_RECON', 'Recon');

/* Apply the new classes (order is important !) */
UPDATE Units SET FormationClass = 'FORMATION_CLASS_RANGED' WHERE (RangedCombat > 0 OR Bombard > 0) AND (Domain = 'DOMAIN_LAND');
UPDATE Units SET FormationClass = 'FORMATION_CLASS_RECON' WHERE PromotionClass = 'PROMOTION_CLASS_RECON' AND Domain = 'DOMAIN_LAND';

/* Apply new AI */
/*
-- to do ?
DELETE FROM UnitAiInfos WHERE UnitType = (SELECT UnitType FROM Units WHERE (RangedCombat > 0 OR Bombard > 0) AND (Domain = 'DOMAIN_LAND'));
*/
UPDATE UnitAiInfos SET AiType ='UNITTYPE_RANGED' WHERE AiType ='UNITTYPE_MELEE' AND (UnitType = 'UNIT_AT_CREW' OR UnitType = 'UNIT_MODERN_AT');

/*
INSERT INTO UnitAiInfos 
(	UnitType, 				AiType) VALUES
(	'UNIT_AMERICAN_P51', 	'UNITTYPE_RANGED'),
(	'UNIT_BIPLANE', 		'UNITTYPE_RANGED'),
(	'UNIT_BOMBER', 			'UNITTYPE_RANGED'),
(	'UNIT_FIGHTER', 		'UNITTYPE_RANGED'),
(	'UNIT_JET_BOMBER', 		'UNITTYPE_RANGED'),
(	'UNIT_JET_FIGHTER', 	'UNITTYPE_RANGED');
*/

/* Range = 1 for all Ranged Land/Sea unit */
UPDATE Units SET Range ='1' WHERE (RangedCombat > 0 OR Bombard > 0) AND (Domain = 'DOMAIN_LAND' OR Domain = 'DOMAIN_SEA');

/* Range = 2 for some units */
UPDATE Units SET Range ='2' WHERE UnitType = 'UNIT_BATTLESHIP' OR UnitType = 'UNIT_BRAZILIAN_MINAS_GERAES';

/* Range = 3 for some units */
UPDATE Units SET Range ='3' WHERE UnitType = 'UNIT_ROCKET_ARTILLERY';

/* Range = 4 for some units */
UPDATE Units SET Range ='4' WHERE UnitType = 'UNIT_MISSILE_CRUISER' OR UnitType = 'UNIT_NUCLEAR_SUBMARINE';

/* Balance */
UPDATE Units SET RangedCombat ='50' WHERE UnitType = 'UNIT_RANGER'; -- default RangedCombat = 60
UPDATE Units SET CanTrain ='0' WHERE UnitType = 'UNIT_OBSERVATION_BALLOON';

/* Air Combat */
UPDATE Districts SET AirSlots = 3 WHERE DistrictType = 'DISTRICT_CITY_CENTER';	-- default = 1
UPDATE Units SET PrereqDistrict = NULL Where PrereqDistrict = "DISTRICT_AERODROME";

UPDATE Units SET BaseSightRange = 3 Where UnitType = "UNIT_BIPLANE";		-- default = 4
UPDATE Units SET BaseSightRange = 4 Where UnitType = "UNIT_FIGHTER";		-- default = 4
UPDATE Units SET BaseSightRange = 4 Where UnitType = "UNIT_AMERICAN_P51";	-- default = 4
UPDATE Units SET BaseSightRange = 4 Where UnitType = "UNIT_BOMBER";			-- default = 4
UPDATE Units SET BaseSightRange = 5 Where UnitType = "UNIT_JET_FIGHTER";	-- default = 2 ???
UPDATE Units SET BaseSightRange = 5 Where UnitType = "UNIT_JET_BOMBER";		-- default = 2 ???

/* Battering Ram and Siege tower upgrades to Military Engineer */
INSERT OR REPLACE INTO UnitUpgrades (Unit, UpgradeUnit) VALUES ('UNIT_BATTERING_RAM','UNIT_MILITARY_ENGINEER');
INSERT OR REPLACE INTO UnitUpgrades (Unit, UpgradeUnit) VALUES ('UNIT_SIEGE_TOWER','UNIT_MILITARY_ENGINEER');
INSERT OR REPLACE INTO TypeTags (Type, Tag)	VALUES ('UNIT_MILITARY_ENGINEER', 'CLASS_SIEGE_TOWER');


-----------------------------------------------
-- Combats
-----------------------------------------------

/* lower damage */
UPDATE GlobalParameters SET Value = 12		WHERE Name = 'COMBAT_BASE_DAMAGE';		-- default = 24
UPDATE GlobalParameters SET Value = 6		WHERE Name = 'COMBAT_MAX_EXTRA_DAMAGE';	-- default = 12

/* remove healing (handled in Lua) */
UPDATE GlobalParameters SET Value = 10		WHERE Name = 'COMBAT_HEAL_CITY_GARRISON';		-- default = 20
UPDATE GlobalParameters SET Value = 5		WHERE Name = 'COMBAT_HEAL_CITY_OUTER_DEFENSES';	-- default = 10
UPDATE GlobalParameters SET Value = 0		WHERE Name = 'COMBAT_HEAL_LAND_ENEMY';			-- default = 5
UPDATE GlobalParameters SET Value = 0		WHERE Name = 'COMBAT_HEAL_LAND_FRIENDLY';		-- default = 15
UPDATE GlobalParameters SET Value = 0		WHERE Name = 'COMBAT_HEAL_LAND_NEUTRAL';		-- default = 10
UPDATE GlobalParameters SET Value = 0		WHERE Name = 'COMBAT_HEAL_NAVAL_ENEMY';			-- default = 0
UPDATE GlobalParameters SET Value = 0		WHERE Name = 'COMBAT_HEAL_NAVAL_FRIENDLY';		-- default = 20
UPDATE GlobalParameters SET Value = 0		WHERE Name = 'COMBAT_HEAL_NAVAL_NEUTRAL';		-- default = 0
UPDATE GlobalParameters SET Value = 0		WHERE Name = 'EXPERIENCE_PROMOTE_HEALED';		-- default = 50
UPDATE GlobalParameters SET Value = 0		WHERE Name = 'EXPERIENCE_RETRAIN_HEALED';		-- default = 100
UPDATE ModifierArguments SET Value = 0 		WHERE ModifierID = 'MEDIC_INCREASE_HEAL_RATE';	-- default = 20

/* Bombard vs Units & Ranged vs Districts */
UPDATE GlobalParameters SET Value = 7		WHERE Name = 'COMBAT_BOMBARD_VS_UNIT_STRENGTH_MODIFIER';	-- default = 17 -- Lower Bombard Combat Strenght vs units by this amount
UPDATE GlobalParameters SET Value = 14		WHERE Name = 'COMBAT_RANGED_VS_DISTRICT_STRENGTH_MODIFIER';	-- default = 17 -- Lower Ranged Combat Strenght vs districts by this amount

-- % of damage against wall:
--"COMBAT_DEFENSE_DAMAGE_PERCENT_BOMBARD","100"
--"COMBAT_DEFENSE_DAMAGE_PERCENT_MELEE","15"
--"COMBAT_DEFENSE_DAMAGE_PERCENT_RANGED","50"


/* Garrison (inner) & Outer Defense */

UPDATE GlobalParameters SET Value = 75		WHERE Name = 'COMBAT_CITY_RANGED_DAMAGE_THRESHOLD';	-- default = 50

UPDATE Districts SET HitPoints = 200 WHERE DistrictType = 'DISTRICT_CITY_CENTER';					-- default = 200
UPDATE ModifierArguments SET Value = 200 WHERE ModifierID = 'CIVIL_ENGINEERING_URBAN_DEFENSES';		-- default = 200

UPDATE Buildings SET OuterDefenseHitPoints = 0 WHERE BuildingType ='BUILDING_PALACE';		-- default = 0
UPDATE Buildings SET OuterDefenseHitPoints = 50 WHERE BuildingType ='BUILDING_WALLS';		-- default = 50
UPDATE Buildings SET OuterDefenseHitPoints = 50 WHERE BuildingType ='BUILDING_CASTLE';		-- default = 50
UPDATE Buildings SET OuterDefenseHitPoints = 50 WHERE BuildingType ='BUILDING_STAR_FORT';	-- default = 50

UPDATE Buildings SET OuterDefenseStrength = 2 WHERE BuildingType ='BUILDING_WALLS';		-- default = 2
UPDATE Buildings SET OuterDefenseStrength = 2 WHERE BuildingType ='BUILDING_CASTLE';	-- default = 2
UPDATE Buildings SET OuterDefenseStrength = 2 WHERE BuildingType ='BUILDING_STAR_FORT';	-- default = 2


-----------------------------------------------
-- Casualties Modifiers
-----------------------------------------------

-- Anti-Personnel (default = 50)
UPDATE Units SET AntiPersonnel = 10 Where UnitType = "UNIT_SCOUT"; 
UPDATE Units SET AntiPersonnel = 25 Where UnitType = "UNIT_SLINGER"; 


-----------------------------------------------
-- Units Requirements
-----------------------------------------------

/* Air */
UPDATE Units SET Personnel = 75, 	Equipment = 75, Materiel = 250, MaterielPerEquipment = 10, FuelConsumptionPerVehicle = 10 Where UnitType = "UNIT_BIPLANE" OR UnitType = "UNIT_FIGHTER" OR UnitType = "UNIT_AMERICAN_P51" OR UnitType = "UNIT_JET_FIGHTER";
UPDATE Units SET Personnel = 160, 	Equipment = 40, Materiel = 400, MaterielPerEquipment = 20, FuelConsumptionPerVehicle = 15 Where UnitType = "UNIT_BOMBER" OR UnitType = "UNIT_JET_BOMBER";

/* Recon */
UPDATE Units SET Personnel = 200, Materiel = 10  Where UnitType = "UNIT_SCOUT" OR UnitType = "UNIT_RANGER";

/* Civilian */
UPDATE Units SET Personnel = 1500,	Materiel = 500	Where UnitType = "UNIT_SETTLER";
UPDATE Units SET Personnel = 300,	Materiel = 300 	Where UnitType = "UNIT_BUILDER";

/* Land Ranged */
UPDATE Units SET Personnel = 1500,	Materiel = 20 	Where UnitType = "UNIT_SLINGER";
UPDATE Units SET Personnel = 2000,	Materiel = 30 	Where UnitType = "UNIT_ARCHER";
UPDATE Units SET Personnel = 2500,	Materiel = 50 	Where UnitType = "UNIT_CROSSBOWMAN";
UPDATE Units SET Personnel = 500, 	Materiel = 200  Where UnitType = "UNIT_AT_CREW" OR UnitType = "UNIT_MACHINE_GUN" OR UnitType = "UNIT_MODERN_AT";
UPDATE Units SET Personnel = 100, 	Materiel = 200  Where UnitType = "UNIT_CATAPULT";
UPDATE Units SET Personnel = 100, 	Materiel = 250  Where UnitType = "UNIT_BOMBARD" OR UnitType = "UNIT_FIELD_CANNON";
UPDATE Units SET Personnel = 100, 	Materiel = 300  Where UnitType = "UNIT_ARTILLERY" OR UnitType = "UNIT_ANTIAIR_GUN";

/* Land infantry */
UPDATE Units SET Personnel = 2000,	Materiel = 30 	Where UnitType = "UNIT_WARRIOR" OR UnitType = "UNIT_AZTEC_EAGLE_WARRIOR";
UPDATE Units SET Personnel = 2500,	Materiel = 40 	Where UnitType = "UNIT_SPEARMAN" OR UnitType = "UNIT_GREEK_HOPLITE";
UPDATE Units SET Personnel = 3000,	Materiel = 75,	Equipment = 50,	EquipmentType = "EQUIPMENT_IRON", 	MaterielPerEquipment = 2 	Where UnitType = "UNIT_SWORDSMAN" OR UnitType= "UNIT_ROMAN_LEGION" OR UnitType= "UNIT_KONGO_SHIELD_BEARER";
UPDATE Units SET Personnel = 4500,	Materiel = 60 	Where UnitType = "UNIT_PIKEMAN";
UPDATE Units SET Personnel = 6000,	Materiel = 60 	Where UnitType = "UNIT_MUSKETMAN" OR UnitType = "UNIT_SPANISH_CONQUISTADOR";
UPDATE Units SET Personnel = 10000,	Materiel = 60 	Where UnitType = "UNIT_INFANTRY";

/* Cavalry */
UPDATE Units SET Personnel = 400,	Materiel = 75, 	Horses = 200, 	Equipment = 100,	EquipmentType = "EQUIPMENT_CHARIOT", 	MaterielPerEquipment = 1	Where UnitType = "UNIT_HEAVY_CHARIOT" or UnitType = "UNIT_EGYPTIAN_CHARIOT_ARCHER";
UPDATE Units SET Personnel = 300,	Materiel = 40, 	Horses = 300 	Where UnitType = "UNIT_BARBARIAN_HORSE_ARCHER";
UPDATE Units SET Personnel = 300,	Materiel = 50, 	Horses = 300 	Where UnitType = "UNIT_HORSEMAN" OR UnitType = "UNIT_BARBARIAN_HORSEMAN";
UPDATE Units SET Personnel = 300,	Materiel = 100, Horses = 300,	Equipment = 300,	EquipmentType = "EQUIPMENT_IRON", 	MaterielPerEquipment = 2 	 	Where UnitType = "UNIT_KNIGHT" OR UnitType = "UNIT_ARABIAN_MAMLUK" OR UnitType = "UNIT_POLISH_HUSSAR";
UPDATE Units SET Personnel = 300,	Materiel = 75, 	Horses = 300 	Where UnitType = "UNIT_CAVALRY" OR UnitType = "UNIT_RUSSIAN_COSSACK";

/* Mechanized */
UPDATE Units SET Personnel = 800, 	Equipment = 200, 	Materiel = 1000, 	MaterielPerEquipment = 10, FuelConsumptionPerVehicle = 5 Where UnitType = "UNIT_TANK" OR UnitType = "UNIT_MODERN_ARMOR";
UPDATE Units SET Personnel = 2500, 	Equipment = 250, 	Materiel = 500, 	MaterielPerEquipment = 5, FuelConsumptionPerVehicle = 1 Where UnitType = "UNIT_MECHANIZED_INFANTRY";
UPDATE Units SET Personnel = 100, 	Equipment = 50,		Materiel = 500, 	MaterielPerEquipment = 10, FuelConsumptionPerVehicle = 3 Where UnitType = "UNIT_ROCKET_ARTILLERY" OR UnitType = "UNIT_MOBILE_SAM";
UPDATE Units SET Personnel = 150, 	Equipment = 75, 	Materiel = 250, 	MaterielPerEquipment = 10, FuelConsumptionPerVehicle = 8 Where UnitType = "UNIT_HELICOPTER";

/* Sea */
UPDATE Units SET Personnel = 200, 	Equipment = 2, 		Materiel = 40,  	MaterielPerEquipment = 25 Where UnitType = "UNIT_BARBARIAN_RAIDER" or UnitType = "UNIT_GALLEY" or UnitType = "UNIT_NORWEGIAN_LONGSHIP";
UPDATE Units SET Personnel = 300, 	Equipment = 2, 		Materiel = 70,  	MaterielPerEquipment = 40 Where UnitType = "UNIT_QUADRIREME";
UPDATE Units SET Personnel = 150, 	Equipment = 3, 		Materiel = 50,  	MaterielPerEquipment = 20 Where UnitType = "UNIT_CARAVEL";
UPDATE Units SET Personnel = 400, 	Equipment = 2, 		Materiel = 100,  	MaterielPerEquipment = 75 Where UnitType = "UNIT_FRIGATE" or UnitType = "UNIT_PRIVATEER" or UnitType = "UNIT_ENGLISH_SEADOG";
UPDATE Units SET Personnel = 150, 	Equipment = 1, 		Materiel = 250,  	MaterielPerEquipment = 300 Where UnitType = "UNIT_IRONCLAD";
UPDATE Units SET Personnel = 2000, 	Equipment = 1, 		Materiel = 5000,  	MaterielPerEquipment = 7500 Where UnitType = "UNIT_BATTLESHIP" or UnitType = "UNIT_BRAZILIAN_MINAS_GERAES";
UPDATE Units SET Personnel = 150, 	Equipment = 3, 		Materiel = 750,  	MaterielPerEquipment = 300 Where UnitType = "UNIT_SUBMARINE" or UnitType = "UNIT_GERMAN_UBOAT";
UPDATE Units SET Personnel = 2500, 	Equipment = 1, 		Materiel = 7500,  	MaterielPerEquipment = 9000 Where UnitType = "UNIT_AIRCRAFT_CARRIER";
UPDATE Units SET Personnel = 250, 	Equipment = 1, 		Materiel = 900,  	MaterielPerEquipment = 1200 Where UnitType = "UNIT_DESTROYER";
UPDATE Units SET Personnel = 400, 	Equipment = 1, 		Materiel = 2000,  	MaterielPerEquipment = 3000 Where UnitType = "UNIT_MISSILE_CRUISER";
