# gui.tcl - stereopairs GUI

package require Tk

set SCRIPT_DIR [file dirname [info script]]
set DOC_DIR [file join $SCRIPT_DIR  ".." "Doc"]

source [file join $SCRIPT_DIR   "setup_stereopairs.tcl"]

source [file join $SCRIPT_DIR   "preferences_mgr.tcl"]

# GUI-related dependencies
source [file join $SCRIPT_DIR   "gui_options_form.tcl"]
source [file join $SCRIPT_DIR   "gui_text_viewer.tcl"]

### Sketch of the GUI #####
# |                 |                 |                   |                   | |
# +---------------------------------------------------------------------------+-+
# |                 |                 |BTN preferences    |BTN help           | |
# +---------------------------------------------------------------------------+-+
# |BTN chooseDir    |                 ENT workDir                             | |
# +---------------------------------------------------------------------------+-+
# |BTN renamePairs  |BTN cloneSettings|BTN compareColors  |BTN hideUnused     | |
# +---------------------------------------------------------------------------+-+
# |BTN restoreNames |LBL progressLbl  |BTN quit           |BTN unhideUnused   | |
# +---------------------------------------------------------------------------+-+
# |               TXT logBox                                                  |^|
# |                                                                           |v|
# +---------------------------------------------------------------------------+-+

set APP_TITLE "DualCam Companion"

set TEXTVIEW_DIFF .txtViewLRDiff; # Tk path for the L/R color differences window
set TEXTVIEW_HELP .txtViewHelp  ; # Tk path for the help window



