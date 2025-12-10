-- Replay Browser Screen
-- Lists saved replay files and allows viewing them

local ReplayBrowser = {}

-- Background image
local bgImage = nil

-- Replay list
local replays = {}
local selectedIndex = nil
local scrollOffset = 0
local maxVisible = 12

-- Viewer state
local viewerMode = false
local viewerContent = nil
local viewerLines = {}
local viewerScrollOffset = 0
local viewerMaxLines = 20
local viewerReplayName = ""

-- UI state
local buttons = {}
local viewerButtons = {}

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
    selectedBg = {0.32, 0.18, 0.22, 1},
    itemBg = {0.15, 0.12, 0.18, 0.9},
    itemHover = {0.22, 0.18, 0.26, 1},
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
end

-- Draw styled panel with decorative borders
local function drawStyledPanel(x, y, w, h)
    -- Drop shadow
    love.graphics.setColor(0, 0, 0, 0.4)
    love.graphics.rectangle("fill", x + 6, y + 6, w, h, 8)

    -- Panel background with gradient
    for i = 0, h - 1 do
        local t = i / h
        local alpha = UI.panelBg[4] - t * 0.1
        love.graphics.setColor(UI.panelBg[1], UI.panelBg[2], UI.panelBg[3], alpha)
        love.graphics.rectangle("fill", x, y + i, w, 1)
    end

    -- Weathering
    drawWeathering(x, y, w, h)

    -- Decorative top border (gold accent)
    love.graphics.setColor(0.48, 0.25, 0.32, 1)
    love.graphics.rectangle("fill", x, y, w, 3)
    love.graphics.setColor(0.62, 0.38, 0.45, 0.6)
    love.graphics.rectangle("fill", x, y, w, 1)

    -- Side borders
    love.graphics.setColor(UI.panelBorder[1], UI.panelBorder[2], UI.panelBorder[3], 0.5)
    love.graphics.setLineWidth(1)
    love.graphics.line(x, y + 3, x, y + h)
    love.graphics.line(x + w, y + 3, x + w, y + h)

    -- Bottom accent
    love.graphics.setColor(0.28, 0.22, 0.34, 0.5)
    love.graphics.rectangle("fill", x, y + h - 2, w, 2)
end

-- Draw a button
local function drawButton(btn, mx, my)
    local x, y, w, h = btn.x, btn.y, btn.w, btn.h
    local hovered = mx >= x and mx <= x + w and my >= y and my <= y + h
    local isPrimary = btn.primary

    -- Button glow on hover
    if hovered then
        love.graphics.setColor(0.55, 0.45, 0.60, 0.15)
        love.graphics.rectangle("fill", x - 4, y - 4, w + 8, h + 8, 10)
    end

    -- Button background
    if isPrimary then
        for i = 0, h - 1 do
            local t = i / h
            local r = 0.32 + (0.48 - 0.32) * (1 - t * 0.5)
            local g = 0.18 + (0.25 - 0.18) * (1 - t * 0.5)
            local b = 0.22 + (0.32 - 0.22) * (1 - t * 0.5)
            if hovered then r, g, b = r + 0.1, g + 0.1, b + 0.05 end
            love.graphics.setColor(r, g, b, 1)
            love.graphics.rectangle("fill", x, y + i, w, 1)
        end
    else
        for i = 0, h - 1 do
            local t = i / h
            local baseColor = hovered and UI.buttonHover or UI.buttonBg
            local r = baseColor[1] * (1 - t * 0.3)
            local g = baseColor[2] * (1 - t * 0.3)
            local b = baseColor[3] * (1 - t * 0.3)
            love.graphics.setColor(r, g, b, 0.95)
            love.graphics.rectangle("fill", x, y + i, w, 1)
        end
    end

    -- Border
    love.graphics.setLineWidth(isPrimary and 2 or 1)
    if isPrimary then
        love.graphics.setColor(0.62, 0.38, 0.45, 1)
    elseif hovered then
        love.graphics.setColor(0.55, 0.45, 0.60, 1)
    else
        love.graphics.setColor(0.42, 0.35, 0.48, 0.6)
    end
    love.graphics.rectangle("line", x, y, w, h, 4)

    -- Top highlight
    love.graphics.setColor(1, 1, 1, isPrimary and 0.3 or 0.15)
    love.graphics.line(x + 4, y + 1, x + w - 4, y + 1)

    -- Text
    local font = Game.fonts and Game.fonts.button or love.graphics.getFont()
    love.graphics.setFont(font)
    local textW = font:getWidth(btn.text)
    local textH = font:getHeight()

    -- Text shadow
    love.graphics.setColor(0, 0, 0, 0.6)
    love.graphics.print(btn.text, x + (w - textW) / 2 + 1, y + (h - textH) / 2 + 1)

    -- Text
    if isPrimary then
        love.graphics.setColor(0.15, 0.1, 0.05, 1)
    elseif hovered then
        love.graphics.setColor(UI.textGold)
    else
        love.graphics.setColor(UI.textLight)
    end
    love.graphics.print(btn.text, x + (w - textW) / 2, y + (h - textH) / 2)

    return hovered
