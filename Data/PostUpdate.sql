/*
	Post Update Database : After XML data filling
	This file update and add required entries to various tables.
	This way we can limit XML rows to the minimum
*/
	

-----------------------------------------------
-- Auto set names tag for new tables
-----------------------------------------------

UPDATE EquipmentClasses 			SET Name = 'LOC_' || EquipmentClasses.EquipmentClass || '_NAME';
UPDATE MilitaryOrganisationLevels	SET Name = 'LOC_' || MilitaryOrganisationLevels.OrganisationLevelType || '_NAME';
UPDATE MilitaryFormations			SET Name = 'LOC_' || MilitaryFormations.MilitaryFormationType || '_NAME';
UPDATE TechnologyContributionTypes	SET Name = 'LOC_' || TechnologyContributionTypes.ContributionType || '_NAME';


-----------------------------------------------
-- Buildings
-----------------------------------------------

/* Create new Buildings entries from the temporary BuildingsGCO table */
INSERT OR REPLACE INTO Buildings (BuildingType, Name, PrereqTech, PrereqDistrict, Cost, NoPedia, MaterielPerProduction, AdvisorType, EquipmentStock, Coast, EmploymentSize, ObsoleteEra, MustPurchase, MaxPlayerInstances)
	SELECT BuildingsGCO.BuildingType, 'LOC_' || BuildingsGCO.BuildingType || '_NAME', BuildingsGCO.PrereqTech, BuildingsGCO.PrereqDistrict, BuildingsGCO.Cost, BuildingsGCO.NoPedia, BuildingsGCO.MaterielPerProduction, BuildingsGCO.AdvisorType, BuildingsGCO.EquipmentStock, BuildingsGCO.Coast, BuildingsGCO.EmploymentSize, BuildingsGCO.ObsoleteEra, BuildingsGCO.MustPurchase, BuildingsGCO.MaxPlayerInstances
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

/* Set modifiers for Buildings Upgrades */	
INSERT INTO Modifiers (ModifierId, ModifierType)
	SELECT 'PRODUCTION_BONUS_FROM_' || BuildingUpgrades.BuildingType, 'MODIFIER_SINGLE_CITY_ADJUST_BUILDING_PRODUCTION'
	FROM BuildingUpgrades;
	
INSERT INTO ModifierArguments (ModifierId, Name, Value)
	SELECT 'PRODUCTION_BONUS_FROM_' || BuildingUpgrades.BuildingType, 'BuildingType', BuildingUpgrades.UpgradeType
	FROM BuildingUpgrades;
	
INSERT INTO ModifierArguments (ModifierId, Name, Value)
	SELECT 'PRODUCTION_BONUS_FROM_' || BuildingUpgrades.BuildingType, 'Amount', BuildingUpgrades.ProductionBonus
	FROM BuildingUpgrades;
	
INSERT INTO BuildingModifiers (BuildingType, ModifierId)
	SELECT BuildingUpgrades.BuildingType, 'PRODUCTION_BONUS_FROM_' || BuildingUpgrades.BuildingType
	FROM BuildingUpgrades;


-----------------------------------------------
-- City Names
-----------------------------------------------

/* Clean table */
DELETE FROM CityNames WHERE CivilizationType NOT IN (SELECT Civilizations.CivilizationType from Civilizations);

-----------------------------------------------
-- Culture Groups
-----------------------------------------------

/* Add Name & Adjective Tags */
UPDATE CultureGroups	SET Name 		= 'LOC_' || CultureGroups.CultureType || '_NAME';
UPDATE CultureGroups	SET Adjective 	= 'LOC_' || CultureGroups.CultureType || '_ADJECTIVE';

/* Add all Civilizations to the Culture Groups table */
INSERT INTO CultureGroups (CultureType, Name, Adjective, Ethnicity)
	SELECT C.CivilizationType, C.Name, C.Adjective, C.Ethnicity
	FROM Civilizations AS C;
	

-----------------------------------------------
-- Resources
-----------------------------------------------

