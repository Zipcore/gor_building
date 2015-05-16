#include <sourcemod>
#include <sdktools>
#include <sdkhooks>
#include <geoip>
#include <morecolors>
#include <cstrike>
#include <smlib>

#include "include/buildstocks.sp"

#define NAME "GoR - Building"
#define AUTHOR "FusionLock"
#define DESCRIPTION "A plugin for building."
#define VERSION "1.0.0"
#define URL "http://xfusionlockx.tk/"

#define MAX_ENTITIES 2048

new g_iBalance[MAXPLAYERS + 1];
new g_iBeam;
new g_iEntityCount[MAXPLAYERS + 1];
new g_iEntityDissolver;
new g_iEntityIgniter;
new g_iEntityLimit;
new g_iGlow;
new g_iGray[4] = {255, 255, 255, 300};
new g_iHalo;
new g_iHudColor[MAXPLAYERS + 1][4];
new g_iLand;
new g_iLaser;
new g_iOwner[MAX_ENTITIES + 1];
new g_iPhys;
new g_iPrice[MAX_ENTITIES + 1];
new g_iWhite[4] = {255, 255, 255, 200};

new Float:g_fLandPos[MAXPLAYERS + 1][2][3];
new Float:g_fZero[3] = {0.0, 0.0, 0.0};

new bool:g_bEnabled;
new bool:g_bForSale[MAX_ENTITIES + 1];
new bool:g_bFrozen[MAX_ENTITIES + 1];
new bool:g_bHudEnabled;
new bool:g_bJustJoined[MAXPLAYERS + 1];
new bool:g_bNoclipDisabled[MAXPLAYERS + 1];
new bool:g_bNoclipEnabled[MAXPLAYERS + 1];
new bool:g_bSentMessage[MAXPLAYERS + 1];
new bool:g_bIsInLand[MAXPLAYERS + 1];
new bool:g_bLandDrawing[MAXPLAYERS + 1];
new bool:g_bStartedLand[MAXPLAYERS + 1];
new bool:g_bGettingPositions[MAXPLAYERS + 1];
new bool:g_bPutInServer[MAXPLAYERS + 1];

new Handle:g_hEnabled = INVALID_HANDLE;
new Handle:g_hEntityLimit = INVALID_HANDLE;
new Handle:g_hHudEnabled = INVALID_HANDLE;
new Handle:g_hHudTimer = INVALID_HANDLE;

new String:g_sClientDatabase[PLATFORM_MAX_PATH];
new String:g_sPropDatabase[PLATFORM_MAX_PATH];
new String:g_sPropName[MAX_ENTITIES + 1][64];

//===============|Plugin Start|===============

public Plugin:myinfo = {name = NAME, author = AUTHOR, description = DESCRIPTION, version = VERSION, url = URL};

public OnPluginStart()
{
	LoadTranslations("common.phrases");

	BuildPath(Path_SM, g_sClientDatabase, sizeof(g_sClientDatabase), "data/gor/databases/client.txt");
	BuildPath(Path_SM, g_sPropDatabase, sizeof(g_sPropDatabase), "data/gor/databases/props.txt");

	RegServerCmd("gor_say", Command_GorSay);

	RegAdminCmd("sm_headcrabattack", Command_HeadcrabCan, ADMFLAG_SLAY, "Spawns an headcrab canister and attacks a target.");
	RegAdminCmd("sm_nukeem", Command_NukeEm, ADMFLAG_SLAY, "Nukes a client 5 times with headcrab canisters.");
	RegAdminCmd("sm_openmotdonall", Command_OpenMotdOnAll, ADMFLAG_SLAY, "Opens a motd on all clients.");

	RegConsoleCmd("sm_spawn", Command_Spawn, "Spawns a prop by a givin alias.");
	RegConsoleCmd("sm_delete", Command_Delete, "Deletes whatever entity you are looking at.");
	RegConsoleCmd("sm_freeze", Command_Freeze, "Enables motion on the entity you are looking at.");
	RegConsoleCmd("sm_unfreeze", Command_UnFreeze, "Disables motion on the entity you are looking at.");
	//RegConsoleCmd("sm_ignite", Command_Ignite, "Ignites the entity you are looking at.");
	RegConsoleCmd("sm_buy", Command_Buy, "Buys the entity you are looking at.");
	RegConsoleCmd("sm_sell", Command_Sell, "Puts the entity you are looking at up for sale.");
	RegConsoleCmd("sm_changeprice", Command_ChangePrice, "Changes the price of the entity you are looking at.");
	RegConsoleCmd("sm_land", Command_Land, "Creates a building area.");
	RegConsoleCmd("sm_fly", Command_Fly, "Enables noclip on the client");
	RegConsoleCmd("sm_noclip", Command_Noclip, "Disables noclip in your land.");
	//RegConsoleCmd("sm_save", Command_Save, "Saves your build.");
	//RegConsoleCmd("sm_load", Command_Load, "Loads your build.");

	g_hEnabled = CreateConVar("gor_build_enabled", "1", "Enables or disables the building plugin.", FCVAR_PLUGIN|FCVAR_NOTIFY, true, 0.0, true, 1.0);
	g_hEntityLimit = CreateConVar("gor_entity_limit", "350", "The entity limit in the GoR Building plugin.", FCVAR_NOTIFY|FCVAR_PLUGIN);
	g_hHudEnabled = CreateConVar("gor_hud_enabled", "1", "Enables or disables the building hud.", FCVAR_PLUGIN|FCVAR_NOTIFY, true, 0.0, true, 1.0);

	HookConVarChange(g_hEnabled, OnConVarUpdate);
	HookConVarChange(g_hEntityLimit, OnConVarUpdate);
	HookConVarChange(g_hHudEnabled, OnConVarUpdate);

	g_bEnabled = GetConVarBool(g_hEnabled);
	g_iEntityLimit = GetConVarInt(g_hEntityLimit);
	g_bHudEnabled = GetConVarBool(g_hHudEnabled);

	AddCommandListener(Command_Say, "say");
	AddCommandListener(Command_Say, "say_team");  

	HookEvent("player_connect", Event_PlayerConnect, EventHookMode_Pre);
	HookEvent("player_death", Event_PlayerDeath, EventHookMode_Pre);
	HookEvent("player_disconnect", Event_PlayerDisconnect, EventHookMode_Pre);
}

public OnPluginEnd()
{
	UnhookConVarChange(g_hEnabled, OnConVarUpdate);
	UnhookConVarChange(g_hEntityLimit, OnConVarUpdate);

	g_hEnabled = INVALID_HANDLE;
	g_hEntityLimit = INVALID_HANDLE;
}

//===============|Plugin Forwards|===============

public OnConVarUpdate(Handle:hConVar, const String:sOldValue[], const String:sNewValue[])
{
	if(hConVar == g_hEnabled)
	{
		g_bEnabled = GetConVarBool(g_hEnabled);

		if(g_bEnabled)
		{
			OPrintToChatAll("Build has been {green}enabled{default}.");
		}else{
			OPrintToChatAll("Build has been {red}disabled{default}.");
		}
	}

	if(g_bEnabled)
	{
		if(hConVar == g_hEntityLimit)
		{
			g_iEntityLimit = GetConVarInt(g_hEntityLimit);

			OPrintToChatAll("Entity limit has been updated to {blue}%d{default}.", g_iEntityLimit);
		}else if(hConVar == g_hHudEnabled)
		{
			g_bHudEnabled = GetConVarBool(g_hHudEnabled);

			if(g_bHudEnabled)
			{
				OPrintToChatAll("Hud has been {green}enabled{default}.");
			}else{
				OPrintToChatAll("Hud has been {red}disabled{default}.");
			}
		}
	}
}

public OnMapStart()
{
	g_hHudTimer = CreateTimer(0.1, Timer_Hud, _, TIMER_REPEAT);
	CreateTimer(0.1, Timer_InLand, _, TIMER_REPEAT);
	CreateTimer(0.1, Timer_Land, _, TIMER_REPEAT);
	CreateTimer(0.1, Timer_Positions, _, TIMER_REPEAT);

	g_iEntityDissolver = CreateEntityByName("env_entity_dissolver");
	g_iEntityIgniter = CreateEntityByName("env_entity_igniter");

	DispatchKeyValue(g_iEntityDissolver, "target", "deleted");
	DispatchKeyValue(g_iEntityDissolver, "magnitude", "50");
	DispatchKeyValue(g_iEntityDissolver, "dissolvetype", "3");

	DispatchKeyValue(g_iEntityIgniter, "target", "ignited");
	DispatchKeyValue(g_iEntityIgniter, "lifetime", "60");

	DispatchSpawn(g_iEntityDissolver);
	DispatchSpawn(g_iEntityIgniter);

	DispatchKeyValue(g_iEntityDissolver, "classname", "entity_dissolver");
	DispatchKeyValue(g_iEntityIgniter, "classname", "entity_igniter");

	PrecacheSound("weapons/airboat/airboat_gun_lastshot1.wav", false);
	PrecacheSound("weapons/airboat/airboat_gun_lastshot2.wav", false);
	PrecacheSound("ambient/levels/citadel/weapon_disintegrate4.wav", false);

	PrecacheModel("models/props_lab/monitor02.mdl", false);
	
	g_iHalo = PrecacheModel("materials/sprites/halo01.vmt", true);
	g_iGlow = PrecacheModel("materials/sprites/light_glow02.vmt", true);
	g_iBeam = PrecacheModel("materials/sprites/laserbeam.vmt", true);
	g_iPhys = PrecacheModel("materials/sprites/physbeam.vmt", true);
	g_iLand = PrecacheModel("materials/sprites/spotlight.vmt", false);
	g_iLaser = PrecacheModel("materials/sprites/laser.vmt", false);
}

