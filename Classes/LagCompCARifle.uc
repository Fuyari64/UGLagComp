class LagCompCARifle extends CARifle;

var float TraceRange;
var bool bIsAltFire;

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
	local vector RewindLoc, TraceDir;
	local Actor ConfirmedHit;
	local HitboxGhost Ghost;
	local float ActiveSpread, ClientTime;
	local int i, Damage;
	local vector ToTarget;
	local Effects WallHit;

	if ( bIsAltFire )
		ActiveSpread = 100.0;
	else
		ActiveSpread = 0.0;

	GetAxes(Owner.Rotation, X, Y, Z);
	StartTrace = Owner.Location + FireOffset.X * X + FireOffset.Y * Y + FireOffset.Z * Z;
	SpreadOffset = class'LagCompRewindManager'.static.GetInstance(Level).GetSpreadOffset(SpreadSeed, Y, Z, ActiveSpread);
	EndTrace = StartTrace + X * TraceRange + SpreadOffset;

	TraceDir = Normal(EndTrace - StartTrace);
	ClientTime = GetClientShotTime(PlayerPawn(Owner));
	M = class'LagCompRewindManager'.static.GetInstance(Level);
	if ( !M.RewindPlayer(PlayerPawn(Owner), ClientTime, StartTrace) )
	{
		log("LagCompCARifle: No rewind data for shooter, using current location");
		StartTrace = Owner.Location;
	}
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
		{
			log("LagCompCARifle: Failed to spawn ghost for "$M.TrackedNPCs[i].Name);
			continue;
		}

		Ghost.SetCollisionSize(M.TrackedNPCs[i].CollisionRadius, M.TrackedNPCs[i].CollisionHeight);
		Ghost.SetCollision(True, True, True);
		ConfirmedHit = Trace(HitLoc, HitNorm, EndTrace, StartTrace, True);
		if ( ConfirmedHit == Ghost )
		{
			log("LagCompCARifle: Ghost rewind confirmed hit on "$M.TrackedNPCs[i].Name);

			if ( M.TrackedNPCs[i] == Level || M.TrackedNPCs[i].bWorldGeometry || M.TrackedNPCs[i].bIsMover || M.TrackedNPCs[i].Brush )
			{
				if ( FRand() < 0.5 )
					WallHit = Level.Spawn(class'CARWallHitEffect2',,, HitLoc + HitNorm * 9, Rotator(HitNorm));
				else WallHit = Level.Spawn(class'CARWallHitEffect',,, HitLoc + HitNorm * 9, Rotator(HitNorm));
				WallHit.DrawScale -= FRand();
			}
			else if ( !M.TrackedNPCs[i].bIsPawn && !M.TrackedNPCs[i].IsA('Carcass') )
			{
				if ( FRand() < 0.01 )
				{
					WallHit = Level.Spawn(class'SpriteSmokePuff',,, HitLoc + HitNorm * 9);
					WallHit.DrawScale -= FRand();
				}
			}

			if ( Level.Game.IsA('SinglePlayer') )
				Damage = Rand(5) + 2;
			else Damage = Rand(10) + 2;

			if ( M.TrackedNPCs[i].IsA('Carcass') )
				Damage = 10 + Rand(10);

			if ( Owner.IsA('SpaceMarine') )
				M.TrackedNPCs[i].TakeDamage(Damage, Pawn(Owner), HitLoc, Damage * 500.0 * TraceDir, 'shot');
			else M.TrackedNPCs[i].TakeDamage(Damage, Pawn(Owner), HitLoc, Damage * 250.0 * TraceDir, 'shot');

			Ghost.Destroy();
			return True;
		}

		Ghost.Destroy();
	}

	log("LagCompCARifle: Unable to find enemy. Defaulting to engine processing. Actor hit: "$HitActor.Name);
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
}
