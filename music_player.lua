--[[
    Music Player UI Component
    Compact dropdown player for gameplay screen

    Features:
    - Slides in from under top bar
    - Track name, progress bar, time display
    - Play/pause, next, prev controls
    - Volume slider
    - Scrollable playlist
]]

local Audio = require("audio")

local MusicPlayer = {}

-- UI State
local isOpen = false
local slideProgress = 0  -- 0 = closed, 1 = fully open
local slideSpeed = 8     -- Animation speed

-- Layout (will be computed based on screen size)
local layout = {
    iconX = 0,
    iconY = 0,
    iconSize = 32,
    panelX = 0,
    panelY = 0,
    panelW = 0,
    panelH = 0,
}

-- Scroll state for playlist
local playlistScroll = 0
local maxScroll = 0

-- Drag state for progress bar
local isDraggingProgress = false
local isDraggingVolume = false

-- Colors (matching ui_draw.lua medieval theme)
local Colors = {
    panelBg = {0.12, 0.11, 0.10, 0.95},
    panelBorder = {0.45, 0.38, 0.22, 1},
    panelHighlight = {0.55, 0.48, 0.32, 0.6},
    text = {0.92, 0.88, 0.80, 1},
    textDim = {0.6, 0.56, 0.48, 1},
    textGold = {1, 0.82, 0.25, 1},
    progressBg = {0.08, 0.07, 0.06, 1},
    progressFill = {0.72, 0.58, 0.26, 1},
    progressHandle = {0.88, 0.72, 0.42, 1},
    buttonBg = {0.18, 0.16, 0.14, 1},
    buttonHover = {0.28, 0.24, 0.20, 1},
    buttonActive = {0.38, 0.32, 0.24, 1},
    listItemBg = {0.15, 0.14, 0.12, 1},
    listItemHover = {0.22, 0.20, 0.17, 1},
    listItemActive = {0.30, 0.26, 0.20, 1},
    scrollbar = {0.3, 0.28, 0.24, 0.6},
}

-- Compute layout based on screen size
local function computeLayout(screenW, screenH)
    local maxW = math.floor(screenW / 6)
    local maxH = math.floor(screenH / 6)

    -- Minimum sizes for usability
    maxW = math.max(maxW, 200)
    maxH = math.max(maxH, 150)

    -- Icon position (top-right, in the top bar area)
    layout.iconSize = 28
    layout.iconX = screenW - layout.iconSize - 12
    layout.iconY = 7  -- Centered in 42px top bar

    -- Panel position (below icon, right-aligned)
    layout.panelW = maxW
    layout.panelH = maxH
    layout.panelX = screenW - layout.panelW - 8
    layout.panelY = 42  -- Just below top bar
end

-- Check if point is in rectangle
local function pointInRect(px, py, x, y, w, h)
    return px >= x and px <= x + w and py >= y and py <= y + h
end

-- Draw music note icon (for the toggle button)
local function drawMusicIcon(x, y, size, hovered, enabled)
    local cx, cy = x + size/2, y + size/2

    -- Background circle
    if hovered then
        love.graphics.setColor(0.35, 0.30, 0.25, 0.9)
    else
        love.graphics.setColor(0.20, 0.18, 0.16, 0.8)
    end
    love.graphics.circle("fill", cx, cy, size/2)

    -- Border
    if hovered then
        love.graphics.setColor(Colors.panelBorder)
    else
        love.graphics.setColor(0.4, 0.36, 0.30, 0.5)
    end
    love.graphics.setLineWidth(1)
    love.graphics.circle("line", cx, cy, size/2)

    -- Music note icon
    if enabled then
        if hovered then
            love.graphics.setColor(Colors.textGold)
        else
            love.graphics.setColor(Colors.text)
        end
    else
        love.graphics.setColor(Colors.textDim[1], Colors.textDim[2], Colors.textDim[3], 0.5)
    end

    love.graphics.setLineWidth(2)
    -- Note head (oval)
    love.graphics.ellipse("fill", cx - 2, cy + 3, 4, 3)
    -- Stem
    love.graphics.line(cx + 2, cy + 3, cx + 2, cy - 6)
    -- Flag
    love.graphics.line(cx + 2, cy - 6, cx + 6, cy - 3)

    -- X if disabled
    if not enabled then
        love.graphics.setColor(1, 0.3, 0.3, 0.8)
        love.graphics.setLineWidth(2)
        love.graphics.line(cx - 5, cy - 5, cx + 5, cy + 5)
        love.graphics.line(cx + 5, cy - 5, cx - 5, cy + 5)
    end
