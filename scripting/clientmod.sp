#pragma semicolon 1
#pragma newdecls required

#include <sourcemod>
#include <cstrike>
#include <sdktools>
#include <sdkhooks>
#include <clientmod>
#include <clientmod/tracerayfilter>
#include <clientmod/multicolors>

//#define SHOOT_POSITION_FIX_DEBUG

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
	CreateNative("CM_EndUserMessage", Native_EndUserMessage);
	CreateNative("CM_GetClientConnectMethod", Native_GetClientConnectMethod);
	
	g_OnClientAuth = CreateGlobalForward("CM_OnClientAuth", ET_Ignore, Param_Cell, Param_Cell);
	g_OnClientBhopRequest = CreateGlobalForward("CM_OnClientBhopRequest", ET_Hook, Param_Cell);
	
	RegPluginLibrary("clientmod");
	return APLRes_Success;
}

CMAuthType g_eCMAuth[MAXPLAYERS] = {CM_Auth_Unknown, ...};
bool g_bClientLog[MAXPLAYERS] = {true, ...};
char _client_version[MAXPLAYERS][16];
char _client_version_min[16];
int g_eClientConnectMethod[MAXPLAYERS] = {0, ...};

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
ConVar g_hDuckFix = null;
ConVar g_hTeamT = null;
ConVar g_hTeamCT = null;
ConVar g_hMaxSpeed = null;
ConVar g_hClientVersionMin = null;
ConVar g_hClientVersionMinMessage = null;
ConVar g_hLogging = null;
ConVar g_hShootPosFix = null;
ConVar g_hClockCorrectionFix = null;
ConVar sv_turbophysics = null;

float g_fTimeLastUnducked[MAXPLAYERS] = {0.0, ...};
bool g_bDoShootPosFix[MAXPLAYERS];
float g_fShootPosPre[MAXPLAYERS][3];
float g_fShootPosPost[MAXPLAYERS][3];
float g_fShootPosTemp[MAXPLAYERS][3];

