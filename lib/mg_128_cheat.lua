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
--cheat codes version, so three tables corresponding to :w

local views = {{},{},{}}

local curr_view = 1

--be sure to put this after midigrid.init()
function midigrid.views_init()
    -- defined so that our table's indices correspond to the quad numbers we've decided on:
    --     1|2|3
    view_btns = {
        config.upper_left_quad_button,
        config.upper_right_quad_button,
        config.lower_left_quad_button
    }
    -- start on "quad" 1
    -- make the grid buf, a hardcoded 128 grid
    grid_buf = {}
    for x = 1, 16 do
        grid_buf[x] = {}
        for y = 1, 8 do
            grid_buf[x][y] = 0
            _populate_view(x,y)
        end
    end
    --rotating the grid just for notes part 
    grid_notes_rot = _rotate_grid_notes(grid_notes)

    --note coords for three view
    view_note_coords = {{},{},{}}
    for row, notes in ipairs(grid_notes_rot) do
      for col, note in ipairs(notes) do
        view_note_coords[1][note] = {col, row}
        view_note_coords[2][note] = {col+6, row}
        view_note_coords[3][note] = {col+12, row}
      end
    end
    --see, still needs to be 16xs of 8y
    midigrid.cols=16
    midigrid.rows=8
    midigrid:refresh()
end

function _populate_view(x,y)
  local index = 16*y+x  --this is all goofy because we are not zero indexed, but it shouldnt matter...
  if x > 12 then
    --we are on the second view
    views[3][index] = grid_notes_rot[y][x-12]
  elseif x > 6 then
    views[2][index] = grid_notes_rot[y][x-6]
  else
    views[1][index] = grid_notes_rot[y][x]
  end
end

-- this rotates a 64 grid_notes table, as specified in config as a table of rows, 90 degrees, so its a table of columns
function _rotate_grid_notes(grid_notes)
        -- ok because we want to "flip this", we need to just do something very simple:
        -- if you flip a 128 grid into portrait mode, you can imagine that suddenly you have 8 columns of 16, rather than 16 columns of 8
        -- cheat codes to us like this, but the grid is not, its programmed always as 16 xs of y.
        -- this part of the code concerns filling out the 'view_note_coords' table, which deals with midi into the script as a grid
        -- it adds an index to a section of the table that represents a view, and gives a coordinate table
        -- now we want to say that our midigrid note for (1,1) is (8,1)
        -- (2,1) is (8,2)
        -- (3,1) is (8,3)
        -- (1,2) is (7,1)
        -- (1,3) is (6,1)
        -- (1,4) is (5,1)
        -- (1,5) is (4,1)
        -- (1,6) is (3,1)
        -- (7,1) is (8,7)
        -- (1,8) is (1,1)
        -- (2,8) is (1,2)
        -- (3,8) is (1,3)
        -- (3,7) is (1,3)
        --...ok
        -- (x,y) to (x',y'):
        -- x = y'
        -- y = 9 - y
        -- x' always seems to be = 9 - y
        -- y' always seems to equal x
        -- I think we can say this makes sense because the transformation on the x axis is one that makes y's original progression (x, (y1,y2,...)) be rather a decreasing distance from the x limit, and it seems random that its 9, but its just because we are base 1...
  --ok all the above is scrapped in favor of simply flipping this grid on init
        -- grid_notes= {
        --   {56,57,58,59,60,61,62,63},
        --   {48,49,50,51,52,53,54,55},
        --   {40,41,42,43,44,45,46,47},
        --   {32,33,34,35,36,37,38,39},
        --   {24,25,26,27,28,29,30,31},
        --   {16,17,18,19,20,21,22,23},
        --   {8,9,10,11,12,13,14,15},
        --   {0,1,2,3,4,5,6,7}
        -- }
        -- iterating, the first row is all the 1 columns
        --special cheat codes rotation cheat codes are:
        -- local x = 9 - row
        -- local y = col
  local rotated = {{},{},{},{},{},{},{},{}}
  for rows = 1, 8 do
    for cols = 8, 1, -1 do
      rotated[rows][cols] = config.grid_notes[cols][rows]
    end
  end
  return rotated
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
            for y = 1, 8  do
                midigrid:led(x, y, grid_buf[x][y])
            end
        end
    elseif view == 2 then
        for x = 9, 16 do
            for y= 1, 8 do
                midigrid:led(x, y, grid_buf[x][y])
            end
        end
    end
    midigrid:refresh()
end


function _handle_view(midi_msg, which_view)
    if midi_msg.type == "note_on" or caps["cc_edge_buttons"] then
        view = which_view
        curr_view = view
        _light_quad_button(view)
        midigrid:changeview(view)
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
      -- print("tab contains!")
        for view, button in ipairs(view_btns) do
            if note == button
                    and curr_view ~= view then
                      -- print("note==button and curr_view ~= view")
                      -- ...and change the quad, if needed
                      -- curr_view = view
                      _handle_view(midi_msg, view)
                return
            end
        end
    -- "musical" notes, i.e. the main 8x8 grid, are in this range, BUT these values are
    -- device-dependent. Reject cc "notes" here.
    -- elseif (note >= 0 and note <= 88)
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
            print('Error: missing coordinates for this midi note!')
        end
    end
end

midigrid.init()
midigrid.views_init()

return midigrid
