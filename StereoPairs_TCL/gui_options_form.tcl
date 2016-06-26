# gui_options_form.tcl  - a generic entry form for several options

package require Tk

set SCRIPT_DIR [file dirname [info script]]

set WND_TITLE "DualCam Companion - options"

set SHOW_TRACE $LOUD_MODE; # a proxy to prevent changing LOUD_MODE without "Save"

################################################################################
### Here (on top-level) the preferences-GUI is created but not yet shown.
### The code originated from: http://www.tek-tips.com/viewthread.cfm?qid=112205
################################################################################

toplevel .optsWnd

set pw [ttk::panedwindow .optsWnd.pw -orient vertical]
grid $pw -column 0 -row 0 -sticky nwes

set f1 [frame $pw.f1]
set f2 [frame $pw.f2 

$pw add $f1
$pw add $f2

$pw paneconfigure $f1 -minsize 100
$pw paneconfigure $f2 -minsize 50

pack $pw -expand 1 -fill both

# TODO:

################################################################################
# 'keyToDescrAndFormat' is a dictionary of <key>::[list <descr> <scan-format>].
# example: {-left_img_subdir {"Subdirectory for left images" "%s"} -time_diff {"time difference in sec between R and L" "%d"}}
# Returns the dictionary of <key>::<value>
proc GUI_options_form {keyToDescrAndFormat}  {
}
