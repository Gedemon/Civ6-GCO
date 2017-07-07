--=====================================================================================--
--	FILE:	 PlotScript.lua
--  Gedemon (2017)
--=====================================================================================--

print ("Loading PlotScript.lua...")

-----------------------------------------------------------------------------------------
-- Defines
-----------------------------------------------------------------------------------------
local SEPARATIST_PLAYER 			= "64" -- use string for table keys for correct serialisation/deserialisation
local NO_IMPROVEMENT 				= -1
local NO_FEATURE	 				= -1
local NO_OWNER 						= -1
local iDiffusionRatePer1000 		= 1
local iRoadMax		 				= tonumber(GameInfo.GlobalParameters["CULTURE_FOLLOW_ROAD_MAX"].Value)
local iRoadBonus	 				= tonumber(GameInfo.GlobalParameters["CULTURE_FOLLOW_ROAD_BONUS"].Value)
local iFollowingRiverMax 			= tonumber(GameInfo.GlobalParameters["CULTURE_FOLLOW_RIVER_MAX"].Value)
local iFollowingRiverBonus			= tonumber(GameInfo.GlobalParameters["CULTURE_FOLLOW_RIVER_BONUS"].Value)
local iCrossingRiverMax 			= tonumber(GameInfo.GlobalParameters["CULTURE_CROSS_RIVER_MAX"].Value)
local iCrossingRiverPenalty			= tonumber(GameInfo.GlobalParameters["CULTURE_CROSS_RIVER_PENALTY"].Value)
local iCrossingRiverThreshold		= tonumber(GameInfo.GlobalParameters["CULTURE_CROSS_RIVER_THRESHOLD"].Value)
local iBaseThreshold 				= tonumber(GameInfo.GlobalParameters["CULTURE_DIFFUSION_THRESHOLD"].Value)

-----------------------------------------------------------------------------------------
-- Debug
-----------------------------------------------------------------------------------------

DEBUG_PLOT_SCRIPT			= false

-----------------------------------------------------------------------------------------
-- Initialize
-----------------------------------------------------------------------------------------
local GCO = {}
function InitializeUtilityFunctions() 	-- Get functions from other contexts
	GCO = ExposedMembers.GCO
	Dprint 	= GCO.Dprint
	print ("Exposed Functions from other contexts initialized...")
	PostInitialize()
end
LuaEvents.InitializeGCO.Add( InitializeUtilityFunctions )

function SaveTables()
	print("--------------------------- Saving CultureMap ---------------------------")	
	GCO.StartTimer("Saving And Checking CultureMap")
	GCO.SaveTableToSlot(ExposedMembers.CultureMap, "CultureMap")
	GCO.SaveTableToSlot(ExposedMembers.PreviousCultureMap, "PreviousCultureMap")
end
LuaEvents.SaveTables.Add(SaveTables)

function CheckSave()
	print("Checking Saved Table...")
	if GCO.AreSameTables(ExposedMembers.CultureMap, GCO.LoadTableFromSlot("CultureMap")) then
		print("- Tables are identical")
	else
		GCO.Error("reloading saved CultureMap table show differences with actual table !")
		CompareData(ExposedMembers.CultureMap, GCO.LoadTableFromSlot("CultureMap"))
	end
	
	if GCO.AreSameTables(ExposedMembers.PreviousCultureMap, GCO.LoadTableFromSlot("PreviousCultureMap")) then
		print("- Tables are identical")
	else
		GCO.Error("reloading saved PreviousCultureMap table show differences with actual table !")
		LuaEvents.StopAuToPlay()
		CompareData(ExposedMembers.CultureMap, GCO.LoadTableFromSlot("CultureMap"))
	end	
	GCO.ShowTimer("Saving And Checking CultureMap")
end
LuaEvents.SaveTables.Add(CheckSave)

function PostInitialize() -- everything that may require other context to be loaded first
	ExposedMembers.CultureMap 			= GCO.LoadTableFromSlot("CultureMap") or {}
	ExposedMembers.PreviousCultureMap 	= GCO.LoadTableFromSlot("PreviousCultureMap") or {}
	InitializePlotFunctions()
	SetCultureDiffusionRatePer1000()
end


-- for debugging
function ShowPlotData()
	for key, data in pairs(ExposedMembers.CultureMap) do
		print(key, data)
		for k, v in pairs (data) do
			print("-", k, v)
		end
	end
end

function CompareData(data1, data2)
	for key, data in pairs(data1) do
		--print(key, data)
		for k, v in pairs (data) do
			if not data2[key] then
				print("- reloaded table is nil for key = ", key)
			elseif not data2[key][k] then			
				print("- no value for key = ", key, " CivID =", k)
			elseif v ~= data2[key][k] then
				print("- different value for key = ", key, " CivID =", k, " Data1 value = ", v, type(v), " Data2 value = ", data2[key][k], type(data2[key][k]), v - data2[key][k] )
			end
		end
	end
end

-----------------------------------------------------------------------------------------
-- Plots Functions
-----------------------------------------------------------------------------------------
function GetKey ( self )
	return tostring(self:GetIndex())
end

function GetPlotFromKey( key )
	return Map.GetPlotByIndex(tonumber(key))
end

local conquestCountdown = {}
function DoConquestCountDown( self )
	local count = conquestCountdown[self:GetKey()]
	if count and count > 0 then
		conquestCountdown[self:GetKey()] = count - 1
	end
end
function GetConquestCountDown( self )
	return conquestCountdown[self:GetKey()] or 0
end
function SetConquestCountDown( self, value )
	conquestCountdown[self:GetKey()] = value
end

function GetCultureTable( self )
	if ExposedMembers.CultureMap and ExposedMembers.CultureMap[self:GetKey()] then
		return ExposedMembers.CultureMap[self:GetKey()]
	end
end
function GetCulture( self, playerID )
	local plotCulture = self:GetCultureTable()
	if plotCulture then 
		return plotCulture[tostring(playerID)] or 0
	end
	return 0
end
function SetCulture( self, playerID, value )
	local key = self:GetKey()
	--print("SetCulture",self:GetX(), self:GetY(), playerID, GCO.ToDecimals(value))
	if ExposedMembers.CultureMap[key] then 
		ExposedMembers.CultureMap[key][tostring(playerID)] = value
	else
		ExposedMembers.CultureMap[key] = {}
		ExposedMembers.CultureMap[key][tostring(playerID)] = value
	end
end
function ChangeCulture( self, playerID, value )
	local key = self:GetKey()
	local value = GCO.Round(value)
	--print("ChangeCulture",self:GetX(), self:GetY(), playerID, GCO.ToDecimals(value), GCO.ToDecimals(self:GetPreviousCulture(playerID )))
	if ExposedMembers.CultureMap[key] then 
		if ExposedMembers.CultureMap[key][tostring(playerID)] then
			ExposedMembers.CultureMap[key][tostring(playerID)] = ExposedMembers.CultureMap[key][tostring(playerID)] + value
		else
			ExposedMembers.CultureMap[key][tostring(playerID)] = value
		end
	else
		ExposedMembers.CultureMap[key] = {}
		ExposedMembers.CultureMap[key][tostring(playerID)] = value
	end
end

function GetPreviousCulture( self, playerID )
	local plotCulture = ExposedMembers.PreviousCultureMap[self:GetKey()]
	if plotCulture then 
		return plotCulture[tostring(playerID)] or 0
	end
	return 0
end
function SetPreviousCulture( self, playerID, value )
	local key = self:GetKey()
	if ExposedMembers.PreviousCultureMap[key] then 
		ExposedMembers.PreviousCultureMap[key][tostring(playerID)] = value
	else
		ExposedMembers.PreviousCultureMap[key] = {}
		ExposedMembers.PreviousCultureMap[key][tostring(playerID)] = value
	end
end

function GetTotalCulture( self )
	local totalCulture = 0
	local plotCulture = self:GetCultureTable()
	if  plotCulture then
		for playerID, value in pairs (plotCulture) do
			totalCulture = totalCulture + value			
		end
	end
	return totalCulture
