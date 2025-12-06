-- Game Configuration Screen
-- Allows player to configure map size, enemies, and tileset before starting

local GameConfig = {}

-- Game is a global defined in main.lua

-- Configuration state
local config = {
    mapSize = 64,        -- 64, 128, 192, 256
    tileset = "summer",  -- "summer", "winter"
    enemies = {
        { name = "Blinky", personality = "blinky" }
    }
}

-- Available options
local mapSizes = {64, 128, 192, 256}
local tilesets = {"summer", "winter"}
local personalities = {
    { name = "Blinky", id = "blinky", desc = "Aggressive rusher" },
    { name = "Pinky", id = "pinky", desc = "Balanced builder" },
    { name = "Inky", id = "inky", desc = "Defensive turtler" },
    { name = "Clyde", id = "clyde", desc = "Unpredictable" },
    { name = "Random", id = "random", desc = "Random personality" },
    { name = "Passive", id = "passive", desc = "Never attacks" },
}

-- UI state
local hoveredElement = nil
local activeDropdown = nil  -- { enemyIndex = n } or nil
local scrollY = 0

-- UI Colors (stone theme)
local UI = {
    panelBg = {0.15, 0.12, 0.1, 0.95},
    panelBorder = {0.4, 0.35, 0.25, 1},
    buttonBg = {0.25, 0.2, 0.15, 1},
    buttonHover = {0.35, 0.28, 0.2, 1},
    buttonBorder = {0.5, 0.45, 0.35, 1},
    buttonBorderHover = {0.8, 0.7, 0.4, 1},
    textLight = {0.92, 0.88, 0.78, 1},
    textGold = {1, 0.85, 0.4, 1},
    textMuted = {0.6, 0.55, 0.45, 1},
    sectionBg = {0.18, 0.15, 0.12, 1},
    dropdownBg = {0.2, 0.17, 0.14, 1},
    selectedBg = {0.3, 0.25, 0.18, 1},
}

-- Button definitions
local buttons = {}
local enemyButtons = {}
local dropdownButtons = {}

function GameConfig.load()
    -- Reset to defaults
    config = {
        mapSize = 64,
        tileset = "summer",
        enemies = {
            { name = "Blinky", personality = "blinky" }
        }
    }
    activeDropdown = nil
    hoveredElement = nil
    
    GameConfig.buildUI()
end

function GameConfig.buildUI()
    buttons = {}
    enemyButtons = {}
    
    local screenW, screenH = love.graphics.getDimensions()
    local panelW, panelH = 500, 520
    local panelX = (screenW - panelW) / 2
    local panelY = (screenH - panelH) / 2
    
    local contentX = panelX + 30
    local btnW = 80
    local btnH = 32
    
    -- Map size buttons
    local mapSizeY = panelY + 100
    for i, size in ipairs(mapSizes) do
        table.insert(buttons, {
            x = contentX + (i-1) * (btnW + 10),
            y = mapSizeY,
            w = btnW,
            h = btnH,
            text = size .. "x" .. size,
            action = function() config.mapSize = size end,
            isSelected = function() return config.mapSize == size end,
            category = "mapSize"
        })
    end
    
    -- Tileset buttons
    local tilesetY = panelY + 180
    for i, tileset in ipairs(tilesets) do
        local displayName = tileset:sub(1,1):upper() .. tileset:sub(2)
        table.insert(buttons, {
            x = contentX + (i-1) * (btnW + 10),
            y = tilesetY,
            w = btnW,
            h = btnH,
            text = displayName,
            action = function() config.tileset = tileset end,
            isSelected = function() return config.tileset == tileset end,
            category = "tileset"
        })
    end
    
    -- Add/Remove enemy buttons
    local enemyY = panelY + 260
    table.insert(buttons, {
        x = contentX + 350,
        y = enemyY - 5,
        w = 30,
        h = 26,
        text = "+",
        action = function()
            if #config.enemies < 4 then
                table.insert(config.enemies, { name = "Random", personality = "random" })
                GameConfig.buildUI()
            end
        end,
        isSelected = function() return false end,
        category = "enemyControl"
    })
    
    table.insert(buttons, {
        x = contentX + 385,
        y = enemyY - 5,
        w = 30,
        h = 26,
        text = "-",
        action = function()
            if #config.enemies > 0 then
                table.remove(config.enemies)
                GameConfig.buildUI()
            end
        end,
        isSelected = function() return false end,
        category = "enemyControl"
    })
    
    -- Enemy name buttons (clickable to show dropdown)
    for i, enemy in ipairs(config.enemies) do
        table.insert(enemyButtons, {
            x = contentX,
            y = enemyY + 30 + (i-1) * 40,
            w = 200,
            h = 32,
            enemyIndex = i,
            text = enemy.name
        })
    end
    
    -- Bottom buttons
    local bottomY = panelY + panelH - 60
    table.insert(buttons, {
        x = panelX + 80,
        y = bottomY,
        w = 140,
        h = 45,
        text = "Start Game",
        action = function()
            GameConfig.startGame()
        end,
        isSelected = function() return false end,
        category = "action",
        primary = true
    })
    
    table.insert(buttons, {
        x = panelX + panelW - 220,
        y = bottomY,
        w = 140,
        h = 45,
        text = "Back",
        action = function()
            Game.SceneManager.switch("title")
        end,
        isSelected = function() return false end,
        category = "action"
    })
