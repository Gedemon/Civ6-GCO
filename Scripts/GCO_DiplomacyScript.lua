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
local fRansomOtherOwnerFactor	= tonumber(GameInfo.GlobalParameters["DIPLO_RANSOM_OTHER_OWNER_FACTOR"].Value) or 1.5
local iMercenaryTruceBaseTurn	= tonumber(GameInfo.GlobalParameters["DIPLO_MERCENARY_TRUCE_BASE_TURN"].Value) or 3

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
	
	LuaEvents.DoDiplomacyTurn.Add( PlayerDiplomacyTurn )
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

function GetDiploKey(iPlayer1, iPlayer2)	-- We save player to player deals/treaty table in one entry, using a "lowerID,higherID" unique key
	return iPlayer1 < iPlayer2 and tostring(iPlayer1)..","..tostring(iPlayer2) or tostring(iPlayer2)..","..tostring(iPlayer1)
end

function GetPlayerIDsFromKey(diploKey :string)
	return diploKey:match("([^,]+),([^,]+)") -- return iPlayer1, iPlayer2
end

--
-- DiplomacyTypes.Deals, DiplomacyTypes.Treaties, DiplomacyTypes.State
function GetPlayersDiplomacy(iPlayer1, iPlayer2, diplomacyType)

	local diploKey 		= GetDiploKey(iPlayer1, iPlayer2)
	local kDiploType	= GetValue(diplomacyType) or {}
	
	return kDiploType[diploKey] or {}
end


--=====================================================================================--
-- Initialize Diplomacy Function
--=====================================================================================--
function SetInitialDiplomacy()

	if Game:GetProperty("DiplomacyInitialized") then -- only called once
		return
	end
	
	-- Make the alternate Barbarian Tribe at peace with every players
	-- Bribed Units will be given to it for the duration of the bribe 
	--[[
	local pPeaceBarb 	= Players[iPeaceBarbarian]
	local pDiplo		= pPeaceBarb:GetDiplomacy()
	if pDiplo then
		for iPlayer = 0, PlayerManager.GetWasEverAliveCount() - 1 do
			if iPlayer ~= iPeaceBarbarian then
				pDiplo:MakePeaceWith(iPlayer, true)
				pDiplo:SetHasMet(iPlayer)
			end
		end
	end
	--]]
	for iPlayer = 0, PlayerManager.GetWasEverAliveCount() - 1 do
		if iPlayer ~= iPeaceBarbarian then
			local pPlayer	= Players[iPlayer]
			local pDiplo 	= pPlayer and pPlayer:GetDiplomacy()
			if pDiplo then
				Dprint( DEBUG_DIPLOMACY_SCRIPT, "- Initialize Diplomacy between players #"..tostring(iPeaceBarbarian).." and #"..tostring(iPlayer))
				pDiplo:MakePeaceWith(iPeaceBarbarian, true)
				pDiplo:SetHasMet(iPeaceBarbarian)
			end
		end
	end
	Game:SetProperty("DiplomacyInitialized", 1);
end

function InitializeDiplomacyCache()

end

--=====================================================================================--
-- Deals Functions
--=====================================================================================--
function IsDealValid(kParameters, row)		-- kParameters from UI call, row from <DiplomaticDealsGCO>

	if (kParameters.UnitID == nil and row.IsUnit) or (kParameters.UnitID and not row.IsUnit) then return false end
	
	if kParameters.UnitID then
		
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
			return false, Locale.Lookup("LOC_DIPLOMACY_NO_DEAL_MULTIPLE_UNITS")
		end
		
		local improvementRow	= GameInfo.Improvements[pPlot:GetImprovementType()]
		if improvementRow and (improvementRow.BarbarianCamp or improvementRow.Goody or improvementRow.ImprovementType == "IMPROVEMENT_FORT") then
			return false, Locale.Lookup("LOC_DIPLOMACY_NO_DEAL_GARRISON_UNIT")
		end
	end
	
	-- check AI agreement
	--
	return true
	
end

function GetDealValue(kParameters, row)

	local dealValue = row.BaseValue or 0
	
	if row.IsUnit and kParameters.UnitID then
		local pUnit = GCO.GetUnit(kParameters.PlayerID, kParameters.UnitID)
		if pUnit then
			-- Recruiting is based on construction cost
			if row.DealType == "DIPLO_DEAL_RECRUIT_SINGLE_UNIT" then
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
	
		-- for now only negociate with Tribes units (to do : Loyalty)
		local playerConfig = PlayerConfigurations[kParameters.PlayerID]
		if playerConfig then
			if playerConfig:GetCivilizationLevelTypeName() ~= "CIVILIZATION_LEVEL_TRIBE" then
				return false
			end
		end
	end
	--
	return true
