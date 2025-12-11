--[[
    SpriteCache - Modular canvas caching for sprite rendering

    Prerender complex sprites to canvases at load time, then blit during draw.
    Trades VRAM for massive draw call reduction (~5 canvas blits vs ~175 primitives).

    Usage:
        local cache = SpriteCache.new(64, 64)

        -- Prerender at load time
        cache:prerender("idle", function(params)
            -- Draw sprite centered at origin
            drawPeonBody(params.carry, params.frame)
        end, {
            carry = {"none", "gold", "lumber"},
            frame = {0, 1, 2, 3, 4, 5}
        })

        -- At draw time
        local canvas = cache:get("idle", "gold", 2)
        love.graphics.draw(canvas, x - 32, y - 54)
]]

local SpriteCache = {}
SpriteCache.__index = SpriteCache

-- Create a new sprite cache
-- width, height: canvas dimensions for each cached sprite
-- options: {originX, originY} - where sprite origin is within canvas
function SpriteCache.new(width, height, options)
    local self = setmetatable({}, SpriteCache)
    self.width = width or 64
    self.height = height or 64
    self.options = options or {}
    self.originX = self.options.originX or math.floor(self.width / 2)
    self.originY = self.options.originY or self.height - 10
    self.cache = {}
    self.stats = {
        canvasCount = 0,
        memoryBytes = 0
    }
    return self
end

-- Core prerendering function (from rotoscopescenes pattern)
-- drawFn receives params table and should draw sprite centered at origin
function SpriteCache:prerenderToCanvas(drawFn, params)
    local canvas = love.graphics.newCanvas(self.width, self.height)
    love.graphics.setCanvas(canvas)
    love.graphics.clear(0, 0, 0, 0)
    love.graphics.push()
    love.graphics.origin()
    love.graphics.translate(self.originX, self.originY)

    -- Reset graphics state for clean rendering
    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.setBlendMode("alpha")

    drawFn(params)

    love.graphics.pop()
    love.graphics.setCanvas()

    -- Track stats
    self.stats.canvasCount = self.stats.canvasCount + 1
    self.stats.memoryBytes = self.stats.memoryBytes + (self.width * self.height * 4)

    return canvas
end

-- Build cache key from variable parameters
local function buildKey(...)
    local parts = {...}
    local key = ""
    for i, part in ipairs(parts) do
        if i > 1 then key = key .. "|" end
        key = key .. tostring(part)
    end
    return key
end

-- Prerender all combinations for a state
-- stateName: base state identifier (e.g., "idle", "walk", "chop")
-- drawFn: function(params) that draws the sprite at origin
-- variants: table of arrays, generates all combinations
--   e.g., {carry = {"none", "gold"}, frame = {0, 1, 2}}
--   generates: (none,0), (none,1), (none,2), (gold,0), (gold,1), (gold,2)
function SpriteCache:prerender(stateName, drawFn, variants)
    self.cache[stateName] = self.cache[stateName] or {}

    -- Extract keys and values from variants
    local keys = {}
    local values = {}
    for k, v in pairs(variants) do
        table.insert(keys, k)
        table.insert(values, v)
    end

    -- Generate all combinations using recursive iteration
    local function iterate(depth, params, path)
        if depth > #keys then
            -- All parameters set, render this combination
            local canvas = self:prerenderToCanvas(drawFn, params)

            -- Store in nested structure for fast lookup
            local node = self.cache[stateName]
            for i = 1, #path - 1 do
                local key = path[i]
                node[key] = node[key] or {}
                node = node[key]
            end
            node[path[#path]] = canvas
            return
        end

        local key = keys[depth]
        for _, value in ipairs(values[depth]) do
            params[key] = value
            local newPath = {unpack(path)}
            table.insert(newPath, value)
            iterate(depth + 1, params, newPath)
        end
    end

    iterate(1, {}, {})
end

-- Get cached canvas for a state and variant values
-- Returns canvas or nil if not found
function SpriteCache:get(stateName, ...)
    local node = self.cache[stateName]
    if not node then return nil end

    local args = {...}
    for i, key in ipairs(args) do
        node = node[key]
        if not node then return nil end
    end

    return node
end

-- Get cache statistics
function SpriteCache:getStats()
    return {
        canvasCount = self.stats.canvasCount,
        memoryKB = math.floor(self.stats.memoryBytes / 1024),
        memoryMB = string.format("%.2f", self.stats.memoryBytes / (1024 * 1024))
    }
end

-- Clear all cached canvases (for cleanup or hot reload)
function SpriteCache:clear()
    for stateName, stateCache in pairs(self.cache) do
        -- Recursively release canvases
        local function releaseNode(node)
            if type(node) == "userdata" then
                -- It's a canvas, release it
                node:release()
            elseif type(node) == "table" then
                for _, child in pairs(node) do
                    releaseNode(child)
                end
            end
        end
        releaseNode(stateCache)
    end
    self.cache = {}
    self.stats.canvasCount = 0
    self.stats.memoryBytes = 0
end

-- Utility: Draw cached sprite with outline effect
-- Draws 4 offset copies (dark outline) then main sprite
function SpriteCache.drawWithOutline(canvas, x, y, outlineColor, outlineOffsets)
    outlineColor = outlineColor or {0.1, 0.08, 0.05, 0.7}
    outlineOffsets = outlineOffsets or {{-1.5, 0}, {1.5, 0}, {0, -1.5}, {0, 1.5}}

    -- Draw outline
    love.graphics.setColor(unpack(outlineColor))
    for _, off in ipairs(outlineOffsets) do
        love.graphics.draw(canvas, x + off[1], y + off[2])
    end

    -- Draw main sprite
    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.draw(canvas, x, y)
end

-- Utility: Draw cached sprite with outline and flash effect
function SpriteCache.drawWithOutlineAndFlash(canvas, x, y, flashTimer, outlineColor, outlineOffsets)
    SpriteCache.drawWithOutline(canvas, x, y, outlineColor, outlineOffsets)

    -- Flash effect for damage
    if flashTimer and flashTimer > 0 then
        love.graphics.setBlendMode("add")
        love.graphics.setColor(1, 1, 1, 0.9)
        love.graphics.draw(canvas, x, y)
        love.graphics.setBlendMode("alpha")
    end
end

return SpriteCache
