#pragma semicolon 1
#pragma newdecls required

#include <sourcemod>
#include <cstrike>
#include <sdktools>
#include <sdkhooks>
#include <clientmod>

public Plugin myinfo =
{
	name = "ClientMod API",
	author = CM_AUTHOR,
	description = "",
	version = CM_VERSION,
	url = CM_URL
};

Handle g_OnClientAuth = INVALID_HANDLE;
Handle g_OnClientBhopRequest = INVALID_HANDLE;
public APLRes AskPluginLoad2(Handle myself, bool late, char[] error, int err_max)
{
	CreateNative("CM_GetClientModVersion", Native_GetClientModVersion);
	CreateNative("CM_GetClientModAuth", Native_GetClientModAuth);
	CreateNative("CM_AddTag", Native_AddTag);
	CreateNative("CM_RemoveTag", Native_RemoveTag);
	g_OnClientAuth = CreateGlobalForward("CM_OnClientAuth", ET_Ignore, Param_Cell, Param_Cell);
	g_OnClientBhopRequest = CreateGlobalForward("CM_OnClientBhopRequest", ET_Hook, Param_Cell);
	
	RegPluginLibrary("clientmod");
	return APLRes_Success;
}

CMAuthType g_eCMAuth[MAXPLAYERS] = {CM_Auth_Unknown, ...};
char _client_version[MAXPLAYERS][8];

ArrayList g_aTagList = null;
ConVar g_hCMTags = null;
ConVar g_hCMSmoke = null;
ConVar g_hSmokeMode = null;
ConVar g_hSmokeType = null;
ConVar g_hSmokeFix = null;
ConVar g_hPrivateMode = null;
ConVar g_hPrivateMessage = null;
ConVar g_hAutoBhop = null;
ConVar g_hDisableBhop = null;
ConVar g_hDisableBhopScale = null;
ConVar g_hTeamT = null;
ConVar g_hTeamCT = null;

public void OnPluginStart()
{
	g_aTagList = new ArrayList(MAX_TAG_STRING_LENGTH);
	
	CreateConVar("clientmod_version", CM_VERSION, "ClientMod API version", FCVAR_NOTIFY|FCVAR_DONTRECORD);
	g_hCMTags = CreateConVar("sv_tags", "", "ClientMod Tags", FCVAR_NOTIFY|FCVAR_DONTRECORD);
	CreateConVar("se_scoreboard", "0", "1 - скрыть показ денег. 2 - Деньги видят только тиммейты. 3 - mp_forcecamera правила для бомбы, щипцов и денег.", FCVAR_REPLICATED, true, 0.0, true, 3.0);
	CreateConVar("se_crosshair_sniper", "0", "Принудительно отключить прицел на снайперках.", FCVAR_REPLICATED, true, 0.0, true, 1.0);
	g_hAutoBhop = CreateConVar("se_autobunnyhopping", "0", "Предсказание автобхопа на стороне клиента.", FCVAR_REPLICATED, true, 0.0, true, 1.0);
	g_hDisableBhop = CreateConVar("se_disablebunnyhopping", "0", "Ограниченое скорости бхопа.", FCVAR_REPLICATED, true, 0.0, true, 1.0);
	g_hDisableBhopScale = CreateConVar("se_disablebunnyhopping_scale", "1.2", "Множитель максимальной скорости бхопа от текущей максимальной скорости бега.", FCVAR_REPLICATED, true, 1.0, true, 2.0);
	
	CreateConVar("se_allowpure", "0", "Разрешить обработку sv_pure клиентом.", FCVAR_REPLICATED, true, 0.0, true, 1.0);
	
	g_hCMSmoke = CreateConVar("se_newsmoke", "0", "Контролируется только командами clientmod_smoke_type и clientmod_smoke_mode", FCVAR_REPLICATED);
	g_hSmokeType = CreateConVar("clientmod_smoke_type", "0", "0 - отключить новый смок. 1 - стандартный из стим версии. 2 - более плотный.", _, true, 0.0, true, 2.0);
	g_hSmokeMode = CreateConVar("clientmod_smoke_mode", "1", "0 - отключить. 1 - убрать пыль, которая мешает смоку и делает его прозрачным. 2 - уменьшить время на пару секунд как в стим версии. 3 - оба режима.", _, true, 0.0, true, 3.0);
	
	g_hSmokeFix = CreateConVar("clientmod_smoke_fix", "0", "0 - отключить. 1 - включить исправления подсветки игроков на радаре через смок.", _, true, 0.0, true, 1.0);
	
	g_hTeamT = CreateConVar("clientmod_team_t", "", "Имя команды Т в таблице счета.", _);
	g_hTeamCT = CreateConVar("clientmod_team_ct", "", "Имя команды КТ в таблице счета.", _);
	
	g_hPrivateMode = CreateConVar("clientmod_private", "0", "Пускать ли только клиентов клиент мода. 1 - только новые. 2 - пускать и старых.", FCVAR_NOTIFY|FCVAR_DONTRECORD, true, 0.0, true, 2.0);
	g_hPrivateMessage = CreateConVar("clientmod_private_message", "The server is ClientMod users only. Download it from vk.com/clientmod ", "Текст для кика не клиент мод клиентов, если clientmod_private = 1", _, true, 0.0, true, 1.0);
	
	g_hSmokeType.AddChangeHook(SmokeCvarHook);
	g_hSmokeMode.AddChangeHook(SmokeCvarHook);
	g_hCMSmoke.AddChangeHook(SmokeCvarHook);
	g_hSmokeFix.AddChangeHook(SmokeFixHook);
	g_hTeamT.AddChangeHook(TeamCvarHook);
	g_hTeamCT.AddChangeHook(TeamCvarHook);
	SmokeCvarHook(null, "", "");
	TeamCvarHook(null, "", "");
	
	CM_TagsInit();
	CM_AutoBhopInit();
	
	for (int i = 1; i < MaxClients; i++)
	{
		if (IsClientConnected(i) && !IsFakeClient(i))
		{
			OnClientConnected(i);
			if (IsClientInGame(i))
			{
				OnClientPutInServer(i);
			}
		}
	}
	CM_SmokeFixEnable(true);
	SmokeFixHook(null, "", "");
}

