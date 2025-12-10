--[[
    Title Screen - Desert Warrior Edition
    Features the warrior prominently with a side panel UI
    Color scheme: Teal, Gold, Sand
]]

local Title = {}

-- Import audio
local Audio
pcall(function() Audio = require("audio") end)

-- Local state
local animTimer = 0
local particles = {}
local medallionSparks = {}
local buttons = {}
local devButton = nil  -- Small icon button in corner
local checkboxes = {}

-- Background image state
local bgImage = nil
local bgCanvas = nil
local jiggleShader = nil
local jiggleTime = 0
local jiggleActive = false
local jiggleDuration = 1.2
local clickX, clickY = 0, 0

-- Background scroll state
local scrollOffset = 0
local scrollDirection = 1  -- 1 = down, -1 = up
local scrollSpeed = 0.8  -- pixels per second (very slow)

-- Color palette inspired by the succubus moonlight (desaturated)
local Colors = {
    -- Muted purples (from the night sky)
    purpleDark = {0.18, 0.14, 0.22, 1},
    purpleMid = {0.28, 0.22, 0.34, 1},
    purpleLight = {0.42, 0.35, 0.48, 1},
    purpleBright = {0.55, 0.45, 0.60, 1},

    -- Dusty rose/mauve (from her wings, less saturated)
    crimsonDark = {0.32, 0.18, 0.22, 1},
    crimsonMid = {0.48, 0.25, 0.32, 1},
    crimsonLight = {0.62, 0.38, 0.45, 1},
    crimsonBright = {0.75, 0.50, 0.55, 1},

    -- Silver/Moonlight (softer)
    silverDark = {0.50, 0.48, 0.52, 1},
    silverMid = {0.68, 0.66, 0.72, 1},
    silverLight = {0.82, 0.80, 0.85, 1},

    -- UI
    panelBg = {0.12, 0.10, 0.15, 0.88},
    panelBorder = {0.45, 0.35, 0.42, 1},
    textLight = {0.85, 0.82, 0.86, 1},
    textGold = {0.72, 0.45, 0.52, 1},  -- Dusty rose accent
    textMuted = {0.55, 0.52, 0.56, 1},
}

-- Sky color rotation shader (targets dark blue pixels)
local skyShader = nil
local skyShaderCode = [[
extern float time;

// Convert RGB to HSV
vec3 rgb2hsv(vec3 c) {
    vec4 K = vec4(0.0, -1.0 / 3.0, 2.0 / 3.0, -1.0);
    vec4 p = mix(vec4(c.bg, K.wz), vec4(c.gb, K.xy), step(c.b, c.g));
    vec4 q = mix(vec4(p.xyw, c.r), vec4(c.r, p.yzx), step(p.x, c.r));
    float d = q.x - min(q.w, q.y);
    float e = 1.0e-10;
    return vec3(abs(q.z + (q.w - q.y) / (6.0 * d + e)), d / (q.x + e), q.x);
}

// Convert HSV to RGB
vec3 hsv2rgb(vec3 c) {
    vec4 K = vec4(1.0, 2.0 / 3.0, 1.0 / 3.0, 3.0);
    vec3 p = abs(fract(c.xxx + K.xyz) * 6.0 - K.www);
    return c.z * mix(K.xxx, clamp(p - K.xxx, 0.0, 1.0), c.y);
}

vec4 effect(vec4 color, Image texture, vec2 texture_coords, vec2 screen_coords) {
    vec4 pixel = Texel(texture, texture_coords);
    vec3 hsv = rgb2hsv(pixel.rgb);

    // Detect sky pixels - wider range to catch more sky areas
    // Hue: blue to purple range (0.5 to 0.85)
    // Value: dark to mid (up to 0.65)
    // Saturation: any amount (lowered threshold)

    // Smoothly blend the mask for softer transitions
    float blueness = smoothstep(0.45, 0.55, hsv.x) * smoothstep(0.9, 0.8, hsv.x);
    float darkness = smoothstep(0.65, 0.35, hsv.z);
    float saturation = smoothstep(0.05, 0.15, hsv.y);
    float skyMask = blueness * darkness * saturation;

    // Rotate hue slowly for sky pixels
    float hueShift = sin(time * 0.15) * 0.08;  // Subtle rotation
    hsv.x = fract(hsv.x + hueShift * skyMask);

    // Slightly vary saturation too
    hsv.y = hsv.y + sin(time * 0.2) * 0.05 * skyMask;

    vec3 result = hsv2rgb(hsv);
    return vec4(result, pixel.a) * color;
}
]]

-- Gelatin jiggle shader
local jiggleShaderCode = [[
extern float time;
extern float intensity;
extern vec2 clickPos;
extern vec2 resolution;

vec4 effect(vec4 color, Image texture, vec2 texture_coords, vec2 screen_coords) {
    vec2 uv = texture_coords;
    vec2 clickUV = clickPos / resolution;
    float dist = distance(uv, clickUV);

    float wave = sin(dist * 20.0 - time * 10.0) * 0.5 + 0.5;
    float decay = exp(-dist * 2.5) * exp(-time * 2.5);

    float jiggleX = sin(uv.y * 12.0 + time * 14.0) * wave * decay * intensity * 0.025;
    float jiggleY = sin(uv.x * 10.0 + time * 12.0) * wave * decay * intensity * 0.02;
    jiggleX += sin(uv.y * 6.0 - time * 8.0) * decay * intensity * 0.012;
    jiggleY += cos(uv.x * 8.0 - time * 9.0) * decay * intensity * 0.01;

    vec2 displaced = clamp(uv + vec2(jiggleX, jiggleY), 0.0, 1.0);
    return Texel(texture, displaced) * color;
}
]]

