#
# Copyright 2019 (c) Pointwise, Inc.
# All rights reserved.
#
# This sample Pointwise script is not supported by Pointwise, Inc.
# It is provided freely for demonstration purposes only.
# SEE THE WARRANTY DISCLAIMER AT THE BOTTOM OF THIS FILE.
#
#
# GeomToMesh: Geometry-Mesh associativity utility functions
#
# Export geometry-mesh associativity UVS parameter for each db constrained block point
# Utilize the CAE mesh file point indices and egadsID db entity attribute
#

package require PWI_Glyph

# Compute unique index for a domain point
proc GetDomN { i j id } {
   return [expr $id*($j-1)+$i]
}

###############################################################################
# PROC LoadGlobalPointIndex
# Enumerate the grid points uniquely
#
# Store the unique index at each topological representation
#   globalPointInd($node)             - unique point index of node
#   globalPointInd($con,$conInd)      - unique point index of con grid point conInd
#   globalPointInd($dom,$domInd)      - unique point index of dom grid point domInd
#
# Also store the unique point count and location
#   globalPoints(num)
#   globalPoints($i)
#
proc LoadGlobalPointIndex { { blks {} } } {
    global globalPointInd globalPoints

    catch { unset globalPointInd }
    catch { unset globalPoints }

    set globalPointID 1
    set globalCellID 1

    set singleBlockMode 1

    # We must determine a unique grid point index for each point
    #   if singleBlockMode = TRUE
    #     Enumerate the points in the order they appear in the block
    #   else
    #     Enumerate the points in the following order
    #       Nodes
    #       Connector interior points
    #       Domain interior points

    if { [llength $blks] == 0 } {
        set blks [pw::Grid getAll -type pw::Block]
    }

    # gather the domains and connectors for the block(s)
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
                }
                set nedge [$dom getEdgeCount]
                for { set iedge 1 } { $iedge <= $nedge } { incr iedge } {
                    set edge [$dom getEdge $iedge]
                    set ncon [$edge getConnectorCount]
                    for { set icon 1 } { $icon <= $ncon } { incr icon } {
                        set con [$edge getConnector $icon]
                        if { ! [info exists refCons($con)] } {
                            set refCons($con)  1
                            lappend cons $con
                        }
                    }
                }
            }
        }
    }

    # gather the unique set of nodes
    foreach con $cons {
        set refNodes([$con getNode Begin]) 1
        set refNodes([$con getNode End]) 1
    }
    set nodes [array names refNodes]

    # uniquely identify nodes globally
    if { ! $singleBlockMode } {
        foreach node $nodes {
            set globalPointInd($node) $globalPointID
            incr globalPointID
        }
    }

    # uniquely identify connector points globally
    if { ! $singleBlockMode } {
        foreach con $cons {
            set dim [$con getDimension]
            set globalPointInd($con,1) $globalPointInd([$con getNode 1])
            set globalPointInd($con,$dim) $globalPointInd([$con getNode 2])
            for { set i 2 } { $i < $dim } { incr i } {
                set globalPointInd($con,$i) $globalPointID
                incr globalPointID
            }

            # debugging
            if 0 {
                for { set i 1 } { $i <= $dim } { incr i } {
                    set name [$con getName]
                    puts "$name $i $globalPointInd($con,$i) [$con getXYZ -grid $i]"
                }
            }
        }
    }

    foreach dom $doms {
        set name [$dom getName]
        set dims [$dom getDimensions]

        set nedge [$dom getEdgeCount]
        set interiorPtOffset 0
        if { 1 == [lindex $dims 1] } {
            # unstructured
            set domInd 1
            for { set iedge 1 } { $iedge <= $nedge } { incr iedge } {
                set edge [$dom getEdge $iedge]
                set ncon [$edge getConnectorCount]
                for { set i 1 } { $i <= $ncon } { incr i } {
                    set con [$edge getConnector $i]
                    set orient [$edge getConnectorOrientation $i]
                    set dim [$con getDimension]
                    set doCon 1
                    if [info exists globalPointInd($con,1)] {
                        set doCon 0
                    }
                    if { $orient == "Same" } {
                        if { $doCon && $singleBlockMode } {
                            set node [$con getNode 1]
                            if { ! [info exists globalPointInd($node)] } {
                                set globalPointInd($node) $globalPointID
                                incr globalPointID
                            }
                            set globalPointInd($con,1) $globalPointInd($node)
                            for { set ic 2 } { $ic < $dim } { incr ic } {
                                set globalPointInd($con,$ic) $globalPointID
                                incr globalPointID
                            }
                            set node [$con getNode 2]
                            if { ! [info exists globalPointInd($node)] } {
                                set globalPointInd($node) $globalPointID
                                incr globalPointID
                            }
                            set globalPointInd($con,$dim) $globalPointInd($node)
                        }
                        set beg 1
                        set end [expr [$con getDimension]-1]
                        for  { set cind $beg } { $cind <= $end } { incr cind } {
                            set globalPointInd($dom,$domInd) $globalPointInd($con,$cind)
                            incr interiorPtOffset
                            incr domInd
                        }
                    } else {
                        if { $doCon && $singleBlockMode } {
                            set node [$con getNode 2]
                            if { ! [info exists globalPointInd($node)] } {
                                set globalPointInd($node) $globalPointID
                                incr globalPointID
                            }
                            set globalPointInd($con,$dim) $globalPointInd($node)
                            for { set ic [expr $dim-1] } { $ic >= 2 } { incr ic -1 } {
                                set globalPointInd($con,$ic) $globalPointID
                                incr globalPointID
                            }
                            set node [$con getNode 1]
                            if { ! [info exists globalPointInd($node)] } {
                                set globalPointInd($node) $globalPointID
                                incr globalPointID
                            }
                            set globalPointInd($con,1) $globalPointInd($node)
                        }
                        set beg [$con getDimension]
                        set end 2
                        for  { set cind $beg } { $cind >= $end } { incr cind -1 } {
                            set globalPointInd($dom,$domInd) $globalPointInd($con,$cind)
                            incr interiorPtOffset
                            incr domInd
                        }
                    }
                }
            }
            set globalPointInd($dom,interiorPtOffset) $interiorPtOffset
            set numPts [expr [lindex $dims 0] * [lindex $dims 1]]
            for { set domInd [expr $interiorPtOffset+1] } { $domInd <= $numPts } { incr domInd } {
                set globalPointInd($dom,$domInd) $globalPointID
                incr globalPointID
            }
        } else {
            # structured
            set globalPointInd($dom,interiorPtOffset) 0
            set numPts [expr [lindex $dims 0] * [lindex $dims 1]]
            set id [lindex $dims 0]
            set jd [lindex $dims 1]
            # j=1 edge
            set edge [$dom getEdge 1]
            set ncon [$edge getConnectorCount]
            set domI 0
            set domJ 1
            set dim $id
            for { set i 1 } { $i <= $ncon } { incr i } {
                set con [$edge getConnector $i]
                set orient [$edge getConnectorOrientation $i]
                set doCon 1
                if [info exists globalPointInd($con,1)] {
                    set doCon 0
                }
                if { $orient == "Same" } {
                    if { $doCon && $singleBlockMode } {
                        set node [$con getNode 1]
                        if { ! [info exists globalPointInd($node)] } {
                            set globalPointInd($node) $globalPointID
                            incr globalPointID
                        }
                        set globalPointInd($con,1) $globalPointInd($node)
                        for { set ic 2 } { $ic < $dim } { incr ic } {
                            set globalPointInd($con,$ic) $globalPointID
                            incr globalPointID
                        }
                        set node [$con getNode 2]
                        if { ! [info exists globalPointInd($node)] } {
                            set globalPointInd($node) $globalPointID
                            incr globalPointID
                        }
                        set globalPointInd($con,$dim) $globalPointInd($node)
                    }
                    set beg 1
                    set end [expr [$con getDimension]-0]
                    for  { set cind $beg } { $cind <= $end } { incr cind } {
                        incr domI
                        set domInd [GetDomN $domI $domJ $id]
                        set globalPointInd($dom,$domInd) $globalPointInd($con,$cind)
                    }
                } else {
                    if { $doCon && $singleBlockMode } {
                        set node [$con getNode 2]
                        if { ! [info exists globalPointInd($node)] } {
                            set globalPointInd($node) $globalPointID
                            incr globalPointID
                        }
                        set globalPointInd($con,$dim) $globalPointInd($node)
                        for { set ic [expr $dim-1] } { $ic >= 2 } { incr ic -1 } {
                            set globalPointInd($con,$ic) $globalPointID
                            incr globalPointID
                        }
                        set node [$con getNode 1]
                        if { ! [info exists globalPointInd($node)] } {
                            set globalPointInd($node) $globalPointID
                            incr globalPointID
                        }
                        set globalPointInd($con,1) $globalPointInd($node)
                    }
                    set beg [$con getDimension]
                    set end 1
                    for  { set cind $beg } { $cind >= $end } { incr cind -1 } {
                        incr domI
                        set domInd [GetDomN $domI $domJ $id]
                        set globalPointInd($dom,$domInd) $globalPointInd($con,$cind)
                    }
                }
            }

            # j=jd edge
            set edge [$dom getEdge 3]
            set ncon [$edge getConnectorCount]
            set domI [expr $id+1]
            set domJ $jd
            set dim $id
            for { set i 1 } { $i <= $ncon } { incr i } {
                set con [$edge getConnector $i]
                set orient [$edge getConnectorOrientation $i]
                set doCon 1
                if [info exists globalPointInd($con,1)] {
                    set doCon 0
                }
                if { $orient == "Same" } {
                    if { $doCon && $singleBlockMode } {
                        set node [$con getNode 1]
                        if { ! [info exists globalPointInd($node)] } {
                            set globalPointInd($node) $globalPointID
                            incr globalPointID
                        }
                        set globalPointInd($con,1) $globalPointInd($node)
                        for { set ic 2 } { $ic < $dim } { incr ic } {
                            set globalPointInd($con,$ic) $globalPointID
                            incr globalPointID
                        }
                        set node [$con getNode 2]
                        if { ! [info exists globalPointInd($node)] } {
                            set globalPointInd($node) $globalPointID
                            incr globalPointID
                        }
                        set globalPointInd($con,$dim) $globalPointInd($node)
                    }
                    set beg 1
                    set end [expr [$con getDimension]-0]
                    for  { set cind $beg } { $cind <= $end } { incr cind } {
                        incr domI -1
                        set domInd [GetDomN $domI $domJ $id]
                        set globalPointInd($dom,$domInd) $globalPointInd($con,$cind)
                    }
                } else {
                    if { $doCon && $singleBlockMode } {
                        set node [$con getNode 2]
                        if { ! [info exists globalPointInd($node)] } {
                            set globalPointInd($node) $globalPointID
                            incr globalPointID
                        }
                        set globalPointInd($con,$dim) $globalPointInd($node)
                        for { set ic [expr $dim-1] } { $ic >= 2 } { incr ic -1 } {
                            set globalPointInd($con,$ic) $globalPointID
                            incr globalPointID
                        }
                        set node [$con getNode 1]
                        if { ! [info exists globalPointInd($node)] } {
                            set globalPointInd($node) $globalPointID
                            incr globalPointID
                        }
                        set globalPointInd($con,1) $globalPointInd($node)
                    }
                    set beg [$con getDimension]
                    set end 1
                    for  { set cind $beg } { $cind >= $end } { incr cind -1 } {
                        incr domI -1
                        set domInd [GetDomN $domI $domJ $id]
                        set globalPointInd($dom,$domInd) $globalPointInd($con,$cind)
                    }
                }
            }

            # i=1 edge
            set edge [$dom getEdge 4]
            set ncon [$edge getConnectorCount]
            set domI 1
            set domJ [expr $jd+1]
            set dim $jd
            for { set i 1 } { $i <= $ncon } { incr i } {
                set con [$edge getConnector $i]
                set orient [$edge getConnectorOrientation $i]
                set doCon 1
                if [info exists globalPointInd($con,1)] {
                    set doCon 0
                }
                if { $orient == "Same" } {
                    if { $doCon && $singleBlockMode } {
                        set node [$con getNode 1]
                        if { ! [info exists globalPointInd($node)] } {
                            set globalPointInd($node) $globalPointID
                            incr globalPointID
                        }
                        set globalPointInd($con,1) $globalPointInd($node)
                        for { set ic 2 } { $ic < $dim } { incr ic } {
                            set globalPointInd($con,$ic) $globalPointID
                            incr globalPointID
                        }
                        set node [$con getNode 2]
                        if { ! [info exists globalPointInd($node)] } {
                            set globalPointInd($node) $globalPointID
                            incr globalPointID
                        }
                        set globalPointInd($con,$dim) $globalPointInd($node)
                    }
                    set beg 1
                    set end [expr [$con getDimension]-0]
                    for  { set cind $beg } { $cind <= $end } { incr cind } {
                        incr domJ -1
                        set domInd [GetDomN $domI $domJ $id]
                        set globalPointInd($dom,$domInd) $globalPointInd($con,$cind)
                    }
                } else {
                    if { $doCon && $singleBlockMode } {
                        set node [$con getNode 2]
                        if { ! [info exists globalPointInd($node)] } {
                            set globalPointInd($node) $globalPointID
                            incr globalPointID
                        }
                        set globalPointInd($con,$dim) $globalPointInd($node)
                        for { set ic [expr $dim-1] } { $ic >= 2 } { incr ic -1 } {
                            set globalPointInd($con,$ic) $globalPointID
                            incr globalPointID
                        }
                        set node [$con getNode 1]
                        if { ! [info exists globalPointInd($node)] } {
                            set globalPointInd($node) $globalPointID
                            incr globalPointID
                        }
                        set globalPointInd($con,1) $globalPointInd($node)
                    }
                    set beg [$con getDimension]
                    set end 1
                    for { set cind $beg } { $cind >= $end } { incr cind -1 } {
                        incr domJ -1
                        set domInd [GetDomN $domI $domJ $id]
                        set globalPointInd($dom,$domInd) $globalPointInd($con,$cind)
                    }
                }
            }

            # i=id edge
            set edge [$dom getEdge 2]
            set ncon [$edge getConnectorCount]
            set domI $id
            set domJ 0
            set dim $jd
            for { set i 1 } { $i <= $ncon } { incr i } {
                set con [$edge getConnector $i]
                set orient [$edge getConnectorOrientation $i]
                set doCon 1
                if [info exists globalPointInd($con,1)] {
                    set doCon 0
                }
                if { $orient == "Same" } {
                    if { $doCon && $singleBlockMode } {
                        set node [$con getNode 1]
                        if { ! [info exists globalPointInd($node)] } {
                            set globalPointInd($node) $globalPointID
                            incr globalPointID
                        }
                        set globalPointInd($con,1) $globalPointInd($node)
                        for { set ic 2 } { $ic < $dim } { incr ic } {
                            set globalPointInd($con,$ic) $globalPointID
                            incr globalPointID
                        }
                        set node [$con getNode 2]
                        if { ! [info exists globalPointInd($node)] } {
                            set globalPointInd($node) $globalPointID
                            incr globalPointID
                        }
                        set globalPointInd($con,$dim) $globalPointInd($node)
                    }
                    set beg 1
                    set end [expr [$con getDimension]-0]
                    for { set cind $beg } { $cind <= $end } { incr cind } {
                        incr domJ
                        set domInd [GetDomN $domI $domJ $id]
                        set globalPointInd($dom,$domInd) $globalPointInd($con,$cind)
                    }
                } else {
                    if { $doCon && $singleBlockMode } {
                        set node [$con getNode 2]
                        if { ! [info exists globalPointInd($node)] } {
                            set globalPointInd($node) $globalPointID
                            incr globalPointID
                        }
                        set globalPointInd($con,$dim) $globalPointInd($node)
                        for { set ic [expr $dim-1] } { $ic >= 2 } { incr ic -1 } {
                            set globalPointInd($con,$ic) $globalPointID
                            incr globalPointID
                        }
                        set node [$con getNode 1]
                        if { ! [info exists globalPointInd($node)] } {
                            set globalPointInd($node) $globalPointID
                            incr globalPointID
                        }
                        set globalPointInd($con,1) $globalPointInd($node)
                    }
                    set beg [$con getDimension]
                    set end 1
                    for  { set cind $beg } { $cind >= $end } { incr cind -1 } {
                        incr domJ
                        set domInd [GetDomN $domI $domJ $id]
                        set globalPointInd($dom,$domInd) $globalPointInd($con,$cind)
                    }
                }
            }

            # interior points
            for { set j 1 } { $j <= $jd } { incr j } {
                for { set i 1 } { $i <= $id } { incr i } {
                    if { $i != 1 && $i != $id && $j != 1 && $j != $jd  } {
                        set domInd [GetDomN $i $j $id]
                        set globalPointInd($dom,$domInd) $globalPointID
                        incr globalPointID
                    }
                }
            }
        }

        set numPts [expr [lindex $dims 0] * [lindex $dims 1]]
        for { set domInd 1 } { $domInd <= $numPts } { incr domInd } {
            set globalPoints($globalPointInd($dom,$domInd)) [$dom getXYZ -grid $domInd]
        }
    }

    set globalPoints(num) [llength [array names globalPoints]]

    # debugging
    if 0 {
        for { set i 1 } { $i < 30 } { incr i } {
            puts "blk $i [$blk getXYZ $i]"
        }
    }
}

