/*
	Gedemon's Civilization Overhaul
	Mod Rules
	Gedemon (2017)
*/


/* Remove GoodyHuts bonuses */
--/* 
UPDATE GoodyHuts 			SET Weight = 0 WHERE GoodyHutType 		<> 'GOODYHUT_GOLD';
UPDATE GoodyHutSubTypes 	SET Weight = 0 WHERE SubTypeGoodyHut 	<> 'GOODYHUT_SMALL_GOLD';
--*/

/* Change speed (doesn't work ?) */
--UPDATE GameSpeed_Turns SET MonthIncrement = MonthIncrement * 0.5, TurnsPerIncrement = TurnsPerIncrement * 2;

/* No resources harvesting */
DELETE FROM Resource_Harvests;

/* Deals */
--/*
DELETE FROM DealItems WHERE DealItemType ='DEAL_ITEM_CITIES' OR DealItemType ='DEAL_ITEM_RESOURCES';
--*/


/* Diplomacy */
UPDATE DiplomaticActions SET InitiatorPrereqCivic ='CIVIC_EARLY_EMPIRE', TargetPrereqCivic ='CIVIC_EARLY_EMPIRE' WHERE DiplomaticActionType ='DIPLOACTION_ALLIANCE';


/* Improvements */
UPDATE Improvements 	SET PrereqTech ='TECH_CONSTRUCTION' WHERE ImprovementType ='IMPROVEMENT_FORT';
INSERT OR REPLACE INTO Improvement_ValidBuildUnits (ImprovementType, UnitType) VALUES ('IMPROVEMENT_FORT', 'UNIT_BUILDER');

/* Features */
DELETE FROM Feature_Removes;

/* Technologies & Civics*/
UPDATE Technologies SET Cost = 25 WHERE TechnologyType ='TECH_THE_WHEEL';
UPDATE Technologies SET UITreeRow = 3 WHERE TechnologyType ='TECH_MACHINERY';
DELETE FROM Technologies WHERE TechnologyType ='TECH_MILITARY_TACTICS';
DELETE FROM TechnologyPrereqs WHERE Technology ='TECH_THE_WHEEL';
DELETE FROM TechnologyPrereqs WHERE Technology ='TECH_MACHINERY';
INSERT INTO TechnologyPrereqs (Technology, PrereqTech) VALUES ('TECH_MACHINERY', 'TECH_ENGINEERING');
INSERT INTO TechnologyPrereqs (Technology, PrereqTech) VALUES ('TECH_MACHINERY', 'TECH_CONSTRUCTION');
DELETE FROM TechnologyPrereqs WHERE Technology ='TECH_ENGINEERING';
INSERT INTO TechnologyPrereqs (Technology, PrereqTech) VALUES ('TECH_ENGINEERING', 'TECH_THE_WHEEL');
INSERT INTO TechnologyPrereqs (Technology, PrereqTech) VALUES ('TECH_ENGINEERING', 'TECH_IRON_WORKING');
DELETE FROM TechnologyPrereqs WHERE Technology ='TECH_CASTLES';
INSERT INTO TechnologyPrereqs (Technology, PrereqTech) VALUES ('TECH_CASTLES', 'TECH_MACHINERY');
DELETE FROM TechnologyPrereqs WHERE Technology ='TECH_MILITARY_ENGINEERING';
INSERT INTO TechnologyPrereqs (Technology, PrereqTech) VALUES ('TECH_MILITARY_ENGINEERING', 'TECH_MACHINERY');

INSERT INTO TechnologyPrereqs (Technology, PrereqTech) VALUES ('TECH_CONSTRUCTION', 'TECH_IRON_WORKING');
INSERT INTO TechnologyPrereqs (Technology, PrereqTech) VALUES ('TECH_STIRRUPS', 'TECH_APPRENTICESHIP');

-- Reduce boost
UPDATE Boosts SET Boost = 30; -- Default = 50

-- Technology cost
UPDATE Technologies SET Cost = Cost*1.00 WHERE EraType ='ERA_ANCIENT';
UPDATE Technologies SET Cost = Cost*1.10 WHERE EraType ='ERA_CLASSICAL';
UPDATE Technologies SET Cost = Cost*1.20 WHERE EraType ='ERA_MEDIEVAL';
UPDATE Technologies SET Cost = Cost*1.30 WHERE EraType ='ERA_RENAISSANCE';
UPDATE Technologies SET Cost = Cost*1.45 WHERE EraType ='ERA_INDUSTRIAL';
UPDATE Technologies SET Cost = Cost*1.60 WHERE EraType ='ERA_MODERN';
UPDATE Technologies SET Cost = Cost*1.80 WHERE EraType ='ERA_ATOMIC';
UPDATE Technologies SET Cost = Cost*2.00 WHERE EraType ='ERA_INFORMATION';

