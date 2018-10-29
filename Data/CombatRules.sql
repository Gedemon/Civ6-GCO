/*
	Gedemon's Civilization Overhaul
	Combat Rules
	Gedemon (2017)
*/
 
/* New Parameters */
INSERT OR REPLACE INTO GlobalParameters (Name, Value) VALUES ('CSO_VERSION', 'Preview .2');

-----------------------------------------------
-- Units
-----------------------------------------------

/* # types of units per tile (some checks to prevent more than 1UPT seems harcoded) */
UPDATE GlobalParameters SET Value = 1 WHERE Name = 'PLOT_UNIT_LIMIT';	-- default = 1

-- Balance : Combat bonus is less required if AI can put twice more units in an area as it already has a production bonus from difficulty
DELETE FROM Modifiers WHERE ModifierId ='HIGH_DIFFICULTY_COMBAT_SCALING'; 

/* AT are ranged support */
UPDATE Units SET Range ='1', PromotionClass ='PROMOTION_CLASS_RANGED' WHERE UnitType = 'UNIT_AT_CREW' OR UnitType = 'UNIT_MODERN_AT';
UPDATE Units SET RangedCombat ='65', Combat ='60' WHERE UnitType = 'UNIT_AT_CREW'; 		-- default Combat = 70
UPDATE Units SET RangedCombat ='75', Combat ='70' WHERE UnitType = 'UNIT_MODERN_AT';	-- default Combat = 80

/* Create new formation classes */
-- Need DLL access to really link FORMATION CLASS to a stacking class ?
INSERT OR REPLACE INTO Types (Type, Kind) VALUES ('FORMATION_CLASS_RANGED', 'KIND_FORMATION_CLASS');
INSERT OR REPLACE INTO UnitFormationClasses (FormationClassType, Name) VALUES ('FORMATION_CLASS_RANGED', 'Ranged');

INSERT OR REPLACE INTO Types (Type, Kind) VALUES ('FORMATION_CLASS_RECON', 'KIND_FORMATION_CLASS');
INSERT OR REPLACE INTO UnitFormationClasses (FormationClassType, Name) VALUES ('FORMATION_CLASS_RECON', 'Recon');

/* Apply the new classes (order is important !) */
UPDATE Units SET FormationClass = 'FORMATION_CLASS_RANGED' 	WHERE (RangedCombat > 0 OR Bombard > 0) AND (Domain = 'DOMAIN_LAND');
UPDATE Units SET FormationClass = 'FORMATION_CLASS_RECON' 	WHERE PromotionClass = 'PROMOTION_CLASS_RECON' AND Domain = 'DOMAIN_LAND';

/* Apply the new Promotion Classes */
UPDATE Units 			SET PromotionClass ='PROMOTION_CLASS_CAVALRY' 		WHERE PromotionClass ='PROMOTION_CLASS_LIGHT_CAVALRY' OR PromotionClass ='PROMOTION_CLASS_HEAVY_CAVALRY';
UPDATE Units 			SET PromotionClass ='PROMOTION_CLASS_LIGHT_CAVALRY' WHERE UnitType ='UNIT_BARBARIAN_HORSEMAN';
--UPDATE Units 			SET PromotionClass ='PROMOTION_CLASS_SKIRMISHER' 	WHERE PromotionClass ='PROMOTION_CLASS_RANGED';
UPDATE Units 			SET PromotionClass ='PROMOTION_CLASS_SKIRMISHER' 	WHERE PromotionClass ='PROMOTION_CLASS_RECON';
UPDATE Units 			SET PromotionClass ='PROMOTION_CLASS_MELEE' 		WHERE PromotionClass ='PROMOTION_CLASS_ANTI_CAVALRY';
--UPDATE UnitPromotions 	SET PromotionClass ='PROMOTION_CLASS_SKIRMISHER' 	WHERE PromotionClass ='PROMOTION_CLASS_RANGED';
UPDATE UnitPromotions 	SET PromotionClass ='PROMOTION_CLASS_CAVALRY' 		WHERE PromotionClass ='PROMOTION_CLASS_LIGHT_CAVALRY';

/* Add corresponding tags */
INSERT OR REPLACE INTO Tags(Tag, Vocabulary) VALUES ('CLASS_CAVALRY', 'ABILITY_CLASS');
INSERT OR REPLACE INTO Tags(Tag, Vocabulary) VALUES ('CLASS_SKIRMISHER', 'ABILITY_CLASS');

