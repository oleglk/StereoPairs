# gui.tcl - stereopairs GUI

package require Tk

set SCRIPT_DIR [file dirname [info script]]
source [file join $SCRIPT_DIR   "setup_stereopairs.tcl"]

source [file join $SCRIPT_DIR   "preferences_mgr.tcl"]

# GUI-related dependencies
source [file join $SCRIPT_DIR   "gui_options_form.tcl"]

### Sketch of the GUI #####
# |                 |                 |                   |                    | |
# +----------------------------------------------------------------------------+-+
# |                 |                 |BTN preferences    |BTN help            | |
# +----------------------------------------------------------------------------+-+
# |BTN chooseDir    |                 ENT workDir                              | |
# +----------------------------------------------------------------------------+-+
# |BTN renamePairs  |BTN cloneSettings|BTN compareColors  |BTN hideUnused      | |
# +----------------------------------------------------------------------------+-+
# |BTN restoreNames |LBL progressLbl  |BTN quit           |BTN unhideUnused    | |
# +----------------------------------------------------------------------------+-+
# |               TXT logBox                                                   |^|
# |                                                                            |v|
# +----------------------------------------------------------------------------+-+

set APP_TITLE "DualCam Companion"


################################################################################
proc _CleanLogText {}  {
  set tclResult [catch {
    .top.logBox configure -state normal
    .top.logBox  delete 0.0 end
  } execResult]
  if { $tclResult != 0 } {
    set msg "Failed changing log text: $execResult!"
    puts $msg;  tk_messageBox -message "-E- $msg" -title $APP_TITLE
  }
  .top.logBox configure -state disabled
}

proc _AppendLogText {str {tags ""}}  {
  global APP_TITLE
  set tclResult [catch {
    .top.logBox configure -state normal
    if { [.top.logBox index "end-1c"] != "1.0" }  {.top.logBox insert end "\n"}
    set res [.top.logBox  insert end "$str" "$tags"]
    .top.logBox see end
  } execResult]
  if { $tclResult != 0 } {
    set msg "Failed changing log text: $execResult!"
    puts $msg;  tk_messageBox -message "-E- $msg" -title $APP_TITLE
  }
  .top.logBox configure -state disabled
}


proc _ReplaceLogText {str}  {
  _CleanLogText;  _AppendLogText $str
}
################################################################################


################################################################################
proc _InitValuesForGUI {}  {
  global GUI_VARS
  ok_trace_msg "Setting hardcoded GUI preferences"
  if { 0 == [preferences_get_val -INITIAL_WORK_DIR GUI_VARS(INITIAL_WORK_DIR)]} {
    ok_err_msg "Fatal: missing preference for INITIAL_WORK_DIR";  return  0  }
  set GUI_VARS(PROGRESS) "...Idle..."
  set GUI_VARS(WORK_DIR) $GUI_VARS(INITIAL_WORK_DIR)
  set msg [dualcam_cd_to_workdir_or_complain $GUI_VARS(WORK_DIR) 0]
  if { $msg != "" }  {
    ok_warn_msg "$msg";   # initial work-dir not required to be valid
    return  0
  }
  return  1
}
################################################################################
_InitValuesForGUI
################################################################################


wm title . $APP_TITLE

grid [ttk::frame .top -padding "3 3 12 12"] -column 0 -row 0 -sticky nwes
grid columnconfigure . 0 -weight 1
grid columnconfigure .top 0 -weight 0
grid columnconfigure .top 1 -weight 1;  grid columnconfigure .top 2 -weight 1
grid columnconfigure .top 3 -weight 1;  grid columnconfigure .top 4 -weight 1
grid columnconfigure .top 6 -weight 0
grid rowconfigure . 0 -weight 1
grid rowconfigure .top 0 -weight 0
grid rowconfigure .top 1 -weight 0;   grid rowconfigure .top 2 -weight 0
grid rowconfigure .top 3 -weight 0;   grid rowconfigure .top 4 -weight 0
grid rowconfigure .top 5 -weight 1


grid [ttk::button .top.preferences -text "Preferences..." -command GUI_ChangePreferences] -column 3 -row 1 -sticky we

grid [ttk::button .top.help -text "Help" -command GUI_ShowHelp] -column 4 -row 1 -sticky we

grid [ttk::button .top.chooseDir -text "Folder..." -command GUI_ChooseDir] -column 1 -row 2 -sticky we
#TODO: how-to:  bind .top <KeyPress-f> ".top.chooseDir invoke"

