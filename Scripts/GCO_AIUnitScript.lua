--[[
local GCO 	= {}
local pairs = pairs
local Dprint, Dline, Dlog
function InitializeUtilityFunctions() 	-- Get functions from other contexts
	GCO 			= ExposedMembers.GCO
	Dprint 			= GCO.Dprint				-- Dprint(bOutput, str) : print str if bOutput is true
	Dline			= GCO.Dline					-- output current code line number to firetuner/log
	Dlog			= GCO.Dlog					-- log a string entry, last 10 lines displayed after a call to GCO.Error()
	pairs 			= GCO.OrderedPairs
	print("Exposed Functions from other contexts initialized...")

	local pVis = PlayersVisibility[Game.GetLocalPlayer()];
	for iPlotIndex = 0, Map.GetPlotCount()-1, 1 do
		pVis:ChangeVisibilityCount(iPlotIndex, 1);
	end
	
	Events.GameCoreEventPublishComplete.Add( MoveAllUnits )
end
GameEvents.InitializeGCO.Add( InitializeUtilityFunctions )

local moved = {}
function MoveAllUnits()
	for _, playerID in ipairs(PlayerManager.GetWasEverAliveIDs()) do
		if playerID ~= 0 then
			local player = Players[playerID]
			if (player:IsTurnActive()) then
				local playerConfig = PlayerConfigurations[playerID]
				print ("------------------------------")
				print("Units of " .. tostring(Locale.Lookup(playerConfig:GetCivilizationShortDescription())))
				local pPlayerUnits = player:GetUnits();
				for i, pUnit in pPlayerUnits:Members() do
					local key = playerID ..",".. pUnit:GetID()
					print(pUnit:GetName(), "GetMaxMoves :", pUnit:GetMaxMoves(), "GetMovesRemaining :", pUnit:GetMovesRemaining(), "GetMovementMovesRemaining :", pUnit:GetMovementMovesRemaining())

					if pUnit:GetMaxMoves() == pUnit:GetMovesRemaining() and moved[key] then
						print(" - Unit movement points restored after moving !")
						UnitManager.ChangeMovesRemaining(pUnit, - pUnit:GetMovesRemaining() )
					end
					
					if not moved[key] then
						local tParameters:table = {};
						tParameters[UnitOperationTypes.PARAM_X] = pUnit:GetX();
						tParameters[UnitOperationTypes.PARAM_Y] = pUnit:GetY()+2;
						tParameters[UnitOperationTypes.PARAM_MODIFIERS] = UnitOperationMoveModifiers.ATTACK + UnitOperationMoveModifiers.MOVE_IGNORE_UNEXPLORED_DESTINATION	
						GCO.RequestOperation( pUnit, UnitOperationTypes.MOVE_TO, tParameters)
					end
					
					if pUnit:GetMaxMoves() > pUnit:GetMovesRemaining() then
						print(" - Unit has moved")
						moved[key] = true
					end
				end
				
			end
		else
			local player = Players[playerID]
			if (player:IsTurnActive()) then
				moved = {}
			end		
		end
	end
end
--Events.GameCoreEventPublishComplete.Add( MoveAllUnits )
--]]

--[[
https://forums.civfanatics.com/threads/technical-commentary-on-civ-game-ai.629321/page-3#post-15053880
--]]

--[[

		local tParameters:table = {};
		tParameters[UnitOperationTypes.PARAM_X] = plotX;
		tParameters[UnitOperationTypes.PARAM_Y] = plotY;
		
			-- Air
			tParameters[UnitOperationTypes.PARAM_MODIFIERS] = UnitOperationMoveModifiers.ATTACK
				UnitManager.RequestOperation(kUnit, UnitOperationTypes.AIR_ATTACK, tParameters);
				UnitManager.RequestOperation(kUnit, UnitOperationTypes.DEPLOY, tParameters);
				
			-- Ranged
			tParameters[UnitOperationTypes.PARAM_MODIFIERS] = UnitOperationMoveModifiers.NONE
				UnitManager.RequestOperation(kUnit, UnitOperationTypes.RANGE_ATTACK, tParameters);
				
			-- Allow for attacking and don't early out if the destination is blocked, etc., but is in the fog.
			tParameters[UnitOperationTypes.PARAM_MODIFIERS] = UnitOperationMoveModifiers.ATTACK + UnitOperationMoveModifiers.MOVE_IGNORE_UNEXPLORED_DESTINATION	
				UnitManager.RequestOperation( kUnit, UnitOperationTypes.COASTAL_RAID, tParameters)
				UnitManager.RequestOperation( kUnit, UnitOperationTypes.SWAP_UNITS, tParameters)
				UnitManager.RequestOperation( kUnit, UnitOperationTypes.MOVE_TO, tParameters)
		
		
		tParameters[UnitOperationTypes.PARAM_MODIFIERS] = UnitOperationMoveModifiers.ATTACK
		
		
			UnitManager.RequestOperation(kUnit, UnitOperationTypes.RANGE_ATTACK, tParameters);
			UnitManager.RequestOperation(kUnit, UnitOperationTypes.COASTAL_RAID, tParameters);
			UnitManager.RequestOperation(kUnit, UnitOperationTypes.SWAP_UNITS, tParameters);
			UnitManager.RequestOperation(kUnit, UnitOperationTypes.MOVE_TO, tParameters);

--]]

