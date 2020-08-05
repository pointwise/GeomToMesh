#
# Copyright (c) 2019-2020 Pointwise, Inc.
# All rights reserved.
# 
# This sample Pointwise script is not supported by Pointwise, Inc.
# It is provided freely for demonstration purposes only.  
# SEE THE WARRANTY DISCLAIMER AT THE BOTTOM OF THIS FILE.
#
#
# GeomToMesh: Database Utilities
# 
# This script is part of the GeomToMesh Glyph script package. It
# provides utility functions for accessing meshing attributes
# attached to database entities.
#

set wd 80
set fmt "  | %-20.20s | %-10.10s | %-${wd}.${wd}s |"
set skipEntsWithoutAttrs 0
set showExtraEntInfo 1

# ----------------------------------------------
# Create a hyperlink to given entity. Used for reporting selectable entity
# names in the Pointwise Message Window.
# ----------------------------------------------
proc mkEntLink { ent { title "" } } {
    if [pw::Application isInteractive] {
        # create a pw hyperlink for the message window
        if { 0 == [string length $title] } {
            return "<a href='pwent://pwi.app?ents=$ent'>[$ent getName]</a>"
        } else {
            return "<a href='pwent://pwi.app?ents=$ent' title='$title'>[$ent getName]</a>"
        }
    } elseif { 0 < [string length $title] } {
        # return the input title for batch mode
        return $title
    } else {
        # just return the name for batch mode
        return [$ent getName]
    }
}

# ----------------------------------------------
# Create a hyperlink to given entity with a title attribute.
# ----------------------------------------------
proc toLink { ent } {
    set title "Entity is [expr { [$ent getEnabled] ? "visible" : "hidden" }]"
    return mkEntLink $ent $title
}

proc mkXYZLink { xyz } {
   if {[llength $xyz] != 3} { return $xyz }
   
   set xyzStr [format "%9.3e %9.3e %9.3e" [lindex $xyz 0] [lindex $xyz 1] [lindex $xyz 2]]
   if [pw::Application isInteractive] {
        return "<a href='pwpnt://pwi.app?loc=$xyz'>$xyzStr</a>"
   } else {
        # just return the XYZ for batch mode
        return $xyz
   }
}


# ----------------------------------------------
# Create names for given entities
# ----------------------------------------------
proc toNames { ents } {
    set ret [list]
    foreach ent $ents {
        if { [llength $ent] > 1 } {
            lappend ret [toNames $ent]
        } elseif { ! [string match {::pw::*} $ent] } {
            lappend ret $ent
        } else {
            lappend ret [toLink $ent]
      }
    }
    return $ret
}

# ----------------------------------------------
# Print value in formatted output
# ----------------------------------------------
proc dumpInfoItem { pfx val } {
    if { 0 != [llength [set val [string trim $val]]] } {
        puts [format "  %-6.6s: %s" $pfx [list $val]]
    }
}

# ----------------------------------------------
# Print extended database information
# ----------------------------------------------
proc dumpExtraInfo { dbEnt } {
    dumpInfoItem type [$dbEnt getType]
    dumpInfoItem isUV [$dbEnt isParametric]
    dumpInfoItem ref [toNames [$dbEnt getReferencingEntities]]
    dumpInfoItem sup [toNames [$dbEnt getSupportEntities]]

    switch -- [$dbEnt getDescription] {
        Edge -
        LinearSpline -
        TrimmedSurface {
            # NOP
        }
        BSplineSurface -
        Quilt -
        SolidModel -
        Model - {
            set cnt [$dbEnt getBoundaryCount]
            set bndrys [list]
            for { set ii 1 } { $ii <= $cnt } { incr ii } {
                lappend bndrys [$dbEnt getBoundary $ii]
            }
            dumpInfoItem bndry [toNames $bndrys]
        }
        default {
        }
    }
}

