/*

	Basic Civilizations
	Civilizations creation file
	by Gedemon (2017)
	
	Ethnicity : MEDIT | EURO | SOUTHAM | ASIAN | AFRICAN
	
*/
		
-----------------------------------------------
-- Temporary Tables for initialization
-----------------------------------------------
		
CREATE TABLE IF NOT EXISTS CivilizationConfiguration
	(	Name TEXT,
		Domain TEXT,
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
-- StandardPlayers	= Civilizations available with the standard mod
-- ExpandedPlayers 	= Civilizations activated by the "Basic Civilizations Expanded" mod
-----------------------------------------------
INSERT INTO CivilizationConfiguration
(	Name,			Domain,				PrimaryColor,			SecondaryColor,			TextColor,		Ethnicity,	CapitalName,	en_US_Name,			en_US_Adj,		en_US_Desc,								Leader_en_US ) VALUES
(	'ALGERIA',		'StandardPlayers',	NULL,					NULL,					'RED',			'MEDIT',	'ALGIERS',		'Algeria', 			'Algerian',		'Peoples Democratic Republic of Algeria','Algerian Government'		),
(	'AMERICA',		'StandardPlayers',	NULL,					NULL,					'WHITE',		'SOUTHAM',	'WASHINGTON',	'U.S.A.', 			'American',		'United States of America',				'American Government'		),
--(	'ANGOLA',		'StandardPlayers',	NULL,					NULL,					'YELLOW',		'AFRICAN',	'LUANDA',		'Angola',			'Angolan',		'Republic of Angola',                   'Angolan Government'		),
(	'ARABIA',		'StandardPlayers',	NULL,					NULL,					'WHITE',		'MEDIT',	'RIYADH',		'Saudi Arabia', 	'Arabian',		'Kingdom of Saudi Arabia',				'Arabian Government'		),
(	'ARGENTINA',	'StandardPlayers',	NULL,					NULL,					'YELLOW',		'SOUTHAM',	'BUENOS_AIRES',	'Argentina',		'Argentine',	'Argentine Republic',					'Argentinian Government'	),
(	'AUSTRALIA',	'StandardPlayers',	NULL,					NULL,					'RED',			'ASIAN',	'CANBERRA',		'Australia',		'Australian',	'Commonwealth of Australia',			'Australian Government'	),
(	'BRAZIL',		'StandardPlayers',	NULL,					NULL,					'WHITE',		'SOUTHAM',	'BRASILIA',		'Brazil', 			'Brazilian',	'Federative Republic of Brazil',		'Brazilian Government'		),
(	'CANADA',		'StandardPlayers',	NULL,					NULL,					'WHITE',		'SOUTHAM',	'OTTAWA',		'Canada',			'Canadian',		'Canada',								'Canadian Government'		),
--(	'CHILE',		'StandardPlayers',	NULL,					NULL,					'WHITE',		'SOUTHAM',	'SANTIAGO',		'Chile',			'Chilean',		'Republic of Chile',                    'Chilean Government'		),
(	'CHINA',		'StandardPlayers',	NULL,					NULL,					'RED',			'ASIAN',	'BEIJING',		'China',			'Chinese',		'Peoples Republic of China',			'Chinese Government'		),
(	'COLOMBIA',		'StandardPlayers',	NULL,					NULL,					'RED',			'SOUTHAM',	'BOGOTA',		'Colombia',			'Colombian',	'Republic of Colombia',					'Colombian Government'		),
(	'CONGO',		'StandardPlayers',	NULL,					NULL,					'WHITE',		'AFRICAN',	'KINCHASSA',	'Congo', 			'Congolese',	'Democratic Republic of the Congo',		'Congolese Government'		),
--(	'CUBA',			'StandardPlayers',	NULL,					NULL,					'WHITE',		'SOUTHAM',	'HAVANA',		'Cuba',				'Cuban',		'Republic of Cuba',						'Cuban Government'			),
--(	'DENMARK',		'StandardPlayers',	NULL,					NULL,					'WHITE',		'EURO',		'COPENHAGEN',	'Denmark',			'Danish',		'Kingdom of Denmark',					'Danish Government'		),
(	'EGYPT',		'StandardPlayers',	NULL,					NULL,					'YELLOW',		'MEDIT',	'CAIRO',		'Egypt', 			'Egyptian',		'Arab Republic of Egypt',				'Egyptian Government'		),
(	'ETHIOPIA',		'StandardPlayers',	NULL,					NULL,					'RED',			'AFRICAN',	'ADDIS_ABABA',	'Ethiopia',			'Ethiopian',	'Federal Democratic Republic of Ethiopia','Ethiopian Government'	),
--(	'FINLAND',		'StandardPlayers',	NULL,					NULL,					'WHITE',		'EURO',		'HELSINKI',		'Finland',			'Finnish',		'Republic of Finland',					'Finnish Government'		),
(	'FRANCE',		'StandardPlayers',	NULL,					NULL,					'WHITE',		'EURO',		'PARIS',		'France', 			'French',		'French Republic',						'French Government'		),
(	'GERMANY',		'StandardPlayers',	NULL,					NULL,					'WHITE',		'EURO',		'BERLIN',		'Germany', 			'German',		'Federal Republic of Germany',			'German Government'		),
(	'GREECE',		'StandardPlayers',	NULL,					NULL,					'BLUE',			'MEDIT',	'ATHENS',		'Greece', 			'Greek',		'Hellenic Republic',					'Greek Government'			),
--(	'ICELAND',		'StandardPlayers',	NULL,					NULL,					'WHITE',		'EURO',		'REYKJAVIK',	'Iceland',			'Icelandic',	'Iceland',								'Icelandic Government'		),
(	'INDIA',		'StandardPlayers',	NULL,					NULL,					'WHITE',		'MEDIT',	'DELHI',		'India', 			'Indian',		'Republic of India',					'Indian Government'		),
--(	'INDONESIA',	'StandardPlayers',	NULL,					NULL,					'RED',			'ASIAN',	'JAKARTA',		'Indonesia',		'Indonesian',	'Republic of Indonesia',				'Indonesian Government'	),
(	'PERSIA',		'StandardPlayers',	NULL,					NULL,					'WHITE',		'MEDIT',	'TEHRAN',		'Persia',			'Persian',		'Islamic Republic of Iran',				'Iranian Government'		),
(	'BABYLON',		'StandardPlayers',	NULL,					NULL,					'WHITE',		'MEDIT',	'BAGHDAD',		'Babylon',			'Babylonian',	'Republic of Iraq',						'Iraqi Government'			),
--(	'IRAN',			'StandardPlayers',	NULL,					NULL,					'WHITE',		'MEDIT',	'TEHRAN',		'Iran',				'Iranian',		'Islamic Republic of Iran',				'Iranian Government'		),
--(	'IRAQ',			'StandardPlayers',	NULL,					NULL,					'WHITE',		'MEDIT',	'BAGHDAD',		'Iraq',				'Iraqi',		'Republic of Iraq',						'Iraqi Government'			),
--(	'IRELAND',		'StandardPlayers',	NULL,					NULL,					'WHITE',		'EURO',		'DUBLIN',		'Ireland',			'Irish',		'Ireland',								'Irish Government'			),
--(	'ISRAEL',		'StandardPlayers',	NULL,					NULL,					'LIGHT_BLUE',	'MEDIT',	'JERUSALEM',	'Israel',			'Israeli',		'State of Israel',						'Israeli Government'		),
(	'ITALY',		'StandardPlayers',	NULL,					NULL,					'WHITE',		'MEDIT',	'ROME',			'Italy', 			'Italian',		'Italian Republic',						'Italian Government'		),
(	'JAPAN',		'StandardPlayers',	NULL,					NULL,					'RED',			'ASIAN',	'TOKYO',		'Japan', 			'Japanese',		'State of Japan',						'Japanese Government'		),
(	'KAZAKHSTAN',	'StandardPlayers',	NULL,					NULL,					'WHITE',		'ASIAN',	'ASTANA',		'Kazakhstan',		'Kazakh',		'Republic of Kazakhstan',				'Kazakh Government'		),
(	'KENYA',		'ExpandedPlayers',	NULL,					NULL,					'BLACK',		'AFRICAN',	'NAIROBI',		'Kenya',			'Kenyan',		'Republic of Kenya',                    'Kenyan Government'		),
--(	'LIBYA',		'StandardPlayers',	NULL,					NULL,					'WHITE',		'MEDIT',	'TRIPOLI',		'Libya',			'Libyan',		'State of Libya',						'Libyan Government'		),
--(	'MADAGASCAR',	'StandardPlayers',	NULL,					NULL,					'GREEN',		'AFRICAN',	'ANTANANARIVO',	'Madagascar',		'Madagascan',	'Republic of Madagascar',				'Madagascan Government'	),
(	'MALAYSIA',		'StandardPlayers',	NULL,					NULL,					'YELLOW',		'ASIAN',	'KUALA_LUMPUR',	'Malaysia',			'Malaysian',	'Federation of Malaysia',               'Malaysian Government'		),
(	'MALI',			'StandardPlayers',	NULL,					NULL,					'WHITE',		'AFRICAN',	'BAMAKO',		'Mali', 			'Malinese',		'Republic of Mali',						'Malinese Government'		),
(	'MEXICO',		'StandardPlayers',	NULL,					NULL,					'WHITE',		'SOUTHAM',	'MEXICO_CITY',	'Mexico', 			'Mexican',		'United Mexican States',				'Mexican Government'		),
(	'MONGOLIA',		'StandardPlayers',	NULL,					NULL,					'RED',			'ASIAN',	'ULAANBAATAR',	'Mongolia', 		'Mongolian',	'Mongolia',								'Mongolian Government'		),
(	'MOROCCO',		'StandardPlayers',	NULL,					NULL,					'RED',			'MEDIT',	'RABAT',		'Morocco',			'Moroccan',		'Kingdom of Morocco',					'Moroccan Government'		),
--(	'MYANMAR',		'StandardPlayers',	NULL,					NULL,					'RED',			'ASIAN',	'NAYPYIDAW',	'Myanmar',			'Burmese',		'Republic of the Union of Myanmar',		'Burmese Government'		),
(	'NETHERLANDS',	'StandardPlayers',	NULL,					NULL,					'WHITE',		'EURO',		'AMSTERDAM',	'Netherlands',		'Dutch',		'Kingdom of the Netherlands',			'Dutch Government'			),
--(	'NEW_ZEALAND',	'StandardPlayers',	NULL,					NULL,					'WHITE',		'ASIAN',	'WELLINGTON',	'New Zealand',		'New Zealand',	'New Zealand',							'New Zealand Government'	),
(	'NIGERIA',		'StandardPlayers',	NULL,					NULL,					'WHITE',		'AFRICAN',	'ABUJA',		'Nigeria',			'Nigerian',		'Federal Republic of Nigeria',          'Nigerian Government'		),
(	'NORWAY',		'StandardPlayers',	NULL,					NULL,					'WHITE',		'EURO',		'OSLO',			'Norway', 			'Norwegian',	'Kingdom of Norway',					'Norwegian Government'		),
--(	'PAKISTAN',		'StandardPlayers',	NULL,					NULL,					'WHITE',		'ASIAN',	'ISLAMABAD',	'Pakistan',			'Pakistani',	'Islamic Republic of Pakistan',         'Pakistani Government'		),
--(	'PERU',			'StandardPlayers',	NULL,					NULL,					'WHITE',		'SOUTHAM',	'LIMA',			'Peru',				'Peruvian',		'Republic of Peru',            			'Peruvian Government'		),
--(	'PHILIPPINES',	'StandardPlayers',	NULL,					NULL,					'YELLOW',		'ASIAN',	'MANILA',		'The Philippines',	'Philippine',	'Republic of the Philippines',          'Philippine Government'	),
--(	'POLAND',		'StandardPlayers',	NULL,					NULL,					'WHITE',		'EURO',		'WARSAW',		'Poland',			'Polish',		'Republic of Poland',					'Polish Government'		),
(	'PORTUGAL',		'StandardPlayers',	NULL,					NULL,					'YELLOW',		'EURO',		'LISBON',		'Portugal',			'Portuguese',	'Portuguese Republic',					'Portuguese Government'	),
--(	'ROMANIA',		'StandardPlayers',	NULL,					NULL,					'YELLOW',		'EURO',		'BUCHAREST',	'Romania',			'Romanian',		'Romania',                              'Romanian Government'		),
(	'RUSSIA',		'StandardPlayers',	NULL,					NULL,					'WHITE',		'EURO',		'MOSCOW',		'Russia', 			'Russian',		'Russian Federation',					'Russian Government'		),
--(	'SOUTH_AFRICA',	'StandardPlayers',	NULL,					NULL,					'BLUE',			'AFRICAN',	'CAPE_TOWN',	'South Africa',		'South African','Republic of South Africa',				'South African Government'	),
(	'KOREA',		'StandardPlayers',	NULL,					NULL,					'WHITE',		'ASIAN',	'SEOUL',		'Korea',			'Korean',		'Republic of Korea',					'South Korean Government'	),
(	'SPAIN',		'StandardPlayers',	NULL,					NULL,					'RED',			'EURO',		'MADRID',		'Spain', 			'Spanish',		'Kingdom of Spain',						'Spanish Government'		),
--(	'SUDAN',		'StandardPlayers',	NULL,					NULL,					'YELLOW',		'AFRICAN',	'KHARTOUM',		'Sudan',			'Sudanese',		'Republic of the Sudan',                'Sudanese Government'		),
(	'SWEDEN',		'StandardPlayers',	NULL,					NULL,					'YELLOW',		'EURO',		'STOCKHOLM',	'Sweden',			'Swedish',		'Kingdom of Sweden',					'Swedish Government'		),
--(	'TANZANIA',		'StandardPlayers',	NULL,					NULL,					'YELLOW',		'AFRICAN',	'DODOMA',		'Tanzania',			'Tanzanian',	'United Republic of Tanzania',          'Tanzanian Government'		),
(	'THAILAND',		'StandardPlayers',	NULL,					NULL,					'RED',			'ASIAN',	'BANGKOK',		'Thailand',			'Thai',			'Kingdom of Thailand',					'Thai Government'			),
(	'TURKEY',		'StandardPlayers',	NULL,					NULL,					'RED',			'MEDIT',	'ANKARA',		'Turkey',			'Turkish',		'Republic of Turkey',					'Turkish Government'		),
(	'ENGLAND',		'StandardPlayers',	NULL,					NULL,					'WHITE',		'EURO',		'LONDON',		'England', 			'British',		'United Kingdom',						'British Government'		),
--(	'UKRAINE',		'StandardPlayers',	NULL,					NULL,					'YELLOW',		'EURO',		'KIEV',			'Ukraine',			'Ukrainian',	'Ukraine',								'Ukrainian Government'		),
(	'UZBEKISTAN',	'StandardPlayers',	NULL,					NULL,					'RED',			'ASIAN',	'TASHKENT',		'Uzbekistan',		'Uzbekistani',	'Republic of Uzbekistan',               'Uzbekistani Government'   ),
--(	'VENEZUELA',	'StandardPlayers',	NULL,					NULL,					'BLUE',			'SOUTHAM',	'CARACAS',		'Venezuela',		'Venezuelan',	'Bolivarian Republic of Venezuela',     'Venezuelan Government'	),
(	'VIETNAM',		'StandardPlayers',	NULL,					NULL,					'RED',			'ASIAN',	'HANOI',		'Vietnam',			'Vietnamese',	'Socialist Republic of Vietnam',		'Vietnamese Government'	),

(	'END_OF_INSERT',	NULL,			NULL,					NULL,					NULL,			NULL,		NULL,			NULL,				NULL,			NULL,									NULL						);	
-----------------------------------------------

-- Remove "END_OF_INSERT" entry 
DELETE from CivilizationConfiguration WHERE Name ='END_OF_INSERT';


