--=====================================================================================--
--	FILE:	 PlayerScript.lua
--  Gedemon (2017)
--=====================================================================================--

print("Loading PlayerScript.lua...")

-----------------------------------------------------------------------------------------
-- Includes
-----------------------------------------------------------------------------------------
include( "GCO_TypeEnum" )
include( "GCO_SmallUtils" )



-----------------------------------------------------------------------------------------
-- Debug
-----------------------------------------------------------------------------------------

DEBUG_PLAYER_SCRIPT	= "PlayerScript"

function TogglePlayerDebug()
	DEBUG_PLAYER_SCRIPT = not DEBUG_PLAYER_SCRIPT
end



-----------------------------------------------------------------------------------------
-- Defines
-----------------------------------------------------------------------------------------

local _cached						= {}	-- cached table to reduce calculations
local OrganizationLevelCivics 		= {		-- Civics unlocking MilitaryOrganisationLevels
		[GameInfo.Civics["CIVIC_MILITARY_TRADITION"].Index]		= GameInfo.MilitaryOrganisationLevels["LEVEL1"].Index,
		[GameInfo.Civics["CIVIC_MILITARY_TRAINING"].Index]		= GameInfo.MilitaryOrganisationLevels["LEVEL2"].Index,
		[GameInfo.Civics["CIVIC_FEUDALISM"].Index]				= GameInfo.MilitaryOrganisationLevels["LEVEL3"].Index,
		[GameInfo.Civics["CIVIC_MERCENARIES"].Index]			= GameInfo.MilitaryOrganisationLevels["LEVEL4"].Index,
		[GameInfo.Civics["CIVIC_NATIONALISM"].Index]			= GameInfo.MilitaryOrganisationLevels["LEVEL5"].Index,
		[GameInfo.Civics["CIVIC_MOBILIZATION"].Index]			= GameInfo.MilitaryOrganisationLevels["LEVEL6"].Index,
		[GameInfo.Civics["CIVIC_COLD_WAR"].Index]				= GameInfo.MilitaryOrganisationLevels["LEVEL7"].Index,
		[GameInfo.Civics["CIVIC_RAPID_DEPLOYMENT"].Index]		= GameInfo.MilitaryOrganisationLevels["LEVEL8"].Index,
}
local OrganizationLevelToSmaller 	= {		-- MilitaryOrganisationLevel to use when the Smaller Units Policy is active
		[GameInfo.MilitaryOrganisationLevels["LEVEL1"].Index]		= GameInfo.MilitaryOrganisationLevels["LEVEL1B"].Index,
		[GameInfo.MilitaryOrganisationLevels["LEVEL2"].Index]		= GameInfo.MilitaryOrganisationLevels["LEVEL2B"].Index,
		[GameInfo.MilitaryOrganisationLevels["LEVEL3"].Index]		= GameInfo.MilitaryOrganisationLevels["LEVEL3B"].Index,
		[GameInfo.MilitaryOrganisationLevels["LEVEL4"].Index]		= GameInfo.MilitaryOrganisationLevels["LEVEL4B"].Index,
		[GameInfo.MilitaryOrganisationLevels["LEVEL5"].Index]		= GameInfo.MilitaryOrganisationLevels["LEVEL5B"].Index,
		[GameInfo.MilitaryOrganisationLevels["LEVEL6"].Index]		= GameInfo.MilitaryOrganisationLevels["LEVEL6B"].Index,
		[GameInfo.MilitaryOrganisationLevels["LEVEL7"].Index]		= GameInfo.MilitaryOrganisationLevels["LEVEL7B"].Index,
		[GameInfo.MilitaryOrganisationLevels["LEVEL8"].Index]		= GameInfo.MilitaryOrganisationLevels["LEVEL8B"].Index,
}
local OrganizationLevelToStandard 	= {		-- to get the normal MilitaryOrganisationLevel to use when the Smaller Units Policy is active
		[GameInfo.MilitaryOrganisationLevels["LEVEL1B"].Index]	= GameInfo.MilitaryOrganisationLevels["LEVEL1"].Index,
		[GameInfo.MilitaryOrganisationLevels["LEVEL2B"].Index]	= GameInfo.MilitaryOrganisationLevels["LEVEL2"].Index,
		[GameInfo.MilitaryOrganisationLevels["LEVEL3B"].Index]	= GameInfo.MilitaryOrganisationLevels["LEVEL3"].Index,
		[GameInfo.MilitaryOrganisationLevels["LEVEL4B"].Index]	= GameInfo.MilitaryOrganisationLevels["LEVEL4"].Index,
		[GameInfo.MilitaryOrganisationLevels["LEVEL5B"].Index]	= GameInfo.MilitaryOrganisationLevels["LEVEL5"].Index,
		[GameInfo.MilitaryOrganisationLevels["LEVEL6B"].Index]	= GameInfo.MilitaryOrganisationLevels["LEVEL6"].Index,
		[GameInfo.MilitaryOrganisationLevels["LEVEL7B"].Index]	= GameInfo.MilitaryOrganisationLevels["LEVEL7"].Index,
		[GameInfo.MilitaryOrganisationLevels["LEVEL8B"].Index]	= GameInfo.MilitaryOrganisationLevels["LEVEL8"].Index,
}
local smallerUnitsPolicyID 			= GameInfo.Policies["POLICY_SMALLER_UNITS"].Index


-----------------------------------------------------------------------------------------
-- Initialize
-----------------------------------------------------------------------------------------

local GCO 	= {}
local pairs = pairs
function InitializeUtilityFunctions() 	-- Get functions from other contexts
	GCO 		= ExposedMembers.GCO
	Dprint 		= GCO.Dprint				-- Dprint(bOutput, str) : print str if bOutput is true
	Dline		= GCO.Dline					-- output current code line number to firetuner/log
	Dlog		= GCO.Dlog					-- log a string entry, last 10 lines displayed after a call to GCO.Error()
	pairs 		= GCO.OrderedPairs
	print("Exposed Functions from other contexts initialized...")
	PostInitialize()
end
LuaEvents.InitializeGCO.Add( InitializeUtilityFunctions )

