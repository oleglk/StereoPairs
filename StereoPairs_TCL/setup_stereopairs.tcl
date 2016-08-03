# setup_stereopairs.tcl

set SCRIPT_DIR [file dirname [info script]]

##############################################################################
# OK_TCLSRC_ROOT <- root directory for TCL source code
set OK_TCLSRC_ROOT    $SCRIPT_DIR
# OK_TCLSTDEXT_ROOT <- root directory for TCL standard extension libraries
set OK_TCLSTDEXT_ROOT $SCRIPT_DIR/../Libs_TCL
#LZC: # OK_CONV_WORK_DIR <- root directory for converter internal use
#LZC: set OK_CONV_WORK_DIR  "e:/LazyConv/TCL/Work"
##############################################################################


### DO NOT CHANGE ANYTHING UNDER THIS LINE !!!
##############################################################################
set normTclSrcRoot    [file normalize $OK_TCLSRC_ROOT]
set normTclStdExtRoot [file normalize $OK_TCLSTDEXT_ROOT]
#LZC: set normConvWorkDir   [file normalize $OK_CONV_WORK_DIR]
##############################################################################

##############################################################################
source [file join $normTclSrcRoot setup_utils.tcl]
##############################################################################
#LZC: set dirList [list $normTclSrcRoot $normTclStdExtRoot $normConvWorkDir]
set dirList [list $normTclSrcRoot $normTclStdExtRoot]
setup::check_dirs_in_list $dirList
##############################################################################
setup::define_src_path $normTclSrcRoot $normTclStdExtRoot
##############################################################################

# don't: package require tool_wrap_main
#LZC: package require cnv_config
#LZC: package require tool_wrap_utils
#LZC: package require camera_data
#LZC: package require filesorter
#LZC: package require imageproc
package require ok_utils
package require img_proc

namespace forget ::ok_utils ::filesorter ::imageproc ::setup
namespace import -force ::ok_utils::*
#LZC: namespace import -force ::filesorter::*
#LZC: namespace import -force ::imageproc::*
namespace import -force ::setup::*

# here only top-level files are sourced; these will drag their dependencies
#~ source [file join $SCRIPT_DIR   "rename_stereo_pairs.tcl"]
#~ source [file join $SCRIPT_DIR   "fake_fileset.tcl"]
#~ source [file join $SCRIPT_DIR   "make_stereocards.tcl"]
#~ source [file join $SCRIPT_DIR   "unused_inputs.tcl"]
source [file join $SCRIPT_DIR   "main_pair_matcher.tcl"]
source [file join $SCRIPT_DIR   "main_settings_copier.tcl"]
source [file join $SCRIPT_DIR   "main_color_analyzer.tcl"]
source [file join $SCRIPT_DIR   "main_workarea_cleaner.tcl"]
source [file join $SCRIPT_DIR   "dir_file_mgr.tcl"]
source [file join $SCRIPT_DIR   "preferences_mgr.tcl"]

## In oder to enable loading several main-s, avoid duplicating settings-init
array unset STS ;   # array for global settings ;  unset once per a project


preferences_set_initial_values  ; # initializing the settings is mandatory
# load default settings if possible
if { 0 == [preferences_read_and_apply] }  {
  ok_warn_msg "Preferences were not loaded; will use hardcoded values"
} else {
  # perform initializations dependent on the saved preferences
  # 'dualcam_cd_to_workdir_or_complain' inits diagnostics log too
  if { 0 == [preferences_get_val -INITIAL_WORK_DIR workAreaDir]} {
    ok_err_msg "Fatal: missing preference for INITIAL_WORK_DIR";  return
  }
  set msg [dualcam_cd_to_workdir_or_complain $workAreaDir 0]
  if { $msg != "" }  {
    ok_warn_msg "$msg";   # initial work-dir not required to be valid
  } else {
    ok_info_msg "Preferences successfully loaded" ;    # into the correct log
  }
}
