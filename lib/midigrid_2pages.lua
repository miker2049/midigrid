--[[ cheapskate library for midi grid devices, 2 pages.
     contains within itself a full 128 grid table, which can be viewed and played by pressing
     the 'leftpage'/'rightpage' buttons as defined in the relevant config file.
]]

local supported_devices = {apcmini = 'apcmini',
                           launchpadmk2 = 'launchpad mk2',
                           launchpadpro = 'launchpad pro 2',
                           launchpad = 'launchpad'}
local config_name = 'none'
for _, dev in pairs(midi.devices) do
    local name = string.lower(dev.name)
    for device, device_name in pairs(supported_devices) do
        if name == device_name then
            config_name = 'midigrid/config/' .. device .. '_config'
        end
    end
end
if config_name == 'none' then
    print('No supported device found')
end
local config = include(config_name)
local gridnotes = config.grid
local brightness_handler = config.brightness_handler
local device_name = config.device_name
local og_dev_add, og_dev_remove
local leftpage = config.leftpage_button
local rightpage = config.rightpage_button

-- adding midi device call backs
local midigrid = {midi_id = nil}
midigrid.ledbuf = {}
midigrid.rows = #gridnotes[1]
midigrid.cols = #gridnotes * 2  -- an assumption, but a safe one

-- start on "page" 1
local apcpage = 1

-- make the grid buf
local gridbuf = {}
for rows = 1, midigrid.rows do
    gridbuf[rows] = {}
    for cols = 1, midigrid.cols do
        gridbuf[rows][cols] = 0
    end
end

-- getting the two pages set up
apcnotecoords1 = {}
apcnotecoords2 = {}
for row, notes in ipairs(gridnotes) do
    for col, note in ipairs(notes) do
        apcnotecoords1[note] = {col, row}
        apcnotecoords2[note] = {col + 8, row}
    end
end
apcnotecoords = {apcnotecoords1, apcnotecoords2}


function midigrid.find_midi_device_id()
    local found_id = nil
    for i, dev in pairs(midi.devices) do
        local name = string.lower(dev.name)
        if midigrid.name_matches(name) then
            found_id = dev.id
        end
    end
    return found_id
end


function midigrid.connect(dummy_id)
    midigrid.set_midi_handler()

    --init on page 1
    midi.devices[midigrid.midi_id]:send({144, leftpage, 1})
    midi.devices[midigrid.midi_id]:send({144, rightpage, 0})
    return midigrid
end


function midigrid.set_key_handler(key_handler)
    midigrid.set_midi_handler()
    midigrid.key = key_handler
end


function midigrid.setup_connect_handling()
    og_dev_add = midi.add
    og_dev_remove = midi.remove
    midi.add = midigrid.handle_dev_add
    midi.remove = midigrid.handle_dev_remove
end


function midigrid.name_matches(name)
    return (name == device_name)
end


function midigrid.handle_dev_add(id, name, dev)
    og_dev_add(id, name, dev)
    midigrid.update_devices()
    if (midigrid.name_matches(name)) and (id ~= midigrid.midi_id) then
        midigrid.midi_id = id
        midigrid.device = dev
        midigrid.set_midi_handler()
    end
end


function midigrid.handle_dev_remove(id)
    og_dev_remove(id)
    midigrid.update_devices()
end


-- this already expects it to have Midi_id
function midigrid.set_midi_handler()
    if midigrid.midi_id == nil then return end
    if midi.devices[midigrid.midi_id] ~= nil then
        midi.devices[midigrid.midi_id].event = midigrid.handle_key_midi

        -- need this for checking .device
        midigrid.device = midi.devices[midigrid.midi_id]
    else
        midigrid.midi_id = nil
    end
end


function midigrid.cleanup()
    midigrid.key = nil
end


function midigrid.update_devices()
    midi.update_devices()
    local new_id = midigrid.find_midi_device_id()

    -- Only set id/handler when helpful
    if (midigrid.midi_id ~= new_id) and (new_id ~= nil) then
        midigrid.midi_id = new_id
        return midigrid.set_midi_handler()
    end
    return (midigrid.midi_id ~= nil)
end


