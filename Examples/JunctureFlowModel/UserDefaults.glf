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
# Override global variables defaults for juncture flow example
#

# Connector level
set conParams(InitDim)                           8; # Initial connector dimension
set conParams(MaxDim)                         1024; # Maximum connector dimension
set conParams(MinDim)                            5; # Minimum connector dimension
set conParams(TurnAngle)                   8.00000; # Maximum turning angle on connectors for dimensioning (0 - not used)
set conParams(Deviation)                       0.0; # Maximum deviation on connectors for dimensioning (0 - not used)
set conParams(SplitAngle)                     30.0; # Turning angle on connectors to split (0 - not used)
set conParams(JoinCons)                          1; # Perform joining operation on 2 connectors at one endpoint
set conParams(ProxGrowthRate)                  1.2; # Connector proximity growth rate
set conParams(SourceSpacing)                     1; # Use source cloud for adaptive pass on connectors V18.2+
set conParams(TurnAngleHard)                  20.0; # Hard edge turning angle limit for domain T-Rex (0.0 - not used)

# Domain level
set domParams(Algorithm)                "Delaunay"; # Isotropic (Delaunay, AdvancingFront or AdvancingFrontOrtho)
set domParams(FullLayers)                        0; # Domain full layers (0 for multi-normals, >= 1 for single normal)
set domParams(MaxLayers)                        20; # Domain maximum layers
set domParams(GrowthRate)                      1.2; # Domain growth rate for 2D T-Rex extrusion
set domParams(IsoType)                  "Triangle"; # Domain iso cell type (Triangle or TriangleQuad)
set domParams(TRexType)                 "Triangle"; # Domain T-Rex cell type (Triangle or TriangleQuad)
set domParams(TRexARLimit)                    10.0; # Domain T-Rex maximum aspect ratio limit (0 - not used)
set domParams(TRexAngleBC)                       0; # Domain T-Rex spacing from surface curvature
set domParams(Decay)                          0.70; # Domain boundary decay
set domParams(MinEdge)                         0.0; # Domain minimum edge length
set domParams(MaxEdge)                         0.0; # Domain maximum edge length
set domParams(Adapt)                             1; # Set up domains marked as source or target from geometry
set domParams(WallSpacing)              0.00243000; # defined spacing when geometry attributed with $wall

# Block level
set blkParams(Algorithm)                "Delaunay"; # Isotropic (Delaunay, Voxel) (V18.3+)
set blkParams(VoxelLayers)                       3; # Number of Voxel transition layers if Algorithm set to Voxel (V18.3+)
set blkParams(boundaryDecay)                   0.5; # Volumetric boundary decay
set blkParams(collisionBuffer)                 1.0; # Collision buffer for colliding T-Rex fronts
set blkParams(maxSkewAngle)                  170.0; # Maximum skew angle for T-Rex extrusion
set blkParams(edgeMaxGrowthRate)               1.2; # Volumetric edge ratio
set blkParams(fullLayers)                        1; # Full layers (0 for multi-normals, >= 1 for single normal)
set blkParams(maxLayers)                       200; # Maximum layers
set blkParams(growthRate)                 1.176080; # Growth rate for volume T-Rex extrusion
set blkParams(TRexType)               "TetPyramid"; # T-Rex cell type (TetPyramid, TetPyramidPrismHex, AllAndConvertWallDoms)
set blkParams(volInitialize)                     1; # Initialize block after setup

# General
set genParams(SkipMeshing)                       1; # Skip meshing of domains during interim processing (V18.3+)
set genParams(CAESolver)                    "CGNS"; # Selected CAE Solver (Currently support CGNS, Gmsh and UGRID)
set genParams(outerBoxScale)                   0.0; # Enclose geometry in box with specified scale (0 - no box)
set genParams(sourceBoxLengthScale)           10.0; # Length scale of enclosed viscous walls in source box (0 - no box)
set genParams(sourceBoxDirection)        { 1 0 0 }; # Principal direction vector (i.e. normalized freestream vector)
set genParams(sourceBoxAngle)                  5.0; # Angle for widening source box in the assigned direction
set genParams(sourceGrowthFactor)             10.0; # Growth rate for spacing value along box
set genParams(ModelSize)                     10000; # Set model size before CAD import (0 - get from file)
set genParams(writeGMA)                    "false"; # Write out geometry-mesh associativity file (true or false)
set genParams(assembleTolMult)                 1.0; # Multiplier on model assembly tolerance for allowed MinEdge
set genParams(modelOrientIntoMeshVolume)         0; # Whether the model is oriented so normals point into the mesh

# Elevate On Export V18.2+
set eoeParams(degree)                           Q1; # Polynomial degree (Q1, Q2, Q3 or Q4) NOTE: ONLY APPLIES TO CGNS AND GMSH
set eoeParams(costThreshold)                   0.8; # Cost convergence threshold
set eoeParams(maxIncAngle)                   175.0; # Maximum included angle tolerance
set eoeParams(relax)                          0.05; # Iteration relaxation factor
set eoeParams(smoothingPasses)                1000; # Number of smoothing passes
set eoeParams(WCNWeight)                       0.5; # WCN cost component weighting factor
set eoeParams(WCNMode)                 "Calculate"; # WCN weight factor method (UseValue or Calculate)
set eoeParams(writeVTU)                    "false"; # Write out ParaView VTU files (true or false)

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
