--=====================================================================================--
--	FILE:	 GCOUtils.lua
--  Gedemon (2017)
--=====================================================================================--

print ("Loading GCOUtils.lua...")

-----------------------------------------------------------------------------------------
-- Defines
-----------------------------------------------------------------------------------------


-----------------------------------------------------------------------------------------
-- Maths
-----------------------------------------------------------------------------------------
function Round(num)
    under = math.floor(num)
    upper = math.floor(num) + 1
    underV = -(under - num)
    upperV = upper - num
    if (upperV > underV) then
        return under
    else
        return upper
    end
end

function Shuffle(t)
  local n = #t
 
  while n >= 2 do
    -- n is now the last pertinent index
    local k = math.random(n) -- 1 <= k <= n
    -- Quick swap
    t[n], t[k] = t[k], t[n]
    n = n - 1
  end
 
  return t
end

function GetSize(t)

	if type(t) ~= "table" then
		return 1 
	end

	local n = #t 
	if n == 0 then
		for k, v in pairs(t) do
			n = n + 1
		end
	end 
	return n
end

----------------------------------------------
-- Units
----------------------------------------------

function GetMaxTransfertTable(unit)
	local maxTranfert = {}
	local unitType = unit:GetType()
	local unitInfo = GameInfo.Units[unit:GetType()]
	maxTranfert.Personnel = GameInfo.GlobalParameters["MAX_PERSONNEL_TRANSFERT_FROM_RESERVE"].Value
	maxTranfert.Materiel = GameInfo.GlobalParameters["MAX_MATERIEL_TRANSFERT_FROM_RESERVE"].Value
	return maxTranfert
end

function HandleCasualtiesByTo(A, B)

	if A.AntiPersonnel then
		B.Dead = Round(B.PersonnelCasualties * A.AntiPersonnel / 100)
	else
		B.Dead = Round(B.PersonnelCasualties * GameInfo.GlobalParameters["DEFAULT_ANTIPERSONNEL_RATIO"].Value / 100)
	end
	
	
	if A.CanTakePrisonners then
	
		if A.CapturedPersonnelRatio then
			B.Captured = Round((B.PersonnelCasualties - B.Dead) * A.CapturedPersonnelRatio / 100)
		else
			B.Captured = Round((B.PersonnelCasualties - B.Dead) * GameInfo.GlobalParameters["DEFAULT_CAPTURED_PERSONNEL_RATIO"].Value / 100)
		end	
		if A.MaxCapture then
			B.Captured = math.min(A.MaxCapture, B.Captured)
		end
	else
		B.Captured = 0
	end
	
	B.Wounded = B.PersonnelCasualties - B.Dead - B.Captured
	
	return B
end

----------------------------------------------
-- Initialize functions for other contexts
----------------------------------------------

function Initialize()
	if not ExposedMembers.GCO then ExposedMembers.GCO = {} end
	ExposedMembers.GCO.Round = Round
	ExposedMembers.GCO.Shuffle = Shuffle
	ExposedMembers.GCO.GetSize = GetSize
	ExposedMembers.GCO.GetMaxTransfertTable = GetMaxTransfertTable
	ExposedMembers.GCO.HandleCasualtiesByTo = HandleCasualtiesByTo
	ExposedMembers.Utils_Initialized = true
end
Initialize()