# ----------------------------------------------
# Print database entity attribute.
# ----------------------------------------------
proc dumpAttr { dbEnt name } {
    global fmt
    lassign [$dbEnt getImportedAttribute $name] aType aVal
    puts [format $fmt $name $aType $aVal ]
}

# ----------------------------------------------
# Print database entity attributes.
# ----------------------------------------------
proc dumpAttrs { dbEnt } {
    set attrNames ""
    # getAttributeDictionary does not exist before Pointwise V18.2
    if { ! [catch { pw::Database getAttributeDictionary -children $dbEnt "PW::Egads" } attrs] ||
         ! [catch { pw::Database getAttributeDictionary -children $dbEnt "PW::Data" }  attrs] } {
        set attrNames [dict keys $attrs]
    }

    if { 0 == [llength $attrNames] && $::skipEntsWithoutAttrs } {
        return
    }
    global fmt wd
    set dashes [string repeat - $wd]
    puts "\n[$dbEnt getDescription] [toLink $dbEnt]:"
    if { $::showExtraEntInfo } {
        dumpExtraInfo $dbEnt
    }
    if { 0 != [llength $attrNames] } {
        puts [format $fmt {Attribute Name} Type Value]
        puts [format $fmt $dashes $dashes $dashes]
        foreach attrName $attrNames {
            dumpAttr $dbEnt $attrName
        }
        puts [format $fmt $dashes $dashes $dashes]
    }
}

# ----------------------------------------------
# Get attribute value for given entity
# ----------------------------------------------
proc attributeValue { dbEnt entDesc phrase } {
    # Check entity
    if { $entDesc == [$dbEnt getDescription] } {
        # getAttributeDictionary does not exist before Pointwise V18.2
        if { ! [catch { pw::Database getAttributeDictionary -children $dbEnt "PW::Egads" } attrs] ||
             ! [catch { pw::Database getAttributeDictionary -children $dbEnt "PW::Data" }  attrs] } {
            if [dict exists $attrs $phrase] {
                return [dict get $attrs $phrase]
            }
        }
        # pre V18.2 attribute
        foreach attrName [$dbEnt getImportedAttributeNames] {
            if { $attrName == $phrase } {
                return [lindex [$dbEnt getImportedAttribute $attrName] 1]
            }
        }
    }

    # Check support entities
    foreach sup [$dbEnt getSupportEntities] {
        if { $entDesc == [$sup getDescription] } {
            # getAttributeDictionary does not exist before Pointwise V18.2
            if { ! [catch { pw::Database getAttributeDictionary -children $sup "PW::Egads" } attrs] ||
                 ! [catch { pw::Database getAttributeDictionary -children $sup "PW::Data" }  attrs] } {
                if [dict exists $attrs $phrase] {
                    return [dict get $attrs $phrase]
                }
            }
            # pre V18.2 attribute
            foreach attrName [$sup getImportedAttributeNames] {
                if { $attrName == $phrase } {
                    return [lindex [$sup getImportedAttribute $attrName] 1]
                }
            }
        }
    }

    return ""
}

# ----------------------------------------------
# Retrieve quilt names from geometry
# ----------------------------------------------
proc assembleTaggedQuilts { } {

    puts "Looking for quilt names in geometry."

    set QuiltList [pw::Database getAll -type "pw::Quilt"]
    puts "  Quilt list has [llength $QuiltList] entries."
  
    set QuiltNames [list]

    # Search geometry for quilt names
    set i 0
    foreach qlt $QuiltList {

        foreach dbEnt [$qlt getSupportEntities] {
            set qname [attributeValue $dbEnt "TrimmedSurface" "PW:QuiltName" ]
            if { "" != $qname } {
                puts "  Quilt [expr $i+1] of [llength $QuiltList] has name $qname."
                if { [lsearch $QuiltNames $qname] == -1 } {
                    lappend QuiltNames $qname
                } else {
                    puts "  ... already in QuiltNames list."
                }
            }
        }
        incr i
    }

    foreach qname $QuiltNames {
        puts "  Assembling quilts tagged with $qname"
        set quilts [list]
        foreach qlt $QuiltList {
            set dbEnts [$qlt getSupportEntities]

            foreach dbEnt $dbEnts {
                set name [attributeValue $dbEnt "TrimmedSurface" "PW:QuiltName" ]
                if { $qname == $name } {
                    lappend quilts $qlt
                    break
                }
            }
        }

        if { 1 < [llength $quilts] } {
            set assembleMode [pw::Application begin Modify $quilts]
            pw::Quilt assemble $quilts
            $assembleMode end
        }
    }
}

