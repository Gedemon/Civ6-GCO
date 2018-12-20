﻿-- ===========================================================================
---- ESPIONAGE OVERVIEW ----
-- ===========================================================================
print("Loading EspionageOverview.lua.")

include( "InstanceManager" );
include( "AnimSidePanelSupport" );
include( "SupportFunctions" );
include( "EspionageSupport" );
include( "TabSupport" );

-- ===========================================================================
-- CONSTANTS
-- ===========================================================================

local RELOAD_CACHE_ID:string = "EspionageOverview"; -- Must be unique (usually the same as the file name)
local MAX_BEFORE_TRUNC_MISSION_NAME		:number = 170;
local MAX_BEFORE_TRUNC_ASK_FOR_TRADE	:number = 135;

local TRAVEL_DEST_TRUNCATE_WIDTH		:number = 170;

local EspionageTabs:table = {
	OPERATIVES		= 0;
	CITY_ACTIVITY	= 1;
	MISSION_HISTORY	= 2;
};

-- ===========================================================================
--	MEMBERS
-- ===========================================================================

local m_AnimSupport:table; -- AnimSidePanelSupport

local m_OperativeIM:table		= InstanceManager:new("OperativeInstance", "Top", Controls.OperativeStack);
local m_CityIM:table			= InstanceManager:new("CityInstance", "CityGrid", Controls.CityActivityStack);
local m_EnemyOperativeIM:table	= InstanceManager:new("EnemyOperativeInstance", "GridButton", Controls.CapturedEnemyOperativeStack);
local m_MissionHistoryIM:table	= InstanceManager:new("MissionHistoryInstance", "Top", Controls.MissionHistoryStack);

-- A table of tabs indexed by EspionageTabs enum
local m_tabs:table = nil;
local m_selectedTab:number = -1;

-- ===========================================================================
function Refresh()
	-- Refresh Tabs
	PopulateTabs();

	if m_selectedTab == EspionageTabs.OPERATIVES then
		Controls.OperativeTabContainer:SetHide(false);
		Controls.CityActivityTabContainer:SetHide(true);
		Controls.MissionHistoryTabContainer:SetHide(true);

		RefreshOperatives();
	elseif m_selectedTab == EspionageTabs.CITY_ACTIVITY then
		Controls.OperativeTabContainer:SetHide(true);
		Controls.CityActivityTabContainer:SetHide(false);
		Controls.MissionHistoryTabContainer:SetHide(true);

		RefreshCityActivity();
	elseif m_selectedTab == EspionageTabs.MISSION_HISTORY then
		Controls.OperativeTabContainer:SetHide(true);
		Controls.CityActivityTabContainer:SetHide(true);
		Controls.MissionHistoryTabContainer:SetHide(false);

		RefreshMissionHistory();
	end
end

function RefreshOperatives()
	m_OperativeIM:ResetInstances();

	local localPlayerID = Game.GetLocalPlayer();
	if (localPlayerID == -1) then
		return;
	end

	local idleSpies:table = {};
	local activeSpies:table = {};
	local travellingSpies:table = {};

	-- Track the number of spies for display in the header
	local numberOfSpies:number = 0;

	-- Sort spies
	local localPlayerUnits:table = Players[localPlayerID]:GetUnits();
	for i, unit in localPlayerUnits:Members() do
		local unitInfo:table = GameInfo.Units[unit:GetUnitType()];
		if unitInfo.Spy then
			local operationType:number = unit:GetSpyOperation();
			if operationType == -1 then
				table.insert(idleSpies, unit);
			else
				table.insert(activeSpies, unit);
			end

			numberOfSpies = numberOfSpies + 1;
		end
	end

	-- Display idle spies
	for i, spy in ipairs(idleSpies) do
		AddOperative(spy);
	end

	-- Display active spies
	for i, spy in ipairs(activeSpies) do
		AddOperative(spy);
	end

	-- Display captured spies
	-- Loop through all players to see if they have any of our captured spies
	local players:table = Game.GetPlayers();
	for i, player in ipairs(players) do
		local playerDiplomacy:table = player:GetDiplomacy();
		local numCapturedSpies:number = playerDiplomacy:GetNumSpiesCaptured();
		for i=0,numCapturedSpies-1,1 do
			local spyInfo:table = playerDiplomacy:GetNthCapturedSpy(player:GetID(), i);
			if spyInfo and spyInfo.OwningPlayer == Game.GetLocalPlayer() then
				AddCapturedOperative(spyInfo, player:GetID());
				numberOfSpies = numberOfSpies + 1;
			end
		end
	end

	-- Display travelling spies
	local playerDiplomacy:table = Players[Game.GetLocalPlayer()]:GetDiplomacy();
	if playerDiplomacy then
		local numSpiesOffMap:number = playerDiplomacy:GetNumSpiesOffMap();
		for i=0,numSpiesOffMap-1,1 do
			local spyOffMapInfo:table = playerDiplomacy:GetNthOffMapSpy(Game.GetLocalPlayer(), i);
			if spyOffMapInfo and spyOffMapInfo.ReturnTurn ~= -1 then
				AddOffMapOperative(spyOffMapInfo);
				numberOfSpies = numberOfSpies + 1;
			end
		end
	end

	-- Update spy count and capcity
	local playerDiplomacy:table = Players[Game.GetLocalPlayer()]:GetDiplomacy();
	Controls.OperativeHeader:SetText(Locale.Lookup("LOC_ESPIONAGEOVERVIEW_OPERATIVES_SUBHEADER", numberOfSpies, playerDiplomacy:GetSpyCapacity()));

	Controls.OperativeStack:CalculateSize();
	Controls.OperativeScrollPanel:CalculateSize();
end

