-- Game Configuration Screen
-- Allows player to configure map size, enemies, and tileset before starting

local GameConfig = {}

-- Import cursor
local Cursor = require("cursor")

-- Game is a global defined in main.lua

-- Background image
local bgImage = nil

-- Configuration state
local config = {
    mapSize = 64,        -- 64, 128, 192, 256
    tileset = "summer",  -- "summer", "winter"
    treeDensity = 0.40,  -- 0.20 to 0.60 (sparse to dense)
    riverEnabled = true,
    numBridges = 2,      -- 1 to 4
    riverWidth = 3,      -- 1 to 5
    players = {
        { type = "human", name = "Player 1" },
        { type = "ai", name = "Blinky", personality = "blinky", showFog = false }
    }
}

-- Max players based on map size
local maxPlayersByMapSize = {
    [64] = 2,
    [128] = 4,
    [192] = 6,
    [256] = 8
}

-- Available options
local mapSizes = {64, 128, 192, 256}
local tilesets = {"summer", "winter"}
local bridgeCounts = {1, 2, 3, 4}
local riverWidths = {1, 2, 3, 4, 5}
local treeDensities = {
    {value = 0.20, label = "Sparse"},
    {value = 0.35, label = "Light"},
    {value = 0.50, label = "Medium"},
    {value = 0.65, label = "Dense"},
    {value = 0.80, label = "Forest"},
}
local personalities = {
    { name = "Blinky", id = "blinky", desc = "Aggressive rusher" },
    { name = "Pinky", id = "pinky", desc = "Balanced builder" },
    { name = "Inky", id = "inky", desc = "Defensive turtler" },
    { name = "Clyde", id = "clyde", desc = "Unpredictable" },
    { name = "Random", id = "random", desc = "Random personality" },
    { name = "Passive", id = "passive", desc = "Never attacks" },
}

-- Player slot types
local playerTypes = {
    { id = "human", name = "Human" },
    { id = "ai", name = "AI" },
    { id = "none", name = "None" },
}

-- UI state
local hoveredElement = nil
local activeDropdown = nil  -- { playerIndex = n, dropdownType = "type" or "personality" } or nil
local scrollY = 0

-- UI Colors (moonlight theme - matching title screen)
local UI = {
    panelBg = {0.12, 0.10, 0.15, 0.88},
    panelBorder = {0.45, 0.35, 0.42, 1},
    buttonBg = {0.18, 0.14, 0.22, 1},
    buttonHover = {0.28, 0.22, 0.34, 1},
    buttonBorder = {0.42, 0.35, 0.48, 1},
    buttonBorderHover = {0.62, 0.38, 0.45, 1},
    textLight = {0.85, 0.82, 0.86, 1},
    textGold = {0.72, 0.45, 0.52, 1},
    textMuted = {0.55, 0.52, 0.56, 1},
    sectionBg = {0.15, 0.12, 0.18, 1},
    dropdownBg = {0.18, 0.15, 0.22, 1},
    selectedBg = {0.32, 0.18, 0.22, 1},
}

-- Hash function for procedural weathering
local function hash(a, b)
    local h = (a * 374761393 + b * 668265263) % 2147483647
    h = ((h * 1274126177) % 2147483647)
    return (h % 1000) / 1000
end

