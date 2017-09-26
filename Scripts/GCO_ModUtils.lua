--=====================================================================================--
--	FILE:	 ModUtils.lua
--  Gedemon (2017)
--=====================================================================================--

print ("Loading ModUtils.lua...")

-----------------------------------------------------------------------------------------
-- Defines
-----------------------------------------------------------------------------------------

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

	
local ResourceValue 		= {			-- cached table with value of resources type
		["RESOURCECLASS_LUXURY"] 	= tonumber(GameInfo.GlobalParameters["CITY_TRADE_INCOME_RESOURCE_LUXURY"].Value),
		["RESOURCECLASS_STRATEGIC"]	= tonumber(GameInfo.GlobalParameters["CITY_TRADE_INCOME_RESOURCE_STRATEGIC"].Value),
		["RESOURCECLASS_BONUS"]		= tonumber(GameInfo.GlobalParameters["CITY_TRADE_INCOME_RESOURCE_BONUS"].Value)
}

local IsEquipment	= {}
for row in GameInfo.Resources() do
	local resourceType	= row.ResourceType
	local strStart, strEnd 	= string.find(resourceType, "EQUIPMENT_")
	if strStart and strStart == 1 and strEnd == 10 then
		IsEquipment[row.Index] = true
	end
end

local foodResourceID 			= GameInfo.Resources["RESOURCE_FOOD"].Index
local materielResourceID		= GameInfo.Resources["RESOURCE_MATERIEL"].Index
local steelResourceID 			= GameInfo.Resources["RESOURCE_STEEL"].Index
local personnelResourceID		= GameInfo.Resources["RESOURCE_PERSONNEL"].Index
local woodResourceID			= GameInfo.Resources["RESOURCE_WOOD"].Index
local medicineResourceID		= GameInfo.Resources["RESOURCE_MEDICINE"].Index
local leatherResourceID			= GameInfo.Resources["RESOURCE_LEATHER"].Index
local plantResourceID			= GameInfo.Resources["RESOURCE_PLANTS"].Index

local ResourceTempIcons = {		-- Table to store temporary icons for resources until new FontIcons could be added...
		--[woodResourceID] 		= "[ICON_RESOURCE_CLOVES]",
		--[materielResourceID] 	= "[ICON_Charges]",
		[steelResourceID] 		= "[ICON_New]",
		[medicineResourceID] 	= "[ICON_Damaged]",
		--[leatherResourceID] 	= "[ICON_New]",
		--[plantResourceID] 		= "[ICON_RESOURCE_CINNAMON]",
		[foodResourceID] 		= "[ICON_Food]",
		[personnelResourceID]	= "[ICON_Position]",
	}

-- Floating Texts LOD
local FLOATING_TEXT_NONE 	= 0
local FLOATING_TEXT_SHORT 	= 1
local FLOATING_TEXT_LONG 	= 2
local floatingTextLevel 	= FLOATING_TEXT_SHORT

-----------------------------------------------------------------------------------------
-- Initialize Functions
-----------------------------------------------------------------------------------------
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
							)
	if not bIsInitialized and Automation.GetTime() > g_Timer + 20 then
		print("Still not initialized...  timer = ",  Automation.GetTime())
		g_Timer = Automation.GetTime()
		print("ExposedMembers.SaveLoad_Initialized         ",ExposedMembers.SaveLoad_Initialized           )
		print("ExposedMembers.Utils_Initialized            ",ExposedMembers.Utils_Initialized              )
		print("ExposedMembers.Serialize_Initialized        ",ExposedMembers.Serialize_Initialized          )
		print("ExposedMembers.ContextFunctions_Initialized ",ExposedMembers.ContextFunctions_Initialized   )
		print("ExposedMembers.RouteConnections_Initialized ",ExposedMembers.RouteConnections_Initialized   )
		print("ExposedMembers.PlotIterator_Initialized     ",ExposedMembers.PlotIterator_Initialized       )
		print("ExposedMembers.PlotScript_Initialized       ",ExposedMembers.PlotScript_Initialized         )
		print("ExposedMembers.CityScript_Initialized       ",ExposedMembers.CityScript_Initialized         )
		print("ExposedMembers.UnitScript_Initialized       ",ExposedMembers.UnitScript_Initialized         )
		print("ExposedMembers.PlayerScript_Initialized     ",ExposedMembers.PlayerScript_Initialized       )
	end
		
	return bIsInitialized
end

local GCO = {}
function InitializeUtilityFunctions() 	-- Get functions from other contexts
	if IsInitializedGCO() then 	
		print ("All GCO script files loaded...")
		GCO = ExposedMembers.GCO					-- contains functions from other contexts
		print ("Exposed Functions from other contexts initialized...")
		Events.GameCoreEventPublishComplete.Remove( InitializeUtilityFunctions )
		-- tell all other scripts they can initialize now
		LuaEvents.InitializeGCO() 
	end