-- ===========================================================================
function RefreshCityActivity()
	m_CityIM:ResetInstances();

	local localPlayer:table = Players[Game.GetLocalPlayer()];
	if not localPlayer then
		return;
	end

	-- Add player owned cities
	AddPlayerCities(localPlayer);

	-- Add cities for other players
	local players:table = Game.GetPlayers();
	for i, player in ipairs(players) do
		-- Ignore the local player since those cities were already added
		if player:GetID() ~= localPlayer:GetID() then
			-- Only show full civs
			if player:IsMajor() then
				AddPlayerCities(player);
			end
		end
	end

	Controls.CityActivityScrollPanel:CalculateSize();
end

-- ===========================================================================
function RefreshMissionHistory()
	m_EnemyOperativeIM:ResetInstances();

	local localPlayerID = Game.GetLocalPlayer();
	if (localPlayerID == -1) then
		return;
	end

	-- Track size of elements in mission history panel to determine size of the mission history scroll panel
	local desiredScrollPanelSizeY:number = Controls.MissionHistoryTabContainer:GetSizeY();

	-- Update captured enemy operative info
	local haveCapturedEnemyOperative:boolean = false;
	local localPlayer:table = Players[localPlayerID];
	local playerDiplomacy:table = localPlayer:GetDiplomacy();
	local numCapturedSpies:number = playerDiplomacy:GetNumSpiesCaptured();
	for i=0,numCapturedSpies-1,1 do
		local spyInfo:table = playerDiplomacy:GetNthCapturedSpy(localPlayer:GetID(), i);
		if spyInfo then
			haveCapturedEnemyOperative = true;
			AddCapturedEnemyOperative(spyInfo);
		end
	end

	-- Hide captured enemy operative info if we have no captured enemy operatives
	if haveCapturedEnemyOperative then
		Controls.CapturedEnemyOperativeContainer:SetHide(false);
		desiredScrollPanelSizeY = desiredScrollPanelSizeY - Controls.CapturedEnemyOperativeContainer:GetSizeY();
	else
		Controls.CapturedEnemyOperativeContainer:SetHide(true);
	end

	-- Update mission history
	m_MissionHistoryIM:ResetInstances();

	if playerDiplomacy then
		-- Add information for last 10 missions
		local recentMissions:table = playerDiplomacy:GetRecentMissions(Game.GetLocalPlayer(), 10, 0);
		if recentMissions then
			-- Hide no missions label
			Controls.NoRecentMissonsLabel:SetHide(true);

			for i,mission in pairs(recentMissions) do
				AddMisisonHistoryInstance(mission);
			end
		else
			-- Show no missions label
			Controls.NoRecentMissonsLabel:SetHide(false);
		end
	end

	-- Adjust the mission history scroll panel to fill bottom of panel
	desiredScrollPanelSizeY = desiredScrollPanelSizeY - Controls.MissionHistoryScrollPanel:GetOffsetY();
	Controls.MissionHistoryScrollPanel:SetSizeY(desiredScrollPanelSizeY);

	Controls.MissionHistoryScrollPanel:CalculateSize();
end

-- ===========================================================================
function AddMisisonHistoryInstance(mission:table)
	-- Don't show missions where the spy must escape but the player has yet to choose an escape route
	if mission.InitialResult == EspionageResultTypes.SUCCESS_MUST_ESCAPE or mission.InitialResult == EspionageResultTypes.FAIL_MUST_ESCAPE then
		if mission.EscapeResult == EspionageResultTypes.NO_RESULT then
			return;
		end
	end

	local missionHistoryInstance:table = m_MissionHistoryIM:GetInstance();

	-- Update operative name and rank
	missionHistoryInstance.OperativeName:SetText(Locale.ToUpper(mission.Name));
	missionHistoryInstance.OperativeRank:SetText(Locale.Lookup(GetSpyRankNameByLevel(mission.LevelAfter)));

	-- Update name and turns since
	local operationInfo:table = GameInfo.UnitOperations[mission.Operation];
	missionHistoryInstance.MissionName:SetText(Locale.Lookup(operationInfo.Description));
	local turnsSinceMission:number = Game.GetCurrentGameTurn() - mission.CompletionTurn;
	missionHistoryInstance.TurnsSinceMission:SetText(Locale.Lookup("LOC_ESPIONAGEOVERVIEW_TURNS_AGO", turnsSinceMission));

	-- Update outcome and font icon
	local outcomeDetails:table = GetMissionOutcomeDetails(mission);
	if outcomeDetails then
		if outcomeDetails.Success then
			missionHistoryInstance.MissionOutcomeText:SetText(Locale.ToUpper("LOC_ESPIONAGEOVERVIEW_MISSIONOUTCOME") .. " " .. Locale.ToUpper("LOC_ESPIONAGEOVERVIEW_SUCCESS"));
		else
			missionHistoryInstance.MissionOutcomeText:SetText(Locale.ToUpper("LOC_ESPIONAGEOVERVIEW_MISSIONOUTCOME") .. " " .. Locale.ToUpper("LOC_ESPIONAGEOVERVIEW_FAILURE"));
		end

		SetMissionHistorySuccess(missionHistoryInstance, outcomeDetails.Success);
		missionHistoryInstance.OperationDetails:SetText(outcomeDetails.Description);

		if outcomeDetails.SpyStatus ~= "" then
			missionHistoryInstance.MissionOutcomeSpyStatus:SetText(outcomeDetails.SpyStatus);
			missionHistoryInstance.MissionOutcomeSpyStatus:SetHide(false);
		else
			missionHistoryInstance.MissionOutcomeSpyStatus:SetHide(true);
		end
	end

	-- Update mission and district icons
	local textureOffsetX, textureOffsetY, textureSheet = IconManager:FindIconAtlas(operationInfo.Icon,40);
	if textureSheet then
		missionHistoryInstance.OperationIcon:SetTexture(textureOffsetX, textureOffsetY, textureSheet);
		missionHistoryInstance.OperationIcon:SetHide(false);
	else
		UI.DataError("Unable to find icon for spy operation: " .. operationInfo.Icon);
		missionHistoryInstance.OperationIcon:SetHide(true);
	end

	if ( operationInfo.TargetDistrict ) then
		local iconString:string = "ICON_" .. operationInfo.TargetDistrict;
		textureOffsetX, textureOffsetY, textureSheet = IconManager:FindIconAtlas(iconString,32);
		if textureSheet then
			missionHistoryInstance.OperationDistrictIcon:SetTexture(textureOffsetX, textureOffsetY, textureSheet);
		else
			UI.DataError("Unable to find icon for district: " .. iconString);
		end
	end
	-- Scale the operation and district icons to match the operation description
	missionHistoryInstance.OperationIconGrid:SetSizeY(missionHistoryInstance.OperationDetailsContainer:GetSizeY());
	missionHistoryInstance.OperationDistrictIconGrid:SetSizeY(missionHistoryInstance.OperationDetailsContainer:GetSizeY());
