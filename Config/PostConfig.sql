
DELETE from Parameters WHERE ParameterId ='RequestedResources';
DELETE from ParameterDependencies WHERE ParameterId ='RequestedResources';

UPDATE MapSizes SET DefaultPlayers ='55' WHERE MapSizeType = 'MAPSIZE_GIANT' OR MapSizeType = 'MAPSIZE_LUDICROUS';