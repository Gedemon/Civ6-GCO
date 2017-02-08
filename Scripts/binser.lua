
--===========================================================================
-- SaveUtils
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
--]]

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
--]]

--===========================================================================
-- Identity-preserving table serialization by Metalua
-- https://github.com/fab13n/metalua
-- https://github.com/fab13n/metalua/blob/no-dll/src/lib/serialize.lua
--===========================================================================

--------------------------------------------------------------------------------
-- Serialize an object into a source code string. This string, when passed as
-- an argument to loadstring()(), returns an object structurally identical
-- to the original one. The following are currently supported:
-- * strings, numbers, booleans, nil
-- * functions without upvalues
-- * tables thereof. Tables can have shared part, but can't be recursive yet.
-- Caveat: metatables and environments aren't saved.
--------------------------------------------------------------------------------

local no_identity = { number=1, boolean=1, string=1, ['nil']=1 }

function serialize2 (x)
   
   local gensym_max =  0  -- index of the gensym() symbol generator
   local seen_once  = { } -- element->true set of elements seen exactly once in the table
   local multiple   = { } -- element->varname set of elements seen more than once
   local nested     = { } -- transient, set of elements currently being traversed
   local nest_points = { }
   local nest_patches = { }
   
   local function gensym()
      gensym_max = gensym_max + 1 ;  return gensym_max
   end
   
   -----------------------------------------------------------------------------
   -- nest_points are places where a table appears within itself, directly or not.
   -- for instance, all of these chunks create nest points in table x:
   -- "x = { }; x[x] = 1", "x = { }; x[1] = x", "x = { }; x[1] = { y = { x } }".
   -- To handle those, two tables are created by mark_nest_point:
   -- * nest_points [parent] associates all keys and values in table parent which
   --   create a nest_point with boolean `true'
   -- * nest_patches contain a list of { parent, key, value } tuples creating
   --   a nest point. They're all dumped after all the other table operations
   --   have been performed.
   --
   -- mark_nest_point (p, k, v) fills tables nest_points and nest_patches with
   -- informations required to remember that key/value (k,v) create a nest point
   -- in table parent. It also marks `parent' as occuring multiple times, since
   -- several references to it will be required in order to patch the nest
   -- points.
   -----------------------------------------------------------------------------
   local function mark_nest_point (parent, k, v)
      local nk, nv = nested[k], nested[v]
      assert (not nk or seen_once[k] or multiple[k])
      assert (not nv or seen_once[v] or multiple[v])
      local mode = (nk and nv and "kv") or (nk and "k") or ("v")
      local parent_np = nest_points [parent]
      local pair = { k, v }
      if not parent_np then parent_np = { }; nest_points [parent] = parent_np end
      parent_np [k], parent_np [v] = nk, nv
      table.insert (nest_patches, { parent, k, v })
      seen_once [parent], multiple [parent]  = nil, true
   end
   
   -----------------------------------------------------------------------------
   -- First pass, list the tables and functions which appear more than once in x
   -----------------------------------------------------------------------------
   local function mark_multiple_occurences (x)
      if no_identity [type(x)] then return end
      if     seen_once [x]     then seen_once [x], multiple [x] = nil, true
      elseif multiple  [x]     then -- pass
      else   seen_once [x] = true end
      
      if type (x) == 'table' then
         nested [x] = true
         for k, v in pairs (x) do
            if nested[k] or nested[v] then mark_nest_point (x, k, v) else
               mark_multiple_occurences (k)
               mark_multiple_occurences (v)
            end
         end
         nested [x] = nil
      end
   end

   local dumped    = { } -- multiply occuring values already dumped in localdefs
   local localdefs = { } -- already dumped local definitions as source code lines


   -- mutually recursive functions:
   local dump_val, dump_or_ref_val

   --------------------------------------------------------------------
   -- if x occurs multiple times, dump the local var rather than the
   -- value. If it's the first time it's dumped, also dump the content
   -- in localdefs.
   --------------------------------------------------------------------            
   function dump_or_ref_val (x)
      if nested[x] then return 'false' end -- placeholder for recursive reference
      if not multiple[x] then return dump_val (x) end
      local var = dumped [x]
      if var then return "_[" .. var .. "]" end -- already referenced
      local val = dump_val(x) -- first occurence, create and register reference
      var = gensym()
      table.insert(localdefs, "_["..var.."]="..val)
      dumped [x] = var
      return "_[" .. var .. "]"
   end

   -----------------------------------------------------------------------------
   -- Second pass, dump the object; subparts occuring multiple times are dumped
   -- in local variables which can be referenced multiple times;
   -- care is taken to dump locla vars in asensible order.
   -----------------------------------------------------------------------------
   function dump_val(x)
      local  t = type(x)
      if     x==nil        then return 'nil'
      elseif t=="number"   then return tostring(x)
      elseif t=="string"   then return string.format("%q", x)
      elseif t=="boolean"  then return x and "true" or "false"
      elseif t=="function" then
         return string.format ("loadstring(%q,'@serialized')", string.dump (x))
      elseif t=="table" then

         local acc        = { }
         local idx_dumped = { }
         local np         = nest_points [x]
         for i, v in ipairs(x) do
            if np and np[v] then
               table.insert (acc, 'false') -- placeholder
            else
               table.insert (acc, dump_or_ref_val(v))
            end
            idx_dumped[i] = true
         end
         for k, v in pairs(x) do
            if np and (np[k] or np[v]) then
               --check_multiple(k); check_multiple(v) -- force dumps in localdefs
            elseif not idx_dumped[k] then
               table.insert (acc, "[" .. dump_or_ref_val(k) .. "] = " .. dump_or_ref_val(v))
            end
         end
         return "{ "..table.concat(acc,", ").." }"
      else
         error ("Can't serialize data of type "..t)
      end
   end
          
   local function dump_nest_patches()
      for _, entry in ipairs(nest_patches) do
         local p, k, v = unpack (entry)
         assert (multiple[p])
         local set = dump_or_ref_val (p) .. "[" .. dump_or_ref_val (k) .. "] = " .. 
            dump_or_ref_val (v) .. " -- rec "
         table.insert (localdefs, set)
      end
   end
   
   mark_multiple_occurences (x)
   local toplevel = dump_or_ref_val (x)
   dump_nest_patches()

   if next (localdefs) then
      return "local _={ }\n" ..
         table.concat (localdefs, "\n") .. 
         "\nreturn " .. toplevel
   else
      return "return " .. toplevel
   end
