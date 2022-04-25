#pragma semicolon 1

#include <sourcemod>
#include <sdktools>
#include <sdkhooks>
#include <cstrike>
#include <clientmod>
#include <clientmod\tracerayfilter>

public Plugin myinfo =
{
	name = "ClientMod Deathnotice",
	author = CM_AUTHOR,
	description = "Extended death notice support",
	version = "1.1",
	url = CM_URL
};

#define ASSIST_DAMAGE_THRESHOLD 40

int g_iPlayerBlind[MAXPLAYERS];
float g_flFlashBangTime[MAXPLAYERS];
float g_flPlayerLastShot[MAXPLAYERS][3];
int g_iPlayerDamage[MAXPLAYERS][MAXPLAYERS];
int g_iPlayerKills[MAXPLAYERS];
bool g_bPlayerShotProcess[MAXPLAYERS];
bool g_bPlayerNoScope[MAXPLAYERS];
ArrayList g_vSmokeList = null;
ConVar g_hCMSmoke = null;
ConVar g_hAssist = null;
ConVar g_hBlind = null;
ConVar g_hSmoke = null;
ConVar g_hPenetrated = null;
ConVar g_hNoscope = null;

public void OnPluginStart()
{
	ClientModEventsPatch(); 
	g_vSmokeList = new ArrayList();
	HookEvent("player_death", Event_PlayerDeath, EventHookMode_Pre);
	HookEvent("player_hurt", Event_PlayerHurt);
	HookEvent("player_spawn", Event_PlayerSpawn);
	HookEvent("bullet_impact", Event_Penetrated, EventHookMode_Pre);
	HookEvent("weapon_fire", Event_Penetrated, EventHookMode_Pre);
	
	HookEvent("player_blind", Event_PlayerBlind);
	HookEvent("flashbang_detonate", Event_PlayerBlind);
	HookEvent("round_start", Event_RoundStart);
	
	g_hAssist = CreateConVar("clientmod_deathnotice_assist", "2", "0 - disabled. 1 - kill only. 2 - kill+flash.", _, true, 0.0, true, 2.0);
	g_hBlind = CreateConVar("clientmod_deathnotice_blind", "1", "0 - disabled. 1 - enable 'blind' kill icon.", _, true, 0.0, true, 1.0);
	g_hSmoke = CreateConVar("clientmod_deathnotice_smoke", "1", "0 - disabled. 1 - enable 'through smoke' kill icon.", _, true, 0.0, true, 1.0);
	g_hPenetrated = CreateConVar("clientmod_deathnotice_penetrated", "1", "0 - disabled. 1 - enable 'penetrated' kill icon.", _, true, 0.0, true, 1.0);
	g_hNoscope = CreateConVar("clientmod_deathnotice_noscope", "1", "0 - disabled. 1 - enable 'no scope' kill icon.", _, true, 0.0, true, 1.0);
	
	for (int i = 1; i <= MaxClients; i++)
	{
		if (IsClientConnected(i) && IsClientInGame(i))
		{ 
			OnClientPutInServer(i);
		}
	}
}

public void OnPluginEnd()
{
	delete g_vSmokeList;
}

public void OnAllPluginsLoaded()
{
	g_hCMSmoke = FindConVar("se_newsmoke");
	if (g_hCMSmoke == null)
	{
		SetFailState("Failed get cvar se_newsmoke");
	}
}

public void OnEntityCreated(int entity, const char[] classname)
{
	if (strcmp(classname, "env_particlesmokegrenade" ) == 0)
	{
		SDKHook(entity, SDKHook_SpawnPost, OnSmokeSpawn);
	}
}
 
public void OnEntityDestroyed(int entity)
{
	if (g_vSmokeList.Length > 0)
	{
		int index = g_vSmokeList.FindValue(entity);
		if (index > -1)
		{
			g_vSmokeList.Erase(index);
		}
	}
}

public void Event_RoundStart(Event event, const char[] name, bool dontBroadcast)
{
	g_vSmokeList.Clear();
}

public void Event_PlayerBlind(Event event, const char[] name, bool dontBroadcast)
{
	int userid = event.GetInt("userid");
	if (name[0] == 'p')
	{
		int client = GetClientOfUserId(userid);
		if (client > 0 && IsClientInGame(client) && IsPlayerAlive(client))
		{
			g_iPlayerBlind[client] = 1;
		}
	}
	else
	{
		for (int i = 0; i < sizeof(g_iPlayerBlind); i++)
		{
			if (g_iPlayerBlind[i] == 1)
			{
				g_iPlayerBlind[i] = userid;
				g_flFlashBangTime[i] = GetGameTime() + GetPlayerFlashDuration(i);
			}
		}
	}
}

