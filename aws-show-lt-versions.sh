#!/bin/bash

# Fetch all Auto Scaling Groups
autoscaling_groups=$(aws autoscaling describe-auto-scaling-groups --query "AutoScalingGroups[*].{Name:AutoScalingGroupName, Instances:Instances}" --output json)

# Loop through each Auto Scaling Group
echo "Fetching launch template versions for each instance in Auto Scaling Groups..."
echo "====================================================="

# Parse through the autoscaling groups
echo "$autoscaling_groups" | jq -c '.[]' | while read -r group; do
    group_name=$(echo "$group" | jq -r '.Name')
    echo "Auto Scaling Group: $group_name"
    
    # Loop through each instance in the group
    echo "$group" | jq -c '.Instances[]' | while read -r instance; do
        instance_id=$(echo "$instance" | jq -r '.InstanceId')
        
        # Fetch the launch template ID and version from tags
        launch_template_info=$(aws ec2 describe-instances --instance-ids "$instance_id" --query "Reservations[].Instances[].Tags[?Key=='aws:ec2launchtemplate:id' || Key=='aws:ec2launchtemplate:version'].[Key, Value]" --output json)
        
        # Extract Launch Template ID and Version from the tags
        launch_template_id=$(echo "$launch_template_info" | jq -r '.[0][] | select(.[0]=="aws:ec2launchtemplate:id") | .[1]')
        launch_template_version=$(echo "$launch_template_info" | jq -r '.[0][] | select(.[0]=="aws:ec2launchtemplate:version") | .[1]')
        
        if [ -n "$launch_template_id" ]; then
            echo "  Instance ID: $instance_id"
            echo "    Launch Template ID: $launch_template_id"
            echo "    Launch Template Version: $launch_template_version"
        else
            echo "  Instance ID: $instance_id does not use a Launch Template."
        fi
    done
    echo "====================================================="
done

