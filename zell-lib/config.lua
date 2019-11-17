-- constants
local config = {
  GRID = {
    SIZE = {
      X = 16, -- default, will be replaced with g.cols
      Y = 8 -- default, will be replaced with g.rows
    },
    LEVEL = {
      ALIVE = 8,
      BORN = 12,
      REBORN = 13,
      DYING = 2,
      DEAD = 0,
      ALIVE_THRESHOLD = 7,
      ACTIVE = 15
    }
  },
  MUSIC = {
    NOTE_NAMES_OCTAVE = {"C", "C#", "D", "D#", "E", "F", "F#", "G", "G#", "A", "A#", "B"},
    NOTES = {}, -- constructed on init
    NOTE_NAMES = {}, -- constructed on init
    SCALE_NAMES = {}, -- constructed on init
    SCALE_LENGTH = 24
  },
  SEQ = {
    MODES = {
      "manual",
      "semi-automatic",
      "automatic"
    },
    PLAY_DIRECTIONS = {
      "up",
      "down",
      "random",
      "drunken up",
      "drunken down"
    },
    PLAY_MODES = {
      "born",
      "reborn",
      "ghost"
    },
  },
  CROW = {
    SUPPORT_MODES = {
      "x/y",
      "x%y",
      "x+y"
    }
  },
  SYNTHS = {
    "internal",
    "midi",
    "both"
  },
}

return config