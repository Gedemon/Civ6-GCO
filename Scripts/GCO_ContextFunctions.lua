-----------------------------------------------------------------------------------------
--	FILE:	 ContextFunctions.lua
--  Gedemon (2017)
-----------------------------------------------------------------------------------------

print ("Loading ContextFunctions.lua...")

--=================================================
-- Initialize UI context function to use them in scripts
-- Notes from Salec (Firaxis) https://forums.civfanatics.com/threads/information-from-firaxis-developer-on-the-mod-tools.611291/
--[[
		The gameplay DLL is running on a separate thread and has it's own set of lua exposures.
		The UI scripts act on cached data that may not be 100% in sync with the state of the gameplay dll (for example if it's playing back combat)
		Because of this the UI-side lua scripts have some different exposures than the gameplay side.
--]]
--=================================================

include( "Civ6Common" )

----------------------------------------------
-- Defines
----------------------------------------------

local ProductionTypes = {
		UNIT		= 0,
		BUILDING	= 1,
		DISTRICT 	= 2
	}

----------------------------------------------
-- Initialize
----------------------------------------------
local GCO = ExposedMembers.GCO -- Initialize with what is already loaded from script contexts, we may need them before the next call to GameCoreEventPublishComplete after this file is loaded
function InitializeUtilityFunctions()
	GCO = ExposedMembers.GCO -- Reinitialize with what may have been added with other UI contexts
	print ("Exposed Functions from other contexts initialized...")
end
LuaEvents.InitializeGCO.Add( InitializeUtilityFunctions )


----------------------------------------------
-- Cities functions
----------------------------------------------
function GetCityCultureYield(plot)
	local contextCity = Cities.GetCityInPlot(plot:GetX(), plot:GetY())  -- We can't use an object comming from a script context to call a function exposed only to the UI context...
	if not contextCity then return 0 end
	local cityCulture = contextCity:GetCulture()
	if cityCulture then
		return cityCulture:GetCultureYield()
	else
		return 0
	end
end

function GetCityPlots(city)
	local contextCity = CityManager.GetCity(city:GetOwner(), city:GetID())
	return Map.GetCityPlots():GetPurchasedPlots(contextCity)
end

function GetCityYield(city, yieldType)
	local contextCity = CityManager.GetCity(city:GetOwner(), city:GetID())
	if not contextCity then return 0 end
	return contextCity:GetYield(yieldType)
end

function GetCityTrade(city)
	local contextCity = CityManager.GetCity(city:GetOwner(), city:GetID())
	return contextCity:GetTrade()
end

function CityCanProduce(city, productionType)
	local contextCity = CityManager.GetCity(city:GetOwner(), city:GetID())
	if not contextCity then return false end
	local pCityBuildQueue = contextCity:GetBuildQueue()
	return pCityBuildQueue:CanProduce( productionType, true )
end

function GetCityProductionTurnsLeft(city, productionType)
	local contextCity = CityManager.GetCity(city:GetOwner(), city:GetID())
	if not contextCity then return 0 end
	local pCityBuildQueue = contextCity:GetBuildQueue()
	return pCityBuildQueue:GetTurnsLeft( productionType )
end

function GetCityProductionYield(city)
	local contextCity = CityManager.GetCity(city:GetOwner(), city:GetID())
	if not contextCity then return 0 end
	local pCityBuildQueue = contextCity:GetBuildQueue()
	return pCityBuildQueue:GetProductionYield()
end

function GetCityProductionProgress(city, productionType, objetID)
	local contextCity = CityManager.GetCity(city:GetOwner(), city:GetID())
	if not contextCity then return 0 end
	local pCityBuildQueue = contextCity:GetBuildQueue()
	if productionType == ProductionTypes.UNIT then
		return pCityBuildQueue:GetUnitProgress(objetID)
	elseif productionType == ProductionTypes.BUILDING then
		return pCityBuildQueue:GetBuildingProgress(objetID)
	elseif productionType == ProductionTypes.DISTRICT then
		return pCityBuildQueue:GetDistrictProgress(objetID)
	else
		return pCityBuildQueue:GetUnitProgress(objetID)
	end
end

----------------------------------------------
-- Game functions
----------------------------------------------
function GetTradeManager()
	return Game.GetTradeManager()
end

----------------------------------------------
-- Players functions
----------------------------------------------
function HasPlayerOpenBordersFrom(player, otherPlayerID)
	local contextPlayer = Players[player:GetID()] -- We can't use an object comming from a script context to call a function exposed only to the UI context...
	return contextPlayer:GetDiplomacy():HasOpenBordersFrom( otherPlayerID )
end

function IsResourceVisibleFor(player, resourceID)
	local contextPlayer = Players[player:GetID()] -- We can't use an object comming from a script context to call a function exposed only to the UI context...
	return contextPlayer:GetResources():IsResourceVisible( resourceID )
end

function HasPolicyActive(player, policyID)
	local contextPlayer 	= Players[player:GetID()] -- We can't use an object comming from a script context to call a function exposed only to the UI context...
	local kPlayerCulture	= contextPlayer:GetCulture()
	local numSlots:number 	= kPlayerCulture:GetNumPolicySlots();
	for i = 0, numSlots-1, 1 do
		if policyID == kPlayerCulture:GetSlotPolicy(i) then
			return true
		end			
	end
	return false
end

----------------------------------------------
-- Plots functions
----------------------------------------------
function IsImprovementPillaged(plot)
	local contextPlot = Map.GetPlot(plot:GetX(), plot:GetY())
	return contextPlot:IsImprovementPillaged()
end


----------------------------------------------
-- Units functions
----------------------------------------------
function GetMoveToPath( unit, plotIndex )
	local contextUnit = UnitManager.GetUnit(unit:GetOwner(), unit:GetID())
	return UnitManager.GetMoveToPath( contextUnit, plotIndex )
end

function SetUnitName( unit, name )
	local contextUnit = UnitManager.GetUnit(unit:GetOwner(), unit:GetID())
	if (contextUnit) then
		local tParameters = {};
		tParameters[UnitCommandTypes.PARAM_NAME] = name
		if (name ~= "") then
			UnitManager.RequestCommand( contextUnit, UnitCommandTypes.NAME_UNIT, tParameters );
		end
	end
end


----------------------------------------------
-- Initialize functions for other contexts
----------------------------------------------
function Initialize()
	if not ExposedMembers.GCO then ExposedMembers.GCO = {} end	
	
	-- cities
	ExposedMembers.GCO.GetCityCultureYield 			= GetCityCultureYield
	ExposedMembers.GCO.GetCityPlots					= GetCityPlots
	ExposedMembers.GCO.GetCityYield 				= GetCityYield
	ExposedMembers.GCO.GetCityTrade 				= GetCityTrade
	ExposedMembers.GCO.CityCanProduce				= CityCanProduce
	ExposedMembers.GCO.GetCityProductionTurnsLeft	= GetCityProductionTurnsLeft
	ExposedMembers.GCO.GetCityProductionYield		= GetCityProductionYield
	ExposedMembers.GCO.GetCityProductionProgress	= GetCityProductionProgress
	-- Game
	ExposedMembers.GCO.GetTradeManager 				= GetTradeManager
	-- players
	ExposedMembers.GCO.HasPlayerOpenBordersFrom 	= HasPlayerOpenBordersFrom
	ExposedMembers.GCO.IsResourceVisibleFor 		= IsResourceVisibleFor
	ExposedMembers.GCO.HasPolicyActive 				= HasPolicyActive
	-- plots
	--local p = getmetatable(Map.GetPlot(1,1)).__index
	--ExposedMembers.GCO.PlotIsImprovementPillaged	= p.IsImprovementPillaged -- attaching this in script context doesn't work as the plot object from script miss other elements required for this by the plot object in UI context 
	ExposedMembers.GCO.IsImprovementPillaged 		= IsImprovementPillaged
	-- units
	ExposedMembers.GCO.GetMoveToPath				= GetMoveToPath
	ExposedMembers.GCO.SetUnitName					= SetUnitName
	-- others
	ExposedMembers.UI 								= UI
	ExposedMembers.Calendar							= Calendar
	ExposedMembers.CombatTypes 						= CombatTypes
	
	ExposedMembers.ContextFunctions_Initialized 	= true
end
Initialize()


----------------------------------------------
-- Testing...
----------------------------------------------
local _cache = {}
function CheckProgression()
	for _, playerID in ipairs(PlayerManager.GetWasEverAliveMajorIDs()) do
		local player 	= Players[playerID]
		local capital 	= player:GetCities():GetCapitalCity()
		if capital then
			GCO.AttachCityFunctions(capital)
			local cityKey				= capital:GetKey()
			local productionHash		= capital:GetBuildQueue():GetCurrentProductionTypeHash()
			local currentProductionInfo	= GetProductionInfoOfCity( capital, productionHash )
			if not _cache[cityKey] then _cache[cityKey] = {} end		
			if not _cache[cityKey].PercentComplete then
				_cache[cityKey].PercentComplete = currentProductionInfo.PercentComplete
				print ("Production progressed at ", Locale.Lookup(capital:GetName()), currentProductionInfo.PercentComplete)
			end
			if _cache[cityKey].PercentComplete ~= currentProductionInfo.PercentComplete then
				_cache[cityKey].PercentComplete = currentProductionInfo.PercentComplete
				print ("Production progressed at ", Locale.Lookup(capital:GetName()), currentProductionInfo.PercentComplete)
			end
		end
	end
end
--Events.GameCoreEventPublishComplete.Add( CheckProgression )

--[[
	return {
		Name					= productionName,
		Description				= description, 
		Type					= type;
		Icon					= iconName,
		PercentComplete			= percentComplete, 
		PercentCompleteNextTurn	= percentCompleteNextTurn,
		Turns					= prodTurnsLeft,
		StatString				= statString;
		Progress				= progress;
		Cost					= cost;		
	};
--]]