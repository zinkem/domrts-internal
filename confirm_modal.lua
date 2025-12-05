--[[
    Confirm Modal Component
    Reusable confirmation dialog
]]

local Button = require("button")

local ConfirmModal = {}
ConfirmModal.__index = ConfirmModal

local colors = {
    overlay = {0, 0, 0, 0.7},
    background = {0.15, 0.18, 0.25, 1},
    border = {0.3, 0.4, 0.6, 1},
    text = {1, 1, 1, 1},
    title = {0.9, 0.9, 0.95, 1}
}

function ConfirmModal.new(params)
    local self = setmetatable({}, ConfirmModal)
    
    self.message = params.message or "Are you sure?"
    self.confirmText = params.confirmText or "Confirm"
    self.cancelText = params.cancelText or "Cancel"
    self.onConfirm = params.onConfirm or function() end
    self.onCancel = params.onCancel or function() end
    self.font = params.font or love.graphics.getFont()
    self.titleFont = params.titleFont or self.font
    
    self.width = params.width or 400
    self.height = params.height or 200
    self.isVisible = false
    
    local screenW, screenH = love.graphics.getDimensions()
    self.x = (screenW - self.width) / 2
    self.y = (screenH - self.height) / 2
    
    local buttonWidth = 120
    local buttonHeight = 40
    local buttonSpacing = 20
    local buttonsY = self.y + self.height - buttonHeight - 30
    local buttonsStartX = self.x + (self.width - (buttonWidth * 2 + buttonSpacing)) / 2
    
    self.confirmButton = Button.new({
        x = buttonsStartX,
        y = buttonsY,
        width = buttonWidth,
        height = buttonHeight,
        text = self.confirmText,
        font = self.font,
        colors = {
            normal = {0.6, 0.3, 0.3, 1},
            hover = {0.7, 0.4, 0.4, 1},
            pressed = {0.5, 0.2, 0.2, 1},
            text = {1, 1, 1, 1},
            border = {0.4, 0.2, 0.2, 1}
        },
        onClick = function()
            self:hide()
            self.onConfirm()
        end
    })
    
    self.cancelButton = Button.new({
        x = buttonsStartX + buttonWidth + buttonSpacing,
        y = buttonsY,
        width = buttonWidth,
        height = buttonHeight,
        text = self.cancelText,
        font = self.font,
        colors = {
            normal = {0.3, 0.4, 0.5, 1},
            hover = {0.4, 0.5, 0.6, 1},
            pressed = {0.2, 0.3, 0.4, 1},
            text = {1, 1, 1, 1},
            border = {0.2, 0.3, 0.4, 1}
        },
        onClick = function()
            self:hide()
            self.onCancel()
        end
    })
    
    return self
end

function ConfirmModal:show()
    self.isVisible = true
end

function ConfirmModal:hide()
    self.isVisible = false
end

function ConfirmModal:toggle()
    self.isVisible = not self.isVisible
end

function ConfirmModal:update(dt)
    if not self.isVisible then return end
    
    self.confirmButton:update(dt)
    self.cancelButton:update(dt)
end

function ConfirmModal:draw()
    if not self.isVisible then return end
    
    local screenW, screenH = love.graphics.getDimensions()
    
    love.graphics.setColor(colors.overlay)
    love.graphics.rectangle("fill", 0, 0, screenW, screenH)
    
    love.graphics.setColor(colors.background)
    love.graphics.rectangle("fill", self.x, self.y, self.width, self.height, 12)
    
    love.graphics.setColor(colors.border)
    love.graphics.setLineWidth(2)
    love.graphics.rectangle("line", self.x, self.y, self.width, self.height, 12)
    
    love.graphics.setColor(colors.text)
    love.graphics.setFont(self.font)
    local textWidth = self.font:getWidth(self.message)
    local textX = self.x + (self.width - textWidth) / 2
    local textY = self.y + 50
    love.graphics.print(self.message, textX, textY)
    
    self.confirmButton:draw()
    self.cancelButton:draw()
    
    love.graphics.setColor(1, 1, 1, 1)
end

function ConfirmModal:mousepressed(x, y, button)
    if not self.isVisible then return false end
    
    self.confirmButton:mousepressed(x, y, button)
    self.cancelButton:mousepressed(x, y, button)
    
    return true
end

function ConfirmModal:mousereleased(x, y, button)
    if not self.isVisible then return false end
    
    self.confirmButton:mousereleased(x, y, button)
    self.cancelButton:mousereleased(x, y, button)
    
    return true
end

function ConfirmModal:keypressed(key)
    if not self.isVisible then return false end
    
    if key == "escape" then
        self:hide()
        self.onCancel()
    elseif key == "return" or key == "kpenter" then
        self:hide()
        self.onConfirm()
    end
    
    return true
end

function ConfirmModal:isActive()
    return self.isVisible
end

return ConfirmModal
