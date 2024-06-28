local L = CustomChat.GetLanguageText
local PANEL = {}

function PANEL:Init()
    self:SetTitle( "" )
    self:ShowCloseButton( false )

    self.channels = {}
    self.channelIndexes = {}
    self.channelListBackgroundColor = Color( 0, 0, 0 )

    self.history = vgui.Create( "CustomChat_History", self )
    self.history:Dock( FILL )
    self.history:DockMargin( 0, -24, 0, 0 )
    self.history:SetFontSize( CustomChat.Config.fontSize )
    self.history:UpdateEmojiPanel()

    self.history.OnClickLink = function( url )
        gui.OpenURL( url )
    end

    self.history.OnPressEnter = function()
        if self.isChatOpen then self:SubmitMessage() end
    end

    self.history.OnSelectEmoji = function( id )
        if self.isChatOpen then self:AppendAtCaret( ":" .. id .. ":" ) end
    end

    self.history.OnRightClick = function( data )
        if self.isChatOpen then self.OnRightClick( data ) end
    end

    self.entryDock = vgui.Create( "DPanel", self )
    self.entryDock:Dock( BOTTOM )
    self.entryDock:DockMargin( 0, 4, 0, 0 )
    self.entryDock._backgroundColor = Color( 0, 0, 0 )

    self.entryDock.Paint = function( s, w, h )
        draw.RoundedBox( 0, 0, 0, w, h, s._backgroundColor )
    end

    local localMode = vgui.Create("DButton", self.entryDock)
    self.localMode = localMode

    localMode:Hide()
    localMode:Dock( LEFT )
    localMode:SetWide( 64 )
    localMode:SetTextColor( color_white )

    localMode.Paint = nil

    localMode.DoClick = function( s )
        self:NextLocalMode()
    end

    self.entry = vgui.Create( "DTextEntry", self.entryDock )
    self.entry:SetFont( "ChatFont" )
    self.entry:SetDrawBorder( false )
    self.entry:SetPaintBackground( false )
    self.entry:SetMaximumCharCount( CustomChat.MAX_MESSAGE_LENGTH )
    self.entry:SetTabbingDisabled( true )
    self.entry:SetMultiline( true )
    self.entry:SetHistoryEnabled( true )
    self.entry:SetDrawLanguageID( false )
    self.entry:Dock( FILL )

    self.entry.Paint = function( s, w, h )
        derma.SkinHook( "Paint", "TextEntry", s, w, h )
    end

    self.entry.OnChange = function( s )
        if not s.GetText then return end

        local text = s:GetText() or ""

        hook.Run( "ChatTextChanged", text )

        local _, lineCount = string.gsub( text, "\n", "\n" )
        lineCount = math.Clamp( lineCount + 1, 1, 5 )

        self.entryDock:SetTall( 20 * lineCount )
        self.entry._multilineMode = lineCount > 1
    end

    self.entry.OnKeyCodeTyped = function( s, code )
        if code == KEY_ESCAPE then
            chat.Close()

        elseif code == KEY_F then
            if input.IsControlDown() then
                self.history:FindText()
            end

        elseif code == KEY_TAB then
            if input.IsControlDown() then
                self:NextChannel()
                return
            end

            local text = s:GetText()
            local replaceText = hook.Run( "OnChatTab", text )

            if type( replaceText ) == "string" and replaceText ~= text:Trim() then
                s:SetText( replaceText )
                s:SetCaretPos( string.len( replaceText ) )
            else
                self:AppendAtCaret( "  " )
            end

        elseif code == KEY_ENTER and not input.IsShiftDown() then
            self:SubmitMessage()
            return true
        
        elseif code == KEY_BACKSPACE and input.IsControlDown() then
            self:NextLocalMode()
            return true
           
        elseif code == KEY_V and input.IsControlDown() then
            if s.imagePasteHack._IsLoading then 
                self.history:Notify("Подождите загрузки предыдущего изображения", 2) 
            else
                -- For some reason HTML doesn't focus on text paste, so it works just as we need
                --  not sure if is right
                s.imagePasteHack:RequestFocus()
            end

        end

        
        if not s._multilineMode and s.m_bHistory then
            if code == KEY_UP then
                s.HistoryPos = s.HistoryPos - 1
                s:UpdateFromHistory()
            end

            if code == KEY_DOWN then
                s.HistoryPos = s.HistoryPos + 1
                s:UpdateFromHistory()
            end
        end
    end

    local imagePasteHack = vgui.Create( "DHTML", self.entry )
    self.entry.imagePasteHack = imagePasteHack

    imagePasteHack:SetHTML([[
    <script>
        window.addEventListener("paste", (event) => {
            if (!event.clipboardData && !window.clipboardData) return;
            const items = (event.clipboardData || window.clipboardData).items;
            if (!items) return;

            for (const item of items) {
                if (item.type.match("^image/")) {
                    const file = item.getAsFile();
                    const reader = new FileReader();
                    reader.onload = () => {
                        const b64 = btoa(reader.result);

                        lua.OnImagePaste(b64);
                    };

                    reader.readAsBinaryString(file);
                
                    break;
                }
            }
        })

        window.addEventListener("focus", (event) => {
            lua.Notify("Нажмите Ctrl+V повторно, чтобы вставить изображение из буфера обмена", 3)
        })
    </script>
    ]])
    imagePasteHack:SetSize(0, 0)
    imagePasteHack:AddFunction( "lua", "OnImagePaste", function( base64 ) 
        if imagePasteHack._IsLoading then return end

        imagePasteHack._IsLoading = true

        self:AppendAtCaret("{загрузка}")
        self.entry:RequestFocus()

        CustomChat.Imgur:Upload( base64, function(url)
            imagePasteHack._IsLoading = nil

            if not url then return end

            self.entry:SetText( self.entry:GetText():gsub("{загрузка}", url) )

            self.entry:RequestFocus()
            self.entry:SetCaretPos(utf8.len(self.entry:GetValue()))
        end )
    end )

    imagePasteHack:AddFunction( "lua", "Notify", function( text, time ) 
        self.history:Notify( text, time )
    end )

    local emojisButton = vgui.Create( "DImageButton", self.entryDock )
    emojisButton:SetImage( "icon16/emoticon_smile.png" )
    emojisButton:SetStretchToFit( false )
    emojisButton:SetWide( 22 )
    emojisButton:Dock( RIGHT )

    emojisButton.DoClick = function()
        self.history:ToggleEmojiPanel()
    end

    self:CreateChannel( "global", L"channel.global", "icon16/world.png" )
    if CustomChat.GetConVarInt( "enable_team_channel", 1 ) == 1 then
        self:CreateChannel( "team", L"channel.team", CustomChat.TEAM_CHAT_ICON )
    end

    self:SetLocalMode( "default" )
    self:SetActiveChannel( "global" )
    self:LoadThemeData()
    self:CloseChat()
