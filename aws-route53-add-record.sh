#!/bin/bash

# Check if AWS CLI is installed
if ! command -v aws &> /dev/null
then
    echo "AWS CLI could not be found. Please install it to continue."
    exit 1
fi

# Input validation
if [ "$#" -ne 4 ]; then
    echo "Usage: $0 <domain-name> <host-name> <record-type> <value>"
    exit 1
fi

DOMAIN_NAME=$1
HOST_NAME=$2
RECORD_TYPE=$3
VALUE=$4
TTL=300 # Default TTL value, adjust as needed

# Find the AWS Route 53 hosted zone ID for the given domain
HOSTED_ZONE_ID=$(aws route53 list-hosted-zones-by-name --dns-name "$DOMAIN_NAME" --query "HostedZones[0].Id" --output text)

if [ -z "$HOSTED_ZONE_ID" ]; then
    echo "Hosted zone for domain $DOMAIN_NAME not found."
    exit 1
fi

# Strip leading /hostedzone/ from the zone ID if present
HOSTED_ZONE_ID=${HOSTED_ZONE_ID#/hostedzone/}

# Prepare the change batch JSON
CHANGE_BATCH=$(cat <<EOF
{
  "Comment": "Add/update $HOST_NAME record for $DOMAIN_NAME",
  "Changes": [
    {
      "Action": "UPSERT",
      "ResourceRecordSet": {
        "Name": "$HOST_NAME.$DOMAIN_NAME",
        "Type": "$RECORD_TYPE",
        "TTL": $TTL,
        "ResourceRecords": [
          {
            "Value": "$VALUE"
          }
        ]
      }
    }
  ]
}
EOF
)

# Execute the change
CHANGE_ID=$(aws route53 change-resource-record-sets --hosted-zone-id "$HOSTED_ZONE_ID" --change-batch "$CHANGE_BATCH" --query 'ChangeInfo.Id' --output text)

if [ $? -eq 0 ]; then
    echo "DNS record change request submitted successfully. Change ID: $CHANGE_ID"
else
    echo "Failed to submit DNS record change request."
    exit 1
fi
