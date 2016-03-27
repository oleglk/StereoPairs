# common.tcl - common utils
# Copyright (C) 2005-2006 by Oleg Kosyakovsky
global OK_TCLSRC_ROOT
if { [info exists OK_TCLSRC_ROOT] } {;   # assume running as a part of LazyConv
    source $OK_TCLSRC_ROOT/lzc_beta_license.tcl
    package provide ok_utils 1.1
}


namespace eval ::ok_utils:: {

    namespace export \
	ok_list_to_set \
	ok_name_in_array \
	ok_discard_empty_list_elements \
	ok_subtract_list_from_list \
	ok_copy_array \
	ok_list_to_array \
	ok_build_dest_filepath \
	ok_insert_suffix_into_filename \
	ok_insert_io_filenames_into_list \
	ok_insert_name_into_list_at_placeholder \
	ok_write_list_into_file \
	ok_read_list_from_file \
	ok_create_absdirs_in_list \
	ok_get_abs_directories_from_filelist \
	ok_get_purenames_list_from_pathlist \
	ok_override_list \
	ok_rename_file_add_suffix \
	ok_copy_file_if_target_inexistent \
	ok_move_file_if_target_inexistent \
	ok_filepath_is_writable \
	ok_delete_file \
	ok_force_delete_dir \
	ok_mkdir \
	ok_is_underlying_filepath \
	ok_arrange_proc_args \
	ok_make_argspec_for_proc \
  ok_run_silent_os_cmd \
  ok_run_loud_os_cmd
}

# Converts list 'theList' into array 'setName' of {elem->"+"} mappings.
# Returns number of elements in 'theList'
proc ::ok_utils::ok_list_to_set {theList setName} {
    upvar $setName theArray
    array unset theArray
    set cnt 0
    foreach el $theList {
	set theArray($el) "+"
	incr cnt
    }
    return $cnt
}

# Checks whether 'name' appears in 'arrayName'
proc ::ok_utils::ok_name_in_array {name arrayName} {
    upvar $arrayName theArray
#    set result [expr {[llength [array names theArray -exact $name]] >= 1} ]
    set result [info exists theArray($name)]
    # puts "ok_name_in_array -> $result"
    return  $result
}


# Returns a list that is a copy of 'inpList' but without empty ("") elements
proc ::ok_utils::ok_discard_empty_list_elements {inpList} {
    set length [llength $inpList]
    set outList [list]
    for {set i 0} {$i < $length} {incr i} {
	set elem [lindex $inpList $i]
	if { $elem != "" } {
	    lappend outList $elem
	}
    }
    return  $outList
}


# Returns list of elements of 'list1' that don't appear in 'list2'.
# The order in resulting list doesn't match that of 'list1'.
proc ::ok_utils::ok_subtract_list_from_list {list1 list2} {
    set result [list]
    set list1S [lsort $list1]
    set list2S [lsort $list2]
    # lsearch shoud be fast if always looking from specified pos in sorted list
    set startPos 0
    foreach el $list1S {
	set ind [lsearch -exact -start $startPos $list2S $el]
	if { $ind == -1 } {
	    lappend result $el
	}
    }
    return  $result
}


# Copies contents of array 'srcArrName' into array 'dstArrName'
proc ::ok_utils::ok_copy_array {srcArrName dstArrName} {
    upvar $srcArrName srcArr
    upvar $dstArrName dstArr
    ok_assert {[array exists srcArr]} ""
    set aList [array get srcArr]
    array set dstArr $aList
}


# Inserts mapping-pairs from list 'srcList' into array 'dstArrName'.
# Returns 1 on success, 0 on failure.
proc ::ok_utils::ok_list_to_array {srcList dstArrName} {
    upvar $dstArrName dstArr
    set tclExecResult [catch {
	array set dstArr $srcList } evalExecResult]
    if { $tclExecResult != 0 } {
	ok_err_msg "$evalExecResult!"
	return  0
    }
    return  1
}