public void OnPluginStart()
{
	g_aTagList = new ArrayList(MAX_TAG_STRING_LENGTH);
	
	CreateConVar("clientmod_version", CM_VERSION, "ClientMod API version", FCVAR_NOTIFY|FCVAR_DONTRECORD).AddChangeHook(VersionCvarHook);
	g_hCMTags = CreateConVar("sv_tags", "", "ClientMod Tags", FCVAR_NOTIFY|FCVAR_DONTRECORD);
	CreateConVar("se_scoreboard", /*не трогать*/"0"/*do not touch*/, "1 - скрыть показ денег. 2 - Деньги видят только тиммейты. 3 - mp_forcecamera правила для бомбы, щипцов и денег.", FCVAR_REPLICATED, true, 0.0, true, 3.0);
	CreateConVar("se_crosshair_sniper", /*не трогать*/"0"/*do not touch*/, "Принудительно отключить прицел на снайперках.", FCVAR_REPLICATED, true, 0.0, true, 1.0);
	g_hAutoBhop = CreateConVar("se_autobunnyhopping", /*не трогать*/"0"/*do not touch*/, "Предсказание автобхопа на стороне клиента.", FCVAR_REPLICATED, true, 0.0, true, 1.0);
	g_hDisableBhop = CreateConVar("se_disablebunnyhopping", /*не трогать*/"0"/*do not touch*/, "Ограниченое скорости бхопа.", FCVAR_REPLICATED, true, 0.0, true, 1.0);
	g_hDisableBhopScale = CreateConVar("se_disablebunnyhopping_scale", /*не трогать*/"1.2"/*do not touch*/, "Множитель максимальной скорости бхопа от текущей максимальной скорости бега.", FCVAR_REPLICATED, true, 1.0, true, 2.0);
	
	g_hDuckFix = CreateConVar("se_duckfix", /*не трогать*/"0"/*do not touch*/, "Исправление быстрого приседания.", FCVAR_REPLICATED, true, 0.0, true, 1.0);
	g_hShootPosFix = CreateConVar("se_shootpositionfix", /*не трогать*/"0"/*do not touch*/, "https://forums.alliedmods.net/showthread.php?t=315405", FCVAR_REPLICATED, true, 0.0, true, 2.0);
	g_hClockCorrectionFix = CreateConVar("se_clockcorrection_ticks", /*не трогать*/"-1"/*do not touch*/, "На сколько тиков отстает моделька игрока перед отображением. -1 - исправление отключено, стандартные 60мс. 0-1 - не проверялось. 2 - оптимально.", FCVAR_REPLICATED, true, -1.0, true, 2.0);
	
	CreateConVar("se_allowpure", /*не трогать*/"0"/*do not touch*/, "Разрешить обработку sv_pure клиентом.", FCVAR_REPLICATED, true, 0.0, true, 1.0);
	
	CreateConVar("se_voice_opus", /*не трогать*/"0"/*do not touch*/, "Активировать на клиенте Opus войс кодек.", FCVAR_REPLICATED, true, 0.0, true, 1.0);
	
	g_hCMSmoke = CreateConVar("se_newsmoke", /*не трогать*/"0"/*do not touch*/, "Контролируется только командами clientmod_smoke_type и clientmod_smoke_mode", FCVAR_REPLICATED);
	g_hSmokeType = CreateConVar("clientmod_smoke_type", "0", "0 - отключить новый смок. 1 - стандартный из стим версии. 2 - более плотный.", 0, true, 0.0, true, 2.0);
	g_hSmokeMode = CreateConVar("clientmod_smoke_mode", "1", "0 - отключить. 1 - убрать пыль, которая мешает смоку и делает его прозрачным. 2 - уменьшить время на пару секунд как в стим версии. 3 - оба режима.", 0, true, 0.0, true, 3.0);
	
	g_hSmokeFix = CreateConVar("clientmod_smoke_fix", "0", "0 - отключить. 1 - включить исправление подсветки игроков на радаре, если один из игроков находится в смоку.", 0, true, 0.0, true, 1.0);
	
	g_hTeamT = CreateConVar("clientmod_team_t", "", "Имя команды Т в таблице счета, в логах и при изменении команды.");
	g_hTeamCT = CreateConVar("clientmod_team_ct", "", "Имя команды КТ в таблице счета, в логах и при изменении команды.");
	
	CreateConVar("se_scoreboard_teamname_t", /*не трогать*/""/*do not touch*/, "Имя команды Т только в таблице счета.", FCVAR_REPLICATED);
	CreateConVar("se_scoreboard_teamname_ct", /*не трогать*/""/*do not touch*/, "Имя команды КТ только в таблице счета.", FCVAR_REPLICATED);
	
	CreateConVar("se_allow_hitmarker", /*не трогать*/"1"/*do not touch*/, "Разрешить хитмаркер через клиентские плагины.", FCVAR_REPLICATED);
	
	RegServerCmd("clientmod_tags", Command_Tags);
	
	g_hPrivateMode = CreateConVar("clientmod_private", "0", "Фильтрация клиентов. -1 - не пускать только устаревшие версии ClientMod и пускать обычных клиентов. 0 - отключить. 1 - пускать только актуальные версии ClientMod. 2 - пускать только актуальные и устаревшие версии ClientMod.", FCVAR_NOTIFY, true, -1.0, true, 2.0);
	g_hPrivateMessage = CreateConVar("clientmod_private_message", "The server is ClientMod users only. Download it from https://clientmod.ru ", "Текст для кика не ClientMod клиентов, если clientmod_private = 1");
	
	g_hClientVersionMin = CreateConVar("clientmod_client_version_min", "3.0.0.9595", "Минимальная версия для входа актуального ClientMod клиента на сервер.");
	g_hClientVersionMinMessage = CreateConVar("clientmod_client_version_min_message", "Your version of ClientMod is too old to play on this server", "Текст для кика, если клиент ниже минимальной версии.");
	
	g_hLogging = CreateConVar("clientmod_logging", "1", "Логинование клиентов.", 0, true, 0.0, true, 1.0);
	
	sv_turbophysics = FindConVar("sv_turbophysics");
	
	g_hSmokeType.AddChangeHook(SmokeCvarHook);
	g_hSmokeMode.AddChangeHook(SmokeCvarHook);
	g_hCMSmoke.AddChangeHook(SmokeCvarHook);
	g_hSmokeFix.AddChangeHook(SmokeFixHook);
	g_hTeamT.AddChangeHook(TeamCvarHook);
	g_hTeamCT.AddChangeHook(TeamCvarHook);
	g_hClientVersionMin.AddChangeHook(ClientVersionHook);
	g_hShootPosFix.AddChangeHook(ShootPosFixHook);
	g_hClockCorrectionFix.AddChangeHook(ClockCorrectionFixHook);
	sv_turbophysics.AddChangeHook(ShootPosFixHook);
	SmokeCvarHook(null, "", "");
	ClientVersionHook(null, "", "");
	
	CM_TagsInit();
	CM_AutoBhopInit();
	
	for (int i = 1; i <= MaxClients; i++)
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
	CM_InitUserMassages();
	CM_ClockCorrectionFixEnable(true);
	ClockCorrectionFixHook(null, "", "");
}

public void OnPluginEnd()
{
	CM_SmokeFixDisable();
	CM_ClockCorrectionFixDisable();
}

public void OnMapStart()
{
	TeamCvarHook(null, "", "");
}

