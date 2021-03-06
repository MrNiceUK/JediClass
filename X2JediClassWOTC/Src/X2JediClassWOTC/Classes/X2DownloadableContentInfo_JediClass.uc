//---------------------------------------------------------------------------------------
//  FILE:   XComDownloadableContentInfo_JediClass.uc                                    
//           
//	Use the X2DownloadableContentInfo class to specify unique mod behavior when the 
//  player creates a new campaign or loads a saved game.
//  
//---------------------------------------------------------------------------------------
//  Copyright (c) 2016 Firaxis Games, Inc. All rights reserved.
//---------------------------------------------------------------------------------------

class X2DownloadableContentInfo_JediClass extends X2DownloadableContentInfo config(JediClass);

struct SocketReplacementInfo
{
	var name TorsoName;
	var string SocketMeshString;
	var bool Female;
};

var config array<SocketReplacementInfo> SocketReplacements;

var config array<Name> IgnoreAbilitiesForForceSpeed;

var config array<LootTable> LOOT_TABLES;

var config name BASIC_LOOT_ENTRIES_TO_TABLE;
var config array<LootTableEntry> BASIC_LOOT_ENTRIES;

var config name ADVANCED_LOOT_ENTRIES_TO_TABLE;
var config array<LootTableEntry> ADVANCED_LOOT_ENTRIES;

var config name SUPERIOR_LOOT_ENTRIES_TO_TABLE;
var config array<LootTableEntry> SUPERIOR_LOOT_ENTRIES;

static function UpdateWeaponMaterial(XGWeapon WeaponArchetype, MeshComponent MeshComp)
{
	local XComLinearColorPalette Palette;
	local LinearColor GlowTint;
	local int i;
	local MaterialInterface Mat, ParentMat;
	local MaterialInstanceTimeVarying MITV, ParentMITV, NewMITV;
	//local SkeletalMeshComponent AttachedMesh;

	//`LOG(GetFuncName() @ XComWeapon(WeaponArchetype.m_kEntity) @ MeshComp.GetNumElements(),, 'X2JediClassWotc');

	if (MeshComp != none)
	{
		for (i = 0; i < MeshComp.GetNumElements(); ++i)
		{
			Mat = MeshComp.GetMaterial(i);
			MITV = MaterialInstanceTimeVarying(Mat);

			//`LOG(GetFuncName() @ i @ XComWeapon(WeaponArchetype.m_kEntity) @ MaterialInstanceTimeVarying(Mat).Parent.Name @ MaterialInstanceConstant(Mat).Parent.Name,, 'X2JediClassWotc');

			if (MITV != none)
			{
				// If this is not a child MIC, make it one. This is done so that the material updates below don't stomp
				// on each other between units.
				if (InStr(MITV.Name, "MaterialInstanceTimeVarying") == INDEX_NONE)
				{
					NewMITV = new (WeaponArchetype) class'MaterialInstanceTimeVarying';
					NewMITV.SetParent(MITV);
					MeshComp.SetMaterial(i, NewMITV);
					MITV = NewMITV;
				}
				
				ParentMat = MITV.Parent;
				while (!ParentMat.IsA('Material'))
				{
					ParentMITV = MaterialInstanceTimeVarying(ParentMat);
					if (ParentMITV != none)
						ParentMat = ParentMITV.Parent;
					else
						break;
				}

				//`LOG(GetFuncName() @ i @ MaterialInstanceTimeVarying(ParentMITV.Parent).Name @ MITV.Name,, 'X2JediClassWotc');
				if (InStr(ParentMat, "MAT_Lightsaber_Blade") != INDEX_NONE)
				{
					//foreach WeaponArchetype.UnitPawn.Mesh.AttachedComponentsOnBone(class'SkeletalMeshComponent', AttachedMesh, 'LeftSwordSheath')
					//{
					//	if (AttachedMesh != none)
					//	{
					//		MITV = MaterialInstanceTimeVarying(DynamicLoadObject("Lightsaber_CV.Materials.Invisible_MITV", class'MaterialInstanceTimeVarying'));
					//	}
					//	else
					//	{
					//		MITV = MaterialInstanceTimeVarying(DynamicLoadObject("Lightsaber_CV.Materials.MAT_Lightsaber_Blade_MITV", class'MaterialInstanceTimeVarying'));
					//	}
					//
					//	MeshComp.SetMaterial(0, MITV);
					//	`LOG(GetFuncName() @ "setting blade mitv" @ MITV,, 'X2JediClassWotc');
					//
					//	break;
					//}

					Palette = `CONTENT.GetColorPalette(ePalette_ArmorTint);
					if (Palette != none)
					{
						if(WeaponArchetype.m_kAppearance.iWeaponTint != INDEX_NONE)
						{
							GlowTint = Palette.Entries[WeaponArchetype.m_kAppearance.iWeaponTint].Primary;
							MITV.SetVectorParameterValue('Emissive Color', GlowTint);
							`LOG(GetFuncName() @ "Setting Emissive Color" @ MITV @ ParentMat,, 'X2JediClassWotc');
						}
					}

					
				}
			}
		}
	}	
}

