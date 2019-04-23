#
# Copyright 2019 (c) Pointwise, Inc.
# All rights reserved.
#
# This sample Pointwise script is not supported by Pointwise, Inc.
# It is provided freely for demonstration purposes only.
# SEE THE WARRANTY DISCLAIMER AT THE BOTTOM OF THIS FILE.

#
# GeomToMesh: Meshing Utilities
#
# This script is part of the GeomToMesh Glyph script package. It
# provides most of the meshing utility functions.
#

# ----------------------------------------------
# Query the System Clock
# ----------------------------------------------
proc timestamp { } {
    puts [clock format [clock seconds] -format "%a %b %d %Y %l:%M:%S%p %Z"]
}

# ----------------------------------------------
# Convert Time in Seconds to h:m:s Format
# ----------------------------------------------
proc convSeconds { time } {
    set h [expr { int(floor($time/3600)) }]
    set m [expr { int(floor($time/60)) % 60 }]
    set s [expr { int(floor($time)) % 60 }]
    return [format "%02d Hours %02d Minutes %02d Seconds" $h $m $s]
}

set constants(pi) [expr 4.0*atan(1.0)]
set constants(rad2deg) [expr 180.0 / $constants(pi)]
set constants(deg2rad) [expr $constants(pi) / 180.0]

# ----------------------------------------------
# Delete a given element from a list
# ----------------------------------------------
proc lremove { varList value } {
    set idx [lsearch -exact $varList $value]
    set varList [lreplace $varList $idx $idx]
    return $varList
}

# ----------------------------------------------
# Get actual spacing at a given node on a con
# ----------------------------------------------
proc conGetActualSpacingAtNode { con node } {
    set dim [$con getDimension]
    if { $dim < 2 } {
        return 0.0
    } elseif { $dim == 2 } {
        return [$con getTotalLength]
    }
    if { [$con getNode Begin] == $node } {
        set xyz1 [$con getXYZ -grid 1]
        set xyz2 [$con getXYZ -grid 2]
    } elseif { [$con getNode End] == $node } {
        set xyz1 [$con getXYZ -grid $dim]
        set xyz2 [$con getXYZ -grid [expr $dim-1]]
    } else {
        return -code error "conGetActualSpacingAtNode: node not used [$con getName] [$node getName]"
    }
    return [pwu::Vector3 length [pwu::Vector3 subtract $xyz1 $xyz2]]
}

# ----------------------------------------------
# Get minimum spacing at a given node
# ----------------------------------------------
proc getMinSpacingAtNode { node } {
    set minSpc 1e9
    foreach c [$node getConnectors] {
        set curSpc [conGetActualSpacingAtNode $c $node]
        if { $curSpc < $minSpc } {
            set minSpc $curSpc
        }
    }
    return $minSpc
}

# ----------------------------------------------
# Calculate turning angle between connectors in radians
# ----------------------------------------------
proc calcTurnAngleBetweenCons { con0 con1 } {
    global constants
    set angle 0.0
    set c0n0 [$con0 getNode Begin]
    set c0n1 [$con0 getNode End]
    set c1n0 [$con1 getNode Begin]
    set c1n1 [$con1 getNode End]
    set dim0 [$con0 getDimension]
    set dim1 [$con1 getDimension]
    if { $c0n0 == $c1n0 } {
        set v0 [pwu::Vector3 subtract [$con0 getXYZ -grid 2] [$con0 getXYZ -grid 1]]
        set v1 [pwu::Vector3 subtract [$con1 getXYZ -grid 1] [$con1 getXYZ -grid 2]]
    } elseif { $c0n0 == $c1n1 } {
        set v0 [pwu::Vector3 subtract [$con0 getXYZ -grid 2] [$con0 getXYZ -grid 1]]
        set v1 [pwu::Vector3 subtract [$con1 getXYZ -grid $dim1] [$con1 getXYZ -grid [expr $dim1 - 1]]]
    } elseif { $c0n1 == $c1n0 } {
        set v0 [pwu::Vector3 subtract [$con0 getXYZ -grid [expr $dim0 - 1]] [$con0 getXYZ -grid $dim0]]
        set v1 [pwu::Vector3 subtract [$con1 getXYZ -grid 1] [$con1 getXYZ -grid 2]]
    } elseif { $c0n1 == $c1n1 } {
        set v0 [pwu::Vector3 subtract [$con0 getXYZ -grid [expr $dim0 - 1]] [$con0 getXYZ -grid $dim0]]
        set v1 [pwu::Vector3 subtract [$con1 getXYZ -grid $dim1] [$con1 getXYZ -grid [expr $dim1 - 1]]]
    } else {
       return -code error "calcTurnAngleBetweenCons - cons don't share a node"
    }

    set vn0 [pwu::Vector3 normalize $v0]
    set vn1 [pwu::Vector3 normalize $v1]
    set dot [pwu::Vector3 dot $vn0 $vn1]
    set angle [expr acos($dot)]

    return $angle
}

# ----------------------------------------------
# Set spacing at nodes
# ----------------------------------------------
proc setSpacingAtNodes { nodeSpacings { reduceOnly 0 } } {
    global domParams
    global constants

    if { 0 == [llength $nodeSpacings] } {
        return 0
    }

    # gather all the cons to be modified and start a modify mode
    foreach { node spacing } $nodeSpacings {
       foreach c [$node getConnectors] {
          set allCons($c) 1
       }
    }

    set modify [pw::Application begin Modify [array names allCons]]
    unset allCons

    set changed 0
    foreach { node spacing } $nodeSpacings {
        # clamp the spacing value
        set spacing [expr max($spacing,$domParams(MinEdge))]

        # get the cons at this node
        set cons [$node getConnectors]
        if { $reduceOnly } {
            if { [llength $cons] < 2 } {
                continue
            }
            if { [llength $cons] == 2 } {
                # check for a loop that has only two connectors
                set nodeOpp [[lindex $cons 0] getNode Begin]
                if { $nodeOpp == $node } {
                    set nodeOpp [[lindex $cons 0] getNode End]
                }
                set oppCons [$nodeOpp getConnectors]
                if { [llength $oppCons] == 2 } {
                    if { [lsort $oppCons] == [lsort $cons] } {
                        # two semi-circle cons
                        continue
                    }
                }

                # compute join angle in degrees, skip if turning angle is less than 35 deg
                set joinAngle [expr [calcTurnAngleBetweenCons [lindex $cons 0] [lindex $cons 1]] * $constants(rad2deg)]
                if { $joinAngle < 35.0 } {
                    continue
                }
            }
            foreach c $cons {
                set curSpc [conGetActualSpacingAtNode $c $node]
                if { $curSpc <= $spacing } {
                    # spacing is already less than maximum
                    continue
                }
                # set the spacing at the indicated end
                if { [$c getNode Begin] == $node } {
                    [$c getDistribution 1] setBeginSpacing $spacing
                    set changed 1
                }
                if { [$c getNode End] == $node } {
                    [$c getDistribution [$c getSubConnectorCount]] setEndSpacing $spacing
                    set changed 1
                }
            }
        } else {
            foreach c $cons {
                # set the spacing at the indicated end
                if { [$c getNode Begin] == $node } {
                    [$c getDistribution 1] setBeginSpacing $spacing
                    set changed 1
                }
                if { [$c getNode End] == $node } {
                    [$c getDistribution [$c getSubConnectorCount]] setEndSpacing $spacing
                    set changed 1
                }
            }
        }
    }
    $modify end
    return $changed
}

# ----------------------------------------------
# Decay spacing value over distance
# ----------------------------------------------
proc decaySpacing { sp distance decay spaceMax } {

    set value $sp

    set mag [expr $distance - $value * 2 * $decay]
    while { 0.0 < $mag && $value < $spaceMax } {
        set mag [expr $mag - $value * 2 * $decay]
        set value [expr $value * $decay]
    }

    return $value
}

# ----------------------------------------------
# Retrieve keyword and value from model geometry
# ----------------------------------------------
proc modelAttributeFromGeometry { keyword } {
    set dbEnts [pw::Database getAll]

    foreach dbEnt $dbEnts {
        set nVal [attributeValue $dbEnt "Model" $keyword ]
        if { 0 != [string length $nVal] } {
            return $nVal
        }
    }

    return ""
}

# ----------------------------------------------
# Retrieve keyword and value from node geometry
# ----------------------------------------------
proc nodeAttributeFromGeometry { node keyword } {
    set gridPoint [$node getPoint]

    # getAttributeDictionary does not exist before Pointwise V18.2
    if { ! [catch { pw::Database getAttributeDictionary -children $gridPoint "PW::Egads" } attrs] ||
         ! [catch { pw::Database getAttributeDictionary -children $gridPoint "PW::Data" }  attrs] } {
        if [dict exists $attrs $keyword] {
            return [dict get $attrs $keyword]
        }
    }

    return ""
}

# ----------------------------------------------
# Retrieve keyword and value from connector geometry
# ----------------------------------------------
proc conAttributeFromGeometry { con keyword } {
    set numSegs [$con getSegmentCount]
    for { set i 1 } { ! [info exists crv] && $i <= $numSegs } { incr i } {
        # guard against undefined connector segments
        set seg [$con getSegment $i]
        if [catch { $seg getCurve } crv] {
            unset crv
        }
    }

    if { ! [info exists crv] } {
        # failed to find segment curve
        set crv [lindex [$con getDatabaseEntities] 0]
    }

    # getAttributeDictionary does not exist before Pointwise V18.2
    if { ! [catch { pw::Database getAttributeDictionary -children $crv "PW::Egads" } attrs] ||
         ! [catch { pw::Database getAttributeDictionary -children $crv "PW::Data" }  attrs] } {
        if [dict exists $attrs $keyword] {
            return [dict get $attrs $keyword]
        }
    }

    return ""
}

# ----------------------------------------------
# Retrieve keyword and value from domain geometry
# ----------------------------------------------
proc domAttributeFromGeometry { dom keyword } {
    set dbEnts [$dom getDatabaseEntities]

    foreach dbEnt $dbEnts {
        set nVal [attributeValue $dbEnt "TrimmedSurface" $keyword]
        if { 0 != [string length $nVal] } {
            return $nVal
        }
    }

    return ""
}

