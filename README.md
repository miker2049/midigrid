
# Table of Contents

1.  [norns cheapskate library](#org0e546c5)
    1.  [instructions](#org42ed9d4)
    2.  [todos](#orgf42c8e5)
        1.  [add cols and rows function](#org83f05cc)
        2.  [make page changing more efficient code wise](#org77afa5e)
        3.  [make some demonstration ports that are little more instructive](#orga40afa7)
        4.  [consider how to make this more sensible with the midi device number thing&#x2026;](#org64505c4)
        5.  [make some demonstrations, make launchpad untz instrument stuff built in](#org31b607f)
    3.  [scripts](#org261617c)
        1.  [step](#orgedb845e)
        2.  [strum](#org9cccd1f)
        3.  [reverse engineering mlr for apc mini](#org8a675de)
        4.  [earthsea for apc mini](#org9841e43)
        5.  [vials for apc mini](#org62ae768)
        6.  [meadowphysics, this is one to look at](#orgc8f0e19)
        7.  [strides](#org83a4422)
        8.  [shfts](#org3e15793)
        9.  [cranes](#orgc623d97)
        10. [ekombi](#orgfd59ba4)
        11. [takt](#orgf0eced5)
        12. [foulplay](#org44f2df4)
        13. [zellen](#org58ec7ff)
        14. [isoseq](#org0602329)


<a id="org0e546c5"></a>

# norns cheapskate library

A few helper scripts for emulating and using midi grids like a monome grid, on the monome norns.
Two scripts in the lib folder, \`apcnome.lua\` and \`apcnome<sub>2pages.lua</sub>\` are the beginning of something more robust, but for now they will allow one to use the akai apc mini as a grid.  Either just straight as 64 grid, or in 2 pages mode which emulates a full 128 grid and you can just switch the two views with the left and right arrow buttons on the apc.  


<a id="org42ed9d4"></a>

## instructions

\`apcnome.lua\` is documented in the script itself, look at the top and change your table grid based off of what you got 

then, all you need to do is change a script wherever it says \`grid.connect\` to \`include(lib/apcnome)\` or \`include(\`lib/apcnome<sub>2pages</sub>\`)

Make sure your apc is the first midi device, and be sure to tell the norns script to only connect to other midi devices otherwise 


<a id="orgf42c8e5"></a>

## todos


<a id="org83f05cc"></a>

### TODO add cols and rows function


<a id="org77afa5e"></a>

### TODO make page changing more efficient code wise


<a id="orga40afa7"></a>

### TODO make some demonstration ports that are little more instructive


<a id="org64505c4"></a>

### TODO consider how to make this more sensible with the midi device number thing&#x2026;


<a id="org31b607f"></a>

### TODO make some demonstrations, make launchpad untz instrument stuff built in


<a id="org261617c"></a>

## scripts

Notes for norns scripts that either work or I wanna make work, or need a little love to make work


<a id="orgedb845e"></a>

### step

works, need to block out midi


<a id="org9cccd1f"></a>

### strum

works but with midi blocking


<a id="org8a675de"></a>

### reverse engineering mlr for apc mini

1.  code notes

    1.  variable initializing
    
    2.  function update<sub>tempo</sub>

2.  ideas

    1.  the nav bar is remapped thusly:
    
        1.  the three modes are haux 1,2,3
        
        2.  the four patterns are haux 4,5,6,7
        
        3.  q is haux 8
        
        4.  alt is shift
    
    2.  rec / speed mode
    
        1.  play is vaux[track]
        
        2.  rec is track[1]
        
        3.  focus track[2] and [3
        
        4.  just get rid of the speed stuff, can use interface for that
    
    3.  simplest:  change nave bar to haux, then remap anything x>8 to the lower row, and spread out the rows
    
        if y == 1 then haux
        if x > 8 then x-8, y+1
        if y = 2, y = 1
        if y = 3, y = 3
        if y = 4, y = 5
        if y = 5, y = 7


<a id="org9841e43"></a>

### earthsea for apc mini

1.  this is pretty much ready to go, use the earthsea from the ash library

    its glitchy and not sure why
    working but glitchy?


<a id="org62ae768"></a>

### vials for apc mini

1.  I think this can be implemented as just split view toggle

    if view2 then {new mapping}

2.  status

    works pretty great two pages


<a id="orgc8f0e19"></a>

### meadowphysics, this is one to look at

1.  basic mode is simple, just subtract by half

2.  Reset, Output, and Speeds

    this just needs a speed interface&#x2026;
    if (config)

3.  if rules then choose with encoder


<a id="org83a4422"></a>

### strides

this one should be easy too, the second half of the grid is just pulled up from an alt key


<a id="org3e15793"></a>

### shfts

a toggle button for the two views


<a id="orgc623d97"></a>

### cranes

this is split in two, but horizontally, so going to need to be a little more sophisticated in the mapping


<a id="orgfd59ba4"></a>

### ekombi

just make it half as precise


<a id="orgf0eced5"></a>

### takt

maybe just a two pager?


<a id="org44f2df4"></a>

### foulplay

only 64 ready to go!


<a id="org58ec7ff"></a>

### zellen

good to go with rows and cols, and adjusting led values


<a id="org0602329"></a>

### isoseq

just the max pattern length needs to change

