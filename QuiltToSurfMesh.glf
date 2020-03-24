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
set conParams(TurnAngle)                  15.0; # Maximum turning angle on connectors (0 - not used)
set conParams(Deviation)                   0.0; # Maximum deviation on connectors (0 - not used)
set conParams(SplitAngle)                 40.0; # Turning angle on connectors to split (0 - not used)
set conParams(sourceDecay)                0.85; # Source decay for proximity dim/dist
set conParams(TurnAngleHard)              40.0; # Hard edge turning angle limit for domain T-Rex (0.0 - not used)
set conParams(ConcaveHardEdgeRefine)      0.25; # Refinement factor for concave hard edges (0.0=isotropic at smallest size, 1.0=no change)
set conParams(edgeMaxGrowthRate)           1.8; # Max edge ratio

# Domain level
set domParams(SkipMeshing)                   1; # Skip meshing of domains during interim processing
set domParams(Algorithm)      "AdvancingFront"; # Isotropic (Delaunay, AdvancingFront or AdvancingFrontOrtho)
set domParams(FullLayers)                    0; # Domain full layers (0 for multi-normals, >= 1 for single normal)
set domParams(MaxLayers)                    30; # Domain maximum layers
set domParams(GrowthRate)                  1.2; # Domain growth rate for 2D T-Rex extrusion
set domParams(IsoType)              "Triangle"; # Domain iso cell type (Triangle or TriangleQuad)
set domParams(TRexType)             "Triangle"; # Domain T-Rex cell type (Triangle or TriangleQuad)
set domParams(TRexARLimit)                30.0; # Domain T-Rex maximum aspect ratio limit (0 - not used)
set domParams(TRexAngleBC)                   0; # Domain T-Rex spacing from surface curvature
set domParams(HardEdgeTargetAR)            5.0; # Domain T-Rex hard edge target aspect ratio
set domParams(HardEdgeConvexOnly)            1; # Whether domain T-Rex is applied to only convex hard edges
set domParams(HardEdgeTRexARLimit)        10.0; # Domain T-Rex hard edge aspect ratio limit (0 - not used)

set domParams(StrDomConvertARTrigger)     10.0; # Domain aspect ratio threshold for conversion to strdom (0 - not used)

set domParams(Decay)                      0.80; # Domain boundary decay
set domParams(MinEdge)                     0.0; # Domain minimum edge length
set domParams(MaxEdge)                     0.0; # Domain maximum edge length


# General
set genParams(displayTRexCons)                  10; # Whether to render TRex connectors by type
set genParams(assembleTolMult)                 1.0; # Multiplier on model assembly tolerance for allowed MinEdge
set genParams(modelOrientIntoMeshVolume)        10; # Whether the model is oriented so normals point into the mesh


if {10} {    
    # quad dominant
    set domParams(Algorithm)      "AdvancingFrontOrtho"; # Isotropic (Delaunay, AdvancingFront or AdvancingFrontOrtho)
    set domParams(IsoType)              "TriangleQuad"; # Domain iso cell type (Triangle or TriangleQuad)
    set domParams(TRexType)             "TriangleQuad"; # Domain T-Rex cell type (Triangle or TriangleQuad)
}

set HLCRM 0;  # Define TRUE for HL-CRM model exascale mesh
if { $HLCRM } {
    set conParams(TurnAngle)                  15.0; # Maximum turning angle on connectors (0 - not used)
    set conParams(MinDim)                       21; # Minimum connector dimension
    set conParams(MaxDim)                     2024; # Maximum connector dimension
    set domParams(MaxEdge)                     4.0; # Domain maximum edge length
    set domParams(TRexARLimit)                60.0; # Domain T-Rex maximum aspect ratio limit (0 - not used)
    set domParams(HardEdgeTRexARLimit)        60.0; # Domain T-Rex hard edge aspect ratio limit (0 - not used)
    set genParams(assembleTolMult)             0.6; # Multiplier on model assembly tolerance for allowed MinEdge
}