end

function GameConfig.startGame()
    -- Build game options from config
    local gameOptions = {
        mapSize = config.mapSize,
        tileset = config.tileset,
        enemies = {}
    }
    
    -- Convert enemy config to game format
    for i, enemy in ipairs(config.enemies) do
        local personality = enemy.personality
        if personality == "random" then
            local options = {"blinky", "pinky", "inky", "clyde"}
            personality = options[math.random(#options)]
        end
        table.insert(gameOptions.enemies, {
            personality = personality
        })
    end
    
    -- Start gameplay with options
    Game.SceneManager.switch("gameplay", gameOptions)
end

function GameConfig.update(dt)
    local mx, my = love.mouse.getPosition()
    hoveredElement = nil
    
    -- Check button hovers
    for _, btn in ipairs(buttons) do
        if mx >= btn.x and mx <= btn.x + btn.w and
           my >= btn.y and my <= btn.y + btn.h then
            hoveredElement = btn
        end
    end
    
    -- Check enemy button hovers
    if not activeDropdown then
        for _, btn in ipairs(enemyButtons) do
            if mx >= btn.x and mx <= btn.x + btn.w and
               my >= btn.y and my <= btn.y + btn.h then
                hoveredElement = btn
            end
        end
    end
    
    -- Check dropdown hovers
    if activeDropdown then
        for _, btn in ipairs(dropdownButtons) do
            if mx >= btn.x and mx <= btn.x + btn.w and
               my >= btn.y and my <= btn.y + btn.h then
                hoveredElement = btn
            end
        end
    end
end

function GameConfig.draw()
    local screenW, screenH = love.graphics.getDimensions()
    
    -- Background
    love.graphics.setColor(0.08, 0.06, 0.05, 1)
    love.graphics.rectangle("fill", 0, 0, screenW, screenH)
    
    -- Subtle pattern
    love.graphics.setColor(0.1, 0.08, 0.07, 0.5)
    for y = 0, screenH, 20 do
        for x = 0, screenW, 20 do
            if (x + y) % 40 == 0 then
                love.graphics.rectangle("fill", x, y, 10, 10)
            end
        end
    end
    
    -- Main panel
    local panelW, panelH = 500, 520
    local panelX = (screenW - panelW) / 2
    local panelY = (screenH - panelH) / 2
    
    -- Panel shadow
    love.graphics.setColor(0, 0, 0, 0.5)
    love.graphics.rectangle("fill", panelX + 6, panelY + 6, panelW, panelH, 8)
    
    -- Panel background
    love.graphics.setColor(UI.panelBg)
    love.graphics.rectangle("fill", panelX, panelY, panelW, panelH, 8)
    
    -- Panel border
    love.graphics.setColor(UI.panelBorder)
    love.graphics.setLineWidth(3)
    love.graphics.rectangle("line", panelX, panelY, panelW, panelH, 8)
    
    -- Title
    love.graphics.setFont(Game.fonts.large or Game.fonts.medium)
    love.graphics.setColor(UI.textGold)
    local title = "New Game"
    local titleW = (Game.fonts.large or Game.fonts.medium):getWidth(title)
    love.graphics.print(title, panelX + (panelW - titleW) / 2, panelY + 25)
    
    -- Decorative line
    love.graphics.setColor(0.5, 0.45, 0.35, 0.6)
    love.graphics.setLineWidth(2)
    love.graphics.line(panelX + 40, panelY + 65, panelX + panelW - 40, panelY + 65)
    
    local contentX = panelX + 30
    
    -- Section: Map Size
    love.graphics.setFont(Game.fonts.medium)
    love.graphics.setColor(UI.textLight)
    love.graphics.print("Map Size", contentX, panelY + 75)
    
    -- Section: Tileset
    love.graphics.print("Tileset", contentX, panelY + 155)
    
    -- Section: Enemies
    love.graphics.print("Opponents", contentX, panelY + 235)
    love.graphics.setFont(Game.fonts.small)
    love.graphics.setColor(UI.textMuted)
    love.graphics.print("(click name to change)", contentX + 100, panelY + 240)
    
    -- Draw all buttons
    for _, btn in ipairs(buttons) do
        GameConfig.drawButton(btn)
    end
    
    -- Draw enemy buttons
    for _, btn in ipairs(enemyButtons) do
        GameConfig.drawEnemyButton(btn)
    end
    
    -- Draw dropdown if active
    if activeDropdown then
        GameConfig.drawDropdown()
    end
    
    love.graphics.setColor(1, 1, 1, 1)
end

function GameConfig.drawButton(btn)
    local isHovered = hoveredElement == btn
    local isSelected = btn.isSelected and btn.isSelected()
    
    -- Background
    if isSelected then
        love.graphics.setColor(0.4, 0.32, 0.2, 1)
    elseif isHovered then
        love.graphics.setColor(UI.buttonHover)
    else
        love.graphics.setColor(UI.buttonBg)
    end
    love.graphics.rectangle("fill", btn.x, btn.y, btn.w, btn.h, 4)
    
    -- Border
    if isSelected or (btn.primary and isHovered) then
        love.graphics.setColor(UI.buttonBorderHover)
    elseif isHovered then
        love.graphics.setColor(0.6, 0.55, 0.4, 1)
    else
        love.graphics.setColor(UI.buttonBorder)
    end
    love.graphics.setLineWidth(2)
    love.graphics.rectangle("line", btn.x, btn.y, btn.w, btn.h, 4)
    
    -- Text
    love.graphics.setFont(Game.fonts.small)
    if isSelected then
        love.graphics.setColor(UI.textGold)
    elseif isHovered then
        love.graphics.setColor(1, 0.95, 0.85, 1)
    else
        love.graphics.setColor(UI.textLight)
    end
    local textW = Game.fonts.small:getWidth(btn.text)
    local textH = Game.fonts.small:getHeight()
    love.graphics.print(btn.text, btn.x + (btn.w - textW) / 2, btn.y + (btn.h - textH) / 2)
end

function GameConfig.drawEnemyButton(btn)
    local isHovered = hoveredElement == btn
    local isActive = activeDropdown and activeDropdown.enemyIndex == btn.enemyIndex
    
    -- Background
    if isActive then
        love.graphics.setColor(0.35, 0.3, 0.22, 1)
    elseif isHovered then
        love.graphics.setColor(UI.buttonHover)
    else
        love.graphics.setColor(UI.sectionBg)
    end
    love.graphics.rectangle("fill", btn.x, btn.y, btn.w, btn.h, 4)
    
    -- Border
    if isActive or isHovered then
        love.graphics.setColor(UI.buttonBorderHover)
    else
        love.graphics.setColor(UI.buttonBorder)
    end
    love.graphics.setLineWidth(1)
    love.graphics.rectangle("line", btn.x, btn.y, btn.w, btn.h, 4)
    
    -- Enemy number
    love.graphics.setFont(Game.fonts.small)
    love.graphics.setColor(UI.textMuted)
    love.graphics.print(btn.enemyIndex .. ".", btn.x + 8, btn.y + 8)
    
    -- Enemy name
    love.graphics.setColor(UI.textGold)
    love.graphics.print(btn.text, btn.x + 30, btn.y + 8)
    
    -- Dropdown arrow
    love.graphics.setColor(UI.textMuted)
    local arrowX = btn.x + btn.w - 20
    local arrowY = btn.y + btn.h / 2
    love.graphics.polygon("fill", arrowX, arrowY - 3, arrowX + 8, arrowY - 3, arrowX + 4, arrowY + 4)
    
    -- Personality description
    local enemy = config.enemies[btn.enemyIndex]
    if enemy then
        for _, p in ipairs(personalities) do
            if p.id == enemy.personality then
                love.graphics.setColor(UI.textMuted)
                love.graphics.setFont(Game.fonts.small)
                love.graphics.print(p.desc, btn.x + btn.w + 15, btn.y + 8)
                break
            end
        end
    end
end

function GameConfig.drawDropdown()
    if not activeDropdown then return end
    
    local enemyBtn = enemyButtons[activeDropdown.enemyIndex]
    if not enemyBtn then return end
    
    local dropX = enemyBtn.x
    local dropY = enemyBtn.y + enemyBtn.h + 2
    local dropW = enemyBtn.w
    local itemH = 28
    local dropH = #personalities * itemH + 4
    
    -- Build dropdown buttons
    dropdownButtons = {}
    for i, p in ipairs(personalities) do
        table.insert(dropdownButtons, {
            x = dropX + 2,
            y = dropY + 2 + (i-1) * itemH,
            w = dropW - 4,
            h = itemH - 2,
            personality = p,
            enemyIndex = activeDropdown.enemyIndex
        })
    end
    
    -- Shadow
    love.graphics.setColor(0, 0, 0, 0.6)
    love.graphics.rectangle("fill", dropX + 3, dropY + 3, dropW, dropH, 4)
    
    -- Background
    love.graphics.setColor(UI.dropdownBg)
    love.graphics.rectangle("fill", dropX, dropY, dropW, dropH, 4)
    
    -- Border
    love.graphics.setColor(UI.buttonBorder)
    love.graphics.setLineWidth(1)
    love.graphics.rectangle("line", dropX, dropY, dropW, dropH, 4)
    
    -- Items
    for _, btn in ipairs(dropdownButtons) do
        local isHovered = hoveredElement == btn
        local isSelected = config.enemies[btn.enemyIndex].personality == btn.personality.id
        
        if isSelected then
            love.graphics.setColor(UI.selectedBg)
            love.graphics.rectangle("fill", btn.x, btn.y, btn.w, btn.h, 3)
        elseif isHovered then
            love.graphics.setColor(0.28, 0.24, 0.18, 1)
            love.graphics.rectangle("fill", btn.x, btn.y, btn.w, btn.h, 3)
        end
        
        love.graphics.setFont(Game.fonts.small)
        if isSelected then
            love.graphics.setColor(UI.textGold)
        elseif isHovered then
            love.graphics.setColor(1, 0.95, 0.85, 1)
        else
            love.graphics.setColor(UI.textLight)
        end
        love.graphics.print(btn.personality.name, btn.x + 10, btn.y + 5)
    end
end

function GameConfig.mousepressed(x, y, button)
    if button ~= 1 then return end
    
    -- Check dropdown items first
    if activeDropdown then
        for _, btn in ipairs(dropdownButtons) do
            if x >= btn.x and x <= btn.x + btn.w and
               y >= btn.y and y <= btn.y + btn.h then
                -- Select this personality
                config.enemies[btn.enemyIndex].name = btn.personality.name
                config.enemies[btn.enemyIndex].personality = btn.personality.id
                activeDropdown = nil
                GameConfig.buildUI()
                return
            end
        end
        -- Clicked outside dropdown - close it
        activeDropdown = nil
        return
    end
    
    -- Check enemy buttons (opens dropdown)
    for _, btn in ipairs(enemyButtons) do
        if x >= btn.x and x <= btn.x + btn.w and
           y >= btn.y and y <= btn.y + btn.h then
            activeDropdown = { enemyIndex = btn.enemyIndex }
            return
        end
    end
    
    -- Check regular buttons
    for _, btn in ipairs(buttons) do
        if x >= btn.x and x <= btn.x + btn.w and
           y >= btn.y and y <= btn.y + btn.h then
            if btn.action then btn.action() end
            return
        end
    end
end

function GameConfig.mousereleased(x, y, button)
end

function GameConfig.keypressed(key)
    if key == "escape" then
        if activeDropdown then
            activeDropdown = nil
        else
            Game.SceneManager.switch("title")
        end
    elseif key == "return" or key == "kpenter" then
        GameConfig.startGame()
    end
end

function GameConfig.mousemoved(x, y, dx, dy)
end

return GameConfig
