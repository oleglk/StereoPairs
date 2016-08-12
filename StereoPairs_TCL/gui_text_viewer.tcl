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
proc textview_open {wndPath filePath {wndTitle ""}} {
 wm deiconify $wndPath
 return  [_loadfl $wndPath $filePath $wndTitle]
}


# +------------------+
# + Close the window +
# +------------------+
proc textview_close {wndPath} {
  wm withdraw $wndPath
}


# +-------------------------------------------------+
# + Initial TK Widget Definitions For Viewer Window +
# +-------------------------------------------------+
proc textview_prebuild {wndPath} {
  toplevel $wndPath

  wm title $wndPath "Text File Viewer"

  set font {Verdana 14}
  # +------------------------+
  # + Filename Label Widgets +
  # +------------------------+
  label $wndPath.fllabel -text "Input Filename:" -relief sunken -bg NavajoWhite2   -fg Navy -anchor nw
  label $wndPath.lblFlname -width 80 -relief sunken -bg NavajoWhite2   -fg Navy -anchor nw

  # +----------------------------------------+
  # + Text File Contents & Scrollbar Widgets +
  # +----------------------------------------+
  label $wndPath.fltext -width 80 -relief sunken -bg White -textvariable fltext
  text $wndPath.txtarea -bg LightYellow2 -font FixedSys -bd 2   -yscrollcommand "$wndPath.vscroller set"
  scrollbar $wndPath.vscroller -command "$wndPath.txtarea yview"
  pack $wndPath.txtarea $wndPath.vscroller -side left -fill y
  
  # +-----------------------------------------------------+
  # + Command Button Widget For Program Exit +
  # +-----------------------------------------------------+
  button $wndPath.close -text "< Close >" -fg Navy -bg NavajoWhite2   -font bold -command [list textview_close $wndPath]
  pack $wndPath.close -side bottom -padx 1m -pady 1m 

  bind $wndPath.txtarea <Key-F3> {textview_close}
  bind $wndPath.fllabel <Key-F3> {textview_close}
  bind $wndPath.lblFlname <Key-F3> {textview_close}

  wm withdraw $wndPath

  # Handle the "non-standard window termination" by
  # invoking the Close button when we receives a
  # WM_DELETE_WINDOW message from the window manager.
  wm protocol $wndPath WM_DELETE_WINDOW {
    set wndPath [focus]
    $wndPath.close invoke
  }
}
################################################################################


# +------------------------------------------------------+
# + Select Open Input Text File & Populate Entry Widgets +
# +------------------------------------------------------+
proc _openfl {wndPath} {
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
  $wndPath.txtarea delete 1.0 end
  set FLNAME [tk_getOpenFile -initialdir $INITIALDIR     -filetypes $file_types -title "Open Input Text File" -parent $wndPath]
  if {$FLNAME != ""} {
    return  [_loadfl $wndPath $FLNAME ""]
  }
  return  ""
}
  
  
  


# +------------------------------------------------------+
# + Populate Entry Widgets from Text File 'filePath' +
# +------------------------------------------------------+
proc _loadfl {wndPath filePath {wndTitle ""}} {
  set retcd [ catch { set infile [open $filePath "r"] } ]
# +------------------------------------------------+
# + Display Error Message Box If File Open Failure +
# +------------------------------------------------+
  if {$retcd == 1} {
    wm title $wndPath $"Text File Open Error"
    set result [tk_messageBox -parent $wndPath         -title "Text File Open Error" -type ok -icon error         -message         "Error Opening File: $filePath.\n"]
    }
# +----------------------------------------------+
# + Open File Successful Load Text File Contents +
# + Line By Line Until End Of File               +
# +----------------------------------------------+
  if {$retcd == 0} {
    set inEOF -1
    set txln ""
    $wndPath.txtarea delete 1.0 end
    while {[gets $infile inln] != $inEOF} {
      set txln "$inln\n"
      $wndPath.txtarea insert end $txln
    }
    close $infile
  }
  $wndPath.lblFlname configure -text $filePath
  if { $wndTitle != "" }  {
    wm title $wndPath $wndTitle ; # override the window title
  }

  return $filePath
}

