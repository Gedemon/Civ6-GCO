/*
	Gedemon's Civilization Overhaul
	Mod Rules
	Gedemon (2017)
*/


/* ************************ */
/*    Vanilla Game Fixes    */
/* ************************ */

UPDATE Leaders SET Sex = 'Female' WHERE LeaderType = 'LEADER_JADWIGA'; -- What ??? Should that be done with each DLC Female leaders ???


/* ************************ */
/* Remove GoodyHuts bonuses */
/* ************************ */
--/* 
UPDATE GoodyHuts 			SET Weight = 0 WHERE GoodyHutType 		<> 'GOODYHUT_GOLD';
UPDATE GoodyHutSubTypes 	SET Weight = 0 WHERE SubTypeGoodyHut 	<> 'GOODYHUT_SMALL_GOLD';
--*/

/* Change speed (doesn't work ?) */
--UPDATE GameSpeed_Turns SET MonthIncrement = MonthIncrement * 0.5, TurnsPerIncrement = TurnsPerIncrement * 2;

/* ************************ */
/* Resources                */
/* ************************ */
DELETE FROM Resource_Harvests;
DELETE FROM Resources WHERE ResourceType='RESOURCE_NITER';
UPDATE Resources SET PrereqTech ='TECH_GEOLOGY' WHERE ResourceType='RESOURCE_OIL';
UPDATE Resources SET PrereqTech ='TECH_GEOLOGY' WHERE ResourceType='RESOURCE_COAL';
UPDATE Resources SET PrereqTech ='TECH_RADIOACTIVITY' WHERE ResourceType='RESOURCE_URANIUM';

/* ************************ */
/* Deals                    */
/* ************************ */
--/*
DELETE FROM DealItems WHERE DealItemType ='DEAL_ITEM_CITIES' OR DealItemType ='DEAL_ITEM_RESOURCES';
--*/

/* ************************ */
/* Improvements             */
/* ************************ */
UPDATE Improvements SET OnePerCity = 1, SameAdjacentValid = 0 WHERE Buildable = 1 AND TraitType IS NOT NULL;		-- Before updating "CanBuildOutsideTerritory"
UPDATE Improvements SET CanBuildOutsideTerritory = 1 WHERE Buildable = 1 AND TraitType ISNULL AND OnePerCity = 0;	-- After setting "OnePerCity", before removing "TraitType"
UPDATE Improvements SET TraitType = NULL WHERE Buildable = 1;														-- After updating "CanBuildOutsideTerritory"
UPDATE Improvements SET Housing = 0;

UPDATE Improvements SET PrereqTech ='TECH_DEFENSIVE_TACTICS',	DefenseModifier = 4, GrantFortification = 2, SameAdjacentValid = 0 WHERE ImprovementType ='IMPROVEMENT_FORT';
--UPDATE Improvements SET PrereqTech ='TECH_MASONRY', 			DefenseModifier = 2, GrantFortification = 1, SameAdjacentValid = 0 WHERE ImprovementType ='IMPROVEMENT_ROMAN_FORT';
UPDATE Improvements SET PrereqTech ='TECH_CONSTRUCTION', 		DefenseModifier = 4, GrantFortification = 2, SameAdjacentValid = 0 WHERE ImprovementType ='IMPROVEMENT_ALCAZAR';
UPDATE Improvements SET PrereqTech ='TECH_CONSTRUCTION', 		SameAdjacentValid = 1 WHERE ImprovementType ='IMPROVEMENT_GREAT_WALL';

UPDATE Improvements SET PrereqTech ='TECH_AGRICULTURE'		WHERE ImprovementType ='IMPROVEMENT_FARM';
UPDATE Improvements SET PrereqTech ='TECH_TRAPPING'			WHERE ImprovementType ='IMPROVEMENT_CAMP';
UPDATE Improvements SET PrereqTech ='TECH_REFINING'			WHERE ImprovementType ='IMPROVEMENT_OIL_WELL';

INSERT INTO Improvement_BonusYieldChanges (Id, ImprovementType,YieldType,BonusYieldChange,PrereqTech) VALUES (10001,'IMPROVEMENT_FARM','YIELD_FOOD',2,'TECH_CALENDAR');
INSERT INTO Improvement_BonusYieldChanges (Id, ImprovementType,YieldType,BonusYieldChange,PrereqTech) VALUES (10002,'IMPROVEMENT_FARM','YIELD_FOOD',4,'TECH_FERTILIZER');
INSERT INTO Improvement_BonusYieldChanges (Id, ImprovementType,YieldType,BonusYieldChange,PrereqTech) VALUES (10003,'IMPROVEMENT_FARM','YIELD_FOOD',8,'TECH_INDUSTRIALIZATION');

UPDATE Improvement_YieldChanges SET YieldChange = 2 WHERE ImprovementType ='IMPROVEMENT_FARM' 		AND YieldType="YIELD_FOOD";
UPDATE Improvement_YieldChanges SET YieldChange = 1 WHERE ImprovementType ='IMPROVEMENT_PASTURE' 	AND YieldType="YIELD_FOOD";
UPDATE Improvement_YieldChanges SET YieldChange = 1 WHERE ImprovementType ='IMPROVEMENT_PLANTATION' AND YieldType="YIELD_FOOD";
UPDATE Improvement_YieldChanges SET YieldChange = 1 WHERE ImprovementType ='IMPROVEMENT_CAMP' 		AND YieldType="YIELD_FOOD";

-- Before adding 'Farms_DefaultAdjacency' for UI display order
INSERT INTO Improvement_Adjacencies (ImprovementType,YieldChangeId)	VALUES ('IMPROVEMENT_FARM','Farms_River_Food_Bonus');
INSERT INTO Adjacency_YieldChanges 	(ID, Description, YieldType, YieldChange, TilesRequired, AdjacentRiver, PrereqTech) VALUES ('Farms_River_Food_Bonus', 'LOC_FARM_RIVER_FOOD_ADJACENCY_BONUS', 'YIELD_FOOD', 	2 , 1 , 1, 'TECH_IRRIGATION');

INSERT OR REPLACE INTO Improvement_Adjacencies(ImprovementType, YieldChangeId) VALUES ('IMPROVEMENT_FARM', 'Farms_DefaultAdjacency');
--INSERT OR REPLACE INTO Adjacency_YieldChanges (ID, Description, YieldType, YieldChange, TilesRequired, AdjacentImprovement, ObsoleteTech, ObsoleteCivic) 
--				VALUES ('Farms_DefaultAdjacency', 'Placeholder', 'YIELD_FOOD', 1, 2,'IMPROVEMENT_FARM','TECH_REPLACEABLE_PARTS','CIVIC_FEUDALISM');
INSERT OR REPLACE INTO Adjacency_YieldChanges (ID, Description, YieldType, YieldChange, TilesRequired, AdjacentImprovement) 
				VALUES ('Farms_DefaultAdjacency', 'Placeholder', 'YIELD_FOOD', 1, 2,'IMPROVEMENT_FARM');

-- After adding 'Farms_DefaultAdjacency' for UI display order
UPDATE Adjacency_YieldChanges	SET YieldChange = 2, rowid = rowid + 100, ObsoleteTech = NULL, ObsoleteCivic = NULL, PrereqCivic = NULL, PrereqTech = 'TECH_FEUDALISM' WHERE ID ='Farms_MedievalAdjacency';
UPDATE Adjacency_YieldChanges	SET YieldChange = 4, rowid = rowid + 100, ObsoleteTech = NULL, ObsoleteCivic = NULL, PrereqCivic = NULL WHERE ID ='Farms_MechanizedAdjacency';


DELETE FROM Improvements WHERE ImprovementType = 'IMPROVEMENT_KURGAN';
DELETE FROM Improvements WHERE ImprovementType = 'IMPROVEMENT_COLOSSAL_HEAD';
DELETE FROM Improvements WHERE ImprovementType = 'IMPROVEMENT_ROMAN_FORT'; -- Roman Fort use the exact same art as fort !
--DELETE FROM Improvements WHERE ImprovementType = 'IMPROVEMENT_STEPWELL';

