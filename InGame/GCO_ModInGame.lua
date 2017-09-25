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
	ContextPtr:LookUpControl("/InGame/TopOptionsMenu/"):SetHide(true)
	if (not m_kPopupDialog:IsOpen()) then
		m_kPopupDialog:AddText(	  Locale.Lookup("LOC_GAME_MENU_RESTART_WARNING"));
		m_kPopupDialog:AddButton( Locale.Lookup("LOC_COMMON_DIALOG_NO_BUTTON_CAPTION"), OnNo );
		m_kPopupDialog:AddButton( Locale.Lookup("LOC_COMMON_DIALOG_YES_BUTTON_CAPTION"), OnReallyRestart, nil, nil, "PopupButtonInstanceRed" );
		m_kPopupDialog:Open();
	end
end

function OnNo()
	ContextPtr:LookUpControl("/InGame/TopOptionsMenu/"):SetHide(false)
end

function Initialize()
	m_kPopupDialog = PopupDialog:new( "ModInGame" );
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
	
end
Events.LoadScreenClose.Add(OnEnterGame)

Initialize()