# ----------------------------------------------
#  Create a source box from the extent the viscous domains
# ----------------------------------------------
proc createSourceBox { scale direction angle growthFactor decay bgsp } {
    puts "Create source box"
    set domList [pw::Grid getAll -type pw::DomainUnstructured]

    set exam [pw::Examine create DomainEdgeLength]

    set minX 1e20
    set maxX -1e20
    set minY 1e20
    set maxY -1e20
    set minZ 1e20
    set maxZ -1e20
    set num 0
    set avgds 0.0
    set minds 1.0e20
    set maxds 0.0
    set gmaxds 0.0
    foreach dom $domList {
        if { 1.0e-10 > $bgsp } {
            $exam clear
            $exam removeAll
            $exam addEntity $dom
            $exam examine
            set gmaxds [expr max($gmaxds , [$exam getMaximum])]
        }

        set sp [domAttributeFromGeometry $dom "PW:WallSpacing"]
        if { 0.0 < $sp } {
            $exam clear
            $exam removeAll
            $exam addEntity $dom
            $exam examine
            set minds [expr min($minds , [$exam getMinimum])]
            set maxds [expr max($maxds , [$exam getMaximum])]
            set avgds [expr ($avgds + [$exam getAverage])]
            incr num 1
            set extnt [$dom getExtents]
            set minExt [lindex $extnt 0]
            set maxExt [lindex $extnt 1]
            if { [lindex $minExt 0] < $minX } {
                set minX [lindex $minExt 0]
            }
            if { [lindex $minExt 1] < $minY } {
                set minY [lindex $minExt 1]
            }
            if { [lindex $minExt 2] < $minZ } {
                set minZ [lindex $minExt 2]
            }
            if { [lindex $maxExt 0] > $maxX } {
                set maxX [lindex $maxExt 0]
            }
            if { [lindex $maxExt 1] > $maxY } {
                set maxY [lindex $maxExt 1]
            }
            if { [lindex $maxExt 2] > $maxZ } {
                set maxZ [lindex $maxExt 2]
            }
        }
    }
    $exam delete

    if { $minX > $maxX } {
        return
    }
    puts [format "  Extents: %.6g < X < %.6g" $minX $maxX]
    puts [format "  Extents: %.6g < Y < %.6g" $minY $maxY]
    puts [format "  Extents: %.6g < Z < %.6g" $minZ $maxZ]

    set avgds [expr $avgds / $num]
    puts [format "  Minimum domain edge length = %.6g" $minds]
    puts [format "  Average domain edge length = %.6g" $avgds]
    puts [format "  Maximum domain edge length = %.6g" $maxds]

    puts [format "  Global maximum domain edge length = %.6g" $gmaxds]
    if { 1.0e-10 > $bgsp } {
        set bgsp $gmaxds
    }
    puts [format "  Background spacing = %.6g" $bgsp]

    set dx [expr $maxX - $minX]
    set dy [expr $maxY - $minY]
    set dz [expr $maxZ - $minZ]
    set midx [expr 0.5*($minX + $maxX)]
    set midy [expr 0.5*($minY + $maxY)]
    set midz [expr 0.5*($minZ + $maxZ)]
    set bminx [expr ($midx - 0.75 * $dx)]
    set bminy [expr ($midy - 0.75 * $dy)]
    set bminz [expr ($midz - 0.75 * $dz)]
    set bmaxx [expr ($midx + 0.75 * $dx)]
    set bmaxy [expr ($midy + 0.75 * $dy)]
    set bmaxz [expr ($midz + 0.75 * $dz)]

    puts [format "  Source box extents: %.6g < X %.6g" $bminx $bmaxx]
    puts [format "  Source box extents: %.6g < Y %.6g" $bminy $bmaxy]
    puts [format "  Source box extents: %.6g < Z %.6g" $bminz $bmaxz]

    puts "  direction = $direction"
    set xmag [lindex $direction 0]
    set ymag [lindex $direction 1]
    set zmag [lindex $direction 2]
    set mag [expr sqrt($xmag*$xmag + $ymag*$ymag + $zmag*$zmag)]
    if { $mag > 1.0e-15 } {
        set xmag [expr $xmag / $mag]
        set ymag [expr $ymag / $mag]
        set zmag [expr $zmag / $mag]
    }
    puts [format "  normalized direction = %.6g %.6g %.6g" $xmag $ymag $zmag]

    if { [expr abs($xmag)] > [expr abs($ymag)] && [expr abs($xmag)] > [expr abs($zmag)] } {
        if { $xmag >= 0.0 } {
            set maindirection +X
        } else {
            set maindirection -X
        }
    }
    if { [expr abs($ymag)] > [expr abs($xmag)] && [expr abs($ymag)] > [expr abs($zmag)] } {
        if { $ymag >= 0.0 } {
            set maindirection +Y
        } else {
            set maindirection -Y
        }
    }
    if { [expr abs($zmag)] > [expr abs($xmag)] && [expr abs($zmag)] > [expr abs($ymag)] } {
        if { $zmag >= 0.0 } {
            set maindirection +Z
        } else {
            set maindirection -Z
        }
    }

    set toRadians [expr 4.0 * atan(1.0) / 180.0]

    puts "  maindirection = $maindirection"

    set vx $xmag
    set vy $ymag
    set vz $zmag
    # set length, width and height directions
    switch -- $maindirection {
        -X {
               set olength [expr $bmaxx - $bminx]
               set width [expr $bmaxy - $bminy]
               set height [expr $bmaxz - $bminz]
               set Alpha [expr atan($zmag / abs($xmag))]
               set Beta [expr atan(-1.0 * $ymag / abs($xmag))]
               puts "Alpha = [expr $Alpha / $toRadians] degrees"
               puts "Beta = [expr $Beta / $toRadians] degrees"
               set cA [expr cos($Alpha)]
               set sA [expr sin($Alpha)]
               set cB [expr cos($Beta)]
               set sB [expr sin($Beta)]
               set rx [expr (-1.0 * $sB)]
               set ry [expr $cB]
               set rz 0
               set rightVec [ list $rx $ry $rz ]
               puts "rightVec = $rightVec"
               set ux [expr $vy * $rz - $vz * $ry]
               set uy [expr $vz * $rx - $vx * $rz]
               set uz [expr $vx * $ry - $vy * $rx]
               set upVec [ list $ux $uy $uz ]
               puts "upVec = $upVec"
               set tX $bmaxx
               set tY [expr $midy + $sB * abs($bmaxx - $midx)]
               set tZ [expr $midz - $sA * abs($bmaxx - $midx)]
           }
        +X {
               set olength [expr $bmaxx - $bminx]
               set width [expr $bmaxy - $bminy]
               set height [expr $bmaxz - $bminz]
               set Alpha [expr atan($zmag / abs($xmag))]
               set Beta [expr atan($ymag / abs($xmag))]
               puts "Alpha = [expr $Alpha / $toRadians] degrees"
               puts "Beta = [expr $Beta / $toRadians] degrees"
               set cA [expr cos($Alpha)]
               set sA [expr sin($Alpha)]
               set cB [expr cos($Beta)]
               set sB [expr sin($Beta)]
               set rx [expr (-1.0 * $sB)]
               set ry $cB
               set rz 0
               set rightVec [ list $rx $ry $rz ]
               puts "rightVec = $rightVec"
               set ux [expr $vy * $rz - $vz * $ry]
               set uy [expr $vz * $rx - $vx * $rz]
               set uz [expr $vx * $ry - $vy * $rx]
               set upVec [ list $ux $uy $uz ]
               puts "upVec = $upVec"
               set tX $bminx
               set tY [expr $midy - $sB * abs($bminx - $midx)]
               set tZ [expr $midz - $sA * abs($bminx - $midx)]
           }
        -Y {
               set olength [expr $bmaxy - $bminy]
               set width [expr $bmaxx - $bminx]
               set height [expr $bmaxz - $bminz]
               set Alpha [expr atan($zmag / abs($ymag))]
               set Beta [expr atan($xmag / abs($ymag))]
               puts "Alpha = [expr $Alpha / $toRadians] degrees"
               puts "Beta = [expr $Beta / $toRadians] degrees"
               set cA [expr cos($Alpha)]
               set sA [expr sin($Alpha)]
               set cB [expr cos($Beta)]
               set sB [expr sin($Beta)]
               set rx [expr (-1.0 * $cB)]
               set ry [expr (-1.0 * $sB)]
               set rz 0
               set rightVec [ list $rx $ry $rz ]
               puts "rightVec = $rightVec"
               set ux [expr $vy * $rz - $vz * $ry]
               set uy [expr $vz * $rx - $vx * $rz]
               set uz [expr $vx * $ry - $vy * $rx]
               set upVec [ list $ux $uy $uz ]
               puts "upVec = $upVec"
               set tX [expr $midx - $sB * abs($bminy - $midy)]
               set tY $bmaxy
               set tZ [expr $midz - $sA * abs($bminy - $midy)]
           }
        +Y {
               set olength [expr $bmaxy - $bminy]
               set width [expr $bmaxx - $bminx]
               set height [expr $bmaxz - $bminz]
               set Alpha [expr atan($zmag / abs($ymag))]
               set Beta [expr atan(-1.0 * $xmag / abs($ymag))]
               puts "Alpha = [expr $Alpha / $toRadians] degrees"
               puts "Beta = [expr $Beta / $toRadians] degrees"
               set cA [expr cos($Alpha)]
               set sA [expr sin($Alpha)]
               set cB [expr cos($Beta)]
               set sB [expr sin($Beta)]
               set rx [expr (-1.0 * $cB)]
               set ry [expr (-1.0 * $sB)]
               set rz 0
               set rightVec [ list $rx $ry $rz ]
               puts "rightVec = $rightVec"
               set ux [expr $vy * $rz - $vz * $ry]
               set uy [expr $vz * $rx - $vx * $rz]
               set uz [expr $vx * $ry - $vy * $rx]
               set upVec [ list $ux $uy $uz ]
               puts "upVec = $upVec"
               set tX [expr $midx + $sB * abs($bminy - $midy)]
               set tY $bminy
               set tZ [expr $midz - $sA * abs($bminy - $midy)]
           }
        -Z {
               set olength [expr $bmaxz - $bminz]
               set width [expr $bmaxx - $bminx]
               set height [expr $bmaxy - $bminy]
               set Alpha [expr atan($ymag / abs($zmag))]
               set Beta [expr atan($xmag / abs($zmag))]
               puts "Alpha = [expr $Alpha / $toRadians] degrees"
               puts "Beta = [expr $Beta / $toRadians] degrees"
               set cA [expr cos($Alpha)]
               set sA [expr sin($Alpha)]
               set cB [expr cos($Beta)]
               set sB [expr sin($Beta)]
               set rx [expr (-1.0 * $cB)]
               set ry 0
               set rz [expr (-1.0 * $sB)]
               set rightVec [ list $rx $ry $rz ]
               puts "rightVec = $rightVec"
               set ux [expr $vy * $rz - $vz * $ry]
               set uy [expr $vz * $rx - $vx * $rz]
               set uz [expr $vx * $ry - $vy * $rx]
               set upVec [ list $ux $uy $uz ]
               puts "upVec = $upVec"
               set tX [expr $midx - $sB * abs($bminz - $midz)]
               set tY [expr $midy - $sA * abs($bminz - $midz)]
               set tZ $bmaxz
           }
        +Z {
               set olength [expr $bmaxz - $bminz]
               set width [expr $bmaxx - $bminx]
               set height [expr $bmaxy - $bminy]
               set Alpha [expr atan($ymag / abs($zmag))]
               set Beta [expr atan(-1.0 * $xmag / abs($zmag))]
               puts "Alpha = [expr $Alpha / $toRadians] degrees"
               puts "Beta = [expr $Beta / $toRadians] degrees"
               set cA [expr cos($Alpha)]
               set sA [expr sin($Alpha)]
               set cB [expr cos($Beta)]
               set sB [expr sin($Beta)]
               set rx [expr (-1.0 * $cB)]
               set ry 0
               set rz [expr (-1.0 * $sB)]
               set rightVec [ list $rx $ry $rz ]
               puts "rightVec = $rightVec"
               set ux [expr $vy * $rz - $vz * $ry]
               set uy [expr $vz * $rx - $vx * $rz]
               set uz [expr $vx * $ry - $vy * $rx]
               set upVec [ list $ux $uy $uz ]
               puts "upVec = $upVec"
               set tX [expr $midx + $sB * abs($bmaxz - $midz)]
               set tY [expr $midy - $sA * abs($bmaxz - $midz)]
               set tZ $bminz
           }
        default {
               set olength [expr $bmaxx - $bminx]
               set width [expr $bmaxy - $bminy]
               set height [expr $bmaxz - $bminz]
               set rightVec { 0 1 0 }
               set upVec { 0 0 1 }
               set tX $bminx
               set tY $midy
               set tZ $midz
          }
    }

    if { $width > $height } {
        set height [expr max($height, 0.5 * $width)]
    }
    if { $height > $width } {
        set width [expr max($width, 0.5 * $height)]
    }
    set length [expr $scale * $olength]
    set sineAngle [expr sin($angle * $toRadians)]
    set topwidth [expr $width + ($sineAngle * $length)]
    set topheight [expr $height + ($sineAngle * $length)]

    puts [format "  Source box length = %.6g" $length]
    puts [format "  Source box width = %.6g" $width]
    puts [format "  Source box height = %.6g" $height]

    set mode [pw::Application begin Create]
        set sourceBox [pw::SourceShape create]
        $sourceBox box -width $width -height $height -topWidth $topwidth -topHeight $topheight -length $length
        $sourceBox setBaseType Plane
        $sourceBox setSectionMinimum 0
        $sourceBox setSectionMaximum 360

        set trans [pwu::Transform identity]
        set trans [pwu::Transform translate $trans "$tX $tY $tZ"]
        set rotTrans [pwu::Transform rotation $rightVec $upVec]
        set trans [pwu::Transform multiply $trans $rotTrans]
        $sourceBox setTransform $trans
        $sourceBox setPivot Base
        $sourceBox setSidesType Plane
        $sourceBox setBaseType Plane
        $sourceBox setTopType Plane

        set begsp [expr 0.5 * ($minds + $maxds)]
        set endsp [expr min( $bgsp, $begsp * $growthFactor)]
        puts [format "  Source box beginning spacing = %.6g" $begsp]
        puts [format "  Source box ending spacing = %.6g" $endsp]
        $sourceBox setBeginSpacing $begsp
        $sourceBox setEndSpacing $endsp
        $sourceBox setBeginDecay $decay
        $sourceBox setEndDecay $decay
    $mode end
}

# ----------------------------------------------
#  Create a outer box model by scaling the extent the existing geometry
# ----------------------------------------------
proc createOuterBox { scale } {

    set dbEnts [pw::Database getAll]
    set extnt [pw::Database getExtents -visibleOnly]
    puts "Create outer box"
    puts "  Geometry extents = $extnt"

    set minExt [lindex $extnt 0]
    set maxExt [lindex $extnt 1]
    set dx [expr [lindex $maxExt 0] - [lindex $minExt 0]]
    set dy [expr [lindex $maxExt 1] - [lindex $minExt 1]]
    set dz [expr [lindex $maxExt 2] - [lindex $minExt 2]]
    set ds [expr max( $dx, max( $dy, $dz))]
    set midx [expr 0.5*([lindex $minExt 0] + [lindex $maxExt 0])]
    set midy [expr 0.5*([lindex $minExt 1] + [lindex $maxExt 1])]
    set midz [expr 0.5*([lindex $minExt 2] + [lindex $maxExt 2])]
    set bminx [expr ($midx - $scale * $ds)]
    set bminy [expr ($midy - $scale * $ds)]
    set bminz [expr ($midz - $scale * $ds)]
    set bmaxx [expr ($midx + $scale * $ds)]
    set bmaxy [expr ($midy + $scale * $ds)]
    set bmaxz [expr ($midz + $scale * $ds)]

    set length [expr $bmaxz - $bminz]
    set width [expr $bmaxx - $bminx]
    set height [expr $bmaxy - $bminy]
    set topwidth $width
    set topheight $height

    set mlist [list]
    set mode [pw::Application begin Create]
        set outerBox [pw::Shape create]
        $outerBox box -width $width -height $height -topWidth $topwidth -topHeight $topheight -length $length
        $outerBox setBaseType Plane
        $outerBox setSectionMinimum 0
        $outerBox setSectionMaximum 360

        set trans [pwu::Transform identity]
        set trans [pwu::Transform translate $trans "$midx $midy $midz"]
        $outerBox setTransform $trans
        $outerBox setPivot Center
        $outerBox setSidesType Plane
        $outerBox setBaseType Plane
        $outerBox setTopType Plane
        set mlist [$outerBox createModels]
        pw::Entity delete $outerBox
    $mode end

    set nmodels [llength $mlist]
    puts "  Outer Box created $nmodels models."
    # rename quilts for later identification
    if { 1 == [llength $mlist] } {
        set mod [lindex $mlist 0]
        set qlist [$mod getQuilts]
        set i 0
        foreach q $qlist {
            incr i 1
            puts "  Quilt $i is named [$q getName]"
            set newname OuterBox_${i}
            puts "  New name is $newname"
            $q setName $newname
        }
    }
}

# ----------------------------------------------
# Retrieve periodic instruction attributes from geometry
# ----------------------------------------------
proc setupPeriodicDomains { tol targetDomListVar } {
    upvar $targetDomListVar targetDomList

    puts "Looking for periodic domain attributes from geometry."
    puts [format "  Tolerance = %.6g" $tol]

    set domList [pw::Grid getAll -type pw::DomainUnstructured]

    set rotateList [list]
    set translateList [list]
    set deleteList [list]

    # look for source and target domains
    set i 0
    foreach dom $domList {

        set target [domAttributeFromGeometry $dom "PW:PeriodicTarget"]
        if { "true" == $target } {
            lappend deleteList $dom
        }

        set tv [domAttributeFromGeometry $dom "PW:PeriodicTranslate"]
        if { [llength $tv] == 3 } {
            puts "  Periodic translation vector found for domain [expr $i+1], tv = $tv"
            lassign $tv tx ty tz
            if { $tx > $tol || $ty > $tol || $tz > $tol } {
                lappend translateList [list $dom $tv]
            }
        }

        set pr [domAttributeFromGeometry $dom "PW:PeriodicRotate"]
        if { [llength $pr] == 7 } {
            puts "  Periodic rotation vector found for domain [expr $i+1], pr = $pr"
            lassign $pr px py pz nx ny nz angle
            if { [string is double -strict $px] &&
                   [string is double -strict $py] &&
                   [string is double -strict $pz] &&
                   [string is double -strict $nx] &&
                   [string is double -strict $ny] &&
                   [string is double -strict $nz] &&
                   [string is double -strict $angle] && [expr abs($angle)] > $tol } {
                lappend rotateList [list $dom $pr]
            }
        }

        incr i 1
    }

    if { [llength $deleteList] > 0 } {
        puts "  Deleting domains in periodic delete list"
        pw::Entity delete $deleteList
    }

    foreach trans $translateList {
        lassign $trans dom tv
        set pmode [pw::Application begin Create]
            $dom createPeriodic -translate $tv
            set tdom [$dom getPeriodic]
            lappend targetDomList $tdom
        $pmode end
    }

    foreach rot $rotateList {
        lassign $rot dom pr
        lassign $pr px py pz nx ny nz angle
        set pmode [pw::Application begin Create]
            $dom createPeriodic -rotate [list $px $py $pz] [list $nx $ny $nz] $angle
            set tdom [$dom getPeriodic]
            lappend targetDomList $tdom
        $pmode end
    }
}

