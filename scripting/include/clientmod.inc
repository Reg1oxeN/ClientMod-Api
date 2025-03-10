#if defined _clientmod_included
  #endinput
#endif
#define _clientmod_included
#include <clientmod/teams>

#define CM_VERSION	"1.6.7"
#define CM_URL		"https://clientmod.ru"
#define CM_AUTHOR	"Reg1oxeN"
#define MAX_TAG_STRING_LENGTH 128

enum CMAuthType {
	CM_Auth_Unknown = 0,
	CM_Auth_Original,
	CM_Auth_ClientMod,
	CM_Auth_ClientMod_Outdated,
};
enum CMSmokeFlag {
	CMSmokeFlag_DensityNormal 	= 1 << 0,
	CMSmokeFlag_DensityBold 	= 1 << 1,
	CMSmokeFlag_RemoveDust 		= 1 << 2,
	CMSmokeFlag_ReduceTime 		= 1 << 3
};
enum CMConnectMethod {
	CMConnectMethod_Unknown		= 1 << 0, //неизвестен - без названия.
	CMConnectMethod_Reconnect	= 1 << 1, //переподключение к серверу. (клиент не заходил на другие сервера и не перезапускал игру, пока его не было на сервере)
	CMConnectMethod_Retry		= 1 << 2, //используется команда retry. при использовании данной команды, все нижестоящие флаги сохраняются.
	CMConnectMethod_Console		= 1 << 3, //подключается используя команду connect в консоле.
	CMConnectMethod_Internet	= 1 << 4, //подключается используя сервер браузер, вкладка интернет.
	CMConnectMethod_Favorites	= 1 << 5, //подключается используя сервер браузер, вкладка избранное.
	CMConnectMethod_History		= 1 << 6, //подключается используя сервер браузер, вкладка история.
	CMConnectMethod_Lan			= 1 << 7, //подключается используя сервер браузер, вкладка локальная сеть.
	CMConnectMethod_App			= 1 << 8, //подключается используя внешнее приложение, например через clientmod://connect/ip:port
	//CMConnectMethod_Reserved9	= 1 << 9,
	//CMConnectMethod_Reserved10	= 1 << 10,
	CMConnectMethod_Redirect	= 1 << 11, //подключается перенаправлением на сервер.
	CMConnectMethod_Ads			= 1 << 12, //подключается через рекламу из главного меню.
	CMConnectMethod_Vip			= 1 << 13  //подключается через вип блок из главного меню.
};

forward void CM_OnClientAuth(int client, CMAuthType type);

forward Action CM_OnClientBhopRequest(int client);

native bool CM_AddTag(const char[] message, any ...);

native bool CM_RemoveTag(const char[] message, any ...);

native bool CM_GetClientModVersion(int client, char[] version, int size);

native CMAuthType CM_GetClientModAuth(int client);

native void CM_EndUserMessage();

native int CM_GetClientConnectMethod(int client);

stock bool CM_IsClientModUser(int client, bool allow_outdated = false)
{
	return allow_outdated ? CM_GetClientModAuth(client) >= CM_Auth_ClientMod : CM_GetClientModAuth(client) == CM_Auth_ClientMod;
}

#include <clientmod/usermessage>
public SharedPlugin __pl_clientmod = 
{
	name = "clientmod",
	file = "clientmod.smx",
#if defined REQUIRE_PLUGIN
	required = 1,
#else
	required = 0,
#endif
};

#if !defined REQUIRE_PLUGIN
public void __pl_clientmod_SetNTVOptional()
{
	MarkNativeAsOptional("CM_AddTag");
	MarkNativeAsOptional("CM_RemoveTag");
	MarkNativeAsOptional("CM_GetClientModVersion");
	MarkNativeAsOptional("CM_GetClientModAuth");
	MarkNativeAsOptional("CM_EndUserMessage");
	MarkNativeAsOptional("CM_GetClientConnectMethod");
}
#endif
