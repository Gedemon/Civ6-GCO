-- ===========================================================================
--	Unit Flag Manager
--	Manages all the 2d "flags" above units on the world map.
-- ===========================================================================

include( "InstanceManager" );
include( "SupportFunctions" );
include( "Civ6Common" );

-- GCO <<<<<

include( "GCO_TypeEnum" )
include( "GCO_PlayerConfig" )

-----------------------------------------------------------------------------------------
-- Initialize Functions
-----------------------------------------------------------------------------------------

local GCO = {}
function InitializeUtilityFunctions()
	GCO = ExposedMembers.GCO		-- contains functions from other contexts
	print ("Exposed Functions from other contexts initialized...")
end
LuaEvents.InitializeGCO.Add( InitializeUtilityFunctions )

local bShownSupplyLine = false

-- GCO >>>>>

-- ===========================================================================
--	CONSTANTS
-- ===========================================================================
local YOFFSET_2DVIEW			:number = 26;
local ZOFFSET_3DVIEW			:number = 36;
local ALPHA_DIM					:number = 0.45;
local COLOR_RED					:number = 0xFF0101F5;
local COLOR_YELLOW				:number = 0xFF2DFFF8;
local COLOR_GREEN				:number = 0xFF4CE710;
local FLAGSTATE_NORMAL			:number= 0;
local FLAGSTATE_FORTIFIED		:number= 1;
local FLAGSTATE_EMBARKED		:number= 2;
local FLAGSTYLE_MILITARY		:number= 0;
local FLAGSTYLE_CIVILIAN		:number= 1;
local FLAGSTYLE_SUPPORT			:number= 2;
local FLAGSTYLE_TRADE			:number= 3;
local FLAGSTYLE_NAVAL			:number= 4;
local FLAGSTYLE_RELIGION		:number= 5;
local FLAGTYPE_UNIT				:number= 0;
local ZOOM_MULT_DELTA			:number = .01;
local TEXTURE_BASE				:string = "UnitFlagBase.dds";
local TEXTURE_CIVILIAN			:string = "UnitFlagCivilian.dds";
local TEXTURE_RELIGION			:string = "UnitFlagReligion.dds";
local TEXTURE_EMBARK			:string = "UnitFlagEmbark.dds";
local TEXTURE_FORTIFY			:string = "UnitFlagFortify.dds";
local TEXTURE_NAVAL				:string = "UnitFlagNaval.dds";
local TEXTURE_SUPPORT			:string = "UnitFlagSupport.dds";
local TEXTURE_TRADE				:string = "UnitFlagTrade.dds";
local TEXTURE_MASK_BASE			:string = "UnitFlagBaseMask.dds";
local TEXTURE_MASK_CIVILIAN		:string = "UnitFlagCivilianMask.dds";
local TEXTURE_MASK_RELIGION		:string = "UnitFlagReligionMask.dds";
local TEXTURE_MASK_EMBARK		:string = "UnitFlagEmbarkMask.dds";
local TEXTURE_MASK_FORTIFY		:string = "UnitFlagFortifyMask.dds";
local TEXTURE_MASK_NAVAL		:string = "UnitFlagNavalMask.dds";
local TEXTURE_MASK_SUPPORT		:string = "UnitFlagSupportMask.dds";
local TEXTURE_MASK_TRADE		:string = "UnitFlagTradeMask.dds";
local TXT_UNITFLAG_ARMY_SUFFIX			:string = " " .. Locale.Lookup("LOC_UNITFLAG_ARMY_SUFFIX");
local TXT_UNITFLAG_CORPS_SUFFIX			:string = " " .. Locale.Lookup("LOC_UNITFLAG_CORPS_SUFFIX");
local TXT_UNITFLAG_ARMADA_SUFFIX			:string = " " .. Locale.Lookup("LOC_UNITFLAG_ARMADA_SUFFIX");
local TXT_UNITFLAG_FLEET_SUFFIX			:string = " " .. Locale.Lookup("LOC_UNITFLAG_FLEET_SUFFIX");
local TXT_UNITFLAG_ACTIVITY_ON_SENTRY	:string = " " .. Locale.Lookup("LOC_UNITFLAG_ACTIVITY_ON_SENTRY");
local TXT_UNITFLAG_ACTIVITY_ON_INTERCEPT:string = " " .. Locale.Lookup("LOC_UNITFLAG_ACTIVITY_ON_INTERCEPT");
local TXT_UNITFLAG_ACTIVITY_AWAKE		:string = " " .. Locale.Lookup("LOC_UNITFLAG_ACTIVITY_AWAKE");
local TXT_UNITFLAG_ACTIVITY_HOLD		:string = " " .. Locale.Lookup("LOC_UNITFLAG_ACTIVITY_HOLD");
local TXT_UNITFLAG_ACTIVITY_SLEEP		:string = " " .. Locale.Lookup("LOC_UNITFLAG_ACTIVITY_SLEEP");
local TXT_UNITFLAG_ACTIVITY_HEALING		:string = " " .. Locale.Lookup("LOC_UNITFLAG_ACTIVITY_HEALING");
local TXT_UNITFLAG_ACTIVITY_NO_ACTIVITY	:string = " " .. Locale.Lookup("LOC_UNITFLAG_ACTIVITY_NO_ACTIVITY");

local m_FlagOffsets :table = {};
	m_FlagOffsets[1] = {-32,0};
	m_FlagOffsets[2] = {32,0};
	m_FlagOffsets[3] = {0,-45};

local m_LinkOffsets :table = {};
	m_LinkOffsets[1] = {0,0};
	m_LinkOffsets[2] = {0,-20};
	m_LinkOffsets[3] = {16,22};


-- ===========================================================================
--	VARIABLES
-- ===========================================================================

-- A link to a container that is rendered after the Unit/City flags.  This is used
-- so that selected units will always appear above the other objects.
local m_SelectedContainer			:table = ContextPtr:LookUpControl( "../SelectedUnitContainer" );

local m_MilitaryInstanceManager		:table = InstanceManager:new( "UnitFlag",	"Anchor", Controls.MilitaryFlags );
local m_CivilianInstanceManager		:table = InstanceManager:new( "UnitFlag",	"Anchor", Controls.CivilianFlags );
local m_SupportInstanceManager		:table = InstanceManager:new( "UnitFlag",	"Anchor", Controls.SupportFlags );
local m_TradeInstanceManager		:table = InstanceManager:new( "UnitFlag",	"Anchor", Controls.TradeFlags );
local m_NavalInstanceManager		:table = InstanceManager:new( "UnitFlag",	"Anchor", Controls.NavalFlags );
local m_AttentionMarkerIM		:table = InstanceManager:new( "AttentionMarkerInstance", "Top" );

local m_cameraFocusX				:number = -1;
local m_cameraFocusY				:number = -1;
local m_zoomMultiplier				:number = 1;
local m_DirtyComponents				:table  = nil;
local m_UnitFlagInstances			:table  = {};
local m_isMapDeselectDisabled		:boolean= false;

-- COMMENTING OUT hstructures.
-- These structures remained defined for the entire lifetime of the application.
-- If a modder or scenario script needs to redefine it, yer boned.
-- Replacing these with regular tables, for now.
-- The meta table definition that holds the function pointers
--hstructure UnitFlagMeta
	---- Pointer back to itself.  Required.
	--__index							: UnitFlagMeta
--
	--new								: ifunction;
	--destroy							: ifunction;
	--Initialize						: ifunction;
	--GetUnit							: ifunction;
	--SetInteractivity				: ifunction;
	--SetFogState						: ifunction;
	--SetHide							: ifunction;
	--SetForceHide					: ifunction;
	--SetFlagUnitEmblem				: ifunction;
	--SetColor						: ifunction;
	--SetDim							: ifunction;
	--OverrideDimmed					: ifunction;
	--UpdateDimmedState				: ifunction;
	--UpdateFlagType					: ifunction;
	--UpdateHealth					: ifunction;
	--UpdateVisibility				: ifunction;
	--UpdateSelected					: ifunction;
	--UpdateFormationIndicators		: ifunction;
	--UpdateName						: ifunction;
	--UpdatePosition					: ifunction;
	--SetPosition						: ifunction;
	--UpdateStats						: ifunction;
	--UpdateReadyState				: ifunction;
	--UpdatePromotions				: ifunction;
	--UpdateAircraftCounter			: ifunction;
--end
--
---- The structure that holds the banner instance data
--hstructure UnitFlag
	--meta							: UnitFlagMeta;
--
	--m_InstanceManager				: table;				-- The instance manager that made the control set.
    --m_Instance						: table;				-- The instanced control set.
    --
	--m_cacheMilitaryFormation		: number;				-- Name of last military formation this flag was in.
    --m_Type							: number;
	--m_Style							: number;
	--m_eVisibility					: number;
    --m_IsInitialized					: boolean;				-- Is flag done it's initial creation.
	--m_IsSelected					: boolean;
    --m_IsCurrentlyVisible			: boolean;
	--m_IsForceHide					: boolean;
    --m_IsDimmed						: boolean;
	--m_OverrideDimmed				: boolean;
	--m_OverrideDim					: boolean;
	--m_FogState						: number;
    --
    --m_Player						: table;
    --m_UnitID						: number;		-- The unit ID.  Keeping just the ID, rather than a reference because there will be times when we need the value, but the unit instance will not exist.
--end

-- Create one instance of the meta object as a global variable with the same name as the data structure portion.  
-- This allows us to do a UnitFlag:new, so the naming looks consistent.
--UnitFlag = hmake UnitFlagMeta {};
UnitFlag = {};

-- Link its __index to itself
UnitFlag.__index = UnitFlag;



-- ===========================================================================
--	Obtain the unit flag associate with a player and unit.
--	RETURNS: flag object (if found), nil otherwise
-- ===========================================================================
function GetUnitFlag(playerID:number, unitID:number)
	if m_UnitFlagInstances[playerID]==nil then
		return nil;
	end
	return m_UnitFlagInstances[playerID][unitID];
end

------------------------------------------------------------------
-- constructor
------------------------------------------------------------------
function UnitFlag.new( self, playerID: number, unitID : number, flagType : number, flagStyle : number )
   -- local o = hmake UnitFlag { };
    local o = {};
	setmetatable( o, self );

	o:Initialize(playerID, unitID, flagType, flagStyle);

	if (m_UnitFlagInstances[playerID] == nil) then
		m_UnitFlagInstances[playerID] = {};
	end
	
	m_UnitFlagInstances[playerID][unitID] = o;
end

------------------------------------------------------------------
function UnitFlag.destroy( self )
    if ( self.m_InstanceManager ~= nil ) then           
        self:UpdateSelected( false );
                        		    
		if (self.m_Instance ~= nil) then
			self.m_InstanceManager:ReleaseInstance( self.m_Instance );
		end
    end
end

------------------------------------------------------------------
function UnitFlag.GetUnit( self )
	local pUnit : table = self.m_Player:GetUnits():FindID(self.m_UnitID);
	return pUnit;
end

------------------------------------------------------------------
function UnitFlag.Initialize( self, playerID: number, unitID : number, flagType : number, flagStyle : number)
	if (flagType == FLAGTYPE_UNIT) then
		if (flagStyle == FLAGSTYLE_MILITARY) then
			self.m_InstanceManager = m_MilitaryInstanceManager;
		elseif flagstyle == FLAGSTYLE_NAVAL then
			self.m_InstanceManager = m_NavalInstanceManager;
		elseif flagstyle == FLAGSTYLE_TRADE then
			self.m_InstanceManager = m_TradeInstanceManager;
		elseif flagstyle == FLAGSTYLE_SUPPORT then
			self.m_InstanceManager = m_SupportInstanceManager;
		else
			self.m_InstanceManager = m_CivilianInstanceManager;
		end

		self.m_Instance = self.m_InstanceManager:GetInstance();
		self.m_Type = flagType;
		self.m_Style = flagStyle;

		self.m_IsInitialized = false;
		self.m_IsSelected = false;
		self.m_IsCurrentlyVisible = false;
		self.m_IsForceHide = false;
		self.m_IsDimmed = false;
		self.m_OverrideDimmed = false;
		self.m_FogState = 0;
    
		self.m_Player = Players[playerID];
		self.m_UnitID = unitID;

		self:SetFlagUnitEmblem();
		self:SetColor();
		self:SetInteractivity();
		self:UpdateFlagType();
		self:UpdateHealth();
		self:UpdateName();
		self:UpdateReligion();
		self:UpdatePosition();
	    self:UpdateVisibility();
		self:UpdateStats();
		if( playerID == Game.GetLocalPlayer() ) then
			self:UpdateReadyState();
		end
		self:UpdateDimmedState();

		self.m_IsInitialized = true;
	end
