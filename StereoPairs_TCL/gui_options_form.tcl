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
# |<<<====================================================================>>>| |
# +--------------------------------------------------------------------------+-+
# |                    |BTN  okSave              |BTN close                  | |
# +--------------------------------------------------------------------------+-+

set WND_TITLE "DualCam Companion - options"

set SHOW_TRACE [ok_loud_mode]; # a proxy to prevent changing LOUD_MODE without "OK"

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
grid rowconfigure .optsWnd.f 4 -weight 0


# header-keywords should be no smaller than corresponding cell data fields
set KEY_HDR "Option-name        "
set VAL_HDR "Option-value                "; # for now - length by try and error
set DESCR_HDR "Option-Description"
grid [tk::text .optsWnd.f.fullHeader -width 60 -height 1 -wrap none -state normal] -column 1 -row 1 -columnspan 3 -sticky we
.optsWnd.f.fullHeader insert end "$KEY_HDR\t$VAL_HDR\t$DESCR_HDR"
.optsWnd.f.fullHeader configure -state disabled
set FONT_HDR [.optsWnd.f.fullHeader configure -font]

grid [tk::text .optsWnd.f.optTable -width 71 -height 12 -wrap none -state disabled] -column 1 -row 2 -columnspan 3 -sticky wens
grid [ttk::scrollbar .optsWnd.f.optTableScrollVert -orient vertical -command ".optsWnd.f.optTable yview"] -column 4 -row 2 -columnspan 1 -sticky wns
.optsWnd.f.optTable configure -yscrollcommand ".optsWnd.f.optTableScrollVert set"
grid [ttk::scrollbar .optsWnd.f.optTableScrollHorz -orient horizontal -command ".optsWnd.f.optTable xview"] -column 1 -row 3 -columnspan 3 -sticky wen
.optsWnd.f.optTable configure -xscrollcommand ".optsWnd.f.optTableScrollHorz set"

  # _CONFIRM_STATUS is a global variable that will hold the value
  # corresponding to the button clicked.  It will also serve as our signal
  # to our GUI_PreferencesShow procedure that the user has finished interacting with the dialog

grid [ttk::button .optsWnd.f.okSave -text "OK" -command {set _CONFIRM_STATUS 1}] -column 2 -row 4
grid [ttk::button .optsWnd.f.cancel -text "Cancel" -command {set _CONFIRM_STATUS 0}] -column 3 -row 4


foreach w [winfo children .optsWnd.f] {grid configure $w -padx 5 -pady 5}



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
# Returns the dictionary of <key>::<value> on success, 0 on error or cancellation
### Example of invocation:
##   GUI_options_form_show [dict create -a {"value of a" "%s"} -i {"value of i" "%d"}]  [dict create -a INIT_a -i 888] 
proc GUI_options_form_show {keyToDescrAndFormat keyToInitVal}  {
  global _CONFIRM_STATUS  
  global KEY_TO_VAL
  
  # read proxy variables
  set ::SHOW_TRACE [ok_loud_mode]
  
  
  # Save old keyboard focus
  set oldFocus [focus]

  # Set the dialog message and display the dialog

  wm deiconify .optsWnd

  # Wait for the window to be displayed
  # before grabbing events

  catch {tkwait visibility .optsWnd}

  if { 1 == [_GUI_fill_options_table $keyToDescrAndFormat $keyToInitVal] }  {
    # ok to present the options
  
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
  } else {  ;   # error(s) in preparing the options
    set _CONFIRM_STATUS 0 ;   # simulate rejection
    tk_messageBox -message "-E- Error in options; please check the log" \
                  -title $::WND_TITLE
  }
  
  focus $oldFocus
  wm withdraw .optsWnd

  if { $_CONFIRM_STATUS == 1 }  { ; # options accepted; no matter if changes applied
    set keyToStrValDict [array get KEY_TO_VAL]; # TCL dict == list of keys and vals
    if { 0 == [set keyToValDict [ok_key_val_list_scan_strings \
                              $keyToDescrAndFormat $keyToStrValDict errStr]] } {
      set msg "Error in options:\n$errStr!"
      tk_messageBox -message "-E- $msg" -title $::WND_TITLE
      return  0
    }
    return  $keyToValDict
  } else { ;                        # options rejected
    return 0
  }
}


proc _GUI_fill_options_table {keyToDescrAndFormat keyToInitVal}  {
  global WND_TITLE
  global KEY_TO_VAL
  array unset KEY_TO_VAL; # essential init
  set keyToValidateCmdPrefix [_build_validation_functions $keyToDescrAndFormat]
  set tBx .optsWnd.f.optTable
  $tBx configure -state normal
  $tBx delete 1.0 end;   # clean all
  set allKeys [lsort [dict keys $keyToDescrAndFormat]]; # TODO: better sort
  set cnt 0;  set errCnt 0
  dict for {key descrAndFormat} $keyToDescrAndFormat {
    set descr [lindex $descrAndFormat 0];   set fmt [lindex $descrAndFormat 1]
    if { 0 == [dict exists $keyToInitVal $key] }  { set val "" } else {
      set tclResult [catch {
        set rawVal [dict get $keyToInitVal $key]
        set val [format $fmt $rawVal]
      } execResult]
      if { $tclResult != 0 } {
        set msg "Invalid initial value '$rawVal' for option '$key' : $execResult!"
        ok_err_msg $msg;  incr errCnt 1;  continue
      }
    }
    if { 1 == [_GUI_append_one_option_record $key $val $descr \
                                             $keyToValidateCmdPrefix] }  { 
      incr cnt 1 } else { incr errCnt 1 }
  }
  $tBx configure -state disabled
  set msg "Prepared $cnt option record(s); $errCnt error(s) occurred"
  if { $errCnt == 0 }   { ok_info_msg $msg } else { ok_err_msg $msg }
  return  [expr {($errCnt == 0)? 1 : 0}]
}


