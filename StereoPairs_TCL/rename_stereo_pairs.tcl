# rename_stereo_pairs.tcl

set SCRIPT_DIR [file dirname [info script]]
source [file join $SCRIPT_DIR   "ok_utils" "debug_utils.tcl"]
ok_trace_msg "---- Sourcing '[info script]' in '$SCRIPT_DIR' ----"
#source [file join $SCRIPT_DIR   "ext_tools.tcl"]

package require ok_utils
namespace import -force ::ok_utils::*

# ------------------------------------------------------------------------------
# ------------------------------------------------------------------------------


proc rename_pairs_in_current_dir {step}  {
  set lrDir [file join [pwd] ".."]
  set lrPattern [file join $lrDir "*.tif"]
  if { {} == [set lrFiles [glob -nocomplain $lrPattern]] }  {
    ok_err_msg "No left-right images to match '$lrPattern'"
    return  0
  }
  set lrFiles [lsort -dictionary -increasing $lrFiles]
  set sbsPattern  [file join [pwd] "*.tif"]
  if { 0 == [set sbsFiles [glob -nocomplain $sbsPattern]] }  {
    ok_err_msg "No side-by-side images to match '$sbsPattern'"
    return  0
  }
  set sbsFiles [lsort -dictionary -increasing $sbsFiles]
  foreach sbsOrigName $sbsFiles {
    if { "" == [set peerPath [_find_peer_image $sbsOrigName $lrFiles \
                                              $step]] }  {
      ok_warn_msg "No peer found for '$sbsOrigName' out of [llength $lrFiles] candidates"
      set suffix "-NONE"
    } else {
      ok_info_msg "Peer for '$sbsOrigName' is '$peerPath'"
      set suffix [_build_suffix_from_peer_path $peerPath]
    }
    set newSBSPath [ok_insert_suffix_into_filename $sbsOrigName $suffix]
    ok_info_msg "Will rename '$sbsOrigName' into '$newSBSPath'"
    file rename -force $sbsOrigName $newSBSPath
  }
  ok_info_msg "Renamed [llength $sbsFiles] image(s) under '[pwd]'"
  return  1
}


proc _find_peer_image {sbsOrigPath lrFiles nameStep}  {
  set pureNameNoExt [file rootname [file tail $sbsOrigPath]]
  ok_trace_msg "sbsOrigPath='$sbsOrigPath' ($pureNameNoExt), lrFiles={$lrFiles}, nameStep=$nameStep"
  set origNameIdx [lsearch $lrFiles "*$pureNameNoExt*"]; #*<purename>* = glob pattern
  if { $origNameIdx < 0 }  {
    return  ""
  }
  set peerIdx [expr $origNameIdx + $nameStep]
  if { $peerIdx < [llength $lrFiles] }  {
    set peerPath [lindex $lrFiles $peerIdx]
  } else {
    set peerPath "" ;   # presumbaly no peer
  }
  return  $peerPath
}


proc _build_suffix_from_peer_path {peerPath}  {
  set peerPureName [file rootname [file tail $peerPath]]
  return  [build_suffix_from_peer_purename $peerPureName]
}


proc build_suffix_from_peer_purename {peerPureName}  {
  if { 0 == [regexp {[0-9].*$} $peerPureName peerNameNum] }  {
    ok_err_msg "Invalid peer image name '$peerPureName'"
    set peerNameNum "INVALID"
  }
  set suffix [format "-%s" $peerNameNum]
  return  $suffix
}
