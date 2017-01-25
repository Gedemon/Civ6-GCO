/*
	GCO
	by Gedemon (2017)
	
*/

-----------------------------------------------
-- Modify Tables
-----------------------------------------------

-- Composition in personnel, vehicules and horses of an unit at full health 
ALTER TABLE Units ADD COLUMN Personnel integer DEFAULT '0';
ALTER TABLE Units ADD COLUMN Vehicules integer DEFAULT '0';
ALTER TABLE Units ADD COLUMN Horses integer DEFAULT '0';

-- Materiel required  
ALTER TABLE Units ADD COLUMN Materiel integer DEFAULT '0'; 				-- total value for unit at 100% health, representing equipement, armement and munitions
ALTER TABLE Units ADD COLUMN MaterielPerVehicule integer DEFAULT '0'; 	-- materiel required to replace a vehicule (reparing cost less)

-- Fuel usage for mechanized units
ALTER TABLE Units ADD COLUMN FuelConsumptionPerVehicule real DEFAULT '0';
ALTER TABLE Units ADD COLUMN FuelType TEXT; -- resource type used as fuel