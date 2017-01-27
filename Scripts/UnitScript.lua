--=====================================================================================--
--	FILE:	 UnitScript.lua
--  Gedemon (2017)
--=====================================================================================--

print ("Loading UnitScript.lua...")

-----------------------------------------------------------------------------------------
-- Defines
-----------------------------------------------------------------------------------------

UnitHitPointsTable = {} -- cached table to store the value of an unit components based on it's HP

-- This should be the first file loaded...
--ExposedMembers.SaveLoad_Initialized = false
--ExposedMembers.Utils_Initialized = false

-----------------------------------------------------------------------------------------
-- Initialize Functions
-----------------------------------------------------------------------------------------

GCO = {}
function InitializeUtilityFunctions() -- Get functions from other contexts
	if ExposedMembers.SaveLoad_Initialized and ExposedMembers.Utils_Initialized then -- can't use GameEvents.ExposedFunctionsInitialized.TestAll() because it will be called before all required test are added to the event...
		GCO = ExposedMembers.GCO
		UI = ExposedMembers.UI
		ExposedMembers.UI = nil -- we may want to clean after everything initialized if we need this in another script context...
		Events.GameCoreEventPublishComplete.Remove( InitializeUtilityFunctions )
		print ("Exposed Functions from other contexts initialized...")
		InitializeTables()
	end
end
Events.GameCoreEventPublishComplete.Add( InitializeUtilityFunctions )

function InitializeTables() -- Tables that may require other context to be loaded (saved/loaded tables)
	if not ExposedMembers.UnitData then ExposedMembers.UnitData = ExposedMembers.GCO.LoadTableFromSlot("UnitData") or {} end
end

function Initialize() -- Everything that can be initialized immediatly after loading this file(cached tables)
	CreateUnitHitPointsTable()
end

function OnEnterGame() -- Everything that can only be initialized after everything as loaded and the game is initialized
	
end
Events.LoadScreenClose.Add(OnEnterGame)

-----------------------------------------------------------------------------------------
-- Unit composition
-----------------------------------------------------------------------------------------
local maxHP = GlobalParameters.COMBAT_MAX_HIT_POINTS -- 100
local minCompLeftFactor = GameInfo.GlobalParameters["MIN_COMPONENT_LEFT_IN_UNIT_FACTOR"].Value -- Modded global parameters are not in GlobalParameters ?????
local maxCompLeftFactor = GameInfo.GlobalParameters["MAX_COMPONENT_LEFT_IN_UNIT_FACTOR"].Value
function GetNumComponentAtHP(maxNumComponent, HPLeft)
	local numComponent = 0
	local maxCompLeft100 = 0
	local minCompLeft100 = ((HPLeft * 100) * (maxNumComponent / maxHP) * (HPLeft / maxHP))
	if maxHP > maxNumComponent then
		maxCompLeft100 = math.min(HPLeft * 100, math.min(maxNumComponent * 100, (HPLeft * 100 / (maxNumComponent / maxHP))))
	else
		maxCompLeft100 = math.min(maxNumComponent * 100, HPLeft * 100 * ( maxNumComponent / maxHP))
	end	
	local numComponent100 = math.max( 100, ((( minCompLeft100 * minCompLeftFactor) + ( maxCompLeft100 * maxCompLeftFactor)) / ( minCompLeftFactor + maxCompLeftFactor )))
	numComponent = math.ceil(numComponent100 / 100)
	return numComponent
end

function CreateUnitHitPointsTable()
	for row in GameInfo.Units() do 
		UnitHitPointsTable[row.Index] = {}
		local Personnel = row.Personnel
		local Vehicules = row.Vehicules
		local Horses = row.Horses
		local Materiel = row.Materiel
		for hp = 1, maxHP do
			UnitHitPointsTable[row.Index][hp] = {}
			if Personnel > 0 then UnitHitPointsTable[row.Index][hp].Personnel = GetNumComponentAtHP(Personnel, hp) else UnitHitPointsTable[row.Index][hp].Personnel = 0 end
			if Vehicules > 0 then UnitHitPointsTable[row.Index][hp].Vehicules = GetNumComponentAtHP(Vehicules, hp) else UnitHitPointsTable[row.Index][hp].Vehicules = 0 end
			if Horses > 0 then UnitHitPointsTable[row.Index][hp].Horses = GetNumComponentAtHP(Horses, hp) else UnitHitPointsTable[row.Index][hp].Horses = 0 end
			if Materiel > 0 then UnitHitPointsTable[row.Index][hp].Materiel = GetNumComponentAtHP(Materiel, hp) else UnitHitPointsTable[row.Index][hp].Materiel = 0 end
		end
	end
