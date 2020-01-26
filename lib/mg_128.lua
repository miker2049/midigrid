--[[ cheapskate library for midi grid devices, 2 quads, i.e. a "128" device.
     contains within itself a full 128 grid table, which can be viewed and played by pressing
     the '*_quad_button' buttons as defined in the relevant config file.
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
        apcmini = 'apcmini',
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

    -- defined so that our table's indices correspond to the quad numbers we've decided on:
    --     1|2
    quad_btns = {
        config.upper_left_quad_button,
        config.upper_right_quad_button
    }

    -- adding midi device call backs
    midigrid.led_buf = {}
    midigrid.rows = #grid_notes[1]
    midigrid.cols = #grid_notes * 2  -- an assumption, but a safe one

    -- start on "quad" 1
    quad = 1

    -- make the grid buf
    grid_buf = {}
    for rows = 1, midigrid.rows do
        grid_buf[rows] = {}
        for cols = 1, midigrid.cols do
            grid_buf[rows][cols] = 0
        end
    end

    -- getting the two quads set up
    local upper_left_note_coords = {}
    local upper_right_note_coords = {}
    for row, notes in ipairs(grid_notes) do
        for col, note in ipairs(notes) do
            upper_left_note_coords[note] = {col, row}
            upper_right_note_coords[note] = {col + 8, row}
        end
    end
    note_coords = {
        upper_left_note_coords,
        upper_right_note_coords
    }

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


function _light_quad_button(which_quad)
    -- regardless of which quad button we wish to light, we still have to turn
    --     off all the others
      for quad, _ in ipairs(quad_btns) do
          if quad == which_quad then
              _local_midi_dev:note_on(quad_btns[quad], 1)
          else
              _local_midi_dev:note_on(quad_btns[quad], 0)
          end
      end
  end


function midigrid.connect(dummy_id)
    if config == nil then
        return midigrid
    end
    midigrid.set_midi_handler()
    print('midigrid "' .. device_name .. '" has ' .. midigrid.rows .. ' rows, ' .. midigrid.cols .. ' cols')
    midigrid:all(0)
    midigrid:refresh()

    -- init on quad 1
    _light_quad_button(1)
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


-- led handling. *generally speaking*; first we clear the unchanged led buffer...
function midigrid:all(brightness)
    local vel = brightness_handler(brightness)
    local note = nil
    if midigrid.device then
        for row = 1, midigrid.rows do
            for col = 1, midigrid.cols do
                if grid_buf[row][col] ~= brightness then  -- this led needs to be set
                    grid_buf[row][col] = brightness
                    if (quad == 1 and col < 9) then
                        note = grid_notes[row][col]
                    elseif (quad == 2 and col > 8) then
                        note = grid_notes[row][col - 8]
                    end
                    -- the result of the fn call becomes the arg to `_brightness_to_buffer`
                    _brightness_to_buffer(note, vel, config:all_led_sysex(vel))
                end
            end
        end
    end
end


-- ...then we update the led buf at our leisure...
function midigrid:led(col, row, brightness)
    if (col >= 1 and row >= 1) and (col <= midigrid.cols and row <= midigrid.rows) then
        local vel = brightness_handler(brightness)
        local note = nil
        grid_buf[row][col] = brightness

        -- if we aint on the right quad dont bother
        if col >= 9 and quad == 1 then
            return
        end
        if col <= 8 and quad == 2 then
            return
        end
        if midigrid.device then
            if quad == 1 then
                note = grid_notes[row][col]
            elseif quad == 2 then
                note = grid_notes[row][col - 8]
            end
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

        -- apparently, we need to refresh the quad button leds as well
        _light_quad_button(quad)

        -- ...and clear the buffer again.
        midigrid.led_buf = {}
    else
        print('Error: no device found')
    end
end


-- surely there is more elegant way!
function midigrid:changequad(quad)
    midigrid.led_buf = {}
    if quad == 1 then
        for row = 1, midigrid.rows do
            for col = 1, midigrid.cols - 8  do
                midigrid:led(col, row, grid_buf[row][col])
            end
        end
    elseif quad == 2 then
        for row = 1, midigrid.rows do
            for col = midigrid.cols - 7, midigrid.cols do
                midigrid:led(col, row, grid_buf[row][col])
            end
        end
    end
    midigrid:refresh()
end


function _handle_quad(midi_msg, which_quad)
    if midi_msg.type == "note_on" or caps["cc_edge_buttons"] then
        quad = which_quad
        _light_quad_button(quad)
        midigrid.changequad(quad)
    end
end


function midigrid.handle_key_midi(event)
    -- type="note_on", note, vel, ch
    -- type="cc", cc, val, ch
    -- so, tldr, `event[2]` is what we want
    local note = event[2]
    local midi_msg = midi.to_msg(event)

    -- first, intercept the quad buttons...
    if tab.contains(quad_btns, note) then
        for local_quad, button in ipairs(quad_btns) do
            if note == button
                    and quad ~= local_quad then
                -- ...and change the quad, if needed
                _handle_quad(midi_msg, local_quad)
            end
        end

    -- "musical" notes, i.e. the main 8x8 grid, are in this range, BUT these values are
    -- device-dependent. Reject cc "notes" here.
    elseif (note >= 0 and note <= 88)
            and (midi_msg.type == 'note_on' or midi_msg.type == 'note_off') then
        local coords = note_coords[quad][note]
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

midigrid.init()

return midigrid