/* Create new Resources Types entries from the Equipment table */
INSERT OR REPLACE INTO Types (Type, Kind)
	SELECT Equipment.ResourceType, 'KIND_RESOURCE'
	FROM Equipment;	
	
/* Create new Resources Types entries from the temporary ResourcesGCO table */
INSERT OR REPLACE INTO Types (Type, Kind)
	SELECT ResourcesGCO.ResourceType, 'KIND_RESOURCE'
	FROM ResourcesGCO WHERE NOT EXISTS (SELECT * FROM Resources WHERE Resources.ResourceType = ResourcesGCO.ResourceType); -- "INSERT OR REPLACE" is actually "DELETE AND INSERT" which cause issues on cascade (deleting ResourceType entries from the Resource table) when we just want to update 

/* Create new Resources Types entries from the Populations table */
INSERT OR REPLACE INTO Types (Type, Kind)
	SELECT Populations.PopulationType, 'KIND_RESOURCE'
	FROM Populations;	
	
/* Update existing Resources with column from the temporary ResourcesGCO table (before adding new resources) */
-- The SQLite IFNULL function accepts two arguments and returns the first non-NULL argument. If both arguments are NULL, the IFNULL function returns NULL
UPDATE Resources SET ResourceClassType 			= ifnull((SELECT ResourcesGCO.ResourceClassType 		FROM ResourcesGCO WHERE ResourcesGCO.ResourceType = Resources.ResourceType AND ResourcesGCO.ResourceClassType 			IS NOT NULL) , Resources.ResourceClassType 			);
UPDATE Resources SET Frequency		 			= ifnull((SELECT ResourcesGCO.Frequency 				FROM ResourcesGCO WHERE ResourcesGCO.ResourceType = Resources.ResourceType AND ResourcesGCO.Frequency 					IS NOT NULL) , Resources.Frequency 					);
UPDATE Resources SET PrereqTech 				= ifnull((SELECT ResourcesGCO.PrereqTech 				FROM ResourcesGCO WHERE ResourcesGCO.ResourceType = Resources.ResourceType AND ResourcesGCO.PrereqTech 					IS NOT NULL) , Resources.PrereqTech					);
UPDATE Resources SET FixedPrice 				= ifnull((SELECT ResourcesGCO.FixedPrice 				FROM ResourcesGCO WHERE ResourcesGCO.ResourceType = Resources.ResourceType AND ResourcesGCO.FixedPrice 					IS NOT NULL) , Resources.FixedPrice 				);
UPDATE Resources SET MaxPriceVariationPercent 	= ifnull((SELECT ResourcesGCO.MaxPriceVariationPercent 	FROM ResourcesGCO WHERE ResourcesGCO.ResourceType = Resources.ResourceType AND ResourcesGCO.MaxPriceVariationPercent	IS NOT NULL) , Resources.MaxPriceVariationPercent 	);
UPDATE Resources SET NoExport					= ifnull((SELECT ResourcesGCO.NoExport					FROM ResourcesGCO WHERE ResourcesGCO.ResourceType = Resources.ResourceType AND ResourcesGCO.NoExport					IS NOT NULL) , Resources.NoExport					);
UPDATE Resources SET NoTransfer 				= ifnull((SELECT ResourcesGCO.NoTransfer 				FROM ResourcesGCO WHERE ResourcesGCO.ResourceType = Resources.ResourceType AND ResourcesGCO.NoTransfer 					IS NOT NULL) , Resources.NoTransfer 				);
UPDATE Resources SET SpecialStock 				= ifnull((SELECT ResourcesGCO.SpecialStock 				FROM ResourcesGCO WHERE ResourcesGCO.ResourceType = Resources.ResourceType AND ResourcesGCO.SpecialStock 				IS NOT NULL) , Resources.SpecialStock 				);
UPDATE Resources SET NotLoot 					= ifnull((SELECT ResourcesGCO.NotLoot 					FROM ResourcesGCO WHERE ResourcesGCO.ResourceType = Resources.ResourceType AND ResourcesGCO.NotLoot						IS NOT NULL) , Resources.NotLoot					);
UPDATE Resources SET DecayRate					= ifnull((SELECT ResourcesGCO.DecayRate 				FROM ResourcesGCO WHERE ResourcesGCO.ResourceType = Resources.ResourceType AND ResourcesGCO.DecayRate					IS NOT NULL) , Resources.DecayRate					);
UPDATE Resources SET UnitsPerTonnage			= ifnull((SELECT ResourcesGCO.UnitsPerTonnage 			FROM ResourcesGCO WHERE ResourcesGCO.ResourceType = Resources.ResourceType AND ResourcesGCO.UnitsPerTonnage				IS NOT NULL) , Resources.UnitsPerTonnage			);