INSERT OR REPLACE INTO Tags(Tag, Vocabulary) VALUES ('CLASS_BARBARIAN_CAVALRY', 'ABILITY_CLASS');
INSERT OR REPLACE INTO Tags(Tag, Vocabulary) VALUES ('CLASS_BARBARIAN_MELEE', 'ABILITY_CLASS');
INSERT OR REPLACE INTO Tags(Tag, Vocabulary) VALUES ('CLASS_BARBARIAN_SKIRMISHER', 'ABILITY_CLASS');
INSERT OR REPLACE INTO Tags(Tag, Vocabulary) VALUES ('CLASS_BARBARIAN_SIEGE', 'ABILITY_CLASS');
INSERT OR REPLACE INTO Tags(Tag, Vocabulary) VALUES ('CLASS_BARBARIAN_SUPPORT', 'ABILITY_CLASS');
INSERT OR REPLACE INTO Tags(Tag, Vocabulary) VALUES ('CLASS_BARBARIAN_NAVAL_RAIDER', 'ABILITY_CLASS');
INSERT OR REPLACE INTO Tags(Tag, Vocabulary) VALUES ('CLASS_BARBARIAN_NAVAL_RANGED', 'ABILITY_CLASS');
INSERT OR REPLACE INTO Tags(Tag, Vocabulary) VALUES ('CLASS_BARBARIAN_NAVAL_MELEE', 'ABILITY_CLASS');

INSERT OR REPLACE INTO TypeTags(Type, Tag) 
	SELECT TypeTags.Type, 'CLASS_CAVALRY'
	FROM TypeTags WHERE Tag ='CLASS_LIGHT_CAVALRY' OR Tag ='CLASS_HEAVY_CAVALRY';
	
INSERT OR REPLACE INTO TypeTags(Type, Tag) 
	SELECT TypeTags.Type, 'CLASS_SKIRMISHER'
	FROM TypeTags WHERE Tag ='CLASS_RANGED' OR Tag ='CLASS_RECON';

/* Update Barbarians to the new classes */
UPDATE BarbarianAttackForces 	SET MeleeTag ='CLASS_BARBARIAN_CAVALRY' 		WHERE MeleeTag ='CLASS_LIGHT_CAVALRY' OR MeleeTag ='CLASS_HEAVY_CAVALRY';
UPDATE BarbarianAttackForces 	SET MeleeTag ='CLASS_BARBARIAN_MELEE' 			WHERE MeleeTag ='CLASS_MELEE';
UPDATE BarbarianAttackForces 	SET MeleeTag ='CLASS_BARBARIAN_NAVAL_MELEE' 	WHERE MeleeTag ='CLASS_NAVAL_MELEE';

UPDATE BarbarianTribes 			SET MeleeTag ='CLASS_BARBARIAN_CAVALRY' 		WHERE TribeType='TRIBE_CAVALRY';
UPDATE BarbarianTribes 			SET RangedTag ='CLASS_RANGED_CAVALRY' 			WHERE TribeType='TRIBE_CAVALRY';
UPDATE BarbarianTribes 			SET MeleeTag ='CLASS_BARBARIAN_MELEE' 			WHERE TribeType ='TRIBE_MELEE';
UPDATE BarbarianTribes 			SET RangedTag ='CLASS_BARBARIAN_SKIRMISHER' 	WHERE TribeType ='TRIBE_MELEE';
UPDATE BarbarianTribes 			SET ScoutTag ='CLASS_BARBARIAN_SKIRMISHER' 		WHERE TribeType='TRIBE_CAVALRY' OR TribeType ='TRIBE_MELEE';
UPDATE BarbarianTribes 			SET DefenderTag ='CLASS_BARBARIAN_SKIRMISHER' 	WHERE TribeType='TRIBE_CAVALRY' OR TribeType ='TRIBE_MELEE';
UPDATE BarbarianTribes 			SET SiegeTag 	='CLASS_BARBARIAN_SIEGE' 		WHERE TribeType='TRIBE_CAVALRY' OR TribeType ='TRIBE_MELEE';
UPDATE BarbarianTribes 			SET SupportTag 	='CLASS_BARBARIAN_SUPPORT' 		WHERE TribeType='TRIBE_CAVALRY' OR TribeType ='TRIBE_MELEE';