end

-- ===========================================================================
function SetMissionHistorySuccess(missionHistoryInstance:table, wasSuccess:boolean)
	if wasSuccess then
		missionHistoryInstance.MissionGradient:SetColorByName("Green");
		missionHistoryInstance.MissionOutcomeText:SetColor(0xFF329600);
		missionHistoryInstance.MissionOutcomeSpyStatus:SetColor(0xFF329600);
		missionHistoryInstance.MissionOutcomeFontIcon:SetText("[ICON_CheckSuccess]");
	else
		missionHistoryInstance.MissionGradient:SetColorByName("Red");
		missionHistoryInstance.MissionOutcomeText:SetColor(0xFF0000C6);
		missionHistoryInstance.MissionOutcomeSpyStatus:SetColor(0xFF0000C6);
		missionHistoryInstance.MissionOutcomeFontIcon:SetText("[ICON_CheckFail]");
	end
end

-- ===========================================================================
function AddPlayerCities(player:table)
	local playerCities:table = player:GetCities();
	for j, city in playerCities:Members() do
		-- Check if the city is revealed
		local localPlayerVis:table = PlayersVisibility[Game.GetLocalPlayer()];
		if localPlayerVis:IsRevealed(city:GetX(), city:GetY()) then
			AddCity(city);
		end
	end
end

-- ===========================================================================
function AddCity(city:table)
	local cityInstance:table = m_CityIM:GetInstance();

	-- Update city banner
	-- GCO <<<<<
	--local backColor:number, frontColor:number  = UI.GetPlayerColors( city:GetOwner() );
	local backColor:number, frontColor:number  = GCO.GetPlayerColors( city:GetOwner() );
	-- GCO >>>>>
	local darkerBackColor:number = DarkenLightenColor(backColor,(-85),238);
	local brighterBackColor:number = DarkenLightenColor(backColor,90,255);

	cityInstance.BannerBase:SetColor( backColor );
	cityInstance.BannerDarker:SetColor( darkerBackColor );
	cityInstance.BannerLighter:SetColor( brighterBackColor );
	cityInstance.CityName:SetColor( frontColor );
	cityInstance.BannerBase:LocalizeAndSetToolTip("LOC_ESPIONAGEOVERVIEW_VIEW_CITY");
	cityInstance.BannerBase:RegisterCallback( Mouse.eLClick, function() LookAtCity(city:GetOwner(), city:GetID()); end );
    cityInstance.BannerBase:RegisterCallback(Mouse.eMouseEnter, function() UI.PlaySound("Main_Menu_Mouse_Over"); end);

	-- Update capital indicator but never show it for city-states
	if city:IsCapital() and Players[city:GetOwner()]:IsMajor() then
		cityInstance.CityName:SetText("[ICON_Capital]" .. " " .. Locale.ToUpper(city:GetName()));
	else
		cityInstance.CityName:SetText(Locale.ToUpper(city:GetName()));
	end

	-- Update district icons
	cityInstance.CityDistrictStack:DestroyAllChildren();
	AddDistrictIcon(cityInstance.CityDistrictStack, city, "DISTRICT_CITY_CENTER");
	--AddDistrictIcon(cityInstance.CityDistrictStack, city, "DISTRICT_COMMERCIAL_HUB");
	--AddDistrictIcon(cityInstance.CityDistrictStack, city, "DISTRICT_THEATER");
	--AddDistrictIcon(cityInstance.CityDistrictStack, city, "DISTRICT_CAMPUS");
	AddDistrictIcon(cityInstance.CityDistrictStack, city, "DISTRICT_INDUSTRIAL_ZONE");
	AddDistrictIcon(cityInstance.CityDistrictStack, city, "DISTRICT_NEIGHBORHOOD");
	AddDistrictIcon(cityInstance.CityDistrictStack, city, "DISTRICT_SPACEPORT");

	-- Update gain sources boost icon
	local player = Players[Game.GetLocalPlayer()];
	local playerDiplomacy:table = player:GetDiplomacy();
	if playerDiplomacy then
		local boostedTurnsRemaining:number = playerDiplomacy:GetSourceTurnsRemaining(city);
		if boostedTurnsRemaining > 0 then
			cityInstance.GainSourcesBoostIcon:SetHide(false);
		else
			cityInstance.GainSourcesBoostIcon:SetHide(true);
		end
	end

	if shouldShowCounterspyIcon then
		cityInstance.CounterspyIconBack:SetHide(false);
		cityInstance.CounterspyIconBack:SetColor( backColor );
		cityInstance.CounterspyIconFront:SetColor( frontColor );
	else
		cityInstance.CounterspyIconBack:SetHide(true);
	end