function SaveTables()
	Dprint( DEBUG_PLAYER_SCRIPT, "--------------------------- Saving PlayerData ---------------------------")
	GCO.SaveTableToSlot(ExposedMembers.PlayerData, "PlayerData")
end
LuaEvents.SaveTables.Add(SaveTables)

function PostInitialize() -- everything that may require other context to be loaded first
	ExposedMembers.PlayerData = GCO.LoadTableFromSlot("PlayerData") or {}
	InitializePlayerFunctions()
	InitializePlayerData() -- after InitializePlayerFunctions
end

function InitializePlayerData()
	for _, playerID in ipairs(PlayerManager.GetWasEverAliveIDs()) do
		local player = Players[playerID]
		if player and not ExposedMembers.PlayerData[player:GetKey()] then
			player:InitializeData()
		end	
	end
end



-----------------------------------------------------------------------------------------
-- PlayerData functions
-----------------------------------------------------------------------------------------
--[[
function UpdatePopulationNeeds(self)
	local era = self:GetEra()
	for row in GameInfo.PopulationNeeds() do
		if (not row.StartEra or (row.StartEra and GameInfo.Eras[row.StartEra].Index >= era)) and (not row.EndEra or (row.EndEra and GameInfo.Eras[row.EndEra].Index < era)) then
			local resourceID 	= GameInfo.Resources[row.ResourceType].Index
			local populationID 	= GameInfo.Resources[row.PopulationType].Index
			-- Needs by population
			if not _cached.PopulationNeeds then _cached.PopulationNeeds = {} end
			if not _cached.PopulationNeeds[populationID] then _cached.PopulationNeeds[populationID] = {} end
			if not _cached.PopulationNeeds[populationID][resourceID] then _cached.PopulationNeeds[populationID][resourceID] = {} end
			if not _cached.PopulationNeeds[populationID][resourceID][row.AffectedType] then _cached.PopulationNeeds[populationID][resourceID][row.AffectedType] = {} end
			_cached.PopulationNeeds[populationID][resourceID][row.AffectedType].NeededCalculFunction 	= loadstring(row.NeededCalculFunction)
			_cached.PopulationNeeds[populationID][resourceID][row.AffectedType].EffectCalculFunction 	= loadstring(row.EffectCalculFunction)
			_cached.PopulationNeeds[populationID][resourceID][row.AffectedType].OnlyBonus 				= row.OnlyBonus
			_cached.PopulationNeeds[populationID][resourceID][row.AffectedType].OnlyPenalty 			= row.OnlyPenalty
			_cached.PopulationNeeds[populationID][resourceID][row.AffectedType].MaxEffectValue 			= row.MaxEffectValue
			_cached.PopulationNeeds[populationID][resourceID][row.AffectedType].Treshold 				= row.Treshold
			
			-- Needs by resources
			if not _cached.ResourcesNeeded then _cached.ResourcesNeeded = {} end
			if not _cached.ResourcesNeeded[resourceID] then _cached.ResourcesNeeded[resourceID] = {} end
			if not _cached.ResourcesNeeded[resourceID][populationID] then _cached.ResourcesNeeded[resourceID][populationID] = {} end
			if not _cached.ResourcesNeeded[resourceID][populationID][row.AffectedType] then _cached.ResourcesNeeded[resourceID][populationID][row.AffectedType] = {} end
			if not _cached.ResourcesNeeded[resourceID][populationID].Priority then -- use the higher priority value for the couple [resourceID][populationID]
				_cached.ResourcesNeeded[resourceID][populationID].Priority = row.Priority
			elseif row.Priority > _cached.ResourcesNeeded[resourceID][populationID].Priority then
				_cached.ResourcesNeeded[resourceID][populationID].Priority = row.Priority
			end
			if not _cached.ResourcesNeeded[resourceID][populationID].Ratio then -- use the higher Ratio value for the couple [resourceID][populationID]
				_cached.ResourcesNeeded[resourceID][populationID].Ratio = row.Ratio
			elseif row.Ratio > _cached.ResourcesNeeded[resourceID][populationID].Ratio then
				_cached.ResourcesNeeded[resourceID][populationID].Ratio = row.Ratio
			end
		end		 
	end
end

function GetPopulationNeeds(self, populationID)
	if not _cached.PopulationNeeds then self:UpdatePopulationNeeds() end
	return _cached.PopulationNeeds[populationID] or {}
end

function GetResourcesNeededForPopulations(self, resourceID)
	if not _cached.ResourcesNeeded then self:UpdatePopulationNeeds() end
	return _cached.ResourcesNeeded[resourceID] or {}
end

function GetResourcesConsumptionRatioForPopulation(self, resourceID, populationID)
	if not _cached.ResourcesNeeded then self:UpdatePopulationNeeds() end
	if not _cached.ResourcesNeeded[resourceID] then return 0 end
	if not _cached.ResourcesNeeded[resourceID][populationID] then return 0 end
	return _cached.ResourcesNeeded[resourceID][populationID].Ratio or 0
end
--]]

function InitializeData(self)
	local playerKey 	= self:GetKey()
	local turnKey 		= GCO.GetTurnKey()
	ExposedMembers.PlayerData[playerKey] = {
		CurrentTurn 		= Game.GetCurrentGameTurn(),
		OrganizationLevel 	= 0,
		Account				= { [turnKey] = {} }, -- [turnKey] = {[AccountType] = value}
		Debt			 	= 0,
		DebtUpdateTurn 		= Game.GetCurrentGameTurn(),
	}
end

function GetKey(self)
	return tostring(self:GetID())
end

function GetData(self)
	local playerKey  = tostring(self:GetKey())
	local playerData = ExposedMembers.PlayerData[playerKey]
	return playerData
end



-----------------------------------------------------------------------------------------
-- General functions
-----------------------------------------------------------------------------------------	

function CanTrain(self, unitType) -- global check, used to show the unit in the build list, the tests for materiel/equipment and others limits are done at the city level 
	local row 	= GameInfo.Units[unitType]
	
	if not row.CanTrain then return false end	
	if row.TraitType then return false end
	
	local tech 	= row.PrereqTech
	if tech then
		local techID = GameInfo.Technologies[tech].Index
		if not self:IsKnownTech(techID) then
			return false
		end
	end
	
	return true
