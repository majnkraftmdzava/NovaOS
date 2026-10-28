-- NovaOS v16.2 GitHub Installer (Complete with Settings & Arcade)
local term = term
local colors = colors
local fs = fs
local os = os
local http = http

term.setBackgroundColor(colors.black)
term.clear()
term.setCursorPos(1, 2)
term.setTextColor(colors.cyan)
print("=== NovaOS GitHub Installer ===")

if not http then
    term.setTextColor(colors.red)
    print("Error: HTTP API is disabled in CC config!")
    print("Enable it in ComputerCraft configuration file.")
    return
end

-- Укажи здесь свои реальные данные GitHub
local GITHUB_USER = "твои_данные_гихаба"
local REPO_NAME = "NovaOS"
local BRANCH = "main"

local baseUrl = "https://raw.githubusercontent.com/" .. GITHUB_USER .. "/" .. REPO_NAME .. "/" .. BRANCH .. "/"

local filesToDownload = {
    "startup",
    "arcade_app",
    "settings_app"
}

for _, filename in ipairs(filesToDownload) do
    term.setTextColor(colors.white)
    io.write("Downloading " .. filename .. "... ")
    
    local url = baseUrl .. filename
    local response = http.get(url)
    
    if response then
        local content = response.readAll()
        response.close()
        
        local file = fs.open(filename, "w")
        file.write(content)
        file.close()
        
        term.setTextColor(colors.lime)
        print("[OK]")
    else
        term.setTextColor(colors.red)
        print("[FAILED]")
    end
end

print("\nInstallation/Update complete!")
print("Rebooting in 2 seconds...")
os.sleep(2)
os.reboot()
