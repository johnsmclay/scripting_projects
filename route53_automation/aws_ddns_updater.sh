#!/bin/bash

# ### For pfsense ###
#  See awscli instructions - scripting_projects/route53_automation/awscli_on_pfsense.md
#  Make sure you install bash as the built-in shell doesn't support a lot of standard bash things.
#  Use the bash path /usr/local/bin/bash instead of /bin/bash as that is the install directory in PfSense.

# ### general info ###
# This assumes you already have the AWSCLI and python 2.7.
# This also assumes you already have your domain/zone setup in Route53 and have created
#   an "A" recordset for the domain name we will be updating.
# Log files write to and look for the currently executing directory, so you will need to
# be in the same directory each time if you want it to work. In cron you do it like this:
#    `cd /root && /root/aws_ddns_update.sh`
# alternatively you can just change the $DIR variable to point to a non-relative path.

# Hosted Zone ID e.g. BJBK35SKMM9OE
ZONEID="enter zone id here"

# The CNAME you want to update e.g. hello.example.com
RECORDSET="enter cname here"

# More advanced options below
# The Time-To-Live of this recordset
TTL=300
# Change this if you want
COMMENT="Auto updating @ `date`"
# Change to AAAA if using an IPv6 address
TYPE="A"

# Get the external IP address from OpenDNS (more reliable than other providers)
IP=`dig +short myip.opendns.com @resolver1.opendns.com`

function valid_ip()
{
    local  ip=$1
    local  stat=1

    if [[ $ip =~ ^[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}$ ]]; then
        OIFS=$IFS
        IFS='.'
        ip=($ip)
        IFS=$OIFS
        [[ ${ip[0]} -le 255 && ${ip[1]} -le 255 \
            && ${ip[2]} -le 255 && ${ip[3]} -le 255 ]]
        stat=$?
    fi
    return $stat
}

function get_current_record_value()
{
    ZONEID=$1
    RECORDSET=$2
    REC_VALUE=`aws route53 list-resource-record-sets --hosted-zone-id ${ZONEID} --query "ResourceRecordSets[?Name == '${RECORDSET}.']" | python -c "import sys, json; print json.load(sys.stdin)[0]['ResourceRecords'][0]['Value']"`
    return ${REC_VALUE}
}

# Get current dir
DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
REC_ID="${ZONEID}_${RECORDSET}"
LOGFILE="$DIR/update-route53.log"
IPFILE="$DIR/update-route53_${REC_ID}.ip"

if ! valid_ip $IP; then
    echo "`date`_${REC_ID}> Invalid IP address: $IP" >> "$LOGFILE"
    exit 1
fi

# Check if the IP has changed
if [ ! -f "$IPFILE" ]
    then
    touch "$IPFILE"
fi

# Usually this just checks the local file the script writes to see if the IP chnaged,
# but if there is a possibility that it got changed in AWS by someone else you might
# want to try uncommenting CURRENT_REC_VALUE and checking against that instead.

#CURRENT_REC_VALUE=`get_current_record_value ${ZONEID} ${RECORDSET}`

if grep -Fxq "$IP" "$IPFILE"; then
    # code if found
    echo "`date`_${REC_ID}> IP is still $IP. Exiting" >> "$LOGFILE"
    exit 0
else
    echo "`date`_${REC_ID}> IP has changed to $IP" >> "$LOGFILE"
    # Fill a temp file with valid JSON
    TMPFILE=$(mktemp /tmp/temporary-file.XXXXXXXX)
    cat > ${TMPFILE} << EOF
    {
      "Comment":"$COMMENT",
      "Changes":[
        {
          "Action":"UPSERT",
          "ResourceRecordSet":{
            "ResourceRecords":[
              {
                "Value":"$IP"
              }
            ],
            "Name":"$RECORDSET",
            "Type":"$TYPE",
            "TTL":$TTL
          }
        }
      ]
    }
EOF

    # Update the Hosted Zone record
    aws route53 change-resource-record-sets \
        --hosted-zone-id $ZONEID \
        --change-batch file://"$TMPFILE" >> "$LOGFILE"
    echo "" >> "$LOGFILE"

    # Clean up
    rm $TMPFILE
fi

# All Done - cache the IP address for next time
echo "$IP" > "$IPFILE"
