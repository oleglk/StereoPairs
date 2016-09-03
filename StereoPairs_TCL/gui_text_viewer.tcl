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

set DEFAULT_LINEWIDTH 80


# Open the window and load 'filePath' into it
proc textview_open {wndPath filePath lineWidth {wndTitle ""}} {
  if { 0 == ([wm state $wndPath] eq "normal") } {
    wm deiconify $wndPath
    set rc [_loadfl $wndPath $filePath $lineWidth $wndTitle]
    _make_text_readonly [_MainTextArea $wndPath]
  } else { set rc 1 } ;   # OK - already open
  return $rc
}


# +------------------+
# + Close the window +
# +------------------+
proc textview_close {wndPath} {
  if { 0 == ([wm state $wndPath] eq "withdrawn") } {
    wm withdraw $wndPath
    _make_text_writable [_MainTextArea $wndPath]
  }
}


# +-------------------------------------------------+
# + Initial TK Widget Definitions For Viewer Window +
# +-------------------------------------------------+
proc textview_prebuild {wndPath} {
  global DEFAULT_LINEWIDTH
  toplevel $wndPath

  wm title $wndPath "Text File Viewer"

  set font {Verdana 14}
  
  # +-----------------------------------------------------+
  # + Command Button Widget For Program Exit +
  # +-----------------------------------------------------+
  button $wndPath.close -text "< Close >" -fg Navy -bg NavajoWhite2   -font bold -command [list textview_close $wndPath]
  pack $wndPath.close -side bottom -padx 1m -pady 1m 

  # +----------------------------------------+
  # + Text File Contents & Scrollbar Widgets +
  # +----------------------------------------+
  frame $wndPath.scrolledText -bg NavyBlue
  pack $wndPath.scrolledText -side bottom -padx 1m -pady 1m -anchor center -fill both -expand true
  set mainTextArea [_MainTextArea $wndPath]
  text $mainTextArea -width $DEFAULT_LINEWIDTH -wrap word -font FixedSys -bd 2   -yscrollcommand "$wndPath.scrolledText.vscroller set"
  scrollbar $wndPath.scrolledText.vscroller -command "$mainTextArea yview"
  pack $wndPath.scrolledText.vscroller -side right -anchor w -fill y  -expand false
  pack $mainTextArea -side right -fill both -expand true

  # +------------------------+
  # + Filename Label Widgets +
  # +------------------------+
  label $wndPath.fllabel -text "Filename:" -relief sunken -bg NavajoWhite2   -fg Navy -anchor nw
  label $wndPath.lblFlname -width 80 -relief sunken -bg NavajoWhite2   -fg Navy -anchor nw
  pack $wndPath.lblFlname -side bottom -padx 1m -pady 1m -anchor nw -fill x -expand false
  pack $wndPath.fllabel   -side bottom -padx 1m -pady 1m -anchor nw -expand false

  bind $mainTextArea <Key-F3> {textview_close}
  bind $wndPath.fllabel <Key-F3> {textview_close}
  bind $wndPath.lblFlname <Key-F3> {textview_close}

  wm withdraw $wndPath

  # Handle the "non-standard window termination" by
  # invoking the Close button when we receives a
  # WM_DELETE_WINDOW message from the window manager.
  wm protocol $wndPath WM_DELETE_WINDOW {
    set wndPath [winfo toplevel [focus]]
    $wndPath.close invoke
  }
}


# winfo toplevel tells the toplevel of the given widget, but menus are toplevels too
proc _UNUSED__is_toplevel {w} {
  return  [expr {[winfo toplevel $w] eq $w && ![catch {$w cget -menu}]}]
}
################################################################################


# Access shortcut for the main text area inside a given window
proc _MainTextArea {wndPath} {  return $wndPath.scrolledText.txtarea }

# +------------------------------------------------------+
# + Select Open Input Text File & Populate Entry Widgets +
# +------------------------------------------------------+
proc _openfl {wndPath} {
  global INITIALDIR DEFAULT_LINEWIDTH
  global FLNAME
  set file_types {
    {"Tcl Files" { .tcl .TCL } }
    {"Text Files" { .txt .TXT } }
    {"All Files"  * }
    }
# +-------------------------------------------------+
# + Cleanup Filename And Text File Contents Widgets +
# +-------------------------------------------------+
  [_MainTextArea $wndPath] delete 1.0 end
  set FLNAME [tk_getOpenFile -initialdir $INITIALDIR     -filetypes $file_types -title "Open Input Text File" -parent $wndPath]
  if {$FLNAME != ""} {
    return  [_loadfl $wndPath $FLNAME $DEFAULT_LINEWIDTH ""]
  }
  return  ""
}
  
  
  


# +------------------------------------------------------+
# + Populate Entry Widgets from Text File 'filePath' +
# +------------------------------------------------------+
proc _loadfl {wndPath filePath lineWidth {wndTitle ""}} {
  set retcd [ catch { set infile [open $filePath "r"] } ]
# +------------------------------------------------+
# + Display Error Message Box If File Open Failure +
# +------------------------------------------------+
  if {$retcd == 1} {
    wm title $wndPath "Text File Open Error"
    set result [tk_messageBox -parent $wndPath         -title "Text File Open Error" -type ok -icon error         -message         "Error Opening File: $filePath.\n"]
    }
# +----------------------------------------------+
# + Open File Successful Load Text File Contents +
# + Line By Line Until End Of File               +
# +----------------------------------------------+
  if {$retcd == 0} {
    set inEOF -1
    set txln ""
    set mainTextArea [_MainTextArea $wndPath]
    # (didn't work)  _make_text_writable $mainTextArea
    $mainTextArea configure -width $lineWidth
    $mainTextArea delete 1.0 end
    while {[gets $infile inln] != $inEOF} {
      set txln "$inln\n"
      $mainTextArea insert end $txln   }
    close $infile
  }
  $wndPath.lblFlname configure -text $filePath
  if { $wndTitle != "" }  {
    wm title $wndPath $wndTitle ; # override the window title
  }
  return $filePath
}


proc _make_text_readonly {textwidget} {
  rename ::$textwidget ::$textwidget.internal
  proc ::$textwidget {args} [string map [list WIDGET ::$textwidget] {
      switch [lindex $args 0] {
          "insert" {}
          "delete" {}
          "default" { return [eval WIDGET.internal $args] }
      }
  }]
}


# This didn't work; consequent _make_text_readonly fails since *.internal exists
proc _make_text_writable {textwidget} {
  rename $textwidget {} ;                   # delete the wrapper command
  rename $textwidget.internal $textwidget ; # restore the original command name
}
