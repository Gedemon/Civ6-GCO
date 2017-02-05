/*

	G.C.O.
	Civilizations texts creation file
	by Gedemon (2017)
	
*/

DROP TABLE IF EXISTS CivilizationsTextsConfiguration;
		
CREATE TABLE CivilizationsTextsConfiguration
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
	
CREATE TABLE IF NOT EXISTS LocalizedText
(	Tag TEXT,
	Text TEXT,
	Language TEXT
);

-----------------------------------------------
-- Fill the initialization table
-----------------------------------------------
INSERT INTO CivilizationsTextsConfiguration
(	Name,			PrimaryColor,		SecondaryColor,			TextColor,	Ethnicity,	CapitalName,	en_US_Name,		en_US_Adj,		en_US_Desc,					Leader_en_US ) VALUES
(	'AMERICA',		'AMERICA_PRIMARY',	'AMERICA_SECONDARY',	'WHITE',	'EURO',		'WASHINGTON',	'America', 		'American',		'United States of America',	'American Governement'	),
(	'ARABIA',		'ARABIA_PRIMARY',	'ARABIA_SECONDARY',		'WHITE',	'MEDIT',	'MECCA',		'Arabia', 		'Arabian',		'Arabian Empire',			'Arabian Governement'	),
(	'BRAZIL',		'BRAZIL_PRIMARY',	'BRAZIL_SECONDARY',		'WHITE',	'EURO',		'BRASILIA',		'Brazil', 		'Brazilian',	'Brazilian Empire',			'Brazilian Governement'	),
(	'CHINA',		'CHINA_PRIMARY',	'CHINA_SECONDARY',		'WHITE',	'ASIAN',	'XIAN',			'China', 		'Chinese',		'Chinese Empire',			'Chinese Governement'	),
(	'EGYPT',		'EGYPT_PRIMARY',	'EGYPT_SECONDARY',		'YELLOW',	'MEDIT',	'THEBES',		'Egypt', 		'Egyptian',		'Egyptian Empire',			'Egyptian Governement'	),
(	'ENGLAND',		'ENGLAND_PRIMARY',	'ENGLAND_SECONDARY',	'WHITE',	'EURO',		'LONDON',		'England', 		'English',		'English Empire',			'English Governement'	),
(	'FRANCE',		'FRANCE_PRIMARY',	'FRANCE_SECONDARY',		'WHITE',	'EURO',		'PARIS',		'France', 		'French',		'French Empire',			'French Governement'	),
(	'GERMANY',		'GERMANY_PRIMARY',	'GERMANY_SECONDARY',	'WHITE',	'EURO',		'BERLIN',		'Germany', 		'German',		'German Empire',			'German Governement'	),
(	'GREECE',		'GREECE_PRIMARY',	'GREECE_SECONDARY',		'BLUE',		'MEDIT',	'ATHENS',		'Greece', 		'Greek',		'Greek Empire',				'Greek Governement'		),
(	'INDIA',		'INDIA_PRIMARY',	'INDIA_SECONDARY',		'WHITE',	'MEDIT',	'DELHI',		'India', 		'Indian',		'Indian Empire',			'Indian Governement'	),
(	'ITALY',		'DARK_GREEN',		'WHITE',				'WHITE',	'MEDIT',	'ROME',			'Italy', 		'Italian',		'Italian Empire',			'Italian Governement'	),
(	'JAPAN',		'JAPAN_PRIMARY',	'JAPAN_SECONDARY',		'RED',		'ASIAN',	'KYOTO',		'Japan', 		'Japanese',		'Japanes Empire',			'Japanese Governement'	),
(	'KONGO',		'KONGO_PRIMARY',	'KONGO_SECONDARY',		'WHITE',	'AFRICAN',	'KINCHASSA',	'Kongo', 		'Kongolese',	'Kongolese Empire',			'Kongolese Governement'	),
(	'NORWAY',		'NORWAY_PRIMARY',	'NORWAY_SECONDARY',		'WHITE',	'EURO',		'OSLO',			'Norway', 		'Norwegian',	'Norwegian Empire',			'Norwegian Governement'	),
(	'ROME',			'ROME_PRIMARY',		'ROME_SECONDARY',		'WHITE',	'MEDIT',	'ROME',			'Rome', 		'Roman',		'Roman Empire',				'Roman Governement'		),
(	'SUMERIA',		'SUMERIA_PRIMARY',	'SUMERIA_SECONDARY',	'WHITE',	'MEDIT',	'URUK',			'Sumeria', 		'Sumerian',		'Sumerian Empire',			'Sumerian Governement'	),
(	'RUSSIA',		'RUSSIA_PRIMARY',	'RUSSIA_SECONDARY',		'WHITE',	'EURO',		'MOSCOW',		'Russia', 		'Russian',		'Russian Federation',		'Russian Governement'	),
(	'SPAIN',		'SPAIN_PRIMARY',	'SPAIN_SECONDARY',		'RED',		'EURO',		'MADRID',		'Spain', 		'Spanish',		'Spanish Empire',			'Spanish Governement'	),
(	'PERSIA',		'RED',				'YELLOW',				'RED',		'MEDIT',	'PASARGADAE',	'Persia', 		'Persian',		'Persian Empire',			'Persian Governement'	),
(	'ALGERIA',		'SPAIN_PRIMARY',	'SPAIN_SECONDARY',		'RED',		'MEDIT',	'ALGIERS',		'Algeria', 		'Algerian',		'Algerian Empire',			'Algerian Governement'	),
(	'MALI',			'SPAIN_PRIMARY',	'SPAIN_SECONDARY',		'RED',		'AFRICAN',	'BAMAKO',		'Mali', 		'Malinese',		'Malinese Empire',			'Malinese Governement'	),
(	'MEXICO',		'SPAIN_PRIMARY',	'SPAIN_SECONDARY',		'RED',		'SOUTHAM',	'MEXICO_CITY',	'Mexico', 		'Mexican',		'Mexican Empire',			'Mexican Governement'	),
(	'MONGOLIA',		'SPAIN_PRIMARY',	'SPAIN_SECONDARY',		'RED',		'ASIAN',	'ULAANBAATAR',	'Mongolia', 	'Mongole',		'Mongole Empire',			'Mongole Governement'	),
(	'SWEDEN',		'SPAIN_PRIMARY',	'SPAIN_SECONDARY',		'RED',		'EURO',		'STOCKHOLM',	'Sweden',		'Swede',		'Swedish Empire',			'Swedish Governement'	),
(	'FINLAND',		'SPAIN_PRIMARY',	'SPAIN_SECONDARY',		'RED',		'EURO',		'HELSINKI',		'Finland',		'Finn',			'Finnish Empire',			'Finnish Governement'	),
(	'KAZAKHSTAN',	'SPAIN_PRIMARY',	'SPAIN_SECONDARY',		'RED',		'ASIAN',	'ASTANA',		'Kazakhstan',	'Kazakh',		'Kazakh Empire',			'Kazakh Governement'	),
(	'SOUTH_AFRICA',	'SPAIN_PRIMARY',	'SPAIN_SECONDARY',		'RED',		'AFRICAN',	'CAPE_TOWN',	'South Africa',	'South African','South African Empire',		'South African Governement'	),
(	'TURKEY',		'SPAIN_PRIMARY',	'SPAIN_SECONDARY',		'RED',		'MEDIT',	'ANKARA',		'Turkey',		'Turkish',		'Turkish Empire',			'Turkish Governement'	),
(	'POLAND',		'SPAIN_PRIMARY',	'SPAIN_SECONDARY',		'RED',		'EURO',		'WARSAW',		'Poland',		'Polish',		'Polish Empire',			'Polish Governement'	),
(	'NETHERLANDS',	'SPAIN_PRIMARY',	'SPAIN_SECONDARY',		'RED',		'EURO',		'AMSTERDAM',	'Netherlands',	'Dutch',		'Dutch Empire',				'Dutch Governement'	),
(	'PORTUGAL',		'SPAIN_PRIMARY',	'SPAIN_SECONDARY',		'RED',		'EURO',		'LISBON',		'Portugal',		'Portuguese',	'Portuguese Empire',		'Portuguese Governement'	),
(	'ISRAEL',		'SPAIN_PRIMARY',	'SPAIN_SECONDARY',		'RED',		'MEDIT',	'JERUSALEM',	'Israel',		'Israeli',		'Israeli Empire',			'Israeli Governement'	),
(	'ARGENTINA',	'SPAIN_PRIMARY',	'SPAIN_SECONDARY',		'RED',		'SOUTHAM',	'BUENOS_AIRES',	'Argentina',	'Argentine',	'Argentinian Empire',		'Argentinian Governement'	),
(	'COLOMBIA',		'SPAIN_PRIMARY',	'SPAIN_SECONDARY',		'RED',		'SOUTHAM',	'BOGOTA',		'Colombia',		'Colombian',	'Colombian Empire',			'Colombian Governement'	),
(	'MOROCCO',		'SPAIN_PRIMARY',	'SPAIN_SECONDARY',		'RED',		'MEDIT',	'RABAT',		'Morocco',		'Moroccan',		'Moroccan Empire',			'Moroccan Governement'	),
(	'LIBYA',		'SPAIN_PRIMARY',	'SPAIN_SECONDARY',		'RED',		'MEDIT',	'TRIPOLI',		'Libya',		'Libyan',		'Libyan Empire',			'Libyan Governement'	),
(	'IRAN',			'SPAIN_PRIMARY',	'SPAIN_SECONDARY',		'RED',		'MEDIT',	'TEHRAN',		'Iran',			'Iranian',		'Iranian Empire',			'Iranian Governement'	),
(	'IRAQ',			'SPAIN_PRIMARY',	'SPAIN_SECONDARY',		'RED',		'MEDIT',	'BAGDAD',		'Iraq',			'Iraqi',		'Iraqi Empire',				'Iraqi Governement'	),
(	'VIETNAM',		'SPAIN_PRIMARY',	'SPAIN_SECONDARY',		'RED',		'ASIAN',	'HANOI',		'Vietnam',		'Vietnamese',	'Vietnamese Empire',		'Vietnamese Governement'	),
(	'NORTH_KOREA',	'SPAIN_PRIMARY',	'SPAIN_SECONDARY',		'RED',		'ASIAN',	'PYONGYANG',	'North Korea',	'North Korean',	'DPR of Korea',				'North Korean Governement'	),
(	'SOUTH_KOREA',	'SPAIN_PRIMARY',	'SPAIN_SECONDARY',		'RED',		'ASIAN',	'SEOUL',		'South Korea',	'South Korean',	'Republic of Korea',		'South Korean Governement'	),
(	'CANADA',		'SPAIN_PRIMARY',	'SPAIN_SECONDARY',		'RED',		'EURO',		'OTTAWA',		'Canada',		'Canadian',		'Canadian Empire',			'Canadian Governement'	),
(	'AUSTRALIA',	'SPAIN_PRIMARY',	'SPAIN_SECONDARY',		'RED',		'EURO',		'CANBERRA',		'Australia',	'Australian',	'Australian Empire',		'Australian Governement'	),
(	'SWITZERLAND',	'SPAIN_PRIMARY',	'SPAIN_SECONDARY',		'RED',		'EURO',		'BERN',			'Switzerland',	'Swiss',		'Swiss Empire',				'Swiss Governement'	),
(	'UKRAINE',		'SPAIN_PRIMARY',	'SPAIN_SECONDARY',		'RED',		'EURO',		'KIEV',			'Ukraine',		'Ukrainian',	'Ukrainian Empire',			'Ukrainian Governement'	),
(	'IRELAND',		'SPAIN_PRIMARY',	'SPAIN_SECONDARY',		'RED',		'EURO',		'DUBLIN',		'Ireland',		'Irish',		'Irish Empire',				'Irish Governement'	),
(	'THAILAND',		'SPAIN_PRIMARY',	'SPAIN_SECONDARY',		'RED',		'ASIAN',	'BANGKOK',		'Thailand',		'Thai',			'Thai Empire',				'Thai Governement'	),
(	'INDONESIA',	'SPAIN_PRIMARY',	'SPAIN_SECONDARY',		'RED',		'ASIAN',	'JAKARTA',		'Indonesia',	'Indonesian',	'Indonesian Empire',		'Indonesian Governement'	),
(	'CHINA_PRC',	'SPAIN_PRIMARY',	'SPAIN_SECONDARY',		'RED',		'ASIAN',	'BEIJING',		'PR China',		'Chinese',		'Peoples Republic of China','PR China Governement'		),
(	'CHINA_ROC',	'SPAIN_PRIMARY',	'SPAIN_SECONDARY',		'RED',		'ASIAN',	'TAIPEI',		'RO China',		'Chinese',		'Republic of China',		'RO China Governement'		),
(	'NEW_ZEALAND',	'SPAIN_PRIMARY',	'SPAIN_SECONDARY',		'RED',		'EURO',		'WELLINGTON',	'New Zealand',	'New Zealander','New Zealand Empire',		'New Zealand Governement'	),
(	'ICELAND',		'SPAIN_PRIMARY',	'SPAIN_SECONDARY',		'RED',		'EURO',		'REYKJAVIK',	'Iceland',		'Icelander',	'Icelander Empire',			'Icelander Governement'	),
(	'MADAGASCAR',	'SPAIN_PRIMARY',	'SPAIN_SECONDARY',		'RED',		'AFRICAN',	'ANTANANARIVO',	'Madagascar',	'Malagasy',		'Malagasy Empire',			'Malagasy Governement'	),
(	'ETHIOPIA',		'SPAIN_PRIMARY',	'SPAIN_SECONDARY',		'RED',		'AFRICAN',	'ADDIS_ABABA',	'Ethiopia',		'Ethiopian',	'Ethiopian Empire',			'Ethiopian Governement'	),
(	'CUBA',			'SPAIN_PRIMARY',	'SPAIN_SECONDARY',		'RED',		'SOUTHAM',	'HAVANA',		'Cuba',			'Cuban',		'Cuban Empire',				'Cuban Governement'	),
(	'END_OF_INSERT',	NULL,			NULL,					NULL,		NULL,		NULL,			NULL,			NULL,			NULL,						NULL					);	
-----------------------------------------------
-- Remove "END_OF_INSERT" entry 
DELETE from CivilizationsTextsConfiguration WHERE Name ='END_OF_INSERT';
	
