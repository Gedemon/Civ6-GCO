
DELETE from Parameters WHERE ParameterId ='RequestedResources' and Key1 IS NOT NULL;
DELETE from ParameterDependencies WHERE ParameterId ='RequestedResources';

UPDATE MapSizes SET DefaultPlayers ='30' WHERE MapSizeType = 'MAPSIZE_GIANT' OR MapSizeType = 'MAPSIZE_LUDICROUS';