INSERT OR REPLACE INTO Improvement_ValidBuildUnits (ImprovementType, UnitType) VALUES ('IMPROVEMENT_FORT', 'UNIT_BUILDER');
INSERT OR REPLACE INTO Improvement_ValidBuildUnits (ImprovementType, UnitType) VALUES ('IMPROVEMENT_AIRSTRIP', 'UNIT_BUILDER');
INSERT OR REPLACE INTO Improvement_ValidBuildUnits (ImprovementType, UnitType) VALUES ('IMPROVEMENT_MISSILE_SILO', 'UNIT_BUILDER');
--INSERT OR REPLACE INTO Improvement_ValidBuildUnits (ImprovementType, UnitType) VALUES ('IMPROVEMENT_ROMAN_FORT', 'UNIT_BUILDER');

INSERT OR REPLACE INTO Improvement_ValidFeatures (ImprovementType, FeatureType) VALUES ('IMPROVEMENT_LUMBER_MILL', 'FEATURE_FOREST_DENSE');
INSERT OR REPLACE INTO Improvement_ValidFeatures (ImprovementType, FeatureType) VALUES ('IMPROVEMENT_LUMBER_MILL', 'FEATURE_FOREST_SPARSE');
INSERT OR REPLACE INTO Improvement_ValidFeatures (ImprovementType, FeatureType) VALUES ('IMPROVEMENT_LUMBER_MILL', 'FEATURE_JUNGLE');
INSERT OR REPLACE INTO Improvement_ValidFeatures (ImprovementType, FeatureType) VALUES ('IMPROVEMENT_STEPWELL', 'FEATURE_JUNGLE');

INSERT OR REPLACE INTO Improvement_ValidTerrains (ImprovementType, TerrainType) VALUES ('IMPROVEMENT_QUARRY', 'TERRAIN_PLAINS');
INSERT OR REPLACE INTO Improvement_ValidTerrains (ImprovementType, TerrainType) VALUES ('IMPROVEMENT_QUARRY', 'TERRAIN_DESERT');
INSERT OR REPLACE INTO Improvement_ValidTerrains (ImprovementType, TerrainType) VALUES ('IMPROVEMENT_QUARRY', 'TERRAIN_PLAINS_HILLS');
INSERT OR REPLACE INTO Improvement_ValidTerrains (ImprovementType, TerrainType) VALUES ('IMPROVEMENT_QUARRY', 'TERRAIN_DESERT_HILLS');

--DELETE FROM Improvement_ValidTerrains WHERE ImprovementType = 'IMPROVEMENT_ROMAN_FORT';
--INSERT OR REPLACE INTO Improvement_ValidTerrains (ImprovementType, TerrainType) VALUES ('IMPROVEMENT_ROMAN_FORT', 'TERRAIN_GRASS_HILLS');
--INSERT OR REPLACE INTO Improvement_ValidTerrains (ImprovementType, TerrainType) VALUES ('IMPROVEMENT_ROMAN_FORT', 'TERRAIN_PLAINS_HILLS');
--INSERT OR REPLACE INTO Improvement_ValidTerrains (ImprovementType, TerrainType) VALUES ('IMPROVEMENT_ROMAN_FORT', 'TERRAIN_SNOW_HILLS');
--INSERT OR REPLACE INTO Improvement_ValidTerrains (ImprovementType, TerrainType) VALUES ('IMPROVEMENT_ROMAN_FORT', 'TERRAIN_DESERT_HILLS');
--INSERT OR REPLACE INTO Improvement_ValidTerrains (ImprovementType, TerrainType) VALUES ('IMPROVEMENT_ROMAN_FORT', 'TERRAIN_TUNDRA_HILLS');

DELETE FROM Improvement_ValidTerrains WHERE ImprovementType = 'IMPROVEMENT_CHATEAU';
INSERT OR REPLACE INTO Improvement_ValidTerrains (ImprovementType, TerrainType) VALUES ('IMPROVEMENT_CHATEAU', 'TERRAIN_GRASS');
INSERT OR REPLACE INTO Improvement_ValidTerrains (ImprovementType, TerrainType) VALUES ('IMPROVEMENT_CHATEAU', 'TERRAIN_PLAINS');

DELETE FROM Improvement_ValidTerrains WHERE ImprovementType = 'IMPROVEMENT_SPHINX';
INSERT OR REPLACE INTO Improvement_ValidTerrains (ImprovementType, TerrainType) VALUES ('IMPROVEMENT_SPHINX', 'TERRAIN_DESERT');
INSERT OR REPLACE INTO Improvement_ValidTerrains (ImprovementType, TerrainType) VALUES ('IMPROVEMENT_SPHINX', 'TERRAIN_DESERT_HILLS');

DELETE FROM Improvement_ValidTerrains WHERE ImprovementType = 'IMPROVEMENT_ZIGGURAT';
INSERT OR REPLACE INTO Improvement_ValidTerrains (ImprovementType, TerrainType) VALUES ('IMPROVEMENT_SPHINX', 'TERRAIN_DESERT');

DELETE FROM Improvement_ValidTerrains WHERE ImprovementType = 'IMPROVEMENT_STEPWELL';
INSERT OR REPLACE INTO Improvement_ValidTerrains (ImprovementType, TerrainType) VALUES ('IMPROVEMENT_STEPWELL', 'TERRAIN_PLAINS');
INSERT OR REPLACE INTO Improvement_ValidTerrains (ImprovementType, TerrainType) VALUES ('IMPROVEMENT_STEPWELL', 'TERRAIN_GRASS_HILLS');

--DELETE FROM Improvement_ValidTerrains WHERE ImprovementType = 'IMPROVEMENT_ALCAZAR';
--INSERT OR REPLACE INTO Improvement_ValidTerrains (ImprovementType, TerrainType) VALUES ('IMPROVEMENT_ALCAZAR', 'TERRAIN_GRASS_HILLS');
--INSERT OR REPLACE INTO Improvement_ValidTerrains (ImprovementType, TerrainType) VALUES ('IMPROVEMENT_ALCAZAR', 'TERRAIN_PLAINS_HILLS');
--INSERT OR REPLACE INTO Improvement_ValidTerrains (ImprovementType, TerrainType) VALUES ('IMPROVEMENT_ALCAZAR', 'TERRAIN_SNOW_HILLS');
--INSERT OR REPLACE INTO Improvement_ValidTerrains (ImprovementType, TerrainType) VALUES ('IMPROVEMENT_ALCAZAR', 'TERRAIN_DESERT_HILLS');
--INSERT OR REPLACE INTO Improvement_ValidTerrains (ImprovementType, TerrainType) VALUES ('IMPROVEMENT_ALCAZAR', 'TERRAIN_TUNDRA_HILLS');

/* ************************ */
/* Features                 */
/* ************************ */
DELETE FROM Feature_Removes;
INSERT INTO Feature_ValidTerrains (FeatureType, TerrainType) VALUES ('FEATURE_FLOODPLAINS', 'TERRAIN_GRASS');
--INSERT INTO Feature_ValidTerrains (FeatureType, TerrainType) VALUES ('FEATURE_FLOODPLAINS', 'TERRAIN_PLAINS');


/* ************************ */
/* Technologies & Civics    */
/* ************************ */

