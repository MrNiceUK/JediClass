//---------------------------------------------------------------------------------------
// Based on X2Effect_Knockback
//---------------------------------------------------------------------------------------
class X2Effect_ForcePush extends X2Effect;

var name ForcePushAnimSequence;

/** Distance that the target will be thrown backwards, in meters */
var int KnockbackDistance;

/** If true, the KnockbackDistance will be added to the target's location instead of the source location. */
var bool bUseTargetLocation;

/** Used to step the knockback forward along the movement vector until either knock back distance is reached, or there are no more valid tiles*/
var private float IncrementalStepSize;

/** If true, the knocked back unit will cause non fragile destruction ( like kinetic strike ) */
var bool bKnockbackDestroysNonFragile;

/** Distance that the target will be thrown backwards, in meters */
var float OverrideRagdollFinishTimerSec;

var float DefaultDamage;
var float DefaultRadius;

function name WasTargetPreviouslyDead(const out EffectAppliedData ApplyEffectParameters, XComGameState_BaseObject kNewTargetState, XComGameState NewGameState)
{
	// A unit that was dead before this game state should not get a knockback, they are already a corpse
	local name AvailableCode;
	local XComGameState_Unit PreviousTargetStateObject;
	local XComGameStateHistory History;

	AvailableCode = 'AA_Success';

	History = `XCOMHISTORY;

	PreviousTargetStateObject = XComGameState_Unit(History.GetGameStateForObjectID(kNewTargetState.ObjectID));
	if( (PreviousTargetStateObject != none) && PreviousTargetStateObject.IsDead() )
	{
		//`LOG("X2Effect_ForcePush WasTargetPreviouslyDead true",, 'JediClass');
		return 'AA_UnitIsDead';
	}

	return AvailableCode;
}

private function bool CanBeDestroyed(XComInteractiveLevelActor InteractiveActor, float DamageAmount)
{
	//make sure the knockback damage can destroy this actor.
	//check the number of interaction points to prevent larger objects from being destroyed.
	//return InteractiveActor != none && DamageAmount >= InteractiveActor.Health && InteractiveActor.InteractionPoints.Length <= 8;
	return true;
}

