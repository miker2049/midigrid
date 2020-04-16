--[[ midigrid core lib for getting midi grid devices to behave like monome grid devices, this is functions shared among the 64, 128, and 256 version.
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

return midigrid
