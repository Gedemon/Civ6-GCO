-----------------------------------------------------------------------------------------
--	FILE:	 SaveLoad.lua
--  Gedemon (2017)
--  Loading/Saving simple tables with the game file using Pickle Table for serialization
--  http://lua-users.org/wiki/PickleTable
-----------------------------------------------------------------------------------------




--=================================================
-- Load / Save
-- Using Civ6 GameConfiguration
--=================================================
--[[
usage:
> ExposedMembers.SaveTableToSlot(t, "myTable")
> t = ExposedMembers.LoadTableFromSlot("myTable")

--]]
--=================================================

----------------------------------------------
-- defines
----------------------------------------------


----------------------------------------------
-- Initialize Functions
----------------------------------------------

local GCO = ExposedMembers.GCO -- Initialize with what is already loaded from script contexts, we may need them before the next call to GameCoreEventPublishComplete after this file is loaded
function InitializeUtilityFunctions() -- Get functions from other contexts
	if ExposedMembers.Utils_Initialized and ExposedMembers.SaveLoad_Initialized and ExposedMembers.binser_Initialized then 
		GCO = ExposedMembers.GCO -- Reinitialize with what may have been added with other UI contexts
		Events.GameCoreEventPublishComplete.Remove( InitializeUtilityFunctions )
		print ("Exposed Functions from other contexts initialized...")
	end
end
Events.GameCoreEventPublishComplete.Add( InitializeUtilityFunctions )

----------------------------------------------
-- events for saving
----------------------------------------------
-- this Lua event is called when listing files on the save/load menu
function SaveMyTables()
	LuaEvents.SaveTables()
end
LuaEvents.FileListQueryComplete.Add( SaveMyTables )

function SaveOnBarbarianTurnEnd(playerID)
	local player = Players[playerID]
	if player:IsBarbarian() then
		LuaEvents.SaveTables()
	end
end
Events.RemotePlayerTurnEnd.Add( SaveOnBarbarianTurnEnd )

-- could get the quicksave key here
function OnInputHandler( pInputStruct:table )
	local uiMsg = pInputStruct:GetMessageType();
	if uiMsg == KeyEvents.KeyDown then
		if pInputStruct:GetKey() == Keys.VK_F5 then -- but the binding can be changed...
			LuaEvents.SaveTables()
		end
	end
	-- pInputStruct:IsShiftDown() and pInputStruct:IsAltDown()
end
ContextPtr:SetInputHandler( OnInputHandler, true )

-- Or on this event for quick save (but is it called soon enough before saving ?)
function OnInputAction( actionID )
	if actionID == Input.GetActionId("QuickSave") then
		LuaEvents.SaveTables()
	end
end
Events.InputActionTriggered( OnInputAction )


----------------------------------------------
-- load/save
----------------------------------------------
-- save
function SaveTableToSlot(t, sSlotName)
	GCO.StartTimer("serialize")
	local startTime = Automation.GetTime()
	if type(t) ~= "table" then 
		print("ERROR: SaveTableToSlot(t, sSlotName), parameter #1 must be a table, nothing saved to slot ".. tostring(sSlotName))
		return
	end
	if type(sSlotName) ~= "string" then 
		print("ERROR: SaveTableToSlot(t, sSlotName), parameter #2 must be a string, the table wasn't saved")
		return
	end
	
	local s = GCO.serialize(t)
	local size = string.len(s)
	GameConfiguration.SetValue(sSlotName, s)
	GCO.ShowTimer("serialize")
	GCO.Dprint("GCO.serialize(t) : SaveTableToSlot for slot " .. tostring(sSlotName) .. ", table size = " .. tostring(GCO.GetSize(t)) .. ", serialized size = " .. tostring(size))

	-- test saved value
	---[[
	do
		GCO.StartTimer("deserialize")
		local s2 = GameConfiguration.GetValue(sSlotName)
		local size2 = string.len(s2)
		if s2 ~= s then
			GCO.Dprint("ERROR: GameConfiguration.GetValue doesn't return the same string that was set in GameConfiguration.SetValue for slot " ..tostring(sSlotName))
			GCO.Dprint("ERROR: String to save length = " .. tostring(size).. ", saved string length = " .. tostring(size2))
			GCO.Dprint("----------------------------------------------------------------------------------------------------------------------------------------")
			GCO.Dprint(s)
			GCO.Dprint("----------------------------------------------------------------------------------------------------------------------------------------")
			GCO.Dprint(s2)
			GCO.Dprint("----------------------------------------------------------------------------------------------------------------------------------------")
		end
		local t2 = GCO.deserialize(s2)
		GCO.ShowTimer("deserialize")
		GCO.Dprint("GCO.deserialize(t) : LoadTableFromSlot for slot " .. tostring(sSlotName) .. ", table size = " .. tostring(GCO.GetSize(t2)) .. ", serialized size = " .. tostring(size2))
	end
	--]]
	
	-- test other serializers
	--[[
	do	
		GCO.Dprint("------------------------------")
		GCO.StartTimer("serialize2")
		local s = GCO.serialize2(t)
		local size = string.len(s)
		GameConfiguration.SetValue("test", s)
		local sCheck = GameConfiguration.GetValue("test")
		if sCheck ~= s then
			GCO.Dprint("ERROR: GameConfiguration.GetValue doesn't return the same string that was set in GameConfiguration.SetValue for slot " ..tostring("test"))
			GCO.Dprint("ERROR: String to save length = " .. tostring(size).. ", saved string length = " .. tostring(string.len(sCheck)))
			GCO.Dprint("----------------------------------------------------------------------------------------------------------------------------------------")
			GCO.Dprint(s)
			GCO.Dprint("----------------------------------------------------------------------------------------------------------------------------------------")
			GCO.Dprint(sCheck)
			GCO.Dprint("----------------------------------------------------------------------------------------------------------------------------------------")
		end
		GCO.ShowTimer("serialize2")
		GCO.Dprint("GCO.serialize2(t) : SaveTableToSlot for slot " .. tostring("test") .. ", table size = " .. tostring(GCO.GetSize(t)) .. ", serialized size = " .. tostring(size))	

		GCO.StartTimer("deserialize2")
		local s2 = GameConfiguration.GetValue("test")
		local size2 = string.len(s2)
		local t2 = GCO.deserialize2(s2)
		GCO.ShowTimer("deserialize2")
		GCO.Dprint("GCO.deserialize2(t) : LoadTableFromSlot for slot " .. tostring("test") .. ", table size = " .. tostring(GCO.GetSize(t2)) .. ", serialized size = " .. tostring(size2))		
		GCO.Dprint("------------------------------")
	end
	--]]
	
