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
ExposedMembers.ResearchScript_Initialized 	= nil
ExposedMembers.GCO_Initialized 				= nil

-- to access GameEvents from UI context
ExposedMembers.GameEvents					= GameEvents
--ExposedMembers.LuaEvents					= LuaEvents

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
		[GameInfo.Resources["RESOURCE_MATERIEL"].Index] 					= "[ICON_RESOURCE_MATERIEL]",
		--[GameInfo.Resources["RESOURCE_STEEL"].Index] 						= "[ICON_New]",
		[GameInfo.Resources["RESOURCE_MEDICINE"].Index] 					= "[ICON_Damaged]",
		[GameInfo.Resources["RESOURCE_FOOD"].Index] 						= "[ICON_Food]",
		[GameInfo.Resources["RESOURCE_PERSONNEL"].Index]					= "[ICON_Position]",
		[GameInfo.Resources["RESOURCE_WOOD_PLANKS"].Index]					= "[ICON_RESOURCE_WOOD_PLANKS]",
		
		[GameInfo.Resources["RESOURCE_WOODEN_HULL_PART"].Index]				= "[ICON_RESOURCE_WOODEN_HULL_PART]",
		[GameInfo.Resources["RESOURCE_STEEL_HULL_PART"].Index]				= "[ICON_EQUIPMENT_DESTROYER]",
		[GameInfo.Resources["RESOURCE_LARGE_STEEL_HULL"].Index]				= "[ICON_EQUIPMENT_AIRCRAFT_CARRIER]",
		
		[GameInfo.Resources["RESOURCE_ELECTRICAL_DEVICES"].Index]			= "[ICON_RESOURCE_ELECTRICAL_DEVICES]",
		[GameInfo.Resources["RESOURCE_ELECTRONIC_COMPONENTS"].Index]		= "[ICON_RESOURCE_ELECTRICAL_DEVICES]",
		[GameInfo.Resources["RESOURCE_ELECTRONIC_SYSTEM"].Index]			= "[ICON_RESOURCE_ELECTRICAL_DEVICES]",
		[GameInfo.Resources["RESOURCE_ADVANCED_ELECTRONIC_SYSTEM"].Index]	= "[ICON_RESOURCE_ELECTRICAL_DEVICES]",		
		
		[GameInfo.Resources["RESOURCE_WOODEN_FUSELAGE"].Index]				= "[ICON_EQUIPMENT_FIGHTER]",
		[GameInfo.Resources["RESOURCE_LARGE_WOODEN_FUSELAGE"].Index]		= "[ICON_EQUIPMENT_FIGHTER]",
		[GameInfo.Resources["RESOURCE_ALUMINUM_FUSELAGE"].Index]			= "[ICON_EQUIPMENT_FIGHTER]",
		[GameInfo.Resources["RESOURCE_LARGE_ALUMINUM_FUSELAGE"].Index]		= "[ICON_EQUIPMENT_FIGHTER]",
		[GameInfo.Resources["RESOURCE_PROPELLER_ENGINE"].Index]				= "[ICON_EQUIPMENT_FIGHTER]",
		[GameInfo.Resources["RESOURCE_JET_ENGINE"].Index]					= "[ICON_EQUIPMENT_FIGHTER]",
		[GameInfo.Resources["RESOURCE_AVIONIC"].Index]						= "[ICON_RESOURCE_AVIONIC]",
		[GameInfo.Resources["RESOURCE_ADVANCED_AVIONIC"].Index]				= "[ICON_RESOURCE_AVIONIC]",		
		
		[GameInfo.Resources["EQUIPMENT_CHARIOT"].Index]				= "[ICON_EQUIPMENT_CHARIOT]",
		[GameInfo.Resources["EQUIPMENT_HORSES"].Index]				= "[ICON_EQUIPMENT_WAR_HORSES]",
		[GameInfo.Resources["EQUIPMENT_WAR_HORSES"].Index]			= "[ICON_EQUIPMENT_WAR_HORSES]",
		--[GameInfo.Resources["EQUIPMENT_ARMORED_HORSES"].Index]		= "[ICON_EQUIPMENT_ARMORED_HORSES]",
		[GameInfo.Resources["EQUIPMENT_LANCES"].Index]				= "[ICON_EQUIPMENT_LANCES]",
		[GameInfo.Resources["EQUIPMENT_WOODEN_BOWS"].Index]			= "[ICON_EQUIPMENT_BOWS]",
		[GameInfo.Resources["EQUIPMENT_LONGBOWS"].Index]			= "[ICON_EQUIPMENT_BOWS]",
		[GameInfo.Resources["EQUIPMENT_CROSSBOWS"].Index]			= "[ICON_EQUIPMENT_CROSSBOWS]",
		[GameInfo.Resources["EQUIPMENT_WOODEN_CLUB"].Index]			= "[ICON_EQUIPMENT_CLUB]",
		[GameInfo.Resources["EQUIPMENT_STONE_AXES"].Index]			= "[ICON_EQUIPMENT_CLUB]",
		[GameInfo.Resources["EQUIPMENT_STONE_SPEARS"].Index]		= "[ICON_EQUIPMENT_SPEARS]",
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
		--[GameInfo.Resources["EQUIPMENT_UNIFORM"].Index]				= "[ICON_EQUIPMENT_UNIFORM]",
		
		[GameInfo.Resources["EQUIPMENT_GALLEY"].Index]				= "[ICON_EQUIPMENT_GALLEY]",
		[GameInfo.Resources["EQUIPMENT_QUADRIREME"].Index]			= "[ICON_EQUIPMENT_QUADRIREME]",
		[GameInfo.Resources["EQUIPMENT_CARAVEL"].Index]				= "[ICON_EQUIPMENT_CARAVEL]",
		[GameInfo.Resources["EQUIPMENT_PRIVATEER"].Index]			= "[ICON_EQUIPMENT_PRIVATEER]",
		[GameInfo.Resources["EQUIPMENT_FRIGATE"].Index]				= "[ICON_EQUIPMENT_FRIGATE]",
		[GameInfo.Resources["EQUIPMENT_IRONCLAD"].Index]			= "[ICON_EQUIPMENT_IRONCLAD]",
		[GameInfo.Resources["EQUIPMENT_DESTROYER"].Index]			= "[ICON_EQUIPMENT_DESTROYER]",
		[GameInfo.Resources["EQUIPMENT_SUBMARINE"].Index]			= "[ICON_EQUIPMENT_SUBMARINE]",
		[GameInfo.Resources["EQUIPMENT_NUCLEAR_SUBMARINE"].Index]	= "[ICON_EQUIPMENT_NUCLEAR_SUBMARINE]",
		[GameInfo.Resources["EQUIPMENT_BATTLESHIP"].Index]			= "[ICON_EQUIPMENT_BATTLESHIP]",
		[GameInfo.Resources["EQUIPMENT_AIRCRAFT_CARRIER"].Index]	= "[ICON_EQUIPMENT_AIRCRAFT_CARRIER]",
		[GameInfo.Resources["EQUIPMENT_MISSILE_CRUISER"].Index]		= "[ICON_EQUIPMENT_MISSILE_CRUISER]",
		
		[GameInfo.Resources["EQUIPMENT_BIPLANE"].Index]				= "[ICON_EQUIPMENT_FIGHTER]",
		[GameInfo.Resources["EQUIPMENT_FIGHTER"].Index]				= "[ICON_EQUIPMENT_FIGHTER]",
		[GameInfo.Resources["EQUIPMENT_JET_FIGHTER"].Index]			= "[ICON_EQUIPMENT_FIGHTER]",
		[GameInfo.Resources["EQUIPMENT_BOMBER"].Index]				= "[ICON_EQUIPMENT_FIGHTER]",
		[GameInfo.Resources["EQUIPMENT_JET_BOMBER"].Index]			= "[ICON_EQUIPMENT_FIGHTER]",
	}
	
