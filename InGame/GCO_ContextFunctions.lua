-----------------------------------------------------------------------------------------
--	FILE:	 ContextFunctions.lua
--  Gedemon (2017)
-----------------------------------------------------------------------------------------

print ("Loading ContextFunctions.lua...")

-- ===========================================================================
-- Initialize UI context function to use them in scripts
-- Notes from Salec (Firaxis) https://forums.civfanatics.com/threads/information-from-firaxis-developer-on-the-mod-tools.611291/
--[[
		The gameplay DLL is running on a separate thread and has it's own set of lua exposures.
		The UI scripts act on cached data that may not be 100% in sync with the state of the gameplay dll (for example if it's playing back combat)
		Because of this the UI-side lua scripts have some different exposures than the gameplay side.
--]]
-- ===========================================================================

include( "Civ6Common" )
include( "InstanceManager" )

-- ===========================================================================
-- Defines
-- ===========================================================================

local ProductionTypes = {
		UNIT		= 0,
		BUILDING	= 1,
		DISTRICT 	= 2
	}


-- ===========================================================================
-- Initialize
-- ===========================================================================
-- Initialize first with what is already loaded from script contexts, we may need them before the next call to GameCoreEventPublishComplete after this file is loaded
local GCO 			= ExposedMembers.GCO 
local GameEvents	= ExposedMembers.GameEvents
--local LuaEvents		= ExposedMembers.LuaEvents
function InitializeUtilityFunctions()
	GCO 	= ExposedMembers.GCO 	-- Reinitialize with what may have been added with other UI contexts
	Dline	= GCO.Dline				-- output current code line number to firetuner/log
	print ("Exposed Functions from other contexts initialized...")
	PostInitialize()
end
GameEvents.InitializeGCO.Add( InitializeUtilityFunctions )

function PostInitialize()
	-- Migration Routes
	local lensPanelYOffSet	= 50
	local lensPanelXOffSet	= 55
	local lensStackCtrl 	= ContextPtr:LookUpControl("/InGame/MinimapPanel/LensToggleStack/")
	local lensPanelCtrl		= ContextPtr:LookUpControl("/InGame/MinimapPanel/LensPanel/")
	
	Controls.HistoricalMigrationRoutesButton:RegisterCallback( Mouse.eLClick, ToggleHistoricalMigrationRoutes )
	Controls.HistoricalMigrationRoutesButton:SetHide( false )
	Controls.HistoricalMigrationRoutesButton:ChangeParent(lensStackCtrl)
	
	Controls.CurrentMigrationRoutesButton:RegisterCallback( Mouse.eLClick, ToggleCurrentMigrationRoutes )
	Controls.CurrentMigrationRoutesButton:SetHide( false )
	Controls.CurrentMigrationRoutesButton:ChangeParent(lensStackCtrl)
	
	lensStackCtrl:CalculateSize();
	lensPanelCtrl:SetSizeY(lensStackCtrl:GetSizeY() + lensPanelYOffSet)
	lensPanelCtrl:SetSizeX(lensStackCtrl:GetSizeX() + lensPanelXOffSet)
	--
end



-- ===========================================================================
-- Generic Get Context Method
-- ===========================================================================
function CallPlayerContextFunction(playerID, sMethod, kArguments)

	local pPlayer 	= Players[playerID]
	
	return kArguments and pPlayer[sMethod](pPlayer,unpack(kArguments)) or pPlayer[sMethod](pPlayer)
	
end

function CallUnitContextFunction(pUnit, sMethod, kArguments)

	local contextUnit = UnitManager.GetUnit(pUnit:GetOwner(), pUnit:GetID())
	
	return kArguments and contextUnit[sMethod](contextUnit,unpack(kArguments)) or contextUnit[sMethod](contextUnit)
	
end

-- ===========================================================================
-- Calendar functions
-- ===========================================================================
function GetTurnYear(turn)
	return Calendar.GetTurnYearForGame(turn)
end

-- ===========================================================================
-- Cities functions
-- ===========================================================================
function GetCityCultureYield(plot)
	local contextCity = Cities.GetCityInPlot(plot:GetX(), plot:GetY())  -- We can't use an object comming from a script context to call a function exposed only to the UI context...
	if not contextCity then return 0 end
	local cityCulture = contextCity:GetCulture()
	if cityCulture then
		return cityCulture:GetCultureYield()
	else
		return 0
	end
end

function GetCityPlots(city)
	if not city then GCO.Warning("city is nil for GetCityPlots"); GCO.DlineFull(); return {} end
	local contextCity = CityManager.GetCity(city:GetOwner(), city:GetID())
	return Map.GetCityPlots():GetPurchasedPlots(contextCity)
end

function GetBuildingsAtLocation(city, plotID)
	local contextCity 	= CityManager.GetCity(city:GetOwner(), city:GetID())
	local pBuildings	= contextCity:GetBuildings()
	return pBuildings:GetBuildingsAtLocation(plotID)
end

function GetCityYield(city, yieldType)
	local contextCity = CityManager.GetCity(city:GetOwner(), city:GetID())
	if not contextCity then return 0 end
	return contextCity:GetYield(yieldType)
end

function GetCityTrade(city)
	local contextCity = CityManager.GetCity(city:GetOwner(), city:GetID())
	return contextCity:GetTrade()
end

function CityCanProduce(city, productionType)
	local contextCity = CityManager.GetCity(city:GetOwner(), city:GetID())
	if not contextCity then return false end
	local pCityBuildQueue = contextCity:GetBuildQueue()
	return pCityBuildQueue:CanProduce( productionType, true )
end

function GetCityProductionTurnsLeft(city, productionType)
	local contextCity = CityManager.GetCity(city:GetOwner(), city:GetID())
	if not contextCity then return 1 end -- do not return 0, this can be used as a divisor
	local pCityBuildQueue = contextCity:GetBuildQueue()
	return pCityBuildQueue:GetTurnsLeft( productionType )
end

function GetCityProductionYield(city)
	local contextCity = CityManager.GetCity(city:GetOwner(), city:GetID())
	if not contextCity then return 0 end
	local pCityBuildQueue = contextCity:GetBuildQueue()
	return pCityBuildQueue:GetProductionYield()
end

function GetCityProductionProgress(city, productionType, objetID)
	local contextCity = CityManager.GetCity(city:GetOwner(), city:GetID())
	if not contextCity then return 0 end
	local pCityBuildQueue = contextCity:GetBuildQueue()
	if productionType == ProductionTypes.UNIT then
		return pCityBuildQueue:GetUnitProgress(objetID)
	elseif productionType == ProductionTypes.BUILDING then
		return pCityBuildQueue:GetBuildingProgress(objetID)
	elseif productionType == ProductionTypes.DISTRICT then
		return pCityBuildQueue:GetDistrictProgress(objetID)
	else
		return pCityBuildQueue:GetUnitProgress(objetID)
	end
end

function IsCityCapital(city)
	local contextCity = CityManager.GetCity(city:GetOwner(), city:GetID())
	return contextCity:IsCapital()
end


-- ===========================================================================
-- Game functions
-- ===========================================================================
function GetTradeManager()
	return Game.GetTradeManager()
end


-- ===========================================================================
-- Players functions
-- ===========================================================================
function HasPlayerOpenBordersFrom(player, otherPlayerID)
	local contextPlayer = Players[player:GetID()] -- We can't use an object comming from a script context to call a function exposed only to the UI context...
	return contextPlayer:GetDiplomacy():HasOpenBordersFrom( otherPlayerID )
end

function CanPlayerDeclareWarOn(player, otherPlayerID)
	local contextPlayer = Players[player:GetID()] -- We can't use an object comming from a script context to call a function exposed only to the UI context...
	return contextPlayer:GetDiplomacy():CanDeclareWarOn( otherPlayerID )
end

function IsResourceVisibleFor(player, resourceID)
	local contextPlayer = Players[player:GetID()] -- We can't use an object comming from a script context to call a function exposed only to the UI context...
	return contextPlayer:GetResources():IsResourceVisible( resourceID )
end

function GetPlayerInfluenceMap(player)
	local contextPlayer = Players[player:GetID()] -- We can't use an object comming from a script context to call a function exposed only to the UI context...
	return contextPlayer:GetInfluenceMap()
end

function HasPolicyActive(player, policyID)
	local contextPlayer 	= Players[player:GetID()] -- We can't use an object comming from a script context to call a function exposed only to the UI context...
	local kPlayerCulture	= contextPlayer:GetCulture()
	local numSlots:number 	= kPlayerCulture:GetNumPolicySlots();
	for i = 0, numSlots-1, 1 do
		if policyID == kPlayerCulture:GetSlotPolicy(i) then
			return true
		end			
	end
	return false
end

function GetActivePolicies(player)
	local contextPlayer 	= Players[player:GetID()] -- We can't use an object comming from a script context to call a function exposed only to the UI context...
	local kPlayerCulture	= contextPlayer:GetCulture()
	local numSlots:number 	= kPlayerCulture:GetNumPolicySlots()
	local policiesList 		= {} 
	for i = 0, numSlots-1, 1 do
		local policyID = kPlayerCulture:GetSlotPolicy(i)
		if GameInfo.Policies[policyID] then
			table.insert(policiesList, policyID)
		end
	end
	return policiesList
end

function GetCurrentGovernment(player)
	local contextPlayer 	= Players[player:GetID()] -- We can't use an object comming from a script context to call a function exposed only to the UI context...
	local kPlayerCulture	= contextPlayer:GetCulture()
	return kPlayerCulture:GetCurrentGovernment()
end

function GetMission(playerID, missionID)
	local pPlayer:table				= Players[playerID]
	local pPlayerDiplomacy:table 	= pPlayer:GetDiplomacy()
	if pPlayerDiplomacy then
		return pPlayerDiplomacy:GetMission(playerID, missionID)
	end
end
-- ===========================================================================
-- Plots functions
-- ===========================================================================
function IsImprovementPillaged(plot)
	local contextPlot = Map.GetPlot(plot:GetX(), plot:GetY())
	return contextPlot:IsImprovementPillaged()
end

function GetPlotAppeal(plot)
	local contextPlot = Map.GetPlot(plot:GetX(), plot:GetY())
	return contextPlot:GetAppeal()
end

function GetPlotActualYield(plot, yieldID)
	local contextPlot = Map.GetPlot(plot:GetX(), plot:GetY())
	return contextPlot:GetYield(yieldID)
end


-- ===========================================================================
-- Units functions
-- ===========================================================================
function GetMoveToPath( unit, plotIndex )
	local contextUnit = UnitManager.GetUnit(unit:GetOwner(), unit:GetID())
	return UnitManager.GetMoveToPath( contextUnit, plotIndex )
end

function SetUnitName( unit, name )
	local contextUnit = UnitManager.GetUnit(unit:GetOwner(), unit:GetID())
	if (contextUnit) then
		local tParameters = {};
		tParameters[UnitCommandTypes.PARAM_NAME] = name
		if (name ~= "") then
			UnitManager.RequestCommand( contextUnit, UnitCommandTypes.NAME_UNIT, tParameters );
		end
	end
end

function RequestOperation( pUnit, UnitOperationType, tParameters)
	local contextUnit = UnitManager.GetUnit(pUnit:GetOwner(), pUnit:GetID())
	UnitManager.RequestOperation( contextUnit, UnitOperationType, tParameters)
end

-- =========================================================================== 
--	Send Status message
-- =========================================================================== 
function StatusMessage( str:string, fDisplayTime:number, messageType:number, subType:number )
	local messageType = messageType or ReportingStatusTypes.DEFAULT
	LuaEvents.StatusMessage(str, fDisplayTime, messageType, subType)
end

-- ===========================================================================
-- Custom Tooltip
-- ===========================================================================
local MIN_Y_POSITION		:number = 50;	-- roughly where top panel starts
local OFFSET_SHOW_AT_MOUSE_X:number = 40; 
local OFFSET_SHOW_AT_MOUSE_Y:number = 20; 
local OFFSET_SHOW_AT_TOUCH_X:number = -30; 
local OFFSET_SHOW_AT_TOUCH_Y:number = -35;
local SIZE_WIDTH_MARGIN		:number = 20;
local SIZE_HEIGHT_PADDING	:number = 20;
local TIME_DEFAULT_PAUSE	:number = 1.1;

local m_isActive		:boolean	= true;		-- Is this active
local m_isShowDebug		:boolean	= false;	-- Read from CONFIG, show debug information in the tooltip?
local m_isOff			:boolean	= false;	-- If the plot tooltip is turned off by a game action/
local m_isShiftDown		:boolean	= false;	-- Is the shift key currently down?
local m_isUsingMouse	:boolean	= true;		-- Both mouse & touch valid at once, but what is the player using?
local m_isValidPlot		:boolean	= false;	-- Is a valid plot active?
local m_plotId			:number		= -1;		-- The currently moused over plot.
local m_screenWidth		:number		= 1024;		-- Min spec by default
local m_screenHeight	:number		= 768;		-- Min spec by default
local m_offsetX			:number		= 0;		-- Current additional offset for tooltip area
local m_offsetY			:number		= 0;
local m_ttWidth			:number		= 0;		-- Width of the tooltip
local m_ttHeight		:number		= 0;		-- Height " " "
local m_touchIdForPoint	:number		= -1;		-- ID of the touch which will act like the mouse
local m_lastMouseMoveTime			= nil;		-- Last time the mouse moved.

local m_kColumnsIM		:table		= InstanceManager:new( "ColumnInstance",	"Top");
local m_kRowsIM			:table		= InstanceManager:new( "RowInstance",		"Top", Controls.InfoTable );

--	Turn on the tooltips
function TooltipOn(parameters)
	m_isOff = false;
	LuaEvents.Tutorial_PlotToolTipsOff()

	-- If the whole system is not active, leave before actually displaying tooltip.
	if not m_isActive then		
	--	return;
	end
	
	--parameters.Header4 = "[ICON_INDENT]           [ICON_TradingPost]       [ICON_TradeRoute]       [ICON_Unit]     [ICON_UP_DOWN]  [ICON_Gold]"
	
	local labelBase = {"Title", "Text", "Header", "List"}
	local nbEntries	= 4
	local labelList = {}
	for i = 1, nbEntries do
		for _, label in ipairs(labelBase) do
			local key	= label..tostring(i)
			table.insert(labelList, key)
		end
	end
	
	for _, key in ipairs(labelList) do
		local text	= parameters[key]
		if text then
			Controls[key]:SetText(text)
		else
			Controls[key]:SetText("")
		end
	end
	
	local maxWidth = 0
	for _, key in ipairs(labelList) do
		local width	= Controls[key]:GetSizeX()
		maxWidth	= math.max(maxWidth, width)
	end
	
	-- Special case for condensed table
	if parameters.ListSmall then 
		Controls.ListSmall:SetText(parameters.ListSmall)
		local width	= Controls.ListSmall:GetSizeX()
		maxWidth	= math.max(maxWidth, width)
	else
		Controls.ListSmall:SetText("")
	end
	Controls.InfoStack:CalculateSize()
	local stackHeight = Controls.InfoStack:GetSizeY();
	Controls.TooltipInfo:SetSizeVal(maxWidth + SIZE_WIDTH_MARGIN, stackHeight + SIZE_HEIGHT_PADDING)
	
	m_ttWidth, m_ttHeight = Controls.InfoStack:GetSizeVal();
	Controls.TooltipGCO:SetSizeVal(m_ttWidth, m_ttHeight);
	
	if m_isUsingMouse then
		RealizeNewPlotTooltipMouse();
	end

	--Controls.TooltipGCO:ReprocessAnchoring()
	Controls.TooltipGCO:ChangeParent(ContextPtr:LookUpControl("/InGame/DiplomacyRibbon")) -- Why is this now needed since the GS patch ?
	--Controls.TooltipGCO:Reparent()
	Controls.TooltipGCO:SetHide(false);
	Controls.TooltipGCO:SetToBeginning();
	Controls.TooltipGCO:Play();
end
LuaEvents.ShowCustomToolTip.Add( TooltipOn )

--	Turn off the tooltips
function TooltipOff()
	m_isOff = true;
	Controls.TooltipGCO:SetToBeginning();	
	Controls.TooltipGCO:SetHide(true);
	LuaEvents.Tutorial_PlotToolTipsOn()
end
LuaEvents.HideCustomToolTip.Add( TooltipOff )

-- Set position
function RealizePositionAt( x:number, y:number )

	if m_isOff then
		return;
	end
	m_screenWidth, m_screenHeight 	= UIManager:GetScreenSizeVal()
	m_offsetX, m_offsetY 			= OFFSET_SHOW_AT_MOUSE_X, OFFSET_SHOW_AT_MOUSE_Y
	
	if UserConfiguration.GetValue("PlotToolTipFollowsMouse") == 1 then
		-- If tool tip manager is showing a *real* tooltip, don't show this plot tooltip to avoid potential overlap.
		if TTManager:IsTooltipShowing() then
			--ClearView();
		else
			local offsetx:number = x + m_offsetX;
			local offsety:number = m_screenHeight - y - m_offsetY;

			if (x + m_ttWidth + m_offsetX) > m_screenWidth then
				offsetx = x + -m_offsetX + -m_ttWidth;	-- flip
			else
				offsetx = x + m_offsetX;
			end

			-- Check height, push down if going off the bottom of the top...
			if offsety + Controls.TooltipGCO:GetSizeY() > (m_screenHeight - MIN_Y_POSITION)
			or offsety > Controls.TooltipGCO:GetSizeY()
			then
				offsety = offsety - Controls.TooltipGCO:GetSizeY();
			end

			Controls.TooltipGCO:SetOffsetVal( offsetx, offsety ); -- Subtract from screen height, as default anchor is "bottom"
		end
	end
	--]]
