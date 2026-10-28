-- NovaOS v16.2 Client (Full Complete Core with Server Config & Smooth Audio)
local term = term
local colors = colors
local os = os
local fs = fs
local peripheral = peripheral
local shell = shell
local rs = redstone
local parallel = parallel

local w, h = term.getSize()

local function initModem()
    local modem = peripheral.find("modem")
    if modem then
        if not modem.isOpen(65535) then modem.open(65535) end
        if not modem.isOpen(os.getComputerID()) then modem.open(os.getComputerID()) end
        return true
    end
    return false
end

local function initSpeaker()
    for _, side in ipairs({"top", "bottom", "left", "right", "front", "back"}) do
        if peripheral.getType(side) == "speaker" then return side end
    end
    return nil
end

local hasModem = initModem()
local speakerSide = initSpeaker()
local currentServerID = nil
local serverConfigFile = "server_config.txt"
local hasUnreadNotifications = false

local function loadServerConfig()
    if fs.exists(serverConfigFile) then
        local f = fs.open(serverConfigFile, "r")
        local id = tonumber(f.readLine())
        f.close()
        if id and id > 0 then currentServerID = id end
    end
end

local function saveServerConfig(id)
    currentServerID = tonumber(id)
    local f = fs.open(serverConfigFile, "w")
    f.write(tostring(currentServerID or 0))
    f.close()
end

loadServerConfig()

local function pingServer()
    local modem = peripheral.find("modem")
    if currentServerID and modem then
        modem.transmit(currentServerID, os.getComputerID(), {
            action = "GET_HISTORY",
            sender = "System",
            senderID = os.getComputerID()
        })
        return true
    end
    return false
end

local function playStartupSound()
    if speakerSide then
        local spk = peripheral.wrap(speakerSide)
        if spk then
            spk.playNote("pling", 1.0, 12)
            os.sleep(0.12)
            spk.playNote("pling", 1.0, 16)
            os.sleep(0.12)
            spk.playNote("pling", 1.0, 19)
            os.sleep(0.18)
            spk.playNote("bell", 1.2, 24)
        end
    end
end

local function playShutdownSound()
    if speakerSide then
        local spk = peripheral.wrap(speakerSide)
        if spk then
            spk.playNote("pling", 1.0, 24)
            os.sleep(0.12)
            spk.playNote("pling", 1.0, 19)
            os.sleep(0.12)
            spk.playNote("pling", 1.0, 12)
        end
    end
end

local usersFile = "users.txt"
local users = {
    {name = "Admin", pass = "1234", theme = colors.cyan, pattern = "solid"}
}

local function loadUsers()
    if fs.exists(usersFile) then
        local f = fs.open(usersFile, "r")
        local data = f.readAll()
        f.close()
        local loaded = textutils.unserialize(data)
        if loaded and type(loaded) == "table" and #loaded > 0 then users = loaded end
    else
        local f = fs.open(usersFile, "w")
        f.write(textutils.serialize(users))
        f.close()
    end
end

local function saveUsers()
    local f = fs.open(usersFile, "w")
    f.write(textutils.serialize(users))
    f.close()
end

loadUsers()
local currentUser = nil
local currentUserObj = nil
local desktopBgColor = colors.cyan
local desktopPattern = "solid"

local function drawBootScreen()
    term.setBackgroundColor(colors.black)
    term.clear()
    
    term.setTextColor(colors.cyan)
    term.setCursorPos(math.floor(w/2) - 10, math.floor(h/2) - 3)
    term.write("=== NovaOS v16.2 ===")
    
    term.setTextColor(colors.white)
    term.setCursorPos(math.floor(w/2) - 13, math.floor(h/2) - 1)
    term.write("Connecting to Server...")
    
    local barW = 20
    local barX = math.floor(w/2) - math.floor(barW/2)
    local barY = math.floor(h/2) + 1
    
    term.setCursorPos(barX, barY)
    term.setBackgroundColor(colors.gray)
    term.write(string.rep(" ", barW))
    
    for i = 1, barW do
        term.setCursorPos(barX + i - 1, barY)
        term.setBackgroundColor(colors.cyan)
        term.write(" ")
        os.sleep(0.02)
    end
    
    pingServer()
    os.sleep(0.15)
end