# ----------------------------------------------
# Retrieve domain attributes from geometry
# ----------------------------------------------
proc loadDomainAttributes { } {
    global domParams

    set domList [pw::Grid getAll -type pw::DomainUnstructured]

    set i 0
    foreach dom $domList {
        puts "Domain [expr $i+1] of [llength $domList]:"

        # look for boundary names
        set name [domAttributeFromGeometry $dom "PW:Name"]
        if { 0 < [string length $name] } {
            puts "  boundary name = $name."
            if [catch { pw::BoundaryCondition getByName $name } bc] {
                puts "    Creating boundary name $name"
                set bc [pw::BoundaryCondition create]
                $bc setName $name
            } else {
                puts "    $name already in boundary name list."
            }
            $bc apply $dom
        } else {
            # look for periodic conditions
            set pdom [$dom getPeriodic]
            if { 0 < [string length $pdom] } {
                set name [domAttributeFromGeometry $pdom "PW:Name"]
                if { 0 < [string length $name] } {
                    puts "  periodic boundary name = $name."
                    if [catch { pw::BoundaryCondition getByName $name } bc] {
                        puts "    Creating boundary name $name"
                        set bc [pw::BoundaryCondition create]
                        $bc setName $name
                    } else {
                        puts "    $name already in boundary name list."
                    }
                    $bc apply $dom
                }
            } else {
                # look for OuterBox geometry
                set dbEnts [$dom getDatabaseEntities]
                foreach db $dbEnts {
                    if [$db isOfType pw::Quilt] {
                        set name [$db getName]
                        puts "  quilt name is $name"
                        if [catch { pw::BoundaryCondition getByName $name } bc] {
                            puts "    Creating boundary name $name"
                            set bc [pw::BoundaryCondition create]
                            $bc setName $name
                        } else {
                            puts "    $name already in boundary name list."
                        }
                        $bc apply $dom
                    }
                }
            }
        }

        # look for mesh algorithm
        set algorithm [domAttributeFromGeometry $dom "PW:DomainAlgorithm"]
        switch -- $algorithm {
            Delaunay -
            AdvancingFront -
            AdvancingFrontOrtho {
                puts "  mesh algorithm = $algorithm."
                $dom setUnstructuredSolverAttribute Algorithm $algorithm
            }
        }

        # look for domain cell types
        set type [domAttributeFromGeometry $dom "PW:DomainIsoType"]
        switch -- $type {
            Triangle -
            TriangleQuad {
                puts "  cell type = $type."
                $dom setUnstructuredSolverAttribute IsoCellType $type
            }
        }

        # look for min edge length
        set minlength [domAttributeFromGeometry $dom "PW:DomainMinEdge"]
        if { "Boundary" == $minlength || ([string is double -strict $minlength] && $domParams(MinEdge) < $minlength) } {
            puts [format "  minimum equilateral edge length = %.6g." $minlength]
            $dom setUnstructuredSolverAttribute EdgeMinimumLength $minlength
        }

        # look for max edge length
        set maxlength [domAttributeFromGeometry $dom "PW:DomainMaxEdge"]
        if { "Boundary" == $maxlength || ([string is double -strict $maxlength] && $domParams(MaxEdge) > $maxlength) } {
            puts [format "  maximum equilateral edge length = %.6g." $maxlength]
            $dom setUnstructuredSolverAttribute EdgeMaximumLength $maxlength
        }

        # look for max angle
        set maxangle [domAttributeFromGeometry $dom "PW:DomainMaxAngle"]
        if { [string is double -strict $maxangle] && 0.0 <= $maxangle } {
            puts [format "  maximum angle = %.6g." $maxangle]
            $dom setUnstructuredSolverAttribute NormalMaximumDeviation $maxangle
        }

        # look for max deviation
        set maxdeviation [domAttributeFromGeometry $dom "PW:DomainMaxDeviation"]
        if { [string is double -strict $maxdeviation] && 0.0 <= $maxdeviation } {
            puts [format "  maximum deviation = %.6g." $maxdeviation]
            $dom setUnstructuredSolverAttribute SurfaceMaximumDeviation $maxdeviation
        }

        # look for swap cell
        set swapcells [domAttributeFromGeometry $dom "PW:DomainSwapCells"]
        if { [string is boolean -strict $swapcells] } {
            puts "  swap cells = $swapcells."
            $dom setUnstructuredSolverAttribute SwapCellsWithNoInteriorPoints $swapcells
        }

        # look for quad max included angle
        set quadmaxangle [domAttributeFromGeometry $dom "PW:DomainQuadMaxAngle"]
        if { [string is double -strict $quadmaxangle] && 0.0 <= $quadmaxangle } {
            puts "  quad maximum included angle = $quadmaxangle."
            $dom setUnstructuredSolverAttribute QuadMaximumIncludedAngle $quadmaxangle
        }

        # look for quad max warp angle
        set quadmaxwarp [domAttributeFromGeometry $dom "PW:DomainQuadMaxWarp"]
        if { [string is double -strict $quadmaxwarp] && 0.0 <= $quadmaxwarp } {
            puts [format "  quad maximum warp angle = %.6g." $quadmaxwarp]
            $dom setUnstructuredSolverAttribute QuadMaximumWarpAngle $quadmaxwarp
        }

        # look for surface decay
        set decay [domAttributeFromGeometry $dom "PW:DomainDecay"]
        if { [string is double -strict $decay] && 0.0 <= $decay } {
            puts [format "  boundary decay = %.6g." $decay]
            $dom setUnstructuredSolverAttribute BoundaryDecay $decay
        }

        # look for T-Rex max layers
        set maxlayers [domAttributeFromGeometry $dom "PW:DomainMaxLayers"]
        if { [string is integer -strict $maxlayers] && 0 <= $maxlayers } {
            puts [format "  T-Rex max layers = %d." [expr int($maxlayers)]]
            $dom setUnstructuredSolverAttribute TRexMaximumLayers [expr int($maxlayers)]
        }

        # look for T-Rex full layers
        set fulllayers [domAttributeFromGeometry $dom "PW:DomainFullLayers"]
        if { [string is integer -strict $fulllayers] && 0 <= $fulllayers } {
            puts [format "  T-Rex full layers = %d." [expr int($fulllayers)]]
            $dom setUnstructuredSolverAttribute TRexFullLayers [expr int($fulllayers)]
        }

        # look for T-Rex growth rate
        set growthrate [domAttributeFromGeometry $dom "PW:DomainTRexGrowthRate"]
        if { [string is double -strict $growthrate] && 1.0 <= $growthrate } {
            puts [format "  T-Rex growth rate = %.6g." $growthrate]
            $dom setUnstructuredSolverAttribute TRexGrowthRate $growthrate
        }

        # look for T-Rex cell type
        set type [domAttributeFromGeometry $dom "PW:DomainTRexType"]
        switch -- $type {
            Triangle -
            TriangleQuad {
                puts "  T-Rex cell type = $type."
                $dom setUnstructuredSolverAttribute TRexCellType $type
            }
        }

        # look for T-Rex isotropic height
        set height [domAttributeFromGeometry $dom "PW:DomainTRexIsoHeight"]
        if { [string is double -strict $height] && 0.0 < $height } {
            puts [format "  T-Rex isotropic height = %.6g." $height]
            $dom setUnstructuredSolverAttribute TRexIsotropicHeight $height
        }

        incr i 1
    }
}

# ----------------------------------------------
# Test connectors for close proximity to other connectors.  For each connector,
# compute distance-decayed spacing from other connectors, and increase
# dimension accodingly if spacing is too large.
# ----------------------------------------------
proc connectorProximitySpacing { decay conMinDim conMaxDim conList nodeListVar nodeSpacingVar } {
    upvar $nodeListVar nodeList
    upvar $nodeSpacingVar nodeSpacing
    global conData

    puts "Adjusting connector dimensions based on proximity to other connectors."

    # store initial spacing for each connector
    set conSpacing [list]
    set modify [pw::Application begin Modify $conList]

    foreach con $conList {
        set dim [$con getDimension]
            set newdim $dim
            set dimChanged 0
            if { $newdim < $conData($con,minDim) } {
                set newdim $conData($con,minDim)
                set dimChanged 1
            }
            if { $newdim > $conData($con,maxDim) } {
                set newdim $conData($con,maxDim)
                set dimChanged 1
            }
            if { $dimChanged } {
                $con setDimension $newdim
            }
        set sp [$con getAverageSpacing]
        lappend conSpacing [list $con $sp]
    }

    set numcons [llength $conList]

    # check spacing of current connector with all connectors not attached
    for { set i 0 } { $i < $numcons } { incr i } {
        set con [lindex [lindex $conSpacing $i] 0]
        set sp [lindex [lindex $conSpacing $i] 1]
        puts "  Proximity test for connector [expr $i+1]/$numcons, [$con getName]."

        # determine minimum decayed spacing from shorter connectors
        set dim [$con getDimension]
        set minsp [expr 1.1*$sp]
        set k -1
        for { set j 0 } { $j < $numcons } { incr j } {

            if { $j != $i } {
                set tcon [lindex [lindex $conSpacing $j] 0]
                set tsp [lindex [lindex $conSpacing $j] 1]
                if { $tsp < $minsp } {
                    set minDS 1.0e20
                    for { set n 2 } { $n < $dim } { incr n } {
                        set pt [$con getXYZ -grid $n]
                        set dp [$tcon closestPoint -distance ds $pt]
                        if { $ds < $minDS } {
                            set minDS $ds
                        }
                    }
                    # decay spacing over distance
                    set newsp [decaySpacing $tsp $minDS $decay $sp]
                    if { $newsp < $minsp } {
                        set minsp $newsp
                    }
                }
            }
        }

        # if decayed spacing is smaller then re-dimension connector
        if { $minsp < $sp } {
            set newdim [$con setDimensionFromSpacing $minsp]
            set dimChanged 0
            if { $newdim < $conData($con,minDim) } {
                set newdim $conData($con,minDim)
                set dimChanged 1
            }
            if { $newdim > $conData($con,maxDim) } {
                set newdim $conData($con,maxDim)
                set dimChanged 1
            }
            if { $dimChanged } {
                $con setDimension $newdim
            }
            set newsp [$con getAverageSpacing]

            puts [format "    Connector dimension changed from %d to %d, avg. spacing changed from %.6g to %.6g" \
                $dim $newdim $sp $newsp]

            set node [$con getNode Begin]
            set k [lsearch $nodeList $node]
            if { -1 != $k } {
                if { [lindex $nodeSpacing $k] > $newsp } {
                    set nodeSpacing [lreplace $nodeSpacing $k $k $newsp]
                }
            }

            set node [$con getNode End]
            set k [lsearch $nodeList $node]
            if { -1 != $k } {
                if { [lindex $nodeSpacing $k] > $newsp } {
                    set nodeSpacing [lreplace $nodeSpacing $k $k $newsp]
                }
            }
        }
    }

    $modify end
}

# ----------------------------------------------
# Create source cloud from connector interval spacing
# ----------------------------------------------
proc CreateSourceFromConSpacing { cons decay } {
    global trexConData domParams
    set exam [pw::Examine create ConnectorEdgeLength]
    set pointData ""
    foreach cn $cons {
        $exam clear
        $exam removeAll
        $exam addEntity $cn
        $exam examine

        set ARLimit 1.0
        if [info exists trexConData($cn,initDs)] {
            # TRex con - adjust target spacing for ARLimit
            set initDs $trexConData($cn,initDs)
            set inv_initDs [expr 1.0 / $initDs]
            if { $trexConData($cn,edgeType) == "HARD" } {
                set ARLimit $domParams(HardEdgeTRexARLimit)
            } else {
                set ARLimit $domParams(TRexARLimit)
            }
            set ARLimit [expr max(1.0, $ARLimit)]
            set inv_ARLimit [expr 1.0 / $ARLimit]
        }

        set count [$exam getValueCount]
        for { set i 1 } { $i <= $count } { incr i } {
            set spacing [$exam getValue $cn $i]

            if { $ARLimit > 1.0 } {
                # TRex con - adjust target spacing to meet ARLimit
                set curAR [expr $spacing * $inv_initDs]
                set factor [expr $spacing * $inv_initDs * $inv_ARLimit]
                if { $factor > 1.1 } {
                    set spacing [expr $spacing / $factor]
                    set npts [expr int($factor+0.5)+1]
                    set delta [expr 1.0 / ($npts-1)]
                    for { set ipt 0 } { $ipt < $npts } { incr ipt } {
                        set w [expr 1.0 * $ipt * $delta]
                        set xyz  [pwu::Vector3 add  \
                            [pwu::Vector3 scale [$exam getXYZ $cn $i] [expr 1.0-$w]] \
                            [pwu::Vector3 scale [$exam getXYZ $cn [expr $i+1]] $w]]
                        lappend pointData [list $xyz $spacing $decay]
                    }
                } else {
                    set xyz [pwu::Vector3 scale [pwu::Vector3 add \
                        [$exam getXYZ $cn $i] [$exam getXYZ $cn [expr $i+1]]] 0.5]
                    lappend pointData [list $xyz $spacing $decay]
                }
            } else {
                set xyz [pwu::Vector3 scale [pwu::Vector3 add \
                    [$exam getXYZ $cn $i] [$exam getXYZ $cn [expr $i+1]]] 0.5]
                lappend pointData [list $xyz $spacing $decay]
            }
        }
    }
    $exam delete

    set cloud ""
    if [llength $pointData] {
        # source data exists, proceed with refinement
        set cloud [pw::SourcePointCloud create]
        $cloud addPoints $pointData
    }

    return $cloud
}

# ----------------------------------------------
# Source-based connector spacing update
# ----------------------------------------------
proc connectorSourceSpacing { decay { useCachedBgSpacing 0 } } {
    global conBgSpacingCache domParams

    puts "Adapt connectors"

    if { ! $useCachedBgSpacing } {
        catch { unset conBgSpacingCache }
    }

    set conList [pw::Grid getAll -type pw::Connector]
    set exam [pw::Examine create ConnectorEdgeLength]

    foreach cn $conList {
        set conData($cn,bbox) [$cn getExtents]
        $exam clear
        $exam removeAll
        $exam addEntity $cn
        $exam examine
        set conData($cn,minSpacing) [$exam getMinimum]
        set conData($cn,maxSpacing) [$exam getMaximum]
        set conData($cn,avgSpacing) [$exam getAverage]
        set conData($cn,npts) [$cn getDimension]
    }
    $exam delete

    set cloud [CreateSourceFromConSpacing $conList $decay]
    if { $cloud != "" } {
        set name "con spacing source"
        $cloud setName $name
        set numcons [llength $conList]
        set i 0
        set modify [pw::Application begin Modify $conList]
        foreach cn $conList {
            incr i 1
            puts "  Point cloud test for connector $i/$numcons, [$cn getName]."
            set dim [$cn getDimension]
            set bgSpacing $conData($cn,avgSpacing)
            set bgSpacing $conData($cn,maxSpacing)
            if { $useCachedBgSpacing && [info exists conBgSpacingCache($cn)] } {
                set bgSpacing $conBgSpacingCache($cn)
            }
            set maxEdgeLength [conAttributeFromGeometry $cn "PW:ConnectorMaxEdge"]
            if { "" != $maxEdgeLength && $domParams(MinEdge) < $maxEdgeLength && $bgSpacing > $maxEdgeLength } {
               set bgSpacing $maxEdgeLength
            }

            set maxEdgeLength $domParams(MaxEdge)
            if { $domParams(MinEdge) < $maxEdgeLength && $bgSpacing > $maxEdgeLength } {
               set bgSpacing $maxEdgeLength
            }

            set conBgSpacingCache($cn) $bgSpacing
            pw::Connector setDimensionFromSizeField -include $cloud \
                 -backgroundSpacing $bgSpacing -defaultDecay $decay \
                 -calculationMethod MinimumValue $cn
            set newdim [$cn getDimension]
            if { $newdim != $dim } {
              puts [format "    Connector adaptation %s %d point%s" \
                  [expr { ($newdim < $dim) ? {removed} : {added} }] \
                  [expr abs($dim - $newdim)] \
                  [expr { (abs($dim - $newdim) == 1) ? {} : {s} }]]
            }
        }
        $modify end
        $cloud delete
    }

    # sync node spacing
    set exam [pw::Examine create ConnectorEdgeLength]
    set nodeSpacing [list]
    foreach cn $conList {
        set conData($cn,bbox) [$cn getExtents]
        $exam clear
        $exam removeAll
        $exam addEntity $cn
        $exam examine

        set node [$cn getNode Begin]
        set ind [lsearch -exact $nodeSpacing $node]
        set spacing [$exam getValue $cn 1]
        if { $ind < 0 } {
            lappend nodeSpacing $node $spacing
        } else {
            incr ind
            set curSpc [lindex $nodeSpacing $ind]
            if { $spacing < $curSpc } {
                set nodeSpacing [lreplace $nodeSpacing $ind $ind $spacing]
            }
        }

        set node [$cn getNode End]
        set ind [lsearch -exact $nodeSpacing $node]
        set spacing [$exam getValue $cn [$exam getValueCount]]
        if { $ind < 0 } {
            lappend nodeSpacing $node $spacing
        } else {
            incr ind
            set curSpc [lindex $nodeSpacing $ind]
            if { $spacing < $curSpc } {
                set nodeSpacing [lreplace $nodeSpacing $ind $ind $spacing]
            }
        }
    }
    $exam delete

    # adjust the spacings
    setSpacingAtNodes $nodeSpacing 0
}