end
function GetCulturePercentTable( self )
	-- return a table with civs culture % for a plot in cultureMap and the total culture
	local plotCulturePercent = {}
	local totalCulture = self:GetTotalCulture()
	local plotCulture = self:GetCultureTable()
	if  plotCulture and totalCulture > 0 then
		for playerID, value in pairs (plotCulture) do
			plotCulturePercent[playerID] = (value / totalCulture * 100)
		end
	end
	return plotCulturePercent, totalCulture
end

function GetCulturePercent( self, playerID )
	-- return a table with civs culture % for a plot in cultureMap and the total culture
	local totalCulture = self:GetTotalCulture()
	if totalCulture > 0 then
		return GCO.Round(self:GetCulture(playerID) * 100 / totalCulture)
	end
	return 0
end

function GetHighestCulturePlayer( self )
	local topPlayer
	local topValue = 0
	local plotCulture = self:GetCultureTable()
	if  plotCulture then
		for playerID, value in pairs (plotCulture) do
			if value > topValue then
				topValue = value
				topPlayer = playerID
			end
		end
	end
	return topPlayer -- can be nil
end

function GetTotalPreviousCulture( self )
	local totalCulture = 0
	local plotCulture = ExposedMembers.PreviousCultureMap[self:GetKey()]
	if  plotCulture then
		for playerID, value in pairs (plotCulture) do
			totalCulture = totalCulture + value			
		end
	end
	return totalCulture
end

function GetCulturePer10000( self, playerID )
	local totalCulture = GetTotalCulture( self )
	if totalCulture > 0 then
		return GCO.Round(GetCulture( self, playerID ) * 10000 / totalCulture)
	end
	return 0
end
function GetPreviousCulturePer10000( self, playerID )
	local totalCulture = GetTotalPreviousCulture( self )
	if totalCulture > 0 then
		return GCO.Round(GetPreviousCulture( self, playerID ) * 10000 / totalCulture)
	end
	return 0
end

function IsLockedByWarForPlayer( self, playerID )
	local bLocked = false
	if (tonumber(GameInfo.GlobalParameters["CULTURE_LOCK_FLIPPING_ON_WAR"].Value) > 0)
	and (self:GetOwner() ~= NO_OWNER)
	and Players[playerID]
	and Players[playerID]:GetDiplomacy():IsAtWarWith(self:GetOwner()) then
		bLocked = true
	end
	return bLocked
end
function IsLockedByFortification( self )
	if (tonumber(GameInfo.GlobalParameters["CULTURE_NO_FORTIFICATION_FLIPPING"].Value) > 0) then
		local improvementType = self:GetImprovementType()
		if ( improvementType ~= NO_IMPROVEMENT) and (not GCO.IsImprovementPillaged(self)) then -- and (not self:IsImprovementPillaged()) then		
			if (GameInfo.Improvements[improvementType].GrantFortification > 0) then
				return true
			end
		end
	end
	return false
end
function IsLockedByCitadelForPlayer( self, playerID )
	if (tonumber(GameInfo.GlobalParameters["CULTURE_NO_FORTIFICATION_FLIPPING"].Value) > 0) then
		local iX = self:GetX()
		local iY = self:GetY()
		for direction = 0, DirectionTypes.NUM_DIRECTION_TYPES - 1, 1 do
			local adjacentPlot = Map.GetAdjacentPlot(iX, iY, direction);
			if (adjacentPlot ~= nil) and (not adjacentPlot:IsWater()) and (not adjacentPlot:GetOwner() == playerID) then
				local improvementType = self:GetImprovementType()
				if ( improvementType ~= NO_IMPROVEMENT) and (not GCO.IsImprovementPillaged(self)) then		
					if (GameInfo.Improvements[improvementType].GrantFortification > 0) then
						return true
					end
				end
			end
		end		
	end
	return false
end

function GetPotentialOwner( self )
	local bestPlayer = NO_OWNER
	local topValue = 0
	local plotCulture = self:GetCultureTable()
	if plotCulture then
		for playerID, value in pairs (plotCulture) do
			local player = Players[tonumber(playerID)]
			if player and player:IsAlive() and value > topValue then
				if not (tonumber(GameInfo.GlobalParameters["CULTURE_FLIPPING_ONLY_ADJACENT"].Value) > 0 and not self:IsAdjacentPlayer(playerID)) then
					topValue = value
					bestPlayer = playerID
				end
			end
		end
	end
	return bestPlayer
end