-- Magical glow shader
local glowShader = nil
local glowShaderCode = [[
extern float time;
extern vec2 resolution;

vec4 effect(vec4 color, Image texture, vec2 texture_coords, vec2 screen_coords) {
    vec2 uv = texture_coords;
    vec4 original = Texel(texture, uv);

    // Sample blur for glow (simple box blur)
    float blurSize = 3.0 / resolution.x;
    vec4 blur = vec4(0.0);
    float samples = 0.0;

    for (float x = -2.0; x <= 2.0; x += 1.0) {
        for (float y = -2.0; y <= 2.0; y += 1.0) {
            vec2 offset = vec2(x, y) * blurSize;
            blur += Texel(texture, uv + offset);
            samples += 1.0;
        }
    }
    blur /= samples;

    // Extract bright areas (luminance threshold)
    float lum = dot(blur.rgb, vec3(0.299, 0.587, 0.114));
    float glowStrength = smoothstep(0.4, 0.8, lum) * 0.2;

    // Add magical color tint that shifts over time
    vec3 magicColor = vec3(
        0.6 + 0.4 * sin(time * 0.5),
        0.4 + 0.3 * sin(time * 0.7 + 1.0),
        0.8 + 0.2 * sin(time * 0.3 + 2.0)
    );

    // Combine original with glow
    vec3 glow = blur.rgb * magicColor * glowStrength;
    vec3 result = original.rgb + glow;

    // Add subtle vignette
    vec2 center = uv - 0.5;
    float vignette = 1.0 - dot(center, center) * 0.5;
    result *= vignette;

    // Add subtle shimmer at edges of bright areas
    float shimmer = sin(uv.x * 50.0 + time * 3.0) * sin(uv.y * 50.0 + time * 2.0);
    shimmer *= glowStrength * 0.1;
    result += vec3(shimmer) * magicColor;

    return vec4(result, original.a) * color;
}
]]

-- Fog/Light rays shader using Perlin noise (from rotoscopescenes)
local fogShader = nil
local fogShaderCode = [[
extern number time;
extern number noiseScale;
extern number fogIntensity;
extern number lightIntensity;
extern number oscillationSpeed;
extern number oscillationAmount;

// Permutation table for Perlin noise
vec3 mod289_3(vec3 x) {
    return x - floor(x * (1.0 / 289.0)) * 289.0;
}

vec4 mod289_4(vec4 x) {
    return x - floor(x * (1.0 / 289.0)) * 289.0;
}

vec3 permute3(vec3 x) {
    return mod289_3(((x * 34.0) + 1.0) * x);
}

vec4 permute4(vec4 x) {
    return mod289_4(((x * 34.0) + 1.0) * x);
}

vec4 taylorInvSqrt(vec4 r) {
    return 1.79284291400159 - 0.85373472095314 * r;
}

// 2D Perlin noise
float snoise(vec2 v) {
    const vec4 C = vec4(0.211324865405187,
                        0.366025403784439,
                        -0.577350269189626,
                        0.024390243902439);

    vec2 i  = floor(v + dot(v, C.yy));
    vec2 x0 = v - i + dot(i, C.xx);

    vec2 i1;
    i1 = (x0.x > x0.y) ? vec2(1.0, 0.0) : vec2(0.0, 1.0);
    vec4 x12 = x0.xyxy + C.xxzz;
    x12.xy -= i1;

    i = mod289_3(vec3(i, 0.0)).xy;
    vec3 p = permute3(permute3(i.y + vec3(0.0, i1.y, 1.0))
                     + i.x + vec3(0.0, i1.x, 1.0));

    vec3 m = max(0.5 - vec3(dot(x0, x0), dot(x12.xy, x12.xy), dot(x12.zw, x12.zw)), 0.0);
    m = m * m;
    m = m * m;

    vec3 x = 2.0 * fract(p * C.www) - 1.0;
    vec3 h = abs(x) - 0.5;
    vec3 ox = floor(x + 0.5);
    vec3 a0 = x - ox;

    m *= 1.79284291400159 - 0.85373472095314 * (a0 * a0 + h * h);

    vec3 g;
    g.x = a0.x * x0.x + h.x * x0.y;
    g.yz = a0.yz * x12.xz + h.yz * x12.yw;
    return 130.0 * dot(m, g);
}

// Fractal Brownian Motion
float fbm(vec2 p, float scale) {
    float value = 0.0;
    float amplitude = 0.5;
    float frequency = scale;

    for (int i = 0; i < 4; i++) {
        value += amplitude * snoise(p * frequency);
        frequency *= 2.0;
        amplitude *= 0.5;
    }

    return value;
}

vec4 effect(vec4 color, Image texture, vec2 texture_coords, vec2 screen_coords) {
    vec4 pixel = Texel(texture, texture_coords);

    // Calculate oscillating noise scale
    float scaleOscillation = sin(time * oscillationSpeed * 0.05) * oscillationAmount;
    float currentScale = noiseScale + scaleOscillation;

    // Slow drift for the noise pattern
    vec2 drift = vec2(time * 0.001, time * 0.00075);

    // Sample noise at current position with drift
    vec2 noiseCoord = texture_coords + drift;
    float noise1 = fbm(noiseCoord, currentScale);

    // Second layer with different drift for more complexity
    vec2 drift2 = vec2(time * -0.00075, time * 0.00125);
    float noise2 = fbm(texture_coords + drift2, currentScale * 1.5);

    // Combine noise layers
    float combinedNoise = (noise1 + noise2) * 0.5;

    // Remap noise from [-1, 1] to [0, 1] range
    float fogAmount = (combinedNoise + 1.0) * 0.5;

    // Apply contrast to make light shafts more defined
    fogAmount = smoothstep(0.2, 0.8, fogAmount);

    // Calculate darkening factor
    float darkness = mix(1.0, 1.0 - fogIntensity, 1.0 - fogAmount);

    // Calculate brightening factor for light rays
    float brightness = 1.0 + (fogAmount * lightIntensity);

    // Apply fog darkening and light brightening to the pixel
    vec3 result = pixel.rgb * darkness * brightness;

    // Add warm glow to bright areas (golden light rays)
    vec3 lightTint = vec3(1.1, 1.05, 0.95);
    result = mix(result, result * lightTint, fogAmount * lightIntensity * 0.5);

    // Add slight color tint to fog (cool blue-ish in shadows)
    vec3 fogTint = vec3(0.9, 0.95, 1.0);
    result = mix(result, result * fogTint, (1.0 - fogAmount) * 0.3);

    return vec4(result, pixel.a) * color;
}
]]

