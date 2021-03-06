-----------------------------------------------------------------------------------------
--	FILE:	 GCO_SaveLoad.lua
--  Gedemon (2017)
-----------------------------------------------------------------------------------------


print ("Loading SaveLoad.lua...")

--==================================================================================================
-- Load / Save
-- Using Civ6 GameConfiguration, require functions from Serialize.lua
-- This is an InGame context because GameConfiguration.SetValue is nil in scripts context
--==================================================================================================
--[[
usage:
> ExposedMembers.GCO.SaveTableToSlot(t, "myTable")
> t = ExposedMembers.GCO.LoadTableFromSlot("myTable")

--]]
--==================================================================================================

----------------------------------------------
-- Defines
----------------------------------------------

DEBUG_SAVELOAD_SCRIPT	= "SaveLoadScript"

----------------------------------------------
-- Initialize Functions
----------------------------------------------
-- Initialize immediatly with what is already loaded from script contexts, we may need them before InitializeUtilityFunctions can be called
local GCO 			= ExposedMembers.GCO 
local GameEvents	= ExposedMembers.GameEvents
----local LuaEvents		= ExposedMembers.LuaEvents
function InitializeUtilityFunctions() -- Get functions from other contexts
	--GCO 		= ExposedMembers.GCO		-- Reinitialize with what may have been added with other UI contexts
	Dprint 		= GCO.Dprint				-- Dprint(bOutput, str) : print str if bOutput is true
	Dline		= GCO.Dline					-- output current code line number to firetuner/log
	Dlog		= GCO.Dlog					-- log a string entry, last 10 lines displayed after a call to GCO.Error()
	print ("Exposed Functions from other contexts initialized...")
end
GameEvents.InitializeGCO.Add( InitializeUtilityFunctions )

----------------------------------------------
-- Events for saving
----------------------------------------------
-- This Lua event is called when listing files on the save/load menu
function SaveMyTables()
	GCO.Dprint( DEBUG_SAVELOAD_SCRIPT, "Calling GameEvents.SaveTables() on FileListQueryComplete...")
	GameEvents.SaveTables.Call()
end
LuaEvents.FileListQueryComplete.Add( SaveMyTables )

-- This event to handle quick saving
function OnInputAction( actionID )
	if actionID == Input.GetActionId("QuickSave") then
		GCO.Dprint( DEBUG_SAVELOAD_SCRIPT, "Calling GameEvents.SaveTables() on QuickSave action...")
		GameEvents.SaveTables.Call()
	end
end
Events.InputActionTriggered.Add( OnInputAction )


----------------------------------------------
-- load/save
----------------------------------------------
-- save
function SaveTableToSlot(t, sSlotName)
	GCO.StartTimer("Serialize and Save "..sSlotName)
	if type(t) ~= "table" then 
		GCO.Error("SaveTableToSlot(t, sSlotName), parameter #1 must be a table, nothing saved to slot ".. tostring(sSlotName))
		return
	end
	if type(sSlotName) ~= "string" then 
		GCO.Error("SaveTableToSlot(t, sSlotName), parameter #2 must be a string, the table wasn't saved")
		return
	end
	
	local s = GCO.serialize(t)
	local size = string.len(s)
	GameConfiguration.SetValue(sSlotName, s)
	GCO.ShowTimer("Serialize and Save "..sSlotName)

	-- test saved value
	--[[
	do
		--GCO.StartTimer("deserialize")
		local s2 = GameConfiguration.GetValue(sSlotName)
		local size2 = string.len(s2)
		if s2 ~= s then
			GCO.Dprint( DEBUG_SAVELOAD_SCRIPT, "ERROR: String to save length = " .. tostring(size).. ", saved string length = " .. tostring(size2))
			GCO.Dprint( DEBUG_SAVELOAD_SCRIPT, "----------------------------------------------------------------------------------------------------------------------------------------")
			GCO.Dprint( DEBUG_SAVELOAD_SCRIPT, s)
			GCO.Dprint( DEBUG_SAVELOAD_SCRIPT, "----------------------------------------------------------------------------------------------------------------------------------------")
			GCO.Dprint( DEBUG_SAVELOAD_SCRIPT, s2)
			GCO.Dprint( DEBUG_SAVELOAD_SCRIPT, "----------------------------------------------------------------------------------------------------------------------------------------")
			GCO.Error("ERROR: GameConfiguration.GetValue doesn't return the same string that was set in GameConfiguration.SetValue for slot " ..tostring(sSlotName))
		end
		--local t2 = GCO.deserialize(s2)
		local status, retval = pcall(GCO.deserialize,s2)
		GCO.ShowTimer(sTimer)
		if not status then
			GCO.Error("Failed to save "..tostring(sSlotName).." ("..tostring(size).." chars)")
			print(retval)
			print(s)
		end
	end
	--]]
end

-- load
function LoadTableFromSlot(sSlotName)
	if not GameConfiguration.GetValue then
		GCO.Error("GameConfiguration.GetValue is null when trying to load from slot ".. tostring(sSlotName))
	end
	local sTimer = "Load "..tostring(sSlotName)
	GCO.StartTimer(sTimer)
	local s = GameConfiguration.GetValue(sSlotName)
	GCO.ShowTimer(sTimer)
	if s then
		local size = string.len(s)
		local sTimer = "Deserialize "..tostring(sSlotName).." ("..tostring(size).." chars)"
		GCO.StartTimer(sTimer)
		--local t = GCO.deserialize(s)
		local status, retval = pcall(GCO.deserialize,s)
		GCO.ShowTimer(sTimer)
		if status then
			return retval
		else
			GCO.Error("Failed to load "..tostring(sSlotName).." ("..tostring(size).." chars)")
			print(retval)
			print(s)
			
			f, msg = loadstring(s)
			if f == nil then
				GCO.Error("In deserialize: "..tostring(msg))
			else
				print("loadstring returns", f, msg)
			end
			
			return nil -- {}
		end
		--return t
	else
		GCO.Dprint( DEBUG_SAVELOAD_SCRIPT, "WARNING: No saved data table in slot ".. tostring(sSlotName) .." (this happens when initializing the table, you can ignore this warning when launching a new game)") 
	end
end

function SaveGameGCO(saveGame)
	GCO.Dprint( DEBUG_SAVELOAD_SCRIPT, "GCO Saving Game... " .. tostring(saveGame.Name))
	Network.SaveGame(saveGame)
end
GameEvents.SaveGameGCO.Add(SaveGameGCO)

----------------------------------------------
-- Initialize functions for other contexts
----------------------------------------------

ExposedMembers.SaveLoad_Initialized = false

function Initialize()
	if not ExposedMembers.GCO then ExposedMembers.GCO = {} end
		
	-- Load / Save
	ExposedMembers.GCO.SaveTableToSlot 				= SaveTableToSlot
	ExposedMembers.GCO.LoadTableFromSlot 			= LoadTableFromSlot
	ExposedMembers.GCO.LoadValue 					= GameConfiguration.GetValue
	ExposedMembers.GCO.SaveValue 					= GameConfiguration.SetValue
	ExposedMembers.SaveLoad_Initialized 			= true
end
Initialize()