static event OnLoadedSavedGame()
{
	UpdateResearch();
}

static function UpdateResearch()
{
	local XComGameStateHistory History;
	local XComGameState NewGameState;
	local X2TechTemplate TechTemplate;
	local X2StrategyElementTemplateManager StratMgr;
	local name ResearchName;

	StratMgr = class'X2StrategyElementTemplateManager'.static.GetStrategyElementTemplateManager();
	History = `XCOMHISTORY;
	NewGameState = class'XComGameStateContext_ChangeContainer'.static.CreateChangeState(default.class $ "::" $ GetFuncName());

	foreach class'X2StrategyElement_LightsaberTech'.default.LIGHTSABER_PROJECT_NAMES(ResearchName)
	{
		if (!IsResearchInHistory(ResearchName))
		{
			`log(default.class @ GetFuncName() @ ResearchName @ "not found, creating...",, 'X2JediClassWOTC');
			TechTemplate = X2TechTemplate(StratMgr.FindStrategyElementTemplate(ResearchName));
			if (TechTemplate != none)
			{
				NewGameState.CreateNewStateObject(class'XComGameState_Tech', TechTemplate);
			}
		}
	}

	if (NewGameState.GetNumGameStateObjects() > 0)
	{
		`GAMERULES.SubmitGameState(NewGameState);
	}
	else
	{
		History.CleanupPendingGameState(NewGameState);
	}
}

static function bool IsResearchInHistory(name ResearchName)
{
	// Check if we've already injected the tech templates
	local XComGameState_Tech	TechState;
	
	foreach `XCOMHISTORY.IterateByClassType(class'XComGameState_Tech', TechState)
	{
		if ( TechState.GetMyTemplateName() == ResearchName )
		{
			return true;
		}
	}
	return false;
}


/// <summary>
/// Called after the Templates have been created (but before they are validated) while this DLC / Mod is installed.
/// </summary>
static event OnPostTemplatesCreated()
{
	//`LOG("ForceLightning Ability" @ class'X2AbilityTemplateManager'.static.GetAbilityTemplateManager().FindAbilityTemplate('ForceLightning'),, 'X2JediClassWOTC');
	OnPostAbilityTemplatesCreated();
	OnPostLootTablesCreated();
}

