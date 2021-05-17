--=====================================================================================--
--	FILE:	 GCO_DiplomacyScript.lua
--  Gedemon (2021)
--=====================================================================================--

print ("Loading GCO_DiplomacyScript.lua...")

--=====================================================================================--
-- Includes
--=====================================================================================--
include( "GCO_TypeEnum" )
include( "GCO_SmallUtils" )


--=====================================================================================--
-- Defines
--=====================================================================================--
DEBUG_DIPLOMACY_SCRIPT 	= "debug"

local _cached			= {}	-- cached table to reduce calculations

local iPeaceBarbarian 			= 62 -- GameDefines.MAX_PLAYERS - 2 <- would that be better ?
local fRansomOtherOwnerFactor	= tonumber(GameInfo.GlobalParameters["DIPLO_RANSOM_OTHER_OWNER_FACTOR"].Value) 		-- 1.5
local iMercenaryTruceBaseTurn	= tonumber(GameInfo.GlobalParameters["DIPLO_MERCENARY_TRUCE_BASE_TURN"].Value)		-- 3
local iMercenaryContractExpire	= tonumber(GameInfo.GlobalParameters["DIPLO_MERCENARY_CONTRACT_EXPIRE_TURN"].Value)	-- 5
local fDealTreasuryCostRatio	= tonumber(GameInfo.GlobalParameters["DIPLO_DEAL_TREASURY_COST_RATIO"].Value)		-- 0.1

--=====================================================================================--
-- Initialize Functions
--=====================================================================================--

local GCO 	= {}
local pairs = pairs
local Dprint, Dline, Dlog, Div, LuaEvents
function InitializeUtilityFunctions() 	-- Get functions from other contexts
	GCO 		= ExposedMembers.GCO		-- contains functions from other contexts 
	LuaEvents	= GCO.LuaEvents
	Dprint 		= GCO.Dprint				-- Dprint(bOutput, str) : print str if bOutput is true
	Dline		= GCO.Dline					-- output current code line number to firetuner/log
	Dlog		= GCO.Dlog					-- log a string entry, last 10 lines displayed after a call to GCO.Error()
	Div			= GCO.Divide
	pairs 		= GCO.OrderedPairs
	GameEvents.InitializeGCO.Remove( InitializeUtilityFunctions )
	print ("Exposed Functions from other contexts initialized...")
	PostInitialize()
end
GameEvents.InitializeGCO.Add( InitializeUtilityFunctions )

function PostInitialize() -- everything that may require other context to be loaded first
	ExposedMembers.GCO.DiplomacyData = GCO.LoadTableFromSlot("DiplomacyData") or {}

	SetInitialDiplomacy()
	InitializeDiplomacyCache()
	
	LuaEvents.DoDiplomacyTurn.Add( PlayerDiplomacyTurn )
	
	GameEvents.ChangeCultureInterest.Add( ChangeInterestModifier )
	GameEvents.ChangeCultureRelation.Add( ChangeRelationModifier )
	GameEvents.SetCultureRelation.Add( SetRelationModifier )
end

function SaveTables()
	Dprint("--------------------------- Saving DiplomacyData ---------------------------")

	GCO.StartTimer("Saving And Checking DiplomacyData")
	GCO.SaveTableToSlot(ExposedMembers.GCO.DiplomacyData, "DiplomacyData")
end
GameEvents.SaveTables.Add(SaveTables)


--=====================================================================================--
-- Generic Functions
--=====================================================================================--

function GetCached(key)
	return _cached[key]
end

function SetCached(key, value)
	_cached[key] = value
end

function GetValue(key)
	local Data = ExposedMembers.GCO.DiplomacyData
	if not Data then
		GCO.Warning("DiplomacyData is nil")
		return nil
	end
	return Data[key]
end

function SetValue(key, value)
	local Data = ExposedMembers.GCO.DiplomacyData
	if not Data then
		GCO.Error("DiplomacyData is nil[NEWLINE]Trying to set ".. tostring(key) .." value to " ..tostring(value))
	end
	Data[key] = value
end

function GetDiploKey(iCulture1, iCulture2)	-- We save player to player deals/treaty table in one entry, using a "lowerID,higherID" unique key
	return iCulture1 < iCulture2 and tostring(iCulture1)..","..tostring(iCulture2) or tostring(iCulture2)..","..tostring(iCulture1)
end

function GetDiploKeyFromPlayerID(iPlayer1, iPlayer2)

	local iCulture1		= GCO.GetCultureIDFromPlayerID(iPlayer1)
	local iCulture2		= GCO.GetCultureIDFromPlayerID(iPlayer2)
	
	return GetDiploKey(iCulture1, iCulture2)
end

function GetCultureIDsFromKey(diploKey :string)
	return diploKey:match("([^,]+),([^,]+)") -- return id1, id2
end

function GetPlayerIDsFromKey(diploKey :string)
	local iCulture1, iCulture2 = GetCultureIDsFromKey(diploKey)
	return GCO.GetPlayerIDFromCultureID(iCulture1), GCO.GetPlayerIDFromCultureID(iCulture2)
end

function GetDiploKeyFromListIDs(tListIDs)
	table.sort(tListIDs)
	return table.concat(tListIDs, ",")
end

function GetListIDsFromDiploKey(diploKey :string)
	return Split(diploKey, ",")
end

function GetNonPlayerCultures()
	local tCultures = {}
	for row in GameInfo.CultureGroups() do
		local cultureID = row.Index
		if GCO.GetPlayerIDFromCultureID(cultureID) == nil and GCO.HasCultureGroupSpawned(cultureID) then -- spawned and not a player
			table.insert(tCultures, cultureID)
		end
	end
	return tCultures
end


