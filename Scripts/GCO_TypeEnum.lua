--=====================================================================================--
--	FILE:	 GCO_TypeEnum.lua
--  Gedemon (2017)
--=====================================================================================--

print ("Loading GCO_TypeEnum.lua...")

-- Treasury
AccountType	= {	-- ENUM for treasury changes (string as it it used as a key for saved table)

		Production 			= "1",	-- Expense for city Production
		Reinforce			= "2",	-- Expense for unit Reinforcement
		BuildingMaintenance	= "4",	-- Expense for buildings Maintenance (vanilla)
		UnitMaintenance		= "5",	-- Expense for units Maintenance (vanilla)
		DistrictMaintenance	= "6",	-- Expense for district Maintenance (vanilla)
		ImportTaxes			= "7",	-- Income from Import Taxes
		ExportTaxes			= "8",	-- Income from Export Taxes
		Plundering			= "9",	-- Income from units Plundering
		CityTaxes			= "10",	-- Income from City Taxes (vanilla)
}