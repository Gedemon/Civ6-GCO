/*
	Gedemon's Civilization Overhaul
	Generic Rules
	Gedemon (2017)
*/

/* Replaces */
UPDATE GlobalParameters SET Value = 65534	WHERE Name = 'CITY_GROWTH_THRESHOLD';						-- default = 15
UPDATE GlobalParameters SET Value = 1		WHERE Name = 'CITY_GROWTH_MULTIPLIER';						-- default = 8
UPDATE GlobalParameters SET Value = 1		WHERE Name = 'CITY_GROWTH_EXPONENT';						-- default = 1.5
UPDATE GlobalParameters SET Value = 0		WHERE Name = 'CITY_FOOD_CONSUMPTION_PER_POPULATION';		-- default = 2
UPDATE GlobalParameters SET Value = 0		WHERE Name = 'CITY_CAPTURED_DAMAGE_PERCENTAGE';				-- default = 50
UPDATE GlobalParameters SET Value = 999		WHERE Name = 'CITY_AMENITIES_FOR_FREE';						-- default = 1
UPDATE GlobalParameters SET Value = 999		WHERE Name = 'CITY_POP_PER_AMENITY';						-- default = 2
UPDATE GlobalParameters SET Value = 0		WHERE Name = 'CITY_POPULATION_LOSS_TO_CONQUEST_PERCENTAGE';	-- default = 0.25
 
/* Defines */

-- city
INSERT OR REPLACE INTO GlobalParameters (Name, Value) VALUES ('CITY_STOCK_PER_SIZE', 					40);	-- base stock for resource 			= CITY_STOCK_PER_SIZE * CitySize
INSERT OR REPLACE INTO GlobalParameters (Name, Value) VALUES ('CITY_FOOD_STOCK_PER_SIZE', 				50);	-- base stock for food	 			= CITY_FOOD_STOCK_PER_SIZE * CitySize
INSERT OR REPLACE INTO GlobalParameters (Name, Value) VALUES ('CITY_STOCK_EQUIPMENT', 					1000);	-- base stock for equipment 		(not related to city size)
INSERT OR REPLACE INTO GlobalParameters (Name, Value) VALUES ('CITY_MATERIEL_PRODUCTION_PER_SIZE',		12);	-- unit of materiel produced 		= CITY_MATERIEL_PRODUCTION_PER_SIZE * CitySize
INSERT OR REPLACE INTO GlobalParameters (Name, Value) VALUES ('CITY_CONSTRUCTION_MINIMUM_STOCK_RATIO',	0.5);	-- minimum stock for construction 	= CITY_CONSTRUCTION_MINIMUM_STOCK_RATIO * stock
--INSERT OR REPLACE INTO GlobalParameters (Name, Value) VALUES ('CITY_MATERIEL_PER_BUIDING_COST',			4);	-- unit of materiel used by unit of cost for buiding construction
INSERT OR REPLACE INTO GlobalParameters (Name, Value) VALUES ('CITY_PERSONNEL_PER_SIZE', 				250);	-- base housing for personnel 	= CITY_PERSONNEL_PER_SIZE + CitySize
INSERT OR REPLACE INTO GlobalParameters (Name, Value) VALUES ('CITY_STARTING_POPULATION_BONUS', 		2500);	-- value added to the starting population of a new city (to do : Settlers with different size for late game)
INSERT OR REPLACE INTO GlobalParameters (Name, Value) VALUES ('CITY_BASE_FOOD_STOCK', 					100);	-- bonus food stock added to base resource stock

INSERT OR REPLACE INTO GlobalParameters (Name, Value) VALUES ('CITY_BASE_UPPER_CLASS_PERCENT', 			5);		-- Used during city creation, before there is a base populatin to refer to.
INSERT OR REPLACE INTO GlobalParameters (Name, Value) VALUES ('CITY_BASE_MIDDLE_CLASS_PERCENT', 		30);	--