--=====================================================================================--
-- Initialize Diplomacy Function
--=====================================================================================--
function SetInitialDiplomacy()

	if Game:GetProperty("DiplomacyInitialized") then -- only called once
		return
	end
	
	-- Make the "Peaceful Barbs" Tribe at peace with every players
	-- Pacified Units will be given to it for the duration of the pacification
	-- Other Tribes start at war with each others
	
	for iPlayer = 0, 63 do --PlayerManager.GetWasEverAliveCount() - 1 do
		if iPlayer ~= iPeaceBarbarian then
			local pPlayer	= Players[iPlayer]
			local pDiplo 	= pPlayer and pPlayer:GetDiplomacy()
			if pDiplo then
				Dprint( DEBUG_DIPLOMACY_SCRIPT, "- Initialize Diplomacy for player#"..tostring(iPlayer))

				if pDiplo:IsAtWarWith( iPeaceBarbarian ) then
					pDiplo:MakePeaceWith(iPeaceBarbarian, true)
				end
				
				if not pDiplo:HasMet(iPeaceBarbarian) then
					-- crashing in MP here, why ???
					--pDiplo:SetHasMet(iPeaceBarbarian)
				end
				
				for iOtherPlayer = 0, 63 do --PlayerManager.GetWasEverAliveCount() - 1 do
					if iOtherPlayer ~= iPlayer and iOtherPlayer ~= iPeaceBarbarian then
						local pOtherPlayer = Players[iOtherPlayer]
						if pOtherPlayer and pOtherPlayer:IsBarbarian() and not pDiplo:IsAtWarWith( iOtherPlayer ) then
							pDiplo:DeclareWarOn(iOtherPlayer, WarTypes.FORMAL_WAR, true);
						end
					end
				end
			end
		end
	end
	
	Game:SetProperty("DiplomacyInitialized", 1);
end

function InitializeDiplomacyCache()

	-- non-player diplo
	for _, cultureID in ipairs(GetNonPlayerCultures()) do
	
	end
	
	-- Player diplo
	for iPlayer = 0, 63 do --PlayerManager.GetWasEverAliveCount() - 1 do
	
	end
end


--=====================================================================================--
-- Diplomacy Functions (Symmetric relations, one table with a key value made from multiple IDs)
--
-- DiplomacyTypes.Deals
-- DiplomacyTypes.Treaties
-- DiplomacyTypes.State
--=====================================================================================--

-- Saved
function GetAllCultureDiplomacy(diplomacyType)

	local kDiploType	= GetValue(diplomacyType)
	
	if kDiploType == nil then -- initialize
		kDiploType = {}
		SetValue(diplomacyType, kDiploType)
	end
	
	return kDiploType
end

function GetCulturesDiplomacy(iCulture1, iCulture2, diplomacyType) -- return list of Deals/Treaties/State between iCulture1 and iCulture2
	
	local diploKey 		= GetDiploKey(iCulture1, iCulture2)
	local kDiploType	= GetAllCultureDiplomacy(diplomacyType)
	
	if kDiploType[diploKey] == nil then -- initialize
		kDiploType[diploKey] = {}
	end
	
	return kDiploType[diploKey]
end

function GetPlayersDiplomacy(iPlayer1, iPlayer2, diplomacyType)

	local iCulture1		= GCO.GetCultureIDFromPlayerID(iPlayer1)
	local iCulture2		= GCO.GetCultureIDFromPlayerID(iPlayer2)
	
	return GetCulturesDiplomacy(iCulture1, iCulture2, diplomacyType)
end

-- Cached
function GetPlayerDiplomacyList(iPlayer, diplomacyType)

	local cultureKey 	= tostring(GCO.GetCultureIDFromPlayerID(iPlayer))
	local kCultureDiplo	= GetAllCultureDiplomacy()
	
	if kCultureDiplo[cultureKey] == nil then -- initialize
		SetCultureDiplomacyList(cultureKey)
	end
	
	return kCultureDiplo[cultureKey][diplomacyType]
	
end

function GetAllCultureDiplomacy()

	local kCultureDiplo	= GetCached("CultureDiplomacy")
	
	if kCultureDiplo == nil then -- initialize
		kCultureDiplo = {}
		SetCached("CultureDiplomacy", kCultureDiplo)
	end
	return kCultureDiplo
end

function SetCultureDiplomacyList(cultureKey)

	local kCultureDiplo			= GetAllCultureDiplomacy()
	kCultureDiplo[cultureKey] 	= {}
	
	for _, diplomacyType in pairs(DiplomacyTypes) do
	
		local kDiploType = GetAllCultureDiplomacy(diplomacyType)
		
		kCultureDiplo[cultureKey][diplomacyType] = {}
		
		for diploKey, diploData in pairs(kDiploType) do
			if string.find(diploKey, cultureKey) then
				kCultureDiplo[cultureKey][diplomacyType][diploKey] = diploData
			end
		end
	end

end


--=====================================================================================--
-- Cultures Relations Functions (Asymmetric)
--
-- Culture relation modifiers are also applied to the own player culture, as they represent people relation to a nation
-- Used to define Homeland stability and Units loyalty
-- It's a variable value (change by summation of modifiers each turn) with a balance tendency to 0 (= neutral)
--=====================================================================================--

-- Saved
function GetCultureRelationValue(iCulture1, iCulture2)

	local cultureKey 	= tostring(iCulture1)
	local otherKey		= tostring(iCulture2)
	local kValues 		= GetValue("RelationValues")
	
	if kValues == nil then -- initialize
		kValues = {}
		SetValue("RelationValues", kValues)
	end
	
	if kValues[cultureKey] == nil then -- initialize
		kValues[cultureKey] = {}
	end
	
	return kValues[cultureKey][otherKey] or 0
end

function ChangeCultureRelationValue(iCulture1, iCulture2, value)

	local cultureKey 	= tostring(iCulture1)
	local otherKey		= tostring(iCulture2)
	local kValues 		= GetValue("RelationValues")
	
	if kValues == nil then -- initialize
		kValues = {}
		SetValue("RelationValues", kValues)
	end
	
	if kValues[cultureKey] == nil then -- initialize
		kValues[cultureKey] = {}
	end
	
	kValues[cultureKey][otherKey] = (kValues[cultureKey][otherKey] or 0) + value
end