-- Fill Technology resource icons
for row in GameInfo.Resources() do
	if row.ResourceClassType == "RESOURCECLASS_KNOWLEDGE" then
		ResourceTempIcons[row.Index]	= "[ICON_SCIENCE]"
	elseif row.ResourceClassType == "RESOURCECLASS_TABLETS" then
		ResourceTempIcons[row.Index]	= "[ICON_SCIENCE]"
	elseif row.ResourceClassType == "RESOURCECLASS_SCROLLS" then
		ResourceTempIcons[row.Index]	= "[ICON_SCIENCE]"
	elseif row.ResourceClassType == "RESOURCECLASS_BOOKS" then
		ResourceTempIcons[row.Index]	= "[ICON_SCIENCE]"
	elseif row.ResourceClassType == "RESOURCECLASS_DIGITAL" then
		ResourceTempIcons[row.Index]	= "[ICON_SCIENCE]"
	end
end

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
							and ExposedMembers.ResearchScript_Initialized
							)
	if not bIsInitialized and Automation.GetTime() > g_Timer + 120 then
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
local OptionGet
local OptionSet
function InitializeUtilityFunctions() 	-- Get functions from other contexts
	if IsInitializedGCO() then 	
		print ("All GCO script files loaded...")
		print ("Game loading time for all scripts = "..tostring(Automation.GetTime() - LoadTimer))
		GCO 		= ExposedMembers.GCO						-- contains functions from other contexts
		LuaEvents	= GCO.LuaEvents
		OptionGet	= ExposedMembers.GCO.Options.GetUserOption	-- or Options.GetAppOption
		OptionSet	= ExposedMembers.GCO.Options.SetUserOption	-- or Options.SetAppOption
		OptionSave	= ExposedMembers.GCO.Options.SaveOptions
		print ("Exposed Functions from other contexts initialized...")
		Events.GameCoreEventPublishComplete.Remove( InitializeUtilityFunctions )
		-- tell all other scripts that they can initialize now
		GameEvents.InitializeGCO.Call()
		PostInitialize()
	end
