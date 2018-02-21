--=====================================================================================--
--	FILE:	 ModUtils.lua
--  Gedemon (2017)
--=====================================================================================--

print ("Loading ModUtils.lua...")
local LoadTimer = Automation.GetTime()
--=====================================================================================--
-- Includes
--=====================================================================================--
include( "GCO_TypeEnum" )
include( "GCO_SmallUtils" )


--=====================================================================================--
-- Defines
--=====================================================================================--

-- This file is the first to load, do some cleaning here just in case Events.LeaveGameComplete() hasn't fired on returning to main menu or loading a game...
ExposedMembers.SaveLoad_Initialized 		= nil
ExposedMembers.ContextFunctions_Initialized	= nil
ExposedMembers.Utils_Initialized 			= nil
ExposedMembers.Serialize_Initialized 		= nil
ExposedMembers.RouteConnections_Initialized	= nil
ExposedMembers.PlotIterator_Initialized		= nil
ExposedMembers.PlotScript_Initialized 		= nil
ExposedMembers.CityScript_Initialized 		= nil
ExposedMembers.UnitScript_Initialized		= nil
ExposedMembers.PlayerScript_Initialized 	= nil
ExposedMembers.GameScript_Initialized		= nil
ExposedMembers.GCO_Initialized 				= nil 

local ResourceValue = {			-- cached table with value of resources type
		["RESOURCECLASS_LUXURY"] 	= tonumber(GameInfo.GlobalParameters["CITY_TRADE_INCOME_RESOURCE_LUXURY"].Value),
		["RESOURCECLASS_STRATEGIC"]	= tonumber(GameInfo.GlobalParameters["CITY_TRADE_INCOME_RESOURCE_STRATEGIC"].Value),
		["RESOURCECLASS_BONUS"]		= tonumber(GameInfo.GlobalParameters["CITY_TRADE_INCOME_RESOURCE_BONUS"].Value),
		["RESOURCECLASS_MATERIEL"]	= tonumber(GameInfo.GlobalParameters["CITY_TRADE_INCOME_RESOURCE_MATERIEL"].Value),
		["RESOURCECLASS_EQUIPMENT"]	= tonumber(GameInfo.GlobalParameters["CITY_TRADE_INCOME_RESOURCE_EQUIPMENT"].Value)
}
local equipmentCostRatio = tonumber(GameInfo.GlobalParameters["CITY_TRADE_INCOME_EQUIPMENT_RATIO"].Value)

local IsEquipment		= {}		-- cached table to check if ResourceID is an Equipment
local IsFood			= {}
local IsEquipmentMaker 	= {}
local IsLuxury		 	= {}
for resourceRow in GameInfo.Resources() do

	if resourceRow.ResourceClassType == "RESOURCECLASS_LUXURY" then
		IsLuxury[resourceRow.Index] = true
	end
	
	local resourceType	= resourceRow.ResourceType
	if GameInfo.Equipment[resourceType] then
		IsEquipment[resourceRow.Index] = true
	end
	
	for productionRow in GameInfo.BuildingResourcesConverted() do
		if resourceType == productionRow.ResourceType then
			if productionRow.ResourceCreated == "RESOURCE_FOOD" then
				IsFood[resourceRow.Index] = true
			end
			if GameInfo.Equipment[productionRow.ResourceCreated] then
				IsEquipmentMaker[resourceRow.Index] = true
			end
		end
	end
end


