--[[
    Custom Cursor Module
    Draws a medieval-themed custom cursor.
    Can be used across different screens (title, config, gameplay, etc.)
]]

local Cursor = {}

-- Draw the normal pointer cursor (golden/bronze medieval style)
function Cursor.drawNormal(mx, my)
    local size = 20

    love.graphics.push()
    love.graphics.translate(mx, my)

    -- Shadow
    love.graphics.setColor(0, 0, 0, 0.3)
    love.graphics.polygon("fill", 3, 3, 3, size + 3, 8, size - 4 + 3, 12, size + 5 + 3, 15, size + 3, 10, size - 3 + 3, 18, size - 3 + 3)

    -- Main arrow body (golden/bronze medieval style)
    love.graphics.setColor(0.85, 0.7, 0.35, 1)
    love.graphics.polygon("fill", 0, 0, 0, size, 5, size - 4, 9, size + 5, 12, size, 7, size - 3, 15, size - 3)

    -- Inner highlight
    love.graphics.setColor(0.95, 0.85, 0.5, 1)
    love.graphics.polygon("fill", 2, 4, 2, size - 4, 5, size - 6)

    -- Outline
    love.graphics.setColor(0.3, 0.2, 0.1, 1)
    love.graphics.setLineWidth(1.5)
    love.graphics.polygon("line", 0, 0, 0, size, 5, size - 4, 9, size + 5, 12, size, 7, size - 3, 15, size - 3)

    -- Decorative dot at top
    love.graphics.setColor(0.7, 0.5, 0.3, 1)
    love.graphics.circle("fill", 1, 2, 2)

    love.graphics.pop()
    love.graphics.setColor(1, 1, 1, 1)
end

-- Draw cursor at current mouse position
function Cursor.draw()
    local mx, my = love.mouse.getPosition()
    Cursor.drawNormal(mx, my)
end

return Cursor
