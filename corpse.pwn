#include <YSI_Coding\y_hooks>
#include <YSI_Data\y_iterate>
#include <streamer>

#define INVALID_ATTACHED_SLOT        (-1)
#define MAX_CORPSES                  (100)
#define INVALID_CORPSE_ID            (-1)

#define CORPSE_STREAMER_DATA_SLOT    (0)

#define MIN_CORPSE_MODEL_ID          (-18000)
#define MAX_CORPSE_MODEL_ID          (-19500)

#define MAX_SKIN_ID                  (611)

#define DEFAULT_CORPSE_MODEL_ID      (-18000)

#define CORPSE_TEXT                  "(( This is a dead body,\n/corpse examine for more information ))"

new Iterator:Corpse<MAX_CORPSES>;

static CorpseObject[MAX_CORPSES];
static Text3D:Corpse3DText[MAX_CORPSES];

static CorpseModel[MAX_CORPSES];
static CorpseSkin[MAX_CORPSES];
static CorpseVirtualWorld[MAX_CORPSES];
static CorpseInterior[MAX_CORPSES];

static CorpseCarriedBy[MAX_CORPSES];
static CorpseCreatedAt[MAX_CORPSES];

static PlayerDraggingCorpseID[MAX_PLAYERS];
static PlayerAttachedCorpseSlot[MAX_PLAYERS];

new CorpseModelID[MAX_SKIN_ID + 1];

stock ResetCorpseSlot(corpseid)
{
    CorpseObject[corpseid] = INVALID_STREAMER_ID;
    Corpse3DText[corpseid] = Text3D:INVALID_STREAMER_ID;

    CorpseModel[corpseid] = INVALID_MODEL_ID;
    CorpseSkin[corpseid] = -1;
    CorpseVirtualWorld[corpseid] = 0;
    CorpseInterior[corpseid] = 0;

    CorpseCarriedBy[corpseid] = INVALID_PLAYER_ID;
    CorpseCreatedAt[corpseid] = 0;

    return 1;
}

stock ResetPlayerCorpseState(playerid)
{
    PlayerDraggingCorpseID[playerid] = INVALID_CORPSE_ID;
    PlayerAttachedCorpseSlot[playerid] = INVALID_ATTACHED_SLOT;
    return 1;
}

stock InitCorpseSystem()
{
    Iter_Clear(Corpse);

    for(new i = 0; i < MAX_CORPSES; i++)
    {
        ResetCorpseSlot(i);
    }

    for(new playerid = 0; playerid < MAX_PLAYERS; playerid++)
    {
        ResetPlayerCorpseState(playerid);
    }

    InitCorpseModelID();
    return 1;
}

stock InitCorpseModelID()
{
    for(new skinid = 0; skinid <= MAX_SKIN_ID; skinid++)
    {
        CorpseModelID[skinid] = DEFAULT_CORPSE_MODEL_ID;
    }

    CorpseModelID[0] = -18000;
    CorpseModelID[1] = -18001;

    return 1;
}

stock bool:IsValidCorpse(corpseid)
{
    if(corpseid < 0 || corpseid >= MAX_CORPSES)
    {
        return false;
    }

    return Iter_Contains(Corpse, corpseid);
}

stock bool:IsCorpseCarriedByAnyPlayer(corpseid)
{
    if(!IsValidCorpse(corpseid))
    {
        return false;
    }

    return CorpseCarriedBy[corpseid] != INVALID_PLAYER_ID;
}

stock bool:IsPlayerDraggingAnyCorpse(playerid)
{
    return PlayerDraggingCorpseID[playerid] != INVALID_CORPSE_ID;
}

stock GetFreeAttachedSlot(playerid)
{
    for(new slot = 0; slot < 10; slot++)
    {
        if(!IsPlayerAttachedObjectSlotUsed(playerid, slot))
        {
            return slot;
        }
    }

    return INVALID_ATTACHED_SLOT;
}