end
Events.GameCoreEventPublishComplete.Add( InitializeUtilityFunctions )

function PostInitialize() -- everything that may require other context to be loaded first
	LuaEvents.ShowLastLog.Add( ShowLastLog )
	LuaEvents.StartPlayerTurn.Add(MarkFlagUpdateSafe)
	LuaEvents.RestartGame.Add(Cleaning)
end

function OnLoadGameViewStateDone()
	print ("Game loading time (not counting map creation) = "..tostring(Automation.GetTime() - LoadTimer))
end
Events.LoadGameViewStateDone.Add( OnLoadGameViewStateDone )

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

function GetMaxPercentFromLowDiff(maxEffectValue, higherValue, lowerValue) 	-- Return a higher value if lowerValue is high
	return maxEffectValue*(lowerValue/higherValue)
end
function GetMaxPercentFromHighDiff(maxEffectValue, higherValue, lowerValue)	-- Return a higher value if lowerValue is low
	return maxEffectValue*(100-(lowerValue/higherValue*100))/100
end
function LimitEffect(maxEffectValue, effectValue)							-- Keep effectValue never equals to maxEffectValue
	return ToDecimals(maxEffectValue*effectValue/(maxEffectValue+1))
end


--=====================================================================================--
-- Bitwise Operators from http://lua-users.org/wiki/BitwiseOperators
--=====================================================================================--
function bit(p)
  return 2 ^ (p - 1)  -- 1-based indexing
end

-- Typical call:  if hasbit(x, bit(3)) then ...
function hasbit(x, p)
  return x % (p + p) >= p       
end

function setbit(x, p)
  return hasbit(x, p) and x or x + p
end

function clearbit(x, p)
  return hasbit(x, p) and x - p or x
end


--=====================================================================================--
-- Debug
--=====================================================================================--
local lastLog			= {}
local bNoOutput 		= false
local bErrorToScreen 	= true
local bWarningToScreen	= false

local debugFilter = {
	["debug"] 			= true,
--	["CityScript"] 		= true,
--	["PlayerScript"] 	= true,
--	["UnitScript"] 		= true,
--	["PlotScript"] 		= true,
	["ResearchScript"] 	= true,
}

function ToggleOutput()
	bNoOutput = not bNoOutput
	print("Spam control = " .. tostring(bNoOutput))
end