# Builds and returns "destination" filepath obtained from 'srcFilePath' by
# replacing extension with 'dstExt' and directory path with 'dstDir'.
# Warning: 'ok_build_dest_filepath a.b c' returns './a.c'
proc ::ok_utils::ok_build_dest_filepath {srcFilePath dstExt {dstDir ""}} {
    set fName [file tail $srcFilePath]
    set fNameNoExt [file rootname $fName]
    set srcDir [file dirname $srcFilePath]
    # set ext [file extension $srcFilePath]
    # regsub -nocase "$ext\$" $fName "" fNameNoExt
    if { $dstDir == "" } {
	set dstDir [file dirname $srcFilePath]
    }
    if { $dstExt != "" } {
	set dstFName "$fNameNoExt$dstExt"
    } else {
	set dstFName $fNameNoExt
    }
    if { $dstDir != "" } {
	set dstPath "$dstDir/$dstFName"
    } else {
	set dstPath "$srcDir/$dstFName"
    }
    return $dstPath
}

# For {A/b/name.ext SUFF} returns A/b/nameSUFF.ext
proc ::ok_utils::ok_insert_suffix_into_filename {origFilePath outNameSuffix} {
    set pathNoExt [file rootname $origFilePath]
    set ext       [file extension $origFilePath]
    set newPath "$pathNoExt$outNameSuffix$ext"
    return  $newPath
}

# Replaces two elements of the list in 'listVarName':
# - the one called "@iName@" by 'inpFileName',
# - the one called "@oName@" by 'outFileName'.
# To skip either 'inpFileName' or 'outFileName', provide appropriate arg as "".
# Returns number of substitutions performed or -1 on error.
#### Usage sample:
# % set argList {a @iName@ b @oName@ c}
# % ::ok_utils::ok_insert_io_filenames_into_list argList INAME ONAME
# % puts $argList
# a INAME b ONAME c
###################
proc ::ok_utils::ok_insert_io_filenames_into_list {listVarName \
						   inpFileName outFileName} {
    # TODO: check that there are exactly 3 arguments
    upvar $listVarName theList
    if { [llength $theList] == 0 } {
	ok_err_msg "ok_insert_io_filenames_into_list{EmptyList $inpFileName $outFileName}"
	return  -1
    }
    set substCnt 0
    set iPos [lsearch -exact $theList "@iName@"]
    if { $iPos >= 0 } {
	set theList [lreplace $theList $iPos $iPos $inpFileName]
	incr substCnt 1
    } elseif { $inpFileName != "" } {
	ok_err_msg "ok_insert_io_filenames_into_list{$theList $inpFileName $outFileName}: no placeholder for input file name"
	return  -1
    }
    set oPos [lsearch -exact $theList "@oName@"]
    if { $oPos >= 0 } {
	set theList [lreplace $theList $oPos $oPos $outFileName]
	incr substCnt 1
    } elseif { $outFileName != "" } {
	ok_err_msg "ok_insert_io_filenames_into_list{$theList $inpFileName $outFileName}: no placeholder for output file name"
	return  -1
    }
    return  $substCnt
}

###################
# Replaces element named 'placeHolderName' of the list in 'listVarName'
# by 'nameToInsert'.
# Returns 1 if substitution performed, 0 otherwise. Throws exception on error.
proc ::ok_utils::ok_insert_name_into_list_at_placeholder { \
				listVarName nameToInsert placeHolderName} {
    upvar $listVarName theList
    if { [llength $theList] == 0 } {
	ok_err_msg "ok_insert_name_into_list_at_placeholder{EmptyList '$nameToInsert' '$placeHolderName'}"
	return  -code error
    }
    set substDone 0
    set pos [lsearch -exact $theList $placeHolderName]
    if { $pos >= 0 } {
	set theList [lreplace $theList $pos $pos $nameToInsert]
	set substDone 1
    } elseif { $nameToInsert != "" } {
	ok_trace_msg "(W) ok_insert_name_into_list_at_placeholder{'$theList' '$nameToInsert' '$placeHolderName'}: no placeholder found"
	return  0
    }
    return  $substDone
}


# Stores strings from 'theList' one-at-a-line in file 'fullPath'
# Returns 1 on success, 0 on error.
proc ::ok_utils::ok_write_list_into_file {theList fullPath} {
    set tclExecResult [catch {
	if { ![string equal $fullPath "stdout"] } {
	    set outF [open $fullPath w]
	} else {
	    set outF stdout
	}
	foreach el $theList {    puts $outF $el	}
	if { ![string equal $fullPath "stdout"] } {    close $outF	}
    } execResult]
    if { $tclExecResult != 0 } {
	ok_err_msg "$execResult!"
	return  0
    }
    return  1
}


