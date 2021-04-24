/*

	Basic Civilizations
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
		Domain TEXT,
		PrimaryColor TEXT,
		SecondaryColor TEXT,
		IsTribe BOOLEAN NOT NULL CHECK (IsTribe IN (0,1)) DEFAULT 0,
		StartingEra TEXT,
		StartingDate INT,
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
-- StandardPlayers	= Civilizations available with the standard mod
-- ExpandedPlayers 	= Civilizations activated by the "Basic Civilizations Expanded" mod
-----------------------------------------------
INSERT INTO CivilizationConfiguration
(	Name,			Domain,				PrimaryColor,			SecondaryColor,			IsTribe,	StartingEra,	StartingDate,	TextColor,		Ethnicity,	CapitalName,	en_US_Name,			en_US_Adj,		en_US_Desc,								Leader_en_US ) VALUES
--(	'ALGERIA',			'StandardPlayers',	NULL,					NULL,					'0',		NULL,			NULL,			'RED',			'MEDIT',	'ALGIERS',		'Algeria', 			'Algerian',		'Peoples Democratic Republic of Algeria','Algerian Government'		),
--(	'AMERICA',			'StandardPlayers',	NULL,					NULL,					'0',		NULL,			'1600',			'WHITE',		'SOUTHAM',	'WASHINGTON',	'U.S.A.', 			'American',		'United States of America',				'American Government'		),
--(	'ANGOLA',			'StandardPlayers',	NULL,					NULL,					'0',		NULL,			NULL,			'YELLOW',		'AFRICAN',	'LUANDA',		'Angola',			'Angolan',		'Republic of Angola',                   'Angolan Government'		),
(	'ARABIA',			'StandardPlayers',	NULL,					NULL,					'0',		'MEDIEVAL',		'500',			'WHITE',		'MEDIT',	'MECCA',		'Arabia', 			'Arabian',		'Arabian Empire',						'Arabian Government'		),
--(	'ARGENTINA',		'StandardPlayers',	NULL,					NULL,					'0',		NULL,			NULL,			'YELLOW',		'SOUTHAM',	'BUENOS_AIRES',	'Argentina',		'Argentine',	'Argentine Republic',					'Argentinian Government'	),
--(	'AUSTRALIA',		'StandardPlayers',	NULL,					NULL,					'0',		NULL,			'1600',			'RED',			'ASIAN',	'CANBERRA',		'Australia',		'Australian',	'Commonwealth of Australia',			'Australian Government'	),
--(	'AZTEC',			'StandardPlayers',	NULL,					NULL,					'0',		NULL,			'-1200',		'WHITE',		'SOUTHAM',	'TENOCHTITLAN',	'Aztec', 			'Aztec',		'Aztec Empire',							'Aztec Government'			),
(	'BABYLON',			'StandardPlayers',	NULL,					NULL,					'0',		'ANCIENT',		'-3960',		'WHITE',		'MEDIT',	'BAGHDAD',		'Babylon',			'Babylonian',	'Babylonian Empire',					'Babylonian Government'			),
--(	'BRAZIL',			'StandardPlayers',	NULL,					NULL,					'0',		NULL,			'1600',			'WHITE',		'SOUTHAM',	'BRASILIA',		'Brazil', 			'Brazilian',	'Federative Republic of Brazil',		'Brazilian Government'		),
--(	'CANADA',			'StandardPlayers',	NULL,					NULL,					'0',		NULL,			'1600',			'WHITE',		'SOUTHAM',	'OTTAWA',		'Canada',			'Canadian',		'Canada',								'Canadian Government'		),
--(	'CHILE',			'StandardPlayers',	NULL,					NULL,					'0',		NULL,			NULL,			'WHITE',		'SOUTHAM',	'SANTIAGO',		'Chile',			'Chilean',		'Republic of Chile',                    'Chilean Government'		),
(	'CHINA',			'StandardPlayers',	NULL,					NULL,					'0',		'ANCIENT',		'-2400',		'RED',			'ASIAN',	'BEIJING',		'China',			'Chinese',		'Chinese Empire',						'Chinese Government'		),
--(	'COLOMBIA',			'StandardPlayers',	NULL,					NULL,					'0',		NULL,			NULL,			'RED',			'SOUTHAM',	'BOGOTA',		'Colombia',			'Colombian',	'Republic of Colombia',					'Colombian Government'		),
--(	'CONGO',			'StandardPlayers',	NULL,					NULL,					'0',		NULL,			NULL,			'WHITE',		'AFRICAN',	'KINCHASSA',	'Congo', 			'Congolese',	'Democratic Republic of the Congo',		'Congolese Government'		),
--(	'CUBA',				'StandardPlayers',	NULL,					NULL,					'0',		NULL,			NULL,			'WHITE',		'SOUTHAM',	'HAVANA',		'Cuba',				'Cuban',		'Republic of Cuba',						'Cuban Government'			),
--(	'DENMARK',			'StandardPlayers',	NULL,					NULL,					'0',		NULL,			NULL,			'WHITE',		'EURO',		'COPENHAGEN',	'Denmark',			'Danish',		'Kingdom of Denmark',					'Danish Government'		),
(	'EGYPT',			'StandardPlayers',	NULL,					NULL,					'0',		'ANCIENT',		'-3200',		'YELLOW',		'MEDIT',	'CAIRO',		'Egypt', 			'Egyptian',		'Egyptian Empire',						'Egyptian Government'		),
(	'ENGLAND',			'StandardPlayers',	NULL,					NULL,					'0',		'MEDIEVAL',		'500',			'WHITE',		'EURO',		'LONDON',		'England', 			'British',		'British Empire',						'British Government'		),
--(	'ETHIOPIA',			'StandardPlayers',	NULL,					NULL,					'0',		NULL,			'-2400',		'RED',			'AFRICAN',	'ADDIS_ABABA',	'Ethiopia',			'Ethiopian',	'Federal Democratic Republic of Ethiopia','Ethiopian Government'	),
--(	'FINLAND',			'StandardPlayers',	NULL,					NULL,					'0',		NULL,			NULL,			'WHITE',		'EURO',		'HELSINKI',		'Finland',			'Finnish',		'Republic of Finland',					'Finnish Government'		),
(	'FRANCE',			'StandardPlayers',	NULL,					NULL,					'0',		'MEDIEVAL',		'450',			'WHITE',		'EURO',		'PARIS',		'France', 			'French',		'French Empire',						'French Government'		),
(	'GERMANY',			'StandardPlayers',	NULL,					NULL,					'0',		'MEDIEVAL',		'450',			'WHITE',		'EURO',		'BERLIN',		'Germany', 			'German',		'German Empire',						'German Government'		),
(	'GREECE',			'StandardPlayers',	NULL,					NULL,					'0',		'CLASSICAL',	'-1600',		'BLUE',			'MEDIT',	'ATHENS',		'Greece', 			'Greek',		'Greek Empire',							'Greek Government'			),
--(	'ICELAND',			'StandardPlayers',	NULL,					NULL,					'0',		NULL,			NULL,			'WHITE',		'EURO',		'REYKJAVIK',	'Iceland',			'Icelandic',	'Iceland',								'Icelandic Government'		),
--(	'INCA',				'StandardPlayers',	NULL,					NULL,					'0',		'CLASSICAL',	'-2000',		'WHITE',		'SOUTHAM',	'CUZCO',		'Inca', 			'Incan',		'Incan Empire',							'Incan Government'			),
(	'INDIA',			'StandardPlayers',	NULL,					NULL,					'0',		'ANCIENT',		'-2500',		'WHITE',		'MEDIT',	'DELHI',		'India', 			'Indian',		'Empire of India',						'Indian Government'		),
(	'INDONESIA',		'StandardPlayers',	NULL,					NULL,					'0',		'MEDIEVAL',		'400',			'RED',			'ASIAN',	'JAKARTA',		'Indonesia',		'Indonesian',	'Indonesian Empire',					'Indonesian Government'	),
--(	'IRAN',				'StandardPlayers',	NULL,					NULL,					'0',		NULL,			NULL,			'WHITE',		'MEDIT',	'TEHRAN',		'Iran',				'Iranian',		'Islamic Republic of Iran',				'Iranian Government'		),
--(	'IRAQ',				'StandardPlayers',	NULL,					NULL,					'0',		NULL,			NULL,			'WHITE',		'MEDIT',	'BAGHDAD',		'Iraq',				'Iraqi',		'Republic of Iraq',						'Iraqi Government'			),
--(	'IRELAND',			'StandardPlayers',	NULL,					NULL,					'0',		NULL,			NULL,			'WHITE',		'EURO',		'DUBLIN',		'Ireland',			'Irish',		'Ireland',								'Irish Government'			),
--(	'ISRAEL',			'StandardPlayers',	NULL,					NULL,					'0',		NULL,			NULL,			'LIGHT_BLUE',	'MEDIT',	'JERUSALEM',	'Israel',			'Israeli',		'State of Israel',						'Israeli Government'		),
--(	'ITALY',			'StandardPlayers',	NULL,					NULL,					'0',		NULL,			NULL,			'WHITE',		'MEDIT',	'ROME',			'Italy', 			'Italian',		'Italian Republic',						'Italian Government'		),
(	'JAPAN',			'StandardPlayers',	NULL,					NULL,					'0',		'MEDIEVAL',		'500',			'RED',			'ASIAN',	'KYOTO',		'Japan', 			'Japanese',		'Japan Empire',							'Japanese Government'		),
(	'KONGO',			'StandardPlayers',	NULL,					NULL,					'0',		'CLASSICAL',	'-1500',		'WHITE',		'AFRICAN',	'MBANZA_KONGO',	'Kongo', 			'Kongolese',	'Kongolese Empire',						'Kongolese Government'		),
(	'KOREA',			'StandardPlayers',	NULL,					NULL,					'0',		'CLASSICAL',	'-500',			'WHITE',		'ASIAN',	'SEOUL',		'Korea',			'Korean',		'Korean Empire',						'Korean Government'	),
--(	'KAZAKHSTAN',		'StandardPlayers',	NULL,					NULL,					'0',		NULL,			NULL,			'WHITE',		'ASIAN',	'ASTANA',		'Kazakhstan',		'Kazakh',		'Republic of Kazakhstan',				'Kazakh Government'		),
--(	'KENYA',			'ExpandedPlayers',	NULL,					NULL,					'0',		NULL,			NULL,			'BLACK',		'AFRICAN',	'NAIROBI',		'Kenya',			'Kenyan',		'Republic of Kenya',                    'Kenyan Government'		),
--(	'LIBYA',			'StandardPlayers',	NULL,					NULL,					'0',		NULL,			NULL,			'WHITE',		'MEDIT',	'TRIPOLI',		'Libya',			'Libyan',		'State of Libya',						'Libyan Government'		),
--(	'MADAGASCAR',		'StandardPlayers',	NULL,					NULL,					'0',		NULL,			NULL,			'GREEN',		'AFRICAN',	'ANTANANARIVO',	'Madagascar',		'Madagascan',	'Republic of Madagascar',				'Madagascan Government'	),
--(	'MALAYSIA',			'StandardPlayers',	NULL,					NULL,					'0',		NULL,			NULL,			'YELLOW',		'ASIAN',	'KUALA_LUMPUR',	'Malaysia',			'Malaysian',	'Federation of Malaysia',               'Malaysian Government'		),
(	'MALI',				'StandardPlayers',	NULL,					NULL,					'0',		'CLASSICAL',	'-1000',		'WHITE',		'AFRICAN',	'BAMAKO',		'Mali', 			'Malian',		'Malian Empire',						'Malian Government'			),
--(	'MAYA',				'StandardPlayers',	NULL,					NULL,					'0',		'CLASSICAL',	'-1600',		'WHITE',		'SOUTHAM',	'TIKAL',		'Maya', 			'Mayan',		'Mayan Empire',							'Mayan Government'			),
--(	'MEXICO',			'StandardPlayers',	NULL,					NULL,					'0',		NULL,			NULL,			'WHITE',		'SOUTHAM',	'MEXICO_CITY',	'Mexico', 			'Mexican',		'United Mexican States',				'Mexican Government'		),
(	'MONGOLIA',			'StandardPlayers',	NULL,					NULL,					'0',		'CLASSICAL',	'-200',			'RED',			'ASIAN',	'ULAANBAATAR',	'Mongolia', 		'Mongolian',	'Mongolian Empire',						'Mongolian Government'		),
--(	'MOROCCO',			'StandardPlayers',	NULL,					NULL,					'0',		NULL,			NULL,			'RED',			'MEDIT',	'RABAT',		'Morocco',			'Moroccan',		'Kingdom of Morocco',					'Moroccan Government'		),
--(	'MYANMAR',			'StandardPlayers',	NULL,					NULL,					'0',		NULL,			NULL,			'RED',			'ASIAN',	'NAYPYIDAW',	'Myanmar',			'Burmese',		'Republic of the Union of Myanmar',		'Burmese Government'		),
--(	'NETHERLANDS',		'StandardPlayers',	NULL,					NULL,					'0',		'MEDIEVAL',		'800',			'WHITE',		'EURO',		'AMSTERDAM',	'Netherlands',		'Dutch',		'Kingdom of the Netherlands',			'Dutch Government'			),
--(	'NEW_ZEALAND',		'StandardPlayers',	NULL,					NULL,					'0',		NULL,			NULL,			'WHITE',		'ASIAN',	'WELLINGTON',	'New Zealand',		'New Zealand',	'New Zealand',							'New Zealand Government'	),
--(	'NIGERIA',			'StandardPlayers',	NULL,					NULL,					'0',		NULL,			NULL,			'WHITE',		'AFRICAN',	'ABUJA',		'Nigeria',			'Nigerian',		'Federal Republic of Nigeria',          'Nigerian Government'		),
(	'NORWAY',			'StandardPlayers',	NULL,					NULL,					'0',		'MEDIEVAL',		'700',			'WHITE',		'EURO',		'OSLO',			'Norway', 			'Norwegian',	'Norwegian Empire',						'Norwegian Government'		),
(	'NUBIA',			'StandardPlayers',	NULL,					NULL,					'0',		'ANCIENT',		'-2400',		'WHITE',		'AFRICAN',	'MEROE',		'Nubia', 			'Nubian',		'Nubian Empire',						'Nubian Government'			),
(	'OTTOMAN',			'StandardPlayers',	NULL,					NULL,					'0',		'MEDIEVAL',		'600',			'RED',			'MEDIT',	'ANKARA',		'Ottoman',			'Ottoman',		'Ottoman Empire',						'Ottoman Government'		),
--(	'PAKISTAN',			'StandardPlayers',	NULL,					NULL,					'0',		NULL,			NULL,			'WHITE',		'ASIAN',	'ISLAMABAD',	'Pakistan',			'Pakistani',	'Islamic Republic of Pakistan',         'Pakistani Government'		),
--(	'PERU',				'StandardPlayers',	NULL,					NULL,					'0',		NULL,			NULL,			'WHITE',		'SOUTHAM',	'LIMA',			'Peru',				'Peruvian',		'Republic of Peru',            			'Peruvian Government'		),
--(	'PHILIPPINES',		'StandardPlayers',	NULL,					NULL,					'0',		NULL,			NULL,			'YELLOW',		'ASIAN',	'MANILA',		'The Philippines',	'Philippine',	'Republic of the Philippines',          'Philippine Government'	),
(	'PERSIA',			'StandardPlayers',	NULL,					NULL,					'0',		'ANCIENT',		'-3400',		'WHITE',		'MEDIT',	'TEHRAN',		'Persia',			'Persian',		'Persian Empire',						'Persian Government'		),
(	'POLAND',			'StandardPlayers',	NULL,					NULL,					'0',		'MEDIEVAL',		'500',			'WHITE',		'EURO',		'WARSAW',		'Poland',			'Polish',		'Polish Empire',						'Polish Government'		),
--(	'PORTUGAL',			'StandardPlayers',	NULL,					NULL,					'0',		NULL,			NULL,			'YELLOW',		'EURO',		'LISBON',		'Portugal',			'Portuguese',	'Portuguese Republic',					'Portuguese Government'	),
--(	'ROMANIA',			'StandardPlayers',	NULL,					NULL,					'0',		NULL,			NULL,			'YELLOW',		'EURO',		'BUCHAREST',	'Romania',			'Romanian',		'Romania',                              'Romanian Government'		),
(	'ROME',				'StandardPlayers',	NULL,					NULL,					'0',		'CLASSICAL',	'-1200',		'WHITE',		'MEDIT',	'ROME',			'Rome', 			'Roman',		'Roman Empire',							'Roman Government'			),
(	'RUSSIA',			'StandardPlayers',	NULL,					NULL,					'0',		'MEDIEVAL',		'600',			'WHITE',		'EURO',		'MOSCOW',		'Russia', 			'Russian',		'Russian Empire',						'Russian Government'		),
--(	'SUMERIA',			'StandardPlayers',	NULL,					NULL,					'0',		NULL,			NULL,			'WHITE',		'AFRICAN',	'URUK',			'Sumeria', 			'Sumerian',		'Sumerian Empire',						'Sumerian Government'		),
--(	'SOUTH_AFRICA',		'StandardPlayers',	NULL,					NULL,					'0',		NULL,			NULL,			'BLUE',			'AFRICAN',	'CAPE_TOWN',	'South Africa',		'South African','Republic of South Africa',				'South African Government'	),
(	'SPAIN',			'StandardPlayers',	NULL,					NULL,					'0',		'MEDIEVAL',		'450',			'RED',			'EURO',		'MADRID',		'Spain', 			'Spanish',		'Spanish Empire',						'Spanish Government'		),
--(	'SUDAN',			'StandardPlayers',	NULL,					NULL,					'0',		NULL,			NULL,			'YELLOW',		'AFRICAN',	'KHARTOUM',		'Sudan',			'Sudanese',		'Republic of the Sudan',                'Sudanese Government'		),
--(	'SWEDEN',			'StandardPlayers',	NULL,					NULL,					'0',		NULL,			NULL,			'YELLOW',		'EURO',		'STOCKHOLM',	'Sweden',			'Swedish',		'Kingdom of Sweden',					'Swedish Government'		),
--(	'TANZANIA',			'StandardPlayers',	NULL,					NULL,					'0',		NULL,			NULL,			'YELLOW',		'AFRICAN',	'DODOMA',		'Tanzania',			'Tanzanian',	'United Republic of Tanzania',          'Tanzanian Government'		),
(	'SIAM',				'StandardPlayers',	NULL,					NULL,					'0',		'MEDIEVAL',		'700',			'RED',			'ASIAN',	'BANGKOK',		'Siam',				'Siamese',		'Siamese Empire',						'Siamese Government'			),
--(	'TURKEY',			'StandardPlayers',	NULL,					NULL,					'0',		NULL,			NULL,			'RED',			'MEDIT',	'ANKARA',		'Turkey',			'Turkish',		'Republic of Turkey',					'Turkish Government'		),
--(	'UKRAINE',			'StandardPlayers',	NULL,					NULL,					'0',		NULL,			NULL,			'YELLOW',		'EURO',		'KIEV',			'Ukraine',			'Ukrainian',	'Ukraine',								'Ukrainian Government'		),
--(	'UZBEKISTAN',		'StandardPlayers',	NULL,					NULL,					'0',		NULL,			NULL,			'RED',			'ASIAN',	'TASHKENT',		'Uzbekistan',		'Uzbekistani',	'Republic of Uzbekistan',               'Uzbekistani Government'   ),
--(	'VENEZUELA',		'StandardPlayers',	NULL,					NULL,					'0',		NULL,			NULL,			'BLUE',			'SOUTHAM',	'CARACAS',		'Venezuela',		'Venezuelan',	'Bolivarian Republic of Venezuela',     'Venezuelan Government'	),
(	'VIETNAM',			'StandardPlayers',	NULL,					NULL,					'0',		'MEDIEVAL',		'900',			'RED',			'ASIAN',	'HANOI',		'Vietnam',			'Vietnamese',	'Vietnamese Empire',					'Vietnamese Government'	),

(	'TRIBE_EURO_1',		'StandardPlayers',	'WHITE',				'BLACK',				'1',		NULL,			NULL,			'WHITE',		'EURO',		'GROKVIL',		'European',			'Tribal',		'Tribal Settlement',					'Tribal WarChiefs'	),
(	'TRIBE_EURO_2',		'StandardPlayers',	'WHITE',				'BLACK',				'1',		NULL,			NULL,			'WHITE',		'EURO',		'GROKVIL',		'European',			'Tribal',		'Tribal Settlement',					'Tribal WarChiefs'	),
(	'TRIBE_EURO_3',		'StandardPlayers',	'WHITE',				'BLACK',				'1',		NULL,			NULL,			'WHITE',		'EURO',		'GROKVIL',		'European',			'Tribal',		'Tribal Settlement',					'Tribal WarChiefs'	),
(	'TRIBE_EURO_4',		'StandardPlayers',	'WHITE',				'BLACK',				'1',		NULL,			NULL,			'WHITE',		'EURO',		'GROKVIL',		'European',			'Tribal',		'Tribal Settlement',					'Tribal WarChiefs'	),
(	'TRIBE_EURO_5',		'StandardPlayers',	'WHITE',				'BLACK',				'1',		NULL,			NULL,			'WHITE',		'EURO',		'GROKVIL',		'European',			'Tribal',		'Tribal Settlement',					'Tribal WarChiefs'	),
(	'TRIBE_ASIAN_1',	'StandardPlayers',	'WHITE',				'BLACK',				'1',		NULL,			NULL,			'WHITE',		'ASIAN',	'GROKVIL',		'Asian',			'Tribal',		'Tribal Settlement',					'Tribal WarChiefs'	),
(	'TRIBE_ASIAN_2',	'StandardPlayers',	'WHITE',				'BLACK',				'1',		NULL,			NULL,			'WHITE',		'ASIAN',	'GROKVIL',		'Asian',			'Tribal',		'Tribal Settlement',					'Tribal WarChiefs'	),
(	'TRIBE_ASIAN_3',	'StandardPlayers',	'WHITE',				'BLACK',				'1',		NULL,			NULL,			'WHITE',		'ASIAN',	'GROKVIL',		'Asian',			'Tribal',		'Tribal Settlement',					'Tribal WarChiefs'	),
(	'TRIBE_ASIAN_4',	'StandardPlayers',	'WHITE',				'BLACK',				'1',		NULL,			NULL,			'WHITE',		'ASIAN',	'GROKVIL',		'Asian',			'Tribal',		'Tribal Settlement',					'Tribal WarChiefs'	),
(	'TRIBE_ASIAN_5',	'StandardPlayers',	'WHITE',				'BLACK',				'1',		NULL,			NULL,			'WHITE',		'ASIAN',	'GROKVIL',		'Asian',			'Tribal',		'Tribal Settlement',					'Tribal WarChiefs'	),
(	'TRIBE_SOUTHAM_1',	'StandardPlayers',	'WHITE',				'BLACK',				'1',		NULL,			NULL,			'WHITE',		'SOUTHAM',	'GROKVIL',		'SouthAm',			'Tribal',		'Tribal Settlement',					'Tribal WarChiefs'	),
(	'TRIBE_SOUTHAM_2',	'StandardPlayers',	'WHITE',				'BLACK',				'1',		NULL,			NULL,			'WHITE',		'SOUTHAM',	'GROKVIL',		'SouthAm',			'Tribal',		'Tribal Settlement',					'Tribal WarChiefs'	),
(	'TRIBE_SOUTHAM_3',	'StandardPlayers',	'WHITE',				'BLACK',				'1',		NULL,			NULL,			'WHITE',		'SOUTHAM',	'GROKVIL',		'SouthAm',			'Tribal',		'Tribal Settlement',					'Tribal WarChiefs'	),
(	'TRIBE_SOUTHAM_4',	'StandardPlayers',	'WHITE',				'BLACK',				'1',		NULL,			NULL,			'WHITE',		'SOUTHAM',	'GROKVIL',		'SouthAm',			'Tribal',		'Tribal Settlement',					'Tribal WarChiefs'	),
(	'TRIBE_SOUTHAM_5',	'StandardPlayers',	'WHITE',				'BLACK',				'1',		NULL,			NULL,			'WHITE',		'SOUTHAM',	'GROKVIL',		'SouthAm',			'Tribal',		'Tribal Settlement',					'Tribal WarChiefs'	),
(	'TRIBE_MEDIT_1',	'StandardPlayers',	'WHITE',				'BLACK',				'1',		NULL,			NULL,			'WHITE',		'MEDIT',	'GROKVIL',		'Medit',			'Tribal',		'Tribal Settlement',					'Tribal WarChiefs'	),
(	'TRIBE_MEDIT_2',	'StandardPlayers',	'WHITE',				'BLACK',				'1',		NULL,			NULL,			'WHITE',		'MEDIT',	'GROKVIL',		'Medit',			'Tribal',		'Tribal Settlement',					'Tribal WarChiefs'	),
(	'TRIBE_MEDIT_3',	'StandardPlayers',	'WHITE',				'BLACK',				'1',		NULL,			NULL,			'WHITE',		'MEDIT',	'GROKVIL',		'Medit',			'Tribal',		'Tribal Settlement',					'Tribal WarChiefs'	),
(	'TRIBE_MEDIT_4',	'StandardPlayers',	'WHITE',				'BLACK',				'1',		NULL,			NULL,			'WHITE',		'MEDIT',	'GROKVIL',		'Medit',			'Tribal',		'Tribal Settlement',					'Tribal WarChiefs'	),
(	'TRIBE_MEDIT_5',	'StandardPlayers',	'WHITE',				'BLACK',				'1',		NULL,			NULL,			'WHITE',		'MEDIT',	'GROKVIL',		'Medit',			'Tribal',		'Tribal Settlement',					'Tribal WarChiefs'	),
(	'TRIBE_AFRICAN_1',	'StandardPlayers',	'WHITE',				'BLACK',				'1',		NULL,			NULL,			'WHITE',		'AFRICAN',	'GROKVIL',		'African',			'Tribal',		'Tribal Settlement',					'Tribal WarChiefs'	),
(	'TRIBE_AFRICAN_2',	'StandardPlayers',	'WHITE',				'BLACK',				'1',		NULL,			NULL,			'WHITE',		'AFRICAN',	'GROKVIL',		'African',			'Tribal',		'Tribal Settlement',					'Tribal WarChiefs'	),
(	'TRIBE_AFRICAN_3',	'StandardPlayers',	'WHITE',				'BLACK',				'1',		NULL,			NULL,			'WHITE',		'AFRICAN',	'GROKVIL',		'African',			'Tribal',		'Tribal Settlement',					'Tribal WarChiefs'	),
(	'TRIBE_AFRICAN_4',	'StandardPlayers',	'WHITE',				'BLACK',				'1',		NULL,			NULL,			'WHITE',		'AFRICAN',	'GROKVIL',		'African',			'Tribal',		'Tribal Settlement',					'Tribal WarChiefs'	),
(	'TRIBE_AFRICAN_5',	'StandardPlayers',	'WHITE',				'BLACK',				'1',		NULL,			NULL,			'WHITE',		'AFRICAN',	'GROKVIL',		'African',			'Tribal',		'Tribal Settlement',					'Tribal WarChiefs'	),

(	'BARB_PEACE',		'StandardPlayers',	'WHITE',				'BLACK',				'1',		NULL,			NULL,			'RED',			'EURO',		'GROKVIL',		'Neutral Barbs',	'Barbarians',	'Barbarian Horde',						'Barbarian WarChiefs'	),

(	'END_OF_INSERT',	NULL,			NULL,					NULL,					'0',		NULL,			NULL,			NULL,			NULL,		NULL,			NULL,				NULL,			NULL,									NULL						);	
-----------------------------------------------

-- Remove "END_OF_INSERT" entry 
DELETE from CivilizationConfiguration WHERE Name ='END_OF_INSERT';


