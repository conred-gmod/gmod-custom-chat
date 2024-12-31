util.AddNetworkString( "customchat.say" )

local Say = CustomChat.Say
local sayCooldown = {}

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