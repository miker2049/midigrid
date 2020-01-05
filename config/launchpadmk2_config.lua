local launchpad = {
  -- here we have the 'grid'. this looks literally like the grid notes as they are on
  -- the device.
  -- note though, that a call to this table will look backwards, i.e, to get the
  -- visual x=1 and y=2, you have to enter midigrid[2][1], not the other way around!
  grid_notes = {
      {81, 82, 83, 84, 85, 86, 87, 88},
      {71, 72, 73, 74, 75, 76, 77, 78},
      {61, 62, 63, 64, 65, 66, 67, 68},
      {51, 52, 53, 54, 55, 56, 57, 58},
      {41, 42, 43, 44, 45, 46, 47, 48},
      {31, 32, 33, 34, 35, 36, 37, 38},
      {21, 22, 23, 24, 25, 26, 27, 28},
      {11, 12, 13, 14, 15, 16, 17, 18}
  },


  --[[ values here correspond to the launchpad mk2 led settings found in the programmer's
           reference.
       HOWEVER, the lp pro can do full rgb, so we'll take andvantage of that. this requires
           sending sysex, and lets us use the full 16 brightness levels. we'll use a table of
           values directly indexed by the value passed into the fn
       NOTE! Individual LED brightnesses only range from 0x0-0x3f (i.e. 0-63); 1/4 the
          resolution of what we're used to (i.e. 0x0-0xff or 0-255)
  ]]
  brightness_handler = function(val)
      local less_angry_rainbow = {
          '0x00,0x00,0x00',
          '0x00,0x09,0x19',
          '0x05,0x16,0x2f',
          '0x14,0x18,0x34',
          '0x08,0x07,0x21',
          '0x12,0x07,0x21',
          '0x19,0x04,0x22',
          '0x29,0x0e,0x2b',
          '0x1f,0x00,0x1a',
          '0x30,0x04,0x20',
          '0x34,0x08,0x19',
          '0x3f,0x15,0x1b',
          '0x3f,0x19,0x14',
          '0x3f,0x20,0x0e',
          '0x3c,0x26,0x0b',
          '0x37,0x2d,0x0b'
      }
      return less_angry_rainbow[val + 1]
  end,

  --[[ this is the column of keys on the sides of the grid, not necessary for strict
       grid emulation but handy!
       the lp pro round buttons send midi ccs
  ]]
  -- top to bottom
  -- right side
  auxcol = {89, 79, 69, 59, 49, 39, 29, 19},
  -- here we set the left and right page buttons for two page mode
  -- we can simply use the cc # as-is
  leftpage_button = 89,
  rightpage_button = 79,

  -- table of device-specific capabilities
  caps = {
    -- can we use sysex to update the grid leds?
    sysex = true,
    -- is this an rgb device?
    rgb = true,
    -- do the edge buttons send cc?
    cc_edge_buttons = true
  },


  split_string = function(color)
      local rgb = {}
      -- '([^,]+)' regex for 'group match any number of characters which are not `,`'
      for byte in string.gmatch(color, '([^,]+)') do
          rgb[#rgb + 1] = byte
      end
      return rgb[1], rgb[2], rgb[3]
  end,


  led_sysex = function(self, led, color)
      local set_led_rgb = '0x0b' -- magic number for "set led rgb"
      -- `color` is e.g. 'ff,f2,e6'
      local r, g, b = self.split_string(color)
      return self.do_sysex(set_led_rgb, led, r, g, b)
  end,


  all_led_sysex = function(self, color)
      local set_all_led_rgb = '0x0e' -- magic number for "set ALL leds"
      local r, g, b = self.split_string(color)
      return self.do_sysex(set_all_led_rgb, r, g, b)
  end,


  do_sysex = function(command, ...)
      local var_args = ', '
      for i = 1, select("#", ...) do
          var_args = var_args .. string.format('%s, ', select(i, ...))
      end
      local end_sysex = '0xf7'
      local sysex_str = string.format('0xf0, 0x00, 0x20, 0x29, 0x02, 0x10, %s%s%s',
                                      command, var_args, end_sysex)
      -- print(sysex_str)
      local sysex = tab.split(sysex_str, ', ')
      return sysex
  end,

  -- For unknown reason(s), allows us to use programmer mode
  device_name = 'launchpad mk2'
}

return launchpad
