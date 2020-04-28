/*

	G.C.O.
	Civilizations creation file
	by Gedemon (2017)
	
*/
		
-----------------------------------------------
-- Update Colors Database
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
INSERT OR REPLACE INTO PlayerColors (Type, Usage, PrimaryColor,	SecondaryColor,	Alt1PrimaryColor,	Alt1SecondaryColor,	Alt2PrimaryColor,	Alt2SecondaryColor,	Alt3PrimaryColor,	Alt3SecondaryColor)
	SELECT	Leader, 'Unique', PrimaryColor, SecondaryColor, PrimaryColor, SecondaryColor, PrimaryColor, SecondaryColor, PrimaryColor, SecondaryColor
	FROM TempColor;
/*	
-- <PlayerColors> when primary color is NULL, it means there is a custom color available for that civilization
INSERT OR REPLACE INTO PlayerColors (Type, Usage, PrimaryColor, SecondaryColor)
	SELECT	'LEADER_' || Name, 'Unique', 'COLOR_PLAYER_' || PrimaryColor, 'COLOR_PLAYER_' || SecondaryColor
	FROM CivilizationConfiguration WHERE PrimaryColor NOT NULL;

INSERT OR REPLACE INTO PlayerColors (Type, Usage, PrimaryColor, SecondaryColor)
	SELECT	'LEADER_' || Name, 'Unique', 'COLOR_PLAYER_' || Name || '_PRIMARY', 'COLOR_PLAYER_' || Name || '_SECONDARY'
	FROM CivilizationConfiguration WHERE PrimaryColor ISNULL;
*/


DROP TABLE CivilizationConfiguration;
DROP TABLE TempColor;

