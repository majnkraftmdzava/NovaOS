-- NovaOS v15.2 Client (Replaced Esc with 'grave' key)
local term = term
local colors = colors
local os = os
local fs = fs
local peripheral = peripheral
local shell = shell
local rs = redstone

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

local function loadServerConfig()
    if fs.exists(serverConfigFile) then
        local f = fs.open(serverConfigFile, "r")
        local id = tonumber(f.readLine())
        f.close()
        if id then currentServerID = id end
    end
end

local function saveServerConfig(id)
    currentServerID = tonumber(id)
    local f = fs.open(serverConfigFile, "w")
    f.write(tostring(currentServerID))
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
    term.write("=== NovaOS v15.2 Net ===")
    
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
                elseif key == keys.grave then -- Кнопка ` вместо Esc
                    mode = "select"
                    inputPass = ""
                end
                
            elseif mode == "register" then
                if key == keys.grave then -- Кнопка ` вместо Esc
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

-- Окна системы
local windows = {
    arcade = { title = "Nova Arcade", x = 5, y = 3, w = 30, h = 14, visible = false, minimized = false, maximized = false, prevX = 5, prevY = 3, prevW = 30, prevH = 14, scroll = 0 },
    music = { title = "Audio Player", x = 8, y = 5, w = 32, h = 14, visible = false, minimized = false, maximized = false, prevX = 8, prevY = 5, prevW = 32, prevH = 14, scroll = 0 },
    files = { title = "File Explorer", x = 11, y = 6, w = 30, h = 13, visible = false, minimized = false, maximized = false, prevX = 11, prevY = 6, prevW = 30, prevH = 13, scroll = 0 },
    calculator = { title = "Calculator", x = 14, y = 5, w = 24, h = 13, visible = false, minimized = false, maximized = false, prevX = 14, prevY = 5, prevW = 24, prevH = 13, scroll = 0 },
    notepad = { title = "Notepad", x = 12, y = 4, w = 30, h = 13, visible = false, minimized = false, maximized = false, prevX = 12, prevY = 4, prevW = 30, prevH = 13, scroll = 0 },
    settings = { title = "Network Config", x = 12, y = 5, w = 28, h = 12, visible = false, minimized = false, maximized = false, prevX = 12, prevY = 5, prevW = 28, prevH = 12, scroll = 0 },
    help = { title = "NovaHelp", x = 10, y = 5, w = 30, h = 12, visible = false, minimized = false, maximized = false, prevX = 10, prevY = 5, prevW = 30, prevH = 12, scroll = 0 },
    taskmgr = { title = "Task Manager", x = 10, y = 4, w = 30, h = 13, visible = false, minimized = false, maximized = false, prevX = 10, prevY = 4, prevW = 30, prevH = 13, scroll = 0 },
    terminal = { title = "NovaCMD", x = 6, y = 4, w = 32, h = 13, visible = false, minimized = false, maximized = false, prevX = 6, prevY = 4, prevW = 32, prevH = 13, scroll = 0 },
    paint = { title = "Nova Paint", x = 4, y = 3, w = 32, h = 14, visible = false, minimized = false, maximized = false, prevX = 4, prevY = 3, prevW = 32, prevH = 14, scroll = 0 },
    redstone = { title = "Security & RS", x = 12, y = 4, w = 30, h = 13, visible = false, minimized = false, maximized = false, prevX = 12, prevY = 4, prevW = 30, prevH = 13, scroll = 0 },
    stock = { title = "Nova Stock", x = 8, y = 4, w = 30, h = 13, visible = false, minimized = false, maximized = false, prevX = 8, prevY = 4, prevW = 30, prevH = 13, scroll = 0 }
}
local windowOrder = {"arcade", "music", "files", "calculator", "notepad", "settings", "help", "taskmgr", "terminal", "paint", "redstone", "stock"}
local activeWindow = nil
local draggingWindow = nil
local dragOffX, dragOffY = 0, 0

local isStartMenuOpen = false

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

local activeGame = nil
local snake = {}
local food = {}
local dirX, dirY = 1, 0
local snakeScore = 0
local snakeHighScore = 0

local function getHighScoreFile() return "snake_hi_" .. (currentUser or "default") .. ".txt" end

local function loadHighScore()
    local file = getHighScoreFile()
    if fs.exists(file) then
        local f = fs.open(file, "r")
        snakeHighScore = tonumber(f.readLine()) or 0
        f.close()
    else snakeHighScore = 0 end
end

local function saveHighScore()
    local f = fs.open(getHighScoreFile(), "w")
    f.write(tostring(snakeHighScore))
    f.close()
end

local tttBoard = {"", "", "", "", "", "", "", "", ""}
local tttTurn = "X"
local tttStatus = "Your Turn (X)"

local function checkTttWin()
    local wins = {{1,2,3},{4,5,6},{7,8,9},{1,4,7},{2,5,8},{3,6,9},{1,5,9},{3,5,7}}
    for _, w in ipairs(wins) do
        if tttBoard[w[1]] ~= "" and tttBoard[w[1]] == tttBoard[w[2]] and tttBoard[w[2]] == tttBoard[w[3]] then
            return tttBoard[w[1]]
        end
    end
    local full = true
    for i = 1, 9 do if tttBoard[i] == "" then full = false end end
    if full then return "Draw" end
    return nil
end

local clickerCoins = 50
local clickerMiners = 0
local clickerDills = 0

local targetGuessNum = math.random(1, 100)
local guessAttempts = 0
local guessHint = "Guess 1-100!"
local guessInput = ""

local msGrid = {}
local msRevealed = {}
local msStatus = "Find Mined Cells!"
local function initMinesweeper()
    msGrid = {}
    msRevealed = {}
    msStatus = "Find Mined Cells!"
    for r = 1, 5 do
        msGrid[r] = {}
        msRevealed[r] = {}
        for c = 1, 5 do
            msGrid[r][c] = (math.random(1, 5) == 1) and "M" or "0"
            msRevealed[r][c] = false
        end
    end
end

local cmdHistory = {"Welcome to NovaCMD v1.0", "Type 'help' for commands"}
local cmdInput = ""

