/*
	Post Update Database : After XML data filling
	This file update and add required entries to various tables.
	This way we can limit XML rows to the minimum
*/

-----------------------------------------------
-- Buildings
-----------------------------------------------

/* Create new Buildings entries from the temporary BuildingsGCO table */
INSERT OR REPLACE INTO Buildings (BuildingType, Name, PrereqTech, PrereqDistrict, Cost, NoPedia, MaterielPerProduction, AdvisorType, EquipmentStock, Coast)
	SELECT BuildingsGCO.BuildingType, 'LOC_' || BuildingsGCO.BuildingType || '_NAME', BuildingsGCO.PrereqTech, BuildingsGCO.PrereqDistrict, BuildingsGCO.Cost, BuildingsGCO.NoPedia, BuildingsGCO.MaterielPerProduction, BuildingsGCO.AdvisorType, BuildingsGCO.EquipmentStock, BuildingsGCO.Coast
	FROM BuildingsGCO;
	
/* Create new Buildings Types entries from the temporary BuildingsGCO table */
INSERT OR REPLACE INTO Types (Type, Kind)
	SELECT BuildingsGCO.BuildingType, 'KIND_BUILDING'
	FROM BuildingsGCO;

/* BuildingsGCO set "DISTRICT_CITY_CENTER" to PrereqDistrict by default, allow handle buildings with no district here */	
UPDATE Buildings SET PrereqDistrict	=	NULL
			WHERE EXISTS				(SELECT * FROM BuildingsGCO WHERE Buildings.BuildingType = BuildingsGCO.BuildingType AND BuildingsGCO.PrereqDistrict = 'NONE');

/* BuildingsGCO set "ADVISOR_GENERIC" to AdvisorType by default, handle buildings with no AdvisorType here */	
UPDATE Buildings SET PrereqDistrict	=	NULL
			WHERE EXISTS				(SELECT * FROM BuildingsGCO WHERE Buildings.BuildingType = BuildingsGCO.BuildingType AND BuildingsGCO.AdvisorType = 'NONE');

			
/* Link existing description entries to Buildings */
UPDATE Buildings SET Description	=	(SELECT Tag FROM LocalizedText WHERE 'LOC_' || Buildings.BuildingType || '_DESCRIPTION' = Tag AND Language='en_US')
			WHERE EXISTS				(SELECT Tag FROM LocalizedText WHERE 'LOC_' || Buildings.BuildingType || '_DESCRIPTION' = Tag AND Language='en_US');


-----------------------------------------------
-- Resources
-----------------------------------------------
		
/* Create new Resources entries from the Equipment table */
INSERT OR REPLACE INTO Resources (ResourceType, Name, ResourceClassType, Frequency, PrereqTech, NoExport, NoTransfer, SpecialStock, NotLoot)
	SELECT Equipment.ResourceType, 'LOC_' || Equipment.ResourceType || '_NAME', Equipment.ResourceClassType, 0, Equipment.PrereqTech, Equipment.NoExport, Equipment.NoTransfer, Equipment.SpecialStock, Equipment.NotLoot
	FROM Equipment;
	
/* Create new Resources entries from the temporary ResourcesGCO table */
INSERT OR REPLACE INTO Resources (ResourceType, Name, ResourceClassType, Frequency, PrereqTech, NoExport, NoTransfer, SpecialStock, NotLoot)
	SELECT ResourcesGCO.ResourceType, 'LOC_' || ResourcesGCO.ResourceType || '_NAME', ResourcesGCO.ResourceClassType, ResourcesGCO.Frequency, ResourcesGCO.PrereqTech, ResourcesGCO.NoExport, ResourcesGCO.NoTransfer, ResourcesGCO.SpecialStock, ResourcesGCO.NotLoot
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
-- Auto set names tag
-----------------------------------------------

UPDATE MilitaryOrganisationLevels	SET Name = 'LOC_' || MilitaryOrganisationLevels.OrganisationLevelType || '_NAME';
UPDATE MilitaryFormations			SET Name = 'LOC_' || MilitaryFormations.MilitaryFormationType || '_NAME';

