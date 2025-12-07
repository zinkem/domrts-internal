--[[
    Palette Shader System
    Renders images with point filtering and color palette reduction
    
    Usage:
    1. Create a PaletteRenderer with target resolution
    2. Call beginCapture() before drawing
    3. Draw your content
    4. Call endCapture() to finalize
    5. Call draw(x, y) to render the palettized result
]]

local PaletteShader = {}
PaletteShader.__index = PaletteShader

-- 56-color palette - a rich retro palette with good color distribution
-- Based on a mix of earth tones, jewel tones, and classic game colors
PaletteShader.DEFAULT_PALETTE = {
    -- Blacks and grays (6)
    {0.00, 0.00, 0.00},  -- Black
    {0.13, 0.13, 0.13},  -- Dark gray
    {0.27, 0.27, 0.27},  -- Gray
    {0.47, 0.47, 0.47},  -- Medium gray
    {0.73, 0.73, 0.73},  -- Light gray
    {1.00, 1.00, 1.00},  -- White
    
    -- Browns/Earth tones (8)
    {0.20, 0.12, 0.05},  -- Dark brown
    {0.35, 0.22, 0.10},  -- Brown
    {0.50, 0.35, 0.20},  -- Medium brown
    {0.65, 0.48, 0.30},  -- Tan
    {0.80, 0.65, 0.45},  -- Light tan
    {0.55, 0.40, 0.25},  -- Leather
    {0.40, 0.30, 0.20},  -- Dark leather
    {0.70, 0.55, 0.35},  -- Sand
    
    -- Reds (6)
    {0.30, 0.05, 0.05},  -- Dark red
    {0.55, 0.10, 0.10},  -- Crimson
    {0.75, 0.20, 0.15},  -- Red
    {0.90, 0.35, 0.30},  -- Bright red
    {0.95, 0.55, 0.50},  -- Light red/pink
    {0.70, 0.25, 0.20},  -- Rust
    
    -- Oranges/Yellows (6)
    {0.60, 0.35, 0.10},  -- Dark orange
    {0.85, 0.50, 0.15},  -- Orange
    {1.00, 0.70, 0.25},  -- Gold
    {0.95, 0.85, 0.40},  -- Yellow
    {1.00, 0.95, 0.60},  -- Light yellow
    {0.72, 0.58, 0.22},  -- Bronze gold
    
    -- Greens (8)
    {0.05, 0.15, 0.05},  -- Dark green
    {0.10, 0.30, 0.10},  -- Forest green
    {0.20, 0.50, 0.20},  -- Green
    {0.35, 0.70, 0.35},  -- Bright green
    {0.55, 0.85, 0.55},  -- Light green
    {0.25, 0.40, 0.25},  -- Olive
    {0.40, 0.55, 0.30},  -- Sage
    {0.15, 0.35, 0.20},  -- Dark teal-green
    
    -- Blues (8)
    {0.05, 0.08, 0.20},  -- Dark navy
    {0.10, 0.15, 0.35},  -- Navy
    {0.15, 0.25, 0.55},  -- Dark blue
    {0.25, 0.45, 0.75},  -- Blue
    {0.45, 0.65, 0.90},  -- Light blue
    {0.70, 0.85, 1.00},  -- Sky blue
    {0.15, 0.40, 0.50},  -- Teal
    {0.10, 0.25, 0.35},  -- Dark teal
    
    -- Purples/Magentas (6)
    {0.20, 0.08, 0.25},  -- Dark purple
    {0.40, 0.15, 0.45},  -- Purple
    {0.60, 0.30, 0.65},  -- Bright purple
    {0.80, 0.50, 0.80},  -- Light purple
    {0.55, 0.20, 0.40},  -- Magenta
    {0.75, 0.40, 0.55},  -- Pink
    
    -- Skin tones (4)
    {0.95, 0.80, 0.65},  -- Light skin
    {0.82, 0.65, 0.50},  -- Medium skin
    {0.65, 0.50, 0.38},  -- Tan skin
    {0.45, 0.32, 0.22},  -- Dark skin
    
    -- Marble/Stone (4)
    {0.88, 0.86, 0.82},  -- Light marble
    {0.75, 0.72, 0.68},  -- Medium marble
    {0.58, 0.55, 0.52},  -- Dark marble
    {0.45, 0.42, 0.38},  -- Stone
}

-- GLSL shader code for palette reduction
local shaderCode = [[
extern Image palette;
extern float paletteSize;
extern vec2 targetResolution;
extern bool enableDithering;
extern float ditherStrength;

// Bayer 4x4 dithering matrix
const float bayerMatrix[16] = float[16](
    0.0/16.0,  8.0/16.0,  2.0/16.0, 10.0/16.0,
   12.0/16.0,  4.0/16.0, 14.0/16.0,  6.0/16.0,
    3.0/16.0, 11.0/16.0,  1.0/16.0,  9.0/16.0,
   15.0/16.0,  7.0/16.0, 13.0/16.0,  5.0/16.0
);

float getBayerValue(vec2 pos) {
    int x = int(mod(pos.x, 4.0));
    int y = int(mod(pos.y, 4.0));
    return bayerMatrix[y * 4 + x] - 0.5;
}

vec4 effect(vec4 color, Image tex, vec2 texture_coords, vec2 screen_coords) {
    // Sample the input texture
    vec4 texColor = Texel(tex, texture_coords) * color;
    
    // If alpha is very low, discard
    if (texColor.a < 0.1) {
        return vec4(0.0);
    }
    
    vec3 inputColor = texColor.rgb;
    
    // Apply dithering offset if enabled
    if (enableDithering) {
        vec2 pixelPos = texture_coords * targetResolution;
        float dither = getBayerValue(pixelPos) * ditherStrength;
        inputColor = inputColor + vec3(dither);
        inputColor = clamp(inputColor, 0.0, 1.0);
    }
    
    // Find closest color in palette
    float minDist = 999999.0;
    vec3 closestColor = inputColor;
    
    for (float i = 0.0; i < paletteSize; i += 1.0) {
        // Sample palette color (stored as 1D texture)
        vec4 palColor = Texel(palette, vec2((i + 0.5) / paletteSize, 0.5));
        
        // Calculate color distance (weighted for perceptual accuracy)
        vec3 diff = inputColor - palColor.rgb;
        // Weighted distance - human eye is more sensitive to green
        float dist = diff.r * diff.r * 0.299 + 
                     diff.g * diff.g * 0.587 + 
                     diff.b * diff.b * 0.114;
        
        if (dist < minDist) {
            minDist = dist;
            closestColor = palColor.rgb;
        }
    }
    
    return vec4(closestColor, texColor.a);
}
]]

function PaletteShader.new(params)
    local self = setmetatable({}, PaletteShader)
    
    params = params or {}
    
    -- Target resolution for pixelation
    self.targetWidth = params.width or 128
    self.targetHeight = params.height or 128
    
    -- Dithering settings
    self.enableDithering = params.dithering ~= false
    self.ditherStrength = params.ditherStrength or 0.03
    
    -- Create the shader
    local success, result = pcall(love.graphics.newShader, shaderCode)
    if success then
        self.shader = result
    else
        print("Shader compilation error: " .. tostring(result))
        self.shader = nil
    end
    
    -- Set default filter to nearest BEFORE creating canvas
    love.graphics.setDefaultFilter("nearest", "nearest")
    
    -- Create canvas for capturing rendered content
    self.canvas = love.graphics.newCanvas(self.targetWidth, self.targetHeight)
    self.canvas:setFilter("nearest", "nearest")  -- Point filtering!
    
    -- Set up palette
    self:setPalette(params.palette or PaletteShader.DEFAULT_PALETTE)
    
    -- Update shader uniforms
    self:updateUniforms()
    
    return self
end

function PaletteShader:setPalette(palette)
    self.palette = palette
    
    -- Create a 1D texture (Nx1 image) for the palette
    local paletteSize = #palette
    local imageData = love.image.newImageData(paletteSize, 1)
    
    for i, color in ipairs(palette) do
        imageData:setPixel(i - 1, 0, color[1], color[2], color[3], 1)
    end
    
    self.paletteTexture = love.graphics.newImage(imageData)
    self.paletteTexture:setFilter("nearest", "nearest")
    
    self:updateUniforms()
end

function PaletteShader:updateUniforms()
    if not self.shader then return end
    
    if self.paletteTexture then
        self.shader:send("palette", self.paletteTexture)
        self.shader:send("paletteSize", #self.palette)
    end
    self.shader:send("targetResolution", {self.targetWidth, self.targetHeight})
    self.shader:send("enableDithering", self.enableDithering)
    self.shader:send("ditherStrength", self.ditherStrength)
end

function PaletteShader:setResolution(width, height)
    self.targetWidth = width
    self.targetHeight = height
    
    -- Recreate canvas at new resolution with point filtering
    love.graphics.setDefaultFilter("nearest", "nearest")
    self.canvas = love.graphics.newCanvas(self.targetWidth, self.targetHeight)
    self.canvas:setFilter("nearest", "nearest")
    
    self:updateUniforms()
end

function PaletteShader:setDithering(enabled, strength)
    self.enableDithering = enabled
    if strength then
        self.ditherStrength = strength
    end
    self:updateUniforms()
end

function PaletteShader:beginCapture(clearColor)
    -- Store previous canvas
    self.previousCanvas = love.graphics.getCanvas()
    
    -- Ensure point filtering
    self.canvas:setFilter("nearest", "nearest")
    
    -- Set our canvas and clear it
    love.graphics.setCanvas(self.canvas)
    if clearColor then
        love.graphics.clear(clearColor[1], clearColor[2], clearColor[3], clearColor[4] or 0)
    else
        love.graphics.clear(0, 0, 0, 0)
    end
    
    -- Disable line smoothing for crisp pixels
    love.graphics.setLineStyle("rough")
    
    -- Reset transform for canvas-local drawing
    love.graphics.push()
    love.graphics.origin()
end

function PaletteShader:endCapture()
    -- Restore transform and canvas
    love.graphics.pop()
    love.graphics.setCanvas(self.previousCanvas)
    self.previousCanvas = nil
end

function PaletteShader:draw(x, y, scale)
    x = x or 0
    y = y or 0
    scale = scale or 1
    
    -- Save and disable scissor during canvas draw (canvas may extend beyond scissor)
    local sx, sy, sw, sh = love.graphics.getScissor()
    love.graphics.setScissor()
    
    -- Ensure point filtering before drawing
    self.canvas:setFilter("nearest", "nearest")
    
    -- Draw the captured canvas with our palette shader
    if self.shader then
        love.graphics.setShader(self.shader)
    end
    
    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.draw(self.canvas, x, y, 0, scale, scale)
    
    love.graphics.setShader()
    
    -- Restore scissor if it was set
    if sx then
        love.graphics.setScissor(sx, sy, sw, sh)
    end
end

function PaletteShader:getCanvas()
    return self.canvas
end

-- Utility: Create a renderer for a specific entity
function PaletteShader.createEntityRenderer(entity, width, height, palette)
    local renderer = PaletteShader.new({
        width = width,
        height = height,
        palette = palette,
        dithering = true,
        ditherStrength = 0.025
    })
    
    return renderer
end

-- Preset palettes
PaletteShader.PALETTES = {
    -- 16-color CGA-inspired
    CGA = {
        {0.00, 0.00, 0.00}, {0.00, 0.00, 0.67}, {0.00, 0.67, 0.00}, {0.00, 0.67, 0.67},
        {0.67, 0.00, 0.00}, {0.67, 0.00, 0.67}, {0.67, 0.33, 0.00}, {0.67, 0.67, 0.67},
        {0.33, 0.33, 0.33}, {0.33, 0.33, 1.00}, {0.33, 1.00, 0.33}, {0.33, 1.00, 1.00},
        {1.00, 0.33, 0.33}, {1.00, 0.33, 1.00}, {1.00, 1.00, 0.33}, {1.00, 1.00, 1.00},
    },
    
    -- 32-color palette (DB32 inspired)
    DB32 = {
        {0.00, 0.00, 0.00}, {0.13, 0.11, 0.20}, {0.27, 0.18, 0.29}, {0.38, 0.24, 0.31},
        {0.50, 0.31, 0.32}, {0.69, 0.44, 0.34}, {0.87, 0.60, 0.41}, {0.98, 0.82, 0.60},
        {0.98, 0.95, 0.80}, {0.78, 0.87, 0.60}, {0.55, 0.75, 0.45}, {0.33, 0.60, 0.40},
        {0.18, 0.42, 0.38}, {0.11, 0.27, 0.33}, {0.13, 0.18, 0.27}, {0.22, 0.24, 0.35},
        {0.33, 0.35, 0.47}, {0.45, 0.47, 0.58}, {0.60, 0.62, 0.69}, {0.78, 0.78, 0.82},
        {0.95, 0.95, 0.95}, {0.87, 0.82, 0.71}, {0.73, 0.65, 0.53}, {0.55, 0.47, 0.40},
        {0.36, 0.31, 0.31}, {0.27, 0.22, 0.27}, {0.36, 0.27, 0.35}, {0.53, 0.33, 0.40},
        {0.71, 0.40, 0.40}, {0.87, 0.53, 0.40}, {0.53, 0.40, 0.53}, {0.40, 0.33, 0.53},
    },
    
    -- Fantasy/RPG palette (good for medieval games)
    FANTASY = {
        -- Darks
        {0.05, 0.05, 0.08}, {0.12, 0.10, 0.15}, {0.20, 0.18, 0.22},
        -- Stone/Gray
        {0.35, 0.33, 0.30}, {0.50, 0.48, 0.45}, {0.65, 0.63, 0.60}, {0.80, 0.78, 0.75}, {0.92, 0.90, 0.87},
        -- Earth/Brown
        {0.25, 0.15, 0.08}, {0.40, 0.25, 0.12}, {0.55, 0.38, 0.20}, {0.70, 0.52, 0.32}, {0.85, 0.68, 0.48},
        -- Gold
        {0.45, 0.35, 0.12}, {0.65, 0.52, 0.18}, {0.82, 0.68, 0.25}, {0.95, 0.82, 0.40}, {1.00, 0.95, 0.60},
        -- Teal
        {0.08, 0.18, 0.22}, {0.12, 0.28, 0.35}, {0.18, 0.42, 0.52}, {0.28, 0.58, 0.68}, {0.45, 0.75, 0.82},
        -- Green
        {0.08, 0.20, 0.10}, {0.15, 0.35, 0.18}, {0.25, 0.50, 0.28}, {0.40, 0.68, 0.42},
        -- Red
        {0.35, 0.10, 0.08}, {0.55, 0.18, 0.12}, {0.75, 0.28, 0.20}, {0.90, 0.45, 0.35},
        -- Blue
        {0.10, 0.15, 0.30}, {0.18, 0.28, 0.50}, {0.30, 0.45, 0.70}, {0.50, 0.65, 0.88},
        -- Purple
        {0.22, 0.12, 0.28}, {0.38, 0.22, 0.45}, {0.55, 0.35, 0.62},
        -- Skin
        {0.95, 0.82, 0.68}, {0.82, 0.65, 0.52}, {0.65, 0.48, 0.38},
        -- Bronze
        {0.45, 0.35, 0.22}, {0.58, 0.48, 0.32}, {0.72, 0.60, 0.42},
        -- Marble
        {0.88, 0.86, 0.82}, {0.78, 0.75, 0.70}, {0.68, 0.65, 0.60},
        -- White
        {1.00, 1.00, 1.00},
    },
}

return PaletteShader