# Reads strings one-at-a-line from file 'fullPath' into 'listVarName'
# Returns 1 on success, 0 on error.
proc ::ok_utils::ok_read_list_from_file {listVarName fullPath} {
    upvar $listVarName theList
    set theList [list]
    set tclExecResult [catch {
	set inF [open $fullPath r]
	while { [gets $inF line] >= 0 } {
	    lappend theList $line
	}
	close $inF
    } execResult]
    if { $tclExecResult != 0 } {
	ok_err_msg "$execResult!"
	return  0
    }
    return  1
}


# If a directory in 'absDirList' doesn't exist, creates it.
# Returns 0 if failed creating any of the directories.
proc ::ok_utils::ok_create_absdirs_in_list {absDirList {descrList 0}} {
  if { ($descrList != 0) && ([llength $absDirList] != [llength $descrList]) }  {
    ok_err_msg "Number of requested directories differs from number of their descriptions"
    return  0
  }
  for {set i 0} {$i < [llength $absDirList]} {incr i}  {
    set dir [lindex $absDirList $i]
    set descr [expr {($descrList != 0)? [lindex $descrList $i] : "requested"}]
    if { [file exists $dir] == 1 } {
      if { [file isdirectory $dir] == 0 } {
        ok_err_msg "$descr directory path '$dir' is not a directory!"
        return  0
      }
      ok_info_msg "$descr directory path '$dir' pre-existed"
      if { [file readable $dir] == 0 } {
        ok_err_msg "$descr directory path '$dir' is unreadable!"
        return  0
      }
    } else {
      # create the directory
      set tclExecResult [catch { file mkdir $dir } execResult]
      if { $tclExecResult != 0 } {
        ok_err_msg "$execResult!"
        ok_err_msg "Failed creating $descr directory '$dir'."
        return  0
      }
      ok_info_msg "Created $descr directory '$dir'."
    }
  }
  return  1
}


# Returns unique list of normalized absolute directory names
# that occur in 'fullPathList'
proc ::ok_utils::ok_get_abs_directories_from_filelist {fullPathList} {
    set dirList [list]
    foreach f $fullPathList {
	set dir [file normalize [file dirname $f]]
	lappend dirList $dir
    }
    set dirList [lsort -ascii -unique $dirList]
    return  $dirList
}


# Builds and returns list of purenames for fullpath-list 'fullPathList'.
# If 'loud' == 1, prints warning on pure-name dupplications.
proc ::ok_utils::ok_get_purenames_list_from_pathlist {fullPathList {loud 1}} {
    set fNameList [list]
    foreach f $fullPathList {
	set pureName [file tail $f]
	lappend fNameList $pureName
    }
    set numAll [llength $fNameList]
    set fNameListU [lsort -ascii -unique $fNameList]
    set numUniq [llength $fNameListU]
    if { [expr {$loud == 1} && {$numAll != $numUniq}] } {
	ok_warn_msg "ok_get_purenames_list_from_pathlist: there are [expr $numAll-$numUniq] pure-name dupplications in fullpath list {$fullPathList}"
    }
    return  $fNameListU
}


# [ok_override_list [list a b c d] [list "@-@" B "@-@" D]] -> [list a B c D]
# The lists should be of same length, otherwise returns ""
proc ::ok_utils::ok_override_list {origList ovrdList} {
    set sameKey "@-@"
    set leng1 [llength $origList]
    set leng2 [llength $ovrdList]
    if { $leng1 != $leng2 } {
	ok_err_msg "ok_override_list called on different length lists: '$origList' and '$ovrdList' ."
	return  ""
    }
    set resultList [list]
    set ind 0
    foreach el $ovrdList {
	# insert either override- or original list element
	if { $el != $sameKey } {
	    lappend resultList $el
	} else {
	    lappend resultList [lindex $origList $ind]
	}
	incr ind 1
    }
    return  $resultList
}

