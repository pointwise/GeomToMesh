GeomToMesh Glyph Scripts
========================

Introduction
~~~~~~~~~~~~

These scripts are provided as-is to Pointwise users for performing automated
mesh generation from an attributed geometry database and a set of user-defined
parameters.  The scripts can be used with Pointwise versions 18.1 and higher.
Note that the scripts can use some features that were introduced in 18.2, such
as *Elevate on Export* to generate mesh files that support High Order elements.
The scripts will ignore meshing parameters and geometry attributes that are not
applicable to the version of Pointwise being used.

**These scripts were developed under a subcontract from MIT as part of their
U.S. Air Force Contract FA8650-14-C-2472.**

The objective of this project was to create a set of scripts to be executed
within the Pointwise mesh generation program that automatically make a single
block unstructured mesh given geometry created using Engineering Sketch Pad
(ESP). No foreknowledge of the elements contained in the geometry file is
required. If the geometry forms a closed model, then a completed unstructured
mesh is the expected result. The scripts create surface meshes that adhere to
the geometry and are sized to respect all length scales.  A set of default
meshing parameters is provided, but can be optionally and selectively
superseded by means of a user-defined parameter file.  These parameters control
the operation of Pointwise during execution.  The default parameters were
developed to incorporate many best practices that produce a quality
unstructured mesh with smoothly varying mesh characteristics.

.. note::
  Even though attribution is not possible with IGES and STEP geometry
  files, the scripts will attempt to generate a completed unstructured volume
  mesh for the input geometry. The final mesh will exhibit all the quality
  characteristics afforded by the processes and best practices, but will not have
  any characteristics provided through geometry attribution. If the geometry is
  both closed and of high quality, the likelihood of a completed mesh is high.
  Once generated, the mesh can be modified using Pointwise to apply
  problem-specific attributes to meet additional quality criteria.

Usage
~~~~~

The main script is *GeomToMesh.glf*. It can be used either in batch mode from
the command line, or in the Pointwise GUI. All of the support scripts must
reside in the same directory as GeomToMesh.glf, including:

- GeomToMeshDefaults.glf  -- Default parameter values that control the meshing process.
- GMDatabaseUtility.glf   -- Functions used for accessing geometry and retrieving attributes.
- GMUtility.glf           -- Functions for performing various meshing operations.
- GMSafeUtility.glf       -- Functions for isolating loading of user-defined parameter files to prevent malicious commands from being executed by the master script.
- GMMeshParamCoords.glf   -- Functions for creating and writing Geometry to Mesh Associativity (GMA) files.
- GMMeshParamCoordsV2.glf -- Functions for creating and writing Geometry to Mesh Associativity (GMA) version 2 files.

The script *RefineByFactor.glf* can be used to refine or coarsen the current mesh
in memory. The factor is defined at the top of the script. This can be used
on meshes created with *GeomToMesh.glf* in a process to create a mesh sequence.

GUI
---

.. image:: https://raw.github.com/pointwise/GeomToMesh/master/GeomToMeshGUI.png

From the *Script* menu, click *Execute...* and browse to the directory
containing the *GeomToMesh.glf*  and support scripts. Type in or select the
geometry file and optional user-defined attributes file, then click *Start*. A
variety of informational messages about the geometry assembly and meshing
process are emitted to the message window.

For ease of repeated usage, it is recommended to add GeomToMesh.glf to the
Script Toolbar using the *Script Toolbar Manager...* under the Script menu.

Batch
-----

In the directory containing the desired geometry and optional user-defined
attributes file, run a command similar to the following:

Windows:

    ``% <path-to-pointwise-install>\win64\bin\tclsh.exe <path-to-scripts>\GeomToMesh.glf geometry-file user-defaults.glf``

Non-Windows (Linux and Mac OS/X):

    ``% <path-to-pointwise_install>/pointwise -b <path-to-scripts>/GeomToMesh.glf geometry-file user-defaults.glf``

Where:

- ``<path-to-pointwise-install>`` is the full path to your licensed Pointwise installation directory
- ``<path-to-scripts>`` is the full or relative path to the directory containing GeomToMesh.glf and its support scripts