-- Hash for procedural effects
local function hash(a, b)
    local h = (a * 374761393 + b * 668265263) % 2147483647
    h = ((h * 1274126177) % 2147483647)
    return (h % 1000) / 1000
end

-- Spawn desert dust particles
local function spawnParticle()
    local screenW, screenH = love.graphics.getDimensions()
    local side = math.random() > 0.5
    table.insert(particles, {
        x = side and -10 or (screenW + 10),
        y = math.random(screenH * 0.3, screenH),
        vx = side and (20 + math.random() * 40) or (-20 - math.random() * 40),
        vy = -5 - math.random() * 15,
        size = 1 + math.random() * 3,
        life = 4 + math.random() * 3,
        maxLife = 4 + math.random() * 3,
        alpha = 0.2 + math.random() * 0.3,
        type = math.random() > 0.8 and "spark" or "dust"
    })
end

-- Spawn sparks/embers from behind the medallion
local function spawnMedallionSpark(cx, cy, radius)
    -- Spawn from edge of medallion
    local angle = math.random() * math.pi * 2
    local spawnRadius = radius * (0.85 + math.random() * 0.3)
    local sparkType = math.random()
    
    local spark = {
        x = cx + math.cos(angle) * spawnRadius,
        y = cy + math.sin(angle) * spawnRadius,
        vx = math.cos(angle) * (10 + math.random() * 30) + (math.random() - 0.5) * 20,
        vy = -40 - math.random() * 60,  -- Float upward
        size = 1.5 + math.random() * 3,
        life = 1.5 + math.random() * 2,
        maxLife = 1.5 + math.random() * 2,
        rotation = math.random() * math.pi * 2,
        rotSpeed = (math.random() - 0.5) * 4,
    }
    
    -- Different spark types
    if sparkType < 0.4 then
        -- Orange ember
        spark.color = {1.0, 0.5 + math.random() * 0.3, 0.1, 1}
        spark.type = "ember"
    elseif sparkType < 0.7 then
        -- Gold spark
        spark.color = {1.0, 0.85, 0.3, 1}
        spark.type = "spark"
        spark.size = spark.size * 0.7
    else
        -- Red flame bit
        spark.color = {1.0, 0.25, 0.1, 1}
        spark.type = "flame"
        spark.size = spark.size * 1.2
    end
    
    table.insert(medallionSparks, spark)
end

-- Draw the stone/metal medallion frame
local function drawMedallion(cx, cy, radius)
    -- Outer glow (magical moonlight glow from behind)
    for i = 30, 1, -1 do
        local glowRadius = radius + i * 6
        local alpha = (1 - i / 30) * 0.18
        local flicker = 0.9 + math.sin(animTimer * 2 + i * 0.3) * 0.1
        -- Shifting purple/blue/pink magical glow
        local r = 0.5 + 0.15 * math.sin(animTimer * 0.5)
        local g = 0.3 + 0.1 * math.sin(animTimer * 0.7 + 1)
        local b = 0.7 + 0.15 * math.sin(animTimer * 0.3 + 2)
        love.graphics.setColor(r, g, b, alpha * flicker)
        love.graphics.circle("fill", cx, cy, glowRadius)
    end
    
    -- Dark stone base
    love.graphics.setColor(0.08, 0.07, 0.06, 1)
    love.graphics.circle("fill", cx, cy, radius)
    
    -- Stone texture rings
    for i = 1, 5 do
        local ringRadius = radius * (0.3 + i * 0.14)
        local shade = 0.12 + i * 0.02
        love.graphics.setColor(shade, shade * 0.9, shade * 0.8, 0.5)
        love.graphics.setLineWidth(2)
        love.graphics.circle("line", cx, cy, ringRadius)
    end
    
    -- Inner gradient (darker center)
    for i = 0, radius * 0.6, 2 do
        local t = i / (radius * 0.6)
        local alpha = (1 - t) * 0.4
        love.graphics.setColor(0, 0, 0, alpha)
        love.graphics.circle("fill", cx, cy, radius * 0.6 - i)
    end
    
    -- Outer bronze ring
    love.graphics.setLineWidth(12)
    love.graphics.setColor(Colors.crimsonDark[1] * 0.7, Colors.crimsonDark[2] * 0.7, Colors.crimsonDark[3] * 0.7, 1)
    love.graphics.circle("line", cx, cy, radius - 6)
    
    -- Bronze ring highlight
    love.graphics.setLineWidth(3)
    love.graphics.setColor(Colors.crimsonMid[1], Colors.crimsonMid[2], Colors.crimsonMid[3], 0.6)
    love.graphics.arc("line", "open", cx, cy, radius - 6, -math.pi * 0.8, -math.pi * 0.2)
    
    -- Inner bronze ring
    love.graphics.setLineWidth(6)
    love.graphics.setColor(Colors.crimsonDark[1] * 0.6, Colors.crimsonDark[2] * 0.6, Colors.crimsonDark[3] * 0.6, 1)
    love.graphics.circle("line", cx, cy, radius * 0.75)
    
    -- Decorative rivets around the edge
    local numRivets = 16
    for i = 1, numRivets do
        local angle = (i / numRivets) * math.pi * 2 - math.pi / 2
        local rx = cx + math.cos(angle) * (radius - 20)
        local ry = cy + math.sin(angle) * (radius - 20)
        
        -- Rivet base
        love.graphics.setColor(Colors.crimsonDark)
        love.graphics.circle("fill", rx, ry, 6)
        -- Rivet highlight
        love.graphics.setColor(Colors.crimsonLight[1], Colors.crimsonLight[2], Colors.crimsonLight[3], 0.7)
        love.graphics.circle("fill", rx - 1.5, ry - 1.5, 2.5)
        -- Rivet shadow
        love.graphics.setColor(0, 0, 0, 0.4)
        love.graphics.arc("fill", rx, ry, 5, math.pi * 0.2, math.pi * 0.8)
    end
    
    -- Center emblem (abstract symbol)
    love.graphics.setColor(Colors.crimsonMid[1], Colors.crimsonMid[2], Colors.crimsonMid[3], 0.8)
    love.graphics.setLineWidth(4)
    -- Diamond shape
    local emblemSize = radius * 0.25
    love.graphics.polygon("line",
        cx, cy - emblemSize,
        cx + emblemSize, cy,
        cx, cy + emblemSize,
        cx - emblemSize, cy
    )
    -- Inner diamond
    love.graphics.setLineWidth(2)
    love.graphics.setColor(Colors.crimsonLight[1], Colors.crimsonLight[2], Colors.crimsonLight[3], 0.5)
    local innerSize = emblemSize * 0.5
    love.graphics.polygon("line",
        cx, cy - innerSize,
        cx + innerSize, cy,
        cx, cy + innerSize,
        cx - innerSize, cy
    )