local function processCommand(cmd)
    table.insert(cmdHistory, "> " .. cmd)
    local lower = string.lower(cmd)
    if lower == "help" then
        table.insert(cmdHistory, "Available: help, ping, list, clear, time, ram, reboot, messenger")
    elseif lower == "clear" then cmdHistory = {}
    elseif lower == "ping" then
        if pingServer() then table.insert(cmdHistory, "Server pinged successfully!") else table.insert(cmdHistory, "Failed to ping server / No ID!") end
    elseif lower == "list" or lower == "dir" then
        local files = fs.list("")
        table.insert(cmdHistory, "Files: " .. table.concat(files, ", "))
    elseif lower == "time" then table.insert(cmdHistory, "Time: " .. textutils.formatTime(os.time(), true))
    elseif lower == "ram" then table.insert(cmdHistory, "RAM Used: " .. math.floor(collectgarbage("count")) .. " KB")
    elseif lower == "messenger" then
        term.setBackgroundColor(colors.black)
        term.clear()
        shell.run("messenger")
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

local selectedSong = 1
local isPlayingMusic = false
local musicStatusText = "Ready"
local isLoopEnabled = false

local songs = {
    { name = "Nova Odyssey (>1 min)", type = "midi", notes = {{inst="pling", n=12}, {inst="pling", n=14}, {inst="pling", n=16}, {inst="bell", n=24}} },
    { name = "Short Happy Tune", type = "midi", notes = {{inst="harp", n=10}, {inst="harp", n=12}, {inst="harp", n=14}} },
    { name = "Lord Verity (DFPWM Original)", type = "dfpwm", file = "lord_verity.dfpwm" }
}

local function loadCustomSongs()
    local fileList = fs.list("")
    for _, f in ipairs(fileList) do
        if f:match("%.dfpwm$") or f:match("%.wav$") then
            local exists = false
            for _, s in ipairs(songs) do if s.file == f then exists = true break end end
            if not exists then table.insert(songs, { name = f, type = "dfpwm", file = f }) end
        end
    end
end
loadCustomSongs()

local calcDisplay = "0"
local calcHistory = {}

local function addCalcHistory(expr, result)
    table.insert(calcHistory, 1, expr .. "=" .. result)
    if #calcHistory > 3 then table.remove(calcHistory) end
end