# return EGADS ID element in given dictionary
proc getEgadsID { params } {
    if [catch { dict get $params egadsID } id] {
        return ""
    }
    return $id
}

# return original EGADS ID element in given dictionary
proc getOrigEgadsID { params } {
    if [catch { dict get $params orig_egadsID } id] {
        return ""
    }
    return $id
}

# return EGADS face ID element in given dictionary
proc getEgadsFaceID { params } {
    if [catch { dict get $params _faceID } id] {
        return ""
    }
    return $id
}

# return EGADS ID of specified grid point
proc getEgadsIDByGridPoint { gridPoint } {
    set params [getEgadsDictionary $gridPoint]
    return [getEgadsID $params]
}

# return EGADS dictionary for the specified grid point
proc getEgadsDictionary { gridPoint } {
    set egads_dict_name "PW::Data"
    set params [pw::Database getAttributeDictionary $gridPoint $egads_dict_name]
    if { 0 == [llength $params] } {
        # NO ATTRIBUTE - try children
        set params [pw::Database getAttributeDictionary -children $gridPoint $egads_dict_name]
    }

    if { 0 == [llength $params] } {
        set egads_dict_name "PW::Egads"
        set params [pw::Database getAttributeDictionary $gridPoint $egads_dict_name]
        if { 0 == [llength $params] } {
            # NO ATTRIBUTE - try children
            set params [pw::Database getAttributeDictionary -children $gridPoint $egads_dict_name]
        }
    }

    return $params
}

