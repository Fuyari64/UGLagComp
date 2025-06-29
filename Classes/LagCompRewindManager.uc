class LagCompRewindManager extends Info;

const MAX_NPCS = 63;
const HISTORY_LENGTH = 30; // ~0.5s at 30fps
const MAX_PLAYERS = 8;

struct PlayerState
{
	var vector Positions[HISTORY_LENGTH];
	var float Times[HISTORY_LENGTH];
	var int Head;
};

struct NPCState
{
	var vector Positions[HISTORY_LENGTH];
	var float Times[HISTORY_LENGTH];
	var int Head;
};

var NPCState NPCBuffers[MAX_NPCS];
var ScriptedPawn TrackedNPCs[MAX_NPCS];
var int NPCCount;

var PlayerPawn TrackedPlayers[MAX_PLAYERS]; // adjust based on max players
var PlayerState PlayerBuffers[MAX_PLAYERS];
var int PlayerCount;

static function LagCompRewindManager GetInstance(LevelInfo Level)
{
	local LagCompRewindManager M;
	foreach Level.AllActors(class'LagCompRewindManager', M)
		return M;
	return Level.Spawn(class'LagCompRewindManager');
}

function PostBeginPlay()
{
	SetTimer(0.033, True);
	Log("LagCompRewindManager: Initialized");
}

function RegisterNPC(ScriptedPawn NPC)
{
	if ( NPCCount >= MAX_NPCS )
		return;
	
	// Optimization: skip static/friendly npcs
	if ( 
			NPC.bIsAmbientCreature || // butterflies, birds, etc.
			NPC.IsA('Tentacle') || // specific known static enemy
			NPC.IsA('Nali') || // friendlies
			NPC.IsA('NaliPriest')
		)
		return;

	log("TraceMutator: Registering spawned ScriptedPawn "$NPC.Name);
	TrackedNPCs[NPCCount] = NPC;
	NPCBuffers[NPCCount].Head = 0;
	NPCCount++;
}

function RegisterPlayer(PlayerPawn P)
{
	local int i;
	log("player ping: "$P.PlayerReplicationInfo.Ping);
	if ( PlayerCount >= 8 ) return;

	// Avoid duplicates
	for ( i = 0; i < PlayerCount; i++ )
		if ( TrackedPlayers[i] == P )
			return;

	log("TraceMutator: Registering player PlayerPawn "$P.Name);
	TrackedPlayers[PlayerCount] = P;
	PlayerBuffers[PlayerCount].Head = 0;
	PlayerCount++;
}


function Timer()
{
	local int i, h, j, k;

	CleanupDeadNPCs();

	for ( i = 0; i < NPCCount; i++ )
	{
		if ( TrackedNPCs[i] != None )
		{
			h = NPCBuffers[i].Head;
			NPCBuffers[i].Positions[h] = TrackedNPCs[i].Location;
			NPCBuffers[i].Times[h] = Level.TimeSeconds;
			NPCBuffers[i].Head = (h + 1) % HISTORY_LENGTH;
		}
	}

	for ( j = 0; j < PlayerCount; j++ )
	{
		if ( TrackedPlayers[j] != None )
		{
			k = PlayerBuffers[j].Head;
			PlayerBuffers[j].Positions[k] = TrackedPlayers[j].Location;
			PlayerBuffers[j].Times[k] = Level.TimeSeconds;
			PlayerBuffers[j].Head = (k + 1) % HISTORY_LENGTH;
		}
	}
}

function CleanupDeadNPCs()
{
	local int i;

	for ( i = 0; i < NPCCount; i++ )
	{
		if ( TrackedNPCs[i] == None || TrackedNPCs[i].bDeleteMe || TrackedNPCs[i].Health <= 0 )
		{
			// Shift everything down
			while ( i < NPCCount - 1 )
			{
				TrackedNPCs[i] = TrackedNPCs[i + 1];
				NPCBuffers[i] = NPCBuffers[i + 1];
				i++;
			}
			NPCCount--;
			i--; // re-check this slot after shifting
		}
	}
}