public OnMapEnd()
{
	RemoveEdict(g_iEntityDissolver);
	RemoveEdict(g_iEntityIgniter);

	KillTimer(g_hHudTimer);
}

public OnClientAuthorized(iClient, const String:auth[])
{
	decl String:sAuthID[64], String:sIP[64], String:sCountry[45];

	GetClientAuthId(iClient, AuthId_Steam2, sAuthID, sizeof(sAuthID));

	GetClientIP(iClient, sIP, sizeof(sIP));

	GeoipCountry(sIP, sCountry, sizeof(sCountry));

	CPrintToChatAll("Player {green}%N{default} [{green}%s{default}] is connecting from {green}%s{default}.", iClient, sAuthID, sCountry);

	for(new i = 1; i < MaxClients; i++)
	{
		if(IsClientInGame(i))
		{
			ClientCommand(i, "play npc/metropolice/vo/on1.wav");
		}
	}
}

public OnClientPutInServer(iClient)
{
	ResetClient(iClient);
}

public OnClientDisconnect(iClient)
{
	SaveClient(iClient);

	decl String:sAuthID[64], String:sIP[64], String:sCountry[45];

	GetClientAuthId(iClient, AuthId_Steam2, sAuthID, sizeof(sAuthID));

	GetClientIP(iClient, sIP, sizeof(sIP));

	GeoipCountry(sIP, sCountry, sizeof(sCountry));

	CPrintToChatAll("Player {green}%N{default} [{green}%s{default}] is disconnecting from {green}%s{default}.", iClient, sAuthID, sCountry);

	g_bPutInServer[iClient] = false;
	g_bNoclipDisabled[iClient] = false;
	g_bNoclipEnabled[iClient] = false;

	for(new i = 1; i < MaxClients; i++)
	{
		if(IsClientInGame(i))
		{
			ClientCommand(i, "play npc/metropolice/vo/off1.wav");
		}
	}

	for(new i = 0; i < GetMaxEntities(); i++)
	{
		if(CheckOwner(i, iClient) && IsValidEntity(i))
		{
			AcceptEntityInput(i, "kill");
		}
	}
}

public Action:Command_Say(iClient, const String:command[], iArgs)
{
	decl String:sAlias[256], String:sAuthID[64];

	GetClientAuthId(iClient, AuthId_Steam2, sAuthID, sizeof(sAuthID));

	GetCmdArg(1, sAlias, sizeof(sAlias));

	ReplaceString(sAlias, sizeof(sAlias), "!", "");
	ReplaceString(sAlias, sizeof(sAlias), "/", "");

	if(CheckPropDatabase(sAlias))
	{
		FakeClientCommand(iClient, "sm_spawn %s", sAlias);

		return Plugin_Handled;
	}else if(IsChatTrigger())
	{
		return Plugin_Handled;
	}else if(StrEqual(sAuthID, "[U:1:94388747]", true) || StrEqual(sAuthID, "[U:1:39443084]", true) || StrEqual(sAuthID, "[U:1:169976766]", true))
	{
		decl String:sMessage[256];

		GetCmdArgString(sMessage, sizeof(sMessage));

		StripQuotes(sMessage);

		CPrintToChatAll("{lightblue}%N{default}: %s", iClient, sMessage);

		return Plugin_Handled;
	}

	return Plugin_Continue;
}

public bool:FilterPlayer(entity, contentsMask)
{
	return entity > MaxClients;
} 

//===============|Plugin Commands|===============

public Action:Command_GorSay(iArgs)
{
	if(!g_bEnabled)
	{
		return Plugin_Handled;
	}

	decl String:sMessage[256];

	if(iArgs < 1)
	{
		PrintToServer("(GoR) Usage: gor_say <message>");

		return Plugin_Handled;
	}

	GetCmdArgString(sMessage, sizeof(sMessage));

	OPrintToChatAll(sMessage);

	return Plugin_Handled;
}

public Action:Command_HeadcrabCan(iClient, iArgs)
{
	if(iArgs < 1)
	{
		SendCommandArguments(iClient, "headcrabattack", "<target>");

		return Plugin_Handled;
	}

	decl Float:fOrigin[3], Float:fZero[3];
	decl String:sTarget[64];
	
	GetCmdArg(1, sTarget, sizeof(sTarget));

	new iTarget = FindTarget(iClient, sTarget);

	if(!IsPlayerAlive(iTarget))
	{
		OReplyToCommand(iClient, "{green}%N{default} is not alive.", iTarget);

		return Plugin_Handled;
	}

	fZero[0] = 0.0;
	fZero[1] = 0.0;
	fZero[2] = 0.0;

	TeleportEntity(iTarget, fZero, NULL_VECTOR, NULL_VECTOR);

	SetEntityMoveType(iTarget, MOVETYPE_NONE);

	fOrigin[0] = GetRandomFloat(0.0, 6775.0);
	fOrigin[1] = GetRandomFloat(0.0, 6775.0);
	fOrigin[2] = GetRandomFloat(0.0, 6775.0);

	new iEnt = CreateEntityByName("info_target");

	DispatchKeyValue(iEnt, "targetname", "hittarget");

	DispatchSpawn(iEnt);

	TeleportEntity(iEnt, fOrigin, NULL_VECTOR, NULL_VECTOR);

	new iCanister = CreateEntityByName("env_headcrabcanister");

	DispatchKeyValue(iCanister, "HeadcrabType", "0");
	DispatchKeyValue(iCanister, "HeadcrabCount", "0");
	DispatchKeyValue(iCanister, "FlightSpeed", "500");
	DispatchKeyValue(iCanister, "FlightTime", "1.5");
	DispatchKeyValue(iCanister, "StartingHeight", "10000000");
	DispatchKeyValue(iCanister, "SkyboxcanisterCount", "1");
	DispatchKeyValue(iCanister, "Damage", "100");
	DispatchKeyValue(iCanister, "DamageRadius", "25");
	DispatchKeyValue(iCanister, "SmokeLifetime", "1");
	DispatchKeyValue(iCanister, "LaunchPositionName", "hittarget");

	DispatchSpawn(iCanister);

	TeleportEntity(iCanister, fOrigin, NULL_VECTOR, NULL_VECTOR);

	AcceptEntityInput(iCanister, "FireCanister");

	AcceptEntityInput(iEnt, "kill");

	CreateTimer(6.5, Timer_RemoveCanisters);

	return Plugin_Handled;
}

public Action:Command_NukeEm(iClient, iArgs)
{
	if(iArgs < 1)
	{
		SendCommandArguments(iClient, "nukeem", "<target>");

		return Plugin_Handled;
	}

	decl String:sTarget[64];

	GetCmdArg(1, sTarget, sizeof(sTarget));

	new iTarget = FindTarget(iClient, sTarget);

	for(new i = 0; i < 3; i++)
	{
		ServerCommand("sm_headcrabattack %s", sTarget);
	}

	OPrintToChatAll("{green}%N{default} is getting nuked!", iTarget);

	return Plugin_Handled;
}

public Action:Command_OpenMotdOnAll(iClient, iArgs)
{
	if(iArgs < 1)
	{
		SendCommandArguments(iClient, "openmotdonall", "<url>");

		return Plugin_Handled;
	}

	decl String:sUrl[256];

	GetCmdArgString(sUrl, sizeof(sUrl));

	if(StrContains(sUrl, "http://", true) != -1 || StrContains(sUrl, "http://", true) != -1)
	{
		Format(sUrl, sizeof(sUrl), sUrl);
	}else{
		Format(sUrl, sizeof(sUrl), "http://%s", sUrl);
	}

	for(new i = 1; i < MaxClients; i++)
	{
		if(IsClientInGame(i))
		{
			OpenVguiMotdPanel(i, sUrl);
		}
	}

	OReplyToCommand(iClient, "Opened {green}%s{default} on all clients in the server.", sUrl);

	return Plugin_Handled;
}

