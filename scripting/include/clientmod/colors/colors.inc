/**************************************************************************
 *                                                                        *
 *                       Colored Chat Functions                           *
 *                   Author: exvel, Editor: Popoklopsi, Powerlord, Bara   *
 *                           Version: 1.1.3	                              *
 *                    REGIOXEN CLIENTMOD VERSION                          *
 **************************************************************************/
 
#if defined _colors_included
 #endinput
#endif
#define _colors_included
 
#define MAX_MESSAGE_LENGTH 250

#define SERVER_INDEX 0
#define NO_INDEX -1
#define NO_PLAYER -2

enum Colors
{
 	Default = 0,
	Darkred,
	Green,
	Lightgreen,
	Red,
	Blue,
	White,
	Olive,
	Colors_Max
}


/* Colors' properties */
char CTag[][] = 			{"{default}",	"{darkred}",	"{green}",	"{lightgreen}",	"{red}",	"{blue}",	"{white}",	"{olive}"	};
char CTagCode[][] = 		{"\x01",		"\x02",			"\x04",		"\x03",			"\x03",		"\x03",		"\x03",		"\x06"		};
bool CTagReqSayText2[] = 	{false,			false,			false,		true,			true,		true,		true,		false		};
bool CProfile_Colors[] = 	{true,			false,			true,		false,			false,		false,		false,		false		};
int CProfile_TeamIndex[] = 	{NO_INDEX,		NO_INDEX,		NO_INDEX,	NO_INDEX,		NO_INDEX,	NO_INDEX,	NO_INDEX,	NO_INDEX	};

bool CSkipList[MAXPLAYERS+1] = {false,...};
bool CProfile_SayText2 = false;
bool CEventIsHooked = false;
/**
 * Prints a message to a specific client in the chat area.
 * Supports color tags.
 *
 * @param client	  Client index.
 * @param szMessage   Message (formatting rules).
 * @return			  No return
 * 
 * On error/Errors:   If the client is not connected an error will be thrown.
 */
stock void C_PrintToChat(int client, const char[] szMessage, any:...)
{
	if (CM_IsClientModUser(client, true))
		return;
	
	if (client <= 0 || client > MaxClients)
		ThrowError("Invalid client index %d", client);
	
	if (!IsClientInGame(client))
		ThrowError("Client %d is not in game", client);
	
	char szBuffer[MAX_MESSAGE_LENGTH];
	char szCMessage[MAX_MESSAGE_LENGTH];

	SetGlobalTransTarget(client);
	
	Format(szBuffer, sizeof(szBuffer), "\x01%s", szMessage);
	VFormat(szCMessage, sizeof(szCMessage), szBuffer, 3);
	
	int index = C_Format(szCMessage, sizeof(szCMessage));
	
	if (index == NO_INDEX)
		PrintToChat(client, szCMessage);
	else
		C_SayText2(client, index, szCMessage);
}

stock void C_ReplyToCommand(int client, const char[] szMessage, any:...)
{
	if (CM_IsClientModUser(client, true))
		return;
	
	char szCMessage[MAX_MESSAGE_LENGTH];
	VFormat(szCMessage, sizeof(szCMessage), szMessage, 3);
	
	if (client == 0)
	{
		C_RemoveTags(szCMessage, sizeof(szCMessage));
		PrintToServer(szCMessage);
	}
	else if (GetCmdReplySource() == SM_REPLY_TO_CONSOLE)
	{
		C_RemoveTags(szCMessage, sizeof(szCMessage));
		PrintToConsole(client, szCMessage);
	}
	else
	{
		C_PrintToChat(client, szCMessage);
	}
}


/**
 * Prints a message to all clients in the chat area.
 * Supports color tags.
 *
 * @param client	  Client index.
 * @param szMessage   Message (formatting rules)
 * @return			  No return
 */
stock void C_PrintToChatAll(const char[] szMessage, any:...)
{
	char szBuffer[MAX_MESSAGE_LENGTH];
	
	for (new i = 1; i <= MaxClients; i++)
	{
		if (CM_IsClientModUser(i, true))
			continue;
		
		if (IsClientInGame(i) && /*!IsFakeClient(i) &&*/ !CSkipList[i])
		{
			SetGlobalTransTarget(i);
			VFormat(szBuffer, sizeof(szBuffer), szMessage, 2);
			C_PrintToChat(i, szBuffer);
		}
		
		CSkipList[i] = false;
	}
}

