util.AddNetworkString( "customchat.say" )

-- Gets a list of all players who can
-- listen to messages from a "speaker".
local function GetListeners( speaker, text, channel, localMode )
    local teamOnly = channel == "team"
    local targets = teamOnly and team.GetPlayers( speaker:Team() ) or player.GetHumans()
    local listeners = {}

    for _, ply in ipairs( targets ) do
        if hook.Run( "PlayerCanSeePlayersChat", text, teamOnly, ply, speaker, channel, localMode ) then
            listeners[#listeners + 1] = ply
        end
    end

    return listeners
end

local IsStringValid = CustomChat.IsStringValid
local sayCooldown = {}

local function Say( speaker, text, channel, localMode )
    if not IsStringValid( text ) then return end
    if not IsStringValid( channel ) then return end
    if channel:len() > CustomChat.MAX_CHANNEL_ID_LENGTH then return end

    if text:len() > CustomChat.MAX_MESSAGE_LENGTH then
        text = text:Left( CustomChat.MAX_MESSAGE_LENGTH )
    end

    local teamOnly = channel == "team"
    local dmTarget = nil

    -- Is this a DM?
    if util.SteamIDTo64( channel ) ~= "0" then
        dmTarget = player.GetBySteamID( channel )
        if not IsValid( dmTarget ) then return end
        if CustomChat.GetConVarInt( "enable_dms", 1 ) == 0 then return end
    end

    text = CustomChat.CleanupString( text )
    text = hook.Run( "PlayerSay", speaker, text, teamOnly, channel, localMode )

    if not IsStringValid( text ) then return end

    if dmTarget then
        -- Send to the DM target
        message = CustomChat.ToJSON( {
            channel = speaker:SteamID(),
            text = text
        } )

        net.Start( "customchat.say", false )
        net.WriteString( message )
        net.WriteEntity( speaker )
        net.Send( dmTarget )

        -- And also relay it back to the speaker
        message = CustomChat.ToJSON( {
            channel = channel,
            text = text
        } )

        net.Start( "customchat.say", false )
        net.WriteString( message )
        net.WriteEntity( speaker )
        net.Send( speaker )

        return
    end

    hook.Run( "player_say", {
        priority = 1, -- ??
        userid = speaker:UserID(),
        text = text,
        teamonly = teamOnly and 1 or 0,
    } )

    local targets = GetListeners( speaker, text, channel, localMode )
    if #targets == 0 then return end

    message = CustomChat.ToJSON( {
        channel = channel,
        localMode = localMode,
        text = text
    } )

    net.Start( "customchat.say", false )
    net.WriteString( message )
    net.WriteEntity( speaker )
    net.Send( targets )
end

local META_PLAYER = FindMetaTable("Player")

function META_PLAYER:Say( text, teamOnly, channel, localMode )
    Say( self, text, teamOnly and "team" or (channel or "global"), localMode )
end

net.Receive( "customchat.say", function( _, speaker )
    local playerId = speaker:SteamID()
    local nextSay = sayCooldown[playerId] or 0

    if RealTime() < nextSay then return end

    sayCooldown[playerId] = RealTime() + 0.5

    local message = net.ReadString()

    message = CustomChat.FromJSON( message )

    Say( speaker, message.text, message.channel, message.localMode )
end )

hook.Add( "PlayerDisconnected", "CustomChat.SayCooldownCleanup", function( ply )
    sayCooldown[ply:SteamID()] = nil
    CustomChat:SetLastSeen( ply:SteamID(), os.time() )
end )
