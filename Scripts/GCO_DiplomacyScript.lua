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
	
	
	
	-- Make the "Peaceful Barbs" Tribe at peace with every players
	-- Pacified Units will be given to it for the duration of the pacification
	-- Other Tribes start at war with each others
--if GCO.Network.IsGameHost() then -- debug
	for iPlayer = 0, 63 do --PlayerManager.GetWasEverAliveCount() - 1 do
		if iPlayer ~= iPeaceBarbarian then
			local pPlayer	= Players[iPlayer]
			local pDiplo 	= pPlayer and pPlayer:GetDiplomacy()
			if pDiplo then
				Dprint( DEBUG_DIPLOMACY_SCRIPT, "- Initialize Diplomacy for player#"..tostring(iPlayer))

	Dline(pDiplo:IsAtWarWith( iPeaceBarbarian ))
				if pDiplo:IsAtWarWith( iPeaceBarbarian ) then
	Dline()
					pDiplo:MakePeaceWith(iPeaceBarbarian, true)
	Dline()
				end
				
	Dline(not pDiplo:HasMet(iPeaceBarbarian))
				if not pDiplo:HasMet(iPeaceBarbarian) then
	Dline()
					--pDiplo:SetHasMet(iPeaceBarbarian)
	Dline()
				end
				
				for iOtherPlayer = 0, 63 do --PlayerManager.GetWasEverAliveCount() - 1 do
	Dline(iOtherPlayer)
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
--end--debug
	Game:SetProperty("DiplomacyInitialized", 1);
end
--Events.LoadScreenClose.Add(SetInitialDiplomacy);

function InitializeDiplomacyCache()

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
Dline("IsDealEnabled: player ID, treasury, cost = ", playerID, treasury, cost)		
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


function PlayerDiplomacyTurn(iPlayer)

	local pPlayer 		= GCO.GetPlayer(iPlayer)
	local playerConfig	= PlayerConfigurations[iPlayer]
	
	Dprint( DEBUG_DIPLOMACY_SCRIPT, "- Do Diplomacy Turn for "..Locale.Lookup(playerConfig:GetCivilizationShortDescription()).." player#"..tostring(iPlayer))

	-- Check Treaties
	
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
	
	Dprint( DEBUG_DIPLOMACY_SCRIPT, "- End Diplomacy Turn for "..Locale.Lookup(playerConfig:GetCivilizationShortDescription()).." player#"..tostring(iPlayer))
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
	newUnit:SetValue("LastEmployer", iNewOwner)
	
	return newUnit
end

function LiberateUnit(pUnit, iNewOwner)

	local iPreviousOwner	= pUnit:GetOriginalOwner() -- old owner before capture
	local newUnit 			= GCO.ChangeUnitTo(pUnit, pUnit:GetType(), iNewOwner)
	
	newUnit:SetValue("CanChangeOrganization", true)
	newUnit:SetValue("ActiveTurnsLeft", nil)
	newUnit:SetValue("UnitPersonnelType", UnitPersonnelType.StandingArmy)
	newUnit:SetValue("PreviousOwner", iPreviousOwner)
	
	return newUnit
end

function PacifyUnit(pUnit, iPreviousOwner, iDuration)
	Dprint( DEBUG_DIPLOMACY_SCRIPT, "- PacifyUnit, give to player#"..tostring(iPeaceBarbarian))
	local newUnit = GCO.ChangeUnitTo(pUnit, pUnit:GetType(), iPeaceBarbarian)
	
	newUnit:SetValue("CanChangeOrganization", nil)
	newUnit:SetValue("ActiveTurnsLeft", iDuration)
	newUnit:SetValue("UnitPersonnelType", UnitPersonnelType.Mercenary)
	newUnit:SetValue("PreviousOwner", iPreviousOwner)
	
	return newUnit
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
	ExposedMembers.GCO.IsDealValid 				= IsDealValid
	ExposedMembers.GCO.IsDealEnabled			= IsDealEnabled
	ExposedMembers.GCO.GetDealValue				= GetDealValue
	ExposedMembers.GCO.CanOpenDiplomacy			= CanOpenDiplomacy
	
end
Initialize()

--[[

-- Open borders (10 turns)

	DealManager.ClearWorkingDeal(DealDirection.OUTGOING, g_SelectedPlayer, g_DiplomaticPlayer);
	local pDeal = DealManager.GetWorkingDeal(DealDirection.OUTGOING, g_SelectedPlayer, g_DiplomaticPlayer);
	if pDeal then
		pDealItem = pDeal:AddItemOfType(DealItemTypes.AGREEMENTS, g_SelectedPlayer);
		if pDealItem then
			pDealItem:SetSubType(DealAgreementTypes.OPEN_BORDERS);
			pDealItem:SetValueType(-1);
			pDealItem:SetFromPlayerID(g_SelectedPlayer);
			pDealItem:SetToPlayerID(g_DiplomaticPlayer);
			pDealItem:SetDuration(10);
			pDealItem:SetLocked(true);
		end
		pDeal:Validate();
		DealManager.EnactWorkingDeal(g_SelectedPlayer, g_DiplomaticPlayer);
	end
	

-- Close borders

	DealManager.ClearWorkingDeal(DealDirection.OUTGOING, g_SelectedPlayer, g_DiplomaticPlayer);
	local pDeal = DealManager.GetWorkingDeal(DealDirection.OUTGOING, g_SelectedPlayer, g_DiplomaticPlayer);
	if pDeal then
		pDealItem = pDeal:AddItemOfType(DealItemTypes.AGREEMENTS, g_SelectedPlayer);
		if pDealItem then
			pDealItem:SetSubType(DealAgreementTypes.OPEN_BORDERS);
			pDealItem:SetValueType(-1);
			pDealItem:SetFromPlayerID(g_SelectedPlayer);
			pDealItem:SetToPlayerID(g_DiplomaticPlayer);
			pDealItem:SetDuration(0);
			pDealItem:SetLocked(true);
		end
		pDeal:Validate();
		DealManager.EnactWorkingDeal(g_SelectedPlayer, g_DiplomaticPlayer);
	end
	




--]]