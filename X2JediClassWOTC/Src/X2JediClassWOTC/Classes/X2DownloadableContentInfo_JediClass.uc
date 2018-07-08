//---------------------------------------------------------------------------------------
//  FILE:   XComDownloadableContentInfo_JediClass.uc                                    
//           
//	Use the X2DownloadableContentInfo class to specify unique mod behavior when the 
//  player creates a new campaign or loads a saved game.
//  
//---------------------------------------------------------------------------------------
//  Copyright (c) 2016 Firaxis Games, Inc. All rights reserved.
//---------------------------------------------------------------------------------------

class X2DownloadableContentInfo_JediClass extends X2DownloadableContentInfo config (JediClass);

var config array<Name> IgnoreAbilitiesForForceSpeed;

var config array<LootTable> LOOT_TABLES;

var config name BASIC_LOOT_ENTRIES_TO_TABLE;
var config array<LootTableEntry> BASIC_LOOT_ENTRIES;

var config name ADVANCED_LOOT_ENTRIES_TO_TABLE;
var config array<LootTableEntry> ADVANCED_LOOT_ENTRIES;

var config name SUPERIOR_LOOT_ENTRIES_TO_TABLE;
var config array<LootTableEntry> SUPERIOR_LOOT_ENTRIES;

/// <summary>
/// This method is run if the player loads a saved game that was created prior to this DLC / Mod being installed, and allows the 
/// DLC / Mod to perform custom processing in response. This will only be called once the first time a player loads a save that was
/// create without the content installed. Subsequent saves will record that the content was installed.
/// </summary>
static event OnLoadedSavedGame()
{
	UpdateResearch();
}

/// <summary>
/// This method is run when the player loads a saved game directly into Strategy while this DLC is installed
/// </summary>
static event OnLoadedSavedGameToStrategy()
{
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
/// Called when the player starts a new campaign while this DLC / Mod is installed. When a new campaign is started the initial state of the world
/// is contained in a strategy start state. Never add additional history frames inside of InstallNewCampaign, add new state objects to the start state
/// or directly modify start state objects
/// </summary>
static event InstallNewCampaign(XComGameState StartState)
{

}

/// <summary>
/// Called just before the player launches into a tactical a mission while this DLC / Mod is installed.
/// Allows dlcs/mods to modify the start state before launching into the mission
/// </summary>
static event OnPreMission(XComGameState StartGameState, XComGameState_MissionSite MissionState)
{

}

/// <summary>
/// Called when the player completes a mission while this DLC / Mod is installed.
/// </summary>
static event OnPostMission()
{

}

/// <summary>
/// Called when the player is doing a direct tactical->tactical mission transfer. Allows mods to modify the
/// start state of the new transfer mission if needed
/// </summary>
static event ModifyTacticalTransferStartState(XComGameState TransferStartState)
{

}

/// <summary>
/// Called after the player exits the post-mission sequence while this DLC / Mod is installed.
/// </summary>
static event OnExitPostMissionSequence()
{

}

/// <summary>
/// Called after the Templates have been created (but before they are validated) while this DLC / Mod is installed.
/// </summary>
static event OnPostTemplatesCreated()
{
	//`LOG("ForceLightning Ability" @ class'X2AbilityTemplateManager'.static.GetAbilityTemplateManager().FindAbilityTemplate('ForceLightning'),, 'JediClass');
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

/// <summary>
/// Called when the difficulty changes and this DLC is active
/// </summary>
static event OnDifficultyChanged()
{

}


/// <summary>
/// Called when viewing mission blades with the Shadow Chamber panel, used primarily to modify tactical tags for spawning
/// Returns true when the mission's spawning info needs to be updated
/// </summary>
static function bool UpdateShadowChamberMissionInfo(StateObjectReference MissionRef)
{
	return false;
}

/// <summary>
/// Called from X2AbilityTag:ExpandHandler after processing the base game tags. Return true (and fill OutString correctly)
/// to indicate the tag has been expanded properly and no further processing is needed.
/// </summary>
static function bool AbilityTagExpandHandler(string InString, out string OutString)
{
	return false;
}
/// <summary>
/// Called from XComGameState_Unit:GatherUnitAbilitiesForInit after the game has built what it believes is the full list of
/// abilities for the unit based on character, class, equipment, et cetera. You can add or remove abilities in SetupData.
/// </summary>
static function FinalizeUnitAbilitiesForInit(XComGameState_Unit UnitState, out array<AbilitySetupData> SetupData, optional XComGameState StartState, optional XComGameState_Player PlayerState, optional bool bMultiplayerDisplay)
{

}