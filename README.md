# Introduction
This was created with the intent of playing at 280 ping with a friend of mine, as I grew in frustration by using hitscan weapons against common enemies. The code could probably be improved with some DRY principles, but the UnrealScript limitations were a bit peculiar, I'm not that much into UnrealGold's campaign to further develop this for now.

## How to build
Clone this repository to your Unreal Gold's main folder.
Add the following line to [Editor.EditorEngine] in SYSTEM/Unreal.ini:
`EditPackages=UGLagComp`

Then under the SYSTEM folder:
`ucc make`

A UGLagComp.u file should now be present.

Note: The compiled file UGLagComp.u has to be deleted whenever you make changes.

## Testing

After compiling the file, start a dedicated server:
`Unreal.exe NagomiSun.unr?Game=UnrealShare.CoopGame?Mutator=UGLagComp.TraceMutator -server -log -alladmin`

I use NagomiSun as it has a hitscan weapon early on as well as many fast moving enemies.

Connect with your client:
`Unreal.exe 127.0.0.1`

To simulate lag you can use a tool like [Clumsy](https://jagt.github.io/clumsy/):
- Filter: `udp and udp.DstPort == 7777`
- Lag -> outbound only
