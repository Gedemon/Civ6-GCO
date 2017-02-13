--=====================================================================================--
--	FILE:	 CultureDiffusionScript.lua
--  Gedemon (2017)
--=====================================================================================--

print ("Loading CultureDiffusionScript.lua...")

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
ExposedMembers.CultureMap 			= {}
ExposedMembers.PreviousCultureMap 	= {}

-----------------------------------------------------------------------------------------
-- Initialize Globals Functions
-----------------------------------------------------------------------------------------

local GCO = {}
function InitializeUtilityFunctions() 	-- Get functions from other contexts
	if ExposedMembers.SaveLoad_Initialized and ExposedMembers.Utils_Initialized then
		GCO = ExposedMembers.GCO		-- contains functions from other contexts
		Events.GameCoreEventPublishComplete.Remove( InitializeUtilityFunctions )
		print ("Exposed Functions from other contexts initialized...")
		ExposedMembers.CultureMap 			= GCO.LoadTableFromSlot("CultureMap") or {}
		ExposedMembers.PreviousCultureMap 	= GCO.LoadTableFromSlot("PreviousCultureMap") or {}
		InitializePlotFunctions()
		SetCultureDiffusionRatePer1000()
	end
end
Events.GameCoreEventPublishComplete.Add( InitializeUtilityFunctions )

function SaveTables()
	print("--------------------------- CultureMap ---------------------------")
	GCO.StartTimer("CultureMap")
	GCO.SaveTableToSlot(ExposedMembers.CultureMap, "CultureMap")
	GCO.SaveTableToSlot(ExposedMembers.PreviousCultureMap, "PreviousCultureMap")
	GCO.ShowTimer("CultureMap")
end
LuaEvents.SaveTables.Add(SaveTables)

-----------------------------------------------------------------------------------------
-- Plots Functions
-----------------------------------------------------------------------------------------

function GetKey ( self )
	return tostring(self:GetIndex())
end

-----------------------------------------------------------------------------------------
-- C++ converted Functions
-----------------------------------------------------------------------------------------

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

function GetCulture( self, playerID )
	local plotCulture = ExposedMembers.CultureMap[self:GetKey()]
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
	local plotCulture = ExposedMembers.CultureMap[self:GetKey()]
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
	local plotCulture = ExposedMembers.CultureMap[self:GetKey()]
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
	local plotCulture = ExposedMembers.CultureMap[self:GetKey()]
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
		if ( improvementType ~= NO_IMPROVEMENT) and (not self:IsImprovementPillaged()) then		
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
				if ( improvementType ~= NO_IMPROVEMENT) and (not self:IsImprovementPillaged()) then		
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
	local plotCulture = ExposedMembers.CultureMap[self:GetKey()]
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