-- Civics cost
UPDATE Civics SET Cost = Cost*1.20 WHERE EraType ='ERA_ANCIENT';
UPDATE Civics SET Cost = Cost*1.50 WHERE EraType ='ERA_CLASSICAL';
UPDATE Civics SET Cost = Cost*1.60 WHERE EraType ='ERA_MEDIEVAL';
UPDATE Civics SET Cost = Cost*1.70 WHERE EraType ='ERA_RENAISSANCE';
UPDATE Civics SET Cost = Cost*1.80 WHERE EraType ='ERA_INDUSTRIAL';
UPDATE Civics SET Cost = Cost*2.00 WHERE EraType ='ERA_MODERN';
UPDATE Civics SET Cost = Cost*2.20 WHERE EraType ='ERA_ATOMIC';
UPDATE Civics SET Cost = Cost*2.40 WHERE EraType ='ERA_INFORMATION';


/* Districts & Buildings */
--/*

UPDATE Buildings SET PrereqDistrict = 'DISTRICT_CITY_CENTER', Coast = '1' WHERE PrereqDistrict ='DISTRICT_HARBOR';
UPDATE Buildings SET PrereqDistrict = 'DISTRICT_CITY_CENTER' WHERE PrereqDistrict ='DISTRICT_CAMPUS';
UPDATE Buildings SET PrereqDistrict = 'DISTRICT_CITY_CENTER' WHERE PrereqDistrict ='DISTRICT_COMMERCIAL_HUB';
UPDATE Buildings SET PrereqDistrict = 'DISTRICT_CITY_CENTER' WHERE PrereqDistrict ='DISTRICT_ENTERTAINMENT_COMPLEX';
UPDATE Buildings SET PrereqDistrict = 'DISTRICT_CITY_CENTER' WHERE PrereqDistrict ='DISTRICT_THEATER';

UPDATE Buildings SET PrereqTech = 'TECH_ENGINEERING' 	WHERE BuildingType ='BUILDING_WATER_MILL';

--UPDATE Buildings SET PrereqTech = 'TECH_MILITARY_SCIENCE' 	WHERE BuildingType ='DISTRICT_ENCAMPMENT';
--UPDATE Buildings SET PrereqTech = 'TECH_INDUSTRIALIZATION' 	WHERE BuildingType ='DISTRICT_INDUSTRIAL_ZONE';
--UPDATE Buildings SET PrereqTech = 'TECH_MASS_PRODUCTION' 	WHERE BuildingType ='BUILDING_SHIPYARD';

UPDATE Buildings SET MaterielPerProduction = '3' WHERE BuildingType ='BUILDING_GRANARY';

UPDATE Districts SET CaptureRemovesBuildings = '0' WHERE DistrictType ='DISTRICT_CITY_CENTER';

UPDATE Districts SET PrereqTech = 'TECH_MILITARY_SCIENCE' 	WHERE DistrictType ='DISTRICT_ENCAMPMENT';
UPDATE Districts SET PrereqTech = 'TECH_INDUSTRIALIZATION' 	WHERE DistrictType ='DISTRICT_INDUSTRIAL_ZONE';
UPDATE Districts SET PrereqTech = 'TECH_MASS_PRODUCTION' 	WHERE DistrictType ='DISTRICT_HARBOR';
--*/

-- Update projects before removing the distric themselves because of the cascade update...
--/* 
--DELETE FROM Projects WHERE PrereqDistrict ='DISTRICT_HARBOR';
DELETE FROM Projects WHERE PrereqDistrict ='DISTRICT_CAMPUS';
DELETE FROM Projects WHERE PrereqDistrict ='DISTRICT_COMMERCIAL_HUB';
DELETE FROM Projects WHERE PrereqDistrict ='DISTRICT_ENTERTAINMENT_COMPLEX';
DELETE FROM Projects WHERE PrereqDistrict ='DISTRICT_THEATER';
DELETE FROM Projects WHERE PrereqDistrict ='DISTRICT_HOLY_SITE';
--*/