local function initSnake()
    snake = {
        {x = math.floor(30 / 2), y = math.floor(13 / 2)},
        {x = math.floor(30 / 2) - 1, y = math.floor(13 / 2)},
        {x = math.floor(30 / 2) - 2, y = math.floor(13 / 2)}
    }
    dirX, dirY = 1, 0
    snakeScore = 0
    food = {x = math.random(2, 28), y = math.random(3, 11)}
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
    term.write("NovaOS v15.2 [" .. currentUser .. "]")
    
    term.setCursorPos(23, 1)
    if currentServerID then
        term.setTextColor(colors.lime)
        term.write("[Srv:#" .. currentServerID .. "]")
    else
        term.setTextColor(colors.red)
        term.write("[Srv:NOT SET]")
    end
    
    local time24 = textutils.formatTime(os.time(), true)
    local time12 = textutils.formatTime(os.time(), false)
    local timeStr = time24 .. " | " .. time12
    
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
    
    local menuX, menuW = 2, 22
    local menuH = 13
    local menuY = h - menuH
    
    term.setBackgroundColor(colors.lightGray)
    term.setTextColor(colors.black)
    
    for i = 0, menuH - 1 do
        term.setCursorPos(menuX, menuY + i)
        term.write(string.rep(" ", menuW))
    end
    
    term.setCursorPos(menuX + 1, menuY + 1) term.write("> Task Manager")
    term.setCursorPos(menuX + 1, menuY + 2) term.write("> Terminal (CMD)")
    term.setCursorPos(menuX + 1, menuY + 3) term.write("> Nova Paint")
    term.setCursorPos(menuX + 1, menuY + 4) term.write("> Redstone/Security")
    term.setCursorPos(menuX + 1, menuY + 5) term.write("> Stock Market")
    term.setCursorPos(menuX + 1, menuY + 6) term.write("> Calculator")
    term.setCursorPos(menuX + 1, menuY + 7) term.write("> Notepad File")
    term.setCursorPos(menuX + 1, menuY + 8) term.write("> File Explorer")
    term.setCursorPos(menuX + 1, menuY + 9) term.write("> Network Config")
    term.setCursorPos(menuX + 1, menuY + 10) term.write("> NovaHelp")
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
        term.write("Nova Stock Market (Coins: $" .. clickerCoins .. ")")
        
        for idx, s in ipairs(stocks) do
            term.setTextColor(colors.white)
            term.setCursorPos(x + 1, y + 2 + (idx - 1) * 2)
            term.write(s.name .. ": $" .. s.price .. " (Own: " .. stockShares[s.name] .. ")")
            drawButton(x + winW - 10, y + 2 + (idx - 1) * 2, 4, 1, colors.green, colors.white, "BUY")
            drawButton(x + winW - 5, y + 2 + (idx - 1) * 2, 4, 1, colors.red, colors.white, "SELL")
        end

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

    elseif id == "arcade" then
        term.setBackgroundColor(colors.black)
        for row = y, y + winH - 1 do
            term.setCursorPos(x, row)
            term.write(string.rep(" ", winW))
        end
        
        if activeGame == nil then
            term.setBackgroundColor(colors.purple)
            term.setTextColor(colors.white)
            term.setCursorPos(x, y)
            term.write(" Nova Arcade Hub" .. string.rep(" ", winW - 16))
            
            drawButton(x + 2, y + 1, winW - 4, 2, colors.green, colors.white, " 1. Snake Game (WASD) ")
            drawButton(x + 2, y + 4, winW - 4, 2, colors.orange, colors.white, " 2. Tic-Tac-Toe ")
            drawButton(x + 2, y + 7, winW - 4, 2, colors.cyan, colors.black, " 3. Resource Clicker ")
            drawButton(x + 2, y + 10, winW - 4, 2, colors.yellow, colors.black, " 4. Guess the Number ")
            drawButton(x + 2, y + 13, winW - 4, 1, colors.red, colors.white, " 5. Minesweeper ")
            
        elseif activeGame == "minesweeper" then
            term.setBackgroundColor(colors.red)
            term.setTextColor(colors.white)
            term.setCursorPos(x, y)
            term.write(" " .. msStatus .. " [Back]" .. string.rep(" ", winW - #msStatus - 8))
            
            for r = 1, 5 do
                for c = 1, 5 do
                    local bx = x + 2 + (c - 1) * 5
                    local by = y + 2 + (r - 1) * 2
                    if msRevealed[r] and msRevealed[r][c] then
                        local val = msGrid[r][c]
                        local bg = (val == "M") and colors.red or colors.lightGray
                        drawButton(bx, by, 4, 2, bg, colors.black, val)
                    else
                        drawButton(bx, by, 4, 2, colors.gray, colors.white, "?")
                    end
                end
            end
            drawButton(x + 2, y + winH - 1, winW - 4, 1, colors.blue, colors.white, " Reset Mines ")

        elseif activeGame == "snake" then
            term.setBackgroundColor(colors.orange)
            term.setTextColor(colors.white)
            term.setCursorPos(x, y)
            term.write(" Score:" .. snakeScore .. " Hi:" .. snakeHighScore .. " [Back]" .. string.rep(" ", winW - 23))
            
            local playH = winH - 1
            for row = y + 1, y + playH do
                term.setCursorPos(x, row)
                term.setBackgroundColor(colors.black)
                term.write(string.rep(" ", winW))
            end
            
            local fx = x + food.x - 1
            local fy = y + 1 + food.y - 1
            if fx >= x and fx < x + winW and fy > y and fy < y + winH then
                term.setCursorPos(fx, fy)
                term.setBackgroundColor(colors.red)
                term.write("O")
            end
            
            for idx, seg in ipairs(snake) do
                local sx = x + seg.x - 1
                local sy = y + 1 + seg.y - 1
                if sx >= x and sx < x + winW and sy > y and sy < y + winH then
                    term.setCursorPos(sx, sy)
                    term.setBackgroundColor(idx == 1 and colors.lime or colors.green)
                    term.write(" ")
                end
            end
            
        elseif activeGame == "tictactoe" then
            term.setBackgroundColor(colors.blue)
            term.setTextColor(colors.white)
            term.setCursorPos(x, y)
            term.write(" " .. tttStatus .. " [Back]" .. string.rep(" ", winW - #tttStatus - 8))
            
            for r = 0, 2 do
                for c = 0, 2 do
                    local idx = r * 3 + c + 1
                    local bx = x + 4 + c * 7
                    local by = y + 3 + r * 3
                    local val = tttBoard[idx]
                    if val == "" then val = "." end
                    drawButton(bx, by, 5, 2, colors.gray, colors.white, val)
                end
            end
            drawButton(x + 4, y + 12, winW - 8, 1, colors.red, colors.white, " Reset Board ")

        elseif activeGame == "clicker" then
            term.setBackgroundColor(colors.cyan)
            term.setTextColor(colors.black)
            term.setCursorPos(x, y)
            term.write(" Resource Clicker [Back]" .. string.rep(" ", winW - 24))
            
            term.setTextColor(colors.yellow)
            term.setCursorPos(x + 2, y + 2)
            term.write("Coins: $" .. clickerCoins)
            
            drawButton(x + 3, y + 4, winW - 6, 3, colors.lime, colors.black, " [ MINE COIN ] ")
            
            drawButton(x + 2, y + 8, winW - 4, 2, colors.gray, colors.white, "Buy Miner ($15) [" .. clickerMiners .. "]")
            drawButton(x + 2, y + 11, winW - 4, 2, colors.gray, colors.white, "Buy Drill ($100) [" .. clickerDills .. "]")

        elseif activeGame == "guessnum" then
            term.setBackgroundColor(colors.yellow)
            term.setTextColor(colors.black)
            term.setCursorPos(x, y)
            term.write(" Guess The Number [Back]" .. string.rep(" ", winW - 24))
            
            term.setCursorPos(x + 2, y + 3)
            term.write(guessHint)
            
            term.setCursorPos(x + 2, y + 5)
            term.write("Attempts: " .. guessAttempts)
            
            term.setCursorPos(x + 2, y + 7)
            term.write("Input: [" .. guessInput .. "_]")
            
            drawButton(x + 4, y + 9, 12, 2, colors.blue, colors.white, " SUBMIT ")
            drawButton(x + 18, y + 9, 8, 2, colors.red, colors.white, " NEW ")
        end

    elseif id == "music" then
        term.setBackgroundColor(colors.black)
        for row = y, y + winH - 1 do
            term.setCursorPos(x, row)
            term.write(string.rep(" ", winW))
        end
        
        term.setBackgroundColor(colors.purple)
        term.setTextColor(colors.white)
        term.setCursorPos(x, y)
        term.write(" Audio Player" .. string.rep(" ", winW - 13))
        
        term.setCursorPos(x + 1, y + 2)
        if speakerSide then
            term.setTextColor(colors.lime)
            term.write("[Speaker OK]")
        else
            term.setTextColor(colors.red)
            term.write("[No Speaker]")
        end
        
        local listHeight = 4
        local startSong = math.max(1, math.min(scroll + 1, math.max(1, #songs - listHeight + 1)))
        for i = startSong, math.min(#songs, startSong + listHeight - 1) do
            local song = songs[i]
            local rowPos = y + 3 + (i - startSong + 1)
            term.setCursorPos(x + 1, rowPos)
            local displayName = song.name
            if #displayName > winW - 4 then displayName = string.sub(displayName, 1, winW - 6) .. ".." end
            
            if i == selectedSong then
                term.setBackgroundColor(colors.lightGray)
                term.setTextColor(colors.black)
                term.write(">" .. displayName .. string.rep(" ", winW - #displayName - 1))
            else
                term.setBackgroundColor(colors.black)
                term.setTextColor(colors.lightGray)
                term.write(" " .. displayName .. string.rep(" ", winW - #displayName - 1))
            end
        end
        
        drawButton(x + 1, y + winH - 5, winW - 2, 1, colors.blue, colors.white, "[ + Load Song / Refresh ]")

        term.setBackgroundColor(colors.black)
        term.setTextColor(colors.cyan)
        term.setCursorPos(x + 1, y + winH - 4)
        term.write(musicStatusText)
        
        term.setCursorPos(x + 1, y + winH - 3)
        term.setTextColor(isLoopEnabled and colors.lime or colors.gray)
        term.write("[Loop: " .. (isLoopEnabled and "ON" or "OFF") .. "]")
        
        drawButton(x + 1, y + winH - 2, 8, 2, colors.green, colors.white, " PLAY ")
        drawButton(x + 10, y + winH - 2, 9, 2, colors.orange, colors.white, " PAUSE ")
        drawButton(x + 20, y + winH - 2, 8, 2, colors.red, colors.white, " STOP ")

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
            if fs.isDir(file) then
                term.setTextColor(colors.yellow)
                term.write("[DIR]  " .. file)
            else
                term.setTextColor(colors.white)
                term.write("[FILE] " .. file)
            end
        end
        
        term.setBackgroundColor(colors.blue)
        term.setTextColor(colors.white)
        term.setCursorPos(x, y + winH - 1)
        local freeSpace = math.floor(fs.getFreeSpace("") / 1024)
        term.write(" Free: " .. freeSpace .. "KB [Del] [New]")

    elseif id == "calculator" then
        term.setBackgroundColor(colors.black)
        for row = y, y + winH - 1 do
            term.setCursorPos(x, row)
            term.write(string.rep(" ", winW))
        end
        
        term.setBackgroundColor(colors.gray)
        term.setTextColor(colors.white)
        term.setCursorPos(x + 1, y + 1)
        term.write(string.rep(" ", winW - 2))
        term.setCursorPos(x + 2, y + 1)
        term.setTextColor(colors.yellow)
        term.write(calcDisplay)
        
        term.setTextColor(colors.lightGray)
        for idx, hist in ipairs(calcHistory) do
            term.setCursorPos(x + 1, y + 2 + idx)
            term.write(hist)
        end
        
        local buttons = {
            {"7", "8", "9", "/"},
            {"4", "5", "6", "*"},
            {"1", "2", "3", "-"},
            {"C", "0", "=", "+"}
        }
        for r, row in ipairs(buttons) do
            for c, btn in ipairs(row) do
                local bx = x + 1 + (c - 1) * 5
                local by = y + 5 + (r * 2)
                drawButton(bx, by, 4, 2, colors.blue, colors.white, btn)
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
        term.write(" File: " .. notepadCurrentFile .. string.rep(" ", winW - #notepadCurrentFile - 7))
        
        term.setBackgroundColor(colors.white)
        local lines = {}
        for line in (notepadText .. "\n"):gmatch("(.-)\n") do
            table.insert(lines, line)
        end
        if #lines == 0 then table.insert(lines, "") end
        
        local maxLines = winH - 3
        local startL = math.max(1, math.min(scroll + 1, math.max(1, #lines - maxLines + 1)))
        
        for i = startL, math.min(#lines, startL + maxLines - 1) do
            term.setCursorPos(x, y + 1 + (i - startL))
            term.write(lines[i])
        end
        
        drawButton(x, y + winH - 1, winW, 1, colors.gray, colors.white, " [ SAVE FILE ] ")

    elseif id == "settings" then
        term.setBackgroundColor(colors.black)
        for row = y, y + winH - 1 do
            term.setCursorPos(x, row)
            term.write(string.rep(" ", winW))
        end
        
        term.setBackgroundColor(colors.gray)
        term.setTextColor(colors.white)
        term.setCursorPos(x, y)
        term.write(" Network Config" .. string.rep(" ", winW - 14))
        
        term.setTextColor(colors.yellow)
        term.setCursorPos(x + 2, y + 2)
        term.write("Current Server ID: " .. (currentServerID or "None"))
        
        drawButton(x + 2, y + 4, winW - 4, 2, colors.blue, colors.white, " SET SERVER ID MANUALLY ")
        drawButton(x + 2, y + 7, winW - 4, 2, colors.green, colors.white, " PING SERVER ")

    elseif id == "help" then
        term.setBackgroundColor(colors.black)
        for row = y, y + winH - 1 do
            term.setCursorPos(x, row)
            term.write(string.rep(" ", winW))
        end
        
        term.setTextColor(colors.yellow)
        term.setCursorPos(x + 2, y + 1) term.write("=== NovaOS v15.2 Net ===")
        term.setTextColor(colors.white)
        term.setCursorPos(x + 2, y + 3) term.write("- Use '`' (grave) to exit apps")
        term.setCursorPos(x + 2, y + 4) term.write("- Run 'messenger' app separately")
        term.setCursorPos(x + 2, y + 7) term.write("Created for CC: Tweaked")

    elseif id == "taskmgr" then
        term.setBackgroundColor(colors.black)
        for row = y, y + winH - 1 do
            term.setCursorPos(x, row)
            term.write(string.rep(" ", winW))
        end
        
        term.setTextColor(colors.yellow)
        term.setCursorPos(x + 1, y + 1)
        term.write("Active Processes & Control:")
        
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
        
        local ramKb = math.floor(collectgarbage("count"))
        term.setTextColor(colors.lightGray)
        term.setCursorPos(x + 1, y + winH - 3)
        term.write("RAM Used: " .. ramKb .. " KB")
        
        local maxBar = winW - 4
        local filled = math.min(maxBar, math.floor((ramKb / 1024) * maxBar))
        term.setCursorPos(x + 2, y + winH - 2)
        term.setBackgroundColor(colors.gray)
        term.write(string.rep(" ", maxBar))
        term.setCursorPos(x + 2, y + winH - 2)
        term.setBackgroundColor(colors.lime)
        term.write(string.rep(" ", filled))
        
        drawButton(x + 1, y + winH - 1, winW - 2, 1, colors.blue, colors.white, " CLEAN RAM (Garbage Collect) ")
    end
end

local function drawWindow(id)
    local win = windows[id]
    if not win.visible or win.minimized then return end
    
    local isActive = (activeWindow == id)
    local titleBg = isActive and colors.blue or colors.gray
    
    term.setBackgroundColor(titleBg)
    term.setTextColor(colors.white)
    term.setCursorPos(win.x, win.y)
    term.write(" " .. win.title)
    
    local btnAreaX = win.x + win.w - 5
    term.setCursorPos(btnAreaX, win.y)
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
    term.setBackgroundColor(desktopBgColor)
    term.setTextColor(colors.white)
    term.setCursorPos(23, 11) term.write(" Files ")

    drawButton(3, 13, 10, 3, colors.orange, colors.white, "Calc")
    drawButton(15, 13, 10, 3, colors.gray, colors.white, "Notepad")
    drawButton(26, 13, 8, 3, colors.black, colors.green, ">_CMD")
    drawButton(35, 13, 8, 3, colors.red, colors.white, "Paint")
end

local function drawWallpaper()
    term.setBackgroundColor(desktopBgColor)
    term.clear()
    
    if desktopPattern == "stars" then
        term.setTextColor(colors.white)
        for row = 2, h - 1 do
            for col = 1, w do
                if (col * row * 7) % 13 == 0 then
                    term.setCursorPos(col, row)
                    term.write("*")
                elseif (col * row * 3) % 17 == 0 then
                    term.setCursorPos(col, row)
                    term.write(".")
                end
            end
        end
    elseif desktopPattern == "grid" then
        term.setTextColor(colors.lightGray)
        for row = 2, h - 1, 2 do
            term.setCursorPos(1, row)
            term.write(string.rep("-", w))
        end
    elseif desktopPattern == "lines" then
        term.setTextColor(colors.blue)
        for col = 1, w, 4 do
            for row = 2, h - 1 do
                term.setCursorPos(col, row)
                term.write("|")
            end
        end
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

local function audioBackgroundProcess()
    local dfpwm = require("cc.audio.dfpwm")
    local decoder = dfpwm.make_decoder()
    
    while true do
        if isPlayingMusic and songs[selectedSong].type == "dfpwm" then
            local filename = songs[selectedSong].file
            if fs.exists(filename) then
                local file = fs.open(filename, "rb")
                local speaker = peripheral.wrap(speakerSide)
                
                while isPlayingMusic and speakerSide do
                    local chunk = file.read(16 * 1024)
                    if not chunk then
                        if isLoopEnabled then
                            file.seek("set", 0)
                            chunk = file.read(16 * 1024)
                        else break end
                    end
                    if chunk then
                        local buffer = decoder(chunk)
                        while not speaker.playAudio(buffer) do os.pullEvent("speaker_audio_empty") end
                    end
                end
                file.close()
                if not isLoopEnabled then
                    isPlayingMusic = false
                    musicStatusText = "Finished"
                    render()
                end
            else
                musicStatusText = "File not found!"
                isPlayingMusic = false
                render()
            end
        end
        os.sleep(0.2)
    end
end

local function handleTimerEvent(timerID, clockTimerRef, snakeTimerRef, clickerTimerRef)
    if timerID == clockTimerRef then
        drawTopBar()
        updateStockPrices()
        if windows.stock.visible then render() end
        return os.startTimer(1)
    elseif timerID == clickerTimerRef then
        clickerCoins = clickerCoins + (clickerMiners * 1) + (clickerDills * 5)
        if windows.arcade.visible and activeGame == "clicker" then render() end
        return os.startTimer(1)
    elseif timerID == snakeTimerRef then
        if windows.arcade.visible and not windows.arcade.minimized and activeGame == "snake" then
            local head = {x = snake[1].x + dirX, y = snake[1].y + dirY}
            local winW, winH = windows.arcade.w, windows.arcade.h - 2
            
            if head.x < 1 or head.x > winW or head.y < 1 or head.y > winH then
                if snakeScore > snakeHighScore then snakeHighScore = snakeScore saveHighScore() end
                initSnake()
            else
                local dead = false
                for _, seg in ipairs(snake) do if head.x == seg.x and head.y == seg.y then dead = true break end end
                if dead then
                    if snakeScore > snakeHighScore then snakeHighScore = snakeScore saveHighScore() end
                    initSnake()
                else
                    table.insert(snake, 1, head)
                    if head.x == food.x and head.y == food.y then
                        snakeScore = snakeScore + 1
                        if snakeScore > snakeHighScore then snakeHighScore = snakeScore saveHighScore() end
                        food = {x = math.random(2, winW - 1), y = math.random(2, winH - 1)}
                    else table.remove(snake) end
                end
            end
            render()
        end
        return os.startTimer(0.2)
    end
    return nil
end

local function handleMouseClick(btn, cx, cy)
    if cy == h then
        if cx >= 2 and cx <= 10 then isStartMenuOpen = not isStartMenuOpen render()
        elseif isStartMenuOpen then isStartMenuOpen = false render()
        else
            local taskX = 12
            for _, id in ipairs(windowOrder) do
                local win = windows[id]
                if win.visible then
                    local titleShort = win.title
                    if #titleShort > 8 then titleShort = string.sub(titleShort, 1, 6) .. ".." end
                    local btnLen = #titleShort + 2
                    if cx >= taskX and cx < taskX + btnLen then
                        if win.minimized then win.minimized = false bringToFront(id)
                        elseif activeWindow == id then win.minimized = true
                        else bringToFront(id) end
                        render()
                        break
                    end
                    taskX = taskX + btnLen + 1
                end
            end
        end
    elseif isStartMenuOpen then
        local menuH = 13
        local menuY = h - menuH
        if cx >= 2 and cx <= 23 and cy >= menuY and cy < h then
            local opt = cy - menuY
            isStartMenuOpen = false
            if opt == 1 then windows.taskmgr.visible = true windows.taskmgr.minimized = false bringToFront("taskmgr") render()
            elseif opt == 2 then windows.terminal.visible = true windows.terminal.minimized = false bringToFront("terminal") render()
            elseif opt == 3 then windows.paint.visible = true windows.paint.minimized = false bringToFront("paint") render()
            elseif opt == 4 then windows.redstone.visible = true windows.redstone.minimized = false bringToFront("redstone") render()
            elseif opt == 5 then windows.stock.visible = true windows.stock.minimized = false bringToFront("stock") render()
            elseif opt == 6 then windows.calculator.visible = true windows.calculator.minimized = false bringToFront("calculator") render()
            elseif opt == 7 then windows.notepad.visible = true windows.notepad.minimized = false bringToFront("notepad") render()
            elseif opt == 8 then windows.files.visible = true windows.files.minimized = false bringToFront("files") render()
            elseif opt == 9 then windows.settings.visible = true windows.settings.minimized = false bringToFront("settings") render()
            elseif opt == 10 then windows.help.visible = true windows.help.minimized = false bringToFront("help") render()
            elseif opt == 11 then currentUser = nil isPlayingMusic = false activeGame = nil loginScreen() loadHighScore() loadNotepad() render()
            elseif opt == 12 then playShutdownSound() os.reboot() end
        else
            isStartMenuOpen = false
            render()
        end
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
                elseif cx == btnAreaX + 2 then
                    if win.maximized then win.maximized = false win.x, win.y, win.w, win.h = win.prevX, win.prevY, win.prevW, win.prevH
                    else win.prevX, win.prevY, win.prevW, win.prevH = win.x, win.y, win.w, win.h win.maximized = true win.x = 1 win.y = 2 win.w = w win.h = h - 2 end
                    render()
                elseif cx == btnAreaX + 4 then win.visible = false render()
                elseif not win.maximized then draggingWindow = hitWindow dragOffX = cx - win.x dragOffY = cy - win.y end
            else
                if hitWindow == "paint" then
                    if cy == win.y + 1 then
                        local paletteColors = {colors.red, colors.green, colors.blue, colors.yellow, colors.black, colors.white}
                        for idx, col in ipairs(paletteColors) do
                            local bx = win.x + (idx - 1) * 3 + 1
                            if cx >= bx and cx < bx + 3 then paintColor = col break end
                        end
                        if cx >= win.x + 20 and cx <= win.x + 30 then
                            local f = fs.open("art_" .. os.time() .. ".txt", "w")
                            f.write(textutils.serialize(paintCanvas))
                            f.close()
                            render()
                        end
                    else
                        local relX = cx - win.x
                        local relY = cy - (win.y + 1)
                        if relY >= 1 and relY <= 10 and relX >= 1 and relX <= 30 then
                            if paintCanvas[relY] and paintCanvas[relY][relX] then
                                paintCanvas[relY][relX] = paintColor
                                render()
                            end
                        end
                    end
                elseif hitWindow == "redstone" then
                    for idx, s in ipairs(rsSides) do
                        local btnY = win.y + 2 + (idx - 1) * 2
                        if cy == btnY and cx >= win.x + 2 and cx <= win.x + 14 then
                            rsStates[s] = not rsStates[s]
                            rs.setOutput(s, rsStates[s])
                            render()
                        end
                    end
                elseif hitWindow == "stock" then
                    for idx, s in ipairs(stocks) do
                        local btnY = win.y + 2 + (idx - 1) * 2
                        if cy == btnY then
                            if cx >= win.x + win.w - 10 and cx <= win.x + win.w - 7 then
                                if clickerCoins >= s.price then
                                    clickerCoins = clickerCoins - s.price
                                    stockShares[s.name] = stockShares[s.name] + 1
                                    render()
                                end
                            elseif cx >= win.x + win.w - 5 and cx <= win.x + win.w - 2 then
                                if stockShares[s.name] > 0 then
                                    stockShares[s.name] = stockShares[s.name] - 1
                                    clickerCoins = clickerCoins + s.price
                                    render()
                                end
                            end
                        end
                    end
                elseif hitWindow == "arcade" then
                    if activeGame == nil then
                        if cy >= win.y + 1 and cy <= win.y + 2 then initSnake() activeGame = "snake" render()
                        elseif cy >= win.y + 4 and cy <= win.y + 5 then tttBoard = {"","","","","","","","",""} tttTurn = "X" tttStatus = "Your Turn (X)" activeGame = "tictactoe" render()
                        elseif cy >= win.y + 7 and cy <= win.y + 8 then activeGame = "clicker" render()
                        elseif cy >= win.y + 10 and cy <= win.y + 11 then targetGuessNum = math.random(1, 100) guessAttempts = 0 guessHint = "Guess 1-100!" guessInput = "" activeGame = "guessnum" render()
                        elseif cy == win.y + 13 then initMinesweeper() activeGame = "minesweeper" render() end
                    elseif activeGame == "minesweeper" then
                        if cx >= win.x + win.w - 8 and cy == win.y then activeGame = nil render()
                        elseif cy == win.y + win.h - 1 then initMinesweeper() render()
                        else
                            for r = 1, 5 do
                                for c = 1, 5 do
                                    local bx = win.x + 2 + (c - 1) * 5
                                    local by = win.y + 2 + (r - 1) * 2
                                    if cx >= bx and cx < bx + 4 and cy >= by and cy < by + 2 then
                                        msRevealed[r][c] = true
                                        if msGrid[r][c] == "M" then msStatus = "BOOM! Game Over" else msStatus = "Safe Cell!" end
                                        render()
                                    end
                                end
                            end
                        end
                    elseif activeGame == "clicker" then
                        if cx >= win.x + win.w - 8 and cy == win.y then activeGame = nil render()
                        elseif cy >= win.y + 4 and cy <= win.y + 6 then clickerCoins = clickerCoins + 1 render()
                        elseif cy >= win.y + 8 and cy <= win.y + 9 then
                            if clickerCoins >= 15 then clickerCoins = clickerCoins - 15 clickerMiners = clickerMiners + 1 render() end
                        elseif cy >= win.y + 11 and cy <= win.y + 12 then
                            if clickerCoins >= 100 then clickerCoins = clickerCoins - 100 clickerDills = clickerDills + 1 render() end
                        end
                    elseif activeGame == "guessnum" then
                        if cx >= win.x + win.w - 8 and cy == win.y then activeGame = nil render()
                        elseif cy >= win.y + 9 and cy <= win.y + 10 then
                            if cx >= win.x + 4 and cx <= win.x + 16 then
                                local gVal = tonumber(guessInput)
                                if gVal then
                                    guessAttempts = guessAttempts + 1
                                    if gVal < targetGuessNum then guessHint = "Higher than " .. gVal .. "!"
                                    elseif gVal > targetGuessNum then guessHint = "Lower than " .. gVal .. "!"
                                    else guessHint = "CORRECT! In " .. guessAttempts .. " tries!" end
                                end
                                guessInput = ""
                                render()
                            elseif cx >= win.x + 18 and cx <= win.x + 26 then
                                targetGuessNum = math.random(1, 100) guessAttempts = 0 guessHint = "Guess 1-100!" guessInput = "" render()
                            end
                        end
                    elseif activeGame == "snake" or activeGame == "tictactoe" then
                        if cx >= win.x + win.w - 8 and cy == win.y then activeGame = nil render()
                        elseif activeGame == "tictactoe" then
                            if cy == win.y + 12 then tttBoard = {"","","","","","","","",""} tttTurn = "X" tttStatus = "Your Turn (X)" render()
                            else
                                for r = 0, 2 do
                                    for c = 0, 2 do
                                        local idx = r * 3 + c + 1
                                        local bx = win.x + 4 + c * 7
                                        local by = win.y + 3 + r * 3
                                        if cx >= bx and cx < bx + 5 and cy >= by and cy < by + 2 then
                                            if tttBoard[idx] == "" and checkTttWin() == nil then
                                                tttBoard[idx] = tttTurn
                                                local winner = checkTttWin()
                                                if winner then
                                                    if winner == "Draw" then tttStatus = "Draw!" else tttStatus = winner .. " Won!" end
                                                else tttTurn = (tttTurn == "X") and "O" or "X" tttStatus = "Turn: " .. tttTurn end
                                                render()
                                            end
                                        end
                                    end
                                end
                            end
                        end
                    end
                elseif hitWindow == "taskmgr" then
                    if cy == win.y + win.h - 1 then
                        collectgarbage("collect")
                        render()
                    else
                        local rowIdx = 2
                        for _, winId in ipairs(windowOrder) do
                            local winObj = windows[winId]
                            if winObj.visible then
                                if cy == win.y + rowIdx and cx >= win.x + win.w - 7 and cx <= win.x + win.w - 1 then
                                    winObj.visible = false
                                    render()
                                    break
                                end
                                rowIdx = rowIdx + 1
                            end
                        end
                    end
                elseif hitWindow == "music" then
                    local scroll = win.scroll or 0
                    local listHeight = 4
                    local startSong = math.max(1, math.min(scroll + 1, math.max(1, #songs - listHeight + 1)))
                    
                    if cy == win.y + win.h - 5 and cx >= win.x + 1 and cx <= win.x + win.w - 2 then loadCustomSongs() musicStatusText = "Songs Refreshed!" render()
                    elseif cy >= win.y + 4 and cy < win.y + 4 + listHeight then
                        local clickedIndex = startSong + (cy - win.y - 4)
                        if clickedIndex <= #songs then selectedSong = clickedIndex render() end
                    elseif cy == win.y + win.h - 3 then isLoopEnabled = not isLoopEnabled render()
                    elseif cy >= win.y + win.h - 2 then
                        if cx >= win.x + 1 and cx <= win.x + 8 then
                            if speakerSide then isPlayingMusic = true musicStatusText = "Playing: " .. songs[selectedSong].name render()
                            else musicStatusText = "No Speaker!" render() end
                        elseif cx >= win.x + 10 and cx <= win.x + 18 then isPlayingMusic = false musicStatusText = "Paused" render()
                        elseif cx >= win.x + 20 and cx <= win.x + 27 then isPlayingMusic = false musicStatusText = "Stopped" render() end
                    end
                elseif hitWindow == "files" then
                    local scroll = win.scroll or 0
                    local files = fs.list("")
                    local maxFiles = win.h - 4
                    local startF = math.max(1, math.min(scroll + 1, math.max(1, #files - maxFiles + 1)))
                    
                    if cy == win.y + win.h - 1 then
                        if cx >= win.x + 9 and cx <= win.x + 14 then
                            printError("Enter filename to delete:")
                            local fName = read()
                            if fName and fs.exists(fName) and not fs.isDir(fName) then fs.delete(fName) end
                            render()
                        elseif cx >= win.x + 16 and cx <= win.x + 21 then
                            printError("Enter new file name:")
                            local fName = read()
                            if fName and not fs.exists(fName) then local f = fs.open(fName, "w") f.write("") f.close() end
                            render()
                        end
                    else
                        local clickedRow = cy - (win.y + 1)
                        local fileIndex = startF + clickedRow - 1
                        if fileIndex <= #files then
                            local targetFile = files[fileIndex]
                            if not fs.isDir(targetFile) then
                                loadNotepad(targetFile)
                                windows.notepad.visible = true windows.notepad.minimized = false bringToFront("notepad") render()
                            end
                        end
                    end
                elseif hitWindow == "calculator" then
                    local buttons = {
                        {"7", "8", "9", "/"},
                        {"4", "5", "6", "*"},
                        {"1", "2", "3", "-"},
                        {"C", "0", "=", "+"}
                    }
                    for r, row in ipairs(buttons) do
                        for c, btn in ipairs(row) do
                            local bx = win.x + 1 + (c - 1) * 5
                            local by = win.y + 5 + (r * 2)
                            if cx >= bx and cx < bx + 4 and cy >= by and cy < by + 2 then
                                if btn == "C" then calcDisplay = "0"
                                elseif btn == "=" then
                                    local ok, res = pcall(load("return " .. calcDisplay))
                                    if ok and res ~= nil then addCalcHistory(calcDisplay, res) calcDisplay = tostring(res) else calcDisplay = "Error" end
                                else
                                    if calcDisplay == "0" or calcDisplay == "Error" then calcDisplay = btn else calcDisplay = calcDisplay .. btn end
                                end
                                render()
                            end
                        end
                    end
                elseif hitWindow == "notepad" then
                    if cy == win.y + win.h - 1 then
                        local f = fs.open(notepadCurrentFile, "w")
                        f.write(notepadText)
                        f.close()
                        render()
                    end
                elseif hitWindow == "settings" then
                    if cy >= win.y + 4 and cy <= win.y + 5 then
                        printError("Enter Server Computer ID:")
                        local sIDInput = read()
                        local numID = tonumber(sIDInput)
                        if numID then
                            saveServerConfig(numID)
                            pingServer()
                        end
                        render()
                    elseif cy >= win.y + 7 and cy <= win.y + 8 then
                        pingServer()
                        render()
                    end
                end
            end
        else
            if cy >= 3 and cy <= 5 and cx >= 3 and cx <= 13 then
                term.setBackgroundColor(colors.black)
                term.clear()
                shell.run("messenger")
                render()
            elseif cy >= 7 and cy <= 10 and cx >= 3 and cx <= 13 then activeGame = nil windows.arcade.visible = true windows.arcade.minimized = false bringToFront("arcade") render()
            elseif cy >= 7 and cy <= 10 and cx >= 15 and cx <= 21 then windows.music.visible = true windows.music.minimized = false bringToFront("music") render()
            elseif cy >= 7 and cy <= 10 and cx >= 23 and cx <= 29 then windows.files.visible = true windows.files.minimized = false bringToFront("files") render()
            elseif cy >= 13 and cy <= 15 and cx >= 3 and cx <= 12 then windows.calculator.visible = true windows.calculator.minimized = false bringToFront("calculator") render()
            elseif cy >= 13 and cy <= 15 and cx >= 15 and cx <= 24 then windows.notepad.visible = true windows.notepad.minimized = false bringToFront("notepad") render()
            elseif cy >= 13 and cy <= 15 and cx >= 26 and cx <= 34 then windows.terminal.visible = true windows.terminal.minimized = false bringToFront("terminal") render()
            elseif cy >= 13 and cy <= 15 and cx >= 35 and cx <= 43 then windows.paint.visible = true windows.paint.minimized = false bringToFront("paint") render()
            end
        end
    end
end

local function mainOSLoop()
    drawBootScreen()
    loginScreen()
    loadHighScore()
    loadNotepad()
    
    playStartupSound()
    render()
    
    local clockTimer = os.startTimer(1)
    local snakeTimer = os.startTimer(0.2)
    local clickerTimer = os.startTimer(1)
    
    while true do
        hasModem = initModem()
        speakerSide = initSpeaker()
        
        local eventData = {os.pullEvent()}
        local event = eventData[1]
        
        if event == "timer" then
            local newTimer = handleTimerEvent(eventData[2], clockTimer, snakeTimer, clickerTimer)
            if newTimer then
                if eventData[2] == clockTimer then clockTimer = newTimer
                elseif eventData[2] == clickerTimer then clickerTimer = newTimer
                else snakeTimer = newTimer end
            end
        elseif event == "mouse_scroll" then
            local scrollDir, cx, cy = eventData[2], eventData[3], eventData[4]
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
                local win = windows[hitWindow]
                win.scroll = (win.scroll or 0) + scrollDir
                if win.scroll < 0 then win.scroll = 0 end
                render()
            end
        elseif event == "mouse_click" then handleMouseClick(eventData[2], eventData[3], eventData[4])
        elseif event == "mouse_drag" then
            local _, cx, cy = eventData[2], eventData[3], eventData[4]
            if draggingWindow then
                local win = windows[draggingWindow]
                if not win.maximized then win.x = cx - dragOffX win.y = cy - dragOffY if win.y < 2 then win.y = 2 end if win.y > h - 3 then win.y = h - 3 end render() end
            end
        elseif event == "mouse_up" then draggingWindow = nil
        elseif event == "char" then
            local ch = eventData[2]
            if windows.terminal.visible and not windows.terminal.minimized and activeWindow == "terminal" then
                if #cmdInput < windows.terminal.w - 3 then cmdInput = cmdInput .. ch render() end
            elseif windows.notepad.visible and not windows.notepad.minimized and activeWindow == "notepad" then
                notepadText = notepadText .. ch
                render()
            elseif windows.arcade.visible and not windows.arcade.minimized and activeWindow == "arcade" then
                if activeGame == "snake" then
                    if (ch == "w" or ch == "W") and dirY == 0 then dirX, dirY = 0, -1
                    elseif (ch == "s" or ch == "S") and dirY == 0 then dirX, dirY = 0, 1
                    elseif (ch == "a" or ch == "A") and dirX == 0 then dirX, dirY = -1, 0
                    elseif (ch == "d" or ch == "D") and dirX == 0 then dirX, dirY = 1, 0 end
                elseif activeGame == "guessnum" then
                    if #guessInput < 3 and tonumber(ch) then guessInput = guessInput .. ch render() end
                end
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
            elseif windows.arcade.visible and not windows.arcade.minimized and activeWindow == "arcade" and activeGame == "snake" then
                if (key == keys.up or key == 200) and dirY == 0 then dirX, dirY = 0, -1
                elseif (key == keys.down or key == 208) and dirY == 0 then dirX, dirY = 0, 1
                elseif (key == keys.left or key == 203) and dirX == 0 then dirX, dirY = -1, 0
                elseif (key == keys.right or key == 205) and dirX == 0 then dirX, dirY = 1, 0 end
            elseif windows.arcade.visible and not windows.arcade.minimized and activeWindow == "arcade" and activeGame == "guessnum" then
                if key == keys.backspace and #guessInput > 0 then guessInput = string.sub(guessInput, 1, #guessInput - 1) render() end
            elseif windows.notepad.visible and not windows.notepad.minimized and activeWindow == "notepad" then
                if key == keys.backspace and #notepadText > 0 then notepadText = string.sub(notepadText, 1, #notepadText - 1) render() end
            end
        end
    end
end

initSnake()
initMinesweeper()
parallel.waitForAll(mainOSLoop, audioBackgroundProcess)