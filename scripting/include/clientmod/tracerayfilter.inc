#if defined _tracerayfilter_included
	#endinput
#endif
#define _tracerayfilter_included

enum CM_Collision_Group_t
{
	CM_COLLISION_GROUP_NONE  = 0,
	CM_COLLISION_GROUP_DEBRIS,			// Collides with nothing but world and static stuff
	CM_COLLISION_GROUP_DEBRIS_TRIGGER, // Same as debris, but hits triggers
	CM_COLLISION_GROUP_INTERACTIVE_DEBRIS,	// Collides with everything except other interactive debris or debris
	CM_COLLISION_GROUP_INTERACTIVE,	// Collides with everything except interactive debris or debris
	CM_COLLISION_GROUP_PLAYER,
	CM_COLLISION_GROUP_BREAKABLE_GLASS,
	CM_COLLISION_GROUP_VEHICLE,
	CM_COLLISION_GROUP_PLAYER_MOVEMENT,  // For HL2, same as CM_COLLISION_GROUP_Player, for
										// TF2, this filters out other players and CBaseObjects
	CM_COLLISION_GROUP_NPC,			// Generic NPC group
	CM_COLLISION_GROUP_IN_VEHICLE,		// for any entity inside a vehicle
	CM_COLLISION_GROUP_WEAPON,			// for any weapons that need collision detection
	CM_COLLISION_GROUP_VEHICLE_CLIP,	// vehicle clip brush to restrict vehicle movement
	CM_COLLISION_GROUP_PROJECTILE,		// Projectiles!
	CM_COLLISION_GROUP_DOOR_BLOCKER,	// Blocks entities not permitted to get near moving doors
	CM_COLLISION_GROUP_PASSABLE_DOOR,	// Doors that the player shouldn't collide with
	CM_COLLISION_GROUP_DISSOLVING,		// Things that are dissolving are in this group
	CM_COLLISION_GROUP_PUSHAWAY,		// Nonsolid on client and server, pushaway in player code

	CM_COLLISION_GROUP_NPC_ACTOR,		// Used so NPCs in scripts ignore the player.
	CM_COLLISION_GROUP_NPC_SCRIPTED,	// USed for NPCs in scripts that should not collide with each other

	LAST_SHARED_CM_COLLISION_GROUP
};

stock bool CM_DefaultFilter(int pEntity, int m_pPassEnt, int fContentsMask)
{
	if (!CM_StandardFilterRules(pEntity, m_pPassEnt, fContentsMask))
		return false;
	
	if (!CM_PassServerEntityFilter(pEntity, m_pPassEnt))
		return false;
		
	if (!CM_ShouldCollide(pEntity, fContentsMask))
		return false;
		
	if (!CM_CCSGameRulesShouldCollide(pEntity, CM_COLLISION_GROUP_NONE))
		return false;
	
	return true;
}

stock bool CM_StandardFilterRules(int pEntity, int m_pPassEnt, int fContentsMask)
{
	if (!pEntity)
		return true;

	int solid = GetEntProp(pEntity, Prop_Send, "m_nSolidType", 1);
	if (!(GetEntityFlags(pEntity) & FL_WORLDBRUSH) || (solid != 1/*SOLID_BSP*/ && solid != 6/*SOLID_VPHYSICS*/))
	{
		if ((fContentsMask & CONTENTS_MONSTER) == 0)
			return false;
	}
	if (!(fContentsMask & CONTENTS_WINDOW) && GetEntityRenderMode(pEntity) != RENDER_NORMAL)
		return false;

	if (!(fContentsMask & CONTENTS_MOVEABLE) &&(view_as<MoveType>(GetEntProp(pEntity, Prop_Data, "m_MoveType", 1)) == MOVETYPE_PUSH))
		return false;

	return true;
}

stock bool CM_PassServerEntityFilter(int pEntTouch, int pEntPass)
{
	if (!pEntTouch || !pEntPass)
		return true;
		
	if (GetEntPropEnt(pEntTouch, Prop_Data, "m_hOwnerEntity") == pEntPass)
		return false;

	if (GetEntPropEnt(pEntPass, Prop_Data, "m_hOwnerEntity") == pEntTouch)
		return false;

	return true;
}

stock bool CM_ShouldCollide(int pEntity, int contentsMask)
{
	if (pEntity && !(contentsMask & CONTENTS_DEBRIS) && GetEntProp(pEntity, Prop_Send, "m_CollisionGroup", 1) == 1/*COLLISION_GROUP_DEBRIS*/)
		return false;
		
	return true;
}

