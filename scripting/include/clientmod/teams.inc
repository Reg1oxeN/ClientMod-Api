#if defined _clientmodteams_included
	#endinput
#endif
#define _clientmodteams_included

stock int CM_GetTeam(int index)
{
	static int teams[4] = { INVALID_ENT_REFERENCE, ... };
	if (index < 0 || index >= sizeof(teams))
	{
		return -1;
	}

	int edict = teams[index];
	if (IsValidEntity(edict))
	{
		return edict;
	}

	bool foundTeamManager = false;
	int maxEntities = GetMaxEntities();
	for (int entity=MaxClients+1; entity < maxEntities; entity++)
	{
		if (!IsValidEntity(entity))
		{
			continue;
		}
		char entity_className[64];
		if (GetEntPropString(entity, Prop_Data, "m_iClassname", entity_className, sizeof(entity_className)) && strcmp(entity_className, "cs_team_manager") == 0)
		{
			foundTeamManager = true;
		}
		else if (foundTeamManager)
		{
			return -1;
		}
		else
		{
			continue;
		}

		int num = GetEntProp(entity, Prop_Send, "m_iTeamNum");
		if (num > -1 && num < sizeof(teams))
		{
			teams[num] = EntIndexToEntRef(entity);
		}
		if (num == index)
		{
			return entity;
		}
	}
	return -1;
}

stock bool CM_SetTeamName(int index, const char[] name)
{
	char sTeamNames[][] =
	{
		"Unassigned",
		"Spectator",
		"TERRORIST",
		"CT"
	};
	
	int team = CM_GetTeam(index);
	if (team != -1)
	{
		if (strlen(name) > 0)
		{
			SetEntPropString(team, Prop_Send, "m_szTeamname", name);
		}
		else
		{
			SetEntPropString(team, Prop_Send, "m_szTeamname", sTeamNames[index]);
		}
		
		
		return true;
	}
	return false;
}