INSERT OR REPLACE INTO GlobalParameters (Name, Value) VALUES ('CITY_BASE_UPPER_CLASS_MAX_PERCENT', 		10);
INSERT OR REPLACE INTO GlobalParameters (Name, Value) VALUES ('CITY_BASE_UPPER_CLASS_MIN_PERCENT', 		1);
INSERT OR REPLACE INTO GlobalParameters (Name, Value) VALUES ('CITY_BASE_MIDDLE_CLASS_MAX_PERCENT', 	50);
INSERT OR REPLACE INTO GlobalParameters (Name, Value) VALUES ('CITY_BASE_MIDDLE_CLASS_MIN_PERCENT', 	25);
INSERT OR REPLACE INTO GlobalParameters (Name, Value) VALUES ('CITY_BASE_LOWER_CLASS_MAX_PERCENT', 		85);
INSERT OR REPLACE INTO GlobalParameters (Name, Value) VALUES ('CITY_BASE_LOWER_CLASS_MIN_PERCENT', 		25);

INSERT OR REPLACE INTO GlobalParameters (Name, Value) VALUES ('CITY_WEALTH_UPPER_CLASS_RATIO', 			1.75);
INSERT OR REPLACE INTO GlobalParameters (Name, Value) VALUES ('CITY_WEALTH_MIDDLE_CLASS_RATIO', 		1.00);
INSERT OR REPLACE INTO GlobalParameters (Name, Value) VALUES ('CITY_WEALTH_LOWER_CLASS_RATIO', 			0.50);
INSERT OR REPLACE INTO GlobalParameters (Name, Value) VALUES ('CITY_WEALTH_SLAVE_CLASS_RATIO', 			0.10);

INSERT OR REPLACE INTO GlobalParameters (Name, Value) VALUES ('CITY_USE_REAL_YEARS_FOR_GROWTH_RATE', 	0);		-- 1 = use real number of years between turns to calculate City Growth Rate (much slower in late game)
INSERT OR REPLACE INTO GlobalParameters (Name, Value) VALUES ('CITY_GROWTH_RATE_BASE_YEARS', 			30);	-- use this fixed value to calculate City Growth Rate when CITY_USE_REAL_YEARS_FOR_GROWTH_RATE = 0

INSERT OR REPLACE INTO GlobalParameters (Name, Value) VALUES ('CITY_CLASS_MINIMAL_GROWTH_RATE',			-3.5);	-- Minimal value for a population class growth rate, per 1000 per "year"
INSERT OR REPLACE INTO GlobalParameters (Name, Value) VALUES ('CITY_CLASS_MAXIMAL_GROWTH_RATE',			3.5);	-- Maximal value for a population class growth rate, per 1000 per "year"

INSERT OR REPLACE INTO GlobalParameters (Name, Value) VALUES ('CITY_BASE_BIRTH_RATE',					25);	-- per 1000 per "year"
INSERT OR REPLACE INTO GlobalParameters (Name, Value) VALUES ('CITY_UPPER_CLASS_BIRTH_RATE_FACTOR', 	0.45);		
INSERT OR REPLACE INTO GlobalParameters (Name, Value) VALUES ('CITY_MIDDLE_CLASS_BIRTH_RATE_FACTOR', 	1.00);	
INSERT OR REPLACE INTO GlobalParameters (Name, Value) VALUES ('CITY_LOWER_CLASS_BIRTH_RATE_FACTOR', 	2.00);	
INSERT OR REPLACE INTO GlobalParameters (Name, Value) VALUES ('CITY_SLAVE_CLASS_BIRTH_RATE_FACTOR', 	2.00);

INSERT OR REPLACE INTO GlobalParameters (Name, Value) VALUES ('CITY_BASE_DEATH_RATE',					17);	-- per 1000 per "year"
INSERT OR REPLACE INTO GlobalParameters (Name, Value) VALUES ('CITY_UPPER_CLASS_DEATH_RATE_FACTOR',		0.40);
INSERT OR REPLACE INTO GlobalParameters (Name, Value) VALUES ('CITY_MIDDLE_CLASS_DEATH_RATE_FACTOR',	1.00);
INSERT OR REPLACE INTO GlobalParameters (Name, Value) VALUES ('CITY_LOWER_CLASS_DEATH_RATE_FACTOR',		2.25);
INSERT OR REPLACE INTO GlobalParameters (Name, Value) VALUES ('CITY_SLAVE_CLASS_DEATH_RATE_FACTOR',		3.00);