end

function RealizeNewPlotTooltipMouse( bIsUpdate:boolean )
	RealizePositionAt( UIManager:GetMousePos() );
end

function RealizeNewPlotTooltipTouch( pInputStruct:table )
	local touchX:number = pInputStruct:GetX();
	local touchY:number = pInputStruct:GetY();
	RealizePositionAt(touchX, touchY);
end

function OnInputHandler( pInputStruct:table )
print("OnInputHandler")
	if not m_isActive then
		return false;
	end

	local uiMsg:number	= pInputStruct:GetMessageType();
	m_isShiftDown		= pInputStruct:IsShiftDown();

    if uiMsg == MouseEvents.MouseMove then
		if (Automation.IsActive()) then
			-- Has the mouse actually moved?
			if (pInputStruct:GetMouseDX() == 0 and pInputStruct:GetMouseDY() == 0) then
				-- If the mouse has not moved for a while. hide the tool tip.
				if (m_lastMouseMoveTime ~= nil and (UI.GetElapsedTime() - m_lastMouseMoveTime > 5.0)) then
					ClearView();
				end
				return false;
			end
		end

		m_lastMouseMoveTime = UI.GetElapsedTime();

		m_isUsingMouse	= true;
		m_offsetX		= OFFSET_SHOW_AT_MOUSE_X;
		m_offsetY		= OFFSET_SHOW_AT_MOUSE_Y;
		RealizeNewPlotTooltipMouse()

	elseif uiMsg == MouseEvents.PointerUpdate and m_touchIdForPoint ~= -1 then		 
		m_isUsingMouse	= false;
		m_offsetX		= OFFSET_SHOW_AT_TOUCH_X;
		m_offsetY		= OFFSET_SHOW_AT_TOUCH_Y;

		if m_touchIdForPoint == pInputStruct:GetTouchID() then
			if m_isOff then
				TooltipOn();
			end		
			RealizeNewPlotTooltipTouch( pInputStruct );
		end
	end
	

    return false;	-- Don't consume, let whatever is after this get crack at input.
