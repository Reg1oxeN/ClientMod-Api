#pragma semicolon 1
#pragma newdecls required

public Plugin myinfo =
{
	name = "#Game_connected block",
	author = "",
	description = "",
	version = "",
	url = ""
};

public void OnPluginStart()
{
	HookUserMessage(GetUserMessageId("TextMsg"), MessageHandler, true);
}

public Action MessageHandler(UserMsg msg_id, Handle bf, const players[], int playersNum, bool reliable, bool init)
{
	if (BfReadByte(bf) == 1)
	{
		char message[256];
		int len = BfReadString(bf, message, sizeof(message));
		if ((len == 15 && message[0] == '#' && message[1] == 'G' && message[6] == 'c') || (len == 33 && message[0] == '#' && message[19] == 'G' && message[24] == 'c'))
		{
			return Plugin_Handled;
		}
	}
	return Plugin_Continue;
}