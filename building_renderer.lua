--[[
    Building Renderer Module
    Centralizes palette shader rendering for all buildings

    Usage:
        local BuildingRenderer = require("building_renderer")

        function Building:draw(x, y, size)
            if BuildingRenderer.begin("large") then
                self:drawBuildingIso(16, 19, size)
                BuildingRenderer.finish(x - 16, y - 19)
            else
                self:drawBuildingIso(x, y, size)
            end
        end
]]

local BuildingRenderer = {}

-- Canvas sizes for different building footprints
BuildingRenderer.CANVAS_SIZES = {
    small = 96,   -- 2x2 buildings (farm)
    large = 128,  -- 3x3 buildings (barracks, townhall, etc.)
}

-- Palette shader module (lazy-loaded)
local PaletteShader = nil
local shaderLoadAttempted = false

-- Shared renderers per size (lazy-initialized)
local renderers = {}

-- Load the palette shader module
local function loadShader()
    if shaderLoadAttempted then return PaletteShader end
    shaderLoadAttempted = true

    local success, result = pcall(function()
        return require("palette_shader")
    end)

    if success then
        PaletteShader = result
    else
        print("BuildingRenderer: Could not load palette_shader module")
    end

    return PaletteShader
end

-- Get or create a renderer for the given size
local function getRenderer(size)
    size = size or "large"

    if renderers[size] then
        -- Validate the canvas still exists
        local canvas = renderers[size]:getCanvas()
        if canvas then
            return renderers[size]
        else
            renderers[size] = nil
        end
    end

    local shader = loadShader()
    if not shader then return nil end

    local canvasSize = BuildingRenderer.CANVAS_SIZES[size] or 128

    local success, renderer = pcall(function()
        return shader.new({
            width = canvasSize,
            height = canvasSize,
            palette = shader.PALETTES.FANTASY,
            dithering = false,
        })
    end)

    if success and renderer then
        renderers[size] = renderer
        return renderer
    else
        print("BuildingRenderer: Failed to create renderer for size: " .. size)
        return nil
    end
end

--- Check if palette shader rendering is enabled
-- @return boolean
function BuildingRenderer.isEnabled()
    -- Check Game.settings if available, default to true
    if Game and Game.settings then
        return Game.settings.paletteShader ~= false
    end
    return true
end

--- Set whether palette shader rendering is enabled
-- @param enabled boolean
function BuildingRenderer.setEnabled(enabled)
    if Game and Game.settings then
        Game.settings.paletteShader = enabled
    end
end

--- Begin capturing for palette shader rendering
-- Call this before drawing building geometry
-- @param size string "small" or "large" (default: "large")
-- @return boolean true if capture started, false if should draw directly
function BuildingRenderer.begin(size)
    if not BuildingRenderer.isEnabled() then
        return false
    end

    local renderer = getRenderer(size)
    if not renderer then
        return false
    end

    renderer:beginCapture()
    return true
end

--- Finish capturing and render the result
-- Call this after drawing building geometry
-- @param x number screen X position
-- @param y number screen Y position
-- @param scale number optional scale factor (default: 1)
function BuildingRenderer.finish(x, y, scale)
    -- Find the active renderer (the one we just captured to)
    for _, renderer in pairs(renderers) do
        if renderer then
            renderer:endCapture()
            renderer:draw(x, y, scale or 1)
            return
        end
    end
end

--- Finish capturing and render with a specific size renderer
-- Use this if you need explicit control over which renderer to use
-- @param size string "small" or "large"
-- @param x number screen X position
-- @param y number screen Y position
-- @param scale number optional scale factor (default: 1)
function BuildingRenderer.finishWithSize(size, x, y, scale)
    local renderer = renderers[size or "large"]
    if renderer then
        renderer:endCapture()
        renderer:draw(x, y, scale or 1)
    end
end

--- Get the canvas size for a given size category
-- @param size string "small" or "large"
-- @return number canvas size in pixels
function BuildingRenderer.getCanvasSize(size)
    return BuildingRenderer.CANVAS_SIZES[size or "large"] or 128
end

--- Clear all cached renderers (useful for graphics context reset)
function BuildingRenderer.clearCache()
    renderers = {}
end

return BuildingRenderer
