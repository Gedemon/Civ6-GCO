/*

	G.C.O.
	Civilizations creation file
	by Gedemon (2017)
	
	Ethnicity : MEDIT | EURO | SOUTHAM | ASIAN | AFRICAN
	
*/
		
-----------------------------------------------
-- Temporary Tables for initialization
-----------------------------------------------

DROP TABLE IF EXISTS CivilizationConfiguration;
		
CREATE TABLE CivilizationConfiguration
	(	Name TEXT,
		PrimaryColor TEXT,
		SecondaryColor TEXT,
		TextColor TEXT,
		Ethnicity TEXT,
		CapitalName TEXT,
		en_US_Name TEXT,
		en_US_Adj TEXT,
		en_US_Desc TEXT,
		Leader_en_US TEXT
	);

-----------------------------------------------
-- Fill the initialization table 
-----------------------------------------------
INSERT INTO CivilizationConfiguration
(	Name,			PrimaryColor,		SecondaryColor,			TextColor,		Ethnicity,	CapitalName,	en_US_Name,		en_US_Adj,		en_US_Desc,					Leader_en_US ) VALUES
(	'AMERICA',		'AMERICA_PRIMARY',	'AMERICA_SECONDARY',	'WHITE',		'EURO',		'WASHINGTON',	'America', 		'American',		'United States of America',	'American Governement'	),
(	'ARABIA',		'ARABIA_PRIMARY',	'ARABIA_SECONDARY',		'WHITE',		'MEDIT',	'MECCA',		'Arabia', 		'Arabian',		'Arabian Empire',			'Arabian Governement'	),
(	'BRAZIL',		'BRAZIL_PRIMARY',	'BRAZIL_SECONDARY',		'WHITE',		'EURO',		'BRASILIA',		'Brazil', 		'Brazilian',	'Brazilian Empire',			'Brazilian Governement'	),
(	'CHINA',		'CHINA_PRIMARY',	'CHINA_SECONDARY',		'WHITE',		'ASIAN',	'XIAN',			'China', 		'Chinese',		'Chinese Empire',			'Chinese Governement'	),
(	'EGYPT',		'EGYPT_PRIMARY',	'EGYPT_SECONDARY',		'YELLOW',		'MEDIT',	'THEBES',		'Egypt', 		'Egyptian',		'Egyptian Empire',			'Egyptian Governement'	),
(	'ENGLAND',		'ENGLAND_PRIMARY',	'ENGLAND_SECONDARY',	'WHITE',		'EURO',		'LONDON',		'England', 		'English',		'English Empire',			'English Governement'	),
(	'FRANCE',		'FRANCE_PRIMARY',	'FRANCE_SECONDARY',		'WHITE',		'EURO',		'PARIS',		'France', 		'French',		'French Empire',			'French Governement'	),
(	'GERMANY',		'GERMANY_PRIMARY',	'GERMANY_SECONDARY',	'WHITE',		'EURO',		'BERLIN',		'Germany', 		'German',		'German Empire',			'German Governement'	),
(	'GREECE',		'GREECE_PRIMARY',	'GREECE_SECONDARY',		'BLUE',			'MEDIT',	'ATHENS',		'Greece', 		'Greek',		'Greek Empire',				'Greek Governement'		),
(	'INDIA',		'INDIA_PRIMARY',	'INDIA_SECONDARY',		'WHITE',		'MEDIT',	'DELHI',		'India', 		'Indian',		'Indian Empire',			'Indian Governement'	),
(	'ITALY',		'DARK_GREEN',		'WHITE',				'WHITE',		'MEDIT',	'ROME',			'Italy', 		'Italian',		'Italian Empire',			'Italian Governement'	),
(	'JAPAN',		'JAPAN_PRIMARY',	'JAPAN_SECONDARY',		'RED',			'ASIAN',	'KYOTO',		'Japan', 		'Japanese',		'Japanes Empire',			'Japanese Governement'	),
(	'KONGO',		'KONGO_PRIMARY',	'KONGO_SECONDARY',		'WHITE',		'AFRICAN',	'KINCHASSA',	'Kongo', 		'Kongolese',	'Kongolese Empire',			'Kongolese Governement'	),
(	'NORWAY',		'NORWAY_PRIMARY',	'NORWAY_SECONDARY',		'WHITE',		'EURO',		'OSLO',			'Norway', 		'Norwegian',	'Norwegian Empire',			'Norwegian Governement'	),
(	'ROME',			'ROME_PRIMARY',		'ROME_SECONDARY',		'WHITE',		'MEDIT',	'ROME',			'Rome', 		'Roman',		'Roman Empire',				'Roman Governement'		),
(	'SUMERIA',		'SUMERIA_PRIMARY',	'SUMERIA_SECONDARY',	'WHITE',		'MEDIT',	'URUK',			'Sumeria', 		'Sumerian',		'Sumerian Empire',			'Sumerian Governement'	),
(	'RUSSIA',		'RUSSIA_PRIMARY',	'RUSSIA_SECONDARY',		'WHITE',		'EURO',		'MOSCOW',		'Russia', 		'Russian',		'Russian Federation',		'Russian Governement'	),
(	'SPAIN',		'SPAIN_PRIMARY',	'SPAIN_SECONDARY',		'RED',			'EURO',		'MADRID',		'Spain', 		'Spanish',		'Spanish Empire',			'Spanish Governement'	),
(	'PERSIA',		'RED',				'YELLOW',				'RED',			'MEDIT',	'PASARGADAE',	'Persia', 		'Persian',		'Persian Empire',			'Persian Governement'	),
(	'ALGERIA',		'WHITE',			'GREEN',				'RED',			'MEDIT',	'ALGIERS',		'Algeria', 		'Algerian',		'Algerian Empire',			'Algerian Governement'	),
(	'MALI',			'YELLOW',			'GREEN',				'WHITE',		'AFRICAN',	'BAMAKO',		'Mali', 		'Malinese',		'Malinese Empire',			'Malinese Governement'	),
(	'MEXICO',		'DARK_GREEN',		'RED',					'WHITE',		'SOUTHAM',	'MEXICO_CITY',	'Mexico', 		'Mexican',		'Mexican Empire',			'Mexican Governement'	),
(	'MONGOLIA',		'MAROON',			'LIGHT_BLUE',			'RED',			'ASIAN',	'ULAANBAATAR',	'Mongolia', 	'Mongole',		'Mongole Empire',			'Mongole Governement'	),
(	'SWEDEN',		'YELLOW',			'BLUE',					'YELLOW',		'EURO',		'STOCKHOLM',	'Sweden',		'Swede',		'Swedish Empire',			'Swedish Governement'	),
(	'FINLAND',		'WHITE',			'MIDDLE_BLUE',			'WHITE',		'EURO',		'HELSINKI',		'Finland',		'Finn',			'Finnish Empire',			'Finnish Governement'	),
(	'KAZAKHSTAN',	'LIGHT_BLUE',		'YELLOW',				'WHITE',		'ASIAN',	'ASTANA',		'Kazakhstan',	'Kazakh',		'Kazakh Empire',			'Kazakh Governement'	),
(	'SOUTH_AFRICA',	'DARK_GREEN',		'BLACK',				'BLUE',			'AFRICAN',	'CAPE_TOWN',	'South Africa',	'South African','South African Empire',		'South African Governement'	),
(	'TURKEY',		'RED',				'WHITE',				'RED',			'MEDIT',	'ANKARA',		'Turkey',		'Turkish',		'Turkish Empire',			'Turkish Governement'	),
(	'POLAND',		'WHITE',			'PALE_RED',				'WHITE',		'EURO',		'WARSAW',		'Poland',		'Polish',		'Polish Empire',			'Polish Governement'	),
(	'NETHERLANDS',	'MIDDLE_BLUE',		'RED',					'WHITE',		'EURO',		'AMSTERDAM',	'Netherlands',	'Dutch',		'Dutch Empire',				'Dutch Governement'	),
(	'PORTUGAL',		'GREEN',			'RED',					'YELLOW',		'EURO',		'LISBON',		'Portugal',		'Portuguese',	'Portuguese Empire',		'Portuguese Governement'	),
(	'ISRAEL',		'LIGHT_BLUE',		'WHITE',				'LIGHT_BLUE',	'MEDIT',	'JERUSALEM',	'Israel',		'Israeli',		'Israeli Empire',			'Israeli Governement'	),
(	'ARGENTINA',	'CYAN',				'WHITE',				'YELLOW',		'SOUTHAM',	'BUENOS_AIRES',	'Argentina',	'Argentine',	'Argentinian Empire',		'Argentinian Governement'	),
(	'COLOMBIA',		'YELLOW',			'MIDDLE_BLUE',			'RED',			'SOUTHAM',	'BOGOTA',		'Colombia',		'Colombian',	'Colombian Empire',			'Colombian Governement'	),
(	'MOROCCO',		'RED',				'DARK_GREEN',			'RED',			'MEDIT',	'RABAT',		'Morocco',		'Moroccan',		'Moroccan Empire',			'Moroccan Governement'	),
(	'LIBYA',		'GREEN',			'BLACK',				'WHITE',		'MEDIT',	'TRIPOLI',		'Libya',		'Libyan',		'Libyan Empire',			'Libyan Governement'	),
(	'IRAN',			'LIGHT_GREEN',		'RED',					'WHITE',		'MEDIT',	'TEHRAN',		'Iran',			'Iranian',		'Iranian Empire',			'Iranian Governement'	),
(	'IRAQ',			'RED',				'BLACK',				'GREEN',		'MEDIT',	'BAGDAD',		'Iraq',			'Iraqi',		'Iraqi Empire',				'Iraqi Governement'	),
(	'VIETNAM',		'PALE_RED',			'YELLOW',				'RED',			'ASIAN',	'HANOI',		'Vietnam',		'Vietnamese',	'Vietnamese Empire',		'Vietnamese Governement'	),
(	'NORTH_KOREA',	'RED',				'MIDDLE_BLUE',			'WHITE',		'ASIAN',	'PYONGYANG',	'North Korea',	'North Korean',	'DPR of Korea',				'North Korean Governement'	),
(	'SOUTH_KOREA',	'WHITE',			'RED',					'BLUE',			'ASIAN',	'SEOUL',		'South Korea',	'South Korean',	'Republic of Korea',		'South Korean Governement'	),
(	'CANADA',		'WHITE',			'PALE_RED',				'WHITE',		'EURO',		'OTTAWA',		'Canada',		'Canadian',		'Canadian Empire',			'Canadian Governement'	),
(	'AUSTRALIA',	'MIDDLE_BLUE',		'WHITE',				'RED',			'EURO',		'CANBERRA',		'Australia',	'Australian',	'Australian Empire',		'Australian Governement'	),
(	'SWITZERLAND',	'PALE_RED',			'WHITE',				'RED',			'EURO',		'BERN',			'Switzerland',	'Swiss',		'Swiss Empire',				'Swiss Governement'	),
(	'UKRAINE',		'YELLOW',			'LIGHT_BLUE',			'YELLOW',		'EURO',		'KIEV',			'Ukraine',		'Ukrainian',	'Ukrainian Empire',			'Ukrainian Governement'	),
(	'IRELAND',		'GREEN',			'ORANGE',				'WHITE',		'EURO',		'DUBLIN',		'Ireland',		'Irish',		'Irish Empire',				'Irish Governement'	),
(	'THAILAND',		'MIDDLE_BLUE',		'WHITE',				'RED',			'ASIAN',	'BANGKOK',		'Thailand',		'Thai',			'Thai Empire',				'Thai Governement'	),
(	'INDONESIA',	'PALE_RED',			'WHITE',				'RED',			'ASIAN',	'JAKARTA',		'Indonesia',	'Indonesian',	'Indonesian Empire',		'Indonesian Governement'	),
(	'CHINA_PRC',	'RED',				'GOLDENROD',			'RED',			'ASIAN',	'BEIJING',		'PR China',		'Chinese',		'Peoples Republic of China','PR China Governement'		),
(	'CHINA_ROC',	'BLUE',				'RED',					'WHITE',		'ASIAN',	'TAIPEI',		'RO China',		'Chinese',		'Republic of China',		'RO China Governement'		),
(	'NEW_ZEALAND',	'MIDDLE_BLUE',		'RED',					'WHITE',		'EURO',		'WELLINGTON',	'New Zealand',	'New Zealander','New Zealand Empire',		'New Zealand Governement'	),
(	'ICELAND',		'DARK_CYAN',		'RED',					'WHITE',		'EURO',		'REYKJAVIK',	'Iceland',		'Icelander',	'Icelander Empire',			'Icelander Governement'	),
(	'MADAGASCAR',	'WHITE',			'PALE_RED',				'GREEN',		'AFRICAN',	'ANTANANARIVO',	'Madagascar',	'Malagasy',		'Malagasy Empire',			'Malagasy Governement'	),
(	'ETHIOPIA',		'DARK_YELLOW',		'GREEN',				'RED',			'AFRICAN',	'ADDIS_ABABA',	'Ethiopia',		'Ethiopian',	'Ethiopian Empire',			'Ethiopian Governement'	),
(	'CUBA',			'MIDDLE_PURPLE',	'RED',					'WHITE',		'SOUTHAM',	'HAVANA',		'Cuba',			'Cuban',		'Cuban Empire',				'Cuban Governement'	),
(	'END_OF_INSERT',	NULL,			NULL,					NULL,		NULL,		NULL,			NULL,			NULL,			NULL,						NULL					);	
-----------------------------------------------

