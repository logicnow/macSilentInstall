#!/bin/bash

# LOGICnow MAX Remote Management OS X Agent Silent Deployment
# Requires OS X Agent 1.5.1 or better

# by Brian J Best, Apple Strategist
# v1.0 initial release
# v1.1 properly dismounts the disk image, checks for root privs

# VARIABLES
# you can specify variables as command-line arguments when running the script
# or if you'd rather you can replace these
# all of these must present to register properly, please put proper values inside the quotation marks

# this is the username (likely email address) you use to log in the MAX Remote Management Dashboard
rmUsername="$1"

# this is the corresponding password for the username 
# (it's in clear text, bear that in mind with your deployment method)
rmPass="$2"

# this is the client name you wish to assign to the computer running this script
rmClient="$3"

# this is the site of the above client that you wish to assign to the computer running this script
rmSite="$4"

## DO NOT EDIT BELOW THIS LINE

# check for arguments
if [ "$rmUsername" == "" ]; then
    echo "Variables must be specified as arguments or hard-coded into the script."
    echo "Example: /path/to/script username password client site"
    echo "Run the script with -? for more help"
    exit 2
fi

# display help
if [ "$rmUsername" == "-?" ]; then
    echo "This script will download, install, and register the MAX Remote Management OS X Agent."
    echo "Run the script with the 4 required variables."
    echo "Example: /path/to/script username password client site [--registeronly]"
    echo ""
    echo "'username' is the username (likely email address) you use to log in the MAX Remote Management Dashboard"
    echo "'password' is the corresponding password for the username, which will appear in clear text in your command. See below."
    echo "'client' is the client name you wish to assign to the computer running this script"
    echo "'site' is the site of the above client that you wish to assign to the computer running this script"
    echo "Adding '--registeronly' will skip the download/install and simply register the agent"
    echo ""
    echo "Bear that in mind with your deployment method your password will be sent in clear text."
    echo "Please use a Standard user account to protect your dashboard, read this for a safety tip:"
    echo "http://www.allthingsmax.com/2011/11/security-best-practices-in-max.html"
    exit 0
fi

# check enrollment variables
if [ "$rmUsername" == "" ] || [ "$rmPass" == "" ] || [ "$rmClient" == "" ] || [ "$rmSite" == "" ]; then
    echo "Registration variables are not set correctly, please try again."
    exit 2
fi

# do we have privileges?
userName=`whoami`
if [ "$userName" != "root" ]; then
    echo "This script requires admin rights. Please run with sudo."
    exit 2
fi

#randomizer to avoid stomping problems
randomID=`uuidgen`

#if user has package downloaded and just needs registration they can say so with a fifth argument
if [ "$5" == "--registeronly" ]; then
    regOnly=1
fi

if [ ${regOnly:-0} -eq 0 ]; then
# download the agent installer
curl -o "/private/tmp/osxagent-$randomID.dmg" "https://www.mac-msp.com/osxagent151.dmg"
#TODO - may need to replace this download link at some point

# mount the DMG, specify the mountpoint since the DMG volume name might change later
hdiutil attach -nobrowse -mountpoint "/Volumes/osxagent-$randomID" "/private/tmp/osxagent-$randomID.dmg"

# sanity check, did we mount and look OK? Download may have failed or could be corrupted.
if [ $? -ne 0 ] || [ ! -e "/Volumes/osxagent-$randomID" ]; then
    echo "Unable to mount the downloaded disk image. Check Internet connectivity and try again."
    exit 2
fi

# install it
installer -pkg "/Volumes/osxagent-$randomID/Advanced Monitoring Agent.pkg" -target /

# sanity check
if [ $? -ne 0 ] || [ ! -e /usr/local/rmmagent/rmmagentd ]; then
    echo "Installation failed."
    exit 2
else
    # all done, detach the image
    hdiutil detach "/Volumes/osxagent-$randomID"
fi

fi #regOnly check

# enroll in RM - little oddity requires wd to be parent folder
if [ -e /usr/local/rmmagent/rmmagentd ]; then
    cd /usr/local/rmmagent; ./rmmagentd -q -u "$rmUsername" -p "$rmPass" -c "$rmClient" -s "$rmSite"
    # TODO - change to -C and -S when Agent 1.5.2 is released
else
    if [ ${regOnly:-0} -eq 1 ]; then
        echo "OS X Agent does not appear to be installed. Please re-run without --registeronly."
    else
        echo "OS X Agent does not appear to be installed. Something went horribly wrong."
    fi
    exit 2
fi

# sanity check 
if [ $? -ne 0 ]; then
    echo "Unable to register the computer. Please check the variables and try again."
    exit 2
else
    echo "Everything appears to have worked. Please check the RM Dashboard for the computer record."
    exit 0
fi
