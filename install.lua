-- NovaOS Web Installer
local term = term
local colors = colors
local http = http
local fs = fs

local GITHUB_USER = "majnkraftmdzava"
local GITHUB_REPO = "NovaOS"
local BRANCH = "main" -- Поменяй на "master", если ветка называется master

local BASE_URL = "https://raw.githubusercontent.com/" .. GITHUB_USER .. "/" .. GITHUB_REPO .. "/" .. BRANCH .. "/"

term.setBackgroundColor(colors.black)
term.clear()
term.setCursorPos(1, 1)

term.setTextColor(colors.cyan)
print("=====================================")
print("      NovaOS GitHub Installer       ")
print("=====================================")
term.setTextColor(colors.white)

if not http then
    term.setTextColor(colors.red)
    print("[ERROR] HTTP API is disabled!")
    print("Enable 'http_enable' in ComputerCraft config.")
    return
end

local function downloadFile(urlPath, savePath)
    local fullUrl = BASE_URL .. urlPath
    term.setTextColor(colors.yellow)
    print("Downloading: " .. urlPath .. "...")
    
    local response = http.get(fullUrl)
    if response then
        local content = response.readAll()
        response.close()
        
        local f = fs.open(savePath, "w")
        f.write(content)
        f.close()
        
        term.setTextColor(colors.lime)
        print(" -> OK: Saved as '" .. savePath .. "'")
        return true
    else
        term.setTextColor(colors.red)
        print(" -> ERROR: Could not download " .. urlPath)
        return false
    end
end

print("Select installation mode:")
print("1) Client Terminal (startup + messenger)")
print("2) Dedicated Server (server)")
print("3) Full Suite (startup + messenger + server)")
term.setTextColor(colors.yellow)
write("Choice (1-3): ")

local choice = read()

term.clearLine()
print("")

if choice == "1" then
    downloadFile("startup.lua", "startup")
    downloadFile("messenger.lua", "messenger")
    term.setTextColor(colors.lime)
    print("\nClient installed! Type 'reboot' or run 'startup'.")

elseif choice == "2" then
    downloadFile("server.lua", "server")
    term.setTextColor(colors.lime)
    print("\nServer installed! Run 'server' to start.")

elseif choice == "3" then
    downloadFile("startup.lua", "startup")
    downloadFile("messenger.lua", "messenger")
    downloadFile("server.lua", "server")
    term.setTextColor(colors.lime)
    print("\nFull Suite installed successfully!")

else
    term.setTextColor(colors.red)
    print("\nInvalid choice. Installation cancelled.")
end