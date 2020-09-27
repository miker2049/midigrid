local launchpad = include('midigrid/lib/devices/generic_device')

--these are LP keys to the sides of our grid
--not necessary for strict grid emulation but handy!
--they are up to down, so 89 is the auxkey to row 1
launchpad.auxcol = {89,79,69,59,49,39,29,19}

--left to right, 91 is aux key to column 1
launchpad.auxrow = {91,92,93,94,95,96,97,98}
launchpad.quad_leds = {notes = {91,92,93,94}}

launchpad.grid_notes= {
  {81,82,83,84,85,86,87,88},
  {71,72,73,74,75,76,77,78},
  {61,62,63,64,65,66,67,68},
  {51,52,53,54,55,56,57,58},
  {41,42,43,44,45,46,47,48},
  {31,32,33,34,35,36,37,38},
  {21,22,23,24,25,26,27,28},
  {11,12,13,14,15,16,17,18}
}

launchpad.brightness_map = {0,
  11,
  100,
  125,
  83,
  117,
  14,
  62,
  99,
  118,
  126,
  97,
  109,
  13,
  12,
  119
}

launchpad.device_name = 'launchpad_minimk3'

return launchpad