Results
-------

In either batch or GUI mode, GeomToMesh will write the final mesh file in
Pointwise format with a name consisting of the geometry file name with
".GeomToMesh" appended to it. Optionally, a CAE file can be exported
for CGNS, Gmsh and UGRID formats, including high order elements if
specified and supported by the format.

Usage Notes
~~~~~~~~~~~

Mesh Parameters
---------------

The meshing process is controlled through either global meshing parameters
(which can be customized for each project), or by attributes attached to
geometry elements. The global parameters are set via a combination of
the provided *GeomToMeshDefaults.glf*  and a customization script that
overrides the defaults as needed.

It is highly recommended that the provided GeomToMeshDefaults.glf file remain unaltered.
These parameters represent the "best practice" values that generally
produce quality unstructured volume grids under normal circumstances. To
define a custom set of parameters:

- copy GeomToMeshDefaults.glf to the directory where the geometry (CAD) file is located
- rename the copy to indicate the objective of the customization, e.g. "CoarseSettings.glf"
- edit the values in that file as desired
  
The custom settings file is specified as input, and is sourced into the main
script *after* the provided default settings (GeomToMeshDefaults.glf) file.
So, only the settings that need to be superseded need to be present.

Geometry Attributes
-------------------

Geometry attributes allow fine-grained control over mesh generation, and
supersede the global settings where applicable.

Supported geometry formats for GeomToMesh include *EGADS*, *IGES*, *STEP* and
*NMB* (Pointwise proprietary geometry format) files.  GeomToMesh will attempt
to create a single unstructured block volume mesh.  IGES and STEP files will not
contain GeomToMesh attributes, so the resulting volume mesh will be of the
isotropic variety with no viscous boundaries or layers.

NMB or EGADS files may contain GeomToMesh attributes, and thus may include
directives that will customize the resulting volume mesh, and may include
viscous boundaries and layers.  ESP writes EGADS files, and has the ability to
assign GeomToMesh attributes to entities in the model. As shown in the table
below, GeomToMesh looks for attributes in the form of key-values pairs on
faces, curves and nodes in the model that have the prefix "PW:", such as
"PW:Name Body" or "PW:WallSpacing 0.001". A list of the possible Pointwise
specific attributes is provided below, and also in the provided Excel
spreadsheet *AttributeVocabulary.xlsx*.

When these attributes are found they guide Pointwise to alter the default
behavior to produce a mesh that has features of interest to the user, such as
boundary conditions and viscous layers.

Note: Preceding $ indicates it is a literal character string