end

-- Draw a small button
local function drawButton(x, y, w, h, icon, hovered, active)
    -- Background
    if active then
        love.graphics.setColor(Colors.buttonActive)
    elseif hovered then
        love.graphics.setColor(Colors.buttonHover)
    else
        love.graphics.setColor(Colors.buttonBg)
    end
    love.graphics.rectangle("fill", x, y, w, h, 4)

    -- Border
    love.graphics.setColor(Colors.panelBorder[1], Colors.panelBorder[2], Colors.panelBorder[3], 0.5)
    love.graphics.setLineWidth(1)
    love.graphics.rectangle("line", x, y, w, h, 4)

    -- Icon
    love.graphics.setColor(hovered and Colors.textGold or Colors.text)
    local cx, cy = x + w/2, y + h/2

    if icon == "prev" then
        -- |<<
        love.graphics.polygon("fill", cx + 3, cy - 5, cx + 3, cy + 5, cx - 3, cy)
        love.graphics.rectangle("fill", cx - 5, cy - 5, 2, 10)
    elseif icon == "next" then
        -- >>|
        love.graphics.polygon("fill", cx - 3, cy - 5, cx - 3, cy + 5, cx + 3, cy)
        love.graphics.rectangle("fill", cx + 3, cy - 5, 2, 10)
    elseif icon == "play" then
        -- >
        love.graphics.polygon("fill", cx - 4, cy - 6, cx - 4, cy + 6, cx + 5, cy)
    elseif icon == "pause" then
        -- ||
        love.graphics.rectangle("fill", cx - 5, cy - 5, 3, 10)
        love.graphics.rectangle("fill", cx + 2, cy - 5, 3, 10)
    end

    return hovered
end

-- Draw progress bar
local function drawProgressBar(x, y, w, h, progress, mx, my)
    local hovered = pointInRect(mx, my, x, y, w, h)

    -- Background
    love.graphics.setColor(Colors.progressBg)
    love.graphics.rectangle("fill", x, y, w, h, 3)

    -- Fill
    local fillW = w * math.min(1, math.max(0, progress))
    love.graphics.setColor(Colors.progressFill)
    love.graphics.rectangle("fill", x, y, fillW, h, 3)

    -- Handle
    if hovered or isDraggingProgress then
        love.graphics.setColor(Colors.progressHandle)
        local handleX = x + fillW
        love.graphics.circle("fill", handleX, y + h/2, 6)
    end

    -- Border
    love.graphics.setColor(Colors.panelBorder[1], Colors.panelBorder[2], Colors.panelBorder[3], 0.4)
    love.graphics.setLineWidth(1)
    love.graphics.rectangle("line", x, y, w, h, 3)

    return hovered
end

-- Draw volume slider
local function drawVolumeSlider(x, y, w, h, volume, mx, my)
    local hovered = pointInRect(mx, my, x - 10, y, w + 20, h + 10)

    -- Track
    love.graphics.setColor(Colors.progressBg)
    love.graphics.rectangle("fill", x, y + h/2 - 2, w, 4, 2)

    -- Fill
    local fillW = w * volume
    love.graphics.setColor(Colors.progressFill[1], Colors.progressFill[2], Colors.progressFill[3], 0.7)
    love.graphics.rectangle("fill", x, y + h/2 - 2, fillW, 4, 2)

    -- Handle
    love.graphics.setColor(hovered and Colors.progressHandle or Colors.text)
    local handleX = x + fillW
    love.graphics.circle("fill", handleX, y + h/2, 5)

    -- Speaker icon
    love.graphics.setColor(Colors.textDim)
    local spkX = x - 14
    love.graphics.rectangle("fill", spkX, y + h/2 - 3, 4, 6)
    love.graphics.polygon("fill", spkX + 4, y + h/2 - 3, spkX + 8, y + h/2 - 6, spkX + 8, y + h/2 + 6, spkX + 4, y + h/2 + 3)

    return hovered
end