public Action Command_Tags(int args)
{
	if (args == 2)
	{
		char type[8]; GetCmdArg(1, type, sizeof(type));
		char buffer[MAX_TAG_STRING_LENGTH]; GetCmdArg(2, buffer, sizeof(buffer));
		if (strcmp(type, "add", false) == 0)
		{
			bool bResult = AddTag(buffer);
			PrintToServer("[ClientMod] %s add tag \"%s\"", bResult ? "Successfully" : "Failed", buffer);
			return Plugin_Handled;
		}
		else if (strcmp(type, "remove", false) == 0)
		{
			bool bResult = RemoveTag(buffer);
			PrintToServer("[ClientMod] %s remove tag \"%s\"", bResult ? "Successfully" : "Failed", buffer);
			return Plugin_Handled;
		}
	}
	PrintToServer("[ClientMod] Usage:\nclientmod_tags add any_tag\nclientmod_tags remove any_tag");
	return Plugin_Handled;
}

public void ClientVersionHook(ConVar convar, const char[] oldValue, const char[] newValue)
{
	char defaultValue[16];
	if (convar != null && convar.GetDefault(defaultValue, sizeof(defaultValue)) > 0 && !CM_IsValidVersion(newValue, defaultValue))
	{
		convar.RestoreDefault();
	}
	g_hClientVersionMin.GetString(_client_version_min, sizeof(_client_version_min));
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

public void VersionCvarHook(ConVar convar, const char[] oldValue, const char[] newValue)
{
	convar.SetString(CM_VERSION);
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
		strlen(_client_new) == 3 && _client_new[0] == '2' && _client_new[1] == '.'&& _client_new[2] == '0' &&
		_client_version[client][0] == '3');
	

	g_eCMAuth[client] = bClientModNew ? CM_Auth_ClientMod : (bClientModUser ? CM_Auth_ClientMod_Outdated : CM_Auth_Original);
	Call_OnClientAuth(client, g_eCMAuth[client]);
	
	
	char _connect_method[16];
	bool bHasConnectMethod = GetClientInfo(client, "_connectmethod", _connect_method, sizeof(_connect_method)) && _connect_method[0];
	g_eClientConnectMethod[client] = bHasConnectMethod ? StringToInt(_connect_method) : 0;
}

public void OnClientPutInServer(int client)
{
	if (!IsFakeClient(client))
	{
		if ((g_hAutoBhop.BoolValue || g_hDisableBhop.BoolValue))
		{
			SDKHookEx(client, SDKHook_PreThink, OnClientPreThink);
		}
		
		if (g_eCMAuth[client] == CM_Auth_ClientMod && CM_IsValidVersion(_client_version[client], "2.0.8"))
		{
			CM_SendValidation(client);
		}
		
		if (g_hShootPosFix.BoolValue)
		{
			SDKHookEx(client, SDKHook_PreThinkPost, OnClientPreThinkPost);
			SDKHookEx(client, SDKHook_PostThink, OnClientPostThink);
			SDKHookEx(client, SDKHook_PostThinkPost, OnClientPostThinkPost);
		}
	}
}

public void OnClientDisconnect(int client)
{
	g_eCMAuth[client] = CM_Auth_Unknown;
	g_bClientLog[client] = true;
	g_fTimeLastUnducked[client] = 0.0;
	g_eClientConnectMethod[client] = 0;
}

public void OnClientAuthorized(int client, const char[] auth)
{
	if (!IsFakeClient(client) && !IsClientInKickQueue(client))
		PrintLog(client, g_eCMAuth[client]);
}

void PrintLog(int client, CMAuthType type)
{
	if (g_hLogging.BoolValue && !g_bClientLog[client])
	{
		g_bClientLog[client] = true;
		
		char clInfo[128];
		switch (type)
		{
			case CM_Auth_Unknown:				return;
			case CM_Auth_Original: 				strcopy(clInfo, sizeof(clInfo), "Original client");
			case CM_Auth_ClientMod_Outdated: 	FormatEx(clInfo, sizeof(clInfo), "Too old version ClientMod \"%s\"", _client_version[client]);
			case CM_Auth_ClientMod: 			
			{
				if (CM_IsValidVersion(_client_version[client], _client_version_min))
				{
					FormatEx(clInfo, sizeof(clInfo), "ClientMod \"%s\"", _client_version[client]);
				}
				else
				{
					FormatEx(clInfo, sizeof(clInfo), "Outdated ClientMod \"%s\" (valid \"%s\" or above)", _client_version[client], _client_version_min);
				}
			}
		}
		
		LogAction(client, -1, "\"%L\" auth with %s", client, clInfo);
	}
}