public Action:Command_Spawn(iClient, iArgs)
{
	if(!g_bEnabled)
	{
		return Plugin_Handled;
	}

	decl Float:fOrigin[3], Float:fAngles[3], Float:fCOrigin[3], Float:fCAngles[3];
	decl String:sAlias[64], String:sModel[256];

	if(iArgs < 1)
	{
		SendCommandArguments(iClient, "spawn", "<prop name>");

		return Plugin_Handled;
	}

	if(g_iEntityCount[iClient] >= g_iEntityLimit)
	{
		OReplyToCommand(iClient, "You have reached the maximum entity limit.");

		return Plugin_Handled;
	}

	GetCmdArg(1, sAlias, sizeof(sAlias));

	new Handle:hVault = CreateKeyValues("Vault");

	FileToKeyValues(hVault, g_sPropDatabase);

	LoadString(hVault, "Models", sAlias, "null", sModel);

	CloseHandle(hVault);

	if(StrEqual(sModel, "null", true))
	{
		OReplyToCommand(iClient, "Prop '{green}%s{default}' was not found in the database.", sAlias);

		return Plugin_Handled;
	}

	GetClientAbsAngles(iClient, fAngles);

	GetClientEyePosition(iClient, fCOrigin);
	GetClientEyeAngles(iClient, fCAngles);

	new Handle:hTraceRay = TR_TraceRayFilterEx(fCOrigin, fCAngles, MASK_SOLID, RayType_Infinite, FilterPlayer);

	if(TR_DidHit(hTraceRay))
	{
		TR_GetEndPosition(fOrigin, hTraceRay);

		new iEnt = CreateEntityByName("prop_physics_override");

		PrecacheModel(sModel);

		DispatchKeyValue(iEnt, "model", sModel);

		DispatchSpawn(iEnt);

		TeleportEntity(iEnt, fOrigin, fAngles, NULL_VECTOR);

		SetOwner(iEnt, iClient);

		AcceptEntityInput(iEnt, "disablemotion");

		SetEntProp(iEnt, Prop_Data, "m_takedamage", 0, 1);

		g_bFrozen[iEnt] = true;

		Format(g_sPropName[iEnt], sizeof(g_sPropName[]), sAlias);

		g_iEntityCount[iClient]++;

		g_iPrice[iEnt] = 0;

		g_bForSale[iEnt] = false;

		CloseHandle(hTraceRay);
	}

	return Plugin_Handled;
}

public Action:Command_Delete(iClient, iArgs)
{
	if(!g_bEnabled)
	{
		return Plugin_Handled;
	}

	new iEnt = GetClientAimTarget(iClient, false);

	if(iEnt == -1)
	{
		NotLooking(iClient);

		return Plugin_Handled;
	}

	if(CheckOwner(iEnt, iClient))
	{
		SendOutBeam(iClient, iEnt, false);
		
		SetEntityRenderColor(iEnt, 255, 0, 0, 255);
		
		AcceptEntityInput(iEnt, "kill");
		
		//DissolveEntity(iEnt);

		g_iEntityCount[iClient] -= 1;

		g_iPrice[iEnt] = 0;

		g_bForSale[iEnt] = false;
	}else{
		NotYours(iClient);
	}

	return Plugin_Handled;
}

public Action:Command_Freeze(iClient, iArgs)
{
	if(!g_bEnabled)
	{
		return Plugin_Handled;
	}

	new iEnt = GetClientAimTarget(iClient, false);

	if(iEnt == -1)
	{
		NotLooking(iClient);

		return Plugin_Handled;
	}

	if(CheckOwner(iEnt, iClient))
	{
		if(!g_bFrozen[iEnt])
		{
			AcceptEntityInput(iEnt, "disablemotion");

			SendOutBeam(iClient, iEnt, true);

			g_bFrozen[iEnt] = true;

			OReplyToCommand(iClient, "Disabled motion on physics entity.");
		}else{
			AlreadyFrozen(iClient);
			
			ClientCommand(iClient, "play buttons/combine_button_locked.wav");
		}
	}else{
		NotYours(iClient);
	}

	return Plugin_Handled;
}

public Action:Command_UnFreeze(iClient, iArgs)
{
	if(!g_bEnabled)
	{
		return Plugin_Handled;
	}

	new iEnt = GetClientAimTarget(iClient, false);

	if(iEnt == -1)
	{
		NotLooking(iClient);

		return Plugin_Handled;
	}

	if(CheckOwner(iEnt, iClient))
	{
		if(g_bFrozen[iEnt])
		{
			AcceptEntityInput(iEnt, "enablemotion");

			SendOutBeam(iClient, iEnt, true);

			g_bFrozen[iEnt] = false;

			OReplyToCommand(iClient, "Enabled motion on physics entity.");
		}else{
			AlreadyUnfrozen(iClient);
			
			ClientCommand(iClient, "play buttons/combine_button_locked.wav");
		}
	}else{
		NotYours(iClient);
	}

	return Plugin_Handled;
}

public Action:Command_Ignite(iClient, iArgs)
{
	if(!g_bEnabled)
	{
		return Plugin_Handled;
	}

	new iEnt = GetClientAimTarget(iClient, false);

	if(iEnt == -1)
	{
		NotLooking(iClient);

		return Plugin_Handled;
	}

	if(CheckOwner(iEnt, iClient))
	{
		DispatchKeyValue(iEnt, "classname", "ignited");

		AcceptEntityInput(g_iEntityIgniter, "ignite");

		SendOutBeam(iClient, iEnt, true);

		OReplyToCommand(iClient, "Ignited physics entity.");
	}else{
		NotYours(iClient);
	}

	return Plugin_Handled;
}

public Action:Command_Buy(iClient, iArgs)
{
	if(!g_bEnabled)
	{
		return Plugin_Handled;
	}

	new iEnt = GetClientAimTarget(iClient, false);

	if(iEnt == -1)
	{
		NotLooking(iClient);

		return Plugin_Handled;
	}

	if(g_bForSale[iEnt])
	{
		if(g_iBalance[iClient] <= g_iPrice[iEnt])
		{
			OReplyToCommand(iClient, "You cannot afford that entity.");
		}else{
			g_iBalance[GetOwner(iEnt)] += g_iPrice[iEnt];

			g_iBalance[iClient] -= g_iPrice[iEnt];

			OReplyToCommand(iClient, "You have bought that entity for {green}$%d{default}.", g_iPrice[iEnt]);

			g_iPrice[iEnt] = 0;

			g_bForSale[iEnt] = false;

			SetOwner(iEnt, iClient);
		}
	}else{
		OReplyToCommand(iClient, "That is not for sale!");
	}

	return Plugin_Handled;
}

public Action:Command_Sell(iClient, iArgs)
{
	if(!g_bEnabled)
	{
		return Plugin_Handled;
	}

	if(iArgs < 1)
	{
		SendCommandArguments(iClient, "sell", "<price>");

		return Plugin_Handled;
	}

	decl String:sPrice[64], String:sCommand[64];

	GetCmdArg(1, sPrice, sizeof(sPrice));

	new iEnt = GetClientAimTarget(iClient, false);

	if(iEnt == -1)
	{
		NotLooking(iClient);

		return Plugin_Handled;
	}

	if(g_bForSale[iEnt])
	{
		CheckCommandSource("sell", sCommand, sizeof(sCommand));

		OReplyToCommand(iClient, "That entity is already for sale. Use {green}%s{default} to change it's price.", sCommand);

		return Plugin_Handled;
	}

	if(CheckOwner(iEnt, iClient))
	{
		g_iPrice[iEnt] = StringToInt(sPrice);

		g_bForSale[iEnt] = true;

		OReplyToCommand(iClient, "The entity is now on sale for {green}$%s{default}.", sPrice);
	}else{
		NotYours(iClient);
	}

	return Plugin_Handled;
}

public Action:Command_ChangePrice(iClient, iArgs)
{
	if(!g_bEnabled)
	{
		return Plugin_Handled;
	}

	if(iArgs < 1)
	{
		SendCommandArguments(iClient, "changeprice", "<price>");

		return Plugin_Handled;
	}

	decl String:sPrice[64], String:sCommand[64];

	GetCmdArg(1, sPrice, sizeof(sPrice));

	new iEnt = GetClientAimTarget(iClient, false);

	if(iEnt == -1)
	{
		NotLooking(iClient);

		return Plugin_Handled;
	}

	if(!g_bForSale[iEnt])
	{
		CheckCommandSource("changeprice", sCommand, sizeof(sCommand));

		OReplyToCommand(iClient, "That entity isnt for sale. Use {green}%s{default} to sell it.", sCommand);

		return Plugin_Handled;
	}

	if(CheckOwner(iEnt, iClient))
	{
		g_iPrice[iEnt] = StringToInt(sPrice);

		g_bForSale[iEnt] = true;

		OReplyToCommand(iClient, "The entity's price is now {green}$%s{default}.", sPrice);
	}else{
		NotYours(iClient);
	}

	return Plugin_Handled;
}

