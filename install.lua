term.clear()
term.setCursorPos(1, 1)
term.setTextColor(colors.cyan)
print("=== NovaOS Installer ===")
term.setTextColor(colors.white)

-- Укажи здесь свой ник на GitHub и название репозитория:
local githubUser = "ТВОЙ_НИК"
local githubRepo = "NovaOS"
local branch = "main"

local url = "https://raw.githubusercontent.com/" .. githubUser .. "/" .. githubRepo .. "/" .. branch .. "/startup.lua"

print("Downloading NovaOS core...")

local response = http.get(url)
if response then
    local content = response.readAll()
    response.close()
    
    local file = fs.open("startup", "w")
    file.write(content)
    file.close()
    
    term.setTextColor(colors.green)
    print("NovaOS successfully installed!")
    print("Rebooting computer in 3 seconds...")
    sleep(3)
    os.reboot()
else
    term.setTextColor(colors.red)
    print("Error: Could not download NovaOS.")
    print("Check HTTP Settings in ComputerCraft config.")
end