/* Create new Resources entries from the temporary ResourcesGCO table (after updating existing resources) */
INSERT OR REPLACE INTO Resources (ResourceType, Name, ResourceClassType, Frequency, PrereqTech, FixedPrice, MaxPriceVariationPercent, NoExport, NoTransfer, SpecialStock, NotLoot, DecayRate, UnitsPerTonnage)
	SELECT ResourcesGCO.ResourceType, 'LOC_' || ResourcesGCO.ResourceType || '_NAME', ResourcesGCO.ResourceClassType, ResourcesGCO.Frequency, ResourcesGCO.PrereqTech, ResourcesGCO.FixedPrice, ResourcesGCO.MaxPriceVariationPercent, ResourcesGCO.NoExport, ResourcesGCO.NoTransfer, ResourcesGCO.SpecialStock, ResourcesGCO.NotLoot, ResourcesGCO.DecayRate, ResourcesGCO.UnitsPerTonnage
	FROM ResourcesGCO WHERE NOT EXISTS (SELECT * FROM Resources WHERE Resources.ResourceType = ResourcesGCO.ResourceType);

/* Create new Resources entries from the Equipment table */
INSERT OR REPLACE INTO Resources (ResourceType, Name, ResourceClassType, Frequency, PrereqTech, FixedPrice, MaxPriceVariationPercent, NoExport, NoTransfer, SpecialStock, NotLoot)
	SELECT Equipment.ResourceType, 'LOC_' || Equipment.ResourceType || '_NAME', Equipment.ResourceClassType, 0, Equipment.PrereqTech, Equipment.FixedPrice, Equipment.MaxPriceVariationPercent, Equipment.NoExport, Equipment.NoTransfer, Equipment.SpecialStock, Equipment.NotLoot
	FROM Equipment;
	
/* update UnitsPerTonnage entries from the Size entries in Equipment table */
UPDATE Resources SET UnitsPerTonnage = 100 / (SELECT Equipment.Size	FROM Equipment WHERE Equipment.ResourceType = Resources.ResourceType AND Equipment.Size < 100);

/* Create new Resources entries from the Population table */
INSERT OR REPLACE INTO Resources (ResourceType, Name, ResourceClassType, Frequency, PrereqTech, FixedPrice, MaxPriceVariationPercent, NoExport, NoTransfer, SpecialStock, NotLoot)
	SELECT Populations.PopulationType, 'LOC_' || Populations.PopulationType || '_NAME', "RESOURCECLASS_POPULATION", 0, NULL, 1, 0, 1, 1, 1, 1
	FROM Populations;


-----------------------------------------------
-- Technologies
-----------------------------------------------

-- Add custom yields for Research Types
INSERT OR REPLACE INTO CustomYields (YieldType , Name, IconString)
	SELECT 'YIELD_' || T.ContributionType, T.Name, T.IconString
	FROM TechnologyContributionTypes AS T WHERE IsResearch ='1';	

-- No boost
DELETE FROM Boosts;

-- TechnologyPrereqs is completly redone
DELETE FROM TechnologyPrereqs;
INSERT OR REPLACE INTO TechnologyPrereqs (Technology, PrereqTech)
	SELECT Technology, PrereqTech
	FROM TechnologyPrereqsGCO;	

