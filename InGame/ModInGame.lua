-----------------------------------------------------------------------------------------
--	FILE:	 ModInGame.lua
--  Gedemon (2017)
-----------------------------------------------------------------------------------------


-----------------------------------------------------------------------------------------
-- Hide unused items
-----------------------------------------------------------------------------------------

function HideLeaderHead()
	ContextPtr:LookUpControl("/InGame/DiplomacyActionView/LeaderAnchor"):SetHide(true)
end

function HideGrowthHexAnchor()
	ContextPtr:LookUpControl("/InGame/CityPanel/GrowthHexAnchor"):SetHide(true)
end

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
	ContextPtr:LookUpControl("/InGame/TopPanel/FaithBacking"):SetHide(true)
	
end
Events.LoadScreenClose.Add(OnEnterGame)