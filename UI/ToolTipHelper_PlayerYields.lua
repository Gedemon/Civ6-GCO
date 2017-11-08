-- ===========================================================================
-- Shared code to get the tool tip for the local player's gold.
--
-- May want to merge this with ToolTipHelper, though it that file is quite large
-- and the files that currently need the yields tool tip don't require all that
-- extra baggge.
-- ===========================================================================

-- GCO <<<<<
-----------------------------------------------------------------------------------------
-- Initialize Functions
-----------------------------------------------------------------------------------------
GCO = ExposedMembers.GCO -- ExposedMembers.GCO can't be nil at this point


-----------------------------------------------------------------------------------------
-- Includes
-----------------------------------------------------------------------------------------
include( "GCO_TypeEnum" )
include( "GCO_SmallUtils" )
-- GCO >>>>>

-- ===========================================================================
function GetExtendedGoldTooltip()
	local szReturnValue = "";

	local localPlayerID = Game.GetLocalPlayer();
	if (localPlayerID ~= -1) then
		local playerTreasury:table	= Players[localPlayerID]:GetTreasury();
		szReturnValue = szReturnValue .. Locale.Lookup("LOC_TOP_PANEL_GOLD_YIELD_TOOLTIP_NET", playerTreasury:GetGoldYield() - playerTreasury:GetTotalMaintenance());
		szReturnValue = szReturnValue .. "[NEWLINE][NEWLINE]";
		szReturnValue = szReturnValue .. Locale.Lookup("LOC_TOP_PANEL_GOLD_YIELD_TOOLTIP_GROSS", playerTreasury:GetGoldYield());
		szReturnValue = szReturnValue .. "[NEWLINE][NEWLINE]";
		szReturnValue = szReturnValue .. Locale.Lookup("LOC_TOP_PANEL_GOLD_YIELD_TOOLTIP_COSTS", playerTreasury:GetTotalMaintenance());
		szReturnValue = szReturnValue .. "[NEWLINE]  ";
		szReturnValue = szReturnValue .. Locale.Lookup("LOC_TOP_PANEL_GOLD_YIELD_TOOLTIP_COSTS_BUILDINGS", playerTreasury:GetBuildingMaintenance());
		szReturnValue = szReturnValue .. "[NEWLINE]  ";
		szReturnValue = szReturnValue .. Locale.Lookup("LOC_TOP_PANEL_GOLD_YIELD_TOOLTIP_COSTS_DISTRICTS", playerTreasury:GetDistrictMaintenance());
		szReturnValue = szReturnValue .. "[NEWLINE]  ";
		szReturnValue = szReturnValue .. Locale.Lookup("LOC_TOP_PANEL_GOLD_YIELD_TOOLTIP_COSTS_UNITS", playerTreasury:GetUnitMaintenance());
		szReturnValue = szReturnValue .. "[NEWLINE]  ";
		szReturnValue = szReturnValue .. Locale.Lookup("LOC_TOP_PANEL_GOLD_YIELD_TOOLTIP_COSTS_WMDS", playerTreasury:GetWMDMaintenance());
		szReturnValue = szReturnValue .. "[NEWLINE]  ";
		local inferredSiphonFundsAmount = playerTreasury:GetTotalMaintenance() - playerTreasury:GetBuildingMaintenance() - playerTreasury:GetDistrictMaintenance() - playerTreasury:GetUnitMaintenance() - playerTreasury:GetWMDMaintenance();
		szReturnValue = szReturnValue .. Locale.Lookup("LOC_TOP_PANEL_GOLD_YIELD_TOOLTIP_COSTS_HOSTILE_SPIES", inferredSiphonFundsAmount);
	end
	return szReturnValue;
end