void Call_OnClientAuth(int client, CMAuthType type)
{
	Call_StartForward(g_OnClientAuth);
	Call_PushCell(client);
	Call_PushCell(type);
	Call_Finish();
	
	g_bClientLog[client] = false;
	
	if (IsClientAuthorized(client))
	{
		PrintLog(client, type);
	}
	
	if ((g_hPrivateMode.IntValue == 1 && type != CM_Auth_ClientMod) || (g_hPrivateMode.IntValue == 2 && type < CM_Auth_ClientMod))
	{
		PrintLog(client, type);
		char szKickMessage[192];
		g_hPrivateMessage.GetString(szKickMessage, sizeof(szKickMessage));
		ReplaceString(szKickMessage, sizeof(szKickMessage), "\\n", "\n");
		KickClient(client, szKickMessage);
		return;
	}
	
	if ((type == CM_Auth_ClientMod && !CM_IsValidVersion(_client_version[client], _client_version_min)) || (g_hPrivateMode.IntValue == -1 && type == CM_Auth_ClientMod_Outdated))
	{
		PrintLog(client, type);
		char szKickMessage[192];
		g_hClientVersionMinMessage.GetString(szKickMessage, sizeof(szKickMessage));
		ReplaceString(szKickMessage, sizeof(szKickMessage), "\\n", "\n");
		KickClient(client, szKickMessage);
	}
}


/***********
 * Natives *
 ***********/
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
public int Native_EndUserMessage(Handle plugin, int numParams)
{
	CM_PatchUserMessages();
	EndMessage();
	CM_UnpatchUserMessages();
	return 1;
}
public int Native_GetClientConnectMethod(Handle plugin, int numParams)
{
	int client = GetNativeCell(1);
	if (client < 1 || client >= sizeof(g_eClientConnectMethod) || !IsClientConnected(client) || IsFakeClient(client))
	{
		return 0;
	}
	return g_eClientConnectMethod[client];
}

/********
 * Tags *
 ********/
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


/*************
 * Auto Bhop *
 *************/
