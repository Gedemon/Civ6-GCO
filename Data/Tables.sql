/*
	GCO
	by Gedemon (2017)
	
*/

-----------------------------------------------
-- Modified Tables
-----------------------------------------------

-- Composition in personnel, vehicles and horses of an unit at full health 
ALTER TABLE Units ADD COLUMN Personnel integer DEFAULT '0';
ALTER TABLE Units ADD COLUMN Equipment integer DEFAULT '0';
ALTER TABLE Units ADD COLUMN EquipmentType TEXT;
ALTER TABLE Units ADD COLUMN Horses integer DEFAULT '0';

-- Materiel required  
ALTER TABLE Units ADD COLUMN Materiel integer DEFAULT '0'; 				-- total value for unit at 100% health, representing general equipement, armement and munitions
ALTER TABLE Units ADD COLUMN MaterielPerEquipment integer DEFAULT '0'; 	-- materiel required to replace a vehicle (reparing cost less)

-- Fuel usage for mechanized units
ALTER TABLE Units ADD COLUMN FuelConsumptionPerVehicle real DEFAULT '0';
ALTER TABLE Units ADD COLUMN FuelType TEXT; -- resource type used as fuel

-- Casualties modifier
ALTER TABLE Units ADD COLUMN AntiPersonnel 	integer DEFAULT '55'; -- 100 means all personnel casualties are dead, no wounded, no prisonners
ALTER TABLE Units ADD COLUMN AntiArmor 		integer DEFAULT '20';
ALTER TABLE Units ADD COLUMN AntiShip 		integer DEFAULT '50';
ALTER TABLE Units ADD COLUMN AntiAir 		integer DEFAULT '50';

-- Columns used when Culture Diffusion is ON and CULTURE_DIFFUSION_VARIATION_BY_ERA = 1
ALTER TABLE Eras ADD COLUMN CultureMinimumForAcquisitionMod integer DEFAULT '100';		-- Percentage of CULTURE_MINIMUM_FOR_ACQUISITION
ALTER TABLE Eras ADD COLUMN CultureDiffusionThresholdMod integer DEFAULT '100';			-- Percentage of CULTURE_DIFFUSION_THRESHOLD
ALTER TABLE Eras ADD COLUMN CultureFlippingMaxDistance integer DEFAULT '100';			-- Replace CULTURE_FLIPPING_MAX_DISTANCE (0 = unlimited)
ALTER TABLE Eras ADD COLUMN CultureConquestEnabled integer DEFAULT '100';				-- Replace CULTURE_CONQUEST_ENABLED (boolean = 0,1) 

-- Culture Diffusion modifiers
ALTER TABLE Features ADD COLUMN CultureThreshold integer DEFAULT '0';
ALTER TABLE Features ADD COLUMN CulturePenalty integer DEFAULT '0';
ALTER TABLE Features ADD COLUMN CultureMaxPercent integer DEFAULT '0';
ALTER TABLE Terrains ADD COLUMN CultureThreshold integer DEFAULT '0';
ALTER TABLE Terrains ADD COLUMN CulturePenalty integer DEFAULT '0';
ALTER TABLE Terrains ADD COLUMN CultureMaxPercent integer DEFAULT '0';

-- Resources trading
ALTER TABLE Resources ADD COLUMN NoExport 	BOOLEAN NOT NULL CHECK (NoExport IN (0,1)) DEFAULT 0; -- Not allowed on international trade routes
ALTER TABLE Resources ADD COLUMN NoTransfer BOOLEAN NOT NULL CHECK (NoTransfer IN (0,1)) DEFAULT 0; -- Not allowed on internal trade routes

-- Hidden Buildings
ALTER TABLE Buildings ADD COLUMN NoPedia 		BOOLEAN NOT NULL CHECK (NoPedia IN (0,1)) DEFAULT 0; 		-- Do not show in Civilopedia
ALTER TABLE Buildings ADD COLUMN NoCityScreen 	BOOLEAN NOT NULL CHECK (NoCityScreen IN (0,1)) DEFAULT 0; 	-- Do not show in City Screens
ALTER TABLE Buildings ADD COLUMN Unlockers 		BOOLEAN NOT NULL CHECK (Unlockers IN (0,1)) DEFAULT 0; 		-- Unlockers for buildings and units

-- Materiel ratio for Buildings construction
ALTER TABLE Buildings ADD COLUMN MaterielPerProduction 	INTEGER DEFAULT '4'; 		-- Materiel per unit of production needed for buildings construction

-----------------------------------------------
-- New Tables
-----------------------------------------------

