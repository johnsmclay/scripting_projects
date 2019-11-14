#!/bin/bash

# == AWS MFA REQUIRED CLI TOOL ==
# Setup:
#   AWS IAM group exists called "RealPerson" which allows you to set your password, setup MFA, and access home directory on S3.
#   It also has a policy attached that denies all requests (other than MFA setup requests) without MFA present (see policy "RequireMFA+ManageOwnMFA" and/or https://docs.aws.amazon.com/IAM/latest/UserGuide/tutorial_users-self-manage-mfa-and-creds.html ).
# Usage:
# 	To run this you need:
# 		`sudo apt-get update`
# 		`sudo apt-get install jq python-pip`
# 		`pip install awscli`
# 		`aws configure` (just pick all the defaults, except for your keys)
# 	In a script that needs to use this tool just add:
# 		`SCRIPTDIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" >/dev/null && pwd )"` < if you put it in the same folder to find the folder
#		`source ${SCRIPTDIR}/aws_cli_mfa_tool.sh` < call this script from wherever it is
#		`aws_cli_mfa_auth` < activate the function from this tool if you need to run it again later (happens automatically the first time).
# Process:
#	1. It checks a cache file for creds at `${MFA_CREDS_CACHE}` and sources it if available applying those creds.
# 	2. It tries a test query of `aws s3 ls --output=json 2>&1` (aka "litmus test") because all RealPerson members are allowed to do the ListBuckets command when using MFA.
# 	3. In the results of that, it looks for "ListBuckets" which should only come up if you were rejected (bad/expired cache creds or not MFA'd).
# 	4. If you failed the test query it tries to pull your MFA info, if you have none, it'll tell you to set up MFA.
#	5. If it finds an MFA device, it asks you for an OTP (the code from the MFA).
#	6. It attempts to get MFA temp creds using the supplied OTP and the MFA serial number it looked up in #4.
#	7. It parses, uses, and caches the creds in `${MFA_CREDS_CACHE}` along with the expiration of the creds as a comment.

aws_cli_mfa_auth () {

	#== Configurable Vars ==
	# Where it will store cached credentials
	MFA_CREDS_CACHE="${HOME}/.aws/mfa_creds"
	# How long the MFA session will be good for in seconds (how long you can use the cached creds)
	MFA_DURATION=129600

	# Make sure the requirements are installed
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

	# Clear out any temp creds currently in use
	unset AWS_ACCESS_KEY_ID
	unset AWS_SECRET_ACCESS_KEY
	unset AWS_SESSION_TOKEN

	# Check for and load the cached creds
	if [ -f ${MFA_CREDS_CACHE} ]; then
		echo ""
		echo "Sourcing cached credentials..."
		source ${MFA_CREDS_CACHE}
	fi

	# Perform the litmus test
	AWSTEST=`aws s3 ls --output=json 2>&1`
	if [[ "${AWSTEST}" == *"ListBuckets"* ]]; then
		unset AWS_ACCESS_KEY_ID
		unset AWS_SECRET_ACCESS_KEY
		unset AWS_SESSION_TOKEN

		# find current MFA info
		AWSMFA=`aws iam list-mfa-devices`
		if [[ "${AWSMFA}" == *"SerialNumber"* ]]; then

			AWSMFASN=`echo ${AWSMFA} | jq -r '.MFADevices[0].SerialNumber'`
			AWSUSER=`echo ${AWSMFA} | jq -r '.MFADevices[0].UserName'`
			echo ""
			echo "MFA SN = ${AWSMFASN}"
			echo ""
			echo "Enter MFA token (usually 6 numbers from a token or something like Google Authenticator)"
			echo ">"
			read MFAOTP
			AWSMFATKNRES=`aws sts get-session-token --serial-number ${AWSMFASN} --token-code ${MFAOTP} --output=json --duration-seconds ${MFA_DURATION}`
			export AWS_ACCESS_KEY_ID=`echo $AWSMFATKNRES | jq -r '.Credentials.AccessKeyId'`
			export AWS_SECRET_ACCESS_KEY=`echo $AWSMFATKNRES | jq -r '.Credentials.SecretAccessKey'`
			export AWS_SESSION_TOKEN=`echo $AWSMFATKNRES | jq -r '.Credentials.SessionToken'`
			AWS_SESSION_EXP=`echo $AWSMFATKNRES | jq -r '.Credentials.Expiration'`

			echo '# MFA Creds cached by script' > ${MFA_CREDS_CACHE}
			cat <<EOL >> ${MFA_CREDS_CACHE}
export AWS_ACCESS_KEY_ID=${AWS_ACCESS_KEY_ID}
export AWS_SECRET_ACCESS_KEY=${AWS_SECRET_ACCESS_KEY}
export AWS_SESSION_TOKEN=${AWS_SESSION_TOKEN}
# Expires: ${AWS_SESSION_EXP}
EOL
			source ${MFA_CREDS_CACHE}

		else
			echo ""
			echo "No MFA device found on account.  MFA is required. Log into the console, go to IAM > Users, then in your account go to 'Security Credentials' and edit 'Assigned MFA Device'."
			exit 0
		fi
	fi

}

aws_cli_mfa_auth
