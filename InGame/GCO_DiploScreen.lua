-----------------------------------------------------------------------------------------
--	FILE:	 GCO_DiploScreen.lua
--  Gedemon (2021)
-----------------------------------------------------------------------------------------

print ("Loading GCO_DiploScreen.lua...")


include( "InstanceManager" );
include( "SupportFunctions" );
include( "Civ6Common" );
include( "LeaderSupport" );
include( "DiplomacyRibbonSupport" );
include( "DiplomacyStatementSupport" );
include( "TeamSupport" );
include( "GameCapabilities" );
include( "LeaderIcon" );
include( "PopupDialog" );
include( "CivilizationIcon" );

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

local DIPLO_PANEL_OFFSET = 100 -- 180 with close button at bottom

local g_unitID 		= nil
local g_playerID	= nil

-- =========================================================================== --
-- Handle Player Action
-- =========================================================================== --

function OnOptionClicked(kOption)

	if kOption.DiplomacyType == DiplomacyTypes.Deals and kOption.DealType then
		kOption.OnStart = "PlayerDealAction" -- Send this GameEvent when processing the operation
		UI.RequestPlayerOperation(Game.GetLocalPlayer(), PlayerOperations.EXECUTE_SCRIPT, kOption)
		Close()
		
		-- Debug
		for i = 1, 63 do
		
			local player 	= Players[i]
			local treasury 	= player and player:GetTreasury()
			if treasury then
				print("treasury player#", i, " = ", treasury:GetGoldBalance())
			end
		end
		--
	end	
end

-- =========================================================================== --
--
-- =========================================================================== --


function CreateDiploPanel(kParameters)
	GCO.Monitor(CreateDiploPanelP, {kParameters}, "CreateDiploPanel")
end


function CreateDiploPanelP(kParameters)

	kParameters.ActorID = kParameters.ActorID or Game.GetLocalPlayer() -- Set the actor of the diplomatic action for GamePlay checks
	
	if not(GCO.CanOpenDiplomacy(kParameters)) then return end
	
	local buttonIM:table;
	local stackControl:table;
	local selectionText :string = "[SIZE_16]";	-- Resetting the string size for the new button instance
	buttonIM = g_SubActionListIM
	stackControl = Controls.OptionStack;
	buttonIM:ResetInstances();
	
	
	g_playerID		= kParameters.PlayerID
	g_unitID		= kParameters.UnitID
	
	local iPlayer	= kParameters.PlayerID
	local iUnit		= kParameters.UnitID
	local pPlayer	= Players[iPlayer]
	local tOptions	= kParameters.Options or {}
	
	if (pPlayer ~= nil) then
		local playerConfig = PlayerConfigurations[iPlayer];
		if (playerConfig ~= nil) then
			-- Set the civ icon
			local civIconController = CivilizationIcon:AttachInstance(Controls.CivIcon);
			civIconController:UpdateIconFromPlayerID(iPlayer);
			-- Set the leader/Unit name
			local leaderDesc = playerConfig:GetLeaderName();
			Controls.PlayerNameText:LocalizeAndSetText( Locale.ToUpper( Locale.Lookup(leaderDesc)));
			Controls.CivNameText:LocalizeAndSetText( Locale.ToUpper( Locale.Lookup(playerConfig:GetCivilizationDescription())));
			if iUnit then
				local pUnit = pPlayer:GetUnits():FindID(iUnit)
				if pUnit then
					Controls.PlayerNameText:LocalizeAndSetText( Locale.Lookup(pUnit:GetName()));
				end
			end
		end
	end
	
	-- Get deals
	for row in GameInfo.DiplomaticDealsGCO() do
		if GCO.IsDealValid(kParameters, row) then
			local value 			= GCO.GetDealValue(kParameters, row)
			local valueStr			= value > 0 and " ("..tostring(value).."[ICON_Gold])" or ""
			local duration			= row.Duration or 0
			local durationStr		= duration > 0 and " (+"..tostring(duration).."[ICON_Turn])" or ""
			local text 				= Locale.Lookup(row.Name) .. valueStr .. durationStr
			--row.Cost				= value -- no need to calculate the cost again in GamePlay
			local bEnable, sReason	= GCO.IsDealEnabled(kParameters, row)
			-- DiplomacyTypes.Deals, DiplomacyTypes.Treaties, DiplomacyTypes.State
			table.insert(tOptions, {Text = text, IsEnabled = bEnable, DisabledReason = sReason, PlayerID = iPlayer, UnitID = iUnit, DiplomacyType = DiplomacyTypes.Deals, DealType = row.DealType})
		end
	end

	for _, kOption in ipairs (tOptions) do
		local instance		:table		= buttonIM:GetInstance(stackControl);
		local selectionText :string		= selectionText.. tostring(kOption.Text);
		local callback		:ifunction;
		local tooltipString	:string		= nil;

		instance.Button:SetToolTipString(selectionText);
		instance.ButtonText:SetText( selectionText )
		
		if not kOption.IsEnabled then
			instance.Button:SetDisabled( true )
			instance.Button:SetToolTipString(kOption.DisabledReason)
		else
			instance.Button:SetDisabled( false )
		end
		
		instance.Button:RegisterCallback( Mouse.eLClick, function() OnOptionClicked(kOption); end );	

	end

	stackControl:CalculateSize();
	Controls.CenterPanel:SetHide(false)
	Controls.CenterPanel:SetSizeY(stackControl:GetSizeY() + DIPLO_PANEL_OFFSET);
	
end

function Close()
	Controls.CenterPanel:SetHide(true)
end


function OnUnitSelectionChanged(playerID, unitID, x, y, i5, bSelect, b2)

	if not Controls.CenterPanel:IsHidden() and not bSelect then
		Close()
		
	elseif Controls.CenterPanel:IsHidden() and bSelect and playerID == g_playerID and unitID == g_unitID then
		Controls.CenterPanel:SetHide(false)
		
	elseif bSelect then
		local pUnit = GCO.GetUnit(playerID, unitID)
		
		if pUnit:GetValue("UnitPersonnelType") == UnitPersonnelType.Mercenary then

			local kParameters 		= {}
			kParameters.PlayerID 	= pUnit:GetOwner()
			kParameters.UnitID 		= unitID
			kParameters.Begin 		= true
			
			LuaEvents.ShowDiploScreenGCO(kParameters)
		end
	end
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
	Controls.GCO_DiploScreen:SetHide(false)
	Controls.CenterPanel:SetHide(true)
	LuaEvents.ShowDiploScreenGCO.Add( CreateDiploPanel )
	LuaEvents.ShowActionScreenGCO.Add( Close )
	Events.UnitSelectionChanged.Add(OnUnitSelectionChanged)
end
Initialize()