--/*
--DELETE FROM Districts WHERE DistrictType ='DISTRICT_HARBOR';
DELETE FROM Districts WHERE DistrictType ='DISTRICT_CAMPUS';
DELETE FROM Districts WHERE DistrictType ='DISTRICT_COMMERCIAL_HUB';
DELETE FROM Districts WHERE DistrictType ='DISTRICT_ENTERTAINMENT_COMPLEX';
DELETE FROM Districts WHERE DistrictType ='DISTRICT_THEATER';
DELETE FROM Districts WHERE DistrictType ='DISTRICT_HOLY_SITE';
--*/

/* Remove Housing & Entertainment */
--/* 
UPDATE Buildings SET Housing = 0;
UPDATE Buildings SET Entertainment = 0;
UPDATE Districts SET Housing = 0;
UPDATE Districts SET Entertainment = 0;
UPDATE Improvements SET Housing = 0;
--*/

/* Start */
UPDATE StartEras SET Tiles = '0', Gold = Gold * 100;

/* Remove Faith */
--/* 
DELETE FROM Buildings WHERE PurchaseYield='YIELD_FAITH';
DELETE FROM Buildings WHERE BuildingType='BUILDING_SHRINE';
DELETE FROM Buildings WHERE BuildingType='BUILDING_TEMPLE';
DELETE FROM Buildings WHERE BuildingType='BUILDING_STAVE_CHURCH';
DELETE FROM Buildings WHERE BuildingType='BUILDING_SHRINE';
DELETE FROM Units WHERE PurchaseYield='YIELD_FAITH';
--*/

--/* 
DELETE FROM Feature_YieldChanges WHERE YieldType ='YIELD_FAITH';
DELETE FROM Feature_AdjacentYields WHERE YieldType ='YIELD_FAITH';
UPDATE GreatWork_YieldChanges SET YieldType = 'YIELD_CULTURE' WHERE YieldType ='YIELD_FAITH';
DELETE FROM Improvement_YieldChanges WHERE YieldType ='YIELD_FAITH';
UPDATE Improvement_BonusYieldChanges SET YieldType = 'YIELD_CULTURE' WHERE YieldType ='YIELD_FAITH';
UPDATE Adjacency_YieldChanges SET YieldType = 'YIELD_CULTURE' WHERE YieldType ='YIELD_FAITH';
UPDATE ModifierArguments SET Value = 'YIELD_CULTURE' WHERE Value ='YIELD_FAITH';
UPDATE Resource_YieldChanges SET YieldType = 'YIELD_CULTURE' WHERE YieldType ='YIELD_FAITH';
DELETE FROM Map_GreatPersonClasses WHERE GreatPersonClassType ='GREAT_PERSON_CLASS_PROPHET';
DELETE FROM Building_YieldChanges WHERE YieldType ='YIELD_FAITH';
--*/


/* Units */
--/*
UPDATE Units SET PopulationCost ='0';
UPDATE Units SET PrereqPopulation ='0';
UPDATE Units SET StrategicResource = NULL;
--*/


/* No purchase */
--/*
UPDATE Units SET PurchaseYield = NULL;
UPDATE Buildings SET PurchaseYield = NULL;
--*/

/* Game Capabilities */
--DELETE FROM GameCapabilities WHERE GameCapability = "CAPABILITY_TRADE";
--DELETE FROM GameCapabilities WHERE GameCapability = "CAPABILITY_CULTURE";
--DELETE FROM GameCapabilities WHERE GameCapability = "CAPABILITY_CIVICS";
--DELETE FROM GameCapabilities WHERE GameCapability = "CAPABILITY_CIVICS_CHOOSER";
--DELETE FROM GameCapabilities WHERE GameCapability = "CAPABILITY_CIVICS_TREE";
--DELETE FROM GameCapabilities WHERE GameCapability = "CAPABILITY_GOVERNMENTS";
--DELETE FROM GameCapabilities WHERE GameCapability = "CAPABILITY_RELIGION";
--DELETE FROM GameCapabilities WHERE GameCapability = "CAPABILITY_FOUND_PANTHEONS";
--DELETE FROM GameCapabilities WHERE GameCapability = "CAPABILITY_FOUND_RELIGIONS";
--DELETE FROM GameCapabilities WHERE GameCapability = "CAPABILITY_DIPLOMACY";
--DELETE FROM GameCapabilities WHERE GameCapability = "CAPABILITY_DIPLOMACY_DEALS";


