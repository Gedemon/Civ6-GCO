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
local DEBUG_AI_SCRIPT 	= "debug"
local AI_TYPE_NAME		= "TribeAI"

local tDecisions		= {}
local tDecisionFactor	= {}
local iNeutralOrder		= 100

local NO_PLAYER = -1

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

	Dprint( DEBUG_AI_SCRIPT, "- AddToDecisionList", sTaskType, sDomainType, plotID, iOrder)
		
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
	local pPlayerVis		= PlayerVisibilityManager.GetPlayerVisibility(self.PlayerID) -- pPlayerVis:GetState(plotIndex) == RevealedState.HIDDEN VISIBLE REVEALED
	local tVillages 		= GCO.GetPlayerTribalVillages(self.PlayerID)
	local influenceMap 		= pPlayer:GetInfluenceMap()
	local pDiplomacy		= pPlayer:GetDiplomacy()
	local playerUnits 		= pPlayer:GetUnits()
	local pMilitaryAI		= pPlayer:GetAi_Military()
	local iCentralVillages	= 0
	local kActiveTargets	= {}
	local kPlayerOperations	= GCO.GetPlayerOperationData(self.PlayerID)
	
	-- Cache current operations targets plotIDs (to not launch another operation on an existing target at a different turn)
	for operationKey, operationData in ipairs(kPlayerOperations) do
		kActiveTargets[operationData.Target] = true
	end
	
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
					local promotionClass = GameInfo.Units[pUnit:GetType()].PromotionClass
					if promotionClass == "PROMOTION_CLASS_MELEE" or promotionClass == "PROMOTION_CLASS_CONSCRIPT" then
						local pUnitAbility = pUnit:GetAbility()
						if pUnitAbility:HasAbility("ABILITY_NO_MOVEMENT") then
							bHasMeleeGarrison = true
							if pUnit:GetDamage() > 50 then
								bNeedRangedGarrison = true
							end
						else
							pPotentialMelee = pUnit
						end
					elseif promotionClass == "PROMOTION_CLASS_RANGED" then
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
					
					self:AddToDecisionList( "CREATE_GARRISON", "Defense", plotID, iNeutralOrder + 100)
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
			
		-- Offense ?
		elseif village.IsCentral then
		
			-- Has close and easy Target ?
			local bestTarget 		= nil
			local bestPopulation	= 0
			for i, otherPlotID in ipairs(GCO.GetPlotsInRange(pPlot, 5)) do
				if (not kActiveTargets[otherPlotID]) and pPlayerVis:GetState(otherPlotID) == RevealedState.REVEALED then
					local otherVillage	= GCO.GetTribalVillageAt(otherPlotID)
					if otherVillage and (otherVillage.Owner == NO_PLAYER or pDiplomacy:IsAtWarWith( otherVillage.Owner )) then
						local otherPlot		= GCO.GetPlotByIndex(otherPlotID)
						local population 	= otherPlot:GetPopulation()
						
						if not otherVillage.IsCentral then
							if population > bestPopulation then
								Dprint( DEBUG_AI_SCRIPT, "      - Found potential target for central village at ", pPlot:GetX(), pPlot:GetY(), ", other village at ", otherPlot:GetX(), otherPlot:GetY(), " population = ", population, " owner = ", otherVillage.Owner)
								bestTarget 		= otherPlot
								bestPopulation	= population
							end
							
						-- to do : military target
						else
						
						end
					end
				end
			end
			
			if bestTarget then
				
				Dprint( DEBUG_AI_SCRIPT, "        - Try to set up Short Move Operation to ", bestTarget:GetX(), bestTarget:GetY())
				
				local iTarget 		= bestTarget:GetIndex()
				local sOperation 	= "GCO Move Op Short"
				
				-- Check for available units in target range
				local tUnitList = {}
				for i, pUnit in playerUnits:Members() do
					 
					if pUnit:IsCombat() and not (GCO.GetUnitOperation(pUnit)) then
					
						local iDistance = Map.GetPlotDistance(pUnit:GetX(), pUnit:GetY(), bestTarget:GetX(), bestTarget:GetY())
					
						if iDistance < 6 then
					
							local tPath, tTurns		= UnitManager.GetMoveToPath(pUnit, iTarget)--GCO.GetMoveToPath( unit, cityPlot:GetIndex() )
							
							if tTurns[#tTurns] then
								Dprint( DEBUG_AI_SCRIPT, "          - potential unit : ", Locale.Lookup(pUnit:GetName()), ", ActiveTurnLeft =", pUnit:GetValue("ActiveTurnsLeft"), ", Turns to reach target = ", tTurns[#tTurns], ", pos = ", pUnit:GetX(), pUnit:GetY())
								
								local activeTurnsLeft 	= pUnit:GetValue("ActiveTurnsLeft")
								local bIsAvailable		= activeTurnsLeft == nil or activeTurnsLeft >= tTurns[#tTurns] -- list of turns, must get the last entry then substract the current game turn to get the number of turns to reach !
								
								if bIsAvailable then
									table.insert(tUnitList, pUnit:GetID()) -- to do: order by number turn to reach, and grab only a few depending on opposition
								end
							end
						end
					end
				end
				if #tUnitList > 0 then
					
					local targetVillage	= GCO.GetTribalVillageAt(iTarget)
					
					--Dprint( DEBUG_AI_SCRIPT, "        - Trying to launch operation ", sOperation, targetVillage.Owner, iTarget, iTarget)
					
					--local iOperationID	= pMilitaryAI:StartScriptedOperationWithTargetAndRally(sOperation, targetVillage.Owner, iTarget, iTarget)
					local iOperationID	= GCO.StartPlayerOperation(self.PlayerID, sOperation,targetVillage.Owner, iTarget, iTarget, plotID)
					
					--if iOperationID ~= -1 then
					
					if iOperationID then
					
						--[[
						Dprint( DEBUG_AI_SCRIPT, "        - Launched operation #"..tostring(iOperationID))
						
						local operationData 	= {} --  { Type = OperationType, TurnsLeft = iTurn, Origin = plotID, Target = plotID, Rally = plotID, Units = {unitID, ...} }
						operationData.Type		= sOperation
						operationData.Origin	= plotID
						operationData.Target	= iTarget
						operationData.Rally		= iTarget
						operationData.Units		= tUnitList
						operationData.TurnsLeft	= iTurnLimit
						
						GCO.AddPlayerOperation (self.PlayerID, iOperationID, operationData)
						--]]
						
						
						for _, unitID in ipairs(tUnitList) do
						
							local pUnit = GCO.GetUnit( self.PlayerID, unitID )
						
							Dprint( DEBUG_AI_SCRIPT, "           - Adding Unit : "..Locale.Lookup(pUnit:GetName()), ", pos = ", pUnit:GetX(), pUnit:GetY())
							
							--pMilitaryAI:AddUnitToScriptedOperation(iOperationID, unitID)
							--GCO.SetUnitOperation(pUnit, iOperationID)
														
							GCO.AddUnitToOperation(pUnit, iOperationID)
						end
						
					--else
						--GCO.Warning("Failed to launch operation for player#".. tostring( self.PlayerID ).. ",".. tostring(sOperation))
					end
					
				-- try to spawn unit for next turn check	
				elseif pPlot:GetPopulation() > 900 then
				
					Dprint( DEBUG_AI_SCRIPT, "        - no unit found, try to spawn for next turn...")
					self:AddToDecisionList( "CREATE_MELEE", "Offense", plotID, iNeutralOrder + math.ceil(bestPopulation*0.25) )
					--self:AddToDecisionList( "CREATE_RANGED", "Offense", plotID, iNeutralOrder + iOrderDiff )
					
				else
					Dprint( DEBUG_AI_SCRIPT, "        - no unit found, abandon target...")
				end
			end
			
		end
	end 
	
	-- Get close units
	
	-- Needs
	local bNeedRecon	= true
	local iNumRecon		= 0
	for i, unit in playerUnits:Members() do
	
		local promotionClass = GameInfo.Units[unit:GetType()].PromotionClass
		if promotionClass == "PROMOTION_CLASS_SKIRMISHER" then
			if unit:GetDamage() < 50 then  -- to do: remove magic number
				iNumRecon	= iNumRecon + 1
				if iNumRecon > (iCentralVillages * 0.5) then -- to do: remove magic number
					bNeedRecon = false
				end
			end
			
		end
		
		if not (GCO.GetUnitOperation(unit)) then
		
			local pUnitAbility = unit:GetAbility()
			
			if not pUnitAbility:HasAbility("ABILITY_NO_MOVEMENT") then
		
				local iActiveTurnsLeft = unit:GetValue("ActiveTurnsLeft")
				if (iActiveTurnsLeft and iActiveTurnsLeft < 3) or unit:GetDamage() > 75 then
				
					-- to do : check stock ?
					local iNeedBackHome = (5 - (iActiveTurnsLeft or 0)) + (unit:GetDamage() * 0.1)
					if TerrainBuilder.GetRandomNumber(iNeedBackHome, "Check to go back home") >= 3 then
					
						Dprint( DEBUG_AI_SCRIPT, "        - Unit want to go back home : "..Locale.Lookup(unit:GetName()), ", pos = ", unit:GetX(), unit:GetY(), ", iNeedBackHome =", iNeedBackHome)
						
						local sOperation 	= "GCO Run Op"
						local homePlotID 	= GCO.FindNearestPlayerVillage( self.PlayerID, unit:GetX(), unit:GetY() )
						local unitPlot		= Map.GetPlot(unit:GetX(), unit:GetY())
						
						if homePlotID then
							--Dprint( DEBUG_AI_SCRIPT, "        - Trying to launch operation ", sOperation, NO_PLAYER, homePlotID, homePlotID)

							--local iOperationID	= pMilitaryAI:StartScriptedOperationWithTargetAndRally(sOperation, NO_PLAYER, homePlotID, homePlotID)
							local iOperationID	= GCO.StartPlayerOperation(self.PlayerID, sOperation, NO_PLAYER, homePlotID, homePlotID, homePlotID)
							
							--if iOperationID ~= -1 then
							if iOperationID then
							
								--Dprint( DEBUG_AI_SCRIPT, "        - Launched operation #"..tostring(iOperationID))
								
								--[[
								pMilitaryAI:AddUnitToScriptedOperation(iOperationID, unit:GetID())
								
								local operationData 	= {} --  { Type = OperationType, TurnsLeft = iTurn, Origin = plotID, Target = plotID, Rally = plotID, Units = {unitID, ...} }
								operationData.Type		= sOperation
								operationData.Origin	= unitPlot:GetIndex()
								operationData.Target	= homePlotID
								operationData.Rally		= homePlotID
								operationData.Units		= { unit:GetID() }
								operationData.TurnsLeft	= iTurnLimit
								
								GCO.AddPlayerOperation (self.PlayerID, iOperationID, operationData)
								GCO.SetUnitOperation(unit, iOperationID)
								--]]
								
								GCO.AddUnitToOperation(unit, iOperationID)
								
							else
								GCO.Warning("Failed to launch operation for player#".. tostring( self.PlayerID ).. ",".. tostring(sOperation))
							end
						else				
							Dprint( DEBUG_AI_SCRIPT, "        - Can't find way Home...")
						end
					end
				end
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
				if pPlayerVis:GetState(otherPlotID) == RevealedState.VISIBLE then
					local otherPlot = GCO.GetPlotByIndex(otherPlotID)
					local tUnits 	= Units.GetUnitsInPlot(otherPlot)
					for i, pUnit in ipairs(tUnits) do
						if pUnit:IsCombat() then
							if pUnit:GetOwner() == self.PlayerID then
								combatDiff = combatDiff - (100 - pUnit:GetDamage())
							elseif pDiplomacy:IsAtWarWith( pUnit:GetOwner() ) then
								combatDiff = combatDiff + (100 - pUnit:GetDamage())
							end
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