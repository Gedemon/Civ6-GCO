-----------------------------------------------------------------------------------------
--	FILE:	 GCO_ActionScreen.lua
--  Gedemon (2021)
-----------------------------------------------------------------------------------------

print ("Loading GCO_ActionScreen.lua...")


include( "InstanceManager" );
include( "SupportFunctions" );
include( "Civ6Common" );
include( "TeamSupport" );
include( "GameCapabilities" );
include( "PopupDialog" );

include( "GCO_TypeEnum" )
include( "GCO_SmallUtils" )

-- =========================================================================== --
-- Initialize
-- =========================================================================== --
-- Initialize first with what is already loaded from script contexts, we may need them before the next call to GameCoreEventPublishComplete after this file is loaded
local GCO 			= ExposedMembers.GCO 
local GameEvents	= ExposedMembers.GameEvents


-- =========================================================================== --
-- Defines
-- =========================================================================== --
g_ActionListIM		= InstanceManager:new( "ActionButton",  "Button" );
g_SubActionListIM	= InstanceManager:new( "ActionButton",  "Button" );

local SlaveClassID 			= GameInfo.Resources["POPULATION_SLAVE"].Index
local foodResourceID 		= GameInfo.Resources["RESOURCE_FOOD"].Index
local materielResourceID	= GameInfo.Resources["RESOURCE_MATERIEL"].Index

local PANEL_OFFSET			= 100
local BACK_BUTTON_OFFSET	= 54

local g_plotID 			= nil
local g_playerID		= nil
local g_unitID			= nil
local g_Parameters		= nil
local g_Menu			= nil
local g_ProductionType	= nil

local m_selectVillageInstance 	= nil -- to be able to manage the button from events when clicking on a village plot

-- =========================================================================== --
-- Handle Player Action
-- =========================================================================== --

function OnOptionClicked(kOption)

	if kOption.DiplomacyType == DiplomacyTypes.Deals and kOption.DealType then
		kOption.OnStart = "PlayerDealAction" -- Send this GameEvent when processing the operation
		UI.RequestPlayerOperation(Game.GetLocalPlayer(), PlayerOperations.EXECUTE_SCRIPT, kOption)
		Close()
	end	
end

-- =========================================================================== --
--
-- =========================================================================== --

local tMainMenu = {
	{Text = "[ICON_List] Change Production", 	SubMenu="Production" },
	{Text = "[ICON_List] Select Action", 		SubMenu="Action" },

}

function OnMenuClicked(kParameters, sMenu, sProductionType)
	CreateActionPanel(kParameters, sMenu, sProductionType)
end

function OnVillageSelected(villagePlotID)
	local pPlot = GCO.GetPlotByIndex(villagePlotID)
	if pPlot then
		-- Set the confirm placement button
		m_selectVillageInstance.ButtonText:LocalizeAndSetText( "LOC_VILLAGE_CONFIRM_PLACEMENT", pPlot:GetX(), pPlot:GetY())
		m_selectVillageInstance.Button:RegisterCallback( Mouse.eLClick, function() OnConfirmPlacementClicked(g_playerID, g_plotID, villagePlotID); end)
		m_selectVillageInstance.Button:SetDisabled( false )
	end
end
LuaEvents.VillageSelected.Add(OnVillageSelected) -- called from PlotInfo.lua when clicking a potential village position

function OnConfirmPlacementClicked(playerID, centralPlotID, villagePlotID)

	print("OnConfirmPlacementClicked", playerID, centralPlotID, villagePlotID)
	
	local kParameters		= {}
	kParameters.OnStart 	= "PlayerTribeDo" -- Send this GameEvent when processing the operation
	kParameters.PlotID		= centralPlotID
	kParameters.TargetID 	= villagePlotID
	kParameters.Type		= "VILLAGE_CREATE"
	UI.RequestPlayerOperation(Game.GetLocalPlayer(), PlayerOperations.EXECUTE_SCRIPT, kParameters)
	Close()

end

function OnProductionClicked(kParameters, sProductionType)

	print("OnProductionClicked", sProductionType)
	
	kParameters.OnStart 	= "PlayerTribeDo" -- Send this GameEvent when processing the operation
	kParameters.Type		= sProductionType
	UI.RequestPlayerOperation(Game.GetLocalPlayer(), PlayerOperations.EXECUTE_SCRIPT, kParameters)
	Close()

