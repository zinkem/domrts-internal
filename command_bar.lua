--[[
    Command Bar Module
    Shared toolbar rendering for gameplay and dev preview

    This module handles drawing the bottom command bar with:
    - Entity info (name, HP, status)
    - Action buttons based on entity type
]]

local CommandBar = {}

-- Dependencies (loaded lazily)
local UIDraw
local UI
local Game

-- Button size constants
CommandBar.BUTTON_SIZE = 50
CommandBar.BUTTON_SPACING = 4
CommandBar.BAR_HEIGHT = 70

-- Initialize dependencies
local function ensureDeps()
    if not UIDraw then
        pcall(function() UIDraw = require("ui_draw") end)
    end
    if not UI then
        pcall(function() UI = require("ui") end)
    end
    if not Game then
        Game = _G.Game
    end
end

-- Get safe font (fallback if Game.fonts not available)
local function getFont(size)
    ensureDeps()
    if Game and Game.fonts then
        if size == "medium" then return Game.fonts.medium end
        if size == "small" then return Game.fonts.small end
    end
    return love.graphics.newFont(size == "medium" and 14 or 10)
end

-- Draw the command bar background
function CommandBar.drawBackground(screenW, screenH)
    ensureDeps()
    if UIDraw and UIDraw.drawCommandBar then
        UIDraw.drawCommandBar(screenW, screenH)
    else
        -- Fallback: simple dark bar
        local barY = screenH - CommandBar.BAR_HEIGHT
        love.graphics.setColor(0.12, 0.1, 0.08, 0.95)
        love.graphics.rectangle("fill", 0, barY, screenW, CommandBar.BAR_HEIGHT)
        love.graphics.setColor(0.4, 0.35, 0.25, 1)
        love.graphics.setLineWidth(2)
        love.graphics.line(0, barY, screenW, barY)
    end
end

-- Draw entity info section (left side of bar)
function CommandBar.drawEntityInfo(entity, x, y, showHP, showStatus)
    ensureDeps()

    if not entity then
        love.graphics.setColor(0.5, 0.45, 0.4, 1)
        love.graphics.setFont(getFont("medium"))
        love.graphics.print("No Selection", x, y)
        return
    end

    -- Entity name
    love.graphics.setColor(1, 0.9, 0.6, 1)
    love.graphics.setFont(getFont("medium"))
    love.graphics.print(entity.name or "Unknown", x, y)

    -- HP bar
    if showHP and entity.hp and entity.maxHp then
        local hpBarW = 120
        local hpBarH = 8
        local hpY = y + 22
        local hpPercent = entity.hp / entity.maxHp

        -- Background
        love.graphics.setColor(0.2, 0.15, 0.1, 1)
        love.graphics.rectangle("fill", x, hpY, hpBarW, hpBarH, 2)

        -- HP fill (green/yellow/red based on health)
        local hpColor = hpPercent > 0.5 and {0.3, 0.8, 0.3} or (hpPercent > 0.25 and {0.9, 0.7, 0.2} or {0.9, 0.3, 0.2})
        love.graphics.setColor(hpColor)
        love.graphics.rectangle("fill", x, hpY, hpBarW * hpPercent, hpBarH, 2)

        -- Border
        love.graphics.setColor(0.5, 0.4, 0.3, 1)
        love.graphics.setLineWidth(1)
        love.graphics.rectangle("line", x, hpY, hpBarW, hpBarH, 2)

        -- HP text
        love.graphics.setFont(getFont("small"))
        love.graphics.setColor(0.9, 0.85, 0.75, 1)
        love.graphics.print(math.floor(entity.hp) .. "/" .. entity.maxHp, x + hpBarW + 8, hpY - 2)
    end

    -- Status text
    if showStatus then
        love.graphics.setFont(getFont("small"))
        local statusY = y + 38

        if entity.isBuilding then
            love.graphics.setColor(0.6, 0.8, 1, 1)
            love.graphics.print("Building...", x, statusY)
        elseif entity.isProducing then
            love.graphics.setColor(0.9, 0.85, 0.6, 1)
            love.graphics.print("Training...", x, statusY)
        elseif entity.isUpgrading then
            love.graphics.setColor(0.95, 0.8, 0.3, 1)
            love.graphics.print("Upgrading...", x, statusY)
        elseif entity.getStateText then
            love.graphics.setColor(0.7, 0.7, 0.65, 1)
            love.graphics.print(entity:getStateText(), x, statusY)
        else
            love.graphics.setColor(0.6, 0.6, 0.55, 1)
            love.graphics.print("Ready", x, statusY)
        end
    end
end

