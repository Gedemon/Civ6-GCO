--=====================================================================================--
--	FILE:	 GCO_AIUnitScript.lua
--  Gedemon (2021)
--=====================================================================================--

print ("Loading GCO_AIUnitScript.lua...")

--=====================================================================================--
-- Includes
--=====================================================================================--
include( "GCO_TypeEnum" )
include( "GCO_SmallUtils" )



--=====================================================================================--
-- 
--=====================================================================================--

--[[

--]]


--[[

--]]

local targetX, targetY
function TestOperation(sOperation, iOriginPlot, iRangeGrabUnits, iTargetPlot, iAttacker, iDefender, iRallyPlot, bForceVisibility)
	print("Testing AI Scripted Operation :", sOperation, iOriginPlot, iRangeGrabUnits, iTargetPlot, iAttacker, iDefender, iRallyPlot, bForceVisibility)
	local GCO 			= ExposedMembers.GCO
	local pOriginPlot 	= Map.GetPlotByIndex(iOriginPlot)
	local pTargetPlot 	= Map.GetPlotByIndex(iTargetPlot)
	targetX, targetY	= pTargetPlot:GetX(), pTargetPlot:GetY()
	local tPlots 		= GCO.GetPlotsInRange(pOriginPlot, iRangeGrabUnits)
	local tUnits		= {}
	local pMilitaryAI	= Players[iAttacker]:GetAi_Military()
	local pVisibility	= PlayersVisibility[iAttacker]
	local bIsVisible	= pVisibility:GetState(iTargetPlot) ~= RevealedState.HIDDEN and pVisibility:GetState(iRallyPlot) ~= RevealedState.HIDDEN
	
	if not bIsVisible then
	
		if bForceVisibility then
			print("Forcing visibility on target and rally plots...")
			if pVisibility:GetState(iTargetPlot) == RevealedState.HIDDEN then
				print(" - Reveal target plot...")
				pVisibility:ChangeVisibilityCount(iTargetPlot, 1)
			end
			if pVisibility:GetState(iRallyPlot) == RevealedState.HIDDEN then
				print(" - Reveal rally plot...")
				pVisibility:ChangeVisibilityCount(iRallyPlot, 1)
			end
		else
			print("WARNING : Visibility issue, iTargetPlot =", pVisibility:GetState(iTargetPlot) ~= RevealedState.HIDDEN," , iRallyPlot = ", pVisibility:GetState(iRallyPlot) ~= RevealedState.HIDDEN)
		end
	
	end
	
	for _, iPlot in ipairs(tPlots) do
		local pPlot = Map.GetPlotByIndex(iPlot)
		if pPlot then 
			local pPlotUnits :table = Map.GetUnitsAt(pPlot);
			if pPlotUnits ~= nil then
				for pUnit :object in pPlotUnits:Units() do
					if pUnit:GetOwner() == iAttacker then
						print(" - Checking path for "..tostring(pUnit:GetName()))
						table.insert(tUnits, pUnit)
						
						local pathInfo, turnsList, obstacles = UnitManager.GetMoveToPath(pUnit, iTargetPlot)
						if #pathInfo > 1 then
							local bVisiblePath	= true
							for index, pathNode in ipairs(pathInfo) do
								if pVisibility:GetState(iTargetPlot) == RevealedState.HIDDEN then
									if bForceVisibility then
										pVisibility:ChangeVisibilityCount(pathNode, 1)
									else
										bVisiblePath = false
									end								
								end
							end
							if bVisiblePath then
								print("   - Clear path !")
							else
								print("   - No Visible path to Target !")
							end
						else
							print("   - No path to Target !")
						end
					end
				end
			end
		end
	end
	
	if #tUnits > 0 then
	
		local iOperationID = -1 --
		if iRallyPlot then
			print("Using StartScriptedOperationWithTargetAndRally...")
			iOperationID = pMilitaryAI:StartScriptedOperationWithTargetAndRally(sOperation, iDefender, iTargetPlot, iRallyPlot)
		else
			print("Using StartScriptedOperation...")
			iOperationID = pMilitaryAI:StartScriptedOperation(sOperation, iDefender, iTargetPlot)
		end
		
		if iOperationID ~= -1 then
			print("Launching operation #"..tostring(iOperationID).." with iRallyPlot =",iRallyPlot)
			for _, pUnit in ipairs(tUnits) do
				local test = pMilitaryAI:AddUnitToScriptedOperation(iOperationID, pUnit:GetID())
				print(" - Adding "..Locale.Lookup(pUnit:GetName()), test)
			end
		else
			print("WARNING, failed to launch operation...")
		end
	else
		print("WARNING, no units found to launch operation...")
	end