end

-- ===========================================================================
function AddDistrictIcon(stackControl:table, city:table, districtType:string)
	local districtInstance:table = {};
	ContextPtr:BuildInstanceForControl( "CityDistrictInstance", districtInstance, stackControl );

	local toolTipString:string = "";

	-- Check if we have this district
	local hasDistrict:boolean = false;
	local cityDistricts:table = city:GetDistricts();
	for i, district in cityDistricts:Members() do
		if district:IsComplete() then
			local districtInfo:table = GameInfo.Districts[district:GetType()];
			if districtInfo.DistrictType == districtType then
				hasDistrict = true;
				toolTipString = Locale.Lookup(districtInfo.Name);
			end
		end
	end

	-- We're manipulating the alpha to hide each element so they maintain their stack positions
	if hasDistrict then
		districtInstance.DistrictIcon:SetAlpha(1.0);
	else
		districtInstance.DistrictIcon:SetAlpha(0.0);
		return;
	end

	-- Update district icon
	districtInstance.DistrictIcon:SetIcon("ICON_" .. districtType);

	-- Check if one of our spies is active in this district
	local shouldShowActiveSpy:boolean = false;
	local playerUnits:table = Players[Game.GetLocalPlayer()]:GetUnits();
	for i,unit in playerUnits:Members() do
		local unitInfo:table = GameInfo.Units[unit:GetUnitType()];
		if not shouldShowActiveSpy and unitInfo.Spy then
			local operationType:number = unit:GetSpyOperation();
			local operationInfo:table = GameInfo.UnitOperations[operationType];
			if operationInfo then
				local spyPlot:table = Map.GetPlot(unit:GetX(), unit:GetY());
				local targetCity:table = Cities.GetPlotPurchaseCity(spyPlot);
				if targetCity:GetOwner() == city:GetOwner() and targetCity:GetID() == city:GetID() then
					local activeDistrictType:number = spyPlot:GetDistrictType();
					local districtInfo = GameInfo.Districts[activeDistrictType];
					if districtInfo.DistrictType == districtType then
						shouldShowActiveSpy = true;
						toolTipString = toolTipString .. "[NEWLINE]" .. Locale.Lookup(operationInfo.Description);
					end
				end
			end
		end
	end

	districtInstance.DistrictIcon:SetToolTipString( toolTipString );

	if shouldShowActiveSpy then
		-- GCO <<<<<
		--local backColor:number, frontColor:number  = UI.GetPlayerColors( Game.GetLocalPlayer() );
		local backColor:number, frontColor:number  = GCO.GetPlayerColors( Game.GetLocalPlayer() );
		-- GCO >>>>>
		districtInstance.SpyIconBack:SetColor( backColor );
		districtInstance.SpyIconFront:SetColor( frontColor );
		districtInstance.SpyIconBack:SetHide(false);
	else
		districtInstance.SpyIconBack:SetHide(true);
	end
end

-- ===========================================================================
function AddTopDistrictToolTips()
	Controls.CityCenterIcon:SetToolTipString(Locale.Lookup("LOC_DISTRICT_CITY_CENTER_NAME"));
	--Controls.CommericalIcon:SetToolTipString(Locale.Lookup("LOC_DISTRICT_COMMERCIAL_HUB_NAME"));
	--Controls.TheaterIcon:SetToolTipString(Locale.Lookup("LOC_DISTRICT_THEATER_NAME"));
	--Controls.ScienceIcon:SetToolTipString(Locale.Lookup("LOC_DISTRICT_CAMPUS_NAME"));
	Controls.IndustrialIcon:SetToolTipString(Locale.Lookup("LOC_DISTRICT_INDUSTRIAL_ZONE_NAME"));
	Controls.NeighborhoodIcon:SetToolTipString(Locale.Lookup("LOC_DISTRICT_NEIGHBORHOOD_NAME"));
	Controls.SpaceIcon:SetToolTipString(Locale.Lookup("LOC_DISTRICT_SPACEPORT_NAME"));
end

-- ===========================================================================
--	Called once during Init
-- ===========================================================================
function PopulateTabs()
	local localPlayerID:number = Game.GetLocalPlayer();
	if localPlayerID == -1 then
		return;
	end

	-- Grab player and diplomacy for local player
	local pPlayer:table = Players[localPlayerID];
	local pPlayerDiplomacy:table = nil;
	if pPlayer then
		pPlayerDiplomacy = pPlayer:GetDiplomacy();
	end

	if m_tabs == nil then
		m_tabs = CreateTabs( Controls.TabContainer, 42, 34, 0xFF331D05 );
	end

	-- Operatives Tab
	if not m_tabs.OperativesTabAdded then
		m_tabs.AddTab( Controls.OperativesTabButton,		OnSelectOperativesTab );
		Controls.OperativesTabButton:RegisterCallback(Mouse.eMouseEnter, function() UI.PlaySound("Main_Menu_Mouse_Over"); end);
		m_tabs.OperativesTabAdded = true;
	end

	-- City Activity Tab
	if not m_tabs.CityActivityTabAdded then
		m_tabs.AddTab( Controls.CityActivityTabButton,		OnSelectCityActivityTab );
		Controls.CityActivityTabButton:RegisterCallback(Mouse.eMouseEnter, function() UI.PlaySound("Main_Menu_Mouse_Over"); end);
		m_tabs.CityActivityTabAdded = true;
	end
		
	-- Mission History Tab
	-- Only show mission history if we have any mission history or captured enemy operatives
	local shouldShowMissionHistory:boolean = false;
	if pPlayerDiplomacy then
		local firstMission = pPlayerDiplomacy:GetMission(localPlayerID, 0);
		if firstMission ~= 0 then
			-- We have a mission so show history
			shouldShowMissionHistory = true;
		end

		local numCapturedSpies:number = pPlayerDiplomacy:GetNumSpiesCaptured();
		if numCapturedSpies > 0 then
			-- Show mission history if we have captured enemy spies
			shouldShowMissionHistory = true;
		end
	end

	if shouldShowMissionHistory then
		if not m_tabs.MissionHistoryTabAdded then
			Controls.MissionHistoryTabButton:SetHide(false);
			m_tabs.AddTab( Controls.MissionHistoryTabButton,	OnSelectMissionHistoryTab );
			Controls.MissionHistoryTabButton:RegisterCallback(Mouse.eMouseEnter, function() UI.PlaySound("Main_Menu_Mouse_Over"); end);
			m_tabs.MissionHistoryTabAdded = true;
		end
	else
		Controls.MissionHistoryTabButton:SetHide(true);
	end

	m_tabs.EvenlySpreadTabs();
	m_tabs.CenterAlignTabs(-25);	-- Use negative to create padding as value represents amount to overlap