-- Remove "END_OF_INSERT" entry 
DELETE from CivilizationConfiguration WHERE Name ='END_OF_INSERT';

-----------------------------------------------
-- Update Gameplay Database
-----------------------------------------------

-- <Types> 
INSERT OR REPLACE INTO Types (Type, Kind)
	SELECT	'CIVILIZATION_' || Name, 'KIND_CIVILIZATION'
	FROM CivilizationConfiguration;
INSERT OR REPLACE INTO Types (Type, Kind)
	SELECT	'LEADER_' || Name, 'KIND_LEADER'
	FROM CivilizationConfiguration;	
	
-- <Civilizations>
DELETE FROM Civilizations WHERE StartingCivilizationLevelType != 'CIVILIZATION_LEVEL_TRIBE';
--DELETE FROM SQLITE_SEQUENCE WHERE NAME = 'MyTableName';
INSERT OR REPLACE INTO Civilizations (CivilizationType, Name, Description, Adjective, StartingCivilizationLevelType, RandomCityNameDepth, Ethnicity)
	SELECT	'CIVILIZATION_' || Name, 'LOC_CIVILIZATION_' || Name || '_NAME', 'LOC_CIVILIZATION_' || Name || '_DESCRIPTION', 'LOC_CIVILIZATION_' || Name || '_ADJECTIVE', 'CIVILIZATION_LEVEL_FULL_CIV', 10, 'ETHNICITY_' || Ethnicity
	FROM CivilizationConfiguration;
	