INSERT OR REPLACE INTO GlobalParameters (Name, Value) VALUES ('CITY_LIGHT_RATIONING_BIRTH_PERCENT', 	1);		-- percentage of actual birth rate variation from food rationing
INSERT OR REPLACE INTO GlobalParameters (Name, Value) VALUES ('CITY_MEDIUM_RATIONING_BIRTH_PERCENT', 	5);
INSERT OR REPLACE INTO GlobalParameters (Name, Value) VALUES ('CITY_HEAVY_RATIONING_BIRTH_PERCENT', 	10);
INSERT OR REPLACE INTO GlobalParameters (Name, Value) VALUES ('CITY_STARVATION_BIRTH_PERCENT', 			15);
INSERT OR REPLACE INTO GlobalParameters (Name, Value) VALUES ('CITY_LIGHT_RATIONING_DEATH_PERCENT', 	5);		-- percentage of actual death rate variation from food rationing
INSERT OR REPLACE INTO GlobalParameters (Name, Value) VALUES ('CITY_MEDIUM_RATIONING_DEATH_PERCENT', 	15);
INSERT OR REPLACE INTO GlobalParameters (Name, Value) VALUES ('CITY_HEAVY_RATIONING_DEATH_PERCENT', 	30);
INSERT OR REPLACE INTO GlobalParameters (Name, Value) VALUES ('CITY_STARVATION_DEATH_PERCENT', 			50);

INSERT OR REPLACE INTO GlobalParameters (Name, Value) VALUES ('CITY_MIN_PERCENT_LEFT_TO_SUPPLY', 		30);	-- stock above that percentage are available for reinforcing units
INSERT OR REPLACE INTO GlobalParameters (Name, Value) VALUES ('CITY_MIN_PERCENT_LEFT_TO_EXPORT', 		75);	-- stock above that percentage are available for trade with other civilizations cities
INSERT OR REPLACE INTO GlobalParameters (Name, Value) VALUES ('CITY_MIN_PERCENT_LEFT_TO_CONVERT', 		0);		-- stock above that percentage are available for use by local industries
INSERT OR REPLACE INTO GlobalParameters (Name, Value) VALUES ('CITY_MIN_PERCENT_LEFT_TO_TRANSFER', 		60);	-- stock above that percentage are available for transfer to other cities of the same civilization
INSERT OR REPLACE INTO GlobalParameters (Name, Value) VALUES ('CITY_MAX_PERCENT_LEFT_TO_IMPORT', 		75);	-- until that percentage is reached, allow trade from other civilizations cities (must be < to CITY_MIN_PERCENT_LEFT_TO_EXPORT from every city to prevent exploit)
INSERT OR REPLACE INTO GlobalParameters (Name, Value) VALUES ('CITY_MAX_PERCENT_LEFT_TO_REQUEST', 		100);	-- until that percentage is reached, allow internal transfer from other cities of the same civilization 

INSERT OR REPLACE INTO GlobalParameters (Name, Value) VALUES ('CITY_TRADE_INCOME_RESOURCE_LUXURY', 		3);
INSERT OR REPLACE INTO GlobalParameters (Name, Value) VALUES ('CITY_TRADE_INCOME_RESOURCE_STRATEGIC', 	2);
INSERT OR REPLACE INTO GlobalParameters (Name, Value) VALUES ('CITY_TRADE_INCOME_RESOURCE_BONUS', 		0.5);

INSERT OR REPLACE INTO GlobalParameters (Name, Value) VALUES ('CITY_TRADE_INCOME_EQUIPMENT_RATIO', 		0.1);

INSERT OR REPLACE INTO GlobalParameters (Name, Value) VALUES ('CITY_TRADE_INCOME_EXPORT_PERCENT', 		100);
INSERT OR REPLACE INTO GlobalParameters (Name, Value) VALUES ('CITY_TRADE_INCOME_IMPORT_PERCENT', 		25);

