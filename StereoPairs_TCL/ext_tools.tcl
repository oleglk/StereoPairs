# ext_tools.tcl

set SCRIPT_DIR [file dirname [info script]]

package require ok_utils

#source [file join $SCRIPT_DIR   "debug_utils.tcl"]
ok_trace_msg "---- Sourcing '[info script]' in '$SCRIPT_DIR' ----"

## Better call path-reading function explicitly from another function
## read_ext_tool_paths_from_csv [file join $SCRIPT_DIR "ext_tool_dirs.csv"]

# - external program executable paths;
# - don't forget to add if using more;
# - COULDN'T PROCESS SPACES (as in "Program Files");

#~ # - ImageMagick:
#~ set _IM_DIR [file join {C:/} {Program Files (x86)} {ImageMagick-6.8.7-3}] ; # DT
#~ #set _IM_DIR [file join {C:/} {Program Files} {ImageMagick-6.8.6-8}]  ; # Asus
#~ #set _IM_DIR [file join {C:/} {Program Files (x86)} {ImageMagick-6.8.6-8}]; # Yoga

#~ set _IMCONVERT [format "{%s}" [file join $_IM_DIR "convert.exe"]]
#~ set _IMIDENTIFY [format "{%s}" [file join $_IM_DIR "identify.exe"]]
#~ set _IMMONTAGE [format "{%s}" [file join $_IM_DIR "montage.exe"]]
#~ # - DCRAW:
#~ #set _DCRAW "dcraw.exe"
#~ set _DCRAW [format "{%s}" [file join $_IM_DIR "dcraw.exe"]]
#~ # - ExifTool:
#~ set _EXIFTOOL "exiftool.exe" ; #TODO: path


####### Do not change after this line ######

# Reads the system-dependent paths from 'csvPath',
# then assigns ultimate tool paths
proc set_ext_tool_paths_from_csv {csvPath}  {
  if { 0 ==[ok_read_variable_values_from_csv $csvPath "external tool path(s)"]} {
    return  0;  # error already printed
  }
  if { 0 == [info exists ::_IM_DIR] }  {
    ok_err_msg "Imagemagick directory path not assigned to variable _IM_DIR by '$csvPath'"
    return  0
  }
  set ::_IMCONVERT  [format "{%s}"  [file join $::_IM_DIR "convert.exe"]]
  set ::_IMIDENTIFY [format "{%s}"  [file join $::_IM_DIR "identify.exe"]]
  set ::_IMMONTAGE  [format "{%s}"  [file join $::_IM_DIR "montage.exe"]]
  # - DCRAW:
  # unless ::_DCRAW points to some custom execuable, point at the default
  if { 0 == [info exists ::_DCRAW] }  {
    set ::_DCRAW      [format "{%s}"  [file join $::_IM_DIR "dcraw.exe"]]
  } else {
    ok_info_msg "Custom dcraw path specified by '$csvPath'"
    set ::_DCRAW      [format "{%s}"  $::_DCRAW]
  }
  # - ExifTool:
  set ::_EXIFTOOL "exiftool.exe" ; #TODO: path
  return  1
}


# Copy-pasted from Lazyconv "::dcraw::is_dcraw_result_ok"
# Verifies whether dcraw command line ended OK through the test it printed.
# Returns 1 if it was good, 0 otherwise.
proc is_dcraw_result_ok {execResultText} {
    # 'execResultText' tells how dcraw-based command ended
    # - OK if noone of 'errKeys' appears
    set result 1;    # as if it ended OK
    set errKeys [list {Improper} {No such file} {missing} {unable} {unrecognized} {Non-numeric}]
#     puts ">>> Check for error keys '$errKeys' the following string:"
#     puts "--------------------------------------------"
#     puts "'$execResultText'"
#     puts "--------------------------------------------"
    foreach key $errKeys {
	if { [string first "$key" $execResultText] >= 0 } {    set result 0  }
    }
    return  $result
}


proc verify_external_tools {} {
  set errCnt 0
  if { 0 == [file isdirectory $::_IM_DIR] }  {
    ok_err_msg "Inexistent or invalid Imagemagick directory '$::_IM_DIR'"
    incr errCnt 1
  }
  if { 0 == [file exists [string trim $::_IMCONVERT " {}"]] }  {
    ok_err_msg "Inexistent ImageMagick 'convert' tool '$::_IMCONVERT'"
    incr errCnt 1
  }
  if { 0 == [file exists [string trim $::_IMIDENTIFY " {}"]] }  {
    ok_err_msg "Inexistent ImageMagick 'identify' tool '$::_IMIDENTIFY'"
    incr errCnt 1
  }
  if { 0 == [file exists [string trim $::_IMMONTAGE " {}"]] }  {
    ok_err_msg "Inexistent ImageMagick 'montage' tool '$::_IMMONTAGE'"
    incr errCnt 1
  }
  if { 0 == [file exists [string trim $::_DCRAW " {}"]] }  {
    ok_err_msg "Inexistent 'dcraw' tool '$::_DCRAW'"
    incr errCnt 1
  }
  if { $errCnt == 0 }  {
    ok_info_msg "All external tools are present"
    return  1
  } else {
    ok_err_msg "Some or all external tools are missing"
    return  0
  }
}
