-----------------------------------------------------------------------------------------
--	FILE:	 SaveLoad.lua
--  Gedemon (2017)
--  Loading/Saving simple tables with the game file using Pickle Table for serialization
--  http://lua-users.org/wiki/PickleTable
-----------------------------------------------------------------------------------------

----------------------------------------------
-- Pickle.lua
-- A table serialization utility for lua
-- Steve Dekorte, http://www.dekorte.com, Apr 2000
-- Freeware
----------------------------------------------

function pickle(t)
  return Pickle:clone():pickle_(t)
end

Pickle = {
  clone = function (t) local nt={}; for i, v in pairs(t) do nt[i]=v end return nt end 
}

function Pickle:pickle_(root)
  if type(root) ~= "table" then 
    error("can only pickle tables, not ".. type(root).."s")
  end
  self._tableToRef = {}
  self._refToTable = {}
  local savecount = 0
  self:ref_(root)
  local s = ""

  while #(self._refToTable) > savecount do
    savecount = savecount + 1
    local t = self._refToTable[savecount]
    s = s.."{\n"
    for i, v in pairs(t) do
        s = string.format("%s[%s]=%s,\n", s, self:value_(i), self:value_(v))
    end
    s = s.."},\n"
  end

  return string.format("{%s}", s)
end

function Pickle:value_(v)
  local vtype = type(v)
  if     vtype == "string" then return string.format("%q", v)
  elseif vtype == "number" then return v
  elseif vtype == "boolean" then return tostring(v)
  elseif vtype == "table" then return "{"..self:ref_(v).."}"
  else --error("pickle a "..type(v).." is not supported")
  end  
end

function Pickle:ref_(t)
  local ref = self._tableToRef[t]
  if not ref then 
    if t == self then error("can't pickle the pickle class") end
    table.insert(self._refToTable, t)
    ref = #(self._refToTable)
    self._tableToRef[t] = ref
  end
  return ref
end

----------------------------------------------
-- unpickle
----------------------------------------------

function unpickle(s)
  if type(s) ~= "string" then
    error("can't unpickle a "..type(s)..", only strings")
  end
  local gentables = loadstring("return "..s)
  local tables = gentables()
  
  for tnum = 1, #(tables) do
    local t = tables[tnum]
    local tcopy = {}; for i, v in pairs(t) do tcopy[i] = v end
    for i, v in pairs(tcopy) do
      local ni, nv
      if type(i) == "table" then ni = tables[i[1]] else ni = i end
      if type(v) == "table" then nv = tables[v[1]] else nv = v end
      t[i] = nil
      t[ni] = nv
    end
  end
  return tables[1]
end


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

GCO = {}
function InitializeUtilityFunctions() -- Get functions from other contexts
	if ExposedMembers.Utils_Initialized and ExposedMembers.SaveLoad_Initialized then 
		GCO = ExposedMembers.GCO
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
	local startTime = Automation.GetTime()
	if type(t) ~= "table" then 
		print("ERROR: SaveTableToSlot(t, sSlotName), parameter #1 must be a table, nothing saved to slot ".. tostring(sSlotName))
		return
	end
	if type(sSlotName) ~= "string" then 
		print("ERROR: SaveTableToSlot(t, sSlotName), parameter #2 must be a string, the table wasn't saved")
		return
	end
	local s = pickle(t)
	local size = string.len(s)
	GameConfiguration.SetValue(sSlotName, s)
	local sCheck = GameConfiguration.GetValue(sSlotName)
	if sCheck ~= s then
		print("ERROR: GameConfiguration.GetValue doesn't return the same string that was set in GameConfiguration.SetValue for slot " ..tostring(sSlotName))
		print("ERROR: String to save length = " .. tostring(size).. ", saved string length = " .. tostring(string.len(sCheck)))
	end
	local endTime = Automation.GetTime()
	print("SaveTableToSlot for slot " .. tostring(sSlotName) .. " used " .. tostring(endTime-startTime) .. " seconds, table size = " .. tostring(GCO.GetSize(t)) .. ", serialized size = " .. tostring(size)) 
end

-- load
function LoadTableFromSlot(sSlotName)
	if not GameConfiguration.GetValue then
		print("ERROR: GameConfiguration.GetValue is null when trying to load from slot ".. tostring(sSlotName))
	end
	local s = GameConfiguration.GetValue(sSlotName)
	if s then
		local t = unpickle(s)
		return t
	else
		print("WARNING: No saved data table in slot ".. tostring(sSlotName) .." (this happens when initializing the table, you can ignore this warning when lauching a new game)") 
	end
end

----------------------------------------------
-- Initialize functions for other contexts
----------------------------------------------

ExposedMembers.SaveLoad_Initialized = false

function Initialize()
	if not ExposedMembers.GCO then ExposedMembers.GCO = {} end
	ExposedMembers.GCO.SaveTableToSlot = SaveTableToSlot
	ExposedMembers.GCO.LoadTableFromSlot = LoadTableFromSlot
	ExposedMembers.UI = UI -- I'd like to handle UI stuff from scripts
	ExposedMembers.CombatTypes = CombatTypes -- I can understand for the UI, but why this is not in script ???
	ExposedMembers.SaveLoad_Initialized = true
end
Initialize()