end

-- ===========================================================================
function SelectTabByIndex( tabIndex:number )
	if tabIndex == EspionageTabs.CITY_ACTIVITY then
		m_tabs.SelectTab( Controls.CityActivityTabButton );
	elseif tabIndex == EspionageTabs.MISSION_HISTORY then
		m_tabs.SelectTab( Controls.MissionHistoryTabButton );
	else
		m_tabs.SelectTab( Controls.OperativesTabButton );
	end
end

-- ===========================================================================
function OnSelectOperativesTab()
	m_selectedTab = EspionageTabs.OPERATIVES;
	Refresh();
end

-- ===========================================================================
function OnSelectCityActivityTab()
	m_selectedTab = EspionageTabs.CITY_ACTIVITY;
	Refresh();
end

-- ===========================================================================
function OnSelectMissionHistoryTab()
	m_selectedTab = EspionageTabs.MISSION_HISTORY;
	Refresh();
end

-- ===========================================================================
function AddOperative(spy:table)
	local operativeInstance:table = m_OperativeIM:GetInstance();

	local spyInfo:table = GameInfo.Units[spy:GetUnitType()];

	-- Operative Name
	operativeInstance.OperativeName:SetText(Locale.ToUpper(spy:GetName()));

	-- Operative Rank
	local spyExperience:table = spy:GetExperience();
	operativeInstance.OperativeRank:SetText(Locale.Lookup(GetSpyRankNameByLevel(spyExperience:GetLevel())));

	-- City Banner
	local spyPlot = Map.GetPlot(spy:GetX(), spy:GetY());
	local ownerCity = Cities.GetPlotPurchaseCity(spyPlot);
	if ownerCity then
		-- GCO <<<<<
		--local backColor:number, frontColor:number  = UI.GetPlayerColors( ownerCity:GetOwner() );
		local backColor:number, frontColor:number  = GCO.GetPlayerColors( ownerCity:GetOwner() );
		-- GCO >>>>>
		operativeInstance.CityBanner:SetColor( backColor );
		operativeInstance.LocationPip:SetColor( frontColor );
		operativeInstance.CityName:SetColor( frontColor );
		operativeInstance.CityName:SetText(Locale.ToUpper(ownerCity:GetName()));
		operativeInstance.CityBanner:LocalizeAndSetToolTip("LOC_ESPIONAGEOVERVIEW_VIEW_CITY");
		operativeInstance.CityBanner:RegisterCallback( Mouse.eLClick, function() LookAtCity(ownerCity:GetOwner(), ownerCity:GetID()); end );
        operativeInstance.CityBanner:RegisterCallback(Mouse.eMouseEnter, function() UI.PlaySound("Main_Menu_Mouse_Over"); end);
		operativeInstance.CityBanner:SetHide(false);
	else
		operativeInstance.CityBanner:SetHide(true);
	end
	
	local operationType:number = spy:GetSpyOperation();
	if operationType == -1 then
		-- Awaiting Assignment
		operativeInstance.Top:SetTextureOffsetVal(0, 73);

		operativeInstance.AwaitingAssignmentStack:SetHide(false);
		operativeInstance.ActiveMissionContainer:SetHide(true);
		operativeInstance.TravellingContainer:SetHide(true);
		operativeInstance.CapturedContainer:SetHide(true);
	else
		-- On Active Assignment
		operativeInstance.Top:SetTextureOffsetVal(0, 0);

		-- Operation Name
		local operationInfo:table = GameInfo.UnitOperations[operationType];
		TruncateStringWithTooltip(operativeInstance.OperationName, MAX_BEFORE_TRUNC_MISSION_NAME, Locale.Lookup(operationInfo.Description)); 

		-- Turns Remaining
		local turnsRemaining:number = spy:GetSpyOperationEndTurn() - Game.GetCurrentGameTurn();
		if turnsRemaining <= 0 then
			turnsRemaining = 0;
		end
		operativeInstance.OperationTurnsRemaining:SetText(Locale.Lookup("LOC_ESPIONAGEOVERVIEW_MORE_TURNS", turnsRemaining));

		-- Percent Complete
		local totalTurns:number = UnitManager.GetTimeToComplete(operationType, spy);
		local percentOperationComplete:number = (totalTurns - turnsRemaining) / totalTurns;
		operativeInstance.OperationPercentComplete:SetPercent(percentOperationComplete);

		-- Operation Icon
		local textureOffsetX, textureOffsetY, textureSheet = IconManager:FindIconAtlas(operationInfo.Icon,40);
		if textureSheet then
			operativeInstance.OperationIcon:SetTexture(textureOffsetX, textureOffsetY, textureSheet);
			operativeInstance.OperationIcon:SetHide(false);
		else
			UI.DataError("Unable to find icon for spy operation: " .. operationInfo.Icon);
			operativeInstance.OperationIcon:SetHide(true);
		end

		-- Operation District Icon
		local spyPlot:table = Map.GetPlot(spy:GetX(), spy:GetY());
		local districtType = spyPlot:GetDistrictType();
		local districtInfo = GameInfo.Districts[districtType];
		if districtInfo then
			local iconString:string = "ICON_" .. districtInfo.DistrictType;
			textureOffsetX, textureOffsetY, textureSheet = IconManager:FindIconAtlas(iconString,32);
			operativeInstance.OperationDistrictIcon:SetTexture(textureOffsetX, textureOffsetY, textureSheet);
		end

		-- Operation Details
		if ownerCity then
			if operationInfo.Hash == UnitOperationTypes.SPY_COUNTERSPY then
				operativeInstance.OperationDetails:SetText(Locale.Lookup("LOC_ESPIONAGECHOOSER_COUNTERSPY", Locale.Lookup(districtInfo.Name)));
			else
				operativeInstance.OperationDetails:SetText(GetFormattedOperationDetailText(operationInfo, spy, ownerCity));
			end
		end

		operativeInstance.AwaitingAssignmentStack:SetHide(true);
		operativeInstance.ActiveMissionContainer:SetHide(false);
		operativeInstance.TravellingContainer:SetHide(true);
		operativeInstance.CapturedContainer:SetHide(true);
	end
