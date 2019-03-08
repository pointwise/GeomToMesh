#
# Copyright 2019 (c) Pointwise, Inc.
# All rights reserved.
#
# This sample Pointwise script is not supported by Pointwise, Inc.
# It is provided freely for demonstration purposes only.
# SEE THE WARRANTY DISCLAIMER AT THE BOTTOM OF THIS FILE.

# ========================================================================================
# QuiltToSurfMesh
# ========================================================================================
# Written by Nick Wyman

#
# Script for performing automatic mesh generation.
# It is a simplified version of GeomToMesh.glf for automatically creating
# surface meshes once quilts of surfaces have been defined. Hence, this is
# run after the geometry has been imported and quilts have been assembled.
#

# Load Glyph and TK
package require PWI_Glyph

# ----------------------------------------------
# Define working directory and load scripts
# ----------------------------------------------
#
set scriptDir [file dirname [info script]]
source [file join $scriptDir "GMDatabaseUtility.glf"]
source [file join $scriptDir "GMUtility.glf"]

#
# Initialize global variables defaults
#

# Connector level
set conParams(InitDim)                      11; # Initial connector dimension
set conParams(MaxDim)                     1024; # Maximum connector dimension
set conParams(MinDim)                        5; # Minimum connector dimension
set conParams(TurnAngle)                   5.0; # Maximum turning angle on connectors (0 - not used)
set conParams(Deviation)                   0.0; # Maximum deviation on connectors (0 - not used)
set conParams(SplitAngle)                 40.0; # Turning angle on connectors to split (0 - not used)
set conParams(sourceDecay)          0.85; # Source decay for proximity dim/dist
set conParams(TurnAngleHard)              40.0; # Hard edge turning angle limit for domain T-Rex (0.0 - not used)
set conParams(edgeMaxGrowthRate)           1.8; # Max edge ratio

# Domain level
set domParams(SkipMeshing)                   1; # Skip meshing of domains during interim processing
set domParams(Algorithm)      "AdvancingFront"; # Isotropic (Delaunay, AdvancingFront or AdvancingFrontOrtho)
set domParams(FullLayers)                    0; # Domain full layers (0 for multi-normals, >= 1 for single normal)
set domParams(MaxLayers)                    25; # Domain maximum layers
set domParams(GrowthRate)                  1.2; # Domain growth rate for 2D T-Rex extrusion
set domParams(IsoType)              "Triangle"; # Domain iso cell type (Triangle or TriangleQuad)
set domParams(TRexType)             "Triangle"; # Domain T-Rex cell type (Triangle or TriangleQuad)
set domParams(TRexARLimit)                20.0; # Domain T-Rex maximum aspect ratio limit (0 - not used)
set domParams(HardEdgeTargetAR)        5.0; # Domain T-Rex hard edge target aspect ratio
set domParams(HardEdgeTRexARLimit)        10.0; # Domain T-Rex hard edge aspect ratio limit (0 - not used)

set domParams(Decay)                      0.80; # Domain boundary decay
set domParams(MinEdge)                     0.0; # Domain minimum edge length
set domParams(MaxEdge)                     0.0; # Domain maximum edge length

# General
set genParams(displayTRexCons)                  0; # Whether to render TRex connectors by type
set genParams(assembleTolMult)                 1.0; # Multiplier on model assembly tolerance for allowed MinEdge

set HLCRM 0;  # Define TRUE for HL-CRM model
if { $HLCRM } {
    set conParams(MinDim)                       21; # Minimum connector dimension
    set conParams(MaxDim)                     2024; # Maximum connector dimension
    set domParams(MaxEdge)                     4.0; # Domain maximum edge length
    set domParams(TRexARLimit)                60.0; # Domain T-Rex maximum aspect ratio limit (0 - not used)
    set domParams(HardEdgeTRexARLimit)        60.0; # Domain T-Rex hard edge aspect ratio limit (0 - not used)
    set genParams(assembleTolMult)             0.6; # Multiplier on model assembly tolerance for allowed MinEdge
}

