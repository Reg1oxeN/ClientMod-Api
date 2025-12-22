#pragma semicolon 1
#pragma newdecls required

#include <sourcemod>
#include <cstrike>
#include <sdktools>
#include <sdkhooks>
#include <clientmod>
#include <clientmod/stock>
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
bool g_bReloadMode = false;

ArrayList g_aTagList = null;
StringMap g_aTagCvars = null;
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
ConVar g_hClockCorrectionTicks = null;
ConVar sv_turbophysics = null;

float g_fTimeLastUnducked[MAXPLAYERS] = {0.0, ...};
bool g_bDoShootPosFix[MAXPLAYERS];
float g_fShootPosPre[MAXPLAYERS][3];
float g_fShootPosPost[MAXPLAYERS][3];
float g_fShootPosTemp[MAXPLAYERS][3];

SmokeLineBlockedFix g_hSmokeLineBlockedFix;
ClockCorrectionChanger g_hClockCorrectionChanger;

public void OnPluginStart()
{
	g_aTagList = new ArrayList(MAX_TAG_ITEM_LENGTH);
	g_aTagCvars = new StringMap();
	
	CreateConVar("clientmod_version", CM_VERSION, "ClientMod API version", FCVAR_NOTIFY|FCVAR_DONTRECORD).AddChangeHook(VersionCvarHook);
	g_hCMTags = CreateConVar("sv_tags", "", "ClientMod Tags", FCVAR_NOTIFY|FCVAR_DONTRECORD);
	CreateConVar("se_scoreboard", /*не трогать*/"0"/*do not touch*/, "1 - скрыть показ денег. 2 - Деньги видят только тиммейты. 3 - mp_forcecamera правила для бомбы, щипцов и денег.", FCVAR_REPLICATED, true, 0.0, true, 3.0);
	CreateConVar("se_crosshair_sniper", /*не трогать*/"0"/*do not touch*/, "Принудительно отключить прицел на снайперках.", FCVAR_REPLICATED, true, 0.0, true, 1.0);
	g_hAutoBhop = CreateConVar("se_autobunnyhopping", /*не трогать*/"0"/*do not touch*/, "Предсказание автобхопа на стороне клиента.", FCVAR_REPLICATED, true, 0.0, true, 1.0);
	g_hDisableBhop = CreateConVar("se_disablebunnyhopping", /*не трогать*/"0"/*do not touch*/, "Ограниченое скорости бхопа.", FCVAR_REPLICATED, true, 0.0, true, 1.0);
	g_hDisableBhopScale = CreateConVar("se_disablebunnyhopping_scale", /*не трогать*/"1.2"/*do not touch*/, "Множитель максимальной скорости бхопа от текущей максимальной скорости бега.", FCVAR_REPLICATED, true, 1.0, true, 2.0);
	
	g_hDuckFix = CreateConVar("se_duckfix", /*не трогать*/"0"/*do not touch*/, "Исправление быстрого приседания.", FCVAR_REPLICATED, true, 0.0, true, 1.0);
	g_hShootPosFix = CreateConVar("se_shootpositionfix", /*не трогать*/"0"/*do not touch*/, "https://forums.alliedmods.net/showthread.php?t=315405", FCVAR_REPLICATED, true, 0.0, true, 2.0);
	g_hClockCorrectionTicks = CreateConVar("se_clockcorrection_ticks", /*не трогать*/"-1"/*do not touch*/, "На сколько тиков отстает моделька игрока перед отображением. -1 - исправление отключено, стандартные 60мс. 0-1 - не проверялось. 2 - оптимально.", FCVAR_REPLICATED, true, -1.0, true, 2.0);
	
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
	
	CreateConVar("se_allow_thirdperson", /*не трогать*/"0"/*do not touch*/, "Разрешить клиентам использовать режим от 3-го лица. 0 - отключить. 1 - разрешить клиенту и серверу использовать команду thirdperson. 2 - разрешить серверу использовать команду thirdperson.", FCVAR_REPLICATED);
	
	RegServerCmd("clientmod_tags", Command_Tags);
	
	g_hPrivateMode = CreateConVar("clientmod_private", "0", "Фильтрация клиентов. -1 - не пускать только устаревшие версии ClientMod и пускать обычных клиентов. 0 - отключить. 1 - пускать только актуальные версии ClientMod. 2 - пускать только актуальные и устаревшие версии ClientMod.", FCVAR_NOTIFY, true, -1.0, true, 2.0);
	g_hPrivateMessage = CreateConVar("clientmod_private_message", "The server is ClientMod users only. Download it from https://clientmod.ru ", "Текст для кика не ClientMod клиентов, если clientmod_private = 1");
	
	g_hClientVersionMin = CreateConVar("clientmod_client_version_min", "3.0.1.1837", "Минимальная версия для входа актуального ClientMod клиента на сервер.");
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
	g_hClockCorrectionTicks.AddChangeHook(ClockCorrectionTicksHook);
	sv_turbophysics.AddChangeHook(ShootPosFixHook);
	
	CM_InitUserMassages();
	g_hSmokeLineBlockedFix.Init();
	g_hClockCorrectionChanger.Init();
	CM_TagsInit();
	CM_AutoBhopInit();
	
	SmokeCvarHook(null, "", "");
	ClientVersionHook(null, "", "");
	SmokeFixHook(null, "", "");
	ClockCorrectionTicksHook(null, "", "");
	
	g_bReloadMode = true;
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
	g_bReloadMode = false;
}
public void OnPluginEnd()
{
	g_hSmokeLineBlockedFix.Disable();
	g_hClockCorrectionChanger.Disable();
}

