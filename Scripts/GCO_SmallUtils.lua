--=====================================================================================--
--	FILE:	 GCO_SmallUtils.lua
--  Gedemon (2017)
--=====================================================================================--

print ("Loading GCO_SmallUtils.lua...")

local indentationString	= ".............................." -- maxLength = 30 car
local indentationSpaces	= "                              "

function Indentation(str, maxLength, bAlignRight, bShowSpace)
	local bIsNumber	= type(str) == "number"
	local maxLength = math.max(2, maxLength or string.len(indentStr))
	--local str 		= (bIsNumber and str > math.pow(10,maxLength-2)-1 and tostring(math.floor(str))) or tostring(str)
	--local str 		= (bIsNumber and str > 9 and tostring(math.floor(str))) or tostring(str)
	local str 		= tostring(str)
	local indentStr	= (bShowSpace and indentationString) or indentationSpaces
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
	elseif length > maxLength then
		if bIsNumber then
			return tostring(math.pow(10,maxLength)-1)
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