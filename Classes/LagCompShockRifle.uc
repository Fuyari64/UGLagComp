class LagCompShockRifle extends ASMD;

var float TraceRange;
var int Damage;
var bool bIsAltFire;

function bool IsEnemyActor(Actor A)
{
	return A != None && A.IsA('Pawn') && Pawn(A).bIsPawn && !Pawn(A).bIsPlayer;
}

function ProcessTraceHit(Actor Other, vector HitLocation, vector HitNormal, vector X, vector Y, vector Z)
{
	// Only use lag comp for primary fire against enemies
	if ( !bIsAltFire && !ServerHit(Other, HitLocation, class'LagCompRewindManager'.static.GetInstance(Level).GetSharedRandomSeed(PlayerPawn(Owner))) )
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
	local float ClientTime, Mult;
	local int i;
	local vector ToTarget;

	// Skip alt fire - that's projectile based
	if ( bIsAltFire )
		return False;

	// Handle amplifier
	if ( bool(Amp) )
		Mult = Amp.UseCharge(100);
	else 
		Mult = 1.0;

	GetAxes(Owner.Rotation, X, Y, Z);
	StartTrace = Owner.Location + FireOffset.X * X + FireOffset.Y * Y + FireOffset.Z * Z;
	SpreadOffset = class'LagCompRewindManager'.static.GetInstance(Level).GetSpreadOffset(SpreadSeed, Y, Z, 0.0);
	EndTrace = StartTrace + X * TraceRange + SpreadOffset;
	TraceDir = Normal(EndTrace - StartTrace);

	ClientTime = GetClientShotTime(PlayerPawn(Owner));
	M = class'LagCompRewindManager'.static.GetInstance(Level);
	if ( !M.RewindPlayer(PlayerPawn(Owner), ClientTime, StartTrace) )
	{
		log("LagCompShockRifle: No rewind data for shooter, using current location");
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
			log("LagCompShockRifle: Failed to spawn ghost for "$M.TrackedNPCs[i].Name);
			continue;
		}

		Ghost.SetCollisionSize(M.TrackedNPCs[i].CollisionRadius, M.TrackedNPCs[i].CollisionHeight);
		ConfirmedHit = Trace(HitLoc, HitNorm, EndTrace, StartTrace, True);
		if ( ConfirmedHit == Ghost )
		{
			log("LagCompShockRifle: Ghost rewind confirmed hit on "$M.TrackedNPCs[i].Name);
			
			PlayASMDVisualEffects(StartTrace, HitLoc);
			
			// Ignoring this, let default engine handle it.
			// if ( TazerProj(M.TrackedNPCs[i]) )
			// {
			// 	AmmoType.UseAmmo(2);
			// 	M.TrackedNPCs[i].Instigator = Pawn(Owner);
			// 	TazerProj(M.TrackedNPCs[i]).SuperExplosion();
			// }
			M.TrackedNPCs[i].TakeDamage(
				Damage * Mult,
				Pawn(Owner),
				HitLoc,
				50000.0 * TraceDir,
				'jolted'
			);
			
			SpawnShockExplosion(HitLoc, HitNorm, Mult);
			
			Ghost.Destroy();
			return True;
		}

		Ghost.Destroy();
	}

	log("LagCompShockRifle: Unable to find enemy. Defaulting to engine processing. Actor hit: "$HitActor.Name);

	return False;
}

function PlayASMDVisualEffects(vector StartTrace, vector HitLocation)
{
	local vector DVector;
	local int NumPoints;

	DVector = HitLocation - StartTrace;
	NumPoints = Min(VSize(DVector) / 70.0, 15);

	if ( NumPoints > 0 )
	{
		SpawnEffect(DVector, NumPoints, rotator(DVector), StartTrace + (DVector / NumPoints));
	}
}

function SpawnShockExplosion(vector HitLocation, vector HitNormal, float Mult)
{
	local RingExplosion r;
	local class<RingExplosion> rc;

	if ( Mult > 1.5 )
		rc = class'RingExplosion3';
	else
		rc = class'RingExplosion';

	r = Level.Spawn(rc,,, HitLocation + HitNormal * 8, rotator(HitNormal));
	if ( r != None )
	{
		r.PlaySound(r.ExploSound,,6);
	}
}

function Fire(float Value)
{
	bIsAltFire = False;
	Super.Fire(Value);
}

function AltFire(float Value)
{
	bIsAltFire = True;
	Super.AltFire(Value);
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
	Damage=32
}