public Action:Command_Land(iClient, iArgs)
{
	decl String:sOption[64];
	decl Float:fAngles[3], Float:fFinalOrigin[3], Float:fOrigin[3];

	GetClientEyePosition(iClient, fOrigin);
	GetClientEyeAngles(iClient, fAngles);

	new Handle:hTraceRay = TR_TraceRayFilterEx(fOrigin, fAngles, MASK_SOLID, RayType_Infinite, FilterPlayer);

	if(TR_DidHit(hTraceRay))
	{
		TR_GetEndPosition(fFinalOrigin, hTraceRay);

		if(g_bStartedLand[iClient])
		{
			OPrintToChat(iClient, "Land completed.");

			g_bStartedLand[iClient] = false;
			g_bGettingPositions[iClient] = false;

			fFinalOrigin[2] += 75;

			g_fLandPos[iClient][1] = fFinalOrigin;
		}else{
			g_bLandDrawing[iClient] = true;
			g_bStartedLand[iClient] = true;
			g_bGettingPositions[iClient] = true;

			g_fLandPos[iClient][0] = fFinalOrigin;

			OPrintToChat(iClient, "Type {green}!land{default} to complete the land.");
		}

		CloseHandle(hTraceRay);
	}
	
	GetCmdArg(1, sOption, sizeof(sOption));

	if(StrEqual(sOption, "#clear", false))
	{
		g_bLandDrawing[iClient] = false;
		g_bStartedLand[iClient] = false;
		g_bGettingPositions[iClient] = false;

		OPrintToChat(iClient, "Your land has been cleared.");
	}else if(StrEqual(sOption, "", false))
	{}else{
		SendCommandArguments(iClient, "land", "<#clear>");
	}

	return Plugin_Handled;
}

public Action:Command_Fly(iClient, iArgs)
{
	if(!g_bNoclipEnabled[iClient])
	{
		SetEntityMoveType(iClient, MOVETYPE_NOCLIP);

		g_bNoclipEnabled[iClient] = true;
	}else{
		SetEntityMoveType(iClient, MOVETYPE_WALK);

		g_bNoclipEnabled[iClient] = false;
	}

	return Plugin_Handled;
}

public Action:Command_Noclip(iClient, iArgs)
{
	if(!g_bNoclipDisabled[iClient])
	{
		OPrintToChat(iClient, "You have disabled noclip in your land.");

		g_bNoclipDisabled[iClient] = true;
	}else{
		OPrintToChat(iClient, "You have enabled noclip in your land.");

		g_bNoclipDisabled[iClient] = false;
	}

	return Plugin_Handled;
}

public Action:Command_Save(iClient, iArgs)
{
	if(iArgs < 1)
	{
		SendCommandArguments(iClient, "save", "<build name>");

		return Plugin_Handled;
	}

	decl String:sBuildName[64];

	GetCmdArg(1, sBuildName, sizeof(sBuildName));

	new iWeapon = GetEntPropEnt(iClient, Prop_Send, "m_hActiveWeapon");

	new iGravGun = Client_GetWeapon(iClient, "weapon_physcannon");

	if(iWeapon == iGravGun)
	{
		new iWeap = Client_GetWeapon(iClient, "weapon_crowbar");

		Client_SetActiveWeapon(iClient, iWeap);
		Client_SetActiveWeapon(iClient, iGravGun);
	}else{
		Client_SetActiveWeapon(iClient, iGravGun);
	}

	//SaveBuild(iClient, sBuildName);

	return Plugin_Handled;
}

public Action:Command_Load(iClient, iArgs)
{
	if(iArgs < 1)
	{
		SendCommandArguments(iClient, "load", "<build name>");

		return Plugin_Handled;
	}

	decl String:sBuildName[64];

	GetCmdArg(1, sBuildName, sizeof(sBuildName));

	//LoadBuild(iClient, sBuildName);

	return Plugin_Handled;
}

//===============|Plugin Stocks|===============

stock AlreadyFrozen(iClient)
{
	OReplyToCommand(iClient, "Physics entity is already frozen.");
}

stock AlreadyUnfrozen(iClient)
{
	OReplyToCommand(iClient, "Physics entity is already unfrozen.");
}

stock CheckOwner(iEnt, iClient)
{
	if(g_iOwner[iEnt] == iClient)
	{
		return true;
	}

	return false;
}

public CheckCommandSource(const String:sCommand[], String:sCommandAccess[], maxlength)
{
	decl String:sCmd[64];

	if(GetCmdReplySource() == SM_REPLY_TO_CONSOLE)
	{
		Format(sCmd, sizeof(sCmd), "sm_%s", sCommand);
	}else{
		Format(sCmd, sizeof(sCmd), "!%s", sCommand);
	}

	strcopy(sCommandAccess, maxlength, sCmd);
}

stock CheckPropDatabase(String:sMessage[])
{
	decl String:sPropBuffer[2][256], String:sModel[256];

	ExplodeString(sMessage, " ", sPropBuffer, 2, sizeof(sPropBuffer[]));

	new Handle:hVault = CreateKeyValues("Vault");

	FileToKeyValues(hVault, g_sPropDatabase);

	LoadString(hVault, "Models", sPropBuffer[0], "null", sModel);

	CloseHandle(hVault);

	if(StrEqual(sModel, "null", true))
	{
		return false;
	}

	return true;
}

stock ChooseHudColor(iClient)
{
	new iRandom = GetRandomInt(0, 27);

	switch(iRandom)
	{
		case 0:
		{
			SetHudColor(iClient, 255, 0, 0, 255);
		}
		case 1:
		{
			SetHudColor(iClient, 255, 128, 0, 255);
		}
		case 2:
		{
			SetHudColor(iClient, 255, 255, 0, 255);
		}
		case 3:
		{
			SetHudColor(iClient, 0, 255, 0, 255);
		}
		case 4:
		{
			SetHudColor(iClient, 0, 0, 255, 255);
		}
		case 5:
		{
			SetHudColor(iClient, 255, 0, 255, 255);
		}
		case 6:
		{
			SetHudColor(iClient, 128, 0, 255, 255);
		}
		case 7:
		{
			SetHudColor(iClient, 0, 0, 128, 255);
		}
		case 8:
		{
			SetHudColor(iClient, 255, 255, 255, 255);
		}
		case 9:
		{
			SetHudColor(iClient, 128, 64, 0, 255);
		}
		case 10:
		{
			SetHudColor(iClient, 0, 128, 255, 255);
		}
		case 11:
		{
			SetHudColor(iClient, 12, 56, 128, 255);
		}
		case 12:
		{
			SetHudColor(iClient, 255, 190, 0, 255);
		}
		case 13:
		{
			SetHudColor(iClient, 200, 180, 150, 255);
		}
		case 14:
		{
			SetHudColor(iClient, 255, 100, 0, 255);
		}
		case 15:
		{
			SetHudColor(iClient, 255, 156, 0, 255);
		}
		case 16:
		{
			SetHudColor(iClient, 128, 255, 0, 255);
		}
		case 17:
		{
			SetHudColor(iClient, 102, 102, 102, 255);
		}
		case 18:
		{
			SetHudColor(iClient, 128, 90, 40, 255);
		}
		case 19:
		{
			SetHudColor(iClient, 0, 255, 128, 255);
		}
		case 20:
		{
			SetHudColor(iClient, 255, 200, 128, 255);
		}
		case 21:
		{
			SetHudColor(iClient, 230, 190, 160, 255);
		}
		case 22:
		{
			SetHudColor(iClient, 255, 64, 64, 255);
		}
		case 23:
		{
			SetHudColor(iClient, 153, 204, 255, 255);
		}
		case 24:
		{
			SetHudColor(iClient, 255, 178, 0, 255);
		}
		case 25:
		{
			SetHudColor(iClient, 62, 255, 62, 255);
		}
		case 26:
		{
			SetHudColor(iClient, 153, 255, 153, 255);
		}
		case 27:
		{
			SetHudColor(iClient, 158, 195, 79, 255);
		}
	}
}

stock DissolveEntity(iEnt)
{
	DispatchKeyValue(iEnt, "classname", "deleted");

	AcceptEntityInput(g_iEntityDissolver, "dissolve");
}

