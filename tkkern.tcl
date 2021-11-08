
#package provide app-tkkern 1.0
#!/bin/sh
# the next line restarts using wish \
exec wish "$0" "$@"

wm title . "tkkern 1.05 2021.11.08"

set tkkernpath [pwd]
#puts $kernfiles

wm protocol . WM_DELETE_WINDOW {
    get_geometry_of_all_toplevels
    write_tkkern_ini 
    exit
    }

##source tooltip.tcl



# tooltip.tcl --
#
#       Balloon help
#
# Copyright (c) 1996-2003 Jeffrey Hobbs
#
# See the file "license.terms" for information on usage and redistribution
# of this file, and for a DISCLAIMER OF ALL WARRANTIES.
#
# RCS: @(#) $Id: tooltip.tcl,v 1.5 2005/11/22 00:55:07 hobbs Exp $
#
# Initiated: 28 October 1996


package require Tk 8.5
package provide tooltip 1.1


#------------------------------------------------------------------------
# PROCEDURE
#	tooltip::tooltip
#
# DESCRIPTION
#	Implements a tooltip (balloon help) system
#
# ARGUMENTS
#	tooltip <option> ?arg?
#
# clear ?pattern?
#	Stops the specified widgets (defaults to all) from showing tooltips
#
# delay ?millisecs?
#	Query or set the delay.  The delay is in milliseconds and must
#	be at least 50.  Returns the delay.
#
# disable OR off
#	Disables all tooltips.
#
# enable OR on
#	Enables tooltips for defined widgets.
#
# <widget> ?-index index? ?-item id? ?message?
#	If -index is specified, then <widget> is assumed to be a menu
#	and the index represents what index into the menu (either the
#	numerical index or the label) to associate the tooltip message with.
#	Tooltips do not appear for disabled menu items.
#	If message is {}, then the tooltip for that widget is removed.
#	The widget must exist prior to calling tooltip.  The current
#	tooltip message for <widget> is returned, if any.
#
# RETURNS: varies (see methods above)
#
# NAMESPACE & STATE
#	The namespace tooltip is used.
#	Control toplevel name via ::tooltip::wname.
#
# EXAMPLE USAGE:
#	tooltip .button "A Button"
#	tooltip .menu -index "Load" "Loads a file"
#
#------------------------------------------------------------------------

namespace eval ::tooltip {
    namespace export -clear tooltip
    variable tooltip
    variable G
    
    array set G {
        enabled		1
        DELAY		500
        AFTERID		{}
        LAST		-1
        TOPLEVEL	.__tooltip__
    }
    
    # The extra ::hide call in <Enter> is necessary to catch moving to
    # child widgets where the <Leave> event won't be generated
    bind Tooltip <Enter> [namespace code {
        #tooltip::hide
        variable tooltip
        variable G
        set G(LAST) -1
        if {$G(enabled) && [info exists tooltip(%W)]} {
            set G(AFTERID) \
                    [after $G(DELAY) [namespace code [list show %W $tooltip(%W) cursor]]]
        }
    }]
    
    bind Menu <<MenuSelect>>	[namespace code { menuMotion %W }]
    bind Tooltip <Leave>	[namespace code hide]
    bind Tooltip <Any-KeyPress>	[namespace code hide]
    bind Tooltip <Any-Button>	[namespace code hide]
}

proc ::tooltip::tooltip {w args} {
    variable tooltip
    variable G
    switch -- $w {
        clear	{
            if {[llength $args]==0} { set args .* }
            clear $args
        }
        delay	{
            if {[llength $args]} {
                if {![string is integer -strict $args] || $args<50} {
                    return -code error "tooltip delay must be an\
                            integer greater than 50 (delay is in millisecs)"
                }
                return [set G(DELAY) $args]
            } else {
                return $G(DELAY)
            }
        }
        off - disable	{
            set G(enabled) 0
            hide
        }
        on - enable	{
            set G(enabled) 1
        }
        default {
            set i $w
            if {[llength $args]} {
                set i [uplevel 1 [namespace code "register [list $w] $args"]]
            }
            set b $G(TOPLEVEL)
            if {![winfo exists $b]} {
                toplevel $b -class Tooltip
                if {[tk windowingsystem] eq "aqua"} {
                    ::tk::unsupported::MacWindowStyle style $b help none
                } else {
                    wm overrideredirect $b 1
                }
                wm positionfrom $b program
                wm withdraw $b
                label $b.label -highlightthickness 0 -relief solid -bd 1 \
                        -background lightyellow -fg black
                pack $b.label -ipadx 1
            }
            if {[info exists tooltip($i)]} { return $tooltip($i) }
        }
    }
}

proc ::tooltip::register {w args} {
    variable tooltip
    set key [lindex $args 0]
    while {[string match -* $key]} {
        switch -- $key {
            -index	{
                if {[catch {$w entrycget 1 -label}]} {
                    return -code error "widget \"$w\" does not seem to be a\
                            menu, which is required for the -index switch"
                }
                set index [lindex $args 1]
                set args [lreplace $args 0 1]
            }
            -item	{
                set namedItem [lindex $args 1]
                if {[catch {$w find withtag $namedItem} item]} {
                    return -code error "widget \"$w\" is not a canvas, or item\
                            \"$namedItem\" does not exist in the canvas"
                }
                if {[llength $item] > 1} {
                    return -code error "item \"$namedItem\" specifies more\
                            than one item on the canvas"
                }
                set args [lreplace $args 0 1]
            }
            default	{
                return -code error "unknown option \"$key\":\
                        should be -index or -item"
            }
        }
        set key [lindex $args 0]
    }
    if {[llength $args] != 1} {
        return -code error "wrong \# args: should be \"tooltip widget\
                ?-index index? ?-item item? message\""
    }
    if {$key eq ""} {
        clear $w
    } else {
        if {![winfo exists $w]} {
            return -code error "bad window path name \"$w\""
        }
        if {[info exists index]} {
            set tooltip($w,$index) $key
            #bindtags $w [linsert [bindtags $w] end "TooltipMenu"]
            return $w,$index
        } elseif {[info exists item]} {
            set tooltip($w,$item) $key
            #bindtags $w [linsert [bindtags $w] end "TooltipCanvas"]
            enableCanvas $w $item
            return $w,$item
        } else {
            set tooltip($w) $key
            bindtags $w [linsert [bindtags $w] end "Tooltip"]
            return $w
        }
    }
}

