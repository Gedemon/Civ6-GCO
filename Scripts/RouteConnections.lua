--
-- RouteConnections.lua
--
-- Copyright 2011  (c)  William Howard
--
-- Determines if a route exists between two plots/cities
--
-- Permission granted to re-distribute this file as part of a mod
-- on the condition that this comment block is preserved in its entirity
--

-- Partially converted to civ6 by Gedemon (don't use "Road" or "Railroad")

print("Loading RouteConnections.lua.")

-------------------------------------------------------------------------------------------
-- FLuaVector
-------------------------------------------------------------------------------------------
function Vector2( i, j )       return { x = i, y = j }; end
function Vector3( i, j, k )    return { x = i, y = j, z = k }; end
function Vector4( i, j, k, l ) return { x = i, y = j, z = k, w = l }; end
function Color( r, g, b, a )   return Vector4( r, g, b, a ); end

function VecAdd( v1, v2 ) 
    temp = {};
    if( v1.x ~= nil and v2.x ~= nil ) then temp.x = v1.x + v2.x; end
    if( v1.y ~= nil and v2.y ~= nil ) then temp.y = v1.y + v2.y; end
    if( v1.z ~= nil and v2.z ~= nil ) then temp.z = v1.z + v2.z; end
    if( v1.w ~= nil and v2.w ~= nil ) then temp.w = v1.w + v2.w; end
    return temp;
end

function VecSubtract( v1, v2 ) 
    temp = {};
    if( v1.x ~= nil and v2.x ~= nil ) then temp.x = v1.x - v2.x; end
    if( v1.y ~= nil and v2.y ~= nil ) then temp.y = v1.y - v2.y; end
    if( v1.z ~= nil and v2.z ~= nil ) then temp.z = v1.z - v2.z; end
    if( v1.w ~= nil and v2.w ~= nil ) then temp.w = v1.w - v2.w; end
    return temp;
end


-------------------------------------------------------------------------------------------
-- Hex Coordinate (thx astog)
-- https://forums.civfanatics.com/threads/using-whowards-border-and-plot-iterators-in-civ-6.607334/
-------------------------------------------------------------------------------------------

function ToHexFromGrid(grid)
    local hex = {
        x = grid.x - (grid.y - (grid.y % 2)) / 2;
        y = grid.y;
    }
    return hex
end

function ToGridFromHex(hex_x, hex_y)
    local grid = {
        x = hex_x + (hex_y - (hex_y % 2)) / 2;
        y = hex_y;
    }
    return grid.x, grid.y
end

-------------------------------------------------------------------------------------------

----- PUBLIC METHODS -----

-- Array of route types - you can change the text, but NOT the order
routes = {"Land", "Road", "Railroad", "Coastal", "Ocean", "Submarine", "River"}

-- Array of highlight colours
highlights = { Red     = Vector4(1.0, 0.0, 0.0, 1.0), 
               Green   = Vector4(0.0, 1.0, 0.0, 1.0), 
               Blue    = Vector4(0.0, 0.0, 1.0, 1.0),
               Cyan    = Vector4(0.0, 1.0, 1.0, 1.0),
               Yellow  = Vector4(1.0, 1.0, 0.0 ,1.0),
               Magenta = Vector4(1.0, 0.0, 1.0, 1.0),
               Black   = Vector4(0.5, 0.5, 0.5, 1.0)}             

--
-- pPlayer                 - player object (not ID) or nil
-- pStartCity, pTargetCity - city objects (not IDs)
-- pStartPlot, pTargetPlot - plot objects (not IDs)
-- sRoute                  - one of routes (see above)
-- bShortestRoute          - true to find the shortest route
-- sHighlight              - one of the highlight keys (see above)
-- fBlockaded              - call-back function of the form f(pPlot, pPlayer) to determine if a plot is blocked for this player (return true if blocked)
--

function isCityConnected(pPlayer, pStartCity, pTargetCity, sRoute, bShortestRoute, sHighlight, fBlockaded)
  return isPlotConnected(pPlayer, pStartCity:Plot(), pTargetCity:Plot(), sRoute, bShortestRoute, sHighlight, fBlockaded)
end

function isPlotConnected(pPlayer, pStartPlot, pTargetPlot, sRoute, bShortestRoute, sHighlight, fBlockaded)
  if (bShortestRoute) then
    lastRouteLength = plotToPlotShortestRoute(pPlayer, pStartPlot, pTargetPlot, sRoute, highlights[sHighlight], fBlockaded)
  else
    lastRouteLength = plotToPlotConnection(pPlayer, pStartPlot, pTargetPlot, sRoute, 1, highlights[sHighlight], listAddPlot(pStartPlot, {}), fBlockaded)
  end

  return (lastRouteLength ~= 0)
end

function getRouteLength()
  return lastRouteLength - 1
end

function getDistance(pPlot1, pPlot2)
  return distanceBetween(pPlot1, pPlot2)
end

function getPathPlots()
  return pathPlots
end

----- PRIVATE DATA AND METHODS -----

lastRouteLength = 0
pathPlots 		= {}
g_FEATURE_ICE 	= GameInfo.Features["FEATURE_ICE"].Index
g_TERRAIN_COAST = GameInfo.Terrains["TERRAIN_COAST"].Index

--
-- Check if pStartPlot is connected to pTargetPlot
--
-- NOTE: This is a recursive method
--
-- Returns the length of the route between the start and target plots (inclusive) - so 0 if no route
--

function plotToPlotConnection(pPlayer, pStartPlot, pTargetPlot, sRoute, iLength, highlight, listVisitedPlots, fBlockaded)
  if (highlight ~= nil) then
    Events.SerialEventHexHighlight(PlotToHex(pStartPlot), true, highlight)
  end

  -- Have we got there yet?
  if (isSamePlot(pStartPlot, pTargetPlot)) then
    return iLength
  end

  -- Find any new plots we can visit from here
  local listRoutes = listFilter(reachablePlots(pPlayer, pStartPlot, sRoute, fBlockaded), listVisitedPlots)

  -- New routes to check, so there is an onward path
  if (listRoutes ~= nil) then
    -- Covert the associative array into a linear array so it can be sorted
    local array = {}
    for sId, pPlot in pairs(listRoutes) do
      table.insert(array, pPlot)
    end

    -- Now sort the linear array by distance from the target plot
    table.sort(array, function(x, y) return (distanceBetween(x, pTargetPlot) < distanceBetween(y, pTargetPlot)) end)

    -- Now check each onward plot in turn to see if that is connected
    for i, pPlot in ipairs(array) do
      -- Check that a prior route didn't visit this plot
      if (not listContainsPlot(pPlot, listVisitedPlots)) then
        -- Add this plot to the list of visited plots
        listAddPlot(pPlot, listVisitedPlots)

        -- If there's a route, we're done
        local iLen = plotToPlotConnection(pPlayer, pPlot, pTargetPlot, sRoute, iLength+1, highlight, listVisitedPlots, fBlockaded)
        if (iLen > 0) then
          return iLen
        end
      end
    end
  end

  if (highlight ~= nil) then
    Events.SerialEventHexHighlight(PlotToHex(pStartPlot), false)
  end

  -- No connection found
  return 0
end


--
-- Find the shortest route between two plots
--
-- We start at the TARGET plot - as the path length from here to the target plot is 1,
-- we will call this "ring 1".  We then find all reachable adjacent plots and place them in "ring 2".
-- If the START plot is in "ring 2", we have a route, if "ring 2" is empty, there is no route,
-- otherwise find all reachable adjacent plots that have not already been seen and place those in "ring 3"
-- We then loop, checking "ring N" otherwise generating "ring N+1"
--
-- Once we have found a route, the path length will be of length N and we know that there must be at 
-- least one route by picking a plot from each ring.  The plot needed from "ring N" is the START plot,
-- we then need ANY plot from "ring N-1" that is adjacent to the start plot. And in general we need 
-- any plot from "ring M-1" that is adjacent to the plot choosen from "ring M".  The final plot in 
-- the path will always be the target plot as that is the only plot in "ring 1"
--
-- Returns the length of the route between the start and target plots (inclusive) - so 0 if no route
--

function plotToPlotShortestRoute(pPlayer, pStartPlot, pTargetPlot, sRoute, highlight, fBlockaded)
  local rings = {}

  local iRing = 1
  rings[iRing] = listAddPlot(pTargetPlot, {})

  repeat
    iRing = generateNextRing(pPlayer, sRoute, rings, iRing, fBlockaded)

    bFound = listContainsPlot(pStartPlot, rings[iRing])
    bNoRoute = (rings[iRing] == nil)
  until (bFound or bNoRoute)

  if (bFound) then-- and highlight ~= nil) then
    --Events.SerialEventHexHighlight(PlotToHex(pStartPlot), true, highlight)
	pathPlots = {}
	table.insert(pathPlots, pStartPlot:GetIndex())

    local pLastPlot = pStartPlot

    for i = iRing - 1, 1, -1 do
      pNextPlot = listFirstAdjacentPlot(pLastPlot, rings[i])
      
      -- Check should be completely unnecessary
      if (pNextPlot == nil) then
        return 0
      end

      --Events.SerialEventHexHighlight(PlotToHex(pNextPlot), true, highlight)
	  table.insert(pathPlots, pNextPlot:GetIndex())

      pLastPlot = pNextPlot
    end
  end  
  
  return (bFound) and iRing or 0