# ----------------------------------------------
# Get maximum model edge assembly tolerance
# ----------------------------------------------
proc getMaxModelEdgeTolerance { models } {
    set exam [pw::Examine create DatabaseEdgeTolerance]
    $exam addEntity $models
    $exam examine
    set maxEdgeTol [$exam getMaximum]
    $exam delete
    return $maxEdgeTol
}

# ----------------------------------------------
# Get maximum database edge tolerance
# ----------------------------------------------
proc maxDBEdgeTolerance { {verbose 1} } {

    if {$verbose} {
        puts "Computing maximum DB edge tolerance."
    }

    set exam [pw::Examine create DatabaseEdgeTolerance]

    set QuiltList [pw::Database getAll -type "pw::Quilt"]
    if {$verbose} {
        puts "  Quilt list has [llength $QuiltList] entries."
    }
  
    set tol 0.0
    foreach quilt $QuiltList {

        $exam clear
        $exam removeAll
        $exam addEntity $quilt
        $exam examine
        if { [catch {
            set ltol 0.0
            set tsurfs [$quilt getSurfaceTrims]
            foreach tsurf $tsurfs {
                set numEdges [$tsurf getBoundaryCount]
                for { set e 1 } { $e <= $numEdges } { incr e } {
                    set count [$exam getValueCount [list $tsurf $e]]
                    for { set i 1 } { $i <= $count } { incr i } {
                        set value [$exam getValue [list $tsurf $e] $i]
                        set ltol [expr max( $ltol, $value )]
                    }
                }
            }
            if {$verbose} {
                puts [format "  Quilt [$quilt getName]: edge tolerance = %.6g" $ltol]
            }
            set tol [expr max( $ltol, $tol )]
        } msg] } {
            puts "  * * * * * * * * * * * * * * * * * * * *"
            puts "  FAILED: $msg"
            puts "  * * * * * * * * * * * * * * * * * * * *\n\n"
        }
    }

    $exam delete

    if {$verbose} {
        puts [format "  Maximum DB edge tolerance = %.6g" $tol]
    }
    return $tol
}

proc getAssembleToleranceForCon {con} {
    if {![HaveConAssembleTolerance]} { return 0.0 }
    return [$con getAssembleTolerance]
}

#
# PROC: getObjectCmds
# Return a list of all static or instance commands for an object
#
# Example usage:
#   getObjectCmds pw::Connector 0 - returns list of static commands for pw::Connector
#   getObjectCmds pw::Connector 1 - returns list of instance commands for pw::Connector object
#
proc getObjectCmds { obj {instanceCommands 0}} {
    if {$instanceCommands} {
        set obj [$obj create]
    }
    catch {$obj _foo_} msg
    if {$instanceCommands} {
        $obj delete
    }
    set cmds [list]
    foreach s [lreplace [lreplace $msg 0 6] end-1 end-1] {
        lappend cmds [string trimright $s ","]
    }
    return $cmds
}


proc HaveConAssembleTolerance {} {
    global conData
    
    if {[info exists conData(haveAssembleTolCmd)]} {
        return $conData(haveAssembleTolCmd)
    }

    set conData(haveAssembleTolCmd) 0
    set conCmds [getObjectCmds pw::Connector 1]
    
    set ind [lsearch -exact $conCmds "getAssembleTolerance"]
    if {$ind != -1} {
        set conData(haveAssembleTolCmd) 1
    }

    return $conData(haveAssembleTolCmd)
}