-- 	
function GetCultureRelations(cultureID)

	local cultureKey = tostring(cultureID)
	local kRelations = GetValue("RelationModifierss")
	
	if kRelations == nil then -- initialize
		kRelations = {}
		SetValue("RelationModifierss", kRelations)
	end
	
	if kRelations[cultureKey] == nil then -- initialize
		kRelations[cultureKey] = {}
	end
	
	return kRelations[cultureKey]
end

function GetPlayerRelations(playerID)
	local cultureID	= GCO.GetCultureIDFromPlayerID(playerID)
	
	return GetCultureRelations(cultureID)
end

function GetRelationTypes(iCulture1, iCulture2)

	local kRelations 	= GetCultureRelations(iCulture1)
	local otherKey		= tostring(iCulture2)
	
	return kRelations[otherKey] or {}
end

function GetRelationModifier(iCulture1, iCulture2, relationType)

	local kRelations 		= GetCultureRelations(iCulture1)
	local otherKey			= tostring(iCulture2)
	local relationKey		= tostring( GameInfo.CultureRelationModifiers[relationType].Index)
	
	return kRelations[otherKey] and kRelations[otherKey][relationKey] or 0
end

function UpdateRelationTypes(iCulture1, iCulture2)

	local kRelationTypes 	= GetRelationTypes(iCulture1, iCulture2)
	local toRemove			= {}
	
	for relationKey, value in pairs(kRelationTypes) do
	
		local relationType 	= tonumber(relationKey)
		local relationRow	= GameInfo.DiplomacyInterestModifiers[relationType]
		
		if value ~= 0 then
			if relationRow.Decay then
				
				local bIsNegative 			= (value < 0)
				value 						= math.max(0,math.abs(value) - relationRow.Decay)
				kRelationTypes[relationKey] = bIsNegative and - value or value
				
			end
		else
			table.insert(toRemove, relationKey)
		end
		
	end
	
	for _, relationKey in ipairs(toRemove) do
		kRelationTypes[relationKey] = nil
	end
end

function SetRelationModifier(iCulture1, iCulture2, relationType, value)

	local relationRow		= GameInfo.CultureRelationModifiers[relationType]
	local kRelations 		= GetCultureRelations(iCulture1)
	local otherKey			= tostring(iCulture2)
	local relationKey		= tostring(relationRow.Index)
	kRelations[otherKey]	= kRelations[otherKey] or {}
	
	kRelations[otherKey][relationKey] = value or relationRow.SetValue or relationRow.BaseValue
	
end

function ChangeRelationModifier(iCulture1, iCulture2, relationType, value)
	
	local relationRow		= GameInfo.CultureRelationModifiers[relationType]
	local value 			= value or relationRow.SetValue
	local kRelations 		= GetCultureRelations(iCulture1)
	local otherKey			= tostring(iCulture2)
	local relationKey		= tostring(relationRow.Index)
	kRelations[otherKey]	= kRelations[otherKey] or {}
	
	kRelations[otherKey][relationKey] = (kRelations[otherKey][relationKey] or 0) + value
	
end

function GetRelationVariation(iCulture1, iCulture2)

	local variation = 0
	for row in GameInfo.CultureRelationModifiers() do
		variation = variation + GetRelationModifier(iCulture1, iCulture2, row.Index)
	end

	return variation
end

-- Strings
function GetCultureRelationIcon(iCulture1, iCulture2)

	local relation = GetCultureRelationValue(iCulture1, iCulture2) or 0
	
	-- to do : remove magic number (threshold)
	if relation >= 50 then
		return "[ICON_VERY_HAPPY]"
	elseif relation >= 25 then
		return "[ICON_HAPPY]"
	elseif relation > -25 then
		return "[ICON_NEUTRAL]"
	elseif relation > -50 then
		return "[ICON_ANGRY]"
	else
		return "[ICON_VERY_ANGRY]"
	end
	
end

--=====================================================================================--
-- Interests Functions  (Asymmetric)
--
-- "Nations have no permanent friends or allies, they only have permanent interests"
--
-- Diplomacy Interests are international relations, which are mostly different than interculture relations, with a few overlap
-- International relations can change quicker than interculture relations
-- Used for Diplomatic interactions
-- It's a fixed value (summation of modifiers)
--=====================================================================================--

function GetCultureInterests(cultureID)

	local cultureKey = tostring(cultureID)
	local kInterests = GetValue("Interests")
	
	if kInterests == nil then -- initialize
		kInterests = {}
		SetValue("Interests", kInterests)
	end
	
	if kInterests[cultureKey] == nil then -- initialize
		kInterests[cultureKey] = {}
	end
	
	return kInterests[cultureKey]
end

function GetPlayerInterests(playerID)
	local cultureID	= GCO.GetCultureIDFromPlayerID(playerID)
	
	return GetCultureInterests(cultureID)
end

function GetInterestTypes(iCulture1, iCulture2)

	local kInterests 		= GetCultureInterests(iCulture1)
	local otherKey			= tostring(iCulture2)
	
	return kInterests[otherKey] or {}
end

function UpdateInterestTypes(iCulture1, iCulture2)

	local kInterestTypes 	= GetInterestTypes(iCulture1, iCulture2)
	local toRemove			= {}
	
	for interestKey, value in pairs(kInterestTypes) do
	
		local interestType 	= tonumber(interestKey)
		local interestRow	= GameInfo.DiplomacyInterestModifiers[interestType]
		
		if value ~= 0 then
			if interestRow.Decay then
				
				local bIsNegative 			= (value < 0)
				value 						= math.max(0,math.abs(value) - interestRow.Decay)
				kInterestTypes[interestKey] = bIsNegative and - value or value
				
			end
		else
			table.insert(toRemove, interestKey)
		end
		
	end
	
	for _, interestKey in ipairs(toRemove) do
		kInterestTypes[interestKey] = nil
	end
end

