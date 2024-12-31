resource.AddWorkshop( "2799307109" )

local LAST_SEEN_TABLE = CustomChat.LAST_SEEN_TABLE

-- Setup "last seen" SQLite table
sql.Query( "CREATE TABLE IF NOT EXISTS " .. LAST_SEEN_TABLE ..
    " ( SteamID TEXT NOT NULL PRIMARY KEY, LastSeen INTEGER NOT NULL );" )

function CustomChat:GetLastSeen( steamId )
    local row = sql.QueryRow( "SELECT LastSeen FROM " .. LAST_SEEN_TABLE .. " WHERE SteamID = '" .. steamId .. "';" )

    if row and row.LastSeen then
        return row.LastSeen
    end
end

function CustomChat:SetLastSeen( steamId, time )
    local row = sql.QueryRow( "SELECT LastSeen FROM " .. LAST_SEEN_TABLE .. " WHERE SteamID = '" .. steamId .. "';" )

    time = math.floor( time )

    if row then
        local success = sql.Query( "UPDATE " .. LAST_SEEN_TABLE ..
            " SET LastSeen = " .. time .. " WHERE SteamID = '" .. steamId .. "';" )

        if success == false then
            CustomChat.Print( "SetLastSeen SQL for player %s failed: %s", steamId, sql.LastError() )
        end
    else
        local success = sql.Query( "INSERT INTO " .. LAST_SEEN_TABLE ..
            " ( SteamID, LastSeen ) VALUES ( '" .. steamId .. "', " .. time .. " );" )

        if success == false then
            CustomChat.Print( "SetLastSeen SQL for player %s failed: %s", steamId, sql.LastError() )
        end
    end
end

function CustomChat:LoadConfig()
    CustomChat.EnsureDataDir()

    local ToJSON, FromJSON = CustomChat.ToJSON, CustomChat.FromJSON
    local LoadDataFile = CustomChat.LoadDataFile

    local themeData = FromJSON( LoadDataFile( "server_theme.json" ) )
    local emojiData = FromJSON( LoadDataFile( "server_emojis.json" ) )
    local tagsData = FromJSON( LoadDataFile( "server_tags.json" ) )

    if not table.IsEmpty( themeData ) then
        NetPrefs.Set( "customchat.theme", ToJSON( themeData ) )
    end

    if not table.IsEmpty( emojiData ) then
        NetPrefs.Set( "customchat.emojis", ToJSON( emojiData ) )
    end

    if not table.IsEmpty( tagsData ) then
        NetPrefs.Set( "customchat.tags", ToJSON( tagsData ) )
    end
end

CustomChat:LoadConfig()


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

function CustomChat.Say( speaker, text, channel, localMode )
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
    text = hook.Run( "PlayerSay", speaker, text, teamOnly, channel ) or text
    
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


hook.Add( "ShutDown", "CustomChat.SaveLastSeen", function()
    local time = os.time()

    for _, ply in ipairs( player.GetHumans() ) do
        local steamId = ply:SteamID()

        if steamId then -- Could be nil on the listen server host
            CustomChat:SetLastSeen( steamId, time )
        end
    end
end )