local debugTable = {}
local bshowDebug = false
function UpdateCulture( self )
	debugTable = {}
	bshowDebug = false
	--table.insert(debugTable, "-------------------------------- UPDATE CULTURE FOR PLOT (".. tostring(self:GetX()) .. "," .. tostring(self:GetY()) ..") --------------------------------" )

	-- No culture on water
	if self:IsWater() then
		if self:GetOwner() ~= NO_OWNER then
			WorldBuilder.CityManager():SetPlotOwner( self:GetX(), self:GetY(), false )
		end
		return
	end
	
	-- Decay
	local plotCulture = self:GetCultureTable()
	if plotCulture then
		--table.insert(debugTable, "----- Decay -----")
		for playerID, value in pairs (plotCulture) do
			
			-- Apply decay
			if value > 0 then
				local minValueOwner = tonumber(GameInfo.GlobalParameters["CULTURE_MINIMAL_ON_OWNED_PLOT"].Value)
				local decay = math.max(1, GCO.Round(value * tonumber(GameInfo.GlobalParameters["CULTURE_DECAY_RATE"].Value) / 100))
				if (value - decay) <= 0 then
					if self:GetOwner() == playerID then
						self:SetCulture(playerID, minValueOwner)
						--table.insert(debugTable, "Player #"..tostring(playerID) .." (value ["..tostring(value).."] - decay [".. tostring(decay) .."]) <= 0 -> SetCulture("..tostring(playerID) ..", minimum for plot owner = ".. tostring(minValueOwner)..")")
					else -- don't remove yet, to show variation with previous turn
						self:SetCulture(playerID, 0)
						--table.insert(debugTable, "Player #"..tostring(playerID) .." (value ["..tostring(value).."] - decay [".. tostring(decay) .."]) <= 0 -> SetCulture("..tostring(playerID) ..", ".. tostring(0)..")")
					end
				else
					if self:GetOwner() == playerID and (value - decay) < minValueOwner then
						self:SetCulture(playerID, minValueOwner)
						--table.insert(debugTable, "Player #"..tostring(playerID) .." (value ["..tostring(value).."] - decay [".. tostring(decay) .."]) <= minValueOwner [".. tostring(minValueOwner).."  -> SetCulture("..tostring(playerID) ..", minimum for plot owner = ".. tostring(minValueOwner)..")")						
					else
						self:ChangeCulture(playerID, -decay)
						--table.insert(debugTable, "Player #"..tostring(playerID) .." (value ["..tostring(value).."] - decay [".. tostring(decay) .."]) = ".. tostring(value - decay).."  -> ChangeCulture("..tostring(playerID) ..", ".. tostring(- decay)..")")	
					end					
				end
			else -- remove dead culture
				ExposedMembers.CultureMap[self:GetKey()][tostring(playerID)] = nil
				--table.insert(debugTable, "Player #"..tostring(playerID) .." value ["..tostring(value).."] <= 0 before decay, removing entry...")	
			end
		end		
		--table.insert(debugTable, "----- ----- -----")
	end
	
	-- diffuse culture on adjacent plots
	--table.insert(debugTable, "Check for diffuse, self:GetTotalCulture() = "..tostring(self:GetTotalCulture()) ..",  CULTURE_DIFFUSION_THRESHOLD = "..tostring(GameInfo.GlobalParameters["CULTURE_DIFFUSION_THRESHOLD"].Value))
	if self:GetTotalCulture() > tonumber(GameInfo.GlobalParameters["CULTURE_DIFFUSION_THRESHOLD"].Value) then
		self:DiffuseCulture()
	end
	
	-- update culture in cities
	--table.insert(debugTable, "Check for city")
	if self:IsCity() then
		local city = Cities.GetCityInPlot(self:GetX(), self:GetY())
		--local cityCulture = city:GetCulture()
		bshowDebug = true
		--table.insert(debugTable, "----- ".. tostring(city:GetName()) .." -----")
		
		-- Culture creation in cities
		local baseCulture = tonumber(GameInfo.GlobalParameters["CULTURE_CITY_BASE_PRODUCTION"].Value)
		local maxCulture = (city:GetPopulation() + GCO.GetCityCultureYield(self)) * tonumber(GameInfo.GlobalParameters["CULTURE_CITY_CAPED_FACTOR"].Value)
		--table.insert(debugTable, "baseCulture = " .. tostring(baseCulture) ..", maxCulture ["..tostring(maxCulture).."] = (city:GetPopulation() ["..tostring(city:GetPopulation()) .." + GCO.GetCityCultureYield(self)[".. tostring(GCO.GetCityCultureYield(self)).."]) * CULTURE_CITY_CAPED_FACTOR["..tonumber(GameInfo.GlobalParameters["CULTURE_CITY_CAPED_FACTOR"].Value).."]")
		if self:GetTotalCulture() < maxCulture then -- don't add culture if above max, the excedent will decay each turn
			if plotCulture then
				-- First add culture for city owner				
				local cultureAdded = 0
				local value = self:GetCulture( city:GetOwner() )
				if tonumber(GameInfo.GlobalParameters["CULTURE_OUTPUT_USE_LOG"].Value) > 0 then
					cultureAdded = GCO.Round((city:GetPopulation() + GCO.GetCityCultureYield(self)) * math.log( value * tonumber(GameInfo.GlobalParameters["CULTURE_CITY_FACTOR"].Value) ,10))
				else
					cultureAdded = GCO.Round((city:GetPopulation() + GCO.GetCityCultureYield(self)) * math.sqrt( value * tonumber(GameInfo.GlobalParameters["CULTURE_CITY_RATIO"].Value)))
				end	
				cultureAdded = cultureAdded + baseCulture
				--table.insert(debugTable, "- Player#".. tostring(playerID)..", population= ".. tostring(city:GetPopulation())..", GCO.GetCityCultureYield(self) =".. tostring(GCO.GetCityCultureYield(self)) ..", math.log( value[".. tostring(value).."] * CULTURE_CITY_FACTOR["..tostring(GameInfo.GlobalParameters["CULTURE_CITY_FACTOR"].Value).."], 10) = " .. tostring(math.log( value * tonumber(GameInfo.GlobalParameters["CULTURE_CITY_FACTOR"].Value) ,10)) ..", math.sqrt( value[".. tostring(value).."] * CULTURE_CITY_RATIO[".. tostring (GameInfo.GlobalParameters["CULTURE_CITY_RATIO"].Value).."]" .. tostring(math.sqrt( value * tonumber(GameInfo.GlobalParameters["CULTURE_CITY_RATIO"].Value))) .. ", baseCulture =" .. tostring(baseCulture) ..", cultureAdded = " ..tostring(cultureAdded))
				self:ChangeCulture(city:GetOwner(), cultureAdded)	
				
				-- Then update all other Culture
				for playerID, value in pairs (plotCulture) do
					if value > 0 then
						local cultureAdded = 0
						if playerID ~= city:GetOwner() then
							if tonumber(GameInfo.GlobalParameters["CULTURE_OUTPUT_USE_LOG"].Value) > 0 then
								cultureAdded = GCO.Round(city:GetPopulation() * math.log( value * tonumber(GameInfo.GlobalParameters["CULTURE_CITY_FACTOR"].Value) ,10))
							else
								cultureAdded = GCO.Round(city:GetPopulation() * math.sqrt( value * tonumber(GameInfo.GlobalParameters["CULTURE_CITY_RATIO"].Value)))
							end
							self:ChangeCulture(playerID, cultureAdded)
						end					
					end				
				end
			elseif self:GetOwner() == city:GetOwner() then -- initialize culture in city
				self:ChangeCulture(city:GetOwner(), baseCulture)
			end
		end
		
		-- Culture Conversion in cities
		local cultureConversionRatePer10000 = tonumber(GameInfo.GlobalParameters["CULTURE_CITY_CONVERSION_RATE"].Value)
		
		-- Todo : add convertion from buildings, policies...
		
		if (cultureConversionRatePer10000 > 0) then 
			if plotCulture then
				for playerID, value in pairs (plotCulture) do
					if playerID ~= playerID and playerID ~= SEPARATIST_PLAYER then
						local converted = GCO.Round(value * cultureConversionRatePer10000 / 10000)
						if converted > 0 then
							self:ChangeCulture(playerID, -converted)
							self:ChangeCulture(city:GetOwner(), converted)
						end						
					end
				end
			end				
		end
		--table.insert(debugTable, "----- ----- -----")
	end
	
	-- Todo : improvements/units can affect culture
	
	-- Update Ownership
	if tonumber(GameInfo.GlobalParameters["CULTURE_ALLOW_TILE_ACQUISITION"].Value) > 0 or tonumber(GameInfo.GlobalParameters["CULTURE_ALLOW_TILE_FLIPPING"].Value) > 0 then
		self:UpdateOwnership()
	end
	
	-- Update locked plot
	if tonumber(GameInfo.GlobalParameters["CULTURE_CONQUEST_ENABLED"].Value) > 0 then
		self:DoConquestCountDown()
	end	
	ShowDebug()