local debugPrint = {}
local bLogToTunerConsole 	= true
function SetDebugToConsole(bValue)
	bLogToTunerConsole = bValue
end
function Dprint(...)
    local args = {...}
	if args.n == 1 then print(args[1]) end 							-- if called with one argument only, print it
	if args.n == 0 or bNoOutput or args[1] == false then return end	-- don't print if the first argument is false (= debug off)
	if not debugFilter[args[1]] then return end						-- filtering...
	if bLogToTunerConsole then print(select(2,...)) end 			-- print everything else after the first argument
end


function Error(...)
	print("ERROR : ", select(1,...))
	local status, err = pcall(function () error("custom error") end)
	local str = string.match(err, '\'Error.-$')
	print(str)
	LuaEvents.StopAuToPlay()
	ExposedMembers.UI.PlaySound("Alert_Negative")
	if bErrorToScreen then GCO.StatusMessage("[COLOR:Red]ERROR detected :[ENDCOLOR] ".. table.concat({ ... }, " "), 20) end
end

function ErrorWithLog(...)
	print("ERROR : ", select(1,...))
	local status, err = pcall(function () error("custom error") end)
	local str = string.match(err, '\'Error.-$')
	print(str)
	LuaEvents.StopAuToPlay()
	LuaEvents.ShowLastLog()
	ExposedMembers.UI.PlaySound("Alert_Negative")
	if bErrorToScreen then GCO.StatusMessage("[COLOR:Red]ERROR detected :[ENDCOLOR] ".. table.concat({ ... }, " "), 60) end
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
	if bWarningToScreen then GCO.StatusMessage("[COLOR:Red]WARNING :[ENDCOLOR] ".. str, seconds) end
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
	if not n then n = 10 end
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
--LuaEvents.ShowLastLog.Add( ShowLastLog )

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
--LuaEvents.StartPlayerTurn.Add(MarkFlagUpdateSafe)


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
    if state == nil and t.__orderedIndex then
		Error("__orderedIndex already exists on orderedNext first call")
	end
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
		Error("key = table in orderedPairs")
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
-- Counter
--=====================================================================================--
local Counter	= {}
function Incremente(name)
	Counter[name] = (Counter[name] or 0) + 1
end

function ShowCounter(name)
	print(Counter[name])
end


function ShowLoggedCounter()
	print(GCO.Separator)
	print("Turn = " .. tostring(Game.GetCurrentGameTurn()))
	for key, value in pairs(Counter) do
		local str = tostring(key) .." tested plots count = " .. tostring(value)
		print(str)
		Counter[key] = 0
	end
	print(GCO.Separator)
end
GameEvents.OnGameTurnStarted.Add(ShowLoggedCounter)


--=====================================================================================--
-- Timer
--=====================================================================================--
local Timer 	= {}
local TimerLog 	= {
	--["GetRiverPath"] 	= 0,
	--["IsPlotConnectedCoastal"] = 0,
	--["IsPlotConnectedOcean"] = 0,
	--["IsPlotConnectedRoad"] = 0,
	--["IsPlotConnectedLand"] = 0,
	--["GetPathToPlotCoastal"] = 0,
	--["GetPathToPlotOcean"] = 0,
	--["GetPathToPlotRoad"] = 0,
	--["GetPathToPlotLand"] = 0,	
}
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
	if TimerLog[name] then TimerLog[name] = TimerLog[name] + diff; end
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

function ShowPlayerLoggedTimers(playerID)
	for key, value in pairs(TimerLog) do
		local str = tostring(key) .." timer = " .. tostring(value) .. " seconds" .. " for " .. tostring(Locale.ToUpper(Locale.Lookup(PlayerConfigurations[playerID]:GetCivilizationShortDescription())))
		print(str)
		TimerLog[key] = 0
	end	
end
--LuaEvents.ShowTimerLog.Add(ShowPlayerLoggedTimers)

function ShowLoggedTimers()
	print(GCO.Separator)
	print("Turn = " .. tostring(Game.GetCurrentGameTurn()))
	for key, value in pairs(TimerLog) do
		local str = tostring(key) .." timer = " .. tostring(value) .. " seconds"
		print(str)
		TimerLog[key] = 0
	end
	print(GCO.Separator)