/*
DELETE FROM Technologies WHERE TechnologyType ='TECH_STIRRUPS';
DELETE FROM Technologies WHERE TechnologyType ='TECH_RIFLING';

DELETE FROM TechnologyPrereqs WHERE Technology ='TECH_MILITARY_TACTICS';
INSERT INTO TechnologyPrereqs (Technology, PrereqTech) VALUES ('TECH_MILITARY_TACTICS', 'TECH_HORSEBACK_RIDING');
INSERT INTO TechnologyPrereqs (Technology, PrereqTech) VALUES ('TECH_MILITARY_TACTICS', 'TECH_CONSTRUCTION');
UPDATE Technologies SET UITreeRow = 1 WHERE TechnologyType ='TECH_MILITARY_TACTICS';

DELETE FROM TechnologyPrereqs WHERE Technology ='TECH_APPRENTICESHIP';
--INSERT INTO TechnologyPrereqs (Technology, PrereqTech) VALUES ('TECH_APPRENTICESHIP', 'TECH_HORSEBACK_RIDING');
INSERT INTO TechnologyPrereqs (Technology, PrereqTech) VALUES ('TECH_APPRENTICESHIP', 'TECH_MILITARY_TACTICS');
UPDATE Technologies SET Cost = 390 WHERE TechnologyType ='TECH_APPRENTICESHIP';

DELETE FROM TechnologyPrereqs WHERE Technology ='TECH_STIRRUPS';
--INSERT INTO TechnologyPrereqs (Technology, PrereqTech) VALUES ('TECH_STIRRUPS', 'TECH_APPRENTICESHIP');
--UPDATE Technologies SET Cost = 450 WHERE TechnologyType ='TECH_STIRRUPS';

DELETE FROM TechnologyPrereqs WHERE Technology ='TECH_CASTLES';
INSERT INTO TechnologyPrereqs (Technology, PrereqTech) VALUES ('TECH_CASTLES', 'TECH_MACHINERY');
UPDATE Technologies SET Cost = 450 WHERE TechnologyType ='TECH_CASTLES';

DELETE FROM TechnologyPrereqs WHERE Technology ='TECH_MILITARY_ENGINEERING';
INSERT INTO TechnologyPrereqs (Technology, PrereqTech) VALUES ('TECH_MILITARY_ENGINEERING', 'TECH_MACHINERY');
INSERT INTO TechnologyPrereqs (Technology, PrereqTech) VALUES ('TECH_MILITARY_ENGINEERING', 'TECH_MILITARY_TACTICS');
UPDATE Technologies SET Cost = 450 WHERE TechnologyType ='TECH_MILITARY_ENGINEERING';

UPDATE Technologies SET Cost = 450 WHERE TechnologyType ='TECH_EDUCATION';

DELETE FROM TechnologyPrereqs WHERE Technology ='TECH_GUNPOWDER';
INSERT INTO TechnologyPrereqs (Technology, PrereqTech) VALUES ('TECH_GUNPOWDER', 'TECH_MILITARY_ENGINEERING');
INSERT INTO TechnologyPrereqs (Technology, PrereqTech) VALUES ('TECH_GUNPOWDER', 'TECH_STIRRUPS');

--DELETE FROM TechnologyPrereqs WHERE Technology ='TECH_CARTOGRAPHY';
INSERT INTO TechnologyPrereqs (Technology, PrereqTech) VALUES ('TECH_CARTOGRAPHY', 'TECH_EDUCATION');
INSERT INTO TechnologyPrereqs (Technology, PrereqTech) VALUES ('TECH_CARTOGRAPHY', 'TECH_CELESTIAL_NAVIGATION');
UPDATE Technologies SET Cost = 540, EraType = 'ERA_RENAISSANCE' WHERE TechnologyType ='TECH_CARTOGRAPHY'; -- cancel changes from Warfare Expanded

DELETE FROM TechnologyPrereqs WHERE Technology ='TECH_MASS_PRODUCTION';
INSERT INTO TechnologyPrereqs (Technology, PrereqTech) VALUES ('TECH_MASS_PRODUCTION', 'TECH_BANKING');
INSERT INTO TechnologyPrereqs (Technology, PrereqTech) VALUES ('TECH_MASS_PRODUCTION', 'TECH_CARTOGRAPHY');
UPDATE Technologies SET Cost = 660 WHERE TechnologyType ='TECH_MASS_PRODUCTION';

INSERT INTO TechnologyPrereqs (Technology, PrereqTech) VALUES ('TECH_SIEGE_TACTICS', 'TECH_MILITARY_ENGINEERING');

--UPDATE Technologies SET Cost = 750 WHERE TechnologyType ='TECH_METAL_CASTING';
--INSERT INTO TechnologyPrereqs (Technology, PrereqTech) VALUES ('TECH_INDUSTRIALIZATION', 'TECH_METAL_CASTING');

INSERT INTO TechnologyPrereqs (Technology, PrereqTech) VALUES ('TECH_SQUARE_RIGGING', 'TECH_METAL_CASTING');
UPDATE Technologies SET Cost = 750 WHERE TechnologyType ='TECH_SQUARE_RIGGING';

UPDATE Technologies SET Cost = 750, EraType='ERA_RENAISSANCE' WHERE TechnologyType ='TECH_SCIENTIFIC_THEORY';

INSERT INTO TechnologyPrereqs (Technology, PrereqTech) VALUES ('TECH_BALLISTICS', 'TECH_SIEGE_TACTICS');
INSERT INTO TechnologyPrereqs (Technology, PrereqTech) VALUES ('TECH_INDUSTRIALIZATION', 'TECH_SCIENTIFIC_THEORY');

DELETE FROM TechnologyPrereqs WHERE Technology ='TECH_SANITATION';
INSERT INTO TechnologyPrereqs (Technology, PrereqTech) VALUES ('TECH_SANITATION', 'TECH_INDUSTRIALIZATION');

DELETE FROM TechnologyPrereqs WHERE Technology ='TECH_ECONOMICS';
INSERT INTO TechnologyPrereqs (Technology, PrereqTech) VALUES ('TECH_ECONOMICS', 'TECH_INDUSTRIALIZATION');

UPDATE Technologies SET Cost = 1070 WHERE TechnologyType ='TECH_STEAM_POWER';

DELETE FROM TechnologyPrereqs WHERE Technology ='TECH_STEEL';
INSERT INTO TechnologyPrereqs (Technology, PrereqTech) VALUES ('TECH_STEEL', 'TECH_STEAM_POWER');
--INSERT INTO TechnologyPrereqs (Technology, PrereqTech) VALUES ('TECH_STEEL', 'TECH_RIFLING');
UPDATE Technologies SET UITreeRow = 2 WHERE TechnologyType ='TECH_STEEL';

UPDATE Technologies SET Cost = 1140 WHERE TechnologyType ='TECH_ELECTRICITY';

DELETE FROM TechnologyPrereqs WHERE Technology ='TECH_RADIO';
INSERT INTO TechnologyPrereqs (Technology, PrereqTech) VALUES ('TECH_RADIO', 'TECH_ELECTRICITY');
INSERT INTO TechnologyPrereqs (Technology, PrereqTech) VALUES ('TECH_RADIO', 'TECH_REPLACEABLE_PARTS');
UPDATE Technologies SET UITreeRow = -3 WHERE TechnologyType ='TECH_RADIO';

--INSERT INTO TechnologyPrereqs (Technology, PrereqTech) VALUES ('TECH_REPLACEABLE_PARTS', 'TECH_RIFLING');

DELETE FROM TechnologyPrereqs WHERE Technology ='TECH_COMBUSTION';
INSERT INTO TechnologyPrereqs (Technology, PrereqTech) VALUES ('TECH_COMBUSTION', 'TECH_STEEL');
UPDATE Technologies SET UITreeRow = 3 WHERE TechnologyType ='TECH_COMBUSTION';

DELETE FROM TechnologyPrereqs WHERE Technology ='TECH_FLIGHT';
INSERT INTO TechnologyPrereqs (Technology, PrereqTech) VALUES ('TECH_FLIGHT', 'TECH_COMBUSTION');
UPDATE Technologies SET Cost = 1350, UITreeRow = 1 WHERE TechnologyType ='TECH_FLIGHT';

DELETE FROM TechnologyPrereqs WHERE Technology ='TECH_ADVANCED_FLIGHT';
INSERT INTO TechnologyPrereqs (Technology, PrereqTech) VALUES ('TECH_ADVANCED_FLIGHT', 'TECH_FLIGHT');
INSERT INTO TechnologyPrereqs (Technology, PrereqTech) VALUES ('TECH_ADVANCED_FLIGHT', 'TECH_RADIO');
UPDATE Technologies SET UITreeRow = -2 WHERE TechnologyType ='TECH_ADVANCED_FLIGHT';

DELETE FROM TechnologyPrereqs WHERE Technology ='TECH_ROCKETRY';
INSERT INTO TechnologyPrereqs (Technology, PrereqTech) VALUES ('TECH_ROCKETRY', 'TECH_ADVANCED_FLIGHT');
INSERT INTO TechnologyPrereqs (Technology, PrereqTech) VALUES ('TECH_ROCKETRY', 'TECH_ADVANCED_BALLISTICS');
INSERT INTO TechnologyPrereqs (Technology, PrereqTech) VALUES ('TECH_ROCKETRY', 'TECH_CHEMISTRY');
UPDATE Technologies SET Cost = 1580, UITreeRow = -1 WHERE TechnologyType ='TECH_ROCKETRY';

--INSERT INTO TechnologyPrereqs (Technology, PrereqTech) VALUES ('TECH_ARMORED_WARFARE', 'TECH_COMBUSTION');

DELETE FROM TechnologyPrereqs WHERE Technology ='TECH_COMBINED_ARMS';
--INSERT INTO TechnologyPrereqs (Technology, PrereqTech) VALUES ('TECH_COMBINED_ARMS', 'TECH_ARMORED_WARFARE');
INSERT INTO TechnologyPrereqs (Technology, PrereqTech) VALUES ('TECH_COMBINED_ARMS', 'TECH_FLIGHT');

INSERT INTO TechnologyPrereqs (Technology, PrereqTech) VALUES ('TECH_COMBINED_ARMS', 'TECH_RADIO');

INSERT INTO TechnologyPrereqs (Technology, PrereqTech) VALUES ('TECH_SYNTHETIC_MATERIALS', 'TECH_ROCKETRY');
UPDATE Technologies SET Cost = 1700 WHERE TechnologyType ='TECH_SYNTHETIC_MATERIALS';

DELETE FROM TechnologyPrereqs WHERE Technology ='TECH_COMPUTERS';
INSERT INTO TechnologyPrereqs (Technology, PrereqTech) VALUES ('TECH_COMPUTERS', 'TECH_RADIO');
UPDATE Technologies SET Cost = 1700 WHERE TechnologyType ='TECH_COMPUTERS';

DELETE FROM TechnologyPrereqs WHERE Technology ='TECH_SATELLITES';
INSERT INTO TechnologyPrereqs (Technology, PrereqTech) VALUES ('TECH_SATELLITES', 'TECH_ROCKETRY');
INSERT INTO TechnologyPrereqs (Technology, PrereqTech) VALUES ('TECH_SATELLITES', 'TECH_COMPUTERS');

DELETE FROM TechnologyPrereqs WHERE Technology ='TECH_GUIDANCE_SYSTEMS';
INSERT INTO TechnologyPrereqs (Technology, PrereqTech) VALUES ('TECH_GUIDANCE_SYSTEMS', 'TECH_ROCKETRY');
INSERT INTO TechnologyPrereqs (Technology, PrereqTech) VALUES ('TECH_GUIDANCE_SYSTEMS', 'TECH_COMPUTERS');
--*/

