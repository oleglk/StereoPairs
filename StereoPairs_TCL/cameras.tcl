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

### Rotation angles derived from cameras' arrangement in DualCam-Companion preferences file
set g_cropPreferences [dict create]; # per-arrangement cropping parameters
dict set g_cropPreferences Horizontal  xyRat [expr 4.0 / 3]
dict set g_cropPreferences Horizontal  pdX   10
dict set g_cropPreferences Horizontal  pdY   0
dict set g_cropPreferences Vertical    xyRat 1.0
dict set g_cropPreferences Vertical    pdX   0
dict set g_cropPreferences Vertical    pdY   30
dict set g_cropPreferences Angled      xyRat 1.0
dict set g_cropPreferences Angled      pdX   10
dict set g_cropPreferences Angled      pdY   10

################################################################################

# Tells rotation angles for left/right images depending on the rig arrangement
# lrOrientSpec tells  L-R cameras' orientations:
#                                       b(ottom)/d(own)|u(p)|l(eft)|r(ight)
proc get_lr_postproc_rotation_angles {lrOrientSpec angleL angleR} {
  upvar $angleL anL
  upvar $angleR anR
  set angles [dict create]
  dict set angles "bd" 0  ;   # bottom-down
  dict set angles "br" 270;   # bottom-right
  dict set angles "bl" 90 ;   # bottom-left
  dict set angles "bu" 180;   # bottom-up
  if { 0 == [regexp -nocase {(b[drlu])-(b[drlu])} \
                              [string tolower $lrOrientSpec] full osL osR] } {
    return  0;  # error
  }
  if { [dict exists $angles $osL] }  {
    set anL [dict get $angles $osL] } else {  return  0 }
  if { [dict exists $angles $osR] }  {
    set anR [dict get $angles $osR] } else {  return  0 }
  set angleL $anL;  set angleR $anR
  return  1;  # success
}


# Retrieves rotation and cropping parameters for known DualCam arrangement
# 'lrArrangement' = Horizontal|Vertical|Angled
proc get_crop_params_for_cam_arrangement {lrArrangement xyRatio padX padY} {
  upvar $xyRatio xyRat
  upvar $padX pdX
  upvar $padY pdY
  global g_cropPreferences
  if { 0 == [dict exists $g_cropPreferences $lrArrangement] }  {
    ok_err_msg "Invalid DualCam arrangement '$lrArrangement'; should be one of {[dict keys $g_cropPreferences]}"
    return  0
  }
  set xyRat [dict get $g_cropPreferences $lrArrangement   xyRat ]
  set pdX   [dict get $g_cropPreferences $lrArrangement   pdX   ]
  set pdY   [dict get $g_cropPreferences $lrArrangement   pdY   ]
  return  1
}


# Decide on rotation-angles, crop-ratio and pads
# given camera orientation from the preferences
# lrOrientSpec tells  L-R cameras' orientations:
#                                       b(ottom)/d(own)|u(p)|l(eft)|r(ight)
# Returns 1 on success, 0 on error.
proc choose_rot_angle_crop_ratio_and_pads {lrOrientSpec \
                                           angleL angleR xyRat pdX pdY}  {
  upvar $angleL angL;   upvar $angleR angR
  upvar $xyRat _xyRat
  upvar $pdX   _pdX;    upvar $pdY   _pdY
  if { 0 == [get_lr_postproc_rotation_angles $lrOrientSpec angL angR] } {
    ok_err_msg "Invalid left- and right cameras' orientation spec '$lrOrientSpec'"
    return  0
  } else {
    ok_info_msg "DualCam orientation: $lrOrientSpec; rotation needed: left->$angL, right->$angR"
  }
  if       { (($angL ==0)||($angL ==180)) && (($angR ==0)||($angR ==180)) }   {
    ok_info_msg "Requested horizontal DualCam orientation"
    get_crop_params_for_cam_arrangement "Horizontal" _xyRat _pdX _pdY
  } elseif { (($angL ==90)||($angL ==270)) && (($angR ==90)||($angR ==270)) }  {
    ok_info_msg "Requested vertical DualCam orientation"
    get_crop_params_for_cam_arrangement "Vertical" _xyRat _pdX _pdY
  } elseif { ( (($angL ==0)||($angL ==180)) && (($angR ==90)||($angR ==270)) ) \
              || \
             ( (($angR ==0)||($angR ==180)) && (($angL ==90)||($angL ==270)) )} {
    ok_info_msg "Requested angled DualCam orientation"
    get_crop_params_for_cam_arrangement "Angled" _xyRat _pdX _pdY
  } else {
    ok_err_msg "Requested unknown DualCam rotations: L->$angL R->$angR"
    return  0
  }
  return  1
}