--/*
-- This way we can set entries in TechnologiesGCO with just the columns to update and leave the rest empty...
-- The SQLite IFNULL function accepts two arguments and returns the first non-NULL argument. If both arguments are NULL, the IFNULL function returns NULL
UPDATE Technologies SET Cost 			= ifnull((SELECT TechnologiesGCO.Cost 			FROM TechnologiesGCO WHERE TechnologiesGCO.TechnologyType = Technologies.TechnologyType AND TechnologiesGCO.Cost 			IS NOT NULL) , Technologies.Cost 			);
UPDATE Technologies SET Repeatable 		= ifnull((SELECT TechnologiesGCO.Repeatable 	FROM TechnologiesGCO WHERE TechnologiesGCO.TechnologyType = Technologies.TechnologyType AND TechnologiesGCO.Repeatable 		IS NOT NULL) , Technologies.Repeatable 		);
UPDATE Technologies SET EmbarkUnitType 	= ifnull((SELECT TechnologiesGCO.EmbarkUnitType FROM TechnologiesGCO WHERE TechnologiesGCO.TechnologyType = Technologies.TechnologyType AND TechnologiesGCO.EmbarkUnitType 	IS NOT NULL) , Technologies.EmbarkUnitType	);
UPDATE Technologies SET EmbarkAll 		= ifnull((SELECT TechnologiesGCO.EmbarkAll 		FROM TechnologiesGCO WHERE TechnologiesGCO.TechnologyType = Technologies.TechnologyType AND TechnologiesGCO.EmbarkAll 		IS NOT NULL) , Technologies.EmbarkAll 		);
UPDATE Technologies SET Description 	= ifnull((SELECT TechnologiesGCO.Description 	FROM TechnologiesGCO WHERE TechnologiesGCO.TechnologyType = Technologies.TechnologyType AND TechnologiesGCO.Description		IS NOT NULL) , Technologies.Description 	);
UPDATE Technologies SET EraType			= ifnull((SELECT TechnologiesGCO.EraType		FROM TechnologiesGCO WHERE TechnologiesGCO.TechnologyType = Technologies.TechnologyType AND TechnologiesGCO.EraType			IS NOT NULL) , Technologies.EraType			);
UPDATE Technologies SET AdvisorType 	= ifnull((SELECT TechnologiesGCO.AdvisorType 	FROM TechnologiesGCO WHERE TechnologiesGCO.TechnologyType = Technologies.TechnologyType AND TechnologiesGCO.AdvisorType 	IS NOT NULL) , Technologies.AdvisorType 	);
UPDATE Technologies SET Critical 		= ifnull((SELECT TechnologiesGCO.Critical 		FROM TechnologiesGCO WHERE TechnologiesGCO.TechnologyType = Technologies.TechnologyType AND TechnologiesGCO.Critical 		IS NOT NULL) , Technologies.Critical 		);
UPDATE Technologies SET BarbarianFree 	= ifnull((SELECT TechnologiesGCO.BarbarianFree 	FROM TechnologiesGCO WHERE TechnologiesGCO.TechnologyType = Technologies.TechnologyType AND TechnologiesGCO.BarbarianFree	IS NOT NULL) , Technologies.BarbarianFree	);
UPDATE Technologies SET UITreeRow		= ifnull((SELECT TechnologiesGCO.UITreeRow 		FROM TechnologiesGCO WHERE TechnologiesGCO.TechnologyType = Technologies.TechnologyType AND TechnologiesGCO.UITreeRow		IS NOT NULL) , Technologies.UITreeRow		);
--*/

