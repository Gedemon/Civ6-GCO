--=====================================================================================--
--	FILE:	 CityScript.lua
--  Gedemon (2017)
--=====================================================================================--

print ("Loading CityScript.lua...")

-----------------------------------------------------------------------------------------
-- Defines
-----------------------------------------------------------------------------------------

local LinkedUnits 		= {}	-- temporary table to list all units linked to a city for supply
local UnitsSupplyDemand	= {}	-- temporary table to list all resources required by units
local CitiesForTransfer = {}	-- temporary table to list all cities connected via (internal) trade routes to a city
local CitiesForTrade	= {}	-- temporary table to list all cities connected via (external) trade routes to a city

-----------------------------------------------------------------------------------------
-- Initialize
-----------------------------------------------------------------------------------------

local GCO = {}
function InitializeUtilityFunctions()
	GCO = ExposedMembers.GCO		-- contains functions from other contexts
	print ("Exposed Functions from other contexts initialized...")
	PostInitialize()
end
LuaEvents.InitializeGCO.Add( InitializeUtilityFunctions )

function PostInitialize() -- everything that may require other context to be loaded first
	ExposedMembers.CityData = GCO.LoadTableFromSlot("CityData") or {}
end

function Initialize() -- called immediatly after loading this file
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
	
	ExposedMembers.CityData[cityKey] = {
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

-- for debugging
function ShowCityData()
	for cityKey, data in pairs(ExposedMembers.CityData) do
		print (cityKey, data)
		for k, v in pairs (data) do
			print ("-", k, v)
			if k == "Prisonners" then
				for id, num in pairs (v) do
					print ("-", "-", id, num)
				end			
			end
		end
	end
end

-----------------------------------------------------------------------------------------
-- Resources functions
-----------------------------------------------------------------------------------------

function UpdateLinkedUnits(self)
	LinkedUnits[self] 		= {}
	UnitsSupplyDemand[self] = {}
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
	CitiesForTransfer[self] = {}
	CitiesForTrade[self] 	= {}
end

-----------------------------------------------------------------------------------------
-- Do Turn for Cities
-----------------------------------------------------------------------------------------

function CityDoTurn(city)

	-- get linked units and supply demand
	city:UpdateLinkedUnits()
	
	-- get linked cities
	city:UpdateLinkedCities()
	
	-- get Resources (allow excedents)
	
	-- diffuse to other cities, sell to foreign cities (do turn for traders ?), reinforce units, use in industry... (orders set in UI ?)
	
	-- remove excedents left
	
	-- Update City Size
	--city:ChangeSize()
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