# ----------------------------------------------
# Main procedure
# ----------------------------------------------
proc QuiltToSurfMesh { } {

    # Start Time
    timestamp
    set tBegin [clock seconds]

    set version [pw::Application getVersion]
    puts $version

    #
    # parameters from GUI or batch
    #
    global conParams domParams blkParams genParams eoeParams
    global CADFile UserDefaults

    #
    # echo PW defaults
    #
    puts "QuiltToSurfMesh: Defaults"
    puts "Connector level"
    puts "    InitDim                   = $conParams(InitDim)"
    puts "    MaxDim                    = $conParams(MaxDim)"
    puts "    MinDim                    = $conParams(MinDim)"
    puts "    TurnAngle                 = $conParams(TurnAngle)"
    puts "    TurnAngle (hard edge)     = $conParams(TurnAngleHard)"
    puts "    Deviation                 = $conParams(Deviation)"
    puts "    SplitAngle                = $conParams(SplitAngle)"
    puts "    SourceDecay               = $conParams(sourceDecay)"
    puts "    edgeMaxGrowthRate         = $conParams(edgeMaxGrowthRate)"
    puts "Domain level"
    puts "    Algorithm                 = $domParams(Algorithm)"
    puts "    FullLayers                = $domParams(FullLayers)"
    puts "    MaxLayers                 = $domParams(MaxLayers)"
    puts "    GrowthRate                = $domParams(GrowthRate)"
    puts "    IsoType                   = $domParams(IsoType)"
    puts "    TRexType                  = $domParams(TRexType)"
    puts "    TRexARLimit               = $domParams(TRexARLimit)"
    puts "    TRexARLimit (hard edge)   = $domParams(HardEdgeTRexARLimit)"
    puts "    Decay                     = $domParams(Decay)"
    puts "    MinEdge                   = $domParams(MinEdge)"
    puts "    MaxEdge                   = $domParams(MaxEdge)"
    puts "Block level"
    # puts "    boundaryDecay        = $blkParams(boundaryDecay)"

    #
    # set default parameters
    #
    if { $conParams(MinDim) > $conParams(InitDim) } {
        set conParams(InitDim) $conParams(MinDim)
    }
    if { 2 > $conParams(MinDim) } {
        set conParams(MinDim) 2
    }

    pw::Application setGridPreference Unstructured

    pw::Connector setDefault Dimension $conParams(InitDim)
    pw::Connector setCalculateDimensionMaximum $conParams(MaxDim)

    pw::DomainUnstructured setDefault Algorithm $domParams(Algorithm)
    pw::DomainUnstructured setDefault BoundaryDecay $domParams(Decay)
    pw::DomainUnstructured setDefault IsoCellType $domParams(IsoType)
    pw::DomainUnstructured setDefault TRexCellType $domParams(TRexType)
    if { 0.0 < $domParams(MinEdge) } {
        pw::DomainUnstructured setDefault EdgeMinimumLength $domParams(MinEdge)
    }
    if { 0.0 < $domParams(MaxEdge) } {
        pw::DomainUnstructured setDefault EdgeMaximumLength $domParams(MaxEdge)
    }

    #    ----------------------------
    #   | Create domains from quilts |
    #    ----------------------------
    #
    # gather quilts
    #
    set QuiltList {}

    set dbEnts [pw::Database getAll]
    puts "Dumping imported attributes for [llength $dbEnts] database entities"
    foreach dbEnt $dbEnts {
        # uncomment next line to see details of attributes for each db entity
        #dumpAttrs $dbEnt
        switch -- [$dbEnt getDescription] {
            Model {
                puts "Model is linked to [$dbEnt getName]"
                lappend ModelList $dbEnt
            }
            Quilt {
                puts "Quilt is linked to [$dbEnt getName]"
                lappend QuiltList [pw::DatabaseEntity getByName [$dbEnt getName]]
            }
            default {
            }
        }
    }
    puts "Model list has [llength $ModelList] entries."
    puts "Quilt list has [llength $QuiltList] entries."

    set conList [pw::Grid getAll -type pw::Connector]
    foreach con $conList {
        $con delete -force
    }

    #
    # create domains on models
    #
    pw::Connector setDefault Dimension $conParams(InitDim)
    pw::Connector setCalculateDimensionMethod Explicit

    SetDomSkipMeshing true

    set i 0
    setMinEdgeFromModelTolerance $ModelList

    foreach model $ModelList {
        set domMode [pw::DomainUnstructured createOnDatabase \
            -splitConnectors $conParams(SplitAngle) \
            -joinConnectors $conParams(SplitAngle) \
            -parametricConnectors EndToEnd -merge 0 -reject unusedSurfs $model]
        if { [llength $unusedSurfs] > 0 } {
            puts "Model [expr $i+1], unused surfaces exist."
            foreach surf $unusedSurfs {
                puts "  [$surf getName]"
            }
            puts "Try increasing base connector dimension conParams(InitDim)"
            exit
        }

        pw::Display update

        incr i 1
    }

    # compute tolerance for connector operations
    #
    set conList [pw::Grid getAll -type pw::Connector]
    puts "Original connector list has [llength $conList] entries."

    set minConLen 1.0e20
    foreach con $conList {
        set len [$con getLength -parameter 1.0]
        if { $len < $minConLen } {
            set minConLen $len
        }
    }
    puts "Minimum connector length = $minConLen"
    set tol [expr $minConLen / $conParams(InitDim) * 0.5]
    puts "Tolerance = $tol"

    #
    # Create list of unique connector endpoints and spacing values.
    # This will be adjusted in several subsequent functions.
    #
    set nodeList {}
    set nodeSpacing {}

    #    -----------------------------
    #   | Reduce connector dimension  |
    #   |  using avg sp and minDim    |
    #    -----------------------------
    reduceConnectorDimensionFromAvgSpacing $conParams(MinDim) $conParams(MaxDim) $conList nodeList nodeSpacing

    pw::Display update

    puts "Number of unique endpoints = [llength $nodeList]"

    #    -----------------------------
    #   |  Process baffle geometries  |
    #    -----------------------------
    if { 0 < [processBaffleIntersections $tol] } {
    }

    #  initialize domain T-Rex flag for connectors
    set conTRex {}

    #    ------------------------------
    #   | Increase connector dimension |
    #   | using deviation or turning   |
    #   | Set connector TRex flag      |
    #    ------------------------------
    if { 0.0 < $conParams(Deviation) || 0.0 < $conParams(TurnAngle) || 0.0 < $conParams(TurnAngleHard) } {
        increaseConnectorDimensionFromAngleDeviationQuilts $conList \
            $conParams(MaxDim) $conParams(TurnAngle) $conParams(Deviation)
    }

    pw::Display update

    #    ------------------------------
    #   | Increase connector dimension |
    #   | using proximity test         |
    #    ------------------------------
    # Preform source refinement from connector spacing
    puts "Performing Source Cloud Refinement"
    connectorSourceSpacing $conParams(sourceDecay)

    pw::Display update

    #
    # conMaxDS will hold the desired maximum delta s on each connector
    #  It is initialized to the length of the connector.
    #  If connector geometry attributes are specified in adjustNodeSpacingFromGeometry it is adjusted.
    #  Then it is passed to the final connector process connectorDimensionFromEndSpacing
    #
    set conMaxDS {}
    set conList [pw::Grid getAll -type pw::Connector]
    foreach con $conList {
        set len [$con getLength -parameter 1.0]
        lappend conMaxDS $len
    }

    #    ----------------------------
    #   | Apply connector attributes |
    #    ----------------------------
    #
    updateNodeSpacingList $conList nodeList nodeSpacing
    set meshChanged [adjustNodeSpacingFromGeometry $conParams(edgeMaxGrowthRate) \
        $conParams(MinDim) $conParams(MaxDim) conMaxDS nodeList nodeSpacing]

    if { $meshChanged } {
        # Preform source refinement from connector spacing
        puts "Performing Source Cloud Refinement"
        connectorSourceSpacing $conParams(sourceDecay)
        set meshChanged 0
    }

    pw::Display update

    set i 0
    foreach con $conList {
        set len [$con getLength -parameter 1.0]
        set ds [lindex $conMaxDS $i]
        if { $ds < $len } {
            puts "Connector [$con getName]: Max DS changed $len to $ds"
        }
        incr i
    }

    set domList [pw::Grid getAll -type pw::DomainUnstructured]
    puts "Domain list has [llength $domList] entries."

    if { [llength $domList] == 0 } {
        exit -1
    }

    #    -------------------------
    #   | Apply domain attributes |
    #    -------------------------
    # search for domain attributes from geometry
    #
    loadDomainAttributes

    #    --------------------------
    #   |   Set up domain T-Rex    |
    #    --------------------------
    # set up domain T-Rex using end point spacing values
    #
    if { 0 < $domParams(MaxLayers) } {
        set meshChanged [setup2DTRexBoundariesQuilts $domList $domParams(FullLayers) $domParams(MaxLayers) \
           $domParams(GrowthRate) $domParams(Decay) ]

        if { $meshChanged } {
            # Preform source refinement from connector spacing
            puts "Performing Source Cloud Refinement"
            connectorSourceSpacing $conParams(sourceDecay) 1
        }
    }

    set domList [pw::Grid getAll -type pw::DomainUnstructured]
    foreach dom $domList {
        $dom setUnstructuredSolverAttribute BoundaryDecay $domParams(Decay)
        $dom setUnstructuredSolverAttribute SwapCellsWithNoInteriorPoints True
        $dom setUnstructuredSolverAttribute TRexIsoTropicHeight [expr sqrt(3.0) / 2.0 ]
    }
    set haveSkipMeshing [HaveDomSkipMeshing]
    SetDomSkipMeshing false

    #    --------------------------
    #   |  Domain refinement pass  |
    #    --------------------------
    # do a refinement pass on all domains
    #
    puts "Performing refinement pass on all domains."
    foreach dom $domList {
        puts "Refining domain [$dom getName]"
        set refineMode [pw::Application begin UnstructuredSolver [list $dom]]
        if { $haveSkipMeshing } {
            if [catch { $refineMode run Initialize } msg] {
                puts "Initialize failed for domain [$dom getName] ($msg)"
            }
        } else {
            if [catch { $refineMode run Refine }] {
                # refine failed, try initialize
                if [catch { $refineMode run Initialize } msg] {
                    puts "Initialize failed for domain [$dom getName] ($msg)"
                }
            }
        }
        $refineMode end
        pw::Display update
    }

    puts "QuiltToSurfMesh finished!"
    timestamp
    puts "Run Time: [convSeconds [pwu::Time elapsed $tBegin]]"

    #    --------------------------
    #   |          FINISH          |
    #    --------------------------

    exit
}

QuiltToSurfMesh

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