end

function IsResourceVisible(self, resourceID)
	return GCO.IsResourceVisibleFor(self, resourceID)
end

function HasPolicyActive(self, policyID)
	return GCO.HasPolicyActive(self, policyID)
end

function GetActivePolicies(self, policyID)
	return GCO.GetActivePolicies(self)
end

function IsObsoleteEquipment(self, equipmentTypeID)
	if not GCO.IsResourceEquipment(equipmentTypeID) then return false end
	local ObsoleteTech = EquipmentInfo[equipmentTypeID].ObsoleteTech
	if not ObsoleteTech then return false end
	local pScience = self:GetTechs()
	local iTech	= GameInfo.Technologies[ObsoleteTech].Index
	return pScience:HasTech(iTech)
end

function GetTotalPopulation(self)
	local populationTotal		= 0
	local populationVariation	= 0
	local playerCities = self:GetCities()
	if playerCities then
		for i, city in playerCities:Members() do
			GCO.AttachCityFunctions(city)
			populationTotal 	= populationTotal + city:GetTotalPopulation()
			populationVariation	= populationVariation + city:GetTotalPopulationVariation()
		end
	end
	return populationTotal, populationVariation
end

function GetPersonnelInCities(self) -- logistic support
	local personnel = 0
	local playerCities = self:GetCities()
	if playerCities then
		for i, city in playerCities:Members() do
			GCO.AttachCityFunctions(city)
			personnel = personnel + city:GetPersonnel()
		end
	end
	return personnel
end

function GetPersonnelInUnits(self)
	local personnel = 0
	local playerUnits = self:GetUnits()
	if playerUnits then
		for i, unit in playerUnits:Members() do
			GCO.AttachUnitFunctions(unit)
			personnel = personnel + unit:GetTotalPersonnel()
		end
	end
	return personnel
end

function GetLogisticPersonnelInActiveDuty(self)
	local maxActiveDutyPersonnel = 0
	for row in GameInfo.UnitPromotionClasses() do
		local promotionClassID 				= row.Index
		local logisticCost 					= self:GetLogisticCost(promotionClassID)
		if logisticCost > maxActiveDutyPersonnel then
			maxActiveDutyPersonnel	= logisticCost
		end
	end
	return math.min(maxActiveDutyPersonnel, self:GetPersonnelInCities())
end

function GetDraftedPercentage(self)
	local PopulationBalance = self:GetTotalPopulation()
	local ArmySize			= self:GetPersonnelInUnits() + self:GetLogisticPersonnelInActiveDuty() 
	return  ArmySize / PopulationBalance * 100
end

function GetMaxDraftedPercentage(self) -- the maximum percentage of population in the army
	local era 				= self:GetEra()
	local basePercentage	= GameInfo.Eras[era].ArmyMaxPercentOfPopulation
	local policies			= self:GetActivePolicies()
	if self:IsAtWar() then
		basePercentage = basePercentage + GameInfo.Eras[era].ArmyMaxPercentWarBoost
	end
	for _, policyID in ipairs(policies) do
		basePercentage = basePercentage + GameInfo.Policies[policyID].ArmyMaxPercentBoost
	end
	return basePercentage
end

function GetDraftEfficiencyPercent(self)
	local maxDraftedPercentage	= self:GetMaxDraftedPercentage()
	local draftedPercentage		= self:GetDraftedPercentage()
	return math.max(0, GCO.GetMaxPercentFromHighDiff(100, maxDraftedPercentage, draftedPercentage))
end

function GetLogisticCost(self, PromotionClassID)
	local logisticCost = 0
	local playerUnits = self:GetUnits()
	if playerUnits then
		for i, unit in playerUnits:Members() do
			GCO.AttachUnitFunctions(unit)
			if PromotionClassID == unit:GetPromotionClassID() then
				logisticCost = logisticCost + unit:GetLogisticCost()
			end
		end
	end
	return logisticCost
end

function GetLogisticSupport(self, PromotionClassID)
	local logisticSupport 		= self:GetPersonnelInCities()
	local promotionClassType 	= GameInfo.UnitPromotionClasses[PromotionClassID].PromotionClassType
	if promotionClassType == "PROMOTION_CLASS_SKIRMISHER" then
		logisticSupport = GCO.Round(logisticSupport * 0.1)
	elseif promotionClassType == "PROMOTION_CLASS_NAVAL_MELEE" or promotionClassType == "PROMOTION_CLASS_NAVAL_RANGED" then
		logisticSupport = GCO.Round(logisticSupport * 0.15)	
	end
	return logisticSupport
end


-----------------------------------------------------------------------------------------
-- Research functions
-----------------------------------------------------------------------------------------	
-- Player function
function IsKnownTech(self, techID)
	local selfID = self:GetID()
	if not _cached.KnownTech then self:SetKnownTech() end
	if not _cached.KnownTech[selfID] then self:SetKnownTech() end
	return _cached.KnownTech[selfID][techID]
end

function SetKnownTech(self)

	local selfID = self:GetID()
	if not _cached.KnownTech then _cached.KnownTech = {} end
	if not _cached.KnownTech[selfID] then _cached.KnownTech[selfID] = {} end
	
	for iPlayer = 0, PlayerManager.GetWasEverAliveCount() - 1 do
		local player = Players[iPlayer]
		if player and player:IsMajor() and player:GetCities():GetCount() > 0 and self:GetDiplomacy():HasMet(iPlayer) then
			local pScience = player:GetTechs()
			for kTech in GameInfo.Technologies() do		
				local iTech	= kTech.Index
				if pScience:HasTech(iTech) then
					_cached.KnownTech[selfID][iTech] = true
				end
			end
		end
	end
end

--Events
function OnResearchCompleted(playerID)
	local player = Players[playerID]
	local playerCities = player:GetCities()
	if playerCities then
		for i, city in playerCities:Members() do
			GCO.AttachCityFunctions(city)
			if city:IsInitialized() then
				city:SetUnlockers()
			end
		end
	end	
end