public void Event_PlayerHurt(Event event, const char[] name, bool dontBroadcast)
{
	int client = GetClientOfUserId(event.GetInt("userid"));
	int attacker = GetClientOfUserId(event.GetInt("attacker"));
	g_iPlayerDamage[client][attacker] += event.GetInt("dmg_health");
}

public void Event_Penetrated(Event event, const char[] name, bool dontBroadcast)
{
	int client = GetClientOfUserId(event.GetInt("userid"));
	if(name[0] == 'b')
	{
	    g_flPlayerLastShot[client][0] = event.GetFloat("x");
	    g_flPlayerLastShot[client][1] = event.GetFloat("y");
	    g_flPlayerLastShot[client][2] = event.GetFloat("z");
	}
	else
	{
		
		g_flPlayerLastShot[client] = view_as<float>({ 0.0, 0.0, 0.0 });
		g_bPlayerShotProcess[client] = true;
		g_bPlayerNoScope[client] = GetPlayerFov(client) == GetPlayerDefaultFov(client);
	}
}

public void Event_PlayerSpawn(Event event, const char[] name, bool dontBroadcast)
{
	OnClientDisconnect(GetClientOfUserId(event.GetInt("userid")));
}

public void OnClientPutInServer(int client)
{
	SDKHook(client, SDKHook_PostThinkPost, OnClientPostThinkPost);
}

public void OnClientDisconnect(int client)
{
	g_iPlayerBlind[client] = 0;
	g_flFlashBangTime[client] = 0.0;
	g_flPlayerLastShot[client] = view_as<float>({ 0.0, 0.0, 0.0 });
	
	for (int i = 0; i < sizeof(g_iPlayerDamage); i++)
	{
		g_iPlayerDamage[client][i] = 0;
		g_iPlayerDamage[i][client] = 0;
	}
}

public void OnClientPostThinkPost(int client)
{
	g_iPlayerKills[client] = 0;
	g_bPlayerNoScope[client] = false;
	g_bPlayerShotProcess[client] = false;
}

public void Event_PlayerDeath(Event event, const char[] name, bool dontBroadcast)
{
	int client = GetClientOfUserId(event.GetInt("userid"));
	int attacker = GetClientOfUserId(event.GetInt("attacker"));
	if (!client || !attacker || client == attacker)
	{
		return;
	}
	
	if (g_hAssist.IntValue > 0)
	{
		int max_damage = 0;
		int assister = 0;
		for (int i = 0; i < sizeof(g_iPlayerDamage); i++)
		{
			if (attacker != i && g_iPlayerDamage[client][i] > ASSIST_DAMAGE_THRESHOLD && g_iPlayerDamage[client][i] > max_damage)
			{
				max_damage = g_iPlayerDamage[client][i];
				assister = i;
			}
		}
		if (assister == 0 && g_hAssist.IntValue > 1)
		{
			int flash_assist = GetClientOfUserId(GetPlayerBlind(client));
			if (flash_assist)
			{
				event.SetBool("assistedflash", true);
				assister = flash_assist;
			}
		}
		if (assister && IsClientInGame(assister) && GetClientTeam(assister) > CS_TEAM_SPECTATOR)
		{
			event.SetInt("assister", GetClientUserId(assister));
		}
	}
	
	
	if (g_hBlind.BoolValue)
	{
		event.SetBool("attackerblind", GetPlayerBlind(attacker, 150) > 0);
	}
	
	int penetrated = GetPlayerPenetrated(attacker, event);
	if (g_hPenetrated.BoolValue)
	{
		event.SetInt("penetrated", penetrated);
	}
	
	if (g_hSmoke.BoolValue)
	{
		event.SetBool("smoke", IsSmokeKill(client, attacker, penetrated > 0));
	}
	
	if (g_hNoscope.BoolValue)
	{
		event.SetBool("noscope", IsPlayerNoScope(attacker, event));
	}
	
	g_iPlayerKills[attacker]++;
}