end

-- Scan for replay files
local function scanReplays()
    replays = {}

    -- Get files from Love2D save directory
    local files = love.filesystem.getDirectoryItems("replays")

    for _, filename in ipairs(files) do
        if filename:match("%.txt$") then
            local filepath = "replays/" .. filename
            local info = love.filesystem.getInfo(filepath)

            -- Parse timestamp from filename: replay_YYYYMMDD_HHMMSS.txt
            local dateStr, timeStr = filename:match("replay_(%d+)_(%d+)%.txt")
            local displayName = filename

            if dateStr and timeStr then
                -- Format: YYYY-MM-DD HH:MM:SS
                local year = dateStr:sub(1, 4)
                local month = dateStr:sub(5, 6)
                local day = dateStr:sub(7, 8)
                local hour = timeStr:sub(1, 2)
                local min = timeStr:sub(3, 4)
                local sec = timeStr:sub(5, 6)
                displayName = string.format("%s-%s-%s %s:%s:%s", year, month, day, hour, min, sec)
            end

            table.insert(replays, {
                filename = filename,
                filepath = filepath,
                displayName = displayName,
                size = info and info.size or 0,
                modtime = info and info.modtime or 0
            })
        end
    end

    -- Sort by modification time (newest first)
    table.sort(replays, function(a, b)
        return a.modtime > b.modtime
    end)
end

-- Read replay content
local function readReplayContent(filepath)
    local content, err = love.filesystem.read(filepath)
    if content then
        return content
    end
    return nil, err
end

-- Open viewer with replay content
local function openViewer(replay)
    local content = readReplayContent(replay.filepath)
    if content then
        viewerMode = true
        viewerContent = content
        viewerReplayName = replay.displayName
        viewerScrollOffset = 0

        -- Split content into lines
        viewerLines = {}
        for line in content:gmatch("[^\r\n]+") do
            table.insert(viewerLines, line)
        end
    end
end

-- Close viewer
local function closeViewer()
    viewerMode = false
    viewerContent = nil
    viewerLines = {}
    viewerScrollOffset = 0
end

