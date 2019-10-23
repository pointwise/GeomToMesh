#
# Copyright 2019 (c) Pointwise, Inc.
# All rights reserved.
#
# This sample Pointwise script is not supported by Pointwise, Inc.
# It is provided freely for demonstration purposes only.
# SEE THE WARRANTY DISCLAIMER AT THE BOTTOM OF THIS FILE.

# ========================================================================================
# RefineByFactor.glf
# ========================================================================================
# Written by Steve Karman

# Script for performing automatic mesh refinement by a prescribed factor (User defined below)
# The assumptions are:
#    1. Unstructured domains (and optionally a single block).
#    2. Basically developed in support of meshes created by GeomToMesh.glf and QuiltToSurfMesh.glf
#    3. The factor can be greater than 1 (refine) or less than 1 (coarsen), but not equal to 0 or negative.
#
#   The script will:
#   Scale the dimensions of each connector by the factor.
#   Change the end point spacing on each connector by 1 / factor.
#   All TRexConditions will be changed by 1 / factor. 
#   The domains will be refined or initialized.
#   If sources exist the beginning and ending spacing values will be changed by 1 / factor.
#   If a volume mesh exists and uses TRex the growth rate will
#   be changed by taking the current growth rate to the power of (1 / factor).
#   Then, if it exists, the single unstructured block will be initialized.
#
#   NOTE: No files will be read or written. It works on the mesh in memory and does not export it.

#
# Load Glyph and TK
package require PWI_Glyph

set factor [expr 12.0 / 11.0 ]

puts "-------------------------------"
puts "Refinement factor = $factor"
puts "-------------------------------"

#
# redimension connectors and adjust end spacing
#
set conList [pw::Grid getAll -type pw::Connector]
set conMode [pw::Application begin Modify $conList]
    set i 0
    foreach con $conList {
        incr i 1
    
        set dim [$con getDimension]
        if { $factor > 1.0 } {
            set newdim [expr { max ($dim+1,int(floor($factor * $dim))) } ]
        } else {
            set newdim [expr { max(2, min($dim-1,int(floor($factor * $dim)))) } ]
        }
    
        set sp [$con getAverageSpacing]
        set node0 [$con getNode Begin]
        set node1 [$con getNode End]
    
        set pt0 [$con getXYZ -grid 1]
        set pt1 [$con getXYZ -grid 2]
        set s0 [pwu::Vector3 length [pwu::Vector3 subtract $pt0 $pt1]]
    
        set pt0 [$con getXYZ -grid $dim]
        set pt1 [$con getXYZ -grid [expr $dim - 1]]
        set s1 [pwu::Vector3 length [pwu::Vector3 subtract $pt0 $pt1]]
    
        $con setDistribution 1 [pw::DistributionTanh create]
    
        puts "Connector $i/[llength $conList] [$con getName]"
        puts "  current dim = $dim, new dim = $newdim"
    
        if { [expr abs(($sp - $s0)/$sp) ] > 0.01 || [expr abs(($sp - $s1)/$sp) ] > 0.01} {
    
            # Set connector distribution type and synchronize end spacing
            set conDist [$con getDistribution 1]
    
            puts "  current spacing: s0 = $s0, s1 = $s1"
    
            set s0 [expr $s0 / $factor]
            set s1 [expr $s1 / $factor]
    
            puts "  new spacing: s0 = $s0, s1 = $s1"
    
            $conDist setBeginSpacing $s0
            $conDist setEndSpacing $s1
        }
    
        $con setDimension $newdim
    
    }
$conMode end

#
# change TRex conditions
#
set condNames [pw::TRexCondition getNames]

foreach name $condNames {

    if { ! [catch { pw::TRexCondition getByName $name } bc] } {

        set type [$bc getConditionType]
        if { "Wall" == $type } {
            set sp [$bc getSpacing]
            set newsp [expr $sp / $factor]
            puts "TRexCondition $name, wall spacing changed from $sp to $newsp"
            $bc setSpacing $newsp
        }
    }

}

#
# refine domains
#

set domList [pw::Grid getAll -type pw::DomainUnstructured]

foreach dom $domList {
    puts "  Refining domain [$dom getName]"
    set refineMode [pw::Application begin UnstructuredSolver [list $dom]]
    if { 0 != [catch { $refineMode run Refine } ] } {
        puts "  Running initialize instead for domain [$dom getName]"
        if { 0 != [catch { $refineMode run Initialize } ] } {
            puts "    Initialize failed for domain [$dom getName]"
            set blkParams(volInitialize) 0
        }
    }
    $refineMode end
    pw::Display update
}

#
# scale source spacing values
#
set srcList [pw::Source getAll]
puts "Number of source entities = [llength $srcList]"
foreach src $srcList {
    set bsp [$src getBeginSpacing]
    set newbsp [expr $bsp / $factor]
    puts "Source [$src getName] beginning spacing = $bsp changed to $newbsp"
    $src setBeginSpacing $newbsp

    set esp [$src getEndSpacing]
    set newesp [expr $esp / $factor]
    puts "Source [$src getName] ending spacing = $esp changed to $newesp"
    $src setEndSpacing $newesp
}

#
# reinitialize volume
#
set uBlk [pw::Grid getAll -type pw::BlockUnstructured]

set nblk [llength $uBlk]
puts "Number of unstructured blocks = $nblk"
if { 1 == $nblk } {
    set solveMode [pw::Application begin UnstructuredSolver $uBlk]
        set Growth [$uBlk getUnstructuredSolverAttribute TRexGrowthRate]
        puts "Current TRex growth rate = $Growth"
        if { $factor > 1.0 } {
            set Growth [expr $Growth ** (1.0 / $factor)]
        } else {
            set Growth [expr $Growth ** $factor]
        }
        puts "New TRex growth rate = $Growth"
        $uBlk setUnstructuredSolverAttribute TRexGrowthRate $Growth
    
        $solveMode setStopWhenFullLayersNotMet true
        $solveMode run Initialize
    $solveMode end
} else {
    puts "Invalid number of blocks!"
}

puts ""
puts "Pointwise script RefineByFactor.glf with factor = $factor has finished!"
puts ""

exit

#
# END SCRIPT
#

#
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

