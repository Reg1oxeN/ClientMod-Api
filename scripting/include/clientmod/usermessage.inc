#define CMUserMsg_KeyHintText	view_as<UserMsg>(34)
#define CMUserMsg_BigSayText	view_as<UserMsg>(35)
#define CMUserMsg_BigHudMsg		view_as<UserMsg>(36)
#define CMUserMsg_SoundOverrides view_as<UserMsg>(37)
#define CMUserMsg_BigHudMsgBg	view_as<UserMsg>(38)

#define BIG_TEXT_LIMIT 250
#define MAX_BIGHUD_MESSAGE_LENGTH   (255-25)
#define MAX_BIGHUDBG_MESSAGE_LENGTH   (255-37)

stock bool CM_PrintKeyHintText(int client, const char[] format, any ...)
{
	if (!CM_IsClientModUser(client))
	{
		return false;
	}
	
	int clients[1]; clients[0] = client;
	Handle userMessage = StartMessageEx(CMUserMsg_KeyHintText, clients, 1, USERMSG_RELIABLE);
	if (userMessage == INVALID_HANDLE)
	{
		return false;
	}

	char buffer[254];
	SetGlobalTransTarget(client);
	VFormat(buffer, sizeof(buffer), format, 3);

	BfWriteString(userMessage, buffer);
	CM_EndUserMessage();
	CloseHandle(userMessage);
	return true;
}

stock void CM_PrintBigSayText(int client, const char[] format, any ...)
{
	char chatMsg[4096];
	SetGlobalTransTarget(client);
	VFormat(chatMsg, sizeof(chatMsg), format, 3);
	
	if (!CM_IsClientModUser(client) || strlen(chatMsg) < 1)
	{
		return;
	}
	
	Format(chatMsg, sizeof(chatMsg), "\x01%s", chatMsg);
	CFormatColor(chatMsg, sizeof(chatMsg), client);
	
	int clients[1]; clients[0] = client;
	int msgLen = strlen(chatMsg);
	int startIndex = 0;
	int msgCount = msgLen / (BIG_TEXT_LIMIT - 1) + 1;
	
	char writeMsg[BIG_TEXT_LIMIT];
	for (int i = 0; i < msgCount; i++)
	{
		Handle userMessage = StartMessageEx(CMUserMsg_BigSayText, clients, 1, USERMSG_RELIABLE);
		if (userMessage)
		{
			strcopy(writeMsg, sizeof(writeMsg), chatMsg[startIndex]);
			startIndex += strlen(writeMsg);
			
			BfWriteByte(userMessage, i);
			if (i == 0)
			{
				BfWriteByte(userMessage, msgCount);
				BfWriteByte(userMessage, 0/*author*/);
			}
			BfWriteString(userMessage, writeMsg);
			
			CM_EndUserMessage();
			CloseHandle(userMessage);
		}
	}
}

stock bool CM_PrintBigHudMsg(int client, int channel, float posX, float posY, float fadeIn, float fadeOut, float holdTime, const char[] format, any ...)
{
	if (!CM_IsClientModUser(client))
	{
		return false;
	}
	
	char hudMsg[4096];
	SetGlobalTransTarget(client);
	VFormat(hudMsg, sizeof(hudMsg), format, 9);
	Format(hudMsg, sizeof(hudMsg), "\x01%s", hudMsg);
	MC_ReplaceColorCodes(hudMsg, 0, false, sizeof(hudMsg));
	
	int clients[1]; clients[0] = client;
	int msgLen = strlen(hudMsg) - MAX_BIGHUD_MESSAGE_LENGTH;
	int startIndex = 0;
	int msgCount = msgLen > 1 ? (msgLen / (BIG_TEXT_LIMIT - 1) + 2) : 1;
	
	char writeMsg[BIG_TEXT_LIMIT];
	for (int i = 0; i < msgCount; i++)
	{
		Handle userMessage = StartMessageEx(CMUserMsg_BigHudMsg, clients, 1, USERMSG_RELIABLE);
		if (userMessage)
		{
			BfWriteByte(userMessage, channel);
			BfWriteByte(userMessage, i);
			if (i == 0)
			{
				BfWriteByte(userMessage, msgCount);
				
				BfWriteFloat(userMessage, posX);
				BfWriteFloat(userMessage, posY);
				
				BfWriteFloat(userMessage, fadeIn);
				BfWriteFloat(userMessage, fadeOut);
				
				BfWriteFloat(userMessage, holdTime);
				
				strcopy(writeMsg, MAX_BIGHUD_MESSAGE_LENGTH, hudMsg[startIndex]);
			}
			else
			{
				strcopy(writeMsg, sizeof(writeMsg), hudMsg[startIndex]);
			}
			startIndex += strlen(writeMsg);
			BfWriteString(userMessage, writeMsg);
			
			CM_EndUserMessage();
			CloseHandle(userMessage);
		}
	}
	return true;
}