end

-- Helper method to find all plots adjacent to the plots in the specified ring
function generateNextRing(pPlayer, sRoute, rings, iRing, fBlockaded)
  local nextRing = nil

  for k, pPlot in pairs(rings[iRing]) do
    local listRoutes = listsFilter(reachablePlots(pPlayer, pPlot, sRoute, fBlockaded), rings)

    if (listRoutes ~= nil) then
      for sId, pPlot in pairs(listRoutes) do
        nextRing = nextRing or {}
        listAddPlot(pPlot, nextRing)
      end
    end
  end

  rings[iRing+1] = nextRing

  return iRing+1
end


--
-- Methods dealing with finding all adjacent tiles that can be reached by the specified route type
--

-- Array of directions, since changing to proximity based decision making, the order is not important
directions = {DirectionTypes.DIRECTION_NORTHEAST, DirectionTypes.DIRECTION_EAST, DirectionTypes.DIRECTION_SOUTHEAST,
              DirectionTypes.DIRECTION_SOUTHWEST, DirectionTypes.DIRECTION_WEST, DirectionTypes.DIRECTION_NORTHWEST}			  
			  
opposed = {
	[DirectionTypes.DIRECTION_NORTHEAST] 	= DirectionTypes.DIRECTION_SOUTHWEST,
	[DirectionTypes.DIRECTION_EAST] 		= DirectionTypes.DIRECTION_WEST,
	[DirectionTypes.DIRECTION_SOUTHEAST] 	= DirectionTypes.DIRECTION_NORTHWEST,
    [DirectionTypes.DIRECTION_SOUTHWEST] 	= DirectionTypes.DIRECTION_NORTHEAST,
	[DirectionTypes.DIRECTION_WEST] 		= DirectionTypes.DIRECTION_EAST,
	[DirectionTypes.DIRECTION_NORTHWEST] 	= DirectionTypes.DIRECTION_SOUTHEAST
	}