function ChangeInterestModifier(iCulture1, iCulture2, interestType, value)

	local value = value or GameInfo.DiplomacyInterestModifiers[interestType].BaseValue
	
	if value == nil or value == 0 then
		return
	end
	
	local kInterests 		= GetCultureInterests(iCulture1)
	local otherKey			= tostring(iCulture2)
	local interestKey		= tostring(GameInfo.DiplomacyInterestModifiers[interestType].Index)
	kInterests[otherKey]	= kInterests[otherKey] or {}
	
	kInterests[otherKey][interestKey] = (kInterests[otherKey][interestKey] or 0) + value
end

function GetCultureInterestValue(iCulture1, iCulture2)
	
	local kInterests 		= GetCultureInterests(iCulture1)
	local otherKey			= tostring(iCulture2)
	kInterests[otherKey]	= kInterests[otherKey] or {}
	
	return GCO.TableSummation(kInterests[otherKey])
end


-- ====================================================================================== --
-- Turn function
-- ====================================================================================== --

function GetPlayerKnownCultures(iPlayer)

	local kCultures = {}
	local pPlayer 	= Players[iPlayer]
	
	-- Get Cultures known from cities
	local playerCities = pPlayer:GetCities()
	if playerCities then
		for i, city in playerCities:Members() do
			local kCityPlots	= GCO.GetCityPlots(city)
			for _,plotID in pairs(kCityPlots) do
				local pPlot = GCO.GetPlotByIndex(plotID)
				for cultureKey, value in pairs (pPlot:GetCulturePercentTable()) do
					if kCultures[cultureKey] == nil then
						kCultures[cultureKey] = {}
					end
					if value > 10 then
						kCultures[cultureKey].InCities = true
					end
				end
			end
		end
	end
	
	-- Get Cultures known from Villages
	local kVillages = GCO.GetPlayerTribalVillages(iPlayer)
	for _, plotKey in ipairs(kVillages) do
		local pPlot = GCO.GetPlotByIndex(tonumber(plotKey))
		for cultureKey, value in pairs(pPlot:GetCulturePercentTable()) do
			if kCultures[cultureKey] == nil then
				kCultures[cultureKey] = {}
			end
			if value > 10 then
				kCultures[cultureKey].InVillages = true
			end
		end
	end
	
	-- Get Cultures known from units
	local pPlayerUnits = pPlayer:GetUnits()
	for i, pUnit in pPlayerUnits:Members() do
		GCO.AttachUnitFunctions(pUnit)
		local kUnitCultures = pUnit:GetValue("CulturePercents") or {}
		for cultureKey, value in pairs (kUnitCultures) do
			if kCultures[cultureKey] == nil then
				kCultures[cultureKey] = {}
			end
			if value > 10 then
				kCultures[cultureKey].InUnits = true
			end
		end
	end
	
	-- Get Cultures known from Interests
	local kInterests = GetCultureInterests(cultureID)
	for cultureKey, value in pairs (kInterests) do
		if kCultures[cultureKey] == nil then
			kCultures[cultureKey] = {}
		end
	end
	
	-- Get Cultures known from Relations
	local kRelations = GetCultureRelations(cultureID)
	for cultureKey, value in pairs (kRelations) do
		if kCultures[cultureKey] == nil then
			kCultures[cultureKey] = {}
		end
	end
	
	return kCultures
end

function PlayerDiplomacyTurn( playerID )
	GCO.Monitor(PlayerDiplomacyTurnP, {playerID}, "Diplomacy Turn Player#".. tostring(playerID))
end