-- Draw a single command button
function CommandBar.drawButton(x, y, btn, hovered, pressed)
    ensureDeps()

    local size = CommandBar.BUTTON_SIZE
    local enabled = btn.enabled ~= false  -- Default to enabled

    if UIDraw and UIDraw.drawCommandButton then
        UIDraw.drawCommandButton(x, y, size, size, btn.text, btn.hotkey, enabled, hovered, pressed, btn.icon)
    else
        -- Fallback: simple button
        if pressed then
            love.graphics.setColor(0.3, 0.25, 0.2, 1)
        elseif hovered then
            love.graphics.setColor(0.35, 0.28, 0.18, 1)
        else
            love.graphics.setColor(0.25, 0.22, 0.18, 1)
        end
        love.graphics.rectangle("fill", x, y, size, size, 4)

        love.graphics.setColor(hovered and {0.75, 0.6, 0.35, 1} or {0.5, 0.45, 0.35, 1})
        love.graphics.setLineWidth(hovered and 2 or 1)
        love.graphics.rectangle("line", x, y, size, size, 4)

        -- Button text
        love.graphics.setColor(enabled and {1, 0.95, 0.85, 1} or {0.5, 0.45, 0.4, 0.6})
        love.graphics.setFont(getFont("small"))
        love.graphics.print(btn.text or "", x + 4, y + size - 14)

        -- Hotkey
        if btn.hotkey then
            love.graphics.setColor(1, 0.9, 0.5, 1)
            love.graphics.print(btn.hotkey, x + 4, y + 4)
        end
    end
end

-- Draw a tooltip above the hovered button
function CommandBar.drawTooltip(btn, btnX, btnY)
    ensureDeps()

    local padding = 8
    local lineHeight = 16
    local lines = {}

    -- Name (always shown)
    table.insert(lines, {text = btn.text or "Unknown", color = {1, 0.9, 0.6, 1}})

    -- Cost (if present)
    if btn.cost then
        table.insert(lines, {text = "Cost: " .. btn.cost, color = {0.9, 0.85, 0.6, 0.9}})
    end

    -- Requirement (if present and button is disabled due to it)
    if btn.requirement then
        table.insert(lines, {text = "Requires: " .. btn.requirement, color = {0.9, 0.5, 0.4, 1}})
    end

    -- Calculate tooltip size
    local font = getFont("small")
    local maxWidth = 0
    for _, line in ipairs(lines) do
        local w = font:getWidth(line.text)
        if w > maxWidth then maxWidth = w end
    end

    local tooltipW = maxWidth + padding * 2
    local tooltipH = #lines * lineHeight + padding * 2 - 4

    -- Position tooltip above button, centered
    local tooltipX = btnX + (CommandBar.BUTTON_SIZE - tooltipW) / 2
    local tooltipY = btnY - tooltipH - 6

    -- Keep tooltip on screen
    local screenW = love.graphics.getWidth()
    if tooltipX < 4 then tooltipX = 4 end
    if tooltipX + tooltipW > screenW - 4 then tooltipX = screenW - tooltipW - 4 end

    -- Draw tooltip background
    love.graphics.setColor(0.1, 0.08, 0.06, 0.95)
    love.graphics.rectangle("fill", tooltipX, tooltipY, tooltipW, tooltipH, 4)

    -- Border
    love.graphics.setColor(0.5, 0.4, 0.25, 0.8)
    love.graphics.setLineWidth(1)
    love.graphics.rectangle("line", tooltipX, tooltipY, tooltipW, tooltipH, 4)

    -- Draw text lines
    love.graphics.setFont(font)
    for i, line in ipairs(lines) do
        love.graphics.setColor(line.color)
        love.graphics.print(line.text, tooltipX + padding, tooltipY + padding + (i - 1) * lineHeight - 2)
    end
end

-- Draw a row of command buttons
function CommandBar.drawButtons(buttons, startX, y, mouseX, mouseY)
    local size = CommandBar.BUTTON_SIZE
    local spacing = CommandBar.BUTTON_SPACING
    local hoveredBtn = nil
    local hoveredX, hoveredY = nil, nil

    for i, btn in ipairs(buttons) do
        local x = startX + (i - 1) * (size + spacing)
        local hovered = mouseX and mouseY and
                        mouseX >= x and mouseX <= x + size and
                        mouseY >= y and mouseY <= y + size
        local pressed = hovered and love.mouse.isDown(1)

        -- Store position for click detection
        btn.x = x
        btn.y = y
        btn.w = size
        btn.h = size
        btn.hovered = hovered

        CommandBar.drawButton(x, y, btn, hovered, pressed)

        -- Track hovered button for tooltip
        if hovered then
            hoveredBtn = btn
            hoveredX = x
            hoveredY = y
        end
    end

    -- Draw tooltip last (on top of everything)
    if hoveredBtn then
        CommandBar.drawTooltip(hoveredBtn, hoveredX, hoveredY)
    end
end

-- Draw complete command bar (simplified version for dev preview)
function CommandBar.drawSimple(screenW, screenH, entity, buttons)
    local barY = screenH - CommandBar.BAR_HEIGHT

    -- Background
    CommandBar.drawBackground(screenW, screenH)

    -- Entity info on left
    CommandBar.drawEntityInfo(entity, 15, barY + 10, true, true)

    -- Buttons starting at x=200
    local mouseX, mouseY = love.mouse.getPosition()
    CommandBar.drawButtons(buttons, 200, barY + 8, mouseX, mouseY)
end

return CommandBar