-----------------------------------------------------------------------------------------
-- Military Organization functions
-----------------------------------------------------------------------------------------
-- Player function
function SetMilitaryOrganizationLevel(self, OrganizationLevelID)
	local playerKey = self:GetKey()
	ExposedMembers.PlayerData[playerKey].OrganizationLevel = OrganizationLevelID
end

function GetMilitaryOrganizationLevel(self)
	local playerKey = self:GetKey()
	if self:IsBarbarian() then
		return math.floor((ExposedMembers.PlayerData[playerKey].OrganizationLevel or 0) / 2)
	else
		return ExposedMembers.PlayerData[playerKey].OrganizationLevel or 0
	end
end

function UpdateMilitaryOrganizationLevel(self)
	-- this function assume that a higher ID means better Civics and OrganizationLevel
	local bestCivicID = -1
	for civicID, organizationLevelID in pairs(OrganizationLevelCivics) do
		if self:GetCulture():HasCivic(civicID) and civicID > bestCivicID then
			bestCivicID = civicID
		end
	end
	if bestCivicID > -1 then	
		local organizationLevel	= OrganizationLevelCivics[bestCivicID]
		if self:HasPolicyActive(smallerUnitsPolicyID) and OrganizationLevelToSmaller[organizationLevel] then
			organizationLevel = OrganizationLevelToSmaller[organizationLevel]
		end
		self:SetMilitaryOrganizationLevel(organizationLevel)
	end
end

-- Events
function OnCivicCompleted(playerID, civicID) -- this function assume that Civics related to Military Organisation Levels are sequential (else the level could downgrade if a later civics is researched before an older)
	if OrganizationLevelCivics[civicID] then
		local player 			= Players[playerID]
		local organizationLevel	= OrganizationLevelCivics[civicID]
		if player:HasPolicyActive(smallerUnitsPolicyID) and OrganizationLevelToSmaller[organizationLevel] then
			organizationLevel = OrganizationLevelToSmaller[organizationLevel]
		end
		player:SetMilitaryOrganizationLevel(organizationLevel)
	end
end

function OnPolicyChanged(playerID, policyID)

	if policyID ~= smallerUnitsPolicyID then return end

	local player 			= Players[playerID]	
	local organizationLevel = player:GetMilitaryOrganizationLevel()
	
	if player:HasPolicyActive(smallerUnitsPolicyID) and OrganizationLevelToSmaller[organizationLevel] then
		organizationLevel = OrganizationLevelToSmaller[organizationLevel]
		player:SetMilitaryOrganizationLevel(organizationLevel)
	end
	
	if (not player:HasPolicyActive(smallerUnitsPolicyID)) and OrganizationLevelToStandard[organizationLevel] then
		organizationLevel = OrganizationLevelToStandard[organizationLevel]
		player:SetMilitaryOrganizationLevel(organizationLevel)
	end
end



-----------------------------------------------------------------------------------------
-- Treasury functions
-----------------------------------------------------------------------------------------

