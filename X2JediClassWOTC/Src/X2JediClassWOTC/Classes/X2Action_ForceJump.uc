class X2Action_ForceJump extends X2Action_Move;

const StartLandingAnimationTime = 0.5;
const MinPathTime = 0.1;
const JumpStartPlayRate = 2.3;
const JumpStopPlayRate = 3.0;
const JumpRateScale = 0.7;
const StartScaleFrom = 1.5;
const StartJumpLoopTransitionEarly = 0.2;

var vector  DesiredLocation;

var private BoneAtom StartingAtom;
var private Rotator DesiredRotation;
var private CustomAnimParams Params;
var private vector StartingLocation;
var private float DistanceFromStartSquared;
var private bool ProjectileHit, bSkipJump;
var private float StopDistanceSquared; // distance from the origin of the grapple past which we are done
var private AnimNodeSequence PlayingSequence;
var private bool bStartTraversalAlongPath, bStartLandingAnimation;
var float TraversalTime;
var XComPrecomputedPath Path;
var XComGameStateContext_Ability AbilityContext;
var bool bSkipLandingAnimation;
var float TriggerDistance; // Distance (in tiles) for tile entry to trigger window breaks (or other enviromental destruction)

function Init()
{
	local vector EmptyVector;
	
	super.Init();

	AbilityContext = XComGameStateContext_Ability(StateChangeContext);

	if (DesiredLocation == EmptyVector)
	{
		if (AbilityContext.InputContext.MovementPaths[0].MovementData.Length > 1)
		{
			DesiredLocation = AbilityContext.InputContext.MovementPaths[0].MovementData[AbilityContext.InputContext.MovementPaths[0].MovementData.Length - 1].Position;
		}
		else
		{
			DesiredLocation = UnitPawn.Location;
			bSkipJump = true;
		}
	}
	`LOG(default.class @ GetFuncName() @ `ShowVar(AbilityContext) @ `ShowVar(DesiredLocation),, 'X2JediClassWOTC');
}

function NotifyEnvironmentDamage(int PreviousPathTileIndex, bool bFragileOnly = true, bool bCheckForDestructibleObject = false)
{
	local float DestroyTileDistance;
	local Vector HitLocation;
	local Vector TileLocation;
	local XComGameState_EnvironmentDamage EnvironmentDamage;		
	local XComWorldData WorldData;
	local TTile PathTile;
	local int Index;		

	WorldData = `XWORLD;
	//If the unit jumped more than one tile index, make sure it is caught
	for(Index = PreviousPathTileIndex; Index <= PathTileIndex; ++Index)
	{
		if (bCheckForDestructibleObject)
		{
			//Only trigger nearby environment damage if the traversal to the next tile has a destructible object
			if (AbilityContext.InputContext.MovementPaths[MovePathIndex].Destructibles.Length == 0 || 
				AbilityContext.InputContext.MovementPaths[MovePathIndex].Destructibles.Find(Index + 1) == INDEX_NONE)
			{
				continue;
			}
		}

		foreach LastInGameStateChain.IterateByClassType(class'XComGameState_EnvironmentDamage', EnvironmentDamage)
		{
			`log(`showvar(EnvironmentDamage));
			if (EnvironmentDamage.DamageCause.ObjectID != Unit.ObjectID)
				continue;
			HitLocation = WorldData.GetPositionFromTileCoordinates(EnvironmentDamage.HitLocationTile);			
			PathTile = AbilityContext.InputContext.MovementPaths[MovePathIndex].MovementTiles[Index];
			TileLocation = WorldData.GetPositionFromTileCoordinates(PathTile);
			
			DestroyTileDistance = VSize(HitLocation - TileLocation);
			`log(`showvar(TileLocation));
			`log(`showvar(HitLocation));
			`log(`showvar(DestroyTileDistance));
			if(DestroyTileDistance < (class'XComWorldData'.const.WORLD_StepSize * TriggerDistance)) /* for force jump purposes, don't care about the fragile flag */
			{				
				`XEVENTMGR.TriggerEvent('Visualizer_WorldDamage', EnvironmentDamage, self);				
				`log("Shots fired!!");
			}
		}
	}
}

