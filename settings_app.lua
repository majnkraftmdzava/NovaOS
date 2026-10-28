-- NovaOS Settings App
local term = term
local colors = colors
local os = os
local w, h = term.getSize()

return function(currentUser, users, saveUsersFunc)
    local desktopBgColor = colors.cyan
    local desktopPattern = "solid"
    
    for _, u in ipairs(users) do
        if u.name == currentUser then
            desktopBgColor = u.theme or colors.cyan
            desktopPattern = u.pattern or "solid"
        end
    end

    local function draw()
        term.setBackgroundColor(colors.black)
        term.clear()
        
        term.setTextColor(colors.yellow)
        term.setCursorPos(2, 2)
        term.write("Desktop Settings & Themes:")
        
        term.setTextColor(colors.white)
        term.setCursorPos(2, 4)
        term.write("Select Background Color:")
        
        local themeCols = {colors.cyan, colors.blue, colors.purple, colors.red, colors.green, colors.black, colors.gray}
        for idx, col in ipairs(themeCols) do
            term.setBackgroundColor(col)
            term.setCursorPos(2 + (idx - 1) * 3, 5)
            term.write("   ")
        end
        
        term.setBackgroundColor(colors.black)
        term.setCursorPos(2, 8)
        term.write("Select Wallpaper Pattern:")
        
        term.setBackgroundColor(desktopPattern == "solid" and colors.blue or colors.gray)
        term.setCursorPos(3, 10) term.write(" Solid ")
        
        term.setBackgroundColor(desktopPattern == "stars" and colors.blue or colors.gray)
        term.setCursorPos(12, 10) term.write(" Stars ")
        
        term.setBackgroundColor(desktopPattern == "grid" and colors.blue or colors.gray)
        term.setCursorPos(21, 10) term.write(" Grid ")
        
        term.setBackgroundColor(colors.green)
        term.setTextColor(colors.white)
        term.setCursorPos(3, 13)
        term.write(" [ SAVE & APPLY ] ")
        
        term.setBackgroundColor(colors.red)
        term.setCursorPos(22, 13)
        term.write(" [ EXIT ] ")
    end

    draw()

    while true do
        local event, btn, cx, cy = os.pullEvent("mouse_click")
        if cy == 5 then
            local themeCols = {colors.cyan, colors.blue, colors.purple, colors.red, colors.green, colors.black, colors.gray}
            for idx, col in ipairs(themeCols) do
                local bx = 2 + (idx - 1) * 3
                if cx >= bx and cx < bx + 3 then
                    desktopBgColor = col
                    draw()
                    break
                end
            end
        elseif cy == 10 then
            if cx >= 3 and cx <= 9 then desktopPattern = "solid" draw()
            elseif cx >= 12 and cx <= 18 then desktopPattern = "stars" draw()
            elseif cx >= 21 and cx <= 27 then desktopPattern = "grid" draw() end
        elseif cy == 13 then
            if cx >= 3 and cx <= 19 then
                for _, u in ipairs(users) do
                    if u.name == currentUser then
                        u.theme = desktopBgColor
                        u.pattern = desktopPattern
                        break
                    end
                end
                saveUsersFunc()
                break
            elseif cx >= 22 and cx <= 30 then
                break
            end
        end
    end
end