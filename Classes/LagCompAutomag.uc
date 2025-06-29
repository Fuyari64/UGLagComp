// Notes:
// Terniaries seem to not work in unreal gold
// Local variables have to always be declared on top of the function
// Static functions work in strange ways
// the hitbox on the titans really are that generous even offline

class LagCompAutomag extends AutoMag;

var float TraceRange;
var int Damage;
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
	local vector RewindLoc;
	local Actor ConfirmedHit;
	local HitboxGhost Ghost;
	local float ActiveSpread, ClientTime;
	local int i;
	local vector ToTarget;

	if ( bIsAltFire )
		ActiveSpread = 100.0;
	else
		ActiveSpread = 0.0;

	GetAxes(Owner.Rotation, X, Y, Z);
	StartTrace = Owner.Location + FireOffset.X * X + FireOffset.Y * Y + FireOffset.Z * Z;
	SpreadOffset = class'LagCompRewindManager'.static.GetInstance(Level).GetSpreadOffset(SpreadSeed, Y, Z, ActiveSpread);
	EndTrace = StartTrace + X * TraceRange + SpreadOffset;

	ClientTime = GetClientShotTime(PlayerPawn(Owner));
	M = class'LagCompRewindManager'.static.GetInstance(Level);
	if ( !M.RewindPlayer(PlayerPawn(Owner), ClientTime, StartTrace) )
	{
		log("LagCompAutomag: No rewind data for shooter, using current location");
		StartTrace = Owner.Location;
	}
	StartTrace += FireOffset.X * X + FireOffset.Y * Y + FireOffset.Z * Z;
	EndTrace = StartTrace + X * TraceRange + SpreadOffset;

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
			log("LagCompAutomag: Failed to spawn ghost for "$M.TrackedNPCs[i].Name);
			continue;
		}

		Ghost.SetCollisionSize(M.TrackedNPCs[i].CollisionRadius, M.TrackedNPCs[i].CollisionHeight);
		ConfirmedHit = Trace(HitLoc, HitNorm, EndTrace, StartTrace, True);
		if ( ConfirmedHit == Ghost )
		{
			log("LagCompAutomag: Ghost rewind confirmed hit on "$M.TrackedNPCs[i].Name);
			M.TrackedNPCs[i].TakeDamage(
				Damage,
				Pawn(Owner),
				HitLoc,
				((FRand() < 0.2) ? 6000.0 : 3000.0) * Normal(EndTrace - StartTrace),
				'shot'
			);
			Ghost.Destroy();
			return True;
		}

		Ghost.Destroy();
	}

	log("LagCompAutomag: Unable to find enemy. Defaulting to engine processing. Actor hit: "$HitActor.Name);

	return False;
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

function LagCompRewindManager GetRewindManager()
{
	local LagCompRewindManager M;

	foreach Level.AllActors(class'LagCompRewindManager', M)
		return M;

	// If not found, spawn it
	return Level.Spawn(class'LagCompRewindManager');
}

defaultproperties
{
	RemoteRole=ROLE_SimulatedProxy
	bNetTemporary=False
	bAlwaysRelevant=True
	bReplicateInstigator=True
	TraceRange=10000.0
	Damage=17
}