end

-- ===========================================================================
function LookAtCity(playerID:number, cityID:number)
	local player = Players[playerID];
	if player then
		city = player:GetCities():FindID(cityID);
		UI.LookAtPlotScreenPosition( city:GetX(), city:GetY(), 0.33, 0.5 );
	end
end

------------------------------------------------------------------------------------------------
function AddOffMapOperative(spy:table)
	local operativeInstance:table = m_OperativeIM:GetInstance();

	-- Adjust texture offset
	operativeInstance.Top:SetTextureOffsetVal(0, 146);

	-- Operative Name
	operativeInstance.OperativeName:SetText(Locale.ToUpper(spy.Name));

	-- Operative Rank
	operativeInstance.OperativeRank:SetText(Locale.Lookup(GetSpyRankNameByLevel(spy.Level)));

	-- Travel Time
	local travelTurnsRemaining:number = spy.ReturnTurn - Game.GetCurrentGameTurn();
	operativeInstance.TravelTurnsRemaining:SetText(Locale.Lookup("LOC_ESPIONAGEOVERVIEW_MORE_TURNS", travelTurnsRemaining));

	-- Travel Percentage Complete
	operativeInstance.TravelPercentComplete:SetPercent(0);

	-- Get city name
	local spyPlot:table = Map.GetPlot(spy.XLocation, spy.YLocation);
	local targetCity:table = Cities.GetPlotPurchaseCity(spyPlot);
	if targetCity then
		TruncateStringWithTooltip(operativeInstance.TravelDestinationName, TRAVEL_DEST_TRUNCATE_WIDTH, Locale.Lookup("LOC_ESPIONAGEOVERVIEW_TRANSIT_TO", targetCity:GetName()));
	end

	operativeInstance.CityBanner:SetHide(true);
	operativeInstance.AwaitingAssignmentStack:SetHide(true);
	operativeInstance.ActiveMissionContainer:SetHide(true);
	operativeInstance.TravellingContainer:SetHide(false);
	operativeInstance.CapturedContainer:SetHide(true);
end

------------------------------------------------------------------------------------------------
function AddCapturedOperative(spy:table, playerCapturedBy:number)
	local operativeInstance:table = m_OperativeIM:GetInstance();

	-- Adjust texture offset
	operativeInstance.Top:SetTextureOffsetVal(0, 146);

	-- Operative Name
	operativeInstance.OperativeName:SetText(Locale.ToUpper(spy.Name));

	-- Operative Rank
	operativeInstance.OperativeRank:SetText(Locale.Lookup(GetSpyRankNameByLevel(spy.Level)));

	-- Update information about the player who captured the spy
	local capturingPlayerConfig:table = PlayerConfigurations[playerCapturedBy];
	if capturingPlayerConfig then
		-- GCO <<<<<
		--local backColor:number, frontColor:number  = UI.GetPlayerColors( playerCapturedBy );
		local backColor:number, frontColor:number  = GCO.GetPlayerColors( playerCapturedBy );
		-- GCO >>>>>
		local textureOffsetX, textureOffsetY, textureSheet = IconManager:FindIconAtlas("ICON_" .. capturingPlayerConfig:GetCivilizationTypeName(),22);
		operativeInstance.CapturingCivIconBack:SetColor(backColor);
		operativeInstance.CapturingCivIconFront:SetColor(frontColor);
		operativeInstance.CapturingCivIconFront:SetTexture(textureOffsetX, textureOffsetY, textureSheet);
		operativeInstance.CapturingCivName:SetText(Locale.Lookup(capturingPlayerConfig:GetPlayerName()));
		TruncateStringWithTooltip(operativeInstance.AskForTradeButton, MAX_BEFORE_TRUNC_ASK_FOR_TRADE, Locale.Lookup("LOC_ESPIONAGEOVERVIEW_ASK_FOR_TRADE"));
		
		-- Show the ask trade button, if there is no pending deal.
		local localPlayerID:number = Game.GetLocalPlayer();
		local atWarWith:boolean = Players[localPlayerID]:GetDiplomacy():IsAtWarWith(playerCapturedBy);
		if atWarWith then
			operativeInstance.AskForTradeButton:SetDisabled(true);
			operativeInstance.AskForTradeButton:SetToolTipString(Locale.Lookup("LOC_DIPLOPANEL_AT_WAR"));
		elseif DealManager.HasPendingDeal(localPlayerID, playerCapturedBy) then
			operativeInstance.AskForTradeButton:SetDisabled(true);
			operativeInstance.AskForTradeButton:SetToolTipString(Locale.Lookup("LOC_DIPLOMACY_ANOTHER_DEAL_WITH_PLAYER_PENDING"));
		else
			operativeInstance.AskForTradeButton:SetDisabled(false);
			operativeInstance.AskForTradeButton:RegisterCallback( Mouse.eLClick, function() OnAskForOperativeTradeClicked(playerCapturedBy, spy.NameIndex); end );
			operativeInstance.AskForTradeButton:SetToolTipString("");
		end
	else
		UI.DataError("Could not find player configuration for player ID: " .. tostring(playerCapturedBy));
	end

	operativeInstance.CityBanner:SetHide(true);
	operativeInstance.AwaitingAssignmentStack:SetHide(true);
	operativeInstance.ActiveMissionContainer:SetHide(true);
	operativeInstance.TravellingContainer:SetHide(true);
	operativeInstance.CapturedContainer:SetHide(false);