UPDATE BarbarianTribes 			SET MeleeTag 	='CLASS_BARBARIAN_NAVAL_RAIDER' 	WHERE TribeType='TRIBE_NAVAL';
UPDATE BarbarianTribes 			SET RangedTag 	='CLASS_BARBARIAN_NAVAL_RANGED' 	WHERE TribeType='TRIBE_NAVAL';
UPDATE BarbarianTribes 			SET SiegeTag 	='CLASS_BARBARIAN_NAVAL_RANGED' 	WHERE TribeType='TRIBE_NAVAL';
UPDATE BarbarianTribes 			SET ScoutTag 	='CLASS_BARBARIAN_NAVAL_MELEE' 		WHERE TribeType='TRIBE_NAVAL';
UPDATE BarbarianTribes 			SET DefenderTag ='CLASS_BARBARIAN_NAVAL_MELEE' 		WHERE TribeType='TRIBE_NAVAL';

INSERT OR REPLACE INTO TypeTags(Type, Tag) VALUES ('UNIT_HEAVY_CHARIOT', 'CLASS_BARBARIAN_CAVALRY');
INSERT OR REPLACE INTO TypeTags(Type, Tag) VALUES ('UNIT_SLINGER', 'CLASS_BARBARIAN_SKIRMISHER');
INSERT OR REPLACE INTO TypeTags(Type, Tag) VALUES ('UNIT_WARRIOR', 'CLASS_BARBARIAN_MELEE');
INSERT OR REPLACE INTO TypeTags(Type, Tag) VALUES ('UNIT_CATAPULT', 'CLASS_BARBARIAN_SIEGE');
INSERT OR REPLACE INTO TypeTags(Type, Tag) VALUES ('UNIT_BATTERING_RAM', 'CLASS_BARBARIAN_SUPPORT');
INSERT OR REPLACE INTO TypeTags(Type, Tag) VALUES ('UNIT_GALLEY', 'CLASS_BARBARIAN_NAVAL_RAIDER');
INSERT OR REPLACE INTO TypeTags(Type, Tag) VALUES ('UNIT_GALLEY', 'CLASS_BARBARIAN_NAVAL_RANGED');
INSERT OR REPLACE INTO TypeTags(Type, Tag) VALUES ('UNIT_GALLEY', 'CLASS_BARBARIAN_NAVAL_MELEE');

/* Longship is a Barbarian units */
UPDATE Units SET TraitType = 'TRAIT_BARBARIAN' WHERE TraitType = 'TRAIT_LEADER_UNIT_NORWEGIAN_LONGSHIP';

/* Field Cannon is now a siege weapon */
UPDATE Units SET PromotionClass ='PROMOTION_CLASS_SIEGE' WHERE  UnitType = 'UNIT_FIELD_CANNON';
UPDATE Units SET Combat ='53', Bombard ='65' WHERE UnitType = 'UNIT_FIELD_CANNON';
DELETE FROM TypeTags WHERE Type='UNIT_FIELD_CANNON';
INSERT OR REPLACE INTO TypeTags(Type, Tag) VALUES ('UNIT_FIELD_CANNON', 'CLASS_SIEGE');

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

/* Balance */
UPDATE Units SET RangedCombat ='50' WHERE UnitType = 'UNIT_RANGER'; -- default RangedCombat = 60
UPDATE Units SET Cost = '110', Combat ='20', RangedCombat ='35' WHERE UnitType = 'UNIT_LONGBOWMAN'; -- from Moar Units
UPDATE Units SET Combat ='40', RangedCombat ='45' WHERE UnitType = 'UNIT_EXPLORER'; -- from Moar Units
UPDATE Units SET CanTrain ='0' WHERE UnitType = 'UNIT_OBSERVATION_BALLOON';

/* Range = 1 for all Ranged Land/Sea unit */
UPDATE Units SET Range ='1' WHERE (RangedCombat > 0 OR Bombard > 0) AND (Domain = 'DOMAIN_LAND' OR Domain = 'DOMAIN_SEA');

/* Range = 2 for some units */
UPDATE Units SET Range ='2' WHERE UnitType = 'UNIT_BATTLESHIP' OR UnitType = 'UNIT_BRAZILIAN_MINAS_GERAES';

/* Range = 3 for some units */
UPDATE Units SET Range ='3' WHERE UnitType = 'UNIT_ROCKET_ARTILLERY';

/* Range = 4 for some units */
UPDATE Units SET Range ='4' WHERE UnitType = 'UNIT_MISSILE_CRUISER' OR UnitType = 'UNIT_NUCLEAR_SUBMARINE';


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


