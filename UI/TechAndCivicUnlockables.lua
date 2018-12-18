------------------------------------------------------------------------------
--	Shared logic for discovering what techs and civics unlock.
------------------------------------------------------------------------------

-- ===========================================================================
--	Filter out base items from the list that also contain a replacement,
--  or which are excluded entirely (with no replacement) by a player trait.
--  This method does NOT maintain ordering.
-- ===========================================================================
function RemoveReplacedUnlockables(unlockables, playerId) 
	local has_trait = GetTraitMapForPlayer(playerId);
	
	local unlock_map = {};
	for i,v in ipairs(unlockables) do
		unlock_map[v[2]] = v;
	end

	for row in GameInfo.BuildingReplaces() do
		if(unlock_map[row.CivUniqueBuildingType]) then
			unlock_map[row.ReplacesBuildingType] = nil;
		end
	end

	for row in GameInfo.DistrictReplaces() do
		if(unlock_map[row.CivUniqueDistrictType]) then
			unlock_map[row.ReplacesDistrictType] = nil;
		end
	end

	for row in GameInfo.ExcludedDistricts() do
		if(has_trait[row.TraitType]) then
			unlock_map[row.DistrictType] = nil;
		end
	end

	for row in GameInfo.UnitReplaces() do
		if(unlock_map[row.CivUniqueUnitType]) then
			unlock_map[row.ReplacesUnitType] = nil;
		end
	end
	
	local results = {};
	for k,v in pairs(unlockables) do
		if(unlock_map[v[2]])then
			table.insert(results, v);
		end
	end

	return results;
end

-- ===========================================================================
--  Returns a map containing all traits a given player has.  
--  Key == TraitType, value == true.
-- ===========================================================================
function GetTraitMapForPlayer(playerId)
	if(playerId == nil) then
		return nil;	
	else
		local has_trait:table = nil;
		local player = playerId and Players[playerId];
		if(player ~= nil) then
			has_trait = {};
			local config = PlayerConfigurations[playerId];
			if(config ~= nil) then
				local leaderType = config:GetLeaderTypeName();
				local civType = config:GetCivilizationTypeName();

				if(leaderType) then
					for row in GameInfo.LeaderTraits() do
						if(row.LeaderType== leaderType) then
							has_trait[row.TraitType] = true;
						end
					end
				end

				if(civType) then
					for row in GameInfo.CivilizationTraits() do
						if(row.CivilizationType== civType) then
							has_trait[row.TraitType] = true;
						end
					end
				end
			end
		end
		return has_trait;
	end
end

-- ===========================================================================
--  Returns an array of all possible items unlocked by an optional player id.
-- ===========================================================================
function GetUnlockableItems(playerId)
	
	local has_trait = GetTraitMapForPlayer(playerId);

	function CanEverUnlock(item)
		return item.TraitType ~= "TRAIT_BARBARIAN" and ((item.TraitType == nil) or (has_trait == nil) or has_trait[item.TraitType]);	
	end

	local unlockables = {};
	
	for row in GameInfo.Governments() do
		if(CanEverUnlock(row)) then
			table.insert(unlockables, {row, row.GovernmentType, row.Name, row.GovernmentType});
		end
	end

	for row in GameInfo.Policies() do
		if(CanEverUnlock(row)) then
			table.insert(unlockables, {row, row.PolicyType, row.Name, row.PolicyType});
		end
	end

	for row in GameInfo.Buildings() do
		if(CanEverUnlock(row)) and not (row.NoPedia) then
			table.insert(unlockables, {row, row.BuildingType, row.Name, row.BuildingType});
		end
	end
		
	for row in GameInfo.Districts() do
		if(CanEverUnlock(row)) then
			table.insert(unlockables, {row, row.DistrictType, row.Name, row.DistrictType});
		end
	end		
	for row in GameInfo.Units() do
		if(CanEverUnlock(row)) then
			table.insert(unlockables, {row, row.UnitType, row.Name, row.UnitType});
		end
	end

	for row in GameInfo.Improvements() do
		if(CanEverUnlock(row)) then
			table.insert(unlockables, {row, row.ImprovementType, row.Name, row.ImprovementType});
		end
	end

	for row in GameInfo.Projects() do
		if(CanEverUnlock(row)) then
			table.insert(unlockables, {row, row.ProjectType, row.Name, row.ProjectType});
		end
	end

	for row in GameInfo.Resources() do
		if(CanEverUnlock(row)) then
			table.insert(unlockables, {row, row.ResourceType, row.Name, row.ResourceType});
		end
	end

	for row in GameInfo.DiplomaticActions() do
		if(CanEverUnlock(row)  and row.Name ~= nil) then
			table.insert(unlockables, {row, row.DiplomaticActionType, row.Name, row.CivilopediaKey});
		end
	end

	return unlockables;