-- led handling. *generally speaking*; first we clear the unchanged led buffer...
function midigrid:all(z)
    vel = brightness_handler(z)
    if self.device then
        for row = 1, midigrid.rows do
            for col = 1, midigrid.cols do
                local oldvel = gridbuf[row][col]
                gridbuf[row][col] = z
                if gridbuf[row][col] ~= oldvel then    -- this led needs to be set
                    if (apcpage == 1 and col < 9) then
                        note = gridnotes[row][col]
                        table.insert(self.ledbuf, 0x90)
                        table.insert(self.ledbuf, note)
                        table.insert(self.ledbuf, vel)
                    elseif (apcpage == 2 and col > 8) then
                        note = gridnotes[row][col - 8]
                        table.insert(self.ledbuf, 0x90)
                        table.insert(self.ledbuf, note)
                        table.insert(self.ledbuf, vel)
                    end
                end
            end
        end
    end
end


-- ...then we update the led buf at our leisure...
function midigrid:led(col, row, z)
    if (col >= 1 and row >= 1)
            and (col <= midigrid.cols and row <= midigrid.rows) then
        vel = brightness_handler(z)
        gridbuf[row][col] = z

        -- if we aint on the right page dont bother
        if col > 8 and apcpage == 1 then
            return
        end
        if col < 8 and apcpage == 2 then
            return
        end
        if self.device then
            if apcpage == 1 then
                note = gridnotes[row][col]
            elseif apcpage == 2 then
                note = gridnotes[row][col - 8]
            end
            if note then
                table.insert(self.ledbuf, 0x90)
                table.insert(self.ledbuf, note)
                table.insert(self.ledbuf, vel)
            else
                print('no note found! coordinates... x: ' .. col .. ' y: ' .. row .. ' z: ' .. z)
            end
        end
    end
end


-- ...then we send the whole buf at once
function midigrid:refresh()
    if self.device then
        midi.devices[midigrid.midi_id]:send(self.ledbuf)

        -- ...and clear the buffer again.
        self.ledbuf = {}
    end
end


-- sure there is more elegant way!
function midigrid:changepage(page)
    midigrid.ledbuf = {}
    if page == 1 then
        for row = 1, midigrid.rows do
            for col = 1, midigrid.cols - 8  do
                midigrid:led(col, row, gridbuf[row][col])
            end
        end
    elseif page == 2 then
        for row = 1, midigrid.rows do
            for col = midigrid.cols - 7, midigrid.cols do
                midigrid:led(col, row, gridbuf[row][col])
            end
        end
    end
    midigrid:refresh()
end


function midigrid.handle_key_midi(event)
    -- type="note_on", note, vel, ch
    -- type="cc", cc, val, ch
    -- so, tldr, `event[2]` is what we want
    local note = event[2]
    local local_grid = midi.devices[midigrid.midi_id]

    -- first, intercept page selectors
    if note == leftpage or note == rightpage then
        if note == leftpage and event[1] == 0x90 and apcpage ~= 1 then
            apcpage = 1
            local_grid:send({144, rightpage, 0})
            local_grid:send({144, leftpage, 1})
            midigrid:changepage(apcpage)
        elseif note == rightpage and event[1] == 0x90 and apcpage ~= 2 then
            apcpage = 2
            local_grid:send({144, rightpage, 1})
            local_grid:send({144, leftpage, 0})
            midigrid:changepage(apcpage)
        else
            -- possibly note_off
        end

    -- "musical" notes, i.e. the main 8x8 grid, are in this range, BUT these values are
    -- device-dependent. Reject cc "notes" here.
    elseif note > -1 and note < 64 then
        local coords = apcnotecoords[apcpage][note]
        local state = 0
        if coords then
            local x, y
            x, y = coords[1], coords[2]
            if event[1] == 0x90 then  -- note_on
                state = 1
            end
            if midigrid.key ~= nil then
                midigrid.key(x, y, state)
            end
        else
            local coords = apcnotecoords[apcpage][note]
            local x, y
            print("missing coords!", x, y, state)
        end
    else
        print("unmapped key")
    end
end

-- init on page 1
midigrid.setup_connect_handling()
midigrid.update_devices()

return midigrid
