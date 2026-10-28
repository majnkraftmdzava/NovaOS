-- NovaOS Net Messenger v2.2 (Exit on 'grave' key instead of Esc)
local term = term
local colors = colors
local os = os
local fs = fs
local peripheral = peripheral

local w, h = term.getSize()
local currentChannel = "general"
local currentTargetID = "0"
local myStatus = "Online"
local cipherKey = 3
local messages = {}
local currentMessageInput = ""
local serverConfigFile = "server_config.txt"
local currentServerID = nil

if fs.exists(serverConfigFile) then
    local f = fs.open(serverConfigFile, "r")
    currentServerID = tonumber(f.readLine())
    f.close()
end

local function decryptText(str, key)
    local res = ""
    for i = 1, #str do
        local b = string.byte(str, i)
        res = res .. string.char((b - key) % 256)
    end
    return res
end

local function encryptText(str, key)
    local res = ""
    for i = 1, #str do
        local b = string.byte(str, i)
        res = res .. string.char((b + key) % 256)
    end
    return res
end

local function parseEmoji(text)
    text = string.gsub(text, ":smile:", "☺")
    text = string.gsub(text, ":heart:", "♥")
    text = string.gsub(text, ":like:", "👍")
    text = string.gsub(text, ":diamond:", "◆")
    text = string.gsub(text, ":warn:", "⚠")
    text = string.gsub(text, ":fire:", "🔥")
    return text
end

local modem = peripheral.find("modem")
if modem then
    modem.open(65535)
    modem.open(os.getComputerID())
    if currentServerID then
        modem.transmit(currentServerID, os.getComputerID(), { action = "GET_HISTORY", senderID = os.getComputerID() })
    end
end

local function drawUI()
    term.setBackgroundColor(colors.gray)
    term.clear()
    term.setCursorPos(1, 1)
    term.write(string.rep(" ", w))
    
    -- Кнопки каналов сверху
    term.setBackgroundColor(currentChannel == "general" and colors.blue or colors.gray)
    term.setCursorPos(2, 1) term.write("#gen")
    term.setBackgroundColor(currentChannel == "trade" and colors.blue or colors.gray)
    term.setCursorPos(7, 1) term.write("#trd")
    term.setBackgroundColor(currentChannel == "security" and colors.blue or colors.gray)
    term.setCursorPos(12, 1) term.write("#sec")
    term.setBackgroundColor(currentChannel == "direct" and colors.purple or colors.gray)
    term.setCursorPos(17, 1) term.write("DM")
    
    term.setBackgroundColor(colors.gray)
    term.setTextColor(colors.white)
    term.setCursorPos(22, 1)
    if currentChannel == "direct" then
        term.write("ID:" .. currentTargetID)
    else
        term.write("[" .. myStatus .. "]")
    end
    
    term.setBackgroundColor(colors.white)
    for row = 2, h - 2 do
        term.setCursorPos(1, row)
        term.write(string.rep(" ", w))
    end
    
    local filtered = {}
    for _, m in ipairs(messages) do
        if currentChannel == "direct" then
            if m.target and tonumber(m.target) > 0 then table.insert(filtered, m) end
        else
            if (m.channel or "general") == currentChannel and (not m.target or tonumber(m.target) == 0) then
                table.insert(filtered, m)
            end
        end
    end
    
    local maxL = h - 3
    local startIdx = math.max(1, #filtered - maxL + 1)
    local drawY = 2
    for i = startIdx, #filtered do
        local m = filtered[i]
        if drawY < h - 1 then
            term.setCursorPos(2, drawY)
            if m.isFile then
                term.setTextColor(colors.purple)
                term.write("[FILE] " .. m.sender .. ": " .. (m.fileName or "file"))
            else
                term.setTextColor(colors.black)
                term.write(m.sender .. ": " .. parseEmoji(m.text or ""))
            end
            drawY = drawY + 1
        end
    end
    
    term.setBackgroundColor(colors.gray)
    term.setCursorPos(1, h - 1)
    term.write(string.rep(" ", w))
    term.setCursorPos(2, h - 1)
    term.setTextColor(colors.white)
    term.write("[Press ` (`) to Exit]")
    
    term.setBackgroundColor(colors.black)
    term.setCursorPos(1, h)
    term.write(">" .. currentMessageInput .. string.rep(" ", w - #currentMessageInput - 1))
end

drawUI()

while true do
    local eventData = {os.pullEvent()}
    local event = eventData[1]
    
    if event == "char" then
        if #currentMessageInput < w - 3 then
            currentMessageInput = currentMessageInput .. eventData[2]
            drawUI()
        end
    elseif event == "key" then
        local key = eventData[2]
        if key == keys.enter then
            if currentMessageInput == "exit" then break end
            if modem and currentServerID and #currentMessageInput > 0 then
                modem.transmit(currentServerID, os.getComputerID(), {
                    action = "SEND_MSG",
                    sender = "User" .. os.getComputerID(),
                    senderID = os.getComputerID(),
                    target = (currentChannel == "direct" and tonumber(currentTargetID) or 0),
                    channel = currentChannel,
                    text = encryptText(currentMessageInput, cipherKey)
                })
            end
            currentMessageInput = ""
            drawUI()
        elseif key == keys.backspace and #currentMessageInput > 0 then
            currentMessageInput = string.sub(currentMessageInput, 1, #currentMessageInput - 1)
            drawUI()
        elseif key == keys.grave then -- Клавиша ` (тильда / ё) вместо Esc
            break
        end
    elseif event == "mouse_click" then
        local btn, cx, cy = eventData[2], eventData[3], eventData[4]
        if cy == 1 then
            if cx >= 2 and cx <= 5 then
                currentChannel = "general"
                drawUI()
            elseif cx >= 7 and cx <= 10 then
                currentChannel = "trade"
                drawUI()
            elseif cx >= 12 and cx <= 15 then
                currentChannel = "security"
                drawUI()
            elseif cx >= 17 and cx <= 19 then
                currentChannel = "direct"
                term.setBackgroundColor(colors.black)
                term.setCursorPos(1, h)
                term.clearLine()
                term.write("Enter Target ID: ")
                local tInput = read()
                if tInput and tInput ~= "" then
                    currentTargetID = tInput
                end
                drawUI()
            end
        end
    elseif event == "modem_message" then
        local msg = eventData[5]
        if type(msg) == "table" then
            if msg.action == "NEW_MSG" and msg.msg then
                local m = msg.msg
                table.insert(messages, {
                    sender = m.sender,
                    text = m.text and decryptText(m.text, cipherKey) or "",
                    channel = m.channel,
                    target = m.target,
                    isFile = (m.action == "SEND_FILE"),
                    fileName = m.fileName
                })
                drawUI()
            elseif msg.action == "HISTORY_DATA" and msg.history then
                messages = {}
                for _, m in ipairs(msg.history) do
                    table.insert(messages, {
                        sender = m.sender,
                        text = m.text and decryptText(m.text, cipherKey) or "",
                        channel = m.channel,
                        target = m.target,
                        isFile = (m.action == "SEND_FILE"),
                        fileName = m.fileName
                    })
                end
                drawUI()
            end
        end
    end
end

term.setBackgroundColor(colors.black)
term.clear()
term.setCursorPos(1, 1)