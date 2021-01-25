-- ===========================================================================
--
--	City Support
--	Civilization VI, Firaxis Games

-- ===========================================================================

include("PortraitSupport");
include("ToolTipHelper");

-- GCO <<<<<
-----------------------------------------------------------------------------------------
-- Initialize Functions
-----------------------------------------------------------------------------------------

local GCO 			= {}
local GameEvents	= ExposedMembers.GameEvents
--local LuaEvents		= ExposedMembers.LuaEvents
function InitializeUtilityFunctions()
	GCO = ExposedMembers.GCO		-- contains functions from other contexts
	print ("Exposed Functions from other contexts initialized...")
end
GameEvents.InitializeGCO.Add( InitializeUtilityFunctions )
-- GCO >>>>>

-- ===========================================================================
--	CONSTANTS
-- ===========================================================================
DATA_DOMINANT_RELIGION = "_DOMINANTRELIGION";

YIELD_STATE = {
	NORMAL  = 0,
	FAVORED = 1,
	IGNORED = 2
}


-- ===========================================================================
--	Obtains the texture for a city's current production.
--	pCity				The city
--	optionalIconSize	Size of the icon to return.
--
--	RETURNS	NIL if error, otherwise a table containing:
--			name of production item
--			description
--			icon texture of the produced item
--			u offset of the icon texture
--			v offset of the icon texture
--			(0-1) percent complete
--			(0-1) percent complete after next turn
--			# of turns
--			progress
--			cost
-- ===========================================================================
function GetCurrentProductionInfoOfCity( pCity:table, iconSize:number )
	local pBuildQueue	:table = pCity:GetBuildQueue();
	if pBuildQueue == nil then
		UI.DataError("No production queue in city!");
		return nil;
	end	
	local hash	:number = pBuildQueue:GetCurrentProductionTypeHash();
	local data	:table  = GetProductionInfoOfCity(pCity, hash);
	return data;
end

-- ===========================================================================
function GetFilteredUnitStatString( statData:table )
	if statData == nil then
		UI.DataError("Invalid stat data passed to GetFilteredUnitStatString");
		return "";
	end

	local statString = "";
	local statStringTooltip = "";
	local newlineCounter = 0;
	for _,statTable in pairs(statData) do
		statString = statString.. statTable.FontIcon.. " ".. statTable.Value.. " ";
		if (newlineCounter == 2) then
			statString = statString.. "[NEWLINE]";
			newlineCounter = 0;
		end
		newlineCounter = newlineCounter + 1;

		statStringTooltip = statStringTooltip.. Locale.Lookup(statTable.Label).. " ".. statTable.Value.. "[NEWLINE]";
	end
	--return statString, statStringTooltip;
	return statString;
end

-- ===========================================================================
function FilterUnitStats( hashOrType:number, eMilitaryFormationType:number )
	local unitInfo = GameInfo.Units[hashOrType];

	if(unitInfo == nil) then
		UI.DataError("Invalid unit hash passed to FilterUnitStats");
		return {};
	end

	local strengthMod : number = 0;

	if(eMilitaryFormationType ~= nil)then
		if eMilitaryFormationType == MilitaryFormationTypes.CORPS_MILITARY_FORMATION then
			strengthMod = GlobalParameters.COMBAT_CORPS_STRENGTH_MODIFIER; 
		elseif eMilitaryFormationType == MilitaryFormationTypes.ARMY_MILITARY_FORMATION then
			strengthMod = GlobalParameters.COMBAT_ARMY_STRENGTH_MODIFIER;
		end
	end

	local data:table = {};

	-- Strength
	if ( unitInfo.Combat > 0) then
		table.insert(data, {Value = unitInfo.Combat + strengthMod, Type = "Combat", Label = "LOC_HUD_UNIT_PANEL_STRENGTH",				FontIcon="[ICON_Strength_Large]",		IconName="ICON_STRENGTH"});
	end
	if ( unitInfo.RangedCombat > 0) then
		table.insert(data, {Value = unitInfo.RangedCombat + strengthMod,		Label = "LOC_HUD_UNIT_PANEL_RANGED_STRENGTH",		FontIcon="[ICON_RangedStrength_Large]",	IconName="ICON_RANGED_STRENGTH"});
	end
	if (unitInfo.Bombard > 0) then
		table.insert(data, {Value = unitInfo.Bombard + strengthMod,	Label = "LOC_HUD_UNIT_PANEL_BOMBARD_STRENGTH",		FontIcon="[ICON_Bombard_Large]",		IconName="ICON_BOMBARD"});
	end
	if (unitInfo.ReligiousStrength > 0) then
		table.insert(data, {Value = unitInfo.ReligiousStrength,	Label = "LOC_HUD_UNIT_PANEL_RELIGIOUS_STRENGTH",	FontIcon="[ICON_ReligionStat_Large]",	IconName="ICON_RELIGION"});
	end
	if (unitInfo.AntiAirCombat > 0) then
		table.insert(data, {Value = unitInfo.AntiAirCombat,	Label = "LOC_HUD_UNIT_PANEL_ANTI_AIR_STRENGTH",		FontIcon="[ICON_AntiAir_Large]",		IconName="ICON_STATS_ANTIAIR"});
	end

	-- Movement
	if(unitInfo.BaseMoves > 0) then
		table.insert(data, {Value = unitInfo.BaseMoves, Type = "BaseMoves",		Label = "LOC_HUD_UNIT_PANEL_MOVEMENT",				FontIcon="[ICON_Movement_Large]",		IconName="ICON_MOVES"});
	end

	-- Range
	if (unitInfo.Range > 0) then
		table.insert(data, {Value = unitInfo.Range;			Label = "LOC_HUD_UNIT_PANEL_ATTACK_RANGE",			FontIcon="[ICON_Range_Large]",			IconName="ICON_RANGE"});
	end

	-- Charges
	if (unitInfo.SpreadCharges > 0) then
		table.insert(data, {Value = unitInfo.SpreadCharges,	Type = "SpreadCharges", Label = "LOC_HUD_UNIT_PANEL_SPREADS",				FontIcon="[ICON_ReligionStat_Large]",	IconName="ICON_RELIGION"});
	end
	if (unitInfo.BuildCharges > 0) then
		table.insert(data, {Value = unitInfo.BuildCharges, Type = "BuildCharges",		Label = "LOC_HUD_UNIT_PANEL_BUILDS",				FontIcon="[ICON_Charges_Large]",		IconName="ICON_BUILD_CHARGES"});
	end
	if (unitInfo.ReligiousHealCharges > 0) then
		table.insert(data, {Value = unitInfo.ReligiousHealCharges, Type = "ReligiousHealCharges",		Label = "LOC_HUD_UNIT_PANEL_HEALS",				FontIcon="[ICON_Charges_Large]",		IconName="ICON_RELIGION"});
	end

	-- If we have more than 4 stats then try to remove melee strength
	if (table.count(data) > 4) then
		for i,stat in ipairs(data) do
			if stat.Type == "Combat" then
				table.remove(data, i);
			end
		end
	end

	-- If we still have more than 4 stats through a data error
	if (table.count(data) > 4) then
		UI.DataError("More than four stats were picked to display for unit ".. unitInfo.UnitType);
	end

	return data;