end

--------------------------------------------------------------
-- Units Initialization
--------------------------------------------------------------

-- return unique key for units table [unitID,playerID]
function GetUnitKey(unit)
	if unit then
		local ownerID = unit:GetOwner()
		local unitID = unit:GetID()
		local unitKey = unitID..","..ownerID
		return unitKey
	else
		print("- WARNING: unit is nil for GetUnitKey()")
	end
end
ExposedMembers.GetUnitKey = GetUnitKey

function RegisterNewUnit(playerID, unit) -- unit is object, not ID

	local unitType = unit:GetType()
	local unitID = unit:GetID()
	local unitKey = GetUnitKey(unit)
	local hp = unit:GetMaxDamage() - unit:GetDamage()
	local reservePseudoHP = GCO.Round(maxHP / 2)

	ExposedMembers.UnitData[unitKey] = { 
		UniqueID = unitKey.."-"..os.clock(), -- for linked statistics
		--TurnCreated = Game.GetGameTurn(),
		Personnel 			= UnitHitPointsTable[unitType][hp].Personnel,
		Vehicules 			= UnitHitPointsTable[unitType][hp].Vehicules,
		Horses 				= UnitHitPointsTable[unitType][hp].Horses,
		Materiel 			= UnitHitPointsTable[unitType][hp].Materiel,
		
		PersonnelReserve	= GCO.Round(UnitHitPointsTable[unitType][reservePseudoHP].Personnel / 10) * 10,
		VehiclesReserve		= GCO.Round(UnitHitPointsTable[unitType][reservePseudoHP].Vehicules / 10) *10,
		HorsesReserve		= GCO.Round(UnitHitPointsTable[unitType][reservePseudoHP].Horses / 10) *10,
		MaterielReserve		= GCO.Round(UnitHitPointsTable[unitType][reservePseudoHP].Materiel / 10) *10,
		
		WoundedPersonnel	= 0,
		DamagedVehicles		= 0,
		Prisonners			= 0,
		
		Moral 				= 100,
		Alive 				= true,
		TotalXP 			= unit:GetExperience():GetExperiencePoints(),
		CombatXP 			= 0,
	}

	LuaEvents.NewUnitCreated()
end

function InitializeUnit(playerID, unitID)
	local unit = UnitManager.GetUnit(playerID, unitID)
	if unit then
		local unitKey = GetUnitKey(unit)
	
		if ExposedMembers.UnitData[unitKey] then
			-- unit already registered, don't add it again...
			print("  - ".. unit:GetName() .." is already registered") 
			return
		end

		print ("Initializing new unit (".. unit:GetName() ..") for player #".. tostring(playerID))
		RegisterNewUnit(playerID, unit)
		print("-------------------------------------")
	else
		print ("- WARNING : tried to initialize nil unit for player #".. tostring(playerID))
	end

end
Events.UnitAddedToMap.Add( InitializeUnit )

--------------------------------------------------------------
-- Damage received
--------------------------------------------------------------