simulated function bool MoveAlongPath(float fTime, XComUnitPawn pActor)
{
	local XKeyframe KF;
	local float UnitTileZ, FinishTime;
	local vector TargetLocation, PathEndPosition;
	local TTile Tile;
	local Rotator PawnRotation;
	
	//fTime *= 1.8;

	KF = Path.ExtractInterpolatedKeyframe(fTime);
	TargetLocation = KF.vLoc;

	// Clamp to floor tile when landing
	if (fTime > Path.akKeyframes[Path.iNumKeyframes / 4].fTime)
	{
		PathEndPosition = Path.GetEndPosition();
		Tile = `XWORLD.GetTileCoordinatesFromPosition(PathEndPosition);
		PathEndPosition = `XWORLD.GetPositionFromTileCoordinates(Tile);
		Path.akKeyframes[Path.iNumKeyframes-1].vLoc = PathEndPosition;
		UnitTileZ = `XWORLD.GetFloorZForPosition(PathEndPosition, true) + pActor.CollisionHeight + class'XComWorldData'.const.Cover_BufferDistance;
		TargetLocation.Z = Max(UnitTileZ, KF.vLoc.Z);
	}

	//`LOG(GetFuncName() @ `ShowVar(TargetLocation.Z) @ `ShowVar(KF.vLoc.Z),, 'X2JediClassWOTC');

	pActor.SetLocation(TargetLocation);
	PawnRotation = pActor.Rotation;
	PawnRotation.Yaw = KF.rRot.Yaw;
	pActor.SetRotation(PawnRotation);

	FinishTime = Path.akKeyframes[Path.iNumKeyframes-1].fTime;
	if (FinishTime - StartLandingAnimationTime > MinPathTime)
	{
		FinishTime -= StartLandingAnimationTime;
	}
	else
	{
		FinishTime -= MinPathTime;
	}

	if (fTime >= FinishTime)
		return true;
	else return false;
}

function InterpolatePath(float StartZ)
{
	local int Index;
	local float Diff, MaxDiff, Decrement;

	Diff = Path.akKeyframes[0].vLoc.Z - StartZ;
	MaxDiff = Diff;

	for(Index = 0; Index < Path.iNumKeyframes; Index++)
	{
		if (Index >= (Path.iNumKeyframes / 2) - 2)
		{
			Decrement = int((MaxDiff / Path.iNumKeyframes) + 0.5) * 2;
			Diff -= Max(Decrement, 0);
		}

		//`LOG(GetFuncName() @ `ShowVar(Diff),, 'X2JediClassWOTC');

		Path.akKeyframes[Index].vLoc.Z -= Diff;
		
		if (Path.akKeyframes[Path.iNumKeyframes-1].fTime >= StartScaleFrom)
		{
			Path.akKeyframes[Index].fTime *= JumpRateScale;
		}
	}
}

simulated state Executing
{
	//function SendWindowBreakNotifies()
	//{	
	//	local XComGameState_EnvironmentDamage EnvironmentDamage;
	//			
	//	foreach VisualizeGameState.IterateByClassType(class'XComGameState_EnvironmentDamage', EnvironmentDamage)
	//	{
	//		`XEVENTMGR.TriggerEvent('Visualizer_WorldDamage', EnvironmentDamage, self);
	//	}
	//}

	simulated event Tick(float fDelta)
	{
		if (bStartTraversalAlongPath)
		{
			TraversalTime += fDelta;

			if (MoveAlongPath(TraversalTime, UnitPawn))
			{
				bStartLandingAnimation = true;
			}
		}
	}

Begin:
	`LOG(default.class @ GetFuncName() @ `ShowVar(UnitPawn.Location) @ `ShowVar(DesiredLocation) @ `ShowVar(bSkipJump),, 'X2JediClassWOTC');

	if (bSkipJump)
	{
		CompleteAction();
	}
	
	Path = XComTacticalGRI(class'Engine'.static.GetCurrentWorldInfo().GRI).GetPrecomputedPath();

	UnitPawn.EnableRMA(true, true);
	UnitPawn.EnableRMAInteractPhysics(true);
	UnitPawn.bSkipIK = true;

	Params.AnimName = 'HL_ForceJumpStart';
	Params.PlayRate = JumpStartPlayRate;
	PlayingSequence = UnitPawn.GetAnimTreeController().PlayFullBodyDynamicAnim(Params);

	`LOG(default.class @ GetFuncName() @ `ShowVar(Params.AnimName),, 'X2JediClassWOTC');

	sleep(PlayingSequence.GetAnimPlaybackLength() - StartJumpLoopTransitionEarly);

	Path.bUseOverrideTargetLocation = true;
	Path.bUseOverrideSourceLocation = true;
	Path.OverrideSourceLocation = UnitPawn.Location;
	Path.OverrideTargetLocation = DesiredLocation;
	Path.OverrideTargetLocation.Z = Unit.GetDesiredZForLocation(DesiredLocation);
	Path.bNoSpinUntilBounce = true;
	Path.UpdateTrajectory();
	Path.bUseOverrideTargetLocation = false;
	Path.bUseOverrideSourceLocation = false;
	InterpolatePath(Unit.Location.Z);

	`LOG(default.class @ GetFuncName() @ `ShowVar(UnitPawn.Location),, 'X2JediClassWOTC');

	bStartTraversalAlongPath = true;

	UnitPawn.GetAnimTreeController().SetAllowNewAnimations(true);
	Params = default.Params;
	Params.AnimName = 'HL_ForceJumpLoop';
	PlayingSequence = UnitPawn.GetAnimTreeController().PlayFullBodyDynamicAnim(Params);
	while(!bStartLandingAnimation)
	{
		//PlayingSequence.ReplayAnim();
		FinishAnim(PlayingSequence, true, 0.05);
		if (bStartLandingAnimation)
		{
			PlayingSequence.StopAnim();
		}
		sleep(0);
		`LOG(default.class @ GetFuncName() @ `ShowVar(Params.AnimName),, 'X2JediClassWOTC');
		
	}
	PlayingSequence.StopAnim();

	UnitPawn.GetAnimTreeController().SetAllowNewAnimations(true);
	UnitPawn.EnableRMA(true, true);
	UnitPawn.EnableRMAInteractPhysics(true);
	
	UnitPawn.SnapToGround();

	if (!bSkipLandingAnimation)
	{
		//DesiredRotation = Rotator(Normal(DesiredLocation - UnitPawn.Location));
		Params = default.Params;
		Params.AnimName = 'HL_ForceJumpStop';
		Params.PlayRate = JumpStopPlayRate;
		//Params.DesiredEndingAtoms.Add(1);
		//Params.DesiredEndingAtoms[0].Scale = 1.0f;
		//Params.DesiredEndingAtoms[0].Translation = Path.OverrideTargetLocation;
		//DesiredRotation = UnitPawn.Rotation;
		//DesiredRotation.Pitch = 0.0f;
		//DesiredRotation.Roll = 0.0f;
		//Params.DesiredEndingAtoms[0].Rotation = QuatFromRotator(DesiredRotation);
		FinishAnim(UnitPawn.GetAnimTreeController().PlayFullBodyDynamicAnim(Params));
		UnitPawn.bSkipIK = false;
	}

	`LOG(default.class @ GetFuncName() @ `ShowVar(Params.AnimName),, 'X2JediClassWOTC');

	UnitPawn.SetLocation(Path.OverrideTargetLocation);

	CompleteAction();
}