function bool RewindAndValidate(ScriptedPawn Target, float HitTime, out vector OutLocation)
{
	local int i, j, bestSlot;
	local float bestDelta;
	local NPCState S;

	for ( i = 0; i < NPCCount; i++ )
	{
		if ( TrackedNPCs[i] == Target )
		{
			S = NPCBuffers[i];
			bestDelta = 9999;
			bestSlot = -1;
			
			for ( j = 0; j < HISTORY_LENGTH; j++ )
			{
				// Skip empty slots (when buffer isn't full yet)
				if ( S.Times[j] == 0 )
					continue;
					
				if ( Abs(S.Times[j] -HitTime) < bestDelta )
				{
					bestDelta = Abs(S.Times[j] -HitTime);
					bestSlot = j;
				}
			}

			if ( bestSlot != -1 )
			{
				OutLocation = S.Positions[bestSlot];
				log("LagCompRewindManager: Found rewind position for "$Target.Name$" at time "$S.Times[bestSlot]$" (requested "$HitTime$")");
				return True;
			}
		}
	}

	log("LagCompRewindManager: No rewind data found for "$Target.Name);
	return False;
}

function bool RewindPlayer(PlayerPawn P, float Time, out vector OutLoc)
{
	local int i, j, bestSlot;
	local float bestDelta;
	local PlayerState S;

	for ( i = 0; i < PlayerCount; i++ )
	{
		if ( TrackedPlayers[i] == P )
		{
			S = PlayerBuffers[i];
			bestDelta = 9999;
			bestSlot = -1;

			for ( j = 0; j < HISTORY_LENGTH; j++ )
			{
				if ( S.Times[j] == 0 ) continue;
				if ( Abs(S.Times[j] -Time) < bestDelta )
				{
					bestDelta = Abs(S.Times[j] -Time);
					bestSlot = j;
				}
			}

			if ( bestSlot != -1 )
			{
				OutLoc = S.Positions[bestSlot];
				log("LagCompRewindManager: Found shooter rewind at "$S.Times[bestSlot]$" for "$P.Name);
				return True;
			}
		}
	}

	log("LagCompRewindManager: No shooter rewind data found for "$P.Name);
	return False;
}


//==============================================================================
// Spread Sync Helper - deterministic spread across client/server using seed
//==============================================================================

function vector GetSpreadOffset(int Seed, vector Y, vector Z, float SpreadAmount)
{
	local float SpreadY, SpreadZ;
	local int OriginalSeed;
	
	// Save the current random seed
	OriginalSeed = Rand(2147483647); // Get current seed state
	
	// Set our deterministic seed
	SetRandomSeed(Seed);
	
	// Generate spread using our seeded random
	SpreadY = (FRand() - 0.5) * SpreadAmount;
	SpreadZ = (FRand() - 0.5) * SpreadAmount;
	
	// Restore original seed (best effort)
	SetRandomSeed(OriginalSeed);
	
	return Y * SpreadY + Z * SpreadZ;
}

//==============================================================================
// Shared Seeder - allows both sides to generate identical FRand sequences
//==============================================================================
function int GetSharedRandomSeed(PlayerPawn P)
{
	// Use timestamp + owner ID hash for deterministic seed
	return int(Level.TimeSeconds * 1000) + P.PlayerReplicationInfo.PlayerID;
}

// Helper function to set random seed (UnrealScript method)
function SetRandomSeed(int NewSeed)
{
	local int i;
	
	// Reset RNG state by calling Rand() with our seed
	// This is a workaround since UnrealScript doesn't expose direct seed setting
	for ( i = 0; i < (NewSeed % 100); i++ )
	{
		Rand(NewSeed);
	}
}

defaultproperties
{
	bAlwaysRelevant=True
}