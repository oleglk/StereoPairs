4kst# file_nameorder.tcl -  making creation order match name order

namespace eval ::ok_utils:: {

  namespace export                \
    ok_list_files_in_nameorder    \
    ok_flat_copy_in_nameorder     \
    ok_find_place_in_nameorder
}


# Returns list of filenames in 'dirPath' in lexicographic name order.
# On error returns "ERROR"
proc ::ok_utils::ok_list_files_in_nameorder {dirPath} {
  set lst [glob -nocomplain -tails -directory $dirPath *]
  return [lsort -ascii -nocase -increasing $lst]
}


# Copies regular files from 'srcDir' into 'dstDir' in name order.
# If 'fileNameGlobPattern' given, copies only files that match the pattern.
# Returns number of files copied or -1 on error.
proc ::ok_utils::ok_flat_copy_in_nameorder {srcDir dstDir \
                      {fileNameGlobPattern ""}}  {
  if { 0 == [ok_filepath_is_existent_dir $srcDir] }  {
    ok_err_msg "Inexistent source directory '$srcDir'"
    return  0
  }
  if { 0 == [ok_create_absdirs_in_list \
              [list $dstDir] [list "Destination directory"]] }  {
    return  0;  # error already printed
  }
  set allFilenames [ok_list_files_in_nameorder $srcDir]
  ok_info_msg "Found [llength $allFilenames] file(s) of any type under ''srcDir"
  set filteredFilenames [list]
  foreach fName $allFilenames {
    if { ![ok_filepath_is_readable $fPath] }  {
      ok_info_msg "'$fName' (directory or special-type) will not be copied"
      continue;
    }
    if { ($fileNameGlobPattern != "") && (TODO: regexp) } {
      ok_info_msg "'$fName' (not matching pattern) will not be copied"
      continue;
    }
    lappend filteredFilenames $fName
    TODO
  }
}


# Returns index fot 'name' if it was inserted into 'nameList'
proc ::ok_utils::ok_find_place_in_nameorder {name nameList} {
  # TODO
}