set HLCRM_Installed 0;  # Define TRUE for HL-CRM wind tunnel model
if { $HLCRM_Installed } {
    set conParams(TurnAngle)                  15.0; # Maximum turning angle on connectors (0 - not used)
    set conParams(MinDim)                        5; # Minimum connector dimension
    set conParams(MaxDim)                     1024; # Maximum connector dimension
    set conParams(ConcaveHardEdgeRefine)      0.25; # Refinement factor for concave hard edges (0.0=isotropic at smallest size, 1.0=no change)
    set domParams(MaxEdge)                     4.0; # Domain maximum edge length
    set domParams(TRexARLimit)                60.0; # Domain T-Rex maximum aspect ratio limit (0 - not used)
    set domParams(HardEdgeTRexARLimit)        60.0; # Domain T-Rex hard edge aspect ratio limit (0 - not used)

    if {0} {    
        # quad dominant
        set domParams(Algorithm)      "AdvancingFrontOrtho"; # Isotropic (Delaunay, AdvancingFront or AdvancingFrontOrtho)
        set domParams(IsoType)              "TriangleQuad"; # Domain iso cell type (Triangle or TriangleQuad)
        set domParams(TRexType)             "TriangleQuad"; # Domain T-Rex cell type (Triangle or TriangleQuad)
    }
    
    set genParams(assembleTolMult)             0.1; # Multiplier on model assembly tolerance for allowed MinEdge
    
    
    # Quilt Filters
    set excludeFilter(quilt,TRex,TurnAngle) [list "fuse*" "windscreen"];      # Skip TurnAngle T-Rex for matching quilts
    set excludeFilter(quilt,TRex,TurnAngleHard) [list "fuse*" "windscreen"];  # Skip TurnAngleHard T-Rex for matching quilts
    
    # Quilt-Pair Shared Boundary Filters
    # Skip curvature-based spacing at boundaries of quilt pairs
    set excludeFilter(quiltPairs,spacing,curvature) [list \
        [list "wing-te-*" "*"] \
        [list "wingtip-te" "*"] \
        [list "elevator-te" "*"] \
        [list "elevatortip-te" "*"] \
        [list "junction*" "*"] \
        ]
    
    # Skip surface curvature-based spacing at boundaries of quilt pairs
    set excludeFilter(quiltPairs,spacing,curvatureSurface) [list \
        [list "fuse*" "windscreen"] \
        [list "windscreen" "*"] \
        [list "fuselage-nose" "*"] \
        [list "wingtip-te" "*"] \
        [list "elevatortip-te" "*"] \
        [list "junction*" "*"] \
        ]
}

set wing_body 0;  # Define TRUE for wing-body tutorial model
if { $wing_body } {
    set conParams(InitDim)                      21; # Initial connector dimension
    set conParams(MinDim)                        5; # Minimum connector dimension
    set conParams(MaxDim)                     1024; # Maximum connector dimension
    set conParams(ConcaveHardEdgeRefine)       0.5; # Smaller value favors smaller spacing on edge
    set domParams(MaxEdge)                     4.0; # Domain maximum edge length
    set domParams(TRexARLimit)                60.0; # Domain T-Rex maximum aspect ratio limit (0 - not used)
    set domParams(HardEdgeTRexARLimit)        60.0; # Domain T-Rex hard edge aspect ratio limit (0 - not used)
    
    set genParams(assembleTolMult)             0.2; # Multiplier on model assembly tolerance for allowed MinEdge

    set excludeFilter(quilt,TRex,TurnAngle) [list "fuse*"];      # Skip TurnAngle T-Rex for matching quilts
    
    # Quilt-Pair Shared Boundary Filters
    # Skip curvature-based spacing at boundaries of quilt pairs
    # set excludeFilter(quiltPairs,spacing,curvature) [list \
        # [list "wing-*" "fuse*"] \
        # ]
    
    # # Skip surface curvature-based spacing at boundaries of quilt pairs
    # set excludeFilter(quiltPairs,spacing,curvatureSurface) [list \
        # [list "wing-*" "fuse*"] \
        # ]
}

set uav 0;  # Define TRUE for UAV model
if { $uav } {
    set conParams(MinDim)                        5; # Minimum connector dimension
    set conParams(MaxDim)                     1024; # Maximum connector dimension
    set conParams(ConcaveHardEdgeRefine)       0.5; # Smaller value favors smaller spacing on edge
    set domParams(MinEdge)                     0.0005; # Domain minimum edge length
    
    # set domParams(MaxEdge)                     4.0; # Domain maximum edge length
    set domParams(TRexARLimit)                60.0; # Domain T-Rex maximum aspect ratio limit (0 - not used)
    set domParams(HardEdgeTRexARLimit)        60.0; # Domain T-Rex hard edge aspect ratio limit (0 - not used)
    
    set genParams(assembleTolMult)             1.0; # Multiplier on model assembly tolerance for allowed MinEdge

    if {10} {    
        # quad dominant
        set domParams(Algorithm)      "AdvancingFrontOrtho"; # Isotropic (Delaunay, AdvancingFront or AdvancingFrontOrtho)
        set domParams(IsoType)              "TriangleQuad"; # Domain iso cell type (Triangle or TriangleQuad)
        set domParams(TRexType)             "TriangleQuad"; # Domain T-Rex cell type (Triangle or TriangleQuad)
    }

    set includeFilter(model) [list "uav"];                       # Mesh matching model names

    set excludeFilter(quilt,TRex,TurnAngle) [list "fuse*"];      # Skip TurnAngle T-Rex for matching quilts
    
}

