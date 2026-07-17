-- Global variables below are used in different functions, so have to be declared globally
filepath = ''
folder = ''
duration = 0
position = 0
isPlaying = true
encode = nil
decode = nil
md5 = nil
currentFilename = ''

-- Position folder is relative to the script directory (deployed alongside the script)
local scriptDir = mp.get_script_directory()
local positionFolder = scriptDir .. '/positions/'

-- Load decoder, encoder, and md5 once at startup
function loadFile(path)
    return assert(loadfile(path))()
end

local function initLibs()
    local libFolder = scriptDir .. '/lib/'
    decode = loadFile(libFolder .. 'decoder.lua')()
    encode = loadFile(libFolder .. 'encoder.lua')()
    md5 = loadFile(libFolder .. 'md5.lua')
end

initLibs()


-- This function is called when mpv loads a file
mp.register_event("file-loaded", function()
    -- Call function to get current file
    currentFilename = getFilename()
    -- Strip filename of any escape characters
    currentFilename = string.gsub(currentFilename, "[^%w%.%-_]", "_")
    -- Get files duration from mpv
    duration = mp.get_property_number("duration")
    -- Set the filepath of the json file to be the combination of the folder and filename with .json extension
    filepath = positionFolder .. currentFilename .. ".json"
    -- Attempt to open the 'positionFile' using the filepath
    local positionFile, err = io.open(filepath, "r")
    -- If the positionFile json is not present
    if not positionFile then
        print("Could not open position file for reading:", err)
        return
    -- Otherwise read the file and use lunajson's decode to un-marshall the Json
    else
        local content, readErr = positionFile:read("*all")
        positionFile:close()
        if readErr then
            print("Error reading position file:", readErr)
            return
        end
        local ok, data = pcall(decode, content)
        if not ok then
            local errMsg = tostring(data)
            print("Failed to parse position file:", errMsg)
            mp.osd_message("Failed to parse position file: " .. errMsg, "5")
            return
        end
        if type(data) ~= "table" or data.loc == nil then
            print("Position file has no valid 'loc' key:", filepath)
            return
        end
        -- Use the 'loc' (location) saved in the Json file and ask mpv to seek to that location in the opened file
        mp.commandv("seek", data.loc, "absolute+exact")
    end
end)

-- Create a periodic timer in mpv for every one second
timer = mp.add_periodic_timer(1, function()
    -- If the file is playing
    if isPlaying then
        -- Set the position to the position that mpv has for the open file
        position = mp.get_property_number("time-pos")
    end
end)

mp.register_event("shutdown", function()
    -- Set isPlaying to false. This is because when exiting mpv sets the 'time-pos' to nil so this stops the wrong position from being saved
    isPlaying = false

    -- If the position is not nil and it is greater than 2 seconds
    if position ~= nil and position > 2 then
        -- Sanitise the filename to remove escape characters
        local filename = string.gsub(currentFilename, "[^%w%.%-_]", "_")

        -- Create the folder to save the positions of open files
        os.execute('mkdir -p "' .. positionFolder .. '"')
        -- Create the filepath to save the position
        filepath = positionFolder .. filename .. ".json"
        -- Open the file

        print("Saving filepath: ", filepath)
        positionFile, err = io.open(filepath, "w")
        if not positionFile then
            print("Error opening file to write:", err)
            return
        end

        -- Get the number of seconds left of the open file. If it is less than five seconds remaining then set the position of the file to zero
        local finalPosition = duration - position
        if finalPosition <= 5 then
            position = 0
        end
        -- Create a table with the key 'loc'. The value is the opened files position
        local data = {
            loc = position
        }

        -- Use lunajson's encode function to marshal Json data
        local str = encode(data)
        -- Write the marshalled Json to the file
        positionFile:write(str)
        positionFile:close()
    end
end)


-- Help function to get the filename of a file
function getFilename()
    -- Check 'force-media-title' to determine if it is a youtube video
    local title = mp.get_property("force-media-title")
    -- If it is a YT video then use the YT video's title
    if title and #title > 0 then
        local fd = md5.sumhexa(title)
        print("Hashed title file descriptor: ", fd)
        -- Return the hashed title descriptor
        return fd
    end
    -- Get the file size and duration of the opened file in mpv
    local file_size = mp.get_property_number("file-size")
    local file_duration = mp.get_property_number("duration")
    -- Add the combination of the values together and convert to a string
    local file_descriptor = tostring(file_size + file_duration)
    -- Use the md5 function to create a hash of the filename
    local fd = md5.sumhexa(file_descriptor)
    print("Hashed file size and duration file descriptor: ", fd)
    -- Return the hashed file size and duration descriptor
    return fd
end
