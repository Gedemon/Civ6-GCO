--=====================================================================================--
--	FILE:	 GCO_ResearchScript.lua
--  Gedemon (2018)
--=====================================================================================--

print ("Loading GCO_ResearchScript.lua...")

--=====================================================================================--
-- Includes
--=====================================================================================--
include( "GCO_TypeEnum" )
include( "GCO_SmallUtils" )


--=====================================================================================--
-- Defines
--=====================================================================================--
local _cached					= {}	-- cached table to reduce calculations

local NO_ITEM					= -1
local NO_TAG					= "N"	-- key for saved tables

local Unlocker					= {}	-- Helper to get the unlocker ID for a Tech
for row in GameInfo.TechnologyPrereqs() do
	if string.sub(row.PrereqTech, 1, 11) == "TECH_UNLOCK" then
		local unlockerID	= GameInfo.Technologies[row.PrereqTech].Index
		local techID		= GameInfo.Technologies[row.Technology].Index
		Unlocker[techID]	= unlockerID
	end
end

local TypeTags			= {}		-- helper to check if an ItemType has a TypeTag 
for row in GameInfo.TypeTags() do
	local itemType 			= row.Type
	local tag				= row.Tag
	TypeTags[itemType] 		= TypeTags[itemType] or {}
	TypeTags[itemType][tag]	= true
end

local EventsTechsList	= {}		-- to get the list of Techs than can be influenced by an EventType 
local TechHasEvent		= {}		-- to check if a Tech can be influenced by an EventType
local TechResearchEvent	= {}		-- to check if a Tech can get research points from EventType
local TechResearchRow	= {}		-- to get the row for a (Tech/Event/TypeTag) combination 
local TechUnlockEvent	= {}		-- to check if a Tech can be unlocked by an EventType
local TechResearchTags	= {}		-- to get the list of possible TypeTags required by a specific Tech/Event pairs for Research points
local TechUnlockTags	= {}		-- to get the list of possible TypeTags required by a specific Tech/Event pairs for unlocking
for row in GameInfo.TechnologyEventContribution() do
	local techID				= GameInfo.Technologies[row.Technology].Index
	local event					= row.ContributionType
	EventsTechsList[event] 		= EventsTechsList[event] 	or {}
	TechHasEvent[techID]		= TechHasEvent[techID] 		or {}
	TechResearchEvent[techID]	= TechResearchEvent[techID] or {}
	if not TechHasEvent[techID][event] then
		table.insert(EventsTechsList[event], techID)
	end
	TechHasEvent[techID][event] 		= true
	TechResearchEvent[techID][event] 	= true
	--
	local typeTag	= row.TypeTag
	if typeTag then
		TechResearchTags[techID]		= TechResearchTags[techID] 			or {}
		TechResearchTags[techID][event]	= TechResearchTags[techID][event] 	or {}
		table.insert(TechResearchTags[techID][event], typeTag)
	end
	--
	TechResearchRow[techID]						= TechResearchRow[techID] 			or {}
	TechResearchRow[techID][event]				= TechResearchRow[techID][event] 	or {}
	if typeTag then
		TechResearchRow[techID][event][typeTag] = {MaxContributionPercent = row.MaxContributionPercent, PrereqTech = row.PrereqTech, PrereqEra = row.PrereqEra, BaseValue = row.BaseValue}
	else
		TechResearchRow[techID][event] = {MaxContributionPercent = row.MaxContributionPercent, PrereqTech = row.PrereqTech, PrereqEra = row.PrereqEra, BaseValue = row.BaseValue}
	end
end
for row in GameInfo.TechnologyEventUnlock() do
	local techID			= GameInfo.Technologies[row.Technology].Index
	local event				= row.ContributionType
	EventsTechsList[event] 	= EventsTechsList[event] 	or {}
	TechHasEvent[techID]	= TechHasEvent[techID] 		or {}
	TechUnlockEvent[techID]	= TechUnlockEvent[techID] 	or {}
	if not TechHasEvent[techID][event] then
		table.insert(EventsTechsList[event], techID)
	end
	TechHasEvent[techID][event] 	= true
	TechUnlockEvent[techID][event] 	= true
	--
	local typeTag	= row.TypeTag
	if typeTag then
		TechUnlockTags[techID]			= TechUnlockTags[techID] 		or {}
		TechUnlockTags[techID][event]	= TechUnlockTags[techID][event] or {}
		table.insert(TechUnlockTags[techID][event], typeTag)
	end
end


local EventsResearchList	= {}		-- to get the list of Research that can get point by an EventType
local EventsResearchValue	= {}		-- to get the points added to a ResearchType by an EventType
local EventsResearchTags	= {}		-- to get the list of possible TypeTags required by a specific Research/Event pairs
for row in GameInfo.TechnologyResearchEventPoints() do
	local research							= row.ResearchType
	local event								= row.ContributionType
	
	EventsResearchList[event] 				= EventsResearchList[event] 		or {}
	table.insert(EventsResearchList[event], research)
	
	EventsResearchValue[research]			= EventsResearchValue[research]	or {}
	EventsResearchValue[research][event]	= row.BaseValue
	
	--
	local typeTag	= row.TypeTag
	if typeTag then
		EventsResearchTags[research]		= EventsResearchTags[research] 		or {}
		EventsResearchTags[research][event]	= EventsResearchTags[research][event] or {}
		table.insert(EventsResearchTags[research][event], typeTag)
	end
end


local ResearchTechList	= {}		-- to get the list of Techs than can get science points from a ResearchType
local ResearchTechMax	= {}		-- to get the max percentage of science added to a Tech by a ResearchType 
for row in GameInfo.TechnologyResearchContribution() do
	local techID	= GameInfo.Technologies[row.Technology].Index
	local research	= row.ContributionType

	ResearchTechList[research] = ResearchTechList[research] or {}
	table.insert(ResearchTechList[research], techID)
	ResearchTechMax[techID]				= ResearchTechMax[techID] or {}
	ResearchTechMax[techID][research]	= row.MaxContributionPercent
