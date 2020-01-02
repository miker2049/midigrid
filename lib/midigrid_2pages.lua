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
local grid_notes = config.grid_notes
local brightness_handler = config.brightness_handler
local device_name = config.device_name
local og_dev_add, og_dev_remove
local caps = config.caps
local leftpage = config.leftpage_button
local rightpage = config.rightpage_button

-- adding midi device call backs
local midigrid = {midi_id = nil}
midigrid.led_buf = {}
midigrid.rows = #grid_notes[1]
midigrid.cols = #grid_notes * 2  -- an assumption, but a safe one

-- start on "page" 1
local page = 1

-- make the grid buf
local grid_buf = {}
for rows = 1, midigrid.rows do
    grid_buf[rows] = {}
    for cols = 1, midigrid.cols do
        grid_buf[rows][cols] = 0
    end
end

-- getting the two pages set up
left_note_coords = {}
right_note_coords = {}
for row, notes in ipairs(grid_notes) do
    for col, note in ipairs(notes) do
        left_note_coords[note] = {col, row}
        right_note_coords[note] = {col + 8, row}
    end
end
note_coords = {left_note_coords, right_note_coords}


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
    midigrid.set_midi_handler()
    print('midigrid "' .. device_name .. '" has ' .. midigrid.rows .. ' rows, ' .. midigrid.cols .. ' cols')
    midigrid:all(0)
    midigrid:refresh()

    -- init on page 1
    midi.devices[midigrid.midi_id]:note_on(leftpage, 1)
    midi.devices[midigrid.midi_id]:note_on(rightpage, 0)
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
    if midi.devices[midigrid.midi_id] ~= nil then
        midi.devices[midigrid.midi_id].event = midigrid.handle_key_midi

        -- need this for checking .device
        midigrid.device = midi.devices[midigrid.midi_id]
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


-- led handling. *generally speaking*; first we clear the unchanged led buffer...
function midigrid:all(brightness)
    vel = brightness_handler(brightness)
    if midigrid.device then
        for row = 1, midigrid.rows do
            for col = 1, midigrid.cols do
                if grid_buf[row][col] ~= brightness then  -- this led needs to be set
                    grid_buf[row][col] = brightness
                    if (page == 1 and col < 9) then
                        note = grid_notes[row][col]
                        if caps['sysex'] and caps['rgb'] then
                            sysex = config:all_led_sysex(vel)
                            for _, byte in ipairs(sysex) do
                                table.insert(midigrid.led_buf, byte)
                            end
                        else
                            table.insert(midigrid.led_buf, 0x90)
                            table.insert(midigrid.led_buf, note)
                            table.insert(midigrid.led_buf, vel)
                        end
                    elseif (page == 2 and col > 8) then
                        note = grid_notes[row][col - 8]
                        if caps['sysex'] and caps['rgb'] then
                            sysex = config:all_led_sysex(vel)
                            for _, byte in ipairs(sysex) do
                                table.insert(midigrid.led_buf, byte)
                            end
                        else
                            table.insert(midigrid.led_buf, 0x90)
                            table.insert(midigrid.led_buf, note)
                            table.insert(midigrid.led_buf, vel)
                        end
                        table.insert(midigrid.led_buf, 0x90)
                        table.insert(midigrid.led_buf, note)
                        table.insert(midigrid.led_buf, vel)
                    end
                end
            end
        end
    end
end


-- ...then we update the led buf at our leisure...
function midigrid:led(col, row, brightness)
    if (col >= 1 and row >= 1)
            and (col <= midigrid.cols and row <= midigrid.rows) then
        vel = brightness_handler(brightness)
        grid_buf[row][col] = brightness

        -- if we aint on the right page dont bother
        if col >= 9 and page == 1 then
            return
        end
        if col <= 8 and page == 2 then
            return
        end
        if midigrid.device then
            if page == 1 then
                note = grid_notes[row][col]
            elseif page == 2 then
                note = grid_notes[row][col - 8]
            end
            if note then
                if caps['sysex'] and caps['rgb'] then
                    sysex = config:led_sysex(note, vel)
                    for _, byte in ipairs(sysex) do
                        table.insert(midigrid.led_buf, byte)
                    end
                else
                    table.insert(midigrid.led_buf, 0x90)
                    table.insert(midigrid.led_buf, note)
                    table.insert(midigrid.led_buf, vel)
                end
            else
                print('no note found! coordinates... x: ' .. col .. ' y: ' .. row .. ' z: ' .. brightness)
            end
        end
    end
end


-- ...then we send the whole buf at once
function midigrid:refresh()
    local local_grid = midi.devices[midigrid.midi_id]
    if midigrid.device then
        local_grid:send(midigrid.led_buf)

        -- apparently, we need to refresh the page leds as well
        if page == 1 then
            local_grid:note_on(leftpage, 1)
            local_grid:note_on(rightpage, 0)
        elseif page == 2 then
            local_grid:note_on(leftpage, 0)
            local_grid:note_on(rightpage, 1)
        end

        -- ...and clear the buffer again.
        midigrid.led_buf = {}
    else
        print('Error: no device found')
    end
end


-- surely there is more elegant way!
function midigrid:changepage(page)
    midigrid.led_buf = {}
    if page == 1 then
        for row = 1, midigrid.rows do
            for col = 1, midigrid.cols - 8  do
                midigrid:led(col, row, grid_buf[row][col])
            end
        end
    elseif page == 2 then
        for row = 1, midigrid.rows do
            for col = midigrid.cols - 7, midigrid.cols do
                midigrid:led(col, row, grid_buf[row][col])
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
    local midi_msg = midi.to_msg(event)
    local local_grid = midi.devices[midigrid.midi_id]

    -- first, intercept page selectors
    if note == leftpage or note == rightpage then
        if note == leftpage
                and (midi_msg.type == 'note_on' or caps['cc_edge_buttons'])
                and page ~= 1 then
            page = 1
            local_grid:note_on(rightpage, 0)
            local_grid:note_on(leftpage, 1)
            midigrid:changepage(page)
        elseif note == rightpage
                and (midi_msg.type == 'note_on' or caps['cc_edge_buttons'])
                and page ~= 2 then
            page = 2
            local_grid:note_on(rightpage, 1)
            local_grid:note_on(leftpage, 0)
            midigrid:changepage(page)
        else
            -- possibly note_off
        end

    -- "musical" notes, i.e. the main 8x8 grid, are in this range, BUT these values are
    -- device-dependent. Reject cc "notes" here.
    elseif (note >= 0 and note <= 88)
            and (midi_msg.type == 'note_on'
            or midi_msg.type == 'note_off') then
        local coords = note_coords[page][note]
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
            print('missing coords!')
        end
    end
end

-- init on page 1
midigrid.setup_connect_handling()
midigrid.update_devices()

return midigrid
