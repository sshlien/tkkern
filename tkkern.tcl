
#package provide app-tkkern 1.0
#!/bin/sh
# the next line restarts using wish \
exec wish "$0" "$@"

wm title . "tkkern 1.04 2021.11.08"

set tkkernpath [pwd]
#puts $kernfiles

wm protocol . WM_DELETE_WINDOW {
    get_geometry_of_all_toplevels
    write_tkkern_ini 
    exit
    }

source tooltip.tcl


# init_kernstate
# position_window (window)
# get_geometry_of_all_toplevels
# write_tkkern_ini
# read_tkkern_ini
#  .header buttons interface
# select_folder
# cfg_settings
# load_collections
# selected_tune
# create_html_header
# load_kern_file
# copy_kern_to_html
# export_to_browser
# edit_kern_src
# make_editor
# BindYview (lists args)
# get_header (file)
# verovio_options
# get_verovio_options


proc init_kernstate {} {
global kernstate
   set kernstate(infolder) ""
   set kernstate(infile) ""
   set kernstate(browser) "firefox"
   set kernstate(tempfile) "[pwd]/tune.html"
   set kernstate(.cfg) ""
   set kernstate(.spine) ""
   set kernstate(.headr) ""
   set kernstate(.voptions) ""
   set kernstate(pwidth) ""
   set kernstate(mbot) ""
   set kernstate(mleft) ""
   set kernstate(mright) ""
   set kernstate(mtop) ""
   set kernstate(sca) ""
   set kernstate(spstaff) ""
   set kernstate(splin) ""
   set kernstate(spnline) ""
   set kernstate(appendtext) 0
   set kernstate(autoresize) 0
   set kernstate(header) 0
   set kernstate(incipit) 0
   set kernstate(remote) 1
   set kernstate(font_family) [font actual helvetica -family]
   set kernstate(font_family_toc) courier
   set kernstate(font_size) 11
   set kernstate(texteditor) gvim
  
}

init_kernstate

proc position_window {window} {
   global kernstate
   if {[string length $kernstate($window)] < 1} return
   wm geometry $window $kernstate($window)
   }

proc get_geometry_of_all_toplevels {} {
   global kernstate
   set toplevellist {"." ".spine" ".headr" ".voptions" ".cfg"}
   foreach top $toplevellist {
    if {[winfo exist $top]} {
      set g [wm geometry $top]
      scan $g "%dx%d+%d+%d" w h x y
      #puts "$top $x $y"
      set kernstate($top) +$x+$y
      }
   }
}

proc write_tkkern_ini {} {
    global kernstate
    global tkkernpath
    set outfile [file join $tkkernpath tkkern.ini]
    set handle [open $outfile w]
    #tk_messageBox -message "writing $outfile"  -type ok
    foreach item [lsort [array names kernstate]] {
        puts $handle "$item $kernstate($item)"
    }
    close $handle
}

proc read_tkkern_ini {tkkernpath} {
    global kernstate 
    set infile [file join $tkkernpath tkkern.ini]
    if {![file exist $infile]} return
    set handle [open $infile r]
    #tk_messageBox -message "reading $infile"  -type ok
    while {[gets $handle line] >= 0} {
        set error_return [catch {set n [llength $line]} error_out]
        if {$error_return} continue
        set contents ""
        set param [lindex $line 0]
        for {set i 1} {$i < $n} {incr i} {
            set contents [concat $contents [lindex $line $i]]
        }
        #if param is not already a member of the kernstate array
        # (set by kern_init), then we ignore it. This prevents
        # kernstate array filling up
        #with obsolete parameters used in older versions of the program.
        set member [array names kernstate $param]
        if [llength $member] { set kernstate($param) $contents }
    }
}


read_tkkern_ini $tkkernpath 
set df [font create -family $kernstate(font_family) -size $kernstate(font_size)]


set w .header
frame $w
button $w.render -text render -font $df -command {copy_kern_to_html; 
   export_to_browser}