# ----------------------------------------------
# Merge connectors that have the same two endpoints and dimension and if the
# middle points are the same within a tolerance.
# ----------------------------------------------
proc connectorMergeUsingEndpoints { conList } {

    puts "Performing merge on connectors with equal dimensions and common end points."

    set replaceList [list]

    foreach con $conList {
        set condim [$con getDimension]
        set n0 [$con getNode Begin]
        set n1 [$con getNode End]
        set len [$con getLength -parameter 1.0]
        set tol [expr $len / ($condim-1.0) * 0.25]

        set n0cons [$n0 getConnectors]
        set n1cons [$n1 getConnectors]

        # select connector at n0 not equal to current with same dimension
        foreach con0 $n0cons {
            if { ($con0 != $con) && ($condim == [$con0 getDimension]) } {
                # search for same connector at n1
                foreach con1 $n1cons {
                    if { $con0 == $con1 } {

                        # check forward match
                        set match_f 0
                        if { $n0 == [$con0 getNode Begin] && $n1 == [$con0 getNode End] } {
                            set match_f 1
                            for { set n 2 } { $n < $condim } { incr n } {
                                set pt0 [$con getXYZ -grid $n]
                                set pt1 [$con1 getXYZ -grid $n]
                                set ds [pwu::Vector3 length [pwu::Vector3 subtract $pt0 $pt1]]
                                if { $ds > $tol } {
                                    set match_f 0
                                    break
                                }
                            }
                        }

                        # check backward match
                        set match_b 0
                        if { $n1 == [$con0 getNode Begin] && $n0 == [$con0 getNode End] } {
                            set match_b 1
                            for { set n 2 } { $n < $condim } { incr n } {
                                set m [expr $condim - $n + 1]
                                set pt0 [$con getXYZ -grid $n]
                                set pt1 [$con1 getXYZ -grid $m]
                                set ds [pwu::Vector3 length [pwu::Vector3 subtract $pt0 $pt1]]
                                if { $ds > $tol } {
                                    set match_b 0
                                    break
                                }
                            }
                        }

                        # if either direction is a match then add to merge list
                        if { 1 == $match_f || 1 == $match_b } {
                            # has it been save already?
                            set flag 0
                            foreach pair $replaceList {
                                set p0 [lindex $pair 0]
                                set p1 [lindex $pair 1]

                                if { $p0 == $con && $p1 == $con1 } {
                                    set flag 1
                                } elseif { $p1 == $con && $p0 == $con1 } {
                                    set flag 1
                                }
                                if { $flag == 1 } {
                                    break
                                }
                            }

                            # add to list
                            if { $flag == 0 } {
                                lappend replaceList [list $con $con1]
                            }
                        }
                    }
                }
            }
        }
    }

    set nmerge [llength $replaceList]
    if { 0 < $nmerge } {
        puts "  Number of merge pairs identified = $nmerge"

        set mergeMode [pw::Application begin Merge]
            foreach pair $replaceList {
                lassign $pair con0 con1
                puts "  Replacing [$con1 getName] with [$con0 getName]"
                $mergeMode replace $con0 $con1
            }
        $mergeMode end
    }

    return $nmerge
}

# ----------------------------------------------
# Compute connector min & max spacing
# ----------------------------------------------
proc CalcConMinMaxSpacing { con } {
    set exam_conLength [pw::Examine create ConnectorEdgeLength]
    $exam_conLength addEntity $con
    $exam_conLength examine
    set rtn [list [$exam_conLength getMinimum] [$exam_conLength getMaximum]]
    $exam_conLength delete
    return $rtn
}

# ----------------------------------------------
# Get domain database entities
# ----------------------------------------------
proc GetDomDbEnts { dom } {
    set dbEnts [list]
    if [$dom isOfType pw::DomainUnstructured] {
        set constraint [$dom getUnstructuredSolverAttribute ShapeConstraint]
        if { $constraint == "Free" } {
            return [list]
        }
        if { $constraint == "Database" } {
            # default ents
            set dbEnts [$dom getDatabaseEntities -solver]
        } else {
            # explicit ent list
            set dbEnts $constraint
        }
    } elseif [$dom isOfType pw::DomainStructured] {
        set constraint [$dom getEllipticSolverAttribute ShapeConstraint]
        if { $constraint == "Free" || $constraint == "Fixed" } {
            return [list]
        }
        if { $constraint == "Database" } {
            # default ents
            set dbEnts [$dom getDatabaseEntities -solver]
        } else {
            # explicit ent list
            set dbEnts $constraint
        }
    }

    # only associate dom faces with surface entities
    set surfEnts [list]
    foreach db $dbEnts {
        if [$db isSurface] {
            lappend surfEnts $db
        }
    }
    set dbEnts $surfEnts

    if { [llength $dbEnts] == 0 } {
      return $dbEnts
    }

    set domEnts [list]

    foreach ent $dbEnts {
        if [$ent isOfType pw::Quilt] {
            # expand quilt into list of constituent trimmed surfaces
            set quiltEnts [list]
            set nsurf [$ent getSurfaceTrimCount]
            for { set isurf 1 } { $isurf <= $nsurf } { incr isurf } {
                set surf [$ent getSurfaceTrim $isurf]
                lappend quiltEnts $surf
            }
            if { [llength $quiltEnts] == 0 } {
                return -code error "bad quilt [$ent getName]"
            }
            foreach qEnt $quiltEnts {
                lappend domEnts $qEnt
            }
       } else {
           lappend domEnts $ent
       }
    }

    return $domEnts
}

# ----------------------------------------------
# Redimension connectors if turning angle or deviation is defined
# ----------------------------------------------
proc increaseConnectorDimensionFromAngleDeviationQuilts { conList conMaxDim conTurnAngle conDeviation } {
    global topo conParams trexConData domParams
    global conData
    set topo(TRexSurfCurvCons) [list]
    set topo(TRexHardEdgeCons) [list]
    set dimRatioTol 2.0
    #
    # NOTE: distribution is reset to equal spacing
    #
    if { 0.0 < $conTurnAngle || 0.0 < $conDeviation } {
        puts "Adjusting connector dimensions based on turning angles and/or deviation."
        set checkForSurfaceCurvatureCons 0
        if { 0 < $domParams(MaxLayers) } {
            # Use TRex layers to capture surface curvature at domain boundaries
            set checkForSurfaceCurvatureCons 1
        }

        if { $checkForSurfaceCurvatureCons } {
            # dimension by curve curvature
            set conMode [pw::Application begin Modify $conList]
                set i 0
                foreach con $conList {
                    set sp [$con getAverageSpacing]
                    incr i 1
                    set dim [$con getDimension]
                    if { $dim == $conData($con,maxDim) } {
                        # dimension can't be increased
                        puts "  skipping connector [mkEntLink $con] (maxDim)"
                        continue
                    }
                    set newdim [$con increaseDimension $conTurnAngle $conDeviation]
                    set dimChanged 0
                    if { $newdim < $conData($con,minDim) } {
                        set newdim $conData($con,minDim)
                        set dimChanged 1
                    }
                    if { $newdim > $conData($con,maxDim) } {
                        set newdim $conData($con,maxDim)
                        set dimChanged 1
                    }
                    if { $dimChanged } {
                        $con setDimension $newdim
                    }
                    set curveDevDist($con) [[$con getDistribution 1] copy]
                    if { $newdim > $dim } {
                        set newsp [$con getAverageSpacing]
                        puts [format "  Connector $i/[llength $conList]. Dim changed from %d to %d.\
                              Spacing changed from %.6g to %.6g." $dim $newdim $sp $newsp]
                    }
                }
            $conMode end

            #    -------------------------
            #   |     Join connectors    |
            #    -------------------------

            # perform join operation and eliminate breakpoints
            if { 0 < [joinConnectors $conParams(SplitAngle)] } {
                set conList [pw::Grid getAll -type pw::Connector]
                puts "  After join, connector list has [llength $conList] entries."

                # some connectors were joined, repeat curve-based deviation
                catch { unset curveDevDist }
                set conMode [pw::Application begin Modify $conList]
                    set i 0
                    foreach con $conList {
                        set sp [$con getAverageSpacing]
                        incr i 1
                        set dim [$con getDimension]

                        if { $dim == $conData($con,maxDim) } {
                            # dimension can't be increased
                            puts "  skipping connector [mkEntLink $con] (maxDim)"
                            continue
                        }

                        set newdim [$con increaseDimension $conTurnAngle $conDeviation]
                        set dimChanged 0
                        if { $newdim < $conData($con,minDim) } {
                            set newdim $conData($con,minDim)
                            set dimChanged 1
                        }
                        if { $newdim > $conData($con,maxDim) } {
                            set newdim $conData($con,maxDim)
                            set dimChanged 1
                        }
                        if { $dimChanged } {
                            $con setDimension $newdim
                        }
                        set curveDevDist($con) [[$con getDistribution 1] copy]
                        if { $newdim > $dim } {
                            set newsp [$con getAverageSpacing]
                            puts [format "  Connector $i/[llength $conList]. Dim changed from %d to %d.\
                              Spacing changed from %.6g to %.6g." $dim $newdim $sp $newsp]
                        }
                    }
                $conMode end
            }

            # dimension by curve and surface curvature
            set conMode [pw::Application begin Modify $conList]
                set i 0
                foreach con $conList {

                    set sp [$con getAverageSpacing]
                    incr i 1
                    set dim [$con getDimension]
                    if { $dim == $conData($con,maxDim) } {
                        # dimension can't be increased
                        puts "  skipping connector [mkEntLink $con] (maxDim)"
                        continue
                    }

                    set conTurnOnlyDim $dim
                    set newdim [$con increaseDimension -surface $conTurnAngle $conDeviation]
                    if { $newdim < $conData($con,minDim) } {
                        set newdim $conData($con,minDim)
                    }
                    if { $newdim > $conData($con,maxDim) } {
                        set newdim $conData($con,maxDim)
                    }

                    set dimRatio [expr 1.0*$newdim / $conTurnOnlyDim]
                    if { $dimRatio > $dimRatioTol } {
                        # A connector which increased dimension considerably
                        # due to surface curvature
                        puts "  *** TRex con: [mkEntLink $con]"
                        puts "    curve-based dim: $conTurnOnlyDim"
                        puts "    surface-based dim: $newdim"
                        puts [format "    crv/srf dim ratio: %.6g" $dimRatio]

                        # Use curve-based dimension and mark as TRexSurfCurvCon
                        set mult [expr max(1.0, $dimRatio / 10.0)]
                        set newdim [expr int($conTurnOnlyDim * $mult + 0.5)]

                        lappend topo(TRexSurfCurvCons) $con

                        # Use curve-based distribution
                        $con replaceDistribution 1 $curveDevDist($con)

                        # Record spacing data for use when computing TRex InitDs
                        set avgSpc [$con getAverageSpacing]
                        lassign [CalcConMinMaxSpacing $con] minSpc maxSpc
                        # maximum spacing which satisfies the turning angle criteria
                        set trexConData($con,spacing) [expr $maxSpc/$domParams(TRexARLimit)]
                        set trexConData($con,minSurfSpacing) $minSpc
                        set trexConData($con,maxSurfSpacing) $maxSpc
                        set trexConData($con,avgSurfSpacing) $avgSpc
                        set trexConData($con,dimRatio) $dimRatio
                    } else {
                        puts "  con: [mkEntLink $con]"
                        puts "    curve-based dim: $conTurnOnlyDim"
                        puts "    surface-based dim: $newdim"
                        puts [format "    dim ratio: %.6g" $dimRatio]
                    }
                    $con setDimension $newdim

                    if { $newdim > $dim } {
                        set newsp [$con getAverageSpacing]
                        puts [format "  Connector $i/[llength $conList]. Dim changed from %d to %d.\
                          Spacing changed from %.6g to %.6g." $dim $newdim $sp $newsp]
                    }
                }
            $conMode end
        } else {
            set conMode [pw::Application begin Modify $conList]
                set i 0
                foreach con $conList {
                    # dimension by curve and surface curvature
                    set dim [$con getDimension]
                    if { $dim == $conData($con,maxDim) } {
                        # dimension can't be increased
                        continue
                    }

                    set sp [$con getAverageSpacing]
                    incr i 1

                    set newdim [$con increaseDimension -surface $conTurnAngle $conDeviation]
                    set dimChanged 0
                    if { $newdim < $conData($con,minDim) } {
                        set newdim $conData($con,minDim)
                        set dimChanged 1
                    }
                    if { $newdim > $conData($con,maxDim) } {
                        set newdim $conData($con,maxDim)
                        set dimChanged 1
                    }
                    if { $dimChanged } {
                        $con setDimension $newdim
                    }
                    # $con replaceDistribution 1 [pw::DistributionTanh create]
                    if { $newdim > $dim } {
                        set newsp [$con getAverageSpacing]
                        puts [format "  Connector $i/[llength $conList]. Dim changed from %d to %d.\
                          Spacing changed from %.6g to %.6g." $dim $newdim $sp $newsp]
                    }

                }
            $conMode end
        }
    }

    if { 0 < $domParams(MaxLayers) } {
        # Use TRex layers to capture hard edges at domain boundaries
        FindHardEdgeCons $conList

        DeconflictSurfCurvHardEdgeCons

        # Alter display of TRex surface curvature connectors
        DisplaySurfCurvatureCons

        # Alter display of TRex hard edge connectors
        DisplayHardEdgeCons
    }
}

# ----------------------------------------------
# Change display of curvature-based connectors
# ----------------------------------------------
proc DisplaySurfCurvatureCons { } {
    global topo genParams
    set group [pw::Group create]
    $group setName TRex_SurfCurvature_cons
    $group setEntityType pw::Connector
    $group addEntity $topo(TRexSurfCurvCons)
    if { $genParams(displayTRexCons) } {
        set col [pw::Collection create]
        $col set $topo(TRexSurfCurvCons)
        $col do setRenderAttribute ColorMode Entity
        $col do setRenderAttribute LineWidth 5
        $col do setColor "#ff0000"
        $col delete
        pw::Display update
    }
}

# ----------------------------------------------
# Change display of hard-edge connectors
# ----------------------------------------------
proc DisplayHardEdgeCons { } {
    global topo genParams
    set group [pw::Group create]
    $group setName TRex_HardEdge_cons
    $group setEntityType pw::Connector
    $group addEntity $topo(TRexHardEdgeCons)

    if { ! $genParams(displayTRexCons) } {
        return
    }

    set col [pw::Collection create]
    $col set $topo(TRexHardEdgeCons)
    $col do setRenderAttribute ColorMode Entity
    $col do setRenderAttribute LineWidth 5
    $col do setColor "#FBFF33"
    $col delete

    pw::Display update
}

# ----------------------------------------------
# Get all edges of domain
# ----------------------------------------------
proc getDomEdges { dom } {
    set edges [list]
    set nedges [$dom getEdgeCount]
    for { set ie 1 } { $ie <= $nedges } { incr ie } {
        lappend edges [$dom getEdge $ie]
    }
    return $edges
}

# ----------------------------------------------
# Get all connectors of domain
# ----------------------------------------------
proc getDomCons { dom } {
    set conList [list]
    set nedges [$dom getEdgeCount]
    for { set ie 1 } { $ie <= $nedges } { incr ie } {
        set ed [$dom getEdge $ie]
        set ncons [$ed getConnectorCount]
        for { set ic 1 } { $ic <= $ncons } { incr ic } {
            set con [$ed getConnector $ic]
            if { -1 == [lsearch $conList $con] } {
                lappend conList $con
            }
        }
    }

    return $conList
}

# ----------------------------------------------
# Get all domains of connectors
# ----------------------------------------------
proc getDomsFromCons { cons } {
    set doms [pw::Domain getDomainsFromConnectors $cons]
    return $doms
}