CREATE TABLE IF NOT EXISTS BuildingResourcesConverted
	(
		BuildingType TEXT NOT NULL,
		ResourceType TEXT NOT NULL,
		ResourceCreated TEXT NOT NULL,
		MultiResRequired BOOLEAN NOT NULL CHECK (MultiResRequired IN (0,1)) DEFAULT 0,	-- ResourceCreated requires multiple ResourceType (multi rows definition)
		MultiResCreated BOOLEAN NOT NULL CHECK (MultiResCreated IN (0,1)) DEFAULT 0,	-- 1 unit of ResourceType creates multiple ResourceCreated (multi rows definition)
		MaxConverted INTEGER NOT NULL DEFAULT 0,
		Ratio REAL NOT NULL DEFAULT 1,
		Priority INTEGER NOT NULL DEFAULT 0, -- higher value means higher priority when consuming resources
		PRIMARY KEY(BuildingType, ResourceType, ResourceCreated),
		FOREIGN KEY (BuildingType) REFERENCES Buildings(BuildingType) ON DELETE CASCADE ON UPDATE CASCADE,
		FOREIGN KEY (ResourceType) REFERENCES Resources(ResourceType) ON DELETE CASCADE ON UPDATE CASCADE,		
		FOREIGN KEY (ResourceCreated) REFERENCES Resources(ResourceType) ON DELETE CASCADE ON UPDATE CASCADE
	);
	
CREATE TABLE IF NOT EXISTS BuildingStock
	(
		BuildingType TEXT NOT NULL,
		ResourceType TEXT NOT NULL,
		Stock INTEGER NOT NULL DEFAULT 0,
		PRIMARY KEY(BuildingType, ResourceType),
		FOREIGN KEY (BuildingType) REFERENCES Buildings(BuildingType) ON DELETE CASCADE ON UPDATE CASCADE,
		FOREIGN KEY (ResourceType) REFERENCES Resources(ResourceType) ON DELETE CASCADE ON UPDATE CASCADE
	);
	
CREATE TABLE IF NOT EXISTS BuildingPopulationEffect
	(
		BuildingType TEXT NOT NULL,
		PopulationType TEXT NOT NULL,		-- POPULATION_UPPER, POPULATION_MIDDLE, POPULATION_LOWER, POPULATION_SLAVE
		EffectType TEXT NOT NULL,			-- CLASS_MAX_PERCENT, CLASS_MIN_PERCENT
		EffectValue INTEGER NOT NULL DEFAULT 0,
		PRIMARY KEY(BuildingType, PopulationType, EffectType),
		FOREIGN KEY (BuildingType) REFERENCES Buildings(BuildingType) ON DELETE CASCADE ON UPDATE CASCADE,
		FOREIGN KEY (PopulationType) REFERENCES Populations(PopulationType) ON DELETE CASCADE ON UPDATE CASCADE
	);
	
CREATE TABLE IF NOT EXISTS FeatureResourcesProduced
	(
		FeatureType TEXT NOT NULL,
		ResourceType TEXT NOT NULL,
		NumPerFeature REAL NOT NULL DEFAULT 0,
		PRIMARY KEY(FeatureType, ResourceType),
		FOREIGN KEY (FeatureType) REFERENCES Features(FeatureType) ON DELETE CASCADE ON UPDATE CASCADE,
		FOREIGN KEY (ResourceType) REFERENCES Resources(ResourceType) ON DELETE CASCADE ON UPDATE CASCADE
	);
	
CREATE TABLE IF NOT EXISTS TerrainResourcesProduced
	(
		TerrainType TEXT NOT NULL,
		ResourceType TEXT NOT NULL,
		NumPerTerrain REAL NOT NULL DEFAULT 0,
		PRIMARY KEY(TerrainType, ResourceType),
		FOREIGN KEY (TerrainType) REFERENCES Terrains(TerrainType) ON DELETE CASCADE ON UPDATE CASCADE,
		FOREIGN KEY (ResourceType) REFERENCES Resources(ResourceType) ON DELETE CASCADE ON UPDATE CASCADE
	);
	
CREATE TABLE IF NOT EXISTS Populations
	(
		PopulationType TEXT NOT NULL,
		Name TEXT NOT NULL,
		Description TEXT NOT NULL,
		PRIMARY KEY(PopulationType)
	);
	