grid [ttk::entry .top.workDir -width 29 -textvariable GUI_VARS(WORK_DIR) -state disabled] -column 2 -row 2 -columnspan 3 -sticky we

grid [ttk::button .top.renamePairs -text "Rename\nPairs" -command GUI_RenamePairs] -column 1 -row 3 -sticky we

grid [ttk::button .top.cloneSettings -text "Clone\nSettings" -command GUI_CloneSettings] -column 2 -row 3 -sticky we

grid [ttk::button .top.compareColors -text "Compare\nColors" -command GUI_CompareColors] -column 3 -row 3 -sticky we

grid [ttk::button .top.hideUnused -text "Hide\nUnused" -command GUI_HideUnused] -column 4 -row 3 -sticky we


grid [ttk::button .top.restoreNames -text "Restore\nNames" -command GUI_RestoreNames] -column 1 -row 4 -sticky we

grid [ttk::label .top.progressLbl -textvariable GUI_VARS(PROGRESS)] -column 2 -row 4 -sticky we

grid [ttk::button .top.quit -text "Quit" -command GUI_Quit] -column 3 -row 4 -sticky we

grid [ttk::button .top.unhideUnused -text "Unhide\nUnused..." -command GUI_UnhideUnused] -column 4 -row 4 -sticky we





grid [tk::text .top.logBox -width 60 -height 6 -wrap word -state disabled] -column 1 -row 5 -columnspan 4 -sticky wens
grid [ttk::scrollbar .top.logBoxScroll -orient vertical -command ".top.logBox yview"] -column 5 -row 5 -columnspan 1 -sticky wns
.top.logBox configure -yscrollcommand ".top.logBoxScroll set"

#.top.logBox tag configure boldline   -font {bold}  ; # TODO: find how to specify bold
#.top.logBox tag configure italicline -font {italic}; # TODO: find how to specify italic
.top.logBox tag configure underline   -underline on




foreach w [winfo children .top] {grid configure $w -padx 5 -pady 5}

focus .top.chooseDir


ok_msg_set_callback "_AppendLogText" ;            # only after the GUI is built
_AppendLogText "Log messages will appear here" ;  # only after the GUI is built


# Handle the "non-standard window termination" by
# invoking the Cancel button when we receives a
# WM_DELETE_WINDOW message from the window manager.
wm protocol . WM_DELETE_WINDOW {
    .top.quit invoke
}
################################################################################



proc GUI_ChangePreferences {}  {
  global APP_TITLE
  tk_messageBox -message "Sorry, preferences not implemented yet]" -title $APP_TITLE
  #~ set res [GUI_PreferencesShow]
  #~ if { $res != 0 }  {
    #~ set savedOK [PreferencesCollectAndWrite]
  #~ }
}


proc GUI_ShowHelp {}  {
  global APP_TITLE SCRIPT_DIR
  tk_messageBox -message "Please read [file join $SCRIPT_DIR {..} {Doc} {UG__Stereopairs.txt}]" -title $APP_TITLE
}


proc GUI_ChooseDir {}  {
  global APP_TITLE SCRIPT_DIR GUI_VARS
  set ret [tk_chooseDirectory -initialdir $GUI_VARS(WORK_DIR)]
  if { $ret != "" }  {
    set msg [_GUI_SetDir $ret]
    #tk_messageBox -message "After cd to work-dir '$GUI_VARS(WORK_DIR)'" -title $APP_TITLE
    if { $msg != "" }  {
      _AppendLogText $msg
      tk_messageBox -message "-E- $msg" -title $APP_TITLE
      return  0
    }
  }
  return  1
}


proc _GUI_SetDir {newWorkDir}  {
  global APP_TITLE SCRIPT_DIR GUI_VARS
  .top.workDir configure -state normal
  set GUI_VARS(WORK_DIR) $newWorkDir
  .top.workDir configure -state disabled
  set msg [dualcam_cd_to_workdir_or_complain $GUI_VARS(WORK_DIR) 1]
  tk_messageBox -message "After cd to work-dir '$GUI_VARS(WORK_DIR)'" -title $APP_TITLE
  return  $msg
}