-----------------------------------------------
-- Units
-----------------------------------------------

/* Create new Units entries from the temporary BuildingsGCO table */
INSERT OR REPLACE INTO Units (UnitType, Name, Cost, Maintenance, BaseMoves, BaseSightRange, ZoneOfControl, Domain, Combat, FormationClass, PromotionClass, AdvisorType)

	SELECT UnitsGCO.UnitType, 'LOC_' || UnitsGCO.UnitType || '_NAME', UnitsGCO.Cost, UnitsGCO.Maintenance, UnitsGCO.BaseMoves, UnitsGCO.BaseSightRange, UnitsGCO.ZoneOfControl, UnitsGCO.Domain, UnitsGCO.Combat, UnitsGCO.FormationClass, UnitsGCO.PromotionClass, UnitsGCO.AdvisorType
	FROM UnitsGCO;
	
/* Create new Buildings Types entries from the temporary BuildingsGCO table */
INSERT OR REPLACE INTO Types (Type, Kind)
	SELECT UnitsGCO.UnitType, 'KIND_UNIT'
	FROM UnitsGCO;
	
/* temporary for testing before removing completely those columns from the Units table */
--UPDATE Units SET Materiel = 0, Horses = 0;

-- Replace Unit Upgrade table by custom version (deprecated by new upgrade mechanism)
/*
INSERT OR REPLACE INTO UnitUpgradesGCO (Unit, UpgradeUnit)
	SELECT UnitUpgrades.Unit, UnitUpgrades.UpgradeUnit
	FROM UnitUpgrades;
 */
DELETE FROM UnitUpgrades;


CREATE TABLE IF NOT EXISTS UnitsTokeep (
		UnitType TEXT NOT NULL
);

INSERT OR REPLACE INTO UnitsTokeep (UnitType)
	VALUES 
