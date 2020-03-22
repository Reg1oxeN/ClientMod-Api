#pragma semicolon 1

#include <sourcemod>
#include <sdktools>
#include <sdkhooks>

/*		строго в таком порядке!		*/
#include <clientmod>
#include <clientmod/multicolors>

public Plugin myinfo =
{
	name = "ClientMod Chat+HudMsg Example",
	author = CM_AUTHOR,
	description = "Пример использования HEX цветов в чате и худе",
	version = "1.0",
	url = CM_URL
};

public void OnPluginStart()
{
	RegConsoleCmd("cm_hud", hud_test);
}

public Action hud_test(int client, int args)
{
	if (client < 1)
		return Plugin_Handled;
	
	PrintToChatAll("%sДанный текст видят только старые клиенты", CHIDE_TAG);
	
	CPrintToChatAll("%s",
	"{#B2F700}TEST {ancient}ancient {arcana}arcana {axis}axis {blue}blue {cyan}cyan\n{gray}gray {legendary}legendary {lime}lime {mythical}mythical {gold}gold {maroon}maroon {strange}strange {valve}valve {yellowgreen}yellowgreen");
	
	if (CM_IsClientModUser(client))
	{
		char sMessage[MAX_HUD_MESSAGE_LENGTH*2]; // CFormatHudText в любом случае вернет текст не больше MAX_HUD_MESSAGE_LENGTH
		CFormatHudText(sMessage, sizeof(sMessage), "%s",
		"{#B2F700}TEST {ancient}ancient {arcana}arcana {axis}axis {blue}blue {cyan}cyan\n{gray}gray {legendary}legendary {lime}lime {mythical}mythical {gold}gold {maroon}maroon {strange}strange {valve}valve {yellowgreen}yellowgreen");
		
		{
			Handle hBuffer = StartMessageOne("HudMsg", client); 
			if (hBuffer)
			{
				BfWriteByte(hBuffer, 1); //channel
				BfWriteFloat(hBuffer, -1.0); //x
				BfWriteFloat(hBuffer, 0.55); //y
				
				BfWriteByte(hBuffer, 255); //r
				BfWriteByte(hBuffer, 0); //g
				BfWriteByte(hBuffer, 0); //b
				BfWriteByte(hBuffer, 255); //a
				
				BfWriteByte(hBuffer, 0); //r
				BfWriteByte(hBuffer, 255); //g
				BfWriteByte(hBuffer, 0); //b
				BfWriteByte(hBuffer, 255); //a
				
				BfWriteByte(hBuffer, 0); //effect
				
				BfWriteFloat(hBuffer, 0.0); //fadein
				BfWriteFloat(hBuffer, 2.0); //fadeout
				
				BfWriteFloat(hBuffer, 10.0); //holdtime
				BfWriteFloat(hBuffer, 0.0); //fxtime
				
				
				BfWriteString(hBuffer, sMessage); 
				EndMessage();
			}
		}
		{
			Handle hBuffer = StartMessageOne("HudMsg", client); 
			if (hBuffer)
			{
				BfWriteByte(hBuffer, 2); //channel
				BfWriteFloat(hBuffer, -1.0); //x
				BfWriteFloat(hBuffer, 0.4); //y
				
				BfWriteByte(hBuffer, 255); //r
				BfWriteByte(hBuffer, 0); //g
				BfWriteByte(hBuffer, 0); //b
				BfWriteByte(hBuffer, 255); //a
				
				BfWriteByte(hBuffer, 0); //r
				BfWriteByte(hBuffer, 255); //g
				BfWriteByte(hBuffer, 0); //b
				BfWriteByte(hBuffer, 255); //a
				
				BfWriteByte(hBuffer, 0); //effect
				
				BfWriteFloat(hBuffer, 0.0); //fadein
				BfWriteFloat(hBuffer, 2.0); //fadeout
				
				BfWriteFloat(hBuffer, 10.0); //holdtime
				BfWriteFloat(hBuffer, 0.0); //fxtime
				
				
				BfWriteString(hBuffer, sMessage); 
				EndMessage();
			}
		}
		/*
		либо пользуйтесь этим апи:
		
		void SetHudTextParams(float x, float y, float holdTime, int r, int g, int b, int a, int effect, float fxTime, float fadeIn, float fadeOut)
		void SetHudTextParamsEx(float x, float y, float holdTime, int color1[4], int color2[4], int effect, float fxTime, float fadeIn, float fadeOut)
		int ShowHudText(int client, int channel, const char[] message, any ...)
		Handle CreateHudSynchronizer()
		int ShowSyncHudText(int client, Handle sync, const char[] message, any ...)
		*/
	}
	
	return Plugin_Handled;
}