end

function AttachCustomToolTip(pInstanceElement, kParameters)

	function ShowToolTip()
		LuaEvents.ShowCustomToolTip(kParameters)
	end
	function CleanToolTip()
		LuaEvents.HideCustomToolTip()
	end					
	pInstanceElement:RegisterMouseEnterCallback(ShowToolTip)
	pInstanceElement:RegisterMouseExitCallback(CleanToolTip)

end


-- ===========================================================================
-- Show plot population on map (buggy / deprecated)
-- ===========================================================================

local g_InstanceManager	:table = InstanceManager:new( "PlotIcons",	"Anchor", Controls.PlotIconsContainer )
local g_MapIconsInstances	:table = {
	[DirectionTypes.DIRECTION_NORTHEAST] 	= {},
	[DirectionTypes.DIRECTION_NORTHWEST] 	= {},
	[DirectionTypes.DIRECTION_EAST]			= {}, 
	[DirectionTypes.DIRECTION_WEST]			= {},
	[DirectionTypes.DIRECTION_SOUTHEAST] 	= {}, 
	[DirectionTypes.DIRECTION_SOUTHWEST] 	= {}
	}
local g_MapIconsInfo	:table = {
	[DirectionTypes.DIRECTION_NORTHEAST] 	= {OffsetX = 12.0,	OffsetY = 24.0,	IconSuffixOut = "NE",	IconSuffixIn = "SW"	},
	[DirectionTypes.DIRECTION_NORTHWEST] 	= {OffsetX = -12.0,	OffsetY = 24.0,	IconSuffixOut = "NW",	IconSuffixIn = "SE"	},
	[DirectionTypes.DIRECTION_EAST]			= {OffsetX = 20.0,	OffsetY = 8.0,	IconSuffixOut = "E",	IconSuffixIn = "W"	}, 
	[DirectionTypes.DIRECTION_WEST]			= {OffsetX = -20.0,	OffsetY = 8.0,	IconSuffixOut = "W",	IconSuffixIn = "E"	},
	[DirectionTypes.DIRECTION_SOUTHEAST] 	= {OffsetX = 12.0,	OffsetY = -8.0,	IconSuffixOut = "SE",	IconSuffixIn = "NW"	}, 
	[DirectionTypes.DIRECTION_SOUTHWEST] 	= {OffsetX = -12.0,	OffsetY = -8.0,	IconSuffixOut = "SW",	IconSuffixIn = "NE"	}
	}

