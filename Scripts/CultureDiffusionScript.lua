--=====================================================================================--
--	FILE:	 CultureDiffusionScript.lua
--  Gedemon (2017)
--=====================================================================================--

print ("Loading CultureDiffusionScript.lua...")

-----------------------------------------------------------------------------------------
-- Defines
-----------------------------------------------------------------------------------------

local SEPARATIST = "64" -- use string for table keys for correct serialisation/deserialisation
ExposedMembers.CultureMap = {}
ExposedMembers.PreviousCultureMap = {}

-----------------------------------------------------------------------------------------
-- Initialize Functions
-----------------------------------------------------------------------------------------

local GCO = {}
function InitializeUtilityFunctions() 	-- Get functions from other contexts
	if ExposedMembers.SaveLoad_Initialized and ExposedMembers.Utils_Initialized then
		GCO = ExposedMembers.GCO		-- contains functions from other contexts
		Events.GameCoreEventPublishComplete.Remove( InitializeUtilityFunctions )
		print ("Exposed Functions from other contexts initialized...")
		InitializePlotFunctions()
	end
end
Events.GameCoreEventPublishComplete.Add( InitializeUtilityFunctions )

-----------------------------------------------------------------------------------------
-- Plots Functions
-----------------------------------------------------------------------------------------

function GetKey ( self )
	return tostring(self:GetIndex())
end

-----------------------------------------------------------------------------------------
-- C++ converted Functions
-----------------------------------------------------------------------------------------

local conquestCountdown = {}
function DoConquestCountDown( self )
	local count = conquestCountdown[self.GetPlotKey()]
	if count and count > 0 then
		conquestCountdown[self.GetPlotKey()] = count - 1
	end
end
function GetConquestCountDown( self )
	return conquestCountdown[self.GetPlotKey()] or 0
end
function SetConquestCountDown( self, value )
	conquestCountdown[self.GetPlotKey()] = value
end

function GetCulture( self, playerID )
	local plotCulture = ExposedMembers.CultureMap[self.GetPlotKey()]
	if plotCulture then 
		return plotCulture[self.GetPlotKey()][tostring(playerID)] or 0
	end
	return 0
end
function SetCulture( self, playerID, value )
	local key = self.GetPlotKey()
	if ExposedMembers.CultureMap[key] then 
		ExposedMembers.CultureMap[key][tostring(playerID)] = value
	else
		ExposedMembers.CultureMap[key] = {}
		ExposedMembers.CultureMap[key][tostring(playerID)] = value
	end
end
function ChangeCulture( self, playerID, value )
	local key = self.GetPlotKey()
	if ExposedMembers.CultureMap[key] then 
		ExposedMembers.CultureMap[key][tostring(playerID)] = ExposedMembers.CultureMap[key][tostring(playerID)] + value
	else
		ExposedMembers.CultureMap[key] = {}
		ExposedMembers.CultureMap[key][tostring(playerID)] = value
	end
end

function GetPreviousCulture( self, playerID )
	local plotCulture = ExposedMembers.PreviousCultureMap[self.GetPlotKey()]
	if plotCulture then 
		return plotCulture[self.GetPlotKey()][tostring(playerID)] or 0
	end
	return 0
end
function SetPreviousCulture( self, playerID, value )
	local key = self.GetPlotKey()
	if ExposedMembers.PreviousCultureMap[key] then 
		ExposedMembers.PreviousCultureMap[key][tostring(playerID)] = value
	else
		ExposedMembers.PreviousCultureMap[key] = {}
		ExposedMembers.PreviousCultureMap[key][tostring(playerID)] = value
	end
end

function GetTotalCulture( self )
	local totalCulture = 0
	local plotCulture = ExposedMembers.CultureMap[self:GetKey()]
	if  plotCulture then
		for playerID, value in pairs (plotCulture) do
			totalCulture = totalCulture + value			
		end
	end
	return totalCulture
end
function GetCulturePercent( self )
	-- return a table with civs culture % for a plot in cultureMap and the total culture
	local plotCulturePercent = {}
	local totalCulture = self:GetTotalCulture()
	local plotCulture = ExposedMembers.CultureMap[self:GetKey()]
	if  plotCulture and totalCulture > 0 then
		for playerID, value in pairs (plotCulture) do
			plotCulturePercent[playerID] = (value / totalCulture * 100)
		end
	end
	return plotCulturePercent, totalCulture
end

function GetHighestCulturePlayer( self )
	local topPlayer
	local topValue = 0
	local plotCulture = ExposedMembers.CultureMap[self:GetKey()]
	if  plotCulture then
		for playerID, value in pairs (plotCulture) do
			if value > topValue then
				topValue = value
				topPlayer = playerID
			end
		end
	end
	return topPlayer -- can be nil
end

function GetTotalPreviousCulture( self )
	local totalCulture = 0
	local plotCulture = ExposedMembers.PreviousCultureMap[self:GetKey()]
	if  plotCulture then
		for playerID, value in pairs (plotCulture) do
			totalCulture = totalCulture + value			
		end
	end
	return totalCulture
end

function GetCulturePer10000( self, playerID )
	local totalCulture = GetTotalCulture( self )
	if totalCulture > 0 then
		return GCO.Round(GetCulture( self, playerID ) * 10000 / totalCulture)
	end
	return 0
end
function GetPreviousCulturePer10000( self, playerID )
	local totalCulture = GetTotalPreviousCulture( self )
	if totalCulture > 0 then
		return GCO.Round(GetPreviousCulture( self, playerID ) * 10000 / totalCulture)
	end
	return 0
end