/* More units on map */
UPDATE Units SET Cost = Cost * 0.75 WHERE Cost > 1 AND (Domain = 'DOMAIN_LAND' or Domain = 'DOMAIN_SEA') AND NOT FormationClass = 'FORMATION_CLASS_CIVILIAN';
UPDATE Units SET Cost = Cost * 0.85 WHERE Cost > 1 AND (Domain = 'DOMAIN_AIR');

-----------------------------------------------
-- Combats
-----------------------------------------------

/* lower damage */
UPDATE GlobalParameters SET Value = 12		WHERE Name = 'COMBAT_BASE_DAMAGE';		-- default = 24
UPDATE GlobalParameters SET Value = 6		WHERE Name = 'COMBAT_MAX_EXTRA_DAMAGE';	-- default = 12

/* remove healing (handled in Lua) */
UPDATE GlobalParameters SET Value = 0		WHERE Name = 'COMBAT_HEAL_CITY_GARRISON';		-- default = 20
UPDATE GlobalParameters SET Value = 0		WHERE Name = 'COMBAT_HEAL_CITY_OUTER_DEFENSES';	-- default = 10
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

/* No Corps or Armies */
DELETE FROM UnitCommands WHERE CommandType='UNITCOMMAND_FORM_CORPS';
DELETE FROM UnitCommands WHERE CommandType='UNITCOMMAND_FORM_ARMY';


/* Garrison (inner) & Outer Defense */

UPDATE GlobalParameters SET Value = 50		WHERE Name = 'COMBAT_CITY_RANGED_DAMAGE_THRESHOLD';	-- default = 50
UPDATE GlobalParameters SET Value = 0		WHERE Name = 'COMBAT_MINIMUM_CITY_STRIKE_STRENGTH';	-- default = 3

UPDATE Districts 			SET HitPoints 	= 300 WHERE DistrictType 	= 'DISTRICT_CITY_CENTER';					-- default = 200
UPDATE ModifierArguments 	SET Value 		= 300 WHERE ModifierID 		= 'CIVIL_ENGINEERING_URBAN_DEFENSES';		-- default = 200

UPDATE Buildings SET OuterDefenseHitPoints = 50		WHERE BuildingType ='BUILDING_PALACE';		-- default = 0
UPDATE Buildings SET OuterDefenseHitPoints = 100 	WHERE BuildingType ='BUILDING_WALLS';		-- default = 50
UPDATE Buildings SET OuterDefenseHitPoints = 200 	WHERE BuildingType ='BUILDING_CASTLE';		-- default = 50
UPDATE Buildings SET OuterDefenseHitPoints = 300 	WHERE BuildingType ='BUILDING_STAR_FORT';	-- default = 50

UPDATE Buildings SET OuterDefenseStrength = 2 WHERE BuildingType ='BUILDING_WALLS';		-- default = 2
UPDATE Buildings SET OuterDefenseStrength = 3 WHERE BuildingType ='BUILDING_CASTLE';	-- default = 2
UPDATE Buildings SET OuterDefenseStrength = 4 WHERE BuildingType ='BUILDING_STAR_FORT';	-- default = 2

/* Remove City Ranged Attack Value */
INSERT OR REPLACE INTO Modifiers
(	ModifierId,							ModifierType,									RunOnce,	Permanent,	SubjectRequirementSetId,	OwnerRequirementSetId	)	VALUES
(	'GCO_REDUCE_CITY_RANGED_STRIKE',	'MODIFIER_PLAYER_CITIES_ADJUST_RANGED_STRIKE',	'0',		'0',		NULL,						NULL					);
INSERT OR REPLACE  INTO ModifierArguments
(	ModifierId,							Name,			Value	)	VALUES
(	'GCO_REDUCE_CITY_RANGED_STRIKE',	'Amount',		'-999'	);

INSERT OR REPLACE  INTO BuildingModifiers
(	BuildingType,						ModifierId				)	VALUES
(	'BUILDING_CENTRAL_SQUARE',			'GCO_REDUCE_CITY_RANGED_STRIKE'	);
/*
INSERT OR REPLACE  INTO TechnologyModifiers
(	TechnologyType,						ModifierId				)	VALUES
(	'TECH_MASONRY',						'GCO_REDUCE_CITY_RANGED_STRIKE'	);
INSERT OR REPLACE  INTO CivicModifiers
(	CivicType,							ModifierId				)	VALUES
(	'CIVIC_CODE_OF_LAWS',				'GCO_REDUCE_CITY_RANGED_STRIKE'	);
*/