end
function UpdateOwnership( self )
	--table.insert(debugTable, "----- UpdateOwnership -----")
	--table.insert(debugTable, "plot (" .. self:GetX()..","..self:GetY()..")")
	if self:GetTotalCulture() > 0 then
		bshowDebug = true
		--table.insert(debugTable, "Total culture = " .. self:GetTotalCulture())
	end
	
	-- cities do not flip without Revolutions...
	if self:IsCity() then return end
	--table.insert(debugTable, "Not City")
	
	-- if plot is locked, don't try to change ownership...
	if (self:GetConquestCountDown() > 0) then return end
	--table.insert(debugTable, "Not Conquered")
	
	-- 	check if fortifications on this plot are preventing tile flipping...
	if (self:IsLockedByFortification()) then return	end
	--table.insert(debugTable, "Not Locked by Fortification")
	
	-- Get potential owner
	local bestPlayerID = self:GetPotentialOwner()
		--table.insert(debugTable, "PotentialOwner = " .. bestPlayerID)
	if (bestPlayerID == NO_OWNER) then
		return
	end
	local bestValue = self:GetCulture(bestPlayerID)
	
	
	--table.insert(debugTable, "ActualOwner[".. self:GetOwner() .."] ~= PotentialOwner AND  bestValue[".. bestValue .."] > GetCultureMinimumForAcquisition( PotentialOwner )[".. GetCultureMinimumForAcquisition( PotentialOwner ) .."] ?" )
	if (bestPlayerID ~= self:GetOwner()) and (bestValue > GetCultureMinimumForAcquisition( bestPlayerID )) then
	
		-- Do we allow tile flipping when at war ?		
		if (self:IsLockedByWarForPlayer(bestPlayerID)) then return end
		--table.insert(debugTable, "Not Locked by war")
		
		-- check if an adjacent fortification can prevent tile flipping...
		if (self:IsLockedByCitadelForPlayer(bestPlayerID)) then return end
		--table.insert(debugTable, "Not Locked by Adjacent Fortification")
		
		-- case 1: the tile was not owned and tile acquisition is allowed
		local bAcquireNewPlot = (self:GetOwner() == NO_OWNER and tonumber(GameInfo.GlobalParameters["CULTURE_ALLOW_TILE_ACQUISITION"].Value) > 0)		
		--table.insert(debugTable, "bAcquireNewPlot = (self:GetOwner()[".. self:GetOwner() .."] == NO_OWNER[".. NO_OWNER .."] AND CULTURE_ALLOW_TILE_ACQUISITION[".. GameInfo.GlobalParameters["CULTURE_ALLOW_TILE_ACQUISITION"].Value .."] > 0) =" .. tostring(bAcquireNewPlot))
		
		-- case 2: tile flipping is allowed and the ratio between the old and the new owner is high enough
		local bConvertPlot = (tonumber(GameInfo.GlobalParameters["CULTURE_ALLOW_TILE_FLIPPING"].Value) > 0 and (bestValue * tonumber(GameInfo.GlobalParameters["CULTURE_FLIPPING_RATIO"].Value)/100) > self:GetCulture(self:GetOwner()))
		--table.insert(debugTable, "bConvertPlot = CULTURE_ALLOW_TILE_FLIPPING[".. GameInfo.GlobalParameters["CULTURE_ALLOW_TILE_FLIPPING"].Value .."] > 0 AND (bestValue[".. bestValue .."] * CULTURE_FLIPPING_RATIO[".. GameInfo.GlobalParameters["CULTURE_FLIPPING_RATIO"].Value .."]/100) > self:GetCulture(self:GetOwner())[".. self:GetCulture(self:GetOwner()) .."]) = " .. tostring(bConvertPlot))

		if bAcquireNewPlot or bConvertPlot then
			local city, distance = GCO.FindNearestPlayerCity(tonumber(bestPlayerID), self:GetX(), self:GetY())
			--table.insert(debugTable, "City: "..tostring(city)..", distance = " .. tostring(distance))
			if not city then return end
			
			-- Is the plot too far away ?			
			--table.insert(debugTable, "distance[".. tostring(distance) .."] <= GetCultureFlippingMaxDistance(bestPlayerID)[".. GetCultureFlippingMaxDistance(bestPlayerID) .."] ?")
			if distance > GetCultureFlippingMaxDistance(bestPlayerID) then return end
			
			-- All test passed succesfully, notify the players and change owner...
			-- to do : notify the players...
			--self:SetOwner(bestPlayerID, city:GetID(), true)
			--table.insert(debugTable, "Changing owner !")
			WorldBuilder.CityManager():SetPlotOwner( self:GetX(), self:GetY(), bestPlayerID, city:GetID() )
		end	
	end	
end

function DiffuseCulture( self )
	
	--table.insert(debugTable, "----- Diffuse -----")
	bshowDebug = true
	local iX = self:GetX()
	local iY = self:GetY()
	local iCultureValue 	= self:GetTotalCulture()
	local iPlotBaseMax 		= iCultureValue * tonumber(GameInfo.GlobalParameters["CULTURE_NORMAL_MAX_PERCENT"].Value) / 100
	for direction = 0, DirectionTypes.NUM_DIRECTION_TYPES - 1, 1 do
		local pAdjacentPlot = Map.GetAdjacentPlot(iX, iY, direction)
		--table.insert(debugTable, "Direction = " .. direction ..", to (" .. pAdjacentPlot:GetX()..","..pAdjacentPlot:GetY()..")")
		if (pAdjacentPlot and not pAdjacentPlot:IsWater()) then
			local iBonus 			= 0
			local iPenalty 			= 0
			local iPlotMax 			= iPlotBaseMax		
			local bIsRoute 			= (self:IsRoute() and not self:IsRoutePillaged()) and (pAdjacentPlot:IsRoute() and not pAdjacentPlot:IsRoutePillaged())
			local bIsFollowingRiver	= self:IsRiverConnection(direction) and not self:IsRiverCrossing(direction)
			local bIsCrossingRiver 	= (not bIsRoute) and self:IsRiverCrossing(direction)
			local terrainType		= self:GetTerrainType()
			local terrainThreshold	= GameInfo.Terrains[terrainType].CultureThreshold
			local terrainPenalty	= GameInfo.Terrains[terrainType].CulturePenalty
			local terrainMaxPercent	= GameInfo.Terrains[terrainType].CultureMaxPercent
			local featureType		= self:GetFeatureType()
			local bSkip				= false
			--table.insert(debugTable, " - iPlotMax = "..iPlotMax..", bIsRoute = ".. tostring(bIsRoute) ..", bIsFollowingRiver =" .. tostring(bIsFollowingRiver) ..", bIsCrossingRiver = " .. tostring(bIsCrossingRiver) ..", terrainType = " .. terrainType ..", terrainThreshold = ".. terrainThreshold ..", terrainPenalty = ".. terrainPenalty ..", terrainMaxPercent = ".. terrainMaxPercent ..", featureType = ".. featureType)
			-- Bonus: following road
			if (bIsRoute) then
				iBonus 		= iBonus + iRoadBonus
				iPlotMax 	= iPlotMax * iRoadMax / 100
				--table.insert(debugTable, " - bIsRoute = true, iPlotMax = ".. iPlotMax .. ", iBonus : " .. iBonus)
			end
			
			-- Bonus: following a river
			if (bIsFollowingRiver) then
				iBonus 		= iBonus + iFollowingRiverBonus
				iPlotMax 	= iPlotMax * iFollowingRiverMax / 100
				--table.insert(debugTable, " - bIsFollowingRiver = true, iPlotMax = ".. iPlotMax .. ", iBonus : " .. iBonus)
			end
			
			-- Penalty: feature
			if featureType ~= NO_FEATURE then
				local featureThreshold	= GameInfo.Features[featureType].CultureThreshold
				local featurePenalty	= GameInfo.Features[featureType].CulturePenalty
				local featureMaxPercent	= GameInfo.Features[featureType].CultureMaxPercent
				if featurePenalty > 0 then
					if iCultureValue > featureThreshold * iBaseThreshold / 100 then
						iPenalty 	= iPenalty + featurePenalty
						iPlotMax 	= iPlotMax * featureMaxPercent / 100
						--table.insert(debugTable, " - featurePenalty[".. featurePenalty .."] > 0, iPlotMax = ".. iPlotMax .. ", iBonus : " .. iBonus)
					else
						bSkip = true -- no diffusion on that plot
						--table.insert(debugTable, " - Skipping plot (iCultureValue[".. iCultureValue .."] < featureThreshold[".. featureThreshold .."] * iBaseThreshold[".. iBaseThreshold .."] / 100)")
					end
				end
			end
			
			-- Penalty: terrain
			if not bSkip then
				if terrainPenalty > 0 then
					if iCultureValue > terrainThreshold * iBaseThreshold / 100 then
						iPenalty 	= iPenalty + terrainPenalty
						iPlotMax 	= iPlotMax * terrainMaxPercent / 100
						--table.insert(debugTable, " - terrainPenalty[".. terrainPenalty .."] > 0, iPlotMax = ".. iPlotMax .. ", iBonus : " .. iBonus)
					else
						bSkip = true -- no diffusion on that plot
						--table.insert(debugTable, " - Skipping plot (iCultureValue[".. iCultureValue .."] < terrainThreshold[".. terrainThreshold .."] * iBaseThreshold[".. iBaseThreshold .."] / 100)")
					end
				end			
			end
			
			-- Penalty: crossing river
			if not bSkip then
				if bIsCrossingRiver then
					if iCultureValue > iCrossingRiverThreshold * iBaseThreshold / 100 then
						iPenalty 	= iPenalty + iCrossingRiverPenalty
						iPlotMax 	= iPlotMax * iCrossingRiverMax / 100
						--table.insert(debugTable, " - bIsCrossingRiver = true, iPlotMax = ".. iPlotMax .. ", iBonus : " .. iBonus)
					else
						bSkip = true -- no diffusion on that plot
						--table.insert(debugTable, " - Skipping plot (iCultureValue[".. iCultureValue .."] < iCrossingRiverThreshold[".. iCrossingRiverThreshold .."] * iBaseThreshold[".. iBaseThreshold .."] / 100)")
					end
				end			
			end
			
			if not bSkip then				
				--table.insert(debugTable, " - iPlotMax = math.min(iPlotMax[" .. iPlotMax.."], iCultureValue[" .. iCultureValue.."] * CULTURE_ABSOLUTE_MAX_PERCENT[" .. tonumber(GameInfo.GlobalParameters["CULTURE_ABSOLUTE_MAX_PERCENT"].Value).."] / 100) = " ..math.min(iPlotMax, iCultureValue * tonumber(GameInfo.GlobalParameters["CULTURE_ABSOLUTE_MAX_PERCENT"].Value) / 100))
				iPlotMax = math.min(iPlotMax, iCultureValue * tonumber(GameInfo.GlobalParameters["CULTURE_ABSOLUTE_MAX_PERCENT"].Value) / 100)
				-- Apply Culture diffusion to all culture groups
				local plotCulture = self:GetCultureTable() -- this should never be nil at this point
				for playerID, value in pairs (plotCulture) do
				
					local iPlayerPlotMax = iPlotMax * self:GetCulturePercent(playerID) / 100
					local iPlayerDiffusedCulture = (self:GetCulture(playerID) * (iDiffusionRatePer1000 + (iDiffusionRatePer1000 * iBonus / 100))) / (1000 + (1000 * iPenalty / 100))
					local iPreviousCulture = pAdjacentPlot:GetCulture(playerID);
					local iNextculture = math.min(iPlayerPlotMax, iPreviousCulture + iPlayerDiffusedCulture);
					--table.insert(debugTable, " - Diffuse for player#"..playerID..", iPlotMax = "..iPlotMax..", iPlayerPlotMax = ".. GCO.ToDecimals(iPlayerPlotMax) ..", iPreviousCulture = ".. GCO.ToDecimals(iPreviousCulture) ..", iNextculture = " ..GCO.ToDecimals(iNextculture)) 
					--table.insert(debugTable, "		iPlayerDiffusedCulture["..GCO.ToDecimals(iPlayerDiffusedCulture).."] = (self:GetCulture(playerID)["..GCO.ToDecimals(self:GetCulture(playerID)).."] * (iDiffusionRatePer1000["..GCO.ToDecimals(iDiffusionRatePer1000).."] + (iDiffusionRatePer1000["..GCO.ToDecimals(iDiffusionRatePer1000).."] * iBonus["..GCO.ToDecimals(iBonus).."] / 100))) / (1000 + (1000 * iPenalty["..GCO.ToDecimals(iPenalty).."] / 100))")
					
					iPlayerDiffusedCulture = iNextculture - iPreviousCulture
					if (iPlayerDiffusedCulture > 0) then -- can be < 0 when a plot try to diffuse to another with a culture value already > at the calculated iPlayerPlotMax...
						pAdjacentPlot:ChangeCulture(playerID, iPlayerDiffusedCulture)
						--table.insert(debugTable, " - Diffusing : " .. iPlayerDiffusedCulture)
					else
						--table.insert(debugTable, " - Not diffusing negative value... (" .. iPlayerDiffusedCulture ..")")
					end
				end				
			end
		else
			--table.insert(debugTable, " - Skipping plot (water)")
		end
	end
	--table.insert(debugTable, "----- ----- -----")