-- Draw playlist item
local function drawPlaylistItem(x, y, w, h, track, index, isCurrentTrack, hovered)
    -- Background
    if isCurrentTrack then
        love.graphics.setColor(Colors.listItemActive)
    elseif hovered then
        love.graphics.setColor(Colors.listItemHover)
    else
        love.graphics.setColor(Colors.listItemBg)
    end
    love.graphics.rectangle("fill", x, y, w, h)

    -- Playing indicator
    if isCurrentTrack then
        love.graphics.setColor(Colors.textGold)
        love.graphics.polygon("fill", x + 8, y + h/2 - 4, x + 8, y + h/2 + 4, x + 14, y + h/2)
    end

    -- Track name
    love.graphics.setColor(isCurrentTrack and Colors.textGold or Colors.text)
    local nameX = isCurrentTrack and (x + 20) or (x + 8)
    local name = track.name
    -- Truncate if too long
    local font = love.graphics.getFont()
    local maxNameW = w - 50
    while font:getWidth(name) > maxNameW and #name > 3 do
        name = name:sub(1, -2)
    end
    if name ~= track.name then
        name = name .. "..."
    end
    love.graphics.print(name, nameX, y + (h - font:getHeight()) / 2)

    -- Duration
    love.graphics.setColor(Colors.textDim)
    local durStr = Audio.formatTime(track.duration)
    local durW = font:getWidth(durStr)
    love.graphics.print(durStr, x + w - durW - 8, y + (h - font:getHeight()) / 2)
end

-- Initialize the player
function MusicPlayer.init(screenW, screenH)
    computeLayout(screenW, screenH)
end

-- Update (call each frame)
function MusicPlayer.update(dt, screenW, screenH)
    -- Recompute layout if screen size changes
    computeLayout(screenW, screenH)

    -- Animate slide
    local targetSlide = isOpen and 1 or 0
    if slideProgress < targetSlide then
        slideProgress = math.min(slideProgress + dt * slideSpeed, 1)
    elseif slideProgress > targetSlide then
        slideProgress = math.max(slideProgress - dt * slideSpeed, 0)
    end

    -- Update max scroll based on playlist size
    local playlist = Audio.getPlaylist()
    local itemHeight = 24
    local visibleHeight = layout.panelH - 100  -- Space for controls
    local totalHeight = #playlist * itemHeight
    maxScroll = math.max(0, totalHeight - visibleHeight)
    playlistScroll = math.min(playlistScroll, maxScroll)
end

