/*
	GCO
	by Gedemon (2017)
	
*/

-----------------------------------------------
-- Modify Tables
-----------------------------------------------

-- Composition in personnel, vehicles and horses of an unit at full health 
ALTER TABLE Units ADD COLUMN Personnel integer DEFAULT '0';
ALTER TABLE Units ADD COLUMN Vehicles integer DEFAULT '0';
ALTER TABLE Units ADD COLUMN Horses integer DEFAULT '0';

-- Materiel required  
ALTER TABLE Units ADD COLUMN Materiel integer DEFAULT '0'; 				-- total value for unit at 100% health, representing equipement, armement and munitions
ALTER TABLE Units ADD COLUMN MaterielPerVehicles integer DEFAULT '0'; 	-- materiel required to replace a vehicle (reparing cost less)

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
-- Create Start Positions Table if needed
-----------------------------------------------

CREATE TABLE IF NOT EXISTS StartPosition
	(	MapName TEXT,
		Civilization TEXT,
		Leader TEXT,
		X INT default 0,
		Y INT default 0);