proc GUI_RenamePairs {}  {
  global APP_TITLE GUI_VARS PREFS
  if { 0 == [_GUI_TryStartAction] }  { return  0 };  # error already printed
  set paramStr [_GUI_RequestOptions "Pair-Matcher" \
                                    "PAIR_MATCHER" errCnt]
  if { $errCnt > 0 } {
    _UpdateGuiEndAction;  return  0;  # error already reported
  }
  set ret [pair_matcher_main $paramStr] ;   # THE EXECUTION
  _UpdateGuiEndAction
  if { $ret == 0 }  {
    #tk_messageBox -message "-E- Failed GUI_RenamePairs in '$GUI_VARS(WORK_DIR)'" -title $APP_TITLE
    return  0
  }
  set msg "Stereopair L/R images renamed under '$GUI_VARS(WORK_DIR)'"
  #tk_messageBox -message $msg -title $APP_TITLE
  ok_info_msg $msg
  return  1
}


proc GUI_CloneSettings {}  {
  global APP_TITLE GUI_VARS PREFS
  if { 0 == [_GUI_TryStartAction] }  { return  0 };  # error already printed
  set paramStr [_GUI_RequestOptions "Settings-Copier" \
                                    "SETTINGS_COPIER" errCnt]
  if { $errCnt > 0 } {
    _UpdateGuiEndAction;  return  0;  # error already reported
  }
  set ret [settings_copier_main $paramStr] ;   # THE EXECUTION
  _UpdateGuiEndAction
  if { $ret == 0 }  {
    #tk_messageBox -message "-E- Failed GUI_CloneSettings in '$GUI_VARS(WORK_DIR)'" -title $APP_TITLE
    return  0
  }
  set msg "Stereopair L/R image-conversion settings cloned under '$GUI_VARS(WORK_DIR)'"
  #tk_messageBox -message $msg -title $APP_TITLE
  ok_info_msg $msg
  return  1
}


# Builds depth-to-color mapping. Returns 1 on success, 0 on error.
proc GUI_CompareColors {}  {
  global APP_TITLE GUI_VARS PREFS
  if { 0 == [_GUI_TryStartAction] }  { return  0 };  # error already printed
  set paramStr [_GUI_RequestOptions "Color-Analyzer" \
                                    "COLOR_ANALYZER" errCnt]
  if { $errCnt > 0 } {
    _UpdateGuiEndAction;  return  0;  # error already reported
  }
  set ret [color_analyzer_main $paramStr] ;   # THE EXECUTION
  _UpdateGuiEndAction
  if { $ret == 0 }  {
    #tk_messageBox -message "-E- Failed GUI_CompareColors in '$GUI_VARS(WORK_DIR)'" -title $APP_TITLE
    return  0
  }
  set msg "Stereopair L/R image colors compared under '$GUI_VARS(WORK_DIR)'"
  #tk_messageBox -message $msg -title $APP_TITLE
  ok_info_msg $msg
}


proc GUI_HideUnused {}       {  return  [_GUI_ProcRAWs 0] }
proc GUI_UnhideUnused {}   {  return  [_GUI_ProcRAWs 1] }


################################################################################
################################################################################
# GUI-involved utility that provides options/preferences for a tool cmd-line
# Returns the cmd-line as a string.
# 'errCnt' > 0 means either errors or cancellation.
proc _GUI_RequestOptions {toolDescrStr toolKeyPrefix errCnt}  {
  upvar $errCnt nErrors
  global APP_TITLE GUI_VARS PREFS
  set nErrors 0
  set key_keysInOrder         [format "%s__keysInOrder"         $toolKeyPrefix]
  set key_keyToDescrAndFormat [format "%s__keyToDescrAndFormat" $toolKeyPrefix]
  set key_keyOnlyArgsList     [format "%s__keyOnlyArgsList"     $toolKeyPrefix]
  set key_hardcodedArgsStr    [format "%s__hardcodedArgsStr"    $toolKeyPrefix]
  if { 0 == [set keyToValIni [preferences_fetch_values \
                                            $PREFS($key_keysInOrder) 0 0]] }  {
    set nErrors 1
    return  "";  # error already printed
  }
  #~ set keyToVal [preferences_strip_rootdir_prefix_from_dirs \
                                          #~ $keyToValIni $GUI_VARS(WORK_DIR) "."]
  set keyToValUlt [GUI_options_form_show \
                $PREFS($key_keyToDescrAndFormat) $keyToValIni \
                "$toolDescrStr Parameters" $PREFS($key_keysInOrder)]
  if { $keyToValUlt == 0 }  {
    set nErrors 1;  # to force cancellation for any reason
    return  "";   # error, if any, already reported
  }
  set paramStr [ok_key_val_list_to_string $keyToValUlt \
                                          $PREFS($key_keyOnlyArgsList) nErrors]
  if { $nErrors > 0 } {
    set msg "$nErrors error(s) in the command parameters"
    tk_messageBox -message "-E- $msg"  -title "$APP_TITLE / $toolDescrStr"
    ok_err_msg $msg;      return  ""
  }
  append paramStr " " $PREFS($key_hardcodedArgsStr)
  return  $paramStr
}


