--[[ cheapskate library for midi grid devices, 2 quads, i.e. a "128" device.
     contains within itself a full 128 grid table, which can be viewed and played by pressing
     the '*_quad_button' buttons as defined in the relevant config file.
]]

-- if there's no *monome* grid attached, norns returns a valid but unpopulated grid table
-- so must we
-------------------------------------------------------------------------------
--
-------------------------------------------------------------------------------
-- views, everything goes to a grid buf, and a set of views defines grid behaviour


local midigrid = include('midigrid/lib/core')
local tab = require 'tabutil'


--views are tables corresponding to a view of the grid_buf, as such they have correspondences between serialized grid bux indices and local midinote messages
local views = {{},{}}


--be sure to put this after midigrid.init()
function midigrid.views_init()
    -- defined so that our table's indices correspond to the quad numbers we've decided on:
    --     1|2
    view_btns = {
        config.upper_left_quad_button,
        config.upper_right_quad_button
    }
    -- start on "quad" 1
    curr_view = 1
    -- make the grid buf, a hardcoded 128 grid
    grid_buf = {}
    for x = 1, 16 do
        grid_buf[x] = {}
        for y = 1, 8 do
            grid_buf[x][y] = 0
            _populate_view(x,y)
        end
    end
    --note coords for two view
    view_note_coords = {{},{}}
    for row, notes in ipairs(grid_notes) do
      for col, note in ipairs(notes) do
        view_note_coords[1][note] = {col, row}
        view_note_coords[2][note] = {col+8, row}
      end
    end
    midigrid.cols=16
    midigrid.rows=8
end

function _populate_view(x,y)
  local index = 16*y+x  --this is all goofy because we are not zero indexed, but it shouldnt matter...
  if x > 8 then
    --we are on the second view
    print('adding the note '..config.grid_notes[y][x-8]..' to the coordinates'..x..','..y..'  at index '..index..' on view 2')
    views[2][index] = config.grid_notes[y][x-8]
  else
    print('adding the note '..config.grid_notes[y][x]..' to the coordinates'..x..','..y..'  at index '..index..' on view 1')
    views[1][index] = config.grid_notes[y][x]
  end
end

function debug_views()
  print("debug"..#views[1])
  for i,v in ipairs(views[1])  do
    local x = math.tointeger(i/#views[1])
    local y = math.tointeger(i%#views[1])
    print("x is "..x.." and y is "..y)
  end
end

function _light_quad_button(which_quad)
    -- regardless of which quad button we wish to light, we still have to turn
    --     off all the others
      for quad, _ in ipairs(view_btns) do
          if quad == which_quad then
              _local_midi_dev:note_on(view_btns[quad], 1)
          else
              _local_midi_dev:note_on(view_btns[quad], 0)
          end
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
  print("all!")
  -- tab.print(views[1])
  debug_views()
  -- tab.print(views[2])
  local vel = brightness_handler(brightness)
  for x = 1, 16 do
    for y = 1, 8 do
      if grid_buf[x][y] ~= brightness then  -- this led needs to be set
        grid_buf[x][y] = brightness
        local index = 16*y+x
        local note = views[curr_view][index]
        if note ~= nil then
          _brightness_to_buffer(note, vel, config:led_sysex(note, vel))
        end
      end
    end
  end
end


function midigrid:led(x, y, brightness)
  grid_buf[x][y] = brightness
  local index =16*y+x
  local note = views[curr_view][index]
  if note ~= nil then
    local vel = brightness_handler(brightness)
    _brightness_to_buffer(note, vel, config:led_sysex(note, vel))
  else
    print("not in view!")
  end
end


function midigrid:refresh()
    if midigrid.device then
        if caps['lp_double_buffer'] then
            _local_midi_dev:send(config:display_double_buffer_sysex())
        end
        _local_midi_dev:send(midigrid.led_buf)
        -- apparently, we need to refresh the quad button leds as well
        _light_quad_button(curr_view)
        -- ...and clear the buffer again.
        midigrid.led_buf = {}
    else
        print('Error: no device found')
    end
end


function midigrid:changeview(view)
    midigrid.led_buf = {}
    if view == 1 then
        for x = 1, 8 do
            for col = 1, 8  do
                midigrid:led(col, row, grid_buf[row][col])
            end
        end
    elseif view == 2 then
        for row = 1, midigrid.rows do
            for col = midigrid.cols - 7, midigrid.cols do
                midigrid:led(col, row, grid_buf[row][col])
            end
        end
    end
    midigrid:refresh()
end


function _handle_quad(midi_msg, which_view)
    if midi_msg.type == "note_on" or caps["cc_edge_buttons"] then
        view = which_view
        _light_quad_button(view)
        midigrid.changeview(quad)
    end
end


function midigrid.handle_key_midi(event)
    -- type="note_on", note, vel, ch
    -- type="cc", cc, val, ch
    -- so, tldr, `event[2]` is what we want
    local note = event[2]
    local midi_msg = midi.to_msg(event)
    -- first, intercept the quad buttons...
    if tab.contains(view_btns, note) then
        for view, button in ipairs(view_btns) do
            if note == button
                    and curr_view ~= view then
                -- ...and change the quad, if needed
                _handle_quad(midi_msg, local_quad)
                return
            end
        end
    -- device-dependent. Reject cc "notes" here.
    elseif (midi_msg.type == 'note_on' or midi_msg.type == 'note_off') then
        local coords = view_note_coords[curr_view][note]
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
midigrid.views_init()

return midigrid
