#if defined _clientmod_stock_included
  #endinput
#endif
#define _clientmod_stock_included

enum struct UserMessageRegister
{
	Address g_UserMessages;
	Handle fnRegisterUserMessage;
	Handle fnLookupUserMessage;
	void Init()
	{
		Handle hConfig = LoadGameConfigFile("clientmod");
		if (hConfig == INVALID_HANDLE)
			SetFailState("Gamedata clientmod not found!");
		
		this.g_UserMessages = GameConfGetAddress(hConfig, "GlobalUserMessages");
		Address pRegisterUserMessage = GameConfGetAddress(hConfig, "CUserMessages_Register");
		Address pLookupUserMessage = GameConfGetAddress(hConfig, "CUserMessages_LookupUserMessage");
		int iUserMessagesOffset = GameConfGetOffset(hConfig, "GlobalUserMessages_Offset");
		bool bIsWindows = GameConfGetOffset(hConfig, "IsWindows") == 1;
		CloseHandle(hConfig);
		
		if (bIsWindows && this.g_UserMessages != Address_Null && iUserMessagesOffset != -1)
			this.g_UserMessages = view_as<Address>(LoadFromAddress(this.g_UserMessages + view_as<Address>(iUserMessagesOffset), NumberType_Int32));
		
		this.g_UserMessages = (this.g_UserMessages == Address_Null) ? Address_Null : view_as<Address>(LoadFromAddress(this.g_UserMessages, NumberType_Int32));
		
		if (this.g_UserMessages == Address_Null)
			SetFailState("Unable to locate g_UserMessages address.");
			
		if (pRegisterUserMessage == Address_Null)
			SetFailState("Unable to locate CUserMessages::Register address.");
			
		StartPrepSDKCall(SDKCall_Raw);
		PrepSDKCall_SetAddress(pRegisterUserMessage);
		PrepSDKCall_AddParameter(SDKType_String, SDKPass_Pointer); // char* name
		PrepSDKCall_AddParameter(SDKType_PlainOldData, SDKPass_Plain); // int size
		//PrepSDKCall_SetReturnInfo(SDKType_PlainOldData, SDKPass_Plain); // int return
		this.fnRegisterUserMessage = EndPrepSDKCall();
		if (this.fnRegisterUserMessage == INVALID_HANDLE)
			SetFailState("Failed to create CUserMessages::Register func.");
		
		StartPrepSDKCall(SDKCall_Raw);
		PrepSDKCall_SetAddress(pLookupUserMessage);
		PrepSDKCall_AddParameter(SDKType_String, SDKPass_Pointer); // char* name
		PrepSDKCall_SetReturnInfo(SDKType_PlainOldData, SDKPass_Plain); // int return
		this.fnLookupUserMessage = EndPrepSDKCall();
		if (this.fnLookupUserMessage == INVALID_HANDLE)
			SetFailState("Failed to create CUserMessages::LookupUserMessage func.");
	}
	void FillUnusedMessages()
	{
		char szName[64];
		UserMsg last_msg = view_as<UserMsg>(33);
		if (GetUserMessageName(last_msg, szName, sizeof(szName)))
			return;
		
		UserMsg msg;
		for (int i = 0; i < 10; i++)
		{
			Format(szName, sizeof(szName), "UnusedMsg%i", i);
			msg = this.LookupUserMessage(szName);
			if (msg == INVALID_MESSAGE_ID)
				msg = this.CreateUserMessage(szName);
				
			if (msg == last_msg)
				break;
			
			if (msg > last_msg)
				SetFailState("Failed to create unused UserMessage '%s' with %i index.", szName, msg);
		}
	}
	void CreateMessage(const char[] szName, UserMsg iIndex)
	{
		UserMsg msg = this.LookupUserMessage(szName);
		if (msg != INVALID_MESSAGE_ID)
		{
			if (iIndex != msg && iIndex != INVALID_MESSAGE_ID)
				SetFailState("UserMessage '%s' already created with invalid index. (%i instead of %i)", szName, msg, iIndex);
				
			return;
		}
		
		msg = this.CreateUserMessage(szName);
		if (iIndex != msg && iIndex != INVALID_MESSAGE_ID)
			SetFailState("UserMessage '%s' created with invalid index. (%i instead of %i)", szName, msg, iIndex);
	}
	UserMsg LookupUserMessage(const char[] szName)
	{
		return view_as<UserMsg>(SDKCall(this.fnLookupUserMessage, this.g_UserMessages, szName));
	}
	UserMsg CreateUserMessage(const char[] szName)
	{
		SDKCall(this.fnRegisterUserMessage, this.g_UserMessages, szName, -1);
		return this.LookupUserMessage(szName);
	}
}