static function OnPostAbilityTemplatesCreated()
{
	local array<name> TemplateNames;
	local array<X2AbilityTemplate> AbilityTemplates;
	local name TemplateName;
	local X2AbilityTemplateManager AbilityMgr;
	local X2AbilityTemplate AbilityTemplate;
	local X2AbilityCost Cost;
	local X2AbilityCost_ActionPoints ActionPointCost;


	AbilityMgr = class'X2AbilityTemplateManager'.static.GetAbilityTemplateManager();
	AbilityMgr.GetTemplateNames(TemplateNames);
	foreach TemplateNames(TemplateName)
	{
		if (default.IgnoreAbilitiesForForceSpeed.Find(TemplateName) != INDEX_NONE)
		{
			continue;
		}

		AbilityMgr.FindAbilityTemplateAllDifficulties(TemplateName, AbilityTemplates);
		foreach AbilityTemplates(AbilityTemplate)
		{
			foreach AbilityTemplate.AbilityCosts(Cost)
			{
				ActionPointCost = X2AbilityCost_ActionPoints(Cost);
				if (ActionPointCost != None)
				{
					ActionPointCost.DoNotConsumeAllEffects.AddItem('ForceSpeed');
				}
			}
		}
	}
}

static function OnPostLootTablesCreated()
{
	local LootTable CurrentLoot;
	local LootTableEntry CurrentEntry;

	foreach default.LOOT_TABLES(CurrentLoot)
	{
		class'X2LootTableManager'.static.AddLootTableStatic(CurrentLoot);
	}

	foreach default.BASIC_LOOT_ENTRIES(CurrentEntry)
	{
		class'X2LootTableManager'.static.AddEntryStatic(default.BASIC_LOOT_ENTRIES_TO_TABLE, CurrentEntry, false);
	}
	class'X2LootTableManager'.static.RecalculateLootTableChanceStatic(default.BASIC_LOOT_ENTRIES_TO_TABLE);

	foreach default.ADVANCED_LOOT_ENTRIES(CurrentEntry)
	{
		class'X2LootTableManager'.static.AddEntryStatic(default.ADVANCED_LOOT_ENTRIES_TO_TABLE, CurrentEntry, false);
	}
	class'X2LootTableManager'.static.RecalculateLootTableChanceStatic(default.ADVANCED_LOOT_ENTRIES_TO_TABLE);

	foreach default.SUPERIOR_LOOT_ENTRIES(CurrentEntry)
	{
		class'X2LootTableManager'.static.AddEntryStatic(default.SUPERIOR_LOOT_ENTRIES_TO_TABLE, CurrentEntry, false);
	}
	class'X2LootTableManager'.static.RecalculateLootTableChanceStatic(default.SUPERIOR_LOOT_ENTRIES_TO_TABLE);
}


static function string DLCAppendSockets(XComUnitPawn Pawn)
{
	local SocketReplacementInfo SocketReplacement;
	local name TorsoName;
	local bool bIsFemale;
	local string DefaultString, ReturnString;
	local XComHumanPawn HumanPawn;

	//`LOG("DLCAppendSockets" @ Pawn,, 'DualWieldMelee');

	HumanPawn = XComHumanPawn(Pawn);
	if (HumanPawn == none) { return ""; }

	TorsoName = HumanPawn.m_kAppearance.nmTorso;
	bIsFemale = HumanPawn.m_kAppearance.iGender == eGender_Female;

	//`LOG("DLCAppendSockets: Torso= " $ TorsoName $ ", Female= " $ string(bIsFemale),, 'DualWieldMelee');

	foreach default.SocketReplacements(SocketReplacement)
	{
		if (TorsoName != 'None' && TorsoName == SocketReplacement.TorsoName && bIsFemale == SocketReplacement.Female)
		{
			ReturnString = SocketReplacement.SocketMeshString;
			break;
		}
		else
		{
			if (SocketReplacement.TorsoName == 'Default' && SocketReplacement.Female == bIsFemale)
			{
				DefaultString = SocketReplacement.SocketMeshString;
			}
		}
	}
	if (ReturnString == "")
	{
		// did not find, so use default
		ReturnString = DefaultString;
	}

	return ReturnString;
}

