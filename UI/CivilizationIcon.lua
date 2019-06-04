-- Copyright 2017-2019, Firaxis Games

-- GCO <<<<<
print("Loading CivilizationIcon.lua.")
include( "GCO_PlayerConfig" )
-- GCO >>>>>

include("LuaClass");
include("Colors");
include("SupportFunctions");

------------------------------------------------------------------
-- Class Table
------------------------------------------------------------------
CivilizationIcon = LuaClass:Extend()

------------------------------------------------------------------
-- Class Constants
------------------------------------------------------------------
CivilizationIcon.m_CivTooltip = {};
TTManager:GetTypeControlTable("CivTooltip", CivilizationIcon.m_CivTooltip);

CivilizationIcon.ICON_UNKNOWN_CIV = "ICON_CIVILIZATION_UNKNOWN";
CivilizationIcon.DATA_FIELD_CLASS = "CIVILIZATION_ICON_CLASS";

------------------------------------------------------------------
-- Class Members
------------------------------------------------------------------
-- This is needed for how we deal with tooltip callbacks.
CivilizationIcon.playerID = -1;
CivilizationIcon.detailString = "";

------------------------------------------------------------------
-- Static-style initialization functions
------------------------------------------------------------------
function CivilizationIcon:GetInstance(instanceManager:table, newParent:table)
	local instance = instanceManager:GetInstance(newParent);
	return CivilizationIcon:AttachInstance(instance);
end

function CivilizationIcon:AttachInstance(instance:table)
	self = instance[CivilizationIcon.DATA_FIELD_CLASS];
	if not self then
		self = CivilizationIcon:new(instance);
		instance[CivilizationIcon.DATA_FIELD_CLASS] = self;
	end
	self:Reset();
	return self, instance;
end
------------------------------------------------------------------

------------------------------------------------------------------
-- Constructor
------------------------------------------------------------------
function CivilizationIcon:new(instance:table)
	self = LuaClass.new(CivilizationIcon)
	self.Controls = instance or Controls;
	return self;
end
------------------------------------------------------------------
function CivilizationIcon:UpdateIconFromPlayerID(playerID:number)

	local localPlayerID:number = Game.GetLocalPlayer();
	local showCivIcon:boolean = playerID == localPlayerID;
	local civIcon:string = self.ICON_UNKNOWN_CIV;

	if playerID ~= -1 then
		if localPlayerID ~= -1 then
			showCivIcon = showCivIcon or Players[localPlayerID]:GetDiplomacy():HasMet(playerID);
		end
		if showCivIcon then
	local playerConfig:table = PlayerConfigurations[playerID];
			civIcon = "ICON_" .. playerConfig:GetCivilizationTypeName();
		end
	end

	local textureOffsetX:number, textureOffsetY:number, textureSheet:string = IconManager:FindIconAtlas(civIcon, self.Controls.CivIcon:GetSizeX());
	if(textureSheet == nil or textureSheet == "") then
		UI.DataError("Could not find icon in CivilizationIcon.UpdateIcon: icon=\""..civIcon.."\", iconSize="..tostring(self.Controls.CivIcon:GetSizeX()));
	else
		self.Controls.CivIcon:SetTexture(textureOffsetX, textureOffsetY, textureSheet);
	end

	self:ColorCivIcon(playerID, showCivIcon);

	if self.Controls.LocalPlayer then
		self.Controls.LocalPlayer:SetHide(playerID ~= localPlayerID);
	end
end

function CivilizationIcon:ColorCivIcon(playerID:number, showCivIcon:boolean)
	if showCivIcon then
		-- GCO <<<<<
		--local backColor, frontColor = UI.GetPlayerColors(playerID);
		local backColor, frontColor = (GCO.GetPlayerColors and GCO.GetPlayerColors(playerID)) or UI.GetPlayerColors(playerID) -- this can be called before full initialization
		-- GCO >>>>>
		self.Controls.CivIcon:SetColor(frontColor);
		if self.Controls.CivIconBacking then
			self.Controls.CivIconBacking:SetColor(backColor);
		else
			self.Controls.CivBacking_Base:SetColor(backColor);
			self.Controls.CivBacking_Lighter:SetColor(UI.DarkenLightenColor(backColor, 80, 255));
			self.Controls.CivBacking_Darker:SetColor(UI.DarkenLightenColor(backColor, -55, 230));
		end
	else
		local COLOR_UNKNOWN = UI.GetColorValue("COLOR_UNKNOWN");
		self.Controls.CivIcon:SetColor(COLOR_UNKNOWN);
		if self.Controls.CivIconBacking then
			self.Controls.CivIconBacking:SetColor(COLOR_UNKNOWN);
		else
			self.Controls.CivBacking_Base:SetColor(COLOR_UNKNOWN);
			self.Controls.CivBacking_Lighter:SetColor(COLOR_UNKNOWN);
			self.Controls.CivBacking_Darker:SetColor(COLOR_UNKNOWN);
		end
	end
