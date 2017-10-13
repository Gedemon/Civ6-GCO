/*
	Post Update Database : After XML data filling
	This file update and add required entries to various tables.
	This way we can limit XML rows to the minimum
*/

-----------------------------------------------
-- Buildings
-----------------------------------------------

/* Create new Buildings entries from the temporary BuildingsGCO table */
INSERT OR REPLACE INTO Buildings (BuildingType, Name, PrereqTech, PrereqDistrict, Cost, NoPedia, MaterielPerProduction, AdvisorType, EquipmentStock)
	SELECT BuildingsGCO.BuildingType, 'LOC_' || BuildingsGCO.BuildingType || '_NAME', BuildingsGCO.PrereqTech, BuildingsGCO.PrereqDistrict, BuildingsGCO.Cost, BuildingsGCO.NoPedia, BuildingsGCO.MaterielPerProduction, BuildingsGCO.AdvisorType, BuildingsGCO.EquipmentStock
	FROM BuildingsGCO;
	
/* Create new Buildings Types entries from the temporary BuildingsGCO table */
INSERT OR REPLACE INTO Types (Type, Kind)
	SELECT BuildingsGCO.BuildingType, 'KIND_BUILDING'
	FROM BuildingsGCO;

/* BuildingsGCO set "DISTRICT_CITY_CENTER" to PrereqDistrict by default, allow handle buildings with no district here */	
UPDATE Buildings SET PrereqDistrict	= 	NULL
			WHERE EXISTS	   			(SELECT * FROM BuildingsGCO WHERE Buildings.BuildingType = BuildingsGCO.BuildingType AND BuildingsGCO.PrereqDistrict = 'NONE');

/* BuildingsGCO set "ADVISOR_GENERIC" to AdvisorType by default, handle buildings with no AdvisorType here */	
UPDATE Buildings SET PrereqDistrict	= 	NULL
			WHERE EXISTS	   			(SELECT * FROM BuildingsGCO WHERE Buildings.BuildingType = BuildingsGCO.BuildingType AND BuildingsGCO.AdvisorType = 'NONE');

			
/* Link existing description entries to Buildings */
UPDATE Buildings SET Description 	= 	(SELECT Tag FROM LocalizedText WHERE 'LOC_' || Buildings.BuildingType || '_DESCRIPTION' = Tag AND Language='en_US')
			WHERE EXISTS	   			(SELECT Tag FROM LocalizedText WHERE 'LOC_' || Buildings.BuildingType || '_DESCRIPTION' = Tag AND Language='en_US');


-----------------------------------------------
-- Resources
-----------------------------------------------
		
/* Create new Resources entries from the Equipment table */
INSERT OR REPLACE INTO Resources (ResourceType, Name, ResourceClassType, Frequency, PrereqTech)
	SELECT Equipment.ResourceType, 'LOC_' || Equipment.ResourceType || '_NAME', 'RESOURCECLASS_STRATEGIC', 0, Equipment.PrereqTech
	FROM Equipment;
	
/* Create new Resources entries from the temporary ResourcesGCO table */
INSERT OR REPLACE INTO Resources (ResourceType, Name, ResourceClassType, Frequency, PrereqTech, NoExport)
	SELECT ResourcesGCO.ResourceType, 'LOC_' || ResourcesGCO.ResourceType || '_NAME', ResourcesGCO.ResourceClassType, ResourcesGCO.Frequency, ResourcesGCO.PrereqTech, ResourcesGCO.NoExport
	FROM ResourcesGCO;
	
/* Create new Resources Types entries from the temporary ResourcesGCO table */
INSERT OR REPLACE INTO Types (Type, Kind)
	SELECT ResourcesGCO.ResourceType, 'KIND_RESOURCE'
	FROM ResourcesGCO;
	
/* Create new Resources Types entries from the Equipment table */
INSERT OR REPLACE INTO Types (Type, Kind)
	SELECT Equipment.ResourceType, 'KIND_RESOURCE'
	FROM Equipment;
	
	
UPDATE EquipmentClasses SET Name = 'LOC_' || EquipmentClasses.EquipmentClass || '_NAME';

-----------------------------------------------
-- Units
-----------------------------------------------

/* Replace Unit Upgrade table by custom version */
INSERT OR REPLACE INTO UnitUpgradesGCO (Unit, UpgradeUnit)
	SELECT UnitUpgrades.Unit, UnitUpgrades.UpgradeUnit
	FROM UnitUpgrades;
DELETE FROM UnitUpgrades;