stock GetCorpseModelForSkin(skinid)
{
    if(skinid < 0 || skinid > MAX_SKIN_ID)
    {
        return DEFAULT_CORPSE_MODEL_ID;
    }

    return CorpseModelID[skinid];
}

stock GetClosestCorpse(playerid)
{
    new Float:x;
    new Float:y;
    new Float:z;

    GetPlayerPos(playerid, x, y, z);

    new nearbyObjects[8];

    new count = Streamer_GetNearbyItems(
        x,
        y,
        z,
        STREAMER_TYPE_OBJECT,
        nearbyObjects,
        sizeof(nearbyObjects),
        1.5,
        GetPlayerVirtualWorld(playerid),
        GetPlayerInterior(playerid)
    );

    for(new i = 0; i < count; i++)
    {
        new storedCorpseID = Streamer_GetIntData(
            STREAMER_TYPE_OBJECT,
            nearbyObjects[i],
            E_STREAMER_CUSTOM(CORPSE_STREAMER_DATA_SLOT)
        );

        if(storedCorpseID > 0)
        {
            new corpseid = storedCorpseID - 1;

            if(IsValidCorpse(corpseid) && !IsCorpseCarriedByAnyPlayer(corpseid))
            {
                return corpseid;
            }
        }
    }

    return INVALID_CORPSE_ID;
}

stock CreateCorpseWorldObject(corpseid, Float:x, Float:y, Float:z, Float:rz, virtualworld, interior)
{
    if(!IsValidCorpse(corpseid))
    {
        return 0;
    }

    new modelid = CorpseModel[corpseid];

    if(modelid == INVALID_MODEL_ID)
    {
        modelid = DEFAULT_CORPSE_MODEL_ID;
        CorpseModel[corpseid] = modelid;
    }

    CorpseObject[corpseid] = CreateDynamicObject(
        modelid,
        x,
        y,
        z + 0.1,
        0.0,
        -90.0,
        rz,
        virtualworld,
        interior
    );

    if(CorpseObject[corpseid] == INVALID_STREAMER_ID)
    {
        return 0;
    }

    Streamer_SetIntData(
        STREAMER_TYPE_OBJECT,
        CorpseObject[corpseid],
        E_STREAMER_CUSTOM(CORPSE_STREAMER_DATA_SLOT),
        corpseid + 1
    );

    Corpse3DText[corpseid] = CreateDynamic3DTextLabel(
        CORPSE_TEXT,
        0xFF6666FF,
        x,
        y,
        z - 0.5,
        15.0,
        INVALID_PLAYER_ID,
        INVALID_VEHICLE_ID,
        1,
        virtualworld,
        interior
    );

    CorpseVirtualWorld[corpseid] = virtualworld;
    CorpseInterior[corpseid] = interior;

    return 1;
}

stock DestroyCorpseWorldObject(corpseid)
{
    if(corpseid < 0 || corpseid >= MAX_CORPSES)
    {
        return 0;
    }

    if(CorpseObject[corpseid] != INVALID_STREAMER_ID)
    {
        DestroyDynamicObject(CorpseObject[corpseid]);
        CorpseObject[corpseid] = INVALID_STREAMER_ID;
    }

    if(Corpse3DText[corpseid] != Text3D:INVALID_STREAMER_ID)
    {
        DestroyDynamic3DTextLabel(Corpse3DText[corpseid]);
        Corpse3DText[corpseid] = Text3D:INVALID_STREAMER_ID;
    }

    return 1;
}