end

-- ===========================================================================
--	Obtains the texture for a city's current production.
--	pCity				The city
--	productionHash		the production hash (present or past) that you want the info for
--
--	RETURNS	NIL if error, otherwise a table containing:
--			name of production item
--			description
--			icon texture of the produced item
--			u offset of the icon texture
--			v offset of the icon texture
--			(0-1) percent complete
--			(0-1) percent complete after next turn
-- ===========================================================================
function GetProductionInfoOfCity( pCity:table, productionHash:number )
	local pBuildQueue	:table = pCity:GetBuildQueue();
	if pBuildQueue == nil then
		UI.DataError("No production queue in city!");
		return nil;
	end
	
	local hash						= productionHash;
	local progress					:number = 0;
	local cost						:number = 0;
	local percentComplete			:number = 0;
	local percentCompleteNextTurn	:number = 0;
	local productionName			:string;
	local description				:string;
	local tooltip					:string;
	local statString				:string;		-- stats for unit to display
	local kIcons					:table = {};	-- icon(s) to use, best first
	local texture					:string;		-- texture of icon
	local u							:number = 0;	-- texture horiztonal offset
	local v							:number = 0;	-- texture vertical offset

	-- Nothing being produced.
	if hash == 0 then
		return {
			Name					= Locale.Lookup("LOC_HUD_CITY_NOTHING_PRODUCED"),
			Description				= "", 
			Texture					= "CityPanel_CitizenIcon",	-- Default texture
			u						= 0,
			v						= 0,
			PercentComplete			= 0, 
			PercentCompleteNextTurn	= 0,
			Turns					= 0,
			Progress				= 0,
			Cost					= 0
		};
	end

	-- Find the information
	local buildingDef	:table = GameInfo.Buildings[hash];
	local districtDef	:table = GameInfo.Districts[hash];
	local unitDef		:table = GameInfo.Units[hash];
	local projectDef	:table = GameInfo.Projects[hash];
	local type			:string= "";

	if( buildingDef ~= nil ) then
		prodTurnsLeft = pBuildQueue:GetTurnsLeft(buildingDef.BuildingType);
		productionName	= Locale.Lookup(buildingDef.Name);
		description		= buildingDef.Description;
		tooltip			= ToolTipHelper.GetBuildingToolTip(hash, Game.GetLocalPlayer(), pCity )
		progress		= pBuildQueue:GetBuildingProgress(buildingDef.Index);
		percentComplete	= progress / pBuildQueue:GetBuildingCost(buildingDef.Index);
		cost			= pBuildQueue:GetBuildingCost(buildingDef.Index);
		kIcons			= {"ICON_"..buildingDef.BuildingType};
		type			= ProductionType.BUILDING;

	elseif( districtDef ~= nil ) then
		prodTurnsLeft = pBuildQueue:GetTurnsLeft(districtDef.DistrictType);
		productionName	= Locale.Lookup(districtDef.Name);
		description		= districtDef.Description;
		tooltip			= ToolTipHelper.GetDistrictToolTip(hash);
		progress		= pBuildQueue:GetDistrictProgress(districtDef.Index);
		percentComplete	= progress / pBuildQueue:GetDistrictCost(districtDef.Index);
		cost			= pBuildQueue:GetDistrictCost(districtDef.Index);
		kIcons			= {"ICON_"..districtDef.DistrictType};
		type			= ProductionType.DISTRICT;

	elseif( unitDef ~= nil ) then

		local owner	:number = pCity:GetOwner();
		local iconName, prefixOnlyIconName, eraOnlyIconName, fallbackIconName = GetUnitPortraitIconNamesFromDefinition( owner, unitDef );		

		prodTurnsLeft = pBuildQueue:GetTurnsLeft(unitDef.UnitType);
		local eMilitaryFormationType :number = pBuildQueue:GetCurrentProductionTypeModifier();
		productionName	= Locale.Lookup(unitDef.Name);
		description		= unitDef.Description;
		tooltip			= ToolTipHelper.GetUnitToolTip(hash, eMilitaryFormationType, pBuildQueue);
		progress		= pBuildQueue:GetUnitProgress(unitDef.Index);
		prodTurnsLeft	= pBuildQueue:GetTurnsLeft(unitDef.UnitType);		
		kIcons			= { iconName, prefixOnlyIconName, eraOnlyIconName, fallbackIconName, "ICON_"..unitDef.UnitType.."_PORTRAIT"}
		statString		= GetFilteredUnitStatString(FilterUnitStats(hash, eMilitaryFormationType));
		type			= ProductionType.UNIT;

		--Units need some additional information to represent the Standard, Corps, and Army versions. This is determined by the MilitaryFormationType
		if (eMilitaryFormationType == MilitaryFormationTypes.STANDARD_FORMATION) then
			percentComplete = progress / pBuildQueue:GetUnitCost(unitDef.Index);	
			cost			= pBuildQueue:GetUnitCost(unitDef.Index);
		elseif (eMilitaryFormationType == MilitaryFormationTypes.CORPS_FORMATION) then
			percentComplete = progress / pBuildQueue:GetUnitCorpsCost(unitDef.Index);
			cost			= pBuildQueue:GetUnitCorpsCost(unitDef.Index);
			if (unitDef.Domain == "DOMAIN_SEA") then
				productionName = productionName .. " " .. Locale.Lookup("LOC_UNITFLAG_FLEET_SUFFIX");
			else
				productionName = productionName .. " " .. Locale.Lookup("LOC_UNITFLAG_CORPS_SUFFIX");
			end
		elseif (eMilitaryFormationType == MilitaryFormationTypes.ARMY_FORMATION) then
			percentComplete = progress / pBuildQueue:GetUnitArmyCost(unitDef.Index);
			cost			= pBuildQueue:GetUnitArmyCost(unitDef.Index);
			if (unitDef.Domain == "DOMAIN_SEA") then
				productionName = productionName .. " " .. Locale.Lookup("LOC_UNITFLAG_ARMADA_SUFFIX");
			else
				productionName = productionName .. " " .. Locale.Lookup("LOC_UNITFLAG_ARMY_SUFFIX");
			end
		end

	elseif (projectDef ~= nil) then
		prodTurnsLeft = pBuildQueue:GetTurnsLeft(projectDef.ProjectType);
		productionName	= Locale.Lookup(projectDef.Name);
		description		= projectDef.Description;
		tooltip			= ToolTipHelper.GetProjectToolTip(hash);
		progress		= pBuildQueue:GetProjectProgress(projectDef.Index);
		cost			= pBuildQueue:GetProjectCost(projectDef.Index);
		percentComplete	= progress / pBuildQueue:GetProjectCost(projectDef.Index);
		kIcons			= {"ICON_"..projectDef.ProjectType};
		type			= ProductionType.PROJECT;
	else
		for row in GameInfo.Types() do
			if row.Hash == hash then
				UI.DataError("Unknown kind of item being produced in city \""..tostring(row.Kind).."\"");
				return nil;
			end
		end
		UI.DataError("Game database does not contain information that matches what the city "..Locale.Lookup(data.CityName).." is producing!");
		return nil;
	end
	if percentComplete > 1 then
		percentComplete = 1;
	end

	percentCompleteNextTurn = (1-percentComplete)/prodTurnsLeft;
	percentCompleteNextTurn = percentComplete + percentCompleteNextTurn;

	return {
		Name					= productionName,
		Description				= description,
		Tooltip					= tooltip,
		Type					= type;
		Icons					= kIcons,
		PercentComplete			= percentComplete, 
		PercentCompleteNextTurn	= percentCompleteNextTurn,
		Turns					= prodTurnsLeft,
		StatString				= statString;
		Progress				= progress;
		Cost					= cost;		
	};