end


-----------------------------------------------------------------------------------------
-- Other Functions
-----------------------------------------------------------------------------------------
function GetCultureMinimumForAcquisition( playerID )
	-- to do : change by era / policies
	return tonumber(GameInfo.GlobalParameters["CULTURE_MINIMUM_FOR_ACQUISITION"].Value)
end

function GetCultureFlippingMaxDistance( playerID )
	-- to do : change by era / policies
	return tonumber(GameInfo.GlobalParameters["CULTURE_FLIPPING_MAX_DISTANCE"].Value)
end

function ShowDebug()
	if bshowDebug then
		for _, text in ipairs(debugTable) do
			print(text)
		end
	end
end

function UpdateCultureOnCityCapture( originalOwnerID, originalCityID, newOwnerID, newCityID, iX, iY )
	print("-----------------------------------------------------------------------------------------")
	print("Update Culture On City Capture")
	local city 		= GCO.GetCity(newOwnerID, newCityID)
	local cityPlots = GCO.GetCityPlots(city)
	for _, plotID in ipairs(cityPlots) do
		local plot	= Map.GetPlotByIndex(plotID)
		print(" - Plot at :", plot:GetX(), plot:GetY())
		local totalCultureLoss = 0
		local plotCulture = plot:GetCultureTable()
		for playerID, value in pairs (plotCulture) do
			local cultureLoss = GCO.Round(plot:GetCulture(playerID) * tonumber(GameInfo.GlobalParameters["CULTURE_LOST_CITY_CONQUEST"].Value) / 100)
			print("   - player#"..tostring(playerID).." lost culture = ", cultureLoss)
			if cultureLoss > 0 then
				totalCultureLoss = totalCultureLoss + cultureLoss
				plot:ChangeCulture(playerID, -cultureLoss)
			end
		end
		local cultureGained = GCO.Round(totalCultureLoss * tonumber(GameInfo.GlobalParameters["CULTURE_GAIN_CITY_CONQUEST"].Value) / 100)
		print("   - player#"..tostring(newOwnerID).." gain culture = ", cultureGained)
		plot:ChangeCulture(newOwnerID, cultureGained)
		local distance = Map.GetPlotDistance(iX, iY, plot:GetX(), plot:GetY())
		local bRemoveOwnership = (tonumber(GameInfo.GlobalParameters["CULTURE_REMOVE_PLOT_CITY_CONQUEST"].Value == 1 and distance > tonumber(GameInfo.GlobalParameters["CULTURE_MAX_DISTANCE_PLOT_CITY_CONQUEST"].Value)))
		print("   - check for changing owner: CULTURE_REMOVE_PLOT_CITY_CONQUEST ="..tostring(GameInfo.GlobalParameters["CULTURE_REMOVE_PLOT_CITY_CONQUEST"].Value)..", distance["..tostring(distance).."] >  CULTURE_MAX_DISTANCE_PLOT_CITY_CONQUEST["..tostring(GameInfo.GlobalParameters["CULTURE_MAX_DISTANCE_PLOT_CITY_CONQUEST"].Value).."]")
		if bRemoveOwnership then
			WorldBuilder.CityManager():SetPlotOwner( plot:GetX(), plot:GetY(), false )
		end
	end
end
LuaEvents.CapturedCityInitialized.Add( UpdateCultureOnCityCapture )

-----------------------------------------------------------------------------------------
-- Initialize Culture Functions
-----------------------------------------------------------------------------------------
function SetCultureDiffusionRatePer1000()
	local iSettingFactor 	= 1
	local iStandardTurns 	= 500
	local iTurnsFactor 		= 1
	-- to do : GameSpeed_Turns, GameSpeedType, add all TurnsPerIncrement
	-- iTurnsFactor = (iStandardTurns * 100 / (getEstimateEndTurn() - getGameTurn()))
	
	local iStandardSize		= 84*54 -- to do : Maps, MapSizeType = Map.GetMapSize(), GridWidth*GridHeight
	local g_iW, g_iH 		= Map.GetGridSize()
	local iMapsize 			= g_iW * g_iH
	local iSizeFactor 		= (iMapsize * 100 / iStandardSize)
	
	iSettingFactor = iSettingFactor * iSizeFactor
	
	iDiffusionRatePer1000 = (tonumber(GameInfo.GlobalParameters["CULTURE_DIFFUSION_RATE"].Value) * iSettingFactor / 100) / 10
	print ("iSettingFactor = ".. tostring(iSettingFactor))
	print ("iDiffusionRatePer1000 = ".. tostring(iDiffusionRatePer1000))
	iDiffusionRatePer1000 = tonumber(GameInfo.GlobalParameters["CULTURE_DIFFUSION_RATE"].Value) / 10
	print ("iDiffusionRatePer1000 = ".. tostring(iDiffusionRatePer1000))
