-----------------------------------------------------------------------------------------
--	FILE:	 ModInGame.lua
--  Gedemon (2017)
-----------------------------------------------------------------------------------------

print ("Loading ModInGame.lua...")

include( "PopupDialog" )

-----------------------------------------------------------------------------------------
-- In Game message 
-----------------------------------------------------------------------------------------
local m_statusIM				:table = InstanceManager:new( "StatusMessageInstance", "Root", Controls.StackOfMessages );
local m_gossipIM				:table = InstanceManager:new( "GossipMessageInstance", "Root", Controls.StackOfMessages );
local m_kMessages 				:table = {}
local DEFAULT_TIME_TO_DISPLAY	= 4
function StatusMessage( str:string, fDisplayTime:number, statusType:number )

	if not statusType then statusType = ReportingStatusTypes.DEFAULT end

	if (statusType == ReportingStatusTypes.DEFAULT or
		statusType == ReportingStatusTypes.GOSSIP) then	-- A statusType we handle?

		local kTypeEntry :table = m_kMessages[statusType];
		if (kTypeEntry == nil) then
			-- New statusType
			m_kMessages[statusType] = {
				InstanceManager = nil,
				MessageInstances= {}
			};
			kTypeEntry = m_kMessages[statusType];

			-- Link to the instance manager and the stack the UI displays in
			if (statusType == ReportingStatusTypes.GOSSIP) then
				kTypeEntry.InstanceManager	= m_gossipIM;
			else
				kTypeEntry.InstanceManager	= m_statusIM;
			end
		end

		local pInstance:table = kTypeEntry.InstanceManager:GetInstance();
		table.insert( kTypeEntry.MessageInstances, pInstance );

		local timeToDisplay:number = (fDisplayTime > 0) and fDisplayTime or DEFAULT_TIME_TO_DISPLAY;
		pInstance.StatusLabel:SetText( str );		
		pInstance.Anim:SetEndPauseTime( timeToDisplay );
		pInstance.Anim:RegisterEndCallback( function() OnEndAnim(kTypeEntry,pInstance) end );
		pInstance.Anim:SetToBeginning();
		pInstance.Anim:Play();

		Controls.StackOfMessages:CalculateSize();
		Controls.StackOfMessages:ReprocessAnchoring();
	end
end
LuaEvents.GCO_Message.Add( StatusMessage )

function OnEndAnim( kTypeEntry:table, pInstance:table )
	pInstance.Anim:ClearEndCallback();
	Controls.StackOfMessages:CalculateSize();
	Controls.StackOfMessages:ReprocessAnchoring();
	kTypeEntry.InstanceManager:ReleaseInstance( pInstance ) 	
end

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
	
end
Events.LoadScreenClose.Add(OnEnterGame)

Initialize()