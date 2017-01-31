/*
	Gedemon's Civilization Overhaul
	Generic Rules
	Gedemon (2017)
*/
 
/* Defines */
INSERT OR REPLACE INTO GlobalParameters (Name, Value) VALUES ('MIN_COMPONENT_LEFT_IN_UNIT_FACTOR', 		5);
INSERT OR REPLACE INTO GlobalParameters (Name, Value) VALUES ('MAX_COMPONENT_LEFT_IN_UNIT_FACTOR', 		3);
INSERT OR REPLACE INTO GlobalParameters (Name, Value) VALUES ('MATERIEL_PERCENTAGE_TO_REPAIR_VEHICLE', 	50);
INSERT OR REPLACE INTO GlobalParameters (Name, Value) VALUES ('UNIT_RESERVE_RATIO', 					75);
INSERT OR REPLACE INTO GlobalParameters (Name, Value) VALUES ('MAX_HP_HEALED_FROM_RESERVE',				25);
INSERT OR REPLACE INTO GlobalParameters (Name, Value) VALUES ('MAX_PERSONNEL_TRANSFERT_FROM_RESERVE',	250);
INSERT OR REPLACE INTO GlobalParameters (Name, Value) VALUES ('MAX_MATERIEL_TRANSFERT_FROM_RESERVE',	100);
INSERT OR REPLACE INTO GlobalParameters (Name, Value) VALUES ('MAX_PSEUDO_HP_FROM_REINFORCEMENT',		5);
INSERT OR REPLACE INTO GlobalParameters (Name, Value) VALUES ('DEFAULT_ANTIPERSONNEL_RATIO',			50);
INSERT OR REPLACE INTO GlobalParameters (Name, Value) VALUES ('CAPTURE_RATIO_FROM_PRISONNERS_CAPACITY',	55);	-- To calculate the max prisonners an unit can capture in combat 
INSERT OR REPLACE INTO GlobalParameters (Name, Value) VALUES ('DEFAULT_CAPTURED_PERSONNEL_RATIO',		45);	-- To calculate the captured personnel from an unit casualties
INSERT OR REPLACE INTO GlobalParameters (Name, Value) VALUES ('MAX_PRISONNERS_LINE_IN_UNIT_FLAG',		2);		-- Number of lines showing prisonners nationality in unit's flag 
INSERT OR REPLACE INTO GlobalParameters (Name, Value) VALUES ('FOOD_CONSUMPTION_PERSONNEL_FACTOR',		2);
INSERT OR REPLACE INTO GlobalParameters (Name, Value) VALUES ('FOOD_CONSUMPTION_HORSES_FACTOR',			3);
INSERT OR REPLACE INTO GlobalParameters (Name, Value) VALUES ('FOOD_CONSUMPTION_WOUNDED_FACTOR',		1.5);
INSERT OR REPLACE INTO GlobalParameters (Name, Value) VALUES ('FOOD_CONSUMPTION_PRISONNERS_FACTOR',		0.5);