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

# Function to start the instance refresh
start_instance_refresh() {
    echo -e "${YELLOW}Starting instance refresh for ASG: $1.${NC}"
    aws autoscaling start-instance-refresh --auto-scaling-group-name "$1" \
        --strategy "Rolling" \
        $AWS_PROFILE $AWS_REGION \
        --preferences '{
            "MinHealthyPercentage": 100,
            "MaxHealthyPercentage": 110,
            "InstanceWarmup": 300
        }'
    echo -e "${GREEN}Instance refresh initiated for $1.${NC}"
}

# Main script logic starts here
TAGS=""
ASK_EACH=false

parse_args "$@"

if [ -z "$TAGS" ]; then
    echo -e "${RED}Use: $SCRIPT_NAME --tags=\"Key1=Value1, ...\" [--ask-each] [--profile=your-profile] [--region=your-region]${NC}"
    exit 1
fi

fetch_and_display_asgs

if [ "$ASK_EACH" = true ]; then
    for ASG_NAME in $ASG_NAMES; do
        read -p "$(echo -e "${YELLOW}Proceed with instance refresh for $ASG_NAME? (y/N):${NC}") " confirm < /dev/tty
        if [[ $confirm == [yY] ]]; then
            start_instance_refresh "$ASG_NAME"
        else
            echo -e "${RED}Skipped instance refresh for $ASG_NAME.${NC}"
        fi
    done
else
    read -p "$(echo -e "${YELLOW}Proceed with instance refresh for all above ASGs? (y/N):${NC}") " confirm_all < /dev/tty
    if [[ $confirm_all == [yY] ]]; then
        for ASG_NAME in $ASG_NAMES; do
            start_instance_refresh "$ASG_NAME"
        done
    else
        echo -e "${RED}Instance refresh canceled for all ASGs.${NC}"
    fi
fi

echo -e "${GREEN}Process completed.${NC}"