# Generate a map of EGADS edge curves
proc mapEgadsCurves { } {
    global egadsCurveMap
    catch { unset egadsCurveMap }
    set attrNames [list "egadsID" "orig_egadsID"]
    set dbEnts [pw::Database getAll]
    foreach dbEnt $dbEnts {
        if { ! [$dbEnt isCurve] } { continue }
        set egadsID [getEgadsID [getEgadsDictionary [list 0.1 0.0 $dbEnt]]]
        if { 0 < [llength $egadsID] } {
            set curveID($dbEnt) $egadsID
        } else {
            # puts "    missing egadsID"
        }
        set egadsID [getOrigEgadsID [getEgadsDictionary [list 0.1 0.0 $dbEnt]]]
        if { 0 < [llength $egadsID] } {
            set orig_curve($egadsID) $dbEnt
        }
    }

    set ents [array names curveID]
    foreach ent $ents {
        set id $curveID($ent)
        if [info exists orig_curve($id)] {
            set egadsCurveMap($ent) $orig_curve($id)
            # puts "Mapped [mkEntLink $ent] to [mkEntLink $orig_curve($id)] ($id)"
        } else {
            # puts "**NO MAP [mkEntLink $ent] ($id)"
        }
    }
}

# Return parametric coordinates of projected point on EGADS curve
proc getUVOnOriginalEgadsCurve { xyz uvs } {
    global egadsCurveMap egadsCurveMapMsgs

    set curve [lindex $uvs 2]
    set new_uvs $uvs
    if [info exists egadsCurveMap($curve)] {
        set orig_curve $egadsCurveMap($curve)
        set new_uvs [$orig_curve closestPoint -distance dist $xyz]
        # puts "Mapped $uvs to $new_uvs"
        set tol [pw::Database getSamePointTolerance]
        if { $dist > $tol } {
            set msg "WARNING: projection distance [format "(%.6g)" $dist] to EGADS curve exceeds tolerance"
            set egadsCurveMapMsgs($msg) 1
            # puts [format "%25.16e %25.16e %25.16e" [lindex $xyz 0] [lindex $xyz 1] [lindex $xyz 2]]
            # set xyz [pw::Application getXYZ $new_uvs]
            # puts [format "%25.16e %25.16e %25.16e" [lindex $xyz 0] [lindex $xyz 1] [lindex $xyz 2]]
        }
    } else {
        # puts "**NO CURVE MAP [mkEntLink $curve]"
        set msg "WARNING: No EGADS curve map for [mkEntLink $curve], exporting native UV"
        set egadsCurveMapMsgs($msg) 1
    }
    return $new_uvs
}