end

-- Draw sparks (called after medallion so they appear in front)
local function drawMedallionSparks()
    for _, spark in ipairs(medallionSparks) do
        local alpha = (spark.life / spark.maxLife)
        local flickerAlpha = alpha * (0.7 + math.sin(animTimer * 20 + spark.rotation) * 0.3)
        
        love.graphics.setColor(spark.color[1], spark.color[2], spark.color[3], flickerAlpha)
        
        if spark.type == "ember" then
            -- Glowing ember with soft edge
            love.graphics.circle("fill", spark.x, spark.y, spark.size)
            love.graphics.setColor(1, 0.9, 0.5, flickerAlpha * 0.5)
            love.graphics.circle("fill", spark.x, spark.y, spark.size * 0.5)
        elseif spark.type == "spark" then
            -- Sharp bright spark
            love.graphics.circle("fill", spark.x, spark.y, spark.size)
        else
            -- Flame wisp (elongated)
            love.graphics.push()
            love.graphics.translate(spark.x, spark.y)
            love.graphics.rotate(spark.rotation)
            love.graphics.ellipse("fill", 0, 0, spark.size * 0.6, spark.size * 1.5)
            love.graphics.pop()
        end
    end
end

-- Draw a stylized button
local function drawButton(btn, mx, my)
    local x, y, w, h = btn.x, btn.y, btn.w, btn.h
    local hovered = mx >= x and mx <= x + w and my >= y and my <= y + h
    local isPrimary = btn.primary
    
    -- Button glow on hover
    if hovered then
        love.graphics.setColor(Colors.purpleBright[1], Colors.purpleBright[2], Colors.purpleBright[3], 0.15)
        love.graphics.rectangle("fill", x - 4, y - 4, w + 8, h + 8, 10)
    end
    
    -- Button background
    if isPrimary then
        -- Gold gradient for primary
        for i = 0, h - 1 do
            local t = i / h
            local r = Colors.crimsonDark[1] + (Colors.crimsonMid[1] - Colors.crimsonDark[1]) * (1 - t * 0.5)
            local g = Colors.crimsonDark[2] + (Colors.crimsonMid[2] - Colors.crimsonDark[2]) * (1 - t * 0.5)
            local b = Colors.crimsonDark[3] + (Colors.crimsonMid[3] - Colors.crimsonDark[3]) * (1 - t * 0.5)
            if hovered then r, g, b = r + 0.1, g + 0.1, b + 0.05 end
            love.graphics.setColor(r, g, b, 1)
            love.graphics.rectangle("fill", x, y + i, w, 1)
        end
    else
        -- Teal for regular buttons
        for i = 0, h - 1 do
            local t = i / h
            local baseColor = hovered and Colors.purpleMid or Colors.purpleDark
            local r = baseColor[1] * (1 - t * 0.3)
            local g = baseColor[2] * (1 - t * 0.3)
            local b = baseColor[3] * (1 - t * 0.3)
            love.graphics.setColor(r, g, b, 0.95)
            love.graphics.rectangle("fill", x, y + i, w, 1)
        end
    end
    
    -- Border
    love.graphics.setLineWidth(isPrimary and 2 or 1)
    if isPrimary then
        love.graphics.setColor(Colors.crimsonLight)
    elseif hovered then
        love.graphics.setColor(Colors.purpleBright)
    else
        love.graphics.setColor(Colors.purpleLight[1], Colors.purpleLight[2], Colors.purpleLight[3], 0.6)
    end
    love.graphics.rectangle("line", x, y, w, h, 4)
    
    -- Top highlight
    love.graphics.setColor(1, 1, 1, isPrimary and 0.3 or 0.15)
    love.graphics.line(x + 4, y + 1, x + w - 4, y + 1)
    
    -- Text
    local font = Game.fonts and Game.fonts.button or love.graphics.getFont()
    love.graphics.setFont(font)
    local textW = font:getWidth(btn.text)
    local textH = font:getHeight()
    
    -- Text shadow
    love.graphics.setColor(0, 0, 0, 0.6)
    love.graphics.print(btn.text, x + (w - textW) / 2 + 1, y + (h - textH) / 2 + 1)
    
    -- Text
    if isPrimary then
        love.graphics.setColor(0.15, 0.1, 0.05, 1)
    elseif hovered then
        love.graphics.setColor(Colors.textGold)
    else
        love.graphics.setColor(Colors.textLight)
    end
    love.graphics.print(btn.text, x + (w - textW) / 2, y + (h - textH) / 2)
    
    return hovered
end