/**
 * Prints a message to a specific client in the chat area.
 * Supports color tags and teamcolor tag.
 *
 * @param client	  Client index.
 * @param author	  Author index whose color will be used for teamcolor tag.
 * @param szMessage   Message (formatting rules).
 * @return			  No return
 * 
 * On error/Errors:   If the client or author are not connected an error will be thrown.
 */
stock void C_PrintToChatEx(int client, int author, const char[] szMessage, any:...)
{
	if (CM_IsClientModUser(client, true))
		return;
	
	if (client <= 0 || client > MaxClients)
		ThrowError("Invalid client index %d", client);
	
	if (!IsClientInGame(client))
		ThrowError("Client %d is not in game", client);
	
	if (author < 0 || author > MaxClients)
		ThrowError("Invalid client index %d", author);
	
	char szBuffer[MAX_MESSAGE_LENGTH];
	char szCMessage[MAX_MESSAGE_LENGTH];
	SetGlobalTransTarget(client);
	Format(szBuffer, sizeof(szBuffer), "\x01%s", szMessage);
	VFormat(szCMessage, sizeof(szCMessage), szBuffer, 4);
	
	int index = C_Format(szCMessage, sizeof(szCMessage), author);
	
	if (index == NO_INDEX)
		PrintToChat(client, szCMessage);
	else
		C_SayText2(client, author, szCMessage);
}

/**
 * Prints a message to all clients in the chat area.
 * Supports color tags and teamcolor tag.
 *
 * @param author	  Author index whos color will be used for teamcolor tag.
 * @param szMessage   Message (formatting rules).
 * @return			  No return
 * 
 * On error/Errors:   If the author is not connected an error will be thrown.
 */
stock void C_PrintToChatAllEx(int author, const char[] szMessage, any:...)
{
	if (author < 0 || author > MaxClients)
		ThrowError("Invalid client index %d", author);
	
	if (!IsClientInGame(author))
		ThrowError("Client %d is not in game", author);
	
	char szBuffer[MAX_MESSAGE_LENGTH];
	
	for (int i = 1; i <= MaxClients; i++)
	{
		if (CM_IsClientModUser(i, true))
			continue;
		
		if (IsClientInGame(i) && /*!IsFakeClient(i) &&*/ !CSkipList[i])
		{
			SetGlobalTransTarget(i);
			VFormat(szBuffer, sizeof(szBuffer), szMessage, 3);
			C_PrintToChatEx(i, author, szBuffer);
		}
		
		CSkipList[i] = false;
	}
}

/**
 * Removes color tags from the string.
 *
 * @param szMessage   String.
 * @return			  No return
 */
stock void C_RemoveTags(char[] szMessage, int maxlength)
{
	for (int i = 0; i < view_as<int>(Colors_Max); i++)
		ReplaceString(szMessage, maxlength, CTag[i], "", false);
	
	ReplaceString(szMessage, maxlength, "{teamcolor}", "", false);
}

/**
 * This function should only be used right in front of
 * C_PrintToChatAll or C_PrintToChatAllEx and it tells
 * to those funcions to skip specified client when printing
 * message to all clients. After message is printed client will
 * no more be skipped.
 * 
 * @param client   Client index
 * @return		   No return
 */
stock void C_SkipNextClient(int client)
{
	if (client <= 0 || client > MaxClients)
		ThrowError("Invalid client index %d", client);
	
	CSkipList[client] = true;
}

/**
 * Replaces color tags in a string with color codes
 *
 * @param szMessage   String.
 * @param maxlength   Maximum length of the string buffer.
 * @return			  Client index that can be used for SayText2 author index
 * 
 * On error/Errors:   If there is more then one team color is used an error will be thrown.
 */