/*

	Despecialize
	https://forums.civfanatics.com/resources/despecialise.25800/
	
	

*/
--/*
-- Leaders
CREATE TABLE IF NOT EXISTS NFLeaders (
      LeaderType  TEXT NOT NULL,
      TraitType   TEXT DEFAULT 'TRAIT_LEADER_NONE',
      Kind        TEXT DEFAULT 'KIND_TRAIT',
      Name        TEXT DEFAULT 'No Leader Trait',
      Description TEXT DEFAULT 'This trait does nothing.',
      PRIMARY KEY (LeaderType)
);
INSERT INTO NFLeaders (LeaderType) SELECT DISTINCT LeaderType FROM LeaderTraits WHERE LeaderType <> 'LEADER_BARBARIAN' AND LeaderType <> 'LEADER_DEFAULT' AND LeaderType NOT LIKE 'LEADER_MINOR_CIV_%';
UPDATE NFLeaders SET TraitType=(TraitType || '_' || substr(LeaderType,8));


-- Civilizations
CREATE TABLE IF NOT EXISTS NFCivs (
      CivilizationType TEXT NOT NULL,
      TraitType        TEXT DEFAULT 'TRAIT_CIVILIZATION_NONE',
      Kind             TEXT DEFAULT 'KIND_TRAIT',
      Name             TEXT DEFAULT 'No Civilization Trait',
      Description      TEXT DEFAULT 'This trait does nothing.',
      PRIMARY KEY (CivilizationType)
);
INSERT INTO NFCivs (CivilizationType) SELECT DISTINCT CivilizationType FROM CivilizationTraits WHERE CivilizationType <> 'CIVILIZATION_BARBARIAN';
UPDATE NFCivs SET TraitType=(TraitType || '_' || substr(CivilizationType,14));


-- Agendas
-- UPDATE HistoricalAgendas SET AgendaType=('AGENDA_NONE_HIST_' || substr(LeaderType,8)); --foreign key constraint failed


--CivilizationTraits,LeaderTraits,AgendaTraits for Types table
INSERT INTO Types (Type,Kind) SELECT TraitType,Kind FROM NFLeaders;
INSERT INTO Types (Type,Kind) SELECT TraitType,Kind FROM NFCivs;
-- .. and Traits table
INSERT INTO Traits (TraitType,Name,Description) SELECT TraitType,Name,Description FROM NFLeaders;
INSERT INTO Traits (TraitType,Name,Description) SELECT TraitType,Name,Description FROM NFCivs;

INSERT INTO CivilizationTraits (CivilizationType,TraitType) SELECT CivilizationType,TraitType FROM NFCivs;
INSERT INTO LeaderTraits (LeaderType,TraitType) SELECT LeaderType,TraitType FROM NFLeaders;



-- This is where the actual despecialising is happening
DELETE FROM CivilizationTraits 
      WHERE TraitType NOT LIKE 'TRAIT_CIVILIZATION_NONE%'
	  AND CivilizationType <> 'CIVILIZATION_BARBARIAN';
DELETE FROM LeaderTraits
      WHERE TraitType NOT LIKE 'TRAIT_LEADER_NONE%'
	  AND LeaderType <> 'LEADER_BARBARIAN'
	  AND LeaderType <> 'LEADER_DEFAULT'
	  AND LeaderType NOT LIKE 'LEADER_MINOR_CIV_%';


--*/

DROP TABLE NFLeaders;
DROP TABLE NFCivs;

/*
	Remap Table IDs
	Code Thanks to lemmy101, Thalassicus, Pazyryk	 
*/

/* 
-- Districts
CREATE TABLE IDRemapper ( id INTEGER PRIMARY KEY AUTOINCREMENT, Type TEXT );
INSERT INTO IDRemapper (Type) SELECT Type FROM Districts ORDER by ID;
UPDATE Districts SET ID =	( SELECT IDRemapper.id-1 FROM IDRemapper WHERE Districts.Type = IDRemapper.Type);
DROP TABLE IDRemapper;

-- Buildings
CREATE TABLE IDRemapper ( id INTEGER PRIMARY KEY AUTOINCREMENT, Type TEXT );
INSERT INTO IDRemapper (Type) SELECT Type FROM Buildings ORDER by ID;
UPDATE Buildings SET ID =	( SELECT IDRemapper.id-1 FROM IDRemapper WHERE Buildings.Type = IDRemapper.Type);
DROP TABLE IDRemapper;

/* */