int GetPlayerPenetrated(int client, Event event)
{
	
	if (g_flPlayerLastShot[client][0] == 0.0 && g_flPlayerLastShot[client][1] == 0.0 && g_flPlayerLastShot[client][2] == 0.0)
	{
		return 0;
	}
	if (!g_bPlayerShotProcess[client])
	{
		return 0;
	}
	
	char weapon[32]; event.GetString("weapon", weapon, sizeof(weapon));
	if (strcmp(weapon, "m3") == 0 || strcmp(weapon, "xm1014") == 0 || strcmp(weapon, "hegrenade") == 0 ||
		strcmp(weapon, "smokegrenade") == 0 || strcmp(weapon, "flashbang") == 0 || strcmp(weapon, "knife") == 0)
	{
		return 0;
	}
	if (g_iPlayerKills[client] > 0)
	{
		return 1;
	}
	
	float ClientPos[3]; GetClientEyePosition(client, ClientPos);
	TR_TraceRayFilter(ClientPos, g_flPlayerLastShot[client], MASK_SHOT, RayType_EndPoint, CM_FilterLocalPlayer, client);
	TR_GetEndPosition(g_flPlayerLastShot[client]);
	return TR_GetFraction() == 1.0 ? 0 : 1;
}

public void OnSmokeSpawn(int entity)
{
	SDKUnhook(entity, SDKHook_SpawnPost, OnSmokeSpawn);
	g_vSmokeList.Push(entity);
}

bool IsLineBlockedBySmoke(const float smokeOrigin[3], const float from[3],  const float to[3])
{
	float totalSmokedLength = 0.0;
	float sightDir[3]; SubtractVectors(to, from, sightDir);
	float sightLength = NormalizeVector(sightDir, sightDir);
	float smokeRadiusSq = 24025.0;
	float trash[3];
	
	{
		float toGrenade[3]; SubtractVectors(smokeOrigin, from, toGrenade);
		float alongDist = GetVectorDotProduct(toGrenade, sightDir);
		float close[3];
		
		if (alongDist < 0.0)
		{
			close = from;
		}
			
		else if (alongDist >= sightLength)
		{
			close = to;
		}
		else
		{
			close = sightDir;
			ScaleVector(close, alongDist);
			AddVectors(from, close, close);
		}
		
		float toClose[3]; SubtractVectors(close, smokeOrigin, toClose);
		float lengthSq = GetVectorLength(toClose, true);
		if (lengthSq < smokeRadiusSq)
		{
			float fromSq = GetVectorLength(toGrenade, true);
			SubtractVectors(smokeOrigin, to, trash);
			float toSq = GetVectorLength(trash, true);
			if (fromSq < smokeRadiusSq)
			{
				if (toSq < smokeRadiusSq)
				{
					SubtractVectors(to, from, trash);
					totalSmokedLength += GetVectorLength(trash);
				}
				else
				{
					float halfSmokedLength = SquareRoot(smokeRadiusSq - lengthSq);
					SubtractVectors(close, from, trash);
					if (alongDist > 0.0)
					{
						totalSmokedLength += halfSmokedLength + GetVectorLength(trash);
					}
					else
					{
						totalSmokedLength += halfSmokedLength - GetVectorLength(trash);
					}
				}
			}
			else if (toSq < smokeRadiusSq)
			{
				float halfSmokedLength = SquareRoot(smokeRadiusSq - lengthSq);
				float v[3];
				SubtractVectors(to, smokeOrigin, v);
				SubtractVectors(close, to, trash);
				if (GetVectorDotProduct(v, sightDir) > 0.0)
				{
					totalSmokedLength += halfSmokedLength +  GetVectorLength(trash);
				}
				else
				{
					totalSmokedLength += halfSmokedLength -  GetVectorLength(trash);
				}
			}
			else
			{
				float smokedLength = 2.0 * SquareRoot(smokeRadiusSq - lengthSq);
				totalSmokedLength += smokedLength;
			}
		}
	}
	return (totalSmokedLength > 0.0);
}