proc ::tooltip::clear {{pattern .*}} {
    variable tooltip
    foreach w [array names tooltip $pattern] {
        unset tooltip($w)
        if {[winfo exists $w]} {
            set tags [bindtags $w]
            if {[set i [lsearch -exact $tags "Tooltip"]] != -1} {
                bindtags $w [lreplace $tags $i $i]
            }
            ## We don't remove TooltipMenu because there
            ## might be other indices that use it
        }
    }
}

proc ::tooltip::show {w msg {i {}}} {
    # Use string match to allow that the help will be shown when
    # the pointer is in any child of the desired widget
    if {![winfo exists $w] || ![string match $w* [eval [list winfo containing] [winfo pointerxy $w]]]} {
        return
    }
    
    variable G
    
    set b $G(TOPLEVEL)
    $b.label configure -text $msg
    update idletasks
    if {$i eq "cursor"} {
        set y [expr {[winfo pointery $w]+20}]
        if {($y+[winfo reqheight $b])>[winfo screenheight $w]} {
            set y [expr {[winfo pointery $w]-[winfo reqheight $b]-5}]
        }
    } elseif {$i ne ""} {
        set y [expr {[winfo rooty $w]+[winfo vrooty $w]+[$w yposition $i]+25}]
        if {($y+[winfo reqheight $b])>[winfo screenheight $w]} {
            # show above if we would be offscreen
            set y [expr {[winfo rooty $w]+[$w yposition $i]-\
                        [winfo reqheight $b]-5}]
        }
    } else {
        set y [expr {[winfo rooty $w]+[winfo vrooty $w]+[winfo height $w]+5}]
        if {($y+[winfo reqheight $b])>[winfo screenheight $w]} {
            # show above if we would be offscreen
            set y [expr {[winfo rooty $w]-[winfo reqheight $b]-5}]
        }
    }
    if {$i eq "cursor"} {
        set x [winfo pointerx $w]
    } else {
        set x [expr {[winfo rootx $w]+[winfo vrootx $w]+\
                    ([winfo width $w]-[winfo reqwidth $b])/2}]
    }
    # only readjust when we would appear right on the screen edge
    if {$x<0 && ($x+[winfo reqwidth $b])>0} {
        set x 0
    } elseif {($x+[winfo reqwidth $b])>[winfo screenwidth $w]} {
        set x [expr {[winfo screenwidth $w]-[winfo reqwidth $b]}]
    }
    if {[tk windowingsystem] eq "aqua"} {
        set focus [focus]
    }
    wm geometry $b +$x+$y
    wm deiconify $b
    raise $b
    if {[tk windowingsystem] eq "aqua" && $focus ne ""} {
        # Aqua's help window steals focus on display
        after idle [list focus -force $focus]
    }
}

proc ::tooltip::menuMotion {w} {
    variable G
    
    if {$G(enabled)} {
        variable tooltip
        
        set cur [$w index active]
        # The next two lines (all uses of LAST) are necessary until the
        # <<MenuSelect>> event is properly coded for Unix/(Windows)?
        if {$cur == $G(LAST)} return
        set G(LAST) $cur
        # a little inlining - this is :hide
        after cancel $G(AFTERID)
        catch {wm withdraw $G(TOPLEVEL)}
        if {[info exists tooltip($w,$cur)] || \
                    (![catch {$w entrycget $cur -label} cur] && \
                    [info exists tooltip($w,$cur)])} {
            set G(AFTERID) [after $G(DELAY) \
                    [namespace code [list show $w $tooltip($w,$cur) $cur]]]
        }
    }
}

proc ::tooltip::hide {args} {
    variable G
    
    after cancel $G(AFTERID)
    catch {wm withdraw $G(TOPLEVEL)}
}

proc ::tooltip::wname {{w {}}} {
    variable G
    if {[llength [info level 0]] > 1} {
        # $w specified
        if {$w ne $G(TOPLEVEL)} {
            hide
            destroy $G(TOPLEVEL)
            set G(TOPLEVEL) $w
        }
    }
    return $G(TOPLEVEL)
}

proc ::tooltip::itemTip {w args} {
    variable tooltip
    variable G
    
    set G(LAST) -1
    set item [$w find withtag current]
    if {$G(enabled) && [info exists tooltip($w,$item)]} {
        set G(AFTERID) [after $G(DELAY) \
                [namespace code [list show $w $tooltip($w,$item) cursor]]]
    }
}

proc ::tooltip::enableCanvas {w args} {
    $w bind all <Enter> [namespace code [list itemTip $w]]
    $w bind all <Leave>		[namespace code hide]
    $w bind all <Any-KeyPress>	[namespace code hide]
    $w bind all <Any-Button>	[namespace code hide]
}


## tooltip.tcl loaded

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