menubutton $w.kern -text kern -font $df -menu $w.kern.type
menu $w.kern.type -tearoff 0
$w.kern.type add command -label spineList -font $df -command spine_viewer
$w.kern.type add command -label kernFile -font $df -command edit_kern_src 
button $w.options -text options -font $df -command verovio_options
button $w.open -text open -font $df -command select_folder
button $w.cfg -text cfg -font $df -command cfg_settings
button $w.help -text help -font $df -command openHelp

pack $w.open $w.cfg $w.kern $w.options $w.render $w.help -side left

pack $w

tooltip::tooltip .header.open  "Selects kern folder to open"
tooltip::tooltip .header.cfg "Select browser and temporary html file to use"
tooltip::tooltip .header.kern "Views selected kern file."
tooltip::tooltip .header.options "Specify page dimensions,\nscale factor\
 and other options."
tooltip::tooltip .header.render "Creates html with kern file embedded
 and sends it to browser.  Can take 20 
seconds to typeset the music."

set w .collection
frame .collection
label .collection.folder -text $kernstate(infolder) -width 55
listbox .collection.list -height 15 -width 60 -bg lightyellow\
    -yscrollcommand {.collection.ysbar set} -selectmode single 
scrollbar .collection.ysbar -orient vertical -command {.collection.list yview}
pack $w.folder
pack $w.list -side left  -fill y
pack $w.ysbar -side right   -fill y -in $w
pack $w -expand 1 -fill both

proc select_folder {} {
global kernstate
 set folder [tk_chooseDirectory -title "Choose the directory containing the kern files" -initialdir $kernstate(infolder)]
    if {[llength $folder] < 1} return
set kernstate(infolder) $folder
.collection.folder configure -text $kernstate(infolder) 
load_collection
}

proc cfg_settings {} {
global kernstate
global df
set w .cfg
if {[winfo exist .cfg]} {return}
toplevel .cfg
position_window ".cfg"
button $w.findeditor -text "find text editor" -font $df -command {setpath texteditor} -width 20
entry $w.editor -textvariable kernstate(texteditor) -font $df -width 50
grid $w.findeditor $w.editor
button $w.browserbut -text "find or enter browser" -font $df  -command pick_browser -width 20
entry $w.browserent -width 50 -textvariable kernstate(browser) -font $df 
button $w.tempfilebut -text "find or enter temp html file" -font $df -command pick_tempfile -width 20
entry $w.tempfilent -width 50 -textvariable kernstate(tempfile) -font $df
grid $w.browserbut $w.browserent
grid $w.tempfilebut $w.tempfilent
radiobutton $w.remote -text "remote javascript" -variable kernstate(remote)\
   -value 1 -font $df
radiobutton $w.local -text "local javascript" -variable kernstate(remote)\
   -value 0 -font $df -command verify_jslib_path
grid $w.remote $w.local -sticky w

#button $w.javascriptlib -text "path to local javascript" -font $df -command setpathjslib -width 20
#entry $w.jslib -width 56 -relief sunken -textvariable netstate(jslib) -font $df
#grid $w.javascriptlib $w.jslib

tooltip::tooltip .cfg.remote "The JavaScript code is loaded from
verovio-script.humdrum.org"
tooltip::tooltip .cfg.local "The JavaScript code is found in the
same location as this code"
}

proc verify_jslib_path {} {
 set path [append [pwd] verovio-toolkit-wasm.js]
 if {[file exist $path]} {
   } else {
    tk_messageBox -message "The javascript code verovio-toolkit-wasm.js
should be in the same folder as this program" -type ok
   }
}

proc openHelp {} {
  global kernstate
  set cmd "exec [list $kernstate(browser)] https://www.humdrum.org/rep/kern/index.html &"
  catch {eval $cmd} exec_out
}