CREATE TABLE IF NOT EXISTS ResourceStockUsage
	(
		ResourceType TEXT NOT NULL,
		MinPercentLeftToSupply INTEGER NOT NULL DEFAULT 50,		-- stock above that percentage are available for reinforcing units
		MinPercentLeftToTransfer INTEGER NOT NULL DEFAULT 75,	-- stock above that percentage are available for transfer to other cities of the same civilization
		MinPercentLeftToExport INTEGER NOT NULL DEFAULT 75,		-- stock above that percentage are available for trade with other civilizations cities
		MinPercentLeftToConvert INTEGER NOT NULL DEFAULT 0,		-- stock above that percentage are available for use by local industries
		MaxPercentLeftToRequest INTEGER NOT NULL DEFAULT 100,	-- until that percentage is reached, allow trade from other civilizations cities 
		MaxPercentLeftToImport INTEGER NOT NULL DEFAULT 75,		-- until that percentage is reached, allow internal transfer from other cities of the same civilization (must be <= MinPercentLeftToExport)
		PRIMARY KEY(ResourceType),
		FOREIGN KEY (ResourceType) REFERENCES Resources(ResourceType) ON DELETE CASCADE ON UPDATE CASCADE
	);
	
		
CREATE TABLE IF NOT EXISTS EquipmentClasses 
	(
		EquipmentClass TEXT NOT NULL, 		-- CLASS_VEHICLE, CLASS_GEAR, ...
		Name TEXT,							-- "Tanks", "Iron Materiel",...
		PRIMARY KEY(EquipmentClass)
	);
	
CREATE TABLE IF NOT EXISTS EquipmentTypeClasses 
	(
		ResourceType TEXT NOT NULL,
		EquipmentClass TEXT NOT NULL, 				
		PRIMARY KEY(ResourceType, EquipmentClass)	-- an equipment could belong to multiple classes
	);
	
CREATE TABLE IF NOT EXISTS Equipment
	(
		ResourceType TEXT NOT NULL,							-- Equipment are handled as resources
		EquipmentSize INTEGER NOT NULL DEFAULT 1,			-- Space taken in a city stockage capacity
		Desirability INTEGER NOT NULL DEFAULT 0,			-- Units will request ResourceType of higher desirability first
		Toughness INTEGER NOT NULL DEFAULT 0,				-- Global value used to determine if a equipment casualty result in destruction or damage (or prevent the equipment casualty and sent it to reserve depending of requirement)
		PersonnelArmor INTEGER NOT NULL DEFAULT 0,
		AntiPersonnel INTEGER NOT NULL DEFAULT 0,
		AntiPersonnelArmor INTEGER NOT NULL DEFAULT 0,
		IgnorePersonnelArmor INTEGER NOT NULL DEFAULT 0,
		VehicleArmor INTEGER NOT NULL DEFAULT 0,
		AntiVehicle INTEGER NOT NULL DEFAULT 0,
		AntiVehicleArmor INTEGER NOT NULL DEFAULT 0,
		IgnoreVehicleArmor INTEGER NOT NULL DEFAULT 0,
		Reliability INTEGER,								-- Percentage, 100 means no loss from breakdown, lower values means possible loss from unreliability (instead of damaged send in reserve)
		FuelConsumption INTEGER,
		FuelType TEXT,
		PRIMARY KEY(ResourceType),
		FOREIGN KEY (ResourceType) REFERENCES Resources(ResourceType) ON DELETE CASCADE ON UPDATE CASCADE
	);
	
CREATE TABLE IF NOT EXISTS EquipmentEffects 
	(
		ResourceType TEXT, 				
		EquipmentEffect TEXT,
		EffectMaxStrength INTEGER NOT NULL DEFAULT 0,
		PRIMARY KEY(ResourceType, EquipmentEffect)		-- an equipment could have multiple effects
	);
		
CREATE TABLE IF NOT EXISTS UnitEquipmentClasses 
	(
		UnitType TEXT NOT NULL,
		EquipmentClass TEXT, 														-- 
		MaxAmount INTEGER,															-- When NULL use the unit's Personnel value
		IsRequired BOOLEAN NOT NULL CHECK (IsRequired IN (0,1)) DEFAULT 1,			-- If required, the equipement is part of the healing table 
		CanBeRepaired BOOLEAN NOT NULL CHECK (CanBeRepaired IN (0,1)) DEFAULT 0,	-- Can this equipment be repaired in reserve, or does it need a complete replacement
		UseInStats BOOLEAN NOT NULL CHECK (UseInStats IN (0,1)) DEFAULT 0,			-- Should we track this equipment losses in unit's statistic
		PRIMARY KEY(UnitType, EquipmentClass),
		FOREIGN KEY (UnitType) REFERENCES Units(UnitType) ON DELETE CASCADE ON UPDATE CASCADE,
		FOREIGN KEY (EquipmentClass) REFERENCES EquipmentClasses(EquipmentClass) ON DELETE CASCADE ON UPDATE CASCADE
	);	
	
