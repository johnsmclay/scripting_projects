#!/bin/bash

# == AWS ASSUME ROLE CLI TOOL ==
# Usage:
# 	To run this you need---
#	  Linux or Windows with WSL:
# 		`sudo apt-get update`
# 		`sudo apt-get install jq python-pip`
# 		`pip install awscli`
# 		`aws configure` (just pick all the defaults, except for your keys)
#	  Mac/OSX:
#		#Setup Homebrew
#		`brew update`
#		`brew install python3 jq`
#		`pip3 install --upgrade pip setuptools wheel awscli`
#		`aws configure` (just pick all the defaults, except for your keys)
# 	In a script that needs to use this tool just add:
# 		`SCRIPTDIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null && pwd )"` < if you put it in the same folder to find the folder
#		`source ${SCRIPTDIR}/aws_cli_mfa_tool.sh` < call this script from wherever it is
#		`aws_cli_mfa_auth` < activate the function from this tool if you need to run it again later (happens automatically the first time).
# Process:
#	1. It checks if the parameter passed is a role ARN or a friendly name
# 	2. If it was a friendly name, the ARN is looked up in the role_defs file.
# 	3. It attempts to get role temp creds using the supplied ARN from #1 or looked up in #2.
#	4. It parses and uses the creds returned.

#== Configurable Vars ==
# Specify your role's friendly name to look up in the list
ROLE=${1:-'~~~~'}
# How long the MFA session will be good for in seconds (how long you can use the cached creds)
ROLE_DURATION=43200
# Where it will read role friendly names
ROLE_DEFS_FILE="${HOME}/.aws/role_defs"

check_dependancies () {
	if [[ "$(which jq)" = *"not found"* || "$(which pip)" = *"not found"* ]]; then
		if [[ "$(cat /etc/issue)" = *"Ubuntu"* ]]; then
			echo "Installing 'jq' and 'python-pip'..."
			sudo apt-get update
			sudo apt-get install jq python-pip
		else
			echo "The pachages jq and python-pip are required for this script."
			exit 0
		fi
	fi

	if [[ "$(which aws)" = *"not found"* ]]; then
		echo "Installing the pip package AWS CLI ('awscli')..."
		echo "You might need to run 'pip install --upgrade pip'"
		pip install awscli
		echo ""
		echo "Time to configure awscli. Please choose the defaults for everything (except your keys)"
		aws configure
	fi
}

# Make sure the requirements are installed
check_dependancies

aws_cli_assume_role () {
	if [[ "${ROLE}" = *"arn:aws:iam"* ]]; then
		ROLE_ARN=${ROLE}
	else
		echo "Specified value is not an ARN, checking 'friendly name' list..."
		FRIENDLY_REGEX="^${ROLE}|"
		ROLE_ARN=`cat ${ROLE_DEFS_FILE} | grep "${FRIENDLY_REGEX}" | cut -d'|' -f2`
	fi
	if [[ "${ROLE_ARN}" == '' ]]; then
		echo "ERROR: no role for friendly name found. Please add to '${ROLE_DEFS_FILE}' as 'friendly_name|arn'"
		exit 0
	else
		echo "Role ARN to assume: '${ROLE_ARN}'"
	fi
	UNXTM=`date +%s`
	ROLE_CREDS=`aws sts assume-role --role-arn ${ROLE_ARN} --role-session-name cli-${UNXTM}`

	# echo "ROLE_CREDS='${ROLE_CREDS}'"
	TEMP_AWS_ACCESS_KEY_ID=`echo $ROLE_CREDS | jq -r '.Credentials.AccessKeyId'`
	TEMP_AWS_SECRET_ACCESS_KEY=`echo $ROLE_CREDS | jq -r '.Credentials.SecretAccessKey'`
	TEMP_AWS_SESSION_TOKEN=`echo $ROLE_CREDS | jq -r '.Credentials.SessionToken'`
	TEMP_AWS_SESSION_EXP=`echo $ROLE_CREDS | jq -r '.Credentials.Expiration'`
	echo "TEMP_AWS_ACCESS_KEY_ID='${TEMP_AWS_ACCESS_KEY_ID}'"
	# echo "TEMP_AWS_SECRET_ACCESS_KEY='${TEMP_AWS_SECRET_ACCESS_KEY}'"
	# echo "TEMP_AWS_SESSION_TOKEN='${TEMP_AWS_SESSION_TOKEN}'"
	echo "TEMP_AWS_SESSION_EXP='${TEMP_AWS_SESSION_EXP}'"
	unset AWS_ACCESS_KEY_ID
	unset AWS_SECRET_ACCESS_KEY
	unset AWS_SESSION_TOKEN
	export AWS_ACCESS_KEY_ID=${TEMP_AWS_ACCESS_KEY_ID}
	export AWS_SECRET_ACCESS_KEY=${TEMP_AWS_SECRET_ACCESS_KEY}
	export AWS_SESSION_TOKEN=${TEMP_AWS_SESSION_TOKEN}

}

aws_cli_assume_role
