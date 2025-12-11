--[[
    Audio Module
    Handles background music and sound effects for the RTS game

    Music player features:
    - Dynamic playlist from music/ folder
    - Track position/duration
    - Seek, next, prev, pause/resume
    - Track info for UI display
]]

local Audio = {}

-- Music state
local playlist = {}       -- {source, name, path, duration}
local currentIndex = 0
local currentMusic = nil
local musicVolume = 0.5
local isPaused = false

-- Sound effects
local hitSounds = {}
local alertSound = nil
local soundVolume = 0.7

-- Track if we were disabled (to know when to restart)
local wasDisabled = false

-- Helper: Extract track name from path
local function getTrackName(path)
    -- Remove directory prefix
    local name = path:match("([^/]+)$") or path
    -- Remove extension
    name = name:match("(.+)%..+$") or name
    return name
end

-- Helper: Scan music folder and build playlist
local function scanMusicFolder()
    playlist = {}

    local musicDir = "music"
    local items = love.filesystem.getDirectoryItems(musicDir)

    for _, item in ipairs(items) do
        local path = musicDir .. "/" .. item
        local info = love.filesystem.getInfo(path)

        if info and info.type == "file" then
            -- Check if it's an audio file
            local ext = item:match("%.(%w+)$")
            if ext then
                ext = ext:lower()
                if ext == "wav" or ext == "mp3" or ext == "ogg" or ext == "flac" then
                    local success, source = pcall(function()
                        return love.audio.newSource(path, "stream")
                    end)

                    if success and source then
                        source:setLooping(false)
                        source:setVolume(musicVolume)

                        table.insert(playlist, {
                            source = source,
                            name = getTrackName(item),
                            path = path,
                            duration = source:getDuration()
                        })
                    end
                end
            end
        end
    end

    -- Sort by name for consistent ordering
    table.sort(playlist, function(a, b) return a.name < b.name end)
end

-- Initialize audio system
function Audio.init()
    -- Scan music folder for tracks
    scanMusicFolder()

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

-- Play a specific track by index
function Audio.playTrack(index)
    if #playlist == 0 then return end
    if index < 1 or index > #playlist then return end

    -- Stop current music
    if currentMusic then
        currentMusic:stop()
    end

    currentIndex = index
    currentMusic = playlist[index].source
    currentMusic:setVolume(musicVolume)
    currentMusic:seek(0)
    isPaused = false

    if Game.settings.musicEnabled then
        currentMusic:play()
    end
end

-- Play a random music track
function Audio.playRandomMusic()
    if #playlist == 0 then return end
    if not Game.settings.musicEnabled then return end

    -- Pick random track (different from current if possible)
    local index
    if #playlist == 1 then
        index = 1
    else
        repeat
            index = math.random(1, #playlist)
        until index ~= currentIndex or #playlist == 1
    end

    Audio.playTrack(index)
end

-- Play next track
function Audio.nextTrack()
    if #playlist == 0 then return end

    local nextIndex = currentIndex + 1
    if nextIndex > #playlist then
        nextIndex = 1
    end

    Audio.playTrack(nextIndex)
end

-- Play previous track (or restart current if > 3 seconds in)
function Audio.prevTrack()
    if #playlist == 0 then return end

    -- If more than 3 seconds into track, restart it
    if currentMusic and currentMusic:tell() > 3 then
        currentMusic:seek(0)
        return
    end

    local prevIndex = currentIndex - 1
    if prevIndex < 1 then
        prevIndex = #playlist
    end

    Audio.playTrack(prevIndex)
end

-- Toggle pause/resume
function Audio.togglePause()
    if not currentMusic then return end

    if isPaused then
        if Game.settings.musicEnabled then
            currentMusic:play()
        end
        isPaused = false
    else
        currentMusic:pause()
        isPaused = true
    end
end

-- Seek to position (0-1 normalized, or seconds if > 1)
function Audio.seek(position)
    if not currentMusic then return end

    local duration = currentMusic:getDuration()
    local targetTime

    if position <= 1 then
        -- Normalized position (0-1)
        targetTime = position * duration
    else
        -- Absolute seconds
        targetTime = position
    end

    -- Clamp to valid range
    targetTime = math.max(0, math.min(targetTime, duration - 0.1))
    currentMusic:seek(targetTime)
end

-- Update audio (call each frame to check if music ended)
function Audio.update(dt)
    if not Game.settings.musicEnabled then
        if currentMusic and currentMusic:isPlaying() then
            currentMusic:pause()
        end
        wasDisabled = true
        return
    end

    -- If just re-enabled, resume or start playing
    if wasDisabled then
        wasDisabled = false
        if currentMusic and isPaused == false then
            currentMusic:play()
        elseif not currentMusic or currentIndex == 0 then
            Audio.playRandomMusic()
        end
        return
    end

    -- Check if music stopped and play next track (unless paused)
    if not isPaused then
        if currentMusic and not currentMusic:isPlaying() then
            Audio.nextTrack()
        elseif not currentMusic and #playlist > 0 then
            Audio.playRandomMusic()
        end
    end
end

-- Get current track info
function Audio.getCurrentTrack()
    if currentIndex == 0 or currentIndex > #playlist then
        return nil
    end
    return playlist[currentIndex]
end

-- Get current track index
function Audio.getCurrentIndex()
    return currentIndex
end

-- Get current playback position in seconds
function Audio.getPosition()
    if not currentMusic then return 0 end
    return currentMusic:tell()
end

-- Get current track duration in seconds
function Audio.getDuration()
    if not currentMusic then return 0 end
    return currentMusic:getDuration()
end

-- Get playlist
function Audio.getPlaylist()
    return playlist
end

-- Get playlist count
function Audio.getTrackCount()
    return #playlist
end

-- Check if paused
function Audio.isPaused()
    return isPaused
end

-- Check if music is playing
function Audio.isMusicPlaying()
    return currentMusic and currentMusic:isPlaying()
end

-- Play a random hit sound
function Audio.playHit()
    if #hitSounds == 0 then return end
    if not Game.settings.soundEnabled then return end

    local index = math.random(1, #hitSounds)
    local sound = hitSounds[index]

    -- Clone and play so multiple can overlap
    local clone = sound:clone()
    clone:setVolume(soundVolume * (0.8 + math.random() * 0.4))
    clone:setPitch(0.9 + math.random() * 0.2)
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
    end
    isPaused = false
end

-- Set music volume (0-1)
function Audio.setMusicVolume(vol)
    musicVolume = math.max(0, math.min(1, vol))
    if currentMusic then
        currentMusic:setVolume(musicVolume)
    end
    -- Update all playlist sources too
    for _, track in ipairs(playlist) do
        track.source:setVolume(musicVolume)
    end
end

-- Get music volume
function Audio.getMusicVolume()
    return musicVolume
end

-- Set sound volume (0-1)
function Audio.setSoundVolume(vol)
    soundVolume = math.max(0, math.min(1, vol))
end

-- Get sound volume
function Audio.getSoundVolume()
    return soundVolume
end

-- Format time as M:SS
function Audio.formatTime(seconds)
    if not seconds or seconds < 0 then return "0:00" end
    local mins = math.floor(seconds / 60)
    local secs = math.floor(seconds % 60)
    return string.format("%d:%02d", mins, secs)
end

return Audio