INSERT OR REPLACE INTO GlobalParameters (Name, Value) VALUES ('CITY_ROUTE_ROAD_LENGTH_FACTOR',			0.50);	-- When calculating supply line efficiency relatively to length (lower = better)
INSERT OR REPLACE INTO GlobalParameters (Name, Value) VALUES ('CITY_ROUTE_RIVER_LENGTH_FACTOR',			0.40);
INSERT OR REPLACE INTO GlobalParameters (Name, Value) VALUES ('CITY_ROUTE_SEA_LENGTH_FACTOR',			0.25);
INSERT OR REPLACE INTO GlobalParameters (Name, Value) VALUES ('CITY_ROUTE_TRADER_LENGTH_FACTOR',		0.00);	-- note : traders are always at max efficiency, they are only limited by their own range
INSERT OR REPLACE INTO GlobalParameters (Name, Value) VALUES ('CITY_ROUTE_AIRPORT_LENGTH_FACTOR',		0.00);	-- note : Airport will use smaller but fixed values set differently

INSERT OR REPLACE INTO GlobalParameters (Name, Value) VALUES ('CITY_UPPER_CLASS_TO_PERSONNEL_RATIO', 	0.01);
INSERT OR REPLACE INTO GlobalParameters (Name, Value) VALUES ('CITY_MIDDLE_CLASS_TO_PERSONNEL_RATIO', 	0.05);
INSERT OR REPLACE INTO GlobalParameters (Name, Value) VALUES ('CITY_LOWER_CLASS_TO_PERSONNEL_RATIO', 	0.10);

INSERT OR REPLACE INTO GlobalParameters (Name, Value) VALUES ('CITY_PERSONNEL_TO_UPPER_CLASS_RATIO', 	0.02);
INSERT OR REPLACE INTO GlobalParameters (Name, Value) VALUES ('CITY_PERSONNEL_TO_MIDDLE_CLASS_RATIO', 	0.60);
INSERT OR REPLACE INTO GlobalParameters (Name, Value) VALUES ('CITY_PERSONNEL_TO_LOWER_CLASS_RATIO', 	0.38); 	-- Just for reference, the code use difference with high+middle class 

INSERT OR REPLACE INTO GlobalParameters (Name, Value) VALUES ('ARMY_PERSONNEL_HIGH_RANK_RATIO', 		0.02);
INSERT OR REPLACE INTO GlobalParameters (Name, Value) VALUES ('ARMY_PERSONNEL_MIDDLE_RANK_RATIO', 		0.10);
INSERT OR REPLACE INTO GlobalParameters (Name, Value) VALUES ('ARMY_PERSONNEL_LOWER_RANK_RATIO', 		0.88); 	-- Just for reference, the code use difference with high+middle ranks 

-- combats
INSERT OR REPLACE INTO GlobalParameters (Name, Value) VALUES ('COMBAT_HEAVY_DIFFERENCE_VALUE',			10);	-- Minimal damage difference to consider a large victory/defeat
INSERT OR REPLACE INTO GlobalParameters (Name, Value) VALUES ('COMBAT_BASE_ANTIPERSONNEL_PERCENT',		50);
INSERT OR REPLACE INTO GlobalParameters (Name, Value) VALUES ('COMBAT_BASE_ANTITANK_PERCENT',			15);
INSERT OR REPLACE INTO GlobalParameters (Name, Value) VALUES ('COMBAT_BASE_ANTIAIR_PERCENT',			25);
INSERT OR REPLACE INTO GlobalParameters (Name, Value) VALUES ('COMBAT_BASE_ANTISHIP_PERCENT',			10);
INSERT OR REPLACE INTO GlobalParameters (Name, Value) VALUES ('COMBAT_CAPTURE_FROM_CAPACITY_PERCENT',	55);	-- To calculate the max prisonners an unit can capture in combat 
INSERT OR REPLACE INTO GlobalParameters (Name, Value) VALUES ('COMBAT_CAPTURED_PERSONNEL_PERCENT',		45);	-- To calculate the captured personnel from an unit casualties
INSERT OR REPLACE INTO GlobalParameters (Name, Value) VALUES ('COMBAT_ATTACKER_MATERIEL_GAIN_PERCENT',	50);
INSERT OR REPLACE INTO GlobalParameters (Name, Value) VALUES ('COMBAT_ATTACKER_MATERIEL_KILL_PERCENT',	75);	-- Percentage of the opponent's materiel gained when killing it
INSERT OR REPLACE INTO GlobalParameters (Name, Value) VALUES ('COMBAT_ATTACKER_EQUIPMENT_KILL_PERCENT',	15);	-- Percentage of the opponent's equipment converted to gained materiel when killing it
INSERT OR REPLACE INTO GlobalParameters (Name, Value) VALUES ('COMBAT_ATTACKER_FOOD_KILL_PERCENT',		75);
INSERT OR REPLACE INTO GlobalParameters (Name, Value) VALUES ('COMBAT_DEFENDER_MATERIEL_GAIN_PERCENT',	25);

