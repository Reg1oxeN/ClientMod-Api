# ClientMod-Api

## Required
- **SourceMod 1.7** or later
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
| **se_scoreboard** | ``Customize ClientMod scoreboard``<br/>**0** - disable<br/>**1** - hide Money<br/>**2** - show Money for teammates only<br/>**3** - true mp_forcecamera rules for C4, Defuse Kit and Money|
| **se_crosshair_sniper** | ``Force disable ClientMod crosshair on sniper weapons``<br/>**0** - disable<br/>**1** - enable<br/> |
| **se_autobunnyhopping** | ``Auto bunny hopping server api and support ClientMod client-side prediction``<br/>**0** - disable<br/>**1** - enable |
| **se_disablebunnyhopping** | ``Reduce bunny hopping speed and support ClientMod client-side prediction``<br/>**0** - disable<br/>**1** - enable |
| **se_disablebunnyhopping_scale** | ``Maximum bunny hopping speed scale if se_disablebunnyhopping enabled``<br/>**1.0-2.0** - MaxPlayerSpeed * scale = max bhop speed |
| **se_allowpure** | ``Allow sv_pure support for ClientMod``<br/>**0** - disable<br/>**1** - enable |
| **se_newsmoke** | ``Smoke grenade control for ClientMod``<br/>This ConVar is controlled only by **clientmod_smoke_type** and **clientmod_smoke_mode** |
| **clientmod_smoke_type** | ``Smoke grenade control for se_newsmoke``<br/>**0** - disable<br/>**1** - smoke as in Steam version of CS:S<br/>**2** - more density |
| **clientmod_smoke_mode** | ``Smoke grenade control for se_newsmoke``<br/>**0** - disable<br/>**1** - disable excess dust for avoid transparent bug (the best choice)<br/>**2** - reduce life time by 2 minutes as in Steam version of CS:S<br/>**3** - both mode |
| **clientmod_smoke_fix** | ``Fixes the spotting of enemies on a radar in smoke``<br/>**0** - disable<br/>**1** - enable<br/> |
| **clientmod_private** | ``Private mode for server``<br/>**0** - disable<br/>**1** - allow access only to the latest version of ClientMod.<br/>**2** - allow access to the any version of ClientMod |
| **clientmod_private_message** | ``Message for kick clients if private mode is activated`` |
| **clientmod_team_t** | ``The custom name of the Terrorist team in the scoreboard`` |
| **clientmod_team_ct** | ``The custom name of the Counter-Terrorist team in the scoreboard`` |




	