end


function PlayerDiplomacyTurn(iPlayer)

	local pPlayer 		= GCO.GetPlayer(iPlayer)
	local playerConfig	= PlayerConfigurations[iPlayer]
	
	Dprint( DEBUG_DIPLOMACY_SCRIPT, "- Do Diplomacy Turn for "..Locale.Lookup(playerConfig:GetCivilizationShortDescription()).." player#"..tostring(iPlayer))

	-- Check Treaties
	
	-- Check Units
	local pPlayerUnits = pPlayer:GetUnits()
	for i, pUnit in pPlayerUnits:Members() do
		GCO.AttachUnitFunctions(pUnit)
		if pUnit:GetValue("UnitPersonnelType") == UnitPersonnelType.Mercenary and pUnit:GetValue("ActiveTurnsLeft") < 0 then
			if iPlayer ~= iPeaceBarbarian then
				-- Mercenary Units are not immediatly hostile
				PacifyUnit(pUnit, pUnit:GetValue("PreviousOwner"), iMercenaryTruceBaseTurn)
			else
				-- Pacified units are disbanded after a few turn
				DisbandMercenary(pUnit)
			end
		end
	end
end


-- ====================================================================================== --
-- Units functions
-- ====================================================================================== --

function RecruitUnit(pUnit, iPreviousOwner, iNewOwner, iDuration)
	local newUnit = GCO.ChangeUnitTo(pUnit, pUnit:GetType(), iNewOwner)
	
	newUnit:SetValue("CanChangeOrganization", nil)
	newUnit:SetValue("ActiveTurnsLeft", iDuration)
	newUnit:SetValue("UnitPersonnelType", UnitPersonnelType.Mercenary)
	newUnit:SetValue("PreviousOwner", iPreviousOwner)
end

function LiberateUnit(pUnit, iNewOwner)

	local iPreviousOwner	= pUnit:GetOriginalOwner() -- old owner before capture
	local newUnit 			= GCO.ChangeUnitTo(pUnit, pUnit:GetType(), iNewOwner)
	
	newUnit:SetValue("CanChangeOrganization", true)
	newUnit:SetValue("ActiveTurnsLeft", nil)
	newUnit:SetValue("UnitPersonnelType", UnitPersonnelType.StandingArmy)
	newUnit:SetValue("PreviousOwner", iPreviousOwner)
end

function PacifyUnit(pUnit, iPreviousOwner, iDuration)
	Dprint( DEBUG_DIPLOMACY_SCRIPT, "- PacifyUnit, give to player#"..tostring(iPeaceBarbarian))
	local newUnit = GCO.ChangeUnitTo(pUnit, pUnit:GetType(), iPeaceBarbarian)
	
	newUnit:SetValue("CanChangeOrganization", nil)
	newUnit:SetValue("ActiveTurnsLeft", iDuration)
	newUnit:SetValue("UnitPersonnelType", UnitPersonnelType.Mercenary)
	newUnit:SetValue("PreviousOwner", iPreviousOwner)
end

function DisbandMercenary(pUnit)
	local newUnit = GCO.ChangeUnitTo(pUnit, pUnit:GetType(), pUnit:GetValue("PreviousOwner"))
	
	newUnit:SetValue("CanChangeOrganization", true)
	newUnit:SetValue("ActiveTurnsLeft", nil)
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
		
		if kParameters.DealType == "DIPLO_DEAL_BRIBE_SINGLE_UNIT" then
		
			Dprint( DEBUG_DIPLOMACY_SCRIPT, " - Bribing Single Unit...")
			local pPlayer	= GCO.GetPlayer(iActor)
			local pUnit 	= GCO.GetUnit(kParameters.PlayerID, kParameters.UnitID)
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
	end
	
end
GameEvents.PlayerDealAction.Add(OnPlayerDealAction)


--=====================================================================================--
-- Initialize script
--=====================================================================================--
function Initialize()
	
	if not ExposedMembers.GCO then ExposedMembers.GCO = {} end
	-- 
	ExposedMembers.GCO.IsDealValid 				= IsDealValid
	ExposedMembers.GCO.IsDealEnabled			= IsDealEnabled
	ExposedMembers.GCO.GetDealValue				= GetDealValue
	ExposedMembers.GCO.CanOpenDiplomacy			= CanOpenDiplomacy
	
end
Initialize()