end

function deserialize2 (x)
	return loadstring(x)()
end

--===========================================================================
-- BLODS - Binary Lua Object (De)Serialization
-- https://gist.github.com/Yevano/e4a2f35cda144a9f9667
--===========================================================================
--[[
    BLODS - Binary Lua Object (De)Serialization
]]

--[[
    Save on table access.
]]
local pairs       = pairs
local type        = type
local loadstring  = loadstring
local mathabs     = math.abs
local mathfloor   = math.floor
local mathfrexp   = math.frexp
local mathmodf    = math.modf
local mathpow     = math.pow
local stringbyte  = string.byte
local stringchar  = string.char
local stringdump  = string.dump
local stringsub   = string.sub
local tableconcat = table.concat

--[[
    Float conversions. Modified from http://snippets.luacode.org/snippets/IEEE_float_conversion_144.
]]
local function double2str(value)
    local s=value<0 and 1 or 0
    if mathabs(value)==1/0 then
        return (s==1 and "\0\0\0\0\0\0\240\255" or "\0\0\0\0\0\0\240\127")
    end
    if value~=value then
        return "\170\170\170\170\170\170\250\255"
    end
    local fr,exp=mathfrexp(mathabs(value))
    fr,exp=fr*2,exp-1
    exp=exp+1023
    return tableconcat({stringchar(mathfloor(fr*2^52)%256),
    stringchar(mathfloor(fr*2^44)%256),
    stringchar(mathfloor(fr*2^36)%256),
    stringchar(mathfloor(fr*2^28)%256),
    stringchar(mathfloor(fr*2^20)%256),
    stringchar(mathfloor(fr*2^12)%256),
    stringchar(mathfloor(fr*2^4)%16+mathfloor(exp)%16*16),
    stringchar(mathfloor(exp/2^4)%128+128*s)})
end

local function str2double(str)
    local fr=stringbyte(str, 1)/2^52+stringbyte(str, 2)/2^44+stringbyte(str, 3)/2^36+stringbyte(str, 4)/2^28+stringbyte(str, 5)/2^20+stringbyte(str, 6)/2^12+(stringbyte(str, 7)%16)/2^4+1
    local exp=(stringbyte(str, 8)%128)*16+mathfloor(str:byte(7)/16)-1023
    local s=mathfloor(stringbyte(str, 8)/128)
    if exp==1024 then
        return fr==1 and (1-2*s)/0 or 0/0
    end
    return (1-2*s)*fr*2^exp
end

--[[
    Integer conversions. Taken from http://lua-users.org/wiki/ReadWriteFormat.
    Modified to support signed ints.
]]