end

local ResearchList		= {}		-- to get the list of ResearchType
local ResearchYieldType	= {}		-- to get the Custom Yield Type associated to a ResearchType
for row in GameInfo.TechnologyContributionTypes() do
	if row.IsResearch then
		local researchType 	= row.ContributionType
		table.insert(ResearchList, 		researchType)
		ResearchYieldType[researchType] = "YIELD_" .. researchType
	end
end
		
local TechUnlockGovernement	= {}	-- helper to convert Governement prereqCivic to prereqTech (to do: directly add prereqTech column in Governments table
for row in GameInfo.Governments() do
	if row.PrereqCivic then
		local techType 	= "TECH_"..string.sub(row.PrereqCivic, 1, 6)
		local techID	= GameInfo.Technologies[techID] and GameInfo.Technologies[techID].Index
		if techID then
			TechUnlockGovernement[techID] 	= row.index
		end
	end
end

--=====================================================================================--
-- Debug
--=====================================================================================--
DEBUG_RESEARCH_SCRIPT		= "ResearchScript"


--=====================================================================================--
-- Initialize
--=====================================================================================--
local GCO 		= {}
local lpairs	= pairs
local pairs 	= pairs
function InitializeUtilityFunctions() 	-- Get functions from other contexts
	GCO 	= ExposedMembers.GCO
	Dprint 	= GCO.Dprint
	Dline	= GCO.Dline					-- output current code line number to firetuner/log
	Dlog	= GCO.Dlog					-- log a string entry, last 10 lines displayed after a call to GCO.Error()
	pairs 	= GCO.OrderedPairs
	print ("Exposed Functions from other contexts initialized...")
	PostInitialize()
end
LuaEvents.InitializeGCO.Add( InitializeUtilityFunctions )

function SaveTables()
	Dprint( DEBUG_RESEARCH_SCRIPT, "--------------------------- Saving ResearchData ---------------------------")	
	GCO.StartTimer("Saving And Checking ResearchData")
	GCO.SaveTableToSlot(ExposedMembers.GCO.ResearchData, "ResearchData")
	GCO.SaveTableToSlot(ExposedMembers.GCO.CityResearchData, 	"CityResearchData")
end
LuaEvents.SaveTables.Add(SaveTables)

function CheckSave()
	Dprint( DEBUG_RESEARCH_SCRIPT, "Checking Saved Table...")
	if GCO.AreSameTables(ExposedMembers.GCO.ResearchData, GCO.LoadTableFromSlot("ResearchData")) then
		Dprint( DEBUG_RESEARCH_SCRIPT, "- Tables are identical")
	else
		GCO.Error("reloading saved ResearchData table show differences with actual table !")
		ShowResearchData()
		CompareData(ExposedMembers.GCO.ResearchData, GCO.LoadTableFromSlot("ResearchData"))
	end
	
	if GCO.AreSameTables(ExposedMembers.GCO.CityResearchData, GCO.LoadTableFromSlot("CityResearchData")) then
		Dprint( DEBUG_RESEARCH_SCRIPT, "- Tables are identical")
	else
		GCO.Error("reloading saved CityResearchData table show differences with actual table !")
		ShowResearchData()
		CompareData(ExposedMembers.GCO.CityResearchData, GCO.LoadTableFromSlot("CityResearchData"))
	end
	
	GCO.ShowTimer("Saving And Checking ResearchData")
end
LuaEvents.SaveTables.Add(CheckSave)

function PostInitialize() -- everything that may require other context to be loaded first
	ExposedMembers.GCO.ResearchData = GCO.LoadTableFromSlot("ResearchData") or {}
	ExposedMembers.GCO.CityResearchData = GCO.LoadTableFromSlot("CityResearchData") or {}
end

-- for debugging
function ShowResearchData()
	for key, data in lpairs(ExposedMembers.GCO.ResearchData) do
		print(key, data)
		for k, v in lpairs (data) do
			print("-", k, v)
		end
	end
	for key, data in lpairs(ExposedMembers.GCO.CityResearchData) do
		print(key, data)
		for k, v in lpairs (data) do
			print("-", k, v)
		end
	end
end

function CompareData(data1, data2)
	print("---------------------------------------------------------------------------------------")
	print("COMPARING : ", data1, data2)
	for key, data in lpairs(data1) do
		print(key, data)
		for k, v in lpairs (data) do
			print("-----------------------------")
			print(k, v)
			if type(v) == 'table' then
				for subkey, subval in lpairs (v) do
					print("-", subkey, subval)
					if type(subval) == 'table' then
						for subkey2, subval2 in lpairs (subval) do
							print("----", subkey2, subval2)
							if type(subval2) == 'table' then
								for subkey3, subval3 in lpairs (subval2) do
									print("--------", subkey3, subval3)
									if type(subval3) == 'table' then
										for subkey4, subval4 in lpairs (subval3) do
											print("------------", subkey4, subval4)
											--print("-----------------------------")
											if not data2[key][k][subkey][subkey2][subkey3] then
												print("------------ reloaded table is nil for subkey3 = ", subkey3)
											elseif not data2[key][k][subkey][subkey2][subkey3][subkey4] then			
												print("------------ no value for key = ", k, "subkey = ", subkey, "subkey2 = ", subkey2, "subkey3 = ", subkey3, "subkey4 = ", subkey4, " CivID =", key)
											elseif subval4 ~= data2[key][k][subkey][subkey2][subkey3][subkey4] then
												print("------------ different value for key = ", key, "subkey = ", subkey, "subkey2 = ", subkey2, "subkey3 = ", subkey3, "subkey4 = ", subkey4, " CivID =", key, " Data1 value = ", subval4, type(subval4), " Data2 value = ", data2[key][k][subkey][subkey2][subkey3][subkey4], type(data2[key][k][subkey][subkey2][subkey3][subkey4]), subval4 - data2[key][k][subkey][subkey2][subkey3][subkey4] )
											else
												--print("-", subkey, data2[key][k][subkey])
											end
										end			
									else
										--print("-----------------------------")
										if not data2[key][k][subkey][subkey2] then
											print("-------- reloaded table is nil for subkey2 = ", subkey2)
										elseif not data2[key][k][subkey][subkey2][subkey3] then			
											print("-------- no value for key = ", k, "subkey = ", subkey, "subkey2 = ", subkey2, "subkey3 = ", subkey3, " CivID =", key)
										elseif subval3 ~= data2[key][k][subkey][subkey2][subkey3] then
											print("-------- different value for key = ", key, "subkey = ", subkey, "subkey2 = ", subkey2, "subkey3 = ", subkey3, " CivID =", key, " Data1 value = ", subval3, type(subval3), " Data2 value = ", data2[key][k][subkey][subkey2][subkey3], type(data2[key][k][subkey][subkey2][subkey3]), subval3 - data2[key][k][subkey][subkey2][subkey3] )
										else
											--print("-", subkey, data2[key][k][subkey])
										end
									end
								end			
							else
								--print("-----------------------------")
								if not data2[key][k][subkey] then
									print("---- reloaded table is nil for subkey = ", subkey)
								elseif not data2[key][k][subkey][subkey2] then			
									print("---- no value for key = ", k, "subkey = ", subkey, "subkey2 = ", subkey2, " CivID =", key)
								elseif subval2 ~= data2[key][k][subkey][subkey2] then
									print("---- different value for key = ", key, "subkey = ", subkey, "subkey2 = ", subkey2, " CivID =", key, " Data1 value = ", subval2, type(subval2), " Data2 value = ", data2[key][k][subkey][subkey2], type(data2[key][k][subkey][subkey2]), subval2 - data2[key][k][subkey][subkey2] )
								else
									--print("-", subkey, data2[key][k][subkey])
								end
							end
						end			
					else
						--print("-----------------------------")
						if not data2[key][k] then
							print("- reloaded table is nil for key = ", k)
						elseif not data2[key][k][subkey] then			
							print("- no value for key = ", k, "subkey = ", subkey, " CivID =", key)
						elseif subval ~= data2[key][k][subkey] then
							print("- different value for key = ", k, "subkey = ", subkey, " CivID =", key, " Data1 value = ", subval, type(subval), " Data2 value = ", data2[key][k][subkey], type(data2[key][k][subkey]), subval - data2[key][k][subkey] )
						else
							--print("-", subkey, data2[key][k][subkey])
						end
					end
				end			
			else
				if not data2[key] then
					print("- reloaded table is nil for CivID = ", key)
				elseif not data2[key][k] then			
					print("- no value for key = ", k, " CivID =", key)
				elseif v ~= data2[key][k] then
					print("- different value for key = ", k, " CivID =", key, " Data1 value = ", v, type(v), " Data2 value = ", data2[key][k], type(data2[key][k]), v - data2[key][k] )
				else
					--print(k, data2[key][k])
				end
			end
		end
	end
end


--=====================================================================================--
-- Research Classes ( http://lua-users.org/wiki/SimpleLuaClasses )
--=====================================================================================--

-- create and use a Research
--	local rsrch 		= Research:Create(playerID)
--	local researchData	= rsrch:GetData()

-----------------------------------------------------------------------------------------
-- Global Research Functions
-----------------------------------------------------------------------------------------

local Research = {}
Research.__index = Research

function Research:Create(playerID)
   local rsrch = {}             -- new Research object
   setmetatable(rsrch,Research)	-- make Research handle lookup
   -- Initialize
   rsrch.PlayerID 	= playerID
   rsrch.Key 		= tostring(playerID)
   return rsrch
end

function Research:GetData()
	if not ExposedMembers.GCO.ResearchData then GCO.Error("ResearchData is nil") end
	local r		= ExposedMembers.GCO.ResearchData
	local data 	= r[self.Key]
	if not data then -- First call
		r[self.Key] = {}
		data 		= r[self.Key]
	end
	return data
end

function Research:GetCache()
	local selfKey 	= self.Key
	if not _cached[selfKey] then _cached[selfKey] = {} end
	return _cached[selfKey]
end

function Research:GetCached(key)
	local selfKey 	= self.Key
	if not _cached[selfKey] then _cached[selfKey] = {} end
	return _cached[selfKey][key]
end

function Research:SetCached(key, value)
	local selfKey 	= self.Key
	if not _cached[selfKey] then _cached[selfKey] = {} end
	_cached[selfKey][key] = value
end

function Research:GetValue(key)
	local Data = self:GetData()
	return Data[key]
end

function Research:SetValue(key, value)
	local Data = self:GetData()
	Data[key] = value
end

function Research:GetPlayer()
	return GCO.GetPlayer(self.PlayerID)
end

function Research:GetEraType()
	local player 	= Players[self.PlayerID]
	if player then
		return GameInfo.Eras[player:GetEra()].EraType
	else
		return GameInfo.Eras[GCO.GetGameEra()].EraType
	end
end

function Research:GetTechs()
	return Players[self.PlayerID]:GetTechs()
end

function Research:HasTech(TechID)
	local pTech = self:GetTechs()
	return pTech:HasTech(TechID)
end

function Research:GetList()
	return ResearchList
end

function Research:DoTurn()
	
	local data 	= self:GetData()
	data.RsrchF	= data.RsrchF or {} -- ResearchField	: [rsrchKey][cntrKey] = value
	local pTech	= self:GetTechs()
	
	Dprint( DEBUG_RESEARCH_SCRIPT, GCO.Separator)
	Dprint( DEBUG_RESEARCH_SCRIPT, "Research:DoTurn")
	
	-------------------------------
	-- Apply and Reset Research Yield
	-------------------------------
	for _, researchType in ipairs(self:GetList()) do
		Dprint( DEBUG_RESEARCH_SCRIPT, " - apply Research Yield : ", Locale.Lookup(GameInfo.TechnologyContributionTypes[researchType].Name))
		local yieldLeft		= self:GetYield(researchType)
		local techList		= {}
		local currentTechID	= pTech:GetResearchingTech()
		local priorityID	= nil
		local numTech		= 0
		local counter		= 0
		
		for _, techID in ipairs(ResearchTechList[researchType] or {}) do
			Dprint( DEBUG_RESEARCH_SCRIPT, "  - Check Tech for that Research Type: ", Locale.Lookup(GameInfo.Technologies[techID].Name))
			if pTech:CanResearch(techID) then
				if techID == currentTechID then
					Dprint( DEBUG_RESEARCH_SCRIPT, "  - Tech is the current Research project...")
					priorityID = techID
				else
					Dprint( DEBUG_RESEARCH_SCRIPT, "  - Can research...")
					techList[techID] 	= true
					numTech				= numTech + 1
				end
			else
				Dprint( DEBUG_RESEARCH_SCRIPT, "  - Skipped, Can't research...")
			end
		end
		
		if priorityID then
			local techID	= priorityID
			local arg 		= { MaxContributionPercent = ResearchTechMax[techID][researchType] or 100, BaseValue = yieldLeft}
			yieldLeft 		= self:AddContribution(techID, nil, nil, researchType, nil, arg)
		end
		
		while numTech > 0 and yieldLeft > 0 and counter < 5  do
			local share		= GCO.ToDecimals(yieldLeft / numTech)
			local toRemove	= {}
			counter			= counter + 1
			for techID, _ in pairs(techList) do
				local prevLeft 	= yieldLeft
				local arg 		= { MaxContributionPercent = ResearchTechMax[techID][researchType] or 100, BaseValue = yieldLeft}
				yieldLeft 		= self:AddContribution(techID, nil, nil, researchType, nil, arg)
				if yieldLeft == prevLeft then -- this tech can't progress from that ResearchType anymore
					table.insert(toRemove, techID)
				end
			end
			for _, techId in ipairs(toRemove) do
				numTech 			= numTech - 1
				techList[techId]	= nil
			end
		end
			
		-- Reset values
		local rsrchKey	= tostring(GameInfo.TechnologyContributionTypes[researchType].Index)
		data.RsrchF[rsrchKey] = {}
		
		-- Handle overflow (todo : change to generate "knowledge" resource in the capital to be stocked/traded or used for research when there won't be overflow)
		if yieldLeft > 0 then 
			--GCO.Warning("yieldLeft = "..tostring(yieldLeft).." for ".. Locale.Lookup(GameInfo.TechnologyContributionTypes[researchType].Name))
			self:ChangeYield(researchType, nil, nil, "YIELD_OVERFLOW", yieldLeft)
		end
	end
	
	-------------------------------
	-- Get Next turn yields
	-------------------------------
	
	local player = self:GetPlayer()
	
	-- Hardcoded special case for Culture/Inspiration
	if GameInfo.TechnologyContributionTypes["RESEARCH_INSPIRATION"] then
		local cultureYield = player:GetCulture():GetCultureYield()
		self:ChangeYield("RESEARCH_INSPIRATION", nil, nil, "YIELD_CULTURE_INSPIRATION", GCO.ToDecimals(cultureYield/2))
	end
	
	-- Loop cities for boost/yields
	local playerCities 	= player:GetCities()
	for i, city in playerCities:Members() do
		GCO.AttachCityFunctions(city)
		
		if city:IsCoastal() then
			DoResearchOnEvent("EVENT_COASTAL_CITY", self.PlayerID, city:GetX(), city:GetY())
		end
		
		-- Set Research Yield base value
		for researchType, CustomYieldType in pairs(ResearchYieldType) do
			local yieldID 	= GameInfo.CustomYields[CustomYieldType].Index
			local yield		= city:GetCustomYield(yieldID)
			if yield > 0 then
				self:ChangeYield(researchType, city:GetX(), city:GetY(), "YIELD_BUILDING", yield)
			end
		end
	end
	
	-- Check revealed plots for boosts (applied next turn)
	local iPlotCount = Map.GetPlotCount()
	for i = 0, iPlotCount - 1 do
		local plot = Map.GetPlotByIndex(i)
		local pPlayerVis = PlayersVisibility[self.PlayerID]
		if (pPlayerVis ~= nil) then
			if (pPlayerVis:IsRevealed(plot:GetX(), plot:GetY())) then
				local resourceID	= plot:GetResourceType()
				if resourceID ~= NO_ITEM then
					self:RegisterResource(resourceID, plot)
				end
				if plot:IsNaturalWonder() then
					self:RegisterNaturalWonder(plot)
				end
			end
		end
	end
	Dprint( DEBUG_RESEARCH_SCRIPT, GCO.Separator)
end

function Research:UnlockTech(TechID, x, y)				-- Give the Tech that unlock TechID

	local unlockerID = Unlocker[TechID]
	if unlockerID then
		local data = self:GetData()
		if not data.Unlocked then data.Unlocked = {} end
		if data.Unlocked[TechID] then return end
		local pTech = self:GetTechs()
		if not pTech:HasTech(unlockerID) then
		
			local currentTechID		= pTech:GetResearchingTech()
			local currentProgress	= pTech:GetResearchProgress(currentTechID)
			
			pTech:SetResearchProgress(unlockerID, pTech:GetResearchCost(unlockerID))
			if currentTechID ~= NO_ITEM then
				pTech:SetResearchProgress(currentTechID, currentProgress)
			end
			
			data.Unlocked[TechID] = true
			if self.PlayerID == Game.GetLocalPlayer() then
			
				-- World View Text
				if x and y then
					local pLocalPlayerVis = PlayersVisibility[self.PlayerID]
					if (pLocalPlayerVis ~= nil) then
						if (pLocalPlayerVis:IsRevealed(x, y)) then
							local sText = Locale.Lookup("LOC_TECH_UNLOCKED_FLOAT", GameInfo.Technologies[TechID].Name)
							Game.AddWorldViewText(EventSubTypes.DAMAGE, sText, x, y, 0)
						end
					end
				end
			
				-- Message Text
				local sText = Locale.Lookup("LOC_TECH_UNLOCKED", GameInfo.Technologies[TechID].Name, GameInfo.Technologies[unlockerID].Description)
				LuaEvents.GCO_Message(sText, 8, ReportingStatusTypes.GOSSIP)
			end
			return true
		end
	end
end

function Research:UnlockGovernement(govID)
	local pCulture	= Players[self.PlayerID]:GetCulture()
	if pCulture then
		pCulture:UnlockGovernment(govID)
	end
end

function Research:RegisterResource(resourceID, plot)	-- "EVENT_DISCOVER_NEW_RESOURCE", "EVENT_DISCOVER_RESOURCE"

	local data 		= self:GetData()
	data.ResPos 	= data.ResPos or {} -- ResourcesPosition	: to mark the plots with resource already discovered 
	data.ResKnw 	= data.ResKnw or {}	-- ResourcesKnown		: to mark the resources already discovered for the first time
	local plotKey	= tostring(plot:GetIndex())
	local player	= self:GetPlayer()
	local resKey	= tostring(resourceID)
	
	if not player:IsResourceVisible(resourceID) then return end -- Can't see that resource...
	if data.ResPos[plotKey] then return end -- Already found a resource on that plot...
	
	local x, y			= plot:GetX(), plot:GetY()
	local resourceType	= GameInfo.Resources[resourceID].ResourceType
	
	-- Discovering a new type of Resource Event
	if not data.ResKnw[resKey] then
		data.ResKnw[resKey] 	= true
		data.ResPos[plotKey] 	= resourceID
		DoResearchOnEvent("EVENT_DISCOVER_NEW_RESOURCE", self.PlayerID, x, y, resourceType)
	else
		-- Register a new plot with resource
		data.ResPos[plotKey] 	= resourceID
		DoResearchOnEvent("EVENT_DISCOVER_RESOURCE", self.PlayerID, x, y, resourceType)
	end
end

function Research:RegisterNaturalWonder(plot)			-- "EVENT_DISCOVER_NATURAL_WONDER"

	local data 				= self:GetData()
	data.KnwNW 				= data.KnwNW or {}	-- KnownNaturalWonder		: to mark the NW already discovered
	local player			= self:GetPlayer()
	local NaturalWonderKey	= tostring(plot:GetFeatureType())
	
	if data.KnwNW[NaturalWonderKey] then return end -- Already found that NW...
	
	-- Discovered a new Natural Wonder
	local x, y			= plot:GetX(), plot:GetY()
	data.KnwNW[NaturalWonderKey] 	= true
	DoResearchOnEvent("EVENT_DISCOVER_NATURAL_WONDER", self.PlayerID, x, y)
end

function Research:AddContribution(techID, x, y, contributionType, itemTag, row)

	local pTech 		= self:GetTechs()
	local prereqTechID	= (row.PrereqTech and GameInfo.Technologies[row.PrereqTech].Index)
	local prereqEra		= row.PrereqEra
	
	Dprint( DEBUG_RESEARCH_SCRIPT, GCO.Separator)
	Dprint( DEBUG_RESEARCH_SCRIPT, "AddContribution : ", Locale.Lookup(GameInfo.Technologies[techID].Name), x, y, contributionType, itemTag, row.PrereqTech, row.PrereqEra)

	if prereqTechID == nil or pTech:HasTech(prereqTechID) then
		if prereqEra == nil or prereqEra == self:GetEraType() then
			local techKey			= tostring(techID)
			local contrKey			= tostring(GameInfo.TechnologyContributionTypes[contributionType].Index)
			local currContribution	= self:GetCurrentContribution(techID, contributionType, itemTag)
			local maxPercent		= row.MaxContributionPercent
			local techProgress		= pTech:GetResearchProgress(techID)
			local techCost			= pTech:GetResearchCost(techID)
			local maxProgress		= techCost * maxPercent / 100
			
			--local progressPercent	= techProgress / techCost * 100
			
			Dprint( DEBUG_RESEARCH_SCRIPT, "  maxPercent = ", maxPercent, " techProgress = ", techProgress, " techCost = ", techCost, ", maxProgress = ", maxProgress, ", currContribution = ", currContribution)
			
			if currContribution < maxProgress then
			
				local currentTechID		= pTech:GetResearchingTech()
				local currentProgress	= pTech:GetResearchProgress(currentTechID)
			
				local value				= row.BaseValue
				local maxContribution 	= math.max(0, math.min( (techCost - techProgress), (maxProgress - currContribution) ) )
				local contribution		= math.min(value, maxContribution)
				
				Dprint( DEBUG_RESEARCH_SCRIPT, "  ContributionValue = ", value, " maxContribution = ", maxContribution, " validated contribution = ", contribution)
				
				if contribution > 0 then
				
					-- Add contribution to the Tech progression
					pTech:SetResearchProgress(techID, techProgress + contribution)
					
					-- Update or create the Tech contribution value for that event/research/need type
					local data 		= self:GetData()
					data.Contrb 	= data.Contrb or {} -- ResearchContribution	: [techKey][contrKey][tagKey] or [techKey][contrKey][NO_TAG]
					local tagKey	= tostring((itemTag and GameInfo.Tags[itemTag].Index) or NO_TAG)
					if not data.Contrb[techKey] then data.Contrb[techKey] = {} end
					if not data.Contrb[techKey][contrKey] then data.Contrb[techKey][contrKey] = {} end
					data.Contrb[techKey][contrKey][tagKey] = GCO.ToDecimals((data.Contrb[techKey][contrKey][tagKey] or 0) + contribution)
					
					--Dprint( DEBUG_RESEARCH_SCRIPT, "  NewValue for data.Contrb[techKey][contrKey][tagKey] = ", data.Contrb[techKey][contrKey][tagKey], " techKey = ", techKey, " contrKey = ", contrKey, " tagKey = ", tagKey)
				
					-- Restore previous researched Tech on the UI
					if currentTechID ~= NO_ITEM then
						pTech:SetResearchProgress(currentTechID, currentProgress)
					end

					if x and y and self.PlayerID == Game.GetLocalPlayer() then
						local pLocalPlayerVis = PlayersVisibility[self.PlayerID]
						if (pLocalPlayerVis ~= nil) then
							if (pLocalPlayerVis:IsRevealed(x, y)) then
								local sText = Locale.Lookup("LOC_TECH_CONTRIBUTION_FLOAT", contribution, GameInfo.Technologies[techID].Name)
								Game.AddWorldViewText(EventSubTypes.DAMAGE, sText, x, y, 0)
							end
						end
					end
				end
				Dprint( DEBUG_RESEARCH_SCRIPT, GCO.Separator)
				return value - contribution
			else
				Dprint( DEBUG_RESEARCH_SCRIPT, " - Requirement failed on current maxProgress = ", maxProgress, " >= techProgress for this type of contribution = ", techProgress)
			end
		else
			Dprint( DEBUG_RESEARCH_SCRIPT, " - Requirement failed for PrereqEra, current era : ", self:GetEraType())
		end
	else
		Dprint( DEBUG_RESEARCH_SCRIPT, " - Requirement failed on PrereqTech : not researched")
	end
	Dprint( DEBUG_RESEARCH_SCRIPT, GCO.Separator)
	return row.BaseValue
end

function Research:GetCurrentContribution(techID, contributionType, itemTag)

	local data 		= self:GetData()
	data.Contrb 	= data.Contrb or {} -- ResearchContribution	: [techKey][contrKey][tagKey] or [techKey][contrKey][NO_TAG]
	
	local techKey	= tostring(techID)
	local contrKey	= tostring(GameInfo.TechnologyContributionTypes[contributionType].Index)
	local tagKey	= tostring((itemTag and GameInfo.Tags[itemTag].Index) or NO_TAG)
	
	return (data.Contrb[techKey] and data.Contrb[techKey][contrKey] and data.Contrb[techKey][contrKey][tagKey]) or 0
	
end

function Research:GetContributionString(techID)

	local makeStr 			= {}
	local pTech 			= self:GetTechs()
	local techCost			= pTech:GetResearchCost(techID)
	local totalProgress		= pTech:GetResearchProgress(techID)
	local contribProgress	= 0
	local bInvertedColor	= true
	local bNoGradient		= false
	
	local function AddToString(techID, contributionType, typeTag, maxPercent)
		local currentContribution	= self:GetCurrentContribution(techID, contributionType, typeTag)
		local maxContribution		= techCost * maxPercent / 100
		local percentContribution	= (currentContribution / (maxContribution > 0 and maxContribution or currentContribution)) * 100
		--GCO.GetPercentBarString(value, bInvertedColors, bNoGradient, color)
		if typeTag then
			table.insert(makeStr, GCO.GetPercentBarString(percentContribution, bInvertedColor, bNoGradient) .. " " .. Locale.Lookup(GameInfo.TechnologyContributionTypes[contributionType].Name) .. " ".. tostring(currentContribution) .."/".. tostring(maxContribution) .." (" .. Locale.Lookup("LOC_"..typeTag.."_NAME") ..")" )
		else
			table.insert(makeStr, GCO.GetPercentBarString(percentContribution, bInvertedColor, bNoGradient) .. " " .. Locale.Lookup(GameInfo.TechnologyContributionTypes[contributionType].Name)  .. " ".. tostring(currentContribution) .."/".. tostring(maxContribution) )
		end
		contribProgress = contribProgress + currentContribution
	end
	
	
	if TechResearchRow[techID] then
		for contributionType, data in pairs(TechResearchRow[techID]) do
			if data.MaxContributionPercent then -- not typeTag
				AddToString(techID, contributionType, typeTag, data.MaxContributionPercent)
			else -- using typeTag
				for typeTag, row in pairs(data) do
					AddToString(techID, contributionType, typeTag, row.MaxContributionPercent)
				end
			end
		end
	end
	
	if ResearchTechMax[techID] then
		for contributionType, maxContributionPercent in pairs(ResearchTechMax[techID]) do
			AddToString(techID, contributionType, nil, maxContributionPercent)
		end
	end
	
	-- Show Academic Research (= vanilla science)
	local academicProgress	= math.floor(totalProgress - contribProgress)
	if academicProgress > 0 then
		local progressPercent 	= (academicProgress / techCost) * 100
		table.insert(makeStr, GCO.GetPercentBarString((progressPercent), bInvertedColor, bNoGradient) .. " " .. Locale.Lookup(GameInfo.TechnologyContributionTypes["RESEARCH_ACADEMIC"].Name)  .. " ".. tostring(academicProgress) .."/".. tostring(techCost) )
	end
	
	return table.concat(makeStr, "[NEWLINE]")
end

function Research:ChangeYield(researchType, x, y, contributionType, value)
	local data 			= self:GetData()
	data.RsrchF			= data.RsrchF or {} -- ResearchField	: [rsrchKey][cntrKey] = value
	local rsrchKey		= tostring(GameInfo.TechnologyContributionTypes[researchType].Index)
	local cntrKey		= tostring(GameInfo.TechnologyContributionTypes[contributionType].Index)
	
	Dprint( DEBUG_RESEARCH_SCRIPT, GCO.Separator)
	Dprint( DEBUG_RESEARCH_SCRIPT, "Change Yield : ", Locale.Lookup(GameInfo.TechnologyContributionTypes[researchType].Name), contributionType)
	
	if not data.RsrchF[rsrchKey] then data.RsrchF[rsrchKey] = {} end
	
	data.RsrchF[rsrchKey][cntrKey] = (data.RsrchF[rsrchKey][cntrKey] or 0) + value
	
	if x and y and self.PlayerID == Game.GetLocalPlayer() then
		local pLocalPlayerVis = PlayersVisibility[self.PlayerID]
		if (pLocalPlayerVis ~= nil) then
			if (pLocalPlayerVis:IsRevealed(x, y)) then
				local sIcon		= GameInfo.TechnologyContributionTypes[researchType].IconString 	or ""
				local sColor	= GameInfo.TechnologyContributionTypes[researchType].ColorString 	or "[COLOR_FLOAT_SCIENCE]"
				local sText 	= sColor .. Locale.Lookup("LOC_RESEARCH_CONTRIBUTION_FLOAT", value, GameInfo.TechnologyContributionTypes[researchType].Name, sIcon, sColor)
				Game.AddWorldViewText(EventSubTypes.DAMAGE, sText, x, y, 0)
			end
		end
	end
	LuaEvents.RefreshTopPanelGCO()
end

function Research:GetYield(researchType)
	local data 			= self:GetData()
	data.RsrchF			= data.RsrchF or {} -- ResearchField	: [rsrchKey][cntrKey] = value
	local rsrchKey		= tostring(GameInfo.TechnologyContributionTypes[researchType].Index)
	return GCO.TableSummation(data.RsrchF[rsrchKey])
end

function Research:GetYieldTooltip(researchType)
	local data 			= self:GetData()
	data.RsrchF			= data.RsrchF or {} -- ResearchField	: [rsrchKey][cntrKey] = value
	local rsrchKey		= tostring(GameInfo.TechnologyContributionTypes[researchType].Index)
	
	local makeStr = {}
	if data.RsrchF[rsrchKey] then
		for cntrKey, value in pairs(data.RsrchF[rsrchKey]) do
			local contributionID	= tonumber(cntrKey)
			table.insert(makeStr, Locale.Lookup("LOC_TOP_PANEL_RESEARCH_YIELD_TOOLTIP", value, GameInfo.TechnologyContributionTypes[contributionID].Name))
		end
	end
	return table.concat(makeStr, "[NEWLINE]")
end

-----------------------------------------------------------------------------------------
-- City Research Functions
-----------------------------------------------------------------------------------------

local CityResearch = {}
CityResearch.__index = CityResearch

function CityResearch:Create(city)
   local rsrch = {}            		-- new CityResearch object
   setmetatable(rsrch,CityResearch)	-- make CityResearch handle lookup
   -- Initialize
   rsrch.City		= city
   rsrch.PlayerID 	= city:GetOwner()
   rsrch.Key 		= GCO.GetCityKey(city)
   return rsrch
end

function CityResearch:GetData()
	if not ExposedMembers.GCO.CityResearchData then GCO.Error("CityResearch is nil") end
	local r		= ExposedMembers.GCO.CityResearchData
	local data 	= r[self.Key]
	if not data then -- First call
		r[self.Key] = {}
		data 		= r[self.Key]
	end
	return data
end

function CityResearch:GetCache()
	local selfKey 	= self.Key
	if not _cached[selfKey] then _cached[selfKey] = {} end
	return _cached[selfKey]
end

function CityResearch:GetCached(key)
	local selfKey 	= self.Key
	if not _cached[selfKey] then _cached[selfKey] = {} end
	return _cached[selfKey][key]
end

function CityResearch:SetCached(key, value)
	local selfKey 	= self.Key
	if not _cached[selfKey] then _cached[selfKey] = {} end
	_cached[selfKey][key] = value
end

function CityResearch:GetValue(key)
	local Data = self:GetData()
	return Data[key]
end

function CityResearch:SetValue(key, value)
	local Data = self:GetData()
	Data[key] = value
end

function CityResearch:GetPlayer()
	return GCO.GetPlayer(self.PlayerID)
end


--=====================================================================================--
-- Other Functions
--=====================================================================================--
function DoResearchOnEvent(event, playerID, x, y, itemType) -- This function requires a Type, not an ID for items (UnitType, ResourceType, ...)

	Dprint( DEBUG_RESEARCH_SCRIPT, "DoResearchOnEvent : ", event, playerID, x, y, itemType)

	local contributionType	= event
	if EventsTechsList[contributionType] then
		local pResearch = Research:Create(playerID)

		for i, techID in ipairs(EventsTechsList[contributionType]) do
			Dprint( DEBUG_RESEARCH_SCRIPT, " - Checking Tech : ", Locale.Lookup(GameInfo.Technologies[techID].Name))
			-- Do we still havent researched that tech yet ?
			if not pResearch:HasTech(techID) then
			
				-- Can this Tech be unlocked by that event ?
				if TechUnlockEvent[techID] and TechUnlockEvent[techID][contributionType] then
				
					Dprint( DEBUG_RESEARCH_SCRIPT, " - Event can unlock Tech")
					
					local itemTagList = TechUnlockTags[techID] and TechUnlockTags[techID][contributionType]
					if itemType and itemTagList then
						-- Does that itemType has the TypeTag for this Event ?
						for i, itemTag in ipairs(itemTagList) do
							Dprint( DEBUG_RESEARCH_SCRIPT, "   - Check for tag : ", itemTag, TypeTags[itemType], TypeTags[itemType] and TypeTags[itemType][itemTag])
							if TypeTags[itemType] and TypeTags[itemType][itemTag] then
								pResearch:UnlockTech(techID, x, y)
							end
						end
					elseif itemTag == nil then 
						-- This unlock doesn't require an item
						pResearch:UnlockTech(techID, x, y)
					else
						-- we shouldn't be here
						GCO.Error("TagType ".. tostring(itemTag) .." exist in DB but DoResearchOnEvent was called without an ItemID for Tech = ".. Locale.Lookup(GameInfo.Technologies[techID].Name) .. ", Event = " ..tostring(contributionType))
					end
				end
				
				-- Is this Tech getting research points from that contributionType ?
				if TechResearchEvent[techID] and TechResearchEvent[techID][contributionType] then
					Dprint( DEBUG_RESEARCH_SCRIPT, " - Event can progress tech : ", Locale.Lookup(GameInfo.Technologies[techID].Name))
					local itemTagList = TechResearchTags[techID] and TechResearchTags[techID][contributionType]
					if itemType and itemTagList then
						-- Does that itemType has the TypeTag for this Event ?
						for i, itemTag in ipairs(itemTagList) do
							Dprint( DEBUG_RESEARCH_SCRIPT, "   - Check for tag : ", itemTag, TypeTags[itemType], TypeTags[itemType] and TypeTags[itemType][itemTag])
							if TypeTags[itemType] and TypeTags[itemType][itemTag] then
								local row = TechResearchRow[techID][contributionType][itemTag]
								pResearch:AddContribution(techID, x, y, contributionType, itemTag, row)
							end
						end
					elseif itemTag == nil then 
						-- This research doesn't require an item
						local row = TechResearchRow[techID][contributionType]
						pResearch:AddContribution(techID, x, y, contributionType, itemTag, row)
					else
						-- we shouldn't be here
						GCO.Error("TagType ".. tostring(itemTag) .." exist in DB but DoResearchOnEvent was called without an ItemID for Tech = ".. Locale.Lookup(GameInfo.Technologies[techID].Name) .. ", Event = " ..tostring(contributionType))
					end
				end
			else
				Dprint( DEBUG_RESEARCH_SCRIPT, " - TechType already Researched")
			end
		end
	else
		Dprint( DEBUG_RESEARCH_SCRIPT, " - No TechType listed for that EventType")
	end
	
	if EventsResearchList[contributionType] then
	
		local pResearch = Research:Create(playerID)

		for i, researchType in ipairs(EventsResearchList[contributionType]) do
		
			Dprint( DEBUG_RESEARCH_SCRIPT, " - Checking Research : ", Locale.Lookup(GameInfo.TechnologyContributionTypes[researchType].Name))
			
			-- Is this Research getting points from that contributionType ?
			local points	= (EventsResearchValue[researchType] and EventsResearchValue[researchType][contributionType]) or 0
			if points > 0 then
				Dprint( DEBUG_RESEARCH_SCRIPT, " - Event can progress Research...")
				local itemTagList = EventsResearchTags[researchType] and EventsResearchTags[researchType][contributionType]
				if itemType and itemTagList then
					-- Does that itemType has the TypeTag for this Event ?
					for i, itemTag in ipairs(itemTagList) do
						Dprint( DEBUG_RESEARCH_SCRIPT, "   - Check for tag : ", itemTag, TypeTags[itemType], TypeTags[itemType] and TypeTags[itemType][itemTag])
						if TypeTags[itemType] and TypeTags[itemType][itemTag] then
							pResearch:ChangeYield(researchType, x, y, contributionType, points)
						end
					end
				elseif itemTag == nil then 
					-- This research doesn't require an item
					pResearch:ChangeYield(researchType, x, y, contributionType, points)
				else
					-- we shouldn't be here
					GCO.Error("TagType ".. tostring(itemTag) .." exist in DB but DoResearchOnEvent was called without an ItemID for Research = ".. Locale.Lookup(GameInfo.TechnologyContributionTypes[researchType].Name) .. ", Event = " ..tostring(contributionType))
				end
			end
		end
	else
		Dprint( DEBUG_RESEARCH_SCRIPT, " - No ResearchType listed for that EventType")
	end
end

--=====================================================================================--
-- Events Functions
--=====================================================================================--

function OnLuaResearchEvent(eventType, playerID, x, y, itemType)
	DoResearchOnEvent(eventType, playerID, x, y, itemType)
end
LuaEvents.ResearchGCO.Add( OnLuaResearchEvent )

function OnResearchCompleted( playerID:number, techID:number, bIsCanceled:boolean)
	-- Is that tech unlocking a Government ?
	local govID	= TechUnlockGovernement[techID]
	if govID then
		local pResearch = Research:Create(playerID)
		pResearch:UnlockGovernement(govID)
	end
end
Events.ResearchCompleted.Add(OnResearchCompleted)

function OnPlayerTurnDone(playerID)
	-- neutralize Civics tree
	local pCulture	= Players[playerID]:GetCulture()
	if pCulture then
		pCulture:ChangeCurrentCulturalProgress(-pCulture:GetCultureYield())
	end
	
	-- do research turn
	local pResearch = Research:Create(playerID)
	pResearch:DoTurn()
end
LuaEvents.PlayerTurnDoneGCO.Add( OnPlayerTurnDone )
	
--=====================================================================================--
-- Shared Functions
--=====================================================================================--


--=====================================================================================--
-- Share functions for other contexts
--=====================================================================================--
function Initialize()
	if not ExposedMembers.GCO then ExposedMembers.GCO = {} end
	--
	ExposedMembers.GCO.Research 				= Research
	ExposedMembers.GCO.CityResearch 			= CityResearch
	--
	ExposedMembers.ResearchScript_Initialized 	= true
end
Initialize()