end
	
function CivilizationIcon:SetLeaderTooltip(playerID:number, details:string)
	local pPlayer:table = Players[playerID];
	local playerConfig:table = PlayerConfigurations[playerID];
	local localPlayerID:number = Game.GetLocalPlayer();
	local localPlayer:table = Players[localPlayerID];

	--Cache our string
	self.playerID = playerID;
	self.detailString = details;

	if(playerID ~= localPlayerID and localPlayer ~= nil and not localPlayer:GetDiplomacy():HasMet(playerID)) then
		self.Controls.CivIcon:SetToolTipType();
		self.Controls.CivIcon:ClearToolTipCallback();
		if GameConfiguration.IsAnyMultiplayer() and pPlayer:IsHuman() then
			self.Controls.CivIcon:SetToolTipString(Locale.Lookup("LOC_DIPLOPANEL_UNMET_PLAYER") .. " (" .. playerConfig:GetPlayerName() .. ")");
		else
			self.Controls.CivIcon:SetToolTipString(Locale.Lookup("LOC_DIPLOPANEL_UNMET_PLAYER"));
		end
	else
		self.Controls.CivIcon:SetToolTipType("CivTooltip");
		self.Controls.CivIcon:SetToolTipCallback(function() self:UpdateLeaderTooltip(self.playerID, self.detailString); end);
	end
end

function CivilizationIcon:SetTooltipString(tooltip:string)
	self.Controls.CivIcon:SetToolTipType();
	self.Controls.CivIcon:ClearToolTipCallback();
	self.Controls.CivIcon:SetToolTipString(tooltip);
end

function CivilizationIcon:UpdateLeaderTooltip(playerID:number, details:string)
	local pPlayer:table = Players[playerID];
	local playerConfig:table = PlayerConfigurations[playerID];
	local localPlayerID:number = Game.GetLocalPlayer();

	if(pPlayer ~= nil and playerConfig ~= nil) then
		self.m_CivTooltip.YouIndicator:SetHide(playerID ~= localPlayerID);

		local leaderTypeName:string = playerConfig:GetLeaderTypeName();
		if(leaderTypeName ~= nil) then
			self.m_CivTooltip.LeaderIcon:SetIcon("ICON_"..leaderTypeName);
			self.m_CivTooltip.LeaderIcon:SetHide(false);

			local desc:string;
			local leaderDesc:string = playerConfig:GetLeaderName();
			local civDesc:string = playerConfig:GetCivilizationDescription();
			if GameConfiguration.IsAnyMultiplayer() and pPlayer:IsHuman() then
				local name = Locale.Lookup(playerConfig:GetPlayerName());
				desc = Locale.Lookup("LOC_DIPLOMACY_DEAL_PLAYER_PANEL_TITLE", leaderDesc, civDesc) .. " (" .. name .. ")";
			else
				desc = Locale.Lookup("LOC_DIPLOMACY_DEAL_PLAYER_PANEL_TITLE", leaderDesc, civDesc);
			end
		
			if (details ~= nil and details ~= "") then
				desc = desc .. "[NEWLINE]" .. details;
			end
			self.m_CivTooltip.LeaderName:SetText(desc);
			self.m_CivTooltip.BG:DoAutoSize();
		end
	end
end

function CivilizationIcon:Reset()
	if self.Controls.LocalPlayer then
		self.Controls.LocalPlayer:SetHide(true);
	end

	if self.detailString ~= "" then
		self.detailString = "";
	end
end