//Returns the list of tiles that the unit will pass through as part of the knock back. The last tile in the array is the final destination.
private function GetTilesEnteredArray(XComGameStateContext_Ability AbilityContext, XComGameState_BaseObject kNewTargetState, out array<TTile> OutTilesEntered, out Vector OutAttackDirection, float DamageAmount)
{
	local XComGameStateHistory History;
	local XComWorldData WorldData;
	local XComGameState_Unit SourceUnit;
	local XComGameState_Unit TargetUnit;
	local Vector SourceLocation;
	local Vector TargetLocation;
	local Vector StartLocation;
	local TTile  TempTile;
	local TTile  LastTempTile;
	local Vector KnockbackToLocation;	
	local float  StepDistance;
	local Vector TestLocation;
	local float  TestDistanceUnits;
	local TTile  MoveToTile;

	local ActorTraceHitInfo TraceHitInfo;
	local array<ActorTraceHitInfo> Hits;

	WorldData = `XWORLD;
	History = `XCOMHISTORY;

	//`LOG("X2Effect_ForcePush GetTilesEnteredArray" @ AbilityContext,, 'JediClass');

	if(AbilityContext != none)
	{
		TargetUnit = XComGameState_Unit(kNewTargetState);
		TargetUnit.GetKeystoneVisibilityLocation(TempTile);
		TargetLocation = WorldData.GetPositionFromTileCoordinates(TempTile);
		//`LOG("X2Effect_ForcePush TargetLocation" @ TargetLocation,, 'JediClass');

		//attack source is from a Unit
		SourceUnit = XComGameState_Unit(History.GetGameStateForObjectID(AbilityContext.InputContext.SourceObject.ObjectID));
		SourceUnit.GetKeystoneVisibilityLocation(TempTile);
		SourceLocation = WorldData.GetPositionFromTileCoordinates(TempTile);

		//`LOG("X2Effect_ForcePush TargetUnit" @ TargetUnit.IsAlive() @ TargetUnit.IsIncapacitated(),, 'JediClass');

		//if(TargetUnit.IsAlive() || TargetUnit.IsIncapacitated())
		//{
			OutAttackDirection = Normal(TargetLocation - SourceLocation);
			OutAttackDirection.Z = 0.0f;
			StartLocation = bUseTargetLocation ? TargetLocation : SourceLocation;
			KnockbackToLocation = StartLocation + (OutAttackDirection * float(KnockbackDistance) * 64.0f); //Convert knockback distance to meters

			//`LOG("X2Effect_ForcePush StartLocation KnockbackToLocation" @ StartLocation @ KnockbackToLocation,, 'JediClass');

			if (WorldData.GetAllActorsTrace(StartLocation, KnockbackToLocation, Hits))
			{
				foreach Hits(TraceHitInfo)
				{
					if((!CanBeDestroyed(XComInteractiveLevelActor(TraceHitInfo.HitActor), DamageAmount) && XComFracLevelActor(TraceHitInfo.HitActor) == none) || !bKnockbackDestroysNonFragile)
					{
						//We hit an indestructible object
						`LOG("X2Effect_ForcePush Hitting undestructible actor",, 'JediClass');
						KnockbackToLocation = TraceHitInfo.HitLocation + (-OutAttackDirection * 16.0f); //Scoot the hit back a bit and use that as the knockback location
						break;
					}
				}
			}

			//Walk in increments down the attack vector. We will stop if we can't find a floor, or have reached the knock back distance
			TestDistanceUnits = VSize2D(KnockbackToLocation - StartLocation);
			StepDistance = 0.0f;
			OutTilesEntered.Length = 0;
			while(StepDistance < TestDistanceUnits)
			{
				TestLocation = StartLocation + (OutAttackDirection * StepDistance);
				if(!WorldData.GetFloorTileForPosition(TestLocation, TempTile, true))
				{
					TestLocation -= (OutAttackDirection * StepDistance * 2);
					break;
				}

				if(LastTempTile != TempTile)
				{
					OutTilesEntered.AddItem(TempTile);
					LastTempTile = TempTile;
				}
				
				StepDistance += IncrementalStepSize;
			}

			//Move the target unit to the knockback location
			WorldData.GetFloorTileForPosition(TestLocation, MoveToTile, true);
			OutTilesEntered.AddItem(MoveToTile);
		//}
	}
}


simulated function ApplyEffectToWorld(const out EffectAppliedData ApplyEffectParameters, XComGameState NewGameState)
{
	local XComGameStateContext_Ability AbilityContext;
	local XComGameState_BaseObject kNewTargetState;
	local int Index;
	local XComGameState_EnvironmentDamage DamageEvent;
	local XComWorldData WorldData;
	local TTile HitTile;
	local array<TTile> TilesEntered;
	local Vector AttackDirection;
	local array<StateObjectReference> Targets;
	local StateObjectReference CurrentTarget;
	local XComGameState_Unit TargetUnit;
	local TTile NewTileLocation;
	local float KnockbackDamage;
	local float KnockbackRadius;
	local int EffectIndex, MultiTargetIndex;
	local X2Effect_ForcePush KnockbackEffect;

	//`LOG("X2Effect_ForcePush ApplyEffectToWorld",, 'JediClass');

	AbilityContext = XComGameStateContext_Ability(NewGameState.GetContext());
	if(AbilityContext != none)
	{
		if (AbilityContext.InputContext.PrimaryTarget.ObjectID > 0)
		{
			// Check the Primary Target for a successful knockback
			for (EffectIndex = 0; EffectIndex < AbilityContext.ResultContext.TargetEffectResults.Effects.Length; ++EffectIndex)
			{
				KnockbackEffect = X2Effect_ForcePush(AbilityContext.ResultContext.TargetEffectResults.Effects[EffectIndex]);
				if (KnockbackEffect != none)
				{
					if (AbilityContext.ResultContext.TargetEffectResults.ApplyResults[EffectIndex] == 'AA_Success')
					{
						Targets.AddItem(AbilityContext.InputContext.PrimaryTarget);
						break;
					}
				}
			}
		}

		for (MultiTargetIndex = 0; MultiTargetIndex < AbilityContext.InputContext.MultiTargets.Length; ++MultiTargetIndex)
		{
			// Check the MultiTargets for a successful knockback
			for (EffectIndex = 0; EffectIndex < AbilityContext.ResultContext.MultiTargetEffectResults[MultiTargetIndex].Effects.Length; ++EffectIndex)
			{
				KnockbackEffect = X2Effect_ForcePush(AbilityContext.ResultContext.MultiTargetEffectResults[MultiTargetIndex].Effects[EffectIndex]);
				if (KnockbackEffect != none)
				{
					if (AbilityContext.ResultContext.MultiTargetEffectResults[MultiTargetIndex].ApplyResults[EffectIndex] == 'AA_Success')
					{
						Targets.AddItem(AbilityContext.InputContext.MultiTargets[MultiTargetIndex]);
						`LOG("X2Effect_ForcePush Add multi target" @ AbilityContext.InputContext.MultiTargets[MultiTargetIndex].ObjectID,, 'JediClass');
						break;
					}
				}
			}
		}

		foreach Targets(CurrentTarget)
		{
			KnockbackDamage = default.DefaultDamage;
			KnockbackRadius = default.DefaultRadius;

			kNewTargetState = NewGameState.GetGameStateForObjectID(CurrentTarget.ObjectID);
			TargetUnit = XComGameState_Unit(kNewTargetState);
			if(TargetUnit != none) //Only units can be knocked back
			{
				TilesEntered.Length = 0;
				GetTilesEnteredArray(AbilityContext, kNewTargetState, TilesEntered, AttackDirection, KnockbackDamage);

				//Only process the code below if the target went somewhere
				if(TilesEntered.Length > 0)
				{
					WorldData = `XWORLD;

					if(bKnockbackDestroysNonFragile)
					{
						for(Index = 0; Index < TilesEntered.Length; ++Index)
						{
							HitTile = TilesEntered[Index];
							HitTile.Z += 1;

							DamageEvent = XComGameState_EnvironmentDamage(NewGameState.CreateStateObject(class'XComGameState_EnvironmentDamage'));
							DamageEvent.DEBUG_SourceCodeLocation = "UC: X2Effect_ForcePush:ApplyEffectToWorld";
							DamageEvent.DamageAmount = KnockbackDamage;
							DamageEvent.DamageTypeTemplateName = 'Melee';
							DamageEvent.HitLocation = WorldData.GetPositionFromTileCoordinates(HitTile);
							DamageEvent.HitLocationTile = HitTile;
							DamageEvent.Momentum = AttackDirection;
							DamageEvent.DamageDirection = AttackDirection; //Limit environmental damage to the attack direction( ie. spare floors )
							DamageEvent.PhysImpulse = 500;
							DamageEvent.DamageRadius = KnockbackRadius;
							DamageEvent.DamageCause = ApplyEffectParameters.SourceStateObjectRef;
							DamageEvent.DamageSource = DamageEvent.DamageCause;
							DamageEvent.bRadialDamage = false;
							DamageEvent.bIsHit = true;
							NewGameState.AddStateObject(DamageEvent);
							//`LOG("X2Effect_ForcePush Add DamageEvent",, 'JediClass');
						}
					}

					NewTileLocation = TilesEntered[TilesEntered.Length - 1];
					TargetUnit.SetVisibilityLocation(NewTileLocation);
				}
			}			
		}
	}
}

simulated function int CalculateDamageAmount(const out EffectAppliedData ApplyEffectParameters, out int ArmorMitigation, out int NewShred)
{
	return 0;
}

simulated function bool PlusOneDamage(int Chance)
{
	return false;
}

simulated function bool IsExplosiveDamage() 
{ 
	return false; 
}

simulated function AddX2ActionsForVisualization(XComGameState VisualizeGameState, out VisualizationTrack BuildTrack, name EffectApplyResult)
{
	local X2Action_ForcePush KnockbackAction;
	local X2Action_CameraFollowUnit CameraFollowAction;

	//`LOG("X2Effect_ForcePush AddX2ActionsForVisualization",, 'JediClass');

	if (EffectApplyResult == 'AA_Success')
	{
		if (BuildTrack.StateObject_NewState.IsA('XComGameState_Unit'))
		{
			if (XComGameState_Unit(BuildTrack.StateObject_NewState).IsAlive())
			{
				CameraFollowAction = X2Action_CameraFollowUnit(class'X2Action_CameraFollowUnit'.static.AddToVisualizationTrack(BuildTrack, VisualizeGameState.GetContext()));
				CameraFollowAction.AbilityToFrame = XComGameStateContext_Ability(VisualizeGameState.GetContext());

				//`LOG("X2Effect_ForcePush Add X2Action_ForcePush",, 'JediClass');
				KnockbackAction = X2Action_ForcePush(class'X2Action_ForcePush'.static.AddToVisualizationTrack(BuildTrack, VisualizeGameState.GetContext()));
				KnockbackAction.ForcePushAnimSequence = ForcePushAnimSequence;
				//KnockbackAction.AnimationDelay = 1.0f + RandRange(0.0f, 1.0f);
				
			}
		}
		else if (BuildTrack.StateObject_NewState.IsA('XComGameState_EnvironmentDamage') || BuildTrack.StateObject_NewState.IsA('XComGameState_Destructible'))
		{
			//This can be added by other effects, so check to see whether this track already has one of these
			if (!`XCOMVISUALIZATIONMGR.TrackHasActionOfType(BuildTrack, class'X2Action_ApplyWeaponDamageToTerrain'))
			{
				class'X2Action_ApplyWeaponDamageToTerrain'.static.AddToVisualizationTrack(BuildTrack, VisualizeGameState.GetContext());
			}
		}
	}
}

simulated function AddX2ActionsForVisualization_Tick(XComGameState VisualizeGameState, out VisualizationTrack BuildTrack, const int TickIndex, XComGameState_Effect EffectState)
{
	
}

defaultproperties
{
	IncrementalStepSize=8.0

	Begin Object Class=X2Condition_UnitProperty Name=UnitPropertyCondition
		ExcludeTurret = true
		ExcludeDead = true
	End Object

	TargetConditions.Add(UnitPropertyCondition)

	DamageTypes.Add("KnockbackDamage");

	DefaultDamage=100000.0
	DefaultRadius=16.0

	OverrideRagdollFinishTimerSec=-1

	ApplyChanceFn=WasTargetPreviouslyDead
}	