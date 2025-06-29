class LagCompMinigun extends Minigun;

var float TraceRange;
var int Damage;

function ProcessTraceHit(Actor Other, vector HitLocation, vector HitNormal, vector X, vector Y, vector Z)
{
	if ( !ServerHit(Other, HitLocation, class'LagCompRewindManager'.static.GetInstance(Level).GetSharedRandomSeed(PlayerPawn(Owner))) )
	{
		Super.ProcessTraceHit(Other, HitLocation, HitNormal, X, Y, Z);
	}
}

function bool ServerHit(Actor HitActor, vector HitLocation, int SpreadSeed)
{
	local LagCompRewindManager M;
	local vector StartTrace, EndTrace, HitLoc, HitNorm, X, Y, Z, SpreadOffset;
	local vector RewindLoc, ToTarget;
	local Actor ConfirmedHit;
	local HitboxGhost Ghost;
	local float ActiveSpread, ClientTime;
	local int i, rndDam;

	ActiveSpread = 100.0;

	GetAxes(Owner.Rotation, X, Y, Z);
	StartTrace = Owner.Location + FireOffset.X * X + FireOffset.Y * Y + FireOffset.Z * Z;
	SpreadOffset = class'LagCompRewindManager'.static.GetInstance(Level).GetSpreadOffset(SpreadSeed, Y, Z, ActiveSpread);
	EndTrace = StartTrace + X * TraceRange + SpreadOffset;

	ClientTime = GetClientShotTime(PlayerPawn(Owner));
	M = class'LagCompRewindManager'.static.GetInstance(Level);
	if ( !M.RewindPlayer(PlayerPawn(Owner), ClientTime, StartTrace) )
		StartTrace = Owner.Location;

	StartTrace += FireOffset.X * X + FireOffset.Y * Y + FireOffset.Z * Z;
	EndTrace = StartTrace + X * TraceRange + SpreadOffset;

	for ( i = 0; i < M.NPCCount; i++ )
	{
		ToTarget = Normal(M.TrackedNPCs[i].Location - StartTrace);
		if ( (X dot ToTarget) < 0.8 )
			continue;

		if ( !M.RewindAndValidate(M.TrackedNPCs[i], ClientTime, RewindLoc) )
			continue;

		Ghost = Level.Spawn(class'UGLagComp.HitboxGhost',,, RewindLoc);
		if ( Ghost == None )
			continue;

		Ghost.SetCollisionSize(M.TrackedNPCs[i].CollisionRadius, M.TrackedNPCs[i].CollisionHeight);
		Ghost.SetCollision(True, True, True);
		ConfirmedHit = Trace(HitLoc, HitNorm, EndTrace, StartTrace, True);

		if ( ConfirmedHit == Ghost )
		{
			if( M.TrackedNPCs[i]==Level || M.TrackedNPCs[i].bWorldGeometry || M.TrackedNPCs[i].bIsMover || M.TrackedNPCs[i].Brush )
				Level.Spawn(class'LightWallHitEffect',,, HitLoc+HitNorm*9, Rotator(HitNorm));
			else if( !M.TrackedNPCs[i].bIsPawn && !M.TrackedNPCs[i].IsA('Carcass') )
				Level.Spawn(class'SpriteSmokePuff',,, HitLoc+HitNorm*9);
			else if( M.TrackedNPCs[i].IsA('ScriptedPawn') && FRand() < 0.2 )
				M.TrackedNPCs[i].WarnTarget(Pawn(Owner), 500, X);

			rndDam = 8 + Rand(6);
			M.TrackedNPCs[i].TakeDamage(
				rndDam,
				Pawn(Owner),
				HitLoc,
				(rndDam * ((FRand()<0.2) ? 1000.f : 500.f)) * Normal(EndTrace - StartTrace),
				'shot'
			);

			Ghost.Destroy();
			return True;
		}

		Ghost.Destroy();
	}

	return False;
}

function float GetClientShotTime(PlayerPawn Shooter)
{
	if ( Shooter.PlayerReplicationInfo == None )
		return Level.TimeSeconds;

	return Level.TimeSeconds - (float(Shooter.PlayerReplicationInfo.Ping) / 200.0);
}

defaultproperties
{
	RemoteRole=ROLE_SimulatedProxy
	bNetTemporary=False
	bAlwaysRelevant=True
	bReplicateInstigator=True
	TraceRange=10000.0
	Damage=10
}