# not used presently
proc setpathjslib {} {
    global kernstate
    set filedir [file dirname $kernstate(jslib)]
    set openfile [tk_chooseDirectory]
    if {[string length $openfile] > 0} {
        set kernstate(jslib) $openfile
        update
    }
}

proc setpath {path_var} {
    global kernstate
    set filedir [file dirname $kernstate($path_var)]
    set openfile [tk_getOpenFile -initialdir $filedir]
    if {[string length $openfile] > 0} {
        set kernstate($path_var) $openfile
        update
    }
}




proc pick_browser {} {
global kernstate
set openfile [tk_getOpenFile]
if {[string length $openfile] > 1} {
   set kernstate(browser) $openfile
   }
}

proc pick_tempfile {} {
global kernstate
set filedir [pwd]
set openfile [tk_getOpenFile -initialdir $filedir ]
if {[string length $openfile] > 1} {
   set kernstate(tempfile) $openfile
   }
}

proc load_collection {} {
  global kernstate
  set w .collection
  $w.list delete 0 end
  set tkkernpath [pwd]
  set infolder $kernstate(infolder)
  if {![file exist $infolder]} return
  cd $infolder
  set kernfiles [glob -nocomplain *.krn]
  set nkerns [llength $kernfiles]
  if {$nkerns < 1} {
    set msg "No kern files were found. Click the open button\
 and click on the folder which contains all the kern files. Note\
 that only subfolders will be visible in the directory widget."
    tk_messageBox -message $msg
    return
    }

  cd $tkkernpath
  set kernfiles [lsort $kernfiles]
  foreach kern $kernfiles {
    $w.list insert end $kern
   }
  $w.list selection set 0
  }

bind .collection.list <<ListboxSelect>> {update_spines}


load_collection

proc selected_tune {} {
global kernstate
set infolder $kernstate(infolder)
set index [.collection.list curselection]
set infile $infolder/[.collection.list get $index]
puts $infile
set kernstate(infile) $infile
return $infile
}