-----------------------------------------------------------------------------------------
-- Initialize Plot Functions
-----------------------------------------------------------------------------------------

function InitializePlotFunctions() -- Note that those functions are limited to this file context
	local p = getmetatable(Map.GetPlot(1,1)).__index
	p.GetKey					= GetKey
	p.GetTotalCulture 			= GetTotalCulture
	p.GetCulturePercent			= GetCulturePercent
	p.DoConquestCountDown 		= DoConquestCountDown
	p.GetConquestCountDown 		= GetConquestCountDown
	p.SetConquestCountDown 		= SetConquestCountDown
	p.GetCulture 				= GetCulture
	p.SetCulture 				= SetCulture
	p.ChangeCulture 			= ChangeCulture
	p.GetPreviousCulture 		= GetPreviousCulture
	p.SetPreviousCulture 		= SetPreviousCulture
	p.GetHighestCulturePlayer 	= GetHighestCulturePlayer
	p.GetTotalPreviousCulture	= GetTotalPreviousCulture
	
end

--[[ C++ code from RED DLL for reference
// RED <<<<<
//	--------------------------------------------------------------------------------
void CvPlot::doConquestCountDown()
{
	if (m_iConquestCountDown > 0)
		m_iConquestCountDown -= 1;
}
//	--------------------------------------------------------------------------------
int CvPlot::getConquestCountDown() const
{
	return m_iConquestCountDown;
}

//	--------------------------------------------------------------------------------
void CvPlot::setConquestCountDown(int iNewValue)
{
	if (m_iConquestCountDown != iNewValue)
		m_iConquestCountDown = iNewValue;
}

//	---------------------------------------------------------------------------
int CvPlot::getCulture(PlayerTypes eIndex) const
{
	return m_aiCulture[eIndex];
}

//	---------------------------------------------------------------------------
void CvPlot::setCulture(PlayerTypes eIndex, int iNewValue)
{
	if (getCulture(eIndex) != iNewValue)
		m_aiCulture[eIndex] = iNewValue;
}

//	---------------------------------------------------------------------------
void CvPlot::changeCulture(PlayerTypes eIndex, int iChange)
{
	setCulture(eIndex, (getCulture(eIndex) + iChange));
}

//	---------------------------------------------------------------------------
int CvPlot::getPreviousCulture(PlayerTypes eIndex) const
{
	return m_aiPreviousCulture[eIndex];
}

//	---------------------------------------------------------------------------
void CvPlot::setPreviousCulture(PlayerTypes eIndex, int iNewValue)
{
	if (getPreviousCulture(eIndex) != iNewValue)
		m_aiPreviousCulture[eIndex] = iNewValue;
}

//	---------------------------------------------------------------------------
int CvPlot::getCulturePercent(PlayerTypes eIndex) const
{
	int iTotalCulture = getTotalCulture();

	if (iTotalCulture > 0)
	{
		return ((getCulture(eIndex) * 100) / iTotalCulture);
	}

	return 0;
}

//	---------------------------------------------------------------------------
int CvPlot::getTotalCulture() const
{
	int iTotalCulture;

	iTotalCulture = 0;

	for (int iI = 0; iI < REALLY_MAX_PLAYERS; iI++) // to include "fake" players (like separatists faction for Revolutions)
	{
		iTotalCulture += getCulture((PlayerTypes)iI);
	}

	return iTotalCulture;
}

//	---------------------------------------------------------------------------
PlayerTypes CvPlot::getHighestCulturePlayer() const
{
	PlayerTypes eBestPlayer = NO_PLAYER;
	int iHighestculture = 0;

	for (int iI = 0; iI < MAX_PLAYERS; iI++) // only "real" players
	{
		if (getCulture((PlayerTypes)iI) > iHighestculture && GET_PLAYER((PlayerTypes)iI).isEverAlive())
		{
			eBestPlayer = (PlayerTypes)iI;
			iHighestculture = getCulture((PlayerTypes)iI);
		}
	}

	return eBestPlayer;
}

//	---------------------------------------------------------------------------
int CvPlot::getTotalPreviousCulture() const
{
	int iTotalCulture;

	iTotalCulture = 0;

	for (int iI = 0; iI < REALLY_MAX_PLAYERS; iI++) // to include "fake" players (like separatists faction for Revolutions)
	{
		iTotalCulture += getPreviousCulture((PlayerTypes)iI);
	}

	return iTotalCulture;
}

//	---------------------------------------------------------------------------
int CvPlot::getCulturePer10000(PlayerTypes eIndex) const
{
	int iTotalCulture = getTotalCulture();

	if (iTotalCulture > 0)
	{
		return ((getCulture(eIndex) * 10000) / iTotalCulture);
	}

	return 0;
}

//	---------------------------------------------------------------------------
int CvPlot::getPreviousCulturePer10000(PlayerTypes eIndex) const
{
	int iTotalCulture = getTotalPreviousCulture();

	if (iTotalCulture > 0)
	{
		return ((getPreviousCulture(eIndex) * 10000) / iTotalCulture);
	}

	return 0;
}

//	---------------------------------------------------------------------------
bool CvPlot::isLockedByWarForPlayer(PlayerTypes eIndex) const
{
	bool bLocked = false;
	if (GC.getCULTURE_LOCK_FLIPPING_ON_WAR() > 0 && getOwner() != NO_PLAYER && GET_TEAM(GET_PLAYER(eIndex).getTeam()).isAtWar(GET_PLAYER(getOwner()).getTeam()))
		bLocked = true;
	return bLocked;
}

//	---------------------------------------------------------------------------
bool CvPlot::isLockedByFortification() const
{
	if (GC.getCULTURE_NO_FORTIFICATION_FLIPPING() > 0) 
	{
		ImprovementTypes eImprovement;

		// Check for Forts, Kasbah, Feitoria, Chateau...
		eImprovement = getImprovementType();
		if (eImprovement != NO_IMPROVEMENT && !IsImprovementPillaged())
		{
			if (GC.getImprovementInfo(eImprovement)->GetDefenseModifier() > 0)
				return true;
		}
	}
	return false;
}

//	---------------------------------------------------------------------------
bool CvPlot::isLockedByCitadelForPlayer(PlayerTypes eIndex) const
{
	if (GC.getCULTURE_NO_FORTIFICATION_FLIPPING() > 0) 
	{
		CvPlot* pAdjacentPlot;
		ImprovementTypes eImprovement;

		for(int iI = 0; iI < NUM_DIRECTION_TYPES; ++iI)
		{
			pAdjacentPlot = plotDirection(getX(), getY(), ((DirectionTypes)iI));

			if(pAdjacentPlot != NULL)
			{
				if (pAdjacentPlot->isWater()) // no need to check water plots
					continue;
					
				if (pAdjacentPlot->getOwner() == eIndex ) // a citadel owner is allowed to acquire adjacent plot using culture
					continue;

				eImprovement = pAdjacentPlot->getImprovementType();
				/*
				if (eImprovement == (ImprovementTypes)GC.getInfoTypeForString("IMPROVEMENT_CITADEL") && !pAdjacentPlot->IsImprovementPillaged())
					return;
				*/
				// less explicit, but faster ? (and not hardcoded...)
				if (eImprovement != NO_IMPROVEMENT && !pAdjacentPlot->IsImprovementPillaged())
				{
					if (GC.getImprovementInfo(eImprovement)->GetNearbyEnemyDamage() > 0)
						return true;
				}
				//*/
			}
		}
	}
	return false;
}


//	---------------------------------------------------------------------------
PlayerTypes CvPlot::getPotentialOwner() const
{
	PlayerTypes eBestPlayer = NO_PLAYER;
	int iBestValue = 0;

	for (int iI = 0; iI < MAX_PLAYERS; iI++) // only "real" players
	{
		if (GET_PLAYER((PlayerTypes)iI).isAlive())
		{
			if (getCulture((PlayerTypes)iI) > iBestValue)
			{
				// Do we allow non-adjacent flipping ?
				if (!isAdjacentPlayer((PlayerTypes)iI, /*LandOnly*/ true) && GC.getCULTURE_FLIPPING_ONLY_ADJACENT() > 0)
					continue;

				iBestValue = getCulture((PlayerTypes)iI);
				eBestPlayer = (PlayerTypes)iI;
			}
		}
	}
	return eBestPlayer;
}

//	---------------------------------------------------------------------------
void CvPlot::updateCulture()
{
	// Logging
	CvString redLogMessage;
	CvString strBuffer;
	CvString strTemp;
	bool bChangeToLog = false;
	FILogFile* pLog = LOGFILEMGR.GetLog("red_update_culture_debug.log", FILogFile::kDontTimeStamp);

	redLogMessage += "---------------------------------------------------------------------------\n";
	strTemp.Format("CvPlot::updateCulture() at (%d,%d) on turn %d", getX(), getY(), GC.getGame().getElapsedGameTurns());
	redLogMessage += strTemp;

	// No culture diffusion on water...
	if (isWater())
		return;	

	// Decay
	// to do: scale by territory (friendly, neutral, foreign, enemy)
	for (int iI = 0; iI < REALLY_MAX_PLAYERS; iI++) // including "fake" players
	{
		// Before any change are made, save the actual culture value for variation display...
		int iCultureValue = getCulture((PlayerTypes)iI);
		setPreviousCulture((PlayerTypes)iI, iCultureValue);

		// apply decay
		if (iCultureValue > 0)
		{
			redLogMessage += "\n\n- Decay applied";
			strTemp.Format("\n	PlayerID= %d, CultureValue = %d, Total Culture = %d, CULTURE_DECAY_RATE = %d ", iI, iCultureValue, getTotalCulture(), GC.getCULTURE_DECAY_RATE());
			redLogMessage += strTemp;
			bChangeToLog =true;

			int iDecay = (iCultureValue * GC.getCULTURE_DECAY_RATE()/100) + 1;
						
			strTemp.Format("\n	iDecay = (iCultureValue * GC.getCULTURE_DECAY_RATE()/100) + 1 = %d ", iDecay);
			redLogMessage += strTemp;

			if (iCultureValue - iDecay <= 0)
			{
				if (getOwner() == (PlayerTypes)iI)
					setCulture((PlayerTypes)iI, GC.getCULTURE_MINIMAL_ON_OWNED_PLOT());
				else
					setCulture((PlayerTypes)iI, 0);
			} 
			else
			{
				changeCulture((PlayerTypes)iI, -iDecay);
			}
		}
	}

	// Diffuse Culture on adjacent plots
	if (getTotalCulture() > GC.getCULTURE_DIFFUSION_THRESHOLD())
	{
		redLogMessage += "\n\n- calling diffuseCulture()";
		bChangeToLog =true;
		diffuseCulture();
	}

	// Update Culture in cities
	if (isCity())
	{
		CvCity* pCity = getPlotCity();
		
		// Culture Creation
		// to do: remove hardcoding, create a column "UniversalCulture" in Policies (and Buildings and units ?) and related function to get bHasLibertyPolicy
		float fCultureAdded;
		bool bHasLibertyPolicy = (GC.getCULTURE_USE_POLICIES() > 0 && GET_PLAYER(getOwner()).GetPlayerPolicies()->HasPolicy((PolicyTypes)GC.getInfoTypeForString("POLICY_LIBERTY")));
		int iMaxCulture = (pCity->getPopulation() + pCity->getJONSCulturePerTurn()) * GC.getCULTURE_CITY_CAPED_FACTOR();

		redLogMessage += "\n\n- Updating culture in City";
		strTemp.Format("\n	City %s, MaxCulture = %d = (Population = %d + CulturePerTurn = %d) * CULTURE_CITY_CAPED_FACTOR = %d", pCity->getNameKey(), iMaxCulture, pCity->getPopulation(), pCity->getJONSCulturePerTurn(), GC.getCULTURE_CITY_CAPED_FACTOR());
		redLogMessage += strTemp;
		if (bHasLibertyPolicy)
			redLogMessage += " (owner has Liberty Policy)";
		bChangeToLog =true;

		if (getTotalCulture() < iMaxCulture) // if this is false, then decay will remove excedental culture next turn...
		{
			for (int iI = 0; iI < MAX_PLAYERS; iI++) // only "real" players
			{
				if (getCulture((PlayerTypes)iI) > 0)
				{
					strTemp.Format("\n		Player (ID= %d) has Culture here (value = %d)", iI, getCulture((PlayerTypes)iI));
					redLogMessage += strTemp;

					if (getOwner() == (PlayerTypes)iI || bHasLibertyPolicy) // city owner OR city owner has Liberty policy
					{
						if (GC.getCULTURE_OUTPUT_USE_LOG() > 1)
							fCultureAdded = ((pCity->getPopulation() + pCity->getJONSCulturePerTurn()) * log10((float)(getCulture((PlayerTypes)iI) * GC.getCULTURE_CITY_FACTOR())));
						else
							fCultureAdded = ((pCity->getPopulation() + pCity->getJONSCulturePerTurn()) * sqrt((float)(getCulture((PlayerTypes)iI) * GC.getCULTURE_CITY_RATIO()/100)));
					}
					else // without the liberty policy, foreign culture does not benefit from city cultural output
					{
						if (GC.getCULTURE_OUTPUT_USE_LOG() > 1)
							fCultureAdded = pCity->getPopulation() * log10((float)(getCulture((PlayerTypes)iI) * GC.getCULTURE_CITY_FACTOR()));
						else
							fCultureAdded = pCity->getPopulation() * sqrt((float)(getCulture((PlayerTypes)iI) * GC.getCULTURE_CITY_RATIO()/100));
					}
					fCultureAdded += GC.getCULTURE_CITY_BASE_PRODUCTION();
					changeCulture((PlayerTypes)iI, (int)fCultureAdded);

					strTemp.Format("\n			Added Culture = %d (CULTURE_CITY_BASE_PRODUCTION = %d)", (int)fCultureAdded, GC.getCULTURE_CITY_BASE_PRODUCTION());
					redLogMessage += strTemp;
				}
				else if (getOwner() == (PlayerTypes)iI)
				{					
					changeCulture(getOwner(), GC.getCULTURE_CITY_BASE_PRODUCTION());

					strTemp.Format("\n			Added CULTURE_CITY_BASE_PRODUCTION = %d", GC.getCULTURE_CITY_BASE_PRODUCTION());
					redLogMessage += strTemp;
				}
			}
		}

		// Culture Conversion in cities
		int iCultureConversionRatePer10000 = GC.getCULTURE_CITY_CONVERSION_RATE();		
		
		redLogMessage += "\n\n- Converting culture in City";
		strTemp.Format("\n	iCultureConversionRatePer10000 = %d, CULTURE_USE_POLICIES = %d", iCultureConversionRatePer10000, GC.getCULTURE_USE_POLICIES());
		redLogMessage += strTemp;

		// to do: remove hardcoding, create a column "CultureConversionRate" in Buildings and Policies (and units ?) and related functions to get values
		if (GC.getCULTURE_USE_POLICIES() > 0)
		{
			if (GET_PLAYER(getOwner()).GetPlayerPolicies()->HasPolicy((PolicyTypes)GC.getInfoTypeForString("POLICY_TRADITION")))
				iCultureConversionRatePer10000+= GC.getCULTURE_TRADITION_OPENER_CONVERSION_RATE();
			
			if (GET_PLAYER(getOwner()).GetPlayerPolicies()->HasPolicy((PolicyTypes)GC.getInfoTypeForString("POLICY_TRADITION_FINISHER")))
				iCultureConversionRatePer10000+= GC.getCULTURE_TRADITION_FINISHER_CONVERSION_RATE();
			
			if (GET_PLAYER(getOwner()).GetPlayerPolicies()->HasPolicy((PolicyTypes)GC.getInfoTypeForString("POLICY_SOCIALIST_REALISM")))
				iCultureConversionRatePer10000+= GC.getCULTURE_SOCIALIST_REALISM_CONVERSION_RATE();
			
			if (GET_PLAYER(getOwner()).GetPlayerPolicies()->HasPolicy((PolicyTypes)GC.getInfoTypeForString("POLICY_MEDIA_CULTURE")))
				iCultureConversionRatePer10000+= GC.getCULTURE_MEDIA_CULTURE_CONVERSION_RATE();
			
			if (GET_PLAYER(getOwner()).GetPlayerPolicies()->HasPolicy((PolicyTypes)GC.getInfoTypeForString("POLICY_NATIONALISM")))
				iCultureConversionRatePer10000+= GC.getCULTURE_NATIONALISM_CONVERSION_RATE();
		}

		if (pCity->GetCityBuildings()->GetNumBuilding((BuildingTypes)GC.getInfoTypeForString("BUILDING_LIBRARY")))
			iCultureConversionRatePer10000+= GC.getCULTURE_LIBRARY_CONVERSION_RATE();
		
		if (pCity->GetCityBuildings()->GetNumBuilding((BuildingTypes)GC.getInfoTypeForString("BUILDING_UNIVERSITY")))
			iCultureConversionRatePer10000+= GC.getCULTURE_UNIVERSITY_CONVERSION_RATE();
		
		if (pCity->GetCityBuildings()->GetNumBuilding((BuildingTypes)GC.getInfoTypeForString("BUILDING_PUBLIC_SCHOOL")))
			iCultureConversionRatePer10000+= GC.getCULTURE_PUBLIC_SCHOOL_CONVERSION_RATE();

		if (iCultureConversionRatePer10000 > 0)
		{
			for (int iI = 0; iI < REALLY_MAX_PLAYERS; iI++) // including "fake" players
			{
				if ((PlayerTypes)iI != getOwner() && (PlayerTypes)iI != SEPARATIST_PLAYER) // but separatists are not affected by foreign culture groups conversion
				{
					int iConverted = getCulture((PlayerTypes)iI) * iCultureConversionRatePer10000 / 10000;
					changeCulture((PlayerTypes)iI, - iConverted); // value near 0 are handled in decay function
					changeCulture(getOwner(), iConverted);
					if (iConverted > 0)
					{
						bChangeToLog =true;
						strTemp.Format("\n		Player (ID= %d) lost %d of his %d culture converted (ratePer10000 = %d) to Player (ID= %d)", iI, iConverted, getCulture((PlayerTypes)iI), iCultureConversionRatePer10000, getOwner());
						redLogMessage += strTemp;
					}
				}
			}
		}
	}

	// Check for culture conversion from improvements
	if (GC.getCULTURE_IMPROVEMENT_CONVERSION_RATE() > 0) 
	{
		ImprovementTypes eImprovement = getImprovementType();

		if (eImprovement != NO_IMPROVEMENT && !IsImprovementPillaged())
		{
			int iCultureYield = GC.getImprovementInfo(eImprovement)->GetYieldChange(YIELD_CULTURE);

			if (iCultureYield > 0)
			{
				redLogMessage += "\n\n- Converting culture on Improvement";
				strTemp.Format("\n	iCultureYield = %d, CULTURE_IMPROVEMENT_CONVERSION_RATE = %d", iCultureYield, GC.getCULTURE_IMPROVEMENT_CONVERSION_RATE());
				redLogMessage += strTemp;
				for (int iI = 0; iI < REALLY_MAX_PLAYERS; iI++) // including "fake" players
				{
					if ((PlayerTypes)iI != getOwner() && (PlayerTypes)iI != SEPARATIST_PLAYER) // but separatists are not affected by foreign culture groups conversion
					{
						int iConverted = getCulture((PlayerTypes)iI) * GC.getCULTURE_IMPROVEMENT_CONVERSION_RATE() * iCultureYield / 10000;
						if (iConverted > 0)
						{
							bChangeToLog =true;
							strTemp.Format("\n		Player (ID= %d) lost %d of his %d culture converted to Player (ID= %d)", iI, iConverted, getCulture((PlayerTypes)iI), getOwner());
							redLogMessage += strTemp;

							changeCulture((PlayerTypes)iI, - iConverted); // value near 0 are handled in decay function
							changeCulture(getOwner(), iConverted);
						}
					}
				}
			}
		}
	}

	// Check for culture conversion/removal from units
	if (GC.getCULTURE_UNIT_CONVERSION_RATE() > 0)
	{
		const IDInfo* pUnitNode;
		const UnitHandle pLoopUnit;
		const UnitHandle pBestUnit;

		pUnitNode = headUnitNode();

		while(pUnitNode != NULL)
		{
			pLoopUnit = GetPlayerUnit(*pUnitNode);
			pUnitNode = nextUnitNode(pUnitNode);
			if(pLoopUnit)
			{
				// great writers convert to their culture
				if (pLoopUnit->getUnitInfo().GetBaseCultureTurnsToCount() > 0)
				{					
					redLogMessage += "\n\n- Converting culture from Great Writer";
					strTemp.Format("\n	CultureTurnsToCount = %d, CULTURE_UNIT_CONVERSION_RATE = %d per 10,000", pLoopUnit->getUnitInfo().GetBaseCultureTurnsToCount(), GC.getCULTURE_UNIT_CONVERSION_RATE());
					redLogMessage += strTemp;

					int iUnitConversionFactor = /*8*/ pLoopUnit->getUnitInfo().GetBaseCultureTurnsToCount();
					for (int iI = 0; iI < REALLY_MAX_PLAYERS; iI++) // including "fake" players
					{
						if ((PlayerTypes)iI != pLoopUnit->getOwner() && (PlayerTypes)iI != SEPARATIST_PLAYER) // but separatists are not affected by foreign culture groups conversion
						{
							int iConverted = getCulture((PlayerTypes)iI) * GC.getCULTURE_UNIT_CONVERSION_RATE() * iUnitConversionFactor / 10000;
							if (iConverted > 0)
							{
								bChangeToLog =true;
								strTemp.Format("\n		Player (ID= %d) lost %d of his %d culture converted to Player (ID= %d)", iI, iConverted, getCulture((PlayerTypes)iI), getOwner());
								redLogMessage += strTemp;

								changeCulture((PlayerTypes)iI, - iConverted); // value near 0 are handled in decay function
								changeCulture(pLoopUnit->getOwner(), iConverted);
							}
						}
					}
				}

				// inquisitors remove heretiques
				if (pLoopUnit->getUnitInfo().IsRemoveHeresy())
				{					
					redLogMessage += "\n\n- Removing heretics culture by Inquisitor";
					strTemp.Format("\n	ReligiousStrength*2 = %d, CULTURE_UNIT_CONVERSION_RATE = %d per 10,000", pLoopUnit->getUnitInfo().GetReligiousStrength()*2, GC.getCULTURE_UNIT_CONVERSION_RATE());
					redLogMessage += strTemp;

					for (int iI = 0; iI < MAX_PLAYERS; iI++) // only "real" players
					{
						if ((PlayerTypes)iI != pLoopUnit->getOwner())
						{
							// check if that Player is following the right path for this Inquisitor, else...
							if (!GET_PLAYER((PlayerTypes)iI).GetReligions()->HasReligionInMostCities(pLoopUnit->GetReligionData()->GetReligion()))
							{		
								// ... pyres, pyres everywhere !
								int iBurned = getCulture((PlayerTypes)iI) * GC.getCULTURE_UNIT_CONVERSION_RATE() * /*1250x2/1000=2.5*/ pLoopUnit->getUnitInfo().GetReligiousStrength()*2/1000 / 10000;
								if (iBurned > 0)
								{
									bChangeToLog =true;
									strTemp.Format("\n		Player (ID= %d) lost %d of his %d culture removed by Inquisitor of Player (ID= %d)", iI, iBurned, getCulture((PlayerTypes)iI), getOwner());
									redLogMessage += strTemp;

									changeCulture((PlayerTypes)iI, - iBurned); // value near 0 are handled in decay function
								}
							}
						}
					}
				}
			}
		}
	}

	// Update ownership
	if (GC.getCULTURE_ALLOW_TILE_ACQUISITION() > 0 || GC.getCULTURE_ALLOW_TILE_FLIPPING() > 0 )
		updateOwnership();

	// Update locked plot
	if (GC.getCULTURE_CONQUEST_ENABLED() > 0 )
		doConquestCountDown();

	if (bChangeToLog)
		pLog->Msg(redLogMessage);
}

//	--------------------------------------------------------------------------------
void CvPlot::updateOwnership()
{
	// cities do not flip without Revolutions...
	if (isCity()) 
		return;

	// if plot is locked, don't try to change ownership...
	if (getConquestCountDown() > 0) 
		return;
		
	// check if fortifications are preventing tile flipping...
	if (isLockedByFortification())
		return;

	// Get potential owner
	PlayerTypes eBestPlayer = getPotentialOwner();
	if (eBestPlayer == NO_PLAYER)
		return;

	int iBestValue = getCulture(eBestPlayer);

	if (eBestPlayer != NO_PLAYER && eBestPlayer != getOwner() && iBestValue >= GET_PLAYER(eBestPlayer).getCultureMinimumForAcquisition()) // we have a potential new owner // GC.getCULTURE_MINIMUM_FOR_ACQUISITION()
	{
		// Do we allow tile flipping when at war ?		
		if (isLockedByWarForPlayer(eBestPlayer))
			return;

		// check if a citadel can prevent tile flipping...
		if (isLockedByCitadelForPlayer(eBestPlayer))
			return;

		// case 1: the tile was not owned and tile acquisition is allowed
		bool bAcquireNewPlot = (getOwner() == NO_PLAYER && GC.getCULTURE_ALLOW_TILE_ACQUISITION() > 0);

		// case 2: tile flipping is allowed and the ratio between the old and the new owner is high enough
		bool bConvertPlot = (GC.getCULTURE_ALLOW_TILE_FLIPPING() && (iBestValue*GC.getCULTURE_FLIPPING_RATIO()/100) > getCulture(getOwner()));

		if (bAcquireNewPlot || bConvertPlot)
		{
			CvCity* pNearestCity = GC.getMap().findCity(getX(), getY(), eBestPlayer, NO_TEAM, /*bSameArea*/ false); // Natural Wonders are not in the same area on a Continent ?
			if (pNearestCity == NULL)
				return;

			int iDistance = plotDistance(getX(), getY(), pNearestCity->getX(), pNearestCity->getY());

			// Is the plot too far away ?
			if (GET_PLAYER(eBestPlayer).getCultureFlippingMaxDistance() > 0 && iDistance >  GET_PLAYER(eBestPlayer).getCultureFlippingMaxDistance()) // GC.getCULTURE_FLIPPING_MAX_DISTANCE()
				return;

			// All test passed succesfully, notify the players and change owner...
			if (bAcquireNewPlot)
			{				
				Localization::String strMessage = Localization::Lookup("TXT_KEY_NOTIFICATION_ACQUIRE_NEW_PLOT");
				strMessage << pNearestCity->getNameKey();
				Localization::String strSummary = Localization::Lookup("TXT_KEY_NOTIFICATION_SUMMARY_ACQUIRE_NEW_PLOT");
				if (eBestPlayer < MAX_MAJOR_CIVS) 
					GET_PLAYER(eBestPlayer).GetNotifications()->Add(NOTIFICATION_CITY_TILE, strMessage.toUTF8(), strSummary.toUTF8(), getX(), getY(), -1);
			}
			else
			{
				Localization::String strMessageAcquire = Localization::Lookup("TXT_KEY_NOTIFICATION_ACQUIRE_PLOT");
				strMessageAcquire << GET_PLAYER(getOwner()).getNameKey();
				strMessageAcquire << pNearestCity->getNameKey();
				Localization::String strSummaryAcquire = Localization::Lookup("TXT_KEY_NOTIFICATION_SUMMARY_ACQUIRE_PLOT");
				if (eBestPlayer < MAX_MAJOR_CIVS) 
					GET_PLAYER(eBestPlayer).GetNotifications()->Add(NOTIFICATION_CITY_TILE, strMessageAcquire.toUTF8(), strSummaryAcquire.toUTF8(), getX(), getY(), -1);
				
				Localization::String strMessageLost = Localization::Lookup("TXT_KEY_NOTIFICATION_LOST_PLOT");
				strMessageLost << GET_PLAYER(eBestPlayer).getNameKey();
				strMessageLost << pNearestCity->getNameKey();
				Localization::String strSummaryLost = Localization::Lookup("TXT_KEY_NOTIFICATION_SUMMARY_LOST_PLOT");				
				if (getOwner() < MAX_MAJOR_CIVS) 
					GET_PLAYER(getOwner()).GetNotifications()->Add(NOTIFICATION_CITY_TILE, strMessageLost.toUTF8(), strSummaryLost.toUTF8(), getX(), getY(), -1);
			}
			
			setOwner(eBestPlayer, pNearestCity->GetID(), /*bCheckUnits*/ true);

		}
	}
}

//	--------------------------------------------------------------------------------
void CvPlot::diffuseCulture()
{
	CvPlot* pAdjacentPlot;

	for(int iI = 0; iI < NUM_DIRECTION_TYPES; ++iI)
	{
		pAdjacentPlot = plotDirection(getX(), getY(), ((DirectionTypes)iI));

		if(pAdjacentPlot != NULL && !pAdjacentPlot->isWater())
		{
			int iBonus = 0;
			int iMalus = 0;
			int iDiffusionRatePer1000 = GC.getGame().getCultureDiffusionRatePer1000();
			int iCultureValue =  getTotalCulture();
			int iBaseThreshold = GC.getCULTURE_DIFFUSION_THRESHOLD();
			int iPlotMax = iCultureValue * GC.getCULTURE_NORMAL_MAX_PERCENT() / 100;

			// Logging
			CvString redLogMessage;
			CvString strBuffer;
			CvString strTemp;
			FILogFile* pLog = LOGFILEMGR.GetLog("red_diffuse_culture_debug.log", FILogFile::kDontTimeStamp);

			redLogMessage += "---------------------------------------------------------------------------\n";
			strTemp.Format("Culture diffusion from (%d,%d) to (%d,%d) on turn %d)", getX(), getY(), pAdjacentPlot->getX(), pAdjacentPlot->getY(), GC.getGame().getElapsedGameTurns());
			redLogMessage += strTemp;
			strTemp.Format("\n	iBonus = %d, iMalus = %d, iDiffusionRatePer1000 = %d, iCultureValue = %d, iBaseThreshold= %d, iPlotMax = %d)", iBonus, iMalus, iDiffusionRatePer1000, iCultureValue, iBaseThreshold, iPlotMax);
			redLogMessage += strTemp;

			bool bIsRoute = (isRoute() && pAdjacentPlot->isRoute());

			// Bonus: following road
			if (bIsRoute)
			{
				iBonus += GC.getCULTURE_FOLLOW_ROAD_BONUS();
				iPlotMax = iPlotMax * GC.getCULTURE_FOLLOW_ROAD_MAX() / 100;
			}

			// Bonus: following a river
			if (isRiverConnection((DirectionTypes)iI) && !isRiverCrossing((DirectionTypes)iI))
			{				
				iBonus += GC.getCULTURE_FOLLOW_RIVER_BONUS();
				iPlotMax = iPlotMax * GC.getCULTURE_FOLLOW_RIVER_MAX() / 100;
			}

			// Malus: crossing forest
			if (pAdjacentPlot->getFeatureType() == FEATURE_FOREST)
			{
				if (iCultureValue > GC.getCULTURE_CROSS_FOREST_THRESHOLD() * iBaseThreshold / 100)
				{
					iMalus += GC.getCULTURE_CROSS_FOREST_PENALTY();
					iPlotMax = iPlotMax * GC.getCULTURE_CROSS_FOREST_MAX() / 100;
				}
				else
				{
					continue; // skip to next adjacent plot, culture won't diffuse to that plot whatever the results of the following tests...
				}
			}

			// Malus: crossing hills
			if (pAdjacentPlot->getPlotType() == PLOT_HILLS)
			{
				if (iCultureValue > GC.getCULTURE_CROSS_HILLS_THRESHOLD() * iBaseThreshold / 100)
				{
					iMalus += GC.getCULTURE_CROSS_HILLS_PENALTY();
					iPlotMax = iPlotMax * GC.getCULTURE_CROSS_HILLS_MAX() / 100;
				}
				else
				{
					continue; // skip to next adjacent plot
				}
			}

			// Malus: crossing tundra
			if (pAdjacentPlot->getTerrainType() == TERRAIN_TUNDRA)
			{
				if (iCultureValue > GC.getCULTURE_CROSS_TUNDRA_THRESHOLD() * iBaseThreshold / 100)
				{
					iMalus += GC.getCULTURE_CROSS_TUNDRA_PENALTY();
					iPlotMax = iPlotMax * GC.getCULTURE_CROSS_TUNDRA_MAX() / 100;
				}
				else
				{
					continue; // skip to next adjacent plot
				}
			}

			// Malus : crossing a river
			if (isRiverCrossing((DirectionTypes)iI))
			{
				bool bIsBridge = false;
				if (getOwner() != NO_PLAYER)
				{
					TeamTypes ePlotTeam = GET_PLAYER(getOwner()).getTeam();
					CvTeam& kPlotTeam = GET_TEAM(ePlotTeam);
					bIsBridge = (kPlotTeam.isBridgeBuilding() && bIsRoute);
				}
				if (!bIsBridge) // add penalty only if there is no bridge here...
				{
					if (iCultureValue > GC.getCULTURE_CROSS_RIVER_THRESHOLD() * iBaseThreshold / 100)
					{
						iMalus += GC.getCULTURE_CROSS_RIVER_PENALTY();
						iPlotMax = iPlotMax * GC.getCULTURE_CROSS_RIVER_MAX() / 100;
					}
					else
					{
						continue; // skip to next adjacent plot
					}

				}
			}

			// Malus: crossing desert
			if (pAdjacentPlot->getTerrainType() == TERRAIN_DESERT)
			{
				if (iCultureValue > GC.getCULTURE_CROSS_DESERT_THRESHOLD() * iBaseThreshold / 100)
				{
					iMalus += GC.getCULTURE_CROSS_DESERT_PENALTY();
					iPlotMax = iPlotMax * GC.getCULTURE_CROSS_DESERT_MAX() / 100;
				}
				else
				{
					continue; // skip to next adjacent plot
				}
			}

			// Malus: crossing snow
			if (pAdjacentPlot->getTerrainType() == TERRAIN_SNOW)
			{
				if (iCultureValue > GC.getCULTURE_CROSS_SNOW_THRESHOLD() * iBaseThreshold / 100)
				{
					iMalus += GC.getCULTURE_CROSS_SNOW_PENALTY();
					iPlotMax = iPlotMax * GC.getCULTURE_CROSS_SNOW_MAX() / 100;
				}
				else
				{
					continue; // skip to next adjacent plot
				}
			}

			// Malus: crossing jungle
			if (pAdjacentPlot->getFeatureType() == FEATURE_JUNGLE)
			{
				if (iCultureValue > GC.getCULTURE_CROSS_JUNGLE_THRESHOLD() * iBaseThreshold / 100)
				{
					iMalus += GC.getCULTURE_CROSS_JUNGLE_PENALTY();
					iPlotMax = iPlotMax * GC.getCULTURE_CROSS_JUNGLE_MAX() / 100;
				}
				else
				{
					continue; // skip to next adjacent plot
				}
			}

			// Malus: crossing marsh
			if (pAdjacentPlot->getFeatureType() == FEATURE_MARSH)
			{
				if (iCultureValue > GC.getCULTURE_CROSS_MARSH_THRESHOLD() * iBaseThreshold / 100)
				{
					iMalus += GC.getCULTURE_CROSS_MARSH_PENALTY();
					iPlotMax = iPlotMax * GC.getCULTURE_CROSS_MARSH_MAX() / 100;
				}
				else
				{
					continue; // skip to next adjacent plot
				}
			}

			// Malus: escalading mountain
			if (pAdjacentPlot->isMountain())
			{
				if (iCultureValue > GC.getCULTURE_CROSS_MOUNTAIN_THRESHOLD() * iBaseThreshold / 100)
				{
					iMalus += GC.getCULTURE_CROSS_MOUNTAIN_PENALTY();
					iPlotMax = iPlotMax * GC.getCULTURE_CROSS_MOUNTAIN_MAX() / 100;
				}
				else
				{
					continue; // skip to next adjacent plot
				}
			}

			iPlotMax = min(iPlotMax, iCultureValue * GC.getCULTURE_ABSOLUTE_MAX_PERCENT() / 100);

			strTemp.Format("\n		Final values: iBonus = %d, iMalus = %d, iPlotMax = %d)", iBonus, iMalus, iPlotMax);
			redLogMessage += strTemp;
			
			// Apply Culture diffusion to all culture groups
			for (int iJ = 0; iJ < MAX_PLAYERS; iJ++) // only "real" players
			{
				int iPlayerPlotMax = iPlotMax * getCulturePercent((PlayerTypes)iJ) / 100;
				int iPlayerDiffusedCulture = (getCulture((PlayerTypes)iJ) * (iDiffusionRatePer1000 + (iDiffusionRatePer1000 * iBonus / 100))) / (1000 + (1000 * iMalus / 100)); // the parenthesis order is important here, yep, still learning simple operations and truncations...
				
				int iPreviousCulture = pAdjacentPlot->getCulture((PlayerTypes)iJ);
				int iNextculture = min(iPlayerPlotMax, iPreviousCulture + iPlayerDiffusedCulture);

				iPlayerDiffusedCulture = iNextculture - iPreviousCulture;

				if (iPlayerDiffusedCulture > 0) // can be < 0 when a plot try to diffuse to another with a culture value already > at the calculated iPlayerPlotMax...
				{
					strTemp.Format("\n				Diffusion for Player (ID = %d) with %d culture: iPlayerDiffusedCulture = %d, iPreviousCulture = %d, iNextculture = %d, iPlayerPlotMax = %d)", iJ, getCulture((PlayerTypes)iJ), iPlayerDiffusedCulture, iPreviousCulture, iNextculture, iPlayerPlotMax);
					redLogMessage += strTemp;

					pAdjacentPlot->changeCulture((PlayerTypes)iJ, iPlayerDiffusedCulture);
				}
			}
			
			pLog->Msg(redLogMessage);
		}
	}
	
}

// RED >>>>>
--]]