-- Draw checkbox
local function drawCheckbox(cb, mx, my)
    local x, y, size = cb.x, cb.y, cb.size or 20
    local hovered = mx >= x and mx <= x + size + 80 and my >= y and my <= y + size
    local checked = cb.checked
    
    -- Box background
    love.graphics.setColor(Colors.purpleDark[1], Colors.purpleDark[2], Colors.purpleDark[3], 0.8)
    love.graphics.rectangle("fill", x, y, size, size, 3)
    
    -- Box border
    if hovered then
        love.graphics.setColor(Colors.purpleBright)
    else
        love.graphics.setColor(Colors.purpleLight[1], Colors.purpleLight[2], Colors.purpleLight[3], 0.6)
    end
    love.graphics.setLineWidth(1)
    love.graphics.rectangle("line", x, y, size, size, 3)
    
    -- Checkmark
    if checked then
        love.graphics.setColor(Colors.crimsonLight)
        love.graphics.setLineWidth(2)
        love.graphics.line(x + 4, y + size/2, x + size/2 - 1, y + size - 5)
        love.graphics.line(x + size/2 - 1, y + size - 5, x + size - 4, y + 5)
    end
    
    -- Label
    local font = Game.fonts and Game.fonts.small or love.graphics.getFont()
    love.graphics.setFont(font)
    if hovered then
        love.graphics.setColor(Colors.textGold)
    else
        love.graphics.setColor(Colors.textLight[1], Colors.textLight[2], Colors.textLight[3], 0.8)
    end
    love.graphics.print(cb.label, x + size + 8, y + (size - font:getHeight()) / 2)
    
    return hovered
end

-- Draw the side panel
local function drawPanel(panelX, panelY, panelW, panelH)
    -- Panel shadow
    love.graphics.setColor(0, 0, 0, 0.4)
    love.graphics.rectangle("fill", panelX + 6, panelY + 6, panelW, panelH, 8)
    
    -- Panel background with gradient
    for i = 0, panelH - 1 do
        local t = i / panelH
        local alpha = Colors.panelBg[4] - t * 0.1
        love.graphics.setColor(Colors.panelBg[1], Colors.panelBg[2], Colors.panelBg[3], alpha)
        love.graphics.rectangle("fill", panelX, panelY + i, panelW, 1)
    end
    
    -- Decorative top border (gold accent)
    love.graphics.setColor(Colors.crimsonMid)
    love.graphics.rectangle("fill", panelX, panelY, panelW, 3)
    love.graphics.setColor(Colors.crimsonLight[1], Colors.crimsonLight[2], Colors.crimsonLight[3], 0.6)
    love.graphics.rectangle("fill", panelX, panelY, panelW, 1)
    
    -- Side borders
    love.graphics.setColor(Colors.panelBorder[1], Colors.panelBorder[2], Colors.panelBorder[3], 0.5)
    love.graphics.setLineWidth(1)
    love.graphics.line(panelX, panelY + 3, panelX, panelY + panelH)
    love.graphics.line(panelX + panelW, panelY + 3, panelX + panelW, panelY + panelH)
    
    -- Bottom accent
    love.graphics.setColor(Colors.purpleMid[1], Colors.purpleMid[2], Colors.purpleMid[3], 0.5)
    love.graphics.rectangle("fill", panelX, panelY + panelH - 2, panelW, 2)
end

-- Draw vignette overlay
local function drawVignette(screenW, screenH)
    local cx, cy = screenW / 2, screenH / 2
    local maxDist = math.sqrt(cx * cx + cy * cy)
    local gridSize = 12  -- Smaller cells for smoother gradient
    
    -- Draw grid cells with distance-based alpha (no overlapping)
    for y = 0, screenH, gridSize do
        for x = 0, screenW, gridSize do
            -- Distance from center of this cell to screen center
            local cellCx = x + gridSize / 2
            local cellCy = y + gridSize / 2
            local dx = cellCx - cx
            local dy = cellCy - cy
            local dist = math.sqrt(dx * dx + dy * dy)
            local t = dist / maxDist  -- 0 at center, 1 at corners
            
            -- Harsher vignette - kicks in earlier and stronger
            local alpha = math.max(0, (t - 0.15) / 0.85) ^ 1.4 * 0.9
            
            if alpha > 0.01 then
                love.graphics.setColor(0.02, 0.03, 0.05, alpha)
                love.graphics.rectangle("fill", x, y, gridSize, gridSize)
            end
        end
    end
end