-----------------------------------------------
-- Update Localization Database
-----------------------------------------------

-- <LocalizedText>
INSERT OR IGNORE INTO LocalizedText (Tag, Text, Language)
	SELECT	'LOC_CIVILIZATION_' || Name || '_NAME', en_US_Name, 'en_US'
	FROM CivilizationsTextsConfiguration;
INSERT OR IGNORE INTO LocalizedText (Tag, Text, Language)
	SELECT	'LOC_CIVILIZATION_' || Name || '_ADJECTIVE', en_US_Adj, 'en_US'
	FROM CivilizationsTextsConfiguration;
INSERT OR IGNORE INTO LocalizedText (Tag, Text, Language)
	SELECT	'LOC_CIVILIZATION_' || Name || '_DESCRIPTION', en_US_Desc, 'en_US'
	FROM CivilizationsTextsConfiguration;
INSERT OR IGNORE INTO LocalizedText (Tag, Text, Language)
	SELECT	'LOC_LEADER_' || Name || '_NAME', Leader_en_US, 'en_US'
	FROM CivilizationsTextsConfiguration;
	
INSERT OR IGNORE INTO LocalizedText (Tag, Text, Language)
	SELECT	'LOC_PEDIA_CITYSTATES_PAGE_CIVILIZATION_' || Name || '_CHAPTER_HISTORY_PARA_1', en_US_Desc, 'en_US' 
	FROM CivilizationsTextsConfiguration;
INSERT OR IGNORE INTO LocalizedText (Tag, Text, Language)
	SELECT	'LOC_PEDIA_CITYSTATES_PAGE_CIVILIZATION_' || Name || '_CHAPTER_HISTORY_PARA_2', '...', 'en_US' 
	FROM CivilizationsTextsConfiguration;
INSERT OR IGNORE INTO LocalizedText (Tag, Text, Language)
	SELECT	'LOC_PEDIA_CITYSTATES_PAGE_CIVILIZATION_' || Name || '_CHAPTER_HISTORY_PARA_3', '...', 'en_US' 
	FROM CivilizationsTextsConfiguration;

-----------------------------------------------
-- Delete temporary table
-----------------------------------------------

DROP TABLE CivilizationsTextsConfiguration;
