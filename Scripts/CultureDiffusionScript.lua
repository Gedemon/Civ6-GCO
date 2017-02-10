--=====================================================================================--
--	FILE:	 CultureDiffusionScript.lua
--  Gedemon (2017)
--=====================================================================================--

print ("Loading CultureDiffusionScript.lua...")

-----------------------------------------------------------------------------------------
-- Defines
-----------------------------------------------------------------------------------------

local SEPARATIST = 64
ExposedMembers.CultureMap = {}

-----------------------------------------------------------------------------------------
-- Initialize Functions
-----------------------------------------------------------------------------------------

local GCO = {}
function InitializeUtilityFunctions() 	-- Get functions from other contexts
	if ExposedMembers.SaveLoad_Initialized and ExposedMembers.Utils_Initialized then
		GCO = ExposedMembers.GCO		-- contains functions from other contexts
		Events.GameCoreEventPublishComplete.Remove( InitializeUtilityFunctions )
		print ("Exposed Functions from other contexts initialized...")
		InitializePlotFunctions()
	end
end
Events.GameCoreEventPublishComplete.Add( InitializeUtilityFunctions )

-----------------------------------------------------------------------------------------
-- Get Functions
-----------------------------------------------------------------------------------------

function GetPlotKey ( self )
	local x = self:GetX()
	local y = self:GetY()
	return x..","..y
end

function GetPlotTotalCulture( self )
	local totalCulture = 0
	local plotCulture = ExposedMembers.CultureMap[self:GetKey()]
	if  plotCulture then
		for playerID, value in pairs (plotCulture) do
			totalCulture = totalCulture + value			
		end
	end
	return totalCulture
end

function GetPlotCulturePercent( self )
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


function InitializePlotFunctions() -- Note that those functions are limited to this file context
	local p = getmetatable(Map.GetPlot(1,1)).__index
	p.GetKey			= GetPlotKey
	p.GetTotalCulture 	= GetPlotTotalCulture
	p.GetCulturePercent	= GetPlotCulturePercent
end
