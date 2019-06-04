
-- ===========================================================================
-- INCLUDE BASE FILE
-- ===========================================================================
include("ActionPanel")

print("Loading ActionPanel_GCO.lua.")
local GameEvents	= ExposedMembers.GameEvents

-- ===========================================================================
--	Attempt to end the turn or execute the most current blocking notification
-- ===========================================================================
function DoEndTurn( optionalNewBlocker:number )

	local pPlayer = Players[Game.GetLocalPlayer()];
	if (pPlayer == nil) then
		return;
	end

	-- If the player can unready their turn, request that.
	-- CanUnreadyTurn() only checks the gamecore state. IsTurnTimerElapsed() is also required to ensure the local player still has turn time remaining.
	if pPlayer:CanUnreadyTurn()
		and not UI.IsTurnTimerElapsed(Game.GetLocalPlayer()) then
		UI.RequestAction(ActionTypes.ACTION_UNREADYTURN);	
		return;
	end

	if UI.IsProcessingMessages() then
		print("ActionPanel:DoEndTurn() The game is busy processing messages");
		return;
	end

	-- If not in selection mode; reset mode before performing the action.
	if UI.GetInterfaceMode() ~= InterfaceModeTypes.SELECTION then
		UI.SetInterfaceMode(InterfaceModeTypes.SELECTION);
	end


	-- Make sure if an active blocker is not set, to do one more check from the engine/authority.
	if optionalNewBlocker ~= nil then
		m_activeBlockerId = optionalNewBlocker;
	else
		m_activeBlockerId = NotificationManager.GetFirstEndTurnBlocking(Game.GetLocalPlayer());
	end
	
	if m_activeBlockerId == EndTurnBlockingTypes.NO_ENDTURN_BLOCKING then
		if (CheckUnitsHaveMovesState()) then
			UI.SelectNextReadyUnit();
		elseif(CheckCityRangeAttackState()) then
			local attackCity = pPlayer:GetCities():GetFirstRangedAttackCity();
			if(attackCity ~= nil) then
				UI.SelectCity(attackCity);
				UI.SetInterfaceMode(InterfaceModeTypes.CITY_RANGE_ATTACK);
			else
				error( "Unable to find selectable attack city while in CheckCityRangeAttackState()" );
			end
		else
			LocalPlayerEndTurnSave()
			UI.RequestAction(ActionTypes.ACTION_ENDTURN);		
			UI.PlaySound("Stop_Unit_Movement_Master");
		end
	
	elseif (   m_activeBlockerId == EndTurnBlockingTypes.ENDTURN_BLOCKING_STACKED_UNITS
			or m_activeBlockerId == EndTurnBlockingTypes.ENDTURN_BLOCKING_UNIT_NEEDS_ORDERS
			or m_activeBlockerId == EndTurnBlockingTypes.ENDTURN_BLOCKING_UNITS)	then

		UI.SelectNextReadyUnit();

	else		

		-- generic turn blocker, trigger the notification associated with the turn blocker.
		local pNotification :table = NotificationManager.FindEndTurnBlocking(m_activeBlockerId, Game.GetLocalPlayer());
		
		if pNotification == nil then
			-- Notification is missing.  Use fallback behavior.
			if not UI.CanEndTurn() then
				print("ERROR: ActionPanel UI thinks that we can't end turn, but the notification system disagrees");
				return;
			end
			LocalPlayerEndTurnSave()
			UI.RequestAction(ActionTypes.ACTION_ENDTURN);		
			return;
		end

		-- Raise the event across the UI which may be listening for this particular notification.
		LuaEvents.ActionPanel_ActivateNotification( pNotification );
	end

end

local autoSaveNum = 0
function LocalPlayerEndTurnSave()
	-- Making our own auto save...
	GameEvents.SaveTables.Call() -- done on "EndTurn" action ID in GCO_SaveLoad.lua
	autoSaveNum = autoSaveNum + 1
	if autoSaveNum > 5 then autoSaveNum = 1 end
	local saveGame = {};
	saveGame.Name = "GCO-EndTurnAutoSave"..tostring(autoSaveNum)
	saveGame.Location = SaveLocations.LOCAL_STORAGE
	saveGame.Type= SaveTypes.SINGLE_PLAYER
	saveGame.IsAutosave = true
	saveGame.IsQuicksave = false
	GameEvents.SaveGameGCO.Call(saveGame)
end