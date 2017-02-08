--===========================================================================
--[[
Serializes given data and returns result string.  Invalid data types:
function, userdata, thread.
]]
function serialize( p )
  
  local r = ""; local t = type( p );
  if t == "function" or t == "userdata" or t == "thread" then
    print( "serialize(): Invalid type: "..t ); --error.
  elseif p ~= nil then
    if t ~= "table" then
      if p == nil or p == true or p == false
        or t == "number" then r = tostring( p );
      elseif t == "string" then
        if p:lower() == "true" or p:lower() == "false"
            or tonumber( p ) ~= nil then r = '"'..p..'"';
        else r = p;
        end
      end
      r = r:gsub( "{", "\[LCB\]" );
      r = r:gsub( "}", "\[RCB\]" );
      r = r:gsub( "=", "\[EQL\]" );
      r = r:gsub( ",", "\[COM\]" );
    else
      r = "{"; local b = false;
      for k,v in pairs( p ) do
        if b then r = r..","; end
        r = r..serialize( k ).."="..serialize( v );
        b = true;
      end
      r = r.."}"
    end
  end
  return r;
end
--===========================================================================
--[[
Deserializes given string and returns result data.
]]
function deserialize( str )

  local findToken = function( str, int )
    if int == nil then int = 1; end
    local s, e, c = str:find( "({)" ,int);
    if s == int then --table.
      local len = str:len();
      local i = 1; --open brace.
      while i > 0 and s ~= nil and e <= len do --find close.
        s, e, c = str:find( "([{}])" ,e+1);
        if     c == "{" then i = i+1;
        elseif c == "}" then i = i-1;
        end
      end
      if i == 0 then c = str:sub(int,e);
      else print( "deserialize(): Malformed table." ); --error.
      end
    else s, e, c = str:find( "([^=,]*)" ,int); --primitive.
    end
    return s, e, c, str:sub( e+1, e+1 );
  end

  local r = nil; local s, c, d;
  if str ~= nil then
    local sT, eT, cT = str:find( "{(.*)}" );
    if sT == 1 then
      r = {}; local len = cT:len(); local e = 1;
      if cT ~= "" then
        repeat
          local t1, t2; local more = false;
          s, e, c, d = findToken( cT, e );
          if s ~= nil then t1 = deserialize( c ); end
          if d == "=" then --key.
            s, e, c, d = findToken( cT, e+2 );
            if s ~= nil then t2 = deserialize( c ); end
          end
          if d == "," then e = e+2; more = true; end --one more.
          if t2 ~= nil then r[t1] = t2;
          else table.insert( r, t1 );
          end
        until e >= len and not more;
      end
    elseif tonumber(str) ~= nil then r = tonumber(str);
    elseif str == "true"  then r = true;
    elseif str == "false" then r = false;
    else
      s, e, c = str:find( '"(.*)"' );
      if s == 1 and e == str:len() then
        if c == "true" or c == "false" or tonumber( c ) ~= nil then
          str = c;
        end
      end
      r = str;
      r = r:gsub( "%[LCB%]", "{" );
      r = r:gsub( "%[RCB%]", "}" );
      r = r:gsub( "%[EQL%]", "=" );
      r = r:gsub( "%[COM%]", "," );
    end
  end
  return r;
end
--===========================================================================

----------------------------------------------
-- Addition for Civ6 mod (Gedemon)
-- Initialize functions for other contexts
----------------------------------------------

function Initialize()
	if not ExposedMembers.GCO then ExposedMembers.GCO = {} end	
	
	ExposedMembers.GCO.serialize = serialize
	ExposedMembers.GCO.deserialize = deserialize
	
	ExposedMembers.binser_Initialized = true
end
Initialize()