--INSERT INTO TechnologyPrereqs (Technology, PrereqTech) VALUES ('TECH_FUTURE_TECH', 'TECH_TELECOMMUNICATIONS');

--DELETE FROM CivicModifiers WHERE ModifierId='CIVIC_AWARD_ONE_INFLUENCE_TOKEN'; -- no use for token yet

UPDATE Civics SET Description = 'LOC_CIVIC_MILITARY_TRAINING_DESCRIPTION' 	WHERE CivicType ='CIVIC_MILITARY_TRAINING';
UPDATE Civics SET Description = 'LOC_CIVIC_MERCENARIES_DESCRIPTION' 		WHERE CivicType ='CIVIC_MERCENARIES';
UPDATE Civics SET UITreeRow = -3, Cost = 275 WHERE CivicType ='CIVIC_NAVAL_TRADITION';

DELETE FROM CivicPrereqs WHERE Civic ='CIVIC_MERCENARIES' AND PrereqCivic ='CIVIC_MILITARY_TRAINING';
DELETE FROM CivicPrereqs WHERE Civic ='CIVIC_NAVAL_TRADITION' AND PrereqCivic ='CIVIC_DEFENSIVE_TACTICS';
INSERT INTO CivicPrereqs (Civic, PrereqCivic) VALUES ('CIVIC_FEUDALISM', 'CIVIC_MILITARY_TRAINING');
INSERT INTO CivicPrereqs (Civic, PrereqCivic) VALUES ('CIVIC_NAVAL_TRADITION', 'CIVIC_MILITARY_TRAINING');
INSERT INTO CivicPrereqs (Civic, PrereqCivic) VALUES ('CIVIC_MERCENARIES', 'CIVIC_NAVAL_TRADITION');

-- Reduce boost
--UPDATE Boosts SET Boost = 30; -- Default = 50 -- no more boost at all


/* ************************ */
/* Policies                 */
/* ************************ */
UPDATE Policies SET PrereqCivic = NULL, PrereqTech = 'TECH_CEREMONIAL_BURIAL' 	WHERE PolicyType ='POLICY_GOD_KING';
UPDATE Policies SET PrereqCivic = NULL, PrereqTech = 'TECH_WARRIOR_CODE' 		WHERE PolicyType ='POLICY_DISCIPLINE';
UPDATE Policies SET PrereqCivic = NULL, PrereqTech = 'TECH_MAP_MAKING' 			WHERE PolicyType ='POLICY_SURVEY';
UPDATE Policies SET PrereqCivic = NULL, PrereqTech = 'TECH_LIBERALISM' 			WHERE PolicyType ='POLICY_LIBERALISM';
UPDATE Policies SET PrereqCivic = NULL, PrereqTech = 'TECH_LIBERALISM' 			WHERE PolicyType ='POLICY_FREE_MARKET';

/* ************************ */
/* Government               */
/* ************************ */
DELETE FROM Government_SlotCounts WHERE GovernmentType ='GOVERNMENT_CHIEFDOM';
INSERT INTO Government_SlotCounts (GovernmentType, GovernmentSlotType, NumSlots) VALUES ('GOVERNMENT_CHIEFDOM', 'SLOT_WILDCARD', '2');


/* ************************ */
/* Conscripts               */
/* ************************ */
UPDATE Policies SET ArmyMaxPercentBoost = 5 WHERE PolicyType ='POLICY_CONSCRIPTION';
UPDATE Policies SET ArmyMaxPercentBoost = 6 WHERE PolicyType ='POLICY_FEUDAL_CONTRACT';
UPDATE Policies SET ArmyMaxPercentBoost = 7 WHERE PolicyType ='POLICY_GRANDE_ARMEE';
UPDATE Policies SET ArmyMaxPercentBoost = 8 WHERE PolicyType ='POLICY_LEVEE_EN_MASSE';
UPDATE Policies SET ArmyMaxPercentBoost = 10 WHERE PolicyType ='POLICY_PATRIOTIC_WAR';

UPDATE Policies SET ActiveTurnsLeftBoost = 3 WHERE PolicyType ='POLICY_MANEUVER';
UPDATE Policies SET ActiveTurnsLeftBoost = 6 WHERE PolicyType ='POLICY_LIGHTNING_WARFARE';

/* ************************ */
/* Army Size                */
/* ************************ */
UPDATE Eras SET ArmyMaxPercentOfPopulation = 1 	WHERE EraType='ERA_ANCIENT';
UPDATE Eras SET ArmyMaxPercentOfPopulation = 1 	WHERE EraType='ERA_CLASSICAL';
UPDATE Eras SET ArmyMaxPercentOfPopulation = 2 	WHERE EraType='ERA_MEDIEVAL';
UPDATE Eras SET ArmyMaxPercentOfPopulation = 3 	WHERE EraType='ERA_RENAISSANCE';
UPDATE Eras SET ArmyMaxPercentOfPopulation = 4 	WHERE EraType='ERA_INDUSTRIAL';
UPDATE Eras SET ArmyMaxPercentOfPopulation = 4	WHERE EraType='ERA_MODERN';
UPDATE Eras SET ArmyMaxPercentOfPopulation = 5	WHERE EraType='ERA_ATOMIC';
UPDATE Eras SET ArmyMaxPercentOfPopulation = 5	WHERE EraType='ERA_INFORMATION';