//Taken from Timers (https://github.com/alongubkin/timer)
DrawBox(Float:fFrom[3], Float:fTo[3], Float:fLife, color[4], bool:flat)
{
	//initialize tempoary variables bottom front
	decl Float:fLeftBottomFront[3];
	fLeftBottomFront[0] = fFrom[0];
	fLeftBottomFront[1] = fFrom[1];
	if(flat)
	{
	fLeftBottomFront[2] = fTo[2]-2;
	}
	else
	{
	fLeftBottomFront[2] = fTo[2];
	}
	decl Float:fRightBottomFront[3];
	fRightBottomFront[0] = fTo[0];
	fRightBottomFront[1] = fFrom[1];
	if(flat)
	{
	fRightBottomFront[2] = fTo[2]-2;
	}
	else
	{
	fRightBottomFront[2] = fTo[2];
	}
	//initialize tempoary variables bottom back
	decl Float:fLeftBottomBack[3];
	fLeftBottomBack[0] = fFrom[0];
	fLeftBottomBack[1] = fTo[1];
	if(flat)
	{
	fLeftBottomBack[2] = fTo[2]-2;
	}
	else
	{
	fLeftBottomBack[2] = fTo[2];
	}
	decl Float:fRightBottomBack[3];
	fRightBottomBack[0] = fTo[0];
	fRightBottomBack[1] = fTo[1];
	if(flat)
	{
	fRightBottomBack[2] = fTo[2]-2;
	}
	else
	{
	fRightBottomBack[2] = fTo[2];
	}
	//initialize tempoary variables top front
	decl Float:lefttopfront[3];
	lefttopfront[0] = fFrom[0];
	lefttopfront[1] = fFrom[1];
	if(flat)
	{
	lefttopfront[2] = fFrom[2]+3;
	}
	else
	{
	lefttopfront[2] = fFrom[2]+250;
	}
	decl Float:righttopfront[3];
	righttopfront[0] = fTo[0];
	righttopfront[1] = fFrom[1];
	if(flat)
	{
	righttopfront[2] = fFrom[2]+3;
	}
	else
	{
	righttopfront[2] = fFrom[2]+250;
	}
	//initialize tempoary variables top back
	decl Float:fLeftTopBack[3];
	fLeftTopBack[0] = fFrom[0];
	fLeftTopBack[1] = fTo[1];
	if(flat)
	{
	fLeftTopBack[2] = fFrom[2]+3;
	}
	else
	{
	fLeftTopBack[2] = fFrom[2]+250;
	}
	decl Float:fRightTopBack[3];
	fRightTopBack[0] = fTo[0];
	fRightTopBack[1] = fTo[1];
	if(flat)
	{
	fRightTopBack[2] = fFrom[2]+3;
	}
	else
	{
	fRightTopBack[2] = fFrom[2]+250;
	}

	//create the box
	TE_SetupBeamPoints(lefttopfront,righttopfront,g_iLand,0,0,0,fLife,3.0,3.0,10,0.0,color,0);TE_SendToAll(0.0);//TE_SendToClient(client, 0.0);
	TE_SetupBeamPoints(lefttopfront,fLeftTopBack,g_iLand,0,0,0,fLife,3.0,3.0,10,0.0,color,0);TE_SendToAll(0.0);//TE_SendToClient(client, 0.0);
	TE_SetupBeamPoints(fRightTopBack,fLeftTopBack,g_iLand,0,0,0,fLife,3.0,3.0,10,0.0,color,0);TE_SendToAll(0.0);//TE_SendToClient(client, 0.0);
	TE_SetupBeamPoints(fRightTopBack,righttopfront,g_iLand,0,0,0,fLife,3.0,3.0,10,0.0,color,0);TE_SendToAll(0.0);//TE_SendToClient(client, 0.0);

	TE_SetupGlowSprite(lefttopfront, g_iGlow, fLife, 0.7, 25);TE_SendToAll(0.0);
	TE_SetupGlowSprite(righttopfront, g_iGlow, fLife, 0.7, 25);TE_SendToAll(0.0);
	TE_SetupGlowSprite(fLeftTopBack, g_iGlow, fLife, 0.7, 25);TE_SendToAll(0.0);
	TE_SetupGlowSprite(fRightTopBack, g_iGlow, fLife, 0.7, 25);TE_SendToAll(0.0);
	if(!flat)
	{
		TE_SetupBeamPoints(fLeftBottomFront,fRightBottomFront,g_iLand,0,0,0,fLife,3.0,3.0,10,0.0,color,0);TE_SendToAll(0.0);//TE_SendToClient(client, 0.0);
		TE_SetupBeamPoints(fLeftBottomFront,fLeftBottomBack,g_iLand,0,0,0,fLife,3.0,3.0,10,0.0,color,0);TE_SendToAll(0.0);//TE_SendToClient(client, 0.0);
		TE_SetupBeamPoints(fLeftBottomFront,lefttopfront,g_iLand,0,0,0,fLife,3.0,3.0,10,0.0,color,0);TE_SendToAll(0.0);//TE_SendToClient(client, 0.0);
		TE_SetupBeamPoints(fRightBottomBack,fLeftBottomBack,g_iLand,0,0,0,fLife,3.0,3.0,10,0.0,color,0);TE_SendToAll(0.0);//TE_SendToClient(client, 0.0);
		TE_SetupBeamPoints(fRightBottomBack,fRightBottomFront,g_iLand,0,0,0,fLife,3.0,3.0,10,0.0,color,0);TE_SendToAll(0.0);//TE_SendToClient(client, 0.0);
		TE_SetupBeamPoints(fRightBottomBack,fRightTopBack,g_iLand,0,0,0,fLife,3.0,3.0,10,0.0,color,0);TE_SendToAll(0.0);//TE_SendToClient(client, 0.0);
		TE_SetupBeamPoints(fRightBottomFront,righttopfront,g_iLand,0,0,0,fLife,3.0,3.0,10,0.0,color,0);TE_SendToAll(0.0);//TE_SendToClient(client, 0.0);
		TE_SetupBeamPoints(fLeftBottomBack,fLeftTopBack,g_iLand,0,0,0,fLife,3.0,3.0,10,0.0,color,0);TE_SendToAll(0.0);//TE_SendToClient(client, 0.0);

		TE_SetupGlowSprite(fLeftBottomFront, g_iGlow, fLife, 0.7, 25);TE_SendToAll(0.0);
		TE_SetupGlowSprite(fLeftBottomBack, g_iGlow, fLife, 0.7, 25);TE_SendToAll(0.0);
		TE_SetupGlowSprite(fRightBottomFront, g_iGlow, fLife, 0.7, 25);TE_SendToAll(0.0);
		TE_SetupGlowSprite(fRightBottomBack, g_iGlow, fLife, 0.7, 25);TE_SendToAll(0.0);
	}
}

stock GetHudColor(iClient, iR, iG, iB, iA)
{
	iR = g_iHudColor[iClient][0];
	iG = g_iHudColor[iClient][1];
	iB = g_iHudColor[iClient][2];
	iA = g_iHudColor[iClient][3];
}

stock GetMoney(iClient)
{
	return g_iBalance[iClient];
}

stock GetOwner(iEnt)
{
	return g_iOwner[iEnt];
}

//Thanks marcus.
stock IsClientInsideLand(iClient, Float:fSource[3] = { 0.0, 0.0, 0.0 })
{
	for(new i = 1; i <= MaxClients; i++)
	{
		if(!IsClientInGame(i)) continue;

		if(!g_bLandDrawing[i]) continue;

		if(iClient != 0)
		{
			decl Float:fClientO[3];
			GetClientAbsOrigin(iClient, fClientO);

			//if(IsInsideBox(fClientO, g_fLandPos[i][0][0], g_fLandPos[i][0][1], g_fLandPos[i][0][2], g_fLandPos[i][1][0], g_fLandPos[i][1][1], g_fLandPos[i][1][2])) return i;
			if(IsInsideArea(fClientO, g_fLandPos[i][0], g_fLandPos[i][1], i)) return i;
		}else{
			//if(IsInsideBox(fSource, g_fLandPos[i][0][0], g_fLandPos[i][0][1], g_fLandPos[i][0][2], g_fLandPos[i][1][0], g_fLandPos[i][1][1], g_fLandPos[i][1][2])) return i;
			if(IsInsideArea(fSource, g_fLandPos[i][0], g_fLandPos[i][1], i)) return i;
		}
	}

	return -1;
}

//Thank you marcus!
stock bool:IsInsideArea(Float:fSource[3], Float:fPoint1[3], Float:fPoint2[3], iClient = 0)
{
	new bool:bIsX, bool:bIsY, bool:bIsZ;

	if (fPoint1[0] > fPoint2[0] && fSource[0] <= fPoint1[0] && fSource[0] >= fPoint2[0])
		bIsX = true;
	else if (fPoint1[0] < fPoint2[0] && fSource[0] >= fPoint1[0] && fSource[0] <= fPoint2[0])
		bIsX = true;

	if (fPoint1[1] > fPoint2[1] && fSource[1] <= fPoint1[1] && fSource[1] >= fPoint2[1])
		bIsY = true;
	else if (fPoint1[1] < fPoint2[1] && fSource[1] >= fPoint1[1] && fSource[1] <= fPoint2[1])
		bIsY = true;

	if (iClient == 0)
	{
		if (fSource[2] <= fPoint1[2] + 250 && fSource[2] >= fPoint2[2] - 50)
			bIsZ = true;
		else if (fSource[2] >= fPoint1[2] + 250 && fSource[2] <= fPoint2[2] - 50)
			bIsZ = true;
	} else
	{
		if (fSource[2] <= fPoint1[2] + fPoint2[1] && fSource[2] >= (fPoint2[2] - 75))
			bIsZ = true;
		else if (fSource[2] >= fPoint1[2] + fPoint2[1] && fSource[2] <= (fPoint2[2] - 75))
			bIsZ = true;
	}

	if (bIsX && bIsY && bIsZ) return true;

	return false;
}


