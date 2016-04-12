# stereopair_naming.tcl

set SCRIPT_DIR [file dirname [info script]]
source [file join $SCRIPT_DIR  "ok_utils" "debug_utils.tcl"]
ok_trace_msg "---- Sourcing '[info script]' in '$SCRIPT_DIR' ----"
#source [file join $SCRIPT_DIR   "dir_file_utils.tcl"]

package require ok_utils
namespace import -force ::ok_utils::*



proc build_spm_left_purename  {basePurename} {
  return  [format "%s_l" $basePurename] }
  
  
proc build_spm_right_purename  {basePurename} {
  return  [format "%s_r" $basePurename] }


proc spm_purename_to_peer_purename {purename} {
  # OK_TODO: generalize
  TODO:implement
}


proc build_stereopair_purename {purenameLeft purenameRight}  {
  set suffix [build_suffix_from_peer_purename $purenameRight]
  return  "$purenameLeft$suffix"
}


proc build_suffix_from_peer_purename {peerPureName}  {
  if { 0 == [regexp {[0-9].*$} $peerPureName peerNameNum] }  {
    ok_err_msg "Invalid peer image name '$peerPureName'"
    set peerNameNum "INVALID"
  }
  set suffix [format "-%s" $peerNameNum]
  return  $suffix
}