# Inserts one option entry line or error message at the end of the textbox.
# Returns 1 on success, 0 on error
proc _GUI_append_one_option_record {key val descr keyToValidateCmd} {
  global KEY_HDR VAL_HDR DESCR_HDR
  global KEY_TO_VAL
  #global FONT_HDR
  set retVal 1
  ok_trace_msg "Processing option {$key} {$val} {$descr}"
  # build and insert into textbox the option line
  # TODO:verify
  # TODO: how to size the entry when header widget differs in font size?
  set strKey "[_format_cell_to_header $key $KEY_HDR]"
  #set strDescr "[_format_cell_to_header $descr $DESCR_HDR]"
  set strDescr $descr;  # it's the last in line - formatting not needed

  set tBx .optsWnd.f.optTable
  set KEY_TO_VAL($key) [_format_cell_to_header $val $VAL_HDR] ;   # initial val
  set entryPath ".optsWnd.f.optTable.val_$key"
  set tclResult [catch {
    set res [$tBx  insert end "$strKey\t"];  # insert text-only line prefix
    set valEntry [ttk::entry $entryPath     \
            -width [string length $VAL_HDR] \
            -textvariable KEY_TO_VAL($key)  \
            -validate key \
            -validatecommand [list {*}[dict get $keyToValidateCmd $key] %P] ]
    set res [$tBx  window create end -window $valEntry];  # insert value entry
    set res [$tBx  insert end "\t$strDescr"];  # insert text-only line suffix
    set res [$tBx  insert end "\n"]
    $tBx see end
  } execResult]
  if { $tclResult != 0 } {
    set msg "Failed appending option record: $execResult!"
    ok_err_msg $msg;  set retVal 0
  }
  return  $retVal
}


proc _format_cell_to_header {cellVal hdrVal}  {
  if { 1 == [string is integer -strict $cellVal] }  {
    return  [format "%[string length $hdrVal]d" $cellVal]
  } elseif { 1 == [string is double -strict $cellVal] }  {
    return  [format "%[string length $hdrVal].2f" $cellVal]
  } else {
    return  [format "%[string length $hdrVal]s" $cellVal]
  }
}


proc _validate_string_by_format_todo {theStr} {
  return  1
}


proc _validate_string_by_given_format {formatSpec str} {
  ok_trace_msg "formatSpec='$formatSpec' str='$str'"
  if { 1 == [scan [string trim $str] "$formatSpec%c" val leftover] }  {
    return  1
  } else  { return  0 }
}


#~ # Builds a set of per-format-spec string validation functions.
#~ # Returns a dict of <key>::<proc>
#~ ## 'keyToDescrAndFormat' is a dictionary of <key>::[list <descr> <scan-format>].
#~ ##   example: {-left_img_subdir {"Subdirectory for left images" "%s"} -time_diff {"time difference in sec between R and L" "%d"}}
#~ proc _build_validation_functions {keyToDescrAndFormat}  {
  #~ set keyToCmdPrefix [dict create]; # will map keys to validate-cmd prefixes
  #~ dict for {key descrAndFormat} $keyToDescrAndFormat {
    #~ set fmt [lindex $descrAndFormat 1]
    #~ dict set keyToCmdPrefix $key \
                    #~ [list _validate_string_by_given_format $fmt]
  #~ }
  #~ ok_trace_msg "Validation commands: {$keyToCmdPrefix}"
  #~ return  $keyToCmdPrefix
#~ }


# Builds a set of per-format-spec string validation functions.
# Returns a dict of <key>::<proc>
## 'keyToDescrAndFormat' is a dictionary of <key>::[list <descr> <scan-format>].
##   example: {-left_img_subdir {"Subdirectory for left images" "%s"} -time_diff {"time difference in sec between R and L" "%d"}}
proc _build_validation_functions {keyToDescrAndFormat}  {
  set keyToCmd [dict create]; # will map keys to validate-cmd prefixes
  
  dict for {key descrAndFormat} $keyToDescrAndFormat {
    set fmt [lindex $descrAndFormat 1]
    switch ( $fmt ) {
    
    "%d"  {
      dict set keyToCmd $key \
                    [list _validate_integer $fmt]
    }
    "%s"  {
      dict set keyToCmd $key \
                    [list _validate_string $fmt]
    }
    default {
      ok_err_msg "Unknown format {$fmt}"
    }
  ok_trace_msg "Validation commands: {$keyToCmd}"
  return  $keyToCmd
}


proc _validate_string {valAsStr} {
  return  [_validate_string_by_given_format "%s" $valAsStr]
}

proc _validate_integer {valAsStr} {
  return  [_validate_string_by_given_format "%d" $valAsStr]
}