/* Create new Technologies entries from the temporary TechnologiesGCO table (after UPDATE)*/
--/*
INSERT INTO Technologies (TechnologyType, Name, Cost, Repeatable, EmbarkUnitType, EmbarkAll, Description, EraType, AdvisorType, Critical, BarbarianFree, UITreeRow)

	SELECT 
		TechnologiesGCO.TechnologyType,
		'LOC_' || TechnologiesGCO.TechnologyType || '_NAME',
		TechnologiesGCO.Cost,
		ifnull(TechnologiesGCO.Repeatable,0),
		TechnologiesGCO.EmbarkUnitType,
		ifnull(TechnologiesGCO.EmbarkAll,0),
		TechnologiesGCO.Description,
		TechnologiesGCO.EraType,
		ifnull(TechnologiesGCO.AdvisorType,'ADVISOR_GENERIC'),
		ifnull(TechnologiesGCO.Critical,0),
		ifnull(TechnologiesGCO.BarbarianFree, 0),
		ifnull(TechnologiesGCO.UITreeRow, 0)
		
	FROM TechnologiesGCO WHERE NOT EXISTS (SELECT * FROM Technologies WHERE Technologies.TechnologyType = TechnologiesGCO.TechnologyType);
--*/
	
	
/* Create new Technologies Types entries from the temporary TechnologiesGCO table */
INSERT INTO Types (Type, Kind)
	SELECT TechnologiesGCO.TechnologyType, 'KIND_TECH'
	FROM TechnologiesGCO WHERE NOT EXISTS (SELECT * FROM Types WHERE Types.Type = TechnologiesGCO.TechnologyType);

/* Link existing description entries (set in NamesTexts.xml) to Technologies */
UPDATE Technologies SET Description	=	(SELECT Tag FROM LocalizedText WHERE 'LOC_' || Technologies.TechnologyType || '_DESCRIPTION' = Tag AND Language='en_US')
				WHERE EXISTS			(SELECT Tag FROM LocalizedText WHERE 'LOC_' || Technologies.TechnologyType || '_DESCRIPTION' = Tag AND Language='en_US');

/* Link existing name entries for Techs imported from Civics */
UPDATE Technologies SET Name	=	(SELECT Name FROM Civics WHERE Civics.Name = 'LOC_CIVIC_' || substr(Technologies.TechnologyType,6) || '_NAME')
				WHERE EXISTS		(SELECT Name FROM Civics WHERE Civics.Name = 'LOC_CIVIC_' || substr(Technologies.TechnologyType,6) || '_NAME');
				
/* Link existing Description entries for Techs imported from Civics */
UPDATE Technologies SET Description	=	(SELECT Description FROM Civics WHERE Civics.Description = 'LOC_CIVIC_' || substr(Technologies.TechnologyType,6) || '_DESCRIPTION')
				WHERE EXISTS			(SELECT Description FROM Civics WHERE Civics.Description = 'LOC_CIVIC_' || substr(Technologies.TechnologyType,6) || '_DESCRIPTION');

/* Move Policies to Tech tree */
UPDATE Policies SET PrereqCivic = NULL, PrereqTech = (SELECT TechnologyType FROM Technologies WHERE Policies.PrereqCivic IS NOT NULL AND Technologies.TechnologyType = 'TECH_' || substr(Policies.PrereqCivic,7))
				WHERE EXISTS		(SELECT TechnologyType FROM Technologies WHERE Policies.PrereqCivic IS NOT NULL AND Technologies.TechnologyType = 'TECH_' || substr(Policies.PrereqCivic,7));
				
/* Move Buildings to Tech tree */
UPDATE Buildings SET PrereqCivic = NULL, PrereqTech = (SELECT TechnologyType FROM Technologies WHERE Buildings.PrereqCivic IS NOT NULL AND Technologies.TechnologyType = 'TECH_' || substr(Buildings.PrereqCivic,7))
				WHERE EXISTS		(SELECT TechnologyType FROM Technologies WHERE Buildings.PrereqCivic IS NOT NULL AND Technologies.TechnologyType = 'TECH_' || substr(Buildings.PrereqCivic,7));

/* Move Resources to Tech tree */
UPDATE Resources SET PrereqCivic = NULL, PrereqTech = (SELECT TechnologyType FROM Technologies WHERE Resources.PrereqCivic IS NOT NULL AND Technologies.TechnologyType = 'TECH_' || substr(Resources.PrereqCivic,7))
				WHERE EXISTS		(SELECT TechnologyType FROM Technologies WHERE Resources.PrereqCivic IS NOT NULL AND Technologies.TechnologyType = 'TECH_' || substr(Resources.PrereqCivic,7));