-- Draw weathering effects on a panel
local function drawWeathering(x, y, w, h)
    -- Color blotches
    local numBlotches = math.floor(w / 30)
    for i = 1, numBlotches do
        local bx = x + hash(i, 1) * w
        local by = y + hash(1, i) * h
        local bsize = 8 + hash(i, i) * 16
        local colorVar = (hash(i * 3, i * 5) - 0.5) * 0.06
        local isDark = hash(i * 7, i * 11) > 0.5

        if isDark then
            love.graphics.setColor(0, 0, 0, 0.08 + colorVar)
        else
            love.graphics.setColor(0.6, 0.5, 0.7, 0.06 + colorVar)
        end
        love.graphics.ellipse("fill", bx, by, bsize, bsize * 0.6)
    end

    -- Sparse cracks
    local numCracks = 3 + math.floor(hash(w, h) * 4)
    for c = 1, numCracks do
        local cx = x + hash(c, 100) * w
        local cy = y + hash(100, c) * h
        local angle = hash(c, 101) * math.pi * 2
        local length = 10 + hash(c, 102) * 20

        love.graphics.setColor(0, 0, 0, 0.15)
        love.graphics.setLineWidth(1)
        local px, py = cx, cy
        for s = 1, math.floor(length / 3) do
            angle = angle + (hash(c * s, s) - 0.5) * 0.6
            local nx = px + math.cos(angle) * 3
            local ny = py + math.sin(angle) * 2
            if nx > x + 5 and nx < x + w - 5 and ny > y + 5 and ny < y + h - 5 then
                love.graphics.line(px, py, nx, ny)
                px, py = nx, ny
            end
        end
    end

    -- Surface noise (grain)
    local numNoise = math.floor(w * h / 80)
    for i = 1, numNoise do
        local px = x + hash(i, 400) * w
        local py = y + hash(400, i) * h
        if hash(i * 3, 401) > 0.45 then
            love.graphics.setColor(0.7, 0.6, 0.8, 0.05)
        else
            love.graphics.setColor(0, 0, 0, 0.07)
        end
        love.graphics.rectangle("fill", px, py, 1, 1)
    end

    -- Worn edges (top and bottom)
    for i = 0, w - 1 do
        if hash(i, 999) > 0.5 then
            local alpha = 0.08 + hash(i, 1000) * 0.1
            love.graphics.setColor(0.5, 0.4, 0.6, alpha)
            love.graphics.rectangle("fill", x + i, y, 1, 1 + hash(i, 1001))
        end
        if hash(i, 998) > 0.5 then
            local alpha = 0.05 + hash(i, 997) * 0.08
            love.graphics.setColor(0, 0, 0, alpha)
            love.graphics.rectangle("fill", x + i, y + h - 1 - hash(i, 996), 1, 1)
        end
    end
end

-- Draw a styled panel (matching title screen style)
local function drawStyledPanel(x, y, w, h)
    -- Panel shadow
    love.graphics.setColor(0, 0, 0, 0.4)
    love.graphics.rectangle("fill", x + 6, y + 6, w, h, 8)

    -- Panel background with gradient
    for i = 0, h - 1 do
        local t = i / h
        local alpha = UI.panelBg[4] - t * 0.1
        love.graphics.setColor(UI.panelBg[1], UI.panelBg[2], UI.panelBg[3], alpha)
        love.graphics.rectangle("fill", x, y + i, w, 1)
    end

    -- Weathering effects
    drawWeathering(x, y, w, h)

    -- Decorative top border (accent color)
    love.graphics.setColor(UI.selectedBg[1], UI.selectedBg[2], UI.selectedBg[3], 1)
    love.graphics.rectangle("fill", x, y, w, 3)
    love.graphics.setColor(UI.buttonBorderHover[1], UI.buttonBorderHover[2], UI.buttonBorderHover[3], 0.6)
    love.graphics.rectangle("fill", x, y, w, 1)

    -- Side borders (subtle)
    love.graphics.setColor(UI.panelBorder[1], UI.panelBorder[2], UI.panelBorder[3], 0.4)
    love.graphics.setLineWidth(1)
    love.graphics.line(x, y + 3, x, y + h)
    love.graphics.line(x + w, y + 3, x + w, y + h)

    -- Bottom accent
    love.graphics.setColor(UI.buttonBg[1], UI.buttonBg[2], UI.buttonBg[3], 0.5)
    love.graphics.rectangle("fill", x, y + h - 2, w, 2)
end

-- Button definitions
local buttons = {}
local playerButtons = {}  -- Player slot buttons
local dropdownButtons = {}

