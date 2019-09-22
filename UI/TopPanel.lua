-- ===========================================================================
--	HUD Top of Screen Area
-- ===========================================================================
include( "InstanceManager" );
include( "SupportFunctions" ); -- Round
include( "ToolTipHelper_PlayerYields" );

-- GCO <<<<<
-----------------------------------------------------------------------------------------
-- Initialize Functions / Variables
-----------------------------------------------------------------------------------------
-- should be already initialized in ToolTipHelper_PlayerYields
--GCO = ExposedMembers.GCO -- ExposedMembers.GCO can't be nil at this point
local bCondensedScience = true
-- GCO >>>>>

-- ===========================================================================
--	CONSTANTS
-- ===========================================================================
META_PADDING	= 100;	-- The amount of padding to give the meta area to make enough room for the (+) when there is resource overflow
FONT_MULTIPLIER	= 11;	-- The amount to multiply times the string length to approximate the width in pixels of the label control


-- ===========================================================================
-- VARIABLES
-- ===========================================================================
m_YieldButtonSingleManager	= InstanceManager:new( "YieldButton_SingleLabel", "Top", Controls.YieldStack );
m_YieldButtonDoubleManager	= InstanceManager:new( "YieldButton_DoubleLabel", "Top", Controls.YieldStack );
m_kResourceIM				= InstanceManager:new( "ResourceInstance", "ResourceText", Controls.ResourceStack );
local m_OpenPediaId;


-- ===========================================================================
-- Yield handles
-- ===========================================================================
local m_ScienceYieldButton:table = nil;
local m_CultureYieldButton:table = nil;
local m_GoldYieldButton:table = nil;
local m_TourismYieldButton:table = nil;
local m_FaithYieldButton:table = nil;
-- GCO <<<<<
local m_DebtYieldButton:table 		= nil;
local m_LogisticCostButton:table 	= nil;
local mResearchYieldButton:table 	= {};
local m_PopulationYieldButton:table = nil;
local m_AdministrationYieldButton:table = nil;
-- GCO >>>>>

-- ===========================================================================
--	Game Engine Event
-- ===========================================================================
function OnCityInitialized( playerID:number, cityID:number )
	if playerID == Game.GetLocalPlayer() then
		RefreshYields();
	end	
end

-- ===========================================================================
--	Game Engine Event
-- ===========================================================================
function OnLocalPlayerChanged( playerID:number , prevLocalPlayerID:number )	
	if playerID == -1 then return; end
	local player = Players[playerID];
	local pPlayerCities	:table = player:GetCities();	
	RefreshAll();
end

-- ===========================================================================
function OnMenu()
	LuaEvents.InGame_OpenInGameOptionsMenu();
end

-- ===========================================================================
--	UI Callback
--	Send signal to open/close the Reports Screen
-- ===========================================================================
function OnToggleReportsScreen()
	local pReportsScreen :table = ContextPtr:LookUpControl( "/InGame/ReportScreen" );
	if pReportsScreen == nil then
		UI.DataError("Unable to toggle Reports Screen.  Not found in '/InGame/ReportScreen'.");
		return;
	end
	if pReportsScreen:IsHidden() then
		LuaEvents.TopPanel_OpenReportsScreen();
	else
		LuaEvents.TopPanel_CloseReportsScreen();
	end
end

-- ===========================================================================
--	Takes a value and returns the string verison with +/- and rounded to
--	the tenths decimal place.
-- ===========================================================================
function FormatValuePerTurn( value:number )
	if(value == 0) then
		return Locale.ToNumber(value);
	else
		return Locale.Lookup("{1: number +#,###.#;-#,###.#}", value);
	end
end

-- ===========================================================================
function Resize()
	Controls.Backing:ReprocessAnchoring();
	Controls.Backing2:ReprocessAnchoring();
	Controls.RightContents:ReprocessAnchoring();	
end

-- GCO <<<<<
-- ===========================================================================
-- GCO action
-- ===========================================================================
function OnScienceClicked()
	bCondensedScience = not bCondensedScience
	RefreshYields()
end
-- GCO >>>>>

