#
# Copyright 2019 (c) Pointwise, Inc.
# All rights reserved.
#
# This sample Pointwise script is not supported by Pointwise, Inc.
# It is provided freely for demonstration purposes only.
# SEE THE WARRANTY DISCLAIMER AT THE BOTTOM OF THIS FILE.

# 
# Override global variables defaults for hemi_cyl example
#

# Connector level
set conParams(InitDim)                      11; # Initial connector dimension
set conParams(MaxDim)                       15; # Maximum connector dimension
set conParams(MinDim)                        5; # Minimum connector dimension
set conParams(TurnAngle)                  20.0; # Maximum turning angle on connectors (0 - not used)
set conParams(Deviation)                   0.0; # Maximum deviation on connectors (0 - not used)
set conParams(SplitAngle)                  0.0; # Turning angle on connectors to split (0 - not used)
set conParams(ProxGrowthRate)              1.5; # connector proximity growth rate
set conParams(SourceSpacing)                 1; # Use source cloud for adaptive pass on connectors V18.2+
set conParams(TurnAngleHard)               0.0; # Hard edge turning angle limit for domain T-Rex (0.0 - not used)

# Domain level
set domParams(Algorithm)      "AdvancingFront"; # Isotropic (Delaunay, AdvancingFront or AdvancingFrontOrtho)
set domParams(FullLayers)                    0; # Domain full layers (0 for multi-normals, >= 1 for single normal)
set domParams(MaxLayers)                     0; # Domain maximum layers
set domParams(GrowthRate)                  1.2; # Domain growth rate for 2D T-Rex extrusion
set domParams(IsoType)              "Triangle"; # Domain iso cell type (Triangle or TriangleQuad)
set domParams(TRexType)             "Triangle"; # Domain T-Rex cell type (Triangle or TriangleQuad)
set domParams(TRexARLimit)                 0.0; # Domain T-Rex maximum aspect ratio limit (0 - not used)
set domParams(Decay)                      0.50; # Domain boundary decay
set domParams(MinEdge)                     0.0; # Domain minimum edge length
set domParams(MaxEdge)                     0.0; # Domain maximum edge length
set domParams(Adapt)                         0; # Set up domains marked as source or target from geometry

# Block level
set blkParams(boundaryDecay)                 0.75; # Volumetric boundary decay
set blkParams(collisionBuffer)                1.0; # Collision buffer for colliding T-Rex fronts
set blkParams(maxSkewAngle)                 180.0; # Maximum skew angle for T-Rex extrusion
set blkParams(edgeMaxGrowthRate)              1.5; # Volumetric edge ratio
set blkParams(fullLayers)                       1; # Full layers (0 for multi-normals, >= 1 for single normal)
set blkParams(maxLayers)                        0; # Maximum layers
set blkParams(growthRate)                     1.2; # Growth rate for volume T-Rex extrusion
set blkParams(TRexType)      "TetPyramidPrismHex"; # T-Rex cell type (TetPyramid, TetPyramidPrismHex, AllAndConvertWallDoms)
set blkParams(volInitialize)                    1; # Initialize block after setup

# General
set genParams(SkipMeshing)                      1; # Skip meshing of domains during interim processing
set genParams(CAESolver)                   "UGRID"; # Selected CAE Solver 
set genParams(outerBoxScale)                  0.0; # Enclose geometry in box with specified scale (0 - no box)
set genParams(sourceBoxLengthScale)           0.0; # Length scale of enclosed viscous walls in source box (0 - no box)
set genParams(sourceBoxDirection)         {1 0 0}; # Principal direction (i.e. freestream vector)
set genParams(sourceBoxAngle)                 0.0; # Angle for widening source box in the assigned direction
set genParams(sourceGrowthFactor)            10.0; # Growth rate for spacing value along box
set genParams(ModelSize)                        0; # Set model size before CAD import (0 - undefined)

set genParams(writeGMA)                     "true"; # Write out geometry-mesh associativity file (true or false)
set genParams(assembleTolMult)                 1.0; # Multiplier on model assembly tolerance for allowed MinEdge

set genParams(displayTRexCons)             "false"; # Highlighted display of TRex connectors (true or false)

#Elevate On Export
set eoeParams(degree)                           Q1; # Polynomial degree (Q1, Q2, Q3 or Q4) NOTE: ONLY APPLIES TO CGNS AND GMSH
set eoeParams(costThreshold)                   0.8; # Cost convergence threshold
set eoeParams(maxIncAngle)                   175.0; # Maximum included angle tolerance
set eoeParams(relax)                          0.05; # Iteration relaxation factor
set eoeParams(smoothingPasses)                1000; # Number of smoothing passes
set eoeParams(WCNWeight)                       0.5; # WCN cost component weighting factor
set eoeParams(WCNMode)                 "Calculate"; # WCN weight factor method (UseValue or Calculate)
set eoeParams(writeVTU)                     "true"; # Write out ParaView VTU files (true or false)

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