# Return whether the given is a vertex
proc isVertex { id } {
    set VERTEXID 6
    set type [expr $id >> 28]
    if { $type == $VERTEXID } {
        return 1
    }
    return 0
}

# Return a decomposed EGADS ID as list of type, body ID and index
proc decodeEgadsID { id } {
    if { [llength $id] < 1 } {
        return [list]
    }
    # set MODELID  0
    # set SHELLID  1
    # set FACEID   2
    # set LOOPID   3
    # set EDGEID   4
    # set COEDGEID 5
    # set VERTEXID 6
    set types [list Model Shell Face Loop Edge CoEdge Vertex]

    #define PACK(t, m, i)       ((t)<<28 | (m)<<20 | (i))
    #define UNPACK(v, t, m, i)  t = v>>28; m = (v>>20)&255; i = v&0xFFFFF;
    set type [expr $id >> 28]
    set bodyID [expr ($id >> 20) & 0xFF]
    set index [expr $id & 0xFFFFF]
    set typeStr [lindex $types $type]
    return [list $typeStr $bodyID $index]
}

# Write the geometry map file for the given set of blocks
# GMA file format
# <number of points>
#    grid_file_point_index  EGADS_entity_ID U V (one point per line)
# EGADS Edge Groups (connectors constrained to EGADS edge geometry)
#  EGADS_edge_ID  number_of_points_on_edge
#    grid_file_point_indices (one point per line)
# EGADS Face Groups (domains constrained to EGADS edge geometry)
#  EGADS_face_ID  number_of_tri_faces_on_face number_of_quad_faces_on_face
#    mesh face indices (grid file point indices forming face) (one face per line)
proc WriteGeomMapFile { fname blks { debugFormat 0 } } {
    global globalPointInd globalPoints domCellEdge
    global egadsCurveMapMsgs

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

    set meshPoint(num) 0

    # add connector points
    foreach con $cons {
        set conName [$con getName]

        set node [$con getNode Begin]
        set gridPoint [$con getPoint 1]
        set egadsID [getEgadsIDByGridPoint $gridPoint]
        set index $globalPointInd($node)

        if { 0 < [llength $egadsID] && ! [info exists meshPoint($index)] } {
            set meshPoint($index) 1
            set meshPoint($meshPoint(num),ind) $index
            set meshPoint($meshPoint(num),xyz) [$con getXYZ 1]
            set meshPoint($meshPoint(num),egadsID) $egadsID
            if [isVertex $egadsID] {
                set uv [list 0.0 0.0]
            } else {
                set gridPoint [getUVOnOriginalEgadsCurve $meshPoint($meshPoint(num),xyz) $gridPoint]
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
            if { 0 < [llength $egadsID] && ! [info exists meshPoint($index)] } {
                set meshPoint($index) 1
                set meshPoint($meshPoint(num),ind) $index
                set meshPoint($meshPoint(num),xyz) [$con getXYZ $i]
                set meshPoint($meshPoint(num),egadsID) $egadsID
                if [isVertex $egadsID] {
                    set uv [list 0.0 0.0]
                } else {
                    set gridPoint [getUVOnOriginalEgadsCurve $meshPoint($meshPoint(num),xyz) $gridPoint]
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
        if { 0 < [llength $egadsID] && ! [info exists meshPoint($index)] } {
            set meshPoint($index) 1
            set meshPoint($meshPoint(num),ind) $index
            set meshPoint($meshPoint(num),xyz) [$con getXYZ $dim]
            set meshPoint($meshPoint(num),egadsID) $egadsID
            if [isVertex $egadsID] {
                set uv [list 0.0 0.0]
            } else {
                set gridPoint [getUVOnOriginalEgadsCurve $meshPoint($meshPoint(num),xyz) $gridPoint]
                set uv [lreplace $gridPoint 2 2]
            }
            set meshPoint($meshPoint(num),uv) $uv
            incr meshPoint(num)
        }
    }

    # add domain interior points
    catch {unset egadsFaceDoms}
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
        
        set domEgadsID 0
        set markedBadDom 0

        set dim [$dom getPointCount]
        for { set domInd 1 } { $domInd <= $dim } { incr domInd } {
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
            if { 0 < [llength $egadsID] && ! [info exists meshPoint($index)] } {
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

    # write the map file
    if [catch { open $fname "w" } f] {
        puts $f
        return -code error "Could not open file $fname: $f"
    }

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
    
    # write con points which map to EGADS edges
    set egadsEdgeConCount 0
    foreach con $cons {
        set conName [$con getName]
        set dim [$con getDimension]
        set conEgadsID 0
        
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
            set conEgadsID [getEgadsIDByGridPoint $gridPoint]
            if {0 == [llength $conEgadsID]} {
                puts "Unable to map $conName to EGADS edge ID"
                continue
            }
            
            # check that other interior points map to same EgadsID
            for { set i 3 } { $i < $dim } { incr i } {
                set gridPoint [$con getPoint $i]
                set egadsID [getEgadsIDByGridPoint $gridPoint]
                if { $egadsID != $conEgadsID } {
                    puts "$conName maps to more than one EGADS edge ID"
                    puts "$egadsID != $conEgadsID"
                    set conEgadsID 0
                    break
                }
            }
        }
        
        if {$conEgadsID == 0} {
            puts "Unable to map $conName to EGADS edge ID"
            continue
        }
        
        # con maps to single EGADS edge ID - write points
        puts $f [format "%d %d" $conEgadsID $dim]
        for { set i 1 } { $i <= $dim } { incr i } {
            puts $f $globalPointInd($con,$i)
        }
        incr egadsEdgeConCount
    }
    puts "GMA contains $egadsEdgeConCount edge groups"

    # write dom faces which map to EGADS faces
    if {[info exists egadsFaceDoms(bad_doms)]} {
        foreach dom $egadsFaceDoms(bad_doms) {
            puts "[$dom getName] maps to more than one EGADS face ID"
            puts "$egadsFaceDoms(bad_doms_egadsIDs)"
        }
    }
    foreach dom $egadsFaceDoms(doms) {
        set num_tri [pw::Grid getElementCount Triangle $dom]    
        set num_quad [pw::Grid getElementCount Quad $dom]
        puts $f [format "%d %d %d" $egadsFaceDoms($dom,egadsID) $num_tri $num_quad]
        
        if [$dom isOfType pw::DomainUnstructured] {
            set num_cells [$dom getCellCount]
            # We're relying on the fact that domain getCell
            # returns all tris followed by all quads.
            for {set i 1} {$i <= $num_cells} {incr i} {
                set cell [$dom getCell $i]
                set globalInds ""
                foreach ind $cell {
                   lappend globalInds $globalPointInd($dom,$ind)
                }
                puts $f $globalInds
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
                    set globalInds ""
                    foreach ind $cell {
                       lappend globalInds $globalPointInd($dom,$ind)
                    }
                    puts $f $globalInds
                }
            }
        }
    }
    puts "GMA contains [llength $egadsFaceDoms(doms)] face groups"
    
    close $f

    set msgs [array names egadsCurveMapMsgs]
    foreach msg $msgs {
       puts "  $msg"
    }

    puts "Wrote geometry-mesh associativity to $fname"
}

# Write the EGACS associativity file for the given block
proc writeEgadsAssocFile { blk fname } {
    global globalPointInd globalPoints

    # Enumerate points by global index
    LoadGlobalPointIndex $blk

    # Map db curves to EGADS originals (preserves parameterization)
    mapEgadsCurves

    WriteGeomMapFile $fname $blk
}

# TEST - export geometry-mesh associativity file for all blocks
if 0 {
    set blks [pw::Grid getAll -type pw::Block]
    foreach blk $blks {
        set blkName [$blk getName]

        set scriptDir [file dirname [info script]]
        set fname [file join $scriptDir "${blkName}.gma"]

        writeEgadsAssocFile $blk $fname
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