# ----------------------------------------------
# Get all connectors with hard edges
# ----------------------------------------------
proc FindHardEdgeCons { cons } {
    global topo constants conParams

    if { $conParams(TurnAngleHard) <= 0.0 } {
        return
    }

    set turnTol [expr cos($conParams(TurnAngleHard)*$constants(deg2rad))]

    puts "FindHardEdgeCons"
    foreach con $cons {
        # set doms [pw::Domain getDomainsFromConnectors $con]
        set doms [getDomsFromCons $con]
        if { [llength $doms] != 2 } {
           continue
        }
        set dim [$con getDimension]
        if { 2 >= $dim } {
            continue
        }

        # Get Db ents associated with the domains
        set domDbEnts1 [GetDomDbEnts [lindex $doms 0]]
        set domDbEnts2 [GetDomDbEnts [lindex $doms 1]]

        if { 0 == [llength $domDbEnts1] || 0 == [llength $domDbEnts2] } {
            continue
        }

        # Walk along con interior grid points
        # Project to domain db surface
        # Get surface normals
        # Calculate turning angle
        set minDot 2.0
        set numProjFail 0
        set numExceedTol 0
        set FailNorm [expr 1.0 / ($dim-2)]
        set fractionProjFail [expr 0.5* $numProjFail * $FailNorm]
        set fractionExceed [expr 1.0*$numExceedTol * $FailNorm]
        for { set i 2 } { $i < $dim } { incr i } {
            set xyz [$con getXYZ $i]
            set dom1Pt [pw::Database closestPoint -explicit $domDbEnts1 -state state1 $xyz]
            if { ! $state1 } {
                incr numProjFail
                set fractionProjFail [expr 0.5* $numProjFail * $FailNorm]
                continue
            }
            set dom2Pt [pw::Database closestPoint -explicit $domDbEnts2 -state state2 $xyz]
            if { ! $state2 } {
                incr numProjFail
                set fractionProjFail [expr 0.5* $numProjFail * $FailNorm]
                continue
            }

            set norm1 [pw::Database getNormal $dom1Pt]
            set norm2 [pw::Database getNormal $dom2Pt]

            set norm1 [pwu::Vector3 normalize $norm1]
            set norm2 [pwu::Vector3 normalize $norm2]
            set dot   [pwu::Vector3 dot $norm1 $norm2]
            if { $dot < $minDot } {
                set minDot $dot
            }
            if { $dot < $turnTol } {
                incr numExceedTol
                set fractionExceed [expr 1.0*$numExceedTol * $FailNorm]
                if { $fractionProjFail < 0.2 && $fractionExceed > 0.5 } {
                    break
                }
            } else {
                if { [expr (1.0 - ($i-2) * $FailNorm) + $fractionExceed] < 0.5 } {
                    # IF    amount remaining to test  +  amount exceed   < 0.5
                    # THEN  con will not qualify as hard edge
                    break
                }
            }
        }

        if { $fractionProjFail < 0.2 && $fractionExceed > 0.5 } {
            puts "  *** Hard Edge CON [mkEntLink $con]"
            # Mark as TRexHardEdgeCon
            lappend topo(TRexHardEdgeCons) $con
        } else {
            puts "   con: [mkEntLink $con]"
        }
        set angle [expr acos( max(-1.0, min(1.0,$minDot)) ) * $constants(rad2deg)]
        puts [format "     Fail  : %4.1f" [expr $fractionProjFail*100]]
        puts [format "     Exceed: %d / %d = %4.1f" $numExceedTol [expr $dim-2] [expr $fractionExceed*100]]
        puts [format "     max turning angle: %.6g" $angle]
    }
}

# ----------------------------------------------
# Computes the Set Containing the Intersection of Set1 & Set2
# ----------------------------------------------
proc intersect { set1 set2 } {
    set set3 [list]
    foreach item $set1 {
        set count($item) 0
    }
    foreach item $set2 {
        if [info exists count($item)] {
            lappend set3 $item
        }
    }
    return $set3
}

# ----------------------------------------------
# Deconflict the two connector lists
# ----------------------------------------------
proc DeconflictSurfCurvHardEdgeCons { } {
    global topo
    set TRexSurfCurvCons [lsort -unique $topo(TRexSurfCurvCons)]
    set TRexHardEdgeCons [lsort -unique $topo(TRexHardEdgeCons)]

    # Remove hard edge cons from surf curve con list
    set intersectCons [intersect $TRexSurfCurvCons $TRexHardEdgeCons]
    foreach con $intersectCons {
        set ind [lsearch -exact $TRexSurfCurvCons $con]
        if { -1 != $ind } {
            set TRexSurfCurvCons [lreplace $TRexSurfCurvCons $ind $ind]
        }
    }
    set topo(TRexSurfCurvCons) $TRexSurfCurvCons
    set topo(TRexHardEdgeCons) $TRexHardEdgeCons
}

# ----------------------------------------------
# set up 2D TRex boundaries for quilts
# ----------------------------------------------
proc setup2DTRexBoundariesQuilts { domList fullLayers maxLayers growthRate boundaryDecay } {
    global topo trexConData domParams
    set meshChanged 0
    set TRexSurfCurvCons [lsort -unique $topo(TRexSurfCurvCons)]
    set TRexHardEdgeCons [lsort -unique $topo(TRexHardEdgeCons)]
    #
    # set T-Rex domain boundary conditions
    # based on surface curvature and hard edges
    #
    puts "Setting up T-Rex domain boundary conditions."

    # Leading edge cons (surface curvature based)

    foreach con $TRexSurfCurvCons {
        # Compute a InitDs which satisfies surface curvature requirement
        # for most of the cells along the boundary
        set initDs [expr 0.5 * ($trexConData($con,minSurfSpacing) + $trexConData($con,avgSurfSpacing))]

        # Spacing on cons incident to this one
        set ndSpc1 [getMinSpacingAtNode [$con getNode Begin]]
        set ndSpc2 [getMinSpacingAtNode [$con getNode End]]
        set ndSpc [expr min($ndSpc1,$ndSpc2)]

        # This could violate the ARLimit, but it's more important to match neighbors
        # We will correct for ARLimit in ConSourceSpacing
        set initDs [expr min( $initDs , $ndSpc )]

        # Clamp to minimum allowed edge length
        set initDs [expr max( $initDs , $domParams(MinEdge) )]

        # Push to nodes keeping smallest value
        foreach end [list Begin End] {
            set node [$con getNode $end]
            if [info exists softEdgeNodes($node)] {
                set initDs [expr min($initDs, $softEdgeNodes($node))]
            }
            set softEdgeNodes($node) $initDs
        }
    }
    foreach con $TRexSurfCurvCons {
        set initDs 1e20
        foreach end [list Begin End] {
            set node [$con getNode $end]
            set initDs [expr min($initDs, $softEdgeNodes($node))]
        }
        set trexConData($con,initDs) $initDs
        set trexConData($con,edgeType) "SMOOTH"
    }
    foreach con $TRexSurfCurvCons {
        set doms [getDomsFromCons $con]
        foreach dom $doms {
            set doDomTRex 0
            set edges [getDomEdges $dom]
            foreach ed $edges {
                set numcons [$ed getConnectorCount]
                for { set i 1 } { $i <= $numcons } { incr i } {
                    set edge_con [$ed getConnector $i]
                    if { $con != $edge_con } {
                        continue
                    }
                    # create a T-Rex wall BC for the connector if needed
                    set name [$con getName]
                    # getByName returns an error if no BC with that name exists
                    if [catch { pw::TRexCondition getByName $name } bc] {
                        set bc [pw::TRexCondition create]
                        $bc setName $name
                        $bc setConditionType Wall
                        $bc setSpacing $trexConData($con,initDs)
                    } elseif { [expr abs($trexConData($con,initDs) - [$bc getSpacing])] > 0.00001 } {
                        puts [format "[$bc getName] old spacing = %.6g new spacing = %.6g" \
                            [$bc getSpacing] $trexConData($con,initDs)]
                        $bc setSpacing $trexConData($con,initDs)
                    }
                    # apply the BC
                    $bc apply [list [list $dom $con]]
                    set doDomTRex 1
                }
            }
            if { $doDomTRex } {
                # Enable TRex for this domain
                enableDomTRexAtts $dom $fullLayers $maxLayers  $growthRate $boundaryDecay
                set meshChanged 1
            }
        }
    }

    # Hard edge cons (turning angle based)

    # Get current spacing at hard edge endpoints
    foreach con $TRexHardEdgeCons {
        set name [$con getName]

        # Spacing on cons incident to this one
        set ndSpc1 [getMinSpacingAtNode [$con getNode Begin]]
        set ndSpc2 [getMinSpacingAtNode [$con getNode End]]
        set initDs [expr min($ndSpc1,$ndSpc2)]
        # This could violate the ARLimit, but it's more important to match neighbors
        # We will correct for ARLimit in ConSourceSpacing

        # Clamp to minimum allowed edge length
        set initDs [expr max( $initDs , $domParams(MinEdge) )]

        foreach end [list Begin End] {
            set node [$con getNode $end]
            if [info exists hardEdgeNodes($node)] {
                set initDs [expr min($initDs, $hardEdgeNodes($node))]
            }
            set hardEdgeNodes($node) $initDs
        }
    }

    # Determine AR of hard edges with current endspacing
    foreach con $TRexHardEdgeCons {
        set initDs 1e20
        foreach end [list Begin End] {
            set node [$con getNode $end]
            set initDs [expr min($initDs, $hardEdgeNodes($node))]
        }

        set avgSpc [$con getAverageSpacing]
        set conAR($con) [expr $avgSpc/$initDs]
    }

    # Recursively determine highest incident connector AR for each node
    set ARChanged 1
    while { $ARChanged } {
        set ARChanged 0
        foreach con $TRexHardEdgeCons {
            foreach end [list Begin End] {
                set node [$con getNode $end]
                if [info exists hardEdgeNodesAR($node)] {
                    if { $conAR($con) > $hardEdgeNodesAR($node) } {
                        set ARChanged 1
                        set hardEdgeNodesAR($node) $conAR($con)
                    } elseif { $conAR($con) < $hardEdgeNodesAR($node) } {
                        set ARChanged 1
                        set conAR($con)  $hardEdgeNodesAR($node)
                    }
                } else {
                    set ARChanged 1
                    set hardEdgeNodesAR($node) $conAR($con)
                }
            }
        }
    }

    # Reduce TRex initDs to satisfy HardEdgeTargetAR
    # Only do so if all incident cons have smaller AR
    set nodes [array names hardEdgeNodes]
    foreach node $nodes {
        set factor [expr $hardEdgeNodesAR($node) / $domParams(HardEdgeTargetAR)]
        if { $factor < 1.0 } {
            set hardEdgeNodes($node) [expr $hardEdgeNodes($node) * $factor]
        }
    }

    foreach con $TRexHardEdgeCons {
        set initDs 1e20
        foreach end [list Begin End] {
            set node [$con getNode $end]
            set initDs [expr min($initDs, $hardEdgeNodes($node))]
        }
        set trexConData($con,initDs) $initDs
        set trexConData($con,edgeType) "HARD"
    }

    foreach con $TRexHardEdgeCons {
        set doms [getDomsFromCons $con]
        foreach dom $doms {
            set doDomTRex 0
            set edges [getDomEdges $dom]
            foreach ed $edges {
                set numcons [$ed getConnectorCount]
                for { set i 1 } { $i <= $numcons } { incr i } {
                    set edge_con [$ed getConnector $i]
                    if { $con != $edge_con } {
                        continue
                    }
                    # create a T-Rex wall BC for the connector if needed
                    set name [$con getName]
                    # getByName returns an error if no BC with that name exists
                    if { [catch { pw::TRexCondition getByName $name } bc] } {
                        set bc [pw::TRexCondition create]
                        $bc setName $name
                        $bc setConditionType Wall
                        $bc setSpacing $trexConData($con,initDs)
                    } elseif { [expr abs($trexConData($con,initDs) - [$bc getSpacing])] > 0.00001 } {
                        puts [format "[$bc getName] old spacing = %.6g new spacing = %.6g" \
                            [$bc getSpacing] $trexConData($con,initDs)]
                        $bc setSpacing $trexConData($con,initDs)
                    }
                    $bc apply [list [list $dom $con]]
                    set doDomTRex 1
                }
            }
            if { $doDomTRex } {
                # Enable TRex for this domain
                enableDomTRexAtts $dom $fullLayers $maxLayers $growthRate $boundaryDecay
                set meshChanged 1
            }
        }
    }

    if { $meshChanged } {
        set meshChanged 0; # mesh hasn't actually changed yet
                           # we've only altered the dom TRex atts
        # Update node spacing of affected cons
        set TRexCons [lsort -unique [join [list $TRexSurfCurvCons $TRexHardEdgeCons]]]

        set nodeSpacing [list]
        foreach con $TRexCons {
            set dist [$con getDistribution 1]
            foreach end [list Begin End] {
                # update node spacing if TRex InitDs is smaller than current spacing
                set spc [$dist get${end}Spacing]
                if { $spc > $trexConData($con,initDs) } {
                    lappend nodeSpacing [$con getNode $end] $trexConData($con,initDs)
                }
            }
        }

        # adjust the spacings, but only reduce as needed
        if [setSpacingAtNodes $nodeSpacing 1] {
            set meshChanged 1
        }
    }
    return $meshChanged
}

# ----------------------------------------------
# Enable TRex boundary attributes
# ----------------------------------------------
proc enableDomTRexAtts { dom fullLayers maxLayers growthRate boundaryDecay } {
    $dom setUnstructuredSolverAttribute TRexFullLayers $fullLayers
    $dom setUnstructuredSolverAttribute TRexMaximumLayers $maxLayers
    $dom setUnstructuredSolverAttribute TRexGrowthRate $growthRate
    $dom setUnstructuredSolverAttribute BoundaryDecay $boundaryDecay
}

