# gui_ext_tools.tcl

package require Tk

set SCRIPT_DIR [file dirname [info script]]

package require ok_utils;   namespace import -force ::ok_utils::*

### Sketch of the GUI #####
# |                    |                         |                           | |
# +--------------------------------------------------------------------------+-+
# |BTN chooseIMDir     |              ENT imDir                              | |
# +--------------------------------------------------------------------------+-+
# |BTN chooseEnfuseDir |              ENT enfuseDir                          | |
# +--------------------------------------------------------------------------+-+
# |BTN chooseDcrawPath |              ENT dcrawPath                          | |
# +--------------------------------------------------------------------------+-+
# |                    |BTN  save                |BTN cancel                 | |
# +--------------------------------------------------------------------------+-+
set WND_TITLE "DualCam Companion - external tools"


################################################################################
### Here (on top-level) the preferences-GUI is created but not yet shown.
### The code originated from: http://www.tek-tips.com/viewthread.cfm?qid=112205
################################################################################

toplevel .toolWnd

grid [ttk::frame .toolWnd.f -padding "3 3 12 12"] -column 0 -row 0 -sticky nwes
grid columnconfigure .toolWnd 0 -weight 1;   grid columnconfigure .toolWnd.f 0 -weight 0
grid columnconfigure .toolWnd.f 1 -weight 0
grid columnconfigure .toolWnd.f 2 -weight 0
grid columnconfigure .toolWnd.f 3 -weight 1
grid rowconfigure .toolWnd 0 -weight 0;   grid rowconfigure .toolWnd.f 0 -weight 0
grid rowconfigure .toolWnd.f 1 -weight 0; grid rowconfigure .toolWnd.f 2 -weight 0
grid rowconfigure .toolWnd.f 3 -weight 0; grid rowconfigure .toolWnd.f 4 -weight 0

# tool-path entries aren't disabled to permit clearing optional ones

grid [ttk::button .toolWnd.f.chooseIMDir -text "ImageMagick folder..." -command GUI_ChooseIMDir] -column 1 -row 1 -sticky w
grid [ttk::entry .toolWnd.f.imDir -width 29 -textvariable ::_IM_DIR] -column 2 -row 1 -columnspan 2 -sticky we

grid [ttk::button .toolWnd.f.chooseDcrawPath -text "Dcraw path (optional)..." -command GUI_ChooseDcraw] -column 1 -row 2 -sticky w
grid [ttk::entry .toolWnd.f.dcrawPath -width 29 -textvariable ::_DCRAW_PATH] -column 2 -row 2 -columnspan 2 -sticky we

grid [ttk::button .toolWnd.f.chooseEnfuseDir -text "Enfuse folder (optional)..." -command GUI_ChooseEnfuseDir] -column 1 -row 3 -sticky w
grid [ttk::entry .toolWnd.f.enfuseDir -width 29 -textvariable ::_ENFUSE_DIR] -column 2 -row 3 -columnspan 2 -sticky we

grid [ttk::button .toolWnd.f.save -text "Save" -command {set _TOOLS_CONFIRM_STATUS 1}] -column 2 -row 6
  # _TOOLS_CONFIRM_STATUS is a global variable that will hold the value
  # corresponding to the button clicked.  It will also serve as our signal
  # to our GUI_ToolsShow procedure that the user has finished interacting with the dialog

grid [ttk::button .toolWnd.f.cancel -text "Cancel" -command {set _TOOLS_CONFIRM_STATUS 0}] -column 3 -row 6


foreach w [winfo children .toolWnd.f] {grid configure $w -padx 5 -pady 5}

wm resizable .toolWnd 1 0;   # prohibit changing window height

# Set the window title, then withdraw the window
# from the screen (hide it)

wm title .toolWnd $WND_TITLE
wm withdraw .toolWnd

# Install a binding to handle the dialog getting
# lost.  If the user tries to click a mouse button
# in our main application, it gets redirected to
# the dialog window.  This binding detects a mouse
# click and in response deiconfies the window (in
# case it was iconified) and raises it to the top
# of the window stack.
#
# We use a symbolic binding tag so that we can
# install this binding easily on all modal dialogs
# we want to create.

bind modalDialog <ButtonPress> {
  wm deiconify %W
  raise %W
}

bindtags .toolWnd [linsert [bindtags .toolWnd] 0 modalDialog]