stock bool CM_PrintBigHudMsgBg(int client, int channel, float posX, float posY, float fadeIn, float fadeOut, float holdTime, int bgColor[4], float bgScale, const char[] format, any ...)
{
	if (!CM_IsClientModUser(client))
	{
		return false;
	}
	
	char hudMsg[4096];
	SetGlobalTransTarget(client);
	VFormat(hudMsg, sizeof(hudMsg), format, 9);
	Format(hudMsg, sizeof(hudMsg), "\x01%s", hudMsg);
	MC_ReplaceColorCodes(hudMsg, 0, false, sizeof(hudMsg));
	
	int clients[1]; clients[0] = client;
	int msgLen = strlen(hudMsg) - MAX_BIGHUDBG_MESSAGE_LENGTH;
	int startIndex = 0;
	int msgCount = msgLen > 1 ? (msgLen / (BIG_TEXT_LIMIT - 1) + 2) : 1;
	
	char writeMsg[BIG_TEXT_LIMIT];
	for (int i = 0; i < msgCount; i++)
	{
		Handle userMessage = StartMessageEx(CMUserMsg_BigHudMsgBg, clients, 1, USERMSG_RELIABLE);
		if (userMessage)
		{
			BfWriteByte(userMessage, channel);
			BfWriteByte(userMessage, i);
			if (i == 0)
			{
				BfWriteByte(userMessage, msgCount);
				
				BfWriteFloat(userMessage, posX);
				BfWriteFloat(userMessage, posY);
				
				BfWriteFloat(userMessage, fadeIn);
				BfWriteFloat(userMessage, fadeOut);
				
				BfWriteFloat(userMessage, holdTime);
				
				BfWriteByte(userMessage, bgColor[0]);
				BfWriteByte(userMessage, bgColor[1]);
				BfWriteByte(userMessage, bgColor[2]);
				BfWriteByte(userMessage, bgColor[3]);
				BfWriteFloat(userMessage, bgScale);
				BfWriteFloat(userMessage, 0.0); //reserved
				
				strcopy(writeMsg, MAX_BIGHUDBG_MESSAGE_LENGTH, hudMsg[startIndex]);
			}
			else
			{
				strcopy(writeMsg, sizeof(writeMsg), hudMsg[startIndex]);
			}
			startIndex += strlen(writeMsg);
			BfWriteString(userMessage, writeMsg);
			
			CM_EndUserMessage();
			CloseHandle(userMessage);
		}
	}
	return true;
}

stock bool CM_AddSoundOverrides(int client, const char[] path, bool precache = false)
{
	if (!CM_IsClientModUser(client) || strlen(path) < 5)
	{
		return false;
	}

	int clients[1]; clients[0] = client;
	Handle userMessage = StartMessageEx(CMUserMsg_SoundOverrides, clients, 1, USERMSG_RELIABLE);
	if (userMessage == INVALID_HANDLE)
	{
		return false;
	}
	char send_path[250];
	strcopy(send_path, sizeof(send_path), path);
	
	BfWriteByte(userMessage, 1);
	BfWriteByte(userMessage, precache ? 1 : 0);
	BfWriteString(userMessage, send_path);
	CM_EndUserMessage();
	CloseHandle(userMessage);
	return true;
}

stock bool CM_ClearSoundOverrides(int client)
{
	if (!CM_IsClientModUser(client))
	{
		return false;
	}

	int clients[1]; clients[0] = client;
	Handle userMessage = StartMessageEx(CMUserMsg_SoundOverrides, clients, 1, USERMSG_RELIABLE);
	if (userMessage == INVALID_HANDLE)
	{
		return false;
	}
	
	BfWriteByte(userMessage, 0);
	CM_EndUserMessage();
	CloseHandle(userMessage);
	return true;
}