end
Events.GameCoreEventPublishComplete.Add( InitializeUtilityFunctions )


-----------------------------------------------------------------------------------------
-- Maths
-----------------------------------------------------------------------------------------
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
    local k = math.random(n) -- 1 <= k <= n
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

----------------------------------------------
-- Debug
----------------------------------------------

local bNoOutput = false
function ToggleOutput()
	bNoOutput = not bNoOutput
	print("Spam control = " .. tostring(bNoOutput))
end

function Dprint(...)
    local args = {...}
	if args.n == 1 then print(args[1]) end 							-- if called with one argument only, print it
	if args.n == 0 or bNoOutput or args[1] == false then return end	-- don't print if the first argument is false (= debug off)
	print(select(2,...)) 											-- print everything else after the first argument
end

function Error(...)
	print("Error : ", select(1,...))
	LuaEvents.StopAuToPlay()
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

----------------------------------------------
-- Timer
----------------------------------------------

local Timer = {}
function StartTimer(name)
	Timer[name] = Automation.GetTime()
end
function ShowTimer(name)
	if bNoOutput then -- spam control
		return
	end
	if Timer[name] then
		print("- "..tostring(name) .." timer = " .. tostring(Automation.GetTime()-Timer[name]) .. " seconds")
	end
end

----------------------------------------------
-- Civilizations
----------------------------------------------

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

----------------------------------------------
-- Map
----------------------------------------------

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

function SupplyPathBlocked(pPlot, pPlayer)

	local ownerID = pPlot:GetOwner()
	local playerID = pPlayer:GetID()

	local aUnits = Units.GetUnitsInPlot(pPlot);
	for i, pUnit in ipairs(aUnits) do
		if pPlayer:GetDiplomacy():IsAtWarWith( pUnit:GetOwner() ) then return true end -- path blocked
	end
		
	if ( ownerID == playerID or ownerID == -1 ) then
		return false
	end

	if GCO.HasPlayerOpenBordersFrom(pPlayer, ownerID) then
		return false
	end	

	return true -- return true if the path is blocked...
end


----------------------------------------------
-- Cities
----------------------------------------------

-- City Capture Events
local cityCaptureTest = {}
function CityCaptureDistrictRemoved(playerID, districtID, cityID, iX, iY)
print("Calling CityCaptureDistrictRemoved (", playerID, districtID, cityID, iX, iY,")")
	local key = iX..","..iY
	cityCaptureTest[key]			= {}
	cityCaptureTest[key].Turn 		= Game.GetCurrentGameTurn()
	cityCaptureTest[key].PlayerID 	= playerID
	cityCaptureTest[key].CityID 	= cityID
end
Events.DistrictRemovedFromMap.Add(CityCaptureDistrictRemoved)
function CityCaptureCityAddedToMap(playerID, cityID, iX, iY)
print("Calling CityCaptureCityAddedToMap (", playerID, cityID, iX, iY,")")
	local key = iX..","..iY
	if (	cityCaptureTest[key]
		and cityCaptureTest[key].Turn 	== Game.GetCurrentGameTurn()
		and not	cityCaptureTest[key].CityAddedXY	)
	then
		cityCaptureTest[key].CityAddedXY = true
		local city = CityManager.GetCity(playerID, cityID)
		local originalOwnerID 	= city:GetOriginalOwner()
		local originalCityID	= cityCaptureTest[key].CityID
		local newOwnerID 		= playerID
		local newCityID			= cityID
		if cityCaptureTest[key].PlayerID == originalOwnerID then
			print("Calling LuaEvents.CapturedCityAddedToMap (", originalOwnerID, originalCityID, newOwnerID, newCityID, iX, iY,")")
			LuaEvents.CapturedCityAddedToMap(originalOwnerID, originalCityID, newOwnerID, newCityID, iX, iY)
		end
	end
end
Events.CityAddedToMap.Add(CityCaptureCityAddedToMap)
function CityCaptureCityInitialized(playerID, cityID, iX, iY)
print("Calling CityCaptureCityInitialized (", playerID, cityID, iX, iY,")")
	local key = iX..","..iY
	if (	cityCaptureTest[key]
		and cityCaptureTest[key].Turn 	== Game.GetCurrentGameTurn() )
	then
		cityCaptureTest[key].CityInitializedXY = true
		local city = CityManager.GetCity(playerID, cityID)
		local originalOwnerID 	= city:GetOriginalOwner()
		local originalCityID	= cityCaptureTest[key].CityID
		local newOwnerID 		= playerID
		local newCityID			= cityID
		if cityCaptureTest[key].PlayerID == originalOwnerID then
			print("Calling LuaEvents.CapturedCityInitialized (", originalOwnerID, originalCityID, newOwnerID, newCityID, iX, iY,")")
			LuaEvents.CapturedCityInitialized(originalOwnerID, originalCityID, newOwnerID, newCityID, iX, iY)
			cityCaptureTest[key] = {}
		end
	end