# ----------------------------------------------
# Redimension connectors if turning angle or deviation is defined
# ----------------------------------------------
proc increaseConnectorDimensionFromAngleDeviation { conList conMaxDim conTurnAngle conDeviation conTurnAngleHard \
                                                    nodeListVar nodeSpacingVar conTRexVar } {
    upvar $nodeListVar nodeList
    upvar $nodeSpacingVar nodeSpacing
    upvar $conTRexVar conTRex
    global constants conData domParams

    #
    # NOTE: distribution is reset to equal spacing
    #

    set softCons [list]
    set hardCons [list]
    set dimRatioThreshold 2.0

    if { 0.0 < $conTurnAngle || 0.0 < $conDeviation } {
        puts "Adjusting connector dimensions based on turning angles and/or deviation."
        set conMode [pw::Application begin Modify $conList]
        set i 0
        foreach con $conList {

            set dim [$con getDimension]
            if { $dim == $conData($con,maxDim) } {
                 # dimension can't be increased
                 puts "  skipping connector [mkEntLink $con] (maxDim)"
                 continue
            }

            # compute dimension for curvature along connector
            set newdim [$con increaseDimension $conTurnAngle $conDeviation]

            # compute dimension for curvature normal to connector
            set curvedim [$con increaseDimension -surface $conTurnAngle $conDeviation]

            # determine whether surface curvature triggers TRex
            set dimRatio [expr $curvedim / $newdim]
            if { $domParams(MaxLayers) > 0 && $dimRatio > $dimRatioThreshold } {

                # set endpoint finest spacings

                set sp [lindex [CalcConMinMaxSpacing $con] 0]

                set node [$con getNode Begin]
                set j [lsearch $nodeList $node]
                if { -1 != $j } {
                    if { [lindex $nodeSpacing $j] > $sp } {
                        set nodeSpacing [lreplace $nodeSpacing $j $j $sp]
                    }
                }
                set node [$con getNode End]
                set j [lsearch $nodeList $node]
                if { -1 != $j } {
                    if { [lindex $nodeSpacing $j] > $sp } {
                        set nodeSpacing [lreplace $nodeSpacing $j $j $sp]
                    }
                }

                # set TRex flag for connector
                lappend conTRex $con
                lappend softCons $con
            } else {
                # not a TRex connector, use curve and surface based dimension
                set newdim $curvedim
            }

            if { $newdim < $conData($con,minDim) } {
                set newdim $conData($con,minDim)
            }
            if { $newdim > $conData($con,maxDim) } {
                set newdim $conData($con,maxDim)
            }

            # reset to dimension along connector
            $con setDimension $newdim

            if { $newdim > $dim } {
                puts "  Connector [expr $i+1]/[llength $conList]. Dim changed from $dim to $newdim."

                set dim [$con getDimension]

                set pt0 [$con getXYZ -grid 1]
                set pt1 [$con getXYZ -grid 2]
                set sp [pwu::Vector3 length [pwu::Vector3 subtract $pt0 $pt1]]
                set node [$con getNode Begin]
                set j [lsearch $nodeList $node]
                if { -1 != $j } {
                    if { [lindex $nodeSpacing $j] > $sp } {
                        set nodeSpacing [lreplace $nodeSpacing $j $j $sp]
                    }
                }

                set pt0 [$con getXYZ -grid $dim]
                set pt1 [$con getXYZ -grid [expr $dim - 1]]
                set sp [pwu::Vector3 length [pwu::Vector3 subtract $pt0 $pt1]]
                set node [$con getNode End]
                set j [lsearch $nodeList $node]
                if { -1 != $j } {
                    if { [lindex $nodeSpacing $j] > $sp } {
                        set nodeSpacing [lreplace $nodeSpacing $j $j $sp]
                    }
                }
            }

            # reset to default spacing type
            $con replaceDistribution 1 [pw::DistributionTanh create]

            incr i 1
        }
        $conMode end

        # Now look for hard edges
        if { 0.0 < $conTurnAngleHard } {
            set turnTol [expr cos($conTurnAngleHard * $constants(deg2rad))]
            foreach con $conList {
                set j [lsearch $conTRex $con]
                if { -1 != $j } {
                    continue
                }
                set doms [pw::Domain getDomainsFromConnectors $con]
                if { [llength $doms] != 2 } {
                    continue
                }
                set dim [$con getDimension]
                if { 2 >= $dim } {
                    continue
                }

                # Get Db ents associated with the domains
                set domDbEnts1 [GetDomDbEnts [lindex $doms 0]]
                set domDbEnts2 [GetDomDbEnts [lindex $doms 1]]

                if { 0 == [llength $domDbEnts1] || 0 == [llength $domDbEnts2] } {
                    continue
                }

                # Walk along con interior grid points
                # Project to domain db surface
                # Get surface normals
                # Calculate turning angle
                set minDot 2.0
                set numProjFail 0
                set numExceedTol 0
                for { set i 2 } { $i < $dim } { incr i } {
                    set xyz [$con getXYZ $i]
                    set dom1Pt [pw::Database closestPoint -explicit $domDbEnts1 -state state1 $xyz]
                    if { ! $state1 } {
                        incr numProjFail
                        continue
                    }
                    set dom2Pt [pw::Database closestPoint -explicit $domDbEnts2 -state state2 $xyz]
                    if { ! $state2 } {
                        incr numProjFail
                        continue
                    }

                    if [catch { pw::Database getNormal $dom1Pt } norm1] {
                        incr numProjFail
                        continue
                    }
                    if [catch { pw::Database getNormal $dom2Pt } norm2] {
                        incr nomProjFail
                        continue
                    }

                    set norm1 [pwu::Vector3 normalize $norm1]
                    set norm2 [pwu::Vector3 normalize $norm2]
                    set dot   [pwu::Vector3 dot $norm1 $norm2]
                    if { $dot < $minDot } {
                        set minDot $dot
                    }
                    if { $dot < $turnTol } {
                        incr numExceedTol
                    }
                }
                set fractionProjFail [expr 0.5* $numProjFail / ($dim-2)]
                set fractionExceed [expr 1.0*$numExceedTol / ($dim-2)]

                if { $fractionProjFail < 0.2 && $fractionExceed > 0.5 } {
                    puts "  *** Hard Edge CON [mkEntLink $con]"
                    # set TRex flag for connector
                    lappend conTRex $con
                    lappend hardCons $con
                } else {
                    puts "   con: [mkEntLink $con]"
                }
                set angle [expr acos( max(-1.0, min(1.0,$minDot)) ) * $constants(rad2deg)]
                puts [format "     Fail  : %4.1f%%" [expr $fractionProjFail*100]]
                puts [format "     Exceed: %d / %d = %4.1f%%" $numExceedTol [expr $dim-2] \
                    [expr $fractionExceed*100]]
                puts [format "     max turning angle: %.6g" $angle]
            }
        }
    }

    if { 0 < [llength $conTRex] } {
        if { 0 < [llength $softCons] } {
            set group [pw::Group create]
            $group setName TRex_SurfCurvature_cons
            $group setEntityType pw::Connector
            $group addEntity $softCons
            set col [pw::Collection create]
            $col set $softCons
            $col do setRenderAttribute ColorMode Entity
            $col do setRenderAttribute LineWidth 5
            $col do setColor "#ff0000"
            $col delete
            pw::Display update
        }
        if { 0 < [llength $hardCons] } {
            set group [pw::Group create]
            $group setName TRex_HardEdge_cons
            $group setEntityType pw::Connector
            $group addEntity $hardCons
            set col [pw::Collection create]
            $col set $hardCons
            $col do setRenderAttribute ColorMode Entity
            $col do setRenderAttribute LineWidth 5
            $col do setColor "#FBFF33"
            $col delete
            pw::Display update
        }
    }
}

# ----------------------------------------------
# Set the minimum edge size from model tolerance
# ----------------------------------------------
proc setMinEdgeFromModelTolerance { models } {
    global domParams genParams
    set modelEdgeTol [expr $genParams(assembleTolMult)*[getMaxModelEdgeTolerance $models]]

    # domParams(MinEdge) represents the smallest allowable grid spacing
    # Set the value to the maximum of the user defined value
    # and the maximim model assembly tolerance

    if { $domParams(MinEdge) > 0.0 } {
        if { $domParams(MinEdge) < $modelEdgeTol } {
            # can't have a mesh edge smaller than model tolerance
            puts [format "Warning: domParams(MinEdge) raised from %.6g to %.6g due to model assembly tolerance" \
                $domParams(MinEdge) $modelEdgeTol]
        }
    } else {
        set domParams(MinEdge) $modelEdgeTol
        puts [format "domParams(MinEdge) defined as %.6e due to model assembly tolerance" \
            $domParams(MinEdge)]
    }
}

# ----------------------------------------------
# Update node spacing
# ----------------------------------------------
proc updateNodeSpacingList { conList nodeListVar nodeSpacingVar } {
    upvar $nodeListVar nodeList
    upvar $nodeSpacingVar nodeSpacing
    set nodeList [list]
    set nodeSpacing [list]

    # create maximum spacing values at nodes
    foreach con $conList {
        set dim [$con getDimension]
        set pt0 [$con getXYZ -grid 1]
        set pt1 [$con getXYZ -grid 2]
        set sp [pwu::Vector3 length [pwu::Vector3 subtract $pt0 $pt1]]
        set node [$con getNode Begin]
        set i [lsearch $nodeList $node]
        if { -1 == $i } {
            lappend nodeList $node
            lappend nodeSpacing $sp
        } else {
            if { [lindex $nodeSpacing $i] < $sp } {
                set nodeSpacing [lreplace $nodeSpacing $i $i $sp]
            }
        }

        set pt0 [$con getXYZ -grid [expr $dim-1]]
        set pt1 [$con getXYZ -grid $dim]
        set sp [pwu::Vector3 length [pwu::Vector3 subtract $pt0 $pt1]]
        set node [$con getNode End]
        set i [lsearch $nodeList $node]
        if { -1 == $i } {
            lappend nodeList $node
            lappend nodeSpacing $sp
        } else {
            if { [lindex $nodeSpacing $i] < $sp } {
                set nodeSpacing [lreplace $nodeSpacing $i $i $sp]
            }
        }
    }
}

# ----------------------------------------------
# Set connector min and max spacing from min edge
# ----------------------------------------------
proc setConMinMaxDimFromMinEdge { } {
    global domParams conParams
    global conData

    # domParams(MinEdge) represents the smallest allowable grid spacing
    # The value has been set to the maximum of the user defined value
    # and the maximim model assembly tolerance

    set conList [pw::Grid getAll -type pw::Connector]
    foreach con $conList {
        # Initialize as user conParams(MinDim) conParams(MaxDim)
        set conData($con,minDim) [expr max(2,$conParams(MinDim))]
        set conData($con,maxDim) [expr max(2,$conParams(MaxDim))]

        # Maximum connector dimension to meet domParams(MinEdge) requirement
        set length [$con getTotalLength]
        set conData($con,maxDim) [expr min($conData($con,maxDim),int(1.0*$length / $domParams(MinEdge) + 0.333))]
        set conData($con,maxDim) [expr max(2,$conData($con,maxDim))]

        set conData($con,minDim) [expr min($conData($con,minDim),$conData($con,maxDim))]
    }
}

# ----------------------------------------------
# Coarsen the mesh to allow smaller length connectors to be
# dimensioned to the minimum requested.
# ----------------------------------------------
proc reduceConnectorDimensionFromAvgSpacing { conMinDim conMaxDim conList nodeListVar nodeSpacingVar } {
    global domParams conParams
    global conData
    upvar $nodeListVar nodeList
    upvar $nodeSpacingVar nodeSpacing

    setConMinMaxDimFromMinEdge

    # Enforce minimum connector dimension
    foreach con $conList {
        set dim [$con getDimension]
        if { $dim < $conData($con,minDim) } {
            $con setDistribution 1 [pw::DistributionTanh create]
            set newdim $conData($con,minDim)
            $con setDimension $newdim
        }
    }

    # create maximum spacing values at nodes
    foreach con $conList {
        set sp [$con getAverageSpacing]
        set node [$con getNode Begin]
        set i [lsearch $nodeList $node]
        if { -1 == $i } {
            lappend nodeList $node
            lappend nodeSpacing $sp
        } else {
            if { [lindex $nodeSpacing $i] < $sp } {
                set nodeSpacing [lreplace $nodeSpacing $i $i $sp]
            }
        }
        set node [$con getNode End]
        set i [lsearch $nodeList $node]
        if { -1 == $i } {
            lappend nodeList $node
            lappend nodeSpacing $sp
        } else {
            if { [lindex $nodeSpacing $i] < $sp } {
                set nodeSpacing [lreplace $nodeSpacing $i $i $sp]
            }
        }
    }

    # create tolerance
    set tol 1.0e20
    set i 0
    foreach sp $nodeSpacing {
        incr i 1
        if { $sp < $tol } {
            set tol $sp
        }
    }
    set tol [expr $tol * 0.1]

    # Adjust connector dimensions
    puts "Adjusting connector dimensions based on average spacings."
    set conMode [pw::Application begin Modify $conList]
        set i 0
        foreach con $conList {
            incr i 1
            set sp [$con getAverageSpacing]
            set node0 [$con getNode Begin]
            set node1 [$con getNode End]
            set s0 [lindex $nodeSpacing [lsearch $nodeList $node0]]
            set s1 [lindex $nodeSpacing [lsearch $nodeList $node1]]

            if { [expr (($s0 - $sp)/$s0) ] > 0.01 || [expr (($s1 - $sp)/$s1) ] > 0.01 } {

                set olddim [$con getDimension]

                # compute new spacing based on length and max endpoint spacing
                set len [$con getLength -parameter 1.0]
                set newdim [expr int($len/max($s0,$s1))]

                if { $newdim < $conData($con,minDim) } {
                    set newdim $conData($con,minDim)
                }
                if { $newdim > $conData($con,maxDim) } {
                    set newdim $conData($con,maxDim)
                }
                if { $newdim != $olddim } {
                    $con setDimension $newdim
                    puts "  Changing dimension for connector $i/[llength $conList] from $olddim to $newdim"
                }

            }
        }
    $conMode end
}