/* Move Districts to Tech tree */
UPDATE Districts SET PrereqCivic = NULL, PrereqTech = (SELECT TechnologyType FROM Technologies WHERE Districts.PrereqCivic IS NOT NULL AND Technologies.TechnologyType = 'TECH_' || substr(Districts.PrereqCivic,7))
				WHERE EXISTS		(SELECT TechnologyType FROM Technologies WHERE Districts.PrereqCivic IS NOT NULL AND Technologies.TechnologyType = 'TECH_' || substr(Districts.PrereqCivic,7));

/* Move Improvements to Tech tree */
UPDATE Improvements SET PrereqCivic = NULL, PrereqTech = (SELECT TechnologyType FROM Technologies WHERE Improvements.PrereqCivic IS NOT NULL AND Technologies.TechnologyType = 'TECH_' || substr(Improvements.PrereqCivic,7))
				WHERE EXISTS		(SELECT TechnologyType FROM Technologies WHERE Improvements.PrereqCivic IS NOT NULL AND Technologies.TechnologyType = 'TECH_' || substr(Improvements.PrereqCivic,7));

/* Move Units to Tech tree */
UPDATE Units SET PrereqCivic = NULL, PrereqTech = (SELECT TechnologyType FROM Technologies WHERE Units.PrereqCivic IS NOT NULL AND Technologies.TechnologyType = 'TECH_' || substr(Units.PrereqCivic,7))
				WHERE EXISTS		(SELECT TechnologyType FROM Technologies WHERE Units.PrereqCivic IS NOT NULL AND Technologies.TechnologyType = 'TECH_' || substr(Units.PrereqCivic,7));

/* Move DiplomaticActions to Tech tree */
UPDATE DiplomaticActions SET InitiatorPrereqCivic = NULL, InitiatorPrereqTech = (SELECT TechnologyType FROM Technologies WHERE DiplomaticActions.InitiatorPrereqCivic IS NOT NULL AND Technologies.TechnologyType = 'TECH_' || substr(DiplomaticActions.InitiatorPrereqCivic,7))
				WHERE EXISTS		(SELECT TechnologyType FROM Technologies WHERE DiplomaticActions.InitiatorPrereqCivic IS NOT NULL AND Technologies.TechnologyType = 'TECH_' || substr(DiplomaticActions.InitiatorPrereqCivic,7));
UPDATE DiplomaticActions SET TargetPrereqCivic = NULL, TargetPrereqTech = (SELECT TechnologyType FROM Technologies WHERE DiplomaticActions.TargetPrereqCivic IS NOT NULL AND Technologies.TechnologyType = 'TECH_' || substr(DiplomaticActions.TargetPrereqCivic,7))
				WHERE EXISTS		(SELECT TechnologyType FROM Technologies WHERE DiplomaticActions.TargetPrereqCivic IS NOT NULL AND Technologies.TechnologyType = 'TECH_' || substr(DiplomaticActions.TargetPrereqCivic,7));

/* Create new Technologies Modifiers entries from the CivicModifiers table */
INSERT INTO TechnologyModifiers (TechnologyType, ModifierId)
	SELECT 'TECH_' || substr(C.CivicType,7), C.ModifierId
	FROM CivicModifiers AS C WHERE EXISTS (SELECT TechnologyType FROM Technologies WHERE Technologies.TechnologyType = 'TECH_' || substr(C.CivicType,7));

/* Remove Techs that are not in the TechnologiesGCO table */
DELETE FROM Technologies WHERE TechnologyType NOT IN (SELECT TechnologyType from TechnologiesGCO);