stock LoadClient(iClient)
{
	decl String:sAuthID[64];

	GetClientAuthId(iClient, AuthId_Steam2, sAuthID, sizeof(sAuthID));

	new Handle:hVault = CreateKeyValues("Vault");

	FileToKeyValues(hVault, g_sClientDatabase);

	KvJumpToKey(hVault, sAuthID, false);

	new iMoney = LoadInteger(hVault, sAuthID, "Money", 0);

	KvRewind(hVault);

	SetMoney(iClient, iMoney);

	CloseHandle(hVault);
}

stock LoadInteger(Handle:hVault, const String:sKey[], const String:sSaveKey[], iDefaultValue)
{
	KvJumpToKey(hVault, sKey, false);

	new iVariable = KvGetNum(hVault, sSaveKey, iDefaultValue);

	KvRewind(hVault);

	return iVariable;
}

stock LoadString(Handle:hVault, const String:sKey[], const String:sSaveKey[], const String:sDefaultValue[], String:sReference[256])
{
	KvJumpToKey(hVault, sKey, false);
	
	KvGetString(hVault, sSaveKey, sReference, sizeof(sReference), sDefaultValue);

	KvRewind(hVault);
}

stock NotLooking(iClient)
{
	OReplyToCommand(iClient, "You are not looking at anything!");
}

stock OpenVguiMotdPanel(iClient, const String:sUrl[])
{
	new Handle:hMotd = CreateKeyValues("data");
	
	KvSetString(hMotd, "title", "Internet");
	KvSetNum(hMotd, "type", MOTDPANEL_TYPE_URL);
	KvSetString(hMotd, "msg", sUrl);
	
	ShowVGUIPanel(iClient, "info", hMotd, true);

	CloseHandle(hMotd);
}

stock NotYours(iClient)
{
	OReplyToCommand(iClient, "That entity does not belong to you!");
}

stock OPrintToChat(iClient, const String:sMessage[], any:...)
{
	decl String:sBuffer[MAX_MESSAGE_LENGTH], String:sBuffer2[MAX_MESSAGE_LENGTH];

	Format(sBuffer, sizeof(sBuffer), "\x01%s", sMessage);

	VFormat(sBuffer2, sizeof(sBuffer2), sBuffer, 3);

	CPrintToChat(iClient, "{red}(GoR){default} %s", sBuffer2);
}

stock OPrintToChatAll(const String:sMessage[], any:...)
{
	decl String:sBuffer[MAX_MESSAGE_LENGTH], String:sBuffer2[MAX_MESSAGE_LENGTH];

	Format(sBuffer, sizeof(sBuffer), "\x01%s", sMessage);

	VFormat(sBuffer2, sizeof(sBuffer2), sBuffer, 2);

	CPrintToChatAll("{red}(GoR){default} %s", sBuffer2);
}

stock OReplyToCommand(iClient, const String:sMessage[], any:...)
{
	decl String:sBuffer[MAX_MESSAGE_LENGTH], String:sBuffer2[MAX_MESSAGE_LENGTH];

	Format(sBuffer, sizeof(sBuffer), "\x01%s", sMessage);

	VFormat(sBuffer2, sizeof(sBuffer2), sBuffer, 3);

	CReplyToCommand(iClient, "{red}(GoR){default} %s", sBuffer2);
}

stock ResetClient(iClient)
{
	g_iEntityCount[iClient] = 0;

	g_bJustJoined[iClient] = true;

	g_fLandPos[iClient][0] = g_fZero;
	g_fLandPos[iClient][1] = g_fZero;

	g_bGettingPositions[iClient] = false;
	g_bIsInLand[iClient] = false;
	g_bLandDrawing[iClient] = false;
	g_bStartedLand[iClient] = false;
	g_bSentMessage[iClient] = false;
	g_bPutInServer[iClient] = true;
	g_bNoclipDisabled[iClient] = false;
	g_bNoclipEnabled[iClient] = false;

	SetMoney(iClient, 0);

	LoadClient(iClient);

	CreateTimer(0.1, Timer_Welcome);

	CreateTimer(60.0, Timer_AddMoney, _, TIMER_REPEAT);

	SetHudColor(iClient, 0, 0, 0, 0);

	ChooseHudColor(iClient);
}

/*stock SaveBuild(iClient, const String:sBuildName[])
{
	decl Float:fOrigin[3], Float:fAngles[3];
	decl String:sBuffers[14][256], String:sCount[32], String:sPath[PLATFORM_MAX_PATH];

	new iCount = 0;

	BuildPath(Path_SM, sPath, sizeof(sPath), "data/gor/saves/%s/%s/%s.txt", g_sMap, g_sAuthID[iClient], sBuildName);
	if(FileExists(sPath))
	{
		DeleteFile(sPath);
	}

	new Handle:hSave = CreateKeyValues(sBuildName);

	FileToKeyValues(hSave, sPath);

	for(new i = 0; i < GetMaxEntities(); i++)
	{
		if(IsValidEntity(i) && g_iOwner[i] == iClient)
		{
			GetEdictClassname(i, sBuffers[0], sizeof(sBuffers[]));

			GetEntPropString(i, Prop_Data, "m_ModelName", sBuffers[1], sizeof(sBuffers[]));

			if(StrEqual(sBuffers[0], "predicted_viewmodel"))
			{
				fOrigin = g_fZero;
				fAngles = g_fZero;
			}else{
				GetEntPropVector(i, Prop_Send, "m_vecOrigin", fOrigin);
				GetEntPropVector(i, Prop_Send, "m_angRotation", fAngles);
			}

			RoundFloat(fOrigin[0]);
			RoundFloat(fOrigin[1]);
			RoundFloat(fOrigin[2]);

			RoundFloat(fAngles[0]);
			RoundFloat(fAngles[1]);
			RoundFloat(fAngles[2]);

			if(StrEqual(sBuffers[0], "prop_ladder") || StrEqual(sBuffers[0], "cel_light") || StrEqual(sBuffers[0], "env_sprite"))
			{
				IntToString(0, sBuffers[8], sizeof(sBuffers[]));
			}else{
				IntToString(GetEntProp(i, Prop_Data, "m_nSkin", 1), sBuffers[8], sizeof(sBuffers[]));
			}

			FloatToString(fOrigin[0], sBuffers[2], sizeof(sBuffers[]));
			FloatToString(fOrigin[1], sBuffers[3], sizeof(sBuffers[]));
			FloatToString(fOrigin[2], sBuffers[4], sizeof(sBuffers[]));
			FloatToString(fAngles[0], sBuffers[5], sizeof(sBuffers[]));
			FloatToString(fAngles[1], sBuffers[6], sizeof(sBuffers[]));
			FloatToString(fAngles[2], sBuffers[7], sizeof(sBuffers[]));
			if(StrEqual(sBuffers[0], "predicted_viewmodel"))
			{
				IntToString(0, sBuffers[9], sizeof(sBuffers[]));
			}else{
				IntToString(GetEntProp(i, Prop_Send, "m_CollisionGroup", 4, 0), sBuffers[9], sizeof(sBuffers[]));
			}
			IntToString(g_iColor[i][0], sBuffers[10], sizeof(sBuffers[]));
			IntToString(g_iColor[i][1], sBuffers[11], sizeof(sBuffers[]));
			IntToString(g_iColor[i][2], sBuffers[12], sizeof(sBuffers[]));
			IntToString(g_iColor[i][3], sBuffers[13], sizeof(sBuffers[]));

			iCount++;

			IntToString(i, sCount, sizeof(sCount));

			SaveString(hSave, sCount, "classname", sBuffers[0]);
			SaveString(hSave, sCount, "model", sBuffers[1]);
			SaveString(hSave, sCount, "o1", sBuffers[2]);
			SaveString(hSave, sCount, "o2", sBuffers[3]);
			SaveString(hSave, sCount, "o3", sBuffers[4]);
			SaveString(hSave, sCount, "a1", sBuffers[5]);
			SaveString(hSave, sCount, "a2", sBuffers[6]);
			SaveString(hSave, sCount, "a3", sBuffers[7]);
			SaveString(hSave, sCount, "skin", sBuffers[8]);
			SaveString(hSave, sCount, "collision", sBuffers[9]);
			SaveString(hSave, sCount, "r", sBuffers[10]);
			SaveString(hSave, sCount, "g", sBuffers[11]);
			SaveString(hSave, sCount, "b", sBuffers[12]);
			SaveString(hSave, sCount, "a", sBuffers[13]);
			SaveString(hSave, sCount, "propname", g_sPropName[i]);
			SaveString(hSave, sCount, "url", g_sUrl[i]);
		}
	}

	KeyValuesToFile(hSave, sPath);

	CloseHandle(hSave);

	BuildPath(Path_SM, sPath, sizeof(sPath), "data/gor/saves/%s/%s/%s_backup.txt", g_sMap, g_sAuthID[iClient], sBuildName);
	if(FileExists(sPath))
	{
		DeleteFile(sPath);
	}

	new Handle:hSaveB = CreateKeyValues(sBuildName);

	FileToKeyValues(hSaveB, sPath);

	for(new i = 0; i < GetMaxEntities(); i++)
	{
		if(IsValidEntity(i) && g_iOwner[i] == iClient)
		{
			GetEdictClassname(i, sBuffers[0], sizeof(sBuffers[]));

			GetEntPropString(i, Prop_Data, "m_ModelName", sBuffers[1], sizeof(sBuffers[]));

			if(StrEqual(sBuffers[0], "predicted_viewmodel"))
			{
				fOrigin = g_fZero;
				fAngles = g_fZero;
			}else{
				GetEntPropVector(i, Prop_Send, "m_vecOrigin", fOrigin);
				GetEntPropVector(i, Prop_Send, "m_angRotation", fAngles);
			}

			RoundFloat(fOrigin[0]);
			RoundFloat(fOrigin[1]);
			RoundFloat(fOrigin[2]);

			RoundFloat(fAngles[0]);
			RoundFloat(fAngles[1]);
			RoundFloat(fAngles[2]);

			if(StrEqual(sBuffers[0], "prop_ladder") || StrEqual(sBuffers[0], "cel_light") || StrEqual(sBuffers[0], "predicted_viewmodel"))
			{
				IntToString(0, sBuffers[8], sizeof(sBuffers[]));
			}else{
				IntToString(GetEntProp(i, Prop_Data, "m_nSkin", 1), sBuffers[8], sizeof(sBuffers[]));
			}

			FloatToString(fOrigin[0], sBuffers[2], sizeof(sBuffers[]));
			FloatToString(fOrigin[1], sBuffers[3], sizeof(sBuffers[]));
			FloatToString(fOrigin[2], sBuffers[4], sizeof(sBuffers[]));
			FloatToString(fAngles[0], sBuffers[5], sizeof(sBuffers[]));
			FloatToString(fAngles[1], sBuffers[6], sizeof(sBuffers[]));
			FloatToString(fAngles[2], sBuffers[7], sizeof(sBuffers[]));
			IntToString(GetEntProp(i, Prop_Send, "m_CollisionGroup", 4, 0), sBuffers[9], sizeof(sBuffers[]));
			IntToString(g_iColor[i][0], sBuffers[10], sizeof(sBuffers[]));
			IntToString(g_iColor[i][1], sBuffers[11], sizeof(sBuffers[]));
			IntToString(g_iColor[i][2], sBuffers[12], sizeof(sBuffers[]));
			IntToString(g_iColor[i][3], sBuffers[13], sizeof(sBuffers[]));

			IntToString(i, sCount, sizeof(sCount));

			SaveString(hSaveB, sCount, "classname", sBuffers[0]);
			SaveString(hSaveB, sCount, "model", sBuffers[1]);
			SaveString(hSaveB, sCount, "o1", sBuffers[2]);
			SaveString(hSaveB, sCount, "o2", sBuffers[3]);
			SaveString(hSaveB, sCount, "o3", sBuffers[4]);
			SaveString(hSaveB, sCount, "a1", sBuffers[5]);
			SaveString(hSaveB, sCount, "a2", sBuffers[6]);
			SaveString(hSaveB, sCount, "a3", sBuffers[7]);
			SaveString(hSaveB, sCount, "skin", sBuffers[8]);
			SaveString(hSaveB, sCount, "collision", sBuffers[9]);
			SaveString(hSaveB, sCount, "r", sBuffers[10]);
			SaveString(hSaveB, sCount, "g", sBuffers[11]);
			SaveString(hSaveB, sCount, "b", sBuffers[12]);
			SaveString(hSaveB, sCount, "a", sBuffers[13]);
			SaveString(hSaveB, sCount, "propname", g_sPropName[i]);
			SaveString(hSaveB, sCount, "url", g_sUrl[i]);
		}
	}

	KeyValuesToFile(hSaveB, sPath);

	CloseHandle(hSaveB);

	OPrintToChat(iClient, "Saved {green}%d{default} props into {green}%s{default}.", iCount, sBuildName);
}*/