-- ===========================================================================
function GetGoldTooltip()
	local szReturnValue = "";

	local localPlayerID = Game.GetLocalPlayer();
	if (localPlayerID ~= -1) then
		local playerTreasury:table	= Players[localPlayerID]:GetTreasury();

		local income_tt_details = playerTreasury:GetGoldYieldToolTip();
		local expense_tt_details = playerTreasury:GetTotalMaintenanceToolTip();

		szReturnValue = Locale.Lookup("LOC_TOP_PANEL_GOLD_YIELD");
		szReturnValue = szReturnValue .. "[NEWLINE][NEWLINE]";
		szReturnValue = szReturnValue .. Locale.Lookup("LOC_TOP_PANEL_GOLD_INCOME", playerTreasury:GetGoldYield());
		if(#income_tt_details > 0) then
			szReturnValue = szReturnValue .. "[NEWLINE]" .. income_tt_details;
		end

		szReturnValue = szReturnValue .. "[NEWLINE][NEWLINE]";
		szReturnValue = szReturnValue .. Locale.Lookup("LOC_TOP_PANEL_GOLD_EXPENSE", -playerTreasury:GetTotalMaintenance());
		if(#expense_tt_details > 0) then
			szReturnValue = szReturnValue .. "[NEWLINE]" .. expense_tt_details;
		end
		
		-- GCO <<<<<
		local player 				= GCO.GetPlayer(localPlayerID) 
		--local balance = player:GetTransactionBalance()
		local baseIncome			= playerTreasury:GetGoldYield() -- vanilla yield
		local importTaxesIncome		= player:GetTransactionType(AccountType.ImportTaxes, GCO.GetPreviousTurnKey()) -- to do : by player playing order, not just assuming local = first
		local exportTaxesIncome		= player:GetTransactionType(AccountType.ExportTaxes)
		local plunderingIncome		= player:GetTransactionType(AccountType.Plundering)
		
		local baseExpense			= -playerTreasury:GetTotalMaintenance()
		local productionExpense		= player:GetTransactionType(AccountType.Production)
		local reinforcementExpense	= player:GetTransactionType(AccountType.Reinforce)
		
		local totalIncome 			= baseIncome + importTaxesIncome + exportTaxesIncome + plunderingIncome
		local totalExpense 			= baseExpense + productionExpense + reinforcementExpense
		
		--	szReturnValue = szReturnValue .. "[NEWLINE][NEWLINE]Extra = " .. tostring(balance) .. "[ICON_Gold]";
		
		szReturnValue = Locale.Lookup("LOC_TOP_PANEL_GOLD_YIELD")
		szReturnValue = szReturnValue .. "[NEWLINE][NEWLINE]"
		szReturnValue = szReturnValue .. Locale.Lookup("LOC_TOP_PANEL_GOLD_INCOME", totalIncome)
		
		if(#income_tt_details > 0) 	then szReturnValue = szReturnValue .. "[NEWLINE]" .. income_tt_details end
		if importTaxesIncome > 0 	then szReturnValue = szReturnValue .. "[NEWLINE]" .. Locale.Lookup("LOC_TOP_PANEL_IMPORT_INCOME", importTaxesIncome) end
		if exportTaxesIncome > 0 	then szReturnValue = szReturnValue .. "[NEWLINE]" .. Locale.Lookup("LOC_TOP_PANEL_EXPORT_INCOME", exportTaxesIncome) end	
		if plunderingIncome > 0 	then szReturnValue = szReturnValue .. "[NEWLINE]" .. Locale.Lookup("LOC_TOP_PANEL_PLUDERING_INCOME", plunderingIncome) end	
		
		szReturnValue = szReturnValue .. "[NEWLINE][NEWLINE]"
		szReturnValue = szReturnValue .. Locale.Lookup("LOC_TOP_PANEL_GOLD_EXPENSE", totalExpense)
		if(#expense_tt_details > 0) then szReturnValue = szReturnValue .. "[NEWLINE]" .. expense_tt_details	end
		if productionExpense < 0 	then szReturnValue = szReturnValue .. "[NEWLINE]" .. Locale.Lookup("LOC_TOP_PANEL_PRODUCTION_EXPENSE", productionExpense) end
		if reinforcementExpense < 0 then szReturnValue = szReturnValue .. "[NEWLINE]" .. Locale.Lookup("LOC_TOP_PANEL_REINFORCEMENT_EXPENSE", reinforcementExpense) end
			
		-- GCO >>>>>
	end
	return szReturnValue;
end

-- ===========================================================================
function GetScienceTooltip()
	local szReturnValue = "";

	local localPlayerID = Game.GetLocalPlayer();
	if (localPlayerID ~= -1) then
		local playerTechnology		:table	= Players[localPlayerID]:GetTechs();
		local currentScienceYield	:number = playerTechnology:GetScienceYield();

		szReturnValue = Locale.Lookup("LOC_TOP_PANEL_SCIENCE_YIELD");
		local science_tt_details = playerTechnology:GetScienceYieldToolTip();
		if(#science_tt_details > 0) then
			szReturnValue = szReturnValue .. "[NEWLINE][NEWLINE]" .. science_tt_details;
		end
	end
	return szReturnValue;
end

-- ===========================================================================
function GetCultureTooltip()
	local szReturnValue = "";

	local localPlayerID = Game.GetLocalPlayer();
	if (localPlayerID ~= -1) then
		local playerCulture			:table	= Players[localPlayerID]:GetCulture();
		local currentCultureYield	:number = playerCulture:GetCultureYield();

		szReturnValue = Locale.Lookup("LOC_TOP_PANEL_CULTURE_YIELD");
		local culture_tt_details = playerCulture:GetCultureYieldToolTip();
		if(#culture_tt_details > 0) then
			szReturnValue = szReturnValue .. "[NEWLINE][NEWLINE]" .. culture_tt_details;
		end
	end
	return szReturnValue;
end

-- ===========================================================================
function GetFaithTooltip()
	local szReturnValue = "";

	local localPlayerID = Game.GetLocalPlayer();
	if (localPlayerID ~= -1) then
		local playerReligion		:table	= Players[localPlayerID]:GetReligion();
		local faithYield			:number = playerReligion:GetFaithYield();
		local faithBalance			:number = playerReligion:GetFaithBalance();

		szReturnValue = Locale.Lookup("LOC_TOP_PANEL_FAITH_YIELD");
		local faith_tt_details = playerReligion:GetFaithYieldToolTip();
		if(#faith_tt_details > 0) then
			szReturnValue = szReturnValue .. "[NEWLINE][NEWLINE]" .. faith_tt_details;
		end
	end
	return szReturnValue;
end
