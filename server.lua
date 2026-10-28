-- NovaOS Relay Server v2.0 (Advanced Messenger Edition)
local function runServer()
    local modem = peripheral.find("modem")

    term.setBackgroundColor(colors.black)
    term.clear()
    term.setCursorPos(1, 1)

    if not modem then
        term.setTextColor(colors.red)
        print("[ERROR] Wireless Modem not found on server!")
        print("Attach a wireless modem to any side and reboot.")
        return
    end

    modem.open(65535)

    term.setTextColor(colors.cyan)
    print("=====================================")
    print("   NovaOS Relay Server v2.0 Online   ")
    print("=====================================")
    term.setTextColor(colors.white)
    print("Server ID: " .. os.getComputerID())
    print("Listening on Port: 65535")
    print("Status: [ ONLINE & READY ]")
    print("=====================================")

    local dbFile = "server_chat_db.txt"
    local chatHistory = {}
    local activeUsers = {}

    local function loadDB()
        if fs.exists(dbFile) then
            local f = fs.open(dbFile, "r")
            local data = f.readAll()
            f.close()
            local loaded = textutils.unserialize(data)
            if loaded then chatHistory = loaded end
        end
    end

    local function saveDB()
        local f = fs.open(dbFile, "w")
        f.write(textutils.serialize(chatHistory))
        f.close()
    end

    loadDB()

    while true do
        local event, side, channel, replyChannel, message, distance = os.pullEvent("modem_message")
        
        if type(message) == "table" then
            local senderID = message.senderID or replyChannel
            local action = message.action
            
            -- Обновление статуса онлайн
            if action == "HEARTBEAT" then
                activeUsers[senderID] = {
                    name = message.sender or ("ID:" .. senderID),
                    status = message.status or "Online",
                    lastSeen = os.clock()
                }
                modem.transmit(senderID, 65535, { action = "USERS_LIST", users = activeUsers })
                
            elseif action == "GET_HISTORY" then
                modem.transmit(senderID, 65535, { action = "HISTORY_DATA", history = chatHistory })

            elseif action == "SEND_MSG" or action == "SEND_FILE" then
                local targetID = tonumber(message.target) or 0
                local channelName = message.channel or "general"
                local timeStr = textutils.formatTime(os.time(), true)
                local senderName = message.sender or ("ID:" .. senderID)
                
                term.setTextColor(colors.yellow)
                if action == "SEND_FILE" then
                    print("[" .. timeStr .. "] FILE from " .. senderName .. " -> [" .. message.fileName .. "]")
                else
                    print("[" .. timeStr .. "] [" .. channelName .. "] " .. senderName .. ": " .. (message.text or ""))
                end
                
                local msgPacket = {
                    action = action,
                    sender = senderName,
                    senderID = senderID,
                    target = targetID,
                    channel = channelName,
                    text = message.text,
                    fileName = message.fileName,
                    fileData = message.fileData,
                    timestamp = timeStr
                }
                
                table.insert(chatHistory, msgPacket)
                if #chatHistory > 150 then table.remove(chatHistory, 1) end
                saveDB()
                
                if targetID > 0 then
                    modem.transmit(targetID, 65535, { action = "NEW_MSG", msg = msgPacket })
                    if senderID ~= targetID then
                        modem.transmit(senderID, 65535, { action = "NEW_MSG", msg = msgPacket })
                    end
                else
                    modem.transmit(65535, 65535, { action = "NEW_MSG", msg = msgPacket })
                end
            end
        end
    end
end

runServer()