proc create_html_header {title} {
  global kernstate
  if {$kernstate(remote)} {
    set jsfile "http://verovio-script.humdrum.org/scripts/verovio-toolkit-wasm.js"
    } else {
    set jsfile [append [pwd] verovio-toolkit-wasm.js"]
    }


  set html_preamble "<!DOCTYPE HTML>\n<html>
<head>
<title>An example</title>
<script src=\"$jsfile\"></script>
</head>
<body>
<p>$title</p>

<div style=\"padding-bottom:30px\" id=\"kernNotation\"></div>
<script id=\"humdrum\" type=\"text/x-humdrum\">
"
}

proc load_kern_file {infile} {
set inhandle [open $infile r]
set kern [read $inhandle]
close $inhandle
return $kern
}

proc copy_kern_to_html {} {
  global kernstate
  global outhandle
  set infile [selected_tune]
  set fileroot [file tail $infile]
  set fileroot [file rootname $fileroot]
  set outhandle [open $kernstate(tempfile) w]
  puts $outhandle [create_html_header $fileroot]
  puts $outhandle [load_kern_file $infile]
  puts $outhandle "</script>\n"
  add_tail_to_html
  }

proc add_tail_to_html {} {
global outhandle
set displayoptions [get_verovio_options]
#puts "displayoptions = \n$displayoptions"
puts $outhandle "<script>
document.addEventListener(\"DOMContentLoaded\", (event) => {
   Module.onRuntimeInitialized = async _ => {
      let tk = new verovio.toolkit();
"
puts $outhandle "
      let humdrumDoc = document.querySelector(\"#humdrum\").textContent.replace(/^\s+/, \"\");
      let verovioOptions = {
      pageHeight:   60000,
        $displayoptions
      };
"
puts $outhandle "
      let svgDoc = tk.renderData(humdrumDoc, verovioOptions);
      let elementDoc = document.querySelector(\"#kernNotation\");
      elementDoc.innerHTML = svgDoc;

   }
});
"

puts $outhandle "
</script>
</body>
</html>
"
close $outhandle
}


proc export_to_browser {} {
    global kernstate
    set cmd "exec [list $kernstate(browser)] file://$kernstate(tempfile) &"
    catch {eval $cmd} exec_out
    if {[string first "no such" $exec_out] >= 0} {
     browser_error $kernstate(browser)
     }
}

proc browser_error {src} {
set msg "tkkern could not find the internet browser executable $src.\
 You need to click the cfg button and indicate the path to the browser."
tk_messageBox -message $msg
}

proc edit_kern_src {} {
   global kernstate
   set infile [selected_tune]
   set cmd "exec [list $kernstate(texteditor)] [list $infile] &"
   catch {eval $cmd} exec_out
   if {[string first "no such" $exec_out] >= 0} {
     edit_error $kernstate(texteditor)
     }
}

proc edit_error {src} {
set msg "hnpui could not find the executable $src. You need to click \
the cfg button and indicate the path to the text editor."
tk_messageBox -message $msg
}


proc spine_viewer {} {
set infile [selected_tune]
set nboxes [get_header $infile]
set w .spine
if {[winfo exist .spine]} {destroy .spine}
toplevel .spine
position_window ".spine"
set listboxes {}
for {set i 0} {$i < $nboxes} {incr i} {
   listbox $w.list$i -height 20 -width 12 -yscrollcommand {.spine.ysbar set}
   pack $w.list$i -side left
   lappend listboxes $w.list$i
   }
scrollbar .spine.ysbar -orient vertical -command [list BindYview $listboxes]
pack .spine.ysbar -side right   -fill y -in $w

set kerndata [load_kern_file $infile]
foreach line [split $kerndata \n] {
  if {[string first "!" $line] == 0} continue
  set spines [split $line \t]
  set nspines [llength $spines]
  for {set i 0} {$i < $nboxes} {incr i} {
      if {$i <$nspines} {
      set elem [lindex $spines $i]
      } else {set elem . }
      if {$i < $nboxes && [string first "!" $elem] != 0} {
           $w.list$i insert end $elem
             } 
      }
    }
}

proc BindYview {lists args} {
  #puts "lists = $lists args = $args"
  foreach l $lists {
    eval {$l yview} $args 
    } 
  }

proc get_header {infile} {
global kernstate
if {[winfo exist .headr] == 1} {
  .headr.t delete 1.0 end } else {
   toplevel .headr
   position_window ".headr"
   text .headr.t -width 50 -yscrollcommand {.headr.ysbar set}
   scrollbar .headr.ysbar -orient vertical -command {.headr.t yview}
   pack .headr.t -side left
   pack .headr.ysbar  -side right -fill y -in .headr
   }
set kerndata [load_kern_file $infile]
set maxspines 0
set n 0
foreach line [split $kerndata \n] {
  set spines [split $line \t]
  set nspines [llength $spines]
  if {$nspines > $maxspines} {
    set maxspines $nspines
    } 

  if {[string first "!!!" $line] == 0} {
    .headr.t insert end $line\n
    }
  incr n
  }
return $maxspines
}

proc update_spines {} {
if {[winfo exist .headr] == 1} {
  set infile [selected_tune]
  get_header $infile }
if {[winfo exist .spine]} {
  spine_viewer
  }
}


proc verovio_options {} {
global kernstate
global df
if {![info exist .voptions]} {
  set w .voptions
  if {[winfo exist $]} {return}
  toplevel $w
  position_window ".voptions"
  label $w.pwidth -text "Page width" -font $df
  tooltip::tooltip .voptions.pwidth "minimum 100, maximum 60000"  
  entry $w.pwidthe -textvariable kernstate(pwidth)
  label $w.mbot -text "Bottom margin" -font $df
  tooltip::tooltip .voptions.mbot "default 50, minimum 0, maximum 500"
  entry $w.mbote -textvariable kernstate(mbot) -font $df
  label $w.mleft -text "Left margin" -font $df
  tooltip::tooltip .voptions.mleft "default 50, minimum 0, maximum 500"
  entry $w.mlefte -textvariable kernstate(mleft) -font $df
  label $w.mright -text "Right margin" -font $df
  tooltip::tooltip .voptions.mright "default 50, minimum 0, maximum 500"
  entry $w.mrighte -textvariable kernstate(mright) -font $df
  label $w.mtop -text "Top margin" -font $df
  tooltip::tooltip .voptions.mtop "default 50, minimum 0, maximum 500"
  entry $w.mtope -textvariable kernstate(mtop) -font $df
  label $w.sca -text "Scale" -font $df
  tooltip::tooltip .voptions.sca "scale factor as a percentage\
default 40, minimum 1"
  entry $w.scae -textvariable kernstate(sca) -font $df
  label $w.spstaff -text "Staff spacing" -font $df
  tooltip::tooltip .voptions.spstaff "default 8, minimum 0, maximum 24"
  entry $w.spstaffe -textvariable kernstate(spstaff) -font $df
  label $w.splin -text "Linear spacing" -font $df
  tooltip::tooltip .voptions.splin "default 0.25, minimum 0.0, maximum 1.0"
  entry $w.spline -textvariable kernstate(splin) 
  label $w.spnlin -text "Nonlinear spacing" -font $df
  tooltip::tooltip .voptions.spnlin "default 0.6, minimum 0.0, maximum 1.0"
  entry $w.spnline -textvariable kernstate(spnline) -font $df
  checkbutton $w.autoresize -variable kernstate(autoresize)\
      -text "auto resize" -onvalue true -offvalue false -font $df
  tooltip::tooltip .voptions.autoresize "re-typeset music when browser window is resized"
  checkbutton $w.header -variable kernstate(header) -text header\
      -onvalue true -offvalue false -font $df
  tooltip::tooltip .voptions.header "include title, composer and other info"
  checkbutton $w.incipit -variable kernstate(incipit)\
      -text incipit -onvalue true -offvalue false -font $df
  tooltip::tooltip .voptions.incipit "display only first system of music score" 
  grid $w.pwidth $w.pwidthe $w.sca $w.scae
  grid $w.mbot $w.mbote $w.mtop $w.mtope
  grid $w.mleft $w.mlefte $w.mright $w.mrighte
  grid $w.spstaff $w.spstaffe 
  grid $w.splin $w.spline $w.spnlin $w.spnline
  grid $w.autoresize $w.header $w.incipit
  }
}

proc get_verovio_options {} {
global kernstate
global numericOptions
set w .voptions
set voptionlist {pwidth mbot mleft mright mtop sca spstaff\
          splin spnline autoresize header incipit}
set opstring ""
foreach op $voptionlist {
   if  {[string length [string trim $kernstate($op) " "]] > 0} {
     set optioname [lindex $numericOptions($op) 0]
     append opstring "\n      $optioname:  $kernstate($op),"
     }
  }
set opstring [string trimright $opstring ,]
#set opstring [string trimleft $opstring \n]
return $opstring
}




# Options
array set  numericOptions {
  pwidth {pageWidth none 100 60000}
  mbot {pageMarginBottom 50 0 500}
  mleft {pageMarginLeft 50 0 500}
  mright {pageMarginRight 50 0 500}
  mtop {pageMarginTop 50 0 500}
  sca {scale 40 1}
  spstaff {spacingStaff 8 0 24} 
  splin {spacingLinear 0.25 0.0 1.0}
  spnline {spacingNonLinear 0.6 0.0 1.0}
  autoresize {autoResize}
  header {header}
  incipit {incipit}
  }

set nonNumericOptionList {
  appendText
  {autoResize false}
  filter 
  {header false}
  {incipit false}
  postFunction
  postFunctionHumdrum
  source
  {suppressSvg false}
  }

