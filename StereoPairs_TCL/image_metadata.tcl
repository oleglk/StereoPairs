# image_metadata.tcl

set SCRIPT_DIR [file dirname [info script]]
package require ok_utils

#source [file join $SCRIPT_DIR   "debug_utils.tcl"]
ok_trace_msg "---- Sourcing '[info script]' in '$SCRIPT_DIR' ----"
source [file join $SCRIPT_DIR   "ext_tools.tcl"]

################################################################################
# indices for metadata fields
set iMetaDate 0
set iMetaTime 1
set iMetaISO  2

# extensions of standard image files
set g_stdImageExtensions {.bmp .jpg .png .tif}
foreach e $g_stdImageExtensions {lappend g_stdImageExtensions [string toupper $e]}
################################################################################


proc is_standard_image {path} {
  set ext [file extension $path]
  return  [expr {0 <= [lsearch -exact $::g_stdImageExtensions $ext]}]
}


#~ proc is_raw_image {path} {
  #~ set ext [file extension $path]
  #~ return  [expr {0 <= [lsearch -exact $::g_rawImageExtensions $ext]}]
#~ }


# Returns dictionary with global times of images in 'imgPathList': {purenane->time}.
# On error returns 0.
# Detects formats by extension; applies relevant methods accordingly.
proc get_listed_images_global_timestamps {imgPathList} {
  set nameToTimeDict [dict create]
  set inexistentCnt 0
  foreach fPath $imgPathList {
    if { 0 == [file exists $fPath] }  {
      ok_err_msg "Inexistent image '$fPath'"
      incr inexistentCnt 1;   continue
    }
    if { -1 == [set gTime [get_image_global_timestamp $fPath]] }  {
      continue; # error already printed
    }
    set purename [AnyFileNameToPurename [file tail $fPath]]
    dict set nameToTimeDict $purename $gTime
  }
  set cntGood [dict size $nameToTimeDict];  set cntAll [llength $imgPathList]
  if { $cntGood == $cntAll }  {
    ok_info_msg "Success reading timestamp(s) of $cntGood image(s)"
  } elseif { $cntGood > 0 }  {
    ok_warn_msg "Read timestamp(s) of $cntGood image(s) out of $cntAll; $inexistentCnt inexistent"
  } else { ;    # all failed
    ok_err_msg "Failed reading timestamp(s) of all $cntAll image(s)"
    return  0
  }
  return  $nameToTimeDict
}


# Returns global time of image 'fullPath'. On error returns -1.
# Detects format by extension; applies relevant method accordingly.
proc get_image_global_timestamp {fullPath} {
  global iMetaDate iMetaTime
  array unset imgInfoArr
  if { [is_standard_image $fullPath] } {
    ok_trace_msg "Image '$fullPath' considered a standard image format"
    set formatStr {%Y %m %d %H %M %S}
    set res [get_image_timestamp_by_imagemagick $fullPath imgInfoArr]
  } else {
    ok_info_msg "Image '$fullPath' considered a RAW image format"
    set formatStr {%Y %b %d %H %M %S}
    set res [GetImageAttributesByDcraw $fullPath imgInfoArr]
  }
  if { $res == 0 }  {
    return  -1; # error already printed
  }
  set gt [_date_time_to_global_time \
                    $imgInfoArr($iMetaDate) $imgInfoArr($iMetaTime) $formatStr]
  if { $gt == -1 }  {
    ok_err_msg "Failed recognizing global timestamp of image '$fullPath'"
    return -1
  }
  ok_trace_msg "Global timestamp of image '$fullPath' is $gt"
  return  $gt
}



# Example: dateList=="{2016 02 13"  timeList=={16 41 08} ==> returns 1455374380
# Returns -1 on error
proc _date_time_to_global_time {dateList timeList formatStr} {
  set dtStr [join [concat $dateList $timeList]]
  set tclExecResult [catch {
    set globalTime  [clock scan "$dtStr" -format $formatStr]
  } evalExecResult]
  if { $tclExecResult != 0 } {
    ok_err_msg "Date/time {$dateList} {$timeList} don't match {$formatStr}: $evalExecResult!"
    return  -1
  }
  return  $globalTime
}


# Puts into 'imgInfoArr' date and time of image 'fullPath'.
# On success returns 1, 0 on error.
# Sample result: imgInfoArr(date)={2016 02 13} imgInfoArr(time)={16 41 08}
# Processing command:
## clock scan "$imgInfoArr($iMetaDate) $imgInfoArr($iMetaTime)" -format {%Y %b %d %H %M %S}
proc get_image_timestamp_by_imagemagick {fullPath imgInfoArr} {
  global iMetaDate iMetaTime
  upvar $imgInfoArr imgInfo
  if { "" == [set tStr [_get_one_image_attribute_by_imagemagick $fullPath \
                                          {%[EXIF:DateTime]} "timestamp"]] } {
    return  0;  # error already printed
  }
  if { 0 == [_ProcessImIdentifyMetadataLine $tStr imgInfo] }  {
    return  0; # TODO: msg
  }
  return  1
}