+----------------------------+----------------------------------+-------------+--------------------------------------------------------+
|Key                         |Value                             |Geometry     |Description                                             |
|                            |                                  |Location     |                                                        |
+============================+==================================+=============+========================================================+
|``PW:Name``                 |                                  |``Face``     |Boundary name for domain or collection of domains.      |
+----------------------------+----------------------------------+-------------+--------------------------------------------------------+
|``PW:QuiltName``            |                                  |``Face``     |Name to give one or more quilts that are assembled into |
|                            |                                  |             |a single quilt. No angle test is performed.             |
+----------------------------+----------------------------------+-------------+--------------------------------------------------------+
|``PW:Baffle``               |``$Baffle or $Intersect``         |``Face``     |Either a true baffle surface or a surface intersected by|
|                            |                                  |             |a baffle.                                               |
+----------------------------+----------------------------------+-------------+--------------------------------------------------------+
|``PW:DomainAlgorithm``      |``$Delaunay, $AdvancingFront,``   |``Face``     |Surface meshing algorithm.                              |
|                            |``$AdvancingFrontOrtho``          |             |                                                        |
+----------------------------+----------------------------------+-------------+--------------------------------------------------------+
|``PW:DomainIsoType``        |``$Triangle, $TriangleQuad``      |``Face``     |Surface cell type. Global default is Triangle.          |
+----------------------------+----------------------------------+-------------+--------------------------------------------------------+
|``PW:DomainMinEdge``        |``$Boundary or > 0.0``            |``Face``     |Cell Minimum Equilateral Edge Length in domain.         |
+----------------------------+----------------------------------+-------------+--------------------------------------------------------+
|``PW:DomainMaxEdge``        |``$Boundary or > 0.0``            |``Face``     |Cell Maximum Equilateral Edge Length in domain.         |
+----------------------------+----------------------------------+-------------+--------------------------------------------------------+
|``PW:DomainMaxAngle``       |``[ 0, 180 )``                    |``Face``     |Cell Maximum Angle in domain (0.0 = NOT APPLIED)        |
+----------------------------+----------------------------------+-------------+--------------------------------------------------------+
|``PW:DomainMaxDeviation``   |``[ 0, infinity )``               |``Face``     |Cell Maximum Deviation in domain (0.0 = NOT APPLIED)    |
+----------------------------+----------------------------------+-------------+--------------------------------------------------------+
|``PW:DomainSwapCells``      |``$true or $false``               |``Face``     |Swap cells with no interior points.                     |
+----------------------------+----------------------------------+-------------+--------------------------------------------------------+
|``PW:DomainQuadMaxAngle``   |``( 90, 180 )``                   |``Face``     |Quad Maximum Included Angle in domain.                  |
+----------------------------+----------------------------------+-------------+--------------------------------------------------------+
|``PW:DomainQuadMaxWarp``    |``( 0, 90 )``                     |``Face``     |Cell Maximum Warp Angle in domain.                      |
+----------------------------+----------------------------------+-------------+--------------------------------------------------------+
|``PW:DomainDecay``          |``[ 0, 1 ]``                      |``Face``     |Boundary decay applied on domain.                       |
+----------------------------+----------------------------------+-------------+--------------------------------------------------------+
|``PW:DomainMaxLayers``      |``[ 0, infinity )``               |``Face``     |Maximum T-Rex layers in domain.                         |
+----------------------------+----------------------------------+-------------+--------------------------------------------------------+
|``PW:DomainFullLayers``     |``[ 0, infinity )``               |``Face``     |Number of full T-Rex layers in domain. (0 allows        |
|                            |                                  |             |multi-normals)                                          |
+----------------------------+----------------------------------+-------------+--------------------------------------------------------+
|``PW:DomainTRexGrowthRate`` |``[ 1, infinity )``               |``Face``     |T-Rex growth rate in domain.                            |
+----------------------------+----------------------------------+-------------+--------------------------------------------------------+
|``PW:DomainTRexType``       |``$Triangle, $TriangleQuad``      |``Face``     |Cell types in T-Rex layers in domain.                   |
+----------------------------+----------------------------------+-------------+--------------------------------------------------------+
|``PW:DomainTRexIsoHeight``  |``> 0.0``                         |``Face``     |Isotropic height for T-Rex cells in domain. Default is  |
|                            |                                  |             |1.0.                                                    |
+----------------------------+----------------------------------+-------------+--------------------------------------------------------+
|``PW:PeriodicTranslate``    |``"tx; ty; tz"``                  |``Face``     |Periodic domain with given translation vector.          |
+----------------------------+----------------------------------+-------------+--------------------------------------------------------+
|``PW:PeriodicRotate``       |``"px; py; pz; nx; ny; nz; ang"`` |``Face``     |Periodic domain with given point, normal and rotation   |
|                            |                                  |             |angle.                                                  |
+----------------------------+----------------------------------+-------------+--------------------------------------------------------+
|``PW:PeriodicTarget``       |``$true or $false``               |``Face``     |Target domain of a translate or rotate periodic domain. |
|                            |                                  |             |This domain will be deleted before the creation of the  |
|                            |                                  |             |periodic domain.                                        |
+----------------------------+----------------------------------+-------------+--------------------------------------------------------+
|``PW:DomainAdaptSource``    |``$true or $false``               |``Face``     |Set domain up for adaptation as a source.               |
+----------------------------+----------------------------------+-------------+--------------------------------------------------------+
|``PW:DomainAdaptTarget``    |``$true or $false``               |``Face``     |Set domain up for adaptation as a target.               |
+----------------------------+----------------------------------+-------------+--------------------------------------------------------+
|``PW:DomainShapeConstraint``|``$DataBase or $Free``            |``Face``     |Set domain shape constraint.                            |
+----------------------------+----------------------------------+-------------+--------------------------------------------------------+
|``PW:DomainBlunt``          |``$true or $false``               |``Face``     |Flag the domain as blunt for special dimension handling.|
+----------------------------+----------------------------------+-------------+--------------------------------------------------------+
|``PW:WallSpacing``          |``$Wall or > 0.0``                |``Face``     |Viscous normal spacing for T-Rex extrusion. $Wall uses  |
|                            |                                  |             |domParams(WallSpacing)                                  |
+----------------------------+----------------------------------+-------------+--------------------------------------------------------+
|``PW:TRexIsoHeight``        |``> 0.0``                         |``Model``    |Isotropic height for volume T-Rex cells. Default is 1.0.|
+----------------------------+----------------------------------+-------------+--------------------------------------------------------+
|``PW:TRexCollisionBuffer``  |``> 0.0``                         |``Model``    |T-Rex collision buffer. Default is 0.5.                 |
+----------------------------+----------------------------------+-------------+--------------------------------------------------------+
|``PW:TRexMaxSkewAngle``     |``[ 0, 180 ]``                    |``Model``    |T-Rex maximum skew angle. Default 180 (Off).            |
+----------------------------+----------------------------------+-------------+--------------------------------------------------------+
|``PW:TRexGrowthRate``       |``[ 1, infinity )``               |``Model``    |T-Rex growth rate.                                      |
+----------------------------+----------------------------------+-------------+--------------------------------------------------------+
|``PW:TRexType``             |``$TetPyramid,``                  |``Model``    |T-Rex cell type.                                        |
|                            |``$TetPyramidPrismHex, or``       |             |                                                        |
|                            |``$AllAndConvertWallDoms``        |             |                                                        |
+----------------------------+----------------------------------+-------------+--------------------------------------------------------+
|``PW:BoundaryDecay``        |``[ 0, 1 ]``                      |``Model``    |Volumetric boundary decay. Default is 0.5.              |
+----------------------------+----------------------------------+-------------+--------------------------------------------------------+
|``PW:EdgeMaxGrowthRate``    |``[ 1, infinity )``               |``Model``    |Volumetric edge maximum growth rate. Default is 1.8.    |
+----------------------------+----------------------------------+-------------+--------------------------------------------------------+
|``PW:MinEdge``              |``$Boundary or > 0.0``            |``Model``    |Tetrahedral Minimum Equilateral Edge Length in block.   |
+----------------------------+----------------------------------+-------------+--------------------------------------------------------+
|``PW:MaxEdge``              |``$Boundary or > 0.0``            |``Model``    |Tetrahedral Maximum Equilateral Edge Length in block.   |
+----------------------------+----------------------------------+-------------+--------------------------------------------------------+
|``PW:ConnectorMaxEdge``     |``> 0.0``                         |``Edge``     |Maximum Edge Length in connector.                       |
+----------------------------+----------------------------------+-------------+--------------------------------------------------------+
|``PW:ConnectorEndSpacing``  |``> 0.0``                         |``Edge``     |Specified connector endpoint spacing.                   |
+----------------------------+----------------------------------+-------------+--------------------------------------------------------+
|``PW:ConnectorDimension``   |``> 0``                           |``Edge``     |Specify connector dimension.                            |
+----------------------------+----------------------------------+-------------+--------------------------------------------------------+
|``PW:ConnectorAverageDS``   |``> 0.0``                         |``Edge``     |Specified average delta spacing for connector dimension.|
+----------------------------+----------------------------------+-------------+--------------------------------------------------------+
|``PW:ConnectorMaxAngle``    |``[ 0, 180 )``                    |``Edge``     |Connector Maximum Angle. (0.0 = NOT APPLIED)            |
+----------------------------+----------------------------------+-------------+--------------------------------------------------------+
|``PW:ConnectorMaxDeviation``|``[ 0, infinity )``               |``Edge``     |Connector Maximum Deviation. (0.0 = NOT APPLIED)        |
+----------------------------+----------------------------------+-------------+--------------------------------------------------------+
|``PW:ConnectorAdaptSource`` |``$true or $false``               |``Edge``     |Set connector up for adaptation as a source.            |
+----------------------------+----------------------------------+-------------+--------------------------------------------------------+
|``PW:NodeSpacing``          |``> 0.0``                         |``Node``     |Specified connector endpoint spacing for a node.        |
+----------------------------+----------------------------------+-------------+--------------------------------------------------------+