end

function OnNewTurn()
	GCO.StartTimer("Culture Diffusion")
	local iPlotCount = Map.GetPlotCount()
	-- set previous culture first
	for i = 0, iPlotCount - 1 do
		local plot = Map.GetPlotByIndex(i)
		local plotCulture = plot:GetCultureTable()
		if  plotCulture then
			for playerID, value in pairs (plotCulture) do
				plot:SetPreviousCulture( playerID, value )			
			end
		end
	end
	-- then update culture
	for i = 0, iPlotCount - 1 do
		local plot = Map.GetPlotByIndex(i)
		plot:UpdateCulture()
	end
	--print("-----------------------------------------------------------------------------------------")
	GCO.ShowTimer("Culture Diffusion")
	--print("-----------------------------------------------------------------------------------------")
end
Events.TurnBegin.Add(OnNewTurn)


function InitializeCityPlots(playerID, cityID, iX, iY)
	print(GCO.Separator)
	print("Initializing New City Plots...")
	local city 		= CityManager.GetCity(playerID, cityID)
	local cityPlot 	= Map.GetPlot(iX, iY)
	local cityPlots	= GCO.GetCityPlots(city)
	local counter 	= 0
	local ring		= 2 -- first ring to test for replacement plots
	for _, plotID in ipairs(cityPlots) do		
		local plot	= Map.GetPlotByIndex(plotID)
		local x		= plot:GetX()
		local y		= plot:GetY()
		if (plot:IsWater() or ( (plot:GetArea():GetID() ~= cityPlot:GetArea():GetID()) and not plot:IsMountain() )) and (plot:GetOwner() ~= NO_OWNER) then
			--adjacentPlot:SetOwner(NO_OWNER)
			WorldBuilder.CityManager():SetPlotOwner( x, y, false )
			counter = counter + 1
		end
	end
	print("- plots to replace = ", counter)
	function ReplacePlots()
		local plotList = {}
		if counter > 0 then
			for pEdgePlot in GCO.PlotRingIterator(cityPlot, ring) do
				if not ((pEdgePlot:IsWater() or ( pEdgePlot:GetArea():GetID() ~= cityPlot:GetArea():GetID() ))) and (pEdgePlot:GetOwner() == NO_OWNER) and pEdgePlot:IsAdjacentPlayer(playerID) then
					print("   adding to list :", pEdgePlot:GetX(), pEdgePlot:GetY(), "on ring :", ring)
					local totalYield = 0
					for row in GameInfo.Yields() do
						local yield = pEdgePlot:GetYield(row.Index);
						if (yield > 0) then
							totalYield = totalYield + 1
						end
					end
					table.insert(plotList, {plot = pEdgePlot, yield = totalYield})				
				end
			end
		end
		table.sort(plotList, function(a, b) return a.yield > b.yield; end)
		for _, data in ipairs(plotList) do
			print("   replacing at : ", data.plot:GetX(), data.plot:GetY())
			WorldBuilder.CityManager():SetPlotOwner( data.plot:GetX(), data.plot:GetY(), playerID, cityID )
			counter = counter - 1
			if counter == 0 then
				return
			end
		end
	end
	local loop = 0
	while (counter > 0 and loop < 4) do
		print(" - loop =", loop, "plots to replace left =", counter )
		ReplacePlots()
		ring = ring + 1
		ReplacePlots()
		ring = ring - 1  -- some plots that where not adjacent to another plot of that player maybe now
		ReplacePlots()
		ring = ring + 1
		loop = loop + 1
	end
	
	print("- check city ownership")	
	for ring = 1, 3 do
		for pEdgePlot in GCO.PlotRingIterator(cityPlot, ring) do
			local OwnerCity	= Cities.GetPlotPurchaseCity(pEdgePlot)
			if OwnerCity and pEdgePlot:GetOwner() == playerID and OwnerCity:GetID() ~= city:GetID() then
				local cityDistance 		= Map.GetPlotDistance(pEdgePlot:GetX(), pEdgePlot:GetY(), city:GetX(), city:GetY())
				local ownerCityDistance = Map.GetPlotDistance(pEdgePlot:GetX(), pEdgePlot:GetY(), OwnerCity:GetX(), OwnerCity:GetY())
				if (cityDistance < ownerCityDistance) and (pEdgePlot:GetWorkerCount() == 0 or cityDistance == 1) then
					print("   change city ownership at : ", pEdgePlot:GetX(), pEdgePlot:GetY(), " city distance = ", cityDistance, " previous city = ", Locale.Lookup(OwnerCity:GetName()), " previous city distance = ", ownerCityDistance)
					WorldBuilder.CityManager():SetPlotOwner( pEdgePlot, false ) -- must remove previous city ownership first, else the UI context doesn't update
					WorldBuilder.CityManager():SetPlotOwner( pEdgePlot, city, true )
					--LuaEvents.UpdatePlotTooltip(  pEdgePlot:GetIndex() )
					--print(Cities.GetPlotPurchaseCity(pEdgePlot):GetName())
					--Events.CityWorkerChanged(playerID, city:GetID())
					--pEdgePlot:SetOwner(city)
				end
			end
		end
	end
end
Events.CityInitialized.Add(InitializeCityPlots)


-----------------------------------------------------------------------------------------
-- Rivers Functions
-----------------------------------------------------------------------------------------
local DirectionStr = {
		[DirectionTypes.DIRECTION_WEST] = "W",
		[DirectionTypes.DIRECTION_NORTHWEST] = "NW",
		[DirectionTypes.DIRECTION_NORTHEAST] = "NE",
		[DirectionTypes.DIRECTION_EAST] = "E",
		[DirectionTypes.DIRECTION_SOUTHEAST] = "SE",
		[DirectionTypes.DIRECTION_SOUTHWEST] = "SW",
	}
	
local FlowDirectionStr = {
		[FlowDirectionTypes.FLOWDIRECTION_NORTHEAST] = "NE",
		[FlowDirectionTypes.FLOWDIRECTION_NORTHWEST] = "NW",
		[FlowDirectionTypes.FLOWDIRECTION_NORTH] = "N",
		[FlowDirectionTypes.FLOWDIRECTION_SOUTHEAST] = "SE",
		[FlowDirectionTypes.FLOWDIRECTION_SOUTH] = "S",
		[FlowDirectionTypes.FLOWDIRECTION_SOUTHWEST] = "SW",
		[FlowDirectionTypes.NO_FLOWDIRECTION] = "NO FLOW",
	}

local PlotPosition = {
	NORTHEAST 	= 1,
	EAST 		= 2,
	SOUTHEAST 	= 3,
	SOUTHWEST 	= 4,
	WEST 		= 5,
	NORTHWEST 	= 6,
	}

function IsEOfRiver(self)
	if not self:IsRiver() then return false	end
	local pAdjacentPlot = Map.GetAdjacentPlot(self:GetX(), self:GetY(), DirectionTypes.DIRECTION_WEST)
	if pAdjacentPlot and pAdjacentPlot:IsWOfRiver() then return true end
	return false
end

function IsSEOfRiver(self)
	if not self:IsRiver() then return false	end
	local pAdjacentPlot = Map.GetAdjacentPlot(self:GetX(), self:GetY(), DirectionTypes.DIRECTION_NORTHWEST)
	if pAdjacentPlot and pAdjacentPlot:IsNWOfRiver() then return true end
	return false
end

function IsSWOfRiver(self)
	if not self:IsRiver() then return false	end
	local pAdjacentPlot = Map.GetAdjacentPlot(self:GetX(), self:GetY(), DirectionTypes.DIRECTION_NORTHEAST)
	if pAdjacentPlot and pAdjacentPlot:IsNEOfRiver() then return true end
	return false
end