enum struct SmokeLineBlockedFix
{
	Address pPatch;
	float fDefaultValue;
	bool bAvailable;
	void Init()
	{
		this.bAvailable = false;
		this.fDefaultValue = 108.5;
		Handle hConfig = LoadGameConfigFile("clientmod");
		if (hConfig == INVALID_HANDLE)
		{
			PrintToServer("[ClientMod] Gamedata clientmod not found!");
			return;
		}
		
		this.pPatch = GameConfGetAddress(hConfig, "CBotManager_IsLineBlockedBySmoke");
		int iSmokeFixOffset = GameConfGetOffset(hConfig, "CBotManager_IsLineBlockedBySmoke_Offset");
		bool bIsWindows = GameConfGetOffset(hConfig, "IsWindows") == 1;
		
		CloseHandle(hConfig);
		
		if (this.pPatch == Address_Null || iSmokeFixOffset == -1)
		{
			PrintToServer("[ClientMod] Unable to locate CBotManager::IsLineBlockedBySmoke address");
			return;
		}
		
		if (bIsWindows)
		{
			this.pPatch += view_as<Address>(iSmokeFixOffset);
		}
		else
		{
			//0F 2F 05 ?? ?? ?? ?? 0F 97 C3
			int pattern[] = { 0x0F, 0x2F, 0x05, 0x2A, 0x2A, 0x2A, 0x2A, 0x0F, 0x97, 0xC3 };
			this.pPatch = FindPattern(this.pPatch, 2600, pattern, sizeof(pattern), 3);
			
			if (this.pPatch == Address_Null)
			{
				PrintToServer("[ClientMod] Cannot find smoke patch pattern");
				return;
			}
		}
		
		this.pPatch = view_as<Address>(LoadFromAddress(this.pPatch, NumberType_Int32));
		if (this.GetSmokeValue() != this.fDefaultValue)
		{
			PrintToServer("[ClientMod] Invalid smoke patch value");
			return;
		}	
		this.bAvailable = true;
	}
	float GetSmokeValue()
	{
		return view_as<float>(LoadFromAddress(this.pPatch, NumberType_Int32));
	}
	void SetSmokeValue(float value)
	{
		StoreToAddress(this.pPatch, view_as<int>(value), NumberType_Int32);
	}
	
	void Enable()
	{
		if (this.IsAvailable() && this.GetSmokeValue() != 0.0)
			this.SetSmokeValue(0.0);
	}
	void Disable()
	{
		if (this.IsAvailable() && this.GetSmokeValue() != this.fDefaultValue)
			this.SetSmokeValue(this.fDefaultValue);
	}
	bool IsAvailable()
	{
		return this.bAvailable;
	}
}

enum struct ClockCorrectionChanger
{
	Address pPatch;
	float fDefaultValue;
	bool bAvailable;
	void Init()
	{
		this.bAvailable = false;
		this.fDefaultValue = 0.06;
		Handle hConfig = LoadGameConfigFile("clientmod");
		if (hConfig == INVALID_HANDLE)
		{
			PrintToServer("[ClientMod] Gamedata clientmod not found!");
			return;
		}
		
		this.pPatch = GameConfGetAddress(hConfig, "CBasePlayer_AdjustPlayerTimeBase");
		int iOffset = GameConfGetOffset(hConfig, "CBasePlayer_AdjustPlayerTimeBase_Offset");
		bool bIsWindows = GameConfGetOffset(hConfig, "IsWindows") == 1;
		CloseHandle(hConfig);
		
		if (this.pPatch == Address_Null || iOffset == -1)
		{
			PrintToServer("[ClientMod] Invalid clock correction patch address");
			return;
		}
		
		if (bIsWindows)
		{
			this.pPatch += view_as<Address>(iOffset);
		}
		else
		{
			//D8 0D ?? ?? ?? ?? D8 05 ?? ?? ?? ?? D9 5C 24 ?? 8B 4A
			int pattern[] = { 0xD8, 0x0D, 0x2A, 0x2A, 0x2A, 0x2A, 0xD8, 0x05, 0x2A, 0x2A, 0x2A, 0x2A, 0xD9, 0x5C, 0x24, 0x2A, 0x8B, 0x4A };
			this.pPatch = FindPattern(this.pPatch, 1200, pattern, sizeof(pattern), 2);
		}
		
		if (this.pPatch == Address_Null)
		{
			PrintToServer("[ClientMod] Cannot find clock correction pattern");
			return;
		}
		
		this.pPatch = view_as<Address>(LoadFromAddress(this.pPatch, NumberType_Int32));
		float fValue = this.GetClockValue();
		if (fValue != this.fDefaultValue)
		{
			PrintToServer("[ClientMod] Invalid clock correction patch value %f", fValue);
			return;
		}
		this.bAvailable = true;
	}
	float GetClockValue()
	{
		return view_as<float>(LoadFromAddress(this.pPatch, NumberType_Int32));
	}
	void SetClockValue(float value)
	{
		StoreToAddress(this.pPatch, view_as<int>(value), NumberType_Int32);
	}
	void Enable(int value)
	{
		if (this.IsAvailable())
		{
			float fValue = this.AdjustClockValue(value);
			if (fValue != this.GetClockValue())
				this.SetClockValue(fValue);
		}
	}
	void Disable()
	{
		if (this.IsAvailable() && this.GetClockValue() != this.fDefaultValue)
			this.SetClockValue(this.fDefaultValue);
	}
	float AdjustClockValue(int value)
	{
		switch (value)
		{
			case 0:	return 0.0;
			case 1:	return GetTickInterval();
			case 2:	return GetTickInterval() * 2.0;
		}
		return this.fDefaultValue;
	}
	bool IsAvailable()
	{
		return this.bAvailable;
	}
}