bool IsSmokeAlive(int entity)
{
	if (GetEntProp(entity, Prop_Send, "m_CurrentStage") != 1)
	{
		return false;
	}
	
	float m_flSpawnTime = GetEntPropFloat(entity, Prop_Send, "m_flSpawnTime");
	CMSmokeFlag smokeCvar = view_as<CMSmokeFlag>(g_hCMSmoke.IntValue);
	bool bNewSmoke = (smokeCvar & CMSmokeFlag_DensityNormal) || smokeCvar & CMSmokeFlag_DensityBold;
	float flExpandTime = (bNewSmoke ? 1.0 : 5.5) * 0.5;
	float flLifetime = GetGameTime() - m_flSpawnTime;
	if (flExpandTime > flLifetime)
	{
		return false;
	}
	
	bool bReduceTime = bNewSmoke && smokeCvar & CMSmokeFlag_ReduceTime;
	float m_FadeStartTime = GetEntPropFloat(entity, Prop_Send, "m_FadeStartTime") - (bReduceTime ? 2.0 : 0.0);
	float m_FadeEndTime = GetEntPropFloat(entity, Prop_Send, "m_FadeEndTime") - (bReduceTime ? 2.0 : 0.0);
	m_FadeEndTime -= (m_FadeEndTime - m_FadeStartTime) * 0.5;
	if (m_FadeStartTime > flLifetime || m_FadeEndTime > flLifetime)
	{
		return true;
	}
	
	return false;
}

bool IsSmokeKill(int client, int attacker, bool penetrated)
{
	if (!client || !attacker || g_vSmokeList.Length < 1 || !IsClientInGame(client) || !IsClientInGame(attacker))
	{
		return false;
	}
	
	float ClientPos[3]; GetClientEyePosition(client, ClientPos);
	float AttackerPos[3]; GetClientEyePosition(attacker, AttackerPos);
	float EntityPos[3];
	if (penetrated)
	{
		ClientPos = g_flPlayerLastShot[attacker];
	}
	for (int i = 0; i < g_vSmokeList.Length; i++)
	{
		int entity = view_as<int>(g_vSmokeList.Get(i));
		if (IsValidEntity(entity) && IsSmokeAlive(entity))
		{
			GetEntPropVector(entity, Prop_Send, "m_vecOrigin", EntityPos);
			if (IsLineBlockedBySmoke(EntityPos, AttackerPos, ClientPos))
			{
				return true;
			}
		}
	}
	return false;
}

int GetPlayerBlind(int client, int min_alpha = 0)
{
	if (g_flFlashBangTime[client] >= GetGameTime())
	{
		if (min_alpha != 0)
		{
			const float certainBlindnessTimeThresh = 3.0;
			float flFlashTimeLeft = g_flFlashBangTime[client] - GetGameTime();
			float m_flFlashMaxAlpha = GetPlayerFlashAlpha(client);
			float flAlphaPercentage = 1.0;
			if (flFlashTimeLeft > certainBlindnessTimeThresh)
			{
				flAlphaPercentage = 1.0;
			}
			else
			{
				flAlphaPercentage = flFlashTimeLeft / certainBlindnessTimeThresh;
				flAlphaPercentage *= flAlphaPercentage;
			}
			float flAlpha = flAlphaPercentage *= m_flFlashMaxAlpha;
			flAlpha = (flAlpha < 0.0) ? 0.0 : (flAlpha > m_flFlashMaxAlpha) ? m_flFlashMaxAlpha : flAlpha;
			if (flAlpha > min_alpha)
			{
				return g_iPlayerBlind[client];
			}
		}
		else
		{
			return g_iPlayerBlind[client];
		}
	}
	
	return 0;
}

float GetPlayerFlashDuration(int client)
{
	if (client > 0 && IsClientInGame(client) && IsPlayerAlive(client))
	{
		return GetEntPropFloat(client, Prop_Send, "m_flFlashDuration");
	}
	return 0.0;
}

float GetPlayerFlashAlpha(int client)
{
	if (client > 0 && IsClientInGame(client) && IsPlayerAlive(client))
	{
		return GetEntPropFloat(client, Prop_Send, "m_flFlashMaxAlpha");
	}
	return 0.0;
}

int GetPlayerFov(int client)
{
	int m_iFOV = GetEntProp(client, Prop_Send, "m_iFOV");
	return m_iFOV == 0 ? GetPlayerDefaultFov(client) : m_iFOV;
}

int GetPlayerDefaultFov(int client)
{
	int m_iDefaultFOV = GetEntProp(client, Prop_Send, "m_iDefaultFOV");
	return m_iDefaultFOV == 0 ? 90 : m_iDefaultFOV;
}

