--  
--   ////\\\\
--   ////\\\\  TUTORIAL
--   ////\\\\  PART 9
--   \\\\////
--   \\\\////  GRID
--   \\\\////
--

local g
local viewport = { width = 128, height = 64, frame = 0 }
local focus = { x = 1, y = 1, brightness = 15 }

-- Main

function init()
  connect()
  -- Render Style
  screen.level(15)
  screen.aa(0)
  screen.line_width(1)
  -- Render
  update()
end

function connect()
  g = include('lib/apcnome')--grid.connect()
  g.key = on_grid_key
  g.add = on_grid_add
  g.remove = on_grid_remove
end

function is_connected()
  return g.device ~= nil
end

function on_grid_key(x,y,z)
  focus.x = x
  focus.y = y
  update()
end

function on_grid_add(g)
  print('on_add')
end

function on_grid_remove(g)
  print('on_remove')
end

function update()
  g:all(0)
  g:led(focus.x,focus.y,focus.brightness)
  g:refresh()
  redraw()
end

-- Interactions

function key(id,state)
  if id == 2 and state == 1 then
    focus.brightness = 15
  elseif id == 3 and state == 1 then
    focus.brightness = 5
  end
  update()
end

function enc(id,delta)
  if id == 2 then
    focus.x = clamp(focus.x + delta, 1, 16)
  elseif id == 3 then
    focus.y = clamp(focus.y + delta, 1, 8)
  end
  update()
end

-- Render

function draw_frame()
  screen.level(15)
  screen.rect(1, 1, viewport.width-1, viewport.height-1)
  screen.stroke()
end

function draw_pixel(x,y)
  if focus.x == x and focus.y == y then
    screen.stroke()
    screen.level(15)
  end
  screen.pixel((x*offset.spacing) + offset.x, (y*offset.spacing) + offset.y)
  if focus.x == x and focus.y == y then
    screen.stroke()
    screen.level(1)
  end
end

function draw_grid()
  if is_connected() ~= true then return end
  screen.level(1)
  offset = { x = 30, y = 13, spacing = 4 }
  for x=1,16,1 do 
    for y=1,8,1 do 
      draw_pixel(x,y)
    end
  end
  screen.stroke()
end

function draw_label()
  screen.level(15)
  local line_height = 8
  screen.move(5,viewport.height - (line_height * 1))
  if is_connected() ~= true then
    screen.text('Grid is not connected.')
  else
    screen.text(focus.x..','..focus.y)
  end
  screen.stroke()
end

function redraw()
  screen.clear()
  draw_frame()
  draw_grid()
  draw_label()
  screen.stroke()
  screen.update()
end

-- Utils

function clamp(val,min,max)
  return val < min and min or val > max and max or val
end
