#pragma semicolon 1

#include <sourcemod>
#include <sdktools>
#include <sdkhooks>
#include <clientmod>

public Plugin myinfo =
{
	name = "ClientMod AutoBhop Example",
	author = CM_AUTHOR,
	description = "Пример использования форварда CM_OnClientBhopRequest для автобхопа клиентов",
	version = "1.0",
	url = CM_URL
};

public void OnAllPluginsLoaded()
{
	ConVar g_hAutoBhop = FindConVar("se_autobunnyhopping");
	if (g_hAutoBhop != null)
	{
		g_hAutoBhop.BoolValue = true;
		CM_AddTag("bhop");
	}
}

public void OnPluginEnd()
{
	CM_RemoveTag("bhop");
}

public Action CM_OnClientBhopRequest(int client)
{
	/*
	return Plugin_Stop; -> запретить
	если используется в нескольких плагинах, то запрос выполняется до первого return Plugin_Stop;
	*/
	
	return Plugin_Continue; // разрешить
}