end
GameEvents.OnGameTurnStarted.Add(ShowLoggedTimers)

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

function CalculateMaxRouteLength(routeLengthFactor)
	local maxRouteLength = 0
	local efficiency = 100
	while efficiency > 0 do
		maxRouteLength 	= maxRouteLength + 1
		efficiency 		= GetRouteEfficiency( maxRouteLength * routeLengthFactor )
	end
	return maxRouteLength
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

function GetAdjacentPlots(plot)
	local iX 	= plot:GetX()
	local iY 	= plot:GetY()
	local list	= {}
	for direction = 0, DirectionTypes.NUM_DIRECTION_TYPES - 1, 1 do
		local adjacentPlot 	= Map.GetAdjacentPlot(iX, iY, direction)
		if adjacentPlot then
			table.insert(list, adjacentPlot)
		end		
	end
	return list
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
-- Colors
--=====================================================================================--
function GetPlayerColors(playerID)

	--print("---------------------------------------")
	--print(pPlayerConfig:GetLeaderTypeName())
	local pPlayerConfig = GCO.GetPlayerConfig(playerID)
	
	local function ColorStringToNumber(colorStr)
		--print("ColorStringToNumber ", colorStr )
		hexString = ""
		for numStr in string.gmatch(colorStr, '([^,]+)') do
			local num = tonumber(numStr)
			local hex = ""
			if (num < 0 or num == 0) then
				hex = "00";
			elseif (num > 255 or num == 255) then
				hex = "ff";
			else
				hex = string.format("%x",num);
				if (string.len(hex)==1) then
					hex = "0"..hex;
				end
			end
		
			hexString = hex .. hexString
			--print(hexString)
		end
		local returnDec = (tonumber(hexString,16) + 2^31) % 2^32 - 2^31 -- see https://stackoverflow.com/questions/37411564/hex-to-int32-value
		--print("Return : ", returnDec )
		return returnDec
	end
	
	local colorRow 		= GameInfo.PlayerColors[pPlayerConfig:GetLeaderTypeName()]
	
	if colorRow == nil or colorRow.PrimaryColor == nil or colorRow.SecondaryColor == nil or GameInfo.Colors[colorRow.PrimaryColor] == nil or GameInfo.Colors[colorRow.SecondaryColor] == nil then
		GCO.Warning("colorRow has nil entry for ".. tostring(pPlayerConfig:GetLeaderTypeName()), colorRow, colorRow and colorRow.PrimaryColor, colorRow and colorRow.SecondaryColor )
		return ExposedMembers.UI.GetPlayerColors(playerID)
	end
--Dline(ColorStringToNumber, GameInfo.Colors, colorRow.PrimaryColor, GameInfo.Colors and colorRow.PrimaryColor and GameInfo.Colors[colorRow.PrimaryColor], GameInfo.Colors and colorRow.PrimaryColor and GameInfo.Colors[colorRow.PrimaryColor] and GameInfo.Colors[colorRow.PrimaryColor].Color)	
	local frontColor	= ColorStringToNumber(GameInfo.Colors[colorRow.PrimaryColor].Color)
	local backColor		= ColorStringToNumber(GameInfo.Colors[colorRow.SecondaryColor].Color)
	
	return frontColor, backColor
end


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
	return tostring(math.max(GameConfiguration.GetStartTurn(), Game.GetCurrentGameTurn()-1))
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
-- Population
--=====================================================================================--
local populationPerSizepower	= tonumber(GameInfo.GlobalParameters["CITY_POPULATION_PER_SIZE_POWER"].Value)
function GetPopulationAtSize(size)
	return GCO.Round(math.pow(size, populationPerSizepower) * 1000)
end
function GetSizeAtPopulation(population)
	return math.max(1,GCO.Round(math.pow(population / 1000, 1 / populationPerSizepower)))
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

function GetResourceImprovementID(resourceID)
	return ResourceImprovementID[resourceID]
end

function IsImprovingResource(improvementID, resourceID)
	return (IsImprovementForResource[improvementID] and IsImprovementForResource[improvementID][resourceID])
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

