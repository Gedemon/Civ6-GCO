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

/* Units*/
UPDATE Units SET PopulationCost ='0';
UPDATE Units SET StrategicResource = NULL;

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