-- ===========================================================================
--
--	PlotToolTip
--	Show information about the plot currently being hovered by the mouse,
--	or the last plot to be touched.
--
--	Three levels of turning these on/off:
--		m_isForceOff	- Completely turns off the system (don't even initialize!)
--		m_isActive		- Temporary turn on/off the system (e.g., wonder reveals)
--		m_isOff			- Off for a moment; such as another tooltip is up
--
-- ===========================================================================

-- GCO <<<<<
-----------------------------------------------------------------------------------------
-- Defines
-----------------------------------------------------------------------------------------
local FeatureResources				= {} -- cached table to list resources produced by a feature
for row in GameInfo.FeatureResourcesProduced() do
	local featureID		= GameInfo.Features[row.FeatureType].Index
	local resourceID 	= GameInfo.Resources[row.ResourceType].Index
	if not FeatureResources[featureID] then FeatureResources[featureID] = {} end
	table.insert(FeatureResources[featureID], {[resourceID] = row.NumPerFeature})
end

local TerrainResources				= {} -- cached table to list resources available on a terrain
for row in GameInfo.TerrainResourcesProduced() do
	local terrainID		= GameInfo.Terrains[row.TerrainType].Index
	local resourceID 	= GameInfo.Resources[row.ResourceType].Index
	if not TerrainResources[terrainID] then TerrainResources[terrainID] = {} end
	table.insert(TerrainResources[terrainID], {[resourceID] = row.NumPerTerrain})
end


-----------------------------------------------------------------------------------------
-- Initialize Functions
-----------------------------------------------------------------------------------------

local GCO = {}
function InitializeUtilityFunctions()
	GCO = ExposedMembers.GCO		-- contains functions from other contexts
	print ("Exposed Functions from other contexts initialized...")
end
LuaEvents.InitializeGCO.Add( InitializeUtilityFunctions )
-- GCO >>>>>

-- ===========================================================================
--	Debug constants
-- ===========================================================================
local m_isForceOff			:boolean = false;	-- Force always off



-- ===========================================================================
--	CONSTANTS
-- ===========================================================================
local MIN_Y_POSITION		:number = 50;	-- roughly where top panel starts
local OFFSET_SHOW_AT_MOUSE_X:number = 40; 
local OFFSET_SHOW_AT_MOUSE_Y:number = 20; 
local OFFSET_SHOW_AT_TOUCH_X:number = -30; 
local OFFSET_SHOW_AT_TOUCH_Y:number = -35;
local SIZE_WIDTH_MARGIN		:number = 20;
local SIZE_HEIGHT_PADDING	:number = 20;
local TIME_DEFAULT_PAUSE	:number = 1.1;


-- ===========================================================================
--	MEMBERS
-- ===========================================================================
local m_isActive		:boolean	= false;	-- Is this active
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

-- This is horrible, i'm sorry.
local TerrainTypeMap :table = {};
do
	for row in GameInfo.Terrains() do
		TerrainTypeMap[row.Index] = row.TerrainType;
	end
end

local FeatureTypeMap :table = {};
do
	for row in GameInfo.Features() do
		FeatureTypeMap[row.Index] = row.FeatureType;
	end
end

local ImprovementTypeMap :table = {};
do
	for row in GameInfo.Improvements() do
		ImprovementTypeMap[row.Index] = row.ImprovementType;
	end
end

local ResourceTypeMap :table = {};
do
	for row in GameInfo.Resources() do
		ResourceTypeMap[row.Index] = row.ResourceType;
	end
end

local UnitTypeMap :table = {};
do
	for row in GameInfo.Units() do
		UnitTypeMap[row.Index] = row.UnitType;
	end
end

local BuildingTypeMap :table = {};
do
	for row in GameInfo.Buildings() do
		BuildingTypeMap[row.Index] = row.BuildingType;
	end
end

local DistrictTypeMap :table = {};
do
	for row in GameInfo.Districts() do
		DistrictTypeMap[row.Index] = row.DistrictType;
	end
end

local ContinentTypeMap :table = {};
do
	for row in GameInfo.Continents() do
		ContinentTypeMap[row.Index] = row.ContinentType;
	end
end



-- ===========================================================================
--	Functions
-- ===========================================================================


-- ===========================================================================
--	Clear the tooltip since over a plot that isn't visible
-- ===========================================================================
function ClearView()
	Controls.TooltipMain:SetHide(true);	
end


-- ===========================================================================
--	Update the position of the mouse (if using that functionality) and
--	flip position if bleeding off edge of frame.
-- ===========================================================================
function RealizePositionAt( x:number, y:number )

	if m_isOff then
		return;
	end

	if UserConfiguration.GetValue("PlotToolTipFollowsMouse") == 1 then
		-- If tool tip manager is showing a *real* tooltip, don't show this plot tooltip to avoid potential overlap.
		if TTManager:IsTooltipShowing() then
			Controls.TooltipMain:SetHide(true);	
		else
			if m_isValidPlot then
				Controls.TooltipMain:SetHide(false);	
		
				local offsetx:number = x + m_offsetX;
				local offsety:number = m_screenHeight - y - m_offsetY;

				if (x + m_ttWidth + m_offsetX) > m_screenWidth then
					offsetx = x + -m_offsetX + -m_ttWidth;	-- flip
				else
					offsetx = x + m_offsetX;
				end

				-- Check height, push down if going off the bottom of the top...
				if offsety + Controls.TooltipMain:GetSizeY() > (m_screenHeight - MIN_Y_POSITION) then
					offsety = offsety - Controls.TooltipMain:GetSizeY();
				end

				Controls.TooltipMain:SetOffsetVal( offsetx, offsety ); -- Subtract from screen height, as default anchor is "bottom"
			end
		end
	end
end

-- ===========================================================================
--	Turn on the tooltips
-- ===========================================================================
function TooltipOn()
	m_isOff = false;

	-- If the whole system is not active, leave before actually displaying tooltip.
	if not m_isActive then		
		return;
	end

	Controls.TooltipMain:SetToBeginning();
	Controls.TooltipMain:Play();
	
	if m_isUsingMouse then
		RealizeNewPlotTooltipMouse();
	end
end

-- ===========================================================================
--	Turn off the tooltips
-- ===========================================================================
function TooltipOff()
	m_isOff = true;
	Controls.TooltipMain:SetToBeginning();	
	Controls.TooltipMain:SetHide(true);
end

-- ===========================================================================
-- View(data)
-- Update the layout based on the view model
-- ===========================================================================
function View(data:table, bIsUpdate:boolean)
	-- Build a string that contains all plot details.
	local details = {};
	local debugInfo = {};

	if(data.Owner ~= nil) then

		local szOwnerString;

		local pPlayerConfig = PlayerConfigurations[data.Owner];
		if (pPlayerConfig ~= nil) then
			szOwnerString = Locale.Lookup(pPlayerConfig:GetCivilizationShortDescription());
		end

		if (szOwnerString == nil or string.len(szOwnerString) == 0) then
			szOwnerString = Locale.Lookup("LOC_TOOLTIP_PLAYER_ID", data.Owner);
		end

		local pPlayer = Players[data.Owner];
		if(GameConfiguration:IsAnyMultiplayer() and pPlayer:IsHuman()) then
			szOwnerString = szOwnerString .. " (" .. pPlayerConfig:GetPlayerName() .. ")";
		end

		table.insert(details, Locale.Lookup("LOC_TOOLTIP_CITY_OWNER",szOwnerString, data.OwningCityName));
	end

	if(data.FeatureType ~= nil) then
		local szFeatureString = Locale.Lookup(GameInfo.Features[data.FeatureType].Name);
		local localPlayer = Players[Game.GetLocalPlayer()];
		local addCivicName = GameInfo.Features[data.FeatureType].AddCivic;
		if (localPlayer ~= nil and addCivicName ~= nil) then
			local civicIndex = GameInfo.Civics[addCivicName].Index;
			if (localPlayer:GetCulture():HasCivic(civicIndex)) then
			    local szAdditionalString;
				if (not data.FeatureAdded) then
					szAdditionalString = Locale.Lookup("LOC_TOOLTIP_PLOT_WOODS_OLD_GROWTH");
				else
					szAdditionalString = Locale.Lookup("LOC_TOOLTIP_PLOT_WOODS_SECONDARY");
				end
				szFeatureString = szFeatureString .. " " .. szAdditionalString;
			end
		end
		table.insert(details, szFeatureString);
	end
	if(data.NationalPark ~= "") then
		table.insert(details, data.NationalPark);
	end

	if(data.ResourceType ~= nil) then
		--if it's a resource that requires a tech to improve, let the player know that in the tooltip
		local resourceType = data.ResourceType;
		local resource = GameInfo.Resources[resourceType];

		-- GCO <<<<<
		--[[
		--local resourceString = Locale.Lookup(resource.Name);
		local resourceString = Locale.Lookup(resource.Name) .. " ("..tostring(data.ResourceCount)..")"
		-- GCO >>>>>
		local resourceTechType;

		local terrainType = data.TerrainType;
		local featureType = data.FeatureType;

		-- Are there any improvements that specifically require this resource?
		for row in GameInfo.Improvement_ValidResources() do
			if (row.ResourceType == resourceType) then
				-- Found one!  Now.  Can it be constructed on this terrain/feature
				local improvementType = row.ImprovementType;
				local has_feature = false;
				local valid_feature = false;
				for inner_row in GameInfo.Improvement_ValidFeatures() do
					if(inner_row.ImprovementType == improvementType) then
						has_feature = true;
						if(inner_row.FeatureType == featureType) then
							valid_feature = true;
						end
					end
				end
				valid_feature = not has_feature or valid_feature;

				local has_terrain = false;
				local valid_terrain = false;
				for inner_row in GameInfo.Improvement_ValidTerrains() do
					if(inner_row.ImprovementType == improvementType) then
						has_terrain = true;
						if(inner_row.TerrainType == terrainType) then
							valid_terrain = true;
						end
					end
				end
				valid_terrain = not has_terrain or valid_terrain;

				if(valid_feature and valid_terrain) then
					resourceTechType = GameInfo.Improvements[improvementType].PrereqTech;
					break;
				end
			end
		end
		if (resourceTechType ~= nil) then
			local localPlayer	= Players[Game.GetLocalPlayer()];
			if (localPlayer ~= nil) then
				local playerTechs	= localPlayer:GetTechs();
				local techType = GameInfo.Technologies[resourceTechType];
				if (techType ~= nil and not playerTechs:HasTech(techType.Index)) then
					resourceString = resourceString .. "[COLOR:Civ6Red]  ( " .. Locale.Lookup("LOC_TOOLTIP_REQUIRES") .. " " .. Locale.Lookup(techType.Name) .. ")[ENDCOLOR]";
				end
			end
		end
		table.insert(details, resourceString)
		
		-- GCO <<<<<
		--]]
		-- GCO >>>>>
	end
	
	if (data.IsRiver == true) then
		table.insert(details, Locale.Lookup("LOC_TOOLTIP_RIVER"));
	end

	-- Movement cost
	if (not data.Impassable and data.MovementCost > 0) then
		table.insert(details, Locale.Lookup("LOC_TOOLTIP_MOVEMENT_COST", data.MovementCost));
	end

	-- ROUTE TILE
	if (data.IsRoute) then
		local routeInfo = GameInfo.Routes[data.RouteType];
		if (routeInfo ~= nil and routeInfo.MovementCost ~= nil and routeInfo.Name ~= nil) then
			
			local str;
			if(data.RoutePillaged) then
				str = Locale.Lookup("LOC_TOOLTIP_ROUTE_MOVEMENT_PILLAGED", routeInfo.MovementCost, routeInfo.Name);
			else
				str = Locale.Lookup("LOC_TOOLTIP_ROUTE_MOVEMENT", routeInfo.MovementCost, routeInfo.Name);
			end

			table.insert(details, str);
		end		
	end

	-- Defense modifier
	if (data.DefenseModifier ~= 0) then
		table.insert(details, Locale.Lookup("LOC_TOOLTIP_DEFENSE_MODIFIER", data.DefenseModifier));
	end

	-- Appeal
	if (not data.IsWater) then
		local strAppealDescriptor;
		for row in GameInfo.AppealHousingChanges() do
			local iMinimumValue = row.MinimumValue;
			local szDescription = row.Description;
			if (data.Appeal >= iMinimumValue) then
				strAppealDescriptor = Locale.Lookup(szDescription);
				break;
			end
		end
		if(strAppealDescriptor) then
			table.insert(details, Locale.Lookup("LOC_TOOLTIP_APPEAL", strAppealDescriptor, data.Appeal));
		end
	end

	if (data.Continent == nil) then
		table.insert(details, Locale.Lookup("LOC_TOOLTIP_CONTINENT_NONE"));
	else
		table.insert(details, Locale.Lookup("LOC_TOOLTIP_CONTINENT", GameInfo.Continents[data.Continent].Description));
	end

	-- Conditional display based on tile type

	-- WONDER TILE
	if(data.WonderType ~= nil) then
		
		table.insert(details, "------------------");
		
		if (data.WonderComplete == true) then
			table.insert(details, Locale.Lookup(GameInfo.Buildings[data.WonderType].Name));

		else

			table.insert(details, Locale.Lookup(GameInfo.Buildings[data.WonderType].Name) .. " " .. Locale.Lookup("LOC_TOOLTIP_PLOT_CONSTRUCTION_TEXT"));
		end
	end

	-- CITY TILE
	if(data.IsCity == true) then
		
		table.insert(details, "------------------");
		
		table.insert(details, Locale.Lookup(GameInfo.Districts[data.DistrictType].Name))

		for yieldType, v in pairs(data.Yields) do
			local yield = GameInfo.Yields[yieldType].Name;
			local yieldicon = GameInfo.Yields[yieldType].IconString;
			local str = tostring(v) .. Locale.Lookup(yieldicon) .. Locale.Lookup(yield);
			table.insert(details, str);
		end
		
		--if(data.Buildings ~= nil and table.count(data.Buildings) > 0) then
		--	table.insert(details, "Buildings: ");
			
		--	for i, v in ipairs(data.Buildings) do 
		--		table.insert(details, "  " .. Locale.Lookup(v));
		--	end
		--end

		--if(data.Constructions ~= nil and table.count(data.Constructions) > 0) then
		--	table.insert(details, "UnderConstruction: ");
		--	
		--	for i, v in ipairs(data.Constructions) do 
		--		table.insert(details, "  " .. Locale.Lookup(v));
		--	end
		--end

	-- DISTRICT TILE
	elseif(data.DistrictID ~= -1) then
		if (not GameInfo.Districts[data.DistrictType].InternalOnly) then	--Ignore 'Wonder' districts
			-- Plot yields (ie. from Specialists)
			if (data.Yields ~= nil) then
				if (table.count(data.Yields) > 0) then
					table.insert(details, "------------------");
					table.insert(details, Locale.Lookup("LOC_PEDIA_CONCEPTS_PAGE_CITIES_9_CHAPTER_CONTENT_TITLE")); -- "Specialists", text lock :'()
				end
				for yieldType, v in pairs(data.Yields) do
					local yield = GameInfo.Yields[yieldType].Name;
					local yieldicon = GameInfo.Yields[yieldType].IconString;
					local str = tostring(v) .. Locale.Lookup(yieldicon) .. Locale.Lookup(yield);
					table.insert(details, str);
				end
			end

			-- Inherent district yields
			local sDistrictName :string = Locale.Lookup(Locale.Lookup(GameInfo.Districts[data.DistrictType].Name));
			if (data.DistrictPillaged) then
				sDistrictName = sDistrictName .. " " .. Locale.Lookup("LOC_TOOLTIP_PLOT_PILLAGED_TEXT");
			end
			table.insert(details, "------------------");
			table.insert(details, sDistrictName);
			if (data.DistrictYields ~= nil) then
				for yieldType, v in pairs(data.DistrictYields) do
					local yield = GameInfo.Yields[yieldType].Name;
					local yieldicon = GameInfo.Yields[yieldType].IconString;
					local str = tostring(v) .. Locale.Lookup(yieldicon) .. Locale.Lookup(yield);
					table.insert(details, str);
				end
			end
		end
				
	-- IMPASSABLE TILE
	elseif(data.Impassable == true) then
		table.insert(details, Locale.Lookup("LOC_TOOLTIP_PLOT_IMPASSABLE_TEXT"));

	-- OTHER TILE
	else
		table.insert(details, "------------------");
		if(data.ImprovementType ~= nil) then
			local improvementStr = Locale.Lookup(GameInfo.Improvements[data.ImprovementType].Name);
			if (data.ImprovementPillaged) then
				improvementStr = improvementStr .. " " .. Locale.Lookup("LOC_TOOLTIP_PLOT_PILLAGED_TEXT");
			end
			table.insert(details, improvementStr)
		end
		
		for yieldType, v in pairs(data.Yields) do
			local yield = GameInfo.Yields[yieldType].Name;
			local yieldicon = GameInfo.Yields[yieldType].IconString;
			local str = tostring(v) .. Locale.Lookup(yieldicon) .. Locale.Lookup(yield);
			table.insert(details, str);
		end
	end

	-- NATURAL WONDER TILE
	if(data.FeatureType ~= nil) then
		local feature = GameInfo.Features[data.FeatureType];
		if(feature.NaturalWonder) then
			table.insert(details, "------------------");
			table.insert(details, Locale.Lookup(feature.Description));
		end
	end
	
	-- For districts, city center show all building info including Great Works
	-- For wonders, just show Great Work info
	if (data.IsCity or data.WonderType ~= nil or data.DistrictID ~= -1) then
		if(data.BuildingNames ~= nil and table.count(data.BuildingNames) > 0) then
			local cityBuildings = data.OwnerCity:GetBuildings();
			if (data.WonderType == nil) then
				table.insert(details, Locale.Lookup("LOC_TOOLTIP_PLOT_BUILDINGS_TEXT"));
			end
			for i, v in ipairs(data.BuildingNames) do 
			    if (data.WonderType == nil) then
					if (data.BuildingsPillaged[i]) then
						table.insert(details, "- " .. Locale.Lookup(v) .. " " .. Locale.Lookup("LOC_TOOLTIP_PLOT_PILLAGED_TEXT"));
					else
						table.insert(details, "- " .. Locale.Lookup(v));
					end
				end
				local iSlots = cityBuildings:GetNumGreatWorkSlots(data.BuildingTypes[i]);
				for j = 0, iSlots - 1, 1 do
					local greatWorkIndex:number = cityBuildings:GetGreatWorkInSlot(data.BuildingTypes[i], j);
					if (greatWorkIndex ~= -1) then
						local greatWorkType:number = cityBuildings:GetGreatWorkTypeFromIndex(greatWorkIndex)
						table.insert(details, "- " .. Locale.Lookup(GameInfo.GreatWorks[greatWorkType].Name));
					end
				end
			end
		end
	end

	-- Show number of civilians working here
	if (data.Owner == Game.GetLocalPlayer() and data.Workers > 0) then
		table.insert(details, Locale.Lookup("LOC_TOOLTIP_PLOT_WORKED_TEXT", data.Workers));
	end

	if (data.Fallout > 0) then
		table.insert(details, Locale.Lookup("LOC_TOOLTIP_PLOT_CONTAMINATED_TEXT", data.Fallout));
	end

	-- Add debug information in here:
	if m_isShowDebug then
		-- Show plot x,y, id and vis count
		local iVisCount = 0;
		if (Game.GetLocalPlayer() ~= -1) then
			local pLocalPlayerVis = PlayerVisibilityManager.GetPlayerVisibility(Game.GetLocalPlayer());
			if (pLocalPlayerVis ~= nil) then
				iVisCount = pLocalPlayerVis:GetLayerValue(VisibilityLayerTypes.TERRAIN, data.X, data.Y);
			end
		end
		-- GCO <<<<<	
		table.insert(debugInfo, "------------------")
		-- GCO >>>>>
		table.insert(debugInfo, "Plot #:" .. tostring(data.Index) .. " @("..tostring(data.X) .. ", " .. tostring(data.Y) .. "), vis:" .. tostring(iVisCount));
			
	end

	-- GCO <<<<<	
	local plot = GCO.GetPlotByIndex(data.Index) -- to get a PlotScript context plot
	
	-- Population & Culture
	table.insert(details, "------------------")
	local totalCulture 	= plot:GetTotalCulture()
	local population	= plot:GetPopulation()
	local size			= plot:GetSize()
	
	if data.IsCity then
		GCO.AttachCityFunctions(data.OwnerCity)
		population = data.OwnerCity:GetRealPopulation()
	else
		table.insert(details, Locale.Lookup("LOC_PLOT_TOOLTIP_SIZE_LINE", GCO.Round(size) ))		
	end	
	table.insert(details, Locale.Lookup("LOC_PLOT_TOOLTIP_POPULATION_LINE", GCO.Round(population) ))
	if totalCulture > 0 then
		local sortedCulture = {}
		for playerID, value in pairs (plot:GetCulturePercentTable()) do
			table.insert(sortedCulture, {playerID = tonumber(playerID), value = value})
		end	
		table.sort(sortedCulture, function(a,b) return a.value>b.value end)
		local numLines = 5
		local other = 0
		local iter = 1
		table.insert(details, Locale.Lookup("LOC_PLOT_TOOLTIP_CULTURE_TOTAL", GCO.Round(totalCulture) ))
		for i, t in ipairs(sortedCulture) do
			if (iter <= numLines) or (#sortedCulture == numLines + 1) then
				local playerConfig = PlayerConfigurations[t.playerID]
				local civAdjective = Locale.Lookup(GameInfo.Civilizations[playerConfig:GetCivilizationTypeID()].Adjective)
				if t.value > 0 then table.insert(details, Locale.Lookup("LOC_PLOT_TOOLTIP_CULTURE_LINE", GCO.ToDecimals(t.value), civAdjective)) end
			else
				other = other + t.value
			end
			iter = iter + 1
		end
		if other > 0 then table.insert(details, Locale.Lookup("LOC_PLOT_TOOLTIP_CULTURE_LINE_OTHER", other)) end
	end
	
	-- Employment
	if not data.IsCity then
		table.insert(details, "------------------")
		local EmploymentTable, maxEmployment = plot:GetAvailableEmployment()
		for key, value in pairs(EmploymentTable) do
			table.insert(details, Locale.Lookup("LOC_PLOT_TOOLTIP_EMPLOYMENT_LINE", value, key))
		end
		table.insert(details, Locale.Lookup("LOC_PLOT_TOOLTIP_MAX_EMPLOYMENT_LINE", maxEmployment))
		table.insert(details, Locale.Lookup("LOC_PLOT_TOOLTIP_EMPLOYED_LINE", plot:GetEmployed()))
		table.insert(details, Locale.Lookup("LOC_PLOT_TOOLTIP_ACTIVITY_PERCENT_LINE", plot:GetActivityFactor()*100))
		table.insert(details, Locale.Lookup("LOC_PLOT_TOOLTIP_OUTPUT_PER_YIELD_LINE", plot:GetOutputPerYield()))
	end
		
	-- Resources
	if not data.IsCity then
		table.insert(details, "------------------")
		local BaseImprovementMultiplier	= tonumber(GameInfo.GlobalParameters["RESOURCE_BASE_IMPROVEMENT_MULTIPLIER"].Value)
		local improvementMultiplier 	= 1
		local improvementID
		if(data.ImprovementType ~= nil) then
			improvementID = GameInfo.Improvements[data.ImprovementType].Index
		end
		for resourceID, v in pairs(data.Resources) do
			local resName 			= GCO.GetResourceIcon(resourceID) .. " " ..Locale.Lookup(GameInfo.Resources[resourceID].Name)
			local improvementNeeded	= GCO.GetResourceImprovementID(resourceID)
			local improvementStr	= ""
			if improvementNeeded then
				if improvementID == improvementNeeded then
					improvementMultiplier = BaseImprovementMultiplier
					improvementStr = " [COLOR:Civ6Green](" ..Locale.Lookup("LOC_PLOT_TOOLTIP_IMPROVEMENT_MULTIPLIER", BaseImprovementMultiplier, GameInfo.Improvements[improvementNeeded].Name)..")[ENDCOLOR]"
				else
					improvementStr = " [COLOR:Civ6Red](" ..Locale.Lookup("LOC_PLOT_TOOLTIP_IMPROVEMENT_MULTIPLIER", BaseImprovementMultiplier, GameInfo.Improvements[improvementNeeded].Name)..")[ENDCOLOR]"
				end
			end
			local str = tostring(GCO.ToDecimals(v * improvementMultiplier * plot:GetOutputPerYield())) .. resName .. "(".. tostring(v) ..")" .. improvementStr
			table.insert(details, str)
		end
	end
	-- GCO >>>>>
	
	-- Set the control values
	if (data.IsLake) then
		Controls.PlotName:LocalizeAndSetText("LOC_TOOLTIP_LAKE");
	else
		Controls.PlotName:LocalizeAndSetText(data.TerrainTypeName);
	end
	Controls.PlotDetails:SetText(table.concat(details, "[NEWLINE]"));

	if m_isShowDebug then
		Controls.DebugTxt:SetText(table.concat(debugInfo, "[NEWLINE]"));
	end
			
	-- Some conditions, jump past "pause" and show immediately
	if m_isShiftDown or UserConfiguration.GetValue("PlotToolTipFollowsMouse") == 0 then
		Controls.TooltipMain:SetPauseTime( 0 );
		Controls.TooltipMain:SetHide(false);
	else
		-- Pause time is shorter when using touch.
		local pauseTime = UserConfiguration.GetPlotTooltipDelay() or TIME_DEFAULT_PAUSE;
		Controls.TooltipMain:SetPauseTime( m_isUsingMouse and pauseTime or (pauseTime/2) );
	end

	if not bIsUpdate then
		Controls.TooltipMain:SetToBeginning();
		Controls.TooltipMain:Play();
	end

	-- Resize the background to wrap the content 
	local plotName_width :number, plotName_height :number		= Controls.PlotName:GetSizeVal();
	local nameHeight :number									= Controls.PlotName:GetSizeY();
	local plotDetails_width :number, plotDetails_height :number = Controls.PlotDetails:GetSizeVal();
	local debugInfoHeight :number								= Controls.DebugTxt:GetSizeY();
	
	local max_width :number = math.max(plotName_width, plotDetails_width);
	
	Controls.InfoStack:CalculateSize();
	local stackHeight = Controls.InfoStack:GetSizeY();

	Controls.PlotInfo:SetSizeVal(max_width + SIZE_WIDTH_MARGIN, stackHeight + SIZE_HEIGHT_PADDING);	
	
	m_ttWidth, m_ttHeight = Controls.InfoStack:GetSizeVal();
	Controls.TooltipMain:SetSizeVal(m_ttWidth, m_ttHeight);
end


-- ===========================================================================
--	Show the information for a given plot
-- ===========================================================================
function ShowPlotInfo( plotId:number, bIsUpdate:boolean )

	-- Ignore request to show plot if system is not on or active.
	if (not m_isActive) or m_isOff then
		ClearView();		-- Make sure it is not there
		return;
	end

	-- Check cached plot ID, only update contents if a different plot is shown
	if plotId ~= m_plotId or bIsUpdate then
		m_plotId = plotId;
		local plot = Map.GetPlotByIndex(plotId);
		if (plot == nil) then
			m_isValidPlot = false;
			ClearView();
			return;
		end

		local eObserverPlayerID = Game.GetLocalObserver();

		local eResourceType;

		if (eObserverPlayerID == PlayerTypes.OBSERVER) then
			m_isValidPlot = true;
			eResourceType = plot:GetResourceType();
		else
			local pPlayerVis = PlayersVisibility[eObserverPlayerID];
			if (pPlayerVis == nil) then
				m_isValidPlot = false;
				ClearView();
				return;
			end

			eResourceType = pPlayerVis:GetLayerValue(VisibilityLayerTypes.RESOURCES, plot);
			m_isValidPlot = pPlayerVis:IsRevealed(plotId);
		end

		local kFalloutManager = Game:GetFalloutManager();
					
		if (not m_isValidPlot) then
			ClearView();
		else
			local new_data = {
				X		= plot:GetX(),
				Y		= plot:GetY(),
				Index	= plot:GetIndex(),
				Appeal				= plot:GetAppeal(),
				Continent			= ContinentTypeMap[plot:GetContinentType()] or nil,
				DefenseModifier		= plot:GetDefenseModifier(),
				DistrictID			= plot:GetDistrictID();
				DistrictPillaged	= false;
				DistrictType		= DistrictTypeMap[plot:GetDistrictType()],
				Fallout				= kFalloutManager:GetFalloutTurnsRemaining(plot:GetIndex());
				FeatureType			= FeatureTypeMap[plot:GetFeatureType()],
				FeatureAdded		= plot:HasFeatureBeenAdded();
				Impassable			= plot:IsImpassable();
				ImprovementType		= ImprovementTypeMap[plot:GetImprovementType()],
				ImprovementPillaged = plot:IsImprovementPillaged(),
				IsCity				= plot:IsCity(),
				IsLake				= plot:IsLake(),
				IsRiver				= plot:IsRiver(),				
				IsRoute				= plot:IsRoute(),
				IsWater				= plot:IsWater(),
				MovementCost		= plot:GetMovementCost(),
				Owner				= (plot:GetOwner() ~= -1) and plot:GetOwner() or nil,
				OwnerCity			= Cities.GetPlotPurchaseCity(plot);
				ResourceCount		= plot:GetResourceCount(),
				ResourceType		= ResourceTypeMap[eResourceType],
				RoutePillaged		= plot:IsRoutePillaged(),
				RouteType			= plot:GetRouteType(),
				TerrainType			= TerrainTypeMap[plot:GetTerrainType()],
				TerrainTypeName		= GameInfo.Terrains[TerrainTypeMap[plot:GetTerrainType()]].Name,
				WonderComplete		= false,
				WonderType			= BuildingTypeMap[plot:GetWonderType()],
				Workers				= plot:GetWorkerCount();

				-- Remove these once we have a visualization of cliffs
				IsNWOfCliff			= plot:IsNWOfCliff(),  
				IsWOfCliff			= plot:IsWOfCliff(),
				IsNEOfCliff			= plot:IsNEOfCliff(),
				---- END REMOVE

				BuildingNames		= {},
				BuildingsPillaged	= {},
				BuildingTypes		= {},
				Constructions		= {},
				Yields				= {},
				-- GCO <<<<<
				Resources			= {},
				-- GCO >>>>>
				DistrictYields		= {},
			};
			
			-- GCO <<<<<
			local localPlayerID = Game.GetLocalPlayer()
			if localPlayerID == -1 then localPlayerID = 0 end
			local localPlayer	= GCO.GetPlayer(localPlayerID)
			local featureID 	= plot:GetFeatureType()
			local terrainID 	= plot:GetTerrainType()
			
			if new_data.ResourceCount > 0 then
				new_data.Resources[eResourceType] = (new_data.Resources[eResourceType] or 0) + new_data.ResourceCount
			end
			
			if FeatureResources[featureID] then
				for _, data in pairs(FeatureResources[featureID]) do
					for resourceID, value in pairs(data) do
						if localPlayer:IsResourceVisible(resourceID) then
							new_data.Resources[resourceID] = (new_data.Resources[resourceID] or 0) + value
						end
					end
				end
			end
			
			if TerrainResources[terrainID] then
				for _, data in pairs(TerrainResources[terrainID]) do
					for resourceID, value in pairs(data) do
						if localPlayer:IsResourceVisible(resourceID) then
							new_data.Resources[resourceID] = (new_data.Resources[resourceID] or 0) + value
						end
					end
				end
			end
			-- GCO >>>>>

			if (plot:IsNationalPark()) then
				new_data.NationalPark = plot:GetNationalParkName();
			else
				new_data.NationalPark = "";
			end
				
			if (new_data.OwnerCity) then
				new_data.OwningCityName = new_data.OwnerCity:GetName();

				local eDistrictType = plot:GetDistrictType();
				if (eDistrictType) then
					local cityDistricts = new_data.OwnerCity:GetDistricts();
					if (cityDistricts) then
						if (cityDistricts:IsPillaged(eDistrictType)) then
							new_data.DistrictPillaged = true;
						end
					end
				end

				-- GCO <<<<<
				--[[
				-- GCO >>>>>
				local cityBuildings = new_data.OwnerCity:GetBuildings();
				if (cityBuildings) then
					local buildingTypes = cityBuildings:GetBuildingsAtLocation(plotId);
					for _, type in ipairs(buildingTypes) do
						-- GCO <<<<<
						if not GameInfo.Buildings[type].NoCityScreen then
						-- GCO >>>>>
						local building = GameInfo.Buildings[type];
						table.insert(new_data.BuildingTypes, type);
						local name = GameInfo.Buildings[building.BuildingType].Name;
						table.insert(new_data.BuildingNames, name);
						local bPillaged = cityBuildings:IsPillaged(type);
						table.insert(new_data.BuildingsPillaged, bPillaged);
						-- GCO <<<<<
						end
						-- GCO >>>>>
					end
					if (cityBuildings:HasBuilding(plot:GetWonderType())) then
						new_data.WonderComplete = true;
					end
				end
				-- GCO <<<<<
				--]]
				-- GCO >>>>>

				local cityBuildQueue = new_data.OwnerCity:GetBuildQueue();
				if (cityBuildQueue) then
					local constructionTypes = cityBuildQueue:GetConstructionsAtLocation(plotID);
					for _, type in ipairs(constructionTypes) do
						local construction = GameInfo.Buildings[type];
						local name = GameInfo.Buildings[construction.BuildingType].Name;
						table.insert(new_data.Constructions, name);
					end
				end
			end
			if (new_data.IsCity == true or new_data.DistrictID == -1) then
				for row in GameInfo.Yields() do
					local yield = plot:GetYield(row.Index);
					if (yield > 0) then
						new_data.Yields[row.YieldType] = yield;
					end
				end	
			else
				local plotOwner = plot:GetOwner();
				local plotPlayer = Players[plotOwner];
				local district = plotPlayer:GetDistricts():FindID(new_data.DistrictID);

				for row in GameInfo.Yields() do
					local yield = plot:GetYield(row.Index);
					local workers = plot:GetWorkerCount();
					if (yield > 0 and workers > 0) then
						yield = yield * workers;
						new_data.Yields[row.YieldType] = yield;
					end

					local districtYield = district:GetYield(row.Index);
					if (districtYield > 0) then
						new_data.DistrictYields[row.YieldType] = districtYield;
					end

				end									
			end

			View(new_data, bIsUpdate);
		end
	end -- If different plot as last frame
end


-- ===========================================================================
function RealizeNewPlotTooltipMouse( bIsUpdate:boolean )
	local plotId :number = UI.GetCursorPlotID();
	ShowPlotInfo( plotId, bIsUpdate );
	
	RealizePositionAt( UIManager:GetMousePos() );
end

-- ===========================================================================
function RealizeNewPlotTooltipTouch( pInputStruct:table )
	-- Normalized = -1 to 1
	local touchX:number = pInputStruct:GetX();
	local touchY:number = pInputStruct:GetY();
	local normalizedX :number = ((touchX / m_screenWidth) - 0.5) * 2;
	local normalizedY :number = ((1 - (touchY / m_screenHeight)) - 0.5) * 2;	-- also flip axis for Y
	local x:number,y:number = UI.GetPlotCoordFromNormalizedScreenPos(normalizedX, normalizedY);
	local pPlot	:table = Map.GetPlot(x, y);	
	ShowPlotInfo( pPlot:GetIndex() );

	RealizePositionAt(touchX, touchY);
end

-- ===========================================================================
--	Input Processing
-- ===========================================================================
function OnInputHandler( pInputStruct:table )

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
		RealizeNewPlotTooltipMouse();

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
function OnBeginWonderReveal()
	ClearView();
end

-- ===========================================================================
function OnShowLeaderScreen()
	m_isActive = false;
	ClearView();
	m_plotId = -1;
end


-- ===========================================================================
function OnHideLeaderScreen()
	m_isActive = true;
end

-- ===========================================================================
function Resize()
	m_screenWidth, m_screenHeight = UIManager:GetScreenSizeVal();
end


-- ===========================================================================
--	Context CTOR
-- ===========================================================================
function OnInit( isHotload )
	if ( isHotload ) then
		LuaEvents.GameDebug_GetValues( "PlotToolTip");
	end
end

-- ===========================================================================
--	EVENT
-- ===========================================================================
function OnUpdateUI( type:number, tag:string, iData1:number, iData2:number, strData1:string)
	if type == SystemUpdateUI.ScreenResize then
		Resize();
	end
end

-- ===========================================================================
--	Context DESTRUCTOR
-- ===========================================================================
function OnShutdown()
	-- Cache values for hotloading...
	LuaEvents.GameDebug_AddValue("PlotToolTip", "m_isActive", m_isActive );
	TTManager:RemoveToolTipDisplayCallback( OnToolTipShow );
end

-- ===========================================================================
--	LuaEvent Handler
--	Set cached values back after a hotload.
-- ===========================================================================
function OnGameDebugReturn( context:string, contextTable:table )
	if context == "PlotToolTip" then m_isActive	= contextTable["m_isActive"]; end
end

-- ===========================================================================
--	LuaEvent Handler
--	Occurs when a player starts dragging the world map.
-- ===========================================================================
function OnDragMapBegin()
	TooltipOff();
end

-- ===========================================================================
--	LuaEvent Handler
--	Occurs when a player stops dragging the world map or has left the client
--	rectangle of the application.
-- ===========================================================================
function OnDragMapEnd()
	if m_isOff and m_isUsingMouse then
		TooltipOn();	
	end
end

-- ===========================================================================
function OnTouchPlotTooltipShow( touchId:number )
	m_touchIdForPoint = touchId;
	Controls.TooltipMain:SetHide(false);	
end

-- ===========================================================================
function OnTouchPlotTooltipHide()
	m_touchIdForPoint = -1;
	Controls.TooltipMain:SetHide(true);	
end

-- ===========================================================================
--	UI Event
--	Tutorial is requesting the tool tips are turned on.
-- ===========================================================================
function OnTutorialTipsOn()
	m_isActive = true;
	TooltipOn();	
end

-- ===========================================================================
--	UI Event
--	Tutorial is requesting the tool tips are turned off.
function OnTutorialTipsOff()
	m_isActive = false;
	TooltipOff();
end


-- ===========================================================================
--	UI Event
--	Raised when ANY tooltip being raised.
--
--	Handles case where a tool tip start to raise and then the cursor moved 
--	over a piece of 2D UI.
-- ===========================================================================
function OnToolTipShow( pToolTip:table )
	Controls.TooltipMain:SetHide(true);		
end

-- ===========================================================================
function Initialize()

	if m_isForceOff or Benchmark.IsEnabled() then
		return;
	end

	m_isShowDebug = (Options.GetAppOption("Debug", "EnableDebugPlotInfo") == 1);
	
	m_isActive = true;
	m_lastMouseMoveTime = nil;

	Resize();

	-- Context Events
	ContextPtr:SetInitHandler( OnInit );
	ContextPtr:SetInputHandler( OnInputHandler, true );
	ContextPtr:SetShutdown( OnShutdown );
	TTManager:AddToolTipDisplayCallback( OnToolTipShow );
	
	-- Game Core Events	
	Events.BeginWonderReveal.Add( OnBeginWonderReveal );
	Events.HideLeaderScreen.Add( OnHideLeaderScreen );	
	Events.ShowLeaderScreen.Add( OnShowLeaderScreen );
	Events.SystemUpdateUI.Add( OnUpdateUI );
	
	-- LUA Events
	LuaEvents.GameDebug_Return.Add( OnGameDebugReturn );			-- hotloading help
	LuaEvents.Tutorial_PlotToolTipsOn.Add( OnTutorialTipsOn );
	LuaEvents.Tutorial_PlotToolTipsOff.Add( OnTutorialTipsOff );
	LuaEvents.WorldInput_DragMapBegin.Add( OnDragMapBegin );
	LuaEvents.WorldInput_DragMapEnd.Add( OnDragMapEnd );
	LuaEvents.WorldInput_TouchPlotTooltipShow.Add( OnTouchPlotTooltipShow );
	LuaEvents.WorldInput_TouchPlotTooltipHide.Add( OnTouchPlotTooltipHide );
	LuaEvents.PlotInfo_UpdatePlotTooltip.Add( RealizeNewPlotTooltipMouse );
end
Initialize();
