# gui_options_form.tcl  - a generic entry form for several options

package require Tk

set SCRIPT_DIR [file dirname [info script]]


### Sketch of the GUI #####
# |                                                                          | |
# +--------------------------------------------------------------------------+-+
# |                        TXT fullHeader                                    | |
# +--------------------------------------------------------------------------+-+
# |                        TXT optTable                                      |^|
# |                                                                          |^|
# |                                                                          |^|
# |                                                                          |||
# |                                                                          |V|
# |                                                                          |V|
# |                                                                          |V|
# +--------------------------------------------------------------------------+-+
# |                    |BTN  save                |BTN close                  | |
# +--------------------------------------------------------------------------+-+

set WND_TITLE "DualCam Companion - options"

set SHOW_TRACE $LOUD_MODE; # a proxy to prevent changing LOUD_MODE without "Save"

################################################################################
### Here (on top-level) the preferences-GUI is created but not yet shown.
### The code originated from: http://www.tek-tips.com/viewthread.cfm?qid=112205
################################################################################

toplevel .optsWnd


grid [ttk::frame .optsWnd.f -padding "3 3 12 12"] -column 0 -row 0 -sticky nwes
grid columnconfigure .optsWnd 0 -weight 1
grid columnconfigure .optsWnd.f 0 -weight 0
grid columnconfigure .optsWnd.f 1 -weight 1
grid columnconfigure .optsWnd.f 2 -weight 1
grid columnconfigure .optsWnd.f 3 -weight 1
grid columnconfigure .optsWnd.f 4 -weight 0
grid rowconfigure .optsWnd 0 -weight 1
grid rowconfigure .optsWnd.f 0 -weight 0
grid rowconfigure .optsWnd.f 1 -weight 0
grid rowconfigure .optsWnd.f 2 -weight 1
grid rowconfigure .optsWnd.f 3 -weight 0

# header-keywords should be no smaller than corresponding cell data fields
set KEY_HDR "Option-name"
set VAL_HDR "Option-value"
set DESCR_HDR "Option-Description"
grid [tk::text .optsWnd.f.fullHeader -width 60 -height 1 -wrap none -state normal] -column 1 -row 1 -columnspan 3 -sticky we
.optsWnd.f.fullHeader insert end "$KEY_HDR\t$VAL_HDR\t$DESCR_HDR"
.optsWnd.f.fullHeader configure -state disabled

grid [tk::text .optsWnd.f.optTable -width 71 -height 12 -wrap none -state disabled] -column 1 -row 2 -columnspan 3 -sticky wens
grid [ttk::scrollbar .optsWnd.f.optTableScroll -orient vertical -command ".optsWnd.f.optTable yview"] -column 4 -row 2 -columnspan 1 -sticky wns
.optsWnd.f.optTable configure -yscrollcommand ".optsWnd.f.optTableScroll set"


foreach w [winfo children .optsWnd.f] {grid configure $w -padx 5 -pady 5}

grid [ttk::button .optsWnd.f.save -text "Save" -command {set _CONFIRM_STATUS 1}] -column 2 -row 3
  # _CONFIRM_STATUS is a global variable that will hold the value
  # corresponding to the button clicked.  It will also serve as our signal
  # to our GUI_PreferencesShow procedure that the user has finished interacting with the dialog

grid [ttk::button .optsWnd.f.cancel -text "Cancel" -command {set _CONFIRM_STATUS 0}] -column 3 -row 3




# Set the window title, then withdraw the window
# from the screen (hide it)

wm title .optsWnd $WND_TITLE
wm withdraw .optsWnd

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

bindtags .optsWnd [linsert [bindtags .optsWnd] 0 modalDialog]

# Handle the "non-standard window termination" by
# invoking the Cancel button when we receives a
# WM_DELETE_WINDOW message from the window manager.
wm protocol .optsWnd WM_DELETE_WINDOW {
    .optsWnd.f.cancel invoke
}
################################################################################


###########################
# Display the dialog
###########################
################################################################################
# 'keyToDescrAndFormat' is a dictionary of <key>::[list <descr> <scan-format>].
# example: {-left_img_subdir {"Subdirectory for left images" "%s"} -time_diff {"time difference in sec between R and L" "%d"}}
# Returns the dictionary of <key>::<value>
proc GUI_options_form_show {keyToDescrAndFormat}  {
  global _CONFIRM_STATUS  
  
  # read proxy variables
  set ::SHOW_TRACE $::LOUD_MODE
  
  
  # Save old keyboard focus
  set oldFocus [focus]

  # Set the dialog message and display the dialog

  wm deiconify .optsWnd

  # Wait for the window to be displayed
  # before grabbing events

  catch {tkwait visibility .optsWnd}
  catch {grab set .optsWnd}

  # Now drop into the event loop and wait
  # until the _CONFIRM_STATUS variable is
  # set.  This is our signal that the user
  # has clicked on one of the buttons.

  tkwait variable _CONFIRM_STATUS

  # Release the grab (very important!) and
  # return focus to its original widget.
  # Then hide the dialog and return the result.

  grab release .optsWnd
  
  # ? or:   focus .optsWnd.f.rawConv
  focus $oldFocus
  wm withdraw .optsWnd

  return $_CONFIRM_STATUS
}