# ----------------------------------------------
# Adjust connectors spacing and dimension where domain values specified in geometry
# ----------------------------------------------
proc adjustNodeSpacingFromGeometry { edgeMaxGrowthRate conMinDim conMaxDim conMaxDSVar nodeListVar nodeSpacingVar } {
    upvar $conMaxDSVar conMaxDS
    upvar $nodeListVar nodeList
    upvar $nodeSpacingVar nodeSpacing
    global domParams conData

    set conList [pw::Grid getAll -type pw::Connector]
    set meshChanged 0

    puts "Adjusting node spacing"

    #
    # look for attributes in geometry
    #
    set modify [pw::Application begin Modify $conList]
    foreach con $conList {
        # look for connector attributes in geometry

        # look for max edge length in connector geometry
        set maxlength [conAttributeFromGeometry $con "PW:ConnectorMaxEdge"]
        if { [string is double -strict $maxlength] && $domParams(MinEdge) < $maxlength } {
            puts [format "  Connector [$con getName], maximum edge length = %.6g." $maxlength]

            set dim [$con getDimension]
            set sp [$con getAverageSpacing]

            if { $maxlength < $sp } {
                set newdim [$con setDimensionFromSpacing $maxlength]
                set dimChanged 0
                if { $newdim < $conData($con,minDim) } {
                    set newdim $conData($con,minDim)
                    set dimChanged 1
                }
                if { $newdim > $conData($con,maxDim) } {
                    set newdim $conData($con,maxDim)
                    set dimChanged 1
                }
                if { $dimChanged } {
                    $con setDimension $newdim
                }
                set newsp [$con getAverageSpacing]
                set meshChanged 1
                puts [format "  Dimension changed from %d to %d, average spacing changed from %.6g to %.6g" \
                    $dim $newdim $sp $newsp]

            }
            puts "  Checking Max DS for connector [$con getName]"
            set k [lsearch $conList $con]
            if { -1 != $k } {
                set ds [lindex $conMaxDS $k]
                if { $ds > $maxlength } {
                    set conMaxDS [lreplace $conMaxDS $k $k $maxlength]
                    puts [format "  Changed from %.6g to %.6g." $ds $maxlength]
                }
            }
        }

        # look for dimension in connector geometry
        set condim [conAttributeFromGeometry $con "PW:ConnectorDimension"]
        if { [string is integer -strict $condim] && 0 < $condim } {
            set dim [$con getDimension]
            if { $condim > $dim } {
                if { $condim < $conData($con,minDim) } {
                    set condim $conData($con,minDim)
                }
                if { $condim > $conData($con,maxDim) } {
                    set condim $conData($con,maxDim)
                }
                $con setDimension $condim
                set meshChanged 1
            }
        }

        # look for average ds in connector geometry
        set avgds [conAttributeFromGeometry $con "PW:ConnectorAverageDS"]
        if { [string is double -strict $avgds] && 0.0 < $avgds } {
            set avgds [expr max($avgds, $domParams(MinEdge))]
            set sp [$con getAverageSpacing]
            if { $avgds < $sp } {
                set newdim [$con setDimensionFromSpacing $avgds]
                set dimChanged 0
                if { $newdim < $conData($con,minDim) } {
                    set newdim $conData($con,minDim)
                    set dimChanged 1
                }
                if { $newdim > $conData($con,maxDim) } {
                    set newdim $conData($con,maxDim)
                    set dimChanged 1
                }
                if { $dimChanged } {
                    $con setDimension $newdim
                }
                set meshChanged 1
            }
        }

        # look for max angle or deviation in connector geometry
        set maxangle [conAttributeFromGeometry $con "PW:ConnectorMaxAngle"]
        set maxdeviation [conAttributeFromGeometry $con "PW:ConnectorMaxDeviation"]
        set angle 0.0
        if { [string is double -strict $maxangle] && 0.0 < $maxangle } {
            set angle $maxangle
        }
        set deviation 0.0
        if { [string is double -strict $maxdeviation] && 0.0 < $maxdeviation } {
            set deviation $maxdeviation
        }
        if { 0.0 < $angle || 0.0 < $deviation } {
            set newdim [$con increaseDimension $angle $deviation]
            set dimChanged 0
            if { $newdim < $conData($con,minDim) } {
                set newdim $conData($con,minDim)
                set dimChanged 1
            }
            if { $newdim > $conData($con,maxDim) } {
                set newdim $conData($con,maxDim)
                set dimChanged 1
            }
            if { $dimChanged } {
                $con setDimension $newdim
            }
            set meshChanged 1
        }
    }

    set nodeSpacingChanged 0
    foreach con $conList {
        set spc [conAttributeFromGeometry $con "PW:ConnectorEndSpacing"]
        set dim [$con getDimension]
        set pt0 [$con getXYZ -grid 1]
        set pt1 [$con getXYZ -grid 2]
        set sp [pwu::Vector3 length [pwu::Vector3 subtract $pt0 $pt1]]
        if { [string is double -strict $spc] && $spc < $sp } {
            set spc [expr max($spc, $domParams(MinEdge))]
            set sp $spc
        }
        set ni [$con getNode Begin]
        set spn [nodeAttributeFromGeometry $ni "PW:NodeSpacing"]
        if { [string is double -strict $spn] && $spn < $sp } {
            set spn [expr max($spn, $domParams(MinEdge))]
            set sp $spn
        }
        if { [string is double -strict $spc] || [string is double -strict $spn] } {
            set node [$con getNode Begin]
            set i [lsearch $nodeList $node]
            if { -1 != $i } {
                if { [lindex $nodeSpacing $i] > $sp } {
                    set nodeSpacing [lreplace $nodeSpacing $i $i $sp]
                    set nodeSpacingChanged 1
                }
            }
        }
        set pt0 [$con getXYZ -grid $dim]
        set pt1 [$con getXYZ -grid [expr $dim - 1]]
        set sp [pwu::Vector3 length [pwu::Vector3 subtract $pt0 $pt1]]
        if { [string is double -strict $spc] && $spc < $sp } {
            set sp $spc
        }
        set ni [$con getNode End]
        set spn [nodeAttributeFromGeometry $ni "PW:NodeSpacing"]
        if { [string is double -strict $spn] && $spn < $sp } {
            set sp $spn
        }
        if { [string is double -strict $spc] || [string is double -strict $spn] } {
            set node [$con getNode End]
            set i [lsearch $nodeList $node]
            if { -1 != $i } {
                if { [lindex $nodeSpacing $i] > $sp } {
                    set nodeSpacing [lreplace $nodeSpacing $i $i $sp]
                    set nodeSpacingChanged 1
                }
            }
        }
    }

    # apply the adjusted nodal spacing values on connectors
    if { $nodeSpacingChanged } {
        set c 0
        foreach con $conList {
            incr c 1
            set dim [$con getDimension]
            set pt0 [$con getXYZ -grid 1]
            set pt1 [$con getXYZ -grid 2]
            set s0 [pwu::Vector3 length [pwu::Vector3 subtract $pt0 $pt1]]
            set ni [$con getNode Begin]
            set node [$con getNode Begin]
            set i [lsearch $nodeList $node]
            set sp0 [lindex $nodeSpacing $i]

            set pt0 [$con getXYZ -grid $dim]
            set pt1 [$con getXYZ -grid [expr $dim - 1]]
            set s1 [pwu::Vector3 length [pwu::Vector3 subtract $pt0 $pt1]]
            set ni [$con getNode End]
            set node [$con getNode End]
            set i [lsearch $nodeList $node]
            set sp1 [lindex $nodeSpacing $i]
            if { $sp0 < $s0 || $sp1 < $s1 } {

                set news0 [expr min($sp0,$s0)]
                set news1 [expr min($sp1,$s1)]

                set news0 [expr max($news0,$domParams(MinEdge))]
                set news1 [expr max($news1,$domParams(MinEdge))]

                puts [format "  Connector $c/[llength $conList].\
                    Endpoint spacing changed from %.6g <-> %.6g to %.6g <-> %.6g." $s0 $s1 $news0 $news1]

                # Set connector distribution type and apply end spacing
                $con setDistribution 1 [pw::DistributionTanh create]
                set conDist [$con getDistribution 1]
                $conDist setBeginSpacing $news0
                $conDist setEndSpacing $news1
                set meshChanged 1
            }
        }
    }

    $modify end

    return $meshChanged
}

# ----------------------------------------------
# Adjust connector dimension up or down based on end point spacing values
# ----------------------------------------------
proc connectorDimensionFromEndSpacing { edgeMaxGrowthRate conMinDim conMaxDim conList conMaxDS \
        AR nodeList nodeSpacing conTRex } {
    global domParams conData

    # Enforce minimum connector dimension
    foreach con $conList {
        set dim [$con getDimension]
        set newdim $dim
        set dimChanged 0
        if { $newdim < $conData($con,minDim) } {
            set newdim $conData($con,minDim)
            set dimChanged 1
        }
        if { $newdim > $conData($con,maxDim) } {
            set newdim $conData($con,maxDim)
            set dimChanged 1
        }
        if { $dimChanged } {
            $con setDimension $newdim
            $con setDistribution 1 [pw::DistributionTanh create]
        }
    }

    # create tolerance
    set tol 1.0e20
    set i 0
    foreach sp $nodeSpacing {
        incr i 1
        if { $sp < $tol } {
            set tol $sp
        }
    }
    set tol [expr $tol * 0.1]

    # Adjust connector dimensions and spacings
    puts "Adjusting connector dimensions based on end spacings."
    set conMode [pw::Application begin Modify $conList]
    set i 0
    foreach con $conList {
        set conMinDim $conData($con,minDim)
        set conMaxDim $conData($con,maxDim)
        set c [lsearch $conTRex $con]
        if { -1 == $c } {
            set tflag 0
        } else {
            set tflag 1
        }
        set dsMax [lindex $conMaxDS $i]
        set len [$con getLength -parameter 1.0]
        incr i 1
        set sp [$con getAverageSpacing]
        set node0 [$con getNode Begin]
        set node1 [$con getNode End]
        set s0 [lindex $nodeSpacing [lsearch $nodeList $node0]]
        set s1 [lindex $nodeSpacing [lsearch $nodeList $node1]]

        # adjust dimension if average is different from end point spacing
        #   and apply tanh distribution
        if { [expr abs(($sp - $s0)/$sp) ] > 0.01 || [expr abs(($sp - $s1)/$sp) ] > 0.01 || $dsMax < $len } {

            set dim [$con getDimension]

            # Set connector distribution type
            $con setDistribution 1 [pw::DistributionTanh create]

            if { [expr $len/$s0] < 2.0 || [expr $len/$s1] < 2.0 } {
                set newdim [expr $dim + 1]
                $con setDimension $newdim
                set sp [$con getAverageSpacing]
            } else {
                set conDist [$con getDistribution 1]

                set s0 [expr max(min($sp,$s0),$domParams(MinEdge))]
                set s1 [expr max(min($sp,$s1),$domParams(MinEdge))]

                $conDist setBeginSpacing $s0
                $conDist setEndSpacing $s1
            }

            # Increase/decrease dimension until segment max growth rate is met
            set flag 0
            set dflag 0
            set iflag 0
            set olddim [$con getDimension]
            while { 0 == $flag } {

                set dim [$con getDimension]
                set maxRatio 1.0
                set minRatio 1.0
                set minds 1.0e20
                set maxds 0.0
                set flag 1
                if { 3 < $dim && $dim < $conMaxDim } {
                    for { set n 1 } { $n < [expr $dim-2] } { incr n } {
                        set pt0 [$con getXYZ -grid $n]
                        set pt1 [$con getXYZ -grid [expr $n + 1]]
                        set pt2 [$con getXYZ -grid [expr $n + 2]]
                        set ds1 [pwu::Vector3 length [pwu::Vector3 subtract $pt1 $pt0]]
                        if { $ds1 > $maxds } {
                            set maxds $ds1
                        }
                        if { $n > 1 && $ds1 < $minds } {
                            set minds $ds1
                        }
                        set ds2 [pwu::Vector3 length [pwu::Vector3 subtract $pt1 $pt2]]
                        if { $ds2 > $maxds } {
                            set maxds $ds2
                        }
                        if { $ds1 > $tol && $ds2 > $tol } {
                            set ratio [expr {max($ds1,$ds2)} / {min($ds1,$ds2)}]
                            if { $ratio > $maxRatio } {
                                set maxRatio $ratio
                            }

                            set ratio [expr { $ds1 / min($s0,$s1) }]
                            if { $ratio < $minRatio } {
                                set minRatio $ratio
                            }
                            set ratio [expr { $ds2 / min($s0,$s1) }]
                            if { $ratio < $minRatio } {
                                set minRatio $ratio
                            }
                        }
                    }
                }

                if { $dim < $conMinDim } {
                    set newdim $conMinDim
                    $con setDimension $newdim
                    set iflag 1
                    set flag 0
                } elseif { 0 == $iflag && $minRatio < [expr 1.0/$edgeMaxGrowthRate] && $dim > $conMinDim } {
                    set newdim [expr $dim - 1]
                    $con setDimension $newdim
                    set dflag 1
                    set flag 0
                } elseif { 0 == $dflag && $dim < $conMaxDim } {
                    if { $maxds > $dsMax || $maxRatio > $edgeMaxGrowthRate || \
                         ( 1 == $tflag && 0.0 < $AR && [expr 2*$maxds/($s0+$s1)] > $AR ) } {
                        # if internal minimum spacing is larger than end spacing increase dimension
                        if { $minds > [expr min($s0,$s1)] } {
                            set newdim [expr $dim + 1]
                            $con setDimension $newdim
                            set iflag 1
                            set flag 0
                        }
                    }
                }

            }
            if { $dim != $olddim } {
                puts "  Changing dimension for connector $i/[llength $conList] from $olddim to $dim"
            }

        }
    }
    $conMode end
}

# ----------------------------------------------
# Set T-Rex domain boundary conditions based on connector endpoint spacing
# compared to average
# ----------------------------------------------
proc setup2DTRexBoundaries { domList fullLayers maxLayers growthRate boundaryDecay ARlimit conTRex } {
    global domParams

    puts "Setting up T-Rex domain boundary conditions."

    set c -1
    foreach dom $domList {
        incr c 1

        set numedges [$dom getEdgeCount]

        set tflag 0
        for { set e 1 } { $e <= $numedges } { incr e } {
            set ed [$dom getEdge $e]
            set numcons [$ed getConnectorCount]
            for { set i 1 } { $i <= $numcons } { incr i } {
                set con [$ed getConnector $i]

                # has connector been identify for 2D TRex
                set c [lsearch $conTRex $con]
                if { -1 == $c } {
                    continue
                }
                set dim [$con getDimension]
                set avgsp [$con getAverageSpacing]

                set pt0 [$con getXYZ -grid 1]
                set pt1 [$con getXYZ -grid 2]
                set s0 [pwu::Vector3 length [pwu::Vector3 subtract $pt0 $pt1]]

                set pt0 [$con getXYZ -grid [expr $dim - 1]]
                set pt1 [$con getXYZ -grid $dim]
                set s1 [pwu::Vector3 length [pwu::Vector3 subtract $pt0 $pt1]]

                set maxsp 0.0
                for { set n 1 } { $n < [expr $dim-2] } { incr n } {
                    set pt0 [$con getXYZ -grid $n]
                    set pt1 [$con getXYZ -grid [expr $n + 1]]
                    set sp [pwu::Vector3 length [pwu::Vector3 subtract $pt0 $pt1]]
                    if { $sp > $maxsp } {
                        set maxsp $sp
                    }
                }

                if { 0.0 < $ARlimit } {
                    set sp [expr max(0.5 * ($s0 + $s1), $maxsp/$ARlimit)]
                } else {
                    set sp [expr 0.5 * ($s0 + $s1)]
                }

                set sp [expr max($sp, $domParams(MinEdge))]
                set name [$con getName]

                # create a T-Rex wall BC for the connector if needed
                if { [catch { pw::TRexCondition getByName $name } bc] } {
                    puts "  Creating T-Rex wall boundary $name"
                    set bc [pw::TRexCondition create]
                    $bc setName $name
                    $bc setConditionType Wall
                    $bc setSpacing $sp
                } else {
                    puts "  $name already in T-Rex boundary list."
                    if { [expr abs($sp - [$bc getSpacing])] > 0.00001 } {
                        puts [format "[$bc getName] old spacing = %.6g new spacing = %.6g" [$bc getSpacing] $sp]
                        $bc setSpacing $sp
                    }
                }
                $bc apply [list [list $dom $con]]

                set tflag 1
            }
        }

        if { 1 == $tflag } {
            $dom setUnstructuredSolverAttribute TRexFullLayers $fullLayers
            $dom setUnstructuredSolverAttribute TRexMaximumLayers $maxLayers
            $dom setUnstructuredSolverAttribute TRexGrowthRate $growthRate
            $dom setUnstructuredSolverAttribute BoundaryDecay $boundaryDecay
        }
    }
}

# ----------------------------------------------
# Retrieve model attributes from geometry
# ----------------------------------------------
proc loadBlockAttributes { uBlk } {

    puts "Retrieving block attributes from geometry."

    # look for boundary decay
    set decay [modelAttributeFromGeometry "PW:BoundaryDecay"]
    if { [string is double -strict $decay] && 0.0 < $decay } {
        puts [format "  Block boundary decay = %.6g." $decay]
        $uBlk setSizeFieldDecay $decay
    }

    # look for edge growth rate
    set rate [modelAttributeFromGeometry "PW:EdgeMaxGrowthRate"]
    if { [string is double -strict $rate] && 1.0 < $rate } {
        puts [format "  Block edge maximum growth rate = %.6g." $rate]
        $uBlk setUnstructuredSolverAttribute EdgeMaximumGrowthRate $rate
    }

    # look for min edge length
    set minlength [modelAttributeFromGeometry "PW:MinEdge"]
    if { "Boundary" == $minlength || ([string is double -strict $minlength] && 0.0 < $minlength) } {
        puts [format "  Minimum equal edge length = %.6g" $minlength]
        $uBlk setUnstructuredSolverAttribute EdgeMinimumLength $minlength
    }

    # look for max edge length
    set maxlength [modelAttributeFromGeometry "PW:MaxEdge"]
    if { "Boundary" == $maxlength || ([string is double -strict $maxlength] && 0.0 < $maxlength) } {
        puts [format "  Maximum equal edge length = %.6g." $maxlength]
        $uBlk setUnstructuredSolverAttribute EdgeMaximumLength $maxlength
    }
}

