#
# Copyright (c) 2019-2020 Pointwise, Inc.
# All rights reserved.
# 
# This sample Pointwise script is not supported by Pointwise, Inc.
# It is provided freely for demonstration purposes only.  
# SEE THE WARRANTY DISCLAIMER AT THE BOTTOM OF THIS FILE.
#
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
