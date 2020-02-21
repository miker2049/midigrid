--[[ cheapskate library for midi grid devices, 4 quads, i.e. a "256" device.
     contains within itself a full 256 grid table, which can be viewed and played by pressing
     the '*_quad_button' buttons as defined in the relevant config file.
]]

local midigrid = include('midigrid/lib/base')
local vgrid = include('midigrid/lib/vgrid')

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
    og_dev_add = nil
    og_dev_remove = nil
    caps = config.caps

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

    --[[--
    -- adding midi device call backs
    midigrid.led_buf = {}
    midigrid.rows = #grid_notes[1] * 2  -- an assumption, but a safe one
    midigrid.cols = #grid_notes * 2  -- as above

    midigrid.vgrid = Vgrid
    midigrid.vgrid.init('256')
    --]]--

    --[[--
    -- getting the four quads set up
    local upper_left_note_coords = {}
    local upper_right_note_coords = {}
    local lower_left_note_coords = {}
    local lower_right_note_coords = {}
    for row, notes in ipairs(grid_notes) do
        for col, note in ipairs(notes) do
            upper_left_note_coords[note] = {col, row}
            upper_right_note_coords[note] = {col + 8, row}
            lower_left_note_coords[note] = {col, row + 8}
            lower_right_note_coords[note] = {col + 8, row + 8}
        end
    end
    note_coords = {
        upper_left_note_coords,
        upper_right_note_coords,
        lower_left_note_coords,
        lower_right_note_coords
    }
    --]]--

    -- setting up connection and connection callbacks before returning
    midigrid.setup_connect_handling()
    midigrid.update_devices()
    _local_midi_dev = midi.devices[midigrid.midi_id]
end

function midigrid.connect(dummy_id)
    if config == nil then
        return midigrid
    end
    midigrid.set_midi_handler()
    print('midigrid "' .. device_name .. '" has ' .. midigrid.rows .. " rows, " .. midigrid.cols .. " cols")
    midigrid:all(0)
    midigrid:refresh()

    -- init on quad 1
    _light_quad_button(1)
    return midigrid
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
        print("`midigrid.device` is:")
        tab.print(midigrid.device)
    else
        midigrid.midi_id = nil
    end
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
    self.vgrid:set_all_led(vel)
end

-- ...then we update the led buf at our leisure...
function midigrid:led(col, row, brightness)
  print("Setting LED r:"..row..' c:'..col..' B:'..brightness)
  migigrid.vgrid.set(col, row, brightness)
end


-- ...then we send the whole buf at once...
function midigrid:refresh()
  --Convert grid level to midi device level
  --local vel = brightness_handler(brightness)
  
    if midigrid.device then
      --_local_midi_dev:redraw(midigrid.vgrid)
        if caps['lp_double_buffer'] then
            _local_midi_dev:send(config:display_double_buffer_sysex())
        end
        _local_midi_dev:send(midigrid.led_buf)

        -- apparently, we need to refresh the quad button leds as well
        _light_quad_button(quad)

        -- ...and clear the buffer again.
        midigrid.led_buf = {}
    else
        print("Error: no device found")
    end
end


function midigrid._draw_quad_buf(quad)
  local actual_row = 0
  local actual_col = 0
  
  print("current Quad")
  tab.print(quads[quad])
  
  print("current Quad Buffer")
  for zz = 1,#quads[quad].buffer do
    tab.print(quads[quad].buffer[zz])
  end
  
  for row = 1,quads[quad].width  do
    actual_row = row + quads[quad].offset_x
    for col = 1,quads[quad].height  do
      -- print("Setting led r:" .. row .. ' c:' .. col)
      actual_col = col + quads[quad].offset_y
      midigrid:led(actual_col, actual_row, quads[quad].buffer[row][col])
    end
  end
end

function midigrid.changequad()
    print("Changing to quad "..quad)
    midigrid._draw_quad_buf(quad)
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
            if note == button and quad ~= local_quad then
                -- ...and change the quad, if needed
                _handle_quad(midi_msg, local_quad)
            end
        end

    -- "musical" notes, i.e. the main 8x8 grid, are in this range, BUT these values are
    -- device-dependent. Reject cc "notes" here.
    elseif (midi_msg.type == "note_on" or midi_msg.type == "note_off") then
        local coords = note_coords[quad][note]
        local state = 0
        if coords then
            local x, y
            x, y = coords[1], coords[2]
            if midi_msg.type == "note_on" then
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