function GetOppositeFlowDirection(dir)
	local numTypes = FlowDirectionTypes.NUM_FLOWDIRECTION_TYPES;
	return ((dir + 3) % numTypes);
end

local opposedDirection = {
	[DirectionTypes.DIRECTION_NORTHEAST] 	= DirectionTypes.DIRECTION_SOUTHWEST,
	[DirectionTypes.DIRECTION_EAST] 		= DirectionTypes.DIRECTION_WEST,
	[DirectionTypes.DIRECTION_SOUTHEAST] 	= DirectionTypes.DIRECTION_NORTHWEST,
    [DirectionTypes.DIRECTION_SOUTHWEST] 	= DirectionTypes.DIRECTION_NORTHEAST,
	[DirectionTypes.DIRECTION_WEST] 		= DirectionTypes.DIRECTION_EAST,
	[DirectionTypes.DIRECTION_NORTHWEST] 	= DirectionTypes.DIRECTION_SOUTHEAST
	}
	
local DirectionString = {
	[DirectionTypes.DIRECTION_NORTHEAST] 	= "NORTHEAST",
	[DirectionTypes.DIRECTION_EAST] 		= "EAST",
	[DirectionTypes.DIRECTION_SOUTHEAST] 	= "SOUTHEAST",
    [DirectionTypes.DIRECTION_SOUTHWEST] 	= "SOUTHWEST",
	[DirectionTypes.DIRECTION_WEST] 		= "WEST",
	[DirectionTypes.DIRECTION_NORTHWEST] 	= "NORTHWEST"
	}

function IsEdgeRiver(self, edge)
	return (edge == DirectionTypes.DIRECTION_NORTHEAST 	and self:IsSWOfRiver()) 
		or (edge == DirectionTypes.DIRECTION_EAST 		and self:IsWOfRiver())
		or (edge == DirectionTypes.DIRECTION_SOUTHEAST 	and self:IsNWOfRiver())
		or (edge == DirectionTypes.DIRECTION_SOUTHWEST 	and self:IsNEOfRiver())
		or (edge == DirectionTypes.DIRECTION_WEST	 	and self:IsEOfRiver())
		or (edge == DirectionTypes.DIRECTION_NORTHWEST 	and self:IsSEOfRiver())
end

function GetNextClockRiverPlot(self, edge)
	local DEBUG_PLOT_SCRIPT			= false
	local nextPlotEdge 	= (edge + 3 + 1) % 6
	local nextPlot		= Map.GetAdjacentPlot(self:GetX(), self:GetY(), edge)
	Dprint( DEBUG_PLOT_SCRIPT, "- Testing : ", nextPlot:GetX(), nextPlot:GetY(), 				" river edge  = ", DirectionString[nextPlotEdge]); 		
	if nextPlot:IsEdgeRiver(nextPlotEdge) then return nextPlot, nextPlotEdge end
end

function GetNextCounterClockRiverPlot(self, edge)
	local DEBUG_PLOT_SCRIPT			= false
	local nextPlotEdge 	= (edge + 3 - 1) % 6
	local nextPlot		= Map.GetAdjacentPlot(self:GetX(), self:GetY(), edge)
	Dprint( DEBUG_PLOT_SCRIPT, "- Testing : ", nextPlot:GetX(), nextPlot:GetY(), 				" river edge  = ", DirectionString[nextPlotEdge]); 	
	if nextPlot:IsEdgeRiver(nextPlotEdge) then return nextPlot, nextPlotEdge end
end

function plotToNode(plot, edge)
	return tostring(plot:GetIndex()) .."," .. tostring(edge)
end

function nodeToPlot(node)
	local pos = string.find(node, ",")
	local plotIndex = tonumber(string.sub(node, 1 , pos -1))
	return Map.GetPlotByIndex(plotIndex)
end

function nodeToPlotEdge(node)
	local pos  = string.find(node, ",")
	local plotIndex = tonumber(string.sub(node, 1 , pos -1))
	local edge = tonumber(string.sub(node, pos +1))
	return Map.GetPlotByIndex(plotIndex), edge
end

function GetRiverPath(self, destPlot)
	local bFound = false
	local newPath
	for direction = 0, DirectionTypes.NUM_DIRECTION_TYPES - 1, 1 do
		if not bFound and self:IsEdgeRiver(direction) then
			newPath = self:GetRiverPathFromEdge(direction, destPlot)
			if newPath then bFound = true end
		end
	end
	return newPath
end

function GetRiverPathFromEdge(self, edge, destPlot)
	local DEBUG_PLOT_SCRIPT			= true

	if not self:IsRiver() or not destPlot:IsRiver() then return end	
	
	local startPlot	= self
	local closedSet = {}
	local openSet	= {}
	local comeFrom 	= {}
	local gScore	= {}
	local fScore	= {}
	
	local startNode	= plotToNode(startPlot, edge)
	
	Dprint( DEBUG_PLOT_SCRIPT, "CHECK FOR RIVER PATH BETWEEN : ", startPlot:GetX(), startPlot:GetY(), " edge direction = ", DirectionString[edge] ," and ", destPlot:GetX(), destPlot:GetY(), " distance = ", Map.GetPlotDistance(startPlot:GetX(), startPlot:GetY(), destPlot:GetX(), destPlot:GetY()) )
	
	function GetPath(currentNode)
		local path 		= {}
		local seen 		= {}
		local current 	= currentNode
		local count 	= 0
		while true do
			local prev = comeFrom[current]
			if prev == nil then break end
			local plot = nodeToPlot(current)
			local plotIndex = plot:GetIndex()
			-- filter the plots that are referenced in consecutive nodes as we are following the edges
			-- but if a path goes through 5 of the 6 edges, we add it twice for displaying the u-turn 
			if plot ~= prevPlot or count > 2 then 
				Dprint( DEBUG_PLOT_SCRIPT, "Adding to path : ", plot:GetX(), plot:GetY())
				table.insert(path, 1, plotIndex)
				prevPlot = plot
				count = 0
			else
				count = count + 1 
			end
			current = prev
		 end
		Dprint( DEBUG_PLOT_SCRIPT, "Adding Starting plot to path : ", startPlot:GetX(), startPlot:GetY())
		table.insert(path, 1, startPlot:GetIndex())
		return path
	end
	
	gScore[startNode]	= 0
	fScore[startNode]	= Map.GetPlotDistance(startPlot:GetX(), startPlot:GetY(), destPlot:GetX(), destPlot:GetY())
	
	local currentNode = startNode
	while currentNode do --and nodeToPlot(currentNode) ~= destPlot do
	
		local currentPlot 		= nodeToPlot(currentNode)
		closedSet[currentNode] 	= true
		
		if currentPlot == destPlot then
			Dprint( DEBUG_PLOT_SCRIPT, "Found a path, returning...")
			return GetPath(currentNode)
		end
		
		local neighbors = GetNeighbors(currentNode)
		for i, data in ipairs(neighbors) do
			local node = plotToNode(data.Plot, data.Edge)
			if not closedSet[node] then
				if gScore[node] == nil then
					local nodeDistance 		= Map.GetPlotDistance(data.Plot:GetX(), data.Plot:GetY(), currentPlot:GetX(), currentPlot:GetY())
					
					--[[
					for direction = 0, DirectionTypes.NUM_DIRECTION_TYPES - 1, 1 do
						if Map.GetAdjacentPlot(data.Plot:GetX(), data.Plot:GetY(), direction) then							
							local oppositeEdge		= (data.Edge + 3) % 6
							if data.Plot:IsEdgeRiver(data.Edge) and currentPlot:IsEdgeRiver(oppositeEdge) then nodeDistance = nodeDistance + 10; break end
						end
					end
					--]]
					if data.Plot:IsRiverCrossingToPlot(currentPlot) then nodeDistance = nodeDistance + 1.5 end
					local destDistance		= Map.GetPlotDistance(data.Plot:GetX(), data.Plot:GetY(), destPlot:GetX(), destPlot:GetY())
					local tentative_gscore 	= (gScore[currentNode] or math.huge) + nodeDistance
				
					table.insert (openSet, {Node = node, Score = tentative_gscore + destDistance})

					if tentative_gscore < (gScore[node] or math.huge) then
						local plot, edge = nodeToPlotEdge(node)
						Dprint( DEBUG_PLOT_SCRIPT, "New best : ", plot:GetX(), plot:GetY(), " edge direction = ", DirectionString[edge])
						comeFrom[node] = currentNode
						gScore[node] = tentative_gscore
						fScore[node] = tentative_gscore + destDistance
					end
				end				
			end		
		end
		table.sort(openSet, function(a, b) return a.Score > b.Score; end)
		local data = table.remove(openSet)
		if data then
			local plot, edge = nodeToPlotEdge(data.Node)
			Dprint( DEBUG_PLOT_SCRIPT, "Next to test : ", plot:GetX(), plot:GetY(), " edge direction = ", DirectionString[edge], data.Node, data.Score)
			currentNode = data.Node 
		else
			currentNode = nil
		end
	end
	Dprint( DEBUG_PLOT_SCRIPT, "failed to find a path")