end

-- ===========================================================================
--	Returns an array of items unlocked by a given tech and optional player id.
--  The item format is an array of {ID, Name, CivilopediaKey}
-- ===========================================================================
function GetUnlockablesForTech( techType, playerId )

	-- Treat -1 NO_PLAYER as nil.
	if(type(playerId) == "number" and playerId < 0) then
		playerId = nil;
	end

	-- Ensure a string civic type rather than hash or index.
	local techInfo = GameInfo.Technologies[techType];
	techType = techInfo.TechnologyType;

	function CanUnlockWithThisTech(item) 
		return (item.PrereqTech == techType) or (item.InitiatorPrereqTech == techType);
	end
		
	-- Populate a complete list of unlockables.
	-- This must be a complete list because some replacement items exist with different prereqs than
	-- that which they replace.
	local unlockables = GetUnlockableItems(playerId);

	-- Filter out replaced items. 
	-- (Only do this if we have a player specified, otherwise this would filter ALL replaced items).
	if(playerId ~= nil) then
		unlockables = RemoveReplacedUnlockables(unlockables, playerId)
	end

	local results = {};
	for i, unlockable in ipairs(unlockables) do
		if(CanUnlockWithThisTech(unlockable[1])) then
			table.insert(results, {select(2,unpack(unlockable))});
		end
	end

	return results;
end

-- ===========================================================================
--	Returns an array of items unlocked by a given civic and optional player id.
--  The item format is an array of {ID, Name, CivilopediaKey}
-- ===========================================================================
function GetUnlockablesForCivic(civicType, playerId)

	-- Treat -1 NO_PLAYER as nil.
	if(type(playerId) == "number" and playerId < 0) then
		playerId = nil;
	end
	
	-- Ensure a string civic type rather than hash or index.
	local civicInfo = GameInfo.Civics[civicType];
	civicType = civicInfo.CivicType;

	function CanUnlockWithCivic(item) 
		return item.PrereqCivic == civicType or item.InitiatorPrereqCivic == civicType;
	end
		
	-- Populate a complete list of unlockables.
	-- This must be a complete list because some replacement items exist with different prereqs than
	-- that which they replace.
	local unlockables = GetUnlockableItems(playerId);

	-- SHIMMY SHIM SHIM
	-- This is gifted via a modifier and we presently don't 
	-- support scrubbing modifiers to add to unlockables. 
	-- Maybe in a patch :)
	if(civicType == "CIVIC_DIPLOMATIC_SERVICE") then
		local spy = GameInfo.Units["UNIT_SPY"]
		if(spy) then
			table.insert(unlockables, {spy, spy.UnitType, spy.Name});
		end
	end

	-- Filter out replaced items. 
	-- (Only do this if we have a player specified, otherwise this would filter ALL replaced items).
	if(playerId ~= nil) then
		unlockables = RemoveReplacedUnlockables(unlockables, playerId)
	end

	local results = {};
	for i, unlockable in ipairs(unlockables) do
		if(CanUnlockWithCivic(unlockable[1])) then
			table.insert(results, {select(2,unpack(unlockable))});
		end
	end

	return results;
end
