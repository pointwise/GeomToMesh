#############################################################################
#
# (C) 2021 Cadence Design Systems, Inc. All rights reserved worldwide.
#
# This sample script is not supported by Cadence Design Systems, Inc.
# It is provided freely for demonstration purposes only.
# SEE THE WARRANTY DISCLAIMER AT THE BOTTOM OF THIS FILE.
#
#############################################################################
#
# GeomToMesh: Geometry-Mesh associativity utility functions
#
# Export geometry-mesh associativity UVS parameter for each db constrained block point
# Utilize the CAE mesh file point indices and egadsID db entity attribute
#

package require PWI_Glyph


# PROC GetDomPeriodicInds
#
# Map domain points along the seam of a periodic db surface
# to their low and high UV locations.
proc GetDomPeriodicInds {dom {verbose 0}} {
    global globalPointInd globalPoints domCellEdge domBoundaryCon
    global egadsCurveMapMsgs dbAssembleTol egadsFaceDoms domBoundaryNode
    global domPeriodicPts
    
    set dim [$dom getPointCount]
    
    set egadsFaceDoms($dom,periodicInds) [list]
    set egadsFaceDoms($dom,numPts) $dim
    set domPeriodicPts($dom,domInds) [list]
    set domPeriodicPts($dom,numSingularPts) 0
    
    set cons [list]
    set periodicCons [list]
    if {$egadsFaceDoms($dom,isPeriodicDB)} {
    
        if {[$dom isOfType pw::DomainStructured]} {        
            error "Periodic structured domains unsupported"
        }
        # determine cons on periodic seam
        set edge [$dom getEdge 1]; # only outer edge can use the seam
        set ncons [$edge getConnectorCount]
        set ind 1
        for {set icon 1} {$icon <= $ncons} {incr icon} {
            set con [$edge getConnector $icon]
            set ind [lsearch -exact $cons $con]
            if {-1 != $ind} {
                # con reused
                lappend periodicCons $con
            } 
            
            set edgeCon($con,startInd) $ind
            set edgeCon($con,orient) [$edge getConnectorOrientation $icon]
            incr ind [$con getDimension]
            lappend cons $con
        }
    
        if {$verbose} {
            puts "[mkEntLink $dom] edge cons"
            foreach con $cons {
                puts "    [mkEntLink $con]"
            }
            puts "  periodic cons"
            foreach con $periodicCons {
                puts "    [mkEntLink $con]"
            }
        }
        
                   
        for {set domInd 1} {$domInd <= $globalPointInd($dom,interiorPtOffset)} {incr domInd} {

            # Check for surface singularity
            if {[info exists domBoundaryNode($dom,$domInd,node)]} {
                set node $domBoundaryNode($dom,$domInd,node)
                set incCons [pw::Connector getConnectorsFromNode $node]
                set domBoundaryNode($dom,$domInd,singularity) 0
                if {[llength $incCons] < 2} {
                    # end of branch cut - anecdotally this happens
                    # at surface singularities which should only
                    # have one parametric representation
                    if {$verbose} {
                        puts "singularity node globalInd:$globalPointInd($node) [mkXYZLink [$node getXYZ]]"
                    }
                    set domBoundaryNode($dom,$domInd,singularity) 1
                    incr domPeriodicPts($dom,numSingularPts)
                }
            }
        
            set ind [lsearch -exact $periodicCons $domBoundaryCon($dom,$domInd,con)]
            if {$ind != -1} {
                # a periodic seam point
                
                set gridPoint [GetDomBdryPointUV $dom $egadsFaceDoms($dom,dbEnts) $domInd $dbAssembleTol]
                set uv [lreplace $gridPoint 2 2]
                set xyz [$dom getXYZ $domInd]
                
                switch $egadsFaceDoms($dom,periodicDir) {
                U {
                    set domPeriodicPts($dom,$domInd,uv,low) $uv
                    set domPeriodicPts($dom,$domInd,uv,high) [lreplace $uv 0 0 1.0]
                    if {[lindex $uv 0] < 0.5} {
                        set side "LOW"
                    } else {
                        # error - we assume map to low side by default
                        set side "HIGH"
                        error "bad side"
                    }
                }
                V {
                    set domPeriodicPts($dom,$domInd,uv,low) $uv
                    set domPeriodicPts($dom,$domInd,uv,high) [lreplace $uv 1 1 1.0]
                    if {[lindex $uv 1] < 0.5} {
                        set side "LOW"
                    } else {
                        # error - we assume map to low side by default
                        set side "HIGH"
                        error "bad side"
                    }
                }
                default {error "bad periodic dir \"$egadsFaceDoms($dom,periodicDir)\""}                
                }

                set uvStr [format "UV: %4.2f %4.2f" [lindex $uv 0] [lindex $uv 1]]
                if {$verbose} {
                    puts "domInd:$domInd globalInd:$globalPointInd($dom,$domInd) [$domBoundaryCon($dom,$domInd,con) getName] \
                        [mkXYZLink $xyz] $uvStr  $egadsFaceDoms($dom,periodicDir)  $side"
                }
                lappend domPeriodicPts($dom,domInds) $domInd
                
            } else {
                if [info exists domBoundaryNode($dom,$domInd,node)] {
                    set node $domBoundaryNode($dom,$domInd,node)
                    set incCons [pw::Connector getConnectorsFromNode $node]
                    foreach incCon $incCons {
                        set ind [lsearch -exact $periodicCons $incCon]
                        if {$ind != -1} {
                            # a periodic seam point
                            set gridPoint [GetDomBdryPointUV $dom $egadsFaceDoms($dom,dbEnts) $domInd $dbAssembleTol]
                            set uv [lreplace $gridPoint 2 2]
                            set xyz [$dom getXYZ $domInd]
                            
                            switch $egadsFaceDoms($dom,periodicDir) {
                            U {
                                set domPeriodicPts($dom,$domInd,uv,low) $uv
                                set domPeriodicPts($dom,$domInd,uv,high) [lreplace $uv 0 0 1.0]
                                if {[lindex $uv 0] < 0.5} {
                                    set side "LOW"
                                } else {
                                    # error - we assume map to low side by default
                                    set side "HIGH"
                                    error "bad side"
                                }
                            }
                            V {
                                set domPeriodicPts($dom,$domInd,uv,low) $uv
                                set domPeriodicPts($dom,$domInd,uv,high) [lreplace $uv 1 1 1.0]
                                if {[lindex $uv 1] < 0.5} {
                                    set side "LOW"
                                } else {
                                    # error - we assume map to low side by default
                                    set side "HIGH"
                                    error "bad side"
                                }
                            }
                            default {error "bad periodic dir \"$egadsFaceDoms($dom,periodicDir)\""}                
                            }

                            set uvStr [format "UV: %4.2f %4.2f" [lindex $uv 0] [lindex $uv 1]]
                            if {$verbose} {
                                set con [lindex $periodicCons $ind]
                                if {[$con getNode Begin] == $node} {
                                    set conInd 1
                                } elseif {[$con getNode End] == $node} {
                                    set conInd [$con getDimension]
                                } else {
                                    error "bad node"
                                }
                                puts "conInd:$conInd globalInd:$globalPointInd($con,$conInd) [mkXYZLink [$con getXYZ $conInd]]"
                                puts "domInd:$domInd globalInd:$globalPointInd($dom,$domInd) [$domBoundaryCon($dom,$domInd,con) getName] \
                                    [mkXYZLink $xyz] $uvStr  $egadsFaceDoms($dom,periodicDir)  $side"
                            }

                            lappend domPeriodicPts($dom,domInds) $domInd
                            break
                        }
                    }
                }
            }
        }
    }
}