-- Draw the player
function MusicPlayer.draw(screenW, screenH, fonts)
    local mx, my = love.mouse.getPosition()

    -- Always draw the music icon
    local iconHovered = pointInRect(mx, my, layout.iconX, layout.iconY, layout.iconSize, layout.iconSize)
    drawMusicIcon(layout.iconX, layout.iconY, layout.iconSize, iconHovered, Game.settings.musicEnabled)

    -- Draw panel if open or animating
    if slideProgress > 0 then
        local panelY = layout.panelY - layout.panelH * (1 - slideProgress)
        local panelAlpha = slideProgress

        -- Clip to panel area
        love.graphics.setScissor(layout.panelX - 2, layout.panelY, layout.panelW + 4, layout.panelH + 4)

        -- Panel background
        love.graphics.setColor(Colors.panelBg[1], Colors.panelBg[2], Colors.panelBg[3], Colors.panelBg[4] * panelAlpha)
        love.graphics.rectangle("fill", layout.panelX, panelY, layout.panelW, layout.panelH, 6)

        -- Panel border
        love.graphics.setColor(Colors.panelBorder[1], Colors.panelBorder[2], Colors.panelBorder[3], panelAlpha)
        love.graphics.setLineWidth(2)
        love.graphics.rectangle("line", layout.panelX, panelY, layout.panelW, layout.panelH, 6)

        -- Top highlight
        love.graphics.setColor(Colors.panelHighlight[1], Colors.panelHighlight[2], Colors.panelHighlight[3], Colors.panelHighlight[4] * panelAlpha)
        love.graphics.rectangle("fill", layout.panelX + 2, panelY + 2, layout.panelW - 4, 1)

        if slideProgress > 0.5 then  -- Only draw content when mostly visible
            local contentAlpha = (slideProgress - 0.5) * 2

            -- Set font
            if fonts and fonts.small then
                love.graphics.setFont(fonts.small)
            end

            local px = layout.panelX + 10
            local py = panelY + 10
            local innerW = layout.panelW - 20

            -- Current track name
            local currentTrack = Audio.getCurrentTrack()
            local trackName = currentTrack and currentTrack.name or "No track"
            love.graphics.setColor(Colors.textGold[1], Colors.textGold[2], Colors.textGold[3], contentAlpha)

            -- Truncate name if needed
            local font = love.graphics.getFont()
            local maxNameW = innerW
            while font:getWidth(trackName) > maxNameW and #trackName > 3 do
                trackName = trackName:sub(1, -2)
            end
            if currentTrack and trackName ~= currentTrack.name then
                trackName = trackName .. "..."
            end
            love.graphics.print(trackName, px, py)
            py = py + 18

            -- Progress bar
            local progress = Audio.getDuration() > 0 and (Audio.getPosition() / Audio.getDuration()) or 0
            local progressHovered = drawProgressBar(px, py, innerW, 8, progress, mx, my)
            py = py + 14

            -- Time display
            love.graphics.setColor(Colors.textDim[1], Colors.textDim[2], Colors.textDim[3], contentAlpha)
            local posStr = Audio.formatTime(Audio.getPosition())
            local durStr = Audio.formatTime(Audio.getDuration())
            love.graphics.print(posStr, px, py)
            local durW = font:getWidth(durStr)
            love.graphics.print(durStr, px + innerW - durW, py)
            py = py + 18

            -- Control buttons
            local btnW = 32
            local btnH = 24
            local btnSpacing = 8
            local totalBtnW = btnW * 3 + btnSpacing * 2
            local btnX = px + (innerW - totalBtnW) / 2

            local prevHovered = pointInRect(mx, my, btnX, py, btnW, btnH)
            drawButton(btnX, py, btnW, btnH, "prev", prevHovered, false)
            btnX = btnX + btnW + btnSpacing

            local playPauseHovered = pointInRect(mx, my, btnX, py, btnW, btnH)
            local playIcon = Audio.isPaused() and "play" or "pause"
            drawButton(btnX, py, btnW, btnH, playIcon, playPauseHovered, false)
            btnX = btnX + btnW + btnSpacing

            local nextHovered = pointInRect(mx, my, btnX, py, btnW, btnH)
            drawButton(btnX, py, btnW, btnH, "next", nextHovered, false)
            py = py + btnH + 10

            -- Volume slider
            local volX = px + 20
            local volW = innerW - 30
            drawVolumeSlider(volX, py, volW, 16, Audio.getMusicVolume(), mx, my)
            py = py + 22

            -- Playlist (remaining space)
            local listY = py
            local listH = panelY + layout.panelH - py - 8

            if listH > 30 then
                -- List background
                love.graphics.setColor(Colors.progressBg[1], Colors.progressBg[2], Colors.progressBg[3], contentAlpha * 0.5)
                love.graphics.rectangle("fill", px, listY, innerW, listH, 4)

                -- Clip to list area
                love.graphics.setScissor(px, listY, innerW, listH)

                local playlist = Audio.getPlaylist()
                local itemH = 24
                local currentIndex = Audio.getCurrentIndex()

                for i, track in ipairs(playlist) do
                    local itemY = listY + (i - 1) * itemH - playlistScroll
                    if itemY + itemH > listY and itemY < listY + listH then
                        local itemHovered = pointInRect(mx, my, px, itemY, innerW, itemH) and slideProgress >= 1
                        drawPlaylistItem(px, itemY, innerW, itemH, track, i, i == currentIndex, itemHovered)
                    end
                end

                -- Scrollbar if needed
                if maxScroll > 0 then
                    local scrollbarH = math.max(20, listH * (listH / (maxScroll + listH)))
                    local scrollbarY = listY + (playlistScroll / maxScroll) * (listH - scrollbarH)
                    love.graphics.setColor(Colors.scrollbar)
                    love.graphics.rectangle("fill", px + innerW - 6, scrollbarY, 4, scrollbarH, 2)
                end
            end
        end

        love.graphics.setScissor()
    end
end