--[[
		function RequestMoveOperation( kUnit:table, tParameters:table, plotX:number, plotY:number )
			-- Air units move and attack slightly differently than land and naval units
			if ( GameInfo.Units[kUnit:GetUnitType()].Domain == "DOMAIN_AIR" ) then
				tParameters[UnitOperationTypes.PARAM_MODIFIERS] = UnitOperationMoveModifiers.ATTACK;
				if (UnitManager.CanStartOperation( kUnit, UnitOperationTypes.AIR_ATTACK, nil, tParameters) ) then
					UnitManager.RequestOperation(kUnit, UnitOperationTypes.AIR_ATTACK, tParameters);
				elseif (UnitManager.CanStartOperation( kUnit, UnitOperationTypes.DEPLOY, nil, tParameters) ) then
					UnitManager.RequestOperation(kUnit, UnitOperationTypes.DEPLOY, tParameters);
				end
			else
				tParameters[UnitOperationTypes.PARAM_MODIFIERS] = UnitOperationMoveModifiers.NONE;
				if (UnitManager.CanStartOperation( kUnit, UnitOperationTypes.RANGE_ATTACK, nil, tParameters) and (kUnit:GetRangedCombat() > kUnit:GetCombat() or kUnit:GetBombardCombat() > kUnit:GetCombat() ) ) then
					UnitManager.RequestOperation(kUnit, UnitOperationTypes.RANGE_ATTACK, tParameters);
				else
					-- Allow for attacking and don't early out if the destination is blocked, etc., but is in the fog.
					tParameters[UnitOperationTypes.PARAM_MODIFIERS] = UnitOperationMoveModifiers.ATTACK + UnitOperationMoveModifiers.MOVE_IGNORE_UNEXPLORED_DESTINATION;
					if (UnitManager.CanStartOperation( kUnit, UnitOperationTypes.COASTAL_RAID, nil, tParameters) ) then
						UnitManager.RequestOperation( kUnit, UnitOperationTypes.COASTAL_RAID, tParameters);
					else
						-- Check that unit isn't already in the plot (essentially canceling the move),
						-- otherwise the operation will complete, and while no move is made, the next
						-- unit will auto seltect.
						if plotX ~= kUnit:GetX() or plotY ~= kUnit:GetY() then
							if (UnitManager.CanStartOperation( kUnit, UnitOperationTypes.SWAP_UNITS, nil, tParameters) ) then
								UnitManager.RequestOperation(kUnit, UnitOperationTypes.SWAP_UNITS, tParameters);
							else
								UnitManager.RequestOperation(kUnit, UnitOperationTypes.MOVE_TO, tParameters);
							end
						end
					end
				end
			end
		end
--]]

--[[
function MoveToXY(unit, x, y)
	--UnitManager.RestoreMovement(unit)
	UnitManager.MoveUnit( unit, x, y )
	--UnitManager.FinishMoves(unit)
	UnitManager.ChangeMovesRemaining(unit, - unit:GetMovesRemaining() )
end

function OnPlayerTurnStarted( iPlayer )
	print ("------------------------------")
	print ("PlayerTurnStarted")	
	print ("------------------------------")
	local player = Players[iPlayer]
	local playerConfig = PlayerConfigurations[iPlayer]
	print("Units of " .. tostring(Locale.Lookup(playerConfig:GetCivilizationShortDescription())))
	local pPlayerUnits = player:GetUnits();
	for i, pUnit in pPlayerUnits:Members() do
		--print(pUnit:GetName(), "GetMaxMoves :", pUnit:GetMaxMoves(), "GetMovesRemaining :", pUnit:GetMovesRemaining(), "GetMovementMovesRemaining :", pUnit:GetMovementMovesRemaining())
		UnitManager.ChangeMovesRemaining(pUnit, 2 )
		MoveToXY(pUnit, pUnit:GetX()+2 , pUnit:GetY())
		UnitManager.ChangeMovesRemaining(pUnit, - pUnit:GetMovesRemaining() )
	end
	for i, pUnit in pPlayerUnits:Members() do
		--print(pUnit:GetName(), "GetMaxMoves :", pUnit:GetMaxMoves(), "GetMovesRemaining :", pUnit:GetMovesRemaining(), "GetMovementMovesRemaining :", pUnit:GetMovementMovesRemaining())
		MoveToXY(pUnit, pUnit:GetX()-2 , pUnit:GetY())
	end
end
--GameEvents.PlayerTurnStarted.Add( OnPlayerTurnStarted )

function OnPlayerTurnActivated( iPlayer, bFirstTime )
	local player = Players[iPlayer]
	local pPlayerUnits = player:GetUnits();
	for i, pUnit in pPlayerUnits:Members() do
		UnitManager.ChangeMovesRemaining(pUnit, - pUnit:GetMovesRemaining() )
	end
end
--Events.PlayerTurnActivated.Add( OnPlayerTurnActivated )


function OnRemotePlayerTurnBegin( iPlayer )
	local player = Players[iPlayer]
	local pPlayerUnits = player:GetUnits();
	for i, pUnit in pPlayerUnits:Members() do
		UnitManager.ChangeMovesRemaining(pUnit, - pUnit:GetMovesRemaining() )
	end
end
--Events.RemotePlayerTurnBegin.Add( OnRemotePlayerTurnBegin )

function UnitMovementPointsRestored(PlayerID, UnitID)
	local unit = UnitManager.GetUnit(PlayerID, UnitID)
	MoveToXY(unit, unit:GetX()+2 , unit:GetY())
	--UnitManager.ChangeMovesRemaining(unit, - unit:GetMovesRemaining() )
end
Events.UnitMovementPointsRestored.Add( UnitMovementPointsRestored )
--]]