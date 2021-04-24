--=====================================================================================--
--	FILE:	 GCO_DefaultAI.lua.lua
--  Gedemon (2021)
--=====================================================================================--

print ("Loading GCO_DefaultAI.lua.lua...")

--=====================================================================================--
-- Includes
--=====================================================================================--
include( "GCO_TypeEnum" )
include( "GCO_SmallUtils" )


--=====================================================================================--
-- Defines
--=====================================================================================--
DEBUG_AI_SCRIPT 	= "debug"

local _cached			= {}	-- cached table to reduce calculations

local AI_TYPE_NAME		= "DefaultAI"

--=====================================================================================--
-- Initialize Functions
--=====================================================================================--

local GCO 	= {}
local pairs = pairs
local Dprint, Dline, Dlog, Div, LuaEvents
function InitializeUtilityFunctions() 	-- Get functions from other contexts
	GCO 		= ExposedMembers.GCO		-- contains functions from other contexts 
	LuaEvents	= GCO.LuaEvents
	Dprint 		= GCO.Dprint				-- Dprint(bOutput, str) : print str if bOutput is true
	Dline		= GCO.Dline					-- output current code line number to firetuner/log
	Dlog		= GCO.Dlog					-- log a string entry, last 10 lines displayed after a call to GCO.Error()
	Div			= GCO.Divide
	pairs 		= GCO.OrderedPairs
	GameEvents.InitializeGCO.Remove( InitializeUtilityFunctions )
	print ("Exposed Functions from other contexts initialized...")
	PostInitialize()
end
GameEvents.InitializeGCO.Add( InitializeUtilityFunctions )

function PostInitialize() -- everything that may require other context to be loaded first
	ExposedMembers.GCO.DefaultAIData = GCO.LoadTableFromSlot("DefaultAIData") or {}

end

function SaveTables()
	Dprint("--------------------------- Saving DefaultAIData ---------------------------")

	GCO.StartTimer("Saving And Checking DefaultAIData")
	GCO.SaveTableToSlot(ExposedMembers.GCO.DefaultAIData, "DefaultAIData")
end
GameEvents.SaveTables.Add(SaveTables)


--=====================================================================================--
-- AI Classes ( http://lua-users.org/wiki/SimpleLuaClasses )
--=====================================================================================--

-- create and use an AI
--	local pAI 		= AI:Create(playerID)
--	local AIData	= pAI:GetData()

-----------------------------------------------------------------------------------------
-- Global AI Functions
-----------------------------------------------------------------------------------------

local AI = {}
AI.__index = AI

function AI:Create(playerID)
   local pAI = {}             -- new AI object
   setmetatable(pAI,AI)	-- make AI handle lookup
   -- Initialize
   pAI.PlayerID = playerID
   pAI.Key 		= tostring(playerID)
   return pAI
end

function AI:GetData()
	if not ExposedMembers.GCO.DefaultAIData then GCO.Error("DefaultAIData is nil") end
	local r		= ExposedMembers.GCO.DefaultAIData
	local data 	= r[self.Key]
	if not data then -- First call
		r[self.Key] = {}
		data 		= r[self.Key]
	end
	return data
end

function AI:GetCache()
	local selfKey 	= self.Key
	if not _cached[selfKey] then _cached[selfKey] = {} end
	return _cached[selfKey]
end

function AI:GetCached(key)
	local Cache = self:GetCache()
	return Cache[key]
end

function AI:SetCached(key, value)
	local Cache = self:GetCache()
	Cache[key]	= value
end

function AI:GetValue(key)
	local Data = self:GetData()
	return Data[key]
end

function AI:SetValue(key, value)
	local Data	= self:GetData()
	Data[key]	= value
end

function AI:GetPlayer()
	return GCO.GetPlayer(self.PlayerID)
end


--=====================================================================================--
-- AI DoTurn
--=====================================================================================--

function AI:DoTurn()
	Dprint( DEBUG_AI_SCRIPT, " - Starting AI turn for Player # ".. tostring(self.PlayerID))
	self:Update()
	self:DoDiplomacy()
end

function AI:Update()
	Dprint( DEBUG_AI_SCRIPT, "   - AI Update...")
	
	-- Update Treasury
	local pPlayer	= self:GetPlayer()
	local pTreasury	= pPlayer:GetTreasury()
	local iDebt		= pPlayer:GetValue("Debt")
	
	self.GoldBalance 	= pTreasury:GetGoldBalance()
	self.GoldYield		= pTreasury:GetGoldYield() - pTreasury:GetTotalMaintenance()
	self.CanSpendGold	= (self.GoldYield > 0 or math.abs(self.GoldYield * 10) < self.GoldBalance) and (self.GoldBalance > iDebt)
	
	-- Update Military
	local pStats = GCO.CallPlayerContextFunction(self.PlayerID, "GetStats")
	print("GetMilitaryStrengthWithoutTreasury",pStats:GetMilitaryStrengthWithoutTreasury())
end

function AI:DoDiplomacy()
	Dprint( DEBUG_AI_SCRIPT, "   - AI Diplomacy...")

end

--=====================================================================================--
-- 
--=====================================================================================--

function InitializeDefaultAI(playerID, typeAI)
	if typeAI == AI_TYPE_NAME then
		Dprint( DEBUG_AI_SCRIPT, "   - Initialize AI for player#", playerID, typeAI)
		local pPlayer 	= GCO.GetPlayer(playerID)
		local pAI		= AI:Create(playerID)
		pAI:SetValue("TypeName", AI_TYPE_NAME)
		pPlayer:SetCached("AI", pAI)
	end
end
GameEvents.InitializePlayerAI.Add(InitializeDefaultAI)

--=====================================================================================--
-- Initialize script
--=====================================================================================--
function Initialize()
	
	if not ExposedMembers.GCO then ExposedMembers.GCO = {} end
	-- 
	ExposedMembers.GCO.AI 		= AI
	
end
Initialize()