function PlayerDiplomacyTurnP(iPlayer)

	local pPlayer 		= GCO.GetPlayer(iPlayer)
	local playerConfig	= PlayerConfigurations[iPlayer]
	local cultureID		= GCO.GetCultureIDFromPlayerID(iPlayer)
	local kCultures		= GetPlayerKnownCultures(iPlayer)
	
	Dprint( DEBUG_DIPLOMACY_SCRIPT, GCO.Separator)
	Dprint( DEBUG_DIPLOMACY_SCRIPT, "Do Diplomacy Turn for "..Locale.Lookup(playerConfig:GetCivilizationShortDescription()).." player#"..tostring(iPlayer) .." culture#"..tostring(cultureID))

	--
	for cultureKey, data in pairs(kCultures) do
	
		local OtherCultureID = tonumber(cultureKey)
		
		Dprint( DEBUG_DIPLOMACY_SCRIPT, "- Update Diplomacy with "..Locale.Lookup(GameInfo.CultureGroups[OtherCultureID].Name).." player#"..tostring(GCO.GetPlayerIDFromCultureID(OtherCultureID)) .." culture#"..tostring(cultureKey))
		
		--
		-- update and apply decay		
		--
		UpdateInterestTypes(cultureID, OtherCultureID)
		UpdateRelationTypes(cultureID, OtherCultureID)
		
		--
		-- set Relation modifiers
		--
		
		-- "Brothers in Arms"
		if data.InUnits then
			SetRelationModifier(cultureID, OtherCultureID, "RELATION_MODIFIER_BROTHERS_IN_ARMS")
		end
		
		-- Balance modifier
		local balance = math.ceil(GetCultureRelationValue(cultureID, OtherCultureID) * 0.1)
		SetRelationModifier(cultureID, OtherCultureID, "RELATION_MODIFIER_BALANCE", -balance)
		
		-- Nation Interest Modifier
		local interestModifier = math.ceil(GetCultureInterestValue(OtherCultureID, cultureID) * 0.065) -- it's Culture2 interests with Culture1 that we want to get here
		SetRelationModifier(cultureID, OtherCultureID, "RELATION_MODIFIER_NATION_INTERESTS", interestModifier)
		
		-- Separatists ?
		if cultureKey == SEPARATIST_CULTURE then
			SetRelationModifier(cultureID, OtherCultureID, "RELATION_MODIFIER_SEPARATIST")
		end
		
		-- nationalist ?
		if OtherCultureID == cultureID then
			SetRelationModifier(cultureID, OtherCultureID, "RELATION_MODIFIER_NATIONALIST")
		end
		
		-- foreigners ?
		if OtherCultureID ~= cultureID and cultureKey ~= INDEPENDENT_CULTURE then
			SetRelationModifier(cultureID, OtherCultureID, "RELATION_MODIFIER_FOREIGN")
		end
		

		--
		-- get and apply relation variation
		--
		local relationVariation = GetRelationVariation(cultureID, OtherCultureID)
		ChangeCultureRelationValue(cultureID, OtherCultureID, relationVariation)
		
		Dline("Culture Relation Value = ", GetCultureRelationValue(cultureID, OtherCultureID))
		
		--
		-- debugging
		--
		local kInterestTypes = GetInterestTypes(cultureID, OtherCultureID)
		local kRelationTypes = GetRelationTypes(cultureID, OtherCultureID)
		
		Dline("kInterestTypes")
		for interestKey, value in pairs(kInterestTypes) do
			local interestType = tonumber(interestKey)
			Dline(" - ",Indentation(Locale.Lookup(GameInfo.DiplomacyInterestModifiers[interestType].Name),15)..tostring(value))
		end

		Dline("kInterestTypes (other culture)")
		for interestKey, value in pairs(GetInterestTypes(OtherCultureID, cultureID)) do
			local interestType = tonumber(interestKey)
			Dline(" - ",Indentation(Locale.Lookup(GameInfo.DiplomacyInterestModifiers[interestType].Name),15)..tostring(value))
		end
		
		Dline("kRelationTypes")
		for relationKey, value in pairs(kRelationTypes) do
			local relationType = tonumber(relationKey)
			Dline(" - ",Indentation(Locale.Lookup(GameInfo.CultureRelationModifiers[relationType].Name),15)..tostring(value))
		end
	
	end
	
	-- Check Treaties
	--
	
	
	-- Check Units
	local pPlayerUnits = pPlayer:GetUnits()
	for i, pUnit in pPlayerUnits:Members() do
		GCO.AttachUnitFunctions(pUnit)		
		
		if pUnit:GetValue("UnitPersonnelType") == UnitPersonnelType.Mercenary then
			if pUnit:GetValue("ActiveTurnsLeft") < 0 then
				if iPlayer ~= iPeaceBarbarian then
					-- Mercenary Units are not immediatly hostile
					local pNewUnit = PacifyUnit(pUnit, pUnit:GetValue("PreviousOwner"), iMercenaryTruceBaseTurn)
					if pNewUnit then
						pNewUnit:SetValue("LastEmploymentEndTurn", Game.GetCurrentGameTurn())
					end
				else
					-- Pacified units are disbanded after a few turn
					DisbandMercenary(pUnit)
				end
			else
				--
				if iPlayer == iPeaceBarbarian then
					-- how to maintain temporary visibility ?
					--local iLastEmployer = pUnit:GetValue("LastEmployer")
					--local pEmployerVis 	= PlayerVisibilityManager.GetPlayerVisibility(iLastEmployer)
				end			
			end
		end
	end

	-- 

	Dprint( DEBUG_DIPLOMACY_SCRIPT, "- End Diplomacy Turn for "..Locale.Lookup(playerConfig:GetCivilizationShortDescription()).." player#"..tostring(iPlayer))
end

function UpdateDiplomacy()

	Dprint( DEBUG_DIPLOMACY_SCRIPT, GCO.Separator)
	Dprint( DEBUG_DIPLOMACY_SCRIPT, "UPDATE DIPLOMACY <<<<<<<<<<")
	
	-- non-player diplo
	for _, cultureID in ipairs(GetNonPlayerCultures()) do
	
		Dprint( DEBUG_DIPLOMACY_SCRIPT, GCO.Separator)
		Dprint( DEBUG_DIPLOMACY_SCRIPT, "Do Diplomacy Turn for non-player Culture : ".. Locale.Lookup(GameInfo.CultureGroups[cultureID].Name) ..", culture#"..tostring(cultureID))
		local kInterests 	= GetCultureInterests(cultureID)
		local kRelations 	= GetCultureRelations(cultureID) -- relation have no usage for non-player, but should we update anyway, as they may get player-controlled at some point ?
		
		Dline("kInterests", kInterests)
		for cultureKey, kInterestTypes in pairs(kInterests) do
		
			local OtherCultureID = tonumber(cultureKey)
			Dprint( DEBUG_DIPLOMACY_SCRIPT, "- Update Interests with "..Locale.Lookup(GameInfo.CultureGroups[OtherCultureID].Name).." player#"..tostring(GCO.GetPlayerIDFromCultureID(OtherCultureID)) .." culture#"..tostring(cultureKey))
			
			UpdateInterestTypes(cultureID, OtherCultureID)
			
			for interestKey, value in pairs(kInterestTypes) do
				local interestType = tonumber(interestKey)
				Dline(Indentation(Locale.Lookup(GameInfo.DiplomacyInterestModifiers[interestType].Name),15)..tostring(value))
			end
		end
		
		Dline("kRelations", kRelations)
		for cultureKey, kRelationTypes in pairs(kRelations) do
		
			local OtherCultureID = tonumber(cultureKey)
			Dprint( DEBUG_DIPLOMACY_SCRIPT, "- Update Relations with "..Locale.Lookup(GameInfo.CultureGroups[OtherCultureID].Name).." player#"..tostring(GCO.GetPlayerIDFromCultureID(OtherCultureID)) .." culture#"..tostring(cultureKey))
			
			UpdateAllRelationModifiers(cultureID, OtherCultureID)
			
			for relationKey, value in pairs(kRelationTypes) do
				local relationType = tonumber(relationKey)
				Dline(Indentation(Locale.Lookup(GameInfo.CultureRelationModifiers[relationType].Name),15)..tostring(value))
			end
		end
		
	end
	
	Dprint( DEBUG_DIPLOMACY_SCRIPT, "UPDATE DIPLOMACY >>>>>>>>>>")
end