void CM_AutoBhopInit()
{
	g_hMaxSpeed = FindConVar("sv_maxspeed");
	g_hAutoBhop.AddChangeHook(AutoBhopHook);
	g_hDisableBhop.AddChangeHook(AutoBhopHook);
}
public void AutoBhopHook(ConVar convar, const char[] oldValue, const char[] newValue)
{
	for (int i = 1; i <= MaxClients; i++)
	{
		if (IsClientInGame(i) && !IsFakeClient(i))
		{
			if (g_hAutoBhop.BoolValue || g_hDisableBhop.BoolValue)
			{
				SDKUnhook(i, SDKHook_PreThink, OnClientPreThink);
				SDKHookEx(i, SDKHook_PreThink, OnClientPreThink);
			}
			else
			{
				SDKUnhook(i, SDKHook_PreThink, OnClientPreThink);
			}
		}
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
			int m_nOldButtons = GetEntProp(client, Prop_Data, "m_nOldButtons");
			if (m_nOldButtons & IN_JUMP)
			{
				SetEntProp(client, Prop_Data, "m_nOldButtons", m_nOldButtons & ~IN_JUMP);
			}
		}
	}
}
void PreventBunnyJumping(int client)
{
	if (!g_hDisableBhop.BoolValue || IsFakeClient(client) || !IsPlayerAlive(client) || !(GetEntityFlags(client) & FL_ONGROUND) || !(GetClientButtons(client) & IN_JUMP) ||
	!(GetEntityMoveType(client) == MOVETYPE_ISOMETRIC || GetEntityMoveType(client) == MOVETYPE_WALK))
		return;
	
	float m_flMaxspeed = GetEntPropFloat(client, Prop_Send, "m_flMaxspeed");
	float sv_maxspeed = g_hMaxSpeed.FloatValue;
	
	float maxscaledspeed = g_hDisableBhopScale.FloatValue * (m_flMaxspeed > sv_maxspeed ? sv_maxspeed : m_flMaxspeed);
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
public Action OnPlayerRunCmd(int client, int &buttons, int &impulse, float vel[3], float angles[3])
{
	g_bDoShootPosFix[client] = false;
	
	if (g_hDuckFix.BoolValue && IsPlayerAlive(client) && !IsFakeClient(client) && (GetEntityFlags(client) & FL_ONGROUND))
	{
		int m_nOldButtons = GetEntProp(client, Prop_Data, "m_nOldButtons");
		if (!(buttons & IN_DUCK) && (m_nOldButtons & IN_DUCK))
		{
			g_fTimeLastUnducked[client] = GetGameTime();
		}
		else if ((buttons & IN_DUCK) && !(m_nOldButtons & IN_DUCK) && ((GetEntityFlags(client) & FL_DUCKING) && (g_fTimeLastUnducked[client] > (GetGameTime() - 2.0))))
		{
			buttons &= ~IN_DUCK;
			return Plugin_Changed;
		}
	}
	
	/**********************
	 * Shoot position debug *
	 **********************/
#if defined SHOOT_POSITION_FIX_DEBUG
	int m_nOldButtons = GetEntProp(client, Prop_Data, "m_nOldButtons");
	if ((buttons & IN_ATTACK) && !(m_nOldButtons & IN_ATTACK))
	{
		float eye_pos[3]; GetClientEyePosition(client, eye_pos);
		float fwd[3], right[3], up[3]; GetAngleVectors(angles, fwd, right, up);
		
		float end_pos[3]; end_pos[0] = fwd[0]; end_pos[1] = fwd[1]; end_pos[2] = fwd[2];
		ScaleVector(end_pos, 4096.0); AddVectors(eye_pos, end_pos, end_pos);
		
		TR_TraceRayFilter(eye_pos, end_pos, MASK_SHOT, RayType_EndPoint, CM_FilterLocalPlayer, client);
		TR_GetEndPosition(end_pos);
		
		static int beamIndex = 0;
		if (beamIndex == 0)
		{
			beamIndex = PrecacheModel("materials/vgui/white.vmt");
		}
		
		TE_SetupBeamPoints(eye_pos, end_pos, beamIndex, 0, 0, 0, 10.0, 0.1, 0.5, 0, 0.0, {0, 0, 255, 255}, 0);
		TE_SendToAll();
	}
#endif
	
	return Plugin_Continue;
}


/*************
 * Smoke fix *
 *************/
Address aSmokeFixAddr = Address_Null;
float fSmokeFixValue =  108.5;
bool bSmokeFixed = false;
Address FindSmokeFix(Address pStart)
{
	int pattern[] = { 0x0F, 0x2F, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0x0F, 0x97 };
	for (int i = 0; i < 3000; i++)
	{
		if (LoadFromAddress(pStart, NumberType_Int8) == pattern[0])
		{
			bool bFound = true;
			for (int j = 1; j < sizeof(pattern); j++)
			{
				int iDestByte = LoadFromAddress(pStart + view_as<Address>(j), NumberType_Int8);
				int iSrcByte = pattern[j];
				
				if (iSrcByte != 0xFF)
				{
					if (iDestByte != iSrcByte)
					{
						bFound = false;
						break;
					}
				}
			}
			if (bFound)
			{
				Address pRet = pStart + view_as<Address>(3);
				Address pTemp = view_as<Address>(LoadFromAddress(pRet, NumberType_Int32));
				if (view_as<float>(LoadFromAddress(pTemp, NumberType_Int32)) == fSmokeFixValue)
				{
					return pRet;
				}
			}
		}
		
		pStart++;
	}
	return Address_Null;
}
void CM_SmokeFixEnable(bool bInit = false)
{
	if (bInit)
	{
		Handle hConfig = LoadGameConfigFile("clientmod");
		if (hConfig == INVALID_HANDLE)
		{
			SetFailState("Load clientmod gamedata Config Fail");
		}
		
		aSmokeFixAddr = GameConfGetAddress(hConfig, "CBotManager_IsLineBlockedBySmoke");
		int iSmokeBlockOffset1 = GameConfGetOffset(hConfig, "BlockedBySmokeOffset1");
		int iSmokeBlockOffset2 = GameConfGetOffset(hConfig, "BlockedBySmokeOffset2");
		
		CloseHandle(hConfig);
		
		if (aSmokeFixAddr == Address_Null || iSmokeBlockOffset1 == -1 || iSmokeBlockOffset2 == -1)
		{
			SetFailState("Read clientmod gamedata Config Fail");
		}
		
		if (iSmokeBlockOffset1)
		{
			aSmokeFixAddr += view_as<Address>(iSmokeBlockOffset1);
			aSmokeFixAddr += view_as<Address>(LoadFromAddress(aSmokeFixAddr, NumberType_Int32) + 4);
			aSmokeFixAddr += view_as<Address>(iSmokeBlockOffset2);
		}
		else
		{
			aSmokeFixAddr = FindSmokeFix(aSmokeFixAddr);
		}
		
		if (aSmokeFixAddr == Address_Null)
		{
			SetFailState("Invalid smoke patch address");
			return;
		}
		
		
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
		bSmokeFixed = false;
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
		SDKHookEx(entity, SDKHook_ThinkPost, SmokeFix_OnThinkPost);
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


/***********************
 * Clock correction fix*
 ***********************/
Address aClockCorrectionFixAddr = Address_Null;
float fClockCorrectionOriginalValue = 0.06;
float fClockCorrectionValue;
void CM_ClockCorrectionFixEnable(bool bInit = false)
{
	if (bInit)
	{
		Handle hConfig = LoadGameConfigFile("clientmod");
		if (hConfig == INVALID_HANDLE)
		{
			SetFailState("Load clientmod gamedata Config Fail");
		}
		
		aClockCorrectionFixAddr = GameConfGetAddress(hConfig, "CBasePlayer_AdjustPlayerTimeBase");
		int iValueOffset = GameConfGetOffset(hConfig, "CBasePlayer_AdjustPlayerTimeBaseOffset");
		
		CloseHandle(hConfig);
		
		if (aClockCorrectionFixAddr == Address_Null || iValueOffset == -1)
		{
			SetFailState("Invalid clock correction patch address");
			return;
		}
		
		aClockCorrectionFixAddr += view_as<Address>(iValueOffset);
		aClockCorrectionFixAddr = view_as<Address>(LoadFromAddress(aClockCorrectionFixAddr, NumberType_Int32));
		fClockCorrectionValue = view_as<float>(LoadFromAddress(aClockCorrectionFixAddr, NumberType_Int32));
		if (fClockCorrectionValue != fClockCorrectionOriginalValue)
		{
			SetFailState("Invalid clock correction patch value %f", fClockCorrectionValue);
		}
		return;
	}
	
	float fix_value = GetClockCorrectionFixValue();
	if (fix_value != fClockCorrectionValue)
	{
		fClockCorrectionValue = fix_value;
		StoreToAddress(aClockCorrectionFixAddr, view_as<int>(fClockCorrectionValue), NumberType_Int32);
	}
}
public void ClockCorrectionFixHook(ConVar convar, const char[] oldValue, const char[] newValue)
{
	CM_ClockCorrectionFixEnable();
}
void CM_ClockCorrectionFixDisable()
{
	if (fClockCorrectionValue != fClockCorrectionOriginalValue)
	{
		StoreToAddress(aClockCorrectionFixAddr, view_as<int>(fClockCorrectionOriginalValue), NumberType_Int32);
	}
}
float GetClockCorrectionFixValue()
{
	switch (g_hClockCorrectionFix.IntValue)
	{
		case 0:	return 0.0;
		case 1:	return GetTickInterval();
		case 2:	return GetTickInterval() * 2.0;
	}
	return fClockCorrectionOriginalValue;
}


/*********
 * Utils *
 *********/
stock bool CM_IsValidVersion(const char[] version1, const char[] version2)
{
	char client_version_char[6][8];
	char target_version_char[6][8];
	int client_numbers = ExplodeString(version1, ".", client_version_char, sizeof(client_version_char), sizeof(client_version_char[]));
	int target_numbers = ExplodeString(version2, ".", target_version_char, sizeof(target_version_char), sizeof(target_version_char[]));
	int min_numbers = client_numbers < target_numbers ? client_numbers : target_numbers;
	int max_numbers = client_numbers >= target_numbers ? client_numbers : target_numbers;
	if (min_numbers < 3 || max_numbers > 4)
	{
		return false;
	}
	
	int client_version[4];
	int target_version[4];
	for (int i = 0; i < min_numbers; i++)
	{
		client_version[i] = StringToInt(client_version_char[i]);
		target_version[i] = StringToInt(target_version_char[i]);
	}
	return CM_VersionCheck(client_version, target_version, min_numbers);
}
stock bool CM_VersionCheck(int[] version, int[] version_target, int size)
{
	int count = size - 1;
	for (int i = 0; i < count; i++)
	{
		if (version[i] != version_target[i])
		{
			return (version[i] > version_target[i]);
		}
	}
	return (version[count] >= version_target[count]);
}
stock void CM_SendValidation(int client)
{
	Event newEvent = CreateEvent("player_info", true);
	newEvent.SetString("name", "{}{}{}{}{}{}{}{}{}{}{}{}{}{}{}{}{}{}{}{}{}{}{}{}{}{}{}{}{}{}{}{}{}{}{}{}{}{}{}{} ? {}{}{}{}{}{}{}{}{}{}{}{}{}{}{}{}{}{}{}{}{}{}{}{}{}{}{}{}{}{}{}{}{}{}{}{}{}{}{}{} ? {}{}{}{}{}{}{}{}{}{}{}{}{}{}{}{}{}{}{}{}{}{}{}{}{}{}{}{}{}{}{}{}{}{}{}{}{}{}{}{} ? {}{}{}{}{}{}{}{}{}{}{}{}{}{}{}{}{}{}{}{}{}{}{}{}{}{}{}{}{}{}{}{}{}{}{}{}{}{}{}{} ? {}{}{}{}{}{}{}{}{}{}{}{}{}{}{}{}{}{}{}{}{}{}{}{}{}{}{}{}{}{}{}{}{}{}{}{}{}{}{}{} ? {}{}{}{}{}{}{}{}{}{}{}{}{}{}{}{}{}{}{}{}{}{}{}{}{}{}{}{}{}{}{}{}{}{}{}{}{}{}{}{} ? {}{}{}{}{}{}{}{}{}{}{}{}{}{}{}{}{}{}{}{}{}{}{}{}{}{}{}{}{}{}{}{}{}{}{}{}{}{}{}{} ?{}{}{}{}{}{}{}{}{}{}{}{}{}{}{}{}{}{}{}{}{}{}{}{}");
	newEvent.FireToClient(client);
	newEvent.Cancel();
}


/************************
 * Custom user messages *
 ************************/
Address aMessageFixAddr = Address_Null;
int iMessageFixOriginal = 0;
int iMessageFixPatch = 0;
stock void CM_InitUserMassages()
{
	Handle hConfig = LoadGameConfigFile("clientmod");
	if (hConfig == INVALID_HANDLE)
	{
		SetFailState("Load clientmod gamedata Config Fail");
	}
	
	aMessageFixAddr = GameConfGetAddress(hConfig, "Message_CheckMessageLength");
	int iMessageOffset = GameConfGetOffset(hConfig, "Message_CheckMessageLengthOffset");
	
	CloseHandle(hConfig);
	
	if (aMessageFixAddr == Address_Null || iMessageOffset == -1)
	{
		SetFailState("Read clientmod gamedata Config Fail");
	}
	
	if (iMessageOffset == 0)
	{
		if (LoadFromAddress(aMessageFixAddr, NumberType_Int8) == 0xE8)
		{
			aMessageFixAddr++;
			aMessageFixAddr += view_as<Address>(LoadFromAddress(aMessageFixAddr, NumberType_Int8) + 4); 
		}
	}
	else
	{
		aMessageFixAddr = CM_FindPatchUserMassages(aMessageFixAddr);
		if (aMessageFixAddr == Address_Null)
		{
			SetFailState("Could not find UserMassages patch addr");
		}
	}
	
	iMessageFixOriginal = LoadFromAddress(aMessageFixAddr, NumberType_Int32);
	
	if (iMessageOffset == 0)
	{
		StoreToAddress(aMessageFixAddr,							0x89,	NumberType_Int8);
		StoreToAddress(aMessageFixAddr + view_as<Address>(1),	0xD0,	NumberType_Int8);
		StoreToAddress(aMessageFixAddr + view_as<Address>(2),	0xC3,	NumberType_Int8);
		StoreToAddress(aMessageFixAddr + view_as<Address>(3),	0x0,	NumberType_Int8);
		iMessageFixPatch = LoadFromAddress(aMessageFixAddr, NumberType_Int32);
	}
	else
	{
		bool bOriginal = LoadFromAddress(aMessageFixAddr, NumberType_Int8) == 0xEF;
		StoreToAddress(aMessageFixAddr, bOriginal ? 0x8B : 0x83, NumberType_Int8);
		iMessageFixPatch = LoadFromAddress(aMessageFixAddr, NumberType_Int32);
	}
	
	CM_UnpatchUserMessages();
}
Address CM_FindPatchUserMassages(Address pStart)
{
	int pattern_original[] = 	{ 0xF, 0x84, 0xEF, 0x00, 0x00, 0x00, 0x3D };
	int pattern_amd[] = 		{ 0xF, 0x84, 0xCB, 0x00, 0x00, 0x00, 0x3D };
	
	for (int i = 0; i < 600; i++)
	{
		if (LoadFromAddress(pStart, NumberType_Int8) == pattern_original[0])
		{
			bool bFound = true;
			for (int j = 1; j < sizeof(pattern_original); j++)
			{
				int iDestByte = LoadFromAddress(pStart + view_as<Address>(j), NumberType_Int8);
				int iSrcByte = pattern_original[j];
				
				if (iSrcByte != 0xFF)
				{
					if (iDestByte != iSrcByte)
					{
						bFound = false;
						break;
					}
				}
			}
			if (bFound)
			{
				Address pRet = pStart + view_as<Address>(2);
				return pRet;
			}
		}
		if (LoadFromAddress(pStart, NumberType_Int8) == pattern_amd[0])
		{
			bool bFound = true;
			for (int j = 1; j < sizeof(pattern_amd); j++)
			{
				int iDestByte = LoadFromAddress(pStart + view_as<Address>(j), NumberType_Int8);
				int iSrcByte = pattern_amd[j];
				
				if (iSrcByte != 0xFF)
				{
					if (iDestByte != iSrcByte)
					{
						bFound = false;
						break;
					}
				}
			}
			if (bFound)
			{
				Address pRet = pStart + view_as<Address>(2);
				return pRet;
			}
		}
		
		pStart++;
	}
	return Address_Null;
}
stock void CM_PatchUserMessages()
{
	StoreToAddress(aMessageFixAddr, iMessageFixPatch, NumberType_Int32);
}
stock void CM_UnpatchUserMessages()
{
	StoreToAddress(aMessageFixAddr, iMessageFixOriginal, NumberType_Int32);
}


/**********************
 * Shoot position fix *
 **********************/
public void ShootPosFixHook(ConVar convar, const char[] oldValue, const char[] newValue)
{
	if (g_hShootPosFix.BoolValue && !sv_turbophysics.BoolValue)
	{
		PrintToServer("se_shootpositionfix is incompatible with sv_turbophysics 0");
		g_hShootPosFix.SetBool(false, true);
	}
	
	if (g_hShootPosFix == convar)
	{
		for (int i = 1; i <= MaxClients; i++)
		{
			if (IsClientInGame(i) && !IsFakeClient(i))
			{
				if (g_hShootPosFix.BoolValue)
				{
					SDKUnhook(i, SDKHook_PreThinkPost, OnClientPreThinkPost);
					SDKUnhook(i, SDKHook_PostThink, OnClientPostThink);
					SDKUnhook(i, SDKHook_PostThinkPost, OnClientPostThinkPost);
					
					SDKHookEx(i, SDKHook_PreThinkPost, OnClientPreThinkPost);
					SDKHookEx(i, SDKHook_PostThink, OnClientPostThink);
					SDKHookEx(i, SDKHook_PostThinkPost, OnClientPostThinkPost);
				}
				else
				{
					SDKUnhook(i, SDKHook_PreThinkPost, OnClientPreThinkPost);
					SDKUnhook(i, SDKHook_PostThink, OnClientPostThink);
					SDKUnhook(i, SDKHook_PostThinkPost, OnClientPostThinkPost);
				}
			}
		}
	}
}
public void OnClientPreThinkPost(int client)
{
	if (g_hShootPosFix.BoolValue && IsPlayerAlive(client) && (g_hShootPosFix.IntValue == 2 || IsClientInAttack(client)))
	{
		g_bDoShootPosFix[client] = true;
		GetEntPropVector(client, Prop_Data, "m_vecAbsOrigin", g_fShootPosPre[client]);
	}
}
public void OnClientPostThink(int client)
{
	if (g_bDoShootPosFix[client])
	{
		GetEntPropVector(client, Prop_Data, "m_vecAbsOrigin", g_fShootPosPost[client]);
		if (!IsValidPosFix(client, true))
		{
			g_bDoShootPosFix[client] = false;
			return;
		}
		SetEntPropVector(client, Prop_Data, "m_vecAbsOrigin", g_fShootPosPre[client]);
	}
}
public void OnClientPostThinkPost(int client)
{
	if (g_bDoShootPosFix[client])
	{
		g_bDoShootPosFix[client] = false;
		if (!IsValidPosFix(client, false))
		{
			return;
		}
		SetEntPropVector(client, Prop_Data, "m_vecAbsOrigin", g_fShootPosPost[client]);
	}
}
bool IsValidPosFix(int client, bool bFirst)
{
	if (bFirst)
	{
		return !(g_fShootPosPre[client][0] == g_fShootPosPost[client][0] && g_fShootPosPre[client][1] == g_fShootPosPost[client][1] && g_fShootPosPre[client][2] == g_fShootPosPost[client][2]);
	}
	GetEntPropVector(client, Prop_Data, "m_vecAbsOrigin", g_fShootPosTemp[client]);
	return !(g_fShootPosPre[client][0] != g_fShootPosTemp[client][0] || g_fShootPosPre[client][1] != g_fShootPosTemp[client][1] || g_fShootPosPre[client][2] != g_fShootPosTemp[client][2]);
}
bool IsClientInAttack(int client)
{
	float curtime = GetGameTime();
	float m_flNextAttack = GetEntPropFloat(client, Prop_Send, "m_flNextAttack");
	
	if (curtime >= m_flNextAttack)
	{
		int m_hActiveWeapon = GetEntPropEnt(client, Prop_Send, "m_hActiveWeapon");
		if (m_hActiveWeapon > MAXPLAYERS && IsValidEntity(m_hActiveWeapon))
		{
			int weapon_slot = -1;
			for (int slot = CS_SLOT_PRIMARY; slot <= CS_SLOT_KNIFE; slot++)
			{
				if (GetPlayerWeaponSlot(client, slot) == m_hActiveWeapon)
				{
					weapon_slot = slot;
					break;
				}
			}
			if (weapon_slot != -1)
			{
				int m_nButtons = GetClientButtons(client);
				if ((m_nButtons & IN_ATTACK2) && GetEntPropFloat(m_hActiveWeapon, Prop_Send, "m_flNextSecondaryAttack") <= curtime)
				{
					return weapon_slot == CS_SLOT_KNIFE;
				}
				else if ((m_nButtons & IN_ATTACK) && GetEntPropFloat(m_hActiveWeapon, Prop_Send, "m_flNextPrimaryAttack") <= curtime)
				{
					//if (GetEntProp(m_hActiveWeapon, Prop_Send, "m_iClip1") > 0)
					{
						if (weapon_slot == CS_SLOT_SECONDARY)
						{
							return !(GetEntProp(client, Prop_Send, "m_iShotsFired") > 0 && !HasBurstMode(m_hActiveWeapon));
						}
						
						return true;
					}
				}
			}
		}
	}
	return false;
}
bool HasBurstMode(int entity)
{
	char cls[16];
	return GetEntityNetClass(entity, cls, sizeof(cls)) && strcmp(cls, "CWeaponGlock") == 0 && GetEntProp(entity, Prop_Send, "m_bBurstMode", 1);
}