function GetPlotIconInstanceAt(x, y, direction)
	local plotIndex = Map.GetPlotIndex(x, y)
	local pInstance = g_MapIconsInstances[direction][plotIndex]
	if (pInstance == nil) then
		return SetPlotIconInstanceAt(x, y, direction)
	end
	return pInstance
end

function SetPlotIconInstanceAt(x, y, direction)
	local plotIndex = Map.GetPlotIndex(x, y)
	local row		= g_MapIconsInfo[direction]
	local pInstance = g_InstanceManager:GetInstance();
	local worldX, worldY = UI.GridToWorld( plotIndex );
	pInstance.Anchor:SetWorldPositionVal( worldX + row.OffsetX, worldY + row.OffsetY, 0.0 )
	--pInstance.Anchor:ChangeParent(ContextPtr:LookUpControl("/InGame/CityBannerManager"))
	
	--
	adjacentPlot = Map.GetAdjacentPlot(x, y, direction)
	if adjacentPlot then
		local plot			= GCO.GetPlot(x, y)
		local migrationData	= plot:GetMigrationDataWith(adjacentPlot)
		local migrants		= migrationData.Migrants
		local total			= migrationData.Total
		if migrants ~= 0 or total ~= 0 then 
			--
			local flow			= math.abs(migrants)
			local iconSuffix 	= (migrants > 0 and row.IconSuffixIn) or (migrants < 0 and row.IconSuffixOut) or (total > 0 and row.IconSuffixIn) or row.IconSuffixOut
			local iconType		= (flow > 10000 and "DOUBLE") or (flow > 1000 and "LONG") or "SMALL"--(flow > 10000 and "DOUBLE") or (flow > 1000 and "SIMPLE") or (flow > 100 and "LONG") or "SMALL"
			local iconStr		= "[ICON_"..iconType.."_ARROW_"..iconSuffix.."]"
			pInstance.TextContainer:SetHide( false )
			pInstance.ListText:SetText(iconStr)
			--
			pInstance.ListText:SetToolTipString("Migrants = ".. tostring(migrants) .."[NEWLINE]Total = "..tostring(total))
			--pInstance.ListText:SetToolTipType("ToolTipMono")
			g_MapIconsInstances[direction][plotIndex] = pInstance
				
			return pInstance
		end
	end
