/* Create table of normal buildings */
CREATE TABLE OriginalBuildingList
	(
		BuildingType TEXT NOT NULL,
		PRIMARY KEY(Building),
		FOREIGN KEY (BuildingType) REFERENCES Buildings(BuildingType) ON DELETE CASCADE ON UPDATE CASCADE
	);
		
INSERT INTO OriginalBuildingList(BuildingType) SELECT BuildingType FROM Buildings;


/* Copy Original Building Prerequest */
CREATE TABLE BuildingRealPrereqs
	(
		Building TEXT NOT NULL,
		PrereqBuilding TEXT NOT NULL,
		PRIMARY KEY(Building, PrereqBuilding),
		FOREIGN KEY (Building) REFERENCES Buildings(BuildingType) ON DELETE CASCADE ON UPDATE CASCADE,
		FOREIGN KEY (PrereqBuilding) REFERENCES Buildings(BuildingType) ON DELETE CASCADE ON UPDATE CASCADE
	);
		
INSERT INTO BuildingRealPrereqs SELECT FROM BuildingPrereqs;
DELETE FROM BuildingPrereqs;

/* Copy Original Units Prerequest */
CREATE TABLE Unit_RealBuildingPrereqs
	(
		Unit TEXT NOT NULL,
		PrereqBuilding TEXT NOT NULL,
		NumSupported INTEGER NOT NULL DEFAULT -1,
		PRIMARY KEY(Unit, PrereqBuilding),
		FOREIGN KEY (Unit) REFERENCES Units(UnitType) ON DELETE CASCADE ON UPDATE CASCADE,
		FOREIGN KEY (PrereqBuilding) REFERENCES Buildings(BuildingType) ON DELETE CASCADE ON UPDATE CASCADE
	);
INSERT INTO Unit_RealBuildingPrereqs SELECT FROM Unit_BuildingPrereqs;
DELETE FROM Unit_BuildingPrereqs;


/* Create unlockers */
CREATE TABLE Unlockers
	(
		UnlockerType TEXT NOT NULL,
		PRIMARY KEY(UnlockerType)
	);

INSERT INTO Unlockers (UnlockerType) SELECT 'UNLOCKER_' || BuildingType FROM OriginalBuildingList;
INSERT INTO Unlockers (UnlockerType) SELECT 'UNLOCKER_' || UnitType FROM Units;

INSERT INTO Buildings (BuildingType, Name, Cost, NoPedia, NoCityScreen) SELECT UnlockerType, UnlockerType || '(should be hidden)', 1, 1, 1 FROM Unlockers;

INSERT INTO BuildingPrereqs (Building, PrereqBuilding) SELECT BuildingType, 'UNLOCKER_' || BuildingType FROM OriginalBuildingList;
INSERT INTO BuildingPrereqs (Building, PrereqBuilding) SELECT UnlockerType, UnlockerType FROM Unlockers;

INSERT INTO Unit_BuildingPrereqs (Unit, PrereqBuilding) SELECT UnitType, 'UNLOCKER_' || UnitType FROM Units;

/* Drop temporary tables */
DROP TABLE OriginalBuildingList;
DROP TABLE Unlockers;
