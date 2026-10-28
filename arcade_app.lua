-- NovaOS Arcade Hub App v2.0 (Fully Working Controls)
local term = term
local colors = colors
local os = os
local keys = keys
local w, h = term.getSize()

return function(currentUser)
    local activeGame = nil
    local snake = {}
    local food = {}
    local dirX, dirY = 1, 0
    local snakeScore = 0

    local function initSnake()
        snake = {
            {x = math.floor(w / 2), y = math.floor(h / 2)},
            {x = math.floor(w / 2) - 1, y = math.floor(h / 2)},
            {x = math.floor(w / 2) - 2, y = math.floor(h / 2)}
        }
        dirX, dirY = 1, 0
        snakeScore = 0
        food = {x = math.random(3, w - 2), y = math.random(4, h - 2)}
    end

    local function draw()
        term.setBackgroundColor(colors.black)
        term.clear()
        
        if activeGame == nil then
            term.setBackgroundColor(colors.purple)
            term.setTextColor(colors.white)
            term.setCursorPos(1, 1)
            term.write(" Nova Arcade Hub" .. string.rep(" ", w - 16))
            
            term.setBackgroundColor(colors.green)
            term.setCursorPos(3, 3) term.write(" 1. Snake Game ")
            
            term.setBackgroundColor(colors.red)
            term.setTextColor(colors.white)
            term.setCursorPos(w - 9, 1) term.write(" [EXIT] ")
        elseif activeGame == "snake" then
            term.setBackgroundColor(colors.orange)
            term.setTextColor(colors.white)
            term.setCursorPos(1, 1)
            term.write(" Score:" .. snakeScore .. " [Press ` to Exit]")
            
            -- Очистка игрового поля
            for r = 3, h do
                term.setCursorPos(1, r)
                term.setBackgroundColor(colors.black)
                term.write(string.rep(" ", w))
            end
            
            -- Рисуем еду
            if food.x and food.y then
                term.setCursorPos(food.x, food.y)
                term.setBackgroundColor(colors.red)
                term.write("O")
            end
            
            -- Рисуем змейку
            for _, seg in ipairs(snake) do
                if seg.x >= 1 and seg.x <= w and seg.y >= 3 and seg.y <= h then
                    term.setCursorPos(seg.x, seg.y)
                    term.setBackgroundColor(colors.lime)
                    term.write(" ")
                end
            end
        end
    end

    draw()
    local timer = os.startTimer(0.15)

    while true do
        local eventData = {os.pullEvent()}
        local event = eventData[1]
        
        if event == "mouse_click" then
            local btn, cx, cy = eventData[2], eventData[3], eventData[4]
            if activeGame == nil then
                if cx >= w - 9 and cx <= w and cy == 1 then break end
                if cy >= 3 and cy <= 4 then 
                    initSnake() 
                    activeGame = "snake" 
                    draw() 
                end
            end
        elseif event == "timer" then
            if activeGame == "snake" then
                local head = {x = snake[1].x + dirX, y = snake[1].y + dirY}
                if head.x < 1 or head.x > w or head.y < 3 or head.y > h then
                    initSnake()
                else
                    local dead = false
                    for _, seg in ipairs(snake) do 
                        if head.x == seg.x and head.y == seg.y then dead = true break end 
                    end
                    if dead then
                        initSnake()
                    else
                        table.insert(snake, 1, head)
                        if head.x == food.x and head.y == food.y then
                            snakeScore = snakeScore + 1
                            food = {x = math.random(3, w - 2), y = math.random(4, h - 2)}
                        else
                            table.remove(snake)
                        end
                    end
                end
                draw()
            end
            timer = os.startTimer(0.15)
        elseif event == "key" then
            local key = eventData[2]
            if key == keys.grave then
                if activeGame ~= nil then
                    activeGame = nil
                    draw()
                else
                    break
                end
            elseif activeGame == "snake" then
                if (key == keys.w or key == 17 or key == keys.up) and dirY == 0 then dirX, dirY = 0, -1
                elseif (key == keys.s or key == 31 or key == keys.down) and dirY == 0 then dirX, dirY = 0, 1
                elseif (key == keys.a or key == 30 or key == keys.left) and dirX == 0 then dirX, dirY = -1, 0
                elseif (key == keys.d or key == 32 or key == keys.right) and dirX == 0 then dirX, dirY = 1, 0 end
            end
        elseif event == "char" and activeGame == "snake" then
            local ch = eventData[2]
            if (ch == "w" or ch == "W") and dirY == 0 then dirX, dirY = 0, -1
            elseif (ch == "s" or ch == "S") and dirY == 0 then dirX, dirY = 0, 1
            elseif (ch == "a" or ch == "A") and dirX == 0 then dirX, dirY = -1, 0
            elseif (ch == "d" or ch == "D") and dirX == 0 then dirX, dirY = 1, 0 end
        end
    end
end