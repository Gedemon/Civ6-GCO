-----------------------------------------------------------------------------------------
--	FILE:	 ContextFunctions.lua
--  Gedemon (2017)
-----------------------------------------------------------------------------------------

--=================================================
-- Initialize UI context function
-- to use them in scripts
--=================================================

----------------------------------------------
-- defines
----------------------------------------------


----------------------------------------------
-- Initialize Functions
----------------------------------------------

local GCO = ExposedMembers.GCO -- Initialize with what is already loaded from script contexts, we may need them before the next call to GameCoreEventPublishComplete after this file is loaded
function InitializeUtilityFunctions() -- Get functions from other contexts
	if ExposedMembers.IsInitializedGCO and ExposedMembers.IsInitializedGCO() then 
		GCO = ExposedMembers.GCO -- Reinitialize with what may have been added with other UI contexts
		Events.GameCoreEventPublishComplete.Remove( InitializeUtilityFunctions )
		print ("Exposed Functions from other contexts initialized...")
	end
end
Events.GameCoreEventPublishComplete.Add( InitializeUtilityFunctions )


----------------------------------------------
-- Cities functions
----------------------------------------------

function GetCityCultureYield(plot)
	local contextCity = Cities.GetCityInPlot(plot:GetX(), plot:GetY())
	if not contextCity then return 0 end
	local cityCulture = contextCity:GetCulture()
	if cityCulture then
		return cityCulture:GetCultureYield()
	else
		return 0
	end
end
-- to do ? 
--[[

	get local c = getmetatable(city).__index on event city added to map
	then use ExposedMembers.GCO.City.GetCulture	= c.GetCulture in scripts that requires it

--]]


----------------------------------------------
-- Players functions
----------------------------------------------

function HasPlayerOpenBordersFrom(Player, otherPlayerID)
	local contextPlayer = Players[Player:GetID()]
	return contextPlayer:GetDiplomacy():HasOpenBordersFrom( otherPlayerID )
end


----------------------------------------------
-- Plots functions
----------------------------------------------

function IsImprovementPillaged(plot)
	local contextPlot = Map.GetPlot(plot:GetX(), plot:GetY()) -- Can't use the plot from a script context in the UI context.
	return contextPlot:IsImprovementPillaged()
end


----------------------------------------------
-- Units functions
----------------------------------------------
function GetMoveToPath( unit, plotIndex )
	local contextUnit = UnitManager.GetUnit(unit:GetOwner(), unit:GetID())
	return UnitManager.GetMoveToPath( contextUnit, plotIndex )
end


----------------------------------------------
-- Initialize functions for other contexts
----------------------------------------------

ExposedMembers.ContextFunctions_Initialized = false

function Initialize()
	if not ExposedMembers.GCO then ExposedMembers.GCO = {} end	
	
	-- cities
	ExposedMembers.GCO.GetCityCultureYield 			= GetCityCultureYield
	-- players
	ExposedMembers.GCO.HasPlayerOpenBordersFrom 	= HasPlayerOpenBordersFrom
	-- plots
	local p = getmetatable(Map.GetPlot(1,1)).__index
	ExposedMembers.GCO.PlotIsImprovementPillaged	= p.IsImprovementPillaged -- attaching this in script context doesn't work as the plot object from script miss other elements required for this by the plot object in UI context 
	ExposedMembers.GCO.IsImprovementPillaged 		= IsImprovementPillaged
	-- units
	ExposedMembers.GCO.GetMoveToPath				= GetMoveToPath
	-- others
	ExposedMembers.UI 								= UI
	ExposedMembers.CombatTypes 						= CombatTypes
	
	ExposedMembers.ContextFunctions_Initialized 	= true
end
Initialize()