bool IsPlayerNoScope(int client, Event event)
{
	if (!g_bPlayerNoScope[client])
	{
		return false;
	}

	char weapon[32]; event.GetString("weapon", weapon, sizeof(weapon));
	return (strcmp(weapon, "awp") == 0 || strcmp(weapon, "scout") == 0 || strcmp(weapon, "g3sg1") == 0 || strcmp(weapon, "sg550") == 0);
}

void ClientModEventsPatch() // автоматическое добавление возможности отправки ассиста со стороны сервера
{
	char newdatakey[][][] = 
	{
		{"assister",		"short"},
		{"assistedflash",	"bool"},
		{"penetrated",		"byte"},
		{"attackerblind",	"bool"},
		{"smoke",			"bool"},
		{"noscope",			"bool"},
	};
	
	bool bSuccessfull = false;
	char FinalEventFilePath[PLATFORM_MAX_PATH];
	DirectoryListing EventFileSearch = OpenDirectory(".", true, "MOD");
	if (EventFileSearch != null)
	{
		char DirName[PLATFORM_MAX_PATH];
		FileType cFileType = FileType_Unknown;
		while (EventFileSearch.GetNext(DirName, sizeof(DirName), cFileType))
		{
			if (strcmp(DirName, "resource", false) == 0 && DirExists(DirName, true, "MOD"))
			{
				strcopy(FinalEventFilePath, sizeof(FinalEventFilePath), DirName);
				
				delete EventFileSearch;
				EventFileSearch = OpenDirectory(DirName, true, "MOD");
				if (EventFileSearch != null)
				{
					while (EventFileSearch.GetNext(DirName, sizeof(DirName), cFileType))
					{
						if (cFileType == FileType_File && strcmp(DirName, "modevents.res", false) == 0)
						{
							char TempPath[PLATFORM_MAX_PATH];
							Format(TempPath, sizeof(TempPath), "%s/%s", FinalEventFilePath, DirName);
							if (!DirExists(TempPath, true, "MOD"))
							{
								strcopy(FinalEventFilePath, sizeof(FinalEventFilePath), TempPath);
								break;
							}
						}
					}
				}
				break;
			}
		}
		if (EventFileSearch != null)
		{
			delete EventFileSearch;
		}
	}
	
	if (!FinalEventFilePath[0])
	{
		PrintToServer("[ClientMod] Failed find path with filesystem!");
		strcopy(FinalEventFilePath, sizeof(FinalEventFilePath), "resource/modevents.res");
	}
	
	if (FinalEventFilePath[strlen(FinalEventFilePath) - 1] == 's')
	{
		char cTrash[8];
		KeyValues hModEvents = new KeyValues("cstrikeevents");
		if (hModEvents.ImportFromFile(FinalEventFilePath) && hModEvents.JumpToKey("player_death"))
		{
			bool bAlreadyPatched = true;
			for (int i = 0; i < sizeof(newdatakey); i++)
			{
				if (!hModEvents.GetString(newdatakey[i][0], cTrash, sizeof(cTrash)) || strcmp(cTrash, newdatakey[i][1]) != 0)
				{
					bAlreadyPatched = false;
					break;
				}
			}
			
			bool bPatched = false;
			if (!bAlreadyPatched)
			{
				for (int i = 0; i < sizeof(newdatakey); i++)
				{
					hModEvents.SetString(newdatakey[i][0], newdatakey[i][1]);
				}
				
				hModEvents.Rewind();
				if (hModEvents.JumpToKey("hostage_rescued_all"))
				{
					hModEvents.SetString("clientmodfix", "none");
				}
				
				hModEvents.Rewind();
				if (hModEvents.JumpToKey("round_freeze_end"))
				{
					hModEvents.SetString("clientmodfix", "none");
				}
				
				hModEvents.Rewind();
				if (hModEvents.JumpToKey("nav_generate"))
				{
					hModEvents.SetString("clientmodfix", "none");
				}
				
				hModEvents.Rewind(); 
				bPatched = hModEvents.ExportToFile(FinalEventFilePath);
			}
			if (bPatched)
			{
				SetFailState("Player_death event successfully patched. Please restart server.");
			}
			else if (bAlreadyPatched)
			{
				PrintToServer("[ClientMod] player_death event already patched!");
			}
			
			bSuccessfull = bAlreadyPatched || bPatched;
		}
		delete hModEvents;
	}
	
	if (!bSuccessfull)
	{
		SetFailState("Failed patch player_death event!");
	}
}