-- food
INSERT OR REPLACE INTO GlobalParameters (Name, Value) VALUES ('FOOD_CONSUMPTION_UPPER_CLASS_FACTOR',	1.25);
INSERT OR REPLACE INTO GlobalParameters (Name, Value) VALUES ('FOOD_CONSUMPTION_MIDDLE_CLASS_FACTOR',	0.75);
INSERT OR REPLACE INTO GlobalParameters (Name, Value) VALUES ('FOOD_CONSUMPTION_LOWER_CLASS_FACTOR',	0.65);
INSERT OR REPLACE INTO GlobalParameters (Name, Value) VALUES ('FOOD_CONSUMPTION_SLAVE_CLASS_FACTOR',	0.50);
INSERT OR REPLACE INTO GlobalParameters (Name, Value) VALUES ('FOOD_RATIONING_TURNS_TO_FAMINE_LIGHT',	15);
INSERT OR REPLACE INTO GlobalParameters (Name, Value) VALUES ('FOOD_RATIONING_TURNS_TO_FAMINE_MEDIUM',	10);
INSERT OR REPLACE INTO GlobalParameters (Name, Value) VALUES ('FOOD_RATIONING_TURNS_TO_FAMINE_HEAVY',	5);
INSERT OR REPLACE INTO GlobalParameters (Name, Value) VALUES ('FOOD_RATIONING_TURNS_LOCKED',			5);
INSERT OR REPLACE INTO GlobalParameters (Name, Value) VALUES ('FOOD_CONSUMPTION_PERSONNEL_FACTOR',		1.25);
INSERT OR REPLACE INTO GlobalParameters (Name, Value) VALUES ('FOOD_CONSUMPTION_HORSES_FACTOR',			3.50);
INSERT OR REPLACE INTO GlobalParameters (Name, Value) VALUES ('FOOD_CONSUMPTION_WOUNDED_FACTOR',		0.75);
INSERT OR REPLACE INTO GlobalParameters (Name, Value) VALUES ('FOOD_CONSUMPTION_PRISONERS_FACTOR',		0.50);
INSERT OR REPLACE INTO GlobalParameters (Name, Value) VALUES ('FOOD_RATIONING_LIGHT_RATIO',				0.85);
INSERT OR REPLACE INTO GlobalParameters (Name, Value) VALUES ('FOOD_RATIONING_MEDIUM_RATIO',			0.55);
INSERT OR REPLACE INTO GlobalParameters (Name, Value) VALUES ('FOOD_RATIONING_HEAVY_RATIO',				0.35);
INSERT OR REPLACE INTO GlobalParameters (Name, Value) VALUES ('FOOD_RATIONING_STARVATION',				0.25);
INSERT OR REPLACE INTO GlobalParameters (Name, Value) VALUES ('FOOD_COLLECTING_ADJACENT_PLOT_RATIO',	0.25);

-- fuel
INSERT OR REPLACE INTO GlobalParameters (Name, Value) VALUES ('FUEL_CONSUMPTION_ACTIVE_FACTOR',			1000);
INSERT OR REPLACE INTO GlobalParameters (Name, Value) VALUES ('FUEL_CONSUMPTION_DAMAGED_FACTOR',		500);
INSERT OR REPLACE INTO GlobalParameters (Name, Value) VALUES ('FUEL_RATIONING_LIGHT_RATIO',				0.60);
INSERT OR REPLACE INTO GlobalParameters (Name, Value) VALUES ('FUEL_RATIONING_MEDIUM_RATIO',			0.40);
INSERT OR REPLACE INTO GlobalParameters (Name, Value) VALUES ('FUEL_RATIONING_HEAVY_RATIO',				0.25);
INSERT OR REPLACE INTO GlobalParameters (Name, Value) VALUES ('FUEL_CONSUMPTION_LIGHT_RATIO',			0.50);
INSERT OR REPLACE INTO GlobalParameters (Name, Value) VALUES ('FUEL_CONSUMPTION_MEDIUM_RATIO',			0.25);
INSERT OR REPLACE INTO GlobalParameters (Name, Value) VALUES ('FUEL_CONSUMPTION_HEAVY_RATIO',			0.10);

