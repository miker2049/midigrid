local apcmini={
  --here we have the 'grid' this looks literally like the grid notes as they are mapped on the apc, they can be changed for other devices
  --note though, that a call to this table will look backwards, i.e, to get the visual x=1 and y=2, you have to enter midigrid[2][1], not the other way around!
  grid_notes= {{56,57,58,59,60,61,62,63},
    {48,49,50,51,52,53,54,55},
    {40,41,42,43,44,45,46,47},
    {32,33,34,35,36,37,38,39},
    {24,25,26,27,28,29,30,31},
    {16,17,18,19,20,21,22,23},
    {8,9,10,11,12,13,14,15},
    {0,1,2,3,4,5,6,7}
  },

  max_note = 63,

  --here, the function expects a brightness_handler val and spits out another val so your midi controller can understand, these values are generally great for apc with most scripts, but will also need to be adjusted for other controllers!
  --corresponds here to the 4 available states on apc: 0(off), 1(green) , 3(yellow), 5(red)
  brightness_handler = function (val)
    if val == 0 then
      return 0
    elseif (val > 0) and (val < 8) then
      return 1
    elseif (val > 7) and (val < 12) then
      return 3
    elseif (val > 11) and (val < 16) then
      return 5
    else
      return 0
    end
  end,

  -- dummy functions because it doesnt apply to apcmini
  all_led_sysex = function(self, color) return end,
  led_sysex = function(self, color) return end,

  -- table of device-specific capabilities
  caps = {
    -- can we use sysex to update the grid leds?
    sysex = false,
    -- is this an rgb device?
    rgb = false,
    -- can we double buffer?
    lp_double_buffer = false,
    -- do the edge buttons send cc?
    cc_edge_buttons = false
  },
  --these are the keys in the apc to the sides of our apc, not necessary for strict grid emulation but handy!
  --they are up to down, so 82 is the auxkey to row 1
  auxcol = {82,83,84,85,86,87,88,89},
  --left to right, 64 is aux key to column 1
  auxrow = {64,65,66,67,68,69,70,71},

  -- here we set the buttons to use when switching quads in multi-quad mode
  upper_left_quad_button = 64,
  upper_right_quad_button = 65,
  lower_left_quad_button = 66,
  lower_right_quad_button = 67,

  device_name='apc mini'
}

return apcmini