-- Draw background image
local function drawBackgroundImage()
    if not bgImage then return end

    local screenW, screenH = love.graphics.getDimensions()
    local imgW, imgH = bgImage:getWidth(), bgImage:getHeight()

    -- Scale to cover, positioned to show the warrior on the right
    local scale = math.max(screenW / imgW, screenH / imgH) * 1.05
    local drawW = imgW * scale
    local drawH = imgH * scale

    -- Offset to right side so warrior is visible (panel will be on left)
    local drawX = (screenW - drawW) / 2 + 100

    -- Calculate vertical scroll range
    -- Top position: image top at screen top (or centered if smaller)
    -- Bottom position: image bottom at screen bottom
    local topY = 0
    local bottomY = screenH - drawH
    local scrollRange = topY - bottomY  -- positive value representing scroll distance

    -- Apply scroll offset (0 = top aligned, scrollRange = bottom aligned)
    local drawY = topY - scrollOffset
    
    -- Canvas for shader
    if not bgCanvas or bgCanvas:getWidth() ~= screenW or bgCanvas:getHeight() ~= screenH then
        bgCanvas = love.graphics.newCanvas(screenW, screenH)
    end

    love.graphics.setCanvas(bgCanvas)
    love.graphics.clear(0, 0, 0, 0)
    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.draw(bgImage, drawX, drawY, 0, scale, scale)
    love.graphics.setCanvas()

    -- Apply sky color rotation shader first (targets dark blue sky pixels)
    if skyShader then
        local tempCanvas = love.graphics.newCanvas(screenW, screenH)
        skyShader:send("time", animTimer)

        love.graphics.setCanvas(tempCanvas)
        love.graphics.clear(0, 0, 0, 0)
        love.graphics.setShader(skyShader)
        love.graphics.setColor(1, 1, 1, 1)
        love.graphics.draw(bgCanvas, 0, 0)
        love.graphics.setShader()
        love.graphics.setCanvas()
        bgCanvas = tempCanvas
    end

    -- Apply jiggle shader if active
    if jiggleActive and jiggleShader then
        local tempCanvas = love.graphics.newCanvas(screenW, screenH)
        jiggleShader:send("time", jiggleTime)
        jiggleShader:send("intensity", math.max(0, 1 - jiggleTime / jiggleDuration))
        jiggleShader:send("clickPos", {clickX, clickY})
        jiggleShader:send("resolution", {screenW, screenH})

        love.graphics.setCanvas(tempCanvas)
        love.graphics.clear(0, 0, 0, 0)
        love.graphics.setShader(jiggleShader)
        love.graphics.setColor(1, 1, 1, 1)
        love.graphics.draw(bgCanvas, 0, 0)
        love.graphics.setShader()
        love.graphics.setCanvas()
        bgCanvas = tempCanvas
    end

    -- Apply fog shader (perlin noise light/dark modulation)
    if fogShader then
        local tempCanvas = love.graphics.newCanvas(screenW, screenH)
        fogShader:send("time", animTimer)
        fogShader:send("noiseScale", 2.0)        -- Lower = larger patterns
        fogShader:send("fogIntensity", 0.3)      -- How dark the dark areas get
        fogShader:send("lightIntensity", 0.25)   -- How bright the light areas get
        fogShader:send("oscillationSpeed", 1.0)  -- How fast scale oscillates
        fogShader:send("oscillationAmount", 0.5) -- How much scale varies

        love.graphics.setCanvas(tempCanvas)
        love.graphics.clear(0, 0, 0, 0)
        love.graphics.setShader(fogShader)
        love.graphics.setColor(1, 1, 1, 1)
        love.graphics.draw(bgCanvas, 0, 0)
        love.graphics.setShader()
        love.graphics.setCanvas()
        bgCanvas = tempCanvas
    end

    -- Apply glow shader (always active for magical effect)
    if glowShader then
        local tempCanvas = love.graphics.newCanvas(screenW, screenH)
        glowShader:send("time", animTimer)
        glowShader:send("resolution", {screenW, screenH})

        love.graphics.setCanvas(tempCanvas)
        love.graphics.clear(0, 0, 0, 0)
        love.graphics.setShader(glowShader)
        love.graphics.setColor(1, 1, 1, 1)
        love.graphics.draw(bgCanvas, 0, 0)
        love.graphics.setShader()
        love.graphics.setCanvas()
        bgCanvas = tempCanvas
    end

    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.draw(bgCanvas, 0, 0)
end

function Title.load()
    animTimer = 0
    particles = {}
    medallionSparks = {}
    jiggleTime = 0
    jiggleActive = false
    scrollOffset = 0
    scrollDirection = 1

    -- Load background image
    local imagePath = "images/succubus_moonlight.png"
    local success, result = pcall(function()
        return love.graphics.newImage(imagePath)
    end)
    if success then
        bgImage = result
        print("Title: Loaded succubus background")
    else
        bgImage = nil
        print("Title: Could not load " .. imagePath)
    end
    
    -- Create sky color rotation shader
    local skySuccess
    skySuccess, skyShader = pcall(function()
        return love.graphics.newShader(skyShaderCode)
    end)
    if not skySuccess then
        print("Title: Sky shader error: " .. tostring(skyShader))
        skyShader = nil
    end

    -- Create jiggle shader
    local shaderSuccess
    shaderSuccess, jiggleShader = pcall(function()
        return love.graphics.newShader(jiggleShaderCode)
    end)
    if not shaderSuccess then
        print("Title: Jiggle shader error: " .. tostring(jiggleShader))
        jiggleShader = nil
    end

    -- Create glow shader
    local glowSuccess
    glowSuccess, glowShader = pcall(function()
        return love.graphics.newShader(glowShaderCode)
    end)
    if not glowSuccess then
        print("Title: Glow shader error: " .. tostring(glowShader))
        glowShader = nil
    end

    -- Create fog shader
    local fogSuccess
    fogSuccess, fogShader = pcall(function()
        return love.graphics.newShader(fogShaderCode)
    end)
    if not fogSuccess then
        print("Title: Fog shader error: " .. tostring(fogShader))
        fogShader = nil
    end

    -- Audio
    if Audio and Audio.init then Audio.init() end
    if Audio and Audio.playRandomMusic then Audio.playRandomMusic() end
    
    -- Layout
    local screenW, screenH = love.graphics.getDimensions()
    local panelW = 280
    local panelX = 100
    local panelY = 80
    local panelH = screenH - 160
    
    local btnW = panelW - 40
    local btnH = 42
    local btnX = panelX + 20
    local btnStartY = panelY + 180
    local btnSpacing = 50
    
    buttons = {
        {
            text = "QUICK PLAY",
            x = btnX, y = btnStartY, w = btnW, h = btnH,
            action = function() Game.SceneManager.switch("gameplay") end,
            primary = true
        },
        {
            text = "New Game",
            x = btnX, y = btnStartY + btnSpacing, w = btnW, h = btnH,
            action = function() Game.SceneManager.switch("gameconfig") end
        },
        {
            text = "How to Play",
            x = btnX, y = btnStartY + btnSpacing * 2, w = btnW, h = btnH,
            action = function() Game.SceneManager.switch("tutorial") end
        },
        {
            text = "Settings",
            x = btnX, y = btnStartY + btnSpacing * 3, w = btnW, h = btnH,
            action = function() 
                -- Could open settings menu
            end
        },
        {
            text = "Exit Game",
            x = btnX, y = btnStartY + btnSpacing * 4 + 20, w = btnW, h = btnH,
            action = function() love.event.quit() end
        }
    }
    
    -- Small dev button in bottom-right corner (icon only)
    devButton = {
        x = screenW - 50,
        y = screenH - 50,
        size = 36,
        action = function() Game.SceneManager.switch("devpreview") end
    }
    
    -- Checkboxes for audio
    local cbY = panelY + panelH - 90
    checkboxes = {
        {
            label = "Music",
            x = btnX, y = cbY,
            size = 22,
            checked = Game.settings.musicEnabled,
            toggle = function(cb)
                cb.checked = not cb.checked
                Game.settings.musicEnabled = cb.checked
            end
        },
        {
            label = "Sound FX",
            x = btnX + 110, y = cbY,
            size = 22,
            checked = Game.settings.soundEnabled,
            toggle = function(cb)
                cb.checked = not cb.checked
                Game.settings.soundEnabled = cb.checked
            end
        }
    }
