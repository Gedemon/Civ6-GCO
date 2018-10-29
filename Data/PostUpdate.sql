/*
	Post Update Database : After XML data filling
	This file update and add required entries to various tables.
	This way we can limit XML rows to the minimum
*/

-----------------------------------------------
-- Buildings
-----------------------------------------------

/* Create new Buildings entries from the temporary BuildingsGCO table */
INSERT OR REPLACE INTO Buildings (BuildingType, Name, PrereqTech, PrereqDistrict, Cost, NoPedia, MaterielPerProduction, AdvisorType, EquipmentStock, Coast, EmploymentSize)
	SELECT BuildingsGCO.BuildingType, 'LOC_' || BuildingsGCO.BuildingType || '_NAME', BuildingsGCO.PrereqTech, BuildingsGCO.PrereqDistrict, BuildingsGCO.Cost, BuildingsGCO.NoPedia, BuildingsGCO.MaterielPerProduction, BuildingsGCO.AdvisorType, BuildingsGCO.EquipmentStock, BuildingsGCO.Coast, BuildingsGCO.EmploymentSize
	FROM BuildingsGCO;
	
/* Create new Buildings Types entries from the temporary BuildingsGCO table */
INSERT OR REPLACE INTO Types (Type, Kind)
	SELECT BuildingsGCO.BuildingType, 'KIND_BUILDING'
	FROM BuildingsGCO;

/* BuildingsGCO set "DISTRICT_CITY_CENTER" to PrereqDistrict by default, allow handle buildings with no district here */	
UPDATE Buildings SET PrereqDistrict	=	NULL
			WHERE EXISTS				(SELECT * FROM BuildingsGCO WHERE Buildings.BuildingType = BuildingsGCO.BuildingType AND BuildingsGCO.PrereqDistrict = 'NONE');

/* BuildingsGCO set "ADVISOR_GENERIC" to AdvisorType by default, handle buildings with no AdvisorType here */	
UPDATE Buildings SET AdvisorType	=	NULL
			WHERE EXISTS				(SELECT * FROM BuildingsGCO WHERE Buildings.BuildingType = BuildingsGCO.BuildingType AND BuildingsGCO.AdvisorType = 'NONE');

			
/* Link existing description entries to Buildings */
UPDATE Buildings SET Description	=	(SELECT Tag FROM LocalizedText WHERE 'LOC_' || Buildings.BuildingType || '_DESCRIPTION' = Tag AND Language='en_US')
			WHERE EXISTS				(SELECT Tag FROM LocalizedText WHERE 'LOC_' || Buildings.BuildingType || '_DESCRIPTION' = Tag AND Language='en_US');


-----------------------------------------------
-- Resources
-----------------------------------------------
		
/* Create new Resources entries from the Equipment table */
INSERT OR REPLACE INTO Resources (ResourceType, Name, ResourceClassType, Frequency, PrereqTech, FixedPrice, MaxPriceVariationPercent, NoExport, NoTransfer, SpecialStock, NotLoot)
	SELECT Equipment.ResourceType, 'LOC_' || Equipment.ResourceType || '_NAME', Equipment.ResourceClassType, 0, Equipment.PrereqTech, Equipment.FixedPrice, Equipment.MaxPriceVariationPercent, Equipment.NoExport, Equipment.NoTransfer, Equipment.SpecialStock, Equipment.NotLoot
	FROM Equipment;
	
/* Create new Resources entries from the temporary ResourcesGCO table */
INSERT OR REPLACE INTO Resources (ResourceType, Name, ResourceClassType, Frequency, PrereqTech, FixedPrice, MaxPriceVariationPercent, NoExport, NoTransfer, SpecialStock, NotLoot)
	SELECT ResourcesGCO.ResourceType, 'LOC_' || ResourcesGCO.ResourceType || '_NAME', ResourcesGCO.ResourceClassType, ResourcesGCO.Frequency, ResourcesGCO.PrereqTech, ResourcesGCO.FixedPrice, ResourcesGCO.MaxPriceVariationPercent, ResourcesGCO.NoExport, ResourcesGCO.NoTransfer, ResourcesGCO.SpecialStock, ResourcesGCO.NotLoot
	FROM ResourcesGCO;
	
/* Create new Resources entries from the Population table */
INSERT OR REPLACE INTO Resources (ResourceType, Name, ResourceClassType, Frequency, PrereqTech, FixedPrice, MaxPriceVariationPercent, NoExport, NoTransfer, SpecialStock, NotLoot)
	SELECT Populations.PopulationType, 'LOC_' || Populations.PopulationType || '_NAME', "RESOURCECLASS_POPULATION", 0, NULL, 1, 0, 1, 1, 1, 1
	FROM Populations;
	