function ReplayBrowser.load()
    selectedIndex = nil
    scrollOffset = 0

    -- Load background image
    local imagePath = "images/reminiscent_adventurer.jpg"
    local success, result = pcall(function()
        return love.graphics.newImage(imagePath)
    end)
    if success then
        bgImage = result
    else
        -- Fallback
        bgImage = nil
    end

    -- Scan for replay files
    scanReplays()

    -- Setup buttons
    local screenW, screenH = love.graphics.getDimensions()
    local panelW = 500
    local panelX = (screenW - panelW) / 2
    local panelH = screenH - 120
    local panelY = 60

    local btnW = 120
    local btnH = 40
    local btnY = panelY + panelH - 60

    buttons = {
        {
            text = "View",
            x = panelX + panelW - btnW * 2 - 30,
            y = btnY,
            w = btnW,
            h = btnH,
            primary = true,
            action = function()
                if selectedIndex and replays[selectedIndex] then
                    openViewer(replays[selectedIndex])
                end
            end
        },
        {
            text = "Refresh",
            x = panelX + 20,
            y = btnY,
            w = btnW,
            h = btnH,
            action = function()
                scanReplays()
                selectedIndex = nil
            end
        },
        {
            text = "Back",
            x = panelX + panelW - btnW - 15,
            y = btnY,
            w = btnW,
            h = btnH,
            action = function()
                Game.SceneManager.switch("title")
            end
        }
    }
end

function ReplayBrowser.update(dt)
    -- Could add animations here
end

