util.AddNetworkString( "customchat.player_spawned" )
util.AddNetworkString( "customchat.player_connect" )
util.AddNetworkString( "customchat.player_disconnect" )

hook.Add( "PlayerInitialSpawn", "CustomChat.BroadcastInitialSpawn", function( ply )
    -- Give some time for other addons to assign the team
    timer.Simple( 3, function()
        if not IsValid( ply ) then return end

        local steamId = ply:SteamID()
        local color = team.GetColor( ply:Team() )

        local time = os.time()
        local absenceLength = 0
        local lastSeen = CustomChat:GetLastSeen( steamId )

        if lastSeen then
            absenceLength = math.max( time - lastSeen, 0 )
        end

        CustomChat:SetLastSeen( steamId, time )

        net.Start( "customchat.player_spawned", false )
        net.WriteString( steamId )
        net.WriteString( ply:Nick() )
        net.WriteColor( color, false )
        net.WriteFloat( absenceLength )
        net.Broadcast()
    end )
end, HOOK_LOW )

gameevent.Listen( "player_connect" )
hook.Add( "player_connect", "CustomChat.BroadcastConnectMessage", function( data )
    hook.Run( "AlterCustomChatConnectMessage", data )

    net.Start("customchat.player_connect")
        net.WriteString( data.name )
        net.WriteString( data.networkid )
        net.WriteBool( data.bot == 1 )
    net.Broadcast()
end )

gameevent.Listen( "player_disconnect" )
hook.Add( "player_disconnect", "CustomChat.BroadcastDisconnectMessage", function( data )
    hook.Run( "AlterCustomChatDisconnectMessage", data )

    net.Start( "customchat.player_disconnect" )
        net.WriteString( data.name  )
        net.WriteString( data.networkid )
        net.WriteBool( data.bot == 1 )
        net.WriteString( data.reason )
    net.Broadcast()
end )