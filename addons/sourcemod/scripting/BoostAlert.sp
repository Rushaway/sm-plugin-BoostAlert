#pragma semicolon 1

#include <sourcemod>
#include <multicolors>
#include <zombiereloaded>

#pragma newdecls required

ConVar g_CVar_BoostHitGroup;
ConVar g_CVar_BoostSpam;
ConVar g_CVar_BoostDelay;
ConVar g_CVar_MinimumDamage;

int g_iGameTimeSpam[MAXPLAYERS+1] = { -1, ... };
int g_iGameTimes[MAXPLAYERS+1] = { -1, ... };
int g_iDamagedIDs[MAXPLAYERS+1] = { -1, ... };
int g_iAttackerIDs[MAXPLAYERS+1] = { -1, ... };

public Plugin myinfo =
{
	name			= "Boost Notifications",
	description		= "Notify admins when a zombie gets boosted",
	author			= "Kelyan3, maxime1907",
	version			= "1.0.0",
	url				= "https://steamcommunity.com/id/BeholdTheBahamutSlayer"
};

public void OnPluginStart()
{
	g_CVar_BoostHitGroup = CreateConVar("sm_boostalert_hitgroup", "1", "0 = Detect the whole body, 1 = Headshot only.");
	g_CVar_BoostSpam = CreateConVar("sm_boostalert_spam", "3", "The amount of time (in seconds) after a boost warning message is sent again.");
	g_CVar_BoostDelay = CreateConVar("sm_boostalert_delay", "15", "The amount of time (in seconds) after a zombie can still print the warning by infecting someone due to being boosted.");
	g_CVar_MinimumDamage = CreateConVar("sm_boostalert_min_damage", "80", "The minimum amount of damage needed to generate a boost warning.");

	HookEvent("player_hurt", EventHook_PlayerHurt, EventHookMode_Post);
	HookEvent("round_start", EventHook_RoundStart, EventHookMode_Post);
}

public Action EventHook_PlayerHurt(Event hEvent, const char[] sEventName, bool bDontBroadcast)
{
	int hitgroup = GetEventInt(hEvent, "hitgroup");

	if (GetEventInt(hEvent, "dmg_health") >= g_CVar_MinimumDamage.IntValue &&
		(g_CVar_BoostHitGroup.IntValue != 0 && g_CVar_BoostHitGroup.IntValue == hitgroup) || g_CVar_BoostHitGroup.IntValue == 0)
	{
		char sWeapon[64];
		GetEventString(hEvent, "weapon", sWeapon, sizeof(sWeapon));

		if (StrEqual(sWeapon, "m3"))
		{
			int time = GetTime();
			int victim = GetClientOfUserId(GetEventInt(hEvent, "userid"));
			int attacker = GetClientOfUserId(GetEventInt(hEvent, "attacker"));

			g_iGameTimes[victim] = time;
			g_iDamagedIDs[victim] = victim;
			g_iAttackerIDs[victim] = attacker;

			int diffTime = time - g_CVar_BoostSpam.IntValue;

			if (g_iGameTimeSpam[victim] <= diffTime)
			{
				g_iGameTimeSpam[victim] = time;
				for (int i = 1; i <= MaxClients; i++)
				{
					if (IsClientConnected(i) && IsClientInGame(i) && (IsClientSourceTV(i) || GetAdminFlag(GetUserAdmin(i), Admin_Generic)))
						CPrintToChat(i, "{green}[SM] {blue}%N {default}boosted {red}%N", attacker, victim);
				}
			}
		}
	}
}

public Action EventHook_RoundStart(Event hEvent, const char[] sEventName, bool bDontBroadcast)
{
	for (int i = 0; i <= MaxClients; i++)
	{
		g_iGameTimes[i] = -1;
		g_iDamagedIDs[i] = -1;
		g_iAttackerIDs[i] = -1;
		g_iGameTimeSpam[i] = -1;
	}
}

public void ZR_OnClientInfected(int client, int attacker, bool motherInfect, bool respawnOverride, bool respawn)
{
	if (client <= 0 || client > MaxClients || attacker <= 0 || attacker > MaxClients)
		return;

	int time = GetTime();
	int diffTime = time - g_CVar_BoostDelay.IntValue;

	if (attacker == g_iDamagedIDs[attacker] && g_iGameTimes[attacker] >= diffTime)
	{
		for (int admin = 1; admin <= MaxClients; admin++)
		{
			if (IsValidClient(admin) && (IsClientSourceTV(admin) || GetAdminFlag(GetUserAdmin(admin), Admin_Generic)))
			{
				if (IsValidClient(g_iAttackerIDs[attacker]) && IsValidClient(g_iDamagedIDs[attacker]))
				{
					CPrintToChat(admin, "{green}[SM] {red}%N {default}infected {red}%N{default}, boosted by {blue}%N{default}.\nCheck your console for more informations.", g_iDamagedIDs[attacker], client, g_iAttackerIDs[attacker]);
					PrintToConsole(admin, "[SM] %L infected %L after being boosted by %L", g_iDamagedIDs[attacker], client, g_iAttackerIDs[attacker]);
				}
			}
		}
	}
}

stock bool IsValidClient(int client, bool bNobots = false)
{
	if (client <= 0 || client > MaxClients || !IsClientConnected(client) || (bNobots && IsFakeClient(client)))
		return false;

	return IsClientInGame(client);
}