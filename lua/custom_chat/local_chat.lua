local LocalChat = CustomChat.LocalChat or {
    Modes = {}
}

CustomChat.LocalChat = LocalChat


local GetPlayerDistance = function( ply )
    return ply:GetInfoNum("custom_chat_local_default_distance", 300)
end

if CLIENT then
    CreateClientConVar( "custom_chat_local_default_distance", 300, true, true, nil, 150, 1000 )
    CreateClientConVar( "custom_chat_secondary_local", 1 )
    CreateClientConVar( "custom_chat_always_local", 0 )

    concommand.Add("say_local", function(_, _, _, argStr)
        CustomChat.Say(argStr, nil, "default")
    end)
end


function LocalChat:GetMode( id )
    return self.Modes[id]
end

function LocalChat:HasMode( id )
    return self.Modes[id] ~= nil
end

function LocalChat:CreateMode( id, name, distance )
    local mode = self:GetMode( id ) or {}

    if mode.index == nil then
        mode.id = id
        mode.index = table.insert(self.Modes, mode)
    end

    mode.name = name
    mode.getDistance = isfunction(distance) and distance or function() return distance end
    mode.getDistanceSquared = function( ply ) return mode.getDistance( ply ) ^ 2 end

    self.Modes[id] = mode
end


LocalChat:CreateMode( "default", "Сказать", GetPlayerDistance )

LocalChat:CreateMode( "yell", "Крикнуть", function( ply )
    return math.min( GetPlayerDistance( ply ) * 2, 1500 )
end )

LocalChat:CreateMode( "whisper", "Шептать", 50 )


if SERVER then
    hook.Add( "PlayerCanSeePlayersChat", "CustomChat.LocalChat", function( text, teamOnly, listener, speaker, channel, localMode )
        if not localMode then return end
        
        local mode = LocalChat:GetMode( localMode )

        return speaker:GetPos():DistToSqr( listener:GetPos() ) <= mode.getDistanceSquared( speaker )
    end )
end