end

------------------------------------------------------------------------------------------------
function OnAskForOperativeTradeClicked(capturingPlayerID:number, capturedSpyID:number)
	-- Can't do this if we already have a pending deal
	if (not DealManager.HasPendingDeal(Game.GetLocalPlayer(), capturingPlayerID)) then
		-- Clear deal
		DealManager.ClearWorkingDeal(DealDirection.OUTGOING, Game.GetLocalPlayer(), capturingPlayerID);

		local bDealValid = false;

		-- Add the spy to the deal
		local pDeal = DealManager.GetWorkingDeal(DealDirection.OUTGOING, Game.GetLocalPlayer(), capturingPlayerID);
		if (pDeal ~= nil) then
			local pDealItem = pDeal:AddItemOfType(DealItemTypes.CAPTIVE, capturingPlayerID);
			if (pDealItem ~= nil) then
				-- The value of the deal item holds the spy's index
				pDealItem:SetValueType( capturedSpyID );
				if (pDealItem:IsValid()) then
					pDealItem:SetLocked(true);
					bDealValid = true;
				end
			end
		end

		-- Request the diplomacy session.  This will open the deal screen, with the deal in its current state.
		if (bDealValid) then
			DiplomacyManager.RequestSession(Game.GetLocalPlayer(), capturingPlayerID, "MAKE_DEAL");
		else
			DealManager.ClearWorkingDeal(DealDirection.OUTGOING, Game.GetLocalPlayer(), capturingPlayerID);
		end
	end
end

------------------------------------------------------------------------------------------------
function AddCapturedEnemyOperative(spyInfo:table)
	local enemyOperativeInstance:table = m_EnemyOperativeIM:GetInstance();

	-- Update spy name
	local spyName:string = Locale.ToUpper(spyInfo.Name);
	enemyOperativeInstance.SpyName:SetText(spyName);

	-- Update owning civ spy icon
	-- GCO <<<<<
	--local backColor:number, frontColor:number  = UI.GetPlayerColors( spyInfo.OwningPlayer );
	local backColor:number, frontColor:number  = GCO.GetPlayerColors( spyInfo.OwningPlayer );
	-- GCO >>>>>
	enemyOperativeInstance.SpyIconBack:SetColor(backColor);
	enemyOperativeInstance.SpyIconFront:SetColor(frontColor);

	-- Update owning civ name
	local owningPlayerConfig:table = PlayerConfigurations[spyInfo.OwningPlayer];
	enemyOperativeInstance.CivName:SetText(Locale.Lookup(owningPlayerConfig:GetCivilizationDescription()));

	local pLocalPlayerDiplo:table = Players[Game.GetLocalPlayer()]:GetDiplomacy();
	if pLocalPlayerDiplo and not pLocalPlayerDiplo:IsAtWarWith(spyInfo.OwningPlayer) then
		-- If we're not at war with the spies owner allow trading for that spy
		enemyOperativeInstance.OfferTradeText:SetHide(false);
		enemyOperativeInstance.GridButton:SetDisabled(false);
		enemyOperativeInstance.GridButton:RegisterCallback( Mouse.eLClick, function() OnAskForEnemyOperativeTradeClicked(spyInfo.OwningPlayer, spyInfo.NameIndex); end );
		enemyOperativeInstance.GridButton:SetToolTipString("");
	else
		enemyOperativeInstance.OfferTradeText:SetHide(true);
		enemyOperativeInstance.GridButton:SetDisabled(true);
		enemyOperativeInstance.GridButton:ClearCallback( Mouse.eLClick );
		enemyOperativeInstance.GridButton:SetToolTipString(Locale.Lookup("LOC_ESPIONAGE_SPY_TRADE_DISABLED_AT_WAR", spyName, Locale.Lookup(owningPlayerConfig:GetCivilizationShortDescription())));
	end
end

------------------------------------------------------------------------------------------------
function OnAskForEnemyOperativeTradeClicked(owningPlayerID:number, capturedSpyID:number)
	-- Clear deal
	DealManager.ClearWorkingDeal(DealDirection.OUTGOING, Game.GetLocalPlayer(), owningPlayerID);

	-- Add the spy to the deal
	local pDeal = DealManager.GetWorkingDeal(DealDirection.OUTGOING, Game.GetLocalPlayer(), owningPlayerID);
	if (pDeal ~= nil) then
		local pDealItem = pDeal:AddItemOfType(DealItemTypes.CAPTIVE, Game.GetLocalPlayer());
		if (pDealItem ~= nil) then
			---- The value of the deal item holds the spy's index
			pDealItem:SetLocked(true);
			pDealItem:SetValueType( capturedSpyID );
		end
	end

	-- Request the diplomacy session.  This will open the deal screen, with the deal in its current state.
	DiplomacyManager.RequestSession(Game.GetLocalPlayer(), owningPlayerID, "MAKE_DEAL");