end

function PANEL:Think()
    -- Makes panel resizable and draggable
    self.BaseClass.Think(self)

    if not self.channelList then return end

    local indexes = self.channelIndexes
    for i = 1, #indexes do
        local channel = self.channels[indexes[i]]
        if channel.check == nil then continue end

        local visible = channel.check()
        if visible ~= nil and visible ~= channel.button:IsVisible() then
            self:SetChannelVisible( channel.id, visible )
        end
    end
end

function PANEL:SetSidebarEnabled( enable )
    if not enable then
        if IsValid( self.channelList ) then
            self.channelList:Remove()
        end

        self.channelList = nil
        return
    end

    self.channelList = vgui.Create( "DPanel", self )
    self.channelList:SetWide( 30 )
    self.channelList:Dock( LEFT )
    self.channelList:DockMargin( 0, -24, 4, 0 )
    self.channelList:DockPadding( 2, 2, 2, 2 )

    self.channelList.Paint = function( _, w, h )
        surface.SetDrawColor( self.channelListBackgroundColor:Unpack() )
        surface.DrawRect( 0, 0, w, h )
    end

    self:UpdateChannelList()
end

function PANEL:UpdateChannelList()
    if not self.channelList then return end

    self.channelList:Clear()
    self.channelList:SetVisible( self.isChatOpen )

    for _, id in ipairs( self.channelIndexes ) do
        local channel = self.channels[id]

        local button = vgui.Create( "CustomChat_ChannelButton", self.channelList )
        button:SetTall( 28 )
        button:SetTooltip( channel.name )
        button:SetIcon( channel.icon )
        button:Dock( TOP )
        button:DockMargin( 0, 0, 0, 2 )
        button.channelId = id
        button.isSelected = channel.isSelected
        button.colorSelected = self.highlightColor
        button.notificationCount = channel.notificationCount

        channel.button = button
    end

    local buttonOpenDM = vgui.Create( "DButton", self.channelList )
    buttonOpenDM:SetText( "" )
    buttonOpenDM:SetIcon( "icon16/add.png" )
    buttonOpenDM:SetTall( 26 )
    buttonOpenDM:SetTooltip( L"channel.open_dm" )
    buttonOpenDM:SetPaintBackground( false )
    buttonOpenDM:Dock( BOTTOM )

    buttonOpenDM.DoClick = function()
        self:OpenDirectMessage()
    end