-- <CivilizationLeaders>
DELETE FROM CivilizationLeaders;
INSERT OR REPLACE INTO CivilizationLeaders (CivilizationType, LeaderType, CapitalName)
	SELECT	'CIVILIZATION_' || Name, 'LEADER_' || Name, 'LOC_CITY_NAME_' || CapitalName
	FROM CivilizationConfiguration;	

-- <PlayerColors>
INSERT OR REPLACE INTO PlayerColors (Type, Usage, PrimaryColor, SecondaryColor, TextColor)
	SELECT	'LEADER_' || Name, 'Unique', 'COLOR_PLAYER_' || PrimaryColor, 'COLOR_PLAYER_' || SecondaryColor, 'COLOR_PLAYER_' || TextColor || '_TEXT'
	FROM CivilizationConfiguration;
	
-- <Leaders>
--DELETE FROM Leaders; -- if we delete, must keep default and barbarian
INSERT OR REPLACE INTO Leaders (LeaderType, Name, InheritFrom)
	SELECT	'LEADER_' || Name, 'LOC_LEADER_' || Name || '_NAME', 'LEADER_DEFAULT'
	FROM CivilizationConfiguration;
	
-- <LeaderTraits>
INSERT OR REPLACE INTO LeaderTraits (LeaderType, TraitType)
	SELECT	'LEADER_' || Name, 'TRAIT_LEADER_MAJOR_CIV'
	FROM CivilizationConfiguration;	
	
-- <LoadingInfo>
INSERT OR REPLACE INTO LoadingInfo (LeaderType, ForegroundImage, BackgroundImage, EraText, PlayDawnOfManAudio)
	SELECT	'LEADER_' || Name, 'dom_blank.dds', 'Loading.dds', 'LOC_CIVILIZATION_' || Name || '_ERA_TEXT', 0
	FROM CivilizationConfiguration;
	
-- <DiplomacyInfo>
INSERT OR REPLACE INTO DiplomacyInfo (Type, BackgroundImage)
	SELECT	'LEADER_' || Name, 'scene_' || Name || '.dds'
	FROM CivilizationConfiguration;

	
-----------------------------------------------
-- Delete temporary table
-----------------------------------------------

DROP TABLE CivilizationConfiguration;