function OnDamageChanged(playerID, unitID, finalDamage, initialDamage)
	local unit = UnitManager.GetUnit(playerID, unitID)
	local unitType = unit:GetType()
	if finalDamage > initialDamage then -- damage received
		if unit then		
			local unitKey = GetUnitKey(unit)
			if ExposedMembers.UnitData[unitKey] then
			
				local initialHP = unit:GetMaxDamage() - initialDamage
				local finalHP = unit:GetMaxDamage() - finalDamage
				local diffPersonnel = UnitHitPointsTable[unitType][initialHP].Personnel - UnitHitPointsTable[unitType][finalHP].Personnel 
				local diffVehicules = UnitHitPointsTable[unitType][initialHP].Vehicules - UnitHitPointsTable[unitType][finalHP].Vehicules 
				local diffHorses 	= UnitHitPointsTable[unitType][initialHP].Horses	- UnitHitPointsTable[unitType][finalHP].Horses	
				local diffMateriel 	= UnitHitPointsTable[unitType][initialHP].Materiel 	- UnitHitPointsTable[unitType][finalHP].Materiel 
				
				-- Handle difference
				
				-- simple version
				ExposedMembers.UnitData[unitKey].Personnel  = ExposedMembers.UnitData[unitKey].Personnel  	- diffPersonnel 
				ExposedMembers.UnitData[unitKey].Vehicules  = ExposedMembers.UnitData[unitKey].Vehicules  	- diffVehicules 
				ExposedMembers.UnitData[unitKey].Horses	    = ExposedMembers.UnitData[unitKey].Horses	  	- diffHorses 	
				ExposedMembers.UnitData[unitKey].Materiel 	= ExposedMembers.UnitData[unitKey].Materiel 	- diffMateriel 
				
				LuaEvents.UnitsCompositionUpdated(playerID, unitID)
				
				-- visualize
				local sText

				if diffPersonnel > 0 then
					sText = "- ".. tostring(diffPersonnel).."[ICON_Position]"
					UI.AddWorldViewText(EventSubTypes.DAMAGE, sText, unit:GetX(), unit:GetY(), 0)
				end
				
				if diffVehicules > 0 then
					sText = "- ".. tostring(diffVehicules).."[ICON_DISTRICT_HANSA]"
					UI.AddWorldViewText(EventSubTypes.DAMAGE, sText, unit:GetX(), unit:GetY(), 0)
				end
				
				if diffHorses > 0 then
					sText = "- ".. tostring(diffHorses).."[ICON_RESOURCE_HORSES]"
					UI.AddWorldViewText(EventSubTypes.DAMAGE, sText, unit:GetX(), unit:GetY(), 0)
				end
				
				if diffMateriel > 0 then
					sText = "- ".. tostring(diffMateriel).."[ICON_Charges]"
					UI.AddWorldViewText(EventSubTypes.DAMAGE, sText, unit:GetX(), unit:GetY(), 0)
				end
			else
				print("WARNING: no entry in UnitData for OnDamageChanged for player #".. tostring(playerID) ..", unitID = ".. tostring(unitID) ..", unit name = ".. unit:GetName())
			end
		else -- dead already ?
			print("WARNING: unit is nil for OnDamageChanged for player #".. tostring(playerID) ..", unitID = ".. tostring(unitID))		
		end
	end
end
--Events.UnitDamageChanged.Add(OnDamageChanged)


function OnCombat( combatResult )
	local attacker = combatResult[CombatResultParameters.ATTACKER]
	local defender = combatResult[CombatResultParameters.DEFENDER]
end
Events.Combat.Add( OnCombat )

--------------------------------------------------------------
-- Healing
--------------------------------------------------------------

-----------------------------------------------------------------------------------------
-- Save the tables
-----------------------------------------------------------------------------------------

function SaveTables()
	GCO.SaveTableToSlot(ExposedMembers.UnitData, "UnitData")	
end
LuaEvents.SaveTables.Add(SaveTables)

-----------------------------------------------------------------------------------------
-- Initialize after loading the file...
-----------------------------------------------------------------------------------------

Initialize()


-----------------------------------------------------------------------------------------
-- Cleaning on exit
-----------------------------------------------------------------------------------------
function Cleaning()
	print ("Cleaning GCO stuff on LeaveGameComplete...")
	ExposedMembers.SaveLoad_Initialized = nil
	ExposedMembers.Utils_Initialized = nil
	ExposedMembers.UnitData = nil
	ExposedMembers.GCO = nil
	ExposedMembers.GetUnitKey = nil
end
Events.LeaveGameComplete.Add(Cleaning)

function TestA()
	print ("Calling TestA...")
end
function TestB()
	print ("Calling TestB...")
end
function TestC()
	print ("Calling TestC...")
end
Events.LoadComplete.Add(TestA)
Events.RequestSave.Add(TestB)
Events.RequestLoad.Add(TestC)
--EndGameView