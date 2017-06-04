/*
	Gedemon's Civilization Overhaul
	Mod Rules
	Gedemon (2017)
*/
 
/* New Parameters */
--INSERT OR REPLACE INTO GlobalParameters (Name, Value) VALUES ('CSO_VERSION', 'Alpha .1');


/* Remove GoodyHuts bonuses */
UPDATE GoodyHuts 			SET Weight = 0 WHERE GoodyHutType 		<> 'GOODYHUT_GOLD';
UPDATE GoodyHutSubTypes 	SET Weight = 0 WHERE SubTypeGoodyHut 	<> 'GOODYHUT_SMALL_GOLD';

/* Units */
UPDATE Units SET PopulationCost ='0';
UPDATE Units SET StrategicResource = NULL;

/* Districts */
--UPDATE Buildings SET PrereqDistrict = 'DISTRICT_CITY_CENTER' WHERE PrereqDistrict ='DISTRICT_HARBOR';
UPDATE Buildings SET PrereqDistrict = 'DISTRICT_CITY_CENTER' WHERE PrereqDistrict ='DISTRICT_CAMPUS';
UPDATE Buildings SET PrereqDistrict = 'DISTRICT_CITY_CENTER' WHERE PrereqDistrict ='DISTRICT_COMMERCIAL_HUB';
UPDATE Buildings SET PrereqDistrict = 'DISTRICT_CITY_CENTER' WHERE PrereqDistrict ='DISTRICT_ENTERTAINMENT_COMPLEX';
UPDATE Buildings SET PrereqDistrict = 'DISTRICT_CITY_CENTER' WHERE PrereqDistrict ='DISTRICT_THEATER';

--DELETE FROM Districts WHERE DistrictType ='DISTRICT_HARBOR';
DELETE FROM Districts WHERE DistrictType ='DISTRICT_CAMPUS';
DELETE FROM Districts WHERE DistrictType ='DISTRICT_COMMERCIAL_HUB';
DELETE FROM Districts WHERE DistrictType ='DISTRICT_ENTERTAINMENT_COMPLEX';
DELETE FROM Districts WHERE DistrictType ='DISTRICT_THEATER';
DELETE FROM Districts WHERE DistrictType ='DISTRICT_HOLY_SITE';

--DELETE FROM Projects WHERE PrereqDistrict ='DISTRICT_HARBOR';
DELETE FROM Projects WHERE PrereqDistrict ='DISTRICT_CAMPUS';
DELETE FROM Projects WHERE PrereqDistrict ='DISTRICT_COMMERCIAL_HUB';
DELETE FROM Projects WHERE PrereqDistrict ='DISTRICT_ENTERTAINMENT_COMPLEX';
DELETE FROM Projects WHERE PrereqDistrict ='DISTRICT_THEATER';
DELETE FROM Projects WHERE PrereqDistrict ='DISTRICT_HOLY_SITE';


/* Start */
UPDATE StartEras SET Tiles = '0';

/* Remove Faith */
--DELETE FROM Districts WHERE YieldType='YIELD_FAITH';
DELETE FROM Buildings WHERE PurchaseYield='YIELD_FAITH';
--DELETE FROM Buildings WHERE BuildingType='BUILDING_SHRINE';
--DELETE FROM Buildings WHERE BuildingType='BUILDING_TEMPLE';
--DELETE FROM Buildings WHERE BuildingType='BUILDING_STAVE_CHURCH';
--DELETE FROM Buildings WHERE BuildingType='BUILDING_SHRINE';
--DELETE FROM Buildings WHERE BuildingType='BUILDING_SHRINE';
--DELETE FROM Buildings WHERE BuildingType='BUILDING_SHRINE';
--DELETE FROM Buildings WHERE BuildingType='BUILDING_SHRINE';
DELETE FROM Units WHERE PurchaseYield='YIELD_FAITH';

DELETE FROM Feature_YieldChanges WHERE YieldType ='YIELD_FAITH';
UPDATE GreatWork_YieldChanges SET YieldType = 'YIELD_CULTURE' WHERE YieldType ='YIELD_FAITH';
DELETE FROM Improvement_YieldChanges WHERE YieldType ='YIELD_FAITH';
UPDATE Improvement_BonusYieldChanges SET YieldType = 'YIELD_CULTURE' WHERE YieldType ='YIELD_FAITH';
UPDATE Adjacency_YieldChanges SET YieldType = 'YIELD_CULTURE' WHERE YieldType ='YIELD_FAITH';
UPDATE ModifierArguments SET Value = 'YIELD_CULTURE' WHERE Value ='YIELD_FAITH';
UPDATE Resource_YieldChanges SET YieldType = 'YIELD_CULTURE' WHERE YieldType ='YIELD_FAITH';
DELETE FROM Map_GreatPersonClasses WHERE GreatPersonClassType ='GREAT_PERSON_CLASS_PROPHET';
DELETE FROM Building_YieldChanges WHERE YieldType ='YIELD_FAITH';

--UPDATE Resource_YieldChanges SET YieldType = 'YIELD_CULTURE' WHERE YieldType ='YIELD_FAITH';
--UPDATE Resource_YieldChanges SET YieldType = 'YIELD_CULTURE' WHERE YieldType ='YIELD_FAITH';
--UPDATE Resource_YieldChanges SET YieldType = 'YIELD_CULTURE' WHERE YieldType ='YIELD_FAITH';
--UPDATE Resource_YieldChanges SET YieldType = 'YIELD_CULTURE' WHERE YieldType ='YIELD_FAITH';



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
CREATE TABLE NFLeaders (
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
CREATE TABLE NFCivs (
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