# Reads metadata value of 'fullPath' specified by 'attribSpec'
# The input is a standard image, not RAW.
# Returns attribute value text on success, "" on error.
# Sample Imagemagick "identify" invocation:
# 	$::_IMIDENTIFY -quiet -verbose -ping -format "%[EXIF:BrightnessValue] <filename>" 
proc _get_one_image_attribute_by_imagemagick {fullPath attribSpec attribName} {
  if { ![file exists $fullPath] || ![file isfile $fullPath] } {
    ok_err_msg "Invalid image path '$fullPath'"
    return  ""
  }
  set tclExecResult [catch {
	# Open a pipe to the program
	#   set io [open "|identify -format \"\%[EXIF:BrightnessValue]\" $fullPath" r]
  set nv_fullPath [file nativename $fullPath]
    set io [eval [list open \
              [format {|%s -quiet -verbose -ping -format %s {%s}} \
                      $::_IMIDENTIFY $attribSpec $nv_fullPath] r]]
    set len [gets $io line];	# Get the reply
    close $io
  } execResult]
  if { $tclExecResult != 0 } {
    ok_err_msg "$execResult!"
    ok_err_msg "Cannot get $attribName of '$fullPath'"
    return  ""
  }
  # $line should have some data
  if { $len == -1 } {
    ok_err_msg "Cannot read $attribName of '$fullPath'"
    return  ""
  }
  #ok_trace_msg "{$attribName} of $fullPath = $line"
  set val [string trim $line]
  if { $val == "" } {
    ok_err_msg "Cannot read $attribName of '$fullPath'"
	  return  ""
  }
  ok_trace_msg "$attribName of $fullPath: $val"
  return  $val
}


# Processes the following exif line(s):
# 2016:02:13 16:41:08
# Returns 1 if line was recognized, otherwise 0
proc _ProcessImIdentifyMetadataLine {line imgInfoArr} {
  global iMetaDate iMetaTime iMetaISO
  upvar $imgInfoArr imgInfo
  # example:'2016:02:13 16:41:08'
  set isMatched [regexp {([0-9]+):([0-9]+):([0-9]+) ([0-9]+):([0-9]+):([0-9]+)} $line fullMach \
                                    year month day hours minutes seconds]
  if { $isMatched == 0 } {
    return  0
  }
  set imgInfo($iMetaDate) [list $year $month $day]
  set imgInfo($iMetaTime) [list $hours $minutes $seconds]
  return  1
}


# Puts into 'brightness' the EXIF brightness value of 'fullPath'
# The input is a standard image, not RAW.
# Returns 1 on success, 0 on error.
# Imagemagick "identify" invocation:
# 	$::_IMIDENTIFY -quiet -verbose -ping -format "%[EXIF:BrightnessValue] <filename>" 
proc get_image_brightness_by_imagemagick {fullPath brightness} {
  upvar $brightness brVal
  if { ![file exists $fullPath] || ![file isfile $fullPath] } {
    ok_err_msg "Invalid image path '$fullPath'"
    return  0
  }
  set tclExecResult [catch {
	# Open a pipe to the program
	#   set io [open "|identify -format \"\%[EXIF:BrightnessValue]\" $fullPath" r]
  set nv_fullPath [file nativename $fullPath]
    set io [eval [list open [format {|%s -quiet -verbose -ping -format %%[EXIF:BrightnessValue] {%s}} \
              $::_IMIDENTIFY $nv_fullPath] r]]
    set len [gets $io line];	# Get the reply
    close $io
  } execResult]
  if { $tclExecResult != 0 } {
    ok_err_msg "$execResult!"
    ok_err_msg "Cannot get BrightnessValue of '$fullPath'"
    return  0
  }
  # $line should be: "<BrightnessValue>"
  if { $len == -1 } {
    ok_err_msg "Cannot get BrightnessValue of '$fullPath'"
    return  0
  }
  # ok_trace_msg "{BrightnessValue} of $fullPath = $line"
  set brVal [string trim $line]
  if { $brVal == "" } {
    ok_err_msg "Cannot get BrightnessValue of '$fullPath'"
	  return  0
  }
  ok_trace_msg "BrightnessValue of $fullPath: $brVal"
  return  1
}


