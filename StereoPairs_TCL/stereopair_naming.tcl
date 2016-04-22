# stereopair_naming.tcl

set SCRIPT_DIR [file dirname [info script]]
source [file join $SCRIPT_DIR  "ok_utils" "debug_utils.tcl"]
ok_trace_msg "---- Sourcing '[info script]' in '$SCRIPT_DIR' ----"
#source [file join $SCRIPT_DIR   "dir_file_utils.tcl"]

package require ok_utils
namespace import -force ::ok_utils::*


set imgNameEndingLeft   "_l"
set imgNameEndingRight  "_r"


proc build_spm_left_purename  {basePurename} {
  return  [format "%s%s" $basePurename $::imgNameEndingLeft] }
  
  
proc build_spm_right_purename  {basePurename} {
  return  [format "%s%s" $basePurename $::imgNameEndingRight] }


proc is_spm_purename {purename} {
  # OK_TODO: generalize
  set iLeft   [string last $::imgNameEndingLeft $purename]
  set iRight  [string last $::imgNameEndingRight $purename]
  if { ($iLeft >= 0) && ($iRight < 0) }  {      ; # it's a left  image
    return  1
  } elseif { ($iLeft < 0) && ($iRight >= 0) } { ; # it's a right image
    return  1
  }
  return  0  ; # not a stereopair name
}


proc spm_purename_to_peer_purename {purename} {
  # OK_TODO: generalize
  set iLeft   [string last $::imgNameEndingLeft $purename]
  set iRight  [string last $::imgNameEndingRight $purename]
  if { ($iLeft >= 0) && ($iRight < 0) }  {      ; # it's a left  image
    return  [string replace $purename $iLeft  end $::imgNameEndingRight]
  } elseif { ($iLeft < 0) && ($iRight >= 0) } { ; # it's a right image
    return  [string replace $purename $iRight end $::imgNameEndingLeft]
  }
  return  ""  ; # error
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