-- ===========================================================================
--	Refresh Data and View
-- ===========================================================================
function RefreshYields()
	local ePlayer		:number = Game.GetLocalPlayer();
	local localPlayer	:table= nil;
	if ePlayer ~= -1 then
		localPlayer = Players[ePlayer];
		if localPlayer == nil then
			return;
		end
	else
		return;
	end
	-- GCO <<<<<
	if ExposedMembers.GCO_Initialized then GCO.InitializePlayerFunctions(localPlayer) end
	-- GCO >>>>>
	
	-- GCO <<<<<	
	---- ADMINISTRATION ----
	-- Strength (empire wide, affect stability), Efficiency (per city, affect production factor)
	-- administrative records
	--  / ICON_Government
	m_AdministrationYieldButton	= m_AdministrationYieldButton or m_YieldButtonSingleManager:GetInstance()
	if ExposedMembers.GCO_Initialized then
		local PopulationBalance, PopulationYield = localPlayer:GetTotalPopulation()
		local popSize			=  math.floor(GCO.GetSizeAtPopulation(PopulationBalance))
		local citiesSize		=  localPlayer:GetCities():GetCount()
		local territorySize		=  localPlayer:GetTerritorySize()
		local numTechs			=  localPlayer:GetNumTechs()
		local balanceColorName	= "DiplomaticLabelCS" -- ResMilitaryLabelCS
		local backingColorName 	= "NeutralCS"
		local territoryCost		= territorySize/10
		local territorySurface	= territorySize*10000
		local techFactor		= numTechs/2
		local empireCost		= math.floor(popSize + citiesSize + territoryCost) * techFactor
		local toolTipStr 		= Locale.Lookup("LOC_TOP_PANEL_ADMINISTRATIVE_COST_TOOLTIP", empireCost, popSize, PopulationBalance, citiesSize, territoryCost, territorySurface, techFactor)
		
		--LOC_TOP_PANEL_ADMINISTRATIVE_COST_TOOLTIP
		--	<Replace Tag="LOC_TOP_PANEL_ADMINISTRATIVE_COST_TOOLTIP"	Text="Administrative cost =  {1_Num : number #,###}[NEWLINE][ICON_BULLET]Population cost = {2_Num : number #,###} from {3_Num : number #,###} pop.[NEWLINE][ICON_BULLET]Cities cost = {4_Num : number #,###} from number of cities[NEWLINE][ICON_BULLET]Territory cost = {5_Num : number #,###} from managing {6_Num : number #,###}km²[NEWLINE][ICON_BULLET]Technology Factor: management cost x{7_Num : number #.##} from technological advancement." Language="en_US" />

		
		m_AdministrationYieldButton.YieldPerTurn:SetText( Locale.ToNumber(empireCost, "#,###") );
		m_AdministrationYieldButton.YieldIconString:SetText("[ICON_Government]"); -- [ICON_DISTRICT_GOVERNMENT] requires R&F
		m_AdministrationYieldButton.YieldPerTurn:SetColorByName(balanceColorName);
		
		m_AdministrationYieldButton.YieldBacking:SetToolTipString( toolTipStr );
		m_AdministrationYieldButton.YieldBacking:SetColorByName(backingColorName);
		m_AdministrationYieldButton.YieldButtonStack:CalculateSize();
	end
	
	---- POPULATION ----
	m_PopulationYieldButton = m_PopulationYieldButton or m_YieldButtonDoubleManager:GetInstance();
	
	if ExposedMembers.GCO_Initialized then
		
		local PopulationBalance, PopulationYield = localPlayer:GetTotalPopulation()
		
		local activeDutyReservist	:number = localPlayer:GetLogisticPersonnelInActiveDuty()
		local activeDutyInUnits		:number = localPlayer:GetPersonnelInUnits()
		local ArmySize				:number = activeDutyReservist + activeDutyInUnits
		local PercentagePopulation	:number = ArmySize / PopulationBalance * 100
		local MaxDraftedPercentage	:number = localPlayer:GetMaxDraftedPercentage()
		
		local balanceColor	= "ResFoodLabelCS"
		if PercentagePopulation > MaxDraftedPercentage then
			balanceColor	= "ModStatusRedCS"
		end		

		m_PopulationYieldButton.YieldBalance:SetText( Locale.ToNumber(PopulationBalance, "#,###.#") );
		m_PopulationYieldButton.YieldBalance:SetColorByName(balanceColor);	
		m_PopulationYieldButton.YieldPerTurn:SetText( FormatValuePerTurn(PopulationYield) );
		m_PopulationYieldButton.YieldIconString:SetText("[ICON_GIFT_UNIT]");
		m_PopulationYieldButton.YieldPerTurn:SetColorByName("ResFoodLabelCS");	

		local toolTipString = Locale.Lookup("LOC_TOP_PANEL_POPULATION_TOOLTIP", PopulationBalance, ArmySize, PercentagePopulation, localPlayer:GetDraftEfficiencyPercent(), MaxDraftedPercentage, activeDutyInUnits, activeDutyReservist)
		m_PopulationYieldButton.YieldBacking:SetToolTipString( toolTipString );
		m_PopulationYieldButton.YieldBacking:SetColorByName("ResFoodLabelCS");
		m_PopulationYieldButton.YieldButtonStack:CalculateSize();		
	end

	---- LOGISTIC COST  ----
	m_LogisticCostButton 	= m_LogisticCostButton or m_YieldButtonSingleManager:GetInstance()
	if ExposedMembers.GCO_Initialized then
		local playerData 			= localPlayer:GetData()
		local availableLogistic		= localPlayer:GetPersonnelInCities()
		local bShowLogistic			= false		
		local classLogisticCost 	= {}
		local classLogisticSupport 	= {}
		local bNoSupport			= false
		local bNearNoSupport		= false
		local nearNoSupportRatio	= 0.80
		for row in GameInfo.UnitPromotionClasses() do
			local promotionClassID 				= row.Index
			local logisticCost 					= localPlayer:GetLogisticCost(promotionClassID)
			local logisticSupport				= localPlayer:GetLogisticSupport(promotionClassID)
			if logisticCost > 0 then
				bShowLogistic							= true
				classLogisticCost[promotionClassID] 	= logisticCost
				classLogisticSupport[promotionClassID] 	= logisticSupport
				if logisticCost >=  logisticSupport then
					bNoSupport = true
				elseif logisticCost > logisticSupport * nearNoSupportRatio then
					bNearNoSupport = true
				end
			end
		end
		local balanceColorName = "Brown"
		local backingColorName = "Brown"
		if bNoSupport then
			balanceColorName = "OperationChance_Red"
		elseif bNearNoSupport then
			balanceColorName = "OperationChance_Yellow"
		end
		
		m_LogisticCostButton.YieldPerTurn:SetText( Locale.ToNumber(availableLogistic, "#,###") );
		m_LogisticCostButton.YieldIconString:SetText("[ICON_Strength_Large]"); -- [ICON_Charges_Large]
		m_LogisticCostButton.YieldPerTurn:SetColorByName(balanceColorName);

		local toolTipStrTable = {}
		for promotionID, logisticCost in pairs(classLogisticCost) do
			local logisticSupport = classLogisticSupport[promotionID]
			local logisticStr = " " .. Locale.ToNumber(logisticCost, "#,###")
			if logisticCost >= logisticSupport then
				logisticStr = " [COLOR_Civ6Red]" .. Locale.ToNumber(logisticCost, "#,###") .. "[ENDCOLOR]"
			elseif logisticCost > logisticSupport * nearNoSupportRatio then
				logisticStr = " [COLOR_OperationChance_Orange]" .. Locale.ToNumber(logisticCost, "#,###") .. "[ENDCOLOR]"
			end				
			--table.insert(toolTipStrTable, Locale.Lookup(GameInfo.UnitPromotionClasses[promotionID].Name) .. logisticStr)
			table.insert(toolTipStrTable, Locale.Lookup("LOC_TOP_PANEL_PROMOTION_COST_TOOLTIP", GameInfo.UnitPromotionClasses[promotionID].Name, logisticStr, logisticSupport))
		end
		local toolTipStr = Locale.Lookup("LOC_TOP_PANEL_LOGISTIC_COST_TOOLTIP", availableLogistic, localPlayer:GetLogisticPersonnelInActiveDuty())..Locale.Lookup("LOC_TOOLTIP_SEPARATOR").. table.concat(toolTipStrTable, "[NEWLINE]")
		m_LogisticCostButton.YieldBacking:SetToolTipString( toolTipStr );
		m_LogisticCostButton.YieldBacking:SetColorByName(backingColorName);
		m_LogisticCostButton.YieldButtonStack:CalculateSize();
		
		if bShowLogistic then
			m_LogisticCostButton.Top:SetHide(false);
		else
			m_LogisticCostButton.Top:SetHide(true);
		end
	end
	-- GCO >>>>>
	
	-- GCO <<<<< GOLD and CULTURE sections moved before all science sections >>>>>
	---- GOLD ----
	if GameCapabilities.HasCapability("CAPABILITY_GOLD") then
		m_GoldYieldButton = m_GoldYieldButton or m_YieldButtonDoubleManager:GetInstance();
		local playerTreasury:table	= localPlayer:GetTreasury();
		local goldYield		:number = playerTreasury:GetGoldYield() - playerTreasury:GetTotalMaintenance();
		local goldBalance	:number = math.floor(playerTreasury:GetGoldBalance());
		-- GCO <<<<<
		if ExposedMembers.GCO_Initialized then
			goldYield = goldYield + localPlayer:GetTransactionBalance()
			goldYield = goldYield + localPlayer:GetTransactionType(AccountType.ImportTaxes, GCO.GetPreviousTurnKey()) -- to do : by player playing order, not just assuming local = first
		end
		-- GCO >>>>>
		m_GoldYieldButton.YieldBalance:SetText( Locale.ToNumber(goldBalance, "#,###.#") );
		m_GoldYieldButton.YieldBalance:SetColorByName("ResGoldLabelCS");	
		m_GoldYieldButton.YieldPerTurn:SetText( FormatValuePerTurn(goldYield) );
		m_GoldYieldButton.YieldIconString:SetText("[ICON_GoldLarge]");
		m_GoldYieldButton.YieldPerTurn:SetColorByName("ResGoldLabelCS");	

		m_GoldYieldButton.YieldBacking:SetToolTipString( GetGoldTooltip() );
		m_GoldYieldButton.YieldBacking:SetColorByName("ResGoldLabelCS");
		m_GoldYieldButton.YieldButtonStack:CalculateSize();		
		
		-- GCO <<<<<
		---- DEBT ----
		m_DebtYieldButton 	= m_DebtYieldButton or m_YieldButtonSingleManager:GetInstance()
		if ExposedMembers.GCO_Initialized then
			local playerData 	= localPlayer:GetData()
			local debt 			= playerData.Debt
			if (debt < 0) then
				local debtYield	= goldBalance + goldYield
				m_DebtYieldButton.YieldPerTurn:SetText( Locale.ToNumber(debt, "#,###.#") );
				m_DebtYieldButton.YieldIconString:SetText("[ICON_GoldLarge]");
				m_DebtYieldButton.YieldPerTurn:SetColorByName("ModStatusRedCS");

				m_DebtYieldButton.YieldBacking:SetToolTipString( Locale.Lookup("LOC_TOP_PANEL_DEBT_TOOLTIP") );
				m_DebtYieldButton.YieldBacking:SetColorByName("ModStatusRedCS");
				m_DebtYieldButton.YieldButtonStack:CalculateSize();
			
				m_DebtYieldButton.Top:SetHide(false);
			else
				m_DebtYieldButton.Top:SetHide(true);
			end
		end
		-- GCO >>>>>
		
	end

	-- GCO <<<<<
	--[[
	-- GCO >>>>>
	---- SCIENCE ----
	m_ScienceYieldButton = m_ScienceYieldButton or m_YieldButtonSingleManager:GetInstance();
	local playerTechnology		:table	= localPlayer:GetTechs();
	local currentScienceYield	:number = playerTechnology:GetScienceYield();
	m_ScienceYieldButton.YieldPerTurn:SetText( FormatValuePerTurn(currentScienceYield) );	

	m_ScienceYieldButton.YieldBacking:SetToolTipString( GetScienceTooltip() );
	m_ScienceYieldButton.YieldIconString:SetText("[ICON_ScienceLarge]");
	m_ScienceYieldButton.YieldButtonStack:CalculateSize();
	-- GCO <<<<<
	--]]
	-- GCO >>>>>
	
	---- CULTURE----
	m_CultureYieldButton = m_CultureYieldButton or m_YieldButtonSingleManager:GetInstance();
	local playerCulture			:table	= localPlayer:GetCulture();
	local currentCultureYield	:number = playerCulture:GetCultureYield();
	m_CultureYieldButton.YieldPerTurn:SetText( FormatValuePerTurn(currentCultureYield) );	
	m_CultureYieldButton.YieldPerTurn:SetColorByName("ResCultureLabelCS");

	m_CultureYieldButton.YieldBacking:SetToolTipString( GetCultureTooltip() );
	m_CultureYieldButton.YieldBacking:SetColor(0x99fe2aec);
	m_CultureYieldButton.YieldIconString:SetText("[ICON_CultureLarge]");
	m_CultureYieldButton.YieldButtonStack:CalculateSize();
	
	-- GCO <<<<<
	---- NEW SCIENCE ----
	if ExposedMembers.GCO_Initialized then -- todo: for naming convention, use "tech" prefix not "research"
		m_ScienceYieldButton = m_ScienceYieldButton or m_YieldButtonDoubleManager:GetInstance()
		local playerTechnology	= localPlayer:GetTechs()
		local pResearch 		= GCO.Research:Create(ePlayer)
		local nextTurnTechs		= pResearch:GetNextTurnTechnology()
		local makeStr			= {}
		local techYield			= 0
		local knowledgeYield	= 0
		local totalDecay		= 0
		local totalKnowledge	= nextTurnTechs.TotalKnowledge
		
		for researchType, row in pairs(nextTurnTechs.Techs) do 
			local balanceValue	= row.Balance
			local yieldValue	= pResearch:GetYield(researchType)
			local researchValue	= math.min(row.ResearchPoints, row.MaxResearchPoint)
			local decayValue	= row.DecayValue	-- this is already a negative value
			local researchName	= GameInfo.Technologies[researchType].Name
			techYield			= techYield + researchValue
			knowledgeYield		= knowledgeYield + yieldValue
			totalDecay			= totalDecay + decayValue
			if yieldValue > 0 or researchValue > 0 or balanceValue > 0 then
				if not bCondensedScience then
					table.insert(makeStr, Locale.Lookup("LOC_TOP_PANEL_RESEARCH_TITLE_TOOLTIP", balanceValue, researchName) .. "[NEWLINE]" .. Locale.Lookup("LOC_TOP_PANEL_RESEARCH_YIELD_TITLE_TOOLTIP", yieldValue) .. "[NEWLINE]" .. tostring(pResearch:GetYieldTooltip(researchType)).. "[NEWLINE]" .. Locale.Lookup("LOC_TOP_PANEL_RESEARCH_POINTS_TITLE_TOOLTIP", researchValue) .. "[NEWLINE]" .. tostring(row.String) .. "[NEWLINE]" .. Locale.Lookup("LOC_TOP_PANEL_RESEARCH_BASE_DECAY_TOOLTIP", decayValue))
				else
					table.insert(makeStr, Locale.Lookup("LOC_TOP_PANEL_RESEARCH_TITLE_TOOLTIP", balanceValue, researchName) .. "(" .. FormatValuePerTurn(yieldValue+decayValue) .. "/[COLOR:SuzerainDark]" .. FormatValuePerTurn(researchValue) .."[ENDCOLOR])")
				end
			end
		end
		
		local scienceTooltip = GetScienceTooltip() 
		if bCondensedScience then
			scienceTooltip = scienceTooltip .. Locale.Lookup("LOC_TOOLTIP_SEPARATOR") .. Locale.Lookup("Condensed mode, [ICON_MOUSE_LEFT] click to expand")
			local nextResearch		= pResearch:GetNextTurnResearch()
			local makeResearchStr	= {}
			local separator			= nil
			for _, researchType in ipairs(pResearch:GetList()) do
				separator			= separator or Locale.Lookup("LOC_TOOLTIP_SEPARATOR")
				local yieldValue	= pResearch:GetYield(researchType, true) -- second parameter to include the local yield when it's directly converted in knowledge locally
				local balanceValue	= nextResearch[researchType].Balance
				local researchValue	= nextResearch[researchType].ResearchPoints
				local decayValue	= nextResearch[researchType].DecayValue	-- this is already a negative value
				local researchName	= GameInfo.TechnologyContributionTypes[researchType].Name
				techYield			= techYield + researchValue
				knowledgeYield		= knowledgeYield + yieldValue
				totalKnowledge		= totalKnowledge + balanceValue
				table.insert(makeResearchStr, Locale.Lookup("LOC_TOP_PANEL_RESEARCH_TITLE_TOOLTIP", balanceValue, researchName) .. "(" .. FormatValuePerTurn(yieldValue+decayValue) .. "/[COLOR:SuzerainDark]" .. FormatValuePerTurn(researchValue) .."[ENDCOLOR])")
			end
			scienceTooltip = scienceTooltip .. (separator or "") .. table.concat(makeResearchStr, Locale.Lookup("LOC_TOOLTIP_SEPARATOR"))
		else
			scienceTooltip = scienceTooltip .. Locale.Lookup("LOC_TOOLTIP_SEPARATOR") .. Locale.Lookup("Expanded mode, [ICON_MOUSE_LEFT] click to condense")
		end
		scienceTooltip = scienceTooltip .. Locale.Lookup("LOC_TOOLTIP_SEPARATOR").. table.concat(makeStr, Locale.Lookup("LOC_TOOLTIP_SEPARATOR"))
		
		local currentScienceYield	:number = playerTechnology:GetScienceYield();
		m_ScienceYieldButton.YieldBalance:SetText( totalKnowledge );
		m_ScienceYieldButton.YieldPerTurn:SetText( FormatValuePerTurn(knowledgeYield+totalDecay) .. "/[COLOR:ResScienceLabelCS]" .. FormatValuePerTurn(currentScienceYield + techYield)  .."[ENDCOLOR]");	
		
		m_ScienceYieldButton.YieldBacking:SetToolTipString( scienceTooltip );
		m_ScienceYieldButton.YieldIconString:SetText("[ICON_ScienceLarge]");
		m_ScienceYieldButton.YieldButtonStack:CalculateSize();
		
		m_ScienceYieldButton.YieldBacking:RegisterCallback( Mouse.eLClick, OnScienceClicked );
	end
	-- GCO >>>>>

	-- GCO <<<<<
	-- Other Sciences fields
	if ExposedMembers.GCO_Initialized then
		local pResearch 		= GCO.Research:Create(ePlayer)
		local nextResearch		= pResearch:GetNextTurnResearch()
		for _, researchType in ipairs(pResearch:GetList()) do
			mResearchYieldButton[researchType]	= mResearchYieldButton[researchType] or m_YieldButtonDoubleManager:GetInstance()
			local yieldButton					= mResearchYieldButton[researchType]
			local yieldValue					= pResearch:GetYield(researchType, true) -- second parameter to include the local yield when it's directly converted in knowledge locally
			local balanceValue					= nextResearch[researchType].Balance
			local researchValue					= nextResearch[researchType].ResearchPoints
			local decayValue					= nextResearch[researchType].DecayValue	-- this is already a negative value
			local researchName					= GameInfo.TechnologyContributionTypes[researchType].Name
			
			if not bCondensedScience and (yieldValue > 0 or researchValue > 0 or balanceValue > 0) then
				yieldButton.YieldBalance:SetText( balanceValue );
				yieldButton.YieldPerTurn:SetText( FormatValuePerTurn(yieldValue+decayValue) .. "/[COLOR:ResScienceLabelCS]" .. FormatValuePerTurn(researchValue) .."[ENDCOLOR]");	
				--yieldButton.YieldPerTurn:SetColorByName("ResCultureLabelCS");

				local sTooltip = Locale.Lookup("LOC_TOP_PANEL_RESEARCH_TITLE_TOOLTIP", balanceValue, researchName) .. Locale.Lookup("LOC_TOOLTIP_SEPARATOR") .. Locale.Lookup("LOC_TOP_PANEL_RESEARCH_YIELD_TITLE_TOOLTIP", yieldValue) .. "[NEWLINE]" .. pResearch:GetYieldTooltip(researchType) .. Locale.Lookup("LOC_TOOLTIP_SEPARATOR") .. Locale.Lookup("LOC_TOP_PANEL_RESEARCH_POINTS_TITLE_TOOLTIP", researchValue) .. "[NEWLINE]" .. nextResearch[researchType].String .. Locale.Lookup("LOC_TOOLTIP_SEPARATOR") .. Locale.Lookup("LOC_TOP_PANEL_RESEARCH_BASE_DECAY_TOOLTIP", decayValue)
				yieldButton.YieldBacking:SetToolTipString( sTooltip );
				--yieldButton.YieldBacking:SetColor(0x99fe2aec);
				yieldButton.YieldIconString:SetText(GameInfo.TechnologyContributionTypes[researchType].IconString);
				yieldButton.YieldButtonStack:CalculateSize();
				yieldButton.Top:SetHide(false)
			else
				yieldButton.Top:SetHide(true)
			end	
		end
	end
	-- GCO >>>>>
	
	---- FAITH ----
	m_FaithYieldButton = m_FaithYieldButton or m_YieldButtonDoubleManager:GetInstance();
	local playerReligion		:table	= localPlayer:GetReligion();
	local faithYield			:number = playerReligion:GetFaithYield();
	local faithBalance			:number = playerReligion:GetFaithBalance();
	m_FaithYieldButton.YieldBalance:SetText( Locale.ToNumber(faithBalance, "#,###.#") );	
	m_FaithYieldButton.YieldPerTurn:SetText( FormatValuePerTurn(faithYield) );
	m_FaithYieldButton.YieldBacking:SetToolTipString( GetFaithTooltip() );
	m_FaithYieldButton.YieldIconString:SetText("[ICON_FaithLarge]");
	m_FaithYieldButton.YieldButtonStack:CalculateSize();
	-- GCO <<<<<
	m_FaithYieldButton.Top:SetHide(true)
	-- GCO >>>>>
	
	---- TOURISM ----
	if GameCapabilities.HasCapability("CAPABILITY_TOURISM") then
		m_TourismYieldButton = m_TourismYieldButton or m_YieldButtonSingleManager:GetInstance();
		local tourismRate = Round(localPlayer:GetStats():GetTourism(), 1);
		local tourismRateTT:string = Locale.Lookup("LOC_WORLD_RANKINGS_OVERVIEW_CULTURE_TOURISM_RATE", tourismRate);
		local tourismBreakdown = localPlayer:GetStats():GetTourismToolTip();
		if(tourismBreakdown and #tourismBreakdown > 0) then
			tourismRateTT = tourismRateTT .. "[NEWLINE][NEWLINE]" .. tourismBreakdown;
		end
		
		m_TourismYieldButton.YieldPerTurn:SetText( tourismRate );	
		m_TourismYieldButton.YieldBacking:SetToolTipString(tourismRateTT);
		m_TourismYieldButton.YieldPerTurn:SetColorByName("ResTourismLabelCS");
		m_TourismYieldButton.YieldBacking:SetColorByName("ResTourismLabelCS");
		m_TourismYieldButton.YieldIconString:SetText("[ICON_TourismLarge]");
		if (tourismRate > 0) then
			m_TourismYieldButton.Top:SetHide(false);
		else
			m_TourismYieldButton.Top:SetHide(true);
		end 
	end

	Controls.YieldStack:CalculateSize();
	Controls.StaticInfoStack:CalculateSize();
	Controls.InfoStack:CalculateSize();

	Controls.YieldStack:RegisterSizeChanged( RefreshResources );
	Controls.StaticInfoStack:RegisterSizeChanged( RefreshResources );
end

-- ===========================================================================
--	Game Engine Event
function OnRefreshYields()
	ContextPtr:RequestRefresh();
end

-- ===========================================================================
function RefreshTrade()

	local localPlayer = Players[Game.GetLocalPlayer()];
	if (localPlayer == nil) then
		return;
	end

	---- ROUTES ----
	local playerTrade	:table	= localPlayer:GetTrade();
	local routesActive	:number = playerTrade:GetNumOutgoingRoutes();
	local sRoutesActive :string = "" .. routesActive;
	local routesCapacity:number = playerTrade:GetOutgoingRouteCapacity();
	if (routesCapacity > 0) then
		if (routesActive > routesCapacity) then
			sRoutesActive = "[COLOR_RED]" .. sRoutesActive .. "[ENDCOLOR]";
		elseif (routesActive < routesCapacity) then
			sRoutesActive = "[COLOR_GREEN]" .. sRoutesActive .. "[ENDCOLOR]";
		end
		Controls.TradeRoutesActive:SetText(sRoutesActive);
		Controls.TradeRoutesCapacity:SetText(routesCapacity);

		local sTooltip = Locale.Lookup("LOC_TOP_PANEL_TRADE_ROUTES_TOOLTIP_ACTIVE", routesActive);
		sTooltip = sTooltip .. "[NEWLINE]";
		sTooltip = sTooltip .. Locale.Lookup("LOC_TOP_PANEL_TRADE_ROUTES_TOOLTIP_CAPACITY", routesCapacity);
		sTooltip = sTooltip .. "[NEWLINE][NEWLINE]";
		sTooltip = sTooltip .. Locale.Lookup("LOC_TOP_PANEL_TRADE_ROUTES_TOOLTIP_SOURCES_HELP");
		Controls.TradeRoutes:SetToolTipString(sTooltip);
		Controls.TradeRoutes:SetHide(false);
	else
		Controls.TradeRoutes:SetHide(true);
	end

	Controls.TradeStack:CalculateSize();
	Controls.TradeStack:ReprocessAnchoring();
end

-- ===========================================================================
function RefreshInfluence()
	if GameCapabilities.HasCapability("CAPABILITY_TOP_PANEL_ENVOYS") then
		local localPlayer = Players[Game.GetLocalPlayer()];
		if (localPlayer == nil) then
			return;
		end

		local playerInfluence	:table	= localPlayer:GetInfluence();
		local influenceBalance	:number	= Round(playerInfluence:GetPointsEarned(), 1);
		local influenceRate		:number = Round(playerInfluence:GetPointsPerTurn(), 1);
		local influenceThreshold:number	= playerInfluence:GetPointsThreshold();
		local envoysPerThreshold:number = playerInfluence:GetTokensPerThreshold();
		local currentEnvoys		:number = playerInfluence:GetTokensToGive();
		
		local sTooltip = "";

		if (currentEnvoys > 0) then
			sTooltip = sTooltip .. Locale.Lookup("LOC_TOP_PANEL_INFLUENCE_TOOLTIP_ENVOYS", currentEnvoys);
			sTooltip = sTooltip .. "[NEWLINE][NEWLINE]";
		end
		sTooltip = sTooltip .. Locale.Lookup("LOC_TOP_PANEL_INFLUENCE_TOOLTIP_POINTS_THRESHOLD", envoysPerThreshold, influenceThreshold);
		sTooltip = sTooltip .. "[NEWLINE][NEWLINE]";
		sTooltip = sTooltip .. Locale.Lookup("LOC_TOP_PANEL_INFLUENCE_TOOLTIP_POINTS_BALANCE", influenceBalance);
		sTooltip = sTooltip .. "[NEWLINE]";
		sTooltip = sTooltip .. Locale.Lookup("LOC_TOP_PANEL_INFLUENCE_TOOLTIP_POINTS_RATE", influenceRate);
		sTooltip = sTooltip .. "[NEWLINE][NEWLINE]";
		sTooltip = sTooltip .. Locale.Lookup("LOC_TOP_PANEL_INFLUENCE_TOOLTIP_SOURCES_HELP");
		
		local meterRatio = influenceBalance / influenceThreshold;
		if (meterRatio < 0) then
			meterRatio = 0;
		elseif (meterRatio > 1) then
			meterRatio = 1;
		end
		Controls.EnvoysMeter:SetPercent(meterRatio);
		Controls.EnvoysNumber:SetText(tostring(currentEnvoys));
		Controls.Envoys:SetToolTipString(sTooltip);
		Controls.EnvoysStack:CalculateSize();
		Controls.EnvoysStack:ReprocessAnchoring();
	else
		Controls.Envoys:SetHide(true);
	end
end

-- ===========================================================================
function RefreshTime()
	local format = UserConfiguration.GetClockFormat();
	
	local strTime;
	
	if(format == 1) then
		strTime = os.date("%H:%M");
	else
		strTime = os.date("%I:%M %p");

		-- Remove the leading zero (if any) from 12-hour clock format
		if(string.sub(strTime, 1, 1) == "0") then
			strTime = string.sub(strTime, 2);
		end
	end

	Controls.Time:SetText( strTime );
	local d = Locale.Lookup("{1_Time : datetime full}", os.time());
	Controls.Time:SetToolTipString(d);
	Controls.TimeArea:ReprocessAnchoring();
end

-- ===========================================================================
function RefreshResources()
	-- GCO <<<<<
	--[[
	-- GCO >>>>>
	local localPlayerID = Game.GetLocalPlayer();
	if (localPlayerID ~= -1) then
		m_kResourceIM:ResetInstances(); 
		local pPlayerResources	=  Players[localPlayerID]:GetResources();
		local yieldStackX		= Controls.YieldStack:GetSizeX();
		local infoStackX		= Controls.StaticInfoStack:GetSizeX();
		local metaStackX		= Controls.RightContents:GetSizeX();
		local screenX, _:number = UIManager:GetScreenSizeVal();
		local maxSize = screenX - yieldStackX - infoStackX - metaStackX - META_PADDING;
		if (maxSize < 0) then maxSize = 0; end
		local currSize = 0;
		local isOverflow = false;
		local overflowString = "";
		local plusInstance:table;
		for resource in GameInfo.Resources() do
			if (resource.ResourceClassType ~= nil and resource.ResourceClassType ~= "RESOURCECLASS_BONUS" and resource.ResourceClassType ~="RESOURCECLASS_LUXURY" and resource.ResourceClassType ~="RESOURCECLASS_ARTIFACT") then
				local amount = pPlayerResources:GetResourceAmount(resource.ResourceType);
				if (amount > 0) then
					local resourceText = "[ICON_"..resource.ResourceType.."] ".. amount;
					local numDigits = 3;
					if (amount >= 10) then
						numDigits = 4;
					end
					local guessinstanceWidth = math.ceil(numDigits * FONT_MULTIPLIER);
					if(currSize + guessinstanceWidth < maxSize and not isOverflow) then
						if (amount ~= 0) then
							local instance:table = m_kResourceIM:GetInstance();
							instance.ResourceText:SetText(resourceText);
							instance.ResourceText:SetToolTipString(Locale.Lookup(resource.Name).."[NEWLINE]"..Locale.Lookup("LOC_TOOLTIP_STRATEGIC_RESOURCE"));
							instanceWidth = instance.ResourceText:GetSizeX();
							currSize = currSize + instanceWidth;
						end
					else
						if (not isOverflow) then 
							overflowString = amount.. "[ICON_"..resource.ResourceType.."]".. Locale.Lookup(resource.Name);
							local instance:table = m_kResourceIM:GetInstance();
							instance.ResourceText:SetText("[ICON_Plus]");
							plusInstance = instance.ResourceText;
						else
							overflowString = overflowString .. "[NEWLINE]".. amount.. "[ICON_"..resource.ResourceType.."]".. Locale.Lookup(resource.Name);
						end
						isOverflow = true;
					end
				end
			end
		end
		if (plusInstance ~= nil) then
			plusInstance:SetToolTipString(overflowString);
		end
		Controls.ResourceStack:CalculateSize();
		if(Controls.ResourceStack:GetSizeX() == 0) then
			Controls.Resources:SetHide(true);
		else
			Controls.Resources:SetHide(false);
		end
	end
	-- GCO <<<<<
	--]]
	Controls.Resources:SetHide(true)
	-- GCO >>>>>
end

-- ===========================================================================
--	Game Engine Event
-- ===========================================================================
function OnRefreshResources()
	RefreshResources();
end

-- ===========================================================================
--	Use an animation control to occasionally (not per frame!) callback for
--	an update on the current time.
-- ===========================================================================
function OnRefreshTimeTick()
	RefreshTime();
	Controls.TimeCallback:SetToBeginning();
	Controls.TimeCallback:Play();
end

-- ===========================================================================
function RefreshTurnsRemaining()

	local endTurn = Game.GetGameEndTurn();		-- This EXCLUSIVE, i.e. the turn AFTER the last playable turn.
	local turn = Game.GetCurrentGameTurn();

	if GameCapabilities.HasCapability("CAPABILITY_DISPLAY_NORMALIZED_TURN") then
		turn = (turn - GameConfiguration.GetStartTurn()) + 1; -- Keep turns starting at 1.
		if endTurn > 0 then
			endTurn = endTurn - GameConfiguration.GetStartTurn();
		end
	end

	if endTurn > 0 then
		-- We have a hard turn limit
		Controls.Turns:SetText(tostring(turn) .. "/" .. tostring(endTurn - 1));
	else
		Controls.Turns:SetText(tostring(turn));
	end

	local strDate = Calendar.MakeYearStr(turn);
	Controls.CurrentDate:SetText(strDate);
end

-- ===========================================================================
function OnWMDUpdate(owner, WMDtype)
	local eLocalPlayer = Game.GetLocalPlayer();
	if ( eLocalPlayer ~= -1 and owner == eLocalPlayer ) then
		local player = Players[owner];
		local playerWMDs = player:GetWMDs();

		for entry in GameInfo.WMDs() do
			if (entry.WeaponType == "WMD_NUCLEAR_DEVICE") then
				local count = playerWMDs:GetWeaponCount(entry.Index);
				if (count > 0) then
					Controls.NuclearDevices:SetHide(false);
					Controls.NuclearDeviceCount:SetText(count);
				else
					Controls.NuclearDevices:SetHide(true);
				end

			elseif (entry.WeaponType == "WMD_THERMONUCLEAR_DEVICE") then
				local count = playerWMDs:GetWeaponCount(entry.Index);
				if (count > 0) then
					Controls.ThermoNuclearDevices:SetHide(false);
					Controls.ThermoNuclearDeviceCount:SetText(count);
				else
					Controls.ThermoNuclearDevices:SetHide(true);
				end
			end
		end

		Controls.YieldStack:CalculateSize();
	end

	OnRefreshYields();	-- Don't directly refresh, call EVENT version so it's queued in the next context update.
end

-- ===========================================================================
function OnGreatPersonActivated(playerID:number)
	if ( Game.GetLocalPlayer() == playerID ) then
		OnRefreshYields();
	end
end

-- ===========================================================================
function OnGreatWorkCreated(playerID:number)
	if ( Game.GetLocalPlayer() == playerID ) then
		OnRefreshYields();
	end
end

-- ===========================================================================
function RefreshAll()
	RefreshTurnsRemaining();
	RefreshTrade();
	RefreshInfluence();
	RefreshYields();
	RefreshTime();
	OnWMDUpdate( Game.GetLocalPlayer() );
end

-- ===========================================================================
--	Game Engine Event
-- ===========================================================================
function OnTurnBegin()	
	RefreshAll();
end

-- ===========================================================================
--	Game Engine Event
-- ===========================================================================
function OnUpdateUI( type:number, tag:string, iData1:number, iData2:number, strData1:string)
	if type == SystemUpdateUI.ScreenResize then
		Resize();
	end
end

-- ===========================================================================
function OnRefresh()
	ContextPtr:ClearRequestRefresh();
	RefreshYields();
end



-- ===========================================================================
--	Game Engine Event
--	Wait until the game engine is done loading before the initial refresh,
--	otherwise there is a chance the load of the LUA threads (UI & core) will 
--  clash and then we'll all have a bad time. :(
-- ===========================================================================
function OnLoadGameViewStateDone()
	RefreshAll();
end


-- ===========================================================================
function LateInitialize()	

	Resize();

	-- UI Callbacks
	Controls.CivpediaButton:RegisterCallback( Mouse.eLClick, function() LuaEvents.ToggleCivilopedia(); end);
	Controls.CivpediaButton:RegisterCallback( Mouse.eMouseEnter, function() UI.PlaySound("Main_Menu_Mouse_Over"); end);
	Controls.MenuButton:RegisterCallback( Mouse.eLClick, OnMenu );
	Controls.MenuButton:RegisterCallback( Mouse.eMouseEnter, function() UI.PlaySound("Main_Menu_Mouse_Over"); end);
	Controls.TimeCallback:RegisterEndCallback( OnRefreshTimeTick );

	-- Game Events
	Events.AnarchyBegins.Add(				OnRefreshYields );
	Events.AnarchyEnds.Add(					OnRefreshYields );
	Events.BeliefAdded.Add(					OnRefreshYields );
	Events.CityInitialized.Add(				OnCityInitialized );
	Events.CityFocusChanged.Add(            OnRefreshYields );
	Events.CityWorkerChanged.Add(           OnRefreshYields );
	Events.DiplomacySessionClosed.Add(		OnRefreshYields );
	Events.FaithChanged.Add(				OnRefreshYields );
	Events.GovernmentChanged.Add(			OnRefreshYields );
	Events.GovernmentPolicyChanged.Add(		OnRefreshYields );
	Events.GovernmentPolicyObsoleted.Add(	OnRefreshYields );
	Events.GreatWorkCreated.Add(            OnGreatWorkCreated );
	Events.ImprovementAddedToMap.Add(		OnRefreshResources );
	Events.ImprovementRemovedFromMap.Add(	OnRefreshResources );
	Events.InfluenceChanged.Add(			RefreshInfluence );
	Events.LoadGameViewStateDone.Add(		OnLoadGameViewStateDone );
	Events.LocalPlayerChanged.Add(			OnLocalPlayerChanged );
	Events.PantheonFounded.Add(				OnRefreshYields );
	Events.PlayerAgeChanged.Add(			OnRefreshYields );
	Events.ResearchCompleted.Add(			OnRefreshResources );
	Events.PlayerResourceChanged.Add(		OnRefreshResources );
	Events.SystemUpdateUI.Add(				OnUpdateUI );
	Events.TradeRouteActivityChanged.Add(	RefreshTrade );
	Events.TradeRouteCapacityChanged.Add(	RefreshTrade );
	Events.TreasuryChanged.Add(				OnRefreshYields );
	Events.TurnBegin.Add(					OnTurnBegin );
	Events.UnitAddedToMap.Add(				OnRefreshYields );
	Events.UnitGreatPersonActivated.Add(    OnGreatPersonActivated );
	Events.UnitKilledInCombat.Add(			OnRefreshYields );
	Events.UnitRemovedFromMap.Add(			OnRefreshYields );
	Events.VisualStateRestored.Add(			OnTurnBegin );
	Events.WMDCountChanged.Add(				OnWMDUpdate );
	Events.CityProductionChanged.Add(		OnRefreshResources);

	-- If no expansions function are in scope, ready to refresh and show values.
	if not XP1_LateInitialize then
		RefreshYields();
	end
	-- GCO <<<<<
	LuaEvents.RefreshTopPanelGCO.Add(		OnRefreshYields );
	-- GCO >>>>>
end
	

-- ===========================================================================
function OnInit( isReload:boolean )
	LateInitialize();
end


-- ===========================================================================
function Initialize()	
	-- UI Callbacks	
	ContextPtr:SetInitHandler( OnInit );	
	ContextPtr:SetRefreshHandler( OnRefresh );
end
Initialize();