# Handle the "non-standard window termination" by
# invoking the Cancel button when we receives a
# WM_DELETE_WINDOW message from the window manager.
wm protocol .toolWnd WM_DELETE_WINDOW {
    .toolWnd.f.cancel invoke
}
################################################################################


###########################
# Display the dialog
###########################
proc GUI_ToolsShow {} {
  global _TOOLS_CONFIRM_STATUS
  
  
  #~ # read proxy variables
  #~ set ::SHOW_TRACE [ok_loud_mode]
  
  
  # Save old keyboard focus
  set oldFocus [focus]

  # Set the dialog message and display the dialog

  wm deiconify .toolWnd

  # Wait for the window to be displayed
  # before grabbing events

  catch {tkwait visibility .toolWnd}
  catch {grab set .toolWnd}

  # Now drop into the event loop and wait
  # until the _TOOLS_CONFIRM_STATUS variable is
  # set.  This is our signal that the user
  # has clicked on one of the buttons.

  tkwait variable _TOOLS_CONFIRM_STATUS

  # Release the grab (very important!) and
  # return focus to its original widget.
  # Then hide the dialog and return the result.

  grab release .toolWnd
  
  focus $oldFocus
  wm withdraw .toolWnd

  return $_TOOLS_CONFIRM_STATUS
}


# Reads old tool paths, displays the dialog, saves new tool paths
proc GUI_ToolsShowAndApply {} {
  set extToolPathsFilePath [dualcam_find_toolpaths_file 0]
  # at this point tools' file may not exist, so the bellow allowed to fail
  set_ext_tool_paths_from_csv $extToolPathsFilePath
  set res [GUI_ToolsShow]
  if { $res != 0 }  {
    if { 0 == [ext_tools_collect_and_write "source: tools form"] }   {
      tk_messageBox -message "-E- Error saving external tools' paths" -title $::WND_TITLE
    }
  } else {
    # reread tools file to restore paths' environment variables
    set_ext_tool_paths_from_csv $extToolPathsFilePath
  }


}

proc GUI_ChooseDcraw {}  {
  global APP_TITLE _DCRAW_PATH
  set oldFocus [focus];  # save old keyboard focus to restore it later
  if { ([info exists _DCRAW_PATH]) && ("" != [string trim $_DCRAW_PATH]) } {
    set ret [tk_getOpenFile -initialdir [file dirname $_DCRAW_PATH]  \
                            -initialfile $_DCRAW_PATH]
  } else {
    set ret [tk_getOpenFile]
  }

  catch {raise .toolWnd; focus $oldFocus}; # TODO: how to restore keyboard focus
  if { $ret != "" }  {
    set ::_DCRAW_PATH $ret
    # TODO: check that the file chosen is executable
  }
  return  1
}


proc GUI_ChooseIMDir {}  {
  global APP_TITLE _IM_DIR
  set oldFocus [focus];  # save old keyboard focus to restore it later
  if { ([info exists _IM_DIR]) && ("" != [string trim $_IM_DIR]) } {
    set ret [tk_chooseDirectory -initialdir $_IM_DIR]
  } else {
    set ret [tk_chooseDirectory]
  }
  catch {raise .toolWnd; focus $oldFocus}; # TODO: how to restore keyboard focus
  if { $ret != "" }  {
    set ::_IM_DIR $ret
  }
  return  1
}


proc GUI_ChooseEnfuseDir {}  {
  global APP_TITLE _ENFUSE_DIR
  set oldFocus [focus];  # save old keyboard focus to restore it later
  if { ([info exists _ENFUSE_DIR]) && ("" != [string trim $_ENFUSE_DIR]) } {
    set ret [tk_chooseDirectory -initialdir $_ENFUSE_DIR]
  } else {
    set ret [tk_chooseDirectory]
  }
  catch {raise .toolWnd; focus $oldFocus}; # TODO: how to restore keyboard focus
  if { $ret != "" }  {
    set ::_ENFUSE_DIR $ret
  }
  return  1
}


#~ proc GUI_IndicateLoudMode {}  {
  #~ global LOUD_MODE
  #~ ok_info_msg [format "Trace mode set to %s" [expr {($LOUD_MODE==1)? on : off}]]
#~ }


proc _GUI_None {}  {
  ok_info_msg "Called _GUI_None"
}
