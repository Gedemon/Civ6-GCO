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
end
GameEvents.InitializeGCO.Add( InitializeUtilityFunctions )


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
	if not contextCity then return 0 end
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
function StatusMessage( str:string, fDisplayTime:number, type:number, bForceDisplay )
	LuaEvents.StatusMessage(str, fDisplayTime, type)
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
	Controls.TooltipGCO:ChangeParent(ContextPtr:LookUpControl("/InGame/CityBannerManager")) -- Why is this now needed since the GS patch ?
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


-- ===========================================================================
-- Initialize functions for other contexts
-- ===========================================================================
function Initialize()

	-- Input Handler for CustomToolTip
	ContextPtr:SetInputHandler( OnInputHandler, true )

	-- Set shared table
	if not ExposedMembers.GCO then ExposedMembers.GCO = {} end	
	
	-- LuaEvents
	ExposedMembers.GCO.LuaEvents					= LuaEvents
	-- calendar
	ExposedMembers.GCO.GetTurnYear					= GetTurnYear
	-- cities
	ExposedMembers.GCO.GetCityCultureYield 			= GetCityCultureYield
	ExposedMembers.GCO.GetCityPlots					= GetCityPlots
	ExposedMembers.GCO.GetBuildingsAtLocation		= GetBuildingsAtLocation
	ExposedMembers.GCO.GetCityYield 				= GetCityYield
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
	ExposedMembers.GCO.IsResourceVisibleFor 		= IsResourceVisibleFor
	ExposedMembers.GCO.HasPolicyActive 				= HasPolicyActive
	ExposedMembers.GCO.GetActivePolicies			= GetActivePolicies
	ExposedMembers.GCO.GetCurrentGovernment			= GetCurrentGovernment
	-- plots
	--local p = getmetatable(Map.GetPlot(1,1)).__index
	--ExposedMembers.GCO.PlotIsImprovementPillaged	= p.IsImprovementPillaged -- attaching this in script context doesn't work as the plot object from script miss other elements required for this by the plot object in UI context 
	ExposedMembers.GCO.IsImprovementPillaged 		= IsImprovementPillaged
	ExposedMembers.GCO.GetPlotAppeal				= GetPlotAppeal
	-- units
	ExposedMembers.GCO.GetMoveToPath				= GetMoveToPath
	ExposedMembers.GCO.SetUnitName					= SetUnitName
	ExposedMembers.GCO.RequestOperation				= RequestOperation
	-- others
	ExposedMembers.UI 								= UI
	ExposedMembers.Calendar							= Calendar
	ExposedMembers.CombatTypes 						= CombatTypes
	ExposedMembers.GCO.Options						= Options
	ExposedMembers.GCO.StatusMessage				= StatusMessage
	
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