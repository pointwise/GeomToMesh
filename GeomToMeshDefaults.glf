#
# Copyright (c) 2019-2020 Pointwise, Inc.
# All rights reserved.
# 
# This sample Pointwise script is not supported by Pointwise, Inc.
# It is provided freely for demonstration purposes only.  
# SEE THE WARRANTY DISCLAIMER AT THE BOTTOM OF THIS FILE.

# ========================================================================================
# GeomToMesh: Defaults
# ========================================================================================
#
# Initialize global variables defaults. These parameters control
# the operation of GeomToMesh and affect the final mesh.
#
# Note: Do not modify this file directly. Instead, make a copy and
# adjust parameters as needed. Customized settings will be sourced
# after this file, so only the changed values need to be present.
#

# Connector level
set conParams(InitDim)                          11; # Initial connector dimension
set conParams(MaxDim)                         1024; # Maximum connector dimension
set conParams(MinDim)                            4; # Minimum connector dimension
set conParams(TurnAngle)                       0.0; # Maximum turning angle on connectors for dimensioning (0 - not used)
set conParams(Deviation)                       0.0; # Maximum deviation on connectors for dimensioning (0 - not used)
set conParams(SplitAngle)                      0.0; # Turning angle on connectors to split (0 - not used)
set conParams(JoinCons)                          1; # Perform joining operation on 2 connectors at one endpoint
set conParams(ProxGrowthRate)                  1.3; # Connector proximity growth rate
set conParams(SourceSpacing)                     0; # Use source cloud for adaptive pass on connectors V18.2+
set conParams(TurnAngleHard)                  70.0; # Hard edge turning angle limit for domain T-Rex (0.0 - not used)
set conParams(EqualSpacing)                      0; # 0 allow unequal spacing along connectors, 1 enforce equal spacing

# Domain level
set domParams(Algorithm)                "Delaunay"; # Isotropic (Delaunay, AdvancingFront or AdvancingFrontOrtho)
set domParams(FullLayers)                        0; # Domain full layers (0 for multi-normals, >= 1 for single normal)
set domParams(MaxLayers)                         0; # Domain maximum layers
set domParams(GrowthRate)                      1.3; # Domain growth rate for 2D T-Rex extrusion
set domParams(IsoType)                  "Triangle"; # Domain iso cell type (Triangle or TriangleQuad)
set domParams(TRexType)                 "Triangle"; # Domain T-Rex cell type (Triangle or TriangleQuad)
set domParams(TRexARLimit)                   200.0; # Domain T-Rex maximum aspect ratio limit (0 - not used)
set domParams(TRexAngleBC)                       0; # Domain T-Rex spacing from surface curvature
set domParams(Decay)                           0.5; # Domain boundary decay
set domParams(MinEdge)                         0.0; # Domain minimum edge length
set domParams(MaxEdge)                         0.0; # Domain maximum edge length
set domParams(Adapt)                             0; # Set up domains marked as source or target from geometry
set domParams(WallSpacing)                     0.0; # defined spacing when geometry attributed with $wall
set domParams(StrDomConvertARTrigger)          0.0; # Aspect ratio to trigger converting domains to structured

# Block level
set blkParams(Algorithm)                "Delaunay"; # Isotropic (Delaunay, Voxel) (V18.3+)
set blkParams(VoxelLayers)                       3; # Number of Voxel transition layers if Algorithm set to Voxel (V18.3+)
set blkParams(boundaryDecay)                   0.5; # Volumetric boundary decay
set blkParams(collisionBuffer)                 0.5; # Collision buffer for colliding T-Rex fronts
set blkParams(maxSkewAngle)                  180.0; # Maximum skew angle for T-Rex extrusion
set blkParams(TRexSkewDelay)                     0; # Number of layers to delay enforcement of skew criteria
set blkParams(edgeMaxGrowthRate)               1.8; # Volumetric edge ratio
set blkParams(fullLayers)                        0; # Full layers (0 for multi-normals, >= 1 for single normal)
set blkParams(maxLayers)                         0; # Maximum layers
set blkParams(growthRate)                      1.3; # Growth rate for volume T-Rex extrusion
set blkParams(TRexType)       "TetPyramidPrismHex"; # T-Rex cell type (TetPyramid, TetPyramidPrismHex, AllAndConvertWallDoms)
set blkParams(volInitialize)                     1; # Initialize block after setup

# General
set genParams(SkipMeshing)                       1; # Skip meshing of domains during interim processing (V18.3+)
set genParams(CAESolver)                        ""; # Selected CAE Solver (Currently support CGNS, Gmsh and UGRID)
set genParams(outerBoxScale)                   0.0; # Enclose geometry in box with specified scale (0 - no box)
set genParams(sourceBoxLengthScale)            0.0; # Length scale of enclosed viscous walls in source box (0 - no box)
set genParams(sourceBoxDirection)        { 1 0 0 }; # Principal direction vector (i.e. normalized freestream vector)
set genParams(sourceBoxAngle)                  0.0; # Angle for widening source box in the assigned direction
set genParams(sourceGrowthFactor)             10.0; # Growth rate for spacing value along box
set genParams(sourcePCDFile)                    ""; # File name containing source spacing data in PCD format
set genParams(ModelSize)                         0; # Set model size before CAD import (0 - get from file)
set genParams(writeGMA)                      "2.0"; # Write out geometry-mesh associativity file version (0.0 - none, 1.0 or 2.0)
set genParams(assembleTolMult)                 1.0; # Multiplier on model assembly tolerance for allowed MinEdge
set genParams(modelOrientIntoMeshVolume)         1; # Whether the model is oriented so normals point into the mesh

# Elevate On Export V18.2+
set eoeParams(degree)                           Q1; # Polynomial degree (Q1, Q2, Q3 or Q4) NOTE: ONLY APPLIES TO CGNS AND GMSH
set eoeParams(costThreshold)                   0.8; # Cost convergence threshold
set eoeParams(maxIncAngle)                   175.0; # Maximum included angle tolerance
set eoeParams(relax)                          0.05; # Iteration relaxation factor
set eoeParams(smoothingPasses)                1000; # Number of smoothing passes
set eoeParams(WCNWeight)                       0.5; # WCN cost component weighting factor
set eoeParams(WCNMode)                 "Calculate"; # WCN weight factor method (UseValue or Calculate)
set eoeParams(writeVTU)                    "false"; # Write out ParaView VTU files (true or false)

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