static function UpdateAnimations(out array<AnimSet> CustomAnimSets, XComGameState_Unit UnitState, XComUnitPawn Pawn)
{
	if (UnitState.IsAdvent() || UnitState.IsAlien() || UnitState.IsCivilian())
	{
		CustomAnimSets.AddItem(AnimSet(`CONTENT.RequestGameArchetype("JediClassAbilities.Anims.AS_ForceChokeTarget")));
	}

	if (UnitState.GetSoldierClassTemplateName() != 'Jedi')
		return;

	if (HasDualMeleeEquipped(UnitState))
	{
		CustomAnimSets.AddItem(AnimSet(`CONTENT.RequestGameArchetype("Lightsaber_CV.Anims.AS_JediDual")));
		
	}
	CustomAnimSets.AddItem(AnimSet(`CONTENT.RequestGameArchetype("JediClassAbilities.Anims.AS_ForcePowers")));

}

static function bool HasDualMeleeEquipped(XComGameState_Unit UnitState, optional XComGameState CheckGameState)
{
	return IsPrimaryMeleeWeaponTemplate(X2WeaponTemplate(UnitState.GetItemInSlot(eInvSlot_PrimaryWeapon, CheckGameState).GetMyTemplate())) &&
		IsSecondaryMeleeWeaponTemplate(X2WeaponTemplate(UnitState.GetItemInSlot(eInvSlot_SecondaryWeapon, CheckGameState).GetMyTemplate()));
}

static function bool IsPrimaryMeleeWeaponTemplate(X2WeaponTemplate WeaponTemplate)
{
	return WeaponTemplate != none &&
		WeaponTemplate.InventorySlot == eInvSlot_PrimaryWeapon &&
		WeaponTemplate.iRange == 0;
}

static function bool IsSecondaryMeleeWeaponTemplate(X2WeaponTemplate WeaponTemplate)
{
	return WeaponTemplate != none &&
		WeaponTemplate.InventorySlot == eInvSlot_SecondaryWeapon &&
		WeaponTemplate.iRange == 0 &&
		WeaponTemplate.WeaponCat != 'wristblade' &&
		WeaponTemplate.WeaponCat != 'shield' &&
		WeaponTemplate.WeaponCat != 'gauntlet';
}

static function bool CanWeaponApplyUpgrade(XComGameState_Item WeaponState, X2WeaponUpgradeTemplate UpgradeTemplate)
{
	local X2WeaponTemplate WeaponTemplate;
	local name TemplateName;
	local bool bIsTemplateWeWant;

	WeaponTemplate = X2WeaponTemplate(WeaponState.GetMyTemplate());

	if (WeaponTemplate == none)
		return true;	// We only care about stopping upgrades for lightsabers, which are weapons, so let non-weapons pass

	foreach class'X2Item_Lightsaber'.default.LIGHTSABER_TEMPLATE_NAMES(TemplateName)
	{
		if (InStr(string(WeaponTemplate.DataName), string(TemplateName)) != INDEX_NONE) // Primary Secondaries adds the primary sabers, so we need to make sure to look for template names generated off of ours
		{
			bIsTemplateWeWant = true;
			break;
		}
	}

	if (bIsTemplateWeWant && UpgradeTemplate.UpgradeCats.Find(WeaponTemplate.WeaponCat) == INDEX_NONE)
		return false;	// Try to find our weapon category in the list of categories the upgrade is intended for. If it's not there, don't allow the upgrade

	return true; // We only get here if: we're testing a weapon that is a lightsaber added by this mod, and the upgrade is intended for lightsabers. Good! It may pass.
}

exec function DebugGiveJediUpgrades(optional int NumToGive = 1)
{
	local XComGameState						NewGameState;
	local X2ItemTemplateManager				ItemMgr;
	local array<X2WeaponUpgradeTemplate>	AllUpgrades;
	local X2WeaponUpgradeTemplate			ThisUpgrade;
	local XComGameState_Item				NewItemState;

	ItemMgr = class'X2ItemTemplateManager'.static.GetItemTemplateManager();
	NewGameState = class'XComGameStateContext_ChangeContainer'.static.CreateChangeState("CHEAT: Give Jedi Upgrades");

	AllUpgrades = ItemMgr.GetAllUpgradeTemplates();

	foreach AllUpgrades(ThisUpgrade)
	{
		if (ThisUpgrade.ClassThatCreatedUs == class'X2Item_WeaponUpgrade_Lightsaber')
		{
			`LOG("Adding to HQ" @ ThisUpgrade.DataName,, 'X2JediClassWOTC');
			NewItemState = ThisUpgrade.CreateInstanceFromTemplate(NewGameState);
			NewItemState.Quantity = NumToGive;
			NewGameState.AddStateObject(NewItemState);
			`XCOMHQ.AddItemToHQInventory(NewItemState);
		}
	}

	`STRATEGYRULES.SubmitGameState(NewGameState);
}

exec function GiveLightSidePoint(int Amount = 1)
{
	local XComGameStateHistory				History;
	local UIArmory							Armory;
	local StateObjectReference				UnitRef;
	local XComGameState_Unit				UnitState;
	
	History = `XCOMHISTORY;

	Armory = UIArmory(`SCREENSTACK.GetFirstInstanceOf(class'UIArmory'));
	if (Armory == none)
	{
		return;
	}

	UnitRef = Armory.GetUnitRef();
	UnitState = XComGameState_Unit(History.GetGameStateForObjectID(UnitRef.ObjectID));
	if (UnitState == none)
	{
		return;
	}
	
	class'JediClassHelper'.static.AddLightSidePoint(UnitState ,Amount);
}

exec function GiveDarkSidePoint(int Amount = 1)
{
	local XComGameStateHistory				History;
	local UIArmory							Armory;
	local StateObjectReference				UnitRef;
	local XComGameState_Unit				UnitState;
	local XComGameState_Unit NewSourceUnit;
	local XComGameState NewGameState;
	local UnitValue DarkSidePoints;
	
	History = `XCOMHISTORY;

	Armory = UIArmory(`SCREENSTACK.GetFirstInstanceOf(class'UIArmory'));
	if (Armory == none)
	{
		return;
	}

	UnitRef = Armory.GetUnitRef();
	UnitState = XComGameState_Unit(History.GetGameStateForObjectID(UnitRef.ObjectID));
	if (UnitState == none || UnitState.GetSoldierClassTemplateName() != 'Jedi')
	{
		return;
	}

	UnitState.GetUnitValue('DarkSidePoints', DarkSidePoints);
	NewGameState = class'XComGameStateContext_ChangeContainer'.static.CreateChangeState(string(GetFuncName()));
	NewSourceUnit = XComGameState_Unit(`XCOMHISTORY.GetGameStateForObjectID(UnitState.ObjectID));
	if (NewSourceUnit != none)
	{
		NewSourceUnit = XComGameState_Unit(NewGameState.ModifyStateObject(NewSourceUnit.Class, NewSourceUnit.ObjectID));
		NewSourceUnit.SetUnitFloatValue('DarkSidePoints', DarkSidePoints.fValue + Amount, eCleanup_Never);
		`GAMERULES.SubmitGameState(NewGameState);
		`LOG("EXEC AddDarkSidePoints for" @ NewSourceUnit.GetFullName() @ Amount @ "(" @ DarkSidePoints.fValue + Amount @ ")",, 'X2JediClassWOTC');
	}
}


exec function LogCrossClassAbilities()
{
	local X2AbilityTemplateManager						TemplateManager;
	local X2AbilityTemplate								Template;
	local array<name>									TemplateNames;
	local name											TemplateName;
	
	TemplateManager = class'X2AbilityTemplateManager'.static.GetAbilityTemplateManager();
	TemplateManager.GetTemplateNames(TemplateNames);
	foreach TemplateNames(TemplateName)
	{
		Template = TemplateManager.FindAbilityTemplate(TemplateName);
		if (Template.bCrossClassEligible)
		{
			`Log(TemplateName,, 'AWC Ability');
		}
	}
}