/* Technology cost */
UPDATE Technologies SET Cost = Cost*2.00 WHERE EraType ='ERA_ANCIENT';
UPDATE Technologies SET Cost = Cost*2.20 WHERE EraType ='ERA_CLASSICAL';
UPDATE Technologies SET Cost = Cost*2.40 WHERE EraType ='ERA_MEDIEVAL';
UPDATE Technologies SET Cost = Cost*2.70 WHERE EraType ='ERA_RENAISSANCE';
UPDATE Technologies SET Cost = Cost*3.00 WHERE EraType ='ERA_INDUSTRIAL';
UPDATE Technologies SET Cost = Cost*3.40 WHERE EraType ='ERA_MODERN';
UPDATE Technologies SET Cost = Cost*3.80 WHERE EraType ='ERA_ARMS_RACE';
UPDATE Technologies SET Cost = Cost*4.30 WHERE EraType ='ERA_ATOMIC';
UPDATE Technologies SET Cost = Cost*4.80 WHERE EraType ='ERA_INFORMATION';
UPDATE Technologies SET Cost = Cost*5.50 WHERE EraType ='ERA_FUTURE';

/* Remove description if asked */	
UPDATE Technologies SET Description	=	NULL
			WHERE EXISTS (SELECT * FROM TechnologiesGCO WHERE Technologies.TechnologyType = TechnologiesGCO.TechnologyType AND TechnologiesGCO.Description = 'NONE');

/* Create Resources from Technologies */
INSERT OR REPLACE INTO Resources (ResourceType, Name, ResourceClassType, Frequency, FixedPrice, SpecialStock, TechnologyType)
	SELECT 'RESOURCE_KNOWLEDGE_' || Technologies.TechnologyType , '{' || Technologies.Name || '} {LOC_RESOURCECLASS_KNOWLEDGE}', 'RESOURCECLASS_KNOWLEDGE', 0, 1, 1, Technologies.TechnologyType
	FROM Technologies;
INSERT OR REPLACE INTO Resources (ResourceType, Name, ResourceClassType, Frequency, FixedPrice, SpecialStock, TechnologyType)
	SELECT 'RESOURCE_TABLETS_' || Technologies.TechnologyType , '{' || Technologies.Name || '} {LOC_RESOURCECLASS_TABLETS}', 'RESOURCECLASS_TABLETS', 0, 0, 1, Technologies.TechnologyType
	FROM Technologies;
INSERT OR REPLACE INTO Resources (ResourceType, Name, ResourceClassType, Frequency, FixedPrice, SpecialStock, TechnologyType)
	SELECT 'RESOURCE_SCROLLS_' || Technologies.TechnologyType , '{' || Technologies.Name || '} {LOC_RESOURCECLASS_SCROLLS}', 'RESOURCECLASS_SCROLLS', 0, 0, 1, Technologies.TechnologyType
	FROM Technologies;
INSERT OR REPLACE INTO Resources (ResourceType, Name, ResourceClassType, Frequency, FixedPrice, SpecialStock, TechnologyType)
	SELECT 'RESOURCE_BOOKS_' || Technologies.TechnologyType , '{' || Technologies.Name || '} {LOC_RESOURCECLASS_BOOKS}', 'RESOURCECLASS_BOOKS', 0, 0, 1, Technologies.TechnologyType
	FROM Technologies;
INSERT OR REPLACE INTO Resources (ResourceType, Name, ResourceClassType, Frequency, FixedPrice, SpecialStock, TechnologyType)
	SELECT 'RESOURCE_DIGITAL_' || Technologies.TechnologyType , '{' || Technologies.Name || '} {LOC_RESOURCECLASS_DIGITAL}', 'RESOURCECLASS_DIGITAL', 0, 0, 1, Technologies.TechnologyType
	FROM Technologies;
	
INSERT OR REPLACE INTO Types (Type, Kind)
	SELECT 'RESOURCE_KNOWLEDGE_' || Technologies.TechnologyType, 'KIND_RESOURCE'
	FROM Technologies;
INSERT OR REPLACE INTO Types (Type, Kind)
	SELECT 'RESOURCE_TABLETS_' || Technologies.TechnologyType, 'KIND_RESOURCE'
	FROM Technologies;
INSERT OR REPLACE INTO Types (Type, Kind)
	SELECT 'RESOURCE_SCROLLS_' || Technologies.TechnologyType, 'KIND_RESOURCE'
	FROM Technologies;
