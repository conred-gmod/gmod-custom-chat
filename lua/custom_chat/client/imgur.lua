local Imgur = CustomChat.Imgur or {
    KEY = "c148510ba377a90"
}

CustomChat.Imgur = Imgur


local function onFailure(err)
    CustomChat.Print(("imgur upload failed: %s"):format(tostring(err)))
end

local function onSuccess(body, size, headers, code)
    if code ~= 200 then
        onFailure(("error code: %d"):format(code))
        return
    end

    local decoded_body = util.JSONToTable(body)
    if not decoded_body then
        onFailure("could not json decode body")
        return
    end

    if not decoded_body.success then
        onFailure(("%s: %s"):format(
            decoded_body.status or "unknown status?",
            decoded_body.data and decoded_body.data.error or "unknown error"
        ))
        return
    end

    local url = decoded_body.data and decoded_body.data.link
    if not url then
        onFailure("success but link wasn't found?")
        return
    end

    CustomChat.Print(("imgur uploaded: %s"):format(tostring(url)))
    return url
end


function Imgur:Upload(base64, callback)
    local name, steamid = LocalPlayer():Name(), LocalPlayer():SteamID()

    http.Post("https://api.imgur.com/3/image.json", 
        {
            image = base64,
            type = "base64",
            name = tostring(os.time()),
            title = ("%s - %s"):format(name, steamid),
            description = ("%s (%s) on %s"):format(name, steamid, os.date("%d/%m/%Y at %H:%M")),
        },
        function(...)
            local url = onSuccess(...)
            callback(url) 
        end,
        function(...)
            onFailure(...)
            callback(false) 
        end,
        {
            ["Authorization"] = "Client-ID " .. self.KEY
        }
    )

    CustomChat.Print(("sent picture (%s) to imgur"):format(string.NiceSize(#base64)))
end