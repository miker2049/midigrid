local launchpad = include('midigrid/lib/devices/generic_device')

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