stock Corpse_Create(playerid)
{
    new corpseid = Iter_Free(Corpse);

    if(corpseid == INVALID_ITERATOR_SLOT)
    {
        return INVALID_CORPSE_ID;
    }

    Iter_Add(Corpse, corpseid);

    new Float:x;
    new Float:y;
    new Float:z;

    GetPlayerPos(playerid, x, y, z);

    new skinid = GetPlayerSkin(playerid);
    new modelid = GetCorpseModelForSkin(skinid);

    CorpseSkin[corpseid] = skinid;
    CorpseModel[corpseid] = modelid;
    CorpseCarriedBy[corpseid] = INVALID_PLAYER_ID;
    CorpseCreatedAt[corpseid] = gettime();

    new virtualworld = GetPlayerVirtualWorld(playerid);
    new interior = GetPlayerInterior(playerid);

    if(!CreateCorpseWorldObject(corpseid, x, y, z, float(random(360)), virtualworld, interior))
    {
        Iter_Remove(Corpse, corpseid);
        ResetCorpseSlot(corpseid);
        return INVALID_CORPSE_ID;
    }

    return corpseid;
}

stock Corpse_Drag(playerid, corpseid)
{
    if(IsPlayerDraggingAnyCorpse(playerid))
    {
        return 0;
    }

    if(!IsValidCorpse(corpseid))
    {
        return 0;
    }

    if(IsCorpseCarriedByAnyPlayer(corpseid))
    {
        return 0;
    }

    new slot = GetFreeAttachedSlot(playerid);

    if(slot == INVALID_ATTACHED_SLOT)
    {
        return 0;
    }

    new modelid = CorpseModel[corpseid];

    if(modelid == INVALID_MODEL_ID)
    {
        modelid = DEFAULT_CORPSE_MODEL_ID;
        CorpseModel[corpseid] = modelid;
    }

    DestroyCorpseWorldObject(corpseid);

    SetPlayerAttachedObject(
        playerid,
        slot,
        modelid,
        1,
        -0.12,
        0.72,
        -0.92,
        -100.1,
        17.20,
        0.0
    );

    CorpseCarriedBy[corpseid] = playerid;

    PlayerDraggingCorpseID[playerid] = corpseid;
    PlayerAttachedCorpseSlot[playerid] = slot;

    return 1;
}

stock Corpse_Drop(playerid, corpseid)
{
    if(!IsPlayerDraggingAnyCorpse(playerid))
    {
        return 0;
    }

    if(!IsValidCorpse(corpseid))
    {
        ResetPlayerCorpseState(playerid);
        return 0;
    }

    if(CorpseCarriedBy[corpseid] != playerid)
    {
        return 0;
    }

    new slot = PlayerAttachedCorpseSlot[playerid];

    if(slot != INVALID_ATTACHED_SLOT)
    {
        if(IsPlayerAttachedObjectSlotUsed(playerid, slot))
        {
            RemovePlayerAttachedObject(playerid, slot);
        }
    }

    new Float:x;
    new Float:y;
    new Float:z;

    GetPlayerPos(playerid, x, y, z);

    new virtualworld = GetPlayerVirtualWorld(playerid);
    new interior = GetPlayerInterior(playerid);

    CorpseCarriedBy[corpseid] = INVALID_PLAYER_ID;

    PlayerDraggingCorpseID[playerid] = INVALID_CORPSE_ID;
    PlayerAttachedCorpseSlot[playerid] = INVALID_ATTACHED_SLOT;

    if(!CreateCorpseWorldObject(corpseid, x, y, z, float(random(360)), virtualworld, interior))
    {
        Iter_Remove(Corpse, corpseid);
        ResetCorpseSlot(corpseid);
        return 0;
    }

    return 1;
}

stock Corpse_Destroy(corpseid)
{
    if(!IsValidCorpse(corpseid))
    {
        return 0;
    }

    new carrier = CorpseCarriedBy[corpseid];

    if(carrier != INVALID_PLAYER_ID)
    {
        if(IsPlayerConnected(carrier))
        {
            new slot = PlayerAttachedCorpseSlot[carrier];

            if(slot != INVALID_ATTACHED_SLOT && IsPlayerAttachedObjectSlotUsed(carrier, slot))
            {
                RemovePlayerAttachedObject(carrier, slot);
            }

            ResetPlayerCorpseState(carrier);
        }
    }

    DestroyCorpseWorldObject(corpseid);

    Iter_Remove(Corpse, corpseid);
    ResetCorpseSlot(corpseid);

    return 1;
}