Future Enhancements
~~~~~~~~~~~~~~~~~~~

Pointwise versions 18.3 and higher provides tools to allow users to
edit/add attributes to geometry within the GUI. The geometry can then be
exported as an NMB file (Pointwise native geometry) and then processed
by the GeomToMesh scripts. 

GeomToMesh attributes can exist in EGADS files written by newer versions
of ESP. Pointwise V18.3 and higher will be able to import EGADS files which
are the native geometry files for ESP. For versions prior to V18.3, geometry
attributes can be stored in Pointwise file (.nmb) using a conversion tool
called *egads2nmb* (provided by ESP) that transforms a standard ESP (.egads)
file to a Pointwise proprietary geometry format file (.nmb). At this time,
there are no plans to support other types of attributed geometry file formats.

Examples
~~~~~~~~

The example directory includes several small cases that
demonstrate the operation of the scripts.

Special Usage Notes
~~~~~~~~~~~~~~~~~~~

Baffle Surfaces
---------------

Baffles are domains that "float" in the interior of a block, and are used to
control grid clustering and other aspects of the interior.  The surface
elements (triangles and quads) in a baffle domain are guaranteed to exist in
the isotropic portion of the final volume mesh. Geometric face elements may be
attributed with PW:Baffle with a value of "Baffle" or "Intersect". The
generated domain for a geometric face element attributed as "Baffle" will be
added to the resulting volume grid as a true baffle.  If the baffle domain will
intersect with another domain, such as an outflow boundary, then boundary
geometry element should be attributed as "Intersect".

