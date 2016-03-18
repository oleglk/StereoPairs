# unused_raws.tcl

set SCRIPT_DIR [file dirname [info script]]
source [file join $SCRIPT_DIR   "ok_utils" "debug_utils.tcl"]
ok_trace_msg "---- Sourcing '[info script]' in '$SCRIPT_DIR' ----"
#source [file join $SCRIPT_DIR   "ext_tools.tcl"]

package require ok_utils
namespace import -force ::ok_utils::*

# ------------------------------------------------------------------------------

set _STEREOPAIR_PURENAME_PATTERN   {[a-zA-Z]*[-_]*([0-9]+)-([0-9]+)[-_0-9]*}
set _STEREOPAIR_PURENAME_GLOB      {*}
#set _STEREOPAIR_EXTENSIONS_PATTERN {(tif|TIF|jpg|JPG|bmp|BMP)}
#set _STEREOPAIR_EXTENSIONS_LIST {tif TIF jpg JPG bmp BMP};  # for Unix
set _STEREOPAIR_EXTENSIONS_LIST {TIF JPG BMP};  # for Windows

set _IMAGE_FILE_ID_PATTERN         {[0-9]+} ;  # example: "dsc(01234).jpg"

proc list_stereopairs_in_dir {dirPath} {
  set spFiles [list]
  foreach ext $::_STEREOPAIR_EXTENSIONS_LIST {
    set spPattern "$::_STEREOPAIR_PURENAME_GLOB.$ext"
    set extFiles [glob -nocomplain -directory $dirPath $spPattern]
    if { 0 < [llength $extFiles] }  { set spFiles [concat $spFiles $extFiles] }
    ok_info_msg "Found [llength $extFiles] file(s) with extension '$ext' in '$dirPath'"
  }
  # TODO: filter by '_STEREOPAIR_PURENAME_PATTERN'
  # find indices at which irrelevant files reside, then delete the elements
  set dropIdxList [list]
  for {set i [expr [llength $spFiles]-1]} {$i >= 0} {incr i -1}  {
    set pureName [file rootname [file tail [lindex $spFiles $i]]]
    ok_trace_msg "Match '$pureName' by '$::_STEREOPAIR_PURENAME_PATTERN'"
    if { 0 == [regexp -nocase -- $::_STEREOPAIR_PURENAME_PATTERN $pureName] }  {
      ok_trace_msg "Drop filename '$pureName' at \[$i\]"
      lappend dropIdxList $i
    }
  }
  foreach i $dropIdxList  {
    set spFiles [lreplace $spFiles $i $i]
  }
  if { 0 == [llength $spFiles] }  {
    ok_err_msg "No stereopair images to match '$::_STEREOPAIR_PURENAME_GLOB' in '$dirPath'"
    return  0
  }
  ok_info_msg "Found [llength $spFiles] stereopair file(s) in '$dirPath'"
  return  $spFiles
}


# Returns list of image-file IDs found in image file names in 'dirPath' directory
# "dsc003-007.tif" => {003 007}
proc find_lr_image_ids_in_dir {dirPath}  {
  set spNames [list_stereopairs_in_dir $dirPath]
  if { 0 == [llength $spNames] }  {
    ok_err_msg "No left-right image ID(s) in '$dirPath'"
    return  0
  }
  set lrNames [_find_lr_image_ids_in_pair_namelist $spNames]
  ok_info_msg "Found [llength $lrNames] left-right image ID(s) in '$dirPath'"
  return  $lrNames
}


# Returns list of image-file IDs found in 'pairNamesOrPaths'.
# "dsc003-007.tif" => {003 007}
proc _find_lr_image_ids_in_pair_namelist {pairNamesOrPaths}  {
  set lrNames [list]
  foreach pairPath $pairNamesOrPaths {
    set pureNameNoExt [file rootname [file tail $pairPath]]
    set spPattern "($::_IMAGE_FILE_ID_PATTERN)-($::_IMAGE_FILE_ID_PATTERN)"
    ok_trace_msg "Match '$pureNameNoExt' by '$spPattern'"
    if { 1 == [regexp -nocase -- $spPattern $pureNameNoExt full name1 name2] }  {
      lappend lrNames $name1;  lappend lrNames $name2
    }
  }
  return  $lrNames
}