function GetVariationStringNoColorHigh(variation)
	if variation > 0 then
		return " [ICON_PressureUp]+".. Locale.Lookup("{1_Num : number #,###}", variation)
	elseif variation < 0 then
		return " [ICON_PressureDown]".. Locale.Lookup("{1_Num : number #,###}", variation)
	end
	return ""
end

function GetVariationStringNoColorPercent(variation)
	if variation > 0 then
		return " [ICON_PressureUp]+".. Locale.Lookup("{1_Num : number #.##}", variation)
	elseif variation < 0 then
		return " [ICON_PressureDown]".. Locale.Lookup("{1_Num : number #.##}", variation)
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

function GetEquipmentPropertyString(equipmentID)
	local str 		= ""
	local bStarted 	= false
	local function StartStr()
		if bStarted then
			return "[COLOR_Grey]--[ENDCOLOR]"
		else
			bStarted = true
			return ""
		end
	end
	local AntiPersonnel = EquipmentInfo[equipmentID].AntiPersonnel
	if AntiPersonnel and AntiPersonnel > 0 then
		str = str .. StartStr() .. tostring(AntiPersonnel) .."[ICON_AntiPersonnel]"
	end
	local PersonnelArmor = EquipmentInfo[equipmentID].PersonnelArmor
	if PersonnelArmor and PersonnelArmor > 0 then
		str = str .. StartStr() .. tostring(PersonnelArmor) .."[ICON_PersonnelArmor]"
	end
	local AntiPersonnelArmor = EquipmentInfo[equipmentID].AntiPersonnelArmor
	if AntiPersonnelArmor and AntiPersonnelArmor > 0 then
		str = str .. StartStr() .. tostring(AntiPersonnelArmor) .."[ICON_AntiArmor]"
	end
	local IgnorePersonnelArmor = EquipmentInfo[equipmentID].IgnorePersonnelArmor
	if IgnorePersonnelArmor and IgnorePersonnelArmor > 0 then
		str = str .. StartStr() .. tostring(IgnorePersonnelArmor) .."[ICON_IgnorArmor]"
	end
	return str
end

function GetPercentBarString(value, bInvertedColors, bNoGradient, color)
	if value == 0 then
		return (bInvertedColors and "[ICON_EMPTY20PERCENT][ICON_EMPTY20PERCENT][ICON_EMPTY20PERCENT][ICON_EMPTY20PERCENT][ICON_EMPTY20PERCENT]") or "[ICON_EMPTY20PERCENT_RED][ICON_EMPTY20PERCENT_RED][ICON_EMPTY20PERCENT_RED][ICON_EMPTY20PERCENT_RED][ICON_EMPTY20PERCENT_RED]"
	end
	
	-- 5 icons for a value between 1 and 100 (value > 100 will return a filled bar)
	local numHalfIcons	= Round(value / 10)
	local numFullIcons 	= math.floor(numHalfIcons / 2)
	local bHalfIcon		= value - (numFullIcons*20) >= 5
	local buildStr 		= {}
	local ColorTable	= (not bInvertedColors and {"_RED", "_ORANGE", "_YELLOW", "_OLIVE", "_GREEN"}) or {"_GREEN", "_OLIVE", "_YELLOW", "_ORANGE", "_RED"}
	local ColorToString	= {["black"] = "_BLACK", ["green"] = "_GREEN", ["red"] = "_RED", ["orange"] = "_ORANGE", ["yellow"] = "_YELLOW", ["olive"] = "_OLIVE" }
	local colorStr		= (color ~= nil and ColorToString[color]) or "_BLACK"
	
	if bNoGradient and color == nil then
		colorStr = ColorTable[math.max(1,numFullIcons)] 
	end
	
	for iconNum = 1, 5 do
		local IconSuffix = (color == nil and (not bNoGradient) and ColorTable[iconNum]) or colorStr
		if iconNum <= numFullIcons then		
			table.insert(buildStr, "[ICON_20PERCENT".. IconSuffix .."]")
		elseif iconNum == numFullIcons + 1 and bHalfIcon then
			table.insert(buildStr, "[ICON_10PERCENT".. IconSuffix .."]")		
		else
			table.insert(buildStr, "[ICON_EMPTY20PERCENT]")
		end
	end
	return table.concat(buildStr)