# PROC GetPeriodicLowUV
#
# Given a grid point constrained to a periodic db surface,
# ensure that the "low" UV value is returned.  This allows
# the mapping routine to only map to the "high" UV direction.
proc GetPeriodicLowUV {gridPoint} {
    # drill down to support surface
    set supportDbs [lindex $gridPoint end]

    while {[llength $supportDbs] == 1} {
        set supportDbs [$supportDbs getSupportEntities]
    }
    
    foreach supDb $supportDbs {
        if {[$supDb isOfType pw::Surface]} {
            set supportSurf $supDb
            break
        }
    }
    
    if ![info exists supportSurf] {
        error "GetPeriodicLowUV - no support surface for $gridPoint"
    }
    
    if {[$supportSurf isClosed -U]} {
        set u [lindex $gridPoint 0]
        if {$u > 0.95} {
            set gridPoint [lreplace $gridPoint 0 0 0.0]
        }
    }
    if {[$supportSurf isClosed -V]} {
        set v [lindex $gridPoint 1]
        if {$v > 0.95} {
            set gridPoint [lreplace $gridPoint 1 1 0.0]
        }
    }
    return $gridPoint
}


# PROC GetDomBdryPointUV
#
# Given a domain grid point index, map to the support surface
# via projection (normal map is to the boundary curve).  
# If the boundary is periodic, the "low" UV coords will be returned.
proc GetDomBdryPointUV {dom dbEnts ind tol} {
    if { ![$dom isInteriorIndex $ind] } {
        # domain boundary points will map to curves or vertices,
        # must be projected to determine surface UV
        set gridPoint [$dbEnts closestPoint -distance dist [$dom getXYZ $ind]]
            
        if { $dist > $tol } {
            set msg "WARNING: projection distance [format "(%.6g)" $dist] to EGADS surface exceeds tolerance $tol"
            puts $msg
            set projxyz [pw::Application getXYZ $gridPoint]
            puts "[mkXYZLink [$dom getXYZ $ind]] -> [mkXYZLink $projxyz]"
        }
        set gridPoint [GetPeriodicLowUV $gridPoint]
        
    } else {
        error "GetDomBdryPointUV non-boundary index"
    }
    return $gridPoint
}


