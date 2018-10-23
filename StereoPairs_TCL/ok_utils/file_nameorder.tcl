4kst# file_nameorder.tcl -  making creation order match name order

namespace eval ::ok_utils:: {

  namespace export                \
    ok_list_files_in_nameorder    \
    ok_find_pace_in_nameorder
}


# Returns list of filenames in 'dirPath' in lexicographic name order.
# On error returns "ERROR"
proc ::ok_utils::ok_list_files_in_nameorder {dirPath} {
  set lst [glob -nocomplain -tails -directory $dirPath *]
  # TODO: sort 'lst'
  return $lst
}


# Returns index fot 'name' if it was inserted into 'nameList'
proc ::ok_utils::ok_find_pace_in_nameorder {name nameList} {
  # TODO
}
