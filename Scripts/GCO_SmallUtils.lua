--=====================================================================================--
--	FILE:	 GCO_SmallUtils.lua
--  Gedemon (2017)
--=====================================================================================--

print ("Loading GCO_SmallUtils.lua...")

local indentationString	= ".............................." -- maxLength = 30 car
local indentationSpaces	= "                              "

function Indentation(str, maxLength, bAlignRight, bShowSpace)
	local bIsNumber	= type(str) == "number"
	local minLength	= 2
	local indentStr	= (bShowSpace and indentationString) or indentationSpaces
	local maxLength = math.max(maxLength or string.len(indentStr))
	--local str 		= (bIsNumber and str > math.pow(10,maxLength-2)-1 and tostring(math.floor(str))) or tostring(str)
	--local str 		= (bIsNumber and str > 9 and tostring(math.floor(str))) or tostring(str)
	local str 		= tostring(str)
	local length 	= string.len(str)
	
	if length > maxLength and bIsNumber then
		str		= tostring(math.floor(tonumber(str)))
		length 	= string.len(str)
	end
	
	if length < maxLength then
		if bAlignRight then
			return string.sub(indentStr, 1, maxLength - length) .. str
		else
			return str.. string.sub(indentStr, 1, maxLength - length)
		end
	elseif length > maxLength and length > minLength then
		if bIsNumber then
			return tostring(math.pow(10,maxLength)-1)  -- return 999 for value >= 1000 when maxLength = 3
		else
			return string.sub(str, 1, maxLength-1).."."
		end
	else
		return str
	end
end

function Indentation20(str)
	local str = tostring(str)
	local length = string.len(str)
	if length < 19 then
		return str.. " " .. string.sub(indentationString, 1, 20 - length) .. " "
	elseif length == 19 then
		return str .. " "
	else
		return string.sub(str, 1, 21)
	end
end

function Indentation15(str)
	local str = tostring(str)
	local length = string.len(str)
	if length < 14 then
		return str.. " " .. string.sub(indentationString, 1, 15 - length) .. " "
	elseif length == 14 then
		return str .. " "
	else
		return string.sub(str, 1, 16)
	end
end

function Indentation8(str)
	local str = tostring(str)
	local length = string.len(str)
	if length < 7 then
		return str.. " " .. string.sub(indentationString, 1, 8 - length) .. " "
	elseif length == 7 then
		return str .. " "
	else
		return string.sub(str, 1, 9)
	end
end

function NumToString(num, limit)
	if not num or type(num) ~= "number" then return tostring(0) end
	if limit and string.len(math.floor(num)) > limit then
		return tostring(math.pow(10,limit)-1)  -- return 999 for value >= 1000 when limit = 3
	end
	if limit and limit < 4 then -- minimal space
		if num < 10 then
			return Locale.Lookup("{1: number #.#}",num)
		else
			return Locale.Lookup("{1: number #}",num)
		end
	else
		if num < 10 then
			return Locale.Lookup("{1: number #.##}",num)
		elseif num < 100 then
			return Locale.Lookup("{1: number #.#}",num)
		else
			return Locale.Lookup("{1: number #,###}",num)
		end
	end
end

function GetKeyFromIDs(i,j)
	return tostring(i)..","..tostring(j)
end

-- ===========================================================================
--	Recursively duplicate (deep copy)
--	Original from: http://lua-users.org/wiki/CopyTable
-- ===========================================================================
function DeepCopy( orig )
    local orig_type = type(orig);
    local copy;
    if orig_type == 'table' then
        copy = {};
        for orig_key, orig_value in next, orig, nil do
            copy[DeepCopy(orig_key)] = DeepCopy(orig_value);
        end
        setmetatable(copy, DeepCopy(getmetatable(orig)));
    else -- number, string, boolean, etc
        copy = orig;
    end
    return copy;
end


-- ===========================================================================
--	Recursively Compare
-- ===========================================================================
function Deepcompare(t1,t2,test_mt)
	local ty1 = type(t1)
	local ty2 = type(t2)
	if ty1 ~= ty2 then return false end
	-- non-table types can be directly compared
	if ty1 ~= 'table' and ty2 ~= 'table' then return t1 == t2 end
	-- as well as tables which have the metamethod __eq
	local mt = getmetatable(t1)
	if test_mt and mt and mt.__eq then return t1 == t2 end
	for k1,v1 in pairs(t1) do
		local v2 = t2[k1]
		if v2 == nil or not Deepcompare(v1,v2) then return false end
	end
	for k2,v2 in pairs(t2) do
		local v1 = t1[k2]
		if v1 == nil or not Deepcompare(v1,v2) then return false end
	end
	return true
end