public void OnMapStart()
{
	TeamCvarHook(null, "", "");
}
public void OnEntityCreated(int entity, const char[] classname)
{
	SmokeFix_OnEntityCreated(entity, classname);
}

Action Command_Tags(int args)
{
	if (args == 2)
	{
		char type[8]; GetCmdArg(1, type, sizeof(type));
		char buffer[MAX_TAG_ITEM_LENGTH]; GetCmdArg(2, buffer, sizeof(buffer));
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
	switch (g_hSmokeMode.IntValue)
	{
		case 1: smoke |= CMSmokeFlag_RemoveDust;
		case 2: smoke |= CMSmokeFlag_ReduceTime;
		case 3: smoke |= CMSmokeFlag_RemoveDust | CMSmokeFlag_ReduceTime;
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
		return;
	
	bool bClientModUser = (GetClientInfo(client, "_client_version", _client_version[client], sizeof(_client_version[])) &&
		strlen(_client_version[client]) > 2 && StringToInt(_client_version[client][0]) > 0);
		
	char _client_new[8];
	bool bClientModValid = false;
	if (g_bReloadMode || (GetClientInfo(client, "~clientmod", _client_new, sizeof(_client_new)) && strcmp(_client_new, "2.0") == 0))
	{
		bClientModValid = bClientModUser && _client_version[client][0] >= _client_version_min[0];
	}

	g_eCMAuth[client] = bClientModValid ? CM_Auth_ClientMod : (bClientModUser ? CM_Auth_ClientMod_Outdated : CM_Auth_Original);
	Call_OnClientAuth(client, g_eCMAuth[client]);
	
	char _connect_method[16];
	bool bHasConnectMethod = GetClientInfo(client, "_connectmethod", _connect_method, sizeof(_connect_method)) && _connect_method[0];
	g_eClientConnectMethod[client] = bHasConnectMethod ? StringToInt(_connect_method) : 0;
}

public void OnClientPutInServer(int client)
{
	if (!IsFakeClient(client))
	{
		if (g_hAutoBhop.BoolValue || g_hDisableBhop.BoolValue)
			SDKHookEx(client, SDKHook_PreThink, OnClientPreThink);
		
		if (g_hShootPosFix.BoolValue)
		{
			SDKHookEx(client, SDKHook_PreThinkPost, OnClientPreThinkPost);
			SDKHookEx(client, SDKHook_PostThink, OnClientPostThink);
			SDKHookEx(client, SDKHook_PostThinkPost, OnClientPostThinkPost);
		}
		
		if (g_eCMAuth[client] == CM_Auth_ClientMod && !IsClientInKickQueue(client))
		{
			char szVersion[4];
			if (!GetClientInfo(client, "~clientmod", szVersion, sizeof(szVersion)) || szVersion[0] != 0)
				ProcessClientKick(client, g_eCMAuth[client], g_hClientVersionMinMessage);
			else
				CM_SendValidation(client);
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
		PrintLog(client, type);
	
	if ((g_hPrivateMode.IntValue == 1 && type != CM_Auth_ClientMod) || (g_hPrivateMode.IntValue == 2 && type < CM_Auth_ClientMod))
	{
		ProcessClientKick(client, type, g_hPrivateMessage);
	}
	else if ((type == CM_Auth_ClientMod && !CM_IsValidVersion(_client_version[client], _client_version_min)) || (g_hPrivateMode.IntValue == -1 && type == CM_Auth_ClientMod_Outdated))
	{
		ProcessClientKick(client, type, g_hClientVersionMinMessage);
	}
}

void ProcessClientKick(int client, CMAuthType type, ConVar message)
{
	PrintLog(client, type);
	char szKickMessage[192];
	message.GetString(szKickMessage, sizeof(szKickMessage));
	ReplaceString(szKickMessage, sizeof(szKickMessage), "\\n", "\n");
	KickClient(client, szKickMessage);
}


/***********
 * Natives *
 ***********/
public int Native_GetClientModAuth(Handle plugin, int numParams)
{
	int client = GetNativeCell(1);
	if (client < 1 || client >= sizeof(g_eCMAuth) || !IsClientConnected(client) || IsFakeClient(client))
		return 0;
		
	return view_as<int>(g_eCMAuth[client]);
}
public int Native_GetClientModVersion(Handle plugin, int numParams)
{
	int client = GetNativeCell(1);
	if (client < 1 || client >= sizeof(_client_version) || !IsClientConnected(client) || IsFakeClient(client) || g_eCMAuth[client] < CM_Auth_ClientMod)
		return 0;
		
	return SetNativeString(2, _client_version[client], GetNativeCell(3)) == SP_ERROR_NONE;
}
public int Native_AddTag(Handle plugin, int numParams)
{
	char buffer[MAX_TAG_ITEM_LENGTH];
	FormatNativeString(0, 1, 2, sizeof(buffer), _, buffer);
	return AddTag(buffer);
}
public int Native_RemoveTag(Handle plugin, int numParams)
{
	char buffer[MAX_TAG_ITEM_LENGTH];
	FormatNativeString(0, 1, 2, sizeof(buffer), _, buffer);
	return RemoveTag(buffer);
}
public int Native_EndUserMessage(Handle plugin, int numParams)
{
	EndMessage();
	return 1;
}
public int Native_GetClientConnectMethod(Handle plugin, int numParams)
{
	int client = GetNativeCell(1);
	if (client < 1 || client >= sizeof(g_eClientConnectMethod) || !IsClientConnected(client) || IsFakeClient(client))
		return 0;
		
	return g_eClientConnectMethod[client];
}

/********
 * Tags *
 ********/
public bool AddTagCvarLink(const char[] szCvar, const char[] szTag)
{
	ConVar pCvar = FindConVar(szCvar);
	if (pCvar == null)
		return false;
	
	if (!g_aTagCvars.SetString(szCvar, szTag, false))
		return false;
	
	pCvar.AddChangeHook(TagCvarLinkHook);
	TagCvarLinkHook(pCvar, "", "");
	return true;
}
public bool RemoveTagCvarLink(const char[] szCvar)
{
	ConVar pCvar = FindConVar(szCvar);
	if (pCvar == null)
		return false;
	
	if (!g_aTagCvars.Remove(szCvar))
		return false;
	
	pCvar.RemoveChangeHook(TagCvarLinkHook);
	return true;
}
public void TagCvarLinkHook(ConVar convar, const char[] oldValue, const char[] newValue)
{
	if (oldValue[0] != '\0' && StringToInt(oldValue) == convar.IntValue)
		return;
	
	char szCvarName[32];
	convar.GetName(szCvarName, sizeof(szCvarName));
	
	char szCvarTag[MAX_TAG_ITEM_LENGTH];
	if (!g_aTagCvars.GetString(szCvarName, szCvarTag, sizeof(szCvarTag)))
		return;
	
	char szCvarDefault[16];
	convar.GetDefault(szCvarDefault, sizeof(szCvarDefault));
	if (StringToInt(szCvarDefault) != convar.IntValue)
	{
		AddTag(szCvarTag);
	}
	else
	{
		RemoveTag(szCvarTag);
	}
}
bool AddTag(const char[] pszTag)
{
	if (strlen(pszTag) < 1)
		return false;
	
	char buffer[MAX_TAG_ITEM_LENGTH];
	for (int index = 0; index < g_aTagList.Length; index++)
	{
		if (g_aTagList.GetString(index, buffer, sizeof(buffer)) > 0 && !strcmp(buffer, pszTag, false))
			return false;
	}
	
	strcopy(buffer, sizeof(buffer), pszTag);
	g_aTagList.PushString(buffer);
	g_aTagList.Sort(Sort_Ascending, Sort_String);
	CM_WriteTag();
	return true;
}
bool RemoveTag(const char[] pszTag)
{
	if (strlen(pszTag) < 1)
		return false;
	
	char buffer[MAX_TAG_ITEM_LENGTH];
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
bool bSuppressWriteTag = false;
void CM_WriteTag()
{
	if (bSuppressWriteTag)
		return;
	
	char szTagString[MAX_TAG_STRING_LENGTH];
	char buffer[MAX_TAG_ITEM_LENGTH];
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
	
	g_hCMTags.RemoveChangeHook(TagsCvarHook);
	g_hCMTags.SetString(szTagString);
	g_hCMTags.AddChangeHook(TagsCvarHook);
}
void CM_TagsInit()
{
	bSuppressWriteTag = true;
	g_hCMTags.AddChangeHook(TagsCvarHook);
	
	{
		char szTickRate[16];
		FormatEx(szTickRate, sizeof(szTickRate), "%itick", RoundToNearest(1.0 / GetTickInterval()));
		AddTag(szTickRate);
	}
	
	AddTagCvarLink("clientmod_private", "private");
	AddTagCvarLink("se_voice_opus", "opus");
	AddTagCvarLink("se_autobunnyhopping", "autobhop");
	AddTagCvarLink("se_disablebunnyhopping", "nobhop");
	AddTagCvarLink("se_allowpure", "pure");
	AddTagCvarLink("se_newsmoke", "newsmoke");
	bSuppressWriteTag = false;
	CM_WriteTag();
}
public void TagsCvarHook(ConVar convar, const char[] oldValue, const char[] newValue)
{
	CM_WriteTag();
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
public void SmokeFixHook(ConVar convar, const char[] oldValue, const char[] newValue)
{
	if (!g_hSmokeLineBlockedFix.IsAvailable())
	{
		PrintToServer("[ClientMod] SmokeFix patch is not available.");
		g_hSmokeFix.RestoreDefault();
		return;
	}
	
	if (g_hSmokeFix.BoolValue)
	{
		g_hSmokeLineBlockedFix.Enable();
	}
	else
	{
		g_hSmokeLineBlockedFix.Disable();
	}
}
void SmokeFix_OnEntityCreated(int entity, const char[] classname)
{
	if (g_hCMSmoke.IntValue != 0 && entity > MaxClients && classname[0] == 's' && strcmp(classname, "smokegrenade_projectile") == 0)
	{
		SDKHookEx(entity, SDKHook_ThinkPost, SmokeFix_OnThinkPost);
	}
}
public void SmokeFix_OnThinkPost(int entity)
{
	//задержка перед полным исчезновением гранаты, чтобы противник раньше времени не спотился на радаре
	int rgba[4]; GetEntityRenderColor(entity, rgba[0], rgba[1], rgba[2], rgba[3]);
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
public void ClockCorrectionTicksHook(ConVar convar, const char[] oldValue, const char[] newValue)
{
	if (!g_hClockCorrectionChanger.IsAvailable())
	{
		PrintToServer("[ClientMod] ClockCorrectionTicks patch is not available.");
		g_hClockCorrectionTicks.RestoreDefault();
		return;
	}
	
	g_hClockCorrectionChanger.Enable(g_hClockCorrectionTicks.IntValue);
}


/************************
 * Custom user messages *
 ************************/
void CM_InitUserMassages()
{
	UserMessageRegister g_hUserMessageRegister;
	g_hUserMessageRegister.Init();
	g_hUserMessageRegister.FillUnusedMessages();
	g_hUserMessageRegister.CreateMessage("KeyHintText", CMUserMsg_KeyHintText);
	g_hUserMessageRegister.CreateMessage("BigSayText", CMUserMsg_BigSayText);
	g_hUserMessageRegister.CreateMessage("BigHudMsg", CMUserMsg_BigHudMsg);
	g_hUserMessageRegister.CreateMessage("SoundOverrides", CMUserMsg_SoundOverrides);
	g_hUserMessageRegister.CreateMessage("BigHudMsgBg", CMUserMsg_BigHudMsgBg);
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
		return;
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