# [ok_rename_file_add_suffix "file1.jpg" "_N"] -> "file1_N.jpg"
proc ::ok_utils::ok_rename_file_add_suffix {inpFileName suffix} {
    if { ![file exists $inpFileName] } {
	ok_err_msg "ok_rename_file_add_suffix got inexistent filename '$inpFileName'"
	return  0
    }
    # check whether the suffix is already there
    set indOfSuffix [string first $suffix $inpFileName]
    if { $indOfSuffix != -1 } {
	# already renamed - do nothing
	ok_warn_msg "ok_rename_file_add_suffix skipps $inpFileName"
	return  1
    }
    set newFileName [ok_insert_suffix_into_filename $inpFileName $suffix]
    set tclExecResult [catch {
	file rename -- $inpFileName $newFileName } execResult]
    if { $tclExecResult != 0 } {
	ok_err_msg "Failed renaming image '$inpFileName' into '$newFileName'."
	return  0
    }
    return  1
}

# Safely copies 'inpFileName' into 'destDir' unless it already exists there
proc ::ok_utils::ok_copy_file_if_target_inexistent {inpFilePath destDir} {
    set tclExecResult [catch {
	file copy -- $inpFilePath $destDir } execResult]
    if { $tclExecResult != 0 } {
	ok_err_msg "Failed copying image '$inpFilePath' into '$destDir'."
	return  0
    }
    return  1
}

# Safely moves 'inpFileName' into 'destDir' unless it already exists there
proc ::ok_utils::ok_move_file_if_target_inexistent {inpFilePath destDir} {
    set tclExecResult [catch {
	file rename -- $inpFilePath $destDir } execResult]
    if { $tclExecResult != 0 } {
	ok_err_msg "Failed moving image '$inpFilePath' into '$destDir'."
	return  0
    }
    return  1
}

# Returns 1 if 'fullPath' is writable to the current user as a regular file
proc ::ok_utils::ok_filepath_is_writable { fullPath } {
    if { $fullPath == "" } {	return  0    }
    if { [file isdirectory $fullPath] } {	return  0    }
    set dirPath [file dirname $fullPath]
    if { ![file exists $dirPath] } {	return  0    }
    if { [expr {[file exists $fullPath]} && {[file writable $fullPath]==0}] } {
	return  0
    }
    return  1
}

# Safely deletes 'filePath'
proc ::ok_utils::ok_delete_file {filePath} {
    set tclExecResult [catch {
	file delete -- $filePath } execResult]
    if { $tclExecResult != 0 } {
	ok_err_msg "Failed deleting file '$filePath'."
	return  0
    }
    return  1
}


# Safely deletes directory 'dirPath'
proc ::ok_utils::ok_force_delete_dir {dirPath} {
    set tclExecResult [catch {
	file delete -force -- $dirPath } execResult]
    if { $tclExecResult != 0 } {
	ok_err_msg "Failed deleting directory '$dirPath'."
	return  0
    }
    return  1
}


# Safely creates directory 'dirPath'
proc ::ok_utils::ok_mkdir {dirPath} {
    ok_assert {{$dirPath != ""}} ""
    if { [file exists $dirPath] && [file isdirectory $dirPath] } {
	return  1
    }
    set tclExecResult [catch {file mkdir $dirPath} execResult]
    if { $tclExecResult != 0 } {
	ok_err_msg "$execResult!"
	ok_err_msg "Failed creating directory '$dirPath'."
	return  0
    }
    return  1
}

# Returns 1 if (file or directory) 'loPath' located under directory 'hiPath'
proc ::ok_utils::ok_is_underlying_filepath {loPath hiPath} {
    set loPathN [file normalize $loPath]
    set hiPathN [file normalize $hiPath]
    ok_assert {[file isdirectory $hiPath]} ""
    # is 'hiPathN' a prefix for 'loPathN'?
    if { 0 != [string first $hiPathN $loPathN] } {
	return  0
    } else {
	return  1
    }
}


