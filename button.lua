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
    
    return self
end

function Button:update(dt)
    if not self.enabled then
        self.state = "normal"
        return
    end
    
    local mx, my = love.mouse.getPosition()
    local isHovered = self:containsPoint(mx, my)
    
    if isHovered then
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
    
    love.graphics.setColor(color)
    love.graphics.rectangle("fill", self.x, self.y, self.width, self.height, self.cornerRadius)
    
    love.graphics.setColor(self.colors.border)
    love.graphics.setLineWidth(2)
    love.graphics.rectangle("line", self.x, self.y, self.width, self.height, self.cornerRadius)
    
    love.graphics.setColor(self.colors.text)
    love.graphics.setFont(self.font)
    local textWidth = self.font:getWidth(self.text)
    local textHeight = self.font:getHeight()
    local textX = self.x + (self.width - textWidth) / 2
    local textY = self.y + (self.height - textHeight) / 2
    love.graphics.print(self.text, textX, textY)
    
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

function Button:setPosition(x, y)
    self.x = x
    self.y = y
end

function Button:setText(text)
    self.text = text
end

return Button