end
Events.CityInitialized.Add(CityCaptureCityInitialized)


----------------------------------------------
-- Common
----------------------------------------------

function GetTotalPrisoners(data) -- works for cityData and unitData
	return TableSummation(data.Prisoners)
end

function GetTurnKey()
	return tostring(Game.GetCurrentGameTurn())
end

function GetPreviousTurnKey()
	return tostring(math.max(0, Game.GetCurrentGameTurn()-1))
end

----------------------------------------------
-- Players
----------------------------------------------

function GetPlayerUpperClassPercent( playerID )
	return tonumber(GameInfo.GlobalParameters["CITY_BASE_UPPER_CLASS_PERCENT"].Value)
end

function GetPlayerMiddleClassPercent( playerID )
	return tonumber(GameInfo.GlobalParameters["CITY_BASE_MIDDLE_CLASS_PERCENT"].Value)
end


----------------------------------------------
-- Resources
----------------------------------------------
function GetBaseResourceCost(resourceID)
	local resourceClassType = GameInfo.Resources[resourceID].ResourceClassType
	return ResourceValue[resourceClassType] or 0
end

function IsResourceEquipment(resourceID)
	return IsEquipment[resourceID]
end

function GetResourceIcon(resourceID)
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

----------------------------------------------
-- Units
----------------------------------------------


----------------------------------------------
-- Texts function
----------------------------------------------

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

----------------------------------------------
-- Share functions for other contexts
----------------------------------------------

function Initialize()
	if not ExposedMembers.GCO then ExposedMembers.GCO = {} end
	-- maths
	ExposedMembers.GCO.Round 			= Round
	ExposedMembers.GCO.Shuffle 			= Shuffle
	ExposedMembers.GCO.GetSize 			= GetSize
	ExposedMembers.GCO.ToDecimals 		= ToDecimals
	ExposedMembers.GCO.TableSummation 	= TableSummation
	-- timers
	ExposedMembers.GCO.StartTimer 		= StartTimer
	ExposedMembers.GCO.ShowTimer 		= ShowTimer
	-- debug
	ExposedMembers.GCO.ToggleOutput 	= ToggleOutput
	ExposedMembers.GCO.Dprint			= Dprint
	ExposedMembers.GCO.AreSameTables	= AreSameTables
	ExposedMembers.GCO.Dump				= Dump
	ExposedMembers.GCO.Error			= Error
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
	-- player
	ExposedMembers.GCO.GetPlayerUpperClassPercent 	= GetPlayerUpperClassPercent
	ExposedMembers.GCO.GetPlayerMiddleClassPercent 	= GetPlayerMiddleClassPercent
	-- Resources
	ExposedMembers.GCO.GetBaseResourceCost 			= GetBaseResourceCost
	ExposedMembers.GCO.IsResourceEquipment			= IsResourceEquipment
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


-----------------------------------------------------------------------------------------
-- Cleaning on exit
-----------------------------------------------------------------------------------------
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
	--
	ExposedMembers.UnitHitPointsTable 			= nil
	--
	ExposedMembers.UnitData 					= nil
	ExposedMembers.CityData 					= nil
	ExposedMembers.PlayerData 					= nil
	ExposedMembers.CultureMap 					= nil
	ExposedMembers.PreviousCultureMap 			= nil
	ExposedMembers.GCO 							= nil
	--
	ExposedMembers.UI 							= nil
	ExposedMembers.Calendar 					= nil
	ExposedMembers.CombatTypes 					= nil
end
Events.LeaveGameComplete.Add(Cleaning)
LuaEvents.RestartGame.Add(Cleaning)


-----------------------------------------------------------------------------------------
-- Testing...
-----------------------------------------------------------------------------------------

local currentTurn = -1
local playerMadeTurn = {}
function GetPlayerTurn(playerID)
	if (currentTurn ~= Game.GetCurrentGameTurn()) then
		currentTurn = Game.GetCurrentGameTurn()
		playerMadeTurn = {}
	end
	if not playerMadeTurn[playerID] then
		LuaEvents.StartPlayerTurn(playerID)			
		print("----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------")
		print("-- Test Start Turn player#"..tostring(playerID))
		print("----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------")
		playerMadeTurn[playerID] = true
	end
end
function OnUnitMovementPointsChanged(playerID)
	print("----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------")
	print("-- Test Start Turn On UnitMovementPointsChanged player#"..tostring(playerID))
	print("----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------")
	GetPlayerTurn(playerID)
end
function OnAiAdvisorUpdated(playerID)
	print("----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------")
	print("-- Test Start Turn On AiAdvisorUpdated player#"..tostring(playerID))
	print("----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------")
	GetPlayerTurn(playerID)
end
function FindActivePlayer()
	for _, playerID in ipairs(PlayerManager.GetWasEverAliveMajorIDs()) do
		local player = Players[playerID]
		if player:IsTurnActive() then
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