--[[
    Button Component - Professional Medieval Metal Theme
    Features: Beveled borders, gradient fills, pressed states with depth
]]

local Button = {}
Button.__index = Button

-- Enhanced metal themed colors - VERY DARK/AGED
local defaultColors = {
    normal = {0.24, 0.22, 0.18, 1},
    hover = {0.32, 0.29, 0.24, 1},
    pressed = {0.16, 0.14, 0.12, 1},
    disabled = {0.18, 0.16, 0.14, 1},
    text = {0.90, 0.86, 0.76, 1},
    textDisabled = {0.45, 0.42, 0.38, 1},
    border = {0.45, 0.36, 0.22, 1},
    borderLight = {0.60, 0.48, 0.32, 1},
    borderDark = {0.22, 0.16, 0.10, 1},
    shine = {1.0, 0.90, 0.70, 0.25},
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
    self.cornerRadius = params.cornerRadius or 6
    
    -- Merge custom colors with defaults
    self.colors = {}
    for k, v in pairs(defaultColors) do
        self.colors[k] = params.colors and params.colors[k] or v
    end
    
    self.state = "normal"
    self.enabled = true
    self.disabledReason = nil
    self.isHovered = false
    
    return self
end

-- Helper: Draw gradient background
local function drawButtonGradient(x, y, w, h, colorTop, colorBottom, cornerRadius)
    local steps = math.ceil(h / 3)
    for i = 0, steps - 1 do
        local t = i / steps
        local segY = y + i * 3
        local segH = math.min(3, h - i * 3)
        love.graphics.setColor(
            colorTop[1] + (colorBottom[1] - colorTop[1]) * t,
            colorTop[2] + (colorBottom[2] - colorTop[2]) * t,
            colorTop[3] + (colorBottom[3] - colorTop[3]) * t,
            colorTop[4] or 1
        )
        love.graphics.rectangle("fill", x, segY, w, segH, 
            i == 0 and cornerRadius or 0, 
            i == 0 and cornerRadius or 0)
    end
end

-- Helper: Draw 3D rivet
local function drawSmallRivet(cx, cy, radius)
    love.graphics.setColor(0.75, 0.6, 0.35, 1)
    love.graphics.circle("fill", cx, cy, radius, 10)
    love.graphics.setColor(0.55, 0.42, 0.22, 1)
    love.graphics.circle("fill", cx + 0.3, cy + 0.3, radius * 0.7, 8)
    love.graphics.setColor(0.75, 0.6, 0.35, 1)
    love.graphics.circle("fill", cx, cy, radius * 0.5, 8)
    love.graphics.setColor(1, 0.95, 0.8, 0.8)
    love.graphics.circle("fill", cx - radius * 0.25, cy - radius * 0.25, radius * 0.25, 6)
end

function Button:update(dt)
    local mx, my = love.mouse.getPosition()
    self.isHovered = self:containsPoint(mx, my)
    
    if not self.enabled then
        self.state = "disabled"
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
    local x, y, w, h = self.x, self.y, self.width, self.height
    local cr = self.cornerRadius
    local isPressed = self.state == "pressed"
    local isDisabled = not self.enabled
    local showError = isDisabled and self.isHovered and self.disabledReason
    
    -- Offset for pressed effect
    local pressOffset = isPressed and 1 or 0
    
    -- 1. DROP SHADOW (skip if pressed)
    if not isPressed then
        love.graphics.setColor(0, 0, 0, 0.35)
        love.graphics.rectangle("fill", x + 2, y + 2, w, h, cr)
        love.graphics.setColor(0, 0, 0, 0.15)
        love.graphics.rectangle("fill", x + 3, y + 3, w, h, cr + 1)
    end
    
    -- Adjust position for press
    local dx, dy = x + pressOffset, y + pressOffset
    
    -- 2. DETERMINE COLORS
    local baseColor, topColor, bottomColor
    
    if showError then
        -- Error state (red)
        baseColor = {0.65, 0.22, 0.18, 1}
        topColor = {0.75, 0.30, 0.25, 1}
        bottomColor = {0.50, 0.15, 0.12, 1}
    elseif isDisabled then
        baseColor = self.colors.disabled
        topColor = {baseColor[1] + 0.05, baseColor[2] + 0.05, baseColor[3] + 0.04, 0.8}
        bottomColor = {baseColor[1] - 0.05, baseColor[2] - 0.05, baseColor[3] - 0.04, 0.8}
    else
        baseColor = self.colors[self.state] or self.colors.normal
        topColor = {baseColor[1] + 0.08, baseColor[2] + 0.08, baseColor[3] + 0.06, baseColor[4] or 1}
        bottomColor = {baseColor[1] - 0.08, baseColor[2] - 0.08, baseColor[3] - 0.06, baseColor[4] or 1}
    end
    
    -- Invert gradient when pressed for "pushed in" look
    if isPressed then
        topColor, bottomColor = bottomColor, topColor
    end
    
    -- 3. GRADIENT FILL
    drawButtonGradient(dx, dy, w, h, topColor, bottomColor, cr)
    
    -- 3.5 SURFACE NOISE (worn texture)
    local function btnHash(a, b)
        local hv = (a * 374761393 + b * 668265263) % 2147483647
        return (hv % 1000) / 1000
    end
    local numNoise = math.floor(w * h * 0.02)
    for i = 1, numNoise do
        local px = dx + 3 + btnHash(i + x, y) * (w - 6)
        local py = dy + 3 + btnHash(y, i + x) * (h - 6)
        local isLight = btnHash(i * 3, i * 7) > 0.45
        if isLight then
            love.graphics.setColor(1, 0.95, 0.85, 0.1)
        else
            love.graphics.setColor(0, 0, 0, 0.12)
        end
        love.graphics.rectangle("fill", px, py, 1, 1)
    end
    
    -- 4. INNER HIGHLIGHT (top edge, skip when pressed)
    if not isPressed then
        love.graphics.setColor(1, 1, 1, 0.15)
        love.graphics.rectangle("fill", dx + 3, dy + 2, w - 6, 2, 1)
    end
    
    -- 5. INNER SHADOW (bottom edge, stronger when pressed)
    local shadowAlpha = isPressed and 0.3 or 0.15
    love.graphics.setColor(0, 0, 0, shadowAlpha)
    love.graphics.rectangle("fill", dx + 3, dy + h - 4, w - 6, 3, 1)
    
    -- 6. BEVELED BORDER
    local borderColor = showError and {0.5, 0.12, 0.1, 1} or self.colors.border
    local borderLight = showError and {0.8, 0.4, 0.35, 1} or self.colors.borderLight
    local borderDark = showError and {0.35, 0.1, 0.08, 1} or self.colors.borderDark
    
    -- Outer dark stroke
    love.graphics.setColor(borderDark)
    love.graphics.setLineWidth(2.5)
    love.graphics.rectangle("line", dx, dy, w, h, cr)
    
    -- Main border
    love.graphics.setColor(borderColor)
    love.graphics.setLineWidth(1.5)
    love.graphics.rectangle("line", dx, dy, w, h, cr)
    
    -- Top/left highlight (skip when pressed)
    if not isPressed then
        love.graphics.setColor(borderLight[1], borderLight[2], borderLight[3], 0.6)
        love.graphics.setLineWidth(1)
        love.graphics.line(dx + cr, dy + 1, dx + w - cr, dy + 1)
        love.graphics.line(dx + 1, dy + cr, dx + 1, dy + h - cr)
    end
    
    -- Bottom/right shadow
    love.graphics.setColor(0, 0, 0, isPressed and 0.2 or 0.35)
    love.graphics.setLineWidth(1)
    love.graphics.line(dx + cr, dy + h - 1, dx + w - cr, dy + h - 1)
    love.graphics.line(dx + w - 1, dy + cr, dx + w - 1, dy + h - cr)
    
    -- 7. CORNER RIVETS (for larger buttons)
    if w > 80 and h > 30 then
        local rivetR = 2.5
        local inset = 8
        drawSmallRivet(dx + inset, dy + h/2, rivetR)
        drawSmallRivet(dx + w - inset, dy + h/2, rivetR)
    end
    
    -- 8. TEXT
    local displayText = showError and self.disabledReason or self.text
    love.graphics.setFont(self.font)
    
    local textW = self.font:getWidth(displayText)
    local textH = self.font:getHeight()
    local textX = dx + (w - textW) / 2
    local textY = dy + (h - textH) / 2
    
    -- Text shadow
    love.graphics.setColor(0, 0, 0, 0.5)
    love.graphics.print(displayText, textX + 1, textY + 1)
    
    -- Text color
    if showError then
        love.graphics.setColor(1, 0.9, 0.85, 1)
    elseif isDisabled then
        love.graphics.setColor(self.colors.textDisabled)
    else
        love.graphics.setColor(self.colors.text)
    end
    love.graphics.print(displayText, textX, textY)
    
    -- Reset
    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.setLineWidth(1)
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
    if self.enabled then
        if self:containsPoint(x, y) then
            self.state = "hover"
        else
            self.state = "normal"
        end
    end
end

function Button:setEnabled(enabled)
    self.enabled = enabled
    if not enabled then
        self.state = "disabled"
    end
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
