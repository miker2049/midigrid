--[[ cheapskate lib for getting midi grid devices to behave like monome grid devices
     two things are run before returning, `setup_connect_handling()` and `update_devices()`.
     `setup_connect_handling()` copies over 'og' midi "add" and "remove" callbacks, and
     provides its own add and remove handlers, i.e. the call backs for:
       - `midi.add()`
       - `midi.remove()`
       - `midi.update_devices()`
     `find_midi_device_id()` iterates through `midi.devices` to see if the name matches, then
     returns `id`, this system manages its own ids, which is why you have to initialize it and
     why first, you connect to it (`midigrid.connect()`), which returns a midigrid object and
     does `set_midi_handler()`
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

-- adding midi device call backs---
local midigrid = {midi_id = nil}
midigrid.ledbuf = {}
midigrid.rows = #gridnotes[1]
midigrid.cols = #gridnotes

-- here, using the grid from the config file, we generate the table to help us go the other
-- way around so, if you press a midi note and you wanna know what it is, this will have an
-- index with our coordinates
local note2coords = {}
for row, notes in ipairs(gridnotes) do
    for col, note in ipairs(notes) do
        note2coords[note] = {col, row}
    end
end


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


function midigrid.handle_key_midi(event)
    -- block cc messages, so they can be mapped
    if (event[1] == 0x90 or event[1] == 0x80) then
        local note = event[2]
        local coords = note2coords[note]
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
            print("missing coords!")
        end
    end
end


-- led handling. *generally speaking*; first we clear the led buffer...
function midigrid:all(vel)
    vel = brightness_handler(vel)
    if self.device then
        self.ledbuf = {}
        for row = 1, midigrid.rows do
            for col = 1, midigrid.cols do
                note = gridnotes[row][col]
                table.insert(self.ledbuf, 0x90)
                table.insert(self.ledbuf, note)
                table.insert(self.ledbuf, vel)
            end
        end
    end
end


-- ...then we update the led buf at our leisure...
function midigrid:led(col, row, z)
    if (col >= 1 and row >= 1)
            and (col <= midigrid.cols and row <= midigrid.rows) then
        vel = brightness_handler(z)
        if self.device then

            -- flag reversed here because thats actually what it is in lua table!!!, see above.
            -- this is clearer either way I think
            note = gridnotes[row][col]
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


-- setting up connection and connection callbacks before returning
midigrid.setup_connect_handling()
midigrid.update_devices()

return midigrid