-- morale
INSERT OR REPLACE INTO GlobalParameters (Name, Value) VALUES ('MORALE_BAD_PERCENT',						25);
INSERT OR REPLACE INTO GlobalParameters (Name, Value) VALUES ('MORALE_LOW_PERCENT',						50);
INSERT OR REPLACE INTO GlobalParameters (Name, Value) VALUES ('MORALE_BAD_DESERTION_RATE',				5);
INSERT OR REPLACE INTO GlobalParameters (Name, Value) VALUES ('MORALE_LOW_DESERTION_RATE',				1);
INSERT OR REPLACE INTO GlobalParameters (Name, Value) VALUES ('MORALE_BAD_MIN_PERCENT_HP',				50);
INSERT OR REPLACE INTO GlobalParameters (Name, Value) VALUES ('MORALE_LOW_MIN_PERCENT_HP',				75);
INSERT OR REPLACE INTO GlobalParameters (Name, Value) VALUES ('MORALE_BAD_MIN_PERCENT_RESERVE',			25);
INSERT OR REPLACE INTO GlobalParameters (Name, Value) VALUES ('MORALE_LOW_MIN_PERCENT_RESERVE',			50);
INSERT OR REPLACE INTO GlobalParameters (Name, Value) VALUES ('MORALE_BASE_VALUE',						100);
INSERT OR REPLACE INTO GlobalParameters (Name, Value) VALUES ('MORALE_CHANGE_WELL_FED',					1);
INSERT OR REPLACE INTO GlobalParameters (Name, Value) VALUES ('MORALE_CHANGE_FOOD_RATIONING_LIGHT',		-1);
INSERT OR REPLACE INTO GlobalParameters (Name, Value) VALUES ('MORALE_CHANGE_FOOD_RATIONING_MEDIUM',	-2);
INSERT OR REPLACE INTO GlobalParameters (Name, Value) VALUES ('MORALE_CHANGE_FOOD_RATIONING_HEAVY',		-4);
INSERT OR REPLACE INTO GlobalParameters (Name, Value) VALUES ('MORALE_CHANGE_COMBAT_LARGE_VICTORY',		4);
INSERT OR REPLACE INTO GlobalParameters (Name, Value) VALUES ('MORALE_CHANGE_COMBAT_VICTORY',			2);
INSERT OR REPLACE INTO GlobalParameters (Name, Value) VALUES ('MORALE_CHANGE_COMBAT_DEFEAT',			-1);
INSERT OR REPLACE INTO GlobalParameters (Name, Value) VALUES ('MORALE_CHANGE_COMBAT_LARGE_DEFEAT',		-3);
INSERT OR REPLACE INTO GlobalParameters (Name, Value) VALUES ('MORALE_COMBAT_EFFECT_NUM_TURNS',			5);
INSERT OR REPLACE INTO GlobalParameters (Name, Value) VALUES ('MORALE_COMBAT_NON_MELEE_RATIO',			0.5);
INSERT OR REPLACE INTO GlobalParameters (Name, Value) VALUES ('MORALE_WOUNDED_LOW_PERCENT',				5);
INSERT OR REPLACE INTO GlobalParameters (Name, Value) VALUES ('MORALE_WOUNDED_HIGH_PERCENT',			50);
INSERT OR REPLACE INTO GlobalParameters (Name, Value) VALUES ('MORALE_CHANGE_WOUNDED_LOW',				-1);
INSERT OR REPLACE INTO GlobalParameters (Name, Value) VALUES ('MORALE_CHANGE_WOUNDED_HIGH',				-3);
INSERT OR REPLACE INTO GlobalParameters (Name, Value) VALUES ('MORALE_HP_LOW_PERCENT',					50);
INSERT OR REPLACE INTO GlobalParameters (Name, Value) VALUES ('MORALE_HP_VERY_LOW_PERCENT',				25);
INSERT OR REPLACE INTO GlobalParameters (Name, Value) VALUES ('MORALE_CHANGE_HP_FULL',					2);
INSERT OR REPLACE INTO GlobalParameters (Name, Value) VALUES ('MORALE_CHANGE_HP_LOW',					-1);
INSERT OR REPLACE INTO GlobalParameters (Name, Value) VALUES ('MORALE_CHANGE_HP_VERY_LOW',				-3);

