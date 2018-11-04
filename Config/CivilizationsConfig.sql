/*

	G.C.O.
	Civilizations creation file
	by Gedemon (2017)
	
*/
		

-----------------------------------------------
-- Update Configuration Database
-----------------------------------------------

	
-- <Players>
DELETE FROM Players;
INSERT OR REPLACE INTO Players (CivilizationType, Domain, LeaderType, CivilizationName, CivilizationIcon, LeaderName, LeaderIcon, CivilizationAbilityName, CivilizationAbilityDescription, CivilizationAbilityIcon, LeaderAbilityName, LeaderAbilityDescription, LeaderAbilityIcon, Portrait, PortraitBackground )
	SELECT	
		'CIVILIZATION_' || Name, 				-- CivilizationType
		CivilizationConfiguration.Domain,		-- Domain
		'LEADER_' || Name, 						-- LeaderType
		'LOC_CIVILIZATION_' || Name || '_NAME',	-- CivilizationName
		'ICON_CIVILIZATION_' || Name,			-- CivilizationIcon
		'LOC_LEADER_' || Name || '_NAME',		-- LeaderName
		'ICON_LEADER_' || Name,					-- LeaderIcon	
		'',										-- CivilizationAbilityName
		'',										-- CivilizationAbilityDescription
		'',										-- CivilizationAbilityIcon
		'',										-- LeaderAbilityName
		'',										-- LeaderAbilityDescription
		'',										-- LeaderAbilityIcon
		'Portrait.dds',							-- Portrait
		'PortraitBackground.dds'				-- PortraitBackground
	FROM CivilizationConfiguration;

-- <PlayerItems>
DELETE FROM PlayerItems;

	
-----------------------------------------------
-- Delete temporary table
-----------------------------------------------

DROP TABLE CivilizationConfiguration;