end


-- ===========================================================================
--	Update the yield data for a city.
-- ===========================================================================
function UpdateYieldData( pCity:table, data:table )
	data.CulturePerTurn				= math.floor( pCity:GetYield( YieldTypes.CULTURE )*10) / 10;
	data.CulturePerTurnToolTip		= pCity:GetYieldToolTip(YieldTypes.CULTURE);

	data.FaithPerTurn				= math.floor( pCity:GetYield( YieldTypes.FAITH )*10) / 10;
	data.FaithPerTurnToolTip		= pCity:GetYieldToolTip(YieldTypes.FAITH);

	data.FoodPerTurn				= math.floor( pCity:GetYield( YieldTypes.FOOD )*10) / 10;
	data.FoodPerTurnToolTip			= pCity:GetYieldToolTip(YieldTypes.FOOD);

	data.GoldPerTurn				= math.floor( pCity:GetYield( YieldTypes.GOLD )*10) / 10;
	data.GoldPerTurnToolTip			= pCity:GetYieldToolTip(YieldTypes.GOLD);

	data.ProductionPerTurn			= math.floor( pCity:GetYield( YieldTypes.PRODUCTION )*10) / 10;
	data.ProductionPerTurnToolTip	= pCity:GetYieldToolTip(YieldTypes.PRODUCTION);

	data.SciencePerTurn				= math.floor( pCity:GetYield( YieldTypes.SCIENCE )*10) / 10;
	data.SciencePerTurnToolTip		= pCity:GetYieldToolTip(YieldTypes.SCIENCE);

	return data;
end


-- ===========================================================================
-- ===========================================================================
function GetDistrictYieldText(district)
	local yieldText = "";
	for yield in GameInfo.Yields() do
		local yieldAmount = district:GetYield(yield.Index);
		if yieldAmount > 0 then
			yieldText = yieldText .. GetYieldString( yield.YieldType, yieldAmount );
		end
	end
	return yieldText;
end