end

-- load
function LoadTableFromSlot(sSlotName)
	if not GameConfiguration.GetValue then
		print("ERROR: GameConfiguration.GetValue is null when trying to load from slot ".. tostring(sSlotName))
	end
	GCO.StartTimer("GameConfiguration.GetValue")
	local s = GameConfiguration.GetValue(sSlotName)
	GCO.ShowTimer("GameConfiguration.GetValue")
	if s then	
		local size = string.len(s)
		GCO.StartTimer("GCO.deserialize(s)")
		local t = GCO.deserialize(s)		
		GCO.ShowTimer("GCO.deserialize(s)")
		GCO.Dprint("GCO.deserialize(s) : LoadTableFromSlot for slot " .. tostring("sSlotName") .. ", table size = " .. tostring(GCO.GetSize(t)) .. ", serialized size = " .. tostring(size))	

		-- test other serializers
		--[[
		GCO.Dprint("------------------------------")
		GCO.StartTimer("GCO.deserialize2(s)")
		local test = GameConfiguration.GetValue("test")
		local u = GCO.deserialize2(test)		
		GCO.ShowTimer("GCO.deserialize2(s)")
		GCO.Dprint("GCO.deserialize2(s) : LoadTableFromSlot for slot " .. tostring("test") .. ", table size = " .. tostring(GCO.GetSize(u)) .. ", serialized size = " .. tostring(size))
		GCO.Dprint("------------------------------")		
		--]]
		
		return t
	else
		print("WARNING: No saved data table in slot ".. tostring(sSlotName) .." (this happens when initializing the table, you can ignore this warning when launching a new game)") 
	end
end

----------------------------------------------
-- Create functions for other contexts
----------------------------------------------

function GetCityCultureYield(plot)
	local city = Cities.GetCityInPlot(plot:GetX(), plot:GetY())
	if not city then return 0 end
	local cityCulture = city:GetCulture()
	if cityCulture then
		return cityCulture:GetCultureYield()
	else
		return 0
	end
end
-- to do
--[[

	get local c = getmetatable(city).__index on event city added to map
	then use ExposedMembers.GCO.City.GetCulture	= c.GetCulture in scripts that requires it

--]]

----------------------------------------------
-- Initialize functions for other contexts
----------------------------------------------

ExposedMembers.SaveLoad_Initialized = false

function Initialize()
	if not ExposedMembers.GCO then ExposedMembers.GCO = {} end
	
	-- UI only objects that we may use in script...
	local p = getmetatable(Map.GetPlot(1,1)).__index
	ExposedMembers.GCO.PlotIsImprovementPillaged	= p.IsImprovementPillaged
	ExposedMembers.GCO.GetCityCultureYield 			= GetCityCultureYield
	ExposedMembers.UI 								= UI
	ExposedMembers.CombatTypes 						= CombatTypes
	
	-- Load / Save
	ExposedMembers.GCO.SaveTableToSlot 				= SaveTableToSlot
	ExposedMembers.GCO.LoadTableFromSlot 			= LoadTableFromSlot	
	ExposedMembers.SaveLoad_Initialized 			= true
end
Initialize()
