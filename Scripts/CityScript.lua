--=====================================================================================--
--	FILE:	 CityScript.lua
--  Gedemon (2017)
--=====================================================================================--

print ("Loading CityScript.lua...")

-----------------------------------------------------------------------------------------
-- Defines
-----------------------------------------------------------------------------------------

local LinkedUnits 	= {}
local LinkedCities 	= {}

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

function Initialize() -- called immediatly on load
	Events.CityAddedToMap.Add( InitializeCityFunctions ) -- first as InitializeCity() may require those functions
	Events.CityAddedToMap.Add( InitializeCity )
end

function SaveTables()
	--print("--------------------------- Saving CityData ---------------------------")
	GCO.StartTimer("CityData")
	GCO.SaveTableToSlot(ExposedMembers.CityData, "CityData")
	GCO.ShowTimer("CityData")
end
LuaEvents.SaveTables.Add(SaveTables)

-----------------------------------------------------------------------------------------
-- Utils functions
-----------------------------------------------------------------------------------------

function GetPopulationPerSize(size)
	return math.pow(size, 2.8) * 1000
end

-----------------------------------------------------------------------------------------
-- City functions
-----------------------------------------------------------------------------------------

function GetSize(self) -- for code consistency
	return self:GetPopulation()
end

function ChangeSize(self)
	if GetPopulationPerSize(self:GetSize()-1) > self:GetRealPopulation() then
		self:ChangePopulation(-1) -- (-1, true) ?
	elseif GetPopulationPerSize(self:GetSize()+1) < self:GetRealPopulation() then
		self:ChangePopulation(1)
	end
end

function GetRealPopulation(self) -- city:GetPopulation() returns city size
	local key = self:GetKey()
	if ExposedMembers.CityData[key] then
		return ExposedMembers.CityData[key].Population
	end
	return 0
end

function GetMaxStock(self, resourceID)
	local maxStock = self:GetSize() * tonumber(GameInfo.GlobalParameters["CITY_MAX_STOCK_PER_SIZE"].Value)

	return maxStock
end

function GetMaxPersonnel(self)
	local maxPersonnel = self:GetSize() * tonumber(GameInfo.GlobalParameters["CITY_MAX_PERSONNEL_PER_SIZE"].Value)

	return maxPersonnel
end


-----------------------------------------------------------------------------------------
-- Initialize Cities
-----------------------------------------------------------------------------------------

function RegisterNewCity(playerID, city)

	local cityKey 	= city:GetKey()
	local personnel = city:GetMaxPersonnel()
	
	ExposedMembers.UnitData[cityKey] = {
		cityID 					= city:GetID(),
		playerID 				= playerID,
		Personnel 				= personnel,
		PreviousPersonnel		= personnel,
		Prisonners				= GCO.CreateEverAliveTableWithDefaultValue(0),
		Stock					= {},
		PreviousStock			= {},
		Population				= GetPopulationPerSize(city:GetSize()),
	}
	
	LuaEvents.NewCityCreated()	
end

function InitializeCity(playerID, cityID) -- add to Events.CityAddedToMap in initialize()
	local city = CityManager.GetCity(playerID, cityID)
	if city then
		local cityKey = city:GetKey()

		if ExposedMembers.CityData[cityKey] then
			-- city already registered, don't add it again...
			print("  - ".. city:GetName() .." is already registered")
			return
		end

		print ("Initializing new city (".. city:GetName() ..") for player #".. tostring(playerID).. " id#" .. tostring(city:GetID()))
		RegisterNewCity(playerID, city)
		print("-------------------------------------")
	else
		print ("- WARNING : tried to initialize nil city for player #".. tostring(playerID))
	end

end


-----------------------------------------------------------------------------------------
-- Resources functions
-----------------------------------------------------------------------------------------

function UpdateLinkedUnits(self)
	LinkedUnits[self] = {}
	for unitKey, data in pairs(ExposedMembers.UnitData) do
		if data.SupplyLineCityKey == self:GetKey() then
			local unit = UnitManager.GetUnit(data.playerID, data.unitID)
			if unit then
				table.insert(LinkedUnits[self], unit)
			end
		end
	end	
end

function UpdateLinkedCities(self)
	LinkedCities[self] = {}
end

-----------------------------------------------------------------------------------------
-- Do Turn for Cities
-----------------------------------------------------------------------------------------

function CityDoTurn(city)
	city:UpdateLinkedUnits()
	city:UpdateLinkedCities()
	-- get Resources (allow excedents)
	-- diffuse to other cities, sell to foreign cities (do turn for traders ?), reinforce units, use in industry... (orders set in UI ?)
	-- remove excedents left
end

function DoCitiesTurn( playerID )

	local player = Players[playerID]
	local playerCities = player:GetCities()
	if playerCities then
		for i, city in playerCities:Members() do
			CityDoTurn(city)
		end
	end
end
LuaEvents.DoCitiesTurn.Add( DoCitiesTurn )

-----------------------------------------------------------------------------------------
-- Initialize City Functions
-----------------------------------------------------------------------------------------

function InitializeCityFunctions(playerID, cityID) -- add to Events.CityAddedToMap in initialize()
	-- Note that those functions are limited to this file context
	local city = CityManager.GetCity(playerID, cityID)
	local c = getmetatable(city).__index
	c.ChangeSize				= ChangeSize
	c.GetSize					= GetSize
	c.GetRealPopulation			= GetRealPopulation
	c.GetKey					= GCO.GetCityKey
	c.GetMaxStock				= GetMaxStock
	c.GetMaxPersonnel			= GetMaxPersonnel
	c.UpdateLinkedUnits			= UpdateLinkedUnits
	c.UpdateLinkedCities		= UpdateLinkedCities
	
	Events.CityAddedToMap.Remove(InitializeCityFunctions)
end

Initialize()