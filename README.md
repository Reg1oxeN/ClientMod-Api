# ClientMod-Api

## Required
- **SourceMod 1.8** or later
- **CS:S v34 server** with ``4044 build for windows`` or ``4100 build for linux``

## Info
| Plugin | Description |
| --- | --- |
| **clientmod.sp** | Main plugin and ``ClientMod Api`` support |
| **clientmod_deathnotice.sp** | Extended ClientMod death notice with ``assist, penetration, flash and smoke`` kills |
| **clientmod_auth_example.sp** | Example of using ClientMod ``client authorization`` |
| **clientmod_autobhop_example.sp** | Example of using server-side ``auto bunny hopping`` and ``server browser tags`` |
| **clientmod_blockmessage_example.sp** | Example of blocking ``new messages ClientMod in chat`` |
| **clientmod_hudmsg_example.sp** | Example of using ClientMod ``HudMsg user message`` and ``chat with hex colors`` |
| **client_crash_exploit.sp** | A funny plugin for crashing old clients. |

<br/>

## ClientMod Plugin
| Console variable | Description |
| --- | --- |
| **se_scoreboard** | ``Customize ClientMod scoreboard.``<br/>**0** - disabled<br/>**1** - hide Money<br/>**2** - show Money for teammates only<br/>**3** - true mp_forcecamera rules for C4, Defuse Kit and Money|
| **se_crosshair_sniper** | ``Force disable ClientMod crosshair on sniper weapons.``<br/>**0** - disabled<br/>**1** - enabled<br/> |
| **se_autobunnyhopping** | ``Auto bunny hopping server api and support ClientMod client-side prediction.``<br/>**0** - disabled<br/>**1** - enabled |
| **se_disablebunnyhopping** | ``Reduce bunny hopping speed and support ClientMod client-side prediction.``<br/>**0** - disabled<br/>**1** - enabled |
| **se_disablebunnyhopping_scale** | ``Maximum bunny hopping speed scale if se_disablebunnyhopping enabled.``<br/>**1.0-2.0** - MaxPlayerSpeed * scale = max bhop speed |
| **se_allowpure** | ``Allow sv_pure support for ClientMod.``<br/>**0** - disabled<br/>**1** - enabled |
| **se_voice_opus** | ``Activate the opus voice codec on the client.``<br/>**0** - disable<br/>**1** - enabled |
| **se_duckfix** | ``Fixes unduck abuse.``<br/>**0** - disabled<br/>**1** - enabled<br/>[You can watch a video with an example of abuse here.](https://youtu.be/VFKVUzjzI7Y) |
| **se_shootpositionfix** | ``Hit Registration Fix (bullet displacement by 1 tick).``<br/>**0** - disabled<br/>**1** - enabled<br/>[You can read more about this here.](https://github.com/ValveSoftware/source-sdk-2013/pull/442)<br/>[Or watch a video of how it works in ClientMod.](https://youtu.be/mwBOGDJ3u34) |
| **se_newsmoke** | ``Smoke grenade control for ClientMod.``<br/>This ConVar is controlled only by **clientmod_smoke_type** and **clientmod_smoke_mode** |
| **se_scoreboard_teamname_t** | ``The custom name of the Terrorist team in the scoreboard only.`` |
| **se_scoreboard_teamname_ct** | ``The custom name of the Counter-Terrorist team in the scoreboard only.`` |
| **se_clockcorrection_ticks** | ``How many ticks is the player model behind before displaying.``<br/>**-1** - disabled and default 60ms<br/>**0** - untested<br/>**1** - untested<br/>**2** - optimal<br/>These delays are always there for smoother gameplay. This command just reduces the window between when the player comes around the corner and sees you first, and how much later you see him in order to react. |
| **se_allow_hitmarker** | ``Allow clients to use hitmarker via client plugins.``<br/>**0** - disabled<br/>**1** - enabled |
| **se_allow_thirdperson** | ``Allows the server set players in third person mode.``<br/>**0** - disabled<br/>**1** - allows client and server to use the thirdperson command<br/>**2** - allows only the server to use the thirdperson command |
| **clientmod_smoke_type** | ``Smoke grenade control for se_newsmoke.``<br/>**0** - disabled<br/>**1** - smoke as in Steam version of CS:S<br/>**2** - more density |
| **clientmod_smoke_mode** | ``Smoke grenade control for se_newsmoke.``<br/>**0** - disabled<br/>**1** - disabled excess dust for avoid transparent bug (the best choice)<br/>**2** - reduce life time by 2 minutes as in Steam version of CS:S<br/>**3** - both mode |
| **clientmod_smoke_fix** | ``Fixes spotting of enemies on the radar if one of the players is in smoke.<br/>Doesn't affect the problem of constant player spotting if the server is started with the -nobots startup argument.``<br/>**0** - disabled<br/>**1** - enabled<br/> |
| **clientmod_private** | ``Private mode for server.``<br/>**-1** - kick only outdated ClientMod clients<br/>**0** - disabled<br/>**1** - allow access only to the latest version of ClientMod<br/>**2** - allow access to the any version of ClientMod |
| **clientmod_private_message** | ``Message for kicked clients if private mode is activated.`` |
| **clientmod_team_t** | ``The custom name of the Terrorist team in the scoreboard, logs and change team message.`` |
| **clientmod_team_ct** | ``The custom name of the Counter-Terrorist team in the scoreboard, logs and change team message.`` |
| **clientmod_client_version_min** | ``The minimum version of the ClientMod 2.0 to enter the server.``<br/>``Must not be lower than 2.0.8!`` |
| **clientmod_client_version_min_message** | ``Message for kicked clients if ClientMod 2.0 is out of date.`` |