set DLR_F11 0;  # Define TRUE for DLR F11 model 
if { $DLR_F11 } {
    set conParams(TurnAngle)                  10.0; # Maximum turning angle on connectors (0 - not used)
    set conParams(MinDim)                        5; # Minimum connector dimension
    set conParams(MaxDim)                     2024; # Maximum connector dimension
    
    set conParams(ConcaveHardEdgeRefine)      0.25; # Refinement factor for concave hard edges (0.0=isotropic at smallest size, 1.0=no change)
    
    set domParams(MaxEdge)                     0.5; # Domain maximum edge length
    set domParams(Decay)                      0.85; # Domain boundary decay
    
    set domParams(TRexAngleBC)                  10; # Domain T-Rex spacing from surface curvature
    
    set domParams(TRexARLimit)                60.0; # Domain T-Rex maximum aspect ratio limit (0 - not used)
    set domParams(HardEdgeTRexARLimit)        60.0; # Domain T-Rex hard edge aspect ratio limit (0 - not used)
    set genParams(assembleTolMult)             1.0; # Multiplier on model assembly tolerance for allowed MinEdge
}

# ----------------------------------------------
# Main procedure
# ----------------------------------------------
proc QuiltToSurfMesh { } {
    global includeFilter
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
                # puts "Model is linked to [$dbEnt getName]"
                lappend ModelList $dbEnt
            }
            Quilt {
                # puts "Quilt is linked to [$dbEnt getName]"
                lappend QuiltList [pw::DatabaseEntity getByName [$dbEnt getName]]
            }
            default {
            }
        }
    }
    
    if {[info exists includeFilter(model)]} {
        # Only mesh models with names matching "includeFilter(model)" pattern
        set modelNames ""
        foreach model $ModelList {
            lappend modelNames [$model getName]
        }
        set includeModels [list]
        foreach pattern $includeFilter(model) {
            set ind [lsearch -glob $modelNames $pattern]
            if {$ind != -1} {
                lappend includeModels [lindex $ModelList $ind]
            }
        }
        
        if {[llength $includeModels] > 0} {
            set ModelList [lsort -unique $includeModels]
        } else {
            error  "Didn't find any Models matching \"$includeFilter(model)\""
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


    UpdateConData
    # displayConAssembleTol
    # exit

    set minConLen 1.0e20
    foreach con $conList {
        set len [$con getLength -parameter 1.0]
        if { $len < $minConLen } {
            set minConLen $len
        }
        # puts "[$con getName] [curvatureSpacingAllowed $con]"
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

    set conList [pw::Grid getAll -type pw::Connector]
    
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
        set conList [pw::Grid getAll -type pw::Connector]
    }

    pw::Display update

    #    ------------------------------
    #   | Increase connector dimension |
    #   | using proximity test         |
    #    ------------------------------
	if {0} {
    # Perform source refinement from connector spacing
    puts "Performing Source Cloud Refinement"
    connectorSourceSpacing $conParams(sourceDecay)
	}

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

    if {0 && $meshChanged } {
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

        if {0 &&  $meshChanged } {
            # Perform source refinement from connector spacing
            puts "Performing Source Cloud Refinement"
            connectorSourceSpacing $conParams(sourceDecay) 1
        }
    }
    
    # Perform source refinement from connector spacing
    puts "Performing Source Cloud Refinement"
    connectorSourceSpacing $conParams(sourceDecay) 1

    IdentifyMappableDomains
    ConvertHighAspectDoms
    

    set domList [pw::Grid getAll -type pw::DomainUnstructured]
    foreach dom $domList {
        $dom setUnstructuredSolverAttribute BoundaryDecay $domParams(Decay)
        $dom setUnstructuredSolverAttribute SwapCellsWithNoInteriorPoints True
        # $dom setUnstructuredSolverAttribute TRexIsoTropicHeight [expr sqrt(3.0) / 2.0 ]
    }
    set haveSkipMeshing [HaveDomSkipMeshing]
    SetDomSkipMeshing false

    #    --------------------------
    #   |  Domain refinement pass  |
    #    --------------------------
    # do a refinement pass on all domains
    #
    puts "Performing meshing pass on all domains."
    foreach dom $domList {
        set refineMode [pw::Application begin UnstructuredSolver [list $dom]]
        if { $haveSkipMeshing } {
            puts "Initializing domain [$dom getName]"
            if [catch { $refineMode run Initialize } msg] {
                puts "Initialize failed for domain [$dom getName] ($msg)"
            }
        } else {
            puts "Refining domain [$dom getName]"
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