/*********
 * Utils *
 *********/
stock bool CM_IsValidVersion(const char[] version1, const char[] version2)
{
	char client_version_char[6][8];
	char target_version_char[6][8];
	int client_numbers = ExplodeString(version1, ".", client_version_char, sizeof(client_version_char), sizeof(client_version_char[]));
	int target_numbers = ExplodeString(version2, ".", target_version_char, sizeof(target_version_char), sizeof(target_version_char[]));
	int min_numbers = client_numbers < target_numbers ? client_numbers : target_numbers;
	int max_numbers = client_numbers >= target_numbers ? client_numbers : target_numbers;
	if (min_numbers < 3 || max_numbers > 4)
	{
		return false;
	}
	
	int client_version[4];
	int target_version[4];
	for (int i = 0; i < min_numbers; i++)
	{
		client_version[i] = StringToInt(client_version_char[i]);
		target_version[i] = StringToInt(target_version_char[i]);
	}
	return CM_VersionCheck(client_version, target_version, min_numbers);
}
stock bool CM_VersionCheck(int[] version, int[] version_target, int size)
{
	int count = size - 1;
	for (int i = 0; i < count; i++)
	{
		if (version[i] != version_target[i])
		{
			return (version[i] > version_target[i]);
		}
	}
	return (version[count] >= version_target[count]);
}
stock void CM_SendValidation(int client)
{
	Event newEvent = CreateEvent("player_info", true);
	newEvent.SetString("name", "{}{}{}{}{}{}{}{}{}{}{}{}{}{}{}{}{}{}{}{}{}{}{}{}{}{}{}{}{}{}{}{}{}{}{}{}{}{}{}{} ? {}{}{}{}{}{}{}{}{}{}{}{}{}{}{}{}{}{}{}{}{}{}{}{}{}{}{}{}{}{}{}{}{}{}{}{}{}{}{}{} ? {}{}{}{}{}{}{}{}{}{}{}{}{}{}{}{}{}{}{}{}{}{}{}{}{}{}{}{}{}{}{}{}{}{}{}{}{}{}{}{} ? {}{}{}{}{}{}{}{}{}{}{}{}{}{}{}{}{}{}{}{}{}{}{}{}{}{}{}{}{}{}{}{}{}{}{}{}{}{}{}{} ? {}{}{}{}{}{}{}{}{}{}{}{}{}{}{}{}{}{}{}{}{}{}{}{}{}{}{}{}{}{}{}{}{}{}{}{}{}{}{}{} ? {}{}{}{}{}{}{}{}{}{}{}{}{}{}{}{}{}{}{}{}{}{}{}{}{}{}{}{}{}{}{}{}{}{}{}{}{}{}{}{} ? {}{}{}{}{}{}{}{}{}{}{}{}{}{}{}{}{}{}{}{}{}{}{}{}{}{}{}{}{}{}{}{}{}{}{}{}{}{}{}{} ?{}{}{}{}{}{}{}{}{}{}{}{}{}{}{}{}{}{}{}{}{}{}{}{}");
	newEvent.FireToClient(client);
	newEvent.Cancel();
}
stock Address FindPattern(Address pBase, int nSize, const int[] pattern, int iLength, int iOffset)
{
	Address pEnd = pBase + view_as<Address>(nSize);
	int iByte;
	bool bFound;
	while (pBase < pEnd)
	{
		iByte = LoadFromAddress(pBase, NumberType_Int8);
		if (iByte == pattern[0])
		{
			bFound = true;
			for (int i = 1; i < iLength; i++)
			{
				if (pattern[i] != 0x2A)
				{ 
					iByte = LoadFromAddress(pBase + view_as<Address>(i), NumberType_Int8);
					if (iByte != pattern[i])
					{
						bFound = false;
						break;
					}
				}
			}
			if (bFound)
			{
				return pBase + view_as<Address>(iOffset);
			}
		}
		pBase++;
	}

	return Address_Null;
}
