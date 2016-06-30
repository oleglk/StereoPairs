# gui_options_form.tcl  - a generic entry form for several options

package require Tk

set SCRIPT_DIR [file dirname [info script]]

package require ok_utils;   namespace import -force ::ok_utils::*


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

set SHOW_TRACE [ok_loud_mode]; # a proxy to prevent changing LOUD_MODE without "Save"

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
# 'keyToInitVal' is a dictionary of <key>::<initial-value>].
# example: {-left_img_subdir "L" -time_diff -3450}
# Returns the dictionary of <key>::<value>
proc GUI_options_form_show {keyToDescrAndFormat keyToInitVal}  {
  global _CONFIRM_STATUS  
  
  # read proxy variables
  set ::SHOW_TRACE [ok_loud_mode]
  
  
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


proc _GUI_fill_options_table {keyToDescrAndFormat keyToInitVal}  {
  global APP_TITLE
  #array unset depthOvrdArr;  array unset PURENAME_TO_DEPTH; # essential init-s
  set tBx .optsWnd.f.optTable
  $tBx configure -state normal
  $tBx delete 1.0 end;   # clean all
  set allKeys [lsort [dict keys $keyToDescrAndFormat]]; # TODO: better sort
  set cnt 0
  dict for {key descrAndFormat} $keyToDescrAndFormat {
    set descr [lindex $descrAndFormat 0]
    if { 0 == [dict exists $keyToInitVal $key] }  { set val "" } else {
      set val [dict get $keyToInitVal $key]  
    }
    incr cnt [_GUI_AppendOneOptionRecord $key $val $descr];# +1 on success
  }
  $tBx configure -state disabled
  ok_info_msg "Prepared $cnt option record(s)"
}


# Inserts depth entry or error message at the end of the textbox.
# Returns 1 on success, 0 on error
proc _GUI_AppendOneDepthOvrdRecord {pureName depthOvrdArrVar} {
  global NAME_HDR ESTIMDEPTH_HDR CHOSENDEPTH_HDR
  global PURENAME_TO_DEPTH
  upvar $depthOvrdArrVar depthOvrdArr
  set retVal 1
  if { 0 == [info exists depthOvrdArr($pureName)] }  {
    set str "Image '$pureName' inexistent in depth-override data"
    ok_err_msg $str;  set retVal 0
  } else {
    ok_trace_msg "Processing depth-ovrd record for '$pureName': {$depthOvrdArr($pureName)}"
    # build and insert into textbox either depth-ovrd record, or error-message 
    if { 0 == [TopUtils_ParseDepthOverrideRecord depthOvrdArr $pureName \
                      globalTime minDepth maxDepth estimatedDepth depth] }  {
      set str "Invalid depth-override record for '$pureName': '$depthOvrdArr($pureName)'"
      ok_err_msg $str;  set retVal 0
    } else {
####  set str "[_FormatCellToHeader $pureName $NAME_HDR]\t[_FormatCellToHeader $estimatedDepth $ESTIMDEPTH_HDR]\t[_FormatCellToHeader $depth $CHOSENDEPTH_HDR]"
      set str "[_FormatCellToHeader $pureName $NAME_HDR]\t[_FormatCellToHeader $estimatedDepth $ESTIMDEPTH_HDR]"
    }
    set tBx .depthWnd.f.depthTable
    set PURENAME_TO_DEPTH($pureName) [_FormatCellToHeader $depth $CHOSENDEPTH_HDR]
    set entryPath ".depthWnd.f.depthTable.depth_$pureName"
    set tclResult [catch {
      set res [$tBx  insert end "$str\t"];  # insert text-only line prefix
      set depthEntry [ttk::entry $entryPath \
                      -width [string length $CHOSENDEPTH_HDR] \
                      -textvariable PURENAME_TO_DEPTH($pureName) \
                      -validate key -validatecommand {ValidateDepthString %P}]
      set res [$tBx  window create end -window $depthEntry]
      set retVal [_GUI_AppendOneEntryPlusMinusResetButtons $pureName $estimatedDepth]
      if { $retVal == 1 }  { incr cnt 1 }
      set res [$tBx  insert end "\n"]
      $tBx see end
    } execResult]
  }
  if { $tclResult != 0 } {
    set msg "Failed appending depth-override record: $execResult!"
    ok_err_msg $msg;  set retVal 0
  }
  return  $retVal
}