end

function ReleaseAllPlotIconInstances()
	for direction, plotInstances in pairs(g_MapIconsInstances) do
		for plotID, pInstance in pairs(plotInstances) do
			g_InstanceManager:ReleaseInstance( pInstance )
		end
	end
end

function ReleasePlotIconInstanceAt(x, y, direction)
	local pInstance = g_MapIconsInstances[direction][plotIndex]
	if (pInstance ~= nil) then
		g_InstanceManager:ReleaseInstance( pInstance )
		g_MapIcons[direction][plotIndex] = nil
	end
end

function HidePlotIcons()
	Controls.PlotIconsContainer:SetHide(true)
end

function ShowPlotIcons()
	Controls.PlotIconsContainer:SetHide(false)
end

function RemoveAllFromMap()
	local iCount = Map.GetPlotCount();
	for plotIndex = 0, iCount-1, 1 do
		RemoveAll(plotIndex)
	end
end

function RemoveAll(plotIndex)
	for direction = 0, DirectionTypes.NUM_DIRECTION_TYPES - 1, 1 do
		local pInstance = g_MapIconsInstances[direction][plotIndex]
		if (pInstance ~= nil) then
			g_InstanceManager:ReleaseInstance( pInstance )
			g_MapIcons[direction][plotIndex] = nil
		end
	end