local function loginScreen()
    local selectedUserIdx = 1
    local mode = "select"
    local inputPass = ""
    local newUserName = ""
    local newUserPass = ""
    local regStep = 1
    local errorMsg = ""
    
    while not currentUser do
        term.setBackgroundColor(colors.blue)
        term.clear()
        
        term.setTextColor(colors.white)
        term.setCursorPos(math.floor(w/2) - 10, 2)
        term.write("=== NovaOS Login ===")
        
        if mode == "select" then
            term.setCursorPos(math.floor(w/2) - 11, 5)
            term.setTextColor(colors.yellow)
            term.write("Select User Profile:")
            
            for i, u in ipairs(users) do
                term.setCursorPos(math.floor(w/2) - 8, 7 + i)
                if i == selectedUserIdx then
                    term.setBackgroundColor(colors.cyan)
                    term.setTextColor(colors.black)
                else
                    term.setBackgroundColor(colors.blue)
                    term.setTextColor(colors.white)
                end
                term.write(" > " .. u.name .. string.rep(" ", 15 - #u.name))
            end
            
            term.setBackgroundColor(colors.blue)
            term.setTextColor(colors.lightGray)
            term.setCursorPos(2, h - 2)
            term.write("[Up/Down] Select  [Enter] Login")
            term.setCursorPos(2, h - 1)
            term.write("[N] Register New User")
            
        elseif mode == "password" then
            local u = users[selectedUserIdx]
            term.setCursorPos(math.floor(w/2) - 11, 6)
            term.setTextColor(colors.yellow)
            term.write("Enter Password for:")
            term.setCursorPos(math.floor(w/2) - math.floor(#u.name/2), 8)
            term.setTextColor(colors.white)
            term.write(u.name)
            
            term.setCursorPos(math.floor(w/2) - 10, 10)
            term.setBackgroundColor(colors.black)
            term.write(" [" .. string.rep("*", #inputPass) .. string.rep(" ", 12 - #inputPass) .. "] ")
            
            if errorMsg ~= "" then
                term.setCursorPos(math.floor(w/2) - math.floor(#errorMsg/2), 12)
                term.setTextColor(colors.red)
                term.write(errorMsg)
            end
            
            term.setBackgroundColor(colors.blue)
            term.setTextColor(colors.lightGray)
            term.setCursorPos(2, h - 1)
            term.write("[` (`) Back  [Enter] Confirm")
            
        elseif mode == "register" then
            term.setCursorPos(math.floor(w/2) - 11, 5)
            term.setTextColor(colors.yellow)
            term.write("Create New Account")
            
            term.setCursorPos(math.floor(w/2) - 12, 7)
            term.setTextColor(colors.white)
            if regStep == 1 then
                term.write("Enter Name: " .. newUserName .. "_")
            else
                term.write("User: " .. newUserName)
                term.setCursorPos(math.floor(w/2) - 12, 9)
                term.write("Enter Pass: " .. string.rep("*", #newUserPass) .. "_")
            end
            
            if errorMsg ~= "" then
                term.setCursorPos(math.floor(w/2) - math.floor(#errorMsg/2), 12)
                term.setTextColor(colors.red)
                term.write(errorMsg)
            end
            
            term.setBackgroundColor(colors.blue)
            term.setTextColor(colors.lightGray)
            term.setCursorPos(2, h - 1)
            term.write("[` (`) Cancel  [Enter] Next")
        end
        
        local eventData = {os.pullEvent()}
        local event = eventData[1]
        
        if event == "key" then
            local key = eventData[2]
            errorMsg = ""
            
            if mode == "select" then
                if key == keys.up then
                    selectedUserIdx = selectedUserIdx - 1
                    if selectedUserIdx < 1 then selectedUserIdx = #users end
                elseif key == keys.down then
                    selectedUserIdx = selectedUserIdx + 1
                    if selectedUserIdx > #users then selectedUserIdx = 1 end
                elseif key == keys.enter then
                    local u = users[selectedUserIdx]
                    if u.pass and u.pass ~= "" then
                        mode = "password"
                        inputPass = ""
                    else
                        currentUser = u.name
                        currentUserObj = u
                        desktopBgColor = u.theme or colors.cyan
                        desktopPattern = u.pattern or "solid"
                    end
                elseif key == keys.n or key == keys.N then
                    mode = "register"
                    newUserName = ""
                    newUserPass = ""
                    regStep = 1
                end
                
            elseif mode == "password" then
                if key == keys.backspace and #inputPass > 0 then
                    inputPass = string.sub(inputPass, 1, #inputPass - 1)
                elseif key == keys.enter then
                    local u = users[selectedUserIdx]
                    if inputPass == u.pass then
                        currentUser = u.name
                        currentUserObj = u
                        desktopBgColor = u.theme or colors.cyan
                        desktopPattern = u.pattern or "solid"
                    else
                        errorMsg = "Incorrect Password!"
                        inputPass = ""
                    end
                elseif key == keys.grave then
                    mode = "select"
                    inputPass = ""
                end
                
            elseif mode == "register" then
                if key == keys.grave then
                    mode = "select"
                elseif key == keys.enter then
                    if regStep == 1 then
                        if newUserName == "" then
                            errorMsg = "Name cannot be empty!"
                        else
                            regStep = 2
                        end
                    else
                        local newU = {name = newUserName, pass = newUserPass, theme = colors.cyan, pattern = "solid"}
                        table.insert(users, newU)
                        saveUsers()
                        currentUser = newUserName
                        currentUserObj = newU
                        desktopBgColor = colors.cyan
                        desktopPattern = "solid"
                    end
                elseif key == keys.backspace then
                    if regStep == 1 and #newUserName > 0 then
                        newUserName = string.sub(newUserName, 1, #newUserName - 1)
                    elseif regStep == 2 and #newUserPass > 0 then
                        newUserPass = string.sub(newUserPass, 1, #newUserPass - 1)
                    end
                end
            end
            
        elseif event == "char" then
            local ch = eventData[2]
            if mode == "password" then
                if #inputPass < 12 then inputPass = inputPass .. ch end
            elseif mode == "register" then
                if regStep == 1 and #newUserName < 12 then
                    newUserName = newUserName .. ch
                elseif regStep == 2 and #newUserPass < 12 then
                    newUserPass = newUserPass .. ch
                end
            end
        end
    end
end

local windows = {
    files = { title = "File Explorer", x = 11, y = 6, w = 30, h = 13, visible = false, minimized = false, maximized = false },
    calculator = { title = "Calculator", x = 14, y = 5, w = 24, h = 13, visible = false, minimized = false, maximized = false },
    notepad = { title = "Notepad", x = 12, y = 4, w = 30, h = 13, visible = false, minimized = false, maximized = false },
    help = { title = "NovaHelp", x = 10, y = 5, w = 30, h = 12, visible = false, minimized = false, maximized = false },
    taskmgr = { title = "Task Manager", x = 10, y = 4, w = 30, h = 13, visible = false, minimized = false, maximized = false },
    terminal = { title = "NovaCMD", x = 6, y = 4, w = 32, h = 13, visible = false, minimized = false, maximized = false },
    paint = { title = "Nova Paint", x = 4, y = 3, w = 32, h = 14, visible = false, minimized = false, maximized = false },
    redstone = { title = "Security & RS", x = 12, y = 4, w = 30, h = 13, visible = false, minimized = false, maximized = false },
    stock = { title = "Nova Stock", x = 8, y = 4, w = 30, h = 13, visible = false, minimized = false, maximized = false },
    music = { title = "Music Player", x = 8, y = 4, w = 30, h = 13, visible = false, minimized = false, maximized = false }
}
local windowOrder = {"files", "calculator", "notepad", "help", "taskmgr", "terminal", "paint", "redstone", "stock", "music"}
local activeWindow = nil
local isStartMenuOpen = false
local draggingWindow = nil
local dragOffsetX, dragOffsetY = 0, 0

local musicSelectedSong = 1
local musicSongs = {
    { name = "Happy Tune (Notes)", type = "notes" },
    { name = "lord_verity.dfpwm", type = "dfpwm" }
}
local musicStatus = "Ready"
local musicState = "stopped"
local musicFileHandle = nil
local musicDecoder = nil

local function scanMusicSongs()
    local list = fs.list("")
    for _, f in ipairs(list) do
        if f:match("%.dfpwm$") then
            local exists = false
            for _, s in ipairs(musicSongs) do if s.file == f then exists = true break end end
            if not exists then table.insert(musicSongs, { name = f, type = "dfpwm", file = f }) end
        end
    end
end
scanMusicSongs()

local paintColor = colors.red
local paintCanvas = {}
for r = 1, 10 do
    paintCanvas[r] = {}
    for c = 1, 30 do paintCanvas[r][c] = colors.white end
end

local rsSides = {"top", "bottom", "left", "right", "front", "back"}
local rsStates = {top = false, bottom = false, left = false, right = false, front = false, back = false}

local stocks = {
    {name = "Diamond", price = 100},
    {name = "Gold", price = 50},
    {name = "Iron", price = 20},
    {name = "Redstone", price = 10}
}
local stockShares = {Diamond = 0, Gold = 0, Iron = 0, Redstone = 0}

local function updateStockPrices()
    for _, s in ipairs(stocks) do
        local change = math.random(-5, 5)
        s.price = math.max(1, s.price + change)
    end
end

local cmdHistory = {"Welcome to NovaCMD v1.0", "Type 'help' for commands"}
local cmdInput = ""

local function processCommand(cmd)
    table.insert(cmdHistory, "> " .. cmd)
    local lower = string.lower(cmd)
    if lower == "help" then
        table.insert(cmdHistory, "Available: help, ping, server <id>, list, clear, time, ram, reboot, messenger")
    elseif lower == "clear" then cmdHistory = {}
    elseif lower == "ping" then
        if pingServer() then table.insert(cmdHistory, "Server pinged successfully!") else table.insert(cmdHistory, "Failed to ping server!") end
    elseif string.sub(lower, 1, 7) == "server " then
        local id = tonumber(string.sub(cmd, 8))
        if id then
            saveServerConfig(id)
            table.insert(cmdHistory, "Server ID set to #" .. id)
        else
            table.insert(cmdHistory, "Invalid Server ID!")
        end
    elseif lower == "list" or lower == "dir" then
        local files = fs.list("")
        table.insert(cmdHistory, "Files: " .. table.concat(files, ", "))
    elseif lower == "time" then table.insert(cmdHistory, "Time: " .. textutils.formatTime(os.time(), true))
    elseif lower == "ram" then table.insert(cmdHistory, "RAM Used: " .. math.floor(collectgarbage("count")) .. " KB")
    elseif lower == "messenger" then
        term.setBackgroundColor(colors.black)
        term.clear()
        shell.run("messenger")
        hasUnreadNotifications = false
        render()
    elseif lower == "reboot" then playShutdownSound() os.reboot()
    else table.insert(cmdHistory, "Unknown command: " .. cmd) end
    if #cmdHistory > 10 then table.remove(cmdHistory, 1) end
end

local notepadCurrentFile = "note_default.txt"
local notepadText = ""

local function loadNotepad(filename)
    notepadCurrentFile = filename or ("note_" .. (currentUser or "default") .. ".txt")
    if fs.exists(notepadCurrentFile) then
        local f = fs.open(notepadCurrentFile, "r")
        notepadText = f.readAll() or ""
        f.close()
    else notepadText = "" end
end

local calcDisplay = "0"
local calcHistory = {}

local function addCalcHistory(expr, result)
    table.insert(calcHistory, 1, expr .. "=" .. result)
    if #calcHistory > 3 then table.remove(calcHistory) end
end

local function bringToFront(id)
    for i, v in ipairs(windowOrder) do
        if v == id then
            table.remove(windowOrder, i)
            table.insert(windowOrder, id)
            activeWindow = id
            break
        end
    end
end

local function drawTopBar()
    term.setCursorPos(1, 1)
    term.setBackgroundColor(colors.blue)
    term.setTextColor(colors.white)
    term.write(string.rep(" ", w))
    
    term.setCursorPos(2, 1)
    term.write("NovaOS [" .. currentUser .. "]")
    
    if hasUnreadNotifications then
        term.setTextColor(colors.yellow)
        term.write(" [!] Msg")
    end
    
    -- Кликабельный статус сервера в верхнем баре для настройки
    term.setCursorPos(22, 1)
    if currentServerID then
        term.setTextColor(colors.lime)
        term.write("[Srv:#" .. currentServerID .. "]")
    else
        term.setTextColor(colors.red)
        term.write("[Srv:NOT SET]")
    end
    
    local timeStr = textutils.formatTime(os.time(), true)
    term.setTextColor(colors.white)
    term.setCursorPos(w - #timeStr - 1, 1)
    term.write(timeStr)
end

local function drawButton(x, y, width, height, bg, fg, text)
    term.setBackgroundColor(bg)
    term.setTextColor(fg)
    for i = 0, height - 1 do
        term.setCursorPos(x, y + i)
        term.write(string.rep(" ", width))
    end
    term.setCursorPos(x + math.floor((width - #text) / 2), y + math.floor(height / 2))
    term.write(text)
end

local function drawStartMenu()
    if not isStartMenuOpen then return end
    
    local menuX, menuW = 2, 24
    local menuH = 14
    local menuY = h - menuH
    
    term.setBackgroundColor(colors.lightGray)
    term.setTextColor(colors.black)
    
    for i = 0, menuH - 1 do
        term.setCursorPos(menuX, menuY + i)
        term.write(string.rep(" ", menuW))
    end
    
    term.setCursorPos(menuX + 1, menuY + 1)  term.write("> Task Manager")
    term.setCursorPos(menuX + 1, menuY + 2)  term.write("> Terminal (CMD)")
    term.setCursorPos(menuX + 1, menuY + 3)  term.write("> Nova Paint")
    term.setCursorPos(menuX + 1, menuY + 4)  term.write("> Redstone/Security")
    term.setCursorPos(menuX + 1, menuY + 5)  term.write("> Stock Market")
    term.setCursorPos(menuX + 1, menuY + 6)  term.write("> Calculator")
    term.setCursorPos(menuX + 1, menuY + 7)  term.write("> Notepad File")
    term.setCursorPos(menuX + 1, menuY + 8)  term.write("> File Explorer")
    term.setCursorPos(menuX + 1, menuY + 9)  term.write("> Music Player")
    term.setCursorPos(menuX + 1, menuY + 10) term.write("> Set Server ID")
    term.setCursorPos(menuX + 1, menuY + 11) term.write("> Switch User")
    term.setCursorPos(menuX + 1, menuY + 12) term.write("> Reboot / Exit")
end

local function drawTaskbar()
    term.setBackgroundColor(colors.gray)
    term.setTextColor(colors.white)
    term.setCursorPos(1, h)
    term.write(string.rep(" ", w))
    
    drawButton(2, h, 9, 1, colors.blue, colors.white, " Start ")
    
    local taskX = 12
    for _, id in ipairs(windowOrder) do
        local win = windows[id]
        if win.visible then
            local btnBg = (activeWindow == id and not win.minimized) and colors.lightBlue or colors.blue
            local titleShort = win.title
            if #titleShort > 8 then titleShort = string.sub(titleShort, 1, 6) .. ".." end
            drawButton(taskX, h, #titleShort + 2, 1, btnBg, colors.white, " " .. titleShort .. " ")
            taskX = taskX + #titleShort + 3
        end
    end
end

local function drawAppContent(id, x, y, winW, winH)
    local win = windows[id]
    local scroll = win.scroll or 0

    if id == "paint" then
        term.setBackgroundColor(colors.gray)
        for row = y, y + winH - 1 do
            term.setCursorPos(x, row)
            term.write(string.rep(" ", winW))
        end
        local paletteColors = {colors.red, colors.green, colors.blue, colors.yellow, colors.black, colors.white}
        for idx, col in ipairs(paletteColors) do
            term.setBackgroundColor(col)
            term.setCursorPos(x + (idx - 1) * 3 + 1, y)
            term.write("   ")
        end
        drawButton(x + 20, y, 10, 1, colors.blue, colors.white, "SAVE ART")
        for r = 1, math.min(10, winH - 2) do
            for c = 1, math.min(30, winW - 2) do
                term.setBackgroundColor(paintCanvas[r][c] or colors.white)
                term.setCursorPos(x + c, y + r)
                term.write(" ")
            end
        end
    elseif id == "redstone" then
        term.setBackgroundColor(colors.black)
        for row = y, y + winH - 1 do
            term.setCursorPos(x, row)
            term.write(string.rep(" ", winW))
        end
        term.setTextColor(colors.yellow)
        term.setCursorPos(x + 1, y + 1)
        term.write("Redstone I/O Controller:")
        for idx, s in ipairs(rsSides) do
            local active = rsStates[s]
            local bg = active and colors.green or colors.red
            local status = active and "ON " or "OFF"
            drawButton(x + 2, y + 2 + (idx - 1) * 2, 12, 1, bg, colors.white, s:upper() .. ": " .. status)
        end
    elseif id == "stock" then
        term.setBackgroundColor(colors.black)
        for row = y, y + winH - 1 do
            term.setCursorPos(x, row)
            term.write(string.rep(" ", winW))
        end
        term.setTextColor(colors.yellow)
        term.setCursorPos(x + 1, y + 1)
        term.write("Nova Stock Market")
        for idx, s in ipairs(stocks) do
            term.setTextColor(colors.white)
            term.setCursorPos(x + 1, y + 2 + (idx - 1) * 2)
            term.write(s.name .. ": $" .. s.price .. " (Own: " .. stockShares[s.name] .. ")")
            drawButton(x + winW - 10, y + 2 + (idx - 1) * 2, 4, 1, colors.green, colors.white, "BUY")
            drawButton(x + winW - 5, y + 2 + (idx - 1) * 2, 4, 1, colors.red, colors.white, "SELL")
        end
    elseif id == "music" then
        term.setBackgroundColor(colors.black)
        for row = y, y + winH - 1 do
            term.setCursorPos(x, row)
            term.write(string.rep(" ", winW))
        end
        term.setTextColor(colors.yellow)
        term.setCursorPos(x + 1, y + 1)
        term.write("Audio Player")
        
        for i, s in ipairs(musicSongs) do
            term.setCursorPos(x + 1, y + 2 + i)
            if i == musicSelectedSong then
                term.setBackgroundColor(colors.lightGray)
                term.setTextColor(colors.black)
                term.write(" > " .. s.name .. string.rep(" ", winW - #s.name - 5))
            else
                term.setBackgroundColor(colors.black)
                term.setTextColor(colors.white)
                term.write("   " .. s.name .. string.rep(" ", winW - #s.name - 5))
            end
        end
        term.setBackgroundColor(colors.black)
        term.setTextColor(colors.cyan)
        term.setCursorPos(x + 1, y + winH - 3)
        term.write("Status: " .. musicStatus)
        
        drawButton(x + 1, y + winH - 2, 6, 1, colors.green, colors.white, "PLAY")
        drawButton(x + 8, y + winH - 2, 7, 1, colors.yellow, colors.black, "PAUSE")
        drawButton(x + 16, y + winH - 2, 6, 1, colors.red, colors.white, "STOP")
    elseif id == "terminal" then
        term.setBackgroundColor(colors.black)
        term.setTextColor(colors.green)
        for row = y, y + winH - 1 do
            term.setCursorPos(x, row)
            term.write(string.rep(" ", winW))
        end
        local maxL = winH - 2
        local startIdx = math.max(1, #cmdHistory - maxL + 1)
        local drawRow = y
        for i = startIdx, #cmdHistory do
            term.setCursorPos(x + 1, drawRow)
            term.write(cmdHistory[i])
            drawRow = drawRow + 1
        end
        term.setCursorPos(x + 1, y + winH - 1)
        term.setTextColor(colors.white)
        term.write(">" .. cmdInput .. "_")
    elseif id == "files" then
        term.setBackgroundColor(colors.black)
        for row = y, y + winH - 1 do
            term.setCursorPos(x, row)
            term.write(string.rep(" ", winW))
        end
        term.setBackgroundColor(colors.gray)
        term.setTextColor(colors.white)
        term.setCursorPos(x, y)
        term.write(" File Explorer" .. string.rep(" ", winW - 13))
        local files = fs.list("")
        local maxFiles = winH - 4
        local startF = math.max(1, math.min(scroll + 1, math.max(1, #files - maxFiles + 1)))
        for i = startF, math.min(#files, startF + maxFiles - 1) do
            local file = files[i]
            local rowPos = y + 1 + (i - startF + 1)
            term.setCursorPos(x + 1, rowPos)
            if fs.isDir(file) then term.setTextColor(colors.yellow) term.write("[DIR]  " .. file)
            else term.setTextColor(colors.white) term.write("[FILE] " .. file) end
        end
        drawButton(x, y + winH - 1, winW, 1, colors.blue, colors.white, "[Del] [New]")
    elseif id == "calculator" then
        term.setBackgroundColor(colors.black)
        for row = y, y + winH - 1 do
            term.setCursorPos(x, row)
            term.write(string.rep(" ", winW))
        end
        term.setBackgroundColor(colors.gray)
        term.setCursorPos(x + 2, y + 1)
        term.setTextColor(colors.yellow)
        term.write(calcDisplay)
        local buttons = {{"7", "8", "9", "/"},{"4", "5", "6", "*"},{"1", "2", "3", "-"},{"C", "0", "=", "+"}}
        for r, row in ipairs(buttons) do
            for c, btn in ipairs(row) do
                drawButton(x + 1 + (c - 1) * 5, y + 5 + (r * 2), 4, 2, colors.blue, colors.white, btn)
            end
        end
    elseif id == "notepad" then
        term.setBackgroundColor(colors.white)
        term.setTextColor(colors.black)
        for row = y, y + winH - 2 do
            term.setCursorPos(x, row)
            term.write(string.rep(" ", winW))
        end
        term.setBackgroundColor(colors.lightGray)
        term.setTextColor(colors.blue)
        term.setCursorPos(x, y)
        term.write(" File: " .. notepadCurrentFile)
        term.setBackgroundColor(colors.white)
        term.setCursorPos(x, y + 1)
        term.write(notepadText)
        drawButton(x, y + winH - 1, winW, 1, colors.gray, colors.white, " [ SAVE FILE ] ")
    elseif id == "help" then
        term.setBackgroundColor(colors.black)
        for row = y, y + winH - 1 do
            term.setCursorPos(x, row)
            term.write(string.rep(" ", winW))
        end
        term.setTextColor(colors.yellow)
        term.setCursorPos(x + 2, y + 1) term.write("=== NovaOS v16.2 ===")
        term.setTextColor(colors.white)
        term.setCursorPos(x + 2, y + 3) term.write("- Modular Architecture")
        term.setCursorPos(x + 2, y + 4) term.write("- Server ID Config Restored")
    elseif id == "taskmgr" then
        term.setBackgroundColor(colors.black)
        for row = y, y + winH - 1 do
            term.setCursorPos(x, row)
            term.write(string.rep(" ", winW))
        end
        term.setTextColor(colors.yellow)
        term.setCursorPos(x + 1, y + 1)
        term.write("Active Processes:")
        local rowIdx = 2
        for _, winId in ipairs(windowOrder) do
            local winObj = windows[winId]
            if winObj.visible then
                term.setCursorPos(x + 1, y + rowIdx)
                term.setTextColor(colors.white)
                term.write(winObj.title)
                drawButton(x + winW - 7, y + rowIdx, 6, 1, colors.red, colors.white, " KILL ")
                rowIdx = rowIdx + 1
            end
        end
    end
end

local function drawWindow(id)
    local win = windows[id]
    if not win.visible or win.minimized then return end
    local isActive = (activeWindow == id)
    term.setBackgroundColor(isActive and colors.blue or colors.gray)
    term.setTextColor(colors.white)
    term.setCursorPos(win.x, win.y)
    term.write(" " .. win.title)
    term.setCursorPos(win.x + win.w - 5, win.y)
    term.write("_ □ X")
    drawAppContent(id, win.x, win.y + 1, win.w, win.h - 1)
end

local function drawDesktopIcons()
    drawButton(3, 3, 11, 3, colors.lightBlue, colors.white, "Messenger")
    drawButton(3, 7, 11, 4, colors.green, colors.white, "🎮 Arcade")
    drawButton(15, 7, 7, 4, colors.purple, colors.white, "♫")
    term.setBackgroundColor(desktopBgColor)
    term.setTextColor(colors.white)
    term.setCursorPos(15, 11) term.write(" Music ")
    drawButton(23, 7, 7, 4, colors.yellow, colors.black, "📁")
    term.setCursorPos(23, 11) term.write(" Files ")
    drawButton(3, 13, 10, 3, colors.orange, colors.white, "Calc")
    drawButton(15, 13, 10, 3, colors.gray, colors.white, "Notepad")
    drawButton(26, 13, 8, 3, colors.black, colors.green, ">_CMD")
    drawButton(35, 13, 8, 3, colors.red, colors.white, "Paint")
end

local function drawWallpaper()
    for _, u in ipairs(users) do
        if u.name == currentUser then
            desktopBgColor = u.theme or colors.cyan
            desktopPattern = u.pattern or "solid"
        end
    end
    term.setBackgroundColor(desktopBgColor)
    term.clear()
    if desktopPattern == "stars" then
        term.setTextColor(colors.white)
        for row = 2, h - 1 do
            for col = 1, w do
                if (col * row * 7) % 13 == 0 then term.setCursorPos(col, row) term.write("*") end
            end
        end
    elseif desktopPattern == "grid" then
        term.setTextColor(colors.lightGray)
        for row = 2, h - 1, 2 do term.setCursorPos(1, row) term.write(string.rep("-", w)) end
    end
end

local function render()
    drawWallpaper()
    drawTopBar()
    drawDesktopIcons()
    for _, id in ipairs(windowOrder) do
        if id ~= activeWindow then drawWindow(id) end
    end
    if activeWindow then drawWindow(activeWindow) end
    drawTaskbar()
    drawStartMenu()
end

local function promptServerConfig()
    term.setBackgroundColor(colors.black)
    term.clear()
    term.setCursorPos(math.floor(w/2) - 10, math.floor(h/2) - 2)
    term.setTextColor(colors.yellow)
    term.write("=== Server Configuration ===")
    
    term.setCursorPos(math.floor(w/2) - 12, math.floor(h/2))
    term.setTextColor(colors.white)
    term.write("Enter Server Computer ID:")
    
    term.setCursorPos(math.floor(w/2) - 6, math.floor(h/2) + 2)
    term.setBackgroundColor(colors.gray)
    term.write(" [         ] ")
    
    term.setCursorPos(math.floor(w/2) - 4, math.floor(h/2) + 2)
    term.setTextColor(colors.yellow)
    
    local input = read()
    local id = tonumber(input)
    if id then
        saveServerConfig(id)
    end
    render()
end

local function handleMouseClick(btn, cx, cy)
    if cy == 1 then
        -- Клик по плашке сервера в верхнем баре открывает настройку
        if cx >= 22 and cx <= 33 then
            isStartMenuOpen = false
            promptServerConfig()
            return
        end
    end

    if cy == h then
        if cx >= 2 and cx <= 10 then isStartMenuOpen = not isStartMenuOpen render()
        elseif isStartMenuOpen then isStartMenuOpen = false render() end
    elseif isStartMenuOpen then
        local menuH = 14
        local menuY = h - menuH
        if cx >= 2 and cx <= 25 and cy >= menuY and cy < h then
            local opt = cy - menuY
            isStartMenuOpen = false
            if opt == 1 then windows.taskmgr.visible = true bringToFront("taskmgr") render()
            elseif opt == 2 then windows.terminal.visible = true bringToFront("terminal") render()
            elseif opt == 3 then windows.paint.visible = true bringToFront("paint") render()
            elseif opt == 4 then windows.redstone.visible = true bringToFront("redstone") render()
            elseif opt == 5 then windows.stock.visible = true bringToFront("stock") render()
            elseif opt == 6 then windows.calculator.visible = true bringToFront("calculator") render()
            elseif opt == 7 then windows.notepad.visible = true bringToFront("notepad") render()
            elseif opt == 8 then windows.files.visible = true bringToFront("files") render()
            elseif opt == 9 then windows.music.visible = true bringToFront("music") render()
            elseif opt == 10 then promptServerConfig()
            elseif opt == 11 then currentUser = nil loginScreen() render()
            elseif opt == 12 then playShutdownSound() os.reboot() end
        else isStartMenuOpen = false render() end
    else
        local hitWindow = nil
        for i = #windowOrder, 1, -1 do
            local id = windowOrder[i]
            local win = windows[id]
            if win.visible and not win.minimized then
                if cx >= win.x and cx < win.x + win.w and cy >= win.y and cy < win.y + win.h then
                    hitWindow = id
                    break
                end
            end
        end
        if hitWindow then
            bringToFront(hitWindow)
            local win = windows[hitWindow]
            if cy == win.y then
                local btnAreaX = win.x + win.w - 5
                if cx == btnAreaX then win.minimized = true render()
                elseif cx == btnAreaX + 4 then win.visible = false render()
                elseif cx < btnAreaX then
                    draggingWindow = hitWindow
                    dragOffsetX = cx - win.x
                    dragOffsetY = cy - win.y
                end
            elseif hitWindow == "music" then
                local wx, wy = win.x, win.y + 1
                local songListStart = wy + 3
                local songListEnd = songListStart + #musicSongs - 1
                local btnRow = wy + win.h - 2
                
                if cy >= songListStart and cy <= songListEnd then
                    musicSelectedSong = (cy - songListStart) + 1
                    render()
                elseif cy == btnRow then
                    if cx >= wx + 1 and cx <= wx + 6 then -- PLAY
                        if not speakerSide then
                            musicStatus = "No Speaker!"
                        else
                            local song = musicSongs[musicSelectedSong]
                            if song.type == "notes" then
                                musicState = "stopped"
                                local spk = peripheral.wrap(speakerSide)
                                spk.playNote("pling", 1.0, 12)
                                os.sleep(0.1)
                                spk.playNote("pling", 1.0, 16)
                                os.sleep(0.1)
                                spk.playNote("pling", 1.0, 19)
                                musicStatus = "Finished!"
                            elseif song.type == "dfpwm" and fs.exists(song.file) then
                                if musicState == "paused" then
                                    musicState = "playing"
                                    musicStatus = "Playing..."
                                else
                                    if musicFileHandle then musicFileHandle.close() end
                                    local dfpwm = require("cc.audio.dfpwm")
                                    musicDecoder = dfpwm.make_decoder()
                                    musicFileHandle = fs.open(song.file, "rb")
                                    musicState = "playing"
                                    musicStatus = "Playing..."
                                end
                            end
                        end
                        render()
                    elseif cx >= wx + 8 and cx <= wx + 14 then -- PAUSE
                        if musicState == "playing" then
                            musicState = "paused"
                            musicStatus = "Paused"
                            render()
                        end
                    elseif cx >= wx + 16 and cx <= wx + 21 then -- STOP
                        musicState = "stopped"
                        if musicFileHandle then
                            musicFileHandle.close()
                            musicFileHandle = nil
                        end
                        musicStatus = "Stopped"
                        render()
                    end
                end
            elseif hitWindow == "calculator" then
                local wx, wy = win.x, win.y + 1
                local buttons = {{"7", "8", "9", "/"},{"4", "5", "6", "*"},{"1", "2", "3", "-"},{"C", "0", "=", "+"}}
                for r, row in ipairs(buttons) do
                    for c, btn in ipairs(row) do
                        local bx = wx + 1 + (c - 1) * 5
                        local by = wy + 5 + (r * 2)
                        if cx >= bx and cx < bx + 4 and cy >= by and cy < by + 2 then
                            if btn == "C" then
                                calcDisplay = "0"
                            elseif btn == "=" then
                                local ok, res = pcall(load("return " .. calcDisplay))
                                if ok and res then
                                    calcDisplay = tostring(res)
                                else
                                    calcDisplay = "Error"
                                end
                            else
                                if calcDisplay == "0" or calcDisplay == "Error" then calcDisplay = btn
                                else calcDisplay = calcDisplay .. btn end
                            end
                            render()
                        end
                    end
                end
            end
        else
            if cy >= 3 and cy <= 5 and cx >= 3 and cx <= 13 then
                term.setBackgroundColor(colors.black)
                term.clear()
                shell.run("messenger")
                hasUnreadNotifications = false
                render()
            elseif cy >= 7 and cy <= 10 and cx >= 3 and cx <= 13 then
                term.setBackgroundColor(colors.black)
                term.clear()
                local ok, arcade = pcall(dofile, "arcade_app.lua")
                if ok and type(arcade) == "function" then arcade(currentUser) end
                render()
            elseif cy >= 7 and cy <= 10 and cx >= 15 and cx <= 21 then
                windows.music.visible = true
                bringToFront("music")
                render()
            elseif cy >= 7 and cy <= 10 and cx >= 23 and cx <= 29 then windows.files.visible = true bringToFront("files") render()
            elseif cy >= 13 and cy <= 15 and cx >= 3 and cx <= 12 then windows.calculator.visible = true bringToFront("calculator") render()
            elseif cy >= 13 and cy <= 15 and cx >= 15 and cx <= 24 then windows.notepad.visible = true bringToFront("notepad") render()
            elseif cy >= 13 and cy <= 15 and cx >= 26 and cx <= 34 then windows.terminal.visible = true bringToFront("terminal") render()
            elseif cy >= 13 and cy <= 15 and cx >= 35 and cx <= 43 then windows.paint.visible = true bringToFront("paint") render()
            end
        end
    end
end

local function audioPlayerThread()
    while true do
        if musicState == "playing" and musicFileHandle and speakerSide then
            local spk = peripheral.wrap(speakerSide)
            if spk then
                local chunk = musicFileHandle.read(16 * 1024)
                if chunk then
                    local buffer = musicDecoder(chunk)
                    if buffer then
                        while not spk.playAudio(buffer) do
                            os.pullEvent("speaker_audio_empty")
                        end
                    end
                else
                    musicFileHandle.close()
                    musicFileHandle = nil
                    musicState = "stopped"
                    musicStatus = "Finished!"
                    if windows.music.visible then render() end
                end
            end
        else
            os.sleep(0.1)
        end
    end
end

local function uiEventThread()
    local clockTimer = os.startTimer(1)
    while true do
        hasModem = initModem()
        speakerSide = initSpeaker()
        
        local eventData = {os.pullEvent()}
        local event = eventData[1]
        
        if event == "timer" then
            clockTimer = os.startTimer(1)
            drawTopBar()
            updateStockPrices()
            if windows.stock.visible then render() end
        elseif event == "mouse_click" then
            handleMouseClick(eventData[2], eventData[3], eventData[4])
        elseif event == "mouse_drag" then
            if draggingWindow then
                local btn, cx, cy = eventData[2], eventData[3], eventData[4]
                local win = windows[draggingWindow]
                win.x = math.max(1, math.min(w - win.w + 1, cx - dragOffsetX))
                win.y = math.max(2, math.min(h - 2, cy - dragOffsetY))
                render()
            end
        elseif event == "mouse_up" then
            draggingWindow = nil
        elseif event == "char" then
            local ch = eventData[2]
            if windows.terminal.visible and not windows.terminal.minimized and activeWindow == "terminal" then
                if #cmdInput < windows.terminal.w - 3 then cmdInput = cmdInput .. ch render() end
            elseif windows.notepad.visible and not windows.notepad.minimized and activeWindow == "notepad" then
                notepadText = notepadText .. ch render()
            end
        elseif event == "key" then
            local key = eventData[2]
            if windows.terminal.visible and not windows.terminal.minimized and activeWindow == "terminal" then
                if key == keys.backspace and #cmdInput > 0 then
                    cmdInput = string.sub(cmdInput, 1, #cmdInput - 1)
                    render()
                elseif key == keys.enter and #cmdInput > 0 then
                    processCommand(cmdInput)
                    cmdInput = ""
                    render()
                end
            elseif windows.notepad.visible and not windows.notepad.minimized and activeWindow == "notepad" then
                if key == keys.backspace and #notepadText > 0 then notepadText = string.sub(notepadText, 1, #notepadText - 1) render() end
            end
        elseif event == "modem_message" then
            local msg = eventData[5]
            if type(msg) == "table" then
                if msg.action == "NEW_MSG" or msg.action == "SEND_FILE" then
                    hasUnreadNotifications = true
                    if speakerSide then
                        local spk = peripheral.wrap(speakerSide)
                        if spk then spk.playNote("bell", 1.0, 18) end
                    end
                    render()
                end
            end
        end
    end
end

local function mainOSLoop()
    drawBootScreen()
    loginScreen()
    loadNotepad()
    playStartupSound()
    render()
    
    parallel.waitForAny(audioPlayerThread, uiEventThread)
end

mainOSLoop()