# ----------------------------------------------
# set T-Rex volume boundary conditions
# ----------------------------------------------
proc setupTRexBoundaries { uBlk domList } {

    puts "Retrieving T-Rex volume boundary conditions from geometry."

    # process all T-Rex related attributes from geometry models

    set height [modelAttributeFromGeometry "PW:TRexIsoHeight"]
    if { [string is double -strict $height] && 0.0 < $height } {
        puts [format "  T-Rex isotropic height = %.6g." $height]
        $uBlk setUnstructuredSolverAttribute TRexIsotropicHeight $height
    }

    set buffer [modelAttributeFromGeometry "PW:TRexCollisionBuffer"]
    if { [string is double -strict $buffer] && 0.0 < $buffer } {
        puts [format "  T-Rex collision buffer = %.6g." $buffer]
        $uBlk setUnstructuredSolverAttribute TRexCollisionBuffer $buffer
    }

    set angle [modelAttributeFromGeometry "PW:TRexMaxSkewAngle"]
    if { [string is double -strict $angle] && 0.0 < $angle && 180.0 > $angle } {
        puts [format "  T-Rex maximum skew angle = %.6g." $angle]
        $uBlk setUnstructuredSolverAttribute TRexSkewCriteriaMaximumAngle $angle
    }

    set rate [modelAttributeFromGeometry "PW:TRexGrowthRate"]
    if { [string is double $rate] && 1.0 < $rate } {
        puts [format "  T-Rex growth rate = %.6g." $rate]
        $uBlk setUnstructuredSolverAttribute TRexGrowthRate $rate
    }

    set type [modelAttributeFromGeometry "PW:TRexType"]
    switch -- $type {
        TetPyramid -
        TetPyramidPrismHex -
        AllAndCovertWallDoms {
            puts "  T-Rex cell type = $type"
            $uBlk setUnstructuredSolverAttribute TRexCellType $type
        }
    }

    # process domain level volume T-Rex extrusion parameters
    set lflag 0

    set tdomList [list]
    foreach dom $domList {
        set sp [domAttributeFromGeometry $dom "PW:WallSpacing"]
        if { [string is double -strict $sp] && 0.0 < $sp } {
            set name [domAttributeFromGeometry $dom "PW:Name"]
            puts [format "  Domain $name has spacing value = %.6g." $sp]
            lappend tdomList $dom

            if { 0 == [string length $name] } {
                set name [$dom getName]
            }

            # create T-Rex wall BC as needed
            if [catch { pw::TRexCondition getByName $name } bc] {
                puts "  Creating T-Rex wall boundary $name"
                set bc [pw::TRexCondition create]
                $bc setName $name
                $bc setConditionType Wall
                $bc setSpacing $sp
            } elseif { [expr abs($sp - [$bc getSpacing])] > 0.00001 } {
                puts [format "[$bc getName] old spacing = %.6g new spacing = %.6g" [$bc getSpacing] $sp]
                $bc setSpacing $sp
            }
            $bc apply [list [list $uBlk $dom]]
            set lflag 1
        }
    }

    # look for adjacent domains that need to be "match" boundaries
    if { 1 == $lflag  && [llength tdomList] > 0 } {
        puts "  Looking for adjacent boundaries to set as match."
        set pflag 0

        foreach dom $tdomList {
            set adjDomList [pw::Domain getAdjacentDomains -all $dom]
            foreach adj $adjDomList {
                set i [lsearch $tdomList $adj]
                if { -1 == $i } {
                    # Create T-Rex match BC as needed
                    if [catch { pw::TRexCondition getByName "Match" } bc] {
                        puts "  Creating T-Rex match boundary"
                        set bc [pw::TRexCondition create]
                        $bc setName "Match"
                        $bc setConditionType Match
                    }

                    $bc apply [list [list $uBlk $adj]]
                    set pflag 1
                }
            }
        }

        if { 1 == $pflag } {
            puts "  Setting Push Attributes on Block."
            $uBlk setUnstructuredSolverAttribute TRexPushAttributes True
        }
    }

    return $lflag
}

# ----------------------------------------------
# set up adaptation of domains using connectors
# ----------------------------------------------
proc setupConAdapt { uBlk domainAdapt } {

    puts "Setting up adaptation using connector sources."

    if { 0 != $domainAdapt } {
        set domList [pw::Grid getAll -type pw::DomainUnstructured]

        foreach bname [pw::TRexCondition getNames] {
            set mbc [pw::TRexCondition getByName $bname]
            $mbc setAdaptation On
        }

        foreach dom $domList {
            set maxlength [$dom getSurfaceEdgeMaximumLength]
            $dom setUnstructuredSolverAttribute EdgeMaximumLength $maxlength
        }
    }

    set conList [pw::Grid getAll -type pw::Connector]

    set maxsp 0.0
    foreach con $conList {
        set dim [$con getDimension]
        for { set n 1 } { $n < [expr $dim-2] } { incr n } {
            set pt0 [$con getXYZ -grid $n]
            set pt1 [$con getXYZ -grid [expr $n + 1]]
            set sp [pwu::Vector3 length [pwu::Vector3 subtract $pt0 $pt1]]
            if { $sp > $maxsp } {
                set maxsp $sp
            }
        }
    }

    puts [format "  Background spacing set to %.6g." $maxsp]

    $uBlk setSizeFieldBackgroundSpacing $maxsp
    $uBlk includeSizeFieldEntity $conList
}

# ----------------------------------------------
# Join connectors where two connectors attached to any node
# ----------------------------------------------
proc joinConnectors { conSplitAngle } {

    global constants

    puts "Performing join operation on connectors."

    # Iteratively look for candidate connector pairs sharing a node with no other connectors
    # If a turning angle is specified and the two connectors qualify then add them to join list.
    # If a turning angle is not specified add to the list.
    # Repeat until no more candidates found.

    set radSplitAngle 0.0
    puts [format "  Connector split turning angle threshold in degrees = %.6g." $conSplitAngle]
    if { 1.0e-10 < $conSplitAngle } {
        set pi [expr 4.0*atan(1.0)]
        set radSplitAngle [expr $conSplitAngle * $pi / 180.0 ]
        puts [format "  Turning angle threshold in radians = %.6g." $radSplitAngle]
    }

    set rflag 0
    set Joined 1
    set pass 0
    while { 0 < $Joined } {

        incr pass 1
        puts "  Join pass $pass."

        set nodeList [list]

        set conList [pw::Grid getAll -type pw::Connector]
        set numcon [llength $conList]
        puts "    Original connector list has $numcon entries."

        foreach con $conList {
            set n [$con getNode Begin]
            set i [lsearch $nodeList $n]
            if { -1 == $i } {
                lappend nodeList $n
            }
            set n [$con getNode End]
            set i [lsearch $nodeList $n]
            if { -1 == $i } {
                lappend nodeList $n
            }
        }

        # create list of candidate connector pairs
        set pairList [list]

        foreach n $nodeList {
            set cons [$n getConnectors]

            if { [llength $cons] == 2 } {
                lassign $cons c0 c1
                set angle -1.0
                if { 0.0 < $radSplitAngle } {
                    # compute join angle in radians
                    if [catch { calcTurnAngleBetweenCons $c0 $c1 } angle] {
                        puts "could not calculate turn angle between [$c0 getName] and [$c1 getName]: $angle"
                        continue
                    }
                    puts [format "    Angle between [$c0 getName] and [$c1 getName] = %.6g radians." $angle]
                }

                if { 1.0e-10 > $conSplitAngle || $angle < $radSplitAngle } {
                    set found 0
                    foreach pair $pairList {
                        lassign $pair p0 p1
                        if { $p0 == $c0 || $p0 == $c1 || $p1 == $c0 || $p1 == $c1 } {
                            set found 1
                            break
                        }
                    }
                    if { 0 == $found } {
                        lappend pairList [list $c0 $c1]
                    }
                }
            }
        }

        set Joined 0
        foreach pair $pairList {
            lassign $pair c0 c1
            set tmp [pw::Connector join -resetDistribution -reject rejectVar [list $c0 $c1]]
            set nreject [llength $rejectVar]
            if { $nreject > 0 } {
                puts "  Connectors [$c0 getName] and [$c1 getName] not joined."
            } else {
                incr Joined 1
                set rflag 1
            }
        }
        puts "  Connector pairs joined = $Joined"

        set conList [pw::Grid getAll -type pw::Connector]
        set newcon [llength $conList]
        puts "  New connector list has $newcon entries."
        if { $newcon == $numcon } {
            set Joined 0
        }
    }

    if { $rflag } {
        puts "   Resetting all connectors to equal spacing."
        set conList [pw::Grid getAll -type pw::Connector]
        foreach con $conList {
            $con replaceDistribution 1 [pw::DistributionTanh create]
        }

        # update con min/max dimen
        setConMinMaxDimFromMinEdge
    }

    return $rflag
}

# ----------------------------------------------
#  Baffle domains are labeled on the geometry.
#  Domains that intersect with baffles domains are also labeled.
#  Connectors from baffles are inserted into baffle intersect domains.
#  This assumes open-ended connector chains. No closed-loop connectors are permitted.
#  It also assumes each connector in the intersected domain is adjacent to only
#  one or two other connectors. In other words, no endpoints connected to more
#  than two connectors.
# ----------------------------------------------
proc processBaffleIntersections { tol } {

    puts "Checking for baffle intersections."

    # return flag equals zero for success.
    # positive = number of unprocessed connectors

    set rflag 0

    set domList [pw::Grid getAll -type pw::DomainUnstructured]

    set bdomList [list]
    set idomList [list]
    foreach dom $domList {
        switch -- [domAttributeFromGeometry $dom "PW:Baffle"] {
            Baffle {
                lappend bdomList $dom
            }
            Intersect {
                lappend idomList $dom
            }
        }
    }

    set numIntersects [llength $idomList]
    set numBaffles [llength $bdomList]

    if { 0 < $numIntersects && 0 < $numBaffles } {
        puts "  Number of Baffle domains = $numBaffles."
        puts "  Number of Baffle intersect domains = $numIntersects."

        # process all intersected domains
        foreach idom $idomList {

            set dbEnts [$idom getDatabaseEntities]

            # create list of connectors on the domain
            set iconList [list]
            set saveList [list]

            # test connectors of baffle domains
            foreach bdom $bdomList {

                set ne [$bdom getEdgeCount]

                # include connectors that are in the domain using closest function for DB quilt
                for { set i 1 } { $i <= $ne } { incr i } {
                    set e [$bdom getEdge $i]
                    set nc [$e getConnectorCount]

                    for { set j 1 } { $j <= $nc } { incr j } {

                        set con [$e getConnector $j]
                        set dim [$con getDimension]

                        set flag 1
                        for { set k 1 } { $k <= $dim && 1 == $flag } { incr k } {
                            set pt [$con getXYZ -grid $k]

                            set dmin 1.0e20
                            foreach dbEnt $dbEnts {
                                if [$dbEnt isOfType pw::Quilt] {
                                    $dbEnt closestPoint -distance ds $pt
                                    if { $ds < $dmin } {
                                        set dmin $ds
                                    }
                                }
                            }
                            if { $dmin > $tol } {
                                set flag 0
                            }
                        }
                        if { 1 == $flag } {
                            lappend iconList $con
                            lappend saveList $con
                        }
                    }
                }
            }

            if { 0 < [llength $iconList] } {

                puts "  Number of saved connectors = [llength $iconList]"

                set rflag 0
                foreach con $iconList {
                    set c0 [[$con getNode Begin] getConnectors]
                    set c1 [[$con getNode End] getConnectors]
                    set count0 0
                    foreach con $c0 {
                        if { -1 == [lsearch $saveList $con] } {
                            incr count0
                        }
                    }
                    set count1 0
                    foreach con $c1 {
                        if { -1 == [lsearch $saveList $con] } {
                            incr count1
                        }
                    }

                    if { 2 < $count0 || 2 < $count1 } {
                        incr rflag 1
                    }
                }

                if { 0 < $rflag } {
                    puts "  Saved connector set is invalid. Number of connectors with more than two neighbors = $rflag"
                    return $rflag
                }

                # add save connectors to domain as new internal edges
                set bmode [pw::Application begin Modify -notopology $idom]

                    set eList [list]
                    set ne [$idom getEdgeCount]
                    for { set i 1 } { $i <= $ne } { incr i } {
                        set e [$idom getEdge $i]
                        lappend eList $e
                    }

                    $idom removeEdges -preserve

                    # add original back in domain
                    foreach ed $eList {
                        $idom addEdge $ed
                    }

                    set flag 1

                    while { 1 == $flag } {

                        # process connectors as open-ended chains
                        set chain [list]

                        catch { unset nextNode }

                        # find first segment with open end
                        for { set i 0 } { $i < [llength $iconList] } { incr i } {
                            set con [lindex $iconList $i]
                            set n0 [$con getNode Begin]
                            set n1 [$con getNode End]
                            set c0 [$n0 getConnectors]
                            set c1 [$n1 getConnectors]
                            set count0 0
                            foreach tcon $c0 {
                                set j [lsearch $saveList $tcon]
                                if { -1 != $j } {
                                    incr count0 1
                                }
                            }
                            set count1 0
                            foreach tcon $c1 {
                                set j [lsearch $saveList $tcon]
                                if { -1 != $j } {
                                    incr count1 1
                                }
                            }
                            if { 1 == $count0 || 1 == $count1 } {
                                lappend chain $con
                                # remove connector from old list
                                set iconList [lremove $iconList $con]
                                if { 2 == $count0 } {
                                    set nextNode $n0
                                }
                                if { 2 == $count1 } {
                                    set nextNode $n1
                                }
                                break
                            }
                        }

                        while { [info exists nextNode] } {

                            foreach con $iconList {
                                set n0 [$con getNode Begin]
                                set n1 [$con getNode End]
                                if { $nextNode == $n0 || $nextNode == $n1 } {
                                    set c0 [$n0 getConnectors]
                                    set c1 [$n1 getConnectors]
                                    set count0 0
                                    foreach tcon $c0 {
                                        set j [lsearch $saveList $tcon]
                                        if { -1 != $j } {
                                            incr count0 1
                                        }
                                    }
                                    set count1 0
                                    foreach tcon $c1 {
                                        set j [lsearch $saveList $tcon]
                                        if { -1 != $j } {
                                            incr count1 1
                                        }
                                    }

                                    lappend chain $con
                                    # remove connector from old list
                                    set iconList [lremove $iconList $con]

                                    if { $nextNode == $n0 && 2 == $count1 } {
                                        set nextNode $n1
                                    } elseif { $nextNode == $n1 && 2 == $count0 } {
                                        set nextNode $n0
                                    } else {
                                        unset nextNode
                                    }
                                    break
                                }
                            }
                        }

                        set flag 0
                        # create new edge
                        if { 0 < [llength $chain] } {
                            set ed [pw::Edge create]
                            # forward pass
                            for { set i 0 } { $i < [llength $chain] } { incr i } {
                                set con [lindex $chain $i]
                                $ed addConnector $con
                            }
                            # revers pass
                            set j [llength $chain]
                            for { set i 0 } { $i < [llength $chain] } { incr i } {
                                set j [expr $j - 1]
                                set con [lindex $chain $j]
                                $ed addConnector $con
                            }

                            # add the edge to the domain
                            $idom addEdge $ed
                            set flag 1
                        }
                    }

                $bmode end
            }

            incr rflag [llength $iconList]
        }
    }

    return $rflag
}

# ----------------------------------------------
# Attempt to use automatic block creation from domains.
# Assumes, no baffles domains are passed in.
# ----------------------------------------------
proc AssembleBlockFromDomains { domList } {

    set unusedDoms [list]

    set uBlk [pw::BlockUnstructured createFromDomains -reject unusedDoms $domList]

    if { 0 < [llength $unusedDoms] } {
        puts "Number of unused domains = [llength $unusedDoms]"
    }

    return $uBlk
}

# ----------------------------------------------
# Check whether skip meshing is available
# ----------------------------------------------
proc HaveDomSkipMeshing { } {
  if [catch { pw::Script getDomainUnstructuredSkipMeshing }] {
      return 0
  }
  return 1
}

# ----------------------------------------------
# set domain skip meshing
# ----------------------------------------------
proc SetDomSkipMeshing { value } {
    if [HaveDomSkipMeshing] {
        if [catch { pw::Script setDomainUnstructuredSkipMeshing $value }] {
        }
    }
}

# END SCRIPT

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
#