--=====================================================================================--
-- Deals Functions
--=====================================================================================--
function IsDealValid(kParameters, row)		-- kParameters from UI call, row from <DiplomaticDealsGCO>

	if (kParameters.UnitID == nil and row.IsUnit) or (kParameters.UnitID and not row.IsUnit) then return false end
	
	if kParameters.UnitID then
	
		if kParameters.PlayerID == kParameters.ActorID then
			-- Only renew contract is available for own units
			if row.DealType ~= "DIPLO_DEAL_RENEW_SINGLE_UNIT" then
				return false
			end
		end
		
		local pUnit = GCO.GetUnit(kParameters.PlayerID, kParameters.UnitID)
		if pUnit then
			local bIsCivilian = GameInfo.Units[pUnit:GetType()].FormationClass == "FORMATION_CLASS_CIVILIAN"
			
			if bIsCivilian then
				if not row.IsCivilian then
					return false
				end
				if row.DealType == "DIPLO_DEAL_PAY_UNIT_RANSOM" then
					if pUnit:GetOwner() == pUnit:GetOriginalOwner() then
						return false
					end
				end
				
			elseif row.IsCivilian then
				return false
				
			elseif row.DealType == "DIPLO_DEAL_RECRUIT_SINGLE_UNIT" then
				if pUnit:GetValue("LastEmployer") == kParameters.ActorID and pUnit:GetValue("LastEmploymentEndTurn") >= Game.GetCurrentGameTurn() - iMercenaryContractExpire then
					-- no need to show the new contract option when renewing is available
					return false
				end
			end
		end
	end
	
	return true
	
end

function IsDealEnabled(kParameters, row)	-- kParameters from UI call, row from <DiplomaticDealsGCO>

	-- Check cost
	local cost = row.Cost or GetDealValue(kParameters, row)
	if cost > 0 then
	
		local playerID 	= kParameters.Sell and kParameters.PlayerID or kParameters.ActorID
		local pPlayer	= GCO.GetPlayer(playerID)
		local treasury	= pPlayer:GetTreasury():GetGoldBalance()
		
		if cost > treasury then
			return false, Locale.Lookup("LOC_DIPLOMACY_NO_TREASURY_FOR_DEAL", cost-treasury )
		end	
	end
	
	
	if row.IsUnit and kParameters.UnitID then
		local pUnit = GCO.GetUnit(kParameters.PlayerID, kParameters.UnitID)
		local pPlot	= Map.GetPlot(pUnit:GetX(), pUnit:GetY())
		if Units.GetUnitCountInPlot(pPlot) > 1 then
		
			local tUnits = Units.GetUnitsInPlot(pPlot)
			for i, pOtherUnit in ipairs(tUnits) do
				if pOtherUnit:GetOwner() ~= kParameters.ActorID and not (pOtherUnit:GetOwner() == kParameters.PlayerID and pOtherUnit:GetID() == pUnit:GetID()) then
					return false, Locale.Lookup("LOC_DIPLOMACY_NO_DEAL_MULTIPLE_UNITS")
				end
			end
		end
		
		local improvementRow	= GameInfo.Improvements[pPlot:GetImprovementType()]
		if improvementRow and (GCO.IsTribeImprovement(pPlot:GetImprovementType()) or improvementRow.BarbarianCamp or improvementRow.Goody or improvementRow.ImprovementType == "IMPROVEMENT_FORT") and pPlot:GetImprovementOwner() ~= kParameters.ActorID then
			return false, Locale.Lookup("LOC_DIPLOMACY_NO_DEAL_GARRISON_UNIT")
		end
		
		local plotOwner = pPlot:GetOwner()
		if plotOwner ~= NO_OWNER and plotOwner ~= kParameters.ActorID then
			local pActor = GCO.GetPlayer(kParameters.ActorID)
			if not pActor:HasOpenBordersFrom(kParameters.PlayerID) then
				return false, Locale.Lookup("LOC_DIPLOMACY_NO_DEAL_CLOSED_BORDER_UNIT")
			end
		end
		
		-- Renewing Contract only for Units with last employer being the deal actor
		if row.DealType == "DIPLO_DEAL_RENEW_SINGLE_UNIT" then
			if pUnit:GetValue("LastEmployer") ~= kParameters.ActorID then
				return false, Locale.Lookup("LOC_DIPLOMACY_NO_DEAL_NOT_LAST_EMPLOYER_UNIT")
			elseif not (kParameters.PlayerID == kParameters.ActorID) and pUnit:GetValue("LastEmploymentEndTurn") and pUnit:GetValue("LastEmploymentEndTurn") < Game.GetCurrentGameTurn() - iMercenaryContractExpire then
				return false, Locale.Lookup("LOC_DIPLOMACY_NO_DEAL_EXPIRED_CONTRACT_UNIT", Game.GetCurrentGameTurn() - (iMercenaryContractExpire+pUnit:GetValue("LastEmploymentEndTurn")))
			end
		end
		
	end
	
	-- check AI agreement
	--
	return true
	
end

function GetDealValue(kParameters, row)

	local dealValue 	= row.BaseValue or 0
	local treasury		= 0
	
	-- Some Deals are proportionnal to the Actor Treasury
	if row.IsValueRelative then
		local pPlayer	= GCO.GetPlayer(kParameters.ActorID)
		treasury		= pPlayer:GetTreasury():GetGoldBalance()
		if treasury > 0 then
			dealValue	= dealValue + (treasury * fDealTreasuryCostRatio)
		end
	end
Dline("GetDealValue, actorID, treasury, dealValue", kParameters.ActorID, treasury, dealValue)
	
	-- Special cases when dealing with units
	if row.IsUnit and kParameters.UnitID then
		local pUnit = GCO.GetUnit(kParameters.PlayerID, kParameters.UnitID)
		if pUnit then
			-- Recruiting is based on construction cost
			if row.DealType == "DIPLO_DEAL_RECRUIT_SINGLE_UNIT" or row.DealType == "DIPLO_DEAL_RENEW_SINGLE_UNIT" then
				local cost	= GameInfo.Units[pUnit:GetType()].Cost
				dealValue	= dealValue + cost
			end
			
			-- Ransom cost more if you're not the original unit owner
			if row.DealType == "DIPLO_DEAL_PAY_UNIT_RANSOM" then
			
				local baseCost		= GameInfo.Units[pUnit:GetType()].Cost
				local bOwnPeople	= kParameters.ActorID == pUnit:GetOriginalOwner()
				
				baseCost 	= bOwnPeople and baseCost or baseCost * fRansomOtherOwnerFactor
				dealValue 	= (dealValue + baseCost)
				
				if pUnit:GetBuildCharges() > 0 then
					local maxBuildCharges	= GameInfo.Units[pUnit:GetType()].BuildCharges
					local ratio				= Div(pUnit:GetBuildCharges(), maxBuildCharges)
					dealValue				= dealValue * ratio
				end
			end
			
			-- In all case a damaged unit can't claim a full payment
			if pUnit:GetDamage() > 0 then
				local ratio = Div(pUnit:GetMaxDamage()-pUnit:GetDamage(), pUnit:GetMaxDamage())
				dealValue	= dealValue * ratio
			end
		end
	end
	return math.ceil(dealValue)