INSERT OR REPLACE INTO Types (Type, Kind)
	SELECT 'RESOURCE_BOOKS_' || Technologies.TechnologyType, 'KIND_RESOURCE'
	FROM Technologies;
INSERT OR REPLACE INTO Types (Type, Kind)
	SELECT 'RESOURCE_DIGITAL_' || Technologies.TechnologyType, 'KIND_RESOURCE'
	FROM Technologies;


/* Create Resources from Research Types */
INSERT OR REPLACE INTO Resources (ResourceType, Name, ResourceClassType, Frequency, FixedPrice, ResearchType)
	SELECT 'RESOURCE_KNOWLEDGE_' || T.ContributionType , '{' || T.Name || '} {LOC_RESOURCECLASS_KNOWLEDGE}', 'RESOURCECLASS_KNOWLEDGE', 0, 1, T.ContributionType
	FROM TechnologyContributionTypes AS T WHERE IsResearch ='1';
	
INSERT OR REPLACE INTO Types (Type, Kind)
	SELECT 'RESOURCE_KNOWLEDGE_' || T.ContributionType, 'KIND_RESOURCE'
	FROM TechnologyContributionTypes AS T WHERE IsResearch ='1';
		
	
--UPDATE Eras SET EraTechBackgroundTexture = 'TechTree_BG_ARMRACE' WHERE EraType ='ERA_MODERN';

/*
INSERT INTO TechnologyPrereqs(Technology, PrereqTech)
	SELECT TechnologyType, TechnologyType
	FROM Technologies WHERE substr(Technologies.TechnologyType,1,11) = 'TECH_UNLOCK';
--*/
	
/* Civics cost 
UPDATE Civics SET Cost = Cost*1.20 WHERE EraType ='ERA_ANCIENT';
UPDATE Civics SET Cost = Cost*1.60 WHERE EraType ='ERA_CLASSICAL';
UPDATE Civics SET Cost = Cost*1.80 WHERE EraType ='ERA_MEDIEVAL';
UPDATE Civics SET Cost = Cost*2.00 WHERE EraType ='ERA_RENAISSANCE';
UPDATE Civics SET Cost = Cost*2.30 WHERE EraType ='ERA_INDUSTRIAL';
UPDATE Civics SET Cost = Cost*2.70 WHERE EraType ='ERA_MODERN';
UPDATE Civics SET Cost = Cost*3.20 WHERE EraType ='ERA_ATOMIC';
UPDATE Civics SET Cost = Cost*3.80 WHERE EraType ='ERA_INFORMATION';
*/

UPDATE Civics SET Cost = 999999;

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



/* Starting resources (last as this will cause a DB error if YnAMP is not activated */
DELETE from CivilizationRequestedResource;
INSERT OR REPLACE INTO CivilizationRequestedResource (Civilization, Resource, Quantity)
	SELECT Civilizations.CivilizationType, 'RESOURCE_STONE', 1 FROM Civilizations;	
INSERT OR REPLACE INTO CivilizationRequestedResource (Civilization, Resource, Quantity)
	SELECT Civilizations.CivilizationType, 'RESOURCE_HORSES', 1 FROM Civilizations;		
INSERT OR REPLACE INTO CivilizationRequestedResource (Civilization, Resource, Quantity)
	SELECT Civilizations.CivilizationType, 'RESOURCE_WHEAT', 1 FROM Civilizations WHERE Ethnicity = 'ETHNICITY_MEDIT' OR  Ethnicity = 'ETHNICITY_EURO' OR  Ethnicity = 'ETHNICITY_SOUTHAM';	
INSERT OR REPLACE INTO CivilizationRequestedResource (Civilization, Resource, Quantity)
	SELECT Civilizations.CivilizationType, 'RESOURCE_RICE', 1 FROM Civilizations WHERE Ethnicity = 'ETHNICITY_ASIAN' OR  Ethnicity = 'ETHNICITY_AFRICAN';