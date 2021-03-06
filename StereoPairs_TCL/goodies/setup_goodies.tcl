# setup_goodies.tcl

set SCRIPT_DIR [file dirname [info script]]

##############################################################################
# OK_TCLSRC_ROOT <- root directory for TCL source code
set OK_TCLSRC_ROOT    [file join $SCRIPT_DIR ".."]; # "goodies" are in subdir
# OK_TCLSTDEXT_ROOT <- root directory for TCL standard extension libraries
set OK_TCLSTDEXT_ROOT [file join $SCRIPT_DIR ".." "Libs_TCL"]
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
## set dirList [list $normTclSrcRoot $normTclStdExtRoot]
set dirList [list $normTclSrcRoot];  # Stereopairs code doesn't use std lib-s
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
#package require img_proc

#namespace forget ::ok_utils ::filesorter ::imageproc ::setup
namespace forget ::ok_utils
namespace import -force ::ok_utils::*
namespace import -force ::setup::*

# here only top-level files are sourced; these will drag their dependencies

## In oder to enable loading several main-s, avoid duplicating settings-init
array unset STS ;   # array for global settings ;  unset once per a project