end

function SetAll(plotIndex)
	local plot = Map.GetPlotByIndex(plotIndex)
	local x, y = plot:GetX(), plot:GetY()
	for direction = 0, DirectionTypes.NUM_DIRECTION_TYPES - 1, 1 do
		local pInstance = g_MapIconsInstances[direction][plotIndex]
		--if (pInstance == nil) then
			SetPlotIconInstanceAt(x, y, direction)
		--end
	end
end

function Rebuild()

	local eObserverID = Game.GetLocalObserver();
	local pLocalPlayerVis = PlayerVisibilityManager.GetPlayerVisibility(eObserverID);

	if (pLocalPlayerVis ~= nil) then
		local iCount = Map.GetPlotCount();
		for plotIndex = 0, iCount-1, 1 do

			local visibilityType = pLocalPlayerVis:GetState(plotIndex);
			if (visibilityType == RevealedState.HIDDEN) then
				RemoveAll(plotIndex);
			else
				SetAll(plotIndex)
				--[[
				if (visibilityType == RevealedState.REVEALED) then
					ChangeToMidFog(plotIndex);
				else
					if (visibilityType == RevealedState.VISIBLE) then
						ChangeToVisible(plotIndex);
					end
				end
				--]]
			end
		end
	end
	Controls.PlotIconsContainer:ChangeParent(ContextPtr:LookUpControl("/InGame/CityBannerManager"))
end


-- ===========================================================================
-- Show MigrationRoute
-- ===========================================================================


g_TradeRoute 				= UILens.CreateLensLayerHash("TradeRoutes")
local testedPlot 			= {} -- List plots that have been tested and doesn't have an exit path
local numPathPlot			= {} -- Store current number of major migration paths found from a plot
local testedPathDir			= {} -- List all plot/direction already stored in a path
kHistoricalMigrationSettings= {
	Name					= "Historical",
	MaxPathsPerPlot			= 5,
	MinMigrationRouteLength = 3,
	MinMigrationFlux		= 25,
	MaxAlphaAtInitialFlux	= 1500,
	MinAlphaRatio			= 0.25, -- ratio is in [0-1]
	bUseLastTurnValue		= false,
}
kCurrentMigrationSettings= {
	Name					= "Current",
	MaxPathsPerPlot			= 5,
	MinMigrationRouteLength = 2,
	MinMigrationFlux		= 0,
	MaxAlphaAtInitialFlux	= 250,
	MinAlphaRatio			= 0.25, -- ratio is in [0-1]
	bUseLastTurnValue		= true
}
kActiveMigrationSettings	= kHistoricalMigrationSettings -- default
local bShowHistoricalMigrationRoute = false
local bShowCurrentMigrationRoute	= false

function SetHasPathDirection(plotIndex,direction,nextIndex)
	numPathPlot[plotIndex] 				= numPathPlot[plotIndex] and numPathPlot[plotIndex] + 1 or 1
	testedPathDir[plotIndex] 			= testedPathDir[plotIndex] or {}
	testedPathDir[plotIndex][direction] = true
	
	local oppDir 						= GCO.GetOppositeDirection(direction)
	testedPathDir[nextIndex] 			= testedPathDir[nextIndex] or {}
	testedPathDir[nextIndex][oppDir] 	= true
end

function HasPathInDirection(plotIndex,direction)
	return testedPathDir[plotIndex] and testedPathDir[plotIndex][direction]
end

