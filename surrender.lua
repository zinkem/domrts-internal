--[[
    Surrender Dialog Module
    Handles the surrender confirmation dialog and credits screen
    Separated from gameplay.lua to avoid upvalue limit
]]

local ConfirmModal = require("confirm_modal")

local Surrender = {}

-- State
local modal = nil
local showingCredits = false
local onDefeatCallback = nil

-- Credits content
local creditsLines = {
    "", "Design & Programming", "Matthew Zinke", "",
    "Art & Graphics", "Pixel Art Assets", "",
    "Music & Sound", "Epic Medieval Tracks", "",
    "Made with LOVE2D", "", "Thank you for playing!",
}

function Surrender.init(onDefeat)
    onDefeatCallback = onDefeat
    showingCredits = false

    modal = ConfirmModal.new({
        message = "Do you want to surrender?",
        confirmText = "Yes",
        cancelText = "No",
        font = Game.fonts.medium,
        onConfirm = function()
            if onDefeatCallback then
                onDefeatCallback()
            end
            if Game.Replay then
                Game.Replay.log("GAME", "Player surrendered")
                Game.Replay.finish()
            end
        end,
        onCancel = function() end
    })
end

function Surrender.reset()
    showingCredits = false
    if modal then
        modal:hide()
    end
end

function Surrender.show()
    if modal then
        modal:show()
    end
end

function Surrender.isActive()
    return modal and modal:isActive()
end

function Surrender.isShowingCredits()
    return showingCredits
end

function Surrender.showCredits()
    showingCredits = true
end

function Surrender.update(dt)
    if modal then
        modal:update(dt)
    end
end

function Surrender.draw()
    if modal then
        modal:draw()
    end
end

function Surrender.drawCreditsScreen(elapsedTime, endScreenButtonSetter)
    local screenW, screenH = love.graphics.getDimensions()
    local UIDraw = require("ui_draw")

    love.graphics.setColor(0.02, 0.02, 0.05, 0.95)
    love.graphics.rectangle("fill", 0, 0, screenW, screenH)

    local boxW, boxH = 500, 420
    local boxX, boxY = (screenW - boxW) / 2, (screenH - boxH) / 2
    UIDraw.drawStonePanel(boxX, boxY, boxW, boxH, 10)

    love.graphics.setFont(Game.fonts.title)
    love.graphics.setColor(0.72, 0.58, 0.26, 1)
    love.graphics.print("CREDITS", (screenW - Game.fonts.title:getWidth("CREDITS")) / 2, boxY + 25)

    love.graphics.setFont(Game.fonts.medium)
    love.graphics.setColor(0.92, 0.88, 0.80, 1)
    for i, line in ipairs(creditsLines) do
        love.graphics.print(line, (screenW - Game.fonts.medium:getWidth(line)) / 2, boxY + 90 + (i - 1) * 26)
    end

    love.graphics.setFont(Game.fonts.small)
    love.graphics.setColor(0.92, 0.88, 0.80, 0.5 + math.sin(elapsedTime * 2) * 0.3)
    love.graphics.print("Press SPACE to return to title", (screenW - Game.fonts.small:getWidth("Press SPACE to return to title")) / 2, boxY + boxH - 45)

    -- Set button bounds for click handling
    if endScreenButtonSetter then
        endScreenButtonSetter({x = boxX + (boxW - 180) / 2, y = boxY + boxH - 60, w = 180, h = 40})
    end
end

function Surrender.keypressed(key)
    if modal and modal:isActive() then
        modal:keypressed(key)
        return true
    end
    return false
end

function Surrender.mousepressed(x, y, button)
    if modal and modal:isActive() then
        modal:mousepressed(x, y, button)
        return true
    end
    return false
end

function Surrender.mousereleased(x, y, button)
    if modal and modal:isActive() then
        modal:mousereleased(x, y, button)
        return true
    end
    return false
end

return Surrender