UPDATE Eras SET ArmyMaxPercentWarBoost = 2 	WHERE EraType='ERA_ANCIENT';
UPDATE Eras SET ArmyMaxPercentWarBoost = 2 	WHERE EraType='ERA_CLASSICAL';
UPDATE Eras SET ArmyMaxPercentWarBoost = 3 	WHERE EraType='ERA_MEDIEVAL';
UPDATE Eras SET ArmyMaxPercentWarBoost = 4 	WHERE EraType='ERA_RENAISSANCE';
UPDATE Eras SET ArmyMaxPercentWarBoost = 5 	WHERE EraType='ERA_INDUSTRIAL';
UPDATE Eras SET ArmyMaxPercentWarBoost = 6	WHERE EraType='ERA_MODERN';
UPDATE Eras SET ArmyMaxPercentWarBoost = 7	WHERE EraType='ERA_ATOMIC';
UPDATE Eras SET ArmyMaxPercentWarBoost = 7	WHERE EraType='ERA_INFORMATION';

UPDATE Eras SET ArmyPersonnelPopulationRatio = 1 	WHERE EraType='ERA_ANCIENT';
UPDATE Eras SET ArmyPersonnelPopulationRatio = 5 	WHERE EraType='ERA_CLASSICAL';
UPDATE Eras SET ArmyPersonnelPopulationRatio = 10 	WHERE EraType='ERA_MEDIEVAL';
UPDATE Eras SET ArmyPersonnelPopulationRatio = 20 	WHERE EraType='ERA_RENAISSANCE';
UPDATE Eras SET ArmyPersonnelPopulationRatio = 50 	WHERE EraType='ERA_INDUSTRIAL';
UPDATE Eras SET ArmyPersonnelPopulationRatio = 150	WHERE EraType='ERA_MODERN';
UPDATE Eras SET ArmyPersonnelPopulationRatio = 200	WHERE EraType='ERA_ATOMIC';
UPDATE Eras SET ArmyPersonnelPopulationRatio = 250	WHERE EraType='ERA_INFORMATION';

/* ************************ */
/* Districts & Buildings    */
/* ************************ */
--/*

-- Update Spy missions before removing Districts !
UPDATE UnitOperations SET TargetDistrict = 'DISTRICT_CITY_CENTER' WHERE OperationType='UNITOPERATION_SPY_SIPHON_FUNDS';
UPDATE UnitOperations SET TargetDistrict = 'DISTRICT_CITY_CENTER' WHERE OperationType='UNITOPERATION_SPY_STEAL_TECH_BOOST';

UPDATE Buildings SET PrereqDistrict = 'DISTRICT_CITY_CENTER' WHERE PrereqDistrict ='DISTRICT_CAMPUS';
UPDATE Buildings SET PrereqDistrict = 'DISTRICT_CITY_CENTER' WHERE PrereqDistrict ='DISTRICT_COMMERCIAL_HUB';
UPDATE Buildings SET PrereqDistrict = 'DISTRICT_CITY_CENTER' WHERE PrereqDistrict ='DISTRICT_ENTERTAINMENT_COMPLEX';
UPDATE Buildings SET PrereqDistrict = 'DISTRICT_CITY_CENTER' WHERE PrereqDistrict ='DISTRICT_THEATER';
UPDATE Buildings SET PrereqDistrict = 'DISTRICT_CITY_CENTER' WHERE PrereqDistrict ='DISTRICT_HOLY_SITE';
UPDATE Buildings SET PrereqDistrict = 'DISTRICT_CITY_CENTER' WHERE PrereqDistrict ='DISTRICT_HARBOR';

UPDATE Buildings SET PrereqDistrict = 'DISTRICT_CITY_CENTER', 	EmploymentSize ='1.00' WHERE BuildingType ='BUILDING_WORKSHOP';
UPDATE Buildings SET PrereqDistrict = 'DISTRICT_CITY_CENTER', 	EmploymentSize ='0.15', Coast = '1' WHERE BuildingType ='BUILDING_LIGHTHOUSE';

UPDATE Buildings SET AdjacentDistrict 	= 'DISTRICT_CITY_CENTER' WHERE BuildingType ='BUILDING_GREAT_LIGHTHOUSE';
UPDATE Buildings SET AdjacentDistrict 	= 'DISTRICT_CITY_CENTER' WHERE BuildingType ='BUILDING_COLOSSUS';

UPDATE Buildings SET PrereqTech = 'TECH_ENGINEERING', 			EmploymentSize ='1.00'	WHERE BuildingType ='BUILDING_WATER_MILL';
UPDATE Buildings SET PrereqTech = 'TECH_GUNPOWDER', 			EmploymentSize ='0.25',	EquipmentStock ='3000'	WHERE BuildingType ='BUILDING_ARMORY';
UPDATE Buildings SET PrereqTech = 'TECH_MILITARY_ENGINEERING',	EmploymentSize ='1.00',	EquipmentStock ='1500' 	WHERE BuildingType ='BUILDING_BARRACKS';
UPDATE Buildings SET PrereqTech = 'TECH_MILITARY_ENGINEERING',	EmploymentSize ='1.00',	EquipmentStock ='750' 	WHERE BuildingType ='BUILDING_STABLE';

UPDATE Buildings SET PrereqTech = 'TECH_MERCANTILISM',			EmploymentSize ='3.00'	WHERE BuildingType ='BUILDING_SHIPYARD';
UPDATE Buildings SET PrereqTech = 'TECH_STEAM_POWER',			EmploymentSize ='4.00'	WHERE BuildingType ='BUILDING_SEAPORT';

UPDATE Buildings SET PrereqTech = 'TECH_BIOTECHNOLOGY',			EmploymentSize ='1.50' WHERE BuildingType ='BUILDING_RESEARCH_LAB';

UPDATE Buildings SET PrereqTech = 'TECH_COMPUTERS',				EmploymentSize ='8.00', TraitType = NULL WHERE BuildingType ='BUILDING_ELECTRONICS_FACTORY';

DELETE FROM BuildingReplaces WHERE CivUniqueBuildingType ='BUILDING_ELECTRONICS_FACTORY';
DELETE FROM BuildingPrereqs WHERE Building ='BUILDING_SHIPYARD';
DELETE FROM BuildingPrereqs WHERE Building ='BUILDING_BANK';

UPDATE Buildings SET MaterielPerProduction = '3',	EmploymentSize ='0.75' WHERE BuildingType ='BUILDING_GRANARY';
--UPDATE Buildings SET MaterielPerProduction = '3',	EmploymentSize ='0.75' WHERE BuildingType ='BUILDING_GRANARY';

UPDATE Buildings SET EmploymentSize ='0.35' WHERE BuildingType ='BUILDING_LIBRARY';
UPDATE Buildings SET EmploymentSize ='0.40' WHERE BuildingType ='BUILDING_ARENA';
UPDATE Buildings SET EmploymentSize ='2.00' WHERE BuildingType ='BUILDING_MARKET';
UPDATE Buildings SET EmploymentSize ='1.00' WHERE BuildingType ='BUILDING_AMPHITHEATER';
UPDATE Buildings SET EmploymentSize ='1.00' WHERE BuildingType ='BUILDING_UNIVERSITY';
UPDATE Buildings SET EmploymentSize ='1.00' WHERE BuildingType ='BUILDING_WORKSHOP';
UPDATE Buildings SET EmploymentSize ='1.50' WHERE BuildingType ='BUILDING_BANK';
UPDATE Buildings SET EmploymentSize ='1.00' WHERE BuildingType ='BUILDING_MUSEUM_ART';
UPDATE Buildings SET EmploymentSize ='1.00' WHERE BuildingType ='BUILDING_MUSEUM_ARTIFACT';
UPDATE Buildings SET EmploymentSize ='9.00' WHERE BuildingType ='BUILDING_FACTORY';
UPDATE Buildings SET EmploymentSize ='4.00' WHERE BuildingType ='BUILDING_STOCK_EXCHANGE';
UPDATE Buildings SET EmploymentSize ='2.00' WHERE BuildingType ='BUILDING_MILITARY_ACADEMY';
UPDATE Buildings SET EmploymentSize ='1.00' WHERE BuildingType ='BUILDING_ZOO';
UPDATE Buildings SET EmploymentSize ='6.00' WHERE BuildingType ='BUILDING_HANGAR';
UPDATE Buildings SET EmploymentSize ='5.00' WHERE BuildingType ='BUILDING_POWER_PLANT';
UPDATE Buildings SET EmploymentSize ='2.00' WHERE BuildingType ='BUILDING_BROADCAST_CENTER';
UPDATE Buildings SET EmploymentSize ='5.00' WHERE BuildingType ='BUILDING_POWER_PLANT';
UPDATE Buildings SET EmploymentSize ='1.50' WHERE BuildingType ='BUILDING_STADIUM';
UPDATE Buildings SET EmploymentSize ='5.00' WHERE BuildingType ='BUILDING_AIRPORT';

--DELETE FROM Buildings WHERE BuildingType='BUILDING_GRANARY';
--DELETE FROM Buildings WHERE BuildingType='BUILDING_MONUMENT';

UPDATE Districts SET CaptureRemovesBuildings = '0' WHERE DistrictType ='DISTRICT_CITY_CENTER';

UPDATE Districts SET PrereqTech = 'TECH_MILITARY_ENGINEERING' 	WHERE DistrictType ='DISTRICT_ENCAMPMENT';
UPDATE Districts SET PrereqTech = 'TECH_INDUSTRIALIZATION' 		WHERE DistrictType ='DISTRICT_INDUSTRIAL_ZONE';
UPDATE Districts SET PrereqTech = 'TECH_MERCANTILISM' 			WHERE DistrictType ='DISTRICT_HARBOR';
--*/