local ResourceTempIcons = {		-- Table to store temporary icons for resources until new FontIcons could be added...
		[GameInfo.Resources["RESOURCE_MATERIEL"].Index] 			= "[ICON_RESOURCE_MATERIEL]",
		--[GameInfo.Resources["RESOURCE_STEEL"].Index] 				= "[ICON_New]",
		[GameInfo.Resources["RESOURCE_MEDICINE"].Index] 			= "[ICON_Damaged]",
		[GameInfo.Resources["RESOURCE_FOOD"].Index] 				= "[ICON_Food]",
		[GameInfo.Resources["RESOURCE_PERSONNEL"].Index]			= "[ICON_Position]",
		[GameInfo.Resources["EQUIPMENT_CHARIOT"].Index]				= "[ICON_EQUIPMENT_CHARIOT]",
		[GameInfo.Resources["EQUIPMENT_WAR_HORSES"].Index]			= "[ICON_EQUIPMENT_WAR_HORSES]",
		[GameInfo.Resources["EQUIPMENT_ARMORED_HORSES"].Index]		= "[ICON_EQUIPMENT_ARMORED_HORSES]",
		[GameInfo.Resources["EQUIPMENT_LANCES"].Index]				= "[ICON_EQUIPMENT_LANCES]",
		[GameInfo.Resources["EQUIPMENT_WOODEN_BOWS"].Index]			= "[ICON_EQUIPMENT_BOWS]",
		[GameInfo.Resources["EQUIPMENT_LONGBOWS"].Index]			= "[ICON_EQUIPMENT_BOWS]",
		[GameInfo.Resources["EQUIPMENT_CROSSBOWS"].Index]			= "[ICON_EQUIPMENT_CROSSBOWS]",
		[GameInfo.Resources["EQUIPMENT_WOODEN_CLUB"].Index]			= "[ICON_EQUIPMENT_CLUB]",
		[GameInfo.Resources["EQUIPMENT_STONE_AXES"].Index]			= "[ICON_EQUIPMENT_CLUB]",
		[GameInfo.Resources["EQUIPMENT_SPIKED_CLUB"].Index]			= "[ICON_EQUIPMENT_CLUB]",
		[GameInfo.Resources["EQUIPMENT_WOODEN_SPEARS"].Index]		= "[ICON_EQUIPMENT_SPEARS]",
		[GameInfo.Resources["EQUIPMENT_BRONZE_SPEARS"].Index]		= "[ICON_EQUIPMENT_SPEARS]",
		[GameInfo.Resources["EQUIPMENT_IRON_SPEARS"].Index]			= "[ICON_EQUIPMENT_SPEARS]",
		[GameInfo.Resources["EQUIPMENT_BRONZE_SWORDS"].Index]		= "[ICON_EQUIPMENT_SWORDS]",
		[GameInfo.Resources["EQUIPMENT_IRON_SWORDS"].Index]			= "[ICON_EQUIPMENT_SWORDS]",
		[GameInfo.Resources["EQUIPMENT_STEEL_SWORDS"].Index]		= "[ICON_EQUIPMENT_SWORDS]",
		[GameInfo.Resources["EQUIPMENT_IRON_PIKES"].Index]			= "[ICON_EQUIPMENT_PIKES]",
		[GameInfo.Resources["EQUIPMENT_STEEL_PIKES"].Index]			= "[ICON_EQUIPMENT_PIKES]",
		
		[GameInfo.Resources["EQUIPMENT_SLINGS"].Index]				= "[ICON_EQUIPMENT_SLINGS]",
		[GameInfo.Resources["EQUIPMENT_MUSKETS"].Index]				= "[ICON_EQUIPMENT_MUSKETS]",
		[GameInfo.Resources["EQUIPMENT_RIFLES"].Index]				= "[ICON_EQUIPMENT_MUSKETS]",
		[GameInfo.Resources["EQUIPMENT_ASSAULT_RIFLES"].Index]		= "[ICON_EQUIPMENT_ASSAULT_RIFLES]",
		[GameInfo.Resources["EQUIPMENT_AUTOMATIC_RIFLES"].Index]	= "[ICON_EQUIPMENT_MUSKETS]",
		[GameInfo.Resources["EQUIPMENT_CATAPULTS"].Index]			= "[ICON_EQUIPMENT_CATAPULTS]",
		[GameInfo.Resources["EQUIPMENT_TREBUCHETS"].Index]			= "[ICON_EQUIPMENT_CATAPULTS]",
		[GameInfo.Resources["EQUIPMENT_BOMBARDS"].Index]			= "[ICON_EQUIPMENT_BOMBARDS]",
		[GameInfo.Resources["EQUIPMENT_CANNONS"].Index]				= "[ICON_EQUIPMENT_CANNONS]",
		[GameInfo.Resources["EQUIPMENT_HOWITZER"].Index]			= "[ICON_EQUIPMENT_HOWITZER]",
		[GameInfo.Resources["EQUIPMENT_TANKS"].Index]				= "[ICON_EQUIPMENT_TANKS]",		
		
		[GameInfo.Resources["EQUIPMENT_LEATHER_ARMOR"].Index]		= "[ICON_EQUIPMENT_LEATHER_ARMOR]",
		[GameInfo.Resources["EQUIPMENT_LINOTHORAX"].Index]			= "[ICON_EQUIPMENT_LINOTHORAX]",
		[GameInfo.Resources["EQUIPMENT_GAMBESON"].Index]			= "[ICON_EQUIPMENT_GAMBESON]",
		[GameInfo.Resources["EQUIPMENT_BRONZE_ARMOR"].Index]		= "[ICON_EQUIPMENT_BRONZE_ARMOR]",
		[GameInfo.Resources["EQUIPMENT_IRON_ARMOR"].Index]			= "[ICON_EQUIPMENT_IRON_ARMOR]",
		[GameInfo.Resources["EQUIPMENT_CHAINMAIL_ARMOR"].Index]		= "[ICON_EQUIPMENT_CHAINMAIL_ARMOR]",
		[GameInfo.Resources["EQUIPMENT_PLATE_ARMOR"].Index]			= "[ICON_EQUIPMENT_PLATE_ARMOR]",		
	}

-- Floating Texts LOD
local FLOATING_TEXT_NONE 	= 0
local FLOATING_TEXT_SHORT 	= 1
local FLOATING_TEXT_LONG 	= 2
local floatingTextLevel 	= FLOATING_TEXT_SHORT

--=====================================================================================--
-- Initialize Functions
--=====================================================================================--
local g_Timer = Automation.GetTime()
function IsInitializedGCO() -- we can't use something like GameEvents.ExposedFunctionsInitialized.TestAll() because it will be called before all required test are added to the event...
	local bIsInitialized = 	(	ExposedMembers.SaveLoad_Initialized 
							and ExposedMembers.Utils_Initialized
							and	ExposedMembers.Serialize_Initialized
							and ExposedMembers.ContextFunctions_Initialized
							and ExposedMembers.RouteConnections_Initialized
							and ExposedMembers.PlotIterator_Initialized
							and ExposedMembers.PlotScript_Initialized
							and ExposedMembers.CityScript_Initialized
							and ExposedMembers.UnitScript_Initialized
							and ExposedMembers.PlayerScript_Initialized
							and ExposedMembers.GameScript_Initialized
							)
	if not bIsInitialized and Automation.GetTime() > g_Timer + 20 then
		Error("GCO Initialization problem")
		print("Still not initialized...  timer = ",  Automation.GetTime())
		g_Timer = Automation.GetTime()
		print("ExposedMembers.SaveLoad_Initialized---------",ExposedMembers.SaveLoad_Initialized           )
		print("ExposedMembers.Utils_Initialized------------",ExposedMembers.Utils_Initialized              )
		print("ExposedMembers.Serialize_Initialized--------",ExposedMembers.Serialize_Initialized          )
		print("ExposedMembers.ContextFunctions_Initialized-",ExposedMembers.ContextFunctions_Initialized   )
		print("ExposedMembers.RouteConnections_Initialized-",ExposedMembers.RouteConnections_Initialized   )
		print("ExposedMembers.PlotIterator_Initialized-----",ExposedMembers.PlotIterator_Initialized       )
		print("ExposedMembers.PlotScript_Initialized-------",ExposedMembers.PlotScript_Initialized         )
		print("ExposedMembers.CityScript_Initialized-------",ExposedMembers.CityScript_Initialized         )
		print("ExposedMembers.UnitScript_Initialized-------",ExposedMembers.UnitScript_Initialized         )
		print("ExposedMembers.PlayerScript_Initialized-----",ExposedMembers.PlayerScript_Initialized       )
		print("ExposedMembers.GameScript_Initialized-------",ExposedMembers.GameScript_Initialized       )
	end
	if bIsInitialized then ExposedMembers.GCO_Initialized = true end -- to check initialization from other contexts
	return bIsInitialized
