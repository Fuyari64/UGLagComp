class LagCompSniperRifle extends Rifle;

var float TraceRange;
var int HeadshotDamage;
var int BodyDamage;

function bool IsEnemyActor(Actor A)
{
	return A != None && A.IsA('Pawn') && Pawn(A).bIsPawn && !Pawn(A).bIsPlayer;
}

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
	local float ClientTime;
	local int i;
	local vector ToTarget;
	local int FinalDamage;
	local float Momentum;
	local name DamageType;

	GetAxes(Owner.Rotation, X, Y, Z);
	StartTrace = Owner.Location + FireOffset.X * X + FireOffset.Y * Y + FireOffset.Z * Z;
	SpreadOffset = class'LagCompRewindManager'.static.GetInstance(Level).GetSpreadOffset(SpreadSeed, Y, Z, 0.0);
	EndTrace = StartTrace + X * TraceRange + SpreadOffset;
	TraceDir = Normal(EndTrace - StartTrace);

	ClientTime = GetClientShotTime(PlayerPawn(Owner));
	M = class'LagCompRewindManager'.static.GetInstance(Level);
	if ( !M.RewindPlayer(PlayerPawn(Owner), ClientTime, StartTrace) )
	{
		log("LagCompSniperRifle: No rewind data for shooter, using current location");
		StartTrace = Owner.Location;
	}
	StartTrace += FireOffset.X * X + FireOffset.Y * Y + FireOffset.Z * Z;
	EndTrace = StartTrace + X * TraceRange + SpreadOffset;
	TraceDir = Normal(EndTrace - StartTrace);

	// Try against all tracked NPCs
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
			log("LagCompSniperRifle: Failed to spawn ghost for "$M.TrackedNPCs[i].Name);
			continue;
		}

		Ghost.SetCollisionSize(M.TrackedNPCs[i].CollisionRadius, M.TrackedNPCs[i].CollisionHeight);
		ConfirmedHit = Trace(HitLoc, HitNorm, EndTrace, StartTrace, True);
		if ( ConfirmedHit == Ghost )
		{
			log("LagCompSniperRifle: Ghost rewind confirmed hit on "$M.TrackedNPCs[i].Name);
			
			// Check for headshot - need to use rewound position for accurate headshot detection
			if ( M.TrackedNPCs[i].bIsPawn && (Instigator.bIsPlayerPawn || (Instigator.skill > 1)) && 
				M.TrackedNPCs[i].IsHeadShot(HitLoc, TraceDir) )
			{
				FinalDamage = HeadshotDamage;
				Momentum = 35000.0;
				DamageType = 'decapitated';
				log("LagCompSniperRifle: Headshot confirmed on "$M.TrackedNPCs[i].Name);
			}
			else
			{
				FinalDamage = BodyDamage;
				Momentum = 30000.0;
				DamageType = 'shot';
			}
			
			M.TrackedNPCs[i].TakeDamage(
				FinalDamage,
				Pawn(Owner),
				HitLoc,
				Momentum * TraceDir,
				DamageType
			);
			Ghost.Destroy();
			return True;
		}

		Ghost.Destroy();
	}

	log("LagCompSniperRifle: Unable to find enemy. Defaulting to engine processing. Actor hit: "$HitActor.Name);

	return False;
}

function float GetClientShotTime(PlayerPawn Shooter)
{
	if ( Shooter.PlayerReplicationInfo == None )
		return Level.TimeSeconds;

	return Level.TimeSeconds - (float(Shooter.PlayerReplicationInfo.Ping) / 200.0);
}

function GiveTo(Pawn Other)
{
	Super.GiveTo(Other);
	SetOwner(Other);
	Instigator = Other;
	if ( Other.Weapon == Self )
	{
		BringUp();
		bWeaponUp = True;
	}
}

defaultproperties
{
	RemoteRole=ROLE_SimulatedProxy
	bNetTemporary=False
	bAlwaysRelevant=True
	bReplicateInstigator=True
	TraceRange=10000.0
	HeadshotDamage=100
	BodyDamage=45
}