proc getAssembleToleranceForCons {} {
    global conData
    
    set conData(minAssembleTol) 1e99
    set conData(maxAssembleTol) -1.0
    set conList [pw::Grid getAll -type pw::Connector]
    foreach con $conList {
        if {![info exists conData($con,assembleTol)]} {
            set conData($con,assembleTol) [getAssembleToleranceForCon $con]
        }
        if {$conData(minAssembleTol) > $conData($con,assembleTol)} {
            set conData(minAssembleTol) $conData($con,assembleTol)
            set conData(minAssembleTolCon) $con
        }
        if {$conData(maxAssembleTol) < $conData($con,assembleTol)} {
            set conData(maxAssembleTol) $conData($con,assembleTol)
            set conData(maxAssembleTolCon) $con
        }
    }
    puts "Min Edge Tol: [format "%9.3e" $conData(minAssembleTol)] on [mkEntLink $conData(minAssembleTolCon)]"
    puts "Max Edge Tol: [format "%9.3e" $conData(maxAssembleTol)] on [mkEntLink $conData(maxAssembleTolCon)]"
}

proc displayConAssembleTol {} {
    global conData
    
    if {![HaveConAssembleTolerance]} { return 0 }
    
    set conList [pw::Grid getAll -type pw::Connector]
    foreach con $conList {
        $con setRenderAttribute ColorMode Entity
        $con setRenderAttribute LineWidth 3
        $con setColor [scalarColor $conData($con,assembleTol) $conData(minAssembleTol) $conData(maxAssembleTol)]
        
        set tol [format "%5.1e" $conData($con,assembleTol)]
        set name [$con getName]
        append name "_$tol"
        $con setName $name
    }    
    return 1
}

# Determine color of a scalar value in blue-red rainbow color map
proc scalarColor {value minVal maxVal} {
    if {$value < $minVal} {
        # below range
        return "0.0 0.0 1.0"
    }
    if {$value > $maxVal} {
        # above range
        return "1.0 0.0 0.0"
    }
   
    set s [expr ($value - $minVal) / ($maxVal - $minVal)]

    if {$s <= 0.25} {
        set r 0.0
        set g [expr  $s / 0.25]
        set b 1.0
    } elseif {$s <= 0.5} {
        set r 0.0
        set g 1.0
        set b [expr (0.5 - $s) / 0.25]
    } elseif {$s <= 0.75} {
        set r [expr ($s - 0.5) / 0.25]
        set g 1.0
        set b 0.0
    } else {
        set r 1.0
        set g [expr (1.0 - $s) / 0.25]
        set b 0.0
    }
    return "$r $g $b"
}



# DISCLAIMER:
# TO THE MAXIMUM EXTENT PERMITTED BY APPLICABLE LAW, POINTWISE DISCLAIMS
# ALL WARRANTIES, EITHER EXPRESS OR IMPLIED, INCLUDING, BUT NOT LIMITED
# TO, IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR
# PURPOSE, WITH REGARD TO THIS SCRIPT.  TO THE MAXIMUM EXTENT PERMITTED 
# BY APPLICABLE LAW, IN NO EVENT SHALL POINTWISE BE LIABLE TO ANY PARTY 
# FOR ANY SPECIAL, INCIDENTAL, INDIRECT, OR CONSEQUENTIAL DAMAGES 
# WHATSOEVER (INCLUDING, WITHOUT LIMITATION, DAMAGES FOR LOSS OF 
# BUSINESS INFORMATION, OR ANY OTHER PECUNIARY LOSS) ARISING OUT OF THE 
# USE OF OR INABILITY TO USE THIS SCRIPT EVEN IF POINTWISE HAS BEEN 
# ADVISED OF THE POSSIBILITY OF SUCH DAMAGES AND REGARDLESS OF THE 
# FAULT OR NEGLIGENCE OF POINTWISE.
