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