(	'UNIT_AIRCRAFT_CARRIER'					),
--(	'UNIT_AMERICAN_P51'						),
--(	'UNIT_AMERICAN_ROUGH_RIDER'				),
(	'UNIT_ANTIAIR_GUN'						),
--(	'UNIT_ARABIAN_MAMLUK'					),
(	'UNIT_ARCHAEOLOGIST'					),
(	'UNIT_ARCHER'							),
(	'UNIT_ARTILLERY'						),
--(	'UNIT_AT_CREW'							),
(	'UNIT_BARBARIAN_HORSEMAN'				),
(	'UNIT_BARBARIAN_HORSE_ARCHER'			),
(	'UNIT_BARBARIAN_RAIDER'					),
--(	'UNIT_BATTERING_RAM'					),
(	'UNIT_BATTLESHIP'						),
(	'UNIT_BIPLANE'							),
(	'UNIT_BOMBARD'							),
(	'UNIT_BOMBER'							),
--(	'UNIT_BRAZILIAN_MINAS_GERAES'			),
(	'UNIT_BUILDER'							),
(	'UNIT_CARAVEL'							),
(	'UNIT_CATAPULT'							),
(	'UNIT_CAVALRY'							),
--(	'UNIT_CHINESE_CROUCHING_TIGER'			),
(	'UNIT_CROSSBOWMAN'						),
(	'UNIT_DESTROYER'						),
--(	'UNIT_EGYPTIAN_CHARIOT_ARCHER'			),
--(	'UNIT_ENGLISH_REDCOAT'					),
--(	'UNIT_ENGLISH_SEADOG'					),
(	'UNIT_FIELD_CANNON'						),
(	'UNIT_FIGHTER'							),
--(	'UNIT_FRENCH_GARDE_IMPERIALE'			),
(	'UNIT_FRIGATE'							),
(	'UNIT_GALLEY'							),
--(	'UNIT_GERMAN_UBOAT'						),
--(	'UNIT_GREAT_ADMIRAL'					),
--(	'UNIT_GREAT_ARTIST'						),
--(	'UNIT_GREAT_ENGINEER'					),
--(	'UNIT_GREAT_GENERAL'					),
--(	'UNIT_GREAT_MERCHANT'					),
--(	'UNIT_GREAT_MUSICIAN'					),
--(	'UNIT_GREAT_PROPHET'					),
--(	'UNIT_GREAT_SCIENTIST'					),
--(	'UNIT_GREAT_WRITER'						),
--(	'UNIT_GREEK_HOPLITE'					),
(	'UNIT_HEAVY_CHARIOT'					),
--(	'UNIT_HELICOPTER'						),
(	'UNIT_HORSEMAN'							),
--(	'UNIT_INDIAN_VARU'						),
(	'UNIT_INFANTRY'							),
(	'UNIT_IRONCLAD'							),
--(	'UNIT_JAPANESE_SAMURAI'					),
(	'UNIT_JET_BOMBER'						),
(	'UNIT_JET_FIGHTER'						),
(	'UNIT_KNIGHT'							),
--(	'UNIT_KONGO_SHIELD_BEARER'				),
--(	'UNIT_MACHINE_GUN'						),
(	'UNIT_MECHANIZED_INFANTRY'				),
--(	'UNIT_MEDIC'							),
--(	'UNIT_MILITARY_ENGINEER'				),
(	'UNIT_MISSILE_CRUISER'					),
(	'UNIT_MOBILE_SAM'						),
(	'UNIT_MODERN_ARMOR'						),
--(	'UNIT_MODERN_AT'						),
(	'UNIT_MUSKETMAN'						),
--(	'UNIT_NORWEGIAN_BERSERKER'				),
(	'UNIT_NORWEGIAN_LONGSHIP'				),
(	'UNIT_NUCLEAR_SUBMARINE'				),
--(	'UNIT_OBSERVATION_BALLOON'				),
(	'UNIT_PIKEMAN'							),
(	'UNIT_PRIVATEER'						),
(	'UNIT_QUADRIREME'						),
(	'UNIT_RANGER'							),
(	'UNIT_ROCKET_ARTILLERY'					),
--(	'UNIT_ROMAN_LEGION'						),
--(	'UNIT_RUSSIAN_COSSACK'					),
--(	'UNIT_SCOUT'							),
--(	'UNIT_SCYTHIAN_HORSE_ARCHER'			),
(	'UNIT_SETTLER'							),
--(	'UNIT_SIEGE_TOWER'						),
(	'UNIT_SLINGER'							),
--(	'UNIT_SPANISH_CONQUISTADOR'				),
(	'UNIT_SPEARMAN'							),
(	'UNIT_SPY'								),
(	'UNIT_SUBMARINE'						),
--(	'UNIT_SUMERIAN_WAR_CART'				),
(	'UNIT_SWORDSMAN'						),
(	'UNIT_TANK'								),
(	'UNIT_TRADER'							),
(	'UNIT_WARRIOR'							),

-- from Moar Units
(	'UNIT_SNIPER'							), -- Commandos
(	'UNIT_MODERN_SNIPER'					), -- Special Forces
(	'UNIT_MACEMAN'							), -- LongSwordsman
(	'UNIT_EXPLORER'							), -- Skirmisher
(	'UNIT_TREBUCHET'						),
(	'UNIT_TERCIO'							), -- check for error on update unit data
(	'UNIT_RIFLEMAN'							),
--(	'UNIT_PHALANX'							),
--(	'UNIT_PELTAST'							),
(	'UNIT_LONGBOWMAN'						),
(	'UNIT_MEDIEVAL_HORSEMAN'				),
(	'UNIT_CUIRASSIER'						),

-- New Units
(	'UNIT_MODERN_INFANTRY'					), -- 

(	'END_OF_INSERT'							);


DELETE FROM Units WHERE UnitType NOT IN (SELECT UnitsTokeep.UnitType from UnitsTokeep);