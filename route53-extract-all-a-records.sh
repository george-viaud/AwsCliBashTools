#!/bin/bash

# Route 53 A-Records to CSV Exporter
# This script extracts all A-records from all Route 53 hosted zones
# and exports them to a CSV file

# Set the output file
OUTPUT_FILE="route53_a_records.csv"

# Initialize the CSV file with headers
echo "base_domain,hostname,ip_address" > "$OUTPUT_FILE"

# Counter for total records
TOTAL_RECORDS=0

# Get all hosted zones
echo "Fetching Route 53 hosted zones..."
ZONES=$(aws route53 list-hosted-zones --query 'HostedZones[*].[Id,Name]' --output text)

if [ -z "$ZONES" ]; then
    echo "No hosted zones found or unable to access Route 53."
    exit 1
fi

# Process each hosted zone
while IFS=$'\t' read -r ZONE_ID ZONE_NAME; do
    # Remove the /hostedzone/ prefix from zone ID
    ZONE_ID=$(echo "$ZONE_ID" | sed 's|/hostedzone/||')
    
    echo -e "\nProcessing zone: $ZONE_NAME (ID: $ZONE_ID)"
    
    # Counter for records in this zone
    ZONE_RECORDS=0
    
    # Initialize pagination token
    NEXT_TOKEN=""
    
    # Temporary file to store records for this zone
    TEMP_FILE=$(mktemp)
    
    # Loop to handle pagination
    while true; do
        # Build the AWS CLI command
        if [ -z "$NEXT_TOKEN" ]; then
            RESPONSE=$(aws route53 list-resource-record-sets \
                --hosted-zone-id "$ZONE_ID" \
                --output json 2>/dev/null)
        else
            RESPONSE=$(aws route53 list-resource-record-sets \
                --hosted-zone-id "$ZONE_ID" \
                --starting-token "$NEXT_TOKEN" \
                --output json 2>/dev/null)
        fi
        
        # Check if the command was successful
        if [ $? -ne 0 ]; then
            echo "  Error fetching records for zone $ZONE_NAME"
            break
        fi
        
        # Extract A-records (including root records)
        echo "$RESPONSE" | jq -r '.ResourceRecordSets[] | 
            select(.Type == "A" and .ResourceRecords != null) | 
            .Name as $name | 
            .ResourceRecords[] | 
            "\($name),\(.Value)"' >> "$TEMP_FILE"
        
        # Check for next token
        NEXT_TOKEN=$(echo "$RESPONSE" | jq -r '.NextToken // empty')
        
        if [ -z "$NEXT_TOKEN" ]; then
            break
        fi
    done
    
    # Count records found in this zone
    if [ -f "$TEMP_FILE" ]; then
        ZONE_RECORDS=$(wc -l < "$TEMP_FILE")
        
        # Process and append records to main CSV
        while IFS=',' read -r hostname ip; do
            # Remove trailing dot from hostname if present
            hostname="${hostname%.}"
            
            # Extract base domain (last two parts of the domain)
            base_domain=$(echo "$hostname" | awk -F'.' '{if(NF>=2) print $(NF-1)"."$NF; else print $0}')
            
            # Escape any commas in the hostname (unlikely but possible)
            hostname="${hostname//,/\\,}"
            
            # Write to CSV with base domain as first column
            echo "$base_domain,$hostname,$ip" >> "$OUTPUT_FILE"
            
        done < "$TEMP_FILE"
        
        TOTAL_RECORDS=$((TOTAL_RECORDS + ZONE_RECORDS))
    fi
    
    # Clean up temporary file
    rm -f "$TEMP_FILE"
    
    echo "  Found $ZONE_RECORDS A-records in $ZONE_NAME"
    
done <<< "$ZONES"

echo -e "\n========================================="
echo "Export complete!"
echo "Total A-records found: $TOTAL_RECORDS"
echo "Output saved to: $OUTPUT_FILE"
echo "========================================="

# Display first few lines of the output
if [ -f "$OUTPUT_FILE" ] && [ "$TOTAL_RECORDS" -gt 0 ]; then
    echo -e "\nFirst 10 records in the CSV:"
    head -n 11 "$OUTPUT_FILE" | column -t -s ','
fi