-- ===========================================================================
--	For a given city, return a table o' data for it and the surrounding
--	districts.
--	RETURNS:	table of data
-- ===========================================================================
function GetCityData( pCity:table )

	local owner					:number = pCity:GetOwner();
	local pPlayer				:table	= Players[owner];
	local pCityDistricts		:table	= pCity:GetDistricts();
	local pMainDistrict			:table	= pPlayer:GetDistricts():FindID( pCity:GetDistrictID() );	-- Note player GetDistrict's object is different than above.
	local districtHitpoints		:number	= 0;
	local currentDistrictDamage :number = 0;
	local wallHitpoints			:number	= 0;
	local currentWallDamage		:number	= 0;
	local garrisonDefense		:number	= 0;

	if pCity ~= nil and pMainDistrict ~= nil then
		districtHitpoints		= pMainDistrict:GetMaxDamage(DefenseTypes.DISTRICT_GARRISON);
		currentDistrictDamage	= pMainDistrict:GetDamage(DefenseTypes.DISTRICT_GARRISON);
		wallHitpoints			= pMainDistrict:GetMaxDamage(DefenseTypes.DISTRICT_OUTER);
		currentWallDamage		= pMainDistrict:GetDamage(DefenseTypes.DISTRICT_OUTER);
		garrisonDefense			= math.floor(pMainDistrict:GetDefenseStrength() + 0.5);
	end

	-- Return value is here, 0/nil may be filled out below.
	local data :table = {
		AmenitiesNetAmount				= 0,
		AmenitiesNum					= 0,
		AmenitiesFromLuxuries			= 0,
		AmenitiesFromEntertainment		= 0,
		AmenitiesFromCivics				= 0,
		AmenitiesFromGreatPeople		= 0,
		AmenitiesFromCityStates			= 0,
		AmenitiesFromReligion			= 0,
		AmenitiesFromNationalParks  	= 0,
		AmenitiesFromStartingEra		= 0,
		AmenitiesFromImprovements		= 0,
		AmenitiesRequiredNum			= 0,
		BeliefsOfDominantReligion		= {},
		Buildings						= {},		-- Per Entry Format: { Name, CitizenNum }
		BuildingsNum					= 0,
		BuildingsAndDistricts			= {},		-- Per Entry Format: { Name, YieldType, YieldChange, Buildings={ Name,YieldType,YieldChange,isPillaged,isBuilt} }
		CityWallTotalHP					= 0,
		CityWallHPPercent				= 0,
		City							= pCity,
		CityName						= pCity:GetName(),
		CulturePerTurn					= 0,
		CurrentFoodPercent				= 0;		
		CurrentProdPercent				= 0,
		CurrentProductionName			= "",
		CurrentProductionDescription	= "",
		CurrentTurnsLeft				= 0,
		Damage							= 0,
		Defense							= garrisonDefense;
		DistrictsNum					= pCityDistricts:GetNumZonedDistrictsRequiringPopulation(),
		DistrictsPossibleNum			= pCityDistricts:GetNumAllowedDistrictsRequiringPopulation(),
		FaithPerTurn					= 0,
		FoodPercentNextTurn				= 0,
		FoodPerTurn						= 0,
		FoodSurplus						= 0,
		GoldPerTurn						= 0,
		GrowthPercent					= 100,
		GrowthThreshold				= 0,
		Happiness						= 0,		
		HappinessGrowthModifier			= 0,		-- Multiplier
		HappinessNonFoodYieldModifier	= 0,		-- Multiplier
		Housing							= 0,
		HousingMultiplier				= 0,
		IsCapital						= pCity:IsCapital(),
		IsUnderSiege					= false,
		OccupationMultiplier            = 0,
		Owner							= owner,
		OtherGrowthModifiers			= 0,
		PantheonBelief					= -1,
		Population						= pCity:GetPopulation(),
		ProdPercentNextTurn				= 0,
		ProductionPerTurn				= 0;		
		ProductionQueue					= {},
		Religions						= {},		-- Format per entry: { Name, Followers }
		ReligionFollowers				= 0,
		SciencePerTurn					= 0,
		TradingPosts					= {},		-- Format per entry: { Player Number }
		TurnsUntilGrowth				= 0,
		TurnsUntilExpansion				= 0,
		UnitStats						= nil,
		Wonders							= {},		-- Format per entry: { Name, YieldType, YieldChange }		
		YieldFilters					= {}	
	};
		
	local pCityGrowth					:table = pCity:GetGrowth();
	local pCityCulture					:table = pCity:GetCulture();
	local cityGold						:table = pCity:GetGold();		
	local pBuildQueue					:table = pCity:GetBuildQueue();
	local currentProduction				:string = TXT_NO_PRODUCTION;
	local currentProductionDescription	:string = "";
	local currentProductionStats		:string = "";
	local pct							:number = 0;
	local pctNextTurn					:number = 0;
	local prodTurnsLeft					:number = -1;
	local productionInfo				:table = GetCurrentProductionInfoOfCity( pCity, SIZE_PRODUCTION_ICON );

	-- If something is currently being produced, mark it in the queue.
	if productionInfo ~= nil then
		currentProduction				= productionInfo.Name;
		currentProductionDescription	= productionInfo.Description;
		if(productionInfo.StatString ~= nil) then
			currentProductionStats		= productionInfo.StatString;
		end
		pct								= productionInfo.PercentComplete;
		pctNextTurn						= productionInfo.PercentCompleteNextTurn;
		prodTurnsLeft					= productionInfo.Turns;
		productionInfo.Index			= 1;
		data.ProductionQueue[1]			= productionInfo;	--Place in front

		-- Some buildings will not have a description.
		if currentProductionDescription == nil then
			currentProductionDescription = "";
		end
	end


	local isGrowing	:boolean = pCityGrowth:GetTurnsUntilGrowth() ~= -1;
	local isStarving:boolean = pCityGrowth:GetTurnsUntilStarvation() ~= -1;

	local turnsUntilGrowth :number = 0;	-- It is possible for zero... no growth and no starving.
	if isGrowing then
		turnsUntilGrowth = pCityGrowth:GetTurnsUntilGrowth();
	elseif isStarving then
		turnsUntilGrowth = -pCityGrowth:GetTurnsUntilStarvation();	-- Make negative
	end	
		
	local food             :number = pCityGrowth:GetFood();
	local growthThreshold  :number = pCityGrowth:GetGrowthThreshold();
	local foodSurplus      :number = pCityGrowth:GetFoodSurplus();
	local foodpct          :number = Clamp( food / growthThreshold, 0.0, 1.0 );
	local foodpctNextTurn  :number = 0;
	if turnsUntilGrowth > 0 then
		local foodGainNextTurn = foodSurplus * pCityGrowth:GetOverallGrowthModifier();
		foodpctNextTurn = (food + foodGainNextTurn) / growthThreshold;
		foodpctNextTurn = Clamp( foodpctNextTurn, 0.0, 1.0 );
	end

	-- Three religion objects to work with: overall game object, the player's religion, and this specific city's religious population
	local pGameReligion		:table = Game.GetReligion();
	local pPlayerReligion	:table = pPlayer:GetReligion();
	local pAllReligions		:table = pGameReligion:GetReligions();
	local pReligions		:table = pCity:GetReligion():GetReligionsInCity();	
	local eDominantReligion	:number = pCity:GetReligion():GetMajorityReligion();
	local followersAll		:number = 0;
	for _, religionData in pairs(pReligions) do				

		-- If the value for the religion type is less than 0, there is no religion (citizens working towards a Patheon).
		local religionType	:string = (religionData.Religion > 0) and GameInfo.Religions[religionData.Religion].ReligionType or "RELIGION_PANTHEON";
		local thisReligion	:table = { ID=religionData.Religion, ReligionType=religionType, Followers=religionData.Followers };
		table.insert( data.Religions, thisReligion );		

		if religionData.Religion == eDominantReligion and eDominantReligion > -1 then
			data.Religions[DATA_DOMINANT_RELIGION] = thisReligion;
			for _,kFoundReligion in ipairs(pAllReligions) do
				if kFoundReligion.Religion == eDominantReligion then
					for _,belief in pairs(kFoundReligion.Beliefs) do
						table.insert( data.BeliefsOfDominantReligion, belief );
					end
					break;
				end
			end
		end

		if religionType ~= "RELIGION_PANTHEON" then
			followersAll = followersAll + religionData.Followers;
		end
	end

	data.AmenitiesNetAmount				= pCityGrowth:GetAmenities() - pCityGrowth:GetAmenitiesNeeded();
	data.AmenitiesNum					= pCityGrowth:GetAmenities();
	data.AmenitiesFromLuxuries			= pCityGrowth:GetAmenitiesFromLuxuries();
	data.AmenitiesFromEntertainment		= pCityGrowth:GetAmenitiesFromEntertainment();
	data.AmenitiesFromCivics			= pCityGrowth:GetAmenitiesFromCivics();
	data.AmenitiesFromGreatPeople		= pCityGrowth:GetAmenitiesFromGreatPeople();
	data.AmenitiesFromCityStates		= pCityGrowth:GetAmenitiesFromCityStates();
	data.AmenitiesFromReligion			= pCityGrowth:GetAmenitiesFromReligion();
	data.AmenitiesFromNationalParks		= pCityGrowth:GetAmenitiesFromNationalParks();
	data.AmenitiesFromStartingEra		= pCityGrowth:GetAmenitiesFromStartingEra();
	data.AmenitiesFromImprovements		= pCityGrowth:GetAmenitiesFromImprovements();
	data.AmenitiesLostFromWarWeariness	= pCityGrowth:GetAmenitiesLostFromWarWeariness();
	data.AmenitiesLostFromBankruptcy	= pCityGrowth:GetAmenitiesLostFromBankruptcy();
	data.AmenitiesRequiredNum			= pCityGrowth:GetAmenitiesNeeded();
	data.AmenitiesFromDistricts			= pCityGrowth:GetAmenitiesFromDistricts();
	data.AmenitiesFromNaturalWonders			= pCityGrowth:GetAmenitiesFromNaturalWonders();
	data.AmenityAdvice					= pCity:GetAmenityAdvice();
	data.CityWallHPPercent				= (wallHitpoints-currentWallDamage) / wallHitpoints;
	data.CityWallCurrentHP				= wallHitpoints-currentWallDamage;
	data.CityWallTotalHP				= wallHitpoints;
	data.CurrentFoodPercent				= foodpct;
	data.CurrentProductionName			= Locale.Lookup( currentProduction );
	data.CurrentProdPercent				= pct;
	data.CurrentProductionDescription	= Locale.Lookup( currentProductionDescription );
	data.CurrentProductionIcons			= productionInfo and productionInfo.Icons;
	data.CurrentProductionStats			= productionInfo.StatString;
	data.CurrentTurnsLeft				= prodTurnsLeft;		
	data.FoodPercentNextTurn			= foodpctNextTurn;
	data.FoodSurplus					= Round( foodSurplus, 1);
	data.GrowthThreshold				= growthThreshold - food;
	data.Happiness						= pCityGrowth:GetHappiness();
	data.HappinessGrowthModifier		= pCityGrowth:GetHappinessGrowthModifier();
	data.HappinessNonFoodYieldModifier	= pCityGrowth:GetHappinessNonFoodYieldModifier();
	data.HitpointPercent				= ((districtHitpoints-currentDistrictDamage) / districtHitpoints);
	data.HitpointsCurrent				= districtHitpoints-currentDistrictDamage;
	data.HitpointsTotal					= districtHitpoints;
	data.Housing						= pCityGrowth:GetHousing();
	data.HousingFromWater				= pCityGrowth:GetHousingFromWater();
	data.HousingFromBuildings			= pCityGrowth:GetHousingFromBuildings();
	data.HousingFromImprovements		= pCityGrowth:GetHousingFromImprovements();
	data.HousingFromDistricts			= pCityGrowth:GetHousingFromDistricts();
	data.HousingFromCivics				= pCityGrowth:GetHousingFromCivics();
	data.HousingFromGreatPeople			= pCityGrowth:GetHousingFromGreatPeople();
	data.HousingFromStartingEra			= pCityGrowth:GetHousingFromStartingEra();
	data.HousingMultiplier				= pCityGrowth:GetHousingGrowthModifier();
	data.HousingAdvice					= pCity:GetHousingAdvice();
	data.OccupationMultiplier			= pCityGrowth:GetOccupationGrowthModifier();
	data.Occupied                       = pCity:IsOccupied();
	data.OtherGrowthModifiers			= pCityGrowth:GetOtherGrowthModifier();	-- Growth modifiers from Religion & Wonders
	data.PantheonBelief					= pPlayerReligion:GetPantheon();	
	data.ProdPercentNextTurn			= pctNextTurn;
	data.ReligionFollowers				= followersAll;
	data.TurnsUntilExpansion			= pCityCulture:GetTurnsUntilExpansion();
	data.TurnsUntilGrowth				= turnsUntilGrowth;
	data.UnitStats						= GetUnitStats( pBuildQueue:GetCurrentProductionTypeHash() );	--NIL if not a unit
	
	-- Helper to get an internally used enum based on the state of a certain yield.	
	local pCitizens :table = pCity:GetCitizens();
	function GetYieldState( yieldEnum:number )
		if pCitizens:IsFavoredYield(yieldEnum) then			return YIELD_STATE.FAVORED;
		elseif pCitizens:IsDisfavoredYield(yieldEnum) then	return YIELD_STATE.IGNORED;
		else												return YIELD_STATE.NORMAL;
		end
	end	 		
	data.YieldFilters[YieldTypes.CULTURE]	= GetYieldState(YieldTypes.CULTURE);
	data.YieldFilters[YieldTypes.FAITH]		= GetYieldState(YieldTypes.FAITH);
	data.YieldFilters[YieldTypes.FOOD]		= GetYieldState(YieldTypes.FOOD);
	data.YieldFilters[YieldTypes.GOLD]		= GetYieldState(YieldTypes.GOLD);
	data.YieldFilters[YieldTypes.PRODUCTION]= GetYieldState(YieldTypes.PRODUCTION);
	data.YieldFilters[YieldTypes.SCIENCE]	= GetYieldState(YieldTypes.SCIENCE);
	data = UpdateYieldData( pCity, data );

	-- Determine builds, districts, and wonders
	local pCityBuildings	:table = pCity:GetBuildings();
	local kCityPlots		:table = Map.GetCityPlots():GetPurchasedPlots( pCity );
	if (kCityPlots ~= nil) then
		for _,plotID in pairs(kCityPlots) do
			local kPlot:table =  Map.GetPlotByIndex(plotID);
			local kBuildingTypes:table = pCityBuildings:GetBuildingsAtLocation(plotID);
			for _, type in ipairs(kBuildingTypes) do
				local building	= GameInfo.Buildings[type];
				-- GCO <<<<<
				if not building.NoCityScreen then
				-- GCO >>>>>
					table.insert( data.Buildings, { 
						Name		= building.Name, 
						Citizens	= kPlot:GetWorkerCount(),
						isPillaged	= pCityBuildings:IsPillaged(type),
						Maintenance	= building.Maintenance			--Expense in gold
					});
				-- GCO <<<<<
				end
				-- GCO >>>>>
			end
		end
	end	

	local pDistrict : table = pPlayer:GetDistricts():FindID( pCity:GetDistrictID() );
	if pDistrict ~= nil then
		data.IsUnderSiege = pDistrict:IsUnderSiege();
	else
		UI.DataError("Some data will be missing as unable to obtain the corresponding district for city: "..pCity:GetName());
	end



	for i, district in pCityDistricts:Members() do

		-- Helper to obtain yields for a district: build a lookup table and then match type.
		local kTempDistrictYields :table = {};
		for yield in GameInfo.Yields() do
			kTempDistrictYields[yield.Index] = yield;
		end
		-- ==========
		function GetDistrictYield( district:table, yieldType:string )
			for i,yield in ipairs( kTempDistrictYields ) do
				if yield.YieldType == yieldType then
					return district:GetYield(i);
				end
			end
			return 0;
		end

		--I do not know why we make local functions, but I am keeping standard
		function GetDistrictBonus( district:table, yieldType:string )
			for i,yield in ipairs( kTempDistrictYields ) do
				if yield.YieldType == yieldType then
					return district:GetAdjacencyYield(i);
				end
			end
			return 0;
		end


		local districtInfo	:table	= GameInfo.Districts[district:GetType()];
		local districtType	:string = districtInfo.DistrictType;	
		local locX			:number = district:GetX();
		local locY			:number = district:GetY();
		local kPlot			:table  = Map.GetPlot(locX,locY);
		local plotID		:number = kPlot:GetIndex();	
		local districtTable :table	= { 
			Name		= Locale.Lookup(districtInfo.Name), 
			Type		= districtType,
			YieldBonus	= GetDistrictYieldText( district ),
			isPillaged  = pCityDistricts:IsPillaged(district:GetType(), plotID);
			isBuilt		= pCityDistricts:HasDistrict(districtInfo.Index, true);
			Icon		= "ICON_"..districtType,
			Buildings	= {},
			Culture		= GetDistrictYield(district, "YIELD_CULTURE" ),			
			Faith		= GetDistrictYield(district, "YIELD_FAITH" ),
			Food		= GetDistrictYield(district, "YIELD_FOOD" ),
			Gold		= GetDistrictYield(district, "YIELD_GOLD" ),
			Production	= GetDistrictYield(district, "YIELD_PRODUCTION" ),
			Science		= GetDistrictYield(district, "YIELD_SCIENCE" ),
			Tourism		= 0,
			Maintenance = districtInfo.Maintenance,
			AdjacencyBonus = {
				Culture		= GetDistrictBonus(district, "YIELD_CULTURE"),
				Faith		= GetDistrictBonus(district, "YIELD_FAITH"),
				Food		= GetDistrictBonus(district, "YIELD_FOOD"),
				Gold		= GetDistrictBonus(district, "YIELD_GOLD"),
				Production	= GetDistrictBonus(district, "YIELD_PRODUCTION"),
				Science		= GetDistrictBonus(district, "YIELD_SCIENCE")
			}
		};

		local buildingTypes = pCityBuildings:GetBuildingsAtLocation(plotID);
		for _, buildingType in ipairs(buildingTypes) do
			local building		:table = GameInfo.Buildings[buildingType];
			local kYields		:table = {};

			-- Obtain yield info for buildings.
			for yieldRow in GameInfo.Yields() do
				local yieldChange = pCity:GetBuildingYield(buildingType, yieldRow.YieldType);
				if yieldChange ~= 0 then
					table.insert( kYields, {
						YieldType	= yieldRow.YieldType,
						YieldChange	= yieldChange
					});
				end
			end

			-- Helper: to extract a particular yield type
			function YieldFind( kYields:table, yieldType:string )
				for _,yield in ipairs(kYields) do
					if yield.YieldType == yieldType then
						return yield.YieldChange;
					end
				end
				return 0;	-- none found
			end

			-- Duplicate of data but common yields in an easy to parse format.
			local culture	:number = YieldFind( kYields, "YIELD_CULTURE" );
			local faith		:number = YieldFind( kYields, "YIELD_FAITH" );
			local food		:number = YieldFind( kYields, "YIELD_FOOD" );
			local gold		:number = YieldFind( kYields, "YIELD_GOLD" );
			local production:number = YieldFind( kYields, "YIELD_PRODUCTION" );
			local science	:number = YieldFind( kYields, "YIELD_SCIENCE" );

			if building.IsWonder then
				table.insert( data.Wonders, {
					Name				= Locale.Lookup(building.Name), 
					Yields				= kYields,
					Type				= building.BuildingType,
					Icon				= "ICON_"..building.BuildingType,
					isPillaged			= pCityBuildings:IsPillaged(building.BuildingType),
					isBuilt				= pCityBuildings:HasBuilding(building.Index),
					CulturePerTurn		= culture,	
					FaithPerTurn		= faith,		
					FoodPerTurn			= food,		
					GoldPerTurn			= gold,		
					ProductionPerTurn	= production,
					SciencePerTurn		= science
				});
			else			
				-- GCO <<<<<
				if not building.NoCityScreen then
				-- GCO >>>>>
				data.BuildingsNum = data.BuildingsNum + 1;
				table.insert( districtTable.Buildings, { 
					-- GCO <<<<<
					Tooltip				= ToolTipHelper.GetBuildingToolTip( building.Hash, owner, pCity ),
					-- GCO >>>>>
					Name				= Locale.Lookup(building.Name), 
					Type				= building.BuildingType,
					Yields				= kYields,
					Icon				= "ICON_"..building.BuildingType,
					Citizens			= kPlot:GetWorkerCount(),
					isPillaged			= pCityBuildings:IsPillaged(buildingType);
					isBuilt				= pCityBuildings:HasBuilding(building.Index);
					CulturePerTurn		= culture,	
					FaithPerTurn		= faith,		
					FoodPerTurn			= food,		
					GoldPerTurn			= gold,		
					ProductionPerTurn	= production,
					SciencePerTurn		= science							
				});
				-- GCO <<<<<
				end
				-- GCO >>>>>
			end

		end

		-- Add district unless it's the special wonder district; toss that one.
		if districtType ~= "DISTRICT_WONDER" then
			table.insert( data.BuildingsAndDistricts, districtTable );
		end
	end

	local pTrade:table = pCity:GetTrade();
	for iPlayer:number = 0, MapConfiguration.GetMaxMajorPlayers()-1,1 do
		if (pTrade:HasActiveTradingPost(iPlayer)) then
			table.insert( data.TradingPosts, iPlayer );
		end
	end

	-- GCO <<<<<
	GCO.AttachCityFunctions(pCity)
	data.ResourcesStock 	= pCity:GetResourcesStockTable()
	data.ResourcesSupply 	= pCity:GetResourcesSupplyTable()
	data.ResourcesDemand 	= pCity:GetResourcesDemandTable()
	data.ForeignRoutes	 	= pCity:GetExportCitiesTable()
	data.TransferRoutes	 	= pCity:GetTransferCitiesTable()
	data.SupplyLines	 	= pCity:GetSupplyLinesTable()		
	
	local upperClass		= pCity:GetUpperClass()
	local middleClass		= pCity:GetMiddleClass()
	local lowerClass		= pCity:GetLowerClass()
	local slaveClass		= pCity:GetSlaveClass()
	local upperHousingSize	= pCity:GetCustomYield( GameInfo.CustomYields["YIELD_UPPER_HOUSING"].Index )
	local upperHousing		= GCO.GetPopulationPerSize(upperHousingSize)
	local upperHousingAvailable	= math.max( 0, upperHousing - upperClass)
	local upperLookingForMiddle	= math.max( 0, upperClass - upperHousing)
	local middleHousingSize	= pCity:GetCustomYield( GameInfo.CustomYields["YIELD_MIDDLE_HOUSING"].Index )
	local middleHousing		= GCO.GetPopulationPerSize(middleHousingSize)
	local middleHousingAvailable	= math.max( 0, middleHousing - middleClass - upperLookingForMiddle)
	local middleLookingForLower		= math.max( 0, (middleClass + upperLookingForMiddle) - middleHousing)
	local lowerHousingSize	= pCity:GetCustomYield( GameInfo.CustomYields["YIELD_LOWER_HOUSING"].Index )
	local lowerHousing		= GCO.GetPopulationPerSize(lowerHousingSize)
	local lowerHousingAvailable	= math.max( 0, lowerHousing - lowerClass - middleLookingForLower)
	local realPopulation	= pCity:GetRealPopulation()
	
	data.TotalPopulation	= realPopulation
	
	data.UpperHousing		= upperHousing
	data.MiddleHousing		= middleHousing
	data.LowerHousing		= lowerHousing
	
	data.UpperAvailable		= upperHousingAvailable
	data.UpperInMiddle		= upperLookingForMiddle
	data.MiddleAvailable	= middleHousingAvailable
	data.MiddleInLower		= middleLookingForLower
	data.LowerAvailable		= lowerHousingAvailable
	
	data.UpperClass			= upperClass
	data.MiddleClass		= middleClass
	data.LowerClass			= lowerClass
	data.SlaveClass			= slaveClass
	
	local maxPopulation		= upperHousing + middleHousing + lowerHousing + slaveClass -- slave class doesn't use housing space	
	
	--[[
	local housingToolTip	= Locale.Lookup("LOC_HUD_CITY_TOTAL_HOUSING", realPopulation, maxPopulation)
	housingToolTip	= housingToolTip .. Locale.Lookup("LOC_TOOLTIP_SEPARATOR") ..Locale.Lookup("LOC_HUD_CITY_UPPER_HOUSING", upperHousing - upperHousingAvailable, upperHousing)
	if upperClass - upperLookingForMiddle > 0 then
		housingToolTip		= housingToolTip .. "[NEWLINE][ICON_Bullet]" .. Locale.Lookup("LOC_CITYBANNER_UPPER_CLASS", upperClass - upperLookingForMiddle)
	end
	
	housingToolTip	= housingToolTip .. "[NEWLINE]" .. Locale.Lookup("LOC_HUD_CITY_MIDDLE_HOUSING", middleHousing - middleHousingAvailable, middleHousing)
	if upperLookingForMiddle > 0 then
		housingToolTip		= housingToolTip .. "[NEWLINE][ICON_Bullet]" .. Locale.Lookup("LOC_CITYBANNER_UPPER_CLASS", upperLookingForMiddle)
	end
	if middleClass - middleLookingForLower > 0 then
		housingToolTip		= housingToolTip .. "[NEWLINE][ICON_Bullet]" .. Locale.Lookup("LOC_CITYBANNER_MIDDLE_CLASS", middleClass - middleLookingForLower)
	end
	
	housingToolTip	= housingToolTip .. "[NEWLINE]" .. Locale.Lookup("LOC_HUD_CITY_LOWER_HOUSING", lowerHousing - lowerHousingAvailable, lowerHousing)
	if middleLookingForLower > 0 then
		housingToolTip		= housingToolTip .. "[NEWLINE][ICON_Bullet]" .. Locale.Lookup("LOC_CITYBANNER_MIDDLE_CLASS", middleLookingForLower)
	end
	if lowerClass > 0 then
		housingToolTip		= housingToolTip .. "[NEWLINE][ICON_Bullet]" .. Locale.Lookup("LOC_CITYBANNER_LOWER_CLASS", lowerClass)
	end
	--]]
	
	data.HousingToolTip		= pCity:GetHousingToolTip()
	data.HousingText		= Locale.Lookup("LOC_HUD_CITY_HOUSING_OCCUPATION")
	
	data.MaxPopulation		= maxPopulation
	
	local popVariation 		= pCity:GetRealPopulationVariation()
	local citySize 			= pCity:GetSize()
				
	local nextPop		= GCO.GetPopulationPerSize(citySize+1)
	local prevPop		= GCO.GetPopulationPerSize(citySize)
	
	data.GrowthPercent		= Clamp( (realPopulation - prevPop) / (nextPop - prevPop), 0.0, 1.0 )
	data.NextGrowthPercent	= Clamp( ((realPopulation + popVariation) - prevPop) / (nextPop - prevPop), 0.0, 1.0 )
	data.GrowthToolTip			= Locale.Lookup("LOC_HUD_CITY_GROWTH_SIZE", popVariation, nextPop, prevPop)
				
	local popDiff	= 0
	if popVariation >= 0 then
		popDiff = nextPop - realPopulation
	elseif popVariation < 0 then
		popDiff = realPopulation - prevPop
	end
	
	data.PopVariation	= popVariation
	data.PopDifference	= popDiff
	if popVariation > 0 then
		data.PopGrowthStr	= Locale.Lookup("LOC_HUD_CITY_POPULATION_TO_GROWTH")
	elseif popVariation < 0 then		
		data.PopGrowthStr	= Locale.Lookup("LOC_HUD_CITY_POPULATION_TO_REDUCE")
	else		
		data.PopGrowthStr	= Locale.Lookup("LOC_HUD_CITY_POPULATION_TO_GROWTH")
	end
		
	local currentProductionHash = pBuildQueue:GetCurrentProductionTypeHash();

	-- Attempt to obtain a hash for each item
	if currentProductionHash ~= 0 then
		pBuildingDef 	= GameInfo.Buildings[currentProductionHash];
		pDistrictDef 	= GameInfo.Districts[currentProductionHash];
		pUnitDef		= GameInfo.Units[currentProductionHash];
		pProjectDef		= GameInfo.Projects[currentProductionHash];
	end	
	
	local productionTip = ""
	if ( pUnitDef ~= nil ) then
		local bCanTrain, reqStr = pCity:CanTrain(pUnitDef.UnitType)
		productionTip = reqStr
	elseif ( pBuildingDef ~= nil ) then
		local bCanTrain, reqStr = pCity:CanConstruct(pBuildingDef.BuildingType)
		productionTip = reqStr							
	end
	local efficiencyPercent = GCO.ToDecimals(pCity:GetConstructionEfficiency() * 100)
	local realTurnsLeft 	= prodTurnsLeft
	productionTip 			= productionTip .. "[NEWLINE]" .. Locale.Lookup("LOC_CITY_BANNER_PRODUCTION_EFFICIENCY", efficiencyPercent)
	if efficiencyPercent < 100 then
		realTurnsLeft 		= GCO.Round(prodTurnsLeft * 100 / efficiencyPercent)
		data.ProdPercentNextTurn	= (pctNextTurn * 100 / efficiencyPercent)
		if realTurnsLeft > prodTurnsLeft then
			productionTip = productionTip .. "[NEWLINE]" .. Locale.Lookup("LOC_CITY_BANNER_PRODUCTION_TURN_LOST", (realTurnsLeft - prodTurnsLeft))
		end
	end
	
	data.RealProductionTurnsLeft	= realTurnsLeft
	data.ProductionToolTip			= productionTip
	
	-- GCO >>>>>

	return data;
end
