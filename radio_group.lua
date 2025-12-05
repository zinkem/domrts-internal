--[[
    Radio Group Component
    Reusable radio button group for toggles
]]

local RadioGroup = {}
RadioGroup.__index = RadioGroup

local colors = {
    label = {0.9, 0.9, 0.9, 1},
    circle = {0.4, 0.5, 0.7, 1},
    circleHover = {0.5, 0.6, 0.8, 1},
    selected = {0.3, 0.8, 0.5, 1},
    border = {0.6, 0.7, 0.8, 1}
}

function RadioGroup.new(params)
    local self = setmetatable({}, RadioGroup)
    
    self.x = params.x or 0
    self.y = params.y or 0
    self.label = params.label or "Option"
    self.options = params.options or {"On", "Off"}
    self.selected = params.selected or 1
    self.onChange = params.onChange or function() end
    self.font = params.font or love.graphics.getFont()
    self.spacing = params.spacing or 80
    self.radioRadius = params.radioRadius or 10
    
    self.hoverIndex = nil
    
    return self
end

function RadioGroup:update(dt)
    local mx, my = love.mouse.getPosition()
    self.hoverIndex = nil
    
    for i, option in ipairs(self.options) do
        local optionX = self.x + 100 + (i - 1) * self.spacing
        local optionY = self.y
        
        local dist = math.sqrt((mx - optionX)^2 + (my - optionY)^2)
        if dist <= self.radioRadius + 5 then
            self.hoverIndex = i
            break
        end
    end
end

function RadioGroup:draw()
    love.graphics.setColor(colors.label)
    love.graphics.setFont(self.font)
    love.graphics.print(self.label .. ":", self.x, self.y - self.font:getHeight() / 2)
    
    for i, option in ipairs(self.options) do
        local optionX = self.x + 100 + (i - 1) * self.spacing
        local optionY = self.y
        
        if self.hoverIndex == i then
            love.graphics.setColor(colors.circleHover)
        else
            love.graphics.setColor(colors.circle)
        end
        love.graphics.circle("line", optionX, optionY, self.radioRadius)
        
        if self.selected == i then
            love.graphics.setColor(colors.selected)
            love.graphics.circle("fill", optionX, optionY, self.radioRadius - 3)
        end
        
        love.graphics.setColor(colors.label)
        love.graphics.print(option, optionX + self.radioRadius + 8, optionY - self.font:getHeight() / 2)
    end
    
    love.graphics.setColor(1, 1, 1, 1)
end

function RadioGroup:mousepressed(x, y, button)
    if button ~= 1 then return end
    
    for i, option in ipairs(self.options) do
        local optionX = self.x + 100 + (i - 1) * self.spacing
        local optionY = self.y
        
        local dist = math.sqrt((x - optionX)^2 + (y - optionY)^2)
        if dist <= self.radioRadius + 5 then
            if self.selected ~= i then
                self.selected = i
                self.onChange(i, option)
            end
            break
        end
    end
end

function RadioGroup:getSelected()
    return self.selected, self.options[self.selected]
end

function RadioGroup:setSelected(index)
    if index >= 1 and index <= #self.options then
        self.selected = index
    end
end

return RadioGroup
