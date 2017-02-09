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
	end
end
Events.GameCoreEventPublishComplete.Add( InitializeUtilityFunctions )

-----------------------------------------------------------------------------------------
-- Get Functions
-----------------------------------------------------------------------------------------

function GetPlotTotalCulture( plotKey )
	local totalCulture = 0
	local plotCulture = ExposedMembers.CultureMap[plotKey]
	if  plotCulture then
		for playerID, value in pairs (plotCulture) do
			totalCulture = totalCulture + value			
		end
	end
	return totalCulture
end

function GetPlotCulturePercent( plotKey )
	-- return a table with civs culture % for a plot in cultureMap and the total culture
	local plotCulturePercent = {}
	local totalCulture = GetPlotTotalCulture( plotKey )
	local plotCulture = ExposedMembers.CultureMap[plotKey]
	if  plotCulture and totalCulture > 0 then
		for playerID, value in pairs (plotCulture) do
			plotCulturePercent[playerID] = (value / totalCulture * 100)
		end
	end
	return plotCulturePercent, totalCulture
end