public void OnPluginEnd()
{
	CM_AutoBhopDisable();
	CM_SmokeFixDisable();
}

public void TeamCvarHook(ConVar convar, const char[] oldValue, const char[] newValue)
{
	char team_t[32];
	char team_ct[32];
	g_hTeamT.GetString(team_t, sizeof(team_t));
	g_hTeamCT.GetString(team_ct, sizeof(team_ct));
	
	if (convar != null || strlen(team_t) > 0)
	{
		CM_SetTeamName(CS_TEAM_T, team_t);
	}
	if (convar != null || strlen(team_ct) > 0)
	{
		CM_SetTeamName(CS_TEAM_CT, team_ct);
	}
}

public void SmokeCvarHook(ConVar convar, const char[] oldValue, const char[] newValue)
{
	int smoke_type = g_hSmokeType.IntValue;
	if (smoke_type == 0)
	{
		g_hCMSmoke.SetInt(0, true);
		return;
	}
	
	CMSmokeFlag smoke = smoke_type == 1 ? CMSmokeFlag_DensityNormal : CMSmokeFlag_DensityBold;
	int smoke_mode = g_hSmokeMode.IntValue;
	if (smoke_mode == 0)
	{
		g_hCMSmoke.SetInt(view_as<int>(smoke), true);
		return;
	}
	if (smoke_mode == 1 || smoke_mode == 3)
	{
		smoke |= CMSmokeFlag_RemoveDust;
	}
	if (smoke_mode == 2 || smoke_mode == 3)
	{
		smoke |= CMSmokeFlag_ReduceTime;
	}
	g_hCMSmoke.SetInt(view_as<int>(smoke), true);
}

public void OnClientConnected(int client)
{
	if (client < 1 || IsFakeClient(client) || IsClientInKickQueue(client))
	{
		return;
	}
	
	bool bClientModUser = (GetClientInfo(client, "_client_version", _client_version[client], sizeof(_client_version[])) &&
		strlen(_client_version[client]) > 2 && StringToInt(_client_version[client][0]) > 0);
		
	char _client_new[8];
	bool bClientModNew = bClientModUser && (GetClientInfo(client, "~clientmod", _client_new, sizeof(_client_new)) &&
		strlen(_client_new) == 3 && _client_new[0] == '2' && _client_new[1] == '.'&& _client_new[2] == '0');
	

	g_eCMAuth[client] = bClientModNew ? CM_Auth_ClientMod : (bClientModUser ? CM_Auth_ClientMod_Outdated : CM_Auth_Original);
	Call_OnClientAuth(client, g_eCMAuth[client]);
}

