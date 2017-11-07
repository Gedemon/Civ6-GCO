--=====================================================================================--
--	FILE:	 GCO_SmallUtils.lua
--  Gedemon (2017)
--=====================================================================================--

print ("Loading GCO_SmallUtils.lua...")

local indentationString	= ".............................."
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