end


-- ===========================================================================
function OnUnitFlagClick( playerID : number, unitID : number )
	local pPlayer = Players[playerID];
	if (pPlayer == nil) then
		return;
	end

	if m_isMapDeselectDisabled then
		return;
	end
		
	-- Only allow a unit selection when in one of the following modes:
	local interfaceMode:number = UI.GetInterfaceMode();
	if interfaceMode ~= InterfaceModeTypes.SELECTION and interfaceMode ~= InterfaceModeTypes.MAKE_TRADE_ROUTE and interfaceMode ~= InterfaceModeTypes.SPY_CHOOSE_MISSION and interfaceMode ~= InterfaceModeTypes.SPY_TRAVEL_TO_CITY and interfaceMode ~= InterfaceModeTypes.VIEW_MODAL_LENS then
		return;
	end

	local pUnit = pPlayer:GetUnits():FindID(unitID);
	if (pUnit == nil ) then
		print("Player clicked a unit flag for unit '"..tostring(unitID).."' but that unit doesn't exist.");
		Controls.PanelTop:ForceAnAssertDueToAboveCondition();
		return;
	end

	if ( Game.GetLocalPlayer() ~= pUnit:GetOwner() ) then

		-- Enemy unit; this may start an attack...
		-- Does player have a selected unit?
		local pSelectedUnit = UI.GetHeadSelectedUnit();
		if ( pSelectedUnit ~= nil ) then
			local tParameters = {};
			tParameters[UnitOperationTypes.PARAM_X] = pUnit:GetX();
			tParameters[UnitOperationTypes.PARAM_Y] = pUnit:GetY();
			tParameters[UnitOperationTypes.PARAM_MODIFIERS] = UnitOperationMoveModifiers.ATTACK;
			if (UnitManager.CanStartOperation( pSelectedUnit, UnitOperationTypes.RANGE_ATTACK, nil, tParameters) ) then
				UnitManager.RequestOperation(pSelectedUnit, UnitOperationTypes.RANGE_ATTACK, tParameters);
			elseif (UnitManager.CanStartOperation( pSelectedUnit, UnitOperationTypes.MOVE_TO, nil, tParameters) ) then
				UnitManager.RequestOperation(pSelectedUnit, UnitOperationTypes.MOVE_TO, tParameters);
			end
		end		
	else	
		-- Player's unit; show info:
		UI.DeselectAllUnits();
		UI.DeselectAllCities();
		UI.SelectUnit( pUnit );
	end
end

------------------------------------------------------------------
-- Set the user interativity for the flag.
function UnitFlag.SetInteractivity( self )

    local localPlayerID :number = Game.GetLocalPlayer();
    local flagPlayerID	:number = self.m_Player:GetID();
	local unitID		:number = self.m_UnitID;
        			

    self.m_Instance.NormalButton:SetVoid1( flagPlayerID );
    self.m_Instance.NormalButton:SetVoid2( unitID );
    self.m_Instance.NormalButton:RegisterCallback( Mouse.eLClick, OnUnitFlagClick );
    -- self.m_Instance.NormalButton:RegisterCallback( Mouse.eMouseEnter, UnitFlagEnter );
    -- self.m_Instance.NormalButton:RegisterCallback( Mouse.eMouseExit, UnitFlagExit );
            
    self.m_Instance.HealthBarButton:SetVoid1( flagPlayerID );
    self.m_Instance.HealthBarButton:SetVoid2( unitID );
    self.m_Instance.HealthBarButton:RegisterCallback( Mouse.eLClick, OnUnitFlagClick );
    -- self.m_Instance.HealthBarButton:RegisterCallback( Mouse.eMouseEnter, UnitFlagEnter );
    -- self.m_Instance.HealthBarButton:RegisterCallback( Mouse.eMouseExit, UnitFlagExit );		
		
	-- Off of the root flag set callbacks to let other UI pieces know that it's focus.
	-- This cannot be done on the buttons because enemy flags are disabled and some
	-- UI (e.g., CombatPreview) may want to query this.
	self.m_Instance.FlagRoot:RegisterMouseEnterCallback( 
		function()
			LuaEvents.UnitFlagManager_PointerEntered( flagPlayerID, unitID ); 
		end );
	
	self.m_Instance.FlagRoot:RegisterMouseExitCallback(	 
		function() 
			LuaEvents.UnitFlagManager_PointerExited( flagPlayerID, unitID ); 
		end);

end

------------------------------------------------------------------
function UnitFlag.UpdateReadyState( self )
	local pUnit : table = self:GetUnit();
	if (pUnit ~= nil and pUnit:IsHuman()) then
		self:SetDim(not pUnit:IsReadyToSelect());
	end
end

------------------------------------------------------------------
function UnitFlag.UpdateStats( self )
	local pUnit : table = self:GetUnit();
	if (pUnit ~= nil) then
		self:UpdateFlagType();
		self:UpdateHealth();
		self:UpdatePromotions();
		self:UpdateAircraftCounter();
	end
end

------------------------------------------------------------------
function UnitFlag.UpdateAircraftCounter( self )
	local pUnit : table = self:GetUnit();
	if (pUnit ~= nil) then
		local airUnitCapacity = pUnit:GetAirSlots();
		if airUnitCapacity > 0 then
			-- Clear previous list entries
			self.m_Instance.UnitListPopup:ClearEntries();

			-- Set max capacity
			self.m_Instance.MaxAirUnitCount:SetText(airUnitCapacity);

			local bHasAirUnits, tAirUnits = pUnit:GetAirUnits();
			if (bHasAirUnits and tAirUnits ~= nil) then
				-- Set current capacity
				local numAirUnits = table.count(tAirUnits);
				self.m_Instance.CurrentAirUnitCount:SetText(numAirUnits);

				-- Update unit instances in unit list
				for i,unit in ipairs(tAirUnits) do
					local unitEntry:table = {};
					self.m_Instance.UnitListPopup:BuildEntry( "UnitListEntry", unitEntry );

					-- Update name
					unitEntry.UnitName:SetText( Locale.ToUpper(unit:GetName()) );

					-- Update icon
					local iconInfo:table, iconShadowInfo:table = GetUnitIcon(unit, 22, true);
					if iconInfo.textureSheet then
						unitEntry.UnitTypeIcon:SetTexture( iconInfo.textureOffsetX, iconInfo.textureOffsetY, iconInfo.textureSheet );
					end

					-- Update callback
					unitEntry.Button:RegisterCallback( Mouse.eLClick, OnUnitSelected );
					unitEntry.Button:SetVoid1(unit:GetOwner());
					unitEntry.Button:SetVoid2(unit:GetID());

					-- Fade out the button icon and text if the unit is not able to move
					if unit:IsReadyToMove() then
						unitEntry.UnitName:SetAlpha(1.0);
						unitEntry.UnitTypeIcon:SetAlpha(1.0);
					else
						unitEntry.UnitName:SetAlpha(ALPHA_DIM);
						unitEntry.UnitTypeIcon:SetAlpha(ALPHA_DIM);
					end
				end

				-- If current air unit count is 0 then disabled popup
				if numAirUnits <= 0 then
					self.m_Instance.UnitListPopup:SetDisabled(true);
				else
					self.m_Instance.UnitListPopup:SetDisabled(false);
				end

				self.m_Instance.UnitListPopup:CalculateInternals();

				-- Adjust the scroll panel offset so stack is centered whether scrollbar is visible or not
				local scrollPanel = self.m_Instance.UnitListPopup:GetScrollPanel();
				if scrollPanel then
					if scrollPanel:GetScrollBar():IsHidden() then
						scrollPanel:SetOffsetX(0);
					else
						scrollPanel:SetOffsetX(7);
					end
				end
		
				self.m_Instance.UnitListPopup:ReprocessAnchoring();
				self.m_Instance.UnitListPopup:GetGrid():ReprocessAnchoring();
			else
				-- Set current capacity to 0
				self.m_Instance.CurrentAirUnitCount:SetText(0);
			end

			-- Update air unit list button colors

			-- Show air unit list
			self.m_Instance.AirUnitContainer:SetHide(false);
		else
			-- Hide air unit list since none can be stationed here
			self.m_Instance.AirUnitContainer:SetHide(true);
		end
	end
end

-- ===========================================================================
function OnUnitSelected( playerID:number, unitID:number )
	local playerUnits:table = Players[playerID]:GetUnits();
	if playerUnits then
		local selectedUnit:table = playerUnits:FindID(unitID);
		if selectedUnit then
			UI.SelectUnit( selectedUnit );
		end
	end
end

------------------------------------------------------------------
-- Set the flag color based on the player colors.
function UnitFlag.SetColor( self )
	local primaryColor, secondaryColor  = UI.GetPlayerColors( self.m_Player:GetID() );
	local darkerFlagColor	:number = DarkenLightenColor(primaryColor,(-85),255);
	local brighterFlagColor :number = DarkenLightenColor(primaryColor,90,255);
	local brighterIconColor :number = DarkenLightenColor(secondaryColor,20,255);
	local darkerIconColor	:number = DarkenLightenColor(secondaryColor,-30,255);
        
	self.m_Instance.FlagBase:SetColor( primaryColor );
	self.m_Instance.UnitIcon:SetColor( brighterIconColor );
	self.m_Instance.FlagBaseOutline:SetColor( primaryColor );
	self.m_Instance.FlagBaseDarken:SetColor( darkerFlagColor );
	self.m_Instance.FlagBaseLighten:SetColor( primaryColor );

	self.m_Instance.FlagOver:SetColor( brighterFlagColor );
	self.m_Instance.NormalSelect:SetColor( brighterFlagColor );
	self.m_Instance.NormalSelectPulse:SetColor( brighterFlagColor );
	self.m_Instance.HealthBarSelect:SetColor( primaryColor );

	-- Set air unit list button color
	self.m_Instance.AirUnitListButton_Base:SetColor( primaryColor );
	self.m_Instance.AirUnitListButton_Darker:SetColor( darkerFlagColor );
	self.m_Instance.AirUnitListButton_Lighter:SetColor( brighterFlagColor );
	self.m_Instance.AirUnitListButton_None:SetColor( primaryColor );
	self.m_Instance.AirUnitListButtonIcon:SetColor( secondaryColor );
end

------------------------------------------------------------------
-- Set the flag texture based on the unit's type
function UnitFlag.SetFlagUnitEmblem( self )      
	local icon:string = nil;
	local pUnit:table = self:GetUnit();
	local individual:number = pUnit:GetGreatPerson():GetIndividual();
	if individual >= 0 then
		local individualType:string = GameInfo.GreatPersonIndividuals[individual].GreatPersonIndividualType;
		local iconModifier:table = GameInfo.GreatPersonIndividualIconModifiers[individualType];
		if iconModifier then
			icon = iconModifier.OverrideUnitIcon;
		end 
	end
	if not icon then
		icon = "ICON_"..GameInfo.Units[pUnit:GetUnitType()].UnitType;
	end
	self.m_Instance.UnitIcon:SetIcon(icon);
end

------------------------------------------------------------------
function UnitFlag.SetDim( self, bDim : boolean )
	if (self.m_IsDimmed ~= bDim) then
		self.m_IsDimmed = bDim;
		self:UpdateDimmedState();
	end
end

-----------------------------------------------------------------
-- Set whether or not the dimmed state for the flag is overridden
function UnitFlag.OverrideDimmed( self, bOverride : boolean )
	self.m_OverrideDimmed = bOverride;
    self:UpdateDimmedState();
end
     
-----------------------------------------------------------------
-- Set the flag's alpha state, based on the current dimming flags.
function UnitFlag.UpdateDimmedState( self )
	if( self.m_IsDimmed and not self.m_OverrideDimmed ) then
		self.m_Instance.FlagRoot:SetToEnd(true);
        self.m_Instance.FlagRoot:SetAlpha( ALPHA_DIM );
        self.m_Instance.HealthBar:SetAlpha( 1.0 / ALPHA_DIM ); -- Health bar doesn't get dimmed, else it is too hard to see.
	else
        self.m_Instance.FlagRoot:SetAlpha( 1.0 );
        self.m_Instance.HealthBar:SetAlpha( 1.0 );            
    end