-- Draw the replay viewer overlay
local function drawViewer(screenW, screenH, mx, my)
    -- Dim background
    love.graphics.setColor(0, 0, 0, 0.7)
    love.graphics.rectangle("fill", 0, 0, screenW, screenH)

    -- Viewer panel (larger than list panel)
    local panelW = math.min(700, screenW - 80)
    local panelH = screenH - 100
    local panelX = (screenW - panelW) / 2
    local panelY = 50

    drawStyledPanel(panelX, panelY, panelW, panelH)

    -- Title
    local titleFont = Game.fonts and (Game.fonts.large or Game.fonts.medium) or love.graphics.getFont()
    love.graphics.setFont(titleFont)
    local titleW = titleFont:getWidth(viewerReplayName)

    love.graphics.setColor(0, 0, 0, 0.5)
    love.graphics.print(viewerReplayName, panelX + (panelW - titleW) / 2 + 1, panelY + 21)
    love.graphics.setColor(UI.textGold)
    love.graphics.print(viewerReplayName, panelX + (panelW - titleW) / 2, panelY + 20)

    -- Content area
    local contentX = panelX + 20
    local contentY = panelY + 55
    local contentW = panelW - 40
    local contentH = panelH - 120
    local lineH = 18

    -- Content background
    love.graphics.setColor(0, 0, 0, 0.4)
    love.graphics.rectangle("fill", contentX, contentY, contentW, contentH, 4)

    -- Calculate visible lines
    viewerMaxLines = math.floor(contentH / lineH)

    -- Use monospace font for log content
    local contentFont = love.graphics.newFont(12)
    love.graphics.setFont(contentFont)

    love.graphics.setScissor(contentX, contentY, contentW, contentH)

    if #viewerLines == 0 then
        love.graphics.setColor(UI.textMuted)
        love.graphics.print("(Empty replay)", contentX + 10, contentY + 10)
    else
        for i = 1, viewerMaxLines do
            local lineIndex = i + viewerScrollOffset
            if lineIndex <= #viewerLines then
                local line = viewerLines[lineIndex]
                local lineY = contentY + (i - 1) * lineH + 4

                -- Color code based on log category
                if line:match("%[GAME%]") then
                    love.graphics.setColor(0.9, 0.75, 0.4, 1)  -- Gold for game events
                elseif line:match("%[CONFIG%]") then
                    love.graphics.setColor(0.6, 0.8, 0.9, 1)  -- Light cyan for config
                elseif line:match("%[QUEUE%]") then
                    love.graphics.setColor(0.9, 0.7, 0.5, 1)  -- Orange for queue actions
                elseif line:match("%[SETUP%]") then
                    love.graphics.setColor(0.6, 0.9, 0.6, 1)  -- Light green for setup/starting units
                elseif line:match("%[SPAWN%]") then
                    love.graphics.setColor(0.5, 0.8, 0.5, 1)  -- Green for spawns
                elseif line:match("%[BUILD%]") then
                    love.graphics.setColor(0.5, 0.7, 0.9, 1)  -- Blue for buildings
                elseif line:match("%[DEATH%]") or line:match("%[DESTROY%]") then
                    love.graphics.setColor(0.9, 0.4, 0.4, 1)  -- Red for deaths
                elseif line:match("%[ORDER%]") then
                    love.graphics.setColor(0.7, 0.6, 0.9, 1)  -- Purple for orders
                elseif line:match("%[SYSTEM%]") then
                    love.graphics.setColor(0.6, 0.6, 0.6, 1)  -- Gray for system
                else
                    love.graphics.setColor(UI.textLight)
                end

                love.graphics.print(line, contentX + 8, lineY)
            end
        end
    end

    love.graphics.setScissor()

    -- Scrollbar (if needed)
    if #viewerLines > viewerMaxLines then
        local scrollbarX = contentX + contentW - 8
        local scrollbarH = contentH - 8
        local thumbH = math.max(20, scrollbarH * (viewerMaxLines / #viewerLines))
        local maxScroll = #viewerLines - viewerMaxLines
        local thumbY = contentY + 4 + (scrollbarH - thumbH) * (viewerScrollOffset / maxScroll)

        -- Track
        love.graphics.setColor(0, 0, 0, 0.3)
        love.graphics.rectangle("fill", scrollbarX, contentY + 4, 6, scrollbarH, 2)

        -- Thumb
        love.graphics.setColor(UI.buttonBorder)
        love.graphics.rectangle("fill", scrollbarX, thumbY, 6, thumbH, 2)
    end

    -- Line count
    local countFont = Game.fonts and Game.fonts.small or love.graphics.newFont(10)
    love.graphics.setFont(countFont)
    love.graphics.setColor(UI.textMuted)
    local countStr = string.format("Lines: %d", #viewerLines)
    love.graphics.print(countStr, contentX + 10, panelY + panelH - 55)

    -- Close button
    local btnW = 120
    local btnH = 40
    local btnX = panelX + panelW - btnW - 20
    local btnY = panelY + panelH - 60

    viewerButtons = {
        {
            text = "Close",
            x = btnX,
            y = btnY,
            w = btnW,
            h = btnH,
            primary = true,
            action = closeViewer
        }
    }

    for _, btn in ipairs(viewerButtons) do
        drawButton(btn, mx, my)
    end
end

function ReplayBrowser.draw()
    local screenW, screenH = love.graphics.getDimensions()
    local mx, my = love.mouse.getPosition()

    -- Draw background
    if bgImage then
        local imgW, imgH = bgImage:getWidth(), bgImage:getHeight()
        local scale = math.max(screenW / imgW, screenH / imgH)
        local drawW = imgW * scale
        local drawH = imgH * scale
        local drawX = (screenW - drawW) / 2
        local drawY = (screenH - drawH) / 2

        love.graphics.setColor(1, 1, 1, 1)
        love.graphics.draw(bgImage, drawX, drawY, 0, scale, scale)

        -- Darken overlay
        love.graphics.setColor(0, 0, 0, 0.5)
        love.graphics.rectangle("fill", 0, 0, screenW, screenH)
    else
        -- Fallback gradient background
        for y = 0, screenH do
            local t = y / screenH
            love.graphics.setColor(0.08 + t * 0.04, 0.06 + t * 0.03, 0.12 + t * 0.05, 1)
            love.graphics.rectangle("fill", 0, y, screenW, 1)
        end
    end

    -- Main panel
    local panelW = 500
    local panelX = (screenW - panelW) / 2
    local panelH = screenH - 120
    local panelY = 60

    drawStyledPanel(panelX, panelY, panelW, panelH)

    -- Title (same font as gameconfig "New Game")
    local titleFont = Game.fonts and (Game.fonts.large or Game.fonts.medium) or love.graphics.getFont()
    love.graphics.setFont(titleFont)
    local title = "Replays"
    local titleW = titleFont:getWidth(title)

    love.graphics.setColor(0, 0, 0, 0.5)
    love.graphics.print(title, panelX + (panelW - titleW) / 2 + 1, panelY + 26)
    love.graphics.setColor(UI.textGold)
    love.graphics.print(title, panelX + (panelW - titleW) / 2, panelY + 25)

    -- Replay list area
    local listX = panelX + 20
    local listY = panelY + 60
    local listW = panelW - 40
    local listH = panelH - 140
    local itemH = 36

    -- List background
    love.graphics.setColor(0, 0, 0, 0.3)
    love.graphics.rectangle("fill", listX, listY, listW, listH, 4)

    -- Use a clean sans-serif font for replay items (more readable for filenames/dates)
    local listFont = love.graphics.newFont(14)
    love.graphics.setFont(listFont)

    love.graphics.setScissor(listX, listY, listW, listH)

    if #replays == 0 then
        love.graphics.setColor(UI.textMuted)
        local msg = "No replays found"
        local msgW = listFont:getWidth(msg)
        love.graphics.print(msg, listX + (listW - msgW) / 2, listY + listH / 2 - 10)

        -- Show save directory path
        local saveDir = love.filesystem.getSaveDirectory() .. "/replays"
        love.graphics.setColor(UI.textMuted[1], UI.textMuted[2], UI.textMuted[3], 0.6)
        local pathW = listFont:getWidth(saveDir)
        love.graphics.print(saveDir, listX + (listW - pathW) / 2, listY + listH / 2 + 15)
    else
        for i, replay in ipairs(replays) do
            if i > scrollOffset and i <= scrollOffset + maxVisible then
                local itemY = listY + (i - scrollOffset - 1) * itemH + 4
                local itemX = listX + 4
                local itemWidth = listW - 8

                local isHovered = mx >= itemX and mx <= itemX + itemWidth and
                                  my >= itemY and my <= itemY + itemH - 4
                local isSelected = selectedIndex == i

                -- Item background
                if isSelected then
                    love.graphics.setColor(UI.selectedBg)
                elseif isHovered then
                    love.graphics.setColor(UI.itemHover)
                else
                    love.graphics.setColor(UI.itemBg)
                end
                love.graphics.rectangle("fill", itemX, itemY, itemWidth, itemH - 4, 3)

                -- Item border on hover/select
                if isSelected or isHovered then
                    love.graphics.setColor(isSelected and UI.textGold or UI.buttonBorder)
                    love.graphics.setLineWidth(1)
                    love.graphics.rectangle("line", itemX, itemY, itemWidth, itemH - 4, 3)
                end

                -- Replay name (using clean font for readability)
                love.graphics.setColor(isSelected and UI.textGold or UI.textLight)
                love.graphics.print(replay.displayName, itemX + 10, itemY + (itemH - 4 - listFont:getHeight()) / 2)

                -- File size
                local sizeStr = string.format("%.1f KB", replay.size / 1024)
                local sizeW = listFont:getWidth(sizeStr)
                love.graphics.setColor(UI.textMuted)
                love.graphics.print(sizeStr, itemX + itemWidth - sizeW - 10, itemY + (itemH - 4 - listFont:getHeight()) / 2)
            end
        end
    end

    love.graphics.setScissor()

    -- Scrollbar (if needed)
    if #replays > maxVisible then
        local scrollbarX = listX + listW - 8
        local scrollbarH = listH - 8
        local thumbH = math.max(20, scrollbarH * (maxVisible / #replays))
        local thumbY = listY + 4 + (scrollbarH - thumbH) * (scrollOffset / (#replays - maxVisible))

        -- Track
        love.graphics.setColor(0, 0, 0, 0.3)
        love.graphics.rectangle("fill", scrollbarX, listY + 4, 6, scrollbarH, 2)

        -- Thumb
        love.graphics.setColor(UI.buttonBorder)
        love.graphics.rectangle("fill", scrollbarX, thumbY, 6, thumbH, 2)
    end

    -- Draw buttons
    for _, btn in ipairs(buttons) do
        drawButton(btn, mx, my)
    end

    -- Draw viewer overlay if active
    if viewerMode then
        drawViewer(screenW, screenH, mx, my)
    end

    love.graphics.setColor(1, 1, 1, 1)
end

function ReplayBrowser.mousepressed(x, y, button)
    if button == 1 then
        -- If viewer is open, only check viewer buttons
        if viewerMode then
            for _, btn in ipairs(viewerButtons) do
                if x >= btn.x and x <= btn.x + btn.w and
                   y >= btn.y and y <= btn.y + btn.h then
                    if btn.action then btn.action() end
                    return
                end
            end
            return  -- Don't process clicks on list when viewer is open
        end

        -- Check buttons
        for _, btn in ipairs(buttons) do
            if x >= btn.x and x <= btn.x + btn.w and
               y >= btn.y and y <= btn.y + btn.h then
                if btn.action then btn.action() end
                return
            end
        end

        -- Check replay list
        local screenW, screenH = love.graphics.getDimensions()
        local panelW = 500
        local panelX = (screenW - panelW) / 2
        local panelH = screenH - 120
        local panelY = 60

        local listX = panelX + 20
        local listY = panelY + 60
        local listW = panelW - 40
        local listH = panelH - 140
        local itemH = 36

        if x >= listX and x <= listX + listW and y >= listY and y <= listY + listH then
            local clickedIndex = math.floor((y - listY) / itemH) + 1 + scrollOffset
            if clickedIndex >= 1 and clickedIndex <= #replays then
                selectedIndex = clickedIndex
            end
        end
    end
end

function ReplayBrowser.mousereleased(x, y, button)
end

function ReplayBrowser.wheelmoved(x, y)
    if viewerMode then
        -- Scroll viewer content (always allow if there's content)
        if #viewerLines > 0 then
            viewerScrollOffset = viewerScrollOffset - y * 3  -- Scroll 3 lines at a time
            local maxScroll = math.max(0, #viewerLines - viewerMaxLines)
            viewerScrollOffset = math.max(0, math.min(viewerScrollOffset, maxScroll))
        end
    else
        -- Scroll replay list
        if #replays > maxVisible then
            scrollOffset = scrollOffset - y
            scrollOffset = math.max(0, math.min(scrollOffset, #replays - maxVisible))
        end
    end
end

function ReplayBrowser.keypressed(key)
    if viewerMode then
        -- Viewer mode key handling
        if key == "escape" then
            closeViewer()
        elseif key == "up" then
            viewerScrollOffset = math.max(0, viewerScrollOffset - 1)
        elseif key == "down" then
            if #viewerLines > viewerMaxLines then
                viewerScrollOffset = math.min(#viewerLines - viewerMaxLines, viewerScrollOffset + 1)
            end
        elseif key == "pageup" then
            viewerScrollOffset = math.max(0, viewerScrollOffset - viewerMaxLines)
        elseif key == "pagedown" then
            if #viewerLines > viewerMaxLines then
                viewerScrollOffset = math.min(#viewerLines - viewerMaxLines, viewerScrollOffset + viewerMaxLines)
            end
        elseif key == "home" then
            viewerScrollOffset = 0
        elseif key == "end" then
            if #viewerLines > viewerMaxLines then
                viewerScrollOffset = #viewerLines - viewerMaxLines
            end
        end
    else
        -- List mode key handling
        if key == "escape" then
            Game.SceneManager.switch("title")
        elseif key == "up" and selectedIndex then
            selectedIndex = math.max(1, selectedIndex - 1)
            if selectedIndex <= scrollOffset then
                scrollOffset = selectedIndex - 1
            end
        elseif key == "down" and selectedIndex then
            selectedIndex = math.min(#replays, selectedIndex + 1)
            if selectedIndex > scrollOffset + maxVisible then
                scrollOffset = selectedIndex - maxVisible
            end
        elseif key == "return" and selectedIndex then
            -- View selected replay
            if replays[selectedIndex] then
                openViewer(replays[selectedIndex])
            end
        end
    end
end

return ReplayBrowser
