/*

	G.C.O.
	Civilizations creation file
	by Gedemon (2017)
	
*/
		
-----------------------------------------------
-- Update Gameplay Database
-----------------------------------------------

-- <Types> 
INSERT OR REPLACE INTO Types (Type, Kind)
	SELECT	'CIVILIZATION_' || Name, 'KIND_CIVILIZATION'
	FROM CivilizationConfiguration;
INSERT OR REPLACE INTO Types (Type, Kind)
	SELECT	'LEADER_' || Name, 'KIND_LEADER'
	FROM CivilizationConfiguration;
	
-- <Civilizations>
DELETE FROM Civilizations WHERE StartingCivilizationLevelType == 'CIVILIZATION_LEVEL_CITY_STATE' OR StartingCivilizationLevelType == 'CIVILIZATION_LEVEL_FULL_CIV';
--DELETE FROM SQLITE_SEQUENCE WHERE NAME = 'MyTableName';
INSERT OR REPLACE INTO Civilizations (CivilizationType, Name, Description, Adjective, StartingCivilizationLevelType, RandomCityNameDepth, Ethnicity)
	SELECT	'CIVILIZATION_' || Name, 'LOC_CIVILIZATION_' || Name || '_NAME', 'LOC_CIVILIZATION_' || Name || '_DESCRIPTION', 'LOC_CIVILIZATION_' || Name || '_ADJECTIVE', 'CIVILIZATION_LEVEL_FULL_CIV', 10, 'ETHNICITY_' || Ethnicity
	FROM CivilizationConfiguration;
	
UPDATE Civilizations SET StartingCivilizationLevelType='CIVILIZATION_LEVEL_TRIBE' WHERE CivilizationType='CIVILIZATION_BARB_PEACE';
UPDATE Leaders SET InheritFrom='LEADER_MINOR_CIV_DEFAULT' WHERE LeaderType='LEADER_BARB_PEACE';
--LEADER_MINOR_CIV_DEFAULT
	
-- <CivilizationLeaders>
DELETE FROM CivilizationLeaders;
INSERT OR REPLACE INTO CivilizationLeaders (CivilizationType, LeaderType, CapitalName)
	SELECT	'CIVILIZATION_' || Name, 'LEADER_' || Name, 'LOC_CITY_NAME_' || CapitalName
	FROM CivilizationConfiguration;	

-- <Leaders>
--DELETE FROM Leaders; -- if we delete, must keep default and barbarian
INSERT OR REPLACE INTO Leaders (LeaderType, Name, InheritFrom)
	SELECT	'LEADER_' || Name, 'LOC_LEADER_' || Name || '_NAME', 'LEADER_DEFAULT'
	FROM CivilizationConfiguration;
	
-- <LeaderTraits>
INSERT OR REPLACE INTO LeaderTraits (LeaderType, TraitType)
	SELECT	'LEADER_' || Name, 'TRAIT_LEADER_MAJOR_CIV'
	FROM CivilizationConfiguration;	

--/*	
-- <LoadingInfo>
INSERT OR REPLACE INTO LoadingInfo (LeaderType, ForegroundImage, BackgroundImage, EraText, PlayDawnOfManAudio)
	--SELECT	'LEADER_' || Name, 'dom_blank.dds', 'LOADING_' || Name || '.dds', ' ', 0 -- 'LOC_CIVILIZATION_' || Name || '_ERA_TEXT'
	SELECT	'LEADER_' || Name, 'dom_blank.dds', 'LEADER_DEFAULT_BACKGROUND.dds', ' ', 0
	FROM CivilizationConfiguration;
--*/

/*	
-- <DiplomacyInfo>
INSERT OR REPLACE INTO DiplomacyInfo (Type, BackgroundImage)
	SELECT	'LEADER_' || Name, 'DIPLO_' || Name || '.dds'
	FROM CivilizationConfiguration;
--*/

-----------------------------------------------
-- Update Colors Database (still used for direct control)
-----------------------------------------------

CREATE TABLE IF NOT EXISTS 
		TempColor (
		Leader								text								default null,
		PrimaryColor						text								default null,
		SecondaryColor						text								default null);


-- When primary color is NULL, it means there is a custom color available for that civilization
INSERT OR REPLACE INTO TempColor (Leader, PrimaryColor, SecondaryColor)
	SELECT	'LEADER_' || Name, 'COLOR_PLAYER_' || PrimaryColor, 'COLOR_PLAYER_' || SecondaryColor
	FROM CivilizationConfiguration WHERE PrimaryColor NOT NULL;

-- Else use the vanilla color
INSERT OR REPLACE INTO TempColor (Leader, PrimaryColor, SecondaryColor)
	SELECT	'LEADER_' || Name, 'COLOR_PLAYER_' || Name || '_PRIMARY', 'COLOR_PLAYER_' || Name || '_SECONDARY'
	FROM CivilizationConfiguration WHERE PrimaryColor ISNULL;

	
-- <PlayerColors> when primary color is NULL, it means there is a custom color available for that civilization
INSERT OR REPLACE INTO PlayerColors (Type, Usage, PrimaryColor,	SecondaryColor)
	SELECT	Leader, 'Unique', PrimaryColor, SecondaryColor
	FROM TempColor;

DROP TABLE TempColor;
	
-----------------------------------------------
-- Delete temporary table
-----------------------------------------------

DROP TABLE CivilizationConfiguration;