INSERT OR REPLACE INTO GlobalParameters (Name, Value) VALUES ('MORALE_CLOSE_TO_HOME_EFFICIENCY_VALUE',	85);
INSERT OR REPLACE INTO GlobalParameters (Name, Value) VALUES ('MORALE_LINKED_TO_HOME_EFFICIENCY_VALUE',	1);
INSERT OR REPLACE INTO GlobalParameters (Name, Value) VALUES ('MORALE_FAR_FROM_HOME_EFFICIENCY_VALUE',	0);
INSERT OR REPLACE INTO GlobalParameters (Name, Value) VALUES ('MORALE_CHANGE_CLOSE_TO_HOME',			2);
INSERT OR REPLACE INTO GlobalParameters (Name, Value) VALUES ('MORALE_CHANGE_LINKED_TO_HOME',			1);
INSERT OR REPLACE INTO GlobalParameters (Name, Value) VALUES ('MORALE_CHANGE_FAR_FROM_HOME',			-1);
INSERT OR REPLACE INTO GlobalParameters (Name, Value) VALUES ('MORALE_CHANGE_NO_WAY_HOME',				-2);

-- Resources
INSERT OR REPLACE INTO GlobalParameters (Name, Value) VALUES ('RESOURCE_BASE_IMPROVEMENT_MULTIPLIER',	5);
INSERT OR REPLACE INTO GlobalParameters (Name, Value) VALUES ('RESOURCE_BASE_COLLECT_COST_MULTIPLIER',	2);		--
INSERT OR REPLACE INTO GlobalParameters (Name, Value) VALUES ('RESOURCE_NOT_WORKED_COST_MULTIPLIER',	1.5);
INSERT OR REPLACE INTO GlobalParameters (Name, Value) VALUES ('RESOURCE_IMPROVEMENT_COST_RATIO',		0.5);

INSERT OR REPLACE INTO GlobalParameters (Name, Value) VALUES ('RESOURCE_TRANSPORT_MAX_COST',			5);
INSERT OR REPLACE INTO GlobalParameters (Name, Value) VALUES ('RESOURCE_COST_MAX_VARIATION_PERCENT',	15);

-- UI
INSERT OR REPLACE INTO GlobalParameters (Name, Value) VALUES ('UI_MAX_PRISONERS_LINE_IN_TOOLTIP',		2);		-- Number of lines showing prisonners nationality in unit's flag 

-- units
INSERT OR REPLACE INTO GlobalParameters (Name, Value) VALUES ('UNIT_MIN_COMPONENT_LEFT_FACTOR', 		5);
INSERT OR REPLACE INTO GlobalParameters (Name, Value) VALUES ('UNIT_MAX_COMPONENT_LEFT_FACTOR', 		3);
INSERT OR REPLACE INTO GlobalParameters (Name, Value) VALUES ('UNIT_MATERIEL_TO_REPAIR_VEHICLE_PERCENT',50);
INSERT OR REPLACE INTO GlobalParameters (Name, Value) VALUES ('UNIT_RESERVE_RATIO', 					0.75);
INSERT OR REPLACE INTO GlobalParameters (Name, Value) VALUES ('UNIT_MAX_HP_HEALED_FROM_RESERVE',		25);
INSERT OR REPLACE INTO GlobalParameters (Name, Value) VALUES ('UNIT_MAX_PERSONNEL_PERCENT_FROM_RESERVE',15);	-- Max percent of max personnel transfered from reserve to front line
INSERT OR REPLACE INTO GlobalParameters (Name, Value) VALUES ('UNIT_MAX_MATERIEL_PERCENT_FROM_RESERVE',	15);	-- Max percent of max materiel transfered from reserve to front line
INSERT OR REPLACE INTO GlobalParameters (Name, Value) VALUES ('UNIT_MAX_PSEUDO_HP_FROM_REINFORCEMENT',	5);
INSERT OR REPLACE INTO GlobalParameters (Name, Value) VALUES ('UNIT_SUPPLY_LINE_LENGTH_FACTOR',			0.85);	-- When calculating supply line efficiency relatively to length