# (this proc is a copy-paste from LazyConv - same name under ::imageproc:: -
# except for executable path not enclosed in extra curved brackets)
# Puts into 'width' and 'height' horizontal and vertical sizes of 'fullPath'
# Returns 1 on success, 0 on error.
# Imagemagick "identify" invocation: identify -ping -format "%w %h" <filename>
proc get_image_dimensions_by_imagemagick {fullPath width height} {
  upvar $width wd
  upvar $height ht
  if { ![file exists $fullPath] || ![file isfile $fullPath] } {
    ok_err_msg "Invalid image path '$fullPath'"
	  return  0
  }
  set tclExecResult [catch {
    # Open a pipe to the program
    #   set io [open "|identify -format \"%w %h\" $fullPath" r]
    set io [eval [list open [format {|%s -ping -format "%%w %%h" %s} \
               $::_IMIDENTIFY $fullPath] r]]
    set len [gets $io line];	# Get the reply
    close $io
  } execResult]
  if { $tclExecResult != 0 } {
    ok_err_msg "$execResult!"
    ok_err_msg "Cannot get width/height of '$fullPath'"
    return  0
  }
  # $line should be: "<width> <height>"
  if { $len == -1 } {
    ok_err_msg "Cannot get width/height of '$fullPath'"
    return  0
  }
  # ok_trace_msg "{W H} of $fullPath = $line"
  set whList [split $line " "]
  if { [llength $whList] != 2 } {
    ok_err_msg "Cannot get width/height of '$fullPath'"
	  return  0
  }
  set wd [lindex $whList 0];    set ht [lindex $whList 1]
  ok_trace_msg "Dimensions of $fullPath: width=$wd, height=$ht"
  return  1
}


# Verifies whether exiftool command line ended OK through the test it printed.
# Returns 1 if it was good, 0 otherwise.
proc is_exiftool_result_ok {execResultText} {
  # 'execResultText' tells how exiftool-based command ended
  # - OK if noone of 'errKeys' appears
  set result 1;    # as if it ended OK
  set errKeys [list {exiftool - Read and write} {File not found} \
                    {Unknown file type} {File format error}]
#     puts ">>> Check for error keys '$errKeys' the following string:"
#     puts "--------------------------------------------"
#     puts "'$execResultText'"
#     puts "--------------------------------------------"
  foreach key $errKeys {
    if { [string first "$key" $execResultText] >= 0 } {    set result 0  }
  }
  return  $result
}


########### DCRAW-based section. Copied from UWIC "read_image_metadata.tcl" ####

# Processes the following exif line(s):
# Timestamp: Sat Aug 23 08:58:21 2014
# Returns 1 if line was recognized, otherwise 0
proc _ProcessDcrawMetadataLine {line imgInfoArr} {
  global iMetaDate iMetaTime iMetaISO
  upvar $imgInfoArr imgInfo
  # example:'Timestamp: Sat Aug 23 08:58:21 2014'
  set isMatched [regexp {Timestamp: ([a-zA-Z]+) ([a-zA-Z]+) ([0-9]+) ([0-9]+):([0-9]+):([0-9]+) ([0-9]+)} $line fullMach \
                                    weekday month day hours minutes seconds year]
  if { $isMatched == 0 } {
    return  0
  }
  set imgInfo($iMetaDate) [list $year $month $day]
  set imgInfo($iMetaTime) [list $hours $minutes $seconds]
  return  1
}


# Puts into 'imgInfoArr' ISO, etc. of image 'fullPath'.
# On success returns number of data fields being read, 0 on error.
proc GetImageAttributesByDcraw {fullPath imgInfoArr} {
  global _DCRAW
  global iMetaDate iMetaTime iMetaISO
  upvar $imgInfoArr imgInfo
  if { ![file exists $fullPath] || ![file isfile $fullPath] } {
    ok_err_msg "Invalid image path '$fullPath'"
    return  0
  }
  set readFieldsCnt 0
  # command to mimic: eval [list $::ext_tools::EXIV2 pr PICT2057.MRW]
  set tclExecResult [catch {
    # Open a pipe to the program, then get the reply and process it
    # set io [open "|dcraw.exe -i -v $fullPath" r]
    set io [eval [list open [format {|%s  -i -v %s} \
             $_DCRAW $fullPath] r]]
    # while { 0 == [eof $io] } { set len [gets $io line]; puts $line }
    while { 0 == [eof $io] } {
      set len [gets $io line]
      #puts $line
      if { 0 != [_ProcessDcrawMetadataLine $line imgInfo] } {
        incr readFieldsCnt
      }
    }
  } execResult]
  if { $tclExecResult != 0 } {
    ok_err_msg "$execResult!";	return  0
  }
  set tclExecResult [catch {
    close $io;  # generates error; separate "catch" to suppress it
  } execResult]
  if { $tclExecResult != 0 } { ok_warn_msg "$execResult - at closing dcraw process" }
  if { $readFieldsCnt == 0 } {
    ok_err_msg "Cannot understand metadata of '$fullPath'"
    return  0
  }
  ok_trace_msg "Metadata of '$fullPath': time=$imgInfo($iMetaTime)"
  return  $readFieldsCnt
}
##### End of DCRAW-based section. Copied from UWIC "read_image_metadata.tcl" ###
