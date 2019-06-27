#pragma semicolon 1

#include <sourcemod>
#include <sdktools>
#include <sdkhooks>
#include <clientmod>

public Plugin myinfo =
{
	name = "ClientMod Auth Example",
	author = CM_AUTHOR,
	description = "Пример использования форварда CM_OnClientAuth для авторизации клиентов",
	version = "1.0",
	url = CM_URL
};

public void CM_OnClientAuth(int client, CMAuthType type)
{
	char version[8];
	if (CM_GetClientModVersion(client, version, sizeof(version)))
	{
		PrintToServer("FORWARD CM_OnClientAuth \"%N\" ClientMod v%s", client, version);
		return;
	}
	
	PrintToServer("FORWARD CM_OnClientAuth \"%N\" Original client", client);
	
}