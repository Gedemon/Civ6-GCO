--=====================================================================================--
--	FILE:	 VisualizerScript.lua
--  Gedemon (2020)
--=====================================================================================--

print("Loading VisualizerScript.lua...")

include( "GCO_TypeEnum" )
include( "GCO_SmallUtils" )

-- ===========================================================================
-- Defines
-- ===========================================================================

local DistrictAssetID 	= {}	-- to get a district asset ID from its Type Name 
local PlacedDistrict 	= {}	-- districs position per cities

local ArtEraToGameEra	= {
	ANC = "ERA_ANCIENT",
	CLA = "ERA_CLASSICAL",
	IND = "ERA_INDUSTRIAL",
	MOD = "ERA_MODERN"
	}

function SetDistrictID()
	local nDistricts = AssetPreview.GetDistrictCount()
	if ( nDistricts > 0 ) then
		for i = 0, nDistricts-1, 1 do
			DistrictAssetID[AssetPreview.GetDistrictName(i)]= i
		end
	end
end

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
	--
	PostInitialize()
end
GameEvents.InitializeGCO.Add( InitializeUtilityFunctions )

function PostInitialize() -- everything that may require other context to be loaded first
	SetDistrictID()

end


-- ===========================================================================
-- Functions
-- ===========================================================================

-- see LandmarkVisualizer.ltp

-- AssetPreview.GetDistrictName(4)
-- tDistrictBases = AssetPreview.GetDistrictBaseList(4)
-- prop = tDistrictBases["DIS_HBR_Base_Modern_01"]
-- AssetPreview.SpoofDistrictBaseAt( 37, 17, prop.civ, prop.era, prop.appeal, 0, "Worked", 4, prop.index )

--AssetPreview.CreateDistrictAt(startx + x, y, g_SelectedCiv, eraidx, g_SelectedAppeal, g_SelectedPopulation, "Worked", g_SelectedDistrictIdx);
-- 
--[[
function()
	local listItems = {};
	local nDistricts = AssetPreview.GetDistrictCount();
	if ( nDistricts > 0 ) then
		for i = 0, nDistricts-1, 1 do
			table.insert( listItems, {
				Text = string.gsub( AssetPreview.GetDistrictName(i), "DISTRICT_", "" ),
				Selected = (g_SelectedDistrictIdx == i)
			} );
		end
	end
	return listItems;
end
--]]

function SetCityLandmarks(playerID, cityID)
	local city 				= CityManager.GetCity(playerID, cityID)	
	local cityKey 			= GetKeyFromIDs(playerID, cityID)
	PlacedDistrict[cityKey] = PlacedDistrict[cityKey] or {}
	if city:GetBuildings():HasBuilding(GameInfo.Buildings["BUILDING_CITY_SHIPYARD"].Index) then
		print("Set Harbor District for ".. Locale.Lookup(city:GetName()))
		local pPlot		= nil
		local assetID 	= DistrictAssetID["DISTRICT_HARBOR"]--DISTRICT_HARBOR
		if PlacedDistrict[cityKey][assetID] then
			pPlot = Map.GetPlotByIndex(PlacedDistrict[cityKey][assetID])
			if pPlot then
				print(" - Already placed at ", pPlot:GetX(), pPlot:GetY())
			end
		end
		if pPlot == nil then
			local tBases 	= AssetPreview.GetDistrictBaseList(assetID)
			local props		= tBases["DIS_HBR_Base_Classical_01"] -- DIS_HBR_Base_Modern_01, DIS_HBR_Base_Classical_01
			local iX, iY	= city:GetX(), city:GetY()
			local bestArea	= 0
			for direction = 0, DirectionTypes.NUM_DIRECTION_TYPES - 1, 1 do
				local adjacentPlot 	= Map.GetAdjacentPlot(iX, iY, direction)
				if adjacentPlot and adjacentPlot:IsWater() then
					local areaSize = adjacentPlot:GetArea():GetPlotCount()
					if (areaSize > bestArea) or (adjacentPlot:GetResourceCount() == 0 and areaSize >= bestArea) then
						pPlot = adjacentPlot
						bestArea = areaSize
					end
				end
			end
			if pPlot then
				--local t = AssetPreview.SpoofDistrictBaseAt( pPlot:GetX(), pPlot:GetY(), props.civ, props.era, props.appeal, 0, "Worked", assetID, props.index )
				print( pPlot:GetX(), pPlot:GetY(), tBases, props, AssetPreview, AssetPreview.CreateDistrictAt, 0, "Worked", assetID)
				local t = AssetPreview.CreateDistrictAt( pPlot:GetX(), pPlot:GetY(), props.civ, 0, props.appeal, 0, "Worked", assetID)
				print(t)
			else
				print("Warning, can't find position to spoof Harbor District for ".. Locale.Lookup(city:GetName()))
			end
		end
	end
end

function RemoveCityLandmarks(playerID, cityID)

	local cityKey = GetKeyFromIDs(playerID, cityID)
	if PlacedDistrict[cityKey] then
		for i, row in ipairs(PlacedDistrict[cityKey]) do
			local plotID 	= row[2]
			local pPlot		= Map.GetPlotByIndex(plotID)
			AssetPreview.ClearLandmarkAt(pPlot:GetX(), pPlot:GetY())
		end
	end
end


-- ===========================================================================
-- Events
-- ===========================================================================

function OnCityProductionCompleted(playerID, cityID, productionID, objectID, bCanceled, typeModifier)

	if productionID == ProductionTypes.BUILDING then
		if GameInfo.Buildings[objectID] and GameInfo.Buildings[objectID].Unlockers then return end
		
		-- update landmarks
		SetCityLandmarks(playerID, cityID)
	end
end
Events.CityProductionCompleted.Add(OnCityProductionCompleted)

function OnCityAddedToMap(playerID, cityID)
	SetCityLandmarks(playerID, cityID)
end
Events.CityAddedToMap.Add(OnCityAddedToMap)

function OnCityRemovedFromMap(playerID, cityID)

	RemoveCityLandmarks(playerID, cityID)
end
Events.CityRemovedFromMap.Add(OnCityRemovedFromMap)

function OnCapturedCityInitialized(originalOwnerID, originalCityID, newOwnerID, newCityID, iX, iY)
	RemoveCityLandmarks(originalOwnerID, originalCityID)
	SetCityLandmarks(newOwnerID, newCityID)
end
GameEvents.CapturedCityInitialized.Add( OnCapturedCityInitialized )

-- ===========================================================================
-- Initialize functions for other contexts
-- ===========================================================================
function Initialize()

	-- Set shared table
	if not ExposedMembers.GCO then ExposedMembers.GCO = {} end	
	
	-- AssetPreview
	--ExposedMembers.GCO.AssetPreview					= AssetPreview
end
Initialize()