end

function listen(...)
    local args = {...}
    if args then
        print("---------------------------------------------------------------------------------- Start <")
        print("num arguments = " .. #args)
        print(unpack({...})) 
		for i = 1, #args do
            if type(args[i])== "table" then
                print("--------------- "..tostring(args[i]).." ---------------");
                for k, v in pairs(args[i]) do print(k,v) end
                print();
            end
        end
        print("------------------------------------------------------------------------------------ End >");
        print();
    else 
        print("---------------------------------------------------------------------------------- Start <")
        print("No arguments...")
        print("------------------------------------------------------------------------------------ End >");
        print();
    end
end
Events.UnitTeleported.Add(listen)

-- Lua callback for GCO test Behavior Operation.  Needs to always return true so not to fail the operation.
function OnTest(targetInfo :table)

	--print("On GCO_Test_Event - targetInfo ", targetInfo)
	for k, v in pairs(targetInfo) do
		print(" - ", k, v)
	end
	targetInfo.Extra = 1;
	return true;
end
GameEvents.GCO_Test_Event.Add(OnTest)
GameEvents.GCO_Run_Event.Add(OnTest)

-- Access to safe zone for game core, intended for use by the AI
function OnTestGoal(targetInfo)
	--print("On GCO_Test_Goal - targetInfo", targetInfo)
	for k, v in pairs(targetInfo) do
		print(" - ", k, v)
	end
	
	--targetInfo.PlotX = targetX
	--targetInfo.PlotY = targetY
	--targetInfo.Extra = Game:GetProperty(g_ObjectStateKeys.CurrentSafeZoneDistance);

	targetInfo.Extra = 1;
	
	return true
end
GameEvents.GCO_Test_Goal.Add(OnTestGoal);
--GCO_Test_Goal

--[[

Attack Barb Camp			TARGET_BARBARIAN_CAMP	0	NONE	Simple Operation Attack	3	-1	25	0	-1	-1	0.5	1	0	0	-1	ATTACK_BARBARIANS	1		
Barb Camp Tech Boost		TARGET_BARBARIAN_CAMP	0	NONE	Simple Operation Attack	3	-1	-1	0	-1	-1	0.0	0	0	0	-1	ATTACK_BARBARIANS	1		
Attack Enemy City			TARGET_ENEMY_COMBAT_DISTRICT	0	WAR	Early City Assault	3	-1	30	0	-1	-1	0.5	1	0	0	5	CITY_ASSAULT	1		
Wartime Attack Enemy City	TARGET_ENEMY_COMBAT_DISTRICT	0	WAR	Early City Assault	3	-1	45	-1	-1	-1	0.25	1	1	0	3	CITY_ASSAULT	1		
Attack Walled City			TARGET_ENEMY_COMBAT_DISTRICT	1	WAR	Siege City Assault	3	-1	30	0	-1	-1	0.6	1	0	0	10	CITY_ASSAULT	1		
Wartime Attack Walled City	TARGET_ENEMY_COMBAT_DISTRICT	1	WAR	Siege City Assault	3	-1	45	-1	-1	-1	0.4	1	1	0	6	CITY_ASSAULT	1		
Barbarian Builder Capture	TARGET_BARBARIAN_CAMP	0	NONE	Escort Worker To Camp	3	-1	-1	0	-1	-1	0.0	0	0	0	-1		1		
Civilian Builder Capture	TARGET_FRIENDLY_CITY	0	NONE	Escort Worker To Camp	1	-1	-1	0	-1	-1	0.0	0	0	0	-1		1		
Settle New City				TARGET_SETTLE_LOCATION	0	NONE	Settle City Op	4	-1	-1	-1	-1	-1	0.0	0	0	0	-1	OP_SETTLE	1		
City Defense				TARGET_FRIENDLY_CITY	1	NONE	Simple City Defense	4	-1	-1	0	-1	-1	0.0	0	0	0	-1		1		
Barbarian Attack			TARGET_ENEMY_COMBAT_DISTRICT	0	NONE	Raid City	3	10	5	0	-1	-1	0.0	0	0	0	-1		0		
Barbarian City Assault		TARGET_ENEMY_COMBAT_DISTRICT	0	NONE	Barbarian City Attack	4	10	5	0	-1	-1	0.0	0	0	0	-1		0		
Nuclear Assault				TARGET_ENEMY_COMBAT_DISTRICT	1	WAR	Nuclear Assault	3	-1	-1	0	-1	-1	0.0	1	1	1	-1	OP_NUCLEAR	1		
Aid Ally					TARGET_ALLY_SUPPORT	0	ALLY	Reinforce Ally	3	-1	45	0	-1	-1	0.0	1	0	0	-1	CITY_ASSAULT	1		
Naval Superiority			TARGET_NAVAL_SUPERIORITY	0	NONE	Naval Superiority Tree	2	-1	-1	-1	-1	-1	0.0	1	0	0	-1	NAVAL_SUPERIORITY	1		


GetAi_Military	AddUnitToScriptedOperation
GetAi_Military	AllowUnitConstruction
GetAi_Military	CanConstructUnits
GetAi_Military	HasOperationAgainst
GetAi_Military	PrepareForWarWith
GetAi_Military	ScriptForceUpdateTargets
GetAi_Military	SetRival
GetAi_Military	SetScriptedOperationReady
GetAi_Military	SetScriptedTargetAndRally
GetAi_Military	StartScriptedOperation
GetAi_Military	StartScriptedOperationWithTargetAndRally

  <TargetTypes>
    <Row TargetType="TARGET_FRIENDLY_CITY" />
    <Row TargetType="TARGET_ENEMY_COMBAT_DISTRICT" />
    <Row TargetType="TARGET_ENEMY_PASSIVE_DISTRICT" />
    <Row TargetType="TARGET_NEUTRAL_CITY" />
    <Row TargetType="TARGET_BARBARIAN_CAMP" />
    <Row TargetType="TARGET_NEUTRAL_CIVILIAN_UNIT" />
    <Row TargetType="TARGET_CIVILIAN_UNIT" />
    <Row TargetType="TARGET_RELIGIOUS_CIVILIAN" />
    <Row TargetType="TARGET_TRADER" />
    <Row TargetType="TARGET_LOW_PRIORITY_UNIT" />
    <Row TargetType="TARGET_MEDIUM_PRIORITY_UNIT" />
    <Row TargetType="TARGET_HIGH_PRIORITY_UNIT" />
    <Row TargetType="TARGET_ENEMY_IMPROVEMENT" />
    <Row TargetType="TARGET_SETTLE_LOCATION" />
    <Row TargetType="TARGET_GOODY_HUT" />
    <Row TargetType="TARGET_ALLY_SUPPORT" />
    <Row TargetType="TARGET_AIR_UNIT" />
    <Row TargetType="TARGET_NAVAL_SUPERIORITY"/> <!-- Note: 'blank' target intended for use by the naval superiority op. -->
    <Row TargetType="TARGET_SCRIPT_SUPPLIED"/>  <!-- For scenario usage. Will call the lua script supplied in the operation definition -->
  </TargetTypes>

--]]


--[[
function StartTreasureFleet()
	local startCity :object = GetTreasureFleetStartCity();
	if(startCity == nil) then
		print("Error: No start city found for Treasure fleet!");
		return;
	end

	-- Treasure Fleet AI can't be started on the first game turn.
	if(Game.GetCurrentGameTurn() == GameConfiguration.GetStartTurn()) then
		return;
	end

	if(startCity:GetOwner() == NO_PLAYER) then
		print("Error: no owner in treasure fleet start city?");
		return;
	end

	print("Spawning treasure fleet location=(" .. tostring(startCity:GetX()) .. ", " .. tostring(startCity:GetY()) .. ")");
	local startPlayer :object = Players[startCity:GetOwner()];
	local startUnits :object = startPlayer:GetUnits();

	-- Start AI Operation.
	local pMilitaryAI :object = startPlayer:GetAi_Military();
	if(pMilitaryAI == nil) then
		print("ERROR: No military AI found.");
		return;
	end
	local rallyPlot :object = Map.GetPlot(startCity:GetX(), startCity:GetY());
	if(rallyPlot == nil) then
		print("ERROR: could not find rally plot.");
		return;
	end
	local treasurePlotIndex :number = Game:GetProperty(g_gamePropertyKeys.TreasureFleetPlotIndex);
	if(treasurePlotIndex == nil) then
		print("ERROR: treasure plot index not set.");
		return;
	end
	local treasurePlot :object = Map.GetPlotByIndex(treasurePlotIndex);
	if(treasurePlot == nil) then
		print("ERROR: treasure plot missing.");
		return;
	end

	local treasureFleetID :number = GetNextTreasureFleetID();

	local iOperationID = pMilitaryAI:StartScriptedOperationWithTargetAndRally("Treasure Fleet Op", NO_PLAYER, treasurePlot:GetIndex(), rallyPlot:GetIndex());

	-- Spawn treasure ships
	for treasureShipIndex = 1, TREASURE_FLEET_GOLD_BOATS, 1 do
		local newTreasureShip :object = startUnits:Create(ms_galleonUnitType, startCity:GetX(), startCity:GetY());
		if(newTreasureShip == nil) then
			print("ERROR: Treasure fleet gold ship failed to spawn");
		else
			newTreasureShip:GetExperience():SetVeteranName(Locale.Lookup("LOC_UNIT_TREASURE_FLEET_GOLD_SHIP_NAME"));
			newTreasureShip:SetProperty(g_unitPropertyKeys.TreasureFleetGoldShip, 1);
			newTreasureShip:SetProperty(g_unitPropertyKeys.TreasureFleetID, treasureFleetID);
			pMilitaryAI:AddUnitToScriptedOperation(iOperationID, newTreasureShip:GetID());
		end
	end

	for guardShipIndex = 1, TREASURE_FLEET_GUARD_BOATS, 1 do
		local newGuardShip :object = startUnits:Create(ms_brigantineUnitType, startCity:GetX(), startCity:GetY());
		if(newGuardShip == nil) then
			print("ERROR: Treasure fleet guard ship failed to spawn");
		else
			newGuardShip:GetExperience():SetVeteranName(Locale.Lookup("LOC_UNIT_TREASURE_FLEET_GUARD_SHIP_NAME"));
			newGuardShip:SetProperty(g_unitPropertyKeys.TreasureFleetGuardShip, 1);
			newGuardShip:SetProperty(g_unitPropertyKeys.TreasureFleetID, treasureFleetID);
			pMilitaryAI:AddUnitToScriptedOperation(iOperationID, newGuardShip:GetID());
		end
	end

	-- Cache the treasureFleetPath for this treasure fleet.
	local treasureFleetPaths :table = Game:GetProperty(g_gamePropertyKeys.TreasureFleetPaths);
	if(treasureFleetPaths == nil) then
		treasureFleetPaths = {};
	end
	treasureFleetPaths = AddTreasureFleetPathsForPlayer(startPlayer:GetID(), treasureFleetPaths);
	Game:SetProperty(g_gamePropertyKeys.TreasureFleetPaths, treasureFleetPaths);

	local cityPlot :object = Map.GetPlot(startCity:GetX(), startCity:GetY());
	SendNotification_Plot(g_NotificationsData.NewTreasureFleet, cityPlot);
end


---------------------------------------------------------------- 
-- AI Functions
---------------------------------------------------------------- 
-- Lua callback for Treasure Fleet Behavior Operation.  Needs to always return true so not to fail the operation.
function OnPiratesScenario_DeleteUnitsAtGoal(targetInfo :table)
	-- Delete any operation boats that have made it to the exit plot.
	local treasurePlotIndex :number = Game:GetProperty(g_gamePropertyKeys.TreasureFleetPlotIndex);
	if(treasurePlotIndex == nil) then
		return true;
	end

	local treasurePlot :object = Map.GetPlotByIndex(treasurePlotIndex);
	if(treasurePlot == nil) then
		return true;
	end

	local treasurePlotUnits :table = Map.GetUnitsAt(treasurePlot);
	if treasurePlotUnits ~= nil then
		for pPlotUnit :object in treasurePlotUnits:Units() do
			if(IsTreasureFleetUnit(pPlotUnit) and pPlotUnit:GetOwner() ~= NO_PLAYER) then
				local pOwner :object = Players[pPlotUnit:GetOwner()];
				local pOwnerUnits :object = pOwner:GetUnits();
				print("Treasure Fleet Ship Name=" .. tostring(pPlotUnit:GetName()) .. " reached treasure exit plot.");
				pOwnerUnits:Destroy(pPlotUnit);
			end
		end
	end

	targetInfo.Extra = 1;
	return true;
end
GameEvents.PiratesScenario_DeleteUnitsAtGoal.Add(OnPiratesScenario_DeleteUnitsAtGoal)
--]]


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


