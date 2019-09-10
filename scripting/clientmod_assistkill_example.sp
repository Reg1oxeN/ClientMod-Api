#pragma semicolon 1

#include <sourcemod>
#include <clientmod>

public Plugin myinfo =
{
	name = "ClientMod Assist Kill Example",
	author = CM_AUTHOR,
	description = "Пример использования асcистов",
	version = "1.0",
	url = CM_URL
};

public void OnPluginStart()
{
	ClientModAssistPatch(); 
	HookEvent("player_death", Event_PlayerDeath, EventHookMode_Pre);
}

public void Event_PlayerDeath(Event event, const char[] name, bool dontBroadcast)
{
	event.SetInt("assister", event.GetInt("userid"));
}

void ClientModAssistPatch() // автоматическое добавление возможности отправки ассиста со стороны сервера
{
	bool bSuccessfull = false;
	char FinalEventFilePath[PLATFORM_MAX_PATH];
	DirectoryListing EventFileSearch = OpenDirectory(".", true, "MOD");
	if (EventFileSearch != null)
	{
		char DirName[PLATFORM_MAX_PATH];
		FileType cFileType = FileType_Unknown;
		while (EventFileSearch.GetNext(DirName, sizeof(DirName), cFileType))
		{
			if (cFileType == FileType_Directory && strcmp(DirName, "resource", false) == 0)
			{
				strcopy(FinalEventFilePath, sizeof(FinalEventFilePath), DirName);
				
				delete EventFileSearch;
				EventFileSearch = OpenDirectory(DirName, true, "MOD");
				if (EventFileSearch != null)
				{
					while (EventFileSearch.GetNext(DirName, sizeof(DirName), cFileType))
					{
						if (cFileType == FileType_File && strcmp(DirName, "modevents.res", false) == 0)
						{
							Format(FinalEventFilePath, sizeof(FinalEventFilePath), "%s/%s", FinalEventFilePath, DirName);
							break;
						}
					}
				}
				break;
			}
		}
		if (EventFileSearch != null)
			delete EventFileSearch;
	}
	
	if (!FinalEventFilePath[0])
	{
		strcopy(FinalEventFilePath, sizeof(FinalEventFilePath), "resource/ModEvents.res");
	}
	
	{
		KeyValues hModEvents = new KeyValues("cstrikeevents");
		if (hModEvents.ImportFromFile(FinalEventFilePath) && hModEvents.JumpToKey("player_death"))
		{
			char cTrash[8];
			bool bAlreadyPatched = hModEvents.GetString("assister", cTrash, sizeof(cTrash)) && strcmp(cTrash, "short") == 0;
			bool bPatched = false;
			if (!bAlreadyPatched)
			{
				hModEvents.SetString("assister", "short");
				
				hModEvents.Rewind();
				if (hModEvents.JumpToKey("hostage_rescued_all"))
				{
					hModEvents.SetString("clientmodfix", "none");
				}
				
				hModEvents.Rewind();
				if (hModEvents.JumpToKey("round_freeze_end"))
				{
					hModEvents.SetString("clientmodfix", "none");
				}
				
				hModEvents.Rewind();
				if (hModEvents.JumpToKey("nav_generate"))
				{
					hModEvents.SetString("clientmodfix", "none");
				}
				
				hModEvents.Rewind(); 
				bPatched = hModEvents.ExportToFile(FinalEventFilePath);
			}
			
			if (bPatched)
				PrintToServer("[ClientMod] Kill assist event successfully patched! Restart server for use.");
			else if (bAlreadyPatched)
				PrintToServer("[ClientMod] Kill assist event already patched!");
				
			
			bSuccessfull = bAlreadyPatched || bPatched;
		}
		delete hModEvents;
	}
	
	
	if (!bSuccessfull)
		PrintToServer("[ClientMod] Kill assist event failed patch!");
	
}