CREATE TABLE IF NOT EXISTS PopulationNeeds
	(
		ResourceType TEXT NOT NULL,
		PopulationType TEXT NOT NULL,
		--EffectType TEXT NOT NULL,		-- HUNGER, ... (allow same resource and same population type to have different effect
		AffectedType TEXT NOT NULL,		-- DEATH_RATE, BIRTH_RATE, STABILITY, ... (same resource, same population and same effect can affect multiple point)
		StartEra TEXT,
		EndEra TEXT,
		Priority INTEGER NOT NULL DEFAULT 0, -- higher value means higher priority when consuming resources
		Ratio REAL NOT NULL DEFAULT 0,	-- consumption ratio
		NeededCalculFunction TEXT NOT NULL,	-- function to get the value of the need from Population number
		OnlyBonus BOOLEAN NOT NULL CHECK (OnlyBonus IN (0,1)) DEFAULT 0,	-- only apply effect if stock > needed
		OnlyPenalty BOOLEAN NOT NULL CHECK (OnlyPenalty IN (0,1)) DEFAULT 1,	-- only apply effect if stock < needed		
		EffectCalculFunction TEXT NOT NULL,	-- DIFF (max(0,needed-stock)) | PERCENT (MaxEffectValue*(100-stock/needed*100))	  or needed/stock if stock > needed
		MaxEffectValue INTEGER,			-- max value for the result of EffectCalculType
		Treshold INTEGER,				-- don't apply value under that Treshold
		PRIMARY KEY(ResourceType, PopulationType, AffectedType),
		FOREIGN KEY (ResourceType) REFERENCES Resources(ResourceType) ON DELETE CASCADE ON UPDATE CASCADE,
		FOREIGN KEY (PopulationType) REFERENCES Populations(PopulationType) ON DELETE CASCADE ON UPDATE CASCADE
	);

CREATE TABLE IF NOT EXISTS CustomYields 
	(
		YieldType TEXT NOT NULL,
		Name TEXT NOT NULL,
		IconString TEXT NOT NULL,
		OccupiedCityChange REAL NOT NULL DEFAULT 0,
		PRIMARY KEY(YieldType)
	);
	
CREATE TABLE IF NOT EXISTS Building_CustomYieldChanges 
	(
		BuildingType TEXT NOT NULL,
		YieldType TEXT NOT NULL,
		YieldChange INTEGER NOT NULL,
		PRIMARY KEY(BuildingType, YieldType),
		FOREIGN KEY (BuildingType) REFERENCES Buildings(BuildingType) ON DELETE CASCADE ON UPDATE CASCADE,
		FOREIGN KEY (YieldType) REFERENCES CustomYields(YieldType) ON DELETE CASCADE ON UPDATE CASCADE
	);
	
/* BuildingRealPrereqsOR is created in Unlockers.sql and is a copy of BuildingPrereqs */
CREATE TABLE IF NOT EXISTS BuildingRealPrereqsAND
	(
		Building TEXT NOT NULL,
		PrereqBuilding TEXT NOT NULL,
		PRIMARY KEY(Building, PrereqBuilding),
		FOREIGN KEY (Building) REFERENCES Buildings(BuildingType) ON DELETE CASCADE ON UPDATE CASCADE,
		FOREIGN KEY (PrereqBuilding) REFERENCES Buildings(BuildingType) ON DELETE CASCADE ON UPDATE CASCADE
	);

/* Unit_RealBuildingPrereqsOR is created in Unlockers.sql and is a copy of Unit_BuildingPrereqs */
CREATE TABLE Unit_RealBuildingPrereqsAND
	(
		Unit TEXT NOT NULL,
		PrereqBuilding TEXT NOT NULL,
		NumSupported INTEGER NOT NULL DEFAULT -1,
		PRIMARY KEY(Unit, PrereqBuilding),
		FOREIGN KEY (Unit) REFERENCES Units(UnitType) ON DELETE CASCADE ON UPDATE CASCADE,
		FOREIGN KEY (PrereqBuilding) REFERENCES Buildings(BuildingType) ON DELETE CASCADE ON UPDATE CASCADE
	);
	
-----------------------------------------------
-- Edit Tables
-----------------------------------------------

/* Civilopedia query */
DELETE FROM CivilopediaPageQueries WHERE SectionId ='BUILDINGS'; -- recreated in GamePlay.xml