public void OnClientPutInServer(int client)
{
	if ((g_hAutoBhop.BoolValue || g_hDisableBhop.BoolValue) && !IsFakeClient(client))
	{
		SDKHook(client, SDKHook_PreThink, OnClientPreThink);
		SDKHook(client, SDKHook_PostThink, OnClientPostThink);
	}
}

public void OnClientDisconnect(int client)
{
	g_eCMAuth[client] = CM_Auth_Unknown;
}

void Call_OnClientAuth(int client, CMAuthType type)
{
	Call_StartForward(g_OnClientAuth);
	Call_PushCell(client);
	Call_PushCell(type);
	Call_Finish();
	
	if ((g_hPrivateMode.IntValue == 1 && type != CM_Auth_ClientMod) || (g_hPrivateMode.IntValue == 2 && type < CM_Auth_ClientMod))
	{
		char szKickMessage[192];
		g_hPrivateMessage.GetString(szKickMessage, sizeof(szKickMessage));
		ReplaceString(szKickMessage, sizeof(szKickMessage), "\\n", "\n");
		KickClient(client, szKickMessage);
	}
}

public int Native_GetClientModAuth(Handle plugin, int numParams)
{
	int client = GetNativeCell(1);
	if (client < 1 || client >= sizeof(g_eCMAuth) || !IsClientConnected(client) || IsFakeClient(client))
	{
		return 0;
	}
	return view_as<int>(g_eCMAuth[client]);
}

public int Native_GetClientModVersion(Handle plugin, int numParams)
{
	int client = GetNativeCell(1);
	if (client < 1 || client >= sizeof(_client_version) || !IsClientConnected(client) || IsFakeClient(client) || g_eCMAuth[client] < CM_Auth_ClientMod)
	{
		return 0;
	}
	return SetNativeString(2, _client_version[client], GetNativeCell(3)) == SP_ERROR_NONE;
}

public int Native_AddTag(Handle plugin, int numParams)
{
	char buffer[MAX_TAG_STRING_LENGTH];
	FormatNativeString(0, 1, 2, sizeof(buffer), _, buffer);
	return AddTag(buffer);
}

public int Native_RemoveTag(Handle plugin, int numParams)
{
	char buffer[MAX_TAG_STRING_LENGTH];
	FormatNativeString(0, 1, 2, sizeof(buffer), _, buffer);
	return RemoveTag(buffer);
}

bool AddTag(char[] pszTag)
{
	if (strlen(pszTag) < 1)
	{
		return false;
	}
	
	char buffer[MAX_TAG_STRING_LENGTH];
	for (int index = 0; index < g_aTagList.Length; index++)
	{
		if (g_aTagList.GetString(index, buffer, sizeof(buffer)) > 0 && !strcmp(buffer, pszTag, false))
		{
			return false;
		}
	}
	
	strcopy(buffer, sizeof(buffer), pszTag);
	g_aTagList.PushString(buffer);
	CM_WriteTag();
	return true;
}


bool RemoveTag(char[] pszTag)
{
	if (strlen(pszTag) < 1)
	{
		return false;
	}
	
	char buffer[MAX_TAG_STRING_LENGTH];
	for (int index = 0; index < g_aTagList.Length; index++)
	{
		if (g_aTagList.GetString(index, buffer, sizeof(buffer)) > 0 && !strcmp(buffer, pszTag, false))
		{
			g_aTagList.Erase(index);
			CM_WriteTag();
			return true;
		}
	}
	return false;
}

void CM_WriteTag()
{
	char szTagString[MAX_TAG_STRING_LENGTH];
	char buffer[MAX_TAG_STRING_LENGTH]; buffer[0] = 0;
	for (int index = 0; index < g_aTagList.Length; index++)
	{
		if (g_aTagList.GetString(index, buffer, sizeof(buffer)) > 0)
		{
			Format(szTagString, sizeof(szTagString), "%s%s,", szTagString, buffer);
		}
	}
	int iSize = strlen(szTagString);
	if (iSize > 0)
	{
		szTagString[iSize - 1] = 0;
	}
	g_hCMTags.SetString(szTagString);
}

void CM_TagsInit()
{
	g_hCMTags.AddChangeHook(TagsCvarHook);
	g_hPrivateMode.AddChangeHook(TagsCvarHook);
	
	AddTag("cm");
	
	{
		char szTickRate[MAX_TAG_STRING_LENGTH];
		FormatEx(szTickRate, sizeof(szTickRate), "%itick", RoundToNearest(1.0 / GetTickInterval()));
		AddTag(szTickRate);
	}
	
	/*
	лень было делать динамическую обработку кваров по типу
	sv_ff 1 -> AddTag("ff");
	sv_ff 0 -> RemoveTag("ff");
	
	{
		ConVar mp_friendlyfire = FindConVar("mp_friendlyfire");
		if (mp_friendlyfire != null && mp_friendlyfire.BoolValue)
			AddTag("friendlyfire");
	}
	{
		ConVar sv_alltalk = FindConVar("sv_alltalk");
		if (sv_alltalk != null && sv_alltalk.BoolValue)
			AddTag("alltalk");
	}
	*/
}

