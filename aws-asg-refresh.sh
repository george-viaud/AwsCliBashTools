#!/bin/bash

# Script Name: Autoscaling Group Refresh
# Description: Easy triggering of ASG refresh via CLI with optional AWS profile and region
# https://github.com/george-viaud/AwsCliBashTools
# Author: George Viaud
# Year: 2024
# License: MIT License (see LICENSE https://opensource.org/licenses/MIT)

SCRIPT_NAME=$(basename "$0")

# ANSI color codes
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

AWS_PROFILE=""
AWS_REGION=""


parse_args() {
    for arg in "$@"
    do
        case $arg in
            --tags=*)
            TAGS="${arg#*=}"
            ;;
            --ask-each)
            ASK_EACH=true
            ;;
            --profile=*)
            AWS_PROFILE="--profile ${arg#*=}"
            ;;
            --region=*)
            AWS_REGION="--region ${arg#*=}"
            ;;
            --delay=*)
            DELAY_SECONDS="${arg#*=}"
            ;;
        esac
    done
}

# Function to fetch ASGs based on provided tags and display their names
fetch_and_display_asgs() {
    echo -e "${BLUE}Fetching ASGs matching tags...${NC}"

    JQ_FILTER='.AutoScalingGroups[] | select('
    FIRST_TAG=true

    IFS=',' read -r -a TAG_ARRAY <<< "$TAGS"
    for TAG_PAIR in "${TAG_ARRAY[@]}"; do
        IFS='=' read -r KEY VALUE <<< "$TAG_PAIR"
        if [ "$FIRST_TAG" = true ]; then
            FIRST_TAG=false
        else
            JQ_FILTER+=' and '
        fi
        JQ_FILTER+="(any(.Tags[]; .Key == \"$KEY\" and .Value == \"$VALUE\"))"
    done
    JQ_FILTER+=') | .AutoScalingGroupName'

    ASG_NAMES=$(aws autoscaling describe-auto-scaling-groups $AWS_PROFILE $AWS_REGION | jq -r "$JQ_FILTER")

    if [ -z "$ASG_NAMES" ]; then
        echo -e "${RED}No matching ASGs found.${NC}"
        exit 1
    fi

    echo -e "${GREEN}Found matching ASGs:${NC}"
    echo "$ASG_NAMES"
}

# Function to start the instance refresh (with retry on throttling)
start_instance_refresh() {
    local asg_name="$1"
    local max_retries=5
    local retry=0
    local wait_sec=2

    echo -e "${YELLOW}Starting instance refresh for ASG: $asg_name.${NC}"
    while true; do
        if output=$(aws autoscaling start-instance-refresh --auto-scaling-group-name "$asg_name" \
            --strategy "Rolling" \
            $AWS_PROFILE $AWS_REGION \
            --preferences '{
                "MinHealthyPercentage": 100,
                "MaxHealthyPercentage": 110,
                "InstanceWarmup": 300
            }' 2>&1); then
            echo "$output"
            echo -e "${GREEN}Instance refresh initiated for $asg_name.${NC}"
            return 0
        fi
        retry=$((retry + 1))
        if [[ "$output" == *"Throttling"* ]] && [ $retry -lt $max_retries ]; then
            echo -e "${YELLOW}Throttled (attempt $retry/$max_retries). Waiting ${wait_sec}s before retry...${NC}" >&2
            sleep "$wait_sec"
            wait_sec=$((wait_sec * 2))  # Exponential backoff: 2, 4, 8, 16...
        else
            echo -e "${RED}$output${NC}" >&2
            echo -e "${RED}Instance refresh failed for $asg_name.${NC}" >&2
            return 1
        fi
    done
}

# Main script logic starts here
TAGS=""
ASK_EACH=false
DELAY_SECONDS=2   # Delay between StartInstanceRefresh calls to avoid AWS throttling

parse_args "$@"

if [ -z "$TAGS" ]; then
    echo -e "${RED}Use: $SCRIPT_NAME --tags=\"Key1=Value1, ...\" [--ask-each] [--delay=N] [--profile=your-profile] [--region=your-region]${NC}"
    exit 1
fi

fetch_and_display_asgs

if [ "$ASK_EACH" = true ]; then
    first=true
    for ASG_NAME in $ASG_NAMES; do
        read -p "$(echo -e "${YELLOW}Proceed with instance refresh for $ASG_NAME? (y/N):${NC}") " confirm < /dev/tty
        if [[ $confirm == [yY] ]]; then
            [ "$first" = true ] || { [ "$DELAY_SECONDS" -gt 0 ] && sleep "$DELAY_SECONDS"; }
            first=false
            start_instance_refresh "$ASG_NAME"
        else
            echo -e "${RED}Skipped instance refresh for $ASG_NAME.${NC}"
        fi
    done
else
    read -p "$(echo -e "${YELLOW}Proceed with instance refresh for all above ASGs? (y/N):${NC}") " confirm_all < /dev/tty
    if [[ $confirm_all == [yY] ]]; then
        first=true
        for ASG_NAME in $ASG_NAMES; do
            [ "$first" = true ] || { [ "$DELAY_SECONDS" -gt 0 ] && sleep "$DELAY_SECONDS"; }
            first=false
            start_instance_refresh "$ASG_NAME"
        done
    else
        echo -e "${RED}Instance refresh canceled for all ASGs.${NC}"
    fi
fi

echo -e "${GREEN}Process completed.${NC}"