function UpdateCulture( self )
	-- No culture on water
	if self:IsWater() then
		return
	end
	
	-- Decay
	local plotCulture = ExposedMembers.CultureMap[self:GetKey()]
	if plotCulture then
		for playerID, value in pairs (plotCulture) do
			
			-- Apply decay
			if value > 0 then
				local minValueOwner = tonumber(GameInfo.GlobalParameters["CULTURE_MINIMAL_ON_OWNED_PLOT"].Value)
				local decay = math.max(1, GCO.Round(value * tonumber(GameInfo.GlobalParameters["CULTURE_DECAY_RATE"].Value) / 100))
				if (value - decay) <= 0 then
					if self:GetOwner() == playerID then
						self:SetCulture(playerID, minValueOwner)
					else -- don't remove yet, to show variation with previous turn
						self:SetCulture(playerID, 0)
					end
				else
					if self:GetOwner() == playerID and (value - decay) < minValueOwner then
						self:SetCulture(playerID, minValueOwner)
					else
						self:ChangeCulture(playerID, -decay)
					end					
				end
			else -- remove dead culture
				ExposedMembers.CultureMap[self:GetKey()][tostring(playerID)] = nil
			end
		end
	end
	
	-- diffuse culture on adjacent plots
	if self:GetTotalCulture() > tonumber(GameInfo.GlobalParameters["CULTURE_DIFFUSION_THRESHOLD"].Value) then
		self:DiffuseCulture()
	end
	
	-- update culture in cities
	if self:IsCity() then
		local city = Cities.GetCityInPlot(self:GetX(), self:GetY())
		--local cityCulture = city:GetCulture()
		
		-- Culture creation in cities
		local baseCulture = tonumber(GameInfo.GlobalParameters["CULTURE_CITY_BASE_PRODUCTION"].Value)
		local maxCulture = (city:GetPopulation() + GCO.GetCityCultureYield(self)) * tonumber(GameInfo.GlobalParameters["CULTURE_CITY_CAPED_FACTOR"].Value)
		if self:GetTotalCulture() < maxCulture then -- don't add culture if above max, the excedent will decay each turn
			if plotCulture then
				for playerID, value in pairs (plotCulture) do
					if value > 0 then
						local cultureAdded = 0
						if playerID == city:GetOwner() then
							if tonumber(GameInfo.GlobalParameters["CULTURE_OUTPUT_USE_LOG"].Value) > 0 then
								cultureAdded = GCO.Round((city:GetPopulation() + GCO.GetCityCultureYield(self)) * math.log( value * tonumber(GameInfo.GlobalParameters["CULTURE_CITY_FACTOR"].Value) ,10))
							else
								cultureAdded = GCO.Round((city:GetPopulation() + GCO.GetCityCultureYield(self)) * math.sqrt( value * tonumber(GameInfo.GlobalParameters["CULTURE_CITY_RATIO"].Value)))
							end						
						else
							if tonumber(GameInfo.GlobalParameters["CULTURE_OUTPUT_USE_LOG"].Value) > 0 then
								cultureAdded = GCO.Round(city:GetPopulation() * math.log( value * tonumber(GameInfo.GlobalParameters["CULTURE_CITY_FACTOR"].Value) ,10))
							else
								cultureAdded = GCO.Round(city:GetPopulation() * math.sqrt( value * tonumber(GameInfo.GlobalParameters["CULTURE_CITY_RATIO"].Value)))
							end						
						end
						cultureAdded = cultureAdded + baseCulture
						print(city:GetName(), city:GetPopulation(), GCO.GetCityCultureYield(self), value, math.log( value * tonumber(GameInfo.GlobalParameters["CULTURE_CITY_FACTOR"].Value) ,10), math.sqrt( value * tonumber(GameInfo.GlobalParameters["CULTURE_CITY_RATIO"].Value)), baseCulture, cultureAdded)
						self:ChangeCulture(playerID, cultureAdded)						
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
	end
	
	-- Todo : improvements/units can affect culture
	
	-- Update Ownership
	if tonumber(GameInfo.GlobalParameters["CULTURE_ALLOW_TILE_ACQUISITION"].Value) > 0 or tonumber(GameInfo.GlobalParameters["CULTURE_ALLOW_TILE_FLIPPING"].Value) > 0 then
		--self:UpdateOwnership()
	end
	
	-- Update locked plot
	if tonumber(GameInfo.GlobalParameters["CULTURE_CONQUEST_ENABLED"].Value) > 0 then
		self:DoConquestCountDown()
	end
	
end
function UpdateOwnership( self )

	-- cities do not flip without Revolutions...
	if self:IsCity() then return end
	
	-- if plot is locked, don't try to change ownership...
	if (self:GetConquestCountDown() > 0) then return end
	
	-- 	check if fortifications on this plot are preventing tile flipping...
	if (self:IsLockedByFortification()) then return	end
	
	-- Get potential owner
	local bestPlayerID = self:GetPotentialOwner()
	if (bestPlayerID == NO_OWNER) then
		return
	end
	local bestValue = self:GetCulture(bestPlayerID)
	
	if (bestPlayerID ~= self:GetOwner()) and (bestValue > GetCultureMinimumForAcquisition( bestPlayerID )) then
	
		-- Do we allow tile flipping when at war ?		
		if (self:IsLockedByWarForPlayer(bestPlayerID)) then return end
		
		-- check if an adjacent fortification can prevent tile flipping...
		if (self:IsLockedByCitadelForPlayer(bestPlayerID)) then return end
		
		-- case 1: the tile was not owned and tile acquisition is allowed
		local bAcquireNewPlot = (self:GetOwner() == NO_OWNER and tonumber(GameInfo.GlobalParameters["CULTURE_ALLOW_TILE_ACQUISITION"].Value) > 0)
		
		-- case 2: tile flipping is allowed and the ratio between the old and the new owner is high enough
		local bConvertPlot = (tonumber(GameInfo.GlobalParameters["CULTURE_ALLOW_TILE_FLIPPING"].Value) > 0 and (bestValue * tonumber(GameInfo.GlobalParameters["CULTURE_FLIPPING_RATIO"].Value)/100) > self:GetCulture(self:GetOwner()))

		if bAcquireNewPlot or bConvertPlot then
			local city, distance = FindNearestPlayerCity(bestPlayerID, self:GetX(), self:GetY())
			if not city then return end
			
			-- Is the plot too far away ?
			if distance > GetCultureFlippingMaxDistance(bestPlayerID) then return end
			
			-- All test passed succesfully, notify the players and change owner...
			-- to do : notify the players...
			self:SetOwner(bestPlayerID, city:GetId(), true)		
		end	
	end	
end