end

function Title.update(dt)
    animTimer = animTimer + dt

    -- Update background scroll
    if bgImage then
        local screenW, screenH = love.graphics.getDimensions()
        local imgW, imgH = bgImage:getWidth(), bgImage:getHeight()
        local scale = math.max(screenW / imgW, screenH / imgH) * 1.05
        local drawH = imgH * scale
        local scrollRange = (drawH - screenH) * 0.5  -- half the full range

        scrollOffset = scrollOffset + scrollDirection * scrollSpeed * dt

        -- Reverse direction at bounds
        if scrollOffset >= scrollRange then
            scrollOffset = scrollRange
            scrollDirection = -1
        elseif scrollOffset <= 0 then
            scrollOffset = 0
            scrollDirection = 1
        end
    end

    -- Update jiggle
    if jiggleActive then
        jiggleTime = jiggleTime + dt
        if jiggleTime >= jiggleDuration then
            jiggleActive = false
            jiggleTime = 0
        end
    end

    -- Audio
    if Audio and Audio.update then Audio.update(dt) end
    
    -- Spawn dust particles
    if math.random() < dt * 1.5 then
        spawnParticle()
    end
    
    -- Update particles
    for i = #particles, 1, -1 do
        local p = particles[i]
        p.x = p.x + p.vx * dt
        p.y = p.y + p.vy * dt
        p.life = p.life - dt
        if p.life <= 0 then
            table.remove(particles, i)
        end
    end
    
    -- Medallion sparks
    local screenW, screenH = love.graphics.getDimensions()
    local panelCenterX = 100 + 280 / 2  -- panelX + panelW/2 = 240
    local medallionX = panelCenterX
    local medallionY = screenH / 2 - 100
    local medallionRadius = 340
    
    -- Spawn new sparks
    if math.random() < dt * 12 then  -- ~12 sparks per second
        spawnMedallionSpark(medallionX, medallionY, medallionRadius)
    end
    
    -- Update medallion sparks
    for i = #medallionSparks, 1, -1 do
        local s = medallionSparks[i]
        s.x = s.x + s.vx * dt
        s.y = s.y + s.vy * dt
        s.vy = s.vy - 20 * dt  -- Slow down upward movement (gravity-ish but upward)
        s.rotation = s.rotation + s.rotSpeed * dt
        s.life = s.life - dt
        if s.life <= 0 then
            table.remove(medallionSparks, i)
        end
    end
    
    -- Sync checkboxes with settings
    if checkboxes[1] then checkboxes[1].checked = Game.settings.musicEnabled end
    if checkboxes[2] then checkboxes[2].checked = Game.settings.soundEnabled end
end

