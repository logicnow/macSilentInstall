# macSilentInstall
A script for use with Apple deployment tools (like Apple Remote Desktop) for deploying/enrolling the MAX Remote Management OS X Agent.

Use of RM's Active Discovery Push Install feature is the preferred way to deploy the OS X Agent, but in situations where that's not feasible, doesn't meet the minimum requirements, or existing deployment tools are already in place this may provide an alternative.

Requires OS X Agent 1.5.1 or better

Run the script with the 4 required variables.
Example: /path/to/macSilentInstall.sh username password client site [--registeronly]

'username' is the username (likely email address) you use to log in the MAX Remote Management Dashboard

'password' is the corresponding password for the username, which will appear in clear text in your command. See below.

'client' is the client name you wish to assign to the computer running this script

'site' is the site of the above client that you wish to assign to the computer running this script

Adding '--registeronly' will skip the download/install and simply register the agent

Bear that in mind with this deployment method your password may be sent in clear text. We recommend setting up a new SuperUser account and/or logging in to the Dashboard with that, and then setting your Agent Key user to not be able to access the dashboard. Then use the Agent Key credentials in this script. 

If you choose to execute the script via SSH, be sure to call with bash or set executable bit (e.g. sudo chmod u+x /path/to/macSilentInstall.sh)