local function signedstringtonumber(str)
  local function _b2n(exp, num, digit, ...)
    if not digit then return num end
    return _b2n(exp*256, num + digit*exp, ...)
  end
  return _b2n(256, stringbyte(str, 1, -1)) - mathpow(2, #str * 8 - 1)
end

local function signednumbertobytes(num, width)
    local function _n2b(width, num, rem)
        rem = rem * 256
        if width == 0 then return rem end
        return rem, _n2b(width-1, mathmodf(num/256))
    end
    return stringchar(_n2b(width-1, mathmodf((num + mathpow(2, width * 8 - 1))/256)))
end

local function stringtonumber(str)
    local function _b2n(exp, num, digit, ...)
      if not digit then return num end
      return _b2n(exp*256, num + digit*exp, ...)
    end
    return _b2n(256, stringbyte(str, 1, -1))
end

local function numbertobytes(num, width)
    local function _n2b(width, num, rem)
        rem = rem * 256
        if width == 0 then return rem end
        return rem, _n2b(width-1, mathmodf(num/256))
    end
    return stringchar(_n2b(width-1, mathmodf((num)/256)))
end

--[[
    (De)Serialization for Lua types.
]]

local function intWidth(int)
    local inth = int < 0 and -int/2 + 1 or int/2
    local div = 256
    for i = 1, 8 do
        if inth/div < 1 then
            return i
        end
        div = div * 256
    end
end

local types = {
    boolean = "b",
    double = "d",
    integer = "i",
    string = "s",
    table = "t",
    ["function"] = "f",
    ["nil"] = "_"
}

local serialization = { }
local deserialization = { }

function serialization.boolean(obj)
    return obj and "\1" or "\0"
end

function serialization.double(obj)
    return double2str(obj)
end

function serialization.integer(obj)
    local width = intWidth(obj)
    return stringchar(width) .. signednumbertobytes(obj, width)
end

function serialization.string(obj)
    local len = #obj
    local width = intWidth(len)
    return tableconcat({ stringchar(width), numbertobytes(len, width), obj })
end

serialization["function"] = function(obj)
    local s = stringdump(obj)
    return numbertobytes(#s, 4) .. s
end

function deserialization.b(idx, ser)
    local ret = stringsub(ser[1], idx, idx) == "\1"
    return ret, idx + 1
end

function deserialization.d(idx, ser)
    local ret = str2double(stringsub(ser[1], idx, idx + 8))
    return ret, idx + 8
end

function deserialization.i(idx, ser)
    local width = stringtonumber(stringsub(ser[1], idx, idx))
    local ret = signedstringtonumber(stringsub(ser[1], idx + 1, idx + width))
    return ret, idx + width + 1
end

function deserialization.s(idx, ser)
    local width = stringtonumber(stringsub(ser[1], idx, idx))
    local len = stringtonumber(stringsub(ser[1], idx + 1, idx + width))
    local ret = stringsub(ser[1], idx + width + 1, idx + width + len)
    return ret, idx + width + len + 1
end

function deserialization.f(idx, ser)
    local len = stringtonumber(stringsub(ser[1], idx, idx + 3))
    local ret = loadstring(stringsub(ser[1], idx + 4, idx + len + 3))
    return ret, idx + len + 4
end

function deserialization._(idx, ser)
    return nil, idx
end

function serialize3(obj)
    -- State vars.
    local ntables = 1
    local tables = { }
    local tableIDs = { }
    local tableSerial = { }

    -- Internal recursive function.
    local function serialize(obj)
        local t = type(obj)
        if t == "table" then
            local len = #obj

            if tables[obj] then
                -- We already serialized this table. Just return the id.
                return tableIDs[obj]
            end

            -- Insert table info.
            local id = ntables
            tables[obj] = true
            local width = intWidth(ntables)
            local ser = "t" .. numbertobytes(width, 1) .. numbertobytes(ntables, width)
            tableIDs[obj] = ser

            -- Important to increment here so tables inside this one don't use the same id.
            ntables = ntables + 1

            -- Serialize the table.
            local serialConcat = { }

            -- Array part.
            for i = 1, len do
                if obj[i] == nil then
                    len = i - 1
                    break
                end
                serialConcat[#serialConcat + 1] = serialize(obj[i])
            end
            serialConcat[#serialConcat + 1] = "\0"

            -- Table part.
            for k, v in pairs(obj) do
                if type(k) ~= "number" or ((k > len or k < 1) or mathfloor(k) ~= k) then
                    -- For each pair, serialize both the key and the value.
                    local idx = #serialConcat
                    serialConcat[idx + 1] = serialize(k)
                    serialConcat[idx + 2] = serialize(v)
                end
            end
            serialConcat[#serialConcat + 1] = "\0"

            -- tableconcat is way faster than normal concatenation using .. when dealing with lots of strings.
            -- Add this serialization to the table of serialized tables for quick access and later more concatenation.
            tableSerial[id] = tableconcat(serialConcat)
            return ser
        else
            -- Do serialization on a non-recursive type.
            if t == "number" then
                -- Space optimization can be done for ints, so serialize them differently from doubles.
                if mathfloor(obj) == obj then
                    return "i" .. serialization.integer(obj)
                end
                return "d" .. serialization.double(obj)
            end
            local ser = types[t]
            return obj == nil and ser or ser .. serialization[t](obj)
        end
    end

    -- Either serialize for a table or for a non-recursive type.
    local ser = serialize(obj)
    if type(obj) == "table" then
        return tableconcat({ "t", tableconcat(tableSerial) })
    end
    return ser
end

function deserialize3(ser)
    local idx = 1
    local tables = { { } }
    local serref = { ser }

    local function getchar()
        local ret = stringsub(serref[1], idx, idx)
        return ret ~= "" and ret or nil
    end

    local function deserializeValue()
        local t = getchar()
        idx = idx + 1
        if t == "t" then
            -- Get table id.
            local width = stringtonumber(getchar())
            idx = idx + 1
            local id = stringtonumber(stringsub(serref[1], idx, idx + width - 1))
            idx = idx + width

            -- Create an empty table as a placeholder.
            if not tables[id] then
                tables[id] = { }
            end

            return tables[id]
        else
            local ret
            ret, idx = deserialization[t](idx, serref)
            return ret
        end
    end

    -- Either deserialize for a table or for a non-recursive type.
    local i = 1
    if getchar() == "t" then
        idx = idx + 1
        while getchar() do
            if not tables[i] then tables[i] = { } end
            local curtbl = tables[i]

            -- Array part.
            while getchar() ~= "\0" do
                curtbl[#curtbl + 1] = deserializeValue()
            end

            -- Table part.
            idx = idx + 1
            while getchar() ~= "\0" do
                curtbl[deserializeValue()] = deserializeValue()
            end

            i = i + 1
            idx = idx + 1
        end
        return tables[1]
    end
    return deserializeValue()
end


--===========================================================================
-- Pickle.lua
--===========================================================================
----------------------------------------------
-- Pickle.lua
-- A table serialization utility for lua
-- Steve Dekorte, http://www.dekorte.com, Apr 2000
-- Freeware
----------------------------------------------

function serialize4(t)
  return Pickle:clone():pickle_(t)
end

Pickle = {
  clone = function (t) local nt={}; for i, v in pairs(t) do nt[i]=v end return nt end 
}

function Pickle:pickle_(root)
  if type(root) ~= "table" then 
    error("can only pickle tables, not ".. type(root).."s")
  end
  self._tableToRef = {}
  self._refToTable = {}
  local savecount = 0
  self:ref_(root)
  local s = ""

  while #(self._refToTable) > savecount do
    savecount = savecount + 1
    local t = self._refToTable[savecount]
    s = s.."{\n"
    for i, v in pairs(t) do
        s = string.format("%s[%s]=%s,\n", s, self:value_(i), self:value_(v))
    end
    s = s.."},\n"
  end

  return string.format("{%s}", s)
end

function Pickle:value_(v)
  local vtype = type(v)
  if     vtype == "string" then return string.format("%q", v)
  elseif vtype == "number" then return v
  elseif vtype == "boolean" then return tostring(v)
  elseif vtype == "table" then return "{"..self:ref_(v).."}"
  else --error("pickle a "..type(v).." is not supported")
  end  
end

function Pickle:ref_(t)
  local ref = self._tableToRef[t]
  if not ref then 
    if t == self then error("can't pickle the pickle class") end
    table.insert(self._refToTable, t)
    ref = #(self._refToTable)
    self._tableToRef[t] = ref
  end
  return ref
end

----------------------------------------------
-- unpickle
----------------------------------------------

function deserialize4(s)
  if type(s) ~= "string" then
    error("can't unpickle a "..type(s)..", only strings")
  end
  local gentables = loadstring("return "..s)
  local tables = gentables()
  
  for tnum = 1, #(tables) do
    local t = tables[tnum]
    local tcopy = {}; for i, v in pairs(t) do tcopy[i] = v end
    for i, v in pairs(tcopy) do
      local ni, nv
      if type(i) == "table" then ni = tables[i[1]] else ni = i end
      if type(v) == "table" then nv = tables[v[1]] else nv = v end
      t[i] = nil
      t[ni] = nv
    end
  end
  return tables[1]
end

--===========================================================================
-- Addition for Civ6 mod (Gedemon)
-- Initialize functions for other contexts
--===========================================================================

function Initialize()
	if not ExposedMembers.GCO then ExposedMembers.GCO = {} end	
	
	ExposedMembers.GCO.serialize 	= serialize
	ExposedMembers.GCO.deserialize 	= deserialize
	
	ExposedMembers.GCO.serialize2 	= serialize2
	ExposedMembers.GCO.deserialize2	= deserialize2
	
	ExposedMembers.GCO.serialize3 	= serialize3
	ExposedMembers.GCO.deserialize3	= deserialize3
	
	ExposedMembers.GCO.serialize4 	= serialize4
	ExposedMembers.GCO.deserialize4	= deserialize4
	
	ExposedMembers.binser_Initialized = true
end
Initialize()