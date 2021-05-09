
DELETE from Parameters WHERE ParameterId ='RequestedResources' and Key1 IS NOT NULL;
DELETE from ParameterDependencies WHERE ParameterId ='RequestedResources';

UPDATE MapSizes SET DefaultPlayers ='30' WHERE MapSizeType = 'MAPSIZE_GIANT' OR MapSizeType = 'MAPSIZE_LUDICROUS';

UPDATE Parameters SET DefaultValue = 1, Visible = 0 WHERE ConfigurationId = 'GAME_NO_GOODY_HUTS';

UPDATE Parameters SET DefaultValue = 'GAMESPEED_STANDARD' WHERE ConfigurationId = 'GAME_SPEED_TYPE';