function DiffuseCulture( self )

	local iX = self:GetX()
	local iY = self:GetY()
	local iCultureValue 	= self:GetTotalCulture()
	local iPlotBaseMax 		= iCultureValue * tonumber(GameInfo.GlobalParameters["CULTURE_NORMAL_MAX_PERCENT"].Value) / 100
	for direction = 0, DirectionTypes.NUM_DIRECTION_TYPES - 1, 1 do
		local pAdjacentPlot = Map.GetAdjacentPlot(iX, iY, direction)
		if (not pAdjacentPlot:IsWater()) then
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
			print(iX, iY, direction, bIsRoute, bIsFollowingRiver, bIsCrossingRiver, terrainType, terrainThreshold, terrainPenalty, terrainMaxPercent, featureType)
			-- Bonus: following road
			if (bIsRoute) then
				iBonus 		= iBonus + iRoadBonus
				iPlotMax 	= iPlotMax * iRoadMax / 100
			end
			
			-- Bonus: following a river
			if (bIsFollowingRiver) then
				iBonus 		= iBonus + iFollowingRiverBonus
				iPlotMax 	= iPlotMax * iFollowingRiverMax / 100
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
					else
						bSkip = true -- no diffusion on that plot
					end
				end
			end
			
			-- Penalty: terrain
			if not bSkip then
				if terrainPenalty > 0 then
					if iCultureValue > terrainThreshold * iBaseThreshold / 100 then
						iPenalty 	= iPenalty + terrainPenalty
						iPlotMax 	= iPlotMax * terrainMaxPercent / 100
					else
						bSkip = true -- no diffusion on that plot
					end
				end			
			end
			
			-- Penalty: crossing river
			if not bSkip then
				if iCrossingRiverPenalty > 0 then
					if iCultureValue > iCrossingRiverThreshold * iBaseThreshold / 100 then
						iPenalty 	= iPenalty + iCrossingRiverPenalty
						iPlotMax 	= iPlotMax * iCrossingRiverMax / 100
					else
						bSkip = true -- no diffusion on that plot
					end
				end			
			end
			
			if not bSkip then
				iPlotMax = math.min(iPlotMax, iCultureValue * tonumber(GameInfo.GlobalParameters["CULTURE_ABSOLUTE_MAX_PERCENT"].Value) / 100)
				-- Apply Culture diffusion to all culture groups
				local plotCulture = ExposedMembers.CultureMap[self:GetKey()] -- this should never be nil at this point
				for playerID, value in pairs (plotCulture) do
				
					local iPlayerPlotMax = iPlotMax * self:GetCulturePercent(playerID) / 100
					local iPlayerDiffusedCulture = (self:GetCulture(playerID) * (iDiffusionRatePer1000 + (iDiffusionRatePer1000 * iBonus / 100))) / (1000 + (1000 * iPenalty / 100))
					local iPreviousCulture = pAdjacentPlot:GetCulture(playerID);
					local iNextculture = math.min(iPlayerPlotMax, iPreviousCulture + iPlayerDiffusedCulture);
					print("DiffuseCulture", pAdjacentPlot:GetX(), pAdjacentPlot:GetY(), playerID, GCO.ToDecimals(iDiffusionRatePer1000), GCO.ToDecimals(iPlayerPlotMax), GCO.ToDecimals(iPlayerDiffusedCulture), GCO.ToDecimals(iPreviousCulture), GCO.ToDecimals(iNextculture), GCO.ToDecimals(self:GetCulture(playerID)), GCO.ToDecimals(iBonus), GCO.ToDecimals(iPenalty) )
					
					iPlayerDiffusedCulture = iNextculture - iPreviousCulture
					if (iPlayerDiffusedCulture > 0) then -- can be < 0 when a plot try to diffuse to another with a culture value already > at the calculated iPlayerPlotMax...
						pAdjacentPlot:ChangeCulture(playerID, iPlayerDiffusedCulture)
					end
				end				
			end
		end
	end
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
		local plotCulture = ExposedMembers.CultureMap[plot:GetKey()]
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
	print("-----------------------------------------------------------------------------------------")
	GCO.ShowTimer("Culture Diffusion")
	print("-----------------------------------------------------------------------------------------")
end
Events.TurnBegin.Add(OnNewTurn)

-----------------------------------------------------------------------------------------
-- Initialize Plot Functions
-----------------------------------------------------------------------------------------

function InitializePlotFunctions() -- Note that those functions are limited to this file context
	local p = getmetatable(Map.GetPlot(1,1)).__index
	
	p.IsImprovementPillaged			= GCO.PlotIsImprovementPillaged 
	
	p.GetKey						= GetKey
	p.GetTotalCulture 				= GetTotalCulture
	p.GetCulturePercent				= GetCulturePercent
	p.DoConquestCountDown 			= DoConquestCountDown
	p.GetConquestCountDown 			= GetConquestCountDown
	p.SetConquestCountDown 			= SetConquestCountDown
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
	
end