end

function CanOpenDiplomacy(kParameters)

	if kParameters.UnitID then
	
		if kParameters.PlayerID == kParameters.ActorID then
			-- open panel of own units only for Mercenary units (to renew contracts)
			local pUnit = GCO.GetUnit(kParameters.PlayerID, kParameters.UnitID)
			if pUnit and pUnit:GetValue("UnitPersonnelType") ~= UnitPersonnelType.Mercenary then
				return false
			end			
		else
			-- for now only negociate with Tribes units (to do : Loyalty)
			local playerConfig = PlayerConfigurations[kParameters.PlayerID]
			if playerConfig then
				if playerConfig:GetCivilizationLevelTypeName() ~= "CIVILIZATION_LEVEL_TRIBE" then
					return false
				end
			end
		end
	end
	--
	return true
end


-- ====================================================================================== --
-- Units functions
-- ====================================================================================== --

function RecruitUnit(pUnit, iPreviousOwner, iNewOwner, iDuration)
	local newUnit = GCO.ChangeUnitTo(pUnit, pUnit:GetType(), iNewOwner)
	
	newUnit:SetValue("CanChangeOrganization", nil)
	newUnit:SetValue("PreviousActiveTurnsLeft", newUnit:GetValue("ActiveTurnsLeft"))
	newUnit:SetValue("ActiveTurnsLeft", iDuration)
	newUnit:SetValue("UnitPersonnelType", UnitPersonnelType.Mercenary)
	newUnit:SetValue("PreviousOwner", iPreviousOwner)
	newUnit:SetValue("LastEmployer", iNewOwner)
	
	return newUnit
end

function LiberateUnit(pUnit, iNewOwner)

	local iPreviousOwner	= pUnit:GetOriginalOwner() -- old owner before capture
	local newUnit 			= GCO.ChangeUnitTo(pUnit, pUnit:GetType(), iNewOwner)
	
	newUnit:SetValue("CanChangeOrganization", true)
	--newUnit:SetValue("ActiveTurnsLeft", newUnit:GetValue("PreviousActiveTurnsLeft"))
	newUnit:SetValue("UnitPersonnelType", UnitPersonnelType.StandingArmy)
	newUnit:SetValue("PreviousOwner", iPreviousOwner)
	
	return newUnit
end

function PacifyUnit(pUnit, iPreviousOwner, iDuration)
	Dprint( DEBUG_DIPLOMACY_SCRIPT, "- PacifyUnit, give to player#"..tostring(iPeaceBarbarian))
	local newUnit = GCO.ChangeUnitTo(pUnit, pUnit:GetType(), iPeaceBarbarian)
	
	newUnit:SetValue("CanChangeOrganization", nil)
	newUnit:SetValue("PreviousActiveTurnsLeft", newUnit:GetValue("PreviousActiveTurnsLeft") or newUnit:GetValue("ActiveTurnsLeft"))
	newUnit:SetValue("ActiveTurnsLeft", iDuration)
	newUnit:SetValue("UnitPersonnelType", UnitPersonnelType.Mercenary)
	newUnit:SetValue("PreviousOwner", iPreviousOwner)
	
	return newUnit
end

function DisbandMercenary(pUnit)
	local newUnit = GCO.ChangeUnitTo(pUnit, pUnit:GetType(), pUnit:GetValue("PreviousOwner"))
	
	newUnit:SetValue("CanChangeOrganization", true)
	newUnit:SetValue("ActiveTurnsLeft", newUnit:GetValue("PreviousActiveTurnsLeft"))
	newUnit:SetValue("UnitPersonnelType", UnitPersonnelType.StandingArmy)
end

-- ====================================================================================== --
-- Handle Player Commands
-- ====================================================================================== --

