local launchpad = include(include('midigrid/device/generic_device'))

launchpad.grid_notes= {
  { 0, 1, 2, 3, 4, 5, 6, 7},
  {16,17,18,19,20,21,22,23},
  {32,33,34,35,36,37,38,39},
  {48,49,50,51,52,53,54,55},
  {64,65,66,67,68,69,70,71},
  {80,81,82,83,84,85,86,87},
  {96,97,98,99,100,101,102,103},
  {112,113,114,115,116,117,118,119}
}

launchpad.brightness_map = {0,28,28,60,60,60,62,62,29,29,29,63,63,13,13,15}

launchpad.device_name = 'launchpad'

return launchpad