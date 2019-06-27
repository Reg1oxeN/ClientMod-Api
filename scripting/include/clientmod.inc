#if defined _clientmod_included
  #endinput
#endif
#define _clientmod_included

#define CM_VERSION	"1.0.0"
#define CM_URL		"https://vk.com/clientmod"
#define CM_AUTHOR	"Reg1oxeN"
#define MAX_TAG_STRING_LENGTH 128

enum CMAuthType {
	CM_Auth_Unknown = 0,
	CM_Auth_Original,
	CM_Auth_ClientMod,
	CM_Auth_ClientMod_Outdated,
};
enum CMSmokeFlag
{
	CMSmokeFlag_DensityNormal = 1 << 0,
	CMSmokeFlag_DensityBold = 1 << 1,
	CMSmokeFlag_RemoveDust = 1 << 2,
	CMSmokeFlag_ReduceTime = 1 << 3
};

forward void CM_OnClientAuth(int client, CMAuthType type);

forward Action CM_OnClientBhopRequest(int client);

native bool CM_AddTag(const char[] message, any ...);

native bool CM_RemoveTag(const char[] message, any ...);

native bool CM_GetClientModVersion(int client, char[] version, int size);

native CMAuthType CM_GetClientModAuth(int client);

stock bool CM_IsClientModUser(int client, bool allow_outdated = false)
{
	return allow_outdated ? CM_GetClientModAuth(client) >= CM_Auth_ClientMod : CM_GetClientModAuth(client) == CM_Auth_ClientMod;
}

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
public __pl_clientmod_SetNTVOptional()
{
	
}
#endif
