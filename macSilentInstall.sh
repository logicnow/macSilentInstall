#!/bin/bash

# SolarWinds MSP Remote Monitoring & Management Agent for Mac Silent Install and Registration
# Requires OS X Agent 1.5.3 or better

# by Brian J Best, Apple Strategist
# v1.0 initial release
# v1.1 properly dismounts the disk image, checks for root privs
# v1.1.1 uses OS X Agent 1.5.3 and -C -S to create client site as needed
# v1.2 does a little song and dance with -C -S -c -s to get good enrollment
# v1.3 fixes rmmagent syntax for creating client, site
# v1.4 adds support for installing Mac Agent 2.0.0 RC on demand, rebranding from Apple and SolarWinds MSP
# v1.5 update to be version independent, we will handle the RC/GA versions on the server side

# VARIABLES
# you can specify variables as command-line arguments when running the script
# or if you'd rather you can replace these
# all of these must present to register properly, please put proper values inside the quotation marks

# this is the username (likely email address) you use to log in the MSP RMM Dashboard
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
    echo "Example: /path/to/macSilentInstall.sh username password client site"
    echo "Run the script with -? for more help"
    exit 2
fi

# display help
if [ "$rmUsername" == "-?" ]; then
    echo "This script will download, install, and register the SolarWinds MSP Remote Monitoring & Management Agent for Mac."
    echo "Run the script with the 4 required variables."
    echo "Example: /path/to/macSilentInstall.sh username password client site [--registeronly] [--rc]"
    echo ""
    echo "'username' is the username (ideally the Agent Key) you use to log in the SolarWinds MSP RMM Dashboard"
    echo "'password' is the corresponding password for the username, which will appear in clear text in your command. See below."
    echo "'client' is the client name you wish to assign to the computer running this script"
    echo "'site' is the site of the above client that you wish to assign to the computer running this script"
    echo ""
    echo "Adding '--registeronly' will skip the download/install and simply register the agent"
    echo "Adding '--rc' will download and install the newest Release Candidate version of the agent"
    echo ""
    echo "Bear that in mind with your deployment method your password will be sent in clear text."
    echo "Please consider using the Agent Key user account with Dashboard Access disabled."
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

#if user has specified they want the RC agent, they'll add it to the end
if [ "$5" == "--rc" ]; then
	agentVers="macagentrc"
else
	agentVers="macagentga"
fi

if [ ${regOnly:-0} -eq 0 ]; then
# download the agent installer
curl -o "/private/tmp/macagent-$randomID.dmg" "https://www.mac-msp.com/$agentVers.dmg"
#TODO - may need to replace this download link at some point

# mount the DMG, specify the mountpoint since the DMG volume name might change later
hdiutil attach -nobrowse -mountpoint "/Volumes/macagent-$randomID" "/private/tmp/macagent-$randomID.dmg"

# sanity check, did we mount and look OK? Download may have failed or could be corrupted.
if [ $? -ne 0 ] || [ ! -e "/Volumes/macagent-$randomID" ]; then
    echo "Unable to mount the downloaded disk image. Check Internet connectivity and try again."
    exit 2
fi

# install it
installer -pkg "/Volumes/macagent-$randomID/Advanced Monitoring Agent.pkg" -target /

# sanity check
if [ $? -ne 0 ] || [ ! -e /usr/local/rmmagent/rmmagentd ]; then
    echo "Installation failed."
    exit 2
else
    # all done, detach the image
    hdiutil detach "/Volumes/macagent-$randomID"
fi

fi #regOnly check

# enroll in RM
if [ -e /usr/local/rmmagent/rmmagentd ]; then
    # little oddity requires wd to be parent folder (might be fixed in 2.1)
    cd /usr/local/rmmagent
    ./rmmagentd -q -u "$rmUsername" -p "$rmPass" -C -c "$rmClient" -S -s "$rmSite"
    if [ $? -ne 0 ]; then
        # let's do the registration dance
        echo "Registration could not create client and site. Trying existing."
        #no joy in creating client/site, maybe already there?
        regAtt2=`./rmmagentd -q -u "$rmUsername" -p "$rmPass" -c "$rmClient" -s "$rmSite" 2>&1`
        if [ $? -ne 0 ]; then
            #nope.
            case "$regAtt2" in
            'Duplicate device name for Client/Site combination')
                echo "Registration failed because a device with this name already exists in the Dashboard. Remove it and try again."
            ;;
            'Agent is already registered')
            	echo "This computer appears to be in the Dashboard already. Please check for it there."
            ;;
            *)
                # try creating site only
                echo "Registration doesn't have existing client and site. Trying to create Site."
                ./rmmagentd -q -u "$rmUsername" -p "$rmPass" -c "$rmClient" -S -s "$rmSite"
                if [ $? -ne 0 ]; then
                    #fail.
                    echo "Registration failed. You may need to register this computer manually."
                fi
            esac
        fi
    fi
else
    if [ ${regOnly:-0} -eq 1 ]; then
        echo "Agent does not appear to be installed. Please re-run without --registeronly."
    else
        echo "Agent does not appear to be installed. Something went horribly wrong."
    fi
    exit 2
fi

# sanity check 
# 1.5.3 uses string "Mac OSX agent is registered successfully."
# 2.0.0 uses string "Agent is registered successfully."
regCheck=`grep 'gent is registered successfully.' /usr/local/rmmagent/log/rmmagentd.log`
if [ "$regCheck" == "" ]; then
    echo "Something went wrong. Please check the variables and try again or register manually."
    exit 2
else
    echo "Everything appears to have worked. Please check the RM Dashboard for the computer record."
    exit 0
fi
