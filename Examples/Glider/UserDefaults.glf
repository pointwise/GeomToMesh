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
# Override global variables defaults for glider example
#

# Connector level
set conParams(InitDim)                       8; # Initial connector dimension
set conParams(MaxDim)                     1024; # Maximum connector dimension
set conParams(MinDim)                        4; # Minimum connector dimension
set conParams(TurnAngle)                  15.0; # Maximum turning angle on connectors for dimensioning (0 - not used)
set conParams(Deviation)                   0.0; # Maximum deviation on connectors for dimensioning (0 - not used)
set conParams(SplitAngle)                 70.0; # Turning angle on connectors to split (0 - not used)
set conParams(JoinCons)                      0; # Perform joining operation on 2 connectors at one endpoint
set conParams(ProxGrowthRate)              1.3; # Connector proximity growth rate
set conParams(SourceSpacing)                 0; # Use source cloud for adaptive pass on connectors V18.2+
set conParams(TurnAngleHard)              60.0; # Hard edge turning angle limit for domain T-Rex (0.0 - not used)

# Domain level
set domParams(Algorithm)   "AdvancingFront"; # Isotropic (Delaunay, AdvancingFront or AdvancingFrontOrtho)
set domParams(FullLayers)                 0; # Domain full layers (0 for multi-normals, >= 1 for single normal)
set domParams(MaxLayers)                 10; # Domain maximum layers
set domParams(GrowthRate)               1.3; # Domain growth rate for 2D T-Rex extrusion
set domParams(IsoType)           "Triangle"; # Domain iso cell type (Triangle or TriangleQuad)
set domParams(TRexType)          "Triangle"; # Domain T-Rex cell type (Triangle or TriangleQuad)
set domParams(TRexARLimit)             10.0; # Domain T-Rex maximum aspect ratio limit (0 - not used)
set domParams(Decay)                    0.5; # Domain boundary decay
set domParams(MinEdge)                  0.0; # Domain minimum edge length
set domParams(MaxEdge)                  0.0; # Domain maximum edge length
set domParams(Adapt)                      0; # Set up domains marked as source or target from geometry
set domParams(WallSpacing)              0.1; # defined spacing when geometry attributed with $wall

# Block level
set blkParams(Algorithm)                "Delaunay"; # Isotropic (Delaunay, Voxel) (V18.3+)
set blkParams(boundaryDecay)                  0.5; # Volumetric boundary decay
set blkParams(collisionBuffer)                2.0; # Collision buffer for colliding T-Rex fronts
set blkParams(maxSkewAngle)                 170.0; # Maximum skew angle for T-Rex extrusion
set blkParams(edgeMaxGrowthRate)              1.5; # Volumetric edge ratio
set blkParams(fullLayers)                       0; # Full layers (0 for multi-normals, >= 1 for single normal)
set blkParams(maxLayers)                       50; # Maximum layers
set blkParams(growthRate)                     1.3; # Growth rate for volume T-Rex extrusion
set blkParams(TRexType)              "TetPyramid"; # T-Rex cell type (TetPyramid, TetPyramidPrismHex, AllAndConvertWallDoms)
set blkParams(volInitialize)                    1; # Initialize block after setup

# General
set genParams(SkipMeshing)                      1; # Skip meshing of domains during interim processing
set genParams(CAESolver)                  "UGRID"; # Selected CAE Solver (Currently support CGNS and UGRID)
set genParams(outerBoxScale)                  0.0; # Enclose geometry in box with specified scale (0 - no box)
set genParams(sourceBoxLengthScale)           0.0; # Length scale of enclosed viscous walls in source box (0 - no box)
set genParams(sourceBoxDirection)         {1 0 0}; # Principal direction (i.e. freestream vector)
set genParams(sourceBoxAngle)                 0.0; # Angle for widening source box in the assigned direction
set genParams(sourceGrowthFactor)            10.0; # Growth rate for spacing value along box
set genParams(ModelSize)                        0; # Set model size before CAD import (0 - undefined)
set genParams(writeGMA)                     "2.0"; # Write out geometry-mesh associativity file version (0.0 - none, 1.0 or 2.0)
set genParams(assembleTolMult)                 1.0; # Multiplier on model assembly tolerance for allowed MinEdge
set genParams(modelOrientIntoMeshVolume)         1; # Whether the model is oriented so normals point into the mesh

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