-- Update projects before removing the distric themselves because of the cascade update...
--/* 
--DELETE FROM Projects WHERE PrereqDistrict ='DISTRICT_HARBOR';
DELETE FROM Projects WHERE PrereqDistrict ='DISTRICT_CAMPUS';
DELETE FROM Projects WHERE PrereqDistrict ='DISTRICT_COMMERCIAL_HUB';
DELETE FROM Projects WHERE PrereqDistrict ='DISTRICT_ENTERTAINMENT_COMPLEX';
DELETE FROM Projects WHERE PrereqDistrict ='DISTRICT_THEATER';
DELETE FROM Projects WHERE PrereqDistrict ='DISTRICT_HOLY_SITE';

DELETE FROM Projects WHERE ProjectType ='PROJECT_REPAIR_OUTER_DEFENSES';
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

/* ************************ */
/* Start                    */
/* ************************ */
UPDATE StartEras SET Tiles = '0', Gold = Gold * 25;

/* ************************ */
/* Remove Faith             */
/* ************************ */
--/* 
--DELETE FROM Buildings WHERE PurchaseYield='YIELD_FAITH';
--DELETE FROM Buildings WHERE BuildingType='BUILDING_SHRINE';
--DELETE FROM Buildings WHERE BuildingType='BUILDING_TEMPLE';
--DELETE FROM Buildings WHERE BuildingType='BUILDING_STAVE_CHURCH';
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


/* ************************ */
/* Units                    */
/* ************************ */
--/*
UPDATE Units SET PopulationCost 	='0';
UPDATE Units SET PrereqPopulation 	='0';
UPDATE Units SET StrategicResource 	= NULL;
UPDATE Units SET MustPurchase 		='0';
--*/

/* ************************ */
/* Promotions               */
/* ************************ */
--/*
--UPDATE UnitPromotions SET Level 	= 1;
--UPDATE UnitPromotions SET Column 	= 0;
UPDATE GlobalParameters SET Value 	= 0 	WHERE Name='EXPERIENCE_ACTIVATE_GOODY_HUT'; 				-- Default = 5
UPDATE GlobalParameters SET Value 	= 0 	WHERE Name='EXPERIENCE_BARB_SOFT_CAP'; 						-- Default = 1
UPDATE GlobalParameters SET Value 	= 0 	WHERE Name='EXPERIENCE_CITY_CAPTURED'; 						-- Default = 10
UPDATE GlobalParameters SET Value 	= 0 	WHERE Name='EXPERIENCE_COMBAT_ATTACKER_BONUS'; 				-- Default = 1
UPDATE GlobalParameters SET Value 	= 0 	WHERE Name='EXPERIENCE_COMBAT_RANGED'; 						-- Default = 1
UPDATE GlobalParameters SET Value 	= 0 	WHERE Name='EXPERIENCE_DISTRICT_VS_UNIT'; 					-- Default = 2
UPDATE GlobalParameters SET Value 	= 0 	WHERE Name='EXPERIENCE_KILL_BONUS'; 						-- Default = 2
UPDATE GlobalParameters SET Value 	= 2 	WHERE Name='EXPERIENCE_MAX_BARB_LEVEL'; 					-- Default = 2
UPDATE GlobalParameters SET Value 	= 6 	WHERE Name='EXPERIENCE_MAX_LEVEL'; 							-- Default = 6
UPDATE GlobalParameters SET Value 	= 0 	WHERE Name='EXPERIENCE_MAXIMUM_ONE_COMBAT'; 				-- Default = 10
UPDATE GlobalParameters SET Value 	= 5 	WHERE Name='EXPERIENCE_NEEDED_FOR_NEXT_LEVEL_MULTIPLIER'; 	-- Default = 5
UPDATE GlobalParameters SET Value 	= 0 	WHERE Name='EXPERIENCE_NOT_COMBAT_RANGED'; 					-- Default = 2
--UPDATE GlobalParameters SET Value	= 0	WHERE Name = 'EXPERIENCE_PROMOTE_HEALED';					-- default = 50 (changed in CombatRules)
--UPDATE GlobalParameters SET Value	= 0	WHERE Name = 'EXPERIENCE_RETRAIN_HEALED';					-- default = 100(changed in CombatRules)
UPDATE GlobalParameters SET Value 	= 0 	WHERE Name='EXPERIENCE_REVEAL_NATURAL_WONDER'; 				-- Default = 15
UPDATE GlobalParameters SET Value 	= 0 	WHERE Name='EXPERIENCE_UNIT_VS_DISTRICT_NOT_CITY_CAPTURED'; -- Default = 3

--UPDATE GlobalParameters SET Value = 99999 WHERE Name = "EXPERIENCE_NEEDED_FOR_NEXT_LEVEL_MULTIPLIER";
--UPDATE Units SET InitialLevel = 2 WHERE Combat > 0 OR RangedCombat > 0 OR Bombard > 0;
--*/

/* ************************ */
/* No purchase              */
/* ************************ */
--/*
UPDATE Units SET PurchaseYield = NULL;
UPDATE Buildings SET PurchaseYield = NULL;
--*/

/* Game Capabilities */
--DELETE FROM GameCapabilities WHERE GameCapability = "CAPABILITY_TRADE";
--DELETE FROM GameCapabilities WHERE GameCapability = "CAPABILITY_CULTURE";

--/*
DELETE FROM GameCapabilities WHERE GameCapability = "CAPABILITY_CIVICS";
DELETE FROM GameCapabilities WHERE GameCapability = "CAPABILITY_CIVICS_CHOOSER";
DELETE FROM GameCapabilities WHERE GameCapability = "CAPABILITY_CIVICS_TREE";
--*/

--DELETE FROM GameCapabilities WHERE GameCapability = "CAPABILITY_GOVERNMENTS";
DELETE FROM GameCapabilities WHERE GameCapability = "CAPABILITY_RELIGION";
DELETE FROM GameCapabilities WHERE GameCapability = "CAPABILITY_FOUND_PANTHEONS";
DELETE FROM GameCapabilities WHERE GameCapability = "CAPABILITY_FOUND_RELIGIONS";
--DELETE FROM GameCapabilities WHERE GameCapability = "CAPABILITY_DIPLOMACY";
--DELETE FROM GameCapabilities WHERE GameCapability = "CAPABILITY_DIPLOMACY_DEALS";