#~ # Chooses depths for all RAWs, computes their color parameters.
#~ # Overrides the color parameters in the settings files/
#~ # Returns 1 on success, 0 on error.
#~ proc _GUI_ProcRAWs {onlyChanged}  {
  #~ global APP_TITLE GUI_VARS
  #~ if { 0 == [_GUI_TryStartAction] }  { return  0 };  # error already printed
  #~ set msg "" ;  # as if evething is OK
  #~ ##TODO:IMPLEMENT set ret [eval exec [list MYCOMMAND PARAMSTR]]
  #~ _UpdateGuiEndAction
  #~ if { $cnt <= 0 }  {
    #~ #tk_messageBox -message "-E- Failed to process settings for all RAWs in '$WORK_DIR':  $msg" -title $APP_TITLE
    #~ return  0
  #~ }
  #~ set msg "WB settings for all RAWs overriden in directory <[file join $WORK_DIR $DATA_DIR]>"
  #~ #tk_messageBox -message $msg -title $APP_TITLE
  #~ ok_info_msg $msg
  #~ return  1
#~ }


proc GUI_Quit {}  {
  global APP_TITLE GUI_VARS SCRIPT_DIR
  set answer [tk_messageBox -type "yesno" -default "no" \
    -message "Are you sure you want to quit?" -icon question -title $APP_TITLE]
  if { $answer == "no" }  {
    return
  }
  ok_finalize_diagnostics
  exit  0
}


proc GUI_RestoreNames {}  {
  global APP_TITLE GUI_VARS PREFS
  if { 0 == [_GUI_TryStartAction] }  { return  0 };  # error already printed
  set paramStr [_GUI_RequestOptions "Left/Right Image Names Restoration" \
                                    "LR_NAME_RESTORER" errCnt]
  if { $errCnt > 0 } {
    _UpdateGuiEndAction;  return  0;  # error already reported
  }
  set ret [pair_matcher_main $paramStr] ;   # THE EXECUTION
  _UpdateGuiEndAction
  if { $ret == 0 }  {
    #tk_messageBox -message "-E- Failed GUI_RestoreNames in '$GUI_VARS(WORK_DIR)'" -title $APP_TITLE
    return  0
  }
  set msg "Stereopair L/R image names restored under '$GUI_VARS(WORK_DIR)'"
  #tk_messageBox -message $msg -title $APP_TITLE
  ok_info_msg $msg
  return  1
}


########## Utilities #######

proc _UpdateGuiStartAction {}   {
  global GUI_VARS
  _CleanLogText
  set GUI_VARS(PROGRESS) "...Working..."
  update idletasks
  set GUI_VARS(CNT_PROBLEMS_BEFORE) [ok_msg_get_errwarn_cnt]
}

proc _UpdateGuiEndAction {}   {
  global GUI_VARS
  set cnt [expr [ok_msg_get_errwarn_cnt] - $GUI_VARS(CNT_PROBLEMS_BEFORE)]
  set msg "The last action encountered $cnt problem(s)"
  if { $cnt > 0 }  { ok_warn_msg $msg } else { ok_info_msg $msg }
  set GUI_VARS(PROGRESS) "...Idle..."
  update idletasks
}


proc _GUI_TryStartAction {}  {
  global APP_TITLE GUI_VARS
  _UpdateGuiStartAction
  #~ if { 0 == [CheckWorkArea] }  {
    #~ #tk_messageBox -message "-E- '$GUI_VARS(WORK_DIR)' lacks essential input files" -title $APP_TITLE
    #~ ok_err_msg "'$GUI_VARS(WORK_DIR)' lacks essential input files"
    #~ _UpdateGuiEndAction;  return  0
  #~ }
  return  1
}