-- Proceed with a transaction (update player's gold)
function ProceedTransaction(self, accountType, value)

	--Dprint( DEBUG_PLAYER_SCRIPT, GCO.Separator)
	--Dprint( DEBUG_PLAYER_SCRIPT, "Proceeding transaction for "..Locale.Lookup(PlayerConfigurations[self:GetID()]:GetCivilizationShortDescription()))
	local playerData 		= self:GetData()
	local turnKey 			= GCO.GetTurnKey()
	local playerTreasury	= self:GetTreasury()
	local goldBalance		= playerTreasury:GetGoldBalance()
	local currentBalance	= math.max(0, goldBalance) -- When negative, GoldBalance is set back to 0 at some point in Core, but it can be < 0 when processing transactions, so assume 0 when negative.
	local afterBalance		= currentBalance + value
	
	--Dprint( DEBUG_PLAYER_SCRIPT, Indentation20("transaction value") .. tostring(value))
	--Dprint( DEBUG_PLAYER_SCRIPT, Indentation20("realBalance") .. tostring(goldBalance))
	--Dprint( DEBUG_PLAYER_SCRIPT, Indentation20("virtualBalance") .. tostring(currentBalance))
	--Dprint( DEBUG_PLAYER_SCRIPT, Indentation20("afterBalance") .. tostring(afterBalance))

	if not playerData.Account[turnKey] then playerData.Account[turnKey] = {} end
	playerData.Account[turnKey][accountType] = (playerData.Account[turnKey][accountType] or 0) + value

	if afterBalance < 0 then
	
		--Dprint( DEBUG_PLAYER_SCRIPT, Indentation20("Debt before") .. tostring(playerData.Debt))
		
		playerData.Debt = playerData.Debt + afterBalance
		
		--Dprint( DEBUG_PLAYER_SCRIPT, Indentation20("Debt after") .. tostring(playerData.Debt))
		
		-- Core will add the base game income to the treasury before setting back the GoldBalance to 0
		-- To prevent any loss, we do not remove from the treasury what has been added to the debt
		value = value - afterBalance
		--Dprint( DEBUG_PLAYER_SCRIPT, Indentation20("Value after") .. tostring(value))
	end	
	
	playerTreasury:ChangeGoldBalance(value)
	
	--Dprint( DEBUG_PLAYER_SCRIPT, GCO.Separator)
end

-- Record a transaction already proceeded (do not update player's gold)
function RecordTransaction(self, accountType, value, turnKey) --turnKey optionnal
	local playerData 		= self:GetData()
	local turnKey 			= turnKey or GCO.GetTurnKey()
	if not playerData.Account[turnKey] then playerData.Account[turnKey] = {} end
	playerData.Account[turnKey][accountType] = (playerData.Account[turnKey][accountType] or 0) + value
end

function GetTransactionBalance(self, turnKey) --turnKey optionnal
	if not ExposedMembers.GCO_Initialized then return 0 end -- return 0 when called from UI scripts on load, before the mod's initialization
	local playerData 		= self:GetData()
	local turnKey 			= turnKey or GCO.GetTurnKey()
	if not playerData.Account[turnKey] then return 0 end
	return GCO.TableSummation(playerData.Account[turnKey])
end

function GetTransactionType(self, accountType, turnKey) --turnKey optionnal
	if not ExposedMembers.GCO_Initialized then return 0 end -- return 0 when called from UI scripts on load, before the mod's initialization
	local playerData 		= self:GetData()
	local turnKey 			= turnKey or GCO.GetTurnKey()
	if not playerData.Account[turnKey] then return 0 end
	return playerData.Account[turnKey][accountType] or 0
end

function UpdateDebt(self)

	Dprint( DEBUG_PLAYER_SCRIPT, GCO.Separator)
	Dprint( DEBUG_PLAYER_SCRIPT, "Updating Debt for "..Locale.Lookup(PlayerConfigurations[self:GetID()]:GetCivilizationShortDescription()))
	
	local playerData 		:table	= self:GetData()
	local playerTreasury	:table	= self:GetTreasury();
	local goldYield			:number = playerTreasury:GetGoldYield() - playerTreasury:GetTotalMaintenance()	
	local goldBalance		:number = playerTreasury:GetGoldBalance()
	local afterBalance		:number = goldBalance + goldYield
	
	Dprint( DEBUG_PLAYER_SCRIPT, Indentation20("goldBalance") .. tostring(goldBalance))
	Dprint( DEBUG_PLAYER_SCRIPT, Indentation20("goldYield") .. tostring(goldYield))	
	Dprint( DEBUG_PLAYER_SCRIPT, Indentation20("afterBalance") .. tostring(afterBalance))
	
	if afterBalance < 0 then
	
		Dprint( DEBUG_PLAYER_SCRIPT, Indentation20("Debt before") .. tostring(playerData.Debt))
		
		playerData.Debt = playerData.Debt + goldYield
		
		Dprint( DEBUG_PLAYER_SCRIPT, Indentation20("Debt after") .. tostring(playerData.Debt))
		
	end
	
	if playerData.Debt < 0 and goldYield > 0 then
	
		Dprint( DEBUG_PLAYER_SCRIPT, Indentation20("Current Debt") .. tostring(playerData.Debt))
		
		local maxRepay			= math.min(goldYield, goldBalance) -- if gold yield is negative after adding the TransactionBalance, use all of the initial value for repayment as it may have been added to the gold balance after core has reset its value to 0
		local extraGoldYield 	= self:GetTransactionBalance()
		goldYield 				= goldYield + extraGoldYield
		
		Dprint( DEBUG_PLAYER_SCRIPT, Indentation20("extraGoldYield") .. tostring(extraGoldYield))		
		Dprint( DEBUG_PLAYER_SCRIPT, Indentation20("finalGoldYield") .. tostring(goldYield))	
		
		if goldYield > 0 then -- if gold yield is still positive, then gold balance was positive (and core did not reset it  to 0)
			maxRepay = math.min(goldYield / 2, goldBalance) -- 50% of net income used to repay the debt (to do: change by era/techs/policies)
		end

		Dprint( DEBUG_PLAYER_SCRIPT, Indentation20("maxRepay") .. tostring(maxRepay))
		
		if maxRepay > 0 then
		
			maxRepay = math.min(maxRepay, -playerData.Debt)
			Dprint( DEBUG_PLAYER_SCRIPT, Indentation20("maxRepay") .. tostring(maxRepay))
			
			playerData.Debt = playerData.Debt + maxRepay
			self:ProceedTransaction(AccountType.Repay, -maxRepay)
			
			Dprint( DEBUG_PLAYER_SCRIPT, Indentation20("New Debt") .. tostring(playerData.Debt))
			Dprint( DEBUG_PLAYER_SCRIPT, Indentation20("New Balance") .. tostring(playerTreasury:GetGoldBalance()))
		end
	end
end

function OnTreasuryChanged(playerID, yield, balance)
	Dprint( DEBUG_PLAYER_SCRIPT, "OnTreasuryChanged", playerID, yield, balance)
	local player = Players[playerID]
	if player and player:IsTurnActive() then
		local playerData 	= player:GetData()
		local currentTurn	= Game.GetCurrentGameTurn()
		if playerData.DebtUpdateTurn ~= currentTurn then
			player:UpdateDebt()
			playerData.DebtUpdateTurn = currentTurn
		end
	end
end



-----------------------------------------------------------------------------------------
-- Diplomacy functions
-----------------------------------------------------------------------------------------

function IsAtWar(self)
	local playerDiplo = self:GetDiplomacy()
	for _, playerID in ipairs(PlayerManager.GetWasEverAliveMajorIDs()) do
		if playerDiplo:IsAtWarWith( playerID ) then
			return true
		end
	end
	return false
end

function OnDiplomacyDeclareWar(attackerPlayerID, defenderPlayerID)

	local attacker 			= Players[attackerPlayerID]
	local defender 			= Players[defenderPlayerID]
	local attackerName		= Locale.Lookup(PlayerConfigurations[attackerPlayerID]:GetCivilizationShortDescription())
	local defenderName		= Locale.Lookup(PlayerConfigurations[defenderPlayerID]:GetCivilizationShortDescription())
	local defenderDiploAI 	= defender:GetAi_Diplomacy()
	local attackerDiploAI 	= attacker:GetAi_Diplomacy()
	local defenderDiplo		= defender:GetDiplomacy()
	local attackerDiplo		= attacker:GetDiplomacy()
	
	Dprint( DEBUG_PLAYER_SCRIPT, GCO.Separator)
	Dprint( DEBUG_PLAYER_SCRIPT, attackerName .. " Has declared war to " .. defenderName)
	
	Dprint( DEBUG_PLAYER_SCRIPT, "...Listing Allies of " .. defenderName)	
	for _, playerID in ipairs(PlayerManager.GetWasEverAliveMajorIDs()) do
		if playerID ~= attackerPlayerID and playerID ~= defenderPlayerID then
			if (defenderDiploAI:GetDiplomaticState(playerID) == "DIPLO_STATE_ALLIED") then
				local ally 		= Players[playerID]
				local allyName 	= Locale.Lookup(PlayerConfigurations[playerID]:GetCivilizationShortDescription())
				Dprint( DEBUG_PLAYER_SCRIPT, "......"..allyName)
				if (not attackerDiplo:IsAtWarWith( playerID )) then
					if attacker:CanDeclareWarOn( playerID ) then
						Dprint( DEBUG_PLAYER_SCRIPT, ".........Receive DoW from " .. attackerName)
						attackerDiplo:DeclareWarOn(playerID)
						local allyMilitaryAI = ally:GetAi_Military()
						Dprint( DEBUG_PLAYER_SCRIPT, ".........allyMilitaryAI = ", allyMilitaryAI);
						allyMilitaryAI:PrepareForWarWith(attackerPlayerID);
						if ( allyMilitaryAI:HasOperationAgainst( attackerPlayerID, true ) ) then
							Dprint( DEBUG_PLAYER_SCRIPT, ".........Has Military operation against " .. attackerName)
						end
					else
						Dprint( DEBUG_PLAYER_SCRIPT, ".........Can't receive DoW from " .. attackerName)
					end
				else
					Dprint( DEBUG_PLAYER_SCRIPT, ".........Already at war with " .. attackerName)
				end
			end
		end	
	end
	
	Dprint( DEBUG_PLAYER_SCRIPT, "...Listing Allies of " .. attackerName)	
	for _, playerID in ipairs(PlayerManager.GetWasEverAliveMajorIDs()) do
		if playerID ~= attackerPlayerID and playerID ~= defenderPlayerID then
			if (attackerDiploAI:GetDiplomaticState(playerID) == "DIPLO_STATE_ALLIED") then
				local ally 		= Players[playerID]
				local allyName 	= Locale.Lookup(PlayerConfigurations[playerID]:GetCivilizationShortDescription())
				local allyDiplo	= ally:GetDiplomacy()
				Dprint( DEBUG_PLAYER_SCRIPT, "......"..allyName)
				if (not allyDiplo:IsAtWarWith( defenderPlayerID )) then
					if ally:CanDeclareWarOn( defenderPlayerID ) then
						Dprint( DEBUG_PLAYER_SCRIPT, ".........Can Declare War on " .. defenderName)
						local allyMilitaryAI = ally:GetAi_Military()
						Dprint( DEBUG_PLAYER_SCRIPT, ".........allyMilitaryAI = ", allyMilitaryAI);
						allyMilitaryAI:PrepareForWarWith(defenderPlayerID);
						if ( allyMilitaryAI:HasOperationAgainst( defenderPlayerID, true ) ) then
							Dprint( DEBUG_PLAYER_SCRIPT, ".........Has Military operation against " .. defenderName)
						end
						Dprint( DEBUG_PLAYER_SCRIPT, ".........Declare War against " .. defenderName)
						allyDiplo:DeclareWarOn(defenderPlayerID)
					else
						Dprint( DEBUG_PLAYER_SCRIPT, ".........Can't Declare War on " .. defenderName)
					end
				else
					Dprint( DEBUG_PLAYER_SCRIPT, ".........Already at war with " .. defenderName)
				end
			end
		end	
	end
end



-----------------------------------------------------------------------------------------
-- Updates functions
-----------------------------------------------------------------------------------------

function UpdateUnitsFlags(self)
	local playerUnits = self:GetUnits()
	if playerUnits then
		for i, unit in playerUnits:Members() do			
			LuaEvents.UnitsCompositionUpdated(self:GetID(), unit:GetID())
		end
	end
end

function UpdateCitiesBanners(self)
	local playerCities = self:GetCities()
	if playerCities then
		for i, city in playerCities:Members() do			
			LuaEvents.CityCompositionUpdated(self:GetID(), city:GetID())
		end
	end
end

function UpdateDataOnNewTurn(self)
	local playerConfig = PlayerConfigurations[self:GetID()]
	Dprint( DEBUG_PLAYER_SCRIPT, GCO.Separator)
	Dprint( DEBUG_PLAYER_SCRIPT, "- Updating Data on new turn for "..Locale.Lookup(playerConfig:GetCivilizationShortDescription()))
	
	if Game.GetCurrentGameTurn() == GameConfiguration.GetStartTurn() then -- don't update on first turn (NewTurn is called on the first turn of a later era start)
		GCO.Warning("Aborting UpdateDataOnNewTurn for ".. Locale.Lookup(playerConfig:GetCivilizationShortDescription()) ..", this is the first turn !")
		return
	end

	local playerCities = self:GetCities()
	if playerCities then
		for i, city in playerCities:Members() do
			GCO.AttachCityFunctions(city)
			city:UpdateDataOnNewTurn()
		end
	end
	
	local playerUnits = self:GetUnits()
	if playerUnits then
		for j, unit in playerUnits:Members() do
			GCO.AttachUnitFunctions(unit)
			unit:UpdateDataOnNewTurn()
		end
	end
	
	self:SetKnownTech()
	
end

function UpdateDataOnLoad(self)

	local playerConfig 	= PlayerConfigurations[self:GetID()]
	local name 			= Locale.Lookup(playerConfig:GetCivilizationShortDescription())
	GCO.StartTimer("UpdateCachedData for "..name)
	Dprint( DEBUG_PLAYER_SCRIPT, GCO.Separator)
	Dprint( DEBUG_PLAYER_SCRIPT, "- Updating Data on (re)Loading for "..name)

	local playerCities = self:GetCities()
	if playerCities then
		for i, city in playerCities:Members() do
			GCO.AttachCityFunctions(city)
			city:UpdateTransferCities()
			city:UpdateExportCities()
		end
	end
	
	local playerUnits = self:GetUnits()
	if playerUnits then
		for j, unit in playerUnits:Members() do
			GCO.AttachUnitFunctions(unit)
			--
		end
	end	
	GCO.ShowTimer("UpdateCachedData for "..name)
end



-----------------------------------------------------------------------------------------
-- DoTurn Functions
-----------------------------------------------------------------------------------------
function SetCurrentTurn(self)
	local playerKey = self:GetKey()
	ExposedMembers.PlayerData[playerKey].CurrentTurn = Game.GetCurrentGameTurn()
end

function HasStartedTurn(self)
	local playerKey = self:GetKey()
	return (ExposedMembers.PlayerData[playerKey].CurrentTurn == Game.GetCurrentGameTurn())
end

local startTurnAutoSaveNum = 0
function DoPlayerTurn( playerID )
	local DEBUG_PLAYER_SCRIPT	= "debug"
	if (playerID == -1) then playerID = 0 end -- this is necessary when starting in AutoPlay
	
	local player = Players[playerID]
	if player and not player:HasStartedTurn() then
		local playerConfig						= PlayerConfigurations[playerID]
		GCO.PlayerTurnsDebugChecks[playerID]	= {}
		local playerName						= Locale.ToUpper(Locale.Lookup(playerConfig:GetCivilizationShortDescription()))
		Dprint( DEBUG_PLAYER_SCRIPT, "---============================================================================================================================================================================---")
		Dprint( DEBUG_PLAYER_SCRIPT, "--- STARTING TURN # ".. tostring(Game.GetCurrentGameTurn()) .." FOR PLAYER # ".. tostring(playerID) .. " ( ".. tostring(playerName) .." )")
		Dprint( DEBUG_PLAYER_SCRIPT, "---============================================================================================================================================================================---")
		
		-- May need that when launching a game with a later era start
		player:UpdateMilitaryOrganizationLevel()
		
		--player:UpdatePopulationNeeds()
		GCO.StartTimer("DoUnitsTurn for ".. tostring(playerName))
		LuaEvents.DoUnitsTurn( playerID )
		GCO.ShowTimer("DoUnitsTurn for ".. tostring(playerName))
		
		--GCO.StartTimer("DoCitiesTurn for ".. tostring(playerName))
		LuaEvents.DoCitiesTurn( playerID )
		--GCO.ShowTimer("DoCitiesTurn for ".. tostring(playerName))
		
		-- update flags after resources transfers
		player:UpdateUnitsFlags()
		player:UpdateCitiesBanners()
		player:SetCurrentTurn()
		
		LuaEvents.ShowTimerLog(playerID)
		
		if playerID == Game.GetLocalPlayer() then		
			--LuaEvents.SaveTables()
		end
		
		if playerID == 0 then --and Automation.IsActive() then
			-- Making our own auto save...
			LuaEvents.SaveTables()
			startTurnAutoSaveNum = startTurnAutoSaveNum + 1
			if startTurnAutoSaveNum > 5 then startTurnAutoSaveNum = 1 end
			local saveGame = {};
			saveGame.Name = "GCO-StartTurnAutoSave"..tostring(startTurnAutoSaveNum)
			saveGame.Location = SaveLocations.LOCAL_STORAGE
			saveGame.Type= SaveTypes.SINGLE_PLAYER
			saveGame.IsAutosave = true
			saveGame.IsQuicksave = false
			LuaEvents.SaveGameGCO(saveGame)
		end
	end
end


function CheckPlayerTurn(playerID)
	local DEBUG_PLAYER_SCRIPT	= "debug"
	local playerConfig	= PlayerConfigurations[playerID]
	local bNoError		= true
	if GCO.PlayerTurnsDebugChecks[playerID] then
		if not GCO.PlayerTurnsDebugChecks[playerID].UnitsTurn then
			GCO.ErrorWithLog("UNITS TURN UNFINISHED AT TURN # ".. tostring(Game.GetCurrentGameTurn()) .." FOR PLAYER #".. tostring(playerID) .. " ( ".. tostring(Locale.ToUpper(Locale.Lookup(playerConfig:GetCivilizationShortDescription()))) .." )")
			bNoError = false
		end
		if not GCO.PlayerTurnsDebugChecks[playerID].CitiesTurn then
			GCO.ErrorWithLog("CITIES TURN UNFINISHED AT TURN # ".. tostring(Game.GetCurrentGameTurn()) .." FOR PLAYER #".. tostring(playerID) .. " ( ".. tostring(Locale.ToUpper(Locale.Lookup(playerConfig:GetCivilizationShortDescription()))) .." )")
			bNoError = false
		end
		if bNoError then		
			Dprint( DEBUG_PLAYER_SCRIPT, "- 'DoTurn' completed for player ID#".. tostring(playerID) .. " - "..Locale.Lookup(playerConfig:GetCivilizationShortDescription()))
		end
		GCO.PlayerTurnsDebugChecks[playerID] = nil
	end
end


-- can't use those, they makes the game crash at self.m_Instance.UnitIcon:SetToolTipString( Locale.Lookup(nameString) ) in UnitFlagManager, and some other unidentified parts of the code...
--GameEvents.PlayerTurnStarted.Add(DoPlayerTurn)
--GameEvents.PlayerTurnStarted.Add(CheckPlayerTurn)
--GameEvents.PlayerTurnStartComplete.Add(DoPlayerTurn)

function DoTurnForLocal() -- The Error reported on the line below is triggered by something else.
	local playerID = Game.GetLocalPlayer()
	Dprint( DEBUG_PLAYER_SCRIPT, "----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------")
	Dprint( DEBUG_PLAYER_SCRIPT, "-- Events.LocalPlayerTurnBegin -> Testing Start Turn for player#"..tostring(playerID))
	Dprint( DEBUG_PLAYER_SCRIPT, "----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------")
	local player = Players[playerID]
	if player and not player:HasStartedTurn() then	
		--DoPlayerTurn(playerID)
		--CheckPlayerTurn(playerID)
		LuaEvents.StartPlayerTurn(playerID)
	end
end


function DoTurnForRemote( playerID )
	Dprint( DEBUG_PLAYER_SCRIPT, "----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------")
	Dprint( DEBUG_PLAYER_SCRIPT, "-- Events.RemotePlayerTurnBegin -> Testing Start Turn for player#"..tostring(playerID))
	Dprint( DEBUG_PLAYER_SCRIPT, "----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------")
	--DoPlayerTurn(playerID)	
	--CheckPlayerTurn(playerID)
	LuaEvents.StartPlayerTurn(playerID)
end


--
function DoTurnForNextPlayerFromRemote( playerID )

	repeat
		playerID = playerID + 1
		player = Players[playerID]
	until((player and player:WasEverAlive()) or playerID > 63)
	
	if playerID > 63 then playerID = 0 end
	
	Dprint( DEBUG_PLAYER_SCRIPT, "----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------")
	Dprint( DEBUG_PLAYER_SCRIPT, "-- Events.RemotePlayerTurnEnd -> Testing Start Turn for player#"..tostring(playerID))
	Dprint( DEBUG_PLAYER_SCRIPT, "----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------")
	LuaEvents.StartPlayerTurn(playerID)
end


function DoTurnForNextPlayerFromLocal( playerID )
	if not playerID then playerID = 0 end
	repeat
		playerID = playerID + 1
		player = Players[playerID]
	until((player and player:WasEverAlive()) or playerID > 63)
	
	if playerID > 63 then playerID = 0 end
	Dprint( DEBUG_PLAYER_SCRIPT, "----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------")
	Dprint( DEBUG_PLAYER_SCRIPT, "-- Events.LocalPlayerTurnEnd -> Testing Start Turn for player#"..tostring(playerID))
	Dprint( DEBUG_PLAYER_SCRIPT, "----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------")
	LuaEvents.StartPlayerTurn(playerID)
end



-----------------------------------------------------------------------------------------
-- Events Functions
-----------------------------------------------------------------------------------------



-----------------------------------------------------------------------------------------
-- Functions passed from UI Context
-----------------------------------------------------------------------------------------
function CanDeclareWarOn(self, playerID)
	return GCO.CanPlayerDeclareWarOn(self, playerID)
end



-----------------------------------------------------------------------------------------
-- Shared Functions
-----------------------------------------------------------------------------------------
function GetPlayer(playerID)
	local player= Players[playerID]
	if not player then
		GCO.Error("player is nil in GetPlayer for playerID#", playerID)
		return
	end
	InitializePlayerFunctions(player)
	return player
end



-----------------------------------------------------------------------------------------
-- Initialize Player Functions
-----------------------------------------------------------------------------------------
function InitializePlayerFunctions(player) -- Note that those functions are limited to this file context
	if not player then player = Players[0] end
	local p = getmetatable(player).__index
	
	p.GetKey									= GetKey
	p.GetData									= GetData
	p.InitializeData							= InitializeData
	--
	p.ProceedTransaction						= ProceedTransaction
	p.RecordTransaction							= RecordTransaction
	p.GetTransactionType						= GetTransactionType
	p.GetTransactionBalance						= GetTransactionBalance
	p.UpdateDebt								= UpdateDebt
	--
	p.IsResourceVisible							= IsResourceVisible
	p.HasPolicyActive							= HasPolicyActive
	p.GetActivePolicies							= GetActivePolicies
	p.IsObsoleteEquipment						= IsObsoleteEquipment
	p.CanTrain									= CanTrain
	--
	p.SetMilitaryOrganizationLevel				= SetMilitaryOrganizationLevel
	p.GetMilitaryOrganizationLevel				= GetMilitaryOrganizationLevel
	p.UpdateMilitaryOrganizationLevel			= UpdateMilitaryOrganizationLevel
	--
	p.IsKnownTech								= IsKnownTech
	p.SetKnownTech								= SetKnownTech
	--
	p.UpdateUnitsFlags							= UpdateUnitsFlags
	p.UpdateCitiesBanners						= UpdateCitiesBanners
	--
	p.SetCurrentTurn							= SetCurrentTurn
	p.HasStartedTurn							= HasStartedTurn
	p.UpdateDataOnNewTurn						= UpdateDataOnNewTurn
	p.UpdateDataOnLoad							= UpdateDataOnLoad
	--
	--p.UpdatePopulationNeeds						= UpdatePopulationNeeds
	p.GetPopulationNeeds						= GetPopulationNeeds
	p.GetResourcesNeededForPopulations			= GetResourcesNeededForPopulations
	p.GetResourcesConsumptionRatioForPopulation = GetResourcesConsumptionRatioForPopulation
	--
	p.IsAtWar									= IsAtWar
	p.CanDeclareWarOn							= CanDeclareWarOn
	--
	p.GetTotalPopulation						= GetTotalPopulation
	p.GetPersonnelInCities						= GetPersonnelInCities
	p.GetPersonnelInUnits						= GetPersonnelInUnits
	p.GetLogisticPersonnelInActiveDuty			= GetLogisticPersonnelInActiveDuty
	p.GetLogisticCost							= GetLogisticCost
	p.GetLogisticSupport						= GetLogisticSupport
	p.GetMaxDraftedPercentage					= GetMaxDraftedPercentage
	p.GetDraftedPercentage						= GetDraftedPercentage
	p.GetDraftEfficiencyPercent					= GetDraftEfficiencyPercent
	
end



----------------------------------------------
-- Initialize
----------------------------------------------
function Initialize()
	-- Sharing Functions for other contexts
	if not ExposedMembers.GCO then ExposedMembers.GCO = {} end
	ExposedMembers.GCO.GetPlayer 					= GetPlayer
	ExposedMembers.GCO.InitializePlayerFunctions 	= InitializePlayerFunctions
	ExposedMembers.GCO.PlayerTurnsDebugChecks 		= {}
	ExposedMembers.PlayerScript_Initialized 		= true
	
	-- Register Events (order matters for same events)
	Events.ResearchCompleted.Add(OnResearchCompleted)
	Events.CivicCompleted.Add(OnCivicCompleted)	
	Events.GovernmentPolicyChanged.Add( OnPolicyChanged )
	Events.DiplomacyDeclareWar.Add(OnDiplomacyDeclareWar)
	Events.TreasuryChanged.Add(OnTreasuryChanged)
	LuaEvents.StartPlayerTurn.Add(DoPlayerTurn)
	LuaEvents.StartPlayerTurn.Add(CheckPlayerTurn)
	Events.LocalPlayerTurnBegin.Add( DoTurnForLocal )
	Events.RemotePlayerTurnBegin.Add( DoTurnForRemote )
	Events.RemotePlayerTurnEnd.Add( DoTurnForNextPlayerFromRemote )
	Events.LocalPlayerTurnEnd.Add( DoTurnForNextPlayerFromLocal )
end
Initialize()