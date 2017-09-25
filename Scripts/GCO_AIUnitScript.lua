

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