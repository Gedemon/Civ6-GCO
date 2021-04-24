/*
	GCO
	by Gedemon (2021)

	Build modifiers from Tables
*/

-----------------------------------------------
-- Terrain Restriction
-----------------------------------------------

INSERT INTO Modifiers (ModifierId, ModifierType)
	SELECT 'MOVEMENT_RESTRICTION_' || Terrains.TerrainType, 'MODIFIER_PLAYER_UNIT_ADJUST_VALID_TERRAIN'
	FROM Terrains;
	
INSERT INTO ModifierArguments (ModifierId, Name, Value)
	SELECT 'MOVEMENT_RESTRICTION_' || Terrains.TerrainType, 'TerrainType', Terrains.TerrainType
	FROM Terrains;
	
INSERT INTO ModifierArguments (ModifierId, Name, Value)
	SELECT 'MOVEMENT_RESTRICTION_' || Terrains.TerrainType, 'Valid', 'false'
	FROM Terrains;
	

-----------------------------------------------
-- Add Terrain Restriction to ABILITY_NO_MOVEMENT
-- The ability is defined in GamePlay.xml
-----------------------------------------------	
INSERT INTO UnitAbilityModifiers (UnitAbilityType, ModifierId)
	SELECT 'ABILITY_NO_MOVEMENT', 'MOVEMENT_RESTRICTION_' || Terrains.TerrainType
	FROM Terrains;