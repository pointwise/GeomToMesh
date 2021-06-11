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
# GeomToMesh: Safe Tcl actions
#

######################################################################
##  PROC: SafeSource
##
##  A safe way to do a blind source of a file.
##  Let the user do what he wants (safely), then try to get something
##  meaningful out of it.
######################################################################
proc SafeSource { fname } {
    if { ! [file readable $fname] } {
        return -code error "SafeSource: Can't open file $fname"
    }

    set safeParser [interp create -safe]

    #-- expose the main parser commands we want the user
    #-- to access in the safe parser
    # $safeParser alias SetModelFileVersion SetModelFileVersion

    set cmd {
        set fid [open $fname r]
        set script [read $fid]
        close $fid
        $safeParser eval $script
    }
    if [catch $cmd err] {
        return -code error "SafeSource: $err"
    }

    #-- Pull the variables we care about out of the safe interpreter
    GetSafeUserDefaultVars $safeParser
    return 0
}

######################################################################
##  PROC: GetSafeUserDefaultVars
##
##  Look in a safe interpreter's namespace for default variables we need.
######################################################################
proc GetSafeUserDefaultVars { parser } {
    global conParams domParams blkParams genParams eoeParams

    set arrayNames [list conParams domParams blkParams genParams eoeParams]  
    foreach arrayName $arrayNames {
        set vars [$parser eval "array names $arrayName"]
        foreach var $vars {
            set val [$parser eval "set ${arrayName}($var)"]
            set ${arrayName}($var) $val
        }
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