end

function PANEL:OpenChat()
    local secondary_local = CustomChat.GetConVarInt( "secondary_local", 1 ) == 1

    self.entryDock:SetTall( 20 )
    self.history:ScrollToBottom()

    self:SetTemporaryMode( false )
    self.isChatOpen = true

    if CustomChat.isUsingTeamOnly == true and not secondary_local then
        self:SetActiveChannel( "team" )
    else
        if self.lastChannelId == "team" then
            self.lastChannelId = nil
        end

        self:SetActiveChannel( self.lastChannelId or "global" )
    end

    if CustomChat.GetConVarInt( "enable_dms", 1 ) == 0 then
        for id, channel in pairs( self.channels ) do
            if channel.isDM then
                self:RemoveChannel( id )
            end
        end
    end

    if CustomChat.GetConVarInt( "always_local", 0 ) == 1 or (CustomChat.isUsingTeamOnly and secondary_local) then
        self.localMode:Show()
    else
        self.localMode:Hide()
        self.localMode:InvalidateParent()
    end
end

function PANEL:CloseChat()
    self.history:ClearSelection()
    self.entry:SetText( "" )
    self.entry.HistoryPos = 0
    self.entry._multilineMode = false

    self:SetTemporaryMode( true )
    self.isChatOpen = false

    if IsValid( self.frameOpenDM ) then
        self.frameOpenDM:Close()
    end
end

function PANEL:SetTemporaryMode( tempMode )
    self.history:SetTemporaryMode( tempMode )

    for _, pnl in ipairs( self:GetChildren() ) do
        if pnl ~= self.history and
            pnl ~= self.btnMaxim and
            pnl ~= self.btnClose and
            pnl ~= self.btnMinim
        then
            pnl:SetVisible( not tempMode )
        end
    end
end

function PANEL:ClearEverything()
    self.history:ClearEverything()

    for id, _ in pairs( self.channels ) do
        self:SetChannelNotificationCount( id, 0 )
    end
end

function PANEL:NextLocalMode()
    local currentIndex = self.localMode.mode.index
    local nextIndex = currentIndex + 1

    if nextIndex > #CustomChat.LocalChat.Modes then
        nextIndex = 1
    end

    self:SetLocalMode( CustomChat.LocalChat.Modes[nextIndex].id )
end

function PANEL:SetLocalMode( id )
    local mode = CustomChat.LocalChat:GetMode( id )

    self.localMode.mode = mode
    self.localMode:SetText( mode.name )
end

function PANEL:NextChannel()
    local currentIndex = 1

    for i, id in ipairs( self.channelIndexes ) do
        if self.channels[id].isSelected then
            currentIndex = i
            break
        end
    end

    local nextIndex = currentIndex + 1

    if nextIndex > #self.channelIndexes then
        nextIndex = 1
    end

    self:SetActiveChannel( self.channelIndexes[nextIndex] )
end

