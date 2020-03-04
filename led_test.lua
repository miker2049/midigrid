local grid = include "midigrid/lib/midigrid"
local g = grid.connect()

local grid_metro = metro.init()

local grid_clock = 0

local light_pattern = {}
for i = 1,16 do
  light_pattern[i] = i-1
end

grid_metro.event = function()
    --print("beat")
    local light_level = 0
    for x = 1,16 do
      -- Two rows showing full LED scale
      for y = 1,2 do
        if x <= 8 then
          light_level = x + (y*8)-8
        else
          light_level = (x-8) + (y*8)-8
        end
        g:led(x,y,light_pattern[light_level])
      end
      -- Rest of the rows scrolling 
      for y = 3,8 do
        light_level = ((x+(y-1)+(grid_clock)) % 16)+1
        g:led(x,y,light_pattern[light_level])
      end
    end
    
    g:refresh()
    
    grid_clock = (grid_clock+1)
end

function init()
  print('init')
  grid_metro:start((0.06))
  g:all(0)
end
  
function redraw()

end

function key(n, z)

end

function enc(n, d)

end