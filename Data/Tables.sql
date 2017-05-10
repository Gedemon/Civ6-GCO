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


-----------------------------------------------
-- New Tables
-----------------------------------------------

CREATE TABLE IF NOT EXISTS BuildingResourcesConverted
	(
		BuildingType TEXT NOT NULL,
		ResourceType TEXT NOT NULL,
		ResourceCreated TEXT NOT NULL,
		MaxConverted INTEGER NOT NULL DEFAULT 0,
		Ratio REAL NOT NULL DEFAULT 0,
		PRIMARY KEY(BuildingType, ResourceType),
		FOREIGN KEY (BuildingType) REFERENCES Buildings(BuildingType) ON DELETE CASCADE ON UPDATE CASCADE,
		FOREIGN KEY (ResourceType) REFERENCES Resources(ResourceType) ON DELETE CASCADE ON UPDATE CASCADE
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
	
CREATE TABLE IF NOT EXISTS UnitEquipmentResourcesPrereqs
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