public void TagsCvarHook(ConVar convar, const char[] oldValue, const char[] newValue)
{
	bool bValid = false;
	if (g_hPrivateMode.BoolValue)
	{
		bValid |= AddTag("private");
	}
	else
	{
		bValid |= RemoveTag("private");
	}
	if (!bValid)
	{
		CM_WriteTag();
	}
}



Address aAutoBhopAddr = Address_Null;
int iPatchSize = 0;
NumberType iPatchType = NumberType_Int8;
int iBackupPatch = 0;
bool bAutoBhopPatched = false;

void CM_AutoBhopInit()
{
	Handle hConfig = LoadGameConfigFile("clientmod");
	if(hConfig == INVALID_HANDLE)
	{
		SetFailState("Load clientmod gamedata Config Fail");
	}
	
	aAutoBhopAddr = GameConfGetAddress(hConfig, "CCSGameMovement_CheckJumpButton");
	int iOffset = GameConfGetOffset(hConfig, "CheckJumpButtonOffset");
	iPatchSize = GameConfGetOffset(hConfig, "PatchSize");
	
	CloseHandle(hConfig);
	
	if (aAutoBhopAddr == Address_Null || iOffset == -1 || iPatchSize == -1)
	{
		SetFailState("Read clientmod gamedata Config Fail");
	}
	aAutoBhopAddr += view_as<Address>(iOffset) + view_as<Address>(iPatchSize == 1 ? 1 : 2);
	iPatchType = iPatchSize == 1 ? NumberType_Int8 : NumberType_Int32;
	iBackupPatch = LoadFromAddress(aAutoBhopAddr, iPatchType);
	
	g_hAutoBhop.AddChangeHook(AutoBhopHook);
	g_hDisableBhop.AddChangeHook(AutoBhopHook);
}

public void AutoBhopHook(ConVar convar, const char[] oldValue, const char[] newValue)
{
	for (int i = 1; i < MaxClients; i++)
	{
		if (IsClientInGame(i) && !IsFakeClient(i))
		{
			if (g_hAutoBhop.BoolValue || g_hDisableBhop.BoolValue)
			{
				SDKHook(i, SDKHook_PreThink, OnClientPreThink);
				SDKHook(i, SDKHook_PostThink, OnClientPostThink);
			}
			else
			{
				SDKUnhook(i, SDKHook_PreThink, OnClientPreThink);
				SDKUnhook(i, SDKHook_PostThink, OnClientPostThink);
			}
		}
	}
}

public void CM_AutoBhopEnable()
{
	if (!bAutoBhopPatched)
	{
		StoreToAddress(aAutoBhopAddr, 0, iPatchType);
		bAutoBhopPatched = true;
	}
}

public void CM_AutoBhopDisable()
{
	if (bAutoBhopPatched)
	{
		StoreToAddress(aAutoBhopAddr, iBackupPatch, iPatchType);
		bAutoBhopPatched = false;
	}
}

public void OnClientPreThink(int client)
{
	PreventBunnyJumping(client);
	if (g_hAutoBhop.BoolValue && IsPlayerAlive(client) && (GetClientButtons(client) & IN_JUMP))
	{
		Action result;
		Call_StartForward(g_OnClientBhopRequest);
		Call_PushCell(client);
		Call_Finish(result);
		if (result != Plugin_Stop)
		{
			CM_AutoBhopEnable();
			return;
		}
	}
	OnClientPostThink(client);
}

public void OnClientPostThink(int client)
{
	CM_AutoBhopDisable();
}