/* Create new Resources Types entries from the temporary ResourcesGCO table */
INSERT OR REPLACE INTO Types (Type, Kind)
	SELECT ResourcesGCO.ResourceType, 'KIND_RESOURCE'
	FROM ResourcesGCO;
	
/* Create new Resources Types entries from the Equipment table */
INSERT OR REPLACE INTO Types (Type, Kind)
	SELECT Equipment.ResourceType, 'KIND_RESOURCE'
	FROM Equipment;	
	
/* Create new Resources Types entries from the Populations table */
INSERT OR REPLACE INTO Types (Type, Kind)
	SELECT Populations.PopulationType, 'KIND_RESOURCE'
	FROM Populations;	
	
UPDATE EquipmentClasses SET Name = 'LOC_' || EquipmentClasses.EquipmentClass || '_NAME';

-----------------------------------------------
-- Auto set names tag
-----------------------------------------------

UPDATE MilitaryOrganisationLevels	SET Name = 'LOC_' || MilitaryOrganisationLevels.OrganisationLevelType || '_NAME';
UPDATE MilitaryFormations			SET Name = 'LOC_' || MilitaryFormations.MilitaryFormationType || '_NAME';

-----------------------------------------------
-- Units
-----------------------------------------------

/* Update existing Units entries from the temporary UnitsGCO table (before INSERT) */
/* Code below is working fine on SQLite manager but not for the game */
/*
UPDATE Units SET
		(UnitType, Name, Cost, Maintenance, BaseMoves, BaseSightRange, ZoneOfControl, Domain, Combat, Bombard, RangedCombat, FormationClass, PromotionClass, AdvisorType, Personnel)
	= (SELECT
		UnitsGCO.UnitType,
		'LOC_' || UnitsGCO.UnitType || '_NAME',
		ifnull(UnitsGCO.Cost, Units.Cost),
		ifnull(UnitsGCO.Maintenance, Units.Maintenance),
		ifnull(UnitsGCO.BaseMoves, Units.BaseMoves),
		ifnull(UnitsGCO.BaseSightRange, Units.BaseSightRange),
		ifnull(UnitsGCO.ZoneOfControl, Units.ZoneOfControl),
		ifnull(UnitsGCO.Domain, Units.Domain),
		ifnull(UnitsGCO.Combat, Units.Combat),
		ifnull(UnitsGCO.Bombard, Units.Bombard),
		ifnull(UnitsGCO.RangedCombat, Units.RangedCombat),
		ifnull(UnitsGCO.FormationClass, Units.FormationClass),
		ifnull(UnitsGCO.PromotionClass, Units.PromotionClass),
		ifnull(UnitsGCO.AdvisorType, Units.AdvisorType),
		ifnull(UnitsGCO.Personnel, Units.Personnel)
    FROM UnitsGCO WHERE UnitsGCO.UnitType = Units.UnitType )
		WHERE EXISTS ( SELECT * FROM UnitsGCO WHERE UnitsGCO.UnitType = Units.UnitType);
--*/

--/*
-- This way we can set entries in UnitsGCO with just the columns to update and leave the rest empty...
UPDATE Units SET BaseMoves 		= ifnull((SELECT UnitsGCO.BaseMoves 		FROM UnitsGCO WHERE UnitsGCO.UnitType = Units.UnitType AND UnitsGCO.BaseMoves 		IS NOT NULL) , Units.BaseMoves 		);
UPDATE Units SET Cost 			= ifnull((SELECT UnitsGCO.Cost 				FROM UnitsGCO WHERE UnitsGCO.UnitType = Units.UnitType AND UnitsGCO.Cost 			IS NOT NULL) , Units.Cost 			);
UPDATE Units SET CanTrain 		= ifnull((SELECT UnitsGCO.CanTrain 			FROM UnitsGCO WHERE UnitsGCO.UnitType = Units.UnitType AND UnitsGCO.CanTrain 		IS NOT NULL) , Units.CanTrain 		);
UPDATE Units SET Maintenance 	= ifnull((SELECT UnitsGCO.Maintenance 		FROM UnitsGCO WHERE UnitsGCO.UnitType = Units.UnitType AND UnitsGCO.Maintenance 	IS NOT NULL) , Units.Maintenance	);
UPDATE Units SET Combat 		= ifnull((SELECT UnitsGCO.Combat 			FROM UnitsGCO WHERE UnitsGCO.UnitType = Units.UnitType AND UnitsGCO.Combat 			IS NOT NULL) , Units.Combat 		);
UPDATE Units SET Bombard 		= ifnull((SELECT UnitsGCO.Bombard 			FROM UnitsGCO WHERE UnitsGCO.UnitType = Units.UnitType AND UnitsGCO.Bombard			IS NOT NULL) , Units.Bombard 		);
UPDATE Units SET RangedCombat	= ifnull((SELECT UnitsGCO.RangedCombat		FROM UnitsGCO WHERE UnitsGCO.UnitType = Units.UnitType AND UnitsGCO.RangedCombat	IS NOT NULL) , Units.RangedCombat	);
UPDATE Units SET Range 			= ifnull((SELECT UnitsGCO.Range 			FROM UnitsGCO WHERE UnitsGCO.UnitType = Units.UnitType AND UnitsGCO.Range 			IS NOT NULL) , Units.Range 			);
UPDATE Units SET PromotionClass = ifnull((SELECT UnitsGCO.PromotionClass 	FROM UnitsGCO WHERE UnitsGCO.UnitType = Units.UnitType AND UnitsGCO.PromotionClass	IS NOT NULL) , Units.PromotionClass	);
UPDATE Units SET PseudoYieldType= ifnull((SELECT UnitsGCO.PseudoYieldType 	FROM UnitsGCO WHERE UnitsGCO.UnitType = Units.UnitType AND UnitsGCO.PseudoYieldType	IS NOT NULL) , Units.PseudoYieldType);

--*/

