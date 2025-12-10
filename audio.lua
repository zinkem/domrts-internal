--[[
    Audio Module
    Handles background music and sound effects for the RTS game
]]

local Audio = {}

-- Music tracks
local musicTracks = {}
local currentMusic = nil
local musicVolume = 0.5

-- Sound effects
local hitSounds = {}
local alertSound = nil
local soundVolume = 0.7

-- Initialize audio system
function Audio.init()
    -- Load music tracks
    local musicFiles = {
        "music/Knights of the Shattered Dawn(1).wav",
        "music/Knights in the Storm.wav",
        "music/Echoes of Eternity.wav",
        "music/Knights of the Shattered Dawn.wav",
        "music/Rise of the Eternal Flame.wav",
        "music/Knights in the Storm(1).wav"
    }
    
    for _, file in ipairs(musicFiles) do
        local success, source = pcall(function()
            return love.audio.newSource(file, "stream")
        end)
        if success and source then
            source:setLooping(false)  -- We'll manually loop to shuffle
            source:setVolume(musicVolume)
            table.insert(musicTracks, source)
        end
    end
    
    -- Load hit sound effects
    local hitFiles = {
        "sfx/ping000.wav",
        "sfx/ping001.wav",
        "sfx/ping002.wav"
    }
    
    for _, file in ipairs(hitFiles) do
        local success, source = pcall(function()
            return love.audio.newSource(file, "static")
        end)
        if success and source then
            source:setVolume(soundVolume)
            table.insert(hitSounds, source)
        end
    end

    -- Load alert sound
    local success, source = pcall(function()
        return love.audio.newSource("sfx/alert2.wav", "static")
    end)
    if success and source then
        source:setVolume(soundVolume)
        alertSound = source
    end

    -- Seed random
    math.randomseed(os.time())
end

-- Play a random music track
function Audio.playRandomMusic()
    if #musicTracks == 0 then return end
    if not Game.settings.musicEnabled then return end
    
    -- Stop current music
    if currentMusic then
        currentMusic:stop()
    end
    
    -- Pick random track
    local index = math.random(1, #musicTracks)
    currentMusic = musicTracks[index]
    currentMusic:setVolume(musicVolume)
    currentMusic:play()
end

-- Track if we were disabled (to know when to restart)
local wasDisabled = false

-- Update audio (call each frame to check if music ended)
function Audio.update(dt)
    if not Game.settings.musicEnabled then
        if currentMusic and currentMusic:isPlaying() then
            currentMusic:stop()
        end
        wasDisabled = true
        return
    end

    -- If just re-enabled, start playing
    if wasDisabled then
        wasDisabled = false
        Audio.playRandomMusic()
        return
    end

    -- Check if music stopped and play next random track
    if currentMusic and not currentMusic:isPlaying() then
        Audio.playRandomMusic()
    elseif not currentMusic and #musicTracks > 0 then
        Audio.playRandomMusic()
    end
end

-- Play a random hit sound
function Audio.playHit()
    if #hitSounds == 0 then return end
    if not Game.settings.soundEnabled then return end

    local index = math.random(1, #hitSounds)
    local sound = hitSounds[index]

    -- Clone and play so multiple can overlap
    local clone = sound:clone()
    clone:setVolume(soundVolume * (0.8 + math.random() * 0.4))  -- Slight volume variation
    clone:setPitch(0.9 + math.random() * 0.2)  -- Slight pitch variation
    clone:play()
end

-- Play alert sound (for errors, invalid actions)
function Audio.playAlert()
    if not alertSound then return end
    if not Game.settings.soundEnabled then return end

    local clone = alertSound:clone()
    clone:setVolume(soundVolume)
    clone:play()
end

-- Stop all music
function Audio.stopMusic()
    if currentMusic then
        currentMusic:stop()
        currentMusic = nil
    end
end

-- Set music volume (0-1)
function Audio.setMusicVolume(vol)
    musicVolume = vol
    if currentMusic then
        currentMusic:setVolume(vol)
    end
end

-- Set sound volume (0-1)
function Audio.setSoundVolume(vol)
    soundVolume = vol
end

-- Check if music is playing
function Audio.isMusicPlaying()
    return currentMusic and currentMusic:isPlaying()
end

return Audio