end

------------------------------------------------------------------------------------------------
function Close()
	m_AnimSupport:Hide();
    if not ContextPtr:IsHidden() then
        UI.PlaySound("CityStates_Panel_Close");
    end
end

------------------------------------------------------------------------------------------------
function Open(forceTabIndex:number)
	-- dont show panel if there is no local player
	local localPlayerID = Game.GetLocalPlayer();
	if (localPlayerID == -1) then
		return
	end

	m_AnimSupport:Show();

	if forceTabIndex then
		SelectTabByIndex( forceTabIndex );
	else
		-- Default to Operatives tab
		m_tabs.SelectTab( Controls.OperativesTabButton );
	end
end

------------------------------------------------------------------------------------------------
function OnLocalPlayerTurnEnd()
	if(GameConfiguration.IsHotseat()) then
		Close();
	end
end

-- ===========================================================================
--	Game Event
-- ===========================================================================
function OnInterfaceModeChanged(eOldMode:number, eNewMode:number)
	if eNewMode == InterfaceModeTypes.VIEW_MODAL_LENS then
		Close();
	end
end

------------------------------------------------------------------------------------------------
function OnSpyRemoved(spyOwner, counterSpyPlayer)
	if (not ContextPtr:IsHidden()) then
		if (spyOwner == Game.GetLocalPlayer()) then
			if (m_selectedTab == EspionageTabs.OPERATIVES) then
				RefreshOperatives();
			end
		end
	end
end

------------------------------------------------------------------------------------------------
function OnSpyAdded(spyOwner, spyUnitID)
	if (not ContextPtr:IsHidden()) then
		if (spyOwner == Game.GetLocalPlayer()) then
			if (m_selectedTab == EspionageTabs.OPERATIVES) then
				RefreshOperatives();
			end
		end
	end
end

function OnDiplomacyDealEnacted()
	if (not ContextPtr:IsHidden()) then
		if (m_selectedTab == EspionageTabs.MISSION_HISTORY) then
			RefreshMissionHistory();
		end
	end
end

------------------------------------------------------------------------------------------------
function OnClose()
	Close();
end

------------------------------------------------------------------------------------------------
function OnOpen()
	UI.PlaySound("CityStates_Panel_Open");
	Open();
end

------------------------------------------------------------------------------------------------
function OnCloseAllExcept(contextToStayOpen:string)
	if contextToStayOpen ~= ContextPtr:GetID() then 
		Close();
	end
end

-- ===========================================================================
function OnUnitOperationStarted(ownerID:number, unitID:number, operationID:number)
	if m_AnimSupport.IsVisible() then
		Refresh();
	end
end

-- ===========================================================================
--	UI EVENT
-- ===========================================================================
function OnInit(isReload:boolean)
	if isReload then
		LuaEvents.GameDebug_GetValues(RELOAD_CACHE_ID);
	end
end

-- ===========================================================================
--	UI EVENT
-- ===========================================================================
function OnShutdown()
	LuaEvents.GameDebug_AddValue(RELOAD_CACHE_ID, "isVisible", m_AnimSupport:IsVisible());
	LuaEvents.GameDebug_AddValue(RELOAD_CACHE_ID, "selectedTab", m_selectedTab);
end

-- ===========================================================================
--	LUA EVENT
--	Reload support
-- ===========================================================================
function OnGameDebugReturn(context:string, contextTable:table)
	if context == RELOAD_CACHE_ID then
		if contextTable["isVisible"] ~= nil and contextTable["isVisible"] then			
			Open();
		end
		if contextTable["selectedTab"] ~= nil then			
			SelectTabByIndex( contextTable["selectedTab"] );
		end
	end
end

-- ===========================================================================
function Initialize()
	Controls.Title:SetText(Locale.Lookup("LOC_ESPIONAGE_TITLE"));
	-- Control Events
	Controls.CloseButton:RegisterCallback(Mouse.eLClick, OnClose);
	Controls.CloseButton:RegisterCallback( Mouse.eMouseEnter, function() UI.PlaySound("Main_Menu_Mouse_Over"); end);

	-- Lua Events
	LuaEvents.PartialScreenHooks_OpenEspionage.Add( OnOpen );
	LuaEvents.PartialScreenHooks_CloseEspionage.Add( OnClose );
	LuaEvents.PartialScreenHooks_CloseAllExcept.Add( OnCloseAllExcept );

	-- Animation Controller
	m_AnimSupport = CreateScreenAnimation(Controls.SlideAnim);

	-- Rundown / Screen Events
	Events.SystemUpdateUI.Add(m_AnimSupport.OnUpdateUI);
	ContextPtr:SetInputHandler(m_AnimSupport.OnInputHandler, true);

	-- Game Engine Events	
	Events.UnitOperationStarted.Add( OnUnitOperationStarted );
	Events.LocalPlayerTurnEnd.Add( OnLocalPlayerTurnEnd );

	Events.InterfaceModeChanged.Add( OnInterfaceModeChanged );
	
	Events.SpyAdded.Add( OnSpyAdded );
	Events.SpyRemoved.Add( OnSpyRemoved );
	Events.DiplomacyDealEnacted.Add( OnDiplomacyDealEnacted ); -- Folks may be trading captured spies, if they do we must update the panel

	-- Hot-Reload Events
	ContextPtr:SetInitHandler(OnInit);
	ContextPtr:SetShutdown(OnShutdown);
	LuaEvents.GameDebug_Return.Add(OnGameDebugReturn);

	PopulateTabs();
	AddTopDistrictToolTips();
end
Initialize();


