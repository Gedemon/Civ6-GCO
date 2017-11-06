--=====================================================================================--
--	FILE:	 GCO_SmallUtils.lua
--  Gedemon (2017)
--=====================================================================================--

print ("Loading GCO_SmallUtils.lua...")

local indentationString	= ".............................."
function Indentation20(str)
	local length = string.len(str)
	if length < 19 then
		return str.. " " .. string.sub(indentationString, 1, 20 - length) .. " "
	elseif length == 19 then
		return str .. " "
	else
		return string.sub(str, 1, 20)
	end
end

function Indentation15(str)
	local length = string.len(str)
	if length < 14 then
		return str.. " " .. string.sub(indentationString, 1, 15 - length) .. " "
	elseif length == 14 then
		return str .. " "
	else
		return string.sub(str, 1, 15)
	end
end