stock bool CM_CCSGameRulesShouldCollide(int pEntity,	CM_Collision_Group_t collisionGroup0)
{
	if (!pEntity)
		return true;
	
	CM_Collision_Group_t collisionGroup1 = view_as<CM_Collision_Group_t>(GetEntProp(pEntity, Prop_Send, "m_CollisionGroup", 1));
	if (collisionGroup0 > collisionGroup1)
	{
		CM_Collision_Group_t temp = collisionGroup0;
		collisionGroup0 = collisionGroup1;
		collisionGroup1 = temp;
	}

	if (collisionGroup0 == CM_COLLISION_GROUP_PLAYER_MOVEMENT && collisionGroup1 == CM_COLLISION_GROUP_WEAPON)
		return false;

	if ((collisionGroup0 == CM_COLLISION_GROUP_PLAYER || collisionGroup0 == CM_COLLISION_GROUP_PLAYER_MOVEMENT) && collisionGroup1 == CM_COLLISION_GROUP_PUSHAWAY)
		return false;

	if (collisionGroup0 == CM_COLLISION_GROUP_DEBRIS && collisionGroup1 == CM_COLLISION_GROUP_PUSHAWAY)
		return true;

	return CM_CGameRulesShouldCollide(collisionGroup0, collisionGroup1);
}

stock bool CM_CGameRulesShouldCollide(CM_Collision_Group_t collisionGroup0, CM_Collision_Group_t collisionGroup1)
{
	if ((collisionGroup0 == CM_COLLISION_GROUP_PLAYER || collisionGroup0 == CM_COLLISION_GROUP_PLAYER_MOVEMENT) && collisionGroup1 == CM_COLLISION_GROUP_PUSHAWAY)
		return false;
		
	if (collisionGroup0 == CM_COLLISION_GROUP_DEBRIS && collisionGroup1 == CM_COLLISION_GROUP_PUSHAWAY)
		return true;
		
	if ((collisionGroup0 == CM_COLLISION_GROUP_IN_VEHICLE) || (collisionGroup1 == CM_COLLISION_GROUP_IN_VEHICLE))
		return false;

	if ((collisionGroup1 == CM_COLLISION_GROUP_DOOR_BLOCKER) && (collisionGroup0 != CM_COLLISION_GROUP_NPC))
		return false;

	if ((collisionGroup0 == CM_COLLISION_GROUP_PLAYER) && (collisionGroup1 == CM_COLLISION_GROUP_PASSABLE_DOOR))
		return false;

	if (collisionGroup0 == CM_COLLISION_GROUP_DEBRIS || collisionGroup0 == CM_COLLISION_GROUP_DEBRIS_TRIGGER)
		return false;

	if ((collisionGroup0 == CM_COLLISION_GROUP_DISSOLVING) || (collisionGroup1 == CM_COLLISION_GROUP_DISSOLVING))
	{
		if (collisionGroup0 != CM_COLLISION_GROUP_NONE)
			return false;
	}

	if (collisionGroup0 == CM_COLLISION_GROUP_INTERACTIVE_DEBRIS && collisionGroup1 == CM_COLLISION_GROUP_INTERACTIVE_DEBRIS)
		return false;

	if (collisionGroup0 == CM_COLLISION_GROUP_INTERACTIVE_DEBRIS && (collisionGroup1 == CM_COLLISION_GROUP_PLAYER_MOVEMENT || collisionGroup1 == CM_COLLISION_GROUP_PLAYER))
		return false;

	if (collisionGroup0 == CM_COLLISION_GROUP_BREAKABLE_GLASS && collisionGroup1 == CM_COLLISION_GROUP_BREAKABLE_GLASS)
		return false;

	if (collisionGroup1 == CM_COLLISION_GROUP_INTERACTIVE && collisionGroup0 != CM_COLLISION_GROUP_NONE)
		return false;

	if (collisionGroup1 == CM_COLLISION_GROUP_PROJECTILE)
	{
		if (collisionGroup0 == CM_COLLISION_GROUP_DEBRIS || collisionGroup0 == CM_COLLISION_GROUP_WEAPON || collisionGroup0 == CM_COLLISION_GROUP_PROJECTILE)
			return false;
	}

	if (collisionGroup1 == CM_COLLISION_GROUP_WEAPON)
	{
		if (collisionGroup0 == CM_COLLISION_GROUP_VEHICLE || collisionGroup0 == CM_COLLISION_GROUP_PLAYER || collisionGroup0 == CM_COLLISION_GROUP_NPC)
			return false;
	}

	if (collisionGroup0 == CM_COLLISION_GROUP_VEHICLE_CLIP || collisionGroup1 == CM_COLLISION_GROUP_VEHICLE_CLIP)
	{
		if (collisionGroup0 == CM_COLLISION_GROUP_VEHICLE)
			return true;
			
		return false;
	}

	return true;
}

stock bool CM_FilterLocalPlayer(int entity, int mask, any target)
{
	return CM_DefaultFilter(entity, target, mask) && entity != target;
}