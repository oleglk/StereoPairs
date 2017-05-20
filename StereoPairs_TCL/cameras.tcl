# cameras.tcl

array unset g_camPresets
set g_camPresets(Sunny)        [list 2740.000000 1024.000000 1640.000000]
set g_camPresets(Shady)        [list 3228.000000 1024.000000 1356.000000]
set g_camPresets(Cloudy)       [list 2948.000000 1024.000000 1508.000000]
set g_camPresets(Tungsten)     [list 1668.000000 1024.000000 2888.000000]
set g_camPresets(Fluorescent)  [list 2404.000000 1024.000000 2280.000000]

set RAW_EXTENSION ""
set KNOWN_RAW_EXTENSIONS_DICT [dict create \
  "iiq"   Phase-One   \
  "3fr"   Hasselblad  \
  "dcr"   Kodak       \
  "k25"   Kodak       \
  "kdc"   Kodak       \
  "cr2"   Canon       \
  "crw"   Canon       \
  "dng"   Adobe       \
  "erf"   Epson       \
  "mef"   Mamiya      \
  "mos"   Leaf        \
  "mrw"   Minolta     \
  "nef"   Nikon       \
  "orf"   Olympus     \
  "pef"   Pentax      \
  "rw2"   Panasonic   \
  "arw"   Sony        \
  "srf"   Sony        \
  "sr2"   Sony        \
                      ]

# Identificator of Dualcam cameras' arrangement
set ::DUALCAM_DESIGN_HORIZ  1
set ::DUALCAM_DESIGN_VERT   2
set ::DUALCAM_DESIGN_ANGLE  3


# Tells rotation angles for left/right images depending on the rig arrangement
proc get_lr_postproc_rotation_angles {arrangeID angleL angleR} {
  upvar $angleL anL
  upvar $angleR anR
  set angles [dict create]
  dict set angles $::DUALCAM_DESIGN_HORIZ {0    0}
  dict set angles $::DUALCAM_DESIGN_VERT  {270  90}
  dict set angles $::DUALCAM_DESIGN_ANGLE {270  0}
  if { [dict exists $angles $arrangeID] }  {
    set anLR [dict get $angles $arrangeID]
    set anL [lindex $anLR 0];   set anR [lindex $anLR 1]
    return  1
  }
  return  0;  # error
}

