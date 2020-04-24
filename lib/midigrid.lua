--the straight, vanilla implementation of midigrid where midi keys correspond to grid leds 1 to 1
local midigrid = include('midigrid/lib/core')

--init is called before returning the final pseudo grid object

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
        --TODO elseif here? 
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