-- Handle mouse press
function MusicPlayer.mousepressed(x, y, button)
    if button ~= 1 then return false end

    -- Check icon click
    if pointInRect(x, y, layout.iconX, layout.iconY, layout.iconSize, layout.iconSize) then
        isOpen = not isOpen
        return true
    end

    -- If closed, ignore
    if slideProgress < 1 then return false end

    -- Check if click is in panel
    if not pointInRect(x, y, layout.panelX, layout.panelY, layout.panelW, layout.panelH) then
        -- Click outside panel - close it
        isOpen = false
        return false
    end

    local px = layout.panelX + 10
    local py = layout.panelY + 10
    local innerW = layout.panelW - 20

    -- Track name row
    py = py + 18

    -- Progress bar (py to py + 8)
    if pointInRect(x, y, px, py, innerW, 8) then
        isDraggingProgress = true
        local progress = (x - px) / innerW
        Audio.seek(progress)
        return true
    end
    py = py + 14

    -- Time display
    py = py + 18

    -- Control buttons
    local btnW = 32
    local btnH = 24
    local btnSpacing = 8
    local totalBtnW = btnW * 3 + btnSpacing * 2
    local btnX = px + (innerW - totalBtnW) / 2

    if pointInRect(x, y, btnX, py, btnW, btnH) then
        Audio.prevTrack()
        return true
    end
    btnX = btnX + btnW + btnSpacing

    if pointInRect(x, y, btnX, py, btnW, btnH) then
        Audio.togglePause()
        return true
    end
    btnX = btnX + btnW + btnSpacing

    if pointInRect(x, y, btnX, py, btnW, btnH) then
        Audio.nextTrack()
        return true
    end
    py = py + btnH + 10

    -- Volume slider
    local volX = px + 20
    local volW = innerW - 30
    if pointInRect(x, y, volX - 10, py, volW + 20, 16) then
        isDraggingVolume = true
        local vol = math.max(0, math.min(1, (x - volX) / volW))
        Audio.setMusicVolume(vol)
        return true
    end
    py = py + 22

    -- Playlist
    local listY = py
    local listH = layout.panelY + layout.panelH - py - 8

    if pointInRect(x, y, px, listY, innerW, listH) then
        local playlist = Audio.getPlaylist()
        local itemH = 24
        local clickedIndex = math.floor((y - listY + playlistScroll) / itemH) + 1
        if clickedIndex >= 1 and clickedIndex <= #playlist then
            Audio.playTrack(clickedIndex)
            return true
        end
    end

    return true  -- Consume click in panel
end

-- Handle mouse release
function MusicPlayer.mousereleased(x, y, button)
    if button == 1 then
        isDraggingProgress = false
        isDraggingVolume = false
    end
end

-- Handle mouse movement (for dragging)
function MusicPlayer.mousemoved(x, y, dx, dy)
    if isDraggingProgress then
        local px = layout.panelX + 10
        local innerW = layout.panelW - 20
        local progress = math.max(0, math.min(1, (x - px) / innerW))
        Audio.seek(progress)
    end

    if isDraggingVolume then
        local px = layout.panelX + 10
        local innerW = layout.panelW - 20
        local volX = px + 20
        local volW = innerW - 30
        local vol = math.max(0, math.min(1, (x - volX) / volW))
        Audio.setMusicVolume(vol)
    end
end

-- Handle mouse wheel (for playlist scrolling)
function MusicPlayer.wheelmoved(x, y)
    if not isOpen or slideProgress < 1 then return false end

    local mx, my = love.mouse.getPosition()

    -- Check if mouse is over playlist area
    local px = layout.panelX + 10
    local py = layout.panelY + 10 + 18 + 14 + 18 + 34 + 22
    local innerW = layout.panelW - 20
    local listH = layout.panelY + layout.panelH - py - 8

    if pointInRect(mx, my, px, py, innerW, listH) then
        playlistScroll = math.max(0, math.min(maxScroll, playlistScroll - y * 24))
        return true
    end

    return false
end

-- Check if player is open
function MusicPlayer.isOpen()
    return isOpen
end

-- Close the player
function MusicPlayer.close()
    isOpen = false
end

-- Check if point is in player UI (for input blocking)
function MusicPlayer.containsPoint(x, y)
    -- Icon always blocks
    if pointInRect(x, y, layout.iconX, layout.iconY, layout.iconSize, layout.iconSize) then
        return true
    end

    -- Panel blocks when open
    if slideProgress > 0 then
        if pointInRect(x, y, layout.panelX, layout.panelY, layout.panelW, layout.panelH) then
            return true
        end
    end

    return false
end

return MusicPlayer
