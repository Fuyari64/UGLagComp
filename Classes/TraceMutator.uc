class TraceMutator extends Mutator;

function PostBeginPlay()
{
	local ScriptedPawn P;
	local PlayerPawn Player;

	Super.PostBeginPlay();

	// Register existing NPCs
	foreach AllActors(class'ScriptedPawn', P)
	{
		if ( !IsAlreadyRegistered(P) )
			GetRewindManager().RegisterNPC(P);
	}

	// Register existing players
	foreach AllActors(class'PlayerPawn', Player)
	{
		if ( !IsAlreadyRegisteredPlayer(Player) )
			GetRewindManager().RegisterPlayer(Player);
	}
}

function bool CheckReplacement(Actor Other, out byte bSuperRelevant)
{
	// Replace AutoMag with LagCompAutomag
	if ( Weapon(Other) != None && Other.IsA('AutoMag') && !Other.IsA('LagCompAutomag') )
	{
		log("TraceMutator: Replacing "$Other.Name$" with LagCompAutomag");
		ReplaceWith(Other, "UGLagComp.LagCompAutomag");
		return False;
	}
	if ( Weapon(Other) != None && Other.IsA('Minigun') && !Other.IsA('LagCompMinigun') )
	{
		log("TraceMutator: Replacing "$Other.Name$" with LagCompMinigun");
		ReplaceWith(Other, "UGLagComp.LagCompMinigun");
		return False;
	}
	if ( Weapon(Other) != None && Other.IsA('Rifle') && !Other.IsA('LagCompSniperRifle') )
	{
		log("TraceMutator: Replacing "$Other.Name$" with LagCompSniperRifle");
		ReplaceWith(Other, "UGLagComp.LagCompSniperRifle");
		return False;
	}
	if ( Weapon(Other) != None && Other.IsA('ASMD') && !Other.IsA('LagCompShockRifle') )
	{
		log("TraceMutator: Replacing "$Other.Name$" with LagCompShockRifle");
		ReplaceWith(Other, "UGLagComp.LagCompShockRifle");
		return False;
	}
	if ( Weapon(Other) != None && Other.IsA('CARifle') && !Other.IsA('LagCompCARifle') )
	{
		log("TraceMutator: Replacing "$Other.Name$" with LagCompCARifle");
		ReplaceWith(Other, "UGLagComp.LagCompCARifle");
		return False;
	}
	if ( Weapon(Other) != None && Other.IsA('AutoMag') && !Other.IsA('LagCompAutomag') )
	{
		log("TraceMutator: Replacing "$Other.Name$" with LagCompAutomag");
		ReplaceWith(Other, "UGLagComp.LagCompAutomag");
		return False;
	}

	// Register dynamic NPCs
	if ( Other.IsA('ScriptedPawn') )
	{
		if ( !IsAlreadyRegistered(ScriptedPawn(Other)) )
			GetRewindManager().RegisterNPC(ScriptedPawn(Other));
	}

	// Register dynamically joined players
	if ( Other.IsA('PlayerPawn') )
	{
		if ( !IsAlreadyRegisteredPlayer(PlayerPawn(Other)) )
			GetRewindManager().RegisterPlayer(PlayerPawn(Other));
	}

	return Super.CheckReplacement(Other, bSuperRelevant);
}

function bool IsAlreadyRegistered(ScriptedPawn P)
{
	local int i;
	for ( i = 0; i < GetRewindManager().NPCCount; i++ )
	{
		if ( GetRewindManager().TrackedNPCs[i] == P )
			return True;
	}
	return False;
}

function bool IsAlreadyRegisteredPlayer(PlayerPawn P)
{
	local int i;
	for ( i = 0; i < GetRewindManager().PlayerCount; i++ )
	{
		if ( GetRewindManager().TrackedPlayers[i] == P )
			return True;
	}
	return False;
}

function LagCompRewindManager GetRewindManager()
{
	local LagCompRewindManager M;
	foreach Level.AllActors(class'LagCompRewindManager', M)
		return M;

	return Level.Spawn(class'LagCompRewindManager');
}

defaultproperties
{
	bAlwaysRelevant=True
}
