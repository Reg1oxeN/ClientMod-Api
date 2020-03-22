#pragma semicolon 1

#include <sourcemod>
#include <sdktools>
#include <sdkhooks>
#include <clientmod>

public Plugin myinfo =
{
	name = "ClientMod Block Message Example",
	author = CM_AUTHOR,
	description = "Пример блокировки дополнительных сообщений в чате клиент мода",
	version = "1.0",
	url = CM_URL
};


public void OnPluginStart()
{
	HookEvent("player_connect",		Event_BlockBroadcast,	EventHookMode_Pre); //подключился
	HookEvent("player_disconnect",	Event_BlockBroadcast,	EventHookMode_Pre); //отключился
	HookEvent("player_team",		Event_BlockBroadcast,	EventHookMode_Pre); //сменил команду
}

public void Event_BlockBroadcast(Event event, const char[] name, bool dontBroadcast)
{
	event.BroadcastDisabled = true;
}