function GameConfig.load()
    -- Hide system cursor (we draw our own)
    love.mouse.setVisible(false)

    -- Load background image
    local success, result = pcall(function()
        return love.graphics.newImage("images/hero_vs_goblin_army_dark_tower.png")
    end)
    if success then
        bgImage = result
    else
        bgImage = nil
        print("GameConfig: Could not load background image")
    end

    -- Reset to defaults
    config = {
        mapSize = 64,
        tileset = "summer",
        treeDensity = 0.50,  -- Medium density
        riverEnabled = true,
        numBridges = 2,
        riverWidth = 3,
        players = {
            { type = "human", name = "Player 1" },
            { type = "ai", name = "Blinky", personality = "blinky", showFog = false }
        }
    }
    activeDropdown = nil
    hoveredElement = nil

    GameConfig.buildUI()
end

-- Helper: Get max players for current map size
local function getMaxPlayers()
    return maxPlayersByMapSize[config.mapSize] or 2
end

-- Helper: Check if there's a human player
local function hasHumanPlayer()
    for _, player in ipairs(config.players) do
        if player.type == "human" then
            return true
        end
    end
    return false
end

-- Helper: Adjust player count when map size changes
local function adjustPlayersForMapSize()
    local maxPlayers = getMaxPlayers()
    -- Remove excess players
    while #config.players > maxPlayers do
        table.remove(config.players)
    end
end