end

function OnActionClicked(kParameters, sActionType)

	print("OnActionClicked", sActionType)
	
	kParameters.OnStart 	= "PlayerTribeDo" -- Send this GameEvent when processing the operation
	kParameters.Type		= sActionType
	UI.RequestPlayerOperation(Game.GetLocalPlayer(), PlayerOperations.EXECUTE_SCRIPT, kParameters)
	Close()

end

function CreateActionPanel(kParameters, sMenu, sProductionType)
	GCO.Monitor(CreateActionPanelP, {kParameters,sMenu,sProductionType}, "CreateActionPanel")
end


function CreateActionPanelP(kParameters, sMenu, sProductionType)
	
	--if not(GCO.CanOpenActionPanel(kParameters)) then return end
print("CreateActionPanelP", sMenu)	
for k, v in pairs(kParameters) do print(k,v) end
	--ExposedMembers.GCO.SelectedCentralVillagePlotID = kParameters.PlotID
	
	LuaEvents.HideVillagePlots()
		
	local buttonIM:table;
	local stackControl:table;
	local selectionText :string = "[SIZE_16]";	-- Resetting the string size for the new button instance
	buttonIM = g_SubActionListIM
	stackControl = Controls.OptionStack;
	buttonIM:ResetInstances();
	
	
	g_playerID			= kParameters.PlayerID
	g_plotID			= kParameters.PlotID
	g_unitID			= kParameters.UnitID
	g_Parameters		= kParameters
	g_Menu				= sMenu
	g_ProductionType	= sProductionType
	
	local iPlayer		= kParameters.PlayerID
	local pPlayer		= GCO.GetPlayer(iPlayer)
	local iPanelOffset	= PANEL_OFFSET
	local bIsMigrating	= pPlayer:GetValue("MigrationTurn") ~= nil
