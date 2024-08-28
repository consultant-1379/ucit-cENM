#!/bin/sh
#
#
#   RestartVM OCF RA. It checks if a file exist in a specific directory.
#                     When it founds the file, it deletes it and restart the VM.
#
#   Copyright (c) 2015 Ericsson, Filippo Gallo
#                     All Rights Reserved.
#
# DO NOT EDIT This file if found on a cENM service group project.
# Master file is under: https://gerrit.ericsson.se/gitweb?p=OSS/ENM-Parent/SQ-Gate/com.ericsson.oss.containerisation/ucit-cENM.git
#
# This file is updated by run_update_credm_info script
# see: https://confluence-oss.seli.wh.rnd.internal.ericsson.com/display/ENMCOMECIM/Script+automation+for+Credential+Manager+introduction+on+cENM+service+group
#
#
#######################################################################
OCF_RESKEY_state="/opt/ericsson/ERICcredentialmanagercli/.state"

if [ "$1x" != "monitorx" ]; then
    echo "called without monitor param"
else
    if [ -f ${OCF_RESKEY_state} ]; then
        echo "Found File. Return 1."
        logger -p user.info "CREDENTIAL MANAGER CLI RESTART VM SCRIPT : file .state has been found, VM will be restarted"
        exit 1
    else
        echo "File not Found File. Return 0."
        exit 0
    fi
    exit 7
fi