function GameConfig.buildUI()
    buttons = {}
    playerButtons = {}

    local screenW, screenH = love.graphics.getDimensions()
    local panelW, panelH = 500, 680  -- Increased height for all options
    local infoPanelW = 280
    local gap = 20
    local totalW = panelW + gap + infoPanelW
    local panelX = (screenW - totalW) / 2
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
            action = function()
                config.mapSize = size
                adjustPlayersForMapSize()
                GameConfig.buildUI()
            end,
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
    
    -- Tree density buttons
    local treesY = panelY + 250
    for i, density in ipairs(treeDensities) do
        table.insert(buttons, {
            x = contentX + (i-1) * 75,
            y = treesY,
            w = 70,
            h = btnH,
            text = density.label,
            action = function() config.treeDensity = density.value end,
            isSelected = function() return config.treeDensity == density.value end,
            category = "trees"
        })
    end
    
    -- River toggle button
    local riverY = panelY + 330
    table.insert(buttons, {
        x = contentX,
        y = riverY,
        w = 60,
        h = btnH,
        text = config.riverEnabled and "On" or "Off",
        action = function() 
            config.riverEnabled = not config.riverEnabled 
            GameConfig.buildUI()  -- Rebuild to update button text
        end,
        isSelected = function() return config.riverEnabled end,
        category = "river"
    })
    
    -- River width and bridge count buttons (only show if river enabled)
    if config.riverEnabled then
        -- River width
        local widthX = contentX + 80
        for i, width in ipairs(riverWidths) do
            table.insert(buttons, {
                x = widthX + (i-1) * 40,
                y = riverY,
                w = 35,
                h = btnH,
                text = tostring(width),
                action = function() config.riverWidth = width end,
                isSelected = function() return config.riverWidth == width end,
                category = "riverWidth"
            })
        end
        
        -- Bridge count
        local bridgeX = contentX + 310
        for i, count in ipairs(bridgeCounts) do
            table.insert(buttons, {
                x = bridgeX + (i-1) * 40,
                y = riverY,
                w = 35,
                h = btnH,
                text = tostring(count),
                action = function() config.numBridges = count end,
                isSelected = function() return config.numBridges == count end,
                category = "bridges"
            })
        end
    end
    
    -- Player slots section
    local playersY = panelY + 410
    local maxPlayers = getMaxPlayers()

    -- Add/Remove player buttons
    table.insert(buttons, {
        x = contentX + 350,
        y = playersY - 5,
        w = 30,
        h = 26,
        text = "+",
        action = function()
            if #config.players < maxPlayers then
                table.insert(config.players, { type = "ai", name = "Random", personality = "random", showFog = false })
                GameConfig.buildUI()
            end
        end,
        isSelected = function() return false end,
        category = "playerControl"
    })

    table.insert(buttons, {
        x = contentX + 385,
        y = playersY - 5,
        w = 30,
        h = 26,
        text = "-",
        action = function()
            if #config.players > 1 then  -- Keep at least 1 player
                table.remove(config.players)
                GameConfig.buildUI()
            end
        end,
        isSelected = function() return false end,
        category = "playerControl"
    })

    -- Player slot buttons
    for i, player in ipairs(config.players) do
        table.insert(playerButtons, {
            x = contentX,
            y = playersY + 30 + (i-1) * 40,
            w = 200,
            h = 32,
            playerIndex = i,
            player = player
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
        treeDensity = config.treeDensity,
        riverEnabled = config.riverEnabled,
        numBridges = config.numBridges,
        riverWidth = config.riverWidth,
        players = {},
        spectatorMode = not hasHumanPlayer()
    }

    -- Convert player config to game format
    for i, player in ipairs(config.players) do
        if player.type ~= "none" then
            local playerData = {
                team = i,
                type = player.type,
                showFog = player.showFog or false
            }
            if player.type == "ai" then
                local personality = player.personality or "random"
                if personality == "random" then
                    local options = {"blinky", "pinky", "inky", "clyde"}
                    personality = options[math.random(#options)]
                end
                playerData.personality = personality
            end
            table.insert(gameOptions.players, playerData)
        end
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
    
    -- Check player button hovers
    if not activeDropdown then
        for _, btn in ipairs(playerButtons) do
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

    -- Background image
    if bgImage then
        local imgW, imgH = bgImage:getWidth(), bgImage:getHeight()
        local scale = math.max(screenW / imgW, screenH / imgH)
        local drawW = imgW * scale
        local drawH = imgH * scale
        local drawX = (screenW - drawW) / 2
        local drawY = (screenH - drawH) / 2
        love.graphics.setColor(1, 1, 1, 1)
        love.graphics.draw(bgImage, drawX, drawY, 0, scale, scale)

        -- Darken overlay so UI is readable
        love.graphics.setColor(0, 0, 0, 0.4)
        love.graphics.rectangle("fill", 0, 0, screenW, screenH)
    else
        -- Fallback background
        love.graphics.setColor(0.08, 0.06, 0.05, 1)
        love.graphics.rectangle("fill", 0, 0, screenW, screenH)
    end

    -- Main panel (shifted left to make room for info panel)
    local panelW, panelH = 500, 680
    local infoPanelW = 280
    local gap = 20
    local totalW = panelW + gap + infoPanelW
    local panelX = (screenW - totalW) / 2
    local panelY = (screenH - panelH) / 2

    -- Draw main panel with title screen style
    drawStyledPanel(panelX, panelY, panelW, panelH)

    -- Title
    love.graphics.setFont(Game.fonts.large or Game.fonts.medium)
    -- Title shadow
    love.graphics.setColor(0, 0, 0, 0.5)
    local title = "New Game"
    local titleW = (Game.fonts.large or Game.fonts.medium):getWidth(title)
    love.graphics.print(title, panelX + (panelW - titleW) / 2 + 1, panelY + 26)
    -- Title text
    love.graphics.setColor(UI.textGold)
    love.graphics.print(title, panelX + (panelW - titleW) / 2, panelY + 25)

    -- Decorative line under title
    love.graphics.setColor(UI.panelBorder[1], UI.panelBorder[2], UI.panelBorder[3], 0.5)
    love.graphics.setLineWidth(2)
    love.graphics.line(panelX + 40, panelY + 65, panelX + panelW - 40, panelY + 65)
    
    local contentX = panelX + 30
    
    -- Section: Map Size
    love.graphics.setFont(Game.fonts.medium)
    love.graphics.setColor(UI.textLight)
    love.graphics.print("Map Size", contentX, panelY + 75)
    
    -- Section: Tileset
    love.graphics.print("Tileset", contentX, panelY + 155)
    
    -- Section: Trees
    love.graphics.print("Trees", contentX, panelY + 225)
    
    -- Section: River
    love.graphics.print("River", contentX, panelY + 305)
    if config.riverEnabled then
        love.graphics.setFont(Game.fonts.small)
        love.graphics.setColor(UI.textMuted)
        love.graphics.print("Width:", contentX + 65, panelY + 335)
        love.graphics.print("Bridges:", contentX + 280, panelY + 335)
    end
    
    -- Section: Players
    love.graphics.setFont(Game.fonts.medium)
    love.graphics.setColor(UI.textLight)
    love.graphics.print("Players", contentX, panelY + 385)
    love.graphics.setFont(Game.fonts.small)
    love.graphics.setColor(UI.textMuted)
    local maxPlayers = getMaxPlayers()
    love.graphics.print("(max " .. maxPlayers .. " for this map)", contentX + 75, panelY + 390)

    -- Draw all buttons
    for _, btn in ipairs(buttons) do
        GameConfig.drawButton(btn)
    end

    -- Draw player buttons
    for _, btn in ipairs(playerButtons) do
        GameConfig.drawPlayerButton(btn)
    end

    -- Info panel on the right
    local infoPanelX = panelX + panelW + gap
    local infoPanelH = panelH

    -- Draw info panel with title screen style
    drawStyledPanel(infoPanelX, panelY, infoPanelW, infoPanelH)

    -- Info panel title
    love.graphics.setFont(Game.fonts.medium)
    -- Title shadow
    love.graphics.setColor(0, 0, 0, 0.5)
    local infoTitle = "Summary"
    local infoTitleW = Game.fonts.medium:getWidth(infoTitle)
    love.graphics.print(infoTitle, infoPanelX + (infoPanelW - infoTitleW) / 2 + 1, panelY + 21)
    -- Title text
    love.graphics.setColor(UI.textGold)
    love.graphics.print(infoTitle, infoPanelX + (infoPanelW - infoTitleW) / 2, panelY + 20)

    -- Decorative line
    love.graphics.setColor(UI.panelBorder[1], UI.panelBorder[2], UI.panelBorder[3], 0.5)
    love.graphics.setLineWidth(2)
    love.graphics.line(infoPanelX + 20, panelY + 50, infoPanelX + infoPanelW - 20, panelY + 50)

    -- Info content
    local infoY = panelY + 70
    local lineHeight = 28
    love.graphics.setFont(Game.fonts.small)

    -- Map info
    love.graphics.setColor(UI.textMuted)
    love.graphics.print("Map", infoPanelX + 20, infoY)
    love.graphics.setColor(UI.textLight)
    love.graphics.print(config.mapSize .. "x" .. config.mapSize .. " tiles", infoPanelX + 100, infoY)
    infoY = infoY + lineHeight

    -- Tileset
    love.graphics.setColor(UI.textMuted)
    love.graphics.print("Season", infoPanelX + 20, infoY)
    love.graphics.setColor(UI.textLight)
    local tilesetName = config.tileset:sub(1,1):upper() .. config.tileset:sub(2)
    love.graphics.print(tilesetName, infoPanelX + 100, infoY)
    infoY = infoY + lineHeight

    -- Trees
    love.graphics.setColor(UI.textMuted)
    love.graphics.print("Trees", infoPanelX + 20, infoY)
    love.graphics.setColor(UI.textLight)
    local treeDensityLabel = "Medium"
    for _, d in ipairs(treeDensities) do
        if math.abs(d.value - config.treeDensity) < 0.01 then
            treeDensityLabel = d.label
            break
        end
    end
    love.graphics.print(treeDensityLabel, infoPanelX + 100, infoY)
    infoY = infoY + lineHeight

    -- River
    love.graphics.setColor(UI.textMuted)
    love.graphics.print("River", infoPanelX + 20, infoY)
    love.graphics.setColor(UI.textLight)
    if config.riverEnabled then
        love.graphics.print("Width " .. config.riverWidth .. ", " .. config.numBridges .. " bridge" .. (config.numBridges > 1 and "s" or ""), infoPanelX + 100, infoY)
    else
        love.graphics.print("None", infoPanelX + 100, infoY)
    end
    infoY = infoY + lineHeight + 10

    -- Divider
    love.graphics.setColor(UI.panelBorder[1], UI.panelBorder[2], UI.panelBorder[3], 0.4)
    love.graphics.setLineWidth(1)
    love.graphics.line(infoPanelX + 20, infoY, infoPanelX + infoPanelW - 20, infoY)
    infoY = infoY + 15

    -- Players section
    love.graphics.setColor(UI.textGold)
    love.graphics.setFont(Game.fonts.small)
    local spectatorMode = not hasHumanPlayer()
    local modeLabel = spectatorMode and " (Spectator)" or ""
    love.graphics.print("Players (" .. #config.players .. ")" .. modeLabel, infoPanelX + 20, infoY)
    infoY = infoY + lineHeight

    love.graphics.setColor(UI.textLight)
    for i, player in ipairs(config.players) do
        local displayName = ""
        if player.type == "human" then
            displayName = i .. ". Human"
        elseif player.type == "ai" then
            local personality = (player.personality or "random"):sub(1,1):upper() .. (player.personality or "random"):sub(2)
            displayName = i .. ". AI (" .. personality .. ")"
        else
            displayName = i .. ". Empty"
        end
        love.graphics.print(displayName, infoPanelX + 25, infoY)
        infoY = infoY + lineHeight - 4
        if infoY > panelY + infoPanelH - 60 then break end
    end

    -- Estimated game info at bottom
    infoY = panelY + infoPanelH - 100
    love.graphics.setColor(UI.panelBorder[1], UI.panelBorder[2], UI.panelBorder[3], 0.4)
    love.graphics.line(infoPanelX + 20, infoY, infoPanelX + infoPanelW - 20, infoY)
    infoY = infoY + 15

    love.graphics.setColor(UI.textMuted)
    love.graphics.setFont(Game.fonts.small)
    local totalTiles = config.mapSize * config.mapSize
    love.graphics.print("Total tiles: " .. totalTiles, infoPanelX + 20, infoY)
    infoY = infoY + lineHeight - 6
    local estimatedTrees = math.floor(totalTiles * config.treeDensity * 0.3)
    love.graphics.print("Est. trees: ~" .. estimatedTrees, infoPanelX + 20, infoY)

    -- Draw dropdown if active
    if activeDropdown then
        GameConfig.drawDropdown()
    end

    -- Custom cursor (always on top)
    Cursor.draw()

    love.graphics.setColor(1, 1, 1, 1)
end

function GameConfig.drawButton(btn)
    local isHovered = hoveredElement == btn
    local isSelected = btn.isSelected and btn.isSelected()
    
    -- Background
    if isSelected then
        love.graphics.setColor(UI.selectedBg)
    elseif isHovered then
        love.graphics.setColor(UI.buttonHover)
    else
        love.graphics.setColor(UI.buttonBg)
    end
    love.graphics.rectangle("fill", btn.x, btn.y, btn.w, btn.h, 4)

    -- Top highlight (subtle)
    love.graphics.setColor(1, 1, 1, isSelected and 0.2 or 0.1)
    love.graphics.line(btn.x + 4, btn.y + 1, btn.x + btn.w - 4, btn.y + 1)

    -- Border (subtle, only on hover/select)
    if isSelected or isHovered then
        love.graphics.setColor(UI.buttonBorderHover[1], UI.buttonBorderHover[2], UI.buttonBorderHover[3], 0.6)
        love.graphics.setLineWidth(1)
        love.graphics.rectangle("line", btn.x, btn.y, btn.w, btn.h, 4)
    end

    -- Text shadow
    love.graphics.setFont(Game.fonts.small)
    local textW = Game.fonts.small:getWidth(btn.text)
    local textH = Game.fonts.small:getHeight()
    love.graphics.setColor(0, 0, 0, 0.5)
    love.graphics.print(btn.text, btn.x + (btn.w - textW) / 2 + 1, btn.y + (btn.h - textH) / 2 + 1)

    -- Text
    if isSelected then
        love.graphics.setColor(UI.textGold)
    elseif isHovered then
        love.graphics.setColor(UI.textLight)
    else
        love.graphics.setColor(UI.textMuted)
    end
    love.graphics.print(btn.text, btn.x + (btn.w - textW) / 2, btn.y + (btn.h - textH) / 2)
end

function GameConfig.drawPlayerButton(btn)
    local isHovered = hoveredElement == btn
    local isActive = activeDropdown and activeDropdown.playerIndex == btn.playerIndex

    local player = btn.player

    -- Background
    if isActive then
        love.graphics.setColor(UI.selectedBg)
    elseif isHovered then
        love.graphics.setColor(UI.buttonHover)
    else
        love.graphics.setColor(UI.sectionBg)
    end
    love.graphics.rectangle("fill", btn.x, btn.y, btn.w, btn.h, 4)

    -- Top highlight (subtle)
    love.graphics.setColor(1, 1, 1, isActive and 0.2 or 0.1)
    love.graphics.line(btn.x + 4, btn.y + 1, btn.x + btn.w - 4, btn.y + 1)

    -- Border (subtle, only on hover/active)
    if isActive or isHovered then
        love.graphics.setColor(UI.buttonBorderHover[1], UI.buttonBorderHover[2], UI.buttonBorderHover[3], 0.6)
        love.graphics.setLineWidth(1)
        love.graphics.rectangle("line", btn.x, btn.y, btn.w, btn.h, 4)
    end

    -- Player number with shadow
    love.graphics.setFont(Game.fonts.small)
    love.graphics.setColor(0, 0, 0, 0.5)
    love.graphics.print(btn.playerIndex .. ".", btn.x + 9, btn.y + 9)
    love.graphics.setColor(UI.textMuted)
    love.graphics.print(btn.playerIndex .. ".", btn.x + 8, btn.y + 8)

    -- Player type/name with shadow
    local displayText = "Empty"
    if player.type == "human" then
        displayText = "Human"
    elseif player.type == "ai" then
        displayText = player.name or "AI"
    end

    love.graphics.setColor(0, 0, 0, 0.5)
    love.graphics.print(displayText, btn.x + 31, btn.y + 9)
    love.graphics.setColor(UI.textGold)
    love.graphics.print(displayText, btn.x + 30, btn.y + 8)

    -- Dropdown arrow
    love.graphics.setColor(UI.textMuted)
    local arrowX = btn.x + btn.w - 20
    local arrowY = btn.y + btn.h / 2
    love.graphics.polygon("fill", arrowX, arrowY - 3, arrowX + 8, arrowY - 3, arrowX + 4, arrowY + 4)

    -- Description based on player type
    local descText = ""
    if player.type == "human" then
        descText = "You"
    elseif player.type == "ai" then
        for _, p in ipairs(personalities) do
            if p.id == player.personality then
                descText = p.desc
                break
            end
        end
    else
        descText = "Slot disabled"
    end

    if descText ~= "" then
        love.graphics.setFont(Game.fonts.small)
        love.graphics.setColor(0, 0, 0, 0.5)
        love.graphics.print(descText, btn.x + btn.w + 16, btn.y + 9)
        love.graphics.setColor(UI.textMuted)
        love.graphics.print(descText, btn.x + btn.w + 15, btn.y + 8)
    end
end

function GameConfig.drawDropdown()
    if not activeDropdown then return end

    local playerBtn = playerButtons[activeDropdown.playerIndex]
    if not playerBtn then return end

    local player = config.players[activeDropdown.playerIndex]
    local dropX = playerBtn.x
    local dropY = playerBtn.y + playerBtn.h + 2
    local dropW = playerBtn.w
    local itemH = 28

    -- Build dropdown items: Human + AI personalities
    -- Options: Human, then AI personalities (Blinky, Pinky, etc.)
    local dropdownItems = {
        { type = "human", name = "Human", desc = "You control this player" }
    }
    for _, p in ipairs(personalities) do
        table.insert(dropdownItems, { type = "ai", name = p.name, personality = p.id, desc = p.desc })
    end

    local dropH = #dropdownItems * itemH + 4

    -- Build dropdown buttons
    dropdownButtons = {}
    for i, item in ipairs(dropdownItems) do
        table.insert(dropdownButtons, {
            x = dropX + 2,
            y = dropY + 2 + (i-1) * itemH,
            w = dropW - 4,
            h = itemH - 2,
            item = item,
            playerIndex = activeDropdown.playerIndex
        })
    end

    -- Shadow
    love.graphics.setColor(0, 0, 0, 0.6)
    love.graphics.rectangle("fill", dropX + 4, dropY + 4, dropW, dropH, 4)

    -- Background with gradient
    for i = 0, dropH - 1 do
        local t = i / dropH
        local alpha = UI.dropdownBg[4] - t * 0.08
        love.graphics.setColor(UI.dropdownBg[1], UI.dropdownBg[2], UI.dropdownBg[3], alpha)
        love.graphics.rectangle("fill", dropX, dropY + i, dropW, 1)
    end

    -- Top border accent
    love.graphics.setColor(UI.buttonBorderHover[1], UI.buttonBorderHover[2], UI.buttonBorderHover[3], 0.6)
    love.graphics.setLineWidth(2)
    love.graphics.line(dropX + 4, dropY, dropX + dropW - 4, dropY)

    -- Subtle side borders
    love.graphics.setColor(1, 1, 1, 0.05)
    love.graphics.setLineWidth(1)
    love.graphics.line(dropX, dropY + 4, dropX, dropY + dropH - 4)
    love.graphics.line(dropX + dropW, dropY + 4, dropX + dropW, dropY + dropH - 4)

    -- Items
    for _, btn in ipairs(dropdownButtons) do
        local isHovered = hoveredElement == btn
        local isSelected = false
        if btn.item.type == "human" and player.type == "human" then
            isSelected = true
        elseif btn.item.type == "ai" and player.type == "ai" and player.personality == btn.item.personality then
            isSelected = true
        end

        if isSelected then
            love.graphics.setColor(UI.selectedBg)
            love.graphics.rectangle("fill", btn.x, btn.y, btn.w, btn.h, 3)
            -- Top highlight on selected
            love.graphics.setColor(1, 1, 1, 0.15)
            love.graphics.line(btn.x + 3, btn.y + 1, btn.x + btn.w - 3, btn.y + 1)
        elseif isHovered then
            love.graphics.setColor(UI.buttonHover)
            love.graphics.rectangle("fill", btn.x, btn.y, btn.w, btn.h, 3)
            -- Top highlight on hover
            love.graphics.setColor(1, 1, 1, 0.1)
            love.graphics.line(btn.x + 3, btn.y + 1, btn.x + btn.w - 3, btn.y + 1)
        end

        -- Text shadow
        love.graphics.setFont(Game.fonts.small)
        love.graphics.setColor(0, 0, 0, 0.5)
        love.graphics.print(btn.item.name, btn.x + 11, btn.y + 6)

        -- Text
        if isSelected then
            love.graphics.setColor(UI.textGold)
        elseif isHovered then
            love.graphics.setColor(UI.textLight)
        else
            love.graphics.setColor(UI.textMuted)
        end
        love.graphics.print(btn.item.name, btn.x + 10, btn.y + 5)
    end
end

function GameConfig.mousepressed(x, y, button)
    if button ~= 1 then return end

    -- Check dropdown items first
    if activeDropdown then
        for _, btn in ipairs(dropdownButtons) do
            if x >= btn.x and x <= btn.x + btn.w and
               y >= btn.y and y <= btn.y + btn.h then
                -- Select this player type/personality
                local player = config.players[btn.playerIndex]
                if btn.item.type == "human" then
                    player.type = "human"
                    player.name = "Human"
                    player.personality = nil
                else
                    player.type = "ai"
                    player.name = btn.item.name
                    player.personality = btn.item.personality
                    player.showFog = player.showFog or false
                end
                activeDropdown = nil
                GameConfig.buildUI()
                return
            end
        end
        -- Clicked outside dropdown - close it
        activeDropdown = nil
        return
    end

    -- Check player buttons (opens dropdown)
    for _, btn in ipairs(playerButtons) do
        if x >= btn.x and x <= btn.x + btn.w and
           y >= btn.y and y <= btn.y + btn.h then
            activeDropdown = { playerIndex = btn.playerIndex }
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