/* Create new Units entries from the temporary UnitsGCO table (after UPDATE)*/
--/*
INSERT INTO Units (UnitType, Name, Cost, CanTrain, Maintenance, BaseMoves, BaseSightRange, ZoneOfControl, Domain, Combat, Bombard, RangedCombat, Range, FormationClass, PromotionClass, AdvisorType, PseudoYieldType, Personnel)

	SELECT 
		UnitsGCO.UnitType,
		'LOC_' || UnitsGCO.UnitType || '_NAME',
		UnitsGCO.Cost,
		ifnull(UnitsGCO.CanTrain,1),
		ifnull(UnitsGCO.Maintenance,0),
		ifnull(UnitsGCO.BaseMoves,2),
		ifnull(UnitsGCO.BaseSightRange,2),
		ifnull(UnitsGCO.ZoneOfControl,1),
		UnitsGCO.Domain,
		ifnull(UnitsGCO.Combat,0),
		ifnull(UnitsGCO.Bombard, 0),
		ifnull(UnitsGCO.RangedCombat, 0),
		ifnull(UnitsGCO.Range, 0),
		UnitsGCO.FormationClass,
		UnitsGCO.PromotionClass,
		ifnull(UnitsGCO.AdvisorType,'ADVISOR_GENERIC'),
		UnitsGCO.PseudoYieldType,
		ifnull(UnitsGCO.Personnel,0)
		
	FROM UnitsGCO WHERE NOT EXISTS (SELECT * FROM Units WHERE Units.UnitType = UnitsGCO.UnitType);
--*/
	
	
/* Create new Units Types entries from the temporary UnitsGCO table */
INSERT INTO Types (Type, Kind)
	SELECT UnitsGCO.UnitType, 'KIND_UNIT'
	FROM UnitsGCO WHERE NOT EXISTS (SELECT * FROM Types WHERE Types.Type = UnitsGCO.UnitType);
	
/* UnitsGCO set "ADVISOR_GENERIC" to AdvisorType by default, handle Units with no AdvisorType here */	
UPDATE Units SET AdvisorType	=	NULL
			WHERE EXISTS (SELECT * FROM UnitsGCO WHERE Units.UnitType = UnitsGCO.UnitType AND UnitsGCO.AdvisorType = 'NONE');

			
/* Link existing description entries to Units */
UPDATE Units SET Description	=	(SELECT Tag FROM LocalizedText WHERE 'LOC_' || Units.UnitType || '_DESCRIPTION' = Tag AND Language='en_US')
			WHERE EXISTS			(SELECT Tag FROM LocalizedText WHERE 'LOC_' || Units.UnitType || '_DESCRIPTION' = Tag AND Language='en_US');
	
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
--(	'UNIT_EXPLORER'							), -- Skirmisher
(	'UNIT_TREBUCHET'						),
--(	'UNIT_TERCIO'							), -- I can't make units with two different equipment types of the same promotion class
(	'UNIT_RIFLEMAN'							),
--(	'UNIT_PHALANX'							),
--(	'UNIT_PELTAST'							),
(	'UNIT_LONGBOWMAN'						),
(	'UNIT_MEDIEVAL_HORSEMAN'				),
(	'UNIT_CUIRASSIER'						),

-- New Units
(	'UNIT_MODERN_INFANTRY'					), -- 

(	'END_OF_INSERT'							);


DELETE FROM Units WHERE UnitType NOT IN (SELECT UnitsTokeep.UnitType from UnitsTokeep UNION SELECT UnitsGCO.UnitType from UnitsGCO);

--DELETE FROM Units WHERE UnitType NOT IN (SELECT UnitsTokeep.UnitType from UnitsTokeep);