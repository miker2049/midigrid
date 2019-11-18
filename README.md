
# norns midigrid library

A few helper scripts for emulating and using midi grids like a monome grid, on the monome norns.

Two scripts in the lib folder to include in scripts as 'grid', config files in the config folder for setups with different devices.


<a id="org21e0a7d"></a>

## instructions

`midigrid.lua` and `apcmini_config.lua` is documented in the scripts themselves, setting up a new config file also means it needs to be loaded into the script itself:

    -----------------------------
    --loading up config file here
    -----------------------------
    local config = include('midigrid/config/apcmini_config')
    -- local config = include('midigrid/config/launchpad_config')
    -- local config = include('midigrid/config/untz_config')
    -----------------------------

Then, in whatever script you are working in, it works well to override the global grid object with our own local one:

    --adding this to script
    local grid = include('cheapskate/lib/midigrid')
    --or this
    local grid = include('cheapskate/lib/midigrid_2pages')
    --which allows this call to work with our midi grid
    local g = grid.connect()

Previous issues with the midi device being blocked are resolved with this new implementation taken from ryanlaws [lunchpaid](https://github.com/ryanlaws/lunchpaid).


<a id="orgbb1c9c6"></a>

## todos


<a id="org0f0b0ee"></a>

### TODO add config files for launchpad (and untz maybe)


<a id="org8ee85f7"></a>

### TODO allow config files to overide led and all functions, for more native launchpad support


<a id="org7925797"></a>

### DONE add cols and rows function


<a id="org8f6e950"></a>

### DONE make page changing more efficient code wise


<a id="org8107a1f"></a>

### DONE consider how to make this more sensible with the midi device number thing&#x2026;


<a id="orgfecddde"></a>

## scripts

Notes for norns scripts that either work or I wanna make work, or need a little love to make work


<a id="orge11eba7"></a>

### step

works, need to block out midi


<a id="org5f17dbf"></a>

### strum

works but with midi blocking


<a id="orge6d5076"></a>

### mlr64

[mlr64](https://github.com/noiserock/custom64)
works!


<a id="org34e4323"></a>

### earthsea for apc mini

1.  this is pretty much ready to go, use the earthsea from the ash library

    its glitchy and not sure why
    working but glitchy?


<a id="orgca53366"></a>

### vials for apc mini

1.  I think this can be implemented as just split view toggle

    if view2 then {new mapping}

2.  status

    works pretty great two pages


<a id="org91703a4"></a>

### meadowphysics, this is one to look at

1.  basic mode is simple, just subtract by half

2.  Reset, Output, and Speeds

    this just needs a speed interface&#x2026;
    if (config)

3.  if rules then choose with encoder


<a id="org408340f"></a>

### strides

this one should be easy too, the second half of the grid is just pulled up from an alt key


<a id="org60c2a34"></a>

### shfts

a toggle button for the two views


<a id="org1ab0ff3"></a>

### cranes

this is split in two, but horizontally, so going to need to be a little more sophisticated in the mapping


<a id="orgb09f2c2"></a>

### ekombi

just make it half as precise


<a id="orga3741e4"></a>

### takt

maybe just a two pager?


<a id="org10026ce"></a>

### foulplay

only 64 ready to go!


<a id="org6488fdb"></a>

### zellen

good to go with rows and cols, and adjusting led values


<a id="orgba2b404"></a>

### isoseq

just the max pattern length needs to change