end


------------------------------------------------------------------
-- Change the flag's fog state
function UnitFlag.SetFogState( self, fogState : number )

	self.m_eVisibility = fogState;

    if (fogState ~= RevealedState.VISIBLE) then
		self:SetHide( true );
    else
		self:SetHide( false );
    end
        
    self.m_FogState = fogState;
end

------------------------------------------------------------------
-- Change the flag's overall visibility
function UnitFlag.SetHide( self, bHide : boolean )
	local isPreviouslyVisible :boolean = self.m_IsCurrentlyVisible;
	self.m_IsCurrentlyVisible = not bHide;
	if self.m_IsCurrentlyVisible ~= isPreviouslyVisible then
		self:UpdateVisibility();
	end
end

------------------------------------------------------------------
-- Change the flag's force hide
function UnitFlag.SetForceHide( self, bHide : boolean )
	self.m_IsForceHide = bHide;
	self:UpdateVisibility();
end

------------------------------------------------------------------
-- Update the flag's type.  This adjust the look of the flag based
-- on the state of the unit.
function UnitFlag.UpdateFlagType( self )
            
	local pUnit = self:GetUnit();
    if pUnit == nil then
		return;
	end	
	
    local textureName:string;
    local maskName:string;
			
	-- Make this more data driven.  It would be nice to have it so any state the unit could be in could have its own look.		
    if( pUnit:IsEmbarked() ) then 
        textureName = TEXTURE_EMBARK;
        maskName	= TEXTURE_MASK_EMBARK;
    elseif( pUnit:GetFortifyTurns() > 0 ) then
		textureName = TEXTURE_FORTIFY;
		maskName	= TEXTURE_MASK_FORTIFY;
    elseif( self.m_Style == FLAGSTYLE_CIVILIAN ) then
        textureName = TEXTURE_CIVILIAN;
        maskName	= TEXTURE_MASK_CIVILIAN;
	elseif( self.m_Style == FLAGSTYLE_RELIGION ) then
        textureName = TEXTURE_RELIGION;
        maskName	= TEXTURE_MASK_RELIGION;
	elseif( self.m_Style == FLAGSTYLE_NAVAL) then
		textureName = TEXTURE_NAVAL;
        maskName	= TEXTURE_MASK_NAVAL;
	elseif( self.m_Style == FLAGSTYLE_SUPPORT) then
		textureName = TEXTURE_SUPPORT;
        maskName	= TEXTURE_MASK_SUPPORT;
	elseif( self.m_Style == FLAGSTYLE_TRADE) then
		textureName = TEXTURE_TRADE;
        maskName	= TEXTURE_MASK_TRADE;
	else
        textureName = TEXTURE_BASE;
        maskName	= TEXTURE_MASK_BASE;
    end
             
        
	self.m_Instance.FlagBaseDarken:SetTexture( textureName );
	self.m_Instance.FlagBaseLighten:SetTexture( textureName );
    self.m_Instance.FlagShadow:SetTexture( textureName );
    self.m_Instance.FlagBase:SetTexture( textureName );
    self.m_Instance.FlagBaseOutline:SetTexture( textureName );
	self.m_Instance.NormalSelectPulse:SetTexture( textureName );
    self.m_Instance.NormalSelect:SetTexture( textureName );
	self.m_Instance.FlagOver:SetTexture( textureName );
	self.m_Instance.FlagOverHealthBar:SetTexture( textureName );
    self.m_Instance.HealthBarSelect:SetTexture( textureName );
    self.m_Instance.LightEffect:SetTexture( textureName );
    self.m_Instance.HealthBarBG:SetTexture( textureName );
    --self.m_Instance.NormalAlphaAnim:SetTexture( textureName );
    --self.m_Instance.HealthBarAlphaAnim:SetTexture( textureName );
        
   self.m_Instance.NormalScrollAnim:SetMask( maskName );
    --self.m_Instance.HealthBarScrollAnim:SetMask( maskName );
end

------------------------------------------------------------------
-- Update the health bar.
function UnitFlag.UpdateHealth( self )
    
	local pUnit = self:GetUnit();
    if pUnit == nil then
		return;
	end	
			
    local healthPercent = 0;
	local maxDamage = pUnit:GetMaxDamage();
	if (maxDamage > 0) then		
		healthPercent = math.max( math.min( (maxDamage - pUnit:GetDamage()) / maxDamage, 1 ), 0 );
    end

    -- going to damaged state
    if( healthPercent < 1 ) then
        -- show the bar and the button anim
        self.m_Instance.HealthBarBG:SetHide( false );
        self.m_Instance.HealthBar:SetHide( false );
        self.m_Instance.HealthBarButton:SetHide( false );
                    
        -- hide the normal button
        self.m_Instance.NormalButton:SetHide( true );
            
        -- handle the selection indicator    
        if ( self.m_IsSelected ) then
            self.m_Instance.NormalSelect:SetHide( true );
            self.m_Instance.HealthBarSelect:SetHide( false );
        end
                    
        if ( healthPercent >= 0.8 ) then
            self.m_Instance.HealthBar:SetColor( COLOR_GREEN );
        elseif( healthPercent > 0.4 and healthPercent < .8) then
            self.m_Instance.HealthBar:SetColor( COLOR_YELLOW );
        else
            self.m_Instance.HealthBar:SetColor( COLOR_RED );
        end
            
    --------------------------------------------------------------------    
    -- going to full health
    else
        self.m_Instance.HealthBar:SetColor( COLOR_GREEN );
            
        -- hide the bar and the button anim
        self.m_Instance.HealthBarBG:SetHide( true );
        self.m_Instance.HealthBarButton:SetHide( true );
        
        -- show the normal button
        self.m_Instance.NormalButton:SetHide( false );
        
        -- handle the selection indicator    
        if ( self.m_IsSelected ) then
            self.m_Instance.NormalSelect:SetHide( false );
            self.m_Instance.HealthBarSelect:SetHide( true );
        end
    end
        
    self.m_Instance.HealthBar:SetPercent( healthPercent );
end

------------------------------------------------------------------
-- Update the visibility of the flag based on the current state.
function UnitFlag.UpdateVisibility( self )

	if self.m_IsForceHide then
		self.m_Instance.Anchor:SetHide(true);
	else
		self.m_Instance.Anchor:SetHide(false);

		if self.m_IsCurrentlyVisible then
			self.m_Instance.FlagRoot:ClearEndCallback();

			if( self.m_IsDimmed and not self.m_OverrideDimmed ) then
				self.m_Instance.FlagRoot:SetToEnd();
		        self.m_Instance.FlagRoot:SetAlpha( ALPHA_DIM );
			else
				-- Fade in (show)
				self.m_Instance.FlagRoot:SetToBeginning();
				self.m_Instance.FlagRoot:Play();
			end
		else
			-- Fade out (hide)
			-- One case where a unit flag is first created, if this check isn't done 
			-- it will pop into existance and then immediately fade out in the FOW.
			if self.m_IsInitialized then
				self.m_Instance.FlagRoot:RegisterEndCallback(function() self.m_Instance.Anchor:SetHide(not self.m_IsCurrentlyVisible); end);
				self.m_Instance.FlagRoot:SetToEnd();
				self.m_Instance.FlagRoot:Reverse();
			else				
				self.m_Instance.Anchor:SetHide(true);
			end
			self.m_Instance.Formation3:SetHide(true);
			self.m_Instance.Formation2:SetHide(true);
		end
	end

end

------------------------------------------------------------------
function GetLevyTurnsRemaining(pUnit : table)
	if (pUnit ~= nil) then
		if (pUnit:GetCombat() > 0) then
			local iOwner = pUnit:GetOwner();
			local iOriginalOwner = pUnit:GetOriginalOwner();
			if (iOwner ~= iOriginalOwner) then
				local pOriginalOwner = Players[iOriginalOwner];
				if (pOriginalOwner ~= nil and pOriginalOwner:GetInfluence() ~= nil) then
					local iLevyTurnCounter = pOriginalOwner:GetInfluence():GetLevyTurnCounter();
					if (iLevyTurnCounter >= 0 and iOwner == pOriginalOwner:GetInfluence():GetSuzerain()) then
						return (pOriginalOwner:GetInfluence():GetLevyTurnLimit() - iLevyTurnCounter);
					end
				end
			end
		end
	end
	return -1;
end

