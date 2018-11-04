/*

	G.C.O.
	Civilizations texts creation file
	by Gedemon (2017)
	
*/

	
-----------------------------------------------
-- Update Localization Database
-----------------------------------------------

-- <LocalizedText>
REPLACE INTO LocalizedText (Tag, Text, Language)
	SELECT	'LOC_CIVILIZATION_' || Name || '_NAME', en_US_Name, 'en_US'
	FROM CivilizationConfiguration;
REPLACE INTO LocalizedText (Tag, Text, Language)
	SELECT	'LOC_CIVILIZATION_' || Name || '_ADJECTIVE', en_US_Adj, 'en_US'
	FROM CivilizationConfiguration;
REPLACE INTO LocalizedText (Tag, Text, Language)
	--SELECT	'LOC_CIVILIZATION_' || Name || '_DESCRIPTION', en_US_Desc, 'en_US'
	SELECT	'LOC_CIVILIZATION_' || Name || '_DESCRIPTION', en_US_Adj || ' government', 'en_US'
	FROM CivilizationConfiguration;
REPLACE INTO LocalizedText (Tag, Text, Language)
	--SELECT	'LOC_LEADER_' || Name || '_NAME', Leader_en_US, 'en_US'
	SELECT	'LOC_LEADER_' || Name || '_NAME', en_US_Name, 'en_US'
	FROM CivilizationConfiguration;
	
INSERT OR IGNORE INTO LocalizedText (Tag, Text, Language)
	SELECT	'LOC_PEDIA_CITYSTATES_PAGE_CIVILIZATION_' || Name || '_CHAPTER_HISTORY_PARA_1', en_US_Desc, 'en_US' 
	FROM CivilizationConfiguration;
INSERT OR IGNORE INTO LocalizedText (Tag, Text, Language)
	SELECT	'LOC_PEDIA_CITYSTATES_PAGE_CIVILIZATION_' || Name || '_CHAPTER_HISTORY_PARA_2', '...', 'en_US' 
	FROM CivilizationConfiguration;
INSERT OR IGNORE INTO LocalizedText (Tag, Text, Language)
	SELECT	'LOC_PEDIA_CITYSTATES_PAGE_CIVILIZATION_' || Name || '_CHAPTER_HISTORY_PARA_3', '...', 'en_US' 
	FROM CivilizationConfiguration;

-----------------------------------------------
-- Delete temporary table
-----------------------------------------------

DROP TABLE CivilizationConfiguration;