function OnPlayerDealAction(iActor : number, kParameters : table)

	local DEBUG_DIPLOMACY_SCRIPT = "debug"
	
	Dprint( DEBUG_DIPLOMACY_SCRIPT, "- OnPlayerDealAction...")
	Dprint( DEBUG_DIPLOMACY_SCRIPT, iActor, kParameters.DiplomacyType, kParameters.DealType, kParameters.Text, kParameters.PlayerID, kParameters.UnitID)

	kParameters.ActorID = iActor
	local row 			= GameInfo.DiplomaticDealsGCO[kParameters.DealType]
	
	if IsDealValid(kParameters, row) and IsDealEnabled(kParameters, row) then
	
		local dealValue = GetDealValue(kParameters, row)
	
		if kParameters.DealType == "DIPLO_DEAL_RECRUIT_SINGLE_UNIT" then
		
			Dprint( DEBUG_DIPLOMACY_SCRIPT, " - Recruiting Single Unit...")
			local pPlayer	= GCO.GetPlayer(iActor)
			local pUnit 	= GCO.GetUnit(kParameters.PlayerID, kParameters.UnitID)
			RecruitUnit(pUnit, kParameters.PlayerID, iActor, row.Duration)
			pPlayer:ProceedTransaction(AccountType.Recruit, -dealValue)
			return
			
		end
		
		if kParameters.DealType == "DIPLO_DEAL_RENEW_SINGLE_UNIT" then
		
			Dprint( DEBUG_DIPLOMACY_SCRIPT, " - Renewing Single Unit Contract...")
			local pPlayer	= GCO.GetPlayer(iActor)
			local pUnit 	= GCO.GetUnit(kParameters.PlayerID, kParameters.UnitID)
			local iTurnLeft	= kParameters.PlayerID == iActor and pUnit:GetValue("ActiveTurnsLeft") or 0
			RecruitUnit(pUnit, pUnit:GetValue("PreviousOwner"), iActor, row.Duration + iTurnLeft) -- previous owner is the original Civ here
			pPlayer:ProceedTransaction(AccountType.Recruit, -dealValue)
			return
			
		end
		
		if kParameters.DealType == "DIPLO_DEAL_BRIBE_SINGLE_UNIT" then
		
			Dprint( DEBUG_DIPLOMACY_SCRIPT, " - Bribing Single Unit...")
			local pPlayer	= GCO.GetPlayer(iActor)
			local pUnit 	= GCO.GetUnit(kParameters.PlayerID, kParameters.UnitID)
			local iTurnLeft	= kParameters.PlayerID == iPeaceBarbarian and pUnit:GetValue("ActiveTurnsLeft") or 0
			PacifyUnit(pUnit, kParameters.PlayerID, row.Duration)
			pPlayer:ProceedTransaction(AccountType.Recruit, -dealValue)
			return
			
		end
		
		if kParameters.DealType == "DIPLO_DEAL_PAY_UNIT_RANSOM" then
		
			Dprint( DEBUG_DIPLOMACY_SCRIPT, " - Paying Unit Ransom...")
			local pPlayer	= GCO.GetPlayer(iActor)
			local pUnit = GCO.GetUnit(kParameters.PlayerID, kParameters.UnitID)
			LiberateUnit(pUnit, iActor)
			pPlayer:ProceedTransaction(AccountType.Recruit, -dealValue)
			return
			
		end
	
	else
		GCO.Error("OnPlayerDealAction called with invalid or disabled Deal[NEWLINE]DealType: ".. tostring(kParameters.DealType).."[NEWLINE]PlayerID: "..tostring(kParameters.PlayerID) .."[NEWLINE]ActorID: "..tostring(iActor))
		print("IsDealValid(kParameters, row)", IsDealValid(kParameters, row))
		print("IsDealEnabled(kParameters, row)", IsDealEnabled(kParameters, row))
		print("kParameters")
		GCO.Dump(kParameters)
		print("row")
		GCO.Dump(row)
		-- Debug
		for i = 1, 63 do
		
			local player 	= Players[i]
			local treasury 	= player and player:GetTreasury()
			if treasury then
				print("treasury player#", i, " = ", treasury:GetGoldBalance())
			end
		end
		--
	end
	
end
GameEvents.PlayerDealAction.Add(OnPlayerDealAction)


--=====================================================================================--
-- Initialize script
--=====================================================================================--
function Initialize()
	
	if not ExposedMembers.GCO then ExposedMembers.GCO = {} end
	--
	ExposedMembers.GCO.GetCultureRelationIcon	= GetCultureRelationIcon
	-- 
	ExposedMembers.GCO.IsDealValid 				= IsDealValid
	ExposedMembers.GCO.IsDealEnabled			= IsDealEnabled
	ExposedMembers.GCO.GetDealValue				= GetDealValue
	ExposedMembers.GCO.CanOpenDiplomacy			= CanOpenDiplomacy
	--
	ExposedMembers.GCO.UpdateDiplomacy			= UpdateDiplomacy
	
end
Initialize()

--[[

-- Open borders (10 turns)

	DealManager.ClearWorkingDeal(DealDirection.OUTGOING, fromPlayerID, toPlayerID);
	local pDeal = DealManager.GetWorkingDeal(DealDirection.OUTGOING, fromPlayerID, toPlayerID);
	if pDeal then
		pDealItem = pDeal:AddItemOfType(DealItemTypes.AGREEMENTS, fromPlayerID);
		if pDealItem then
			pDealItem:SetSubType(DealAgreementTypes.OPEN_BORDERS);
			pDealItem:SetValueType(-1);
			pDealItem:SetFromPlayerID(fromPlayerID);
			pDealItem:SetToPlayerID(toPlayerID);
			pDealItem:SetDuration(10);
			pDealItem:SetLocked(true);
		end
		pDeal:Validate();
		DealManager.EnactWorkingDeal(fromPlayerID, toPlayerID);
	end
	

-- Close borders

	DealManager.ClearWorkingDeal(DealDirection.OUTGOING, fromPlayerID, toPlayerID);
	local pDeal = DealManager.GetWorkingDeal(DealDirection.OUTGOING, fromPlayerID, toPlayerID);
	if pDeal then
		pDealItem = pDeal:AddItemOfType(DealItemTypes.AGREEMENTS, fromPlayerID);
		if pDealItem then
			pDealItem:SetSubType(DealAgreementTypes.OPEN_BORDERS);
			pDealItem:SetValueType(-1);
			pDealItem:SetFromPlayerID(fromPlayerID);
			pDealItem:SetToPlayerID(toPlayerID);
			pDealItem:SetDuration(0);
			pDealItem:SetLocked(true);
		end
		pDeal:Validate();
		DealManager.EnactWorkingDeal(fromPlayerID, toPlayerID);
	end
	
-- Make Alliance


	DealManager.ClearWorkingDeal(DealDirection.OUTGOING, fromPlayerID, toPlayerID);
	local pDeal = DealManager.GetWorkingDeal(DealDirection.OUTGOING, fromPlayerID, toPlayerID);
	if pDeal then
		pDealItem = pDeal:AddItemOfType(DealItemTypes.AGREEMENTS, fromPlayerID);
		if pDealItem then
			pDealItem:SetSubType(DealAgreementTypes.ALLIANCE);
			pDealItem:SetValueType(DB.MakeHash("ALLIANCE_MILITARY"));
			pDealItem:SetLocked(true);
		end
		pDeal:Validate();
		DealManager.EnactWorkingDeal(fromPlayerID, toPlayerID);
	end



--]]