hook OnGameModeInit()
{
    InitCorpseSystem();

    AddSimpleModel(-1, 19379, -18000, "truth_down.dff", "truth.txd");
    AddSimpleModel(-1, 19379, -18001, "andre_down.dff", "andre.txd");

    return 1;
}

hook OnPlayerConnect(playerid)
{
    ResetPlayerCorpseState(playerid);
    return 1;
}

hook OnPlayerDisconnect(playerid, reason)
{
    if(IsPlayerDraggingAnyCorpse(playerid))
    {
        Corpse_Drop(playerid, PlayerDraggingCorpseID[playerid]);
    }

    ResetPlayerCorpseState(playerid);
    return 1;
}

hook OnPlayerDeath(playerid, killerid, reason)
{
    Corpse_Create(playerid);
    return 1;
}

CMD:corpse(playerid, params[])
{
    if(isnull(params))
    {
        return SendClientMessage(playerid, 0xFFFFFFFF, "/corpse (options: carry, drop, examine, delete)");
    }

    if(!strcmp(params, "carry", true))
    {
        new corpseid = GetClosestCorpse(playerid);

        if(corpseid == INVALID_CORPSE_ID)
        {
            return SendClientMessage(playerid, 0xFFFFFFFF, "You're too far away from the closest corpse.");
        }

        if(!Corpse_Drag(playerid, corpseid))
        {
            return SendClientMessage(playerid, 0xFFFFFFFF, "You can't carry that corpse.");
        }

        ApplyAnimation(playerid, "CARRY", "liftup", 3.0, 0, 0, 0, 0, 0);
        SendClientMessage(playerid, 0xFF6666FF, "You picked up the corpse.");
        return 1;
    }

    if(!strcmp(params, "drop", true))
    {
        if(!IsPlayerDraggingAnyCorpse(playerid))
        {
            return SendClientMessage(playerid, 0xFFFFFFFF, "You're not carrying any corpse.");
        }

        if(!Corpse_Drop(playerid, PlayerDraggingCorpseID[playerid]))
        {
            return SendClientMessage(playerid, 0xFFFFFFFF, "Something went wrong.");
        }

        ApplyAnimation(playerid, "CARRY", "putdwn", 3.0, 0, 0, 0, 0, 0);
        SendClientMessage(playerid, 0xFF6666FF, "You dropped the corpse.");
        return 1;
    }

    if(!strcmp(params, "examine", true))
    {
        new corpseid = GetClosestCorpse(playerid);

        if(corpseid == INVALID_CORPSE_ID)
        {
            return SendClientMessage(playerid, 0xFFFFFFFF, "You're too far away from the closest corpse.");
        }

        new message[144];

        format(
            message,
            sizeof(message),
            "Corpse ID: %d | Skin: %d | Model: %d | Created: %d seconds ago.",
            corpseid,
            CorpseSkin[corpseid],
            CorpseModel[corpseid],
            gettime() - CorpseCreatedAt[corpseid]
        );

        SendClientMessage(playerid, 0xFF6666FF, message);
        return 1;
    }

    if(!strcmp(params, "delete", true))
    {
        new corpseid = GetClosestCorpse(playerid);

        if(corpseid == INVALID_CORPSE_ID)
        {
            return SendClientMessage(playerid, 0xFFFFFFFF, "You're too far away from the closest corpse.");
        }

        if(!Corpse_Destroy(corpseid))
        {
            return SendClientMessage(playerid, 0xFFFFFFFF, "Something went wrong.");
        }

        SendClientMessage(playerid, 0xFF6666FF, "Corpse deleted.");
        return 1;
    }

    SendClientMessage(playerid, 0xFF6666FF, "/corpse (options: carry, drop, examine, delete)");
    return 1;
}