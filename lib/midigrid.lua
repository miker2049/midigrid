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

-- if there's no *monome* grid attached, norns returns a valid but unpopulated grid table
-- so must we
local midigrid = {
    midi_id = nil,
    device = nil,
    rows = 0,
    cols = 0,
    name = "none"
}


brightness_handler = function(val) return 0 end


function midigrid.init()
    local supported_devices = {
        apcmini = 'apc mini',
        launchpadmk2 = 'launchpad mk2',
        launchpadpro = 'launchpad pro 2',
        launchpad = 'launchpad',
        launchpadmini = 'launchpad mini'
    }
    local config_name = 'none'
    config = nil
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
        return midigrid
    end
    config = include(config_name)
    grid_notes = config.grid_notes
    brightness_handler = config.brightness_handler
    device_name = config.device_name
    og_dev_add = nil
    og_dev_remove = nil
    caps = config.caps

    -- adding midi device call backs---
    midigrid.led_buf = {}
    midigrid.rows = #grid_notes[1]
    midigrid.cols = #grid_notes

    -- here, using the grid from the config file, we generate the table to help us go the other
    -- way around so, if you press a midi note and you wanna know what it is, this will have an
    -- index with our coordinates
    note_coords = {}
    for row, notes in ipairs(grid_notes) do
        for col, note in ipairs(notes) do
            note_coords[note] = {col, row}
        end
    end

    -- setting up connection and connection callbacks before returning
    midigrid.setup_connect_handling()
    midigrid.update_devices()
    _local_midi_dev = midi.devices[midigrid.midi_id]
end

function midigrid.find_midi_device_id()
    local found_id = nil
    for _, dev in pairs(midi.devices) do
        local name = string.lower(dev.name)
        if midigrid.name_matches(name) then
            found_id = dev.id
        end
    end
    return found_id
end


function midigrid.connect(dummy_id)
    if config == nil then
        return midigrid
    end
    midigrid.set_midi_handler()
    print('midigrid "' .. device_name .. '" has ' .. midigrid.rows .. ' rows, ' .. midigrid.cols .. ' cols')
    midigrid:all(0)
    midigrid:refresh()
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
        midigrid.set_midi_handler()
    end
end


function midigrid.handle_dev_remove(id)
    og_dev_remove(id)
    midigrid.update_devices()
end


-- this already expects it to have Midi_id
function midigrid.set_midi_handler()
    if midigrid.midi_id == nil then
        return
    end
    local local_grid = midi.devices[midigrid.midi_id]
    if local_grid ~= nil then
        local_grid.event = midigrid.handle_key_midi

        -- need this for checking .device
        midigrid.device = local_grid
        print('`midigrid.device` is:')
        tab.print(midigrid.device)
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


function _brightness_to_buffer(note, vel, result)
    -- `result` is the table returned by whichever led fn we called as an arg to
    --     *this* fn
    if caps["sysex"] and caps["rgb"] then
        for _, bytes in ipairs(result) do
            table.insert(midigrid.led_buf, bytes)
        end
    else
        table.insert(midigrid.led_buf, 0x90)
        table.insert(midigrid.led_buf, note)
        table.insert(midigrid.led_buf, vel)
    end
end


-- led handling. *generally speaking*; first we clear the led buffer...
function midigrid:all(brightness)
    local vel = brightness_handler(brightness)
    local note = nil
    if midigrid.device then
        midigrid.led_buf = {}
        for row = 1, midigrid.rows do
            for col = 1, midigrid.cols do
                note = grid_notes[row][col]
                -- the result of the fn call becomes the arg to `_brightness_to_buffer`
                _brightness_to_buffer(note, vel, config:all_led_sysex(vel))
            end
        end
    end
end


-- ...then we update the led buf at our leisure...
function midigrid:led(col, row, brightness)
    if (col >= 1 and row >= 1) and (col <= midigrid.cols and row <= midigrid.rows) then
        local vel = brightness_handler(brightness)
        local note = nil
        if midigrid.device then
            note = grid_notes[row][col]
            if note then
                -- the result of the fn call becomes the arg to `_brightness_to_buffer`
                _brightness_to_buffer(note, vel, config:led_sysex(note, vel))
            else
                print('no note found! coordinates... x: ' .. col .. ' y: ' .. row .. ' z: ' .. brightness)
            end
        end
    end
end


-- ...then we send the whole buf at once
function midigrid:refresh()
    if midigrid.device then
        if caps['lp_double_buffer'] then
            _local_midi_dev:send(config:display_double_buffer_sysex())
        end
        _local_midi_dev:send(midigrid.led_buf)

        -- ...and clear the buffer again.
        midigrid.led_buf = {}
    else
        print('Error: no device found')
    end
end


function midigrid.handle_key_midi(event)
    -- type="note_on", note, vel, ch
    -- so, tldr, `event[2]` is what we want
    local note = event[2]
    local midi_msg = midi.to_msg(event)

    -- "musical" notes, i.e. the main 8x8 grid, are in this range, BUT these values are
    -- device-dependent. Reject cc "notes" here.
    if (note >= 0 and note <= 88)
            and (midi_msg.type == 'note_on' or midi_msg.type == 'note_off') then
        local coords = note_coords[note]
        local state = 0
        if coords then
            local x, y
            x, y = coords[1], coords[2]
            if midi_msg.type == 'note_on' then
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


midigrid.init()

return midigrid
