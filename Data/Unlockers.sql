/* Create table of normal buildings */
CREATE TABLE OriginalBuildingList
	(
		BuildingType TEXT NOT NULL,
		PRIMARY KEY(BuildingType),
		FOREIGN KEY (BuildingType) REFERENCES Buildings(BuildingType) ON DELETE CASCADE ON UPDATE CASCADE
	);
		
INSERT INTO OriginalBuildingList(BuildingType) SELECT BuildingType FROM Buildings;


/* Copy Original Building Prerequest */
CREATE TABLE BuildingRealPrereqsOR
	(
		Building TEXT NOT NULL,
		PrereqBuilding TEXT NOT NULL,
		PRIMARY KEY(Building, PrereqBuilding),
		FOREIGN KEY (Building) REFERENCES Buildings(BuildingType) ON DELETE CASCADE ON UPDATE CASCADE,
		FOREIGN KEY (PrereqBuilding) REFERENCES Buildings(BuildingType) ON DELETE CASCADE ON UPDATE CASCADE
	);
		
INSERT INTO BuildingRealPrereqsOR SELECT * FROM BuildingPrereqs;
DELETE FROM BuildingPrereqs;

/* Copy Original Units Prerequest */
CREATE TABLE Unit_RealBuildingPrereqsOR
	(
		Unit TEXT NOT NULL,
		PrereqBuilding TEXT NOT NULL,
		NumSupported INTEGER NOT NULL DEFAULT -1,
		PRIMARY KEY(Unit, PrereqBuilding),
		FOREIGN KEY (Unit) REFERENCES Units(UnitType) ON DELETE CASCADE ON UPDATE CASCADE,
		FOREIGN KEY (PrereqBuilding) REFERENCES Buildings(BuildingType) ON DELETE CASCADE ON UPDATE CASCADE
	);
INSERT INTO Unit_RealBuildingPrereqsOR SELECT * FROM Unit_BuildingPrereqs;
DELETE FROM Unit_BuildingPrereqs;


/* Create unlockers */
CREATE TABLE Unlockers
	(
		UnlockerType TEXT NOT NULL,
		PRIMARY KEY(UnlockerType)
	);

INSERT INTO Unlockers (UnlockerType) SELECT 'UNLOCKER_' || BuildingType FROM OriginalBuildingList;
INSERT INTO Unlockers (UnlockerType) SELECT 'UNLOCKER_' || UnitType FROM Units;

INSERT INTO Types ("Type", Kind) SELECT UnlockerType, 'KIND_BUILDING' FROM Unlockers;

INSERT INTO Buildings (BuildingType, Name, Cost, NoPedia, NoCityScreen, Unlockers) SELECT UnlockerType, UnlockerType, 1, 1, 1, 1 FROM Unlockers;

INSERT INTO BuildingPrereqs (Building, PrereqBuilding) SELECT BuildingType, 'UNLOCKER_' || BuildingType FROM OriginalBuildingList;
INSERT INTO BuildingPrereqs (Building, PrereqBuilding) SELECT UnlockerType, UnlockerType FROM Unlockers;

INSERT INTO Unit_BuildingPrereqs (Unit, PrereqBuilding) SELECT UnitType, 'UNLOCKER_' || UnitType FROM Units;

/* Drop temporary tables */
DROP TABLE OriginalBuildingList;
DROP TABLE Unlockers;