stock int C_Format(char[] szMessage, int maxlength, int author=NO_INDEX)
{
	/* Hook event for auto profile setup on map start */
	if (!CEventIsHooked)
	{
		C_SetupProfile();
		HookEvent("server_spawn", C_Event_MapStart, EventHookMode_PostNoCopy);
		CEventIsHooked = true;
	}
	
	int iRandomPlayer = NO_INDEX;
	
	/* If author was specified replace {teamcolor} tag */
	if (author != NO_INDEX)
	{
		if (CProfile_SayText2)
		{
			ReplaceString(szMessage, maxlength, "{teamcolor}", "\x03", false);
			iRandomPlayer = author;
		}
		/* If saytext2 is not supported by game replace {teamcolor} with green tag  */
		else
			ReplaceString(szMessage, maxlength, "{teamcolor}", CTagCode[Green], false);
	}
	else
		ReplaceString(szMessage, maxlength, "{teamcolor}", "", false);
	
	/* For other color tags we need a loop */
	for (int i = 0; i < view_as<int>(Colors_Max); i++)
	{
		/* If tag not found - skip */
		if (StrContains(szMessage, CTag[i], false) == -1)
			continue;
			
		/* If tag is not supported by game replace it with green tag */
		else if (!CProfile_Colors[i])
			ReplaceString(szMessage, maxlength, CTag[i], CTagCode[Green], false);
		
		/* If tag doesn't need saytext2 simply replace */
		else if (!CTagReqSayText2[i])
			ReplaceString(szMessage, maxlength, CTag[i], CTagCode[i], false);

		/* Tag needs saytext2 */
		else
		{
			/* If saytext2 is not supported by game replace tag with green tag */
			if (!CProfile_SayText2)
				ReplaceString(szMessage, maxlength, CTag[i], CTagCode[Green], false);
				
			/* Game supports saytext2 */
			else 
			{
				/* If random player for tag wasn't specified replace tag and find player */
				if (iRandomPlayer == NO_INDEX)
				{
					/* Searching for valid client for tag */
					iRandomPlayer = C_FindRandomPlayerByTeam(CProfile_TeamIndex[i]);
					
					/* If player not found replace tag with green color tag */
					if (iRandomPlayer == NO_PLAYER)
						ReplaceString(szMessage, maxlength, CTag[i], CTagCode[Green], false);

					/* If player was found simply replace */
					else
						ReplaceString(szMessage, maxlength, CTag[i], CTagCode[i], false);
					
				}
				/* If found another team color tag throw error */
				else
				{
					ReplaceString(szMessage, maxlength, CTag[i], "");
					//ThrowError("Using two team colors in one message is not allowed");
				}
			}
			
		}
	}
	
	MC_RemoveColorCodes(szMessage, maxlength);
	
	return iRandomPlayer;
}

/**
 * Founds a random player with specified team
 *
 * @param color_team  Client team.
 * @return			  Client index or NO_PLAYER if no player found
 */
stock int C_FindRandomPlayerByTeam(int color_team)
{
	if (color_team == SERVER_INDEX)
		return 0;
	else
	{
		for (int i = 1; i <= MaxClients; i++)
		{
			if (IsClientInGame(i) && GetClientTeam(i) == color_team)
				return i;
		}	
	}

	return NO_PLAYER;
}

/**
 * Sends a SayText2 usermessage to a client
 *
 * @param szMessage   Client index
 * @param maxlength   Author index
 * @param szMessage   Message
 * @return			  No return.
 */
stock void C_SayText2(int client, int author, const char[] szMessage)
{
	Handle hBuffer = StartMessageOne("SayText2", client, USERMSG_RELIABLE|USERMSG_BLOCKHOOKS);
	if (hBuffer)
	{
		BfWriteByte(hBuffer, author);
		BfWriteByte(hBuffer, true);
		BfWriteString(hBuffer, szMessage);
		EndMessage();
	}
}

/**
 * Creates game color profile 
 * This function must be edited if you want to add more games support
 *
 * @return			  No return.
 */
stock void C_SetupProfile()
{
	CProfile_Colors[Olive] = true;
	CProfile_Colors[Red] = true;
	CProfile_Colors[Blue] = true;
	CProfile_Colors[White] = true;
	CProfile_Colors[Lightgreen] = true;
	CProfile_TeamIndex[Red] = 2;
	CProfile_TeamIndex[Blue] = 3;
	CProfile_TeamIndex[White] = 1;
	CProfile_TeamIndex[Lightgreen] = SERVER_INDEX;
	CProfile_SayText2 = true;
}

public Action C_Event_MapStart(Handle event, const char[] name, bool dontBroadcast)
{
	C_SetupProfile();
	
	for (int i = 1; i <= MaxClients; i++)
		CSkipList[i] = false;
		
	return Plugin_Continue;
}