end

local GCO = {}
function InitializeUtilityFunctions() 	-- Get functions from other contexts
	if IsInitializedGCO() then 	
		print ("All GCO script files loaded...")
		print ("Game loading time for all scripts = "..tostring(Automation.GetTime() - LoadTimer))
		GCO = ExposedMembers.GCO					-- contains functions from other contexts
		print ("Exposed Functions from other contexts initialized...")
		Events.GameCoreEventPublishComplete.Remove( InitializeUtilityFunctions )
		-- tell all other scripts that they can initialize now
		LuaEvents.InitializeGCO() 
	end
end
Events.GameCoreEventPublishComplete.Add( InitializeUtilityFunctions )

function OnLoadGameViewStateDone()
	print ("Game loading time (not counting map creation) = "..tostring(Automation.GetTime() - LoadTimer))
end
Events.LoadGameViewStateDone.Add( OnLoadGameViewStateDone )


--=====================================================================================--
-- http://lua-users.org/wiki/SortedIteration
-- Ordered table iterator, allow to iterate on the natural order of the keys of a table.
--=====================================================================================--
function __genOrderedIndex( t )
    local orderedIndex = {}
    for key in pairs (t) do
        table.insert ( orderedIndex, key )
    end
    table.sort ( orderedIndex )
    return orderedIndex
end

function orderedNext(t, state)
    -- Equivalent of the next function, but returns the keys in the alphabetic
    -- order.  We use a temporary ordered key table that is stored in the
    -- table being iterated.

    local key = nil
    --print("orderedNext: state = "..tostring(state) )
    if state == nil then
        -- the first time, generate the index
        t.__orderedIndex = __genOrderedIndex( t )
        key = t.__orderedIndex[1]
    else
        -- fetch the next value
        for i = 1, #t.__orderedIndex do
            if t.__orderedIndex[i] == state then
                key = t.__orderedIndex[i+1]
            end
        end
    end

    if key and type(key) ~= "table" then
        return key, t[key]
    end

	if key and type(key) == "table" then
		print("WARNING: key = table in orderedPairs")
		for k, v in pairs(key) do print(k,v) end
	end
	
    -- no more value to return, cleanup
    t.__orderedIndex = nil
    return
end

function orderedPairs(t)
    -- Equivalent of the pairs() function on tables.  Allows to iterate
    -- in order
    return orderedNext, t, nil
end


--=====================================================================================--
-- Maths/Tables
--=====================================================================================--
function Round(num)
    under = math.floor(num)
    upper = math.floor(num) + 1
    underV = -(under - num)
    upperV = upper - num
    if (upperV > underV) then
        return under
    else
        return upper
    end
end

function Shuffle(t)
  local n = #t
 
  while n >= 2 do
    -- n is now the last pertinent index
    local k = TerrainBuilder.GetRandomNumber(n, "shuffle table")+1 --math.random(n) -- 1 <= k <= n
    -- Quick swap
    t[n], t[k] = t[k], t[n]
    n = n - 1
  end
 
  return t
end

function GetSize(t)

	if type(t) ~= "table" then
		return 1 
	end

	local n = #t 
	if n == 0 then
		for k, v in pairs(t) do
			n = n + 1
		end
	end 
	return n
end

function ToDecimals(num)
	num = Round(num*100)/100
	string.format("%5.2f", num)
	return num
end

function TableSummation(data) -- return the Summation of all values in a table formatted like { key = value }
	if not data then return 0 end
	local total = 0
	for _, number in pairs(data) do
		total = total + number
	end	
	return total
end

function IsEmpty(testTable)
	return (next(testTable) == nil)
end

--=====================================================================================--
-- Debug
--=====================================================================================--
local lastLog			= {}
local bNoOutput 		= false
local bErrorToScreen 	= true

local debugFilter = {
	["debug"] 		= true,
	["CityScript"] 	= true,
--	["UnitScript"] 	= true,
}

function ToggleOutput()
	bNoOutput = not bNoOutput
	print("Spam control = " .. tostring(bNoOutput))
end

local debugPrint = {}
local bLogToTunerConsole 	= false
local bLogToDebugTable	 	= not bLogToTunerConsole
function SetDebugToConsole(bValue)
	bLogToTunerConsole = bValue
end
function Dprint(...)
    local args = {...}
	if args.n == 1 then print(args[1]) end 							-- if called with one argument only, print it
	if args.n == 0 or bNoOutput or args[1] == false then return end	-- don't print if the first argument is false (= debug off)
	if not debugFilter[args[1]] then return end						-- filtering...
	if bLogToTunerConsole then print(select(2,...)) end 			-- print everything else after the first argument
	if bLogToDebugTable then table.insert(debugPrint, {...}) end	-- log into debug table, output on error only
end