-- Return a list of (up to 6) reachable plots from this one by route type
function reachablePlots(pPlayer, pPlot, sRoute, fBlockaded)
  local list = nil

  for loop, direction in ipairs(directions) do
    local pDestPlot = Map.GetAdjacentPlot(pPlot:GetX(), pPlot:GetY(), direction)

    -- Don't let submarines fall over the edge!
    if (pDestPlot ~= nil) then
	  local IsPlotRevealed = false
	  local pPlayerVis = PlayersVisibility[pPlayer:GetID()]
	  if (pPlayerVis ~= nil) then
	  	if (pPlayerVis:IsRevealed(pDestPlot:GetX(), pDestPlot:GetY())) then -- IsVisible
	  	  IsPlotRevealed = true
	  	end
	  end	
	
      if (pPlayer == nil or IsPlotRevealed) then
        local bAdd = false

        -- Be careful of order, must check for road before rail, and coastal before ocean
        if (sRoute == routes[1] and not( pDestPlot:IsImpassable() or pDestPlot:IsWater())) then
          bAdd = true
        elseif (sRoute == routes[2] and pDestPlot:GetRouteType() ~= RouteTypes.NONE) then --and pDestPlot:GetRouteType() >= 0) then 		
          bAdd = true
        elseif (sRoute == routes[3] and pDestPlot:GetRouteType() >= 1) then
          bAdd = true
        elseif (sRoute == routes[4] and pDestPlot:GetTerrainType() == g_TERRAIN_COAST) then
          bAdd = true
        elseif (sRoute == routes[5] and pDestPlot:IsWater()) then
          bAdd = true
        elseif (sRoute == routes[6] and pDestPlot:IsWater()) then
          bAdd = true
        elseif (sRoute == routes[7] and (pDestPlot:IsRiverConnection(direction) or pDestPlot:IsRiverConnection(opposed[direction])) ) then -- to do allows only descending = IsRiverConnection(direction) until specific technologie...
          bAdd = true
        end

        -- Special case for water, a city on the coast counts as water
        if (not bAdd and (sRoute == routes[4] or sRoute == routes[5] or sRoute == routes[6])) then
          bAdd = pDestPlot:IsCity()
        end

        -- Check for impassable and blockaded tiles
        bAdd = bAdd and isPassable(pDestPlot, sRoute) and not isBlockaded(pDestPlot, pPlayer, fBlockaded, pPlot)

        if (bAdd) then
          list = list or {}
          listAddPlot(pDestPlot, list)
        end
      end
    end
  end

  return list
end

-- Is the plot passable for this route type ...
function isPassable(pPlot, sRoute)
  bPassable = true

  -- ... due to terrain, eg those covered in ice
  if (pPlot:GetFeatureType() == g_FEATURE_ICE and sRoute ~= routes[6]) then
    bPassable = false
  end

  return bPassable
end

