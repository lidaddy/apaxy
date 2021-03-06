#!/bin/bash
#
# apaxy configurator
# v0.2
# configure apaxy according to your local paths and configuration
# author : Jordan Bancino and Ploc
# contact : jordan [@] bancino.net
# licence : GPLv3

# enabling strict mode
# -e - exit immediatly on error (disable with "+e" when an error can happens, then enable it again with "-e")
# -u - undefined variables are forbidden (enable this option after getting parameters from $1 $2...) see below
# -o pipefail - find error return code inside piped commands
# IFS - set strong internal field separator
set -eo pipefail
IFS=$'\n\t'

# default config
defaultLogLevel=2
defaultLogFile="$(basename "${0}" .sh).log"
defaultApacheWebRootPath="/var/www/html"
defaultInstallWebPath=""

# functions

###
 # display help
 ##
displayHelp () {
    cat <<EOF
$(basename "${0}") configure apaxy according to your local paths and configuration.

It can either configure apaxy according to your local paths and configuration bu it can also install the required files in your http server path.

EOF
    displayUsage
    cat <<EOF

Available optionnal parameters are :
  -h  - display help
  -d  - set path/to/dir/ directory where apaxy will be installed on the filesystem
  -w  - set path/to/dir/ directory where apaxy will be available on the httpd server
  -ll - set the log level
  -lf - set the log file
EOF
}

###
 # display usage
 ##
displayUsage () {
    cat <<EOF
usage - $(basename "${0}") [-h] [-d path/to/dir/] [-w path/to/dir/] [-ll logLevel] [-lf logFile]
EOF
}

###
 # log a message
 #
 # @global $logLevel the log level
 # @global $logFile the log file
 # @param $1 the log level of the message
 # @param $2 the log message
 ##
log () {
    local paramLogLevel="${1}"
    local paramLogMessage="${2}"

    # shellcheck disable=SC2155
    local logDate="$(date +%H:%M:%S)"
    local logMessage="[${logDate}] ${paramLogMessage}"

    if [ "${paramLogLevel}" -le "${logLevel}" ]
    then
        echo "${logMessage}"
    fi

    if [ ! -z "${logFile}" ]
    then
        echo "${logMessage}" >> "${logFile}"
    fi
}

# getting parameters value from config file (can be overloaded by cli values)
workingDirectory=$(dirname "$0")

if [ -f "${workingDirectory}/apaxy.config" ]; then
    # shellcheck source=apaxy.config
    source "${workingDirectory}/apaxy.config"
else
    log 1 "ERROR - apaxy configuration not found, please restore or create the configuration file apaxy.config"
    exit 1
fi

# getting parameters value from cli (can overload config file values)
while [ "$#" -ge 1 ] ; do
    case "${1}" in
        -h|--help) # display help
            displayHelp
            exit 0
            ;;
        -d) # set path/to/dir/ directory where apaxy will be available on the httpd server
            shiftStep=2
            apacheWebRootPath="${2}"
            ;;
        -w) # set path/to/dir/ directory where apaxy will be installed on the filesystem
            shiftStep=2
            installWebPath="${2}"
            ;;
        -ll) # set the log level
            shiftStep=2
            logLevel="${2}"
            ;;
        -lf) # set the log file
            shiftStep=2
            logFile="${2}"
            ;;
        *)
            displayUsage
            exit 2
            ;;
    esac

    if [ "$#" -ge "${shiftStep}" ]
    then
        shift "${shiftStep}"
    else
        log 1 "ERROR - invalid number of arguments"
        exit 3
    fi
done

# setting parameters value
if [ -z "${apacheWebRootPath}" ]
then
    apacheWebRootPath="${defaultApacheWebRootPath}"
fi

if [ -z "${installWebPath}" ]
then
    installWebPath="${defaultInstallWebPath}"
fi

if [ -n "${apacheWebRootPath}" ] && [ -z "${installWebPath}" ]
then
    installDir="${apacheWebRootPath}"
else
    installDir="${apacheWebRootPath}${installWebPath}"
fi

if [ -z "${logLevel}" ]
then
    logLevel="${defaultLogLevel}"
fi

if [ -z "${logFile}" ]
then
    logFile="${workingDirectory}/${defaultLogFile}"
fi

# enabling strict mode
# -u - undefined variables are forbidden (enable this option after getting parameters from $1 $2...)
set -u

# checking parameters value
if [ ! -d "$(dirname "${logFile}")" ]
then
    log 1 "ERROR - $(dirname "${logFile}") does not exist"
    exit 4
fi

# script
log 1 "- creating install directory ${installDir}"
mkdir -p "${installDir}"
if [ ! -d "${installDir}" ] || [ ! -w "${installDir}" ]; then
    log 1 "ERROR - install directory ${installDir} does not exist or is not writable by the current user"
    exit 5
fi

log 1 "- copying apaxy in install directory"
cp -r apaxy/* "${installDir}/"

log 1 "- configuring apaxy in install directory"

log 2 "- generating htaccess"
sed "s|{FOLDERNAME}|${installWebPath}|g" < "${installDir}/htaccess.txt" > "${installDir}/.htaccess"
rm "${installDir}/htaccess.txt"

# find all the html files and replace the variable in them
# this will automatically take care of the error pages, headers and footers
log 2 "- setting path in html files"
files=$(find ${installDir} -name "*.html")
while read -r file; do
    sed -i "s|{FOLDERNAME}|${installWebPath}|g" "${file}"
done <<< "${files}"

log 2 "- syncing filesystem"
sync
log 1 "- filesystem has been synced and is now consistent"
log 1 "- apaxy has been successfully configured and installed in ${installDir}"
