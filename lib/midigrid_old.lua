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

local midigrid = include('midigrid/lib/base')

brightness_handler = function(val) return 0 end


function midigrid.init()
    local midi_device = midigrid._find_midigrid_devices() or 'none'
    
    if midi_device == 'none' then
        print('No supported device found')
        return midigrid
    end

    config = include('midigrid/config/' .. midi_device .. '_config')
    
    grid_notes = config.grid_notes
    brightness_handler = config.brightness_handler
    
    device_name = config.device_name
    name = config.device_name
    caps = config.caps
    
    og_dev_add = nil
    og_dev_remove = nil

    -- defined so that our table's indices correspond to the quad numbers we've decided on:
    --     1|2
    --     ---
    --     3|4
    quad_btns = {
        config.upper_left_quad_button,
        config.upper_right_quad_button,
        config.lower_left_quad_button,
        config.lower_right_quad_button
    }

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
    -- Note that midi msg already translates note on vel 0 to note off type
    local midi_msg = midi.to_msg(event)
    
    -- Debug incomming midi messages
    -- tab.print(midi_msg)

    -- "musical" notes, i.e. the main 8x8 grid, are in this range, BUT these values are
    -- device-dependent. Reject cc "notes" here.
    if (midi_msg.type == 'note_on' or midi_msg.type == 'note_off') then
        local coords = note_coords[midi_msg.note]
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
        if (midi_msg.type == 'cc') then
          print ('CC '.. midi_msg.note)
        end
    end
end


midigrid.init()

return midigrid