------------------------------------------------------------------
function UnitFlag.UpdatePromotions( self )
	self.m_Instance.Promotion_Flag:SetHide(true);
	local pUnit : table = self:GetUnit();
	if pUnit ~= nil then
		-- If this unit is levied (ie. from a city-state), showing that takes precedence
		local iLevyTurnsRemaining = GetLevyTurnsRemaining(pUnit);
		if (iLevyTurnsRemaining >= 0) then
			self.m_Instance.UnitNumPromotions:SetText("[ICON_Turn]");
			self.m_Instance.Promotion_Flag:SetHide(false);
		-- Otherwise, show the experience level
		else
			local unitExperience = pUnit:GetExperience();
			if (unitExperience ~= nil) then
				local promotionList :table = unitExperience:GetPromotions();
				if (#promotionList > 0) then
					--[[
					local tooltipString :string = "";
					for i, promotion in ipairs(promotionList) do
						tooltipString = tooltipString .. Locale.Lookup(GameInfo.UnitPromotions[promotion].Name);
						if (i < #promotionList) then
							tooltipString = tooltipString .. "[NEWLINE]";
						end
					end
					self.m_Instance.Promotion_Flag:SetToolTipString(tooltipString);
					--]]
					self.m_Instance.UnitNumPromotions:SetText(#promotionList);
					self.m_Instance.Promotion_Flag:SetHide(false);
				end
			end
		end
	end
end

------------------------------------------------------------------
-- Update the unit religion indicator icon
function UnitFlag.UpdateReligion( self )
	local pUnit : table = self:GetUnit();
	if pUnit ~= nil then
		local religionType = pUnit:GetReligionType();
		if (religionType > 0 and pUnit:GetReligiousStrength() > 0) then
			local religion:table = GameInfo.Religions[religionType];
			local religionIcon:string = "ICON_" .. religion.ReligionType;
			local religionColor:number = UI.GetColorValue(religion.Color);

			self.m_Instance.ReligionIcon:SetIcon(religionIcon);
			self.m_Instance.ReligionIcon:SetColor(religionColor);
			self.m_Instance.ReligionIconBacking:LocalizeAndSetToolTip(religion.Name);
			self.m_Instance.ReligionIconBacking:SetHide(false);
		else
			self.m_Instance.ReligionIconBacking:SetHide(true);
		end
	end
end

------------------------------------------------------------------
-- Update the unit name / tooltip
function UnitFlag.UpdateName( self )
	local pUnit : table = self:GetUnit();
	if pUnit ~= nil then
		local unitName = pUnit:GetName();
		local pPlayerCfg = PlayerConfigurations[ self.m_Player:GetID() ];
		local nameString : string;
		if(GameConfiguration.IsAnyMultiplayer() and pPlayerCfg:IsHuman()) then
			nameString = Locale.Lookup( pPlayerCfg:GetCivilizationShortDescription() ) .. " (" .. Locale.Lookup(pPlayerCfg:GetPlayerName()) .. ") - " .. Locale.Lookup( unitName );
		else
			nameString = Locale.Lookup( pPlayerCfg:GetCivilizationShortDescription() ) .. " - " .. Locale.Lookup( unitName );
		end

		-- display military formation indicator(s)
		-- GCO <<<<<
		--[[
		local militaryFormation = pUnit:GetMilitaryFormation();
		if self.m_Style == FLAGSTYLE_NAVAL then
			if (militaryFormation == MilitaryFormationTypes.CORPS_FORMATION) then
				nameString = nameString .. TXT_UNITFLAG_FLEET_SUFFIX;
			elseif (militaryFormation == MilitaryFormationTypes.ARMY_FORMATION) then
				nameString = nameString .. TXT_UNITFLAG_ARMADA_SUFFIX;
			end	
		else
			if (militaryFormation == MilitaryFormationTypes.CORPS_FORMATION) then
				nameString = nameString .. TXT_UNITFLAG_CORPS_SUFFIX;
			elseif (militaryFormation == MilitaryFormationTypes.ARMY_FORMATION) then
				nameString = nameString .. TXT_UNITFLAG_ARMY_SUFFIX;
			end
		end
		--]]
		GCO.AttachUnitFunctions(pUnit)
		nameString = nameString .. " " ..Locale.Lookup(pUnit:GetMilitaryFormationTypeName())
		
		local militaryFormationString = pUnit:GetMilitaryFormationSizeString();
		if string.len(militaryFormationString) > 0 then
			self.m_Instance.CorpsMarker:SetHide(true);
			self.m_Instance.MilitaryFormationMarker:SetHide(false);
			self.m_Instance.MilitaryFormationString:SetText(militaryFormationString)
		else
			self.m_Instance.CorpsMarker:SetHide(true);
			self.m_Instance.ArmyMarker:SetHide(true);
		end	
		
		local activeTurnsLeft = pUnit:GetProperty("ActiveTurnsLeft")
		if activeTurnsLeft then
			self.m_Instance.ActiveTurnsLeft:SetHide(false);
			self.m_Instance.ActiveTurnsLeftString:SetText("[ICON_Turn]")
			local toolTipString = Locale.Lookup("LOC_UNITFLAG_TURNS_LEFT_BEFORE_DISBANDING", activeTurnsLeft)
			if pUnit:GetProperty("UnitPersonnelType") == UnitPersonnelType.Conscripts then
				local player = GCO.GetPlayer(pUnit:GetOwner())
				if player:IsAtWar() then
					toolTipString = Locale.Lookup("LOC_UNITFLAG_DISBANDING_LOCKED_BY_WAR", activeTurnsLeft)
				elseif activeTurnsLeft >= 0 then
					--self.m_Instance.ActiveTurnsLeftString:SetText(tostring(activeTurnsLeft).."[ICON_Turn]")
					--self.m_Instance.ActiveTurnsLeftString:SetText("[ICON_Turn]")
					--self.m_Instance.ActiveTurnsLeftString:SetToolTipString(tostring(activeTurnsLeft).."[ICON_Turn] before disbanding")
				else
					--self.m_Instance.ActiveTurnsLeftString:SetText("[COLOR_Civ6DarkRed]"..tostring(activeTurnsLeft).."[ENDCOLOR][ICON_Turn]")
					self.m_Instance.ActiveTurnsLeftString:SetText("[ICON_Disbanding]")
					--self.m_Instance.ActiveTurnsLeftString:SetToolTipString("Disbanding since [COLOR_Civ6DarkRed]"..tostring(-activeTurnsLeft).."[ENDCOLOR][ICON_Turn] turns")
					toolTipString = Locale.Lookup("LOC_UNITFLAG_CURRENTLY_DISBANDING", -activeTurnsLeft)
				end
			end
			self.m_Instance.ActiveTurnsLeftString:SetToolTipString(toolTipString)
			
		else
			self.m_Instance.ActiveTurnsLeft:SetHide(true);
		end	
		-- GCO >>>>>

		-- DEBUG TEXT FOR SHOWING UNIT ACTIVITY TYPE
		--[[
		local activityType = UnitManager.GetActivityType(pUnit);
		if (activityType == ActivityTypes.ACTIVITY_SENTRY) then
			nameString = nameString .. TXT_UNITFLAG_ACTIVITY_ON_SENTRY;
		elseif (activityType == ActivityTypes.ACTIVITY_INTERCEPT) then
			nameString = nameString .. TXT_UNITFLAG_ACTIVITY_ON_INTERCEPT;
		elseif (activityType == ActivityTypes.ACTIVITY_AWAKE) then
			nameString = nameString .. TXT_UNITFLAG_ACTIVITY_AWAKE;
		elseif (activityType == ActivityTypes.ACTIVITY_HOLD) then
			nameString = nameString .. TXT_UNITFLAG_ACTIVITY_HOLD;
		elseif (activityType == ActivityTypes.ACTIVITY_SLEEP) then
			nameString = nameString .. TXT_UNITFLAG_ACTIVITY_SLEEP;
		elseif (activityType == ActivityTypes.ACTIVITY_HEAL) then
			nameString = nameString .. TXT_UNITFLAG_ACTIVITY_HEALING;
		elseif (activityType == ActivityTypes.NO_ACTIVITY) then
			nameString = nameString .. TXT_UNITFLAG_ACTIVITY_NO_ACTIVITY;
		end
		]]--

		-- display archaeology info
		local idArchaeologyHomeCity = pUnit:GetArchaeologyHomeCity();
		if (idArchaeologyHomeCity ~= 0) then
			local pCity = self.m_Player:GetCities():FindID(idArchaeologyHomeCity);
			if (pCity ~= nil) then
				nameString = nameString .. "[NEWLINE]" .. Locale.Lookup("LOC_UNITFLAG_ARCHAEOLOGY_HOME_CITY", pCity:GetName());
				local iGreatWorkIndex = pUnit:GetGreatWorkIndex();
				if (iGreatWorkIndex >= 0) then
					local eGWType = Game.GetGreatWorkType(iGreatWorkIndex);
					local eGWPlayer = Game.GetGreatWorkPlayer(iGreatWorkIndex);
					nameString = nameString .. "[NEWLINE]" .. Locale.Lookup("LOC_UNITFLAG_ARCHAEOLOGY_ARTIFACT", GameInfo.GreatWorks[eGWType].Name, PlayerConfigurations[eGWPlayer]:GetPlayerName());
				end
			end
		end

		-- display religion info
		if (pUnit:GetReligiousStrength() > 0) then
			local eReligion = pUnit:GetReligionType();
			if (eReligion > 0) then
				nameString = nameString .. " (" .. Game.GetReligion():GetName(eReligion) .. ")";
			end
		end

		-- display levy status
		local iLevyTurnsRemaining = GetLevyTurnsRemaining(pUnit);
		if (iLevyTurnsRemaining >= 0 and PlayerConfigurations[pUnit:GetOriginalOwner()] ~= nil) then
			nameString = nameString .. "[NEWLINE]" .. Locale.Lookup("LOC_UNITFLAG_LEVY_ACTIVE", PlayerConfigurations[pUnit:GetOriginalOwner()]:GetPlayerName(), iLevyTurnsRemaining);
		end

		-- GCO <<<<<
		local unitKey 	= pUnit:GetKey()
		local unitData 	= ExposedMembers.UnitData[unitKey]
		local unitType 	= pUnit:GetUnitType()
		local unitInfo 	= GameInfo.Units[unitType]
		
		if unitData then
		
			local frontlineStrTitle = Locale.Lookup("LOC_UNITFLAG_ANCIENT_FRONTLINE_TITLE")
			local reserveStrTitle 	= Locale.Lookup("LOC_UNITFLAG_ANCIENT_RESERVE_TITLE")
			local rearStrTitle 		= Locale.Lookup("LOC_UNITFLAG_ANCIENT_REAR_TITLE")
			local era = self.m_Player:GetEra()
			if era >= GameInfo.Eras["ERA_INDUSTRIAL"].Index then
				frontlineStrTitle 	= Locale.Lookup("LOC_UNITFLAG_FRONTLINE_TITLE")
				reserveStrTitle 	= Locale.Lookup("LOC_UNITFLAG_RESERVE_TITLE")
				rearStrTitle 		= Locale.Lookup("LOC_UNITFLAG_REAR_TITLE")			
			end
		
			-- Condition
			nameString = nameString .. "[NEWLINE]" .. Locale.Lookup("LOC_UNITFLAG_MORALE_TITLE")
			nameString = nameString .. "[NEWLINE]" .. pUnit:GetMoraleString()
			nameString = nameString .. "[NEWLINE][ICON_AntiPersonnel]" .. GCO.Round(pUnit:GetPropertyPercent("AntiPersonnel")) .. "[COLOR_Grey]--[ENDCOLOR][ICON_PersonnelArmor]" .. GCO.Round(pUnit:GetPropertyPercent("PersonnelArmor")) .. "[COLOR_Grey]--[ENDCOLOR][ICON_AntiArmor]" .. GCO.Round(pUnit:GetPropertyPercent("AntiPersonnelArmor")) .. "[COLOR_Grey]--[ENDCOLOR][ICON_IgnorArmor]" .. GCO.Round(pUnit:GetPropertyPercent("IgnorePersonnelArmor")) .. " "
			if pUnit:GetLogisticCost() > 0 then
				nameString = nameString .. "[NEWLINE]" .. Locale.Lookup("LOC_UNITFLAG_LOGISTIC_COST", pUnit:GetLogisticCost())
			end
			
			--local bHasComponents = (unitInfo.Personnel + unitInfo.Equipment + unitInfo.Horses + unitInfo.Materiel > 0)
			local personnel = pUnit:GetComponent("Personnel")
			local bHasComponents = personnel > 0
			if bHasComponents then
				
				-- "Frontline"
				nameString = nameString .. "[NEWLINE]" .. frontlineStrTitle
				nameString = nameString .. "[NEWLINE]" .. Locale.Lookup("LOC_UNITFLAG_PERSONNEL", personnel, pUnit:GetMaxFrontLinePersonnel()) .. GCO.GetVariationString(pUnit:GetComponentVariation("Personnel"))
				nameString = nameString .. pUnit:GetFrontLineEquipmentString()

				local bestUnitType, percentageStr = pUnit:GetTypesFromEquipmentList()
				if bestUnitType and (bestUnitType ~= unitType) then 
					nameString = nameString .. "[NEWLINE]" .. Locale.Lookup("LOC_UNITFLAG_PENDING_TYPE_CHANGE", GameInfo.Units[bestUnitType].Name) -- Locale.Lookup(GameInfo.Units[bestUnitType].Name))
				end
				if percentageStr then
					nameString = nameString .. "[NEWLINE]" .. percentageStr
				end
				
				-- "Reserve" (show even when = 0 if it's a component required in front line)
				local reserveStr = ""
				nameString = nameString .. "[NEWLINE]" .. reserveStrTitle
				if pUnit:GetComponent("PersonnelReserve") 	> 0 then reserveStr = reserveStr .. "[NEWLINE]" .. Locale.Lookup("LOC_UNITFLAG_PERSONNEL_RESERVE", pUnit:GetComponent("PersonnelReserve")) .. GCO.GetVariationString(pUnit:GetComponentVariation("PersonnelReserve")) end
				reserveStr = reserveStr .. pUnit:GetReserveEquipmentString()
				--if unitInfo.Horses 		> 0 or unitData.HorsesReserve > 0 then nameString = nameString .. "[NEWLINE]" .. Locale.Lookup("LOC_UNITFLAG_HORSES_RESERVE", unitData.HorsesReserve) .. GCO.GetVariationString(pUnit:GetComponentVariation("HorsesReserve")) end
				--if unitInfo.Materiel 	> 0 then nameString = nameString .. "[NEWLINE]" .. Locale.Lookup("LOC_UNITFLAG_MATERIEL_RESERVE", unitData.MaterielReserve) .. GCO.GetVariationString(pUnit:GetComponentVariation("MaterielReserve")) end
				if reserveStr ~= "" then
					nameString = nameString .. reserveStr
				else
					nameString = nameString .. "[NEWLINE]" .. Locale.Lookup("LOC_UNITFLAG_EMPTY_RESERVE")
				end
			end
			
			-- "Rear"
			local totalPrisoners = GCO.GetTotalPrisoners(unitData)
			--local bHasExtra = (unitData.WoundedPersonnel + unitData.DamagedEquipment + totalPrisoners + unitData.FoodStock + unitData.FoodStock > 0)
			local bHasExtra = (unitData.WoundedPersonnel + totalPrisoners + unitData.FoodStock + unitData.FoodStock > 0)
			if bHasExtra then
				nameString = nameString .. "[NEWLINE]" .. rearStrTitle
				if unitData.WoundedPersonnel 	> 0 then nameString = nameString .. "[NEWLINE]" .. Locale.Lookup("LOC_UNITFLAG_WOUNDED_PERSONNEL", unitData.WoundedPersonnel) .. GCO.GetNeutralVariationString(pUnit:GetComponentVariation("WoundedPersonnel")) end
				--if unitData.DamagedEquipment 	> 0 then nameString = nameString .. "[NEWLINE]" .. Locale.Lookup("LOC_UNITFLAG_DAMAGED_EQUIPMENT", unitData.DamagedEquipment)  .. GCO.GetNeutralVariationString(pUnit:GetComponentVariation("DamagedEquipment"))end
				if totalPrisoners	 			> 0 then nameString = nameString .. GCO.GetPrisonersStringByCiv(unitData) end	-- "[NEWLINE]" .. Locale.Lookup("LOC_UNITFLAG_PRISONERS", totalPrisoners) .. GCO.GetPrisonersStringByCiv(unitData) end
				if unitData.FoodStock 			> 0 then nameString = nameString .. "[NEWLINE]" .. pUnit:GetFoodStockString() end
				if unitData.MedicineStock 		> 0 then nameString = nameString .. "[NEWLINE]" .. Locale.Lookup("LOC_UNITFLAG_MEDICINE_STOCK", unitData.MedicineStock)  .. GCO.GetVariationString(pUnit:GetComponentVariation("MedicineStock"))end
				if unitData.FuelStock 			> 0 then nameString = nameString .. "[NEWLINE]" .. pUnit:GetFuelStockString(unitData) end
				nameString = nameString .. pUnit:GetResourcesStockString()
			end
				
			-- Statistics
			--local bHasStatistics = (unitData.TotalDeath + unitData.TotalEquipmentLost + unitData.TotalHorsesLost > 0)
			local bHasStatistics = (unitData.TotalDeath + unitData.TotalHorsesLost > 0)				
			if bHasStatistics then
			
				nameString = nameString .. "[NEWLINE]" .. Locale.Lookup("LOC_UNITFLAG_STATS_TITLE")					
				if unitData.TotalDeath 			> 0 then nameString = nameString .. "[NEWLINE]" .. Locale.Lookup("LOC_UNITFLAG_TOTAL_DEATH", unitData.TotalDeath) end
				if unitData.TotalKill 			> 0 then nameString = nameString .. "[NEWLINE]" .. Locale.Lookup("LOC_UNITFLAG_TOTAL_KILL", unitData.TotalKill) end
				--if unitData.TotalEquipmentLost 	> 0 then nameString = nameString .. "[NEWLINE]" .. Locale.Lookup("LOC_UNITFLAG_TOTAL_EQUIPMENT_LOST", unitData.TotalEquipmentLost) end
				if unitData.TotalHorsesLost 	> 0 then nameString = nameString .. "[NEWLINE]" .. Locale.Lookup("LOC_UNITFLAG_TOTAL_HORSES_LOST", unitData.TotalHorsesLost) end
				
			end
				
			-- Unit Consumption
			local foodConsumption = pUnit:GetFoodConsumption()
			local fuelConsumption = pUnit:GetFuelConsumption()
			local bHasConsumption = ( foodConsumption + fuelConsumption > 0)				
			if bHasConsumption then
			
				nameString = nameString .. "[NEWLINE]" .. Locale.Lookup("LOC_UNITFLAG_CONSUMPTION_TITLE")
				if foodConsumption 				> 0 then nameString = nameString .. pUnit:GetFoodConsumptionString() end
				if fuelConsumption 				> 0 then nameString = nameString .. pUnit:GetFuelConsumptionString() end
				
			end	

			-- Supply Line
			--if bHasComponents then
			
				nameString = nameString .. "[NEWLINE]" .. Locale.Lookup("LOC_UNITFLAG_SUPPLY_LINE_TITLE")
				if unitData.SupplyLineCityKey then
					local city = GCO.GetCityFromKey( unitData.SupplyLineCityKey )
					if city then
						if unitData.SupplyLineEfficiency > 0 then
							nameString = nameString .. "[NEWLINE]" .. Locale.Lookup("LOC_UNITFLAG_SUPPLY_LINE_DETAILS", city:GetName(), unitData.SupplyLineEfficiency)
						else
							nameString = nameString .. "[NEWLINE]" .. Locale.Lookup("LOC_UNITFLAG_SUPPLY_LINE_TOO_FAR", city:GetName())
						end
					end
				else
					nameString = nameString .. "[NEWLINE]" .. Locale.Lookup("LOC_UNITFLAG_NO_SUPPLY_LINE")
				end
				
			--end
		end

		function ShowSupplyLine()
			if not unitData then print("WTF ??? unitData[unitkey] is nil in ShowSupplyLine for key = "..tostring(unitKey)) return end
			if not unitData.SupplyLineCityKey then return end
			--if bShownSupplyLine then return end
			UILens.SetActive("TradeRoute")
			UILens.ClearLayerHexes( LensLayers.TRADE_ROUTE )
			local pathPlots = pUnit:GetSupplyPathPlots()
			if pathPlots then
				local kVariations:table = {}
				local lastElement : number = table.count(pathPlots)
				local localPlayer = Game.GetLocalPlayer()
				if localPlayer == -1 then localPlayer = 0 end
				local localPlayerVis:table = PlayersVisibility[localPlayer]
				local destPlot = Map.GetPlotByIndex(pathPlots[lastElement])
				if Automation.IsActive() or (localPlayerVis and localPlayerVis:IsRevealed(destPlot:GetX(), destPlot:GetY())) then
					table.insert(kVariations, {"TradeRoute_Destination", pathPlots[lastElement]} )					
					local color = RGBAValuesToABGRHex(0.25, 0.25, 0.25, 0.5) --RGBAValuesToABGRHex(1, 1, 1, 1)
					UILens.SetLayerHexesPath( LensLayers.TRADE_ROUTE, localPlayer, pathPlots, kVariations, color )
					bShownSupplyLine = true
				end
			end
		end		
		--self.m_Instance.UnitIcon:RegisterMouseOverCallback( ShowSupplyLine )
		self.m_Instance.UnitIcon:RegisterMouseEnterCallback( ShowSupplyLine )
		--ShowSupplyLine()
		-- GCO >>>>>
		
		self.m_Instance.UnitIcon:SetToolTipString( Locale.Lookup(nameString) );
	end
end

------------------------------------------------------------------
-- The selection state has changed.
function UnitFlag.UpdateSelected( self, isSelected : boolean )
	local pUnit : table = self:GetUnit();
	
	--local pPlayer : table = Players[Game.GetLocalPlayer()];
	
	if (pUnit ~= nil) then
        self.m_IsSelected = isSelected;
        
        if( pUnit:GetDamage() == 0 ) then
            self.m_Instance.NormalSelect:SetHide( not self.m_IsSelected );
            self.m_Instance.HealthBarSelect:SetHide( true );
        else
            self.m_Instance.HealthBarSelect:SetHide( not self.m_IsSelected );
            self.m_Instance.NormalSelect:SetHide( true );
        end
        
		-- If selected, change our parent to the selection container so we are on top in the drawing order
       -- if( self.m_IsSelected ) then
       --     self.m_Instance.Anchor:ChangeParent( m_SelectedContainer );
       -- else
			-- Re-attach back to the manager parent            			
		--	self.m_Instance.Anchor:ChangeParent( self.m_InstanceManager.m_ParentControl );			            
        --end
        
        self:OverrideDimmed( self.m_IsSelected );

	end
end

------------------------------------------------------------------
-- Update the position of the flag to match the current unit position.
function UnitFlag.UpdatePosition( self )
	local pUnit : table = self:GetUnit();
	if (pUnit ~= nil) then
		self:SetPosition( UI.GridToWorld( pUnit:GetX(), pUnit:GetY() ) );
	end
	
	--local yOffset = 0;	--offset for 2D strategic view
	--local zOffset = 0;	--offset for 3D world view
	--
	--if (UI.GetWorldRenderView() == WorldRenderView.VIEW_2D) then
	--	yOffset = YOFFSET_2DVIEW;
	--	zOffset = 0;
	--else
	--	yOffset = 0;
	--	yOffset = -25 + m_zoomMultiplier*25;
	--	zOffset = ZOFFSET_3DVIEW;
	--end
	--
	--local worldX;
	--local worldY;
	--local worldZ;
	--
	--worldX, worldY, worldZ = UI.GridToWorld( pUnit:GetX(), pUnit:GetY() );
	--self.m_Instance.Anchor:SetWorldPositionVal( worldX, worldY+yOffset, worldZ+zOffset );

end

------------------------------------------------------------------
function CanRangeAttack(pCityOrDistrict : table)
	-- An invalid plot means we want to know if there are any locations that the city can range strike.
	return CityManager.CanStartCommand( pCityOrDistrict, CityCommandTypes.RANGE_ATTACK );
end


-- ===========================================================================
--	Returns a city object immediately left of plot, or NIL if no city there.
-- ===========================================================================
function GetCityPlotLeftOf( x:number, y:number )
	local pPlot:table = Map.GetAdjacentPlot( x, y, DirectionTypes.DIRECTION_WEST );
	if pPlot == nil then
		return nil; --This will happen in non-world-wrapping maps.
	end
	return Cities.GetCityInPlot( pPlot:GetX(), pPlot:GetY() );
end

-- ===========================================================================
--	Returns a city object immediately right of plot, or NIL if no city there.
-- ===========================================================================
function GetCityPlotRightOf( x:number, y:number )
	local pPlot:table = Map.GetAdjacentPlot( x, y, DirectionTypes.DIRECTION_EAST );
	if pPlot == nil then
		return nil; --This will happen in non-world-wrapping maps.
	end
	return Cities.GetCityInPlot( pPlot:GetX(), pPlot:GetY() );
end

-- ===========================================================================
--	Set the position of the flag.
-- ===========================================================================
function UnitFlag.SetPosition( self, worldX : number, worldY : number, worldZ : number )

	local unitStackXOffset = 0;
	local rangedAttackXOffset = 0;
	local cityBannerZOffset: number = 0;
	local cityBannerYOffset: number = 0;
	if (self ~= nil ) then
		local pUnit : table = self:GetUnit();
		if (pUnit ~= nil) then
			local unitX = pUnit:GetX();
			local unitY = pUnit:GetY();

			if unitX == -9999 or unitY == -9999 then
				UI.DataError("Unable to set a unit #"..tostring(pUnit:GetID()).." ("..tostring(pUnit:GetName())..") flag due to an invalid position: "..unitX..","..unitY);
				return;
			end

			-- If there is a city sharing the plot with the unit, "duck" the unit flag with an offset to minimize UI overlapping
			if (pUnit ~= nil) then
				local pCity				:table = Cities.GetCityInPlot( unitX, unitY );
				local pCityToTheRight	:table = GetCityPlotRightOf( unitX, unitY );
				local pCityToTheLeft	:table = GetCityPlotLeftOf( unitX, unitY );
				if (pCity ~= nil or pCityToTheRight ~= nil or pCityToTheLeft ~= nil) then
					if (pCity ~= nil) then
						-- If the city can attack, offset the unit flag icon so that we can see the ranged attack action icon
						local pDistrict : table = pCity:GetDistricts():FindID(pCity:GetDistrictID());
						if (pCity:GetOwner() == Game.GetLocalPlayer() and CanRangeAttack(pDistrict) ) then
							rangedAttackXOffset = 30 - m_zoomMultiplier*15;
						end
					end
					cityBannerZOffset = -15;
					cityBannerYOffset = m_zoomMultiplier * 25 - 25;
				end

				local pPlot:table = Map.GetPlot( unitX, unitY );
				if( pPlot ) then
					local eImprovementType :number = pPlot:GetImprovementType();
					if( eImprovementType ~= -1 ) then
						local kImprovementData : table = GameInfo.Improvements[eImprovementType];
						if ( kImprovementData.AirSlots > 0 or kImprovementData.WeaponSlots > 0) then
							cityBannerZOffset = -15;
							cityBannerYOffset = 5;
						end
					end
					local eDistrictType :number = pPlot:GetDistrictType();
					if( eDistrictType ~= -1 ) then
						if ( GameInfo.Districts[eDistrictType].DistrictType == "DISTRICT_ENCAMPMENT" ) then
							rangedAttackXOffset = -5;
							cityBannerZOffset = -15;
							cityBannerYOffset =  30;
						end
						if ( GameInfo.Districts[eDistrictType].AirSlots > 0 ) then
							cityBannerZOffset = -15;
							cityBannerYOffset = 5;
						end
					end
				end

			end
		end
	end

	local yOffset = 0;	--offset for 2D strategic view
	local zOffset = 0;	--offset for 3D world view
	local xOffset = unitStackXOffset + rangedAttackXOffset;

	if (UI.GetWorldRenderView() == WorldRenderView.VIEW_2D) then
		yOffset = 20;
		zOffset = 0;
	else
		yOffset = cityBannerYOffset;
		zOffset = 40 + cityBannerZOffset;
	end
	self.m_Instance.Anchor:SetWorldPositionVal( worldX+xOffset, worldY+yOffset, worldZ+zOffset );
end


-- ===========================================================================
--	Creates a unit flag (if one doesn't exist).
-- ===========================================================================
function CreateUnitFlag( playerID: number, unitID : number, unitX : number, unitY : number )
	-- If a flag already exists for this player/unit combo... just return.
	if (m_UnitFlagInstances[ playerID ] ~= nil and m_UnitFlagInstances[ playerID ][ unitID ] ~= nil) then
	    return;
    end

	-- Allocate a new flag.
	local pPlayer	:table = Players[playerID];
	local pUnit		:table = pPlayer:GetUnits():FindID(unitID);
	if pUnit ~= nil and pUnit:GetUnitType() ~= -1 then
		if (pUnit:GetCombat() ~= 0 or pUnit:GetRangedCombat() ~= 0) then		-- Need a simpler what to test if the unit is a combat unit or not.
			if "DOMAIN_SEA" == GameInfo.Units[pUnit:GetUnitType()].Domain then
				UnitFlag:new( playerID, unitID, FLAGTYPE_UNIT, FLAGSTYLE_NAVAL );
			else
				UnitFlag:new( playerID, unitID, FLAGTYPE_UNIT, FLAGSTYLE_MILITARY );
			end
		else
			if GameInfo.Units[pUnit:GetUnitType()].MakeTradeRoute then
				UnitFlag:new( playerID, unitID, FLAGTYPE_UNIT, FLAGSTYLE_TRADE );
			elseif "FORMATION_CLASS_SUPPORT" == GameInfo.Units[pUnit:GetUnitType()].FormationClass then
				UnitFlag:new( playerID, unitID, FLAGTYPE_UNIT, FLAGSTYLE_SUPPORT );
			elseif pUnit:GetReligiousStrength() > 0 then
				UnitFlag:new( playerID, unitID, FLAGTYPE_UNIT, FLAGSTYLE_RELIGION );
			else
				UnitFlag:new( playerID, unitID, FLAGTYPE_UNIT, FLAGSTYLE_CIVILIAN );
			end
		end
	end
end

-- ===========================================================================
--	Engine Event
-- ===========================================================================
function OnUnitAddedToMap( playerID: number, unitID : number, unitX : number, unitY : number )
	CreateUnitFlag( playerID, unitID, unitX, unitY );
	UpdateIconStack(unitX, unitY);
end

------------------------------------------------------------------
function OnUnitRemovedFromMap( playerID: number, unitID : number )
	
    local flagInstance = GetUnitFlag( playerID, unitID );
	if flagInstance ~= nil then
		flagInstance:destroy();
		m_UnitFlagInstances[ playerID ][ unitID ] = nil;

		local pUnit : table = flagInstance:GetUnit();
		if (pUnit ~= nil) then
			UpdateIconStack(pUnit:GetX(), pUnit:GetY());
		end

	end
	
end

------------------------------------------------------------------
function OnUnitVisibilityChanged( playerID: number, unitID : number, eVisibility : number )
    local flagInstance = GetUnitFlag( playerID, unitID );
	if (flagInstance ~= nil) then
		flagInstance:SetFogState( eVisibility );
		flagInstance:UpdatePosition();

		local pUnit : table = flagInstance:GetUnit();
		if (pUnit ~= nil) then
			UpdateIconStack(pUnit:GetX(), pUnit:GetY());
		end

    end
end

------------------------------------------------------------------
function OnUnitEmbarkedStateChanged( playerID: number, unitID : number, bEmbarkedState : boolean )
    local flagInstance = GetUnitFlag( playerID, unitID );
	if (flagInstance ~= nil) then
		flagInstance:UpdateFlagType();
    end
end

------------------------------------------------------------------
function OnUnitSelectionChanged( playerID : number, unitID : number, hexI : number, hexJ : number, hexK : number, bSelected : boolean, bEditable : boolean )
    local flagInstance = GetUnitFlag( playerID, unitID );
	if (flagInstance ~= nil) then
		flagInstance:UpdateSelected( bSelected );
    end

	if (bSelected) then
		--[[
		local pPlayer = Players[ playerID ];
		if (pPlayer ~= nil) then
			local pUnit = pPlayer:GetUnits():FindID(unitID);
			print(pUnit:GetUnitType(), hexI, hexJ);
		end
		--]]
		UpdateIconStack(hexI, hexJ);
	end
end

------------------------------------------------------------------
function OnUnitTeleported( playerID: number, unitID : number, x : number, y : number)

    local flagInstance = GetUnitFlag( playerID, unitID );
	if (flagInstance ~= nil) then
		flagInstance:UpdatePosition();

		-- Mark the unit in the dirty list, the rest of the updating will happen there.
		m_DirtyComponents:AddComponent(playerID, unitID, ComponentType.UNIT);
		UpdateIconStack(x, y);
    end

end

-------------------------------------------------
-- The position of the unit sim has changed.
-------------------------------------------------
function UnitSimPositionChanged( playerID, unitID, worldX, worldY, worldZ, bVisible, bComplete )
    local flagInstance = GetUnitFlag( playerID, unitID );

	if (flagInstance ~= nil) then
		if (bComplete) then
			local plotX, plotY = UI.GetPlotCoordFromWorld(worldX, worldY, worldZ);
			UpdateIconStack( plotX, plotY );
		end
		if( not bVisible ) then
			flagInstance.m_Instance.FlagRoot:SetToBeginning();
		end

		flagInstance:SetPosition(worldX, worldY, worldZ);
    end
end

-------------------------------------------------
-- Unit Formations
-------------------------------------------------
function OnEnterFormation(playerID1, unitID1, playerID2, unitID2)
	local pPlayer = Players[ playerID1 ];
	if (pPlayer ~= nil) then
		local pUnit = pPlayer:GetUnits():FindID(unitID1);
		if (pUnit ~= nil) then
			UpdateIconStack(pUnit:GetX(), pUnit:GetY());
		end
	end
end

-------------------------------------------------
-- Unit flag arrangement and formation visualization
-------------------------------------------------
function UpdateIconStack( plotX:number, plotY:number )
	local unitList:table = Units.GetUnitsInPlotLayerID( plotX, plotY, MapLayers.ANY );
	if unitList ~= nil then
		-- If a unit is going to die it shouldn't be counted 
		
		local numUnits:number = table.count(unitList);
		for i, pUnit in ipairs(unitList) do
			if pUnit:IsDelayedDeath() then
				numUnits = numUnits - 1; 
			elseif ShouldHideFlag(pUnit) then
				-- Don't count unit flags which will be hidden
				numUnits = numUnits - 1; 
			end
		end
		local multiSpacingX = 32;
		local landCombatOffsetX = 0;
		local civilianOffsetX =  0;
		local formationIndex = 0;
		local DuoFlag;
		for _, pUnit in ipairs(unitList) do
			-- Cache commonly used values (optimization)
			local unitID:number = pUnit:GetID();
			local unitOwner:number = pUnit:GetOwner();
			local flag = GetUnitFlag( unitOwner, unitID );

			if ( flag ~= nil and flag.m_eVisibility == RevealedState.VISIBLE ) then
				local unitInfo:table = GameInfo.Units[pUnit:GetUnitType()];

				-- Check if we should hide this units flag
				flag.m_Instance.FlagRoot:SetHide(ShouldHideFlag(pUnit));

				-- If there's more than one unit in the hex, offset their flags so they don't overlap
				local formationClassString:string = unitInfo.FormationClass;
				local iFormationCount:number = pUnit:GetFormationUnitCount();
				if(iFormationCount > 1 or numUnits > 1) then
					if ( iFormationCount < 2 ) then					
						if (formationClassString == "FORMATION_CLASS_LAND_COMBAT") then
							flag.m_Instance.FlagRoot:SetOffsetVal(landCombatOffsetX + m_FlagOffsets[1][1], m_FlagOffsets[1][2] );
							landCombatOffsetX = landCombatOffsetX - multiSpacingX;
						elseif	(formationClassString == "FORMATION_CLASS_CIVILIAN" or formationClassString == "FORMATION_CLASS_SUPPORT") then
							flag.m_Instance.FlagRoot:SetOffsetVal(civilianOffsetX + m_FlagOffsets[2][1], m_FlagOffsets[2][2]);
							civilianOffsetX = civilianOffsetX + multiSpacingX;
						elseif	(formationClassString == "FORMATION_CLASS_NAVAL") then
							flag.m_Instance.FlagRoot:SetOffsetVal(m_FlagOffsets[3][1], m_FlagOffsets[3][2]);
						elseif	(formationClassString == "FORMATION_CLASS_AIR") then
							flag.m_Instance.FlagRoot:SetOffsetVal(m_FlagOffsets[3][1], m_FlagOffsets[3][2] * -1 );
						else
							flag.m_Instance.FlagRoot:SetOffsetVal(0,0);
						end

						flag.m_Instance.Formation2:SetHide(true);
						flag.m_Instance.Formation3:SetHide(true);
					else 
						if (iFormationCount < 3) then
							flag.m_Instance.Formation2:SetHide(true);
							flag.m_Instance.Formation3:SetHide(true);
							if formationClassString ~= "FORMATION_CLASS_LAND_COMBAT" then
								if(DuoFlag and (formationClassString == "FORMATION_CLASS_CIVILIAN" or formationClassString == "FORMATION_CLASS_SUPPORT")) then
									DuoFlag.m_Instance.Formation2:SetHide(true);
								else
									flag.m_Instance.Formation2:SetHide(false);
									flag.m_Instance.Formation2:SetOffsetVal(m_LinkOffsets[1][1], m_LinkOffsets[1][2]);
									flag.m_Instance.Formation2:SetSizeX(64);
								end
								DuoFlag = flag;
							end
							
						else
							flag.m_Instance.Formation2:SetHide(true);
							flag.m_Instance.Formation3:SetHide(true);
							if formationClassString == "FORMATION_CLASS_CIVILIAN" or formationClassString == "FORMATION_CLASS_SUPPORT" then	
								flag.m_Instance.Formation3:SetHide(false);
								flag.m_Instance.Formation3:SetOffsetVal(m_LinkOffsets[2][1], m_LinkOffsets[2][2]);
								flag.m_Instance.Formation3:SetSizeX(100);
								flag.m_Instance.Formation3:SetSizeY(80);
							end	
							
						end
						
						formationIndex = formationIndex + 1;
						flag.m_Instance.FlagRoot:SetOffsetVal(m_FlagOffsets[formationIndex][1], m_FlagOffsets[formationIndex][2] );
					end

				else
					-- If there is not more than one unit remove the offset and hide the formation indicator
					flag.m_Instance.FlagRoot:SetOffsetX(0);
					flag.m_Instance.FlagRoot:SetOffsetY(0);		
					flag.m_Instance.Formation2:SetHide(true);
					flag.m_Instance.Formation3:SetHide(true);
				end

				-- Avoid name changing (per frame) as there are lots of small string allocations that will occur.
				-- The only time the name would change is if the military formation has changed.
				local militaryFormation:number = pUnit:GetMilitaryFormation();
				if flag.m_cacheMilitaryFormation ~= militaryFormation then
					if militaryFormation == MilitaryFormationTypes.CORPS_FORMATION then
						flag.m_Instance.CorpsMarker:SetHide(false);
						flag.m_Instance.ArmyMarker:SetHide(true);
					elseif militaryFormation == MilitaryFormationTypes.ARMY_FORMATION then
						flag.m_Instance.CorpsMarker:SetHide(true);
						flag.m_Instance.ArmyMarker:SetHide(false);
					else
						flag.m_Instance.CorpsMarker:SetHide(true);
						flag.m_Instance.ArmyMarker:SetHide(true);
					end
					flag.m_cacheMilitaryFormation = militaryFormation;
					flag:UpdateName();
				end

			end
		end
	end
end

---========================================
function ShouldHideFlag(pUnit:table)
	local unitInfo:table = GameInfo.Units[pUnit:GetUnitType()];
	local unitPlot:table = Map.GetPlot(pUnit:GetX(), pUnit:GetY());

	-- Cache commonly used values (optimization)
	local unitID:number = pUnit:GetID();
	local unitOwner:number = pUnit:GetOwner();

	-- If we're an air unit then check if we should hide the unit flag due to being based in a stacked tile
	local shouldHideFlag:boolean = false;

	local activityType = UnitManager.GetActivityType(pUnit);
	if (activityType == ActivityTypes.ACTIVITY_INTERCEPT) then
		return false;
	end

	if	unitInfo.Domain == "DOMAIN_AIR" then
		-- Hide air unit if we're stationed at a airstrip
		local tPlotAirUnits = unitPlot:GetAirUnits();
		if tPlotAirUnits then
			for i,unit in ipairs(tPlotAirUnits) do
				if unitOwner == unit:GetOwner() and unitID == unit:GetID() then
					shouldHideFlag = true;
				end
			end
		end

		-- Hide air unit if we're stationed at an aerodrome
		if not shouldHideFlag then
			local districtID:number = unitPlot:GetDistrictID();
			if districtID > 0 then
				local pPlayer = Players[unitOwner];
				local pDistrict = pPlayer:GetDistricts():FindID(districtID);
				local pDistrictInfo = GameInfo.Districts[pDistrict:GetType()];
				if pDistrict and not pDistrictInfo.CityCenter then
					local bHasAirUnits, tAirUnits = pDistrict:GetAirUnits();
					if (bHasAirUnits and tAirUnits ~= nil) then
						for _,unit in ipairs(tAirUnits) do
							if unitOwner == unit:GetOwner() and unitID == unit:GetID() then
								shouldHideFlag = true;
							end
						end
					end
				end
			end
		end

		-- Hide air unit if we're stationed on an aircraft carrier
		if not shouldHideFlag then
			local unitsInPlot = Units.GetUnitsInPlot(unitPlot);
			for i, unit in ipairs(unitsInPlot) do
				-- If we have any air unit slots then hide the stationed units flag
				if unit:GetAirSlots() > 0 then
					shouldHideFlag = true;
				end
			end
		end
	end

	return shouldHideFlag;
end

-------------------------------------------------
-- Zoom level calculation
-------------------------------------------------
function OnCameraUpdate( vFocusX:number, vFocusY:number, fZoomLevel:number )
	m_cameraFocusX	= vFocusX;
	m_cameraFocusY	= vFocusY;

	-- If no change in the zoom, no update necessary.
	if( math.abs( (1-fZoomLevel) - m_zoomMultiplier ) < ZOOM_MULT_DELTA ) then 
		return;
	end
	m_zoomMultiplier= 1-fZoomLevel;
	 
	if m_zoomMultiplier < 0.6 then 
		m_zoomMultiplier = 0.6; 
	end


	--Reposition flags that are near cities, since they are the only ones that can change position because of a zoom level change.

	local units = Game.GetUnits{NearCity = true};
	for i, idTable:table in pairs(units) do
		PositionFlagForUnitToView( idTable[1], idTable[2] ); 
	end
end

-- ===========================================================================
--	Game Engine Event
-- ===========================================================================
function OnPlayerTurnActivated( ePlayer:number, bFirstTimeThisTurn:boolean )

	if ePlayer == -1 then
		return;
	end

	if Players[ ePlayer ] == nil then
		return;
	end
	
	if m_UnitFlagInstances[ ePlayer ]==nil then
		return;
	end

	local idLocalPlayer = Game.GetLocalPlayer();
	if (ePlayer == idLocalPlayer and bFirstTimeThisTurn) then

		local playerFlagInstances = m_UnitFlagInstances[ idLocalPlayer ];
		for id, flag in pairs(playerFlagInstances) do
			if (flag ~= nil) then
				flag:UpdateStats();
				flag:UpdateReadyState();
			end
		end

		-- Hide all attention icons
		m_AttentionMarkerIM:ResetInstances();

		-- Iterate through barbarian units to determine if they should show an attention icon
		for _, pPlayer in ipairs(Players) do
		if pPlayer:IsBarbarian() then			
				local iPlayerID:number = pPlayer:GetID();
			local pPlayerUnits:table = pPlayer:GetUnits();

			for i, pUnit in pPlayerUnits:Members() do	
					local flag:table = GetUnitFlag(iPlayerID, pUnit:GetID());

					if flag ~= nil then
				local targetPlayer	:number		= pUnit:GetBarbarianTargetPlayer();

				if targetPlayer ~= -1 and targetPlayer == idLocalPlayer then				
							m_AttentionMarkerIM:GetInstance(flag.m_Instance.FlagRoot);
							flag.bHasAttentionMarker = true;
				else
							flag.bHasAttentionMarker = false;
					end					
				end
			end
		end
	end
end
end

------------------------------------------------------------------
function OnBarbarianSpottedCity(iPlayerID:number, iUnitID:number, cityOwner:number, cityID:number)
	local flag:table = GetUnitFlag(iPlayerID, iUnitID);

	if flag ~= nil and flag.bHasAttentionMarker ~= true then
		local pPlayer:table = Players[iPlayerID];
		local pPlayerUnits:table = pPlayer:GetUnits();
		local pUnit:table = pPlayerUnits:FindID(iUnitID);
		local targetPlayer:number = pUnit and pUnit:GetBarbarianTargetPlayer() or -1;

		if targetPlayer ~= -1 and targetPlayer == Game.GetLocalPlayer() then
			m_AttentionMarkerIM:GetInstance(flag.m_Instance.FlagRoot);
			flag.bHasAttentionMarker = true;
		end
	end
end

------------------------------------------------------------------
function OnPlayerConnectChanged(iPlayerID)
	-- When a human player connects/disconnects, their unit flag tooltips need to be updated.
	local pPlayer = Players[ iPlayerID ];
	if (pPlayer ~= nil) then
		if (m_UnitFlagInstances[ iPlayerID ] == nil) then
			return;
		end

		local playerFlagInstances = m_UnitFlagInstances[ iPlayerID ];
		for id, flag in pairs(playerFlagInstances) do
			if (flag ~= nil) then
				flag:UpdateName();
			end
		end
    end
end

------------------------------------------------------------------
function OnUnitDamageChanged( playerID : number, unitID : number, newDamage : number, oldDamage : number)
	local pPlayer = Players[ playerID ];
	if (pPlayer ~= nil) then
		local pUnit = pPlayer:GetUnits():FindID(unitID);
		if (pUnit ~= nil) then
			local flag = GetUnitFlag(playerID, pUnit:GetID());
			if (flag ~= nil) then
				flag:UpdateStats();
				if (flag.m_eVisibility == RevealedState.VISIBLE) then
					local iDelta = newDamage - oldDamage;
					local szText;
					if (iDelta < 0) then
						szText = Locale.Lookup("LOC_WORLD_UNIT_DAMAGE_DECREASE_FLOATER", -iDelta);
					else
						szText = Locale.Lookup("LOC_WORLD_UNIT_DAMAGE_INCREASE_FLOATER", -iDelta);
					end

					UI.AddWorldViewText(EventSubTypes.DAMAGE, szText, pUnit:GetX(), pUnit:GetY(), 0);
				end
			end
		end
	end
end

------------------------------------------------------------------
function OnUnitAbilityGained( playerID : number, unitID : number, eAbilityType : number)
	if (playerID == Game.GetLocalPlayer()) then
		local pPlayer = Players[ playerID ];
		if (pPlayer ~= nil) then
			local pUnit = pPlayer:GetUnits():FindID(unitID);
			if (pUnit ~= nil) then
				local flag = GetUnitFlag(playerID, pUnit:GetID());
				if (flag ~= nil) then
					if (flag.m_eVisibility == RevealedState.VISIBLE) then
						local abilityInfo = GameInfo.UnitAbilities[eAbilityType];
						if (abilityInfo ~= nil and abilityInfo.ShowFloatTextWhenEarned) then
						local sAbilityName = GameInfo.UnitAbilities[eAbilityType].Name;
						if (sAbilityName ~= nil) then
							local floatText = Locale.Lookup(sAbilityName);
							UI.AddWorldViewText(EventSubTypes.DAMAGE, floatText, pUnit:GetX(), pUnit:GetY(), 0);
						end
					end
				end
			end
		end
	end
end
end

------------------------------------------------------------------
function OnUnitFortificationChanged( playerID : number, unitID : number ) 
	local pPlayer = Players[ playerID ];
	if (pPlayer ~= nil) then
		local pUnit = pPlayer:GetUnits():FindID(unitID);
		if (pUnit ~= nil) then
			local flag = GetUnitFlag(playerID, pUnit:GetID());
			if (flag ~= nil) then
				flag:UpdateStats();
			end
		end
	end
end

------------------------------------------------------------------
function OnUnitPromotionChanged( playerID : number, unitID : number ) 
	local pPlayer = Players[ playerID ];
	if (pPlayer ~= nil) then
		local pUnit = pPlayer:GetUnits():FindID(unitID);
		if (pUnit ~= nil) then
			local flag = GetUnitFlag(playerID, pUnit:GetID());
			if (flag ~= nil) then
				flag:UpdateStats();
			end
		end
	end
end

------------------------------------------------------------------
function OnObjectPairingChanged(eSubType, parentOwner, parentType, parentID, childOwner, childType, childID)
	local pPlayer = Players[ parentOwner ];
	if (pPlayer ~= nil) then
		if (parentType == ComponentType.UNIT) then
			local pUnit = pPlayer:GetUnits():FindID(parentID);
			if (pUnit ~= nil) then
				local flag = GetUnitFlag(parentOwner, pUnit:GetID());
				if (flag ~= nil) then
					flag:UpdateStats();
				end
			end
		end
	end
end

------------------------------------------------------------------
function OnUnitArtifactChanged( playerID : number, unitID : number ) 
	local pPlayer = Players[ playerID ];
	if (pPlayer ~= nil) then
		local pUnit = pPlayer:GetUnits():FindID(unitID);
		if (pUnit ~= nil) then
			local flag = GetUnitFlag(playerID, pUnit:GetID());
			if (flag ~= nil) then
				flag:UpdateName();
			end
		end
	end
end

------------------------------------------------------------------
function OnUnitActivityChanged( playerID :number, unitID :number, eActivityType :number)
	local pPlayer = Players[ playerID ];
	if (pPlayer ~= nil) then
		local pUnit = pPlayer:GetUnits():FindID(unitID);
		if (pUnit ~= nil) then
			local flag = GetUnitFlag(playerID, pUnit:GetID());
			if (flag ~= nil) then
				flag:UpdateName();
			end
		end
	end
end

------------------------------------------------------------------
function SetForceHideForID( id : table, bState : boolean)
	if (id ~= nil) then
		if (id.componentType == ComponentType.UNIT) then
		    local flagInstance = GetUnitFlag( id.playerID, id.componentID );
			if (flagInstance ~= nil) then
				flagInstance:SetForceHide(bState);
				flagInstance:UpdatePosition();
			end
		end
    end
end
-------------------------------------------------
-- Combat vis is beginning
-------------------------------------------------
function OnCombatVisBegin( kVisData )

	SetForceHideForID( kVisData[CombatVisType.ATTACKER], true );
	SetForceHideForID( kVisData[CombatVisType.DEFENDER], true );
	SetForceHideForID( kVisData[CombatVisType.INTERCEPTOR], true );
	SetForceHideForID( kVisData[CombatVisType.ANTI_AIR], true );

end

-------------------------------------------------
-- Combat vis is ending
-------------------------------------------------
function OnCombatVisEnd( kVisData )

	SetForceHideForID( kVisData[CombatVisType.ATTACKER], false );
	SetForceHideForID( kVisData[CombatVisType.DEFENDER], false );
	SetForceHideForID( kVisData[CombatVisType.INTERCEPTOR], false );
	SetForceHideForID( kVisData[CombatVisType.ANTI_AIR], false );

end

-- ===========================================================================
--	Refresh the contents of the flags.
--	This does not include the flags' positions in world space; those are
--	updated on another event.
-- ===========================================================================
function Refresh()
	local pLocalPlayerVis = PlayersVisibility[Game.GetLocalPlayer()];
	if (pLocalPlayerVis ~= nil) then
		
		local plotsToUpdate	:table = {};
		local players		:table = Game.GetPlayers{Alive = true};

		for i, player in ipairs(players) do
			local playerID		:number = player:GetID();
			local playerUnits	:table = players[i]:GetUnits();
			for ii, unit in playerUnits:Members() do
				local unitID	:number = unit:GetID();
				local locX		:number = unit:GetX();
				local locY		:number = unit:GetY();

				-- If flag doesn't exist for this combo, create it:
				if ( m_UnitFlagInstances[ playerID ] == nil or m_UnitFlagInstances[ playerID ][ unitID ] == nil) then
					if not unit:IsDead() and not unit:IsDelayedDeath() then
						CreateUnitFlag(playerID, unitID, locX, locY);
					end
				end				
				
				-- If flag is visible, ensure it's being viewed that way; set plot for an update call.
				-- While event will handle in normal case, this is necessary for hotloading and flags are re-created.								
				if pLocalPlayerVis:IsVisible(locX, locY) then
					OnUnitVisibilityChanged(playerID, unitID, RevealedState.VISIBLE);
					if plotsToUpdate[locX] == nil then
						plotsToUpdate[locX] = {};
					end
					plotsToUpdate[locX][locY] = true;	-- Mark for update
				end				

			end
		end

		-- Update only the plots requiring a refresh.
		for locX:number,ys:table in pairs(plotsToUpdate) do
			for locY:number,_ in pairs(ys) do
				UpdateIconStack( locX, locY );	
			end				
		end

	end
end

----------------------------------------------------------------
function OnUnitCommandStarted(playerID, unitID, hCommand, iData1)
	if ( hCommand == GameInfo.Types["UNITCOMMAND_NAME_UNIT"].Hash ) then
		local flagInstance = GetUnitFlag( playerID, unitID );
		if (flagInstance ~= nil) then
			flagInstance:UpdateName();
		end
	end
end

----------------------------------------------------------------
function OnUnitUpgraded(player, unitID, eUpgradeUnitType)
	local pPlayer = Players[ player ];
	if (pPlayer ~= nil) then
		local pUnit = pPlayer:GetUnits():FindID(unitID);
		if (pUnit ~= nil) then
			local flagInstance = GetUnitFlag( player, unitID );
			if (flagInstance ~= nil) then
				flagInstance:UpdateName();
				flagInstance:UpdatePromotions();
			end
		end
	end
end

----------------------------------------------------------------
function OnMilitaryFormationChanged( playerID : number, unitID : number )
	local pPlayer = Players[ playerID ];
	if (pPlayer ~= nil) then
		local pUnit = pPlayer:GetUnits():FindID(unitID);
		if (pUnit ~= nil) then
			local flagInstance = GetUnitFlag( playerID, unitID );
			if flagInstance ~= nil then
			local militaryFormation = pUnit:GetMilitaryFormation();
			if (militaryFormation == MilitaryFormationTypes.CORPS_FORMATION) then
				flagInstance.m_Instance.CorpsMarker:SetHide(false);
				flagInstance.m_Instance.ArmyMarker:SetHide(true);
			elseif (militaryFormation == MilitaryFormationTypes.ARMY_FORMATION) then
				flagInstance.m_Instance.CorpsMarker:SetHide(false);
				flagInstance.m_Instance.ArmyMarker:SetHide(false);
			else
				flagInstance.m_Instance.CorpsMarker:SetHide(true);
				flagInstance.m_Instance.ArmyMarker:SetHide(true);
			end
		end
	end
end
end

------------------------------------------------- 
-- Position flag for unit appropriately in 2D and 3D view
-------------------------------------------------
function PositionFlagForUnitToView( playerID : number, unitID : number )
	local flagInstance = GetUnitFlag( playerID, unitID );
	if (flagInstance ~= nil) then
		if (flagInstance.m_eVisibility == RevealedState.VISIBLE) then
			local pUnit : table = flagInstance:GetUnit();
			flagInstance:SetPosition( UI.GridToWorld( pUnit:GetX(), pUnit:GetY() ) );
		end
	end
end

-------------------------------------------------
-- Position all unit flags appropriately in 2D and 3D view
-------------------------------------------------
function PositionFlagsToView()
	local players = Game.GetPlayers{Alive = true}; 
	for i, player in ipairs(players) do
		local playerID = player:GetID();
		local playerUnits = players[i]:GetUnits();
		for ii, unit in playerUnits:Members() do
			local unitID = unit:GetID();
			PositionFlagForUnitToView( playerID, unitID );
		end
	end
end

----------------------------------------------------------------
function OnEventPlaybackComplete()

	for playerID, unitID in m_DirtyComponents:Members() do

	    local flagInstance = GetUnitFlag( playerID, unitID );
		if (flagInstance ~= nil) then
			flagInstance:UpdateFlagType();
			flagInstance:UpdateReadyState();
	    end
	end

	m_DirtyComponents:Clear();
end

-- ===========================================================================
--	Gamecore Event
--	Called once per layer that is turned on when a new lens is activated,
--	or when a player explicitly turns off the layer from the "player" lens.
-- ===========================================================================
function OnLensLayerOn( layerNum:number )		
	if	layerNum == LensLayers.UNITS_MILITARY or
		layerNum == LensLayers.UNITS_RELIGIOUS or
		layerNum == LensLayers.UNITS_CIVILIAN or
		layerNum == LensLayers.UNITS_ARCHEOLOGY then
		ContextPtr:SetHide(false);
	end
end

-- ===========================================================================
--	Gamecore Event
--	Called once per layer that is turned on when a new lens is deactivated,
--	or when a player explicitly turns off the layer from the "player" lens.
-- ===========================================================================
function OnLensLayerOff( layerNum:number )
	if	layerNum == LensLayers.UNITS_MILITARY or
		layerNum == LensLayers.UNITS_RELIGIOUS or
		layerNum == LensLayers.UNITS_CIVILIAN or
		layerNum == LensLayers.UNITS_ARCHEOLOGY then
		ContextPtr:SetHide(true);
	end
end

function OnLevyCounterChanged( originalOwnerID : number )
	local pOriginalOwner = Players[originalOwnerID];
	if (pOriginalOwner ~= nil and pOriginalOwner:GetInfluence() ~= nil) then
		local suzerainID = pOriginalOwner:GetInfluence():GetSuzerain();
		local pSuzerain = Players[suzerainID];
		if (pSuzerain ~= nil) then
			if (m_UnitFlagInstances[ suzerainID ] == nil) then
				return;
			end

			local suzerainFlagInstances = m_UnitFlagInstances[ suzerainID ];
			for id, flag in pairs(suzerainFlagInstances) do
				if (flag ~= nil) then
					flag:UpdateName();
					flag:UpdatePromotions();
				end
			end
		end
    end
end

-- ===========================================================================
function OnLocalPlayerChanged()

	-- Hide all the flags, we will get updates later
	for _, playerFlagInstances in pairs(m_UnitFlagInstances) do
		for id, flag in pairs(playerFlagInstances) do
			if (flag ~= nil) then
				flag:SetFogState(RevealedState.HIDDEN);
			end
		end
    end

	m_DirtyComponents:Clear();
end

-- ===========================================================================
function RegisterDirtyEvents()
	m_DirtyComponents = DirtyComponentsManager.Create();
	m_DirtyComponents:AddEvent("UNIT_OPERATION_DEACTIVATED");
	m_DirtyComponents:AddEvent("UNIT_ACTIVITY_CHANGED");
	m_DirtyComponents:AddEvent("UNIT_MOVEMENT_POINTS_CHANGED");
	m_DirtyComponents:AddEvent("UNIT_EMBARK_CHANGED");
end

-- ===========================================================================
--	LUA Event
--	Tutorial system is disabling selection.
-- ===========================================================================
function OnTutorial_DisableMapSelect( isDisabled:boolean )
	m_isMapDeselectDisabled = isDisabled;
end

-- ===========================================================================
--	UI Callback
-- ===========================================================================
function OnInit(isHotload : boolean)
	-- If hotloading, rebuild from scratch.
	if isHotload then
		Refresh();
	end
end

-- ===========================================================================
--	UI Callback
--	Handle the UI shutting down.
-- ===========================================================================
function OnShutdown()
	m_MilitaryInstanceManager:ResetInstances();
	m_CivilianInstanceManager:ResetInstances();
	m_SupportInstanceManager:ResetInstances();
	m_TradeInstanceManager:ResetInstances();
	m_NavalInstanceManager:ResetInstances();
	DirtyComponentsManager.Destroy( m_DirtyComponents );
	m_DirtyComponents = nil;
end

-- ===========================================================================
function Initialize()

	ContextPtr:SetInitHandler( OnInit );
	ContextPtr:SetShutdown( OnShutdown );

	Events.Camera_Updated.Add( OnCameraUpdate );
	Events.CombatVisBegin.Add( OnCombatVisBegin );		
	Events.CombatVisEnd.Add( OnCombatVisEnd );
	Events.GameCoreEventPlaybackComplete.Add(OnEventPlaybackComplete);
	Events.LensLayerOn.Add(	OnLensLayerOn );
	Events.LensLayerOff.Add( OnLensLayerOff );
	Events.LevyCounterChanged.Add( OnLevyCounterChanged );
	Events.LocalPlayerChanged.Add(OnLocalPlayerChanged);	
	Events.MultiplayerPlayerConnected.Add( OnPlayerConnectChanged );
	Events.MultiplayerPostPlayerDisconnected.Add( OnPlayerConnectChanged );
	Events.ObjectPairing.Add(OnObjectPairingChanged);
	Events.PlayerTurnActivated.Add( OnPlayerTurnActivated );
	Events.UnitAddedToMap.Add( OnUnitAddedToMap );
	Events.UnitDamageChanged.Add( OnUnitDamageChanged );
	Events.UnitEnterFormation.Add( OnEnterFormation );
	Events.UnitExitFormation.Add( OnEnterFormation );
	Events.UnitFormCorps.Add( OnMilitaryFormationChanged );
	Events.UnitFormArmy.Add( OnMilitaryFormationChanged );
	Events.UnitArtifactChanged.Add( OnUnitArtifactChanged );
	Events.UnitFortificationChanged.Add( OnUnitFortificationChanged );
	Events.UnitRemovedFromMap.Add( OnUnitRemovedFromMap );
	Events.UnitSelectionChanged.Add( OnUnitSelectionChanged );
	Events.UnitSimPositionChanged.Add( UnitSimPositionChanged );
	Events.UnitTeleported.Add( OnUnitTeleported );
	Events.UnitVisibilityChanged.Add( OnUnitVisibilityChanged );
	Events.UnitEmbarkedStateChanged.Add( OnUnitEmbarkedStateChanged );
	Events.UnitCommandStarted.Add( OnUnitCommandStarted );
	Events.UnitUpgraded.Add( OnUnitUpgraded );
	Events.WorldRenderViewChanged.Add(PositionFlagsToView);
	Events.UnitPromoted.Add(OnUnitPromotionChanged);
	Events.UnitAbilityGained.Add(OnUnitAbilityGained);
	Events.BarbarianSpottedCity.Add(OnBarbarianSpottedCity);
	--Events.UnitActivityChanged.Add(OnUnitActivityChanged); --Currently only needed for debugging.

	LuaEvents.Tutorial_DisableMapSelect.Add( OnTutorial_DisableMapSelect );
		
	RegisterDirtyEvents();
end
Initialize();

-- GCO <<<<<
function OnUnitsCompositionUpdated(playerID, unitID)
	local playerID = tonumber(playerID) -- playerID may be a string when used for key in tables
	local pPlayer = Players[ playerID ]
	if (pPlayer ~= nil) then	
		local pUnit = pPlayer:GetUnits():FindID(unitID)
		if (pUnit ~= nil) then
			local flag = GetUnitFlag(playerID, unitID)
			if (flag ~= nil) then
				flag:UpdateName()
			end
		end
	end
end
LuaEvents.UnitsCompositionUpdated.Add(OnUnitsCompositionUpdated)

function OnMouseOut()
	bShownSupplyLine = false
	if UILens.IsLensActive("TradeRoute") then
		-- Make sure to switch back to default lens
		UILens.SetActive("Default");
	end
end
LuaEvents.UnitFlagManager_PointerExited.Add( OnMouseOut )
-- GCO >>>>>
