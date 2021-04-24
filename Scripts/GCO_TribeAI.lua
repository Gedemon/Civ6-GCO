--=====================================================================================--
--	FILE:	 GCO_TribeAI.lua
--  Gedemon (2021)
--=====================================================================================--

print ("Loading GCO_TribeAI.lua...")

--=====================================================================================--
-- Includes
--=====================================================================================--
include( "GCO_TypeEnum" )
include( "GCO_SmallUtils" )


--=====================================================================================--
-- Defines
--=====================================================================================--
DEBUG_AI_SCRIPT 	= "debug"
local AI_TYPE_NAME	= "TribeAI"

local tDecisions		= {}
local tDecisionFactor	= {}
local iNeutralOrder		= 100

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
end
GameEvents.InitializeGCO.Add( InitializeUtilityFunctions )

--=====================================================================================--
-- 
--=====================================================================================--

function AddToDecisionList(self, sTaskType, sDomainType, plotID, iOrder)

	local row				= GameInfo.TribalVillageProductions[sTaskType] or GameInfo.TribalVillageActions[sTaskType]
	local iOrder			= iOrder or iNeutralOrder
	local kParameters 		= {}
	kParameters.PlayerID	= self.PlayerID
	kParameters.AI			= true
	kParameters.PlotID		= plotID
	kParameters.Type		= sTaskType
	local bCanDoTask,b,s	= GCO.TribeCanDo(kParameters, row)
	
	if bCanDoTask then
		table.insert(tDecisions, {Domain = sDomainType, Parameters = kParameters, Order = iOrder})
	end
	return bCanDoTask
end


--=====================================================================================--
-- AI DoTurn
--=====================================================================================--

function DoTurn(self)
	Dprint( DEBUG_AI_SCRIPT, " - TRIBE AI: Starting turn for Player # ".. tostring(self.PlayerID))
	
	-- Reset Decisions tables
	tDecisions		= {}
	tDecisionFactor	= {}
	
	-- Set initial Decision Domain factor
	-- Higher value = Higher priority
	tDecisionFactor.Defense 	= iNeutralOrder -- 100
	tDecisionFactor.Offense 	= iNeutralOrder
	tDecisionFactor.Homeland	= iNeutralOrder
	
	--self:Update()
	self:DoDiplomacy()
	self:DoStrategy()
	self:DoHomeLand()
	
	self:DoTasks()
end

function DoTasks(self)

	Dprint( DEBUG_AI_SCRIPT, "   - TRIBE AI: Do Tasks...")

	-- Sort tasks by orders
	Dprint( DEBUG_AI_SCRIPT, "   - Ordering Tasks with Defense, Offense, Homeland = ", tDecisionFactor.Defense, tDecisionFactor.Offense, tDecisionFactor.Homeland)
	local iOrderRandomRange	= math.ceil(iNeutralOrder * 0.5) -- to do : remove magic number
	for _, task in ipairs(tDecisions) do
		local randomOrderChange = TerrainBuilder.GetRandomNumber(iOrderRandomRange, "Get Random Order change")
		local initialOrderValue	= task.Order
		local orderTypeChange	= tDecisionFactor[task.Domain]
		task.Order				= initialOrderValue + orderTypeChange + randomOrderChange
		
		Dprint( DEBUG_AI_SCRIPT, "    - ".. Indentation(task.Parameters.Type,15), Indentation(task.Domain,15), " Order (initial, random change, type change, final) = ", initialOrderValue, randomOrderChange, orderTypeChange, task.Order )
	end
	table.sort (tDecisions, function(a, b) return a.Order > b.Order; end)
	
	-- Do task in order
	Dprint( DEBUG_AI_SCRIPT, "   - Executing Tasks...")
	for _, task in ipairs(tDecisions) do
		local bActionDone = GCO.OnPlayerTribeDo(self.PlayerID, task.Parameters)
		Dprint( DEBUG_AI_SCRIPT, "        - ", Indentation(task.Parameters.Type,15), Indentation(task.Domain,15),  bActionDone, task.Order)
	end

end

function DoDiplomacy(self)
	Dprint( DEBUG_AI_SCRIPT, "   - TRIBE AI: Diplomacy...")

end