-- Is the plot blockaded for this player ...
function isBlockaded(pDestPlot, pPlayer, fBlockaded, pOriginPlot)
  bBlockaded = false

  if (fBlockaded ~= nil) then
    bBlockaded = fBlockaded(pDestPlot, pPlayer, pOriginPlot)
  end

  return bBlockaded
end



--
-- Calculate the distance between two plots
--
-- See http://www-cs-students.stanford.edu/~amitp/Articles/HexLOS.html
-- Also http://keekerdc.com/2011/03/hexagon-grids-coordinate-systems-and-distance-calculations/
--
function distanceBetween(pPlot1, pPlot2)
 -- should use game function
 --return Map.GetPlotDistance(pPlot1:GetX(), pPlot1:GetY(), pPlot2:GetX(), pPlot2:GetY())  

 -- --[[
  local mapX, mapY = Map.GetGridSize()

  -- Need to work on a hex based grid
  local hex1 = PlotToHex(pPlot1)
  local hex2 = PlotToHex(pPlot2)

  -- Calculate the distance between the x and z co-ordinate pairs
  -- allowing for the East-West wrap, (ie shortest route may be by going backwards!)
  local deltaX = math.min(math.abs(hex2.x - hex1.x), mapX - math.abs(hex2.x - hex1.x))
  local deltaZ = math.min(math.abs(hex2.z - hex1.z), mapX - math.abs(hex2.z - hex1.z))

  -- Calculate the distance between the y co-ordinates
  -- there is no North-South wrap, so this is easy
  local deltaY = math.abs(hex2.y - hex1.y)

  -- Calculate the distance between the plots
  local distance = math.max(deltaX, deltaY, deltaZ)

  -- Allow for both end points in the distance calculation
  return distance + 1
   --]]
end

-- Get the hex co-ordinates of a plot
function PlotToHex(pPlot)
  local hex = ToHexFromGrid(Vector2(pPlot:GetX(), pPlot:GetY()))

  -- X + y + z = 0, hence z = -(x+y)
  hex.z = -(hex.x + hex.y)

  return hex
end


--
-- List (associative arrays) helper methods
--

-- Return a list formed by removing all entries from list1 which are in list2
function listFilter(list1, list2)
  local list = nil

  if (list1 ~= nil) then
    for sKey, pPlot in pairs(list1) do
      if (list2 == nil or list2[sKey] == nil) then
        list = list or {}
        list[sKey] = pPlot
      end
    end
  end

  return list
end

-- Return a list formed by removing all entries from list which are in any of the individual lists in lists
function listsFilter(list, lists)
  for i = #lists, 1, -1 do
    list = listFilter(list, lists[i])

    if (list == nil) then break end
  end

  return list
end

-- Return true if pPlot is in list
function listContainsPlot(pPlot, list)
  return (list ~= nil and list[getPlotKey(pPlot)] ~= nil)
end

-- Add the plot to the list
function listAddPlot(pPlot, list)
  if (list ~= nil) then
    list[getPlotKey(pPlot)] = pPlot
  end

  return list
end

function listFirstAdjacentPlot(pPlot, list)
  for key, plot in pairs(list) do
    if (distanceBetween(pPlot, plot) == 2) then
      return plot
    end
  end

  -- We should NEVER reach here
  return nil
end


--
-- Plot helper methods
--

-- Are the plots one and the same?
function isSamePlot(pPlot1, pPlot2)
  return (pPlot1:GetX() == pPlot2:GetX() and pPlot1:GetY() == pPlot2:GetY())
end

-- Get a unique key for the plot
function getPlotKey(pPlot)
  return string.format("%d:%d", pPlot:GetX(), pPlot:GetY())
end

-- Get the grid-based (x, y) co-ordinates of the plot as a string
function plotToGridStr(pPlot)
  if (pPlot == nil) then return "" end

  return string.format("(%d, %d)", pPlot:GetX(), pPlot:GetY())
end

-- Get the hex-based (x, y, z) co-ordinates of the plot as a string
function plotToHexStr(pPlot)
  if (pPlot == nil) then return "" end

  local hex = PlotToHex(pPlot)

  return string.format("(%d, %d, %d)", hex.x, hex.y, hex.z)
end

----------------------------------------------
-- Initialize functions for other contexts
----------------------------------------------

ExposedMembers.RouteConnections_Initialized = false

function Initialize()
	if not ExposedMembers.GCO then ExposedMembers.GCO = {} end
		
	-- Route Connections
	ExposedMembers.GCO.IsCityConnected 				= isCityConnected
	ExposedMembers.GCO.IsPlotConnected 				= isPlotConnected
	ExposedMembers.GCO.GetRouteLength 				= getRouteLength
	ExposedMembers.GCO.GetRoutePlots 				= getPathPlots
	ExposedMembers.RouteConnections_Initialized		= true
end
Initialize()