/* ************************ */
/* Diplomacy                */
/* ************************ */

-- more spies, sooner
INSERT OR REPLACE INTO CivicModifiers (CivicType, ModifierId) VALUES ('CIVIC_EARLY_EMPIRE','CIVIC_GRANT_SPY');
INSERT OR REPLACE INTO CivicModifiers (CivicType, ModifierId) VALUES ('CIVIC_FEUDALISM','CIVIC_GRANT_SPY');

-- Alliance at Feudalism, Defensive Pact at Early Empire
UPDATE DiplomaticActions SET InitiatorPrereqCivic ='CIVIC_FEUDALISM', TargetPrereqCivic ='CIVIC_FEUDALISM' WHERE DiplomaticActionType ='DIPLOACTION_ALLIANCE';
UPDATE DiplomaticActions SET InitiatorPrereqCivic ='CIVIC_EARLY_EMPIRE', TargetPrereqCivic ='CIVIC_EARLY_EMPIRE', RequiresAlliance =0 WHERE DiplomaticActionType ='DIPLOACTION_DEFENSIVE_PACT';

-- Research Agrement requires Alliance
UPDATE DiplomaticActions SET RequiresAlliance =1 WHERE DiplomaticActionType ='DIPLOACTION_RESEARCH_AGREEMENT';
DELETE FROM DiplomaticStateActions WHERE StateType='DIPLO_STATE_DECLARED_FRIEND' AND DiplomaticActionType='DIPLOACTION_RESEARCH_AGREEMENT';

-- Defensive pact start at friendly relation, now included in Alliance
DELETE FROM DiplomaticStateActions WHERE StateType='DIPLO_STATE_ALLIED' AND DiplomaticActionType='DIPLOACTION_DEFENSIVE_PACT';
INSERT OR REPLACE INTO DiplomaticStateActions (StateType, DiplomaticActionType, Worth, Cost) VALUES ('DIPLO_STATE_FRIENDLY','DIPLOACTION_DEFENSIVE_PACT','-30','30');