function DoHomeLand(self)
	Dprint( DEBUG_AI_SCRIPT, "   - TRIBE AI: Homeland...")

	local sDomainType	= "Homeland"
	local tVillages		= GCO.GetPlayerTribalVillages(self.PlayerID)
	
	for _, plotKey in ipairs(tVillages) do
		local plotID 	= tonumber(plotKey)
		local pPlot		= GCO.GetPlotByIndex(plotID)
		local village	= GCO.GetTribalVillageAt(plotID)
		
		-- Check for Repair
		if pPlot:IsImprovementPillaged() and pPlot:GetPopulation() > 600 then -- to do : remove magic number
			self:AddToDecisionList( "VILLAGE_REBUILD", sDomainType, plotID)
		end
		
	end
end


function DoStrategy(self)
	Dprint( DEBUG_AI_SCRIPT, "   - TRIBE AI: Strategy...")
	
	local pPlayer 			= self:GetPlayer()
	local tVillages 		= GCO.GetPlayerTribalVillages(self.PlayerID)
	local influenceMap 		= pPlayer:GetInfluenceMap()
	local iCentralVillages	= 0
	
	-- Under threat
	local kThreatened = {}
	for _, plotKey in ipairs(tVillages) do
		local plotID 	= tonumber(plotKey)
		local pPlot		= GCO.GetPlotByIndex(plotID)
		local village	= GCO.GetTribalVillageAt(plotID)
		local threat	= influenceMap:Find( plotID )
		
		if village.IsCentral then
			iCentralVillages = iCentralVillages + 1
			-- check for garrison
			local bHasMeleeGarrison		= false
			local bHasRangedGarrison	= false
			local pPotentialMelee		= nil
			local pPotentialRanged		= nil
			local bNeedRangedGarrison 	= false
			local tUnits = Units.GetUnitsInPlot(pPlot)
			for i, pUnit in ipairs(tUnits) do
				if pUnit:IsCombat() then
					if GameInfo.Units[pUnit:GetType()].PromotionClass == "PROMOTION_CLASS_MELEE" then
						local pUnitAbility = pUnit:GetAbility()
						if pUnitAbility:HasAbility("ABILITY_NO_MOVEMENT") then
							bHasMeleeGarrison = true
							if pUnit:GetDamage() > 50 then
								bNeedRangedGarrison = true
							end
						else
							pPotentialMelee = pUnit
						end
					elseif GameInfo.Units[pUnit:GetType()].PromotionClass == "PROMOTION_CLASS_RANGED" then
						local pUnitAbility = pUnit:GetAbility()
						if pUnitAbility:HasAbility("ABILITY_NO_MOVEMENT") then
							bHasRangedGarrison = true
						else
							pPotentialRanged = pUnit
						end
					end
				end
			end
			
			if not bHasMeleeGarrison then
				Dprint( DEBUG_AI_SCRIPT, "      - Trying to set Melee garrison at at ", pPlot:GetX(), pPlot:GetY())
				if pPotentialMelee then
					local pUnitAbility = pPotentialMelee:GetAbility()
					pUnitAbility:ChangeAbilityCount("ABILITY_NO_MOVEMENT", 1)
					pPotentialMelee:SetValue("ActiveTurnsLeft", nil)
					if pPotentialMelee:GetDamage() > 50 then
						bNeedRangedGarrison = true
					end
					Dprint( DEBUG_AI_SCRIPT, "        - Found garrison : ".. Locale.Lookup(pPotentialMelee:GetName()))
				else
					
					self:AddToDecisionList( "CREATE_MELEE", "Defense", plotID, iNeutralOrder + 100)
					tDecisionFactor.Defense = tDecisionFactor.Defense + 100
					
				end
			end
			
			
			if bNeedRangedGarrison and not bHasRangedGarrison then
				Dprint( DEBUG_AI_SCRIPT, "      - Trying to set Ranged garrison at at ", pPlot:GetX(), pPlot:GetY())
				if pPotentialRanged then
					local pUnitAbility = pPotentialRanged:GetAbility()
					pUnitAbility:ChangeAbilityCount("ABILITY_NO_MOVEMENT", 1)
					pPotentialRanged:SetValue("ActiveTurnsLeft", nil)
					Dprint( DEBUG_AI_SCRIPT, "        - Found garrison : ".. Locale.Lookup(pPotentialRanged:GetName()))
				else
					
					self:AddToDecisionList( "CREATE_RANGED", "Defense", plotID, iNeutralOrder + 50)
					tDecisionFactor.Defense = tDecisionFactor.Defense + 50
				end
			end
			
		end
		
		if ( threat > 0 ) then
			if village.IsCentral then
				kThreatened[plotID] = kThreatened[plotID] and math.max(kThreatened[plotID], threat) or threat
			elseif village.CentralPlot then
				kThreatened[village.CentralPlot] = kThreatened[village.CentralPlot] and math.max(kThreatened[village.CentralPlot], threat) or threat
			end
		end
	end
	-- Has lost Village
	-- Has Target
	-- 
	
	-- Needs
	local bNeedRecon	= true
	local iNumRecon		= 0
	local playerUnits = pPlayer:GetUnits()
	for i, unit in playerUnits:Members() do
	
		local promotionClass = GameInfo.Units[unit:GetType()].PromotionClass
		if promotionClass == "PROMOTION_CLASS_SKIRMISHER" and unit:GetDamage() < 50 then  -- to do: remove magic number
			iNumRecon	= iNumRecon + 1
			if iNumRecon > (iCentralVillages * 0.5) then -- to do: remove magic number
				bNeedRecon = false
			end
		end
		
	end
	
	--
	-- Recruit
	--
	
	-- Respond to threats
	for plotID, threat in pairs(kThreatened) do
		
		local pPlot		= GCO.GetPlotByIndex(plotID)
		local village	= GCO.GetTribalVillageAt(plotID)
		
		Dprint( DEBUG_AI_SCRIPT, "      - Threat level = ", threat, " at ", pPlot:GetX(), pPlot:GetY())

		if village and village.IsCentral then
		
			-- Get defense to threat
			local combatDiff = 0
			for i, otherPlotID in ipairs(GCO.GetPlotsInRange(pPlot, 4)) do
				local otherPlot = GCO.GetPlotByIndex(otherPlotID)
				local tUnits 	= Units.GetUnitsInPlot(otherPlot)
				for i, pUnit in ipairs(tUnits) do
					if pUnit:IsCombat() then
						if pUnit:GetOwner() == self.PlayerID then
							combatDiff = combatDiff - (100 - pUnit:GetDamage())
						elseif pPlayer:GetDiplomacy():IsAtWarWith( pUnit:GetOwner() ) then
							combatDiff = combatDiff + (100 - pUnit:GetDamage())
						end
					end
				end
			end
		
			Dprint( DEBUG_AI_SCRIPT, "      - combatDiff after units count = ", combatDiff)
			
			if combatDiff > 0 then
				for i = 1, math.ceil(combatDiff/100) do
				
					local iOrderDiff = math.ceil(Div(50,i))
					self:AddToDecisionList( "CREATE_MELEE", "Defense", plotID, iNeutralOrder + iOrderDiff )
					tDecisionFactor.Defense = tDecisionFactor.Defense + iOrderDiff
				end
			end
		end
	end
	
	-- Spawn recon
	for _, plotKey in ipairs(tVillages) do
		local plotID 	= tonumber(plotKey)
		local pPlot		= GCO.GetPlotByIndex(plotID)
		local village	= GCO.GetTribalVillageAt(plotID)
	
		if village and village.IsCentral and bNeedRecon and pPlot:GetPopulation() > 600 then -- to do : remove magic number
		
			self:AddToDecisionList( "CREATE_SKIRMISHER", "Offense", plotID, iNeutralOrder )
		end
	end

end

--=====================================================================================--
-- 
--=====================================================================================--

function InitializeTribeAI(playerID, typeAI)
	if typeAI == AI_TYPE_NAME then
		Dprint( DEBUG_AI_SCRIPT, "   - Initialize AI for player#", playerID, typeAI)
		
		
		local pPlayer 	= GCO.GetPlayer(playerID)
		local pAI		= GCO.AI:Create(playerID) -- Create a default AI
		
		-- Set name to current AI
		pAI:SetValue("TypeName", AI_TYPE_NAME)
		
		-- Replace/Add AI functions
		pAI.DoTurn				= DoTurn
		pAI.DoDiplomacy			= DoDiplomacy
		pAI.DoHomeLand			= DoHomeLand
		pAI.DoStrategy			= DoStrategy
		pAI.AddToDecisionList	= AddToDecisionList
		pAI.DoTasks				= DoTasks
		--
		pPlayer:SetCached("AI", pAI)
	end
end
GameEvents.InitializePlayerAI.Add(InitializeTribeAI)