print("bIsMigrating", bIsMigrating, pPlayer:GetValue("MigrationTurn") )	
	--
	if kParameters.UnitID then
	
		if not bIsMigrating then
			Close()
			return
		end
	
		local pUnit =  GCO.GetUnit(iPlayer, kParameters.UnitID)
	
		if GameInfo.Units[pUnit:GetType()].UnitType == "UNIT_CARAVAN" then
		
			Controls.TitleText:LocalizeAndSetText( pUnit:GetName() )
			
			-- get plot
			local pPlot = GCO.GetPlotByIndex(kParameters.PlotID)
			
			-- check if can create settlement here
			local bCanSettle, sReason = GCO.CanCaravanSettle(pPlot, iPlayer)
			
			local instance :table 	= buttonIM:GetInstance(stackControl)
			instance.ButtonText:LocalizeAndSetText( "LOC_VILLAGE_SETTLE_HERE" ) 
			instance.Button:RegisterCallback( Mouse.eLClick, function() OnActionClicked(kParameters, "CREATE_NEW_SETTLEMENT"); end)
			
			if bCanSettle then
				instance.Button:SetDisabled( false )
				instance.Button:SetToolTipString("")
			
			else
				instance.Button:SetDisabled( true )
				instance.Button:SetToolTipString(sReason)
			end
		
			Controls.Title1:LocalizeAndSetText( "" )
			Controls.Text1:SetText("")
			Controls.Header1:SetText("")
			Controls.List1:SetText("")
				
			Controls.Title2:SetText("")
			Controls.Header2:SetText("")
			Controls.List2:SetText("")
			
			Controls.Title3:SetText("")
			Controls.Text3:SetText("")
			Controls.Header3:SetText("")
			Controls.List3:SetText("")
			
			Controls.Title4:SetText("")
			Controls.Text4:SetText("")
			Controls.Header4:SetText("")
			Controls.List4:SetText("")
			
			Controls.BackButton:SetHide( true )
		else
			Close()
			return
		end
	--
	else
	
		if bIsMigrating then 
			Close()
			return
		end
	
		local village	= GCO.GetTribalVillageAt(kParameters.PlotID)
		local pPlot 	= GCO.GetPlotByIndex(kParameters.PlotID)
		
		local backMenu	= "Main" --
		
		Controls.TitleText:LocalizeAndSetText( GameInfo.Improvements[village.Type].Name )
		
		if sMenu == "Main" then
			for _, row in ipairs(tMainMenu) do
				local instance :table 	= buttonIM:GetInstance(stackControl)
				instance.ButtonText:LocalizeAndSetText( row.Text )
				instance.Button:RegisterCallback( Mouse.eLClick, function() OnMenuClicked(kParameters, row.SubMenu); end)
				if row.SubMenu == "Production" and village.TurnsLeft then
					instance.Button:SetDisabled( true )
					instance.Button:SetToolTipString(Locale.Lookup("LOC_VILLAGE_PRODUCTION_LOCKED"))
				else
					instance.Button:SetDisabled( false )
					instance.Button:SetToolTipString("")
				end
			end
		end
		
		local function GetCostString(row) 
			local tCostStr = {}
			if row.GoldCost then
				table.insert(tCostStr, tostring(row.GoldCost).."[ICON_Gold]")
			end
			if row.PopulationCost then
				table.insert(tCostStr, tostring(row.PopulationCost).."[ICON_Position]")
			end
			if row.MaterielCost then
				table.insert(tCostStr, tostring(row.MaterielCost).."[ICON_RESOURCE_MATERIEL]")
			end
			if row.BaseTurns then
				table.insert(tCostStr, tostring(row.BaseTurns).."[ICON_Turn]")
			end
			return #tCostStr > 0 and " ("..table.concat(tCostStr,", ")..")" or ""
		end
		
		if sMenu == "Production" then

			for row in GameInfo.TribalVillageProductions() do
				--local kProductionParameters				= {}
				--kProductionParameters.ProductionType	= row.ProductionType
				--kProductionParameters.MenuParameters	= kParameters
				
				--local bCanProduce, bCanShow, sReason = GCO.TribeCanProduce(row.ProductionType, kParameters)
				local bCanProduce, bCanShow, sReason = GCO.TribeCanDo(kParameters, row)
				if bCanShow	then
					
					local instance	:table	= buttonIM:GetInstance(stackControl);
					instance.ButtonText:SetText( Locale.Lookup(row.Name) .. GetCostString(row))
									
					if row.ProductionType == "VILLAGE_CREATE" then -- special case, require map selection
						if bCanProduce then
							instance.Button:RegisterCallback( Mouse.eLClick, function() OnMenuClicked(kParameters, "VillageSelection"); end)
							instance.Button:SetDisabled( false )
						else
							instance.Button:SetDisabled( true )
						end
					else
						if bCanProduce then
							instance.Button:RegisterCallback( Mouse.eLClick, function() OnProductionClicked(kParameters, row.ProductionType); OnMenuClicked(kParameters, "Main", row.ProductionType); end)
							instance.Button:SetDisabled( false )
						else
							instance.Button:SetDisabled( true )
						end
					end
					instance.Button:SetToolTipString(sReason) -- sReason also include description if it exits
				end
			end
		end
		
		if sMenu == "Action" then
			for row in GameInfo.TribalVillageActions() do
				
				local bCanDo, bCanShow, sReason = GCO.TribeCanDo(kParameters, row)
				--if GCO.TribeCanDoAction(row.ActionType, kParameters)	then
				if bCanShow	then
					--local kActionParameters				= {}
					--kActionParameters.ActionType		= row.ActionType
					--kActionParameters.MenuParameters	= kParameters
					local instance	:table	= buttonIM:GetInstance(stackControl);
					instance.ButtonText:SetText( Locale.Lookup(row.Name) .. GetCostString(row))
					if bCanDo then
						if row.ActionType =="START_MIGRATION" or row.ActionType =="CREATE_CITY" then -- We don't want to return to the main menu in those cases
							instance.Button:RegisterCallback( Mouse.eLClick, function() OnActionClicked(kParameters, row.ActionType); end)
						else
							instance.Button:RegisterCallback( Mouse.eLClick, function() OnActionClicked(kParameters, row.ActionType); OnMenuClicked(kParameters, "Main"); end)
						end
						instance.Button:SetDisabled( false )
					else
						instance.Button:SetDisabled( true )
					end
					instance.Button:SetToolTipString(sReason) -- sReason also include description if it exits
				end
			end
		end
		
		--
		-- Set titles and village information
		--
		
		if sMenu == "VillageSelection" then
			backMenu = "Production"
			local instance	:table	= buttonIM:GetInstance(stackControl);
			instance.ButtonText:LocalizeAndSetText( "LOC_SELECT_VILLAGE_POSITION" )
			instance.Button:SetDisabled( true )
			m_selectVillageInstance = instance
			LuaEvents.SelectVillageClicked(kParameters.PlotID) -- show potential village plots in PlotInfo.lua
			
			Controls.Title1:LocalizeAndSetText( "Create New Village" )
		else
			m_selectVillageInstance = nil
		
			if village.IsCentral or village.TurnsLeft then
				local productionType	= sProductionType or village.ProductionType
				local sProductionString = Locale.Lookup("LOC_VILLAGE_CURRENT_TASK", GameInfo.TribalVillageProductions[productionType].Name)
				if village.TurnsLeft then
					sProductionString = sProductionString .." ".. tostring(village.TurnsLeft).."[ICON_Turn]"
				elseif productionType == "PRODUCTION_MATERIEL" or productionType == "PRODUCTION_EQUIPMENT" then
					sProductionString = sProductionString .." ".. Locale.Lookup("LOC_VILLAGE_PRODUCTION_OUTPUT", GCO.GetTribeOutputFactor(pPlot))
				end
				Controls.Title1:LocalizeAndSetText( sProductionString )
			else
				Controls.Title1:LocalizeAndSetText( "" )
			end
		end
		
		--Controls.Title1:LocalizeAndSetText( "Title1" )
		--Controls.Header1:LocalizeAndSetText( "Header1" )
		--Controls.List1:LocalizeAndSetText( "List1" )
		
		Controls.Title2:SetText("")
		Controls.Header2:SetText("")
		Controls.List2:SetText("")
		
		Controls.Title3:SetText("")
		Controls.Text3:SetText("")
		Controls.Header3:SetText("")
		Controls.List3:SetText("")
		
		Controls.Title4:SetText("")
		Controls.Text4:SetText("")
		Controls.Header4:SetText("")
		Controls.List4:SetText("")
				
		if sMenu == "Main" then
			local tCulturestring, cultureHeader = pPlot:GetCultureString()
			if #tCulturestring > 0 then
				local sToolTipString 	= table.concat(tCulturestring, "[NEWLINE]")
				Controls.Title2:LocalizeAndSetText("LOC_CITYBANNER_POPULATION_TITLE")
				Controls.Header2:SetText(cultureHeader)
				Controls.List2:SetText(sToolTipString)
			end
			
			-- food string
			--LOC_CITYBANNER_FOOD_STOCK_TITLE
			--village.FoodRequired
			
			local tFoodString 	= {}
			local foodStock		= 0
			for _, resourceID in ipairs(GCO.GetEdibleFoodList()) do
			
				local stock = pPlot:GetStock(resourceID)
				
				if stock > 0 then
					foodStock			= foodStock + stock
					local resRow 		= GameInfo.Resources[resourceID]
					local variation		= stock - pPlot:GetPreviousStock(resourceID)
					local rowString		= ""--GCO.GetResourceIcon(resourceID)
				
					rowString 			= Indentation(Locale.Lookup(resRow.Name), 15) --rowString .. " " .. 
					rowString 			= rowString .. "|" .. Indentation(stock, 4, true) .."/"..Indentation(pPlot:GetMaxStock(resourceID), 4, true)
					rowString			= rowString .. " |" .. (variation < 0 and "[COLOR_Civ6Red]-"..Indentation(-variation, 3, true) or "[COLOR_Civ6Green]+"..Indentation(variation, 3, true)) .."[ENDCOLOR]"
					table.insert(tFoodString, rowString)
				end
			end
			if #tFoodString > 0 then
				--Controls.Header3:LocalizeAndSetText("LOC_VILLAGE_PRODUCTION_HEADER")
				Controls.List3:SetText(table.concat(tFoodString, "[NEWLINE]"))
			end
			
			local foodTitleStr = Locale.Lookup("LOC_CITYBANNER_FOOD_STOCK_TITLE")
			
			if village.FoodRequired and village.FoodProduced then
				--foodTitleStr = Locale.Lookup("LOC_VILLAGE_FOOD_REQUIRED", village.FoodRequired, foodStock, village.FoodProduced)
				
				Controls.Text3:SetText(Locale.Lookup("LOC_VILLAGE_FOOD_REQUIRED", village.FoodRequired, foodStock, village.FoodProduced))
			end
			
			if foodStock > 0 or village.FoodRequired then
				Controls.Title3:SetText(foodTitleStr)
			end
			
			if village.IsCentral then
				Controls.Title4:LocalizeAndSetText("LOC_TRIBE_MATERIEL_STOCK_TITLE")
				Controls.Text4:LocalizeAndSetText("LOC_TRIBE_MATERIEL_STOCK_TEXT", village.MaterielProduced or 0, pPlot:GetStock(materielResourceID))
			end
			
			Controls.BackButton:SetHide( true )
		else
			Controls.BackButton:RegisterCallback( Mouse.eLClick, function() OnMenuClicked(kParameters, backMenu); end);
			Controls.BackButton:SetHide( false )
			iPanelOffset = iPanelOffset + BACK_BUTTON_OFFSET
		end
	end
	
	-- Artificial offset for buttons below the Village summary table
	Controls.DebugTxt:LocalizeAndSetText( " " )
	
	Controls.InfoStack:CalculateSize();
	stackControl:CalculateSize();
	Controls.CenterPanel:SetHide(false)
	Controls.CenterPanel:SetSizeY(stackControl:GetSizeY() + Controls.InfoStack:GetSizeY() + iPanelOffset );
	