void PreventBunnyJumping(int client)
{
	if (!g_hDisableBhop.BoolValue || IsFakeClient(client) || !IsPlayerAlive(client) || !(GetEntityFlags(client) & FL_ONGROUND) || !(GetClientButtons(client) & IN_JUMP)||
	!(GetEntityMoveType(client) == MOVETYPE_ISOMETRIC || GetEntityMoveType(client) == MOVETYPE_WALK))
		return;
	
	float maxscaledspeed = g_hDisableBhopScale.FloatValue * GetEntPropFloat(client, Prop_Send, "m_flMaxspeed");
	if (maxscaledspeed <= 0.0)
		return;
		
	float m_vecAbsVelocity[3];
	GetEntPropVector(client, Prop_Data, "m_vecAbsVelocity", m_vecAbsVelocity);
	float zbackup = m_vecAbsVelocity[2];
	m_vecAbsVelocity[2] = 0.0;
	
	float spd = GetVectorLength(m_vecAbsVelocity);
	if (spd <= maxscaledspeed)
		return;
	
	float fraction = (maxscaledspeed / spd);
	
	m_vecAbsVelocity[0] *= fraction;
	m_vecAbsVelocity[1] *= fraction;
	m_vecAbsVelocity[2] = zbackup;
	
	SetEntPropVector(client, Prop_Data, "m_vecAbsVelocity", m_vecAbsVelocity);
}



Address aSmokeFixAddr = Address_Null;
float fSmokeFixValue =  108.5;
bool bSmokeFixed = false;

void CM_SmokeFixEnable(bool bInit = false)
{
	if (bInit)
	{
		Handle hConfig = LoadGameConfigFile("clientmod");
		if(hConfig == INVALID_HANDLE)
		{
			SetFailState("Load clientmod gamedata Config Fail");
		}
		
		aSmokeFixAddr = GameConfGetAddress(hConfig, "CBotManager_IsLineBlockedBySmoke");
		int iSmokeBlockOffset1 = GameConfGetOffset(hConfig, "BlockedBySmokeOffset1");
		int iSmokeBlockOffset2 = GameConfGetOffset(hConfig, "BlockedBySmokeOffset2");
		
		CloseHandle(hConfig);
		
		if (aSmokeFixAddr == Address_Null || iSmokeBlockOffset1 == -1)
		{
			SetFailState("Read clientmod gamedata Config Fail");
		}
		
		if (iSmokeBlockOffset1)
		{
			aSmokeFixAddr += view_as<Address>(iSmokeBlockOffset1);
			aSmokeFixAddr += view_as<Address>(LoadFromAddress(aSmokeFixAddr, NumberType_Int32) + 4);
		}
		aSmokeFixAddr += view_as<Address>(iSmokeBlockOffset2);
		
		aSmokeFixAddr = view_as<Address>(LoadFromAddress(aSmokeFixAddr, NumberType_Int32));
		
		if (view_as<float>(LoadFromAddress(aSmokeFixAddr, NumberType_Int32)) != fSmokeFixValue)
		{
			SetFailState("Invalid smoke patch value");
		}
		
		return;
	}
	
	if (!bSmokeFixed)
	{
		StoreToAddress(aSmokeFixAddr, view_as<int>(0.0), NumberType_Int32);
		bSmokeFixed = true;
	}
}

void CM_SmokeFixDisable()
{
	if (bSmokeFixed)
	{
		StoreToAddress(aSmokeFixAddr, view_as<int>(fSmokeFixValue), NumberType_Int32);
	}
}

public void SmokeFixHook(ConVar convar, const char[] oldValue, const char[] newValue)
{
	if (g_hSmokeFix.BoolValue)
	{
		CM_SmokeFixEnable();
	}
	else
	{
		CM_SmokeFixDisable();
	}
}

public void OnEntityCreated(int entity, const char[] classname) 
{ 
	if (bSmokeFixed && entity > MaxClients && classname[0] == 's' && strcmp(classname, "smokegrenade_projectile") == 0)
	{
		SDKHook(entity, SDKHook_ThinkPost, SmokeFix_OnThinkPost);
	}
}

public void SmokeFix_OnThinkPost(int entity)
{
	int rgba[4];
	GetEntityRenderColor(entity, rgba[0], rgba[1], rgba[2], rgba[3]);
	if (rgba[3] == 1)
	{
		int next_think = GetEntProp(entity, Prop_Data, "m_nNextThinkTick");
		if (next_think > -1)
		{
			bool bReduce = (view_as<CMSmokeFlag>(g_hCMSmoke.IntValue) & CMSmokeFlag_ReduceTime) == CMSmokeFlag_ReduceTime;
			int fix_think = RoundToZero(0.5 + ((bReduce ? 18.0 : 20.0) - 5.0 - GetTickInterval() * 255.0 - 4.0) / GetTickInterval());
			SetEntProp(entity, Prop_Data, "m_nNextThinkTick", next_think + fix_think);
		}
	}
}