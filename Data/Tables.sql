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
ALTER TABLE Buildings ADD COLUMN NoPedia 		BOOLEAN NOT NULL CHECK (NoPedia IN (0,1)) DEFAULT 0; -- Do not show in Civilopedia
ALTER TABLE Buildings ADD COLUMN NoCityScreen 	BOOLEAN NOT NULL CHECK (NoCityScreen IN (0,1)) DEFAULT 0; -- Do not show in City Screens

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
	
CREATE TABLE IF NOT EXISTS UnitEquipmentResources
	(
		EquipmentType TEXT NOT NULL,
		ResourceType TEXT NOT NULL,
		Amount INTEGER NOT NULL DEFAULT 0,
		PRIMARY KEY(EquipmentType, ResourceType),
		FOREIGN KEY (ResourceType) REFERENCES Resources(ResourceType) ON DELETE CASCADE ON UPDATE CASCADE
	);
		
CREATE TABLE IF NOT EXISTS UnitEquipments 
	(
		EquipmentType TEXT NOT NULL,												-- TYPE_TANK, TYPE_MODERN_ARMOR, TYPE_CHARIOT, ...
		EquipmentName TEXT,															-- "Tanks", "Iron Materiel",...
		EquipmentClass TEXT, 														-- CLASS_VEHICLE, CLASS_GEAR, ...
		CanBeRepaired BOOLEAN NOT NULL CHECK (CanBeRepaired IN (0,1)) DEFAULT 1,	-- Can this equipment be repaired on the fiel, or does it need a complete replacement
		UseInStats BOOLEAN NOT NULL CHECK (UseInStats IN (0,1)) DEFAULT 1,			-- Should we track losses in unit's statistic
		PRIMARY KEY(EquipmentType)
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


-----------------------------------------------
-- Edit Tables
-----------------------------------------------

/* Civilopedia query */
DELETE FROM CivilopediaPageQueries WHERE SectionId ='BUILDINGS'; -- recreated in GamePlay.xml