local lastLine = 1
function ShowDebugPrint(numEntriesToDisplay)
	if not numEntriesToDisplay then numEntriesToDisplay = 99000 end
	local numEntries	= #debugPrint
	local startPos		= math.max(1, lastLine, numEntries - numEntriesToDisplay)
	local endPos		= numEntries --math.min(numEntries, numEntriesToDisplay)
	print("=========================================================================================================================================")
	print("<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<< DEBUG <<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<<")
	print("=========================================================================================================================================")
	print("Showing " .. tostring(endPos-startPos) .. " lines / "..tostring(numEntries))
	print("startPos = " .. tostring(startPos))
	print("=========================================================================================================================================")
	if numEntries > 0 then
		for i = startPos, endPos do
			print(unpack(debugPrint[i]))
		end
	end
	lastLine = endPos
	print("=========================================================================================================================================")
	print(">>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>> DEBUG >>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>")
	print("=========================================================================================================================================")
	--debugPrint = {}
end

function CleanDebugPrint()
	local maxEntries 	= 100000
	local numEntries	= #debugPrint
	if numEntries > maxEntries then
		local toRemove = numEntries - maxEntries
		print("removing " .. tostring(toRemove) .. " lines from DebugPrint table at size " .. #debugPrint )
		for i = 1, toRemove do
			debugPrint[i] = nil
		end
		lastLine = 1
	end
end
GameEvents.OnGameTurnStarted.Add(CleanDebugPrint)

function Error(...)
	print("ERROR : ", select(1,...))
	local status, err = pcall(function () error("custom error") end)
	local str = string.match(err, '\'Error.-$')
	print(str)
	LuaEvents.StopAuToPlay()
	ExposedMembers.UI.PlaySound("Alert_Negative")
	if bErrorToScreen then LuaEvents.GCO_Message("[COLOR:Red]ERROR detected :[ENDCOLOR] ".. table.concat({ ... }, " "), 60) end
	ShowDebugPrint()
end

function ErrorWithLog(...)
	print("ERROR : ", select(1,...))
	local status, err = pcall(function () error("custom error") end)
	local str = string.match(err, '\'Error.-$')
	print(str)
	LuaEvents.StopAuToPlay()
	LuaEvents.ShowLastLog()
	ExposedMembers.UI.PlaySound("Alert_Negative")
	if bErrorToScreen then LuaEvents.GCO_Message("[COLOR:Red]ERROR detected :[ENDCOLOR] ".. table.concat({ ... }, " "), 60) end
	ShowDebugPrint()
end

function Warning(str, seconds)
	local seconds = seconds or 7
	local status, err = pcall(function () error("custom error") end)
	local line = string.match(err, 'Warning.-$')
	local line = string.match(line, 'GCO_.-$')
	local line = string.match(line, ':.-\'')
	local line = string.match(line, '%d+')
	print("WARNING : ".. str .. " at line "..line )	
	ExposedMembers.UI.PlaySound("Alert_Neutral")
	--if bErrorToScreen then LuaEvents.GCO_Message("[COLOR:Red]WARNING :[ENDCOLOR] ".. str, seconds) end
	--ShowDebugPrint()
end

function Dline(...)
	local status, err = pcall(function () error("custom error") end)
	local str = string.match(err, 'Dline.-$')
	local str = string.match(str, 'GCO_.-$')
	local str = string.match(str, ':.-\'')
	local str = string.match(str, '%d+')
	Dprint("debug", "at line "..str, select(1,...))	
	print("at line "..str, select(1,...))
end

function DlineFull(...)
	local status, err = pcall(function () error("custom error") end)
	local str = string.match(err, 'DlineFull.-$')
	Dprint(str)
end

function DfullLog()
	local status, err = pcall(function () error("logged call") end)
	local str = string.match(err, '\'Dlog.-$')
	--local str = string.match(str, '^.-%[')
	--local str = string.match(str, '^.*%[')
	--local str = string.match(str, '^.*\'')
	local str = string.gsub(str, '\'Dlog\'', '')
	--local str = string.match(str, ':.-\'')
	--local str = string.match(str, '%d+')
	--print(lastLog, str)
	table.insert(lastLog, str)
end

function Dlog(...)
	table.insert(lastLog, select(1,...))
end

function ShowLastLog(n)
	if not n then n = 100 end
	print("Check logged call...")
	if #lastLog > 0 then
		print("last 10 logged call...")
		for i = #lastLog, 1, -1 do
			print(GCO.Separator)
			print("Log entry #", i)
			print(lastLog[i])
			print(GCO.Separator)
			if i < #lastLog - n then return end
		end
	end
	lastLog = {}
end
LuaEvents.ShowLastLog.Add( ShowLastLog )

function Monitor(f, arguments, name) -- doesn't work as intended, fail on pcall when used like this GCO.Monitor(self.SetCityRationing, {self}, "SetCityRationing for ".. name)
	StartTimer(name)
	print(f, name)
	local status, err = pcall(f(unpack(arguments)))	
	print(status, err)
	if not status then
		Error(err)
	end
	ShowTimer(name)
end

-- Compare tables
local function internalProtectedEquals(o1, o2, ignore_mt, callList)
    if o1 == o2 then return true end
    local o1Type = type(o1)
    local o2Type = type(o2)
    if o1Type ~= o2Type then return false end
    if o1Type ~= 'table' then return false end

    -- add only when objects are tables, cache results
    local oComparisons = callList[o1]
    if not oComparisons then
        oComparisons = {}
        callList[o1] = oComparisons
    end
    -- false means that comparison is in progress
    oComparisons[o2] = false

    if not ignore_mt then
        local mt1 = getmetatable(o1)
        if mt1 and mt1.__eq then
            --compare using built in method
            return o1 == o2
        end
    end

    local keySet = {}
    for key1, value1 in pairs(o1) do
        local value2 = o2[key1]
        if value2 == nil then return false end

        local vComparisons = callList[value1]
        if not vComparisons or vComparisons[value2] == nil then
            if not internalProtectedEquals(value1, value2, ignore_mt, callList) then
                return false
            end
        end

        keySet[key1] = true
    end

    for key2, _ in pairs(o2) do
        if not keySet[key2] then
            return false
        end
    end

    -- comparison finished - objects are equal do not compare again
    oComparisons[o2] = true
    return true
end

function AreSameTables(o1, o2, ignore_mt)
    return internalProtectedEquals(o1, o2, ignore_mt, {})
end

local seen = {}
function Dump(t,i)
	if not i then i = "" end
	seen[t]=true
	local s={}
	local n=0
	for k, v in pairs(t) do
		print(i,k,v)
		if type(v)=="table" and not seen[v] then
			print(i.."num entries = "..#v)
			Dump(v,i.."\t\t")
		end
		if type(k)=="table" and not seen[k] then
			print(i.."num entries = "..#k)
			Dump(k,i.."\t\t")
		end
	end
end

-- Check if we can call flag update (ie we are outside OnGameTurnStarted() tick)
local bSafeToCallFlagUpdate = true
function CanCallFlagUpdate()
	return bSafeToCallFlagUpdate
end
function MarkFlagUpdateUnsafe()
	bSafeToCallFlagUpdate = false
end
GameEvents.OnGameTurnStarted.Add(MarkFlagUpdateUnsafe)
function MarkFlagUpdateSafe()
	bSafeToCallFlagUpdate = true
end
LuaEvents.StartPlayerTurn.Add(MarkFlagUpdateSafe)

--=====================================================================================--
-- Timer
--=====================================================================================--
local Timer = {}
function StartTimer(name)
	Timer[name] = { Start = Automation.GetTime() }
end
function StopTimer(name)
	if Timer[name] then Timer[name].Stop = Automation.GetTime() end
end
function ShowTimer(name) -- bShowInGame, seconds are optionnal
	if bNoOutput then -- spam control
		return
	end
	local diff = 0
	if Timer[name] and Timer[name].Start and Timer[name].Stop then
		diff = Timer[name].Stop-Timer[name].Start
	elseif Timer[name] and Timer[name].Start then
		diff = Automation.GetTime()-Timer[name].Start
	end	
	local str = tostring(name) .." timer = " .. tostring(diff) .. " seconds"
	Dprint(str)
	if diff > 0.5 then
		if diff < 2 then
			GCO.Warning(str, 2)
		elseif diff < 5 then
			GCO.Warning(str, 4)
		else
			GCO.Warning(str,8)		
		end
	end
	return str
end


--=====================================================================================--
-- Civilizations
--=====================================================================================--
function CreateEverAliveTableWithDefaultValue(value)
	local t = {}
	for i, playerID in ipairs(PlayerManager.GetWasEverAliveIDs()) do
		t[tostring(playerID)] = value -- key must be string for correct serialization
	end
	return t
end

function CreateEverAliveTableWithEmptyTable()
	local t = {}
	for i, playerID in ipairs(PlayerManager.GetWasEverAliveIDs()) do
		t[tostring(playerID)] = {} -- key must be string for correct serialization
	end
	return t
end


--=====================================================================================--
-- Map
--=====================================================================================--
function FindNearestPlayerCity( eTargetPlayer, iX, iY )

	local pCity = nil
    local iShortestDistance = 10000
	local pPlayer = Players[eTargetPlayer]
	if pPlayer then
		local pPlayerCities:table = pPlayer:GetCities()
		for i, pLoopCity in pPlayerCities:Members() do
			local iDistance = Map.GetPlotDistance(iX, iY, pLoopCity:GetX(), pLoopCity:GetY())
			if (iDistance < iShortestDistance) then
				pCity = pLoopCity
				iShortestDistance = iDistance
			end
		end
	else
		print ("WARNING : Player is nil in FindNearestPlayerCity for ID = ".. tostring(eTargetPlayer) .. "at" .. tostring(iX) ..","..tostring(iY))
	end

	if (not pCity) then
		--print ("No city found of player " .. tostring(eTargetPlayer) .. " in range of " .. tostring(iX) .. ", " .. tostring(iY));
	end
   
    return pCity, iShortestDistance;
end

function GetRouteEfficiency(length)
	return GCO.Round( 100 - math.pow(length,2) )
end

function TradePathBlocked(pPlot, pPlayer) -- check for trade path (doesn't require open border, but blocked by enemy units/territory)

	local ownerID = pPlot:GetOwner()
	local playerID = pPlayer:GetID()
	
	if pPlayer:GetDiplomacy():IsAtWarWith( ownerID ) then return true end -- path blocked

	local aUnits = Units.GetUnitsInPlot(pPlot);
	for i, pUnit in ipairs(aUnits) do
		if pPlayer:GetDiplomacy():IsAtWarWith( pUnit:GetOwner() ) then return true end -- path blocked
	end

	return false
end

function SupplyPathBlocked(pPlot, pPlayer) -- check for supply path (requires open border and blocked by enemy units/territory)

	local ownerID = pPlot:GetOwner()
	local playerID = pPlayer:GetID()	

	-- check for enemy units first
	local aUnits = Units.GetUnitsInPlot(pPlot);
	for i, pUnit in ipairs(aUnits) do
		if pPlayer:GetDiplomacy():IsAtWarWith( pUnit:GetOwner() ) then return true end -- path blocked
	end
	
	-- then own territory is open
	if ( ownerID == playerID or ownerID == -1 ) then
		return false
	end

	-- then open border in foreign territory
	if GCO.HasPlayerOpenBordersFrom(pPlayer, ownerID) then
		return false
	end	

	return true -- return true if the path is blocked...
end

--=====================================================================================--
-- Cities
--=====================================================================================--
-- City Capture Events
local cityCaptureTest = {}
function CityCaptureDistrictRemoved(playerID, districtID, cityID, iX, iY)
Dprint("Calling CityCaptureDistrictRemoved (", playerID, districtID, cityID, iX, iY,")")
	local key = iX..","..iY
	cityCaptureTest[key]			= {}
	cityCaptureTest[key].Turn 		= Game.GetCurrentGameTurn()
	cityCaptureTest[key].PlayerID 	= playerID
	cityCaptureTest[key].CityID 	= cityID
end
Events.DistrictRemovedFromMap.Add(CityCaptureDistrictRemoved)
function CityCaptureCityAddedToMap(playerID, cityID, iX, iY)
Dprint("Calling CityCaptureCityAddedToMap (", playerID, cityID, iX, iY,")")
	local key = iX..","..iY
	if (	cityCaptureTest[key]
		and cityCaptureTest[key].Turn 	== Game.GetCurrentGameTurn()
		and not	cityCaptureTest[key].CityAddedXY	)
	then
		cityCaptureTest[key].CityAddedXY = true
		local city = CityManager.GetCity(playerID, cityID)
		if city then
			local originalOwnerID 	= city:GetOriginalOwner()
			local originalCityID	= cityCaptureTest[key].CityID
			local newOwnerID 		= playerID
			local newCityID			= cityID
			if cityCaptureTest[key].PlayerID == originalOwnerID then
				Dprint("Calling LuaEvents.CapturedCityAddedToMap (", originalOwnerID, originalCityID, newOwnerID, newCityID, iX, iY,")")
				LuaEvents.CapturedCityAddedToMap(originalOwnerID, originalCityID, newOwnerID, newCityID, iX, iY)
			end
		else
			GCO.Warning("City is nil in CityCaptureCityAddedToMap for cityID, playerID "..tostring(cityID)..","..tostring(playerID))
		end
	end
end
Events.CityAddedToMap.Add(CityCaptureCityAddedToMap)
function CityCaptureCityInitialized(playerID, cityID, iX, iY)
Dprint("Calling CityCaptureCityInitialized (", playerID, cityID, iX, iY,")")
	local key = iX..","..iY
	if (	cityCaptureTest[key]
		and cityCaptureTest[key].Turn 	== Game.GetCurrentGameTurn() )
	then
		cityCaptureTest[key].CityInitializedXY = true
		local city = CityManager.GetCity(playerID, cityID)
		if city then
			local originalOwnerID 	= city:GetOriginalOwner()
			local originalCityID	= cityCaptureTest[key].CityID
			local newOwnerID 		= playerID
			local newCityID			= cityID
			if cityCaptureTest[key].PlayerID == originalOwnerID then
				Dprint("Calling LuaEvents.CapturedCityInitialized (", originalOwnerID, originalCityID, newOwnerID, newCityID, iX, iY,")")
				LuaEvents.CapturedCityInitialized(originalOwnerID, originalCityID, newOwnerID, newCityID, iX, iY)
				cityCaptureTest[key] = {}
			end
		else
			GCO.Warning("City is nil in CityCaptureCityInitialized for cityID, playerID "..tostring(cityID)..","..tostring(playerID))			
		end
	end
end
Events.CityInitialized.Add(CityCaptureCityInitialized)


--=====================================================================================--
-- Common
--=====================================================================================--
function GetTotalPrisoners(data) -- works for cityData and unitData
	return TableSummation(data.Prisoners)
end

function GetTurnKey()
	return tostring(Game.GetCurrentGameTurn())
end

function GetPreviousTurnKey()
	return tostring(math.max(0, Game.GetCurrentGameTurn()-1))
end


--=====================================================================================--
-- Players
--=====================================================================================--
function GetPlayerUpperClassPercent( playerID )
	return tonumber(GameInfo.GlobalParameters["CITY_BASE_UPPER_CLASS_PERCENT"].Value)
end

function GetPlayerMiddleClassPercent( playerID )
	return tonumber(GameInfo.GlobalParameters["CITY_BASE_MIDDLE_CLASS_PERCENT"].Value)
end


--=====================================================================================--
-- Resources
--=====================================================================================--
function GetBaseResourceCost(resourceID)
	local resourceID = tonumber(resourceID)
	local resourceClassType = GameInfo.Resources[resourceID].ResourceClassType
	local cost = ResourceValue[resourceClassType] or 0
	if IsResourceEquipment(resourceID) then
		local resourceTypeName = GameInfo.Resources[resourceID].ResourceType
		local equipmentSize = GameInfo.Equipment[resourceTypeName].Size
		cost = cost * equipmentCostRatio * equipmentSize		
	end
	return cost
end

function IsResourceEquipment(resourceID)
	return (IsEquipment[resourceID] == true)
end

function IsResourceFood(resourceID)
	return (IsFood[resourceID] == true)
end

function IsResourceLuxury(resourceID)
	return (IsLuxury[resourceID] == true)
end

function IsResourceEquipmentMaker(resourceID)
	return (IsEquipmentMaker[resourceID] == true)
end


function GetResourceIcon(resourceID)
	if not resourceID then return "[ICON_EQUIPMENT_CRATES]" end -- allow call with no argument to return default icon
	local iconStr = ""
	if ResourceTempIcons[resourceID] then
		iconStr = ResourceTempIcons[resourceID]
	elseif IsEquipment[resourceID] then
		iconStr = "[ICON_Production]"
	else
		local resRow = GameInfo.Resources[resourceID]
		iconStr = "[ICON_"..tostring(resRow.ResourceType) .. "]"
	end		
	return iconStr
end

--=====================================================================================--
-- Units
--=====================================================================================--

function KillUnit(unitID,playerID)
	local unit = UnitManager.GetUnit(playerID, unitID)
	UnitManager.Kill(unit)
end

--=====================================================================================--
-- Texts function
--=====================================================================================--

function GetPrisonersStringByCiv(data) -- works for unitData and cityData
	local sortedPrisoners = {}
	for playerID, number in pairs(data.Prisoners) do
		table.insert(sortedPrisoners, {playerID = tonumber(playerID), Number = number})
	end	
	table.sort(sortedPrisoners, function(a,b) return a.Number>b.Number end)
	local numLines = tonumber(GameInfo.GlobalParameters["UI_MAX_PRISONERS_LINE_IN_TOOLTIP"].Value)
	local str = ""
	local other = 0
	local iter = 1
	for i, t in ipairs(sortedPrisoners) do
		if (iter <= numLines) or (#sortedPrisoners == numLines + 1) then
			local playerConfig = PlayerConfigurations[t.playerID]
			local civAdjective = Locale.Lookup(GameInfo.Civilizations[playerConfig:GetCivilizationTypeID()].Adjective)
			if t.Number > 0 then str = str .. "[NEWLINE]" .. Locale.Lookup("LOC_UNITFLAG_PRISONERS_NATIONALITY", t.Number, civAdjective) end
		else
			other = other + t.Number
		end
		iter = iter + 1
	end
	if other > 0 then str = str .. "[NEWLINE]" .. Locale.Lookup("LOC_UNITFLAG_PRISONERS_OTHER_NATIONALITY", other) end
	return str
end

function GetVariationString(variation)
	if variation > 0 then
		return " [ICON_PressureUp][COLOR_Civ6Green]+".. tostring(variation).."[ENDCOLOR]"
	elseif variation < 0 then
		return " [ICON_PressureDown][COLOR_Civ6Red]".. tostring(variation).."[ENDCOLOR]"
	end
	return ""
end

function GetNeutralVariationString(variation)
	if variation > 0 then
		return " [ICON_TradeRouteLarge][COLOR_Blue]+".. tostring(variation).."[ENDCOLOR]"
	elseif variation < 0 then
		return " [ICON_TradeRouteLarge][COLOR_Blue]".. tostring(variation).."[ENDCOLOR]"
	end
	return ""
end

function GetVariationStringGreenPositive(variation)
	if variation > 0 then
		return " [COLOR_Civ6Green]+".. tostring(variation).."[ENDCOLOR]"
	elseif variation < 0 then
		return " [COLOR_Civ6Red]".. tostring(variation).."[ENDCOLOR]"
	end
	return ""
end

function GetVariationStringRedPositive(variation)
	if variation > 0 then
		return " [COLOR_Civ6Red]+".. tostring(variation).."[ENDCOLOR]"
	elseif variation < 0 then
		return " [COLOR_Civ6Green]".. tostring(variation).."[ENDCOLOR]"
	end
	return ""
end

--=====================================================================================--
-- Share functions for other contexts
--=====================================================================================--

function Initialize()
	if not ExposedMembers.GCO then ExposedMembers.GCO = {} end
	-- utils
	ExposedMembers.GCO.OrderedPairs 	= orderedPairs
	-- maths
	ExposedMembers.GCO.Round 			= Round
	ExposedMembers.GCO.Shuffle 			= Shuffle
	ExposedMembers.GCO.GetSize 			= GetSize
	ExposedMembers.GCO.ToDecimals 		= ToDecimals
	ExposedMembers.GCO.TableSummation 	= TableSummation
	ExposedMembers.GCO.IsEmpty 			= IsEmpty
	-- timers
	ExposedMembers.GCO.StartTimer 		= StartTimer
	ExposedMembers.GCO.ShowTimer 		= ShowTimer
	ExposedMembers.GCO.StopTimer 		= StopTimer
	-- debug
	ExposedMembers.GCO.ToggleOutput 		= ToggleOutput
	ExposedMembers.GCO.SetDebugToConsole 	= SetDebugToConsole
	ExposedMembers.GCO.Dprint				= Dprint
	ExposedMembers.GCO.AreSameTables		= AreSameTables
	ExposedMembers.GCO.Dump					= Dump
	ExposedMembers.GCO.Error				= Error
	ExposedMembers.GCO.ErrorWithLog 		= ErrorWithLog
	ExposedMembers.GCO.Warning				= Warning
	ExposedMembers.GCO.Dline 				= Dline
	ExposedMembers.GCO.DlineFull 			= DlineFull
	ExposedMembers.GCO.Dlog 				= Dlog
	ExposedMembers.GCO.DfullLog 			= DfullLog
	ExposedMembers.GCO.CanCallFlagUpdate	= CanCallFlagUpdate
	ExposedMembers.GCO.Monitor 				= Monitor
	-- "globals"
	ExposedMembers.GCO.Separator		= "---------------------------------------------------------------------------"
	-- civilizations
	ExposedMembers.GCO.CreateEverAliveTableWithDefaultValue = CreateEverAliveTableWithDefaultValue
	ExposedMembers.GCO.CreateEverAliveTableWithEmptyTable 	= CreateEverAliveTableWithEmptyTable
	-- common
	ExposedMembers.GCO.GetTotalPrisoners 			= GetTotalPrisoners
	ExposedMembers.GCO.GetTurnKey 					= GetTurnKey
	ExposedMembers.GCO.GetPreviousTurnKey			= GetPreviousTurnKey
	-- map
	ExposedMembers.GCO.FindNearestPlayerCity 		= FindNearestPlayerCity
	ExposedMembers.GCO.GetRouteEfficiency 			= GetRouteEfficiency
	ExposedMembers.GCO.SupplyPathBlocked 			= SupplyPathBlocked
	ExposedMembers.GCO.TradePathBlocked 			= TradePathBlocked
	-- player
	ExposedMembers.GCO.GetPlayerUpperClassPercent 	= GetPlayerUpperClassPercent
	ExposedMembers.GCO.GetPlayerMiddleClassPercent 	= GetPlayerMiddleClassPercent
	-- Resources
	ExposedMembers.GCO.GetBaseResourceCost 			= GetBaseResourceCost
	ExposedMembers.GCO.IsResourceEquipment			= IsResourceEquipment
	ExposedMembers.GCO.IsResourceFood 				= IsResourceFood
	ExposedMembers.GCO.IsResourceLuxury 			= IsResourceLuxury
	ExposedMembers.GCO.IsResourceEquipmentMaker		= IsResourceEquipmentMaker
	ExposedMembers.GCO.GetResourceIcon				= GetResourceIcon
	-- texts
	ExposedMembers.GCO.GetPrisonersStringByCiv 			= GetPrisonersStringByCiv
	ExposedMembers.GCO.GetVariationString 				= GetVariationString
	ExposedMembers.GCO.GetNeutralVariationString		= GetNeutralVariationString
	ExposedMembers.GCO.GetVariationStringGreenPositive 	= GetVariationStringGreenPositive
	ExposedMembers.GCO.GetVariationStringRedPositive	= GetVariationStringRedPositive
	-- initialization	
	ExposedMembers.Utils_Initialized 	= true
end
Initialize()


--=====================================================================================--
-- Cleaning on exit
--=====================================================================================--
function Cleaning()
	print ("Cleaning GCO stuff on LeaveGameComplete...")
	-- 
	ExposedMembers.SaveLoad_Initialized 		= nil
	ExposedMembers.ContextFunctions_Initialized	= nil
	ExposedMembers.Utils_Initialized 			= nil
	ExposedMembers.Serialize_Initialized 		= nil
	ExposedMembers.RouteConnections_Initialized	= nil	
	ExposedMembers.PlotIterator_Initialized		= nil
	ExposedMembers.PlotScript_Initialized 		= nil
	ExposedMembers.CityScript_Initialized 		= nil
	ExposedMembers.UnitScript_Initialized		= nil
	ExposedMembers.PlayerScript_Initialized 	= nil
	ExposedMembers.GCO_Initialized 				= nil 
	--
	ExposedMembers.UnitHitPointsTable 			= nil
	--
	ExposedMembers.UnitData 					= nil
	ExposedMembers.CityData 					= nil
	ExposedMembers.PlayerData 					= nil
	ExposedMembers.CultureMap 					= nil
	ExposedMembers.PreviousCultureMap 			= nil
	ExposedMembers.GCO 							= nil
	ExposedMembers.lastCombat					= nil
	--
	ExposedMembers.UI 							= nil
	ExposedMembers.Calendar 					= nil
	ExposedMembers.CombatTypes 					= nil
end
Events.LeaveGameComplete.Add(Cleaning)
LuaEvents.RestartGame.Add(Cleaning)


--=====================================================================================--
-- Testing...
--=====================================================================================--

local currentTurn = -1
local playerMadeTurn = {}
function GetPlayerTurn(playerID)
	if (currentTurn ~= Game.GetCurrentGameTurn()) then
		currentTurn = Game.GetCurrentGameTurn()
		playerMadeTurn = {}
	end
	if not playerMadeTurn[playerID] then		
		Dprint("----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------")
		Dprint("-- Events.GameCoreEventPublishComplete -> Testing Start Turn for player#"..tostring(playerID))
		Dprint("----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------")
		LuaEvents.StartPlayerTurn(playerID)
		playerMadeTurn[playerID] = true
	end
end
function OnUnitMovementPointsChanged(playerID)
	Dprint("----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------")
	Dprint("-- Test Start Turn On UnitMovementPointsChanged player#"..tostring(playerID))
	Dprint("----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------")
	GetPlayerTurn(playerID)
end
function OnAiAdvisorUpdated(playerID)
	Dprint("----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------")
	Dprint("-- Test Start Turn On AiAdvisorUpdated player#"..tostring(playerID))
	Dprint("----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------")
	GetPlayerTurn(playerID)
end
function FindActivePlayer()
	for _, playerID in ipairs(PlayerManager.GetWasEverAliveMajorIDs()) do
		local player = Players[playerID]
		if player:IsTurnActive() or playerID == 0 then -- start player 0 turn ASAP when automation is running (player:IsTurnActive() always return false for player 0 in that case)
			GetPlayerTurn(playerID)
		end
	end
end
--Events.GameCoreEventPublishComplete.Add( FindActivePlayer ) -- first to fire, but not early enough
--Events.UnitMovementPointsChanged.Add(OnUnitMovementPointsChanged)
--Events.OnAiAdvisorUpdated.Add(OnAiAdvisorUpdated)

function TestA()
	print ("Calling TestA...")
end
function TestB()
	print ("Calling TestB...")
end
function TestC()
	print ("Calling TestC...")
end
function TestD()
	print ("Calling TestD...")
end
function TestE()
	print ("Calling TestE...")
end
function TestF()
	print ("Calling TestF...")
end
--Events.AppInitComplete.Add(TestA)
--Events.GameViewStateDone.Add(TestB)
--Events.LoadGameViewStateDone.Add(TestC)
--Events.LoadScreenContentReady.Add(TestD)
--Events.MainMenuStateDone.Add(TestE)
--Events.LoadComplete.Add(TestA)
--Events.RequestSave.Add(TestB)
--Events.RequestLoad.Add(TestC)
--Events.EndGameView.Add(TestC)
--GameEvents.PlayerTurnStarted.Add(TestA)
--GameEvents.PlayerTurnStartComplete.Add(TestB)
--Events.LocalPlayerTurnBegin.Add( TestC )
--Events.RemotePlayerTurnBegin.Add( TestD )

--Events.CityProductionUpdated.Add(TestA)
--Events.CityProductionUpdated.Add(TestA)
--Events.CityProductionCompleted.Add(TestC)