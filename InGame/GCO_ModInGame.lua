-----------------------------------------------------------------------------------------
--	FILE:	 ModInGame.lua
--  Gedemon (2017)
-----------------------------------------------------------------------------------------

print ("Loading ModInGame.lua...")

include( "PopupDialog" )


-----------------------------------------------------------------------------------------
-- Hide unused items
-----------------------------------------------------------------------------------------

function HideLeaderHead()
	ContextPtr:LookUpControl("/InGame/DiplomacyActionView/LeaderAnchor"):SetHide(true)
end

function HideGrowthHexAnchor()
	ContextPtr:LookUpControl("/InGame/CityPanel/GrowthHexAnchor"):SetHide(true)
end


----------------------------------------------------------------------------------------
-- Manage "Restart" button
----------------------------------------------------------------------------------------
local RestartCtrl
local bRestartInitialized	= false
local restartTimer			= 0
local waitBeforeRestart		= 5.9
function RestartTimer()
	if bRestartInitialized then
		if Automation.GetTime() - restartTimer > waitBeforeRestart then
			Events.GameCoreEventPublishComplete.Remove( RestartTimer )
			LuaEvents.RestartGame()
			Network.RestartGame()
		else
			RestartCtrl:SetText( Locale.Lookup("LOC_GAME_MENU_YNAMP_RESTART_TIMER", math.floor(math.max(0, waitBeforeRestart - (Automation.GetTime() - restartTimer)))) )
		end
	end
end

function OnRestartGame()
	if bRestartInitialized then
		bRestartInitialized = false
		bNeedToSave			= true
		RestartCtrl:SetText( Locale.Lookup("LOC_GAME_MENU_GCO_RESTART") )
		Events.GameCoreEventPublishComplete.Remove( RestartTimer )
	else
		bRestartInitialized = true
		RestartCtrl:SetText( Locale.Lookup("LOC_GAME_MENU_GCO_RESTART_TIMER", waitBeforeRestart) )
		restartTimer = Automation.GetTime()
		Events.GameCoreEventPublishComplete.Add( RestartTimer )
	end
end

--[[
-----------------------------------------------------------------------------------------
-- Override the restart button
-----------------------------------------------------------------------------------------
local m_kPopupDialog	: table;			-- Custom due to Utmost popup status

function OnReallyRestart()
	-- Start a fresh game using the existing game configuration.
	LuaEvents.RestartGame()
	Network.RestartGame();
end

function OnRestartGame()

	-- Below code broken, so direct restart as a nasty workaround...
	OnReallyRestart()
	
	-- [ [
	ContextPtr:LookUpControl("/InGame/TopOptionsMenu/"):SetHide(true)
	if (not m_kPopupDialog:IsOpen()) then
		m_kPopupDialog:AddText(	  Locale.Lookup("LOC_GAME_MENU_RESTART_WARNING"));
		m_kPopupDialog:AddButton( Locale.Lookup("LOC_COMMON_DIALOG_NO_BUTTON_CAPTION"), OnNo );
		m_kPopupDialog:AddButton( Locale.Lookup("LOC_COMMON_DIALOG_YES_BUTTON_CAPTION"), OnReallyRestart, nil, nil, "PopupButtonInstanceRed" );
		m_kPopupDialog:Open();
	end
	-- ] ]
end

function OnNo()
	ContextPtr:LookUpControl("/InGame/TopOptionsMenu/"):SetHide(false)
end

function Initialize()
	m_kPopupDialog = PopupDialog:new( "ModInGame" );
end
--]]

-----------------------------------------------------------------------------------------
-- Move Research/Civic popup
-----------------------------------------------------------------------------------------
function MoveTechPopUp()
	ContextPtr:LookUpControl("/InGame/TechCivicCompletedPopup"):SetOffsetX((ContextPtr:LookUpControl("/InGame/TechCivicCompletedPopup"):GetSizeX() - ContextPtr:LookUpControl("/InGame/TechCivicCompletedPopup/PopupBackgroundImage"):GetSizeX())/2)
	--ContextPtr:LookUpControl("/InGame/TechCivicCompletedPopup"):SetOffsetY(-(ContextPtr:LookUpControl("/InGame/TechCivicCompletedPopup"):GetSizeY() - ContextPtr:LookUpControl("/InGame/TechCivicCompletedPopup/PopupBackgroundImage"):GetSizeY())/2)
end


-----------------------------------------------------------------------------------------
-- Hide unused items
-----------------------------------------------------------------------------------------

function OnEnterGame()
	ContextPtr:LookUpControl("/InGame/DiplomacyActionView/LeaderAnchor"):RegisterWhenShown(HideLeaderHead)	
	ContextPtr:LookUpControl("/InGame/CityPanel/GrowthHexAnchor"):RegisterWhenShown(HideGrowthHexAnchor)
	
	-- 
	ContextPtr:LookUpControl("/InGame/CityPanel/ReligionGrid"):SetHide(true)
	ContextPtr:LookUpControl("/InGame/CityPanel/ReligionButton"):SetHide(true)
	ContextPtr:LookUpControl("/InGame/CityPanel/FaithGrid"):SetHide(true)
	ContextPtr:LookUpControl("/InGame/CityPanel/PurchaseTileCheck"):SetHide(true)
	ContextPtr:LookUpControl("/InGame/CityPanel/ProduceWithFaithCheck"):SetHide(true)
	ContextPtr:LookUpControl("/InGame/ProductionPanel/PurchaseFaithTab"):SetHide(true)
	--ContextPtr:LookUpControl("/InGame/TopPanel/FaithBacking"):SetHide(true)
	ContextPtr:LookUpControl("/InGame/CityPanelOverview/ReligionButton"):SetHide(true)
	
	ContextPtr:LookUpControl("/InGame/TopOptionsMenu/RestartButton"):RegisterCallback( Mouse.eLClick, OnRestartGame );
	
	-- Move research popup to top/right	
	ContextPtr:LookUpControl("/InGame/TechCivicCompletedPopup"):RegisterWhenShown(MoveTechPopUp)	
	
	RestartCtrl = ContextPtr:LookUpControl("/InGame/TopOptionsMenu/RestartButton")
end
Events.LoadScreenClose.Add(OnEnterGame)

--Initialize()