# gui_text_viewer.tcl - readonly text viewer window.

# Based on: VW.TCL by Tony Dycks
#
# DESCRIPTION:
#   Tcl/Tk Wish Script For Viewing A Text File Using A TK Window.
#   File Contents Are Displayed On Text Widget Using TK As A GUI.
#   A Scrollbar Widget Is Added To Allow The Viewing Of File Contents.
#   Program Uses A File Menu Options To Select Files For Viewing 
#   And To Exit The Program. Clicking The "Exit Program" Button Closes
#   The TK Window And Ends The Program. Bind To <F3> Function Key
#   To Exit The Program.
#
# REFERENCES: 
#   Personal Derivation Of TCL/TK Code Using The Grid Layout Manager. 
#
# LICENSING: 
#   Released Under The GPL As Open Source. 
#



package require Tk

set SCRIPT_DIR [file dirname [info script]]

package require ok_utils;   namespace import -force ::ok_utils::*


# +---------------------------------------------------+
# + Set Initial Directory To Current Logged Directory +
# +---------------------------------------------------+
set INITIALDIR [pwd]
global INITIALDIR
global FLNAME


# Open the window and load 'filePath' into it
proc textview_open {filePath} {
 wm deiconify .txvWnd
 return  [_loadfl $filePath]
}
################################################################################


# +------------------------------------------------------+
# + Select Open Input Text File & Populate Entry Widgets +
# +------------------------------------------------------+
proc _openfl {} {
  global INITIALDIR
  global FLNAME
  set file_types {
    {"Tcl Files" { .tcl .TCL } }
    {"Text Files" { .txt .TXT } }
    {"All Files"  * }
    }
# +-------------------------------------------------+
# + Cleanup Filename And Text File Contents Widgets +
# +-------------------------------------------------+
  .txvWnd.txtarea delete 1.0 end
  set FLNAME [tk_getOpenFile -initialdir $INITIALDIR     -filetypes $file_types -title "Open Input Text File" -parent .txvWnd]
  if {$FLNAME != ""} {
    return  [_loadfl $FLNAME]
  }
  return  ""
}
  
  
  


# +------------------------------------------------------+
# + Populate Entry Widgets from Text File 'filePath' +
# +------------------------------------------------------+
proc _loadfl {filePath} {
  set retcd [ catch { set infile [open $filePath "r"] } ]
# +------------------------------------------------+
# + Display Error Message Box If File Open Failure +
# +------------------------------------------------+
  if {$retcd == 1} {
    wm title .txvWnd "Text File Open Error"
    set result [tk_messageBox -parent .txvWnd         -title "Text File Open Error" -type ok -icon error         -message         "Error Opening File: $filePath.\n"]
    }
# +----------------------------------------------+
# + Open File Successful Load Text File Contents +
# + Line By Line Until End Of File               +
# +----------------------------------------------+
  if {$retcd == 0} {
    set inEOF -1
    set txln ""
    .txvWnd.txtarea delete 1.0 end
    while {[gets $infile inln] != $inEOF} {
      set txln "$inln\n"
      .txvWnd.txtarea insert end $txln
    }
    close $infile
  }
  .txvWnd.lblFlname configure -text $filePath
  return $filePath
}


# +------------------+
# + Close the window +
# +------------------+
proc textview_close {} {
  wm withdraw .txvWnd
}

# +-------------------------------------------------+
# + Initial TK Widget Definitions For Viewer Window +
# +-------------------------------------------------+
toplevel .txvWnd

wm title .txvWnd "VW.TCL Version 1.01 -- Text File Viewer Tcl/Tk Progam"
# +--------------+
# + Menu Widgets +
# +--------------+
menubutton .txvWnd.fl -text "File" -menu .txvWnd.fl.menu -anchor nw
menu .txvWnd.fl.menu
.txvWnd.fl.menu add command -label "Open" -command _openfl
.txvWnd.fl.menu add separator
.txvWnd.fl.menu add command -label "Exit" -command textview_close
set font {Verdana 14}
# +------------------------+
# + Filename Label Widgets +
# +------------------------+
label .txvWnd.fllabel -text "Input Filename:" -relief sunken -bg NavajoWhite2   -fg Navy -anchor nw
label .txvWnd.lblFlname -width 80 -relief sunken -bg NavajoWhite2   -fg Navy -anchor nw
pack .txvWnd.fl .txvWnd.fllabel .txvWnd.lblFlname -side top -padx 1m -pady 1m -anchor nw
# +----------------------------------------+
# + Text File Contents & Scrollbar Widgets +
# +----------------------------------------+
label .txvWnd.fltext -width 80 -relief sunken -bg White -textvariable fltext
text .txvWnd.txtarea -bg LightYellow2 -font FixedSys -bd 2   -yscrollcommand ".txvWnd.vscroller set"
scrollbar .txvWnd.vscroller -command ".txvWnd.txtarea yview"
pack .txvWnd.txtarea .txvWnd.vscroller -side left -fill y
# +-----------------------------------------------------+
# + Command Button Widgets For Open File & Program Exit +
# +-----------------------------------------------------+
button .txvWnd.openfl -text "<< Open File >>" -fg Navy -bg NavajoWhite2   -font bold -command _openfl
button .txvWnd.close -text "< Close >" -fg Navy -bg NavajoWhite2   -font bold -command textview_close
pack .txvWnd.close .txvWnd.openfl -side bottom -padx 1m -pady 1m 

bind .txvWnd.txtarea <Key-F3> {textview_close}
bind .txvWnd.fllabel <Key-F3> {textview_close}
bind .txvWnd.lblFlname <Key-F3> {textview_close}

wm withdraw .txvWnd

# Handle the "non-standard window termination" by
# invoking the Close button when we receives a
# WM_DELETE_WINDOW message from the window manager.
wm protocol .txvWnd WM_DELETE_WINDOW {
    .txvWnd.close invoke
}