-- Remove War delay after Denounce (else the mod's DoW from Alliance fail in that case)
UPDATE GlobalParameters SET Value = 0 	WHERE Name='DIPLOMACY_DENOUNCE_WAR_DELAY'; 				-- Default = 5

-- Reduce Warmongering
UPDATE Eras SET WarmongerPoints = 0 	WHERE EraType='ERA_ANCIENT'; 		-- Default = 0
UPDATE Eras SET WarmongerPoints = 2 	WHERE EraType='ERA_CLASSICAL';  	-- Default = 4
UPDATE Eras SET WarmongerPoints = 4 	WHERE EraType='ERA_MEDIEVAL';  		-- Default = 8
UPDATE Eras SET WarmongerPoints = 6 	WHERE EraType='ERA_RENAISSANCE';  	-- Default = 12
UPDATE Eras SET WarmongerPoints = 9 	WHERE EraType='ERA_INDUSTRIAL';  	-- Default = 18
UPDATE Eras SET WarmongerPoints = 12 	WHERE EraType='ERA_MODERN';  		-- Default = 24
UPDATE Eras SET WarmongerPoints = 16 	WHERE EraType='ERA_ATOMIC';  		-- Default = 24
UPDATE Eras SET WarmongerPoints = 24 	WHERE EraType='ERA_INFORMATION';  	-- Default = 24

-- Reduce Warmongering
UPDATE DiplomaticActions SET WarmongerPercent = 50 	WHERE DiplomaticActionType='DIPLOACTION_DECLARE_FORMAL_WAR'; 		-- Default = 100
UPDATE DiplomaticActions SET WarmongerPercent = 35 	WHERE DiplomaticActionType='DIPLOACTION_JOINT_WAR'; 				-- Default = 100
UPDATE DiplomaticActions SET WarmongerPercent = 100	WHERE DiplomaticActionType='DIPLOACTION_DECLARE_SURPRISE_WAR'; 		-- Default = 150
UPDATE DiplomaticActions SET WarmongerPercent = 35 	WHERE DiplomaticActionType='DIPLOACTION_DECLARE_HOLY_WAR';			-- Default = 50
UPDATE DiplomaticActions SET WarmongerPercent = 0 	WHERE DiplomaticActionType='DIPLOACTION_DECLARE_LIBERATION_WAR';	-- Default = 0
UPDATE DiplomaticActions SET WarmongerPercent = 0 	WHERE DiplomaticActionType='DIPLOACTION_DECLARE_RECONQUEST_WAR'; 	-- Default = 0
UPDATE DiplomaticActions SET WarmongerPercent = 0 	WHERE DiplomaticActionType='DIPLOACTION_DECLARE_PROTECTORATE_WAR'; 	-- Default = 0
UPDATE DiplomaticActions SET WarmongerPercent = 35 	WHERE DiplomaticActionType='DIPLOACTION_DECLARE_COLONIAL_WAR'; 		-- Default = 50
UPDATE DiplomaticActions SET WarmongerPercent = 50 	WHERE DiplomaticActionType='DIPLOACTION_DECLARE_TERRITORIAL_WAR'; 	-- Default = 75

-- Reduce Warmongering
UPDATE GlobalParameters SET Value = 100 	WHERE Name='WARMONGER_CITY_PERCENT_OF_DOW'; 				-- Default = 50
UPDATE GlobalParameters SET Value = 50 		WHERE Name='WARMONGER_FINAL_MAJOR_CITY_MULTIPLIER'; 		-- Default = 200
UPDATE GlobalParameters SET Value = 100		WHERE Name='WARMONGER_FINAL_MINOR_CITY_MULTIPLIER'; 		-- Default = 100
UPDATE GlobalParameters SET Value = 50 		WHERE Name='DIPLOMACY_WARMONGER_POINT_PERCENT_DECAY'; 		-- Default = 50
UPDATE GlobalParameters SET Value = 32 		WHERE Name='WARMONGER_LIBERATE_POINTS'; 					-- Default = 32
UPDATE GlobalParameters SET Value = 200 	WHERE Name='WARMONGER_RAZE_PENALTY_PERCENT'; 				-- Default = 200
UPDATE GlobalParameters SET Value = 100 	WHERE Name='WARMONGER_REDUCTION_IF_AT_WAR'; 				-- Default = 40
UPDATE GlobalParameters SET Value = 85	 	WHERE Name='WARMONGER_REDUCTION_IF_DENOUNCED'; 				-- Default = 20

-- allow Joint War when declared friends or allied only...
DELETE FROM DiplomaticStateActions WHERE StateType='DIPLO_STATE_NEUTRAL' AND DiplomaticActionType='DIPLOACTION_JOINT_WAR';
DELETE FROM DiplomaticStateActions WHERE StateType='DIPLO_STATE_FRIENDLY' AND DiplomaticActionType='DIPLOACTION_JOINT_WAR';

-- ...but finally remove all war except "surprise war", as it's the only one than affect diplomatic values
DELETE FROM DiplomaticStateActions WHERE DiplomaticActionType='DIPLOACTION_JOINT_WAR';

DELETE FROM DiplomacyStatementTypes WHERE Type='DECLARE_FORMAL_WAR';
DELETE FROM DiplomacyStatementTypes WHERE Type='DECLARE_HOLY_WAR';
DELETE FROM DiplomacyStatementTypes WHERE Type='DECLARE_RECONQUEST_WAR';
DELETE FROM DiplomacyStatementTypes WHERE Type='DECLARE_LIBERATION_WAR';
DELETE FROM DiplomacyStatementTypes WHERE Type='DECLARE_PROTECTORATE_WAR';
DELETE FROM DiplomacyStatementTypes WHERE Type='DECLARE_COLONIAL_WAR';
DELETE FROM DiplomacyStatementTypes WHERE Type='DECLARE_TERRITORIAL_WAR';

DELETE FROM DiplomacyStatements WHERE Type='DECLARE_FORMAL_WAR';
DELETE FROM DiplomacyStatements WHERE Type='DECLARE_HOLY_WAR';
DELETE FROM DiplomacyStatements WHERE Type='DECLARE_RECONQUEST_WAR';
DELETE FROM DiplomacyStatements WHERE Type='DECLARE_LIBERATION_WAR';
DELETE FROM DiplomacyStatements WHERE Type='DECLARE_PROTECTORATE_WAR';
DELETE FROM DiplomacyStatements WHERE Type='DECLARE_COLONIAL_WAR';
DELETE FROM DiplomacyStatements WHERE Type='DECLARE_TERRITORIAL_WAR';

DELETE FROM DiplomaticActions WHERE DiplomaticActionType LIKE '%_WAR' and DiplomaticActionType <> 'DIPLOACTION_DECLARE_SURPRISE_WAR';

-- Remove near border warning when having open border agreement
INSERT INTO RequirementSetRequirements (RequirementSetId, RequirementId) VALUES ('PLAYER_NEAR_CULTURE_BORDER', 'REQUIRES_PLAYER_NO_OPEN_BORDERS');

-- Remove "close to victory" non-sense
DELETE FROM TraitModifiers WHERE TraitType='TRAIT_LEADER_MAJOR_CIV' AND ModifierId='STANDARD_DIPLOMATIC_CLOSE_TO_VICTORY';

-- Remove joint war as you can't get negative modifier with 3rd party civ using that...
DELETE FROM TraitModifiers WHERE TraitType='TRAIT_LEADER_MAJOR_CIV' AND ModifierId='STANDARD_DIPLOMACY_JOINT_WAR';

UPDATE ModifierArguments SET Value = 10	 	WHERE ModifierID='STANDARD_DIPLOMACY_JOINT_WAR' AND Name='InitialValue'; 		-- Default = 5
UPDATE ModifierArguments SET Value = 10	 	WHERE ModifierID='STANDARD_DIPLOMACY_JOINT_WAR' AND Name='ReductionTurns'; 		-- Default = 20

UPDATE ModifierArguments SET Value = 20	 	WHERE ModifierID='STANDARD_DIPLOMATIC_ALLY' AND Name='InitialValue'; 		-- Default = 18
UPDATE ModifierArguments SET Value = 5	 	WHERE ModifierID='STANDARD_DIPLOMATIC_ALLY' AND Name='ReductionTurns'; 		-- Default = 10

UPDATE ModifierArguments SET Value = 10	 	WHERE ModifierID='STANDARD_DIPLOMATIC_DECLARED_FRIEND' AND Name='InitialValue'; 		-- Default = 9
UPDATE ModifierArguments SET Value = 5	 	WHERE ModifierID='STANDARD_DIPLOMATIC_DECLARED_FRIEND' AND Name='ReductionTurns'; 		-- Default = 10

UPDATE ModifierArguments SET Value = -16	WHERE ModifierID='STANDARD_DIPLOMATIC_DENOUNCED' AND Name='InitialValue'; 			-- Default = -9
UPDATE ModifierArguments SET Value = 5	 	WHERE ModifierID='STANDARD_DIPLOMATIC_DENOUNCED' AND Name='ReductionTurns'; 		-- Default = 10

UPDATE ModifierArguments SET Value = 40	 	WHERE ModifierID='STANDARD_DIPLOMATIC_LIBERATED_MY_CITY' AND Name='InitialValue'; 		-- Default = 20
UPDATE ModifierArguments SET Value = 10	 	WHERE ModifierID='STANDARD_DIPLOMATIC_LIBERATED_MY_CITY' AND Name='ReductionTurns'; 	-- Default = 20

UPDATE ModifierArguments SET Value = 1	 	WHERE ModifierID='STANDARD_DIPLOMATIC_WARMONGER' AND Name='ReductionTurns'; 	-- Default = 2

UPDATE ModifierArguments SET Value = -10 	WHERE ModifierID='STANDARD_DIPLOMATIC_3RD_PARTY_ALLIED_WITH_ENEMY' AND Name='AmountPerIncident'; 		-- Default = -8
UPDATE ModifierArguments SET Value = 50 	WHERE ModifierID='STANDARD_DIPLOMATIC_3RD_PARTY_ALLIED_WITH_ENEMY' AND Name='MaxEffectMagnitude'; 		-- Default = 8

UPDATE ModifierArguments SET Value = -6 	WHERE ModifierID='STANDARD_DIPLOMATIC_3RD_PARTY_DECLARED_FRIENDSHIP_WITH_ENEMY' AND Name='AmountPerIncident'; 		-- Default = -6
UPDATE ModifierArguments SET Value = 24 	WHERE ModifierID='STANDARD_DIPLOMATIC_3RD_PARTY_DECLARED_FRIENDSHIP_WITH_ENEMY' AND Name='MaxEffectMagnitude'; 		-- Default = 8

UPDATE ModifierArguments SET Value = 8 		WHERE ModifierID='STANDARD_DIPLOMATIC_3RD_PARTY_ALLIED_WITH_FRIEND' AND Name='AmountPerIncident'; 		-- Default = 8
UPDATE ModifierArguments SET Value = 40	 	WHERE ModifierID='STANDARD_DIPLOMATIC_3RD_PARTY_ALLIED_WITH_FRIEND' AND Name='MaxEffectMagnitude'; 		-- Default = 8

UPDATE ModifierArguments SET Value = 6 		WHERE ModifierID='STANDARD_DIPLOMATIC_3RD_PARTY_DECLARED_FRIENDSHIP_WITH_FRIEND' AND Name='AmountPerIncident'; 		-- Default = 6
UPDATE ModifierArguments SET Value = 24	 	WHERE ModifierID='STANDARD_DIPLOMATIC_3RD_PARTY_DECLARED_FRIENDSHIP_WITH_FRIEND' AND Name='MaxEffectMagnitude'; 	-- Default = 8

UPDATE ModifierArguments SET Value = 8		WHERE ModifierID='STANDARD_DIPLOMATIC_3RD_PARTY_DECLARED_SURPRISE_WAR_ON_ENEMY' AND Name='AmountPerIncident'; 		-- Default = 8
UPDATE ModifierArguments SET Value = 48	 	WHERE ModifierID='STANDARD_DIPLOMATIC_3RD_PARTY_DECLARED_SURPRISE_WAR_ON_ENEMY' AND Name='MaxEffectMagnitude'; 		-- Default = 8

UPDATE ModifierArguments SET Value = -16	WHERE ModifierID='STANDARD_DIPLOMATIC_3RD_PARTY_DECLARED_SURPRISE_WAR_ON_FRIEND' AND Name='AmountPerIncident'; 		-- Default = -8
UPDATE ModifierArguments SET Value = 48	 	WHERE ModifierID='STANDARD_DIPLOMATIC_3RD_PARTY_DECLARED_SURPRISE_WAR_ON_FRIEND' AND Name='MaxEffectMagnitude'; 	-- Default = 8

UPDATE ModifierArguments SET Value = 6 		WHERE ModifierID='STANDARD_DIPLOMATIC_3RD_PARTY_DENOUNCED_ENEMY' AND Name='AmountPerIncident'; 		-- Default = 6
UPDATE ModifierArguments SET Value = 24	 	WHERE ModifierID='STANDARD_DIPLOMATIC_3RD_PARTY_DENOUNCED_ENEMY' AND Name='MaxEffectMagnitude'; 	-- Default = 8

UPDATE ModifierArguments SET Value = -12 	WHERE ModifierID='STANDARD_DIPLOMATIC_3RD_PARTY_DENOUNCED_FRIEND' AND Name='AmountPerIncident'; 		-- Default = -6
UPDATE ModifierArguments SET Value = 36 	WHERE ModifierID='STANDARD_DIPLOMATIC_3RD_PARTY_DENOUNCED_FRIEND' AND Name='MaxEffectMagnitude'; 		-- Default = 8


/* ************************ */
/* ************************ */
/* ************************ */
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