# Write the geometry map file for the given set of blocks
# GMA Version 2.0 file format
#
# NumEgadsEdgeGroups  NumEgadsFaceGroups
# Foreach connector (EgadsEdgeGroup)
#   Con <name>
#   WholeConEgadsID  NumPoints
#   NumPoints lines of GlobalUniquePointIndex PointEgadsCurveID PointEgadsCurveTParam
#
# Foreach domain (EgadsFaceGroup)
#   Dom <name>
#   NumPoints
#   WholeDomEgadsID  NumTris NumQuads
#   NumPoints lines of GlobalUniquePointIndex PointEgadsSurfaceID PointEgadsSurfaceUVParam
#   NumTris lines of Cell's LocalPointIndices 
#   NumQuads lines of Cell's LocalPointIndices 
proc WriteGeomMapFileV2 { fname blks { debugFormat 0 } {verbose 0}} {
    global globalPointInd globalPoints domCellEdge
    global egadsCurveMapMsgs dbAssembleTol egadsFaceDoms
    global domPeriodicPts domBoundaryNode
    
    set writePoints 0;  # whether to write point XYZ as debug info
    
    # set startTime [clock clicks -milliseconds]
    
    # Use assembly tolerance when projecting points
    set dbAssembleTol [maxDBEdgeTolerance 0]

    catch { unset egadsCurveMapMsgs }

    if { [llength $blks] == 0 } {
        return -code error "WriteGeometryFile: no block"
    }
    
    set cons [list]
    set doms [list]
    foreach blk $blks {
        set nface [$blk getFaceCount]
        for { set iface 1 } { $iface <= $nface } { incr iface } {
            set face [$blk getFace $iface]
            set ndom [$face getDomainCount]
            for { set idom 1 } { $idom <= $ndom } { incr idom } {
                set dom [$face getDomain $idom]
                if { ! [info exists refDoms($dom)] } {
                    set refDoms($dom) 1
                    lappend doms $dom
                    set flipDom($dom) 0
                    if { "Same" != [$face getDomainOrientation $idom] } {
                        set flipDom($dom) 1
                    }
                }
                set nedge [$dom getEdgeCount]
                for { set iedge 1 } { $iedge <= $nedge } { incr iedge } {
                    set edge [$dom getEdge $iedge]
                    set ncon [$edge getConnectorCount]
                    for { set icon 1 } { $icon <= $ncon } { incr icon } {
                        set con [$edge getConnector $icon]
                        if { ! [info exists refCons($con)] } {
                            set refCons($con) 1
                            lappend cons $con
                        }
                    }
                }
            }
        }
    }

    if {$writePoints} {
        set meshPoint(num) 0
    }

    set startTime [clock clicks -milliseconds]

    # add connector points
    foreach con $cons {
        set conName [$con getName]

        set node [$con getNode Begin]
        set gridPoint [$con getPoint 1]
        set egadsID [getEgadsIDByGridPoint $gridPoint]
        set index $globalPointInd($node)
        set tol [getAssembleToleranceForCon $con]
        if {$tol == 0.0} {
            # use global assembly tolerance
            set tol $dbAssembleTol
        }

        if { $writePoints && 0 < [llength $egadsID] && ! [info exists meshPoint($index)] } {
            set meshPoint($index) 1
            set meshPoint($meshPoint(num),ind) $index
            set meshPoint($meshPoint(num),xyz) [$con getXYZ 1]
            set meshPoint($meshPoint(num),egadsID) $egadsID
            if [isVertex $egadsID] {
                set uv [list 0.0 0.0]
            } else {
                set gridPoint [getUVOnOriginalEgadsCurve $meshPoint($meshPoint(num),xyz) $gridPoint $tol]
                set uv [lreplace $gridPoint 2 2]
            }
            set meshPoint($meshPoint(num),uv) $uv
            incr meshPoint(num)
        }

        set dim [$con getDimension]

        for { set i 2 } { $i < $dim } { incr i } {
            set gridPoint [$con getPoint $i]
            set egadsID [getEgadsIDByGridPoint $gridPoint]
            set index $globalPointInd($con,$i)
            if { $writePoints && 0 < [llength $egadsID] && ! [info exists meshPoint($index)] } {
                set meshPoint($index) 1
                set meshPoint($meshPoint(num),ind) $index
                set meshPoint($meshPoint(num),xyz) [$con getXYZ $i]
                set meshPoint($meshPoint(num),egadsID) $egadsID
                if [isVertex $egadsID] {
                    set uv [list 0.0 0.0]
                } else {
                    set gridPoint [getUVOnOriginalEgadsCurve $meshPoint($meshPoint(num),xyz) $gridPoint $tol]
                    set uv [lreplace $gridPoint 2 2]
                }
                set meshPoint($meshPoint(num),uv) $uv
                incr meshPoint(num)
            }
        }

        set node [$con getNode End]
        set gridPoint [$con getPoint $dim]
        set egadsID [getEgadsIDByGridPoint $gridPoint]
        set index $globalPointInd($node)
        if { $writePoints && 0 < [llength $egadsID] && ! [info exists meshPoint($index)] } {
            set meshPoint($index) 1
            set meshPoint($meshPoint(num),ind) $index
            set meshPoint($meshPoint(num),xyz) [$con getXYZ $dim]
            set meshPoint($meshPoint(num),egadsID) $egadsID
            if [isVertex $egadsID] {
                set uv [list 0.0 0.0]
            } else {
                set gridPoint [getUVOnOriginalEgadsCurve $meshPoint($meshPoint(num),xyz) $gridPoint $tol]
                set uv [lreplace $gridPoint 2 2]
            }
            set meshPoint($meshPoint(num),uv) $uv
            incr meshPoint(num)
        }
    }

    set endTime [clock clicks -milliseconds]
    # puts " add connector points [format {%.2f secs} [expr ($endTime-$startTime) * 0.001]]" 
    set startTime [clock clicks -milliseconds]


    # add domain interior points
    catch {unset egadsFaceDoms}
    set egadsFaceDoms(doms) [list]
    foreach dom $doms {
        set domName [$dom getName]

        set dbEnts [list]
        if [$dom isOfType pw::DomainUnstructured] {
            set constraint [$dom getUnstructuredSolverAttribute ShapeConstraint]
            if { $constraint == "Free" } {
                continue
            } elseif { $constraint == "Database" } {
                # default ents
                set dbEnts [$dom getDatabaseEntities -solver]
            } else {
                # explicit ent list
                set dbEnts $constraint
            }
        } elseif [$dom isOfType pw::DomainStructured] {
            set constraint [$dom getEllipticSolverAttribute  ShapeConstraint]
            if { $constraint == "Free" || $constraint == "Fixed" } {
                continue
            } elseif { $constraint == "Database" } {
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

        if { [llength $dbEnts] <= 0 } {
            # unconstrained domain
            continue
        }
        set egadsFaceDoms($dom,dbEnts) $dbEnts
        
        # Determine if the support surface is periodic
        set egadsFaceDoms($dom,isPeriodicDB) 0
        set egadsFaceDoms($dom,periodicDir) 0
        if {[llength $dbEnts] == 1} {
            # support entity could be a quilt or trimmed surf
            # we need to drill down to the single supporting
            # untrimmed surface
            set supportDbs [$dbEnts getSupportEntities]
            while {[llength $supportDbs] == 1} {
                set supportDbs [$supportDbs getSupportEntities]
            }
            
            set supDb ""
            foreach supDb $supportDbs {
                if {[$supDb isOfType pw::Surface]} {
                    set supportSurf $supDb
                    break
                }
            }
            
            # a periodic support surface will be "closed"
            if {[$supportSurf isClosed -U]} {
                set egadsFaceDoms($dom,isPeriodicDB) 1
                set egadsFaceDoms($dom,periodicDir) U
            }
            if {[$supportSurf isClosed -V]} {
                set egadsFaceDoms($dom,isPeriodicDB) 1
                set egadsFaceDoms($dom,periodicDir) V
            }

            if {$egadsFaceDoms($dom,isPeriodicDB) && $verbose} {
                puts "[mkEntLink $dom] support: [mkEntLink $supportSurf] isPeriodic in $egadsFaceDoms($dom,periodicDir)"
            }
        }

        # Map periodic UV points -- must call this for all
        # doms so that needed arrays are initialized
        GetDomPeriodicInds $dom
        
        set domEgadsID 0
        set markedBadDom 0

        set dim [$dom getPointCount]
        for { set domInd [expr $globalPointInd($dom,interiorPtOffset)+1] } { $domInd <= $dim } { incr domInd } {
        
            if { ! [$dom isInteriorIndex $domInd] } {
                # domain boundary points accounted for in connector constraints
                continue
            }
            set gridPoint [$dom getPoint $domInd]
            set egadsID [getEgadsIDByGridPoint $gridPoint]
            if {$egadsID != "" && $domEgadsID == 0} {
               set domEgadsID $egadsID
               lappend egadsFaceDoms(doms) $dom
               set egadsFaceDoms($dom,egadsID) $egadsID
            } else {
               if {!$markedBadDom && $egadsID != $domEgadsID} {
                   set markedBadDom 1
                   lappend egadsFaceDoms(bad_doms) $dom
                   lappend egadsFaceDoms(bad_doms_egadsIDs) $dom
                   set ind [lsearch -exact $egadsFaceDoms(doms) $dom]
                   set egadsFaceDoms(doms) [lreplace $egadsFaceDoms(doms) $ind $ind]
               }
            }
            set index $globalPointInd($dom,$domInd)
            if { $writePoints && 0 < [llength $egadsID] && ! [info exists meshPoint($index)] } {
                set meshPoint($index) 1
                set meshPoint($meshPoint(num),ind) $index
                set meshPoint($meshPoint(num),xyz) [$dom getXYZ $domInd]
                set meshPoint($meshPoint(num),egadsID) $egadsID
                set uv [lreplace $gridPoint 2 2]
                # set uv [list [lindex $gridPoint 0] [lindex $gridPoint 1]]
                set meshPoint($meshPoint(num),uv) $uv
                incr meshPoint(num)
            }
        }
        if {$domEgadsID == 0 && [llength $dbEnts] == 1 } {
             # can't map using interior points, use solver constraint
             set egadsID [getEgadsIDByGridPoint $dbEnts]
             if {$egadsID != ""} {
                set domEgadsID $egadsID
                lappend egadsFaceDoms(doms) $dom
                set egadsFaceDoms($dom,egadsID) $egadsID
             }
        }

        if {$domEgadsID == 0} {
            puts "Unable to map $domName to EGADS face ID"
        }
    }

    set endTime [clock clicks -milliseconds]
    # puts " add domain interior points [format {%.2f secs} [expr ($endTime-$startTime) * 0.001]]" 
    set startTime [clock clicks -milliseconds]

    # write the map file
    if [catch { open $fname "w" } f] {
        puts $f
        return -code error "Could not open file $fname: $f"
    }
    
    puts $f "#Geometry-Mesh Associativity V2.0"
    puts $f "2 0"
    puts $f "# NumConnectors  NumDomains"
    puts $f "[llength $cons] [llength $egadsFaceDoms(doms)]"

    if {$writePoints} {
        puts $f $meshPoint(num)
        if { $debugFormat } {
            puts $f "index   xyz  egadsID  UV  GE_topology"
            set fmt "%8d %25.16e %25.16e %25.16e %16d %25.16e %25.16e %s"
            for { set ipt 0 } { $ipt < $meshPoint(num) } { incr ipt } {
                #"%8d %12.5e %12.5e %12.5e %16d %16.9e %16.9e %s"
                #"%8d %12.7f %12.7f %12.7f %16d %16.9e %16.9e %s"
                set str [format $fmt \
                    $meshPoint($ipt,ind)  \
                    [lindex $meshPoint($ipt,xyz) 0] [lindex $meshPoint($ipt,xyz) 1] [lindex $meshPoint($ipt,xyz) 2] \
                    $meshPoint($ipt,egadsID)  \
                    [lindex $meshPoint($ipt,uv) 0] [lindex $meshPoint($ipt,uv) 1] \
                    [decodeEgadsID $meshPoint($ipt,egadsID)]]
                puts $f $str
            }
        } else {
            # puts $f "index egadsID U V"
            set fmt "%8d %12d %25.16e %25.16e"
            for { set ipt 0 } { $ipt < $meshPoint(num) } { incr ipt } {
                set str [format $fmt \
                    $meshPoint($ipt,ind)  \
                    $meshPoint($ipt,egadsID)  \
                    [lindex $meshPoint($ipt,uv) 0] [lindex $meshPoint($ipt,uv) 1]]
                puts $f $str
            }
        }
    }
    
    
    set startTime [clock clicks -milliseconds]
    
    # write con points which map to EGADS edges
    set egadsEdgeConCount 0
    foreach con $cons {
        set conName [$con getName]
        set dim [$con getDimension]
        set conEgadsID 0
        set conDbCurve ""
        set egadsCurve ""
        set tol [getAssembleToleranceForCon $con]
        if {$tol == 0.0} {
            # use global assembly tolerance
            set tol $dbAssembleTol
        }
        
        set goodConMap 1
        if {$dim < 3} {
            # map conEgadsID from node
            set nodePoint [$con getPoint -constrained isDb 1]
            if {$isDb} {
                set nodeDB [lindex $nodePoint 2]
                set nodeEgadsID [getEgadsIDByGridPoint $nodeDB]
                if {$nodeEgadsID != ""} {
                    set conEgadsID $nodeEgadsID
                }
            }
        } else {
            # map conEgadsID from interior grid point
            set gridPoint [$con getPoint 2]
            set conEgadsID [getEgadsIDByGridPoint $gridPoint ]
            if {0 == [llength $conEgadsID]} {
                puts "Unable to map $conName to EGADS edge ID"
                continue
            }
            set conDbCurve [lindex $gridPoint 2]
            set egadsCurve [getOriginalEgadsCurve $conDbCurve]
            
            # check that other interior points map to same EgadsID
            for { set i 3 } { $i < $dim } { incr i } {
                set gridPoint [$con getPoint $i]
                set egadsID [getEgadsIDByGridPoint $gridPoint ]
                if { $egadsID != $conEgadsID } {
                
                    puts "[mkEntLink $con] maps to more than one EGADS edge ID"
                    if {$goodConMap == 1} {
                        set gridPoint2 [$con getPoint 2]
                        set gridPoint2Str [lreplace $gridPoint2 2 2 [mkEntLink [lindex $gridPoint2 2]]]
                        set xyz [$con getXYZ 2]
                        puts "  conPtInd: 2"
                        puts "  dbCoords: $gridPoint2Str"
                        puts "  [mkXYZLink $xyz]"
                        puts "  egadsID: $conEgadsID"
                        puts "  egads Ent: [decodeEgadsID $conEgadsID]"
                        # dictionary dump
                        set conEgadsID [getEgadsIDByGridPoint $gridPoint2 1 ]

                        puts ""
                        set xyz [$con getXYZ $i]
                        puts "  conPtInd: $i"
                        set gridPointStr [lreplace $gridPoint 2 2 [mkEntLink [lindex $gridPoint 2]]]
                        puts "  dbCoords: $gridPointStr"
                        puts "  [mkXYZLink $xyz]"
                        puts "  egadsID: $egadsID"
                        puts "  egads Ent: [decodeEgadsID $egadsID]"
                        # dictionary dump
                        set egadsID [getEgadsIDByGridPoint $gridPoint 1]
                        puts ""
                    } else {
                        set xyz [$con getXYZ $i]
                        puts "conPtInd $i [mkXYZLink $xyz] $egadsID != $conEgadsID"
                    }
                    set goodConMap 0
                    break
                }
            }
        }
        
        if {$goodConMap == 0} {
            puts "Unable to map $conName to EGADS edge ID"
            continue
        }
        
        # con maps to single EGADS edge ID - write points
        puts $f "#Con [$con getName]"
        puts $f "# WholeConEgadsID  NumPoints"
        puts $f [format "%d %d" $conEgadsID $dim]
        puts $f "# GlobalUniquePointIndex PointEgadsCurveID PointEgadsCurveTParam"
        set fmt "%8d %12d %25.16e "
        
        set isPeriodic 0
        if {$egadsCurve != ""} {
            if {[$egadsCurve isClosed]} {
                set isPeriodic 1
            }
        }
        
        for { set i 1 } { $i <= $dim } { incr i } {
            set gridPoint [$con getPoint $i]
            # make sure we're using UV on con db curve
            set gridPoint [lreplace $gridPoint 2 2 $conDbCurve]
            set egadsID [getEgadsIDByGridPoint $gridPoint]
            if { 0 < [llength $egadsID] } {
                set gridPoint [getUVOnOriginalEgadsCurve [$con getXYZ $i] $gridPoint $tol]
                set uv [lreplace $gridPoint 2 2]
                set ptU [lindex $uv 0]
                if {$isPeriodic && ($ptU < 0.01 || $ptU > 0.99)} {
                    if {$i == 1} {
                        set gridPoint2 [$con getPoint 2]
                        set gridPoint2 [getUVOnOriginalEgadsCurve [$con getXYZ 2] $gridPoint2 $tol]
                        set nextU [lindex $gridPoint2 0]
                        if {$nextU < 0.5} {
                            # use begin parametric coord
                            set uv [lreplace $uv 0 0 0.0]
                        } else {
                            # use end parametric coord
                            set uv [lreplace $uv 0 0 1.0]
                        }
                    } elseif {$i == $dim} {
                        if {$lastU < 0.5} {
                            # use begin parametric coord
                            set uv [lreplace $uv 0 0 0.0]
                        } else {
                            # use end parametric coord
                            set uv [lreplace $uv 0 0 1.0]
                        }
                    }
                }
            } else {
                puts "[mkEntLink $con] missing egadsID for point $i [mkXYZLink [$con getXYZ $i]]"
            }

            if {$i == 1 || $i == $dim} {
                # nodes will map to EGADS vertex, use curve ID instead
                set egadsID $conEgadsID
            }
            
            set lastU [lindex $uv 0]
            set str [format $fmt \
                $globalPointInd($con,$i) $egadsID $lastU ]
            puts $f $str
        }
        incr egadsEdgeConCount
    }
    puts "GMA contains $egadsEdgeConCount edge groups"
    
    set endTime [clock clicks -milliseconds]
    # puts " add write cons [format {%.2f secs} [expr ($endTime-$startTime) * 0.001]]" 
    set startTime [clock clicks -milliseconds]
    
    # write dom faces which map to EGADS faces
    if {[info exists egadsFaceDoms(bad_doms)]} {
        foreach dom $egadsFaceDoms(bad_doms) {
            puts "[$dom getName] maps to more than one EGADS face ID"
            puts "$egadsFaceDoms(bad_doms_egadsIDs)"
        }
    }
    set fmt "%8d %12d %25.16e %25.16e"
    foreach dom $egadsFaceDoms(doms) {
        set num_tri [pw::Grid getElementCount Triangle $dom]    
        set num_quad [pw::Grid getElementCount Quad $dom]
        
        set dims [$dom getDimensions]
        set id [lindex $dims 0]
        set jd [lindex $dims 1]
        
        puts $f "#Dom [$dom getName]"
        
        if {$egadsFaceDoms($dom,isPeriodicDB) && $verbose} {
            puts "support geom for [mkEntLink $dom] is periodic in $egadsFaceDoms($dom,periodicDir)"
        }

        set numUniquePts [expr $id * $jd]
        set numpts [expr $numUniquePts + [llength $domPeriodicPts($dom,domInds)] - $domPeriodicPts($dom,numSingularPts)]
        
        puts $f "# WholeDomEgadsID  NumPoints NumTris NumQuads"
        puts $f [format "%d %d %d %d" $egadsFaceDoms($dom,egadsID) \
                $numpts $num_tri $num_quad]
        
        puts $f "# GlobalUniquePointIndex PointEgadsSurfaceID PointEgadsSurfaceUVParam"
        
        # write dom points, then dom faces using local indexing
        set tol $dbAssembleTol
        for {set j 1} {$j <= $jd} {incr j} {
            for {set i 1} {$i <= $id} {incr i} {

                if [$dom isOfType pw::DomainStructured] {
                    set ind [$dom getLinearIndex "$i $j"]
                } else {
                    set ind $i
                }
                set gridPoint [$dom getPoint $ind]
                set egadsID [getEgadsIDByGridPoint $gridPoint]
                
                if { 0 < [llength $egadsID] } {
                    set uv [lreplace $gridPoint 2 2]
                } else {
                    puts "[mkEntLink $dom] missing egadsID for point $ind [mkXYZLink [$dom getXYZ $ind]]"
                }

                if { ![$dom isInteriorIndex $ind] } {
                    # domain boundary points will map to curves or vertices,
                    # must be projected to determine surface UV
                    set gridPoint [GetDomBdryPointUV $dom $egadsFaceDoms($dom,dbEnts) $ind $tol]
                    set uv [lreplace $gridPoint 2 2]
                    set egadsFaceDoms($dom,dbEnts) 
                    set egadsID $egadsFaceDoms($dom,egadsID)
                }
                set domUV($ind) $uv

                set str [format $fmt \
                    $globalPointInd($dom,$ind) $egadsID [lindex $uv 0] [lindex $uv 1]]
                puts $f $str
            
            }
        }

        # write "high-side" UV copy of periodic points
        set localInd $numUniquePts
        foreach domInd $domPeriodicPts($dom,domInds) {
        
            if {[info exists domBoundaryNode($dom,$domInd,node)] &&
                $domBoundaryNode($dom,$domInd,singularity)} {
                # don't map singularity
                continue
            }
        
            incr localInd
            set domPeriodicPts($dom,$domInd,highInd) $localInd
            set egadsID $egadsFaceDoms($dom,egadsID)
            set gridPoint $domPeriodicPts($dom,$domInd,uv,high)
            set uv [lreplace $gridPoint 2 2]
            set str [format $fmt \
                $globalPointInd($dom,$domInd) $egadsID [lindex $uv 0] [lindex $uv 1]]
            puts $f $str
        }
        
        
        puts $f "# Cell's LocalPointIndices "

        if [$dom isOfType pw::DomainUnstructured] {
            set num_cells [$dom getCellCount]
            # We're relying on the fact that domain getCell
            # returns all tris followed by all quads.
            for {set i 1} {$i <= $num_cells} {incr i} {
                set cell [$dom getCell $i]
                set localInds [list]
                set localPeriodicInds [list]
                set localNonPeriodicInds [list]
                foreach ind $cell {
                   lappend localInds $ind
                   
                    if {$egadsFaceDoms($dom,isPeriodicDB)} {
                        set perInd [lsearch -exact $domPeriodicPts($dom,domInds) $ind]
                        if {-1 == $perInd} {
                            lappend localNonPeriodicInds $ind
                        } else {
                            lappend localPeriodicInds $ind
                        }
                    }
                }
                
                if [llength $localPeriodicInds] {
                    # cell uses periodic indices
                    # map periodic "side" based on avgUV of non-periodic inds
                    set avgU 0.0
                    set avgV 0.0
                    if {[llength $localNonPeriodicInds] < 1} {
                        error "tri uses periodic ind, but has no non-periodic inds"
                    }
                    foreach ind $localNonPeriodicInds {
                        set avgU [expr $avgU + [lindex $domUV($ind) 0]]
                        set avgV [expr $avgV + [lindex $domUV($ind) 1]]
                    }
                    set avgU [expr $avgU / [llength $localNonPeriodicInds]]
                    set avgV [expr $avgV / [llength $localNonPeriodicInds]]
                    
                    set side "low"
                    switch $egadsFaceDoms($dom,periodicDir) {
                    U { if {$avgU > 0.5} { set side "high" } }
                    V { if {$avgV > 0.5} { set side "high" } }
                    default {error "bad side"}
                    }
                    if {$side == "high"} {
                        # switch cell index to high-side UV index
                        set oldLocalInds $localInds
                        set localInds [list]
                        foreach ind $oldLocalInds {
                        
                            set perInd [lsearch -exact $domPeriodicPts($dom,domInds) $ind]
                            if {-1 != $perInd} {

                                if {[info exists domBoundaryNode($dom,$ind,node)] &&
                                    $domBoundaryNode($dom,$ind,singularity)} {
                                    # don't map singularity
                                    lappend localInds $ind
                                } else {
                                    lappend localInds "$domPeriodicPts($dom,$ind,highInd)"
                                }                            
                                
                            } else {
                                lappend localInds $ind
                            }
                        }
                    }
                }
                
                puts $f "$localInds"
            }
        
        } elseif [$dom isOfType pw::DomainStructured] {
            set dims [$dom getDimensions]
            set id [lindex $dims 0]
            set jd [lindex $dims 1]
            for {set j 1} {$j < $jd} {incr j} {
                for {set i 1} {$i < $id} {incr i} {
                    # Note: domain getCell could return a tri if 
                    # the domain contains a pole connector.  
                    # We are not handling this case appropriately since 
                    # the tris and quads will be interleaved.
                    set cell [$dom getCell "$i $j"]
                    set localInds [list]
                    foreach ind $cell {
                        lappend localInds $ind
                    }
                    puts $f "$localInds"
                }
            }
        }
    }
    puts "GMA contains [llength $egadsFaceDoms(doms)] face groups"
    
    set endTime [clock clicks -milliseconds]
    # puts " add write doms [format {%.2f secs} [expr ($endTime-$startTime) * 0.001]]" 
    set startTime [clock clicks -milliseconds]
    
    close $f

    set msgs [array names egadsCurveMapMsgs]
    foreach msg $msgs {
       puts "  $msg"
    }

    puts "Wrote geometry-mesh associativity to $fname"
    # set endTime [clock clicks -milliseconds]
    # puts "elapsed time [format {%.2f} [expr ($endTime-$startTime)*0.001]]"
}

# TEST - export geometry-mesh associativity file for all blocks
if 0 {
    set scriptDir [file dirname [info script]]
    set writeDir $scriptDir
    
    source [file join $scriptDir "GMDatabaseUtility.glf"]
    source [file join $scriptDir "GMMeshParamCoords.glf"]
    source [file join $scriptDir "GMSafe.glf"]
    source [file join $scriptDir "GMUtility.glf"]
    
    set blks [pw::Grid getAll -type pw::Block]
    foreach blk $blks {
        set blkName [$blk getName]

        set scriptDir [file dirname [info script]]
        set fname [file join $writeDir "${blkName}.gma"]

        writeEgadsAssocFile $blk $fname 2
    }
}


#############################################################################
#
# This file is licensed under the Cadence Public License Version 1.0 (the
# "License"), a copy of which is found in the included file named "LICENSE",
# and is distributed "AS IS." TO THE MAXIMUM EXTENT PERMITTED BY APPLICABLE
# LAW, CADENCE DISCLAIMS ALL WARRANTIES AND IN NO EVENT SHALL BE LIABLE TO
# ANY PARTY FOR ANY DAMAGES ARISING OUT OF OR RELATING TO USE OF THIS FILE.
# Please see the License for the full text of applicable terms.
#
#############################################################################