Periodic Domains
----------------

Periodic domains are created in pairs where one is the "source" and the other
(its periodic partner) is an exact copy that has been transformed from the
source, typically through either translation or rotation.  Only pure
translation or rotation periodic domains may be generated by GeomToMesh.  The
geometric face that represents the source domain should be attributed with
PW:PeriodicTranslate or PW:PeriodicRotate with a value component comprised of a
translation vector, "tx; ty; tz" or a rotation transform, "px; py; pz; nx; ny;
nz; angle", respectively. The translation form includes the three components of
the translation from the source domain to the target domain. The rotation
transform includes the origin point, normal (rotation axis) and angle used to
define the pure rotation from the source domain to the target domain. If there
is a geometric face that represents the intended periodic partner domain, it
must be attributed with PW:PeriodicTarget and a value of "true". The domain
automatically created for this geometric face will be replaced with the
periodic domain copy through the designated transformation.

Source Adaptation
-----------------

A supplemental source points file can be specified using the parameter
genParams(SourcePCDFile) in the UserDefaults.glf file. This is the name of a
Point Cloud Data (PCD) file containing points in space and a desired element
size. An example file is provided in the ThreeSpheresBox example directory.
The entries for each point include the three coordinates, a spacing value,
and a decay value. The decay value is optional. If not specified the default
background decay will be used. The intent is to permit solution based
adaptation.  The PCD file can be manually created or created from a flow
solution, either using feature-based or output-based (adjoint) adaptation
techniques. This is left up to the user. These points will be added to the
sources and used to adapt the domains and volume mesh.

Reference
~~~~~~~~~

The scripts are the subject of an AIAA paper "Automatic Unstructured
Mesh Generation with Geometry Attribution", AIAA-2019-1721
presented at AIAA Science and Technology Forum and 
Exposition 2019 in San Diego, CA. Please refer to that reference for
details about the processes followed for automated mesh generation.