end


function GetNeighbors(node)
	local DEBUG_PLOT_SCRIPT			= false
	Dprint( DEBUG_PLOT_SCRIPT, "Get neighbors :")
	local neighbors 				= {}
	local plot, edge 				= nodeToPlotEdge(node)
	local oppositeEdge				= (edge + 3) % 6
	local oppositePlot				= Map.GetAdjacentPlot(plot:GetX(), plot:GetY(), edge)
	local nextEdge 					= (edge + 1) % 6
	local prevEdge 					= (edge - 1) % 6
	
	-- Check next edge, same plot
	Dprint( DEBUG_PLOT_SCRIPT, "- Testing : ", plot:GetX(), plot:GetY(), " river edge  = ", DirectionString[nextEdge])
	if plot:IsEdgeRiver(nextEdge) then
		Dprint( DEBUG_PLOT_SCRIPT, "- Adding : ", plot:GetX(), plot:GetY(), " river edge  = ", DirectionString[nextEdge])
 		table.insert( neighbors, { Plot = plot, Edge = nextEdge } ) 
	end

	-- Check previous edge, same plot
	Dprint( DEBUG_PLOT_SCRIPT, "- Testing : ", plot:GetX(), plot:GetY(), " river edge  = ", DirectionString[prevEdge])
	if plot:IsEdgeRiver(prevEdge) then
		Dprint( DEBUG_PLOT_SCRIPT, "- Adding : ", plot:GetX(), plot:GetY(), " river edge  = ", DirectionString[prevEdge])
		table.insert( neighbors, { Plot = plot, Edge = prevEdge } ) 
	end

	-- Add Opposite plot, same edge
	--Dprint( DEBUG_PLOT_SCRIPT, "- Testing : ", oppositePlot:GetX(), oppositePlot:GetY(), " river edge  = ", DirectionString[oppositeEdge])
	--if oppositePlot:IsEdgeRiver(oppositeEdge) then
		Dprint( DEBUG_PLOT_SCRIPT, "- Adding : ", oppositePlot:GetX(), oppositePlot:GetY(), " river edge  = ", DirectionString[oppositeEdge])
		table.insert( neighbors, { Plot = oppositePlot, 	Edge = oppositeEdge } )
	--end
	
	-- Test diverging edge on next plot (clock direction)
	local clockPlot, clockEdge		= plot:GetNextClockRiverPlot(nextEdge)
	if clockPlot then
		Dprint( DEBUG_PLOT_SCRIPT, "- Adding : ", clockPlot:GetX(), clockPlot:GetY(), " river edge  = ", DirectionString[clockEdge])
		table.insert(neighbors, { Plot = clockPlot, Edge = clockEdge }	)
	end
	
	-- Test diverging edge on previous plot (counter-clock direction)
	local counterPlot, counterEdge	= plot:GetNextCounterClockRiverPlot(prevEdge)
	if counterPlot then 
		Dprint( DEBUG_PLOT_SCRIPT, "- Adding : ", counterPlot:GetX(), counterPlot:GetY(), " river edge  = ", DirectionString[counterEdge])
		table.insert(neighbors, { Plot = counterPlot, 	Edge = counterEdge }) 
	end
	
	return neighbors
end

-----------------------------------------------------------------------------------------
-- UI Functions
-----------------------------------------------------------------------------------------
--ContextPtr:RequestRefresh()


-----------------------------------------------------------------------------------------
-- Shared Functions
-----------------------------------------------------------------------------------------
function GetPlotByIndex(index) -- return a plot with PlotScript functions for another context
	local plot = Map.GetPlotByIndex(index)
	InitializePlotFunctions(plot)
	return plot
end

function GetPlot(x, y) -- return a plot with PlotScript functions for another context
	local plot = Map.GetPlot(x, y)
	InitializePlotFunctions(plot)
	return plot
end


-----------------------------------------------------------------------------------------
-- Initialize Plot Functions
-----------------------------------------------------------------------------------------
function InitializePlotFunctions(plot) -- Note that those functions are limited to this file context

	if not plot then plot = Map.GetPlot(1,1) end
	local p = getmetatable(plot).__index
	
	p.IsImprovementPillaged			= GCO.PlotIsImprovementPillaged -- not working ?
	
	p.GetKey						= GetKey
	p.GetTotalCulture 				= GetTotalCulture
	p.GetCulturePercent				= GetCulturePercent
	p.GetCulturePercentTable		= GetCulturePercentTable
	p.DoConquestCountDown 			= DoConquestCountDown
	p.GetConquestCountDown 			= GetConquestCountDown
	p.SetConquestCountDown 			= SetConquestCountDown
	p.GetCultureTable				= GetCultureTable
	p.GetCulture 					= GetCulture
	p.SetCulture 					= SetCulture
	p.ChangeCulture 				= ChangeCulture
	p.GetPreviousCulture 			= GetPreviousCulture
	p.SetPreviousCulture 			= SetPreviousCulture
	p.GetHighestCulturePlayer 		= GetHighestCulturePlayer
	p.GetTotalPreviousCulture		= GetTotalPreviousCulture
	p.IsLockedByWarForPlayer		= IsLockedByWarForPlayer
	p.IsLockedByFortification		= IsLockedByFortification
	p.IsLockedByCitadelForPlayer 	= IsLockedByCitadelForPlayer
	p.GetPotentialOwner				= GetPotentialOwner
	p.UpdateCulture					= UpdateCulture
	p.UpdateOwnership				= UpdateOwnership
	p.DiffuseCulture				= DiffuseCulture
	--
	p.IsEOfRiver					= IsEOfRiver
	p.IsSEOfRiver					= IsSEOfRiver
	p.IsSWOfRiver					= IsSWOfRiver
	p.IsFollowingRiverTo			= IsFollowingRiverTo	-- not reliable
	p.IsEdgeRiver					= IsEdgeRiver
	p.GetNextClockRiverPlot			= GetNextClockRiverPlot
	p.GetNextCounterClockRiverPlot	= GetNextCounterClockRiverPlot
	p.GetRiverPath					= GetRiverPath
	p.GetRiverPathFromEdge			= GetRiverPathFromEdge

end


----------------------------------------------
-- Share functions for other contexts
----------------------------------------------
function Initialize()
	if not ExposedMembers.GCO then ExposedMembers.GCO = {} end
	ExposedMembers.GCO.GetPlotByIndex 			= GetPlotByIndex
	ExposedMembers.GCO.GetPlot 					= GetPlot
	ExposedMembers.GCO.InitializePlotFunctions 	= InitializePlotFunctions
	--
	ExposedMembers.GCO.GetPlotFromKey 			= GetPlotFromKey
	ExposedMembers.GCO.GetRiverPath				= GetRiverPath
	--
	ExposedMembers.PlotScript_Initialized 		= true
end
Initialize()