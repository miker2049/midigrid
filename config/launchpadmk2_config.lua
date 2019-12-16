local launchpad={
  --here we have the 'grid' this looks literally like the grid notes as they are mapped on the apc, they can be changed for other devices
  --note though, that a call to this table will look backwards, i.e, to get the visual x=1 and y=2, you have to enter midigrid[2][1], not the other way around!
  grid= {
    {81,82,83,84,85,86,87,88},
    {71,72,73,74,75,76,77,78},
    {61,62,63,64,65,66,67,68},
    {51,52,53,54,55,56,57,58},
    {41,42,43,44,45,46,47,48},
    {31,32,33,34,35,36,37,38},
    {21,22,23,24,25,26,27,28},
    {11,12,13,14,15,16,17,18}
  },
  --here, the function expects a brightness_handler val and spits out another val so your midi controller can understand, these values are generally great for apc with most scripts, but will also need to be adjusted for other controllers!
  --corresponds here to the launchpad led settings found in the manual
  brightness_handler = function (val)
    if val == 0 then
      return 0
    elseif (val > 0) and (val < 3) then --0-2
      --low green
      return 28
    elseif (val > 2) and (val < 6) then --3-5
      --full green
      return 60
    elseif (val > 5) and (val < 8) then --6--7
      --full yellow
      return 62
    elseif (val > 7) and (val < 11) then--8-10
      --low amber
      return 29
    elseif (val > 10) and (val < 13) then--11-12
      --full amber
      return 63
    elseif (val > 12) and (val < 15) then--13-14
      --low red
      return 13
    elseif (val > 14) and (val < 17) then--15-16
      --full red
      return 15
    else
      return 0
    end
  end,

  --these are the keys in the apc to the sides of our apc, not necessary for strict grid emulation but handy!
  --they are up to down, so 8 is the auxkey to row 1
  auxcol = {89,79,69,59,49,39,29,19},
  --need to impletement launchpad row, they are 176 messages instead, which messes stuff up right now
  auxrow = {},

  -- here is setting the left and right page buttons for two page mode
  leftpage_button=89,
  rightpage_button=79,

  device_name='launchpad mk2'
}

return launchpad