//function CompleteAction()
//{
//	super.CompleteAction();
//
//	// since we step out of and step into cover from different tiles, 
//	// need to set the enter cover restore to the destination location
//	Unit.RestoreLocation = DesiredLocation;
//}

defaultproperties
{
	ProjectileHit = false;
}


	//while( ProjectileHit == false )
	//{
	//	Sleep(0.0f);
	//}

	// Have an emphasis on seeing the grapple tight
	//Sleep(0.1f);

	//Params.AnimName = 'NO_GrappleStart';
	//DesiredLocation.Z = Unit.GetDesiredZForLocation(DesiredLocation);
	//DesiredRotation = Rotator(Normal(DesiredLocation - UnitPawn.Location));
	//StartingAtom.Rotation = QuatFromRotator(DesiredRotation);
	//StartingAtom.Translation = UnitPawn.Location;
	//StartingAtom.Scale = 1.0f;
	//UnitPawn.GetAnimTreeController().GetDesiredEndingAtomFromStartingAtom(Params, StartingAtom);
	//PlayingSequence = UnitPawn.GetAnimTreeController().PlayFullBodyDynamicAnim(Params);
	//
	//// hide the targeting icon
	//Unit.SetDiscState(eDS_None);
	//
	//StartingLocation = UnitPawn.Location;
	//StopDistanceSquared = Square(VSize(DesiredLocation - StartingLocation) - UnitPawn.fStrangleStopDistance);
	//
	//// to protect against overshoot, rather than check the distance to the target, we check the distance from the source.
	//// Otherwise it is possible to go from too far away in front of the target, to too far away on the other side
	//DistanceFromStartSquared = 0;
	//while( DistanceFromStartSquared < StopDistanceSquared )
	//{
	//	if( !PlayingSequence.bRelevant || !PlayingSequence.bPlaying || PlayingSequence.AnimSeq == None )
	//	{
	//		if( DistanceFromStartSquared < StopDistanceSquared )
	//		{
	//			`RedScreen("Grapple never made it to the destination");
	//		}
	//		break;
	//	}
	//
	//	Sleep(0.0f);
	//	DistanceFromStartSquared = VSizeSq(UnitPawn.Location - StartingLocation);
	//}

	// send messages to do the window break visualization
	//SendWindowBreakNotifies();


	defaultproperties
	{
		TriggerDistance = 0.5
	}