################################################################################
proc _CleanLogText {}  {
  set tclResult [catch {
    .top.logBox configure -state normal
    .top.logBox  delete 0.0 end
  } execResult]
  if { $tclResult != 0 } {
    set msg "Failed changing log text: $execResult!"
    puts $msg;  tk_messageBox -type ok -icon error -message "-E- $msg" -title $APP_TITLE
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
    puts $msg;  tk_messageBox -type ok -icon error -message "-E- $msg" -title $APP_TITLE
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


################################################################################
if { "" == [info commands _GUI_UnbindModifiersWithKey] }  {
  proc _GUI_UnbindModifiersWithKey {bindTag key}  {
    set script [bind $bindTag $key] ;   # the existing binding
    bind $bindTag <Control-$key>  continue; # ? break
    bind $bindTag <Alt-$key>      continue; # ? break
    bind $bindTag $key            $script 
  }
}
################################################################################



wm title . $APP_TITLE
wm minsize . 500 300  ;   # chosen experimentally on 1600x900 screen

grid [ttk::frame .top -padding "3 3 12 12"] -column 0 -row 0 -sticky nwes
grid columnconfigure . 0 -weight 1
#grid columnconfigure .top 0 -weight 0
grid columnconfigure .top 1 -weight 1 -uniform 88;  grid columnconfigure .top 2 -weight 1 -uniform 88
grid columnconfigure .top 3 -weight 1 -uniform 88;  grid columnconfigure .top 4 -weight 1 -uniform 88
#grid columnconfigure .top 6 -weight 0
grid rowconfigure . 0 -weight 1
grid rowconfigure .top 0 -weight 0
grid rowconfigure .top 1 -weight 0;   grid rowconfigure .top 2 -weight 0
grid rowconfigure .top 3 -weight 0;   grid rowconfigure .top 4 -weight 0
grid rowconfigure .top 5 -weight 1


grid [ttk::frame .top.userCmds -relief sunken] -column 1 -row 1 -sticky we
# usr buttons get explicit min-width to override that of the style
pack [ttk::button .top.userCmds.usr1 -text "Usr1" -command GUI_UsrCmd1 -width -5] -side left -fill both -expand 1
pack [ttk::button .top.userCmds.usr2 -text "Usr2" -command GUI_UsrCmd2 -width -5] -side left -fill both -expand 1

grid [ttk::button .top.preferences -text "Preferences..." -command GUI_ChangePreferences] -column 3 -row 1 -sticky we

grid [ttk::button .top.help -text "Help" -command GUI_ShowHelp] -column 4 -row 1 -sticky we

grid [ttk::button .top.chooseDir -text "Folder..." -command GUI_ChooseDir] -column 1 -row 2 -sticky we
#TODO: how-to:  bind .top <KeyPress-f> ".top.chooseDir invoke"

grid [ttk::entry .top.workDir -width 29 -textvariable GUI_VARS(WORK_DIR) -state disabled] -column 2 -row 2 -columnspan 3 -sticky we

grid [ttk::button .top.renamePairs -text "Rename\nPairs..." -command GUI_RenamePairs] -column 1 -row 3 -sticky we

grid [ttk::button .top.cloneSettings -text "Clone\nSettings..." -command GUI_CloneSettings] -column 2 -row 3 -sticky we

grid [ttk::button .top.compareColors -text "Compare\nColors..." -command GUI_CompareColors] -column 3 -row 3 -sticky we

grid [ttk::button .top.hideUnused -text "Hide\nUnused..." -command GUI_HideUnused] -column 4 -row 3 -sticky we


grid [ttk::button .top.restoreNames -text "Restore\nNames..." -command GUI_RestoreNames] -column 1 -row 4 -sticky we

grid [ttk::label .top.progressLbl -textvariable GUI_VARS(PROGRESS)] -column 2 -row 4 -sticky we

grid [ttk::button .top.quit -text "Quit" -command GUI_Quit] -column 3 -row 4 -sticky we

grid [ttk::button .top.unhideUnused -text "Unhide\nUnused..." -command GUI_UnhideUnused] -column 4 -row 4 -sticky we





grid [tk::text .top.logBox -width 60 -height 6 -wrap word -state disabled] -column 1 -row 5 -columnspan 4 -sticky wens
grid [ttk::scrollbar .top.logBoxScroll -orient vertical -command ".top.logBox yview"] -column 5 -row 5 -columnspan 1 -sticky wns
.top.logBox configure -yscrollcommand ".top.logBoxScroll set"

#.top.logBox tag configure boldline   -font {bold}  ; # TODO: find how to specify bold
#.top.logBox tag configure italicline -font {italic}; # TODO: find how to specify italic
.top.logBox tag configure underline   -underline on


foreach w [winfo children .top] {
  grid configure $w -padx 5 -pady 5
  # Unbind alt-Space from buttons to let system menu react on Alt-Space
  if { "TButton" == [winfo class $w] }   {
    _GUI_UnbindModifiersWithKey $w space
  }
}
_GUI_UnbindModifiersWithKey TButton space


focus -force .top.chooseDir ;   # -force ensures focus upon initial GUI build


ok_msg_set_callback "_AppendLogText" ;            # only after the GUI is built
_AppendLogText "Log messages will appear here" ;  # only after the GUI is built


# Handle the "non-standard window termination" by
# invoking the Cancel button when we receives a
# WM_DELETE_WINDOW message from the window manager.
wm protocol . WM_DELETE_WINDOW {
    .top.quit invoke
}
################################################################################

textview_prebuild $TEXTVIEW_DIFF  ; # prepare window for L/R color differences
textview_prebuild $TEXTVIEW_HELP  ; # prepare window for the help
################################################################################


proc GUI_UsrCmd1 {}  {
  global APP_TITLE
  if { 0 == [_GUI_TryStartAction] }  { return  0 };  # error already printed
  set paramStr [_GUI_RequestOptions "Custom-command-1" \
                                    "CUST_1_CMD" errCnt]
  if { $errCnt > 0 } {
    _UpdateGuiEndAction;  return  0;  # error already reported
  }
  catch {exec $paramStr} ;   # THE EXECUTION
  #tk_messageBox -message "User-command-1 not implemented" -title $APP_TITLE
  _UpdateGuiEndAction
  return  1
}

# ?Cmd-line example: catch {open "|\"[info nameofexecutable]\" \"C:/Program Files (x86)/etcl/TKCon/tkcon.tcl\""} res
# Non-working: catch {open "|\"c:/Windows/System32/cmd.exe\" \"/K\" \"D:/Photo/TMP/Try_raw2hdr/SCRIPT_TMP/trial_batch.bat\""} res

proc GUI_UsrCmd2 {}  {
  global APP_TITLE
  if { 0 == [_GUI_TryStartAction] }  { return  0 };  # error already printed
  tk_messageBox -message "User-command-2 not implemented" -title $APP_TITLE
  _UpdateGuiEndAction
  return  1
}


proc GUI_ChangePreferences {}  {
  global APP_TITLE GUI_VARS PREFS
  if { 0 == [_GUI_TryStartAction] }  { return  0 };  # error already printed
  if { 0 == [_GUI_EditPreferences] } {
    _UpdateGuiEndAction;  return  0;  # just cancel
  }
  _UpdateGuiEndAction
  #~ set msg "TODO '$GUI_VARS(WORK_DIR)'"
  #~ #tk_messageBox -message $msg -title $APP_TITLE
  #~ ok_info_msg $msg
  return  1
}


proc GUI_ShowHelp {}  {
  global APP_TITLE DOC_DIR TEXTVIEW_HELP
  set helpPath [file join $DOC_DIR "DualCam_UserGuide.txt"]
  #set helpPath [file join $DOC_DIR "try.txt"]
  if { "" == [textview_open $TEXTVIEW_HELP $helpPath 80 \
                  "$APP_TITLE  User Guide"] }   {
      _UpdateGuiEndAction;  return  0;  # error already reported
    }
}


proc GUI_ChooseDir {}  {
  global APP_TITLE SCRIPT_DIR GUI_VARS
  set ret [tk_chooseDirectory -initialdir $GUI_VARS(WORK_DIR)]
  if { $ret != "" }  {
    set msg [_GUI_SetDir $ret]
    #tk_messageBox -message "After cd to work-dir '$GUI_VARS(WORK_DIR)'" -title $APP_TITLE
    if { $msg != "" }  {
      _AppendLogText $msg
      tk_messageBox -type ok -icon error -message "-E- $msg" -title $APP_TITLE
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
  #tk_messageBox -message "Changed working directory to '$GUI_VARS(WORK_DIR)'" -title $APP_TITLE
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
  global APP_TITLE GUI_VARS PREFS TEXTVIEW_DIFF
  if { 0 == [_GUI_TryStartAction] }  { return  0 };  # error already printed
  textview_close $TEXTVIEW_DIFF;  # close old viewer if any prior to computing
  set paramStr [_GUI_RequestOptions "Color-Analyzer" \
                                    "COLOR_ANALYZER" errCnt]
  if { $errCnt > 0 } {
    _UpdateGuiEndAction;  return  0;  # error already reported
  }
  set ret [color_analyzer_main $paramStr] ;   # THE EXECUTION

  if { $ret != 0 }  {
    # find the output file and show it in textview
    set colorDiffSortedCSVPath \
                  [file join $::STS(outDirPath) $::COLORDIFF_SORTED_CSV_NAME]
    if { "" == [textview_open $TEXTVIEW_DIFF $colorDiffSortedCSVPath 100 \
                  "Left-Right color comparison ($colorDiffSortedCSVPath)"] }   {
      _UpdateGuiEndAction;  return  0;  # error already reported
    }
    ok_info_msg "Left-right color comparison output from '$colorDiffSortedCSVPath' shown in the GUI viewer"
  }

  _UpdateGuiEndAction
  if { $ret == 0 }  {
    #tk_messageBox -message "-E- Failed GUI_CompareColors in '$GUI_VARS(WORK_DIR)'" -title $APP_TITLE
    return  0
  }
  set msg "Stereopair L/R image colors compared under '$GUI_VARS(WORK_DIR)'"
  #tk_messageBox -message $msg -title $APP_TITLE
  ok_info_msg $msg
}


proc GUI_HideUnused {}       {
  global APP_TITLE GUI_VARS PREFS
  if { 0 == [_GUI_TryStartAction] }  { return  0 };  # error already printed
  set paramStr [_GUI_RequestOptions "Workarea-Cleaner" \
                                    "WORKAREA_CLEANER" errCnt]
  if { $errCnt > 0 } {
    _UpdateGuiEndAction;  return  0;  # error already reported
  }
  set ret [workarea_cleaner_main $paramStr] ;   # THE EXECUTION
  _UpdateGuiEndAction
  if { $ret == 0 }  {
    #tk_messageBox -message "-E- Failed GUI_HideUnused in '$GUI_VARS(WORK_DIR)'" -title $APP_TITLE
    return  0
  }
  set msg "Unused stereopair image- and related files hidden under '$GUI_VARS(WORK_DIR)'"
  #tk_messageBox -message $msg -title $APP_TITLE
  ok_info_msg $msg
}


proc GUI_UnhideUnused {}   {
  global APP_TITLE GUI_VARS PREFS
  if { 0 == [_GUI_TryStartAction] }  { return  0 };  # error already printed
  set restoreFromDir [tk_chooseDirectory -initialdir $GUI_VARS(WORK_DIR) \
    -title "Choose a directory to restore files from"]
  if { $restoreFromDir == "" }  {
    set msg "Canceled restoration of hidden files in the workarea"
    tk_messageBox -message $msg -title $APP_TITLE;    ok_info_msg $msg
    return  0
  }
  if { 0 == [preferences_is_backup_dir_path $restoreFromDir] }  {
    set msg "'-E- $restoreFromDir' is not a backup directory"
    tk_messageBox -message $msg -title $APP_TITLE;    ok_err_msg $msg
    return  0
  }

  set paramStr [_GUI_RequestOptions "Workarea-Restorer" \
                                    "WORKAREA_RESTORER" errCnt]
  if { $errCnt > 0 } {
    _UpdateGuiEndAction;  return  0;  # error already reported
  }
  append paramStr " -restore_from_dir $restoreFromDir"
  set ret [workarea_cleaner_main $paramStr] ; # EXECUTION; same proc as cleaner
  _UpdateGuiEndAction
  if { $ret == 0 }  {
    #tk_messageBox -message "-E- Failed GUI_UnhideUnused in '$GUI_VARS(WORK_DIR)'" -title $APP_TITLE
    return  0
  }
  set msg "Unused stereopair image- and related files restored under '$GUI_VARS(WORK_DIR)'"
  #tk_messageBox -message $msg -title $APP_TITLE
  ok_info_msg $msg
}


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
                $PREFS($key_keyToDescrAndFormat) $keyToValIni 0 \
                "$toolDescrStr Parameters" $PREFS($key_keysInOrder)]
  if { $keyToValUlt == 0 }  {
    set nErrors 1;  # to force cancellation for any reason
    return  "";   # error, if any, already reported
  }
  set paramStr [ok_key_val_list_to_string $keyToValUlt \
                                          $PREFS($key_keyOnlyArgsList) nErrors]
  if { $nErrors > 0 } {
    set msg "$nErrors error(s) in the command parameters"
    tk_messageBox -type ok -icon error -message "-E- $msg"  -title "$APP_TITLE / $toolDescrStr"
    ok_err_msg $msg;      return  ""
  }
  append paramStr " " $PREFS($key_hardcodedArgsStr)
  return  $paramStr
}


################################################################################
################################################################################
# GUI-involved utility that edits and saves preferences
# Returns 1 on accept, 0 on cancellation.
proc _GUI_EditPreferences {}  {
  global APP_TITLE GUI_VARS PREFS
  set nErrors 0
  set key_keysInOrder         "ALL_PREFERENCES__keysInOrder"
  set key_keyToDescrAndFormat "ALL_PREFERENCES__keyToDescrAndFormat"
  set keysNoHeaders [preferences_strip_special_keywords_from_list \
                                                      $PREFS($key_keysInOrder)]
  if { 0 == [set keyToValIni [preferences_fetch_values \
                                            $keysNoHeaders 0 0]] }  {
    return  0;  # error already printed
  }
  set keyToValUlt [GUI_options_form_show \
              $PREFS($key_keyToDescrAndFormat) $keyToValIni \
              preferences_get_initial_user_changeable_values \
              "Edit Preferences" $PREFS($key_keysInOrder)]
  if { $keyToValUlt == 0 }  {
    return  0;   # error, if any, already reported; or it's a cancellation
  }
  if { 0 == [ok_list_to_array $keyToValUlt keyToValUltAsArray] }  {
    return  0;  # error already printed
  }
  ok_copy_array keyToValUltAsArray PREFS ;  # merges 'keyToValUlt' into 'PREFS'
  # save the new preferences from 'PREFS'
  if { 0 == [preferences_collect_and_write] }  {
    set msg "Failed to save preferences; please see the log"
    tk_messageBox -type ok -icon error -message "-E- $msg"  -title "$APP_TITLE / Edit Preferences"
    return  0
  }
  return  1
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
  if { $cnt > 0 }  { append msg "; please see underlined messages in the log" }
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