# Builds and returns an ordered list of run-time arguments
# for (existing!) procedure 'procName'
# out of argument-spec array 'swArgArr' that maps argument name to its value.
# 'procName' Should be fully qualified.
# Exits on error.
# Example:
# Run> proc try_args {a1 {a2 a2Def}} {puts "a1='$a1', a2='$a2'"}
# Run> array unset argsArray;  array set argsArray {-a1 a1Val -a2 a2Val}
# Run> ::ok_utils::ok_arrange_proc_args ::try_args argsArray
# Run> a1Val a2Val
# Run> array unset argsArray;  array set argsArray {-a1 a1Val}
# Run> ::ok_utils::ok_arrange_proc_args ::try_args argsArray
# Run> a1Val a2Def
proc ::ok_utils::ok_arrange_proc_args {procName swArgArr} {
    upvar $swArgArr swArgs
    ok_assert {[llength [info procs $procName]] != 0} \
	"ok_arrange_proc_args called for inexistent procedure '$procName'"
    set errCnt 0
    # browse arguments of 'procName' and look for value of each in 'swArgs'
    set allArgs [info args $procName]
    set procArgValList [list]
    foreach argName $allArgs {
	set hasDefault [info default $procName $argName defVal]
	if { $hasDefault } {    set argVal $defVal
	} else {	        set argVal ""	}
	set keyInArray "-$argName"
	if { [ok_name_in_array $keyInArray swArgs] } {
	    set argVal $swArgs($keyInArray)
	} elseif { 0 == $hasDefault } {
	    ok_err_msg \
		"ok_arrange_proc_args '$procName': no value for '$argName'"
	    incr errCnt
	}
	lappend procArgValList $argVal
    }
    if { $errCnt > 0 } {
	ok_err_msg \
	 "ok_arrange_proc_args '$procName' failed defining $errCnt argument(s)"
	return  -code error
    }
    return  $procArgValList
}


# Builds and returns argument spec for procedure 'procName'.
# Format: {{-arg1_name [arg1_defVal]} {-arg2_name [arg2_defVal]} ... } 
proc ::ok_utils::ok_make_argspec_for_proc {procName} {
    ok_assert {[llength [info procs $procName]] != 0} \
	"ok_make_argspec_for_proc called for inexistent procedure '$procName'"
    set argSpec [list]
    set allArgs [info args $procName]
    foreach argName $allArgs {
	set argAndVal [list "-$argName"]
	set hasDefault [info default $procName $argName defVal]
	if { $hasDefault } {    lappend argAndVal $defVal
	} else {	        lappend argAndVal ""	}
	lappend argSpec $argAndVal
    }
    return  $argSpec
}



# This approach isn't debugged - variables not seen inside 'scriptToExec' scope
proc ::ok_utils::ok_exec_under_catch {scriptToExec scriptResult} {
    upvar $scriptResult result
    set tclExecResult [catch {set result [eval $scriptToExec]} execResult]
    if { $tclExecResult != 0 } {
	ok_err_msg "$execResult!"
	return  0
    }
    return  1
}


# Safely runs OS command 'cmdList' that doesn't print output
# if there are no errors.
# Returns 1 on success, 0 on error.
# This proc did not appear in LazyConv.
proc ::ok_utils::ok_run_silent_os_cmd {cmdList}  {
	ok_pri_list_as_list [concat "(TMP--next-cmd-to-exec==)" $cmdList]
  set tclExecResult [catch {    set result [eval exec $cmdList]
    #if { 1 == [ok_loud_mode] } {	    flush $logFile	}
    if { $result == 0 }  { return 0 } ;  # error already printed
  } evalExecResult]
  if { $tclExecResult != 0 } {
    ok_err_msg "Failed executing command: '$cmdList'.";
    ok_err_msg "$evalExecResult!"
    return  0
  }
  return  1
}


# Safely runs OS command 'cmdList' that does print output, maybe meaningful.
# 'outputCheckCB' callback should return 1 on no errors in output, 0 otherwise.
# Returns 1 on success, 0 on error.
# This proc did not appear in LazyConv.
proc ::ok_utils::ok_run_loud_os_cmd {cmdList outputCheckCB}  {
	ok_pri_list_as_list [concat "(TMP--next-cmd-to-exec==)" $cmdList]
  set tclExecResult1 [catch { set result [eval exec $cmdList] } cmdExecResult]
  set tclExecResult2 [catch {
    if { 0 == [$outputCheckCB $cmdExecResult] } {
      #cmdExecResult tells how cmd ended
      ok_err_msg "'$cmdExecResult'"
      return  0
    } else { ok_trace_msg "$cmdExecResult!" }
  } chkExecResult]
  if { $tclExecResult2 != 0 } {
    ok_err_msg "Failed running '$outputCheckCB' to verify result of command: '$cmdList'.";
    ok_err_msg "$chkExecResult!"
    return  0
  }
  return  1
}