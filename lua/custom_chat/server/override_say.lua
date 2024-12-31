local Say = CustomChat.Say

local PLAYER = FindMetaTable( "Player" )

PLAYER.DefaultSay = PLAYER.DefaultSay or PLAYER.Say

function PLAYER:Say( text, teamOnly, channel, localMode )
    Say( self, text, teamOnly and "team" or (channel or "global"), localMode )
end