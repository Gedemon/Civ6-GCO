--=====================================================================================--
--	FILE:	 CityScript.lua
--  Gedemon (2017)
--=====================================================================================--

print ("Loading CityScript.lua...")

-----------------------------------------------------------------------------------------
-- Defines
-----------------------------------------------------------------------------------------


-----------------------------------------------------------------------------------------
-- Initialize Globals Functions
-----------------------------------------------------------------------------------------

local GCO = {}
function InitializeUtilityFunctions() 	-- Get functions from other contexts
	if ExposedMembers.IsInitializedGCO and ExposedMembers.IsInitializedGCO() then
		GCO = ExposedMembers.GCO		-- contains functions from other contexts
		Events.GameCoreEventPublishComplete.Remove( InitializeUtilityFunctions )
		print ("Exposed Functions from other contexts initialized...")
		ExposedMembers.CityData = GCO.LoadTableFromSlot("CityData") or {}
	end
end
Events.GameCoreEventPublishComplete.Add( InitializeUtilityFunctions )

function SaveTables()
	--print("--------------------------- Saving CityData ---------------------------")
	GCO.StartTimer("CityData")
	GCO.SaveTableToSlot(ExposedMembers.CityData, "CityData")
	GCO.ShowTimer("CityData")
end
LuaEvents.SaveTables.Add(SaveTables)

-----------------------------------------------------------------------------------------
-- City functions
-----------------------------------------------------------------------------------------

function GetKey(self)
	return self:GetID() ..",".. self:GetOriginalOwner()
end

function ChangeSize(self)
	if math.pow(self:GetPopulation()-1, 2.8) * 1000 > self:GetCurrentPopulation() then
		self:ChangePopulation(-1) -- (-1, true) ?
	elseif math.pow(self:GetPopulation()+1, 2.8) * 1000 < self:GetCurrentPopulation() then
		self:ChangePopulation(1)
	end
end

function GetCurrentPopulation(self)
	local key = self:GetKey()
	if ExposedMembers.CityData[key] then
		return ExposedMembers.CityData[key].Population
	end
	return 0
end


-----------------------------------------------------------------------------------------
-- Initialize City Functions
-----------------------------------------------------------------------------------------

function InitializeCityFunctions(playerID, cityID) -- Note that those functions are limited to this file context
	local city = CityManager.GetCity(playerID, cityID)
	local c = getmetatable(city).__index
	c.ChangeSize				= ChangeSize
	c.GetCurrentPopulation		= GetCurrentPopulation
	c.GetKey					= GetKey
	
	Events.CityAddedToMap.Remove(InitializeCityFunctions)
end
Events.CityAddedToMap.Add(InitializeCityFunctions)