end

function GetEvaluationStringFromValue(value, maxValue, minValue, name, EvaluationStrings, EvaluationColors)
	local EvaluationStrings	= EvaluationStrings or {"LOC_EVALUATION_VERY_BAD","LOC_EVALUATION_BAD","LOC_EVALUATION_AVERAGE","LOC_EVALUATION_GOOD","LOC_EVALUATION_VERY_GOOD"}
	local EvaluationColors	= EvaluationColors or {"COLOR_Civ6DarkRed","COLOR_OperationChance_Orange","NONE","NONE","COLOR_Civ6Green"}
	local range 			= maxValue - minValue -- 200 if (-100 to 100)
	local valueInRange		= (range / 2) + (math.max(minValue, math.min(maxValue, value))) -- 100 if 0
	local percentage		= (valueInRange / ((range > 0 and range) or valueInRange)) * 100 -- 50 if 0
	local stringPosition	= math.max(1,Round(percentage * #EvaluationStrings / 100)) -- 3 if 0
	local colorPosition		= math.max(1,Round(percentage * #EvaluationColors / 100)) -- 3 if 0
	local returnString		= Locale.Lookup("LOC_EVALUATION_NUMBER", value) --(value > 0 and "+"..tostring(value)) or tostring(value)
	if name then
		returnString = returnString .. " " .. Locale.Lookup("LOC_EVALUATION_STRING_WITH_NAME", EvaluationStrings[stringPosition], name)
	else
		returnString = returnString .. " " .. Locale.Lookup("LOC_EVALUATION_STRING", EvaluationStrings[stringPosition])
	end
	if EvaluationColors[colorPosition] ~= "NONE" then
		returnString = "[".. EvaluationColors[colorPosition] .."]" .. returnString .. "[ENDCOLOR]"
	end
	return returnString
end


--=====================================================================================--
-- GCO Options
--=====================================================================================--
local OptionSection			= "Interface"					-- "Interface" if OptionGet = Options.GetUserOption, "UI" if OptionGet = Options.GetAppOption
local OptionTypeOverride 	= "PlayHistoricMomentAnimation" -- even if R&F is disabled by GCO, we can't use this else it would mess with people using R&F (maybe check if R&F use "value = 0" or "value = 1" to use the option, and overwrite when this is set to the one not used ?)
local OptionsGCO			= {"Test1", "Test2"} 			-- to do : XML table 
local OptionsBit			= {}

for i, optionType in ipairs(OptionsGCO) do
	OptionsBit[optionType] = bit(i)
end

function IsOptionActive(optionType)
	if OptionsBit[optionType] then
		local optionsValue	= OptionGet(OptionSection, OptionTypeOverride)
		return hasbit(optionsValue, OptionsBit[optionType])
	else
		Warning("GCO Option not registered :" .. tostring(optionType))
	end
end

function ChangeOption(optionType, bValue)
	if OptionsBit[optionType] then
		local optionsValue	= OptionGet(OptionSection, OptionTypeOverride)
		if bValue == true then
			optionsValue = setbit(optionsValue, OptionsBit[optionType])
		else
			optionsValue = clearbit(optionsValue, OptionsBit[optionType])		
		end
		OptionSet(OptionSection, OptionTypeOverride, optionsValue)
		OptionSave()
	else
		Warning("GCO Option not registered :" .. tostring(optionType))	
	end
end


--=====================================================================================--
-- Share functions for other contexts
--=====================================================================================--

function Initialize()
	if not ExposedMembers.GCO then ExposedMembers.GCO = {} end
	-- utils
	ExposedMembers.GCO.OrderedPairs 	= orderedPairs
	-- maths
	ExposedMembers.GCO.Round 						= Round
	ExposedMembers.GCO.Shuffle 						= Shuffle
	ExposedMembers.GCO.GetSize 						= GetSize
	ExposedMembers.GCO.ToDecimals 					= ToDecimals
	ExposedMembers.GCO.TableSummation 				= TableSummation
	ExposedMembers.GCO.IsEmpty 						= IsEmpty
	ExposedMembers.GCO.GetMaxPercentFromLowDiff 	= GetMaxPercentFromLowDiff
	ExposedMembers.GCO.GetMaxPercentFromHighDiff 	= GetMaxPercentFromHighDiff
	ExposedMembers.GCO.LimitEffect 					= LimitEffect

	-- counter
	ExposedMembers.GCO.Incremente 		= Incremente
	ExposedMembers.GCO.ShowCounter		= ShowCounter
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
	-- color
	ExposedMembers.GCO.GetPlayerColors				= GetPlayerColors
	-- common
	ExposedMembers.GCO.GetTotalPrisoners 			= GetTotalPrisoners
	ExposedMembers.GCO.GetTurnKey 					= GetTurnKey
	ExposedMembers.GCO.GetPreviousTurnKey			= GetPreviousTurnKey
	-- map
	ExposedMembers.GCO.FindNearestPlayerCity 		= FindNearestPlayerCity
	ExposedMembers.GCO.GetRouteEfficiency 			= GetRouteEfficiency
	ExposedMembers.GCO.CalculateMaxRouteLength		= CalculateMaxRouteLength
	ExposedMembers.GCO.SupplyPathBlocked 			= SupplyPathBlocked
	ExposedMembers.GCO.TradePathBlocked 			= TradePathBlocked
	ExposedMembers.GCO.GetAdjacentPlots				= GetAdjacentPlots
	-- player
	ExposedMembers.GCO.GetPlayerUpperClassPercent 	= GetPlayerUpperClassPercent
	ExposedMembers.GCO.GetPlayerMiddleClassPercent 	= GetPlayerMiddleClassPercent
	-- population
	ExposedMembers.GCO.GetPopulationAtSize			= GetPopulationAtSize
	ExposedMembers.GCO.GetSizeAtPopulation			= GetSizeAtPopulation
	-- Resources
	ExposedMembers.GCO.GetBaseResourceCost 			= GetBaseResourceCost
	ExposedMembers.GCO.IsResourceEquipment			= IsResourceEquipment
	ExposedMembers.GCO.IsResourceFood 				= IsResourceFood
	ExposedMembers.GCO.IsResourceLuxury 			= IsResourceLuxury
	ExposedMembers.GCO.IsResourceEquipmentMaker		= IsResourceEquipmentMaker
	ExposedMembers.GCO.GetResourceIcon				= GetResourceIcon
	ExposedMembers.GCO.GetResourceImprovementID		= GetResourceImprovementID
	ExposedMembers.GCO.IsImprovingResource			= IsImprovingResource
	-- texts
	ExposedMembers.GCO.GetPrisonersStringByCiv 			= GetPrisonersStringByCiv
	ExposedMembers.GCO.GetVariationString 				= GetVariationString
	ExposedMembers.GCO.GetVariationStringNoColorHigh	= GetVariationStringNoColorHigh
	ExposedMembers.GCO.GetVariationStringNoColorPercent	= GetVariationStringNoColorPercent
	ExposedMembers.GCO.GetNeutralVariationString		= GetNeutralVariationString
	ExposedMembers.GCO.GetVariationStringGreenPositive 	= GetVariationStringGreenPositive
	ExposedMembers.GCO.GetVariationStringRedPositive	= GetVariationStringRedPositive
	ExposedMembers.GCO.GetEquipmentPropertyString		= GetEquipmentPropertyString
	ExposedMembers.GCO.GetPercentBarString				= GetPercentBarString
	ExposedMembers.GCO.GetEvaluationStringFromValue		= GetEvaluationStringFromValue
	-- Options
	ExposedMembers.GCO.IsOptionActive					= IsOptionActive
	ExposedMembers.GCO.ChangeOption						= ChangeOption
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
	ExposedMembers.ResearchScript_Initialized	= nil
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
	--
	ExposedMembers.GameEvents					= nil
	--ExposedMembers.LuaEvents					= nil
end
Events.LeaveGameComplete.Add(Cleaning)
--LuaEvents.RestartGame.Add(Cleaning)


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