end

function Close()
	Controls.CenterPanel:SetHide(true)
	LuaEvents.HideVillagePlots()
	g_playerID			= nil
	g_plotID			= nil
	g_unitID			= nil
	g_Parameters		= nil
	g_Menu				= nil
	g_ProductionType	= nil
	--ExposedMembers.GCO.SelectedCentralVillagePlotID = nil
end

function Refresh()
	if g_Parameters and g_Menu then
		CreateActionPanel(g_Parameters, g_Menu, g_ProductionType)
	end
end


function OnUnitSelectionChanged(playerID, unitID, x, y, i5, bSelect, b2)
	if not Controls.CenterPanel:IsHidden() and not bSelect then
		Close()
	elseif Controls.CenterPanel:IsHidden() and bSelect and playerID == g_playerID and unitID == g_unitID then
		Controls.CenterPanel:SetHide(false)
	end
end


-- ===========================================================================
--	Use the mask lens layer to dim hexes not in the list.
--  (Code from TutorialScenarioBase.lua)
-- ===========================================================================
function DimHexes( kHexIndexes:table )
	local mapHexMask : number = UILens.CreateLensLayerHash("Action_Hex_Mask");
	UILens.SetLayerHexesArea( mapHexMask, Game.GetLocalPlayer(), kHexIndexes );
end

-- ===========================================================================
function ClearDimHexes()
	local mapHexMask : number = UILens.CreateLensLayerHash("Action_Hex_Mask");
	UILens.ClearLayerHexes( mapHexMask );
end

-- =========================================================================== --
--	initialize
-- =========================================================================== --
function Initialize()
	--[[
	Controls.QuitButton:RegisterCallback(Mouse.eMouseEnter, function() UI.PlaySound("Main_Menu_Mouse_Over"); end);
	Controls.QuitButton:RegisterCallback(Mouse.eLClick, Close);
	--]]
	Controls.Close:RegisterCallback(Mouse.eMouseEnter, function() UI.PlaySound("Main_Menu_Mouse_Over"); end);
	Controls.Close:RegisterCallback(Mouse.eLClick, Close);
	Controls.GCO_ActionScreen:SetHide(false)
	Controls.CenterPanel:SetHide(true)
	LuaEvents.ShowActionScreenGCO.Add( CreateActionPanel )
	LuaEvents.ShowDiploScreenGCO.Add( Close )
	Events.UnitSelectionChanged.Add(OnUnitSelectionChanged)
	LuaEvents.RefreshActionScreenGCO.Add( Refresh )
end
Initialize()