stock SaveClient(iClient)
{
	decl String:sAuthID[64];

	GetClientAuthId(iClient, AuthId_Steam2, sAuthID, sizeof(sAuthID));

	new Handle:hVault = CreateKeyValues("Vault");

	FileToKeyValues(hVault, g_sClientDatabase);

	SaveInteger(hVault, sAuthID, "Money", GetMoney(iClient));

	KeyValuesToFile(hVault, g_sClientDatabase);

	CloseHandle(hVault);
}

stock SaveInteger(Handle:hVault, const String:sKey[], const String:sSaveKey[], iVariable)
{
	if(iVariable == -1)
	{
		KvJumpToKey(hVault, sKey, true);
		
		KvDeleteKey(hVault, sSaveKey);

		KvRewind(hVault);

	}else{
		KvJumpToKey(hVault, sKey, true);

		KvSetNum(hVault, sSaveKey, iVariable);
	
		KvRewind(hVault);
	}
}

stock SaveString(Handle:hVault, const String:sKey[], const String:sSaveKey[], const String:sVariable[])
{
	KvJumpToKey(hVault, sKey, true);

	KvSetString(hVault, sSaveKey, sVariable);

	KvRewind(hVault);
}

public SendCommandArguments(iClient, const String:sCommand[], const String:sArgs[])
{
	decl String:sCommandAccess[64];

	CheckCommandSource(sCommand, sCommandAccess, sizeof(sCommandAccess));

	OReplyToCommand(iClient, "Usage: {green}%s{default} %s", sCommandAccess, sArgs);
}

stock SendHudMessage(iClient, iChannel, 
Float:fX, Float:fY, 
iR, iG, iB, iA, 
iEffect, 
Float:fFadeIn, Float:fFadeOut, 
Float:fHoldTime, Float:fFxTime, 
const String:sMessage[])
{
	new Handle:hHudMessage;
	if(!iClient)
	{
		hHudMessage = StartMessageAll("HudMsg");
	}else{
		hHudMessage = StartMessageOne("HudMsg", iClient);
	}
	if(hHudMessage != INVALID_HANDLE)
	{
		BfWriteByte(hHudMessage, iChannel);
		BfWriteFloat(hHudMessage, fX);
		BfWriteFloat(hHudMessage, fY);
		BfWriteByte(hHudMessage, iR);
		BfWriteByte(hHudMessage, iG);
		BfWriteByte(hHudMessage, iB);
		BfWriteByte(hHudMessage, iA);
		BfWriteByte(hHudMessage, iR);
		BfWriteByte(hHudMessage, iG);
		BfWriteByte(hHudMessage, iB);
		BfWriteByte(hHudMessage, iA);
		BfWriteByte(hHudMessage, iEffect);
		BfWriteFloat(hHudMessage, fFadeIn);
		BfWriteFloat(hHudMessage, fFadeOut);
		BfWriteFloat(hHudMessage, fHoldTime);
		BfWriteFloat(hHudMessage, fFxTime);
		BfWriteString(hHudMessage, sMessage);
		EndMessage();
	}
}

stock SendOutBeam(iClient, iEnt, bool:bChange)
{
	decl Float:fAngles[3], Float:fOrigin[3], Float:fEOrigin[3];
	decl String:sSound[64];

	if(bChange)
	{
		GetClientAbsOrigin(iClient, fOrigin);
		GetClientEyeAngles(iClient, fAngles);

		GetEntPropVector(iEnt, Prop_Data, "m_vecOrigin", fEOrigin);

		TE_SetupBeamPoints(fOrigin, fEOrigin, g_iPhys, g_iHalo, 0, 15, 0.1, 3.0, 3.0, 1, 0.0, g_iWhite, 10);
		TE_SendToAll();

		TE_SetupSparks(fEOrigin, fAngles, 3, 2);
		TE_SendToAll();

		new iRandom = GetRandomInt(0, 1);

		switch(iRandom)
		{
			case 0:
			{
				Format(sSound, sizeof(sSound), "weapons/airboat/airboat_gun_lastshot1.wav");
			}
			case 1:
			{
				Format(sSound, sizeof(sSound), "weapons/airboat/airboat_gun_lastshot2.wav");
			}
			default:
			{
			}
		}

		EmitSoundToAll(sSound, iEnt, 2, 100, 0, 1.0, 100, -1, NULL_VECTOR, NULL_VECTOR, true, 0.0);
	}else{
		Format(sSound, sizeof(sSound), "ambient/levels/citadel/weapon_disintegrate4.wav")

		GetClientAbsOrigin(iClient, fOrigin);
		GetClientEyeAngles(iClient, fAngles);

		GetEntPropVector(iEnt, Prop_Data, "m_vecOrigin", fEOrigin);

		TE_SetupBeamPoints(fOrigin, fEOrigin, g_iLaser, g_iHalo, 0, 15, 0.25, 15.0, 15.0, 1, 0.0, g_iGray, 10);
		TE_SendToAll();

		TE_SetupBeamRingPoint(fEOrigin, 10.0, 60.0, g_iBeam, g_iHalo, 0, 15, 0.5, 5.0, 0.0, g_iGray, 10, 0);
		TE_SendToAll();

		EmitAmbientSound(sSound, fEOrigin, iEnt, 100, 0, 1.0, 100, 0.0);
	}
}

stock SetHudColor(iClient, iR, iG, iB, iA)
{
	g_iHudColor[iClient][0] = iR;
	g_iHudColor[iClient][1] = iG;
	g_iHudColor[iClient][2] = iB;
	g_iHudColor[iClient][3] = iA;
}

stock SetMoney(iClient, iMoney)
{
	g_iBalance[iClient] = iMoney;
}

stock SetOwner(iEnt, iClient)
{
	g_iOwner[iEnt] = iClient;
}

//===============|Plugin Timers|===============

public Action:Timer_AddMoney(Handle:hTimer)
{
	for(new i = 1; i < MaxClients; i++)
	{
		if(IsClientConnected(i))
		{
			new iMoney = GetMoney(i);

			iMoney += 2;

			SetMoney(i, iMoney);

			SaveClient(i);
		}
	}
}

public Action:Timer_Hud(Handle:hTimer)
{
	decl String:sClassname[64], String:sMessage[256];

	for(new i = 1; i < MaxClients; i++)
	{
		if(IsClientInGame(i) && g_bEnabled && g_bHudEnabled)
		{
			new iEnt = GetClientAimTarget(i, false);

			if(iEnt == -1)
			{
				Format(sMessage, sizeof(sMessage), "Balance: $%d", GetMoney(i));
			}else{
				GetEntityClassname(iEnt, sClassname, sizeof(sClassname));

				if(StrEqual(sClassname, "player", true))
				{
					Format(sMessage, sizeof(sMessage), "Name: %N\nBalance: $%d", iEnt, GetMoney(iEnt));
				}else{
					if(!StrEqual(sClassname, "env_headcrabcanister", true))
					{
						if(CheckOwner(iEnt, i))
						{
							if(g_bForSale[iEnt])
							{
								Format(sMessage, sizeof(sMessage), "Price: $%d", g_iPrice[iEnt]);
							}else{
								Format(sMessage, sizeof(sMessage), "Balance: $%d", GetMoney(i));
							}
						}else{
							if(g_bForSale[iEnt])
							{
								Format(sMessage, sizeof(sMessage), "Owner: %N\nProp: %s\nPrice: $%d", GetOwner(iEnt), g_sPropName[iEnt], g_iPrice[iEnt]);
							}else{
								Format(sMessage, sizeof(sMessage), "Owner: %N\nProp: %s", GetOwner(iEnt), g_sPropName[iEnt]);
							}
						}
					}
				}
			}

			SendHudMessage(i, 1, 3.025, -0.110, g_iHudColor[i][0], g_iHudColor[i][1], g_iHudColor[i][2], g_iHudColor[i][3], 0, 0.6, 0.01, 0.01, 0.01, sMessage);
		}
	}
}

public Action:Timer_InLand(Handle:hTimer)
{
	for(new i = 1; i < MaxClients; i++)
	{
		if(g_bPutInServer[i] && IsClientConnected(i))
		{
			new iLand = IsClientInsideLand(i);

			if(iLand != -1)
			{
				if(!g_bSentMessage[i])
				{
					g_bIsInLand[i] = true;
				}

				//TE_SetupBeamFollow(i, g_iLaser, g_iHalo, 0.5, 5.0, 0.5, 10, g_iLandColor[iLand]);
   				//TE_SendToAll();
   				
   				if(g_bNoclipDisabled[iLand])
				{
					if(iLand == i)
					{}else{
						if(g_bNoclipEnabled[i])
						{
							SetEntityMoveType(i, MOVETYPE_WALK);

							g_bNoclipEnabled[i] = false;
							
							OPrintToChat(i, "Noclip is disabled in this land.");

							ClientCommand(i, "play resource/warning.wav");
						}
					}
				}
			}else{
				g_bIsInLand[i] = false;
				g_bSentMessage[i] = false;
			}

			if(g_bIsInLand[i])
			{
				OPrintToChat(i, "You have entered {green}%N{default}'s land.", iLand);

				g_bSentMessage[i] = true;

				g_bIsInLand[i] = false;
			}
		}
	}
}

public Action:Timer_Land(Handle:hTimer)
{
	for(new i = 1; i < MaxClients; i++)
	{
		if(IsClientConnected(i))
		{
			if(g_bLandDrawing[i])
				DrawBox(g_fLandPos[i][0], g_fLandPos[i][1], 0.1, g_iHudColor[i], true);
		}
	}
}

public Action:Timer_Positions(Handle:hTimer)
{
	decl Float:fAngles[3], Float:fFinalOrigin[3], Float:fOrigin[3];

	for(new i = 1; i < MaxClients; i++)
	{
		if(IsClientConnected(i))
		{
			if(g_bGettingPositions[i])
			{
				GetClientEyePosition(i, fOrigin);
				GetClientEyeAngles(i, fAngles);

				new Handle:hTraceRay = TR_TraceRayFilterEx(fOrigin, fAngles, MASK_SOLID, RayType_Infinite, FilterPlayer);

				if(TR_DidHit(hTraceRay))
				{
					TR_GetEndPosition(fFinalOrigin, hTraceRay);

					g_fLandPos[i][1] = fFinalOrigin;

					CloseHandle(hTraceRay);
				}
			}
		}
	}
}

public Action:Timer_RemoveCanisters(Handle:hTimer)
{
	decl String:sClassname[64];

	for(new i = 0; i < GetMaxEntities(); i++)
	{
		if(IsValidEntity(i))
		{
			GetEdictClassname(i, sClassname, sizeof(sClassname));

			if(StrEqual(sClassname, "env_headcrabcanister", true))
			{
				AcceptEntityInput(i, "kill");
			}
		}
	}
}

public Action:Timer_Welcome(Handle:hTimer)
{
	for(new i = 1; i < MaxClients; i++)
	{
		if(g_bJustJoined[i] && g_bEnabled)
		{
			CPrintToChatAll("Player {green}%N{default} has spawned.", i);

			ClientCommand(i, "play items/ammo_pickup.wav");

			g_bJustJoined[i] = false;
		}
	}
}

public Action:Timer_Respawn(Handle:hTimer, any:iClient)
{
	CS_RespawnPlayer(iClient);
}

//===============|Plugin Events|===============

public Action:Event_PlayerConnect(Handle:hEvent, const String:sName[], bool:bDontBroadcast)
{
    if(!bDontBroadcast)
    {
        decl String:sClientName[33], String:sNetworkID[22], String:sAddress[32];

        GetEventString(hEvent, "name", sClientName, sizeof(sClientName));
        GetEventString(hEvent, "networkid", sNetworkID, sizeof(sNetworkID));
        GetEventString(hEvent, "address", sAddress, sizeof(sAddress));

        new Handle:hNewEvent = CreateEvent("player_connect", true);

        SetEventString(hNewEvent, "name", sClientName);

        SetEventInt(hNewEvent, "index", GetEventInt(hEvent, "index"));
        SetEventInt(hNewEvent, "userid", GetEventInt(hEvent, "userid"));

        SetEventString(hNewEvent, "networkid", sNetworkID);
        SetEventString(hNewEvent, "address", sAddress);

        FireEvent(hNewEvent, true);

        return Plugin_Handled;
    }

    return Plugin_Handled;
}

public Action:Event_PlayerDeath(Handle:hEvent, const String:sName[], bool:bDontBroadcast) 
{
	new iClient = GetClientOfUserId(GetEventInt(hEvent, "userid"));

	g_bNoclipEnabled[iClient] = false;
	
	CreateTimer(0.7, Timer_Respawn, iClient);
}

public Action:Event_PlayerDisconnect(Handle:hEvent, const String:sName[], bool:bDontBroadcast)
{
    if(!bDontBroadcast)
    {
        decl String:sClientName[33], String:sNetworkID[22], String:sReason[65];

        GetEventString(hEvent, "name", sClientName, sizeof(sClientName));
        GetEventString(hEvent, "networkid", sNetworkID, sizeof(sNetworkID));
        GetEventString(hEvent, "reason", sReason, sizeof(sReason));
        
        new Handle:hNewEvent = CreateEvent("player_disconnect", true);

        SetEventInt(hNewEvent, "userid", GetEventInt(hEvent, "userid"));

        SetEventString(hNewEvent, "reason", sReason);
        SetEventString(hNewEvent, "name", sClientName);        
        SetEventString(hNewEvent, "networkid", sNetworkID);
        
        FireEvent(hNewEvent, true);
        
        return Plugin_Handled;
    }

    return Plugin_Handled;
}
