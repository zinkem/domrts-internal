--[[
    Button Component
    Reusable button with hover/click states
]]

local Button = {}
Button.__index = Button

local colors = {
    normal = {0.3, 0.5, 0.8, 1},
    hover = {0.4, 0.6, 0.9, 1},
    pressed = {0.2, 0.4, 0.7, 1},
    text = {1, 1, 1, 1},
    border = {0.2, 0.3, 0.5, 1}
}

function Button.new(params)
    local self = setmetatable({}, Button)
    
    self.x = params.x or 0
    self.y = params.y or 0
    self.width = params.width or 200
    self.height = params.height or 50
    self.text = params.text or "Button"
    self.onClick = params.onClick or function() end
    self.font = params.font or love.graphics.getFont()
    self.colors = params.colors or colors
    self.cornerRadius = params.cornerRadius or 8
    
    self.state = "normal"
    self.enabled = true
    self.disabledReason = nil  -- Text to show on hover when disabled
    self.isHovered = false     -- Track hover even when disabled
    
    return self
end

function Button:update(dt)
    local mx, my = love.mouse.getPosition()
    self.isHovered = self:containsPoint(mx, my)
    
    if not self.enabled then
        self.state = "normal"
        return
    end
    
    if self.isHovered then
        if love.mouse.isDown(1) then
            self.state = "pressed"
        else
            self.state = "hover"
        end
    else
        self.state = "normal"
    end
end

function Button:draw()
    local color = self.colors[self.state] or self.colors.normal
    
    -- When disabled and hovered with a reason, turn red and show reason as text
    local displayText = self.text
    if not self.enabled and self.isHovered and self.disabledReason then
        love.graphics.setColor(0.7, 0.2, 0.2, 1)
        displayText = self.disabledReason
    elseif not self.enabled then
        -- Dim the button if disabled but not hovered
        love.graphics.setColor(color[1] * 0.5, color[2] * 0.5, color[3] * 0.5, color[4] * 0.7)
    else
        love.graphics.setColor(color)
    end
    love.graphics.rectangle("fill", self.x, self.y, self.width, self.height, self.cornerRadius)
    
    -- Border - red when showing reason, normal otherwise
    if not self.enabled and self.isHovered and self.disabledReason then
        love.graphics.setColor(0.5, 0.1, 0.1, 1)
    else
        love.graphics.setColor(self.colors.border)
    end
    love.graphics.setLineWidth(2)
    love.graphics.rectangle("line", self.x, self.y, self.width, self.height, self.cornerRadius)
    
    -- Text - white when showing reason, dimmed when disabled, normal otherwise
    if not self.enabled and self.isHovered and self.disabledReason then
        love.graphics.setColor(1, 1, 1, 1)
    elseif not self.enabled then
        love.graphics.setColor(self.colors.text[1] * 0.6, self.colors.text[2] * 0.6, self.colors.text[3] * 0.6, self.colors.text[4])
    else
        love.graphics.setColor(self.colors.text)
    end
    love.graphics.setFont(self.font)
    local textWidth = self.font:getWidth(displayText)
    local textHeight = self.font:getHeight()
    local textX = self.x + (self.width - textWidth) / 2
    local textY = self.y + (self.height - textHeight) / 2
    love.graphics.print(displayText, textX, textY)
    
    love.graphics.setColor(1, 1, 1, 1)
end

function Button:containsPoint(px, py)
    return px >= self.x and px <= self.x + self.width and
           py >= self.y and py <= self.y + self.height
end

function Button:mousepressed(x, y, button)
    if button == 1 and self.enabled and self:containsPoint(x, y) then
        self.state = "pressed"
    end
end

function Button:mousereleased(x, y, button)
    if button == 1 and self.enabled and self:containsPoint(x, y) and self.state == "pressed" then
        self.onClick()
    end
    if self:containsPoint(x, y) then
        self.state = "hover"
    else
        self.state = "normal"
    end
end

function Button:setEnabled(enabled)
    self.enabled = enabled
end

function Button:setDisabledReason(reason)
    self.disabledReason = reason
end

function Button:setPosition(x, y)
    self.x = x
    self.y = y
end

function Button:setText(text)
    self.text = text
end

return Button
