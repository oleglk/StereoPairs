# fake_fileset.bat

set SCRIPT_DIR [file dirname [info script]]
source [file join $SCRIPT_DIR  "ok_utils" "debug_utils.tcl"]
ok_trace_msg "---- Sourcing '[info script]' in '$SCRIPT_DIR' ----"
source [file join $SCRIPT_DIR   "ext_tools.tcl"]

package require ok_utils
namespace import -force ::ok_utils::*

# Sample cmd:
#   convert -background lightblue -fill blue -font Candice -pointsize 72 label:Anthony label.gif

set _FILE_PREF "DSC"
set _FILE_EXT  "TIF"
set _NAMENUM_LENGTH 5

proc generate_fileset_in_dir {dirPath start num step}  {
  if { 0 == [file exists $dirPath] }  {
    file mkdir $dirPath
  }
  set nameFormat [format "%s%%0%dd.%s" \
                          $::_FILE_PREF $::_NAMENUM_LENGTH $::_FILE_EXT]
  ok_info_msg "Start generating $num files; name-format: '$nameFormat'"
  for {set i 0} {$i < $num} {incr i 1}  {
    set fileName [format $nameFormat [expr $start + $i*$step]]
    set filePath [file join $dirPath $fileName]
    set cmdList [concat $::_IMCONVERT \
                  -background darkblue -fill white -font Arial -pointsize 72 \
                  label:$fileName $filePath]
    ok_run_silent_os_cmd $cmdList
  }
  ok_info_msg "Done generating $num files"
}
