--=====================================================================================--
--	FILE:	 VisualizerScript.lua
--  Gedemon (2020)
--=====================================================================================--

print("Loading VisualizerScript.lua...")

include( "GCO_TypeEnum" )
include( "GCO_SmallUtils" )

-- =========================================================================== --
-- Defines
-- =========================================================================== --

local cityShipYardID 	= GameInfo.Buildings["BUILDING_CITY_SHIPYARD"].Index
local cityHarbordID 	= GameInfo.Buildings["BUILDING_CITY_HARBOR"].Index
local shipYardID 		= GameInfo.Buildings["BUILDING_SHIPYARD"].Index
local seaportID 		= GameInfo.Buildings["BUILDING_SEAPORT"].Index
local lighthoutseID		= GameInfo.Buildings["BUILDING_LIGHTHOUSE"].Index
local ancientWallID		= GameInfo.Buildings["BUILDING_WALLS"].Index


-- =========================================================================== --
-- Helpers
-- =========================================================================== --

DistrictAssetID = {}	-- to get a district asset ID from its Type Name 
PlacedDistrict 	= {}	-- districs position per cities

ArtEraToGameEra	= {
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

function HasTwoAdjacentLandPlots(iX, iY)
	local bIsPreviousLand = false
	local bIsFirstDirLand = nil
	for direction = 0, DirectionTypes.NUM_DIRECTION_TYPES - 1, 1 do
		local adjacentPlot 	= Map.GetAdjacentPlot(iX, iY, direction)
		if adjacentPlot then
			if bIsFirstDirLand == nil then -- mark the first plot to test with last plot
				bIsFirstDirLand = not adjacentPlot:IsWater()
			end
			if not adjacentPlot:IsWater() then -- land plot
				if bIsPreviousLand then
					return true	-- we've found 2 consecutive land plots
				else
					bIsPreviousLand = true
				end
			else
				bIsPreviousLand = false
			end
		end
	end
	return (bIsPreviousLand and bIsFirstDirLand) -- check first and last tested plot
end

-- =========================================================================== --
-- Initialize
-- =========================================================================== --
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


-- =========================================================================== --
-- Functions
-- =========================================================================== --

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

function SetFakeCity(iX, iY, civType, eraType, iPopulation, bHasWall, sState)

	local pLocalPlayerVis 	= PlayerVisibilityManager.GetPlayerVisibility(Game.GetLocalObserver())
	if not pLocalPlayerVis:IsVisible(iX, iY) then
		return
	end
	
	RemoveLandmarkAt(iX, iY)
	
	local civHash		= GameInfo.Civilizations[civType] and GameInfo.Civilizations[civType].Hash
	local eraID			= GameInfo.Eras[eraType] and GameInfo.Eras[eraType].Index or 0
	local sState		= sState or "Worked" -- "Pillaged"
	local iPopulation	= iPopulation or 1
	local pPlot			= Map.GetPlot(iX, iY)
	local assetID 		= DistrictAssetID["DISTRICT_CITY_CENTER"]
	local tBases 		= AssetPreview.GetDistrictBaseList(assetID)
	local props			= tBases["DIS_CTY_EmptyCity_Base"]
	
	print( iX, iY, civHash or props.civ, eraID, props.appeal, iPopulation, sState, assetID)
	AssetPreview.CreateDistrictAt( iX, iY, civHash or props.civ, eraID, props.appeal, iPopulation, sState, assetID)
	
	if bHasWall then
		AssetPreview.CreateBuildingAt(iX, iY, "Worked", ancientWallID);
	end
	--ancientWallID
end

function RemoveLandmarkAt(iX, iY)
	AssetPreview.ClearLandmarkAt(iX, iY)
end

function SetCityLandmarks(playerID, cityID, bNoRefresh)
	local bForceRefresh		= not bNoRefresh
	local city 				= CityManager.GetCity(playerID, cityID)
	local pLocalPlayerVis 	= PlayerVisibilityManager.GetPlayerVisibility(Game.GetLocalObserver())
	
	if not pLocalPlayerVis:IsVisible(city:GetX(), city:GetY()) then
		return
	end
	
	local cityKey 			= GetKeyFromIDs(playerID, cityID)
	PlacedDistrict[cityKey] = PlacedDistrict[cityKey] or {}
	local pBuildings		= city:GetBuildings()
	if pBuildings:HasBuilding(cityShipYardID) or pBuildings:HasBuilding(cityHarbordID) or pBuildings:HasBuilding(shipYardID) then
		print("Set Harbor District for ".. Locale.Lookup(city:GetName()))
		local pPlot		= nil
		local assetID 	= DistrictAssetID["DISTRICT_HARBOR"]--DISTRICT_HARBOR
		if PlacedDistrict[cityKey][assetID] then
			pPlot = Map.GetPlotByIndex(PlacedDistrict[cityKey][assetID])
			if pPlot then
				print(" - Already placed at ", pPlot:GetX(), pPlot:GetY())
			end
		end
		if pPlot == nil or bForceRefresh then
		
			local tBases 	= AssetPreview.GetDistrictBaseList(assetID)
			local props		= pBuildings:HasBuilding(seaportID) and tBases["DIS_HBR_Base_Modern_01"] or tBases["DIS_HBR_Base_Classical_01"] -- DIS_HBR_Base_Modern_01, DIS_HBR_Base_Classical_01
			local iX, iY	= city:GetX(), city:GetY()
			local bestScore	= 0
			for direction = 0, DirectionTypes.NUM_DIRECTION_TYPES - 1, 1 do
				local adjacentPlot 	= Map.GetAdjacentPlot(iX, iY, direction)
				if adjacentPlot and adjacentPlot:IsWater() then
					local areaSize 	= adjacentPlot:GetArea():GetPlotCount()
					local score 	= areaSize + (HasTwoAdjacentLandPlots(adjacentPlot:GetX(), adjacentPlot:GetY()) and 5 or -1) - adjacentPlot:GetResourceCount() 
					if (score > bestScore)  then
						pPlot = adjacentPlot
						bestScore = score
					end
				end
			end
			if pPlot then
			
				AssetPreview.ClearLandmarkAt(pPlot:GetX(), pPlot:GetY())
				
				--local t = AssetPreview.SpoofDistrictBaseAt( pPlot:GetX(), pPlot:GetY(), props.civ, props.era, props.appeal, 0, "Worked", assetID, props.index )
				--print( pPlot:GetX(), pPlot:GetY(), tBases, props, AssetPreview, AssetPreview.CreateDistrictAt, 0, "Worked", assetID)
				AssetPreview.CreateDistrictAt( pPlot:GetX(), pPlot:GetY(), props.civ, 0, props.appeal, 0, "Worked", assetID) -- "Construction", "Pillaged"
				if city:GetBuildings():HasBuilding(lighthoutseID) then
					print("  - Adding Lighthouse")
					AssetPreview.CreateBuildingAt(pPlot:GetX(), pPlot:GetY(), "Worked", lighthoutseID);
				end
				if city:GetBuildings():HasBuilding(cityShipYardID) or city:GetBuildings():HasBuilding(shipYardID) then
					print("  - Adding Shipyard")
					AssetPreview.CreateBuildingAt(pPlot:GetX(), pPlot:GetY(), "Worked", shipYardID);
				end
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


-- =========================================================================== --
-- Events
-- =========================================================================== --

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

function OnCityVisibilityChanged(playerID: number, cityID : number, eVisibility : number)

	if (visibilityType == RevealedState.HIDDEN) then
		RemoveCityLandmarks(playerID, cityID)
	else		
		if (visibilityType == RevealedState.REVEALED) then
			RemoveCityLandmarks(playerID, cityID)
		else
			if (visibilityType == RevealedState.VISIBLE) then
				SetCityLandmarks(playerID, cityID)
			end
		end
	end
end
Events.CityVisibilityChanged.Add( OnCityVisibilityChanged )


-- =========================================================================== --
-- Initialize functions for other contexts
-- =========================================================================== --
function Initialize()

	-- Set shared table
	if not ExposedMembers.GCO then ExposedMembers.GCO = {} end	
	
	-- AssetPreview
	--ExposedMembers.GCO.AssetPreview					= AssetPreview
end
Initialize()


