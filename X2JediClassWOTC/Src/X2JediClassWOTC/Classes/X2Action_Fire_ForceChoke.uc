class X2Action_Fire_ForceChoke extends X2Action_Fire;

var XComUnitPawn TargetUnitPawn;
var CustomAnimParams Params;
var vector SourceToTarget;
var float TimeUntilRagdoll;
var int ScanNotify;
var AnimNotifyEvent NotifyEvent;
var AnimNodeSequence StopUnitSequence, StopTargetSequence;
var Name TargetBeginAnim, TargetEndAnim, SourceBeginAnim;

function Init()
{
	super.Init();

	TargetUnitPawn = TargetUnit.GetPawn();

	SourceToTarget = TargetUnitPawn.Location - UnitPawn.Location;
}

simulated state Executing
{
Begin:
	UnitPawn.EnableRMA(true, true);
	UnitPawn.EnableRMAInteractPhysics(true);
	UnitPawn.bSkipIK = true;
	TargetUnitPawn.EnableRMA(true, true);
	TargetUnitPawn.EnableRMAInteractPhysics(true);
	TargetUnitPawn.bSkipIK = true;
	TargetUnit.IdleStateMachine.GoDormant(UnitPawn);

	TargetUnitPawn.GetAnimTreeController().SetAllowNewAnimations(true);
	Params = default.Params;
	Params.AnimName = TargetBeginAnim;
	Params.Looping = false;
	Params.DesiredEndingAtoms.Add(1);
	Params.DesiredEndingAtoms[0].Translation = TargetUnitPawn.Location;
	Params.DesiredEndingAtoms[0].Translation.Z = TargetUnitPawn.GetDesiredZForLocation(TargetUnitPawn.Location);
	Params.DesiredEndingAtoms[0].Rotation = QuatFromRotator(Rotator(-SourceToTarget));
	Params.DesiredEndingAtoms[0].Scale = 1.0f;
	TargetUnitPawn.GetAnimTreeController().PlayFullBodyDynamicAnim(Params);
	TargetUnitPawn.GetAnimTreeController().SetAllowNewAnimations(false);

	Params = default.Params;
	Params.AnimName = SourceBeginAnim;
	Params.Looping = false;
	FinishAnim(UnitPawn.GetAnimTreeController().PlayFullBodyDynamicAnim(Params));

	TimeUntilRagdoll = -1.0f;

	Params = default.Params;
	Params.AnimName = TargetEndAnim;
	Params.Looping = false;
	TargetUnitPawn.GetAnimTreeController().SetAllowNewAnimations(true);
	StopTargetSequence = TargetUnitPawn.GetAnimTreeController().PlayFullBodyDynamicAnim(Params);
	if( StopTargetSequence != None && StopTargetSequence.AnimSeq != None )
	{
		for( ScanNotify = 0; ScanNotify < StopTargetSequence.AnimSeq.Notifies.Length; ++ScanNotify )
		{
			NotifyEvent = StopTargetSequence.AnimSeq.Notifies[ScanNotify];
			if( XComAnimNotify_Ragdoll(NotifyEvent.Notify) != None )
			{
				TimeUntilRagdoll = NotifyEvent.Time;
			}
		}
	}

	if(TimeUntilRagdoll != -1.0f )
	{
		Sleep(TimeUntilRagdoll);
		//TargetUnitPawn.StartRagDoll();
	}
	//FinishAnim(StopUnitSequence);


	CompleteAction();
}

defaultproperties
{
	SourceBeginAnim = "FF_ForceChokeA"
	TargetBeginAnim = "FF_ForceChokedStartA"
	TargetEndAnim = "FF_ForceChokedStopA"
}