function Title.draw()
    local screenW, screenH = love.graphics.getDimensions()
    local mx, my = love.mouse.getPosition()
    
    -- Background gradient (desert sky colors)
    for i = 0, screenH - 1 do
        local t = i / screenH
        local r = 0.15 + t * 0.1
        local g = 0.20 + t * 0.08
        local b = 0.28 - t * 0.05
        love.graphics.setColor(r, g, b, 1)
        love.graphics.rectangle("fill", 0, i, screenW, 1)
    end
    
    -- Background image
    drawBackgroundImage()
    
    -- Vignette
    drawVignette(screenW, screenH)
    
    -- Medallion (centered with panel)
    local panelCenterX = 100 + 280 / 2  -- panelX + panelW/2 = 240
    local medallionX = panelCenterX
    local medallionY = screenH / 2 - 100  -- Up from center
    local medallionRadius = 340
    drawMedallion(medallionX, medallionY, medallionRadius)
    
    -- Medallion sparks (in front of medallion, behind panel)
    drawMedallionSparks()
    
    -- Dust particles
    for _, p in ipairs(particles) do
        local alpha = (p.life / p.maxLife) * p.alpha
        if p.type == "spark" then
            love.graphics.setColor(Colors.crimsonLight[1], Colors.crimsonLight[2], Colors.crimsonLight[3], alpha)
        else
            love.graphics.setColor(Colors.silverLight[1], Colors.silverLight[2], Colors.silverLight[3], alpha * 0.6)
        end
        love.graphics.circle("fill", p.x, p.y, p.size)
    end
    
    -- Side panel
    local panelW = 280
    local panelX = 100
    local panelY = 80
    local panelH = screenH - 160
    
    drawPanel(panelX, panelY, panelW, panelH)
    
    -- Title
    local titleFont = Game.fonts and Game.fonts.title or love.graphics.getFont()
    love.graphics.setFont(titleFont)
    
    local title = "DOMINION"
    local titleW = titleFont:getWidth(title)
    -- Center title in panel, but ensure it doesn't go off-screen
    local titleX = math.max(10, panelX + (panelW - titleW) / 2)
    local titleY = panelY + 25
    
    -- Title glow
    local glowPulse = 0.6 + math.sin(animTimer * 2) * 0.4
    love.graphics.setColor(Colors.crimsonMid[1], Colors.crimsonMid[2], Colors.crimsonMid[3], 0.25 * glowPulse)
    for dx = -3, 3 do
        for dy = -3, 3 do
            if dx ~= 0 or dy ~= 0 then
                love.graphics.print(title, titleX + dx, titleY + dy)
            end
        end
    end
    
    -- Title shadow
    love.graphics.setColor(0, 0, 0, 0.7)
    love.graphics.print(title, titleX + 2, titleY + 2)
    
    -- Title main
    love.graphics.setColor(Colors.crimsonBright)
    love.graphics.print(title, titleX, titleY)
    
    -- Subtitle
    local subtitleFont = Game.fonts and Game.fonts.subtitle or love.graphics.getFont()
    love.graphics.setFont(subtitleFont)
    local subtitle = "Rise to Power"
    local subtitleW = subtitleFont:getWidth(subtitle)
    
    love.graphics.setColor(0, 0, 0, 0.5)
    love.graphics.print(subtitle, panelX + (panelW - subtitleW) / 2 + 1, titleY + 55 + 1)
    love.graphics.setColor(Colors.purpleBright[1], Colors.purpleBright[2], Colors.purpleBright[3], 0.9)
    love.graphics.print(subtitle, panelX + (panelW - subtitleW) / 2, titleY + 55)
    
    -- Decorative line under subtitle
    local lineY = titleY + 95
    love.graphics.setColor(Colors.crimsonMid[1], Colors.crimsonMid[2], Colors.crimsonMid[3], 0.6)
    love.graphics.setLineWidth(1)
    love.graphics.line(panelX + 30, lineY, panelX + panelW - 30, lineY)
    
    -- Diamond accent in center of line
    local diamondX = panelX + panelW / 2
    love.graphics.setColor(Colors.crimsonLight)
    love.graphics.polygon("fill", 
        diamondX, lineY - 5,
        diamondX + 5, lineY,
        diamondX, lineY + 5,
        diamondX - 5, lineY
    )
    
    -- Buttons
    for _, btn in ipairs(buttons) do
        drawButton(btn, mx, my)
    end
    
    -- Audio section label
    local smallFont = Game.fonts and Game.fonts.small or love.graphics.getFont()
    love.graphics.setFont(smallFont)
    love.graphics.setColor(Colors.textMuted)
    love.graphics.print("Audio", panelX + 20, panelY + panelH - 115)
    
    -- Checkboxes
    for _, cb in ipairs(checkboxes) do
        drawCheckbox(cb, mx, my)
    end
    
    -- Small dev button in corner (gear/wrench icon)
    if devButton then
        local db = devButton
        local dbHovered = mx >= db.x and mx <= db.x + db.size and my >= db.y and my <= db.y + db.size
        
        -- Button background
        love.graphics.setColor(Colors.purpleDark[1], Colors.purpleDark[2], Colors.purpleDark[3], dbHovered and 0.9 or 0.6)
        love.graphics.rectangle("fill", db.x, db.y, db.size, db.size, 6)
        
        -- Border
        if dbHovered then
            love.graphics.setColor(Colors.purpleBright)
        else
            love.graphics.setColor(Colors.purpleLight[1], Colors.purpleLight[2], Colors.purpleLight[3], 0.4)
        end
        love.graphics.setLineWidth(1)
        love.graphics.rectangle("line", db.x, db.y, db.size, db.size, 6)
        
        -- Gear icon (simplified)
        local cx, cy = db.x + db.size/2, db.y + db.size/2
        local outerR = db.size * 0.32
        local innerR = db.size * 0.18
        local toothH = db.size * 0.12
        
        if dbHovered then
            love.graphics.setColor(Colors.crimsonLight)
        else
            love.graphics.setColor(Colors.textLight[1], Colors.textLight[2], Colors.textLight[3], 0.7)
        end
        
        -- Center circle
        love.graphics.circle("fill", cx, cy, innerR)
        
        -- Gear teeth
        love.graphics.setLineWidth(3)
        local numTeeth = 6
        for i = 1, numTeeth do
            local angle = (i / numTeeth) * math.pi * 2 + animTimer * 0.5
            local x1 = cx + math.cos(angle) * innerR
            local y1 = cy + math.sin(angle) * innerR
            local x2 = cx + math.cos(angle) * (outerR + toothH)
            local y2 = cy + math.sin(angle) * (outerR + toothH)
            love.graphics.line(x1, y1, x2, y2)
        end
        
        -- Inner hole
        love.graphics.setColor(Colors.purpleDark[1], Colors.purpleDark[2], Colors.purpleDark[3], 1)
        love.graphics.circle("fill", cx, cy, innerR * 0.4)
    end
    
    -- Version in corner
    love.graphics.setColor(Colors.textLight[1], Colors.textLight[2], Colors.textLight[3], 0.3)
    love.graphics.print("v0.1 - Made with LÖVE", screenW - 150, screenH - 25)
end

function Title.keypressed(key)
    if key == "return" or key == "space" then
        Game.SceneManager.switch("gameplay")
    elseif key == "escape" then
        love.event.quit()
    elseif key == "m" then
        Game.settings.musicEnabled = not Game.settings.musicEnabled
    end
end

function Title.mousepressed(x, y, button)
    if button ~= 1 then return end
    
    -- Trigger jiggle on background click
    if bgImage then
        jiggleActive = true
        jiggleTime = 0
        clickX = x
        clickY = y
    end
    
    -- Check buttons
    for _, btn in ipairs(buttons) do
        if x >= btn.x and x <= btn.x + btn.w and
           y >= btn.y and y <= btn.y + btn.h then
            if btn.action then btn.action() end
            return
        end
    end
    
    -- Check checkboxes
    for _, cb in ipairs(checkboxes) do
        local size = cb.size or 20
        if x >= cb.x and x <= cb.x + size + 80 and
           y >= cb.y and y <= cb.y + size then
            if cb.toggle then cb.toggle(cb) end
            return
        end
    end
    
    -- Check dev button
    if devButton then
        local db = devButton
        if x >= db.x and x <= db.x + db.size and
           y >= db.y and y <= db.y + db.size then
            if db.action then db.action() end
            return
        end
    end
end

function Title.unload()
    bgCanvas = nil
end

return Title