function PANEL:CreateChannel( id, name, icon, func_check )
    local channel = self.channels[id]

    if channel then
        channel.name = name
        channel.check = func_check
        channel.icon = icon

        self:UpdateChannelList()

        return channel
    end

    self.history:QueueJavascript( "CreateChannel('" .. id .. "');" )

    channel = {
        id = id,
        name = name,
        check = func_check,
        icon = icon,
        missedCount = 0,
        notificationCount = 0
    }

    self.channels[id] = channel
    self.channelIndexes[#self.channelIndexes + 1] = id
    self:UpdateChannelList()

    return channel
end

function PANEL:RemoveChannel( id )
    if not self.channels[id] then return end

    if id == self.lastChannelId then
        self:NextChannel()
    end

    self.history:QueueJavascript( "RemoveChannel('" .. id .. "');" )

    table.RemoveByValue( self.channelIndexes, id )

    self.channels[id] = nil
    self:UpdateChannelList()
end

function PANEL:SetChannelVisible( id, state )
    local channel = self.channels[id]
    if channel == nil then return end

    if id == self.lastChannelId then
        self:NextChannel()
    end

    channel.button:SetVisible( state )

    self.history:QueueJavascript( Format("SetChannelVisible(\"%s\", %s)", id, tostring( state ) ) )
end

function PANEL:SetActiveChannel( id )
    local channel = self.channels[id]
    if not channel then return end

    self.lastChannelId = id
    channel.missedCount = 0

    self:SetChannelNotificationCount( id, 0 )

    if self.isChatOpen then
        self.history:QueueJavascript( "SetActiveChannel('" .. id .. "');" )
    end

    for chid, c in pairs( self.channels ) do
        c.isSelected = chid == id
    end

    if id == "team" then
        local color = team.GetColor( LocalPlayer():Team() )

        color.r = color.r * 0.3
        color.g = color.g * 0.3
        color.b = color.b * 0.3
        color.a = self.inputBackgroundColor.a

        self:SetEntryLabel( CustomChat.TEAM_CHAT_LABEL, color )

    elseif id == "global" then
        self:SetEntryLabel( "custom_chat.say" )

    else
        self:SetEntryLabel( L( "say" ) .. " (" .. channel.name .. ")" )
    end

    if self.isChatOpen then
        self.entry:RequestFocus()
        self:UpdateChannelList()
    end
end

function PANEL:SetChannelNotificationCount( id, count )
    if self.channels[id] then
        self.channels[id].notificationCount = count
        self:UpdateChannelList()
    end
end

function PANEL:SetEntryLabel( text, color )
    self.entry:SetPlaceholderText( text )
    self.entryDock._backgroundColor = color or self.inputBackgroundColor
end

function PANEL:LoadThemeData( data )
    CustomChat.Theme.Parse( data, self )

    self.history:SetDefaultFont( self.fontName )
    self.history:SetFontShadowEnabled( self.enableFontShadow )
    self.history:SetEnableAnimations( self.enableSlideAnimation )
    self.history:SetEnableAvatars( self.enableAvatars )

    self.history:SetBackgroundColor( self.inputBackgroundColor )
    self.history:SetScrollBarColor( self.scrollBarColor )
    self.history:SetScrollBackgroundColor( self.scrollBackgroundColor )
    self.history:SetHighlightColor( self.highlightColor )

    self:DockPadding( self.padding, self.padding + 24, self.padding, self.padding )

    self.entry:SetTextColor( self.inputColor )
    self.entry:SetCursorColor( self.inputColor )
    self.entry:SetHighlightColor( self.highlightColor )

    self.entryDock._backgroundColor = self.inputBackgroundColor
    self.channelListBackgroundColor = self.inputBackgroundColor

    self:UpdateChannelList()
    self:InvalidateChildren()
end

function PANEL:AppendContents( contents, channelId, showTimestamp )
    local channel = self.channels[channelId]
    if not channel then return end

    if self.lastChannelId ~= channelId then
        channel.missedCount = channel.missedCount + 1
    end

    if channel.missedCount > 0 then
        self:SetChannelNotificationCount( channelId, channel.missedCount )
    end

    self.history:AppendContents( contents, channelId, showTimestamp )
end

function PANEL:AppendAtCaret( text )
    local oldText = self.entry:GetText()
    local caretPos = self.entry:GetCaretPos() 
    local newText = utf8.sub( oldText, 1, caretPos ) .. text .. utf8.sub( oldText, caretPos + 1 )

    if utf8.len( newText ) < self.entry:GetMaximumCharCount() then
        self.entry:SetText( newText )
        self.entry:SetCaretPos( caretPos + utf8.len( text ) )
    else
        surface.PlaySound( "resource/warning.wav" )
    end
end

function PANEL:SubmitMessage()
    local text = CustomChat.CleanupString( self.entry:GetText() )

    if string.len( text ) > 0 then
        local history = self.entry.History
        table.RemoveByValue( history, text )

        local historyCount = #history
        history[historyCount + 1] = text

        if historyCount >= 50 then
            table.remove( history, 1 )
        end
    end

    self.entry:SetText( "" )
    self.OnSubmitMessage( text, self.lastChannelId, self.localMode:IsVisible() and self.localMode.mode.id or false )
end

function PANEL:OpenDirectMessage()
    if CustomChat.GetConVarInt( "enable_dms", 1 ) == 0 then
        Derma_Message( L"server_dms_disabled", L"open_dm", L"ok" )

        return
    end

    if IsValid( self.frameOpenDM ) then
        self.frameOpenDM:Close()
    end

    local frame = vgui.Create( "DFrame" )
    frame:SetSize( 380, 300 )
    frame:SetTitle( L"channel.open_dm" )
    frame:ShowCloseButton( true )
    frame:SetDeleteOnClose( true )
    frame:MakePopup()

    frame.OnClose = function()
        self.frameOpenDM = nil
    end

    self.frameOpenDM = frame
    CustomChat:PutFrameToTheSide( frame )

    local playersScroll = vgui.Create( "DScrollPanel", frame )
    playersScroll:Dock( FILL )
    playersScroll.pnlCanvas:DockPadding( 4, 4, 4, 4 )

    local scrollColor = Color( 30, 30, 30 )

    playersScroll.Paint = function( _, w, h )
        draw.RoundedBox( 4, 0, 0, w, h, scrollColor )
    end

    local targets = {}
    local localPly = LocalPlayer()

    -- Filter existing DMs
    for _, ply in ipairs( player.GetHumans() ) do
        if ply ~= localPly and not self.channels[ply:SteamID()] then
            targets[#targets + 1] = ply
        end
    end

    if #targets == 0 then
        frame:SetTall( 80 )
        CustomChat:PutFrameToTheSide( frame )

        local label = vgui.Create( "DLabel", frame )
        label:Dock( FILL )
        label:SetTextColor( Color( 255, 255, 255 ) )
        label:SetContentAlignment( 5 )
        label:SetText( L"channel.no_dm_targets" )

        return
    end

    local bgColor = Color( 0, 0, 0 )
    local nameColor = Color( 255, 255, 255 )

    local PaintLine = function( s, w, h )
        draw.RoundedBox( 4, 0, 0, w, h, bgColor )
        draw.SimpleText( s._name, "Trebuchet18", 36, h * 0.5, nameColor, 0, 1 )
    end

    local ClickLine = function( s )
        frame:Close()

        if IsValid( s._ply ) then
            local channel = self:CreateChannel( s._id, s._name, s._ply )
            channel.isDM = true

            self:SetActiveChannel( s._id )
        end
    end

    local function UpdateList( filter )
        playersScroll:Clear()

        for _, ply in ipairs( targets ) do
            local playerName = ply:Nick()

            if not filter or playerName:lower():find( filter, 1, true ) then
                local line = vgui.Create( "DPanel", playersScroll )
                line:SetCursor( "hand" )
                line:SetTall( 32 )
                line:Dock( TOP )
                line:DockMargin( 0, 0, 0, 2 )

                line._ply = ply
                line._id = ply:SteamID()
                line._name = playerName
                line.Paint = PaintLine
                line.OnMousePressed = ClickLine

                local avatar = vgui.Create( "AvatarImage", line )
                avatar:Dock( LEFT )
                avatar:DockMargin( 4, 4, 4, 4 )
                avatar:SetWide( 24 )
                avatar:SetPlayer( ply, 64 )
            end
        end
    end

    UpdateList()

    local entryFilter = vgui.Create( "DTextEntry", frame )
    entryFilter:SetTabbingDisabled( true )
    entryFilter:SetDrawLanguageID( false )
    entryFilter:SetPlaceholderText( "custom_chat.channel.dm_player_filter" )
    entryFilter:Dock( BOTTOM )

    entryFilter.OnChange = function( s )
        local text = s:GetText():Trim():lower()
        if text:len() < 1 then text = nil end

        UpdateList( text )
    end
end

local MAT_BLUR = Material( "pp/blurscreen" )

function PANEL:Paint( w, h )
    if not self.isChatOpen then return end

    if self.backgroundBlur > 0 then
        surface.SetDrawColor( 255, 255, 255, 255 )
        surface.SetMaterial( MAT_BLUR )

        MAT_BLUR:SetFloat( "$blur", self.backgroundBlur )
        MAT_BLUR:Recompute()

        render.UpdateScreenEffectTexture()

        local x, y = self:LocalToScreen( 0, 0 )
        surface.DrawTexturedRect( -x, -y, ScrW(), ScrH() )
    end

    draw.RoundedBox( self.cornerRadius, 0, 0, w, h, self.backgroundColor )
end

function PANEL.OnSubmitMessage( _text, _channelId, _localModeId ) end
function PANEL.OnRightClick( _data ) end

vgui.Register( "CustomChat_Frame", PANEL, "DFrame" )