function GetMigrationPathFrom(plotIndex, path)
	local prevID	= #path > 0 and path[#path]
	local plot		= GCO.GetPlotByIndex(plotIndex)
	local Best		= { Value = - kActiveMigrationSettings.MinMigrationFlux}
	local worst		= 0
	local prevTurn	= GCO.GetPreviousTurnKey()
	
	for direction = 0, DirectionTypes.NUM_DIRECTION_TYPES - 1, 1 do					
	
		adjacentPlot = Map.GetAdjacentPlot(plot:GetX(), plot:GetY(), direction)
		if adjacentPlot and prevID ~= adjacentPlot:GetIndex() and not HasPathInDirection(plotIndex,direction) then
			local migrationData	= plot:GetMigrationDataWith(adjacentPlot)
			local value			= kActiveMigrationSettings.bUseLastTurnValue and migrationData.Migrants or migrationData.Total
			worst 				= value > worst and value or worst
			
			if value < Best.Value then -- looking for negative value here (ie population moving out)
				Best.Value 	= value
				Best.Plot	= adjacentPlot
				Best.Dir	= direction
			end
			
			if worst + Best.Value >= 0 then -- more pop moving in than out
				Best.Plot = nil
			end
		end
	end
	
	if Best.Plot then -- more people moving out than in, add to pass and test next
	
		local nextID 		= Best.Plot:GetIndex()
		
		SetHasPathDirection(plotIndex,Best.Dir,nextID)
		table.insert(path, plotIndex)
		--print("find path entry #"..tostring(#path).." from ".. plot:GetX() ..",".. plot:GetY() .. " to " .. Best.Plot:GetX() ..",".. Best.Plot:GetY())		
		GetMigrationPathFrom(nextID, path)
		
	else
		table.insert(path, plotIndex)
		--print("no path after entry #"..tostring(#path).." from ".. plot:GetX() ..",".. plot:GetY())
		testedPlot[plotIndex] = true
	end
end

function GetMigrationRoutes()
	local pLocalPlayerVis 	= PlayerVisibilityManager.GetPlayerVisibility(Game.GetLocalObserver())
	local migrationRoutes 	= {}
	-- Reset tables
	testedPlot 				= {}
	numPathPlot				= {}
	testedPathDir			= {}

	if (pLocalPlayerVis ~= nil) then
		local iCount = Map.GetPlotCount();
		for plotIndex = 0, iCount-1, 1 do
			if not testedPlot[plotIndex] then
				local visibilityType = pLocalPlayerVis:GetState(plotIndex);
				if (visibilityType ~= RevealedState.HIDDEN) then
					local numPaths = numPathPlot[plotIndex] or 0
					for n = numPaths, kActiveMigrationSettings.MaxPathsPerPlot - 1 do
						local path = {}
						GetMigrationPathFrom(plotIndex, path)
						if #path >= kActiveMigrationSettings.MinMigrationRouteLength then
							table.insert(migrationRoutes, path)
						end
					end
				end
			end
		end
	end
	ShowMigrationRoutes(migrationRoutes)
end

function ShowMigrationRoutes(migrationRoutes)
	if UI.GetInterfaceMode() == InterfaceModeTypes.CITY_MANAGEMENT or UI.GetInterfaceMode() == InterfaceModeTypes.MAKE_TRADE_ROUTE then return end
	UILens.SetActive(g_TradeRoute)
	UILens.ClearLayerHexes( g_TradeRoute )
	
	local prevTurn	= GCO.GetPreviousTurnKey()
	local kSettings	= kActiveMigrationSettings
	
	for _, pathPlots in ipairs(migrationRoutes) do
		if pathPlots then
			local kVariations:table = {}
			local startPlot = Map.GetPlotByIndex(pathPlots[1])
			local nextPlot	= Map.GetPlotByIndex(pathPlots[2])
			local kData		= startPlot:GetMigrationDataWith(nextPlot)
			local startFlux	= -(kSettings.bUseLastTurnValue and kData.Migrants or kData.Total) -- we were looking for negative values (population moving out)
			local alphaRatio= math.min(1,kSettings.MinAlphaRatio + ((1 - kSettings.MinAlphaRatio) * (startFlux/kSettings.MaxAlphaAtInitialFlux))) -- x + (1-x) * ratio
			local ownerID	= startPlot:GetOwner()
			local color 	= UI.GetColorValue(0.90, 0.90, 0.90, alphaRatio) --RGBAValuesToABGRHex(1, 1, 1, 1) --RGBAValuesToABGRHex
			if ownerID ~= -1 then
				local backColor, frontColor = (GCO.GetPlayerColors and GCO.GetPlayerColors(ownerID)) or UI.GetPlayerColors(ownerID)
				color = UI.DarkenLightenColor(backColor, 0, 255*alphaRatio) -- +amt = lighter -amt = darker alpha=0-255
			end
			UILens.SetLayerHexesPath( g_TradeRoute, Game.GetLocalPlayer(), pathPlots, kVariations, color )
			--bShowMigrationRoute = true
			--end
		end
	end
end
	
function ClearRoutes()
	if UI.GetInterfaceMode() == InterfaceModeTypes.CITY_MANAGEMENT or UI.GetInterfaceMode() == InterfaceModeTypes.MAKE_TRADE_ROUTE then return end
	bShowHistoricalMigrationRoute 	= false
	bShowCurrentMigrationRoute 		= false
	UILens.ClearLayerHexes( g_TradeRoute )
	if UILens.IsLensActive(g_TradeRoute) then
		-- Make sure to switch back to default lens
		UILens.SetActive("Default");
	end
end

function ToggleHistoricalMigrationRoutes()
	if bShowHistoricalMigrationRoute then
		ClearRoutes()
	else
		ClearRoutes()
		kActiveMigrationSettings = kHistoricalMigrationSettings
		GetMigrationRoutes()
		bShowHistoricalMigrationRoute 	= true
	end
end
function ToggleCurrentMigrationRoutes()
	if bShowCurrentMigrationRoute then
		ClearRoutes()
	else
		ClearRoutes()
		kActiveMigrationSettings = kCurrentMigrationSettings
		GetMigrationRoutes()
		bShowCurrentMigrationRoute		= true
	end
end

-- ===========================================================================
-- Initialize functions for other contexts
-- ===========================================================================
function Initialize()

	-- Input Handler for CustomToolTip
	ContextPtr:SetInputHandler( OnInputHandler, true )
	
	--
	--Controls.PlotIconsContainer:ChangeParent(ContextPtr:LookUpControl("/InGame/CityBannerManager"))
	

	-- Set shared table
	if not ExposedMembers.GCO then ExposedMembers.GCO = {} end	
	
	-- LuaEvents
	ExposedMembers.GCO.LuaEvents					= LuaEvents
	-- Network
	ExposedMembers.GCO.Network						= Network
	-- calendar
	ExposedMembers.GCO.GetTurnYear					= GetTurnYear
	-- cities
	ExposedMembers.GCO.GetCityCultureYield 			= GetCityCultureYield
	ExposedMembers.GCO.GetCityPlots					= GetCityPlots
	ExposedMembers.GCO.GetBuildingsAtLocation		= GetBuildingsAtLocation
	ExposedMembers.GCO.GetCityYield 				= GetCityYield
	ExposedMembers.GCO.IsCityCapital				= IsCityCapital
	ExposedMembers.GCO.GetCityTrade 				= GetCityTrade
	ExposedMembers.GCO.CityCanProduce				= CityCanProduce
	ExposedMembers.GCO.GetCityProductionTurnsLeft	= GetCityProductionTurnsLeft
	ExposedMembers.GCO.GetCityProductionYield		= GetCityProductionYield
	ExposedMembers.GCO.GetCityProductionProgress	= GetCityProductionProgress
	-- Game
	ExposedMembers.GCO.GetTradeManager 				= GetTradeManager
	-- players
	ExposedMembers.GCO.HasPlayerOpenBordersFrom 	= HasPlayerOpenBordersFrom
	ExposedMembers.GCO.CanPlayerDeclareWarOn 		= CanPlayerDeclareWarOn
	ExposedMembers.GCO.GetPlayerInfluenceMap		= GetPlayerInfluenceMap
	ExposedMembers.GCO.IsResourceVisibleFor 		= IsResourceVisibleFor
	ExposedMembers.GCO.HasPolicyActive 				= HasPolicyActive
	ExposedMembers.GCO.GetActivePolicies			= GetActivePolicies
	ExposedMembers.GCO.GetCurrentGovernment			= GetCurrentGovernment
	ExposedMembers.GCO.GetMission					= GetMission
	ExposedMembers.GCO.CallPlayerContextFunction	= CallPlayerContextFunction
	-- plots
	--local p = getmetatable(Map.GetPlot(1,1)).__index
	--ExposedMembers.GCO.PlotIsImprovementPillaged	= p.IsImprovementPillaged -- attaching this in script context doesn't work as the plot object from script miss other elements required for this by the plot object in UI context 
	ExposedMembers.GCO.IsImprovementPillaged 		= IsImprovementPillaged
	ExposedMembers.GCO.GetPlotAppeal				= GetPlotAppeal
	ExposedMembers.GCO.GetPlotActualYield			= GetPlotActualYield
	-- units
	ExposedMembers.GCO.GetMoveToPath				= GetMoveToPath
	ExposedMembers.GCO.SetUnitName					= SetUnitName
	ExposedMembers.GCO.RequestOperation				= RequestOperation
	ExposedMembers.GCO.CallUnitContextFunction		= CallUnitContextFunction
	-- others
	ExposedMembers.UI 								= UI
	ExposedMembers.Calendar							= Calendar
	ExposedMembers.CombatTypes 						= CombatTypes
	ExposedMembers.GCO.Options						= Options
	ExposedMembers.GCO.StatusMessage				= StatusMessage
	ExposedMembers.GCO.AttachCustomToolTip			= AttachCustomToolTip
	
	ExposedMembers.ContextFunctions_Initialized 	= true
end
Initialize()


-- ===========================================================================
-- Testing...
-- ===========================================================================
local _cache = {}
function CheckProgression()
	for _, playerID in ipairs(PlayerManager.GetWasEverAliveMajorIDs()) do
		local player 	= Players[playerID]
		local capital 	= player:GetCities():GetCapitalCity()
		if capital then
			GCO.AttachCityFunctions(capital)
			local cityKey				= capital:GetKey()
			local productionHash		= capital:GetBuildQueue():GetCurrentProductionTypeHash()
			local currentProductionInfo	= GetProductionInfoOfCity( capital, productionHash )
			if not _cache[cityKey] then _cache[cityKey] = {} end		
			if not _cache[cityKey].PercentComplete then
				_cache[cityKey].PercentComplete = currentProductionInfo.PercentComplete
				print ("Production progressed at ", Locale.Lookup(capital:GetName()), currentProductionInfo.PercentComplete)
			end
			if _cache[cityKey].PercentComplete ~= currentProductionInfo.PercentComplete then
				_cache[cityKey].PercentComplete = currentProductionInfo.PercentComplete
				print ("Production progressed at ", Locale.Lookup(capital:GetName()), currentProductionInfo.PercentComplete)
			end
		end
	end
end
--Events.GameCoreEventPublishComplete.Add( CheckProgression )

--[[
	return {
		Name					= productionName,
		Description				= description, 
		Type					= type;
		Icon					= iconName,
		PercentComplete			= percentComplete, 
		PercentCompleteNextTurn	= percentCompleteNextTurn,
		Turns					= prodTurnsLeft,
		StatString				= statString;
		Progress				= progress;
		Cost					= cost;		
	};
--]]

