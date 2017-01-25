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

When to save ?

-- this Lua event is called when listing files on the save/load menu
function SaveMyTable()
	ExposedMembers.SaveTableToSlot(myTable, "myTable")
end
LuaEvents.FileListQueryComplete.Add( SaveMyTable )

-- could get the quicksave key here
function OnInputHandler( pInputStruct:table )
	local uiMsg = pInputStruct:GetMessageType();
	if uiMsg == KeyEvents.KeyDown then
		if pInputStruct:GetKey() == Keys.VK_F5 then -- but the binding can be changed...
			ExposedMembers.SaveTableToSlot(myTable, "myTable")
		end
	end
	-- pInputStruct:IsShiftDown() and pInputStruct:IsAltDown()
end
ContextPtr:SetInputHandler( OnInputHandler, true )

-- Or on this event for quick save (but is it called soon enough before saving ?)
function OnInputAction( actionID )
	if actionID == Input.GetActionId("QuickSave") then
		SaveMyTables()
	end
end
Events.InputActionTriggered( OnInputAction )
--]]
--=================================================

-- save
function SaveTableToSlot(t, sSlotName)
	if type(t) ~= "table" then 
		print("ERROR: SaveTableToSlot(t, sSlotName), parameter #1 must be a table, nothing saved to slot ".. tostring(sSlotName))
		return
	end
	if type(sSlotName) ~= "string" then 
		print("ERROR: SaveTableToSlot(t, sSlotName), parameter #2 must be a string, the table wasn't saved")
		return
	end
	local s = pickle(t)
	GameConfiguration.SetValue(sSlotName, s)
end

-- load
function LoadTableFromSlot(sSlotName)
	local s = GameConfiguration.GetValue(sSlotName)
	if s then
		local t = unpickle(s)
		return t
	else
		print("ERROR: can't load table from ".. tostring(sSlotName)) 
	end
end

function Initialize()
	ExposedMembers.SaveTableToSlot = SaveTableToSlot
	ExposedMembers.LoadTableFromSlot = LoadTableFromSlot
end
Initialize()