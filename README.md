# Aws Cli Bash Tools
Useful scripts for use with aws-cli

## Disclaimer

These scripts are provided "as-is," without warranty of any kind. Use of these scripts is at your own risk. The author is not responsible for any costs, damages, or service interruptions that may occur as a result of their use. Ensure you have proper backups and fully understand the impact of operations such as refreshing Auto Scaling Groups within your AWS environment. It is strongly recommended to test the scripts' functionality in a non-production environment before deploying them in production.

## Prerequisites
- Ensure AWS CLI is installed and configured with the necessary permissions.
- Ensure `jq` is installed for processing JSON data.

## Suggested Installation

To use these scripts from anywhere on your system, it's recommended to move the project folder to a central location and then include that location in your system's `PATH`.

### Moving the Script

Move the script to a suitable directory, such as `/opt/`:
```bash
sudo mv AwsCliBashTools /opt/
```

### Updating the PATH

Add the script's location to your `PATH` by appending it to your `~/.bashrc` or `~/.zshrc` file:
```bash
echo 'export PATH="$PATH:/opt/AwsCliBashTools"' >> ~/.bashrc
```
Then, source your `.bashrc` or `.zshrc` to apply the changes:
```bash
source ~/.bashrc
```

***
## aws-asg-refresh.sh

A Bash script for easily triggering refresh actions on AWS Auto Scaling Groups (ASGs) via the command line, with support for filtering ASGs based on tags and optional AWS profile and region specification.

### Basic Usage
Invoke the script with the `--tags` option followed by a comma-separated list of tag key-value pairs to filter the ASGs:

```bash
./aws-asg-refresh.sh --tags="Environment=Production,App=Analytics"
```

This command will fetch all ASGs with the specified tags and ask to initiate a refresh action on them as a group.

### Specifying AWS Profile and Region
You can specify an AWS profile and region for commands that require it by using the `--profile` and `--region` options, respectively:

```bash
./aws-asg-refresh.sh --tags="Environment=Production,App=Analytics" --profile your-profile --region us-west-2
```

Replace `your-profile` with your actual profile name and `us-west-2` with the desired AWS region.

### Individual-Match Confirmation
To manually confirm each ASG refresh, use the `--ask-each` flag:

```bash
./aws-asg-refresh.sh --tags="Environment=Production,App=Analytics" --ask-each
```

The script will prompt for confirmation for each individual ASG matched.
***

## aws-route53-add-record.sh

A Bash script designed to simplify the process of adding DNS records to AWS Route 53. This script is handy for managing DNS records programmatically without directly using the AWS Management Console or the AWS CLI's complex syntax.

### Basic Usage
To add a new DNS record, invoke the script with the domain name, record name, record type, and record value as arguments:

```bash
./aws-route53-add-record.sh <domain-name> <record-name> <record-type> <record-value>
```

Example - Adding a CNAME record:
```bash
./aws-route53-add-record.sh example.com www CNAME example.com
```

***

## aws-show-lt-versions.sh

A Bash script that displays launch template information for all instances across all Auto Scaling Groups in your AWS account. This script is useful for auditing which launch template versions are currently in use by your ASG instances.

### Basic Usage
Simply run the script without any arguments:

```bash
./aws-show-lt-versions.sh
```

### What it does
The script will:
1. Fetch all Auto Scaling Groups in your AWS account
2. Loop through each ASG and examine all instances within it
3. Display the Launch Template ID and version for each instance
4. Show instances that are not using launch templates

### Example Output
```
Auto Scaling Group: my-production-asg
  Instance ID: i-1234567890abcdef0
    Launch Template ID: lt-1234567890abcdef0
    Launch Template Version: 3
  Instance ID: i-0987654321fedcba0 does not use a Launch Template.
=====================================================
```

### Prerequisites
- AWS CLI configured with permissions to:
  - `autoscaling:DescribeAutoScalingGroups`
  - `ec2:DescribeInstances`
- `jq` installed for JSON processing

***

## route53-extract-all-a-records.sh

A comprehensive Bash script that extracts all A-records from all Route 53 hosted zones in your AWS account and exports them to a CSV file. This script is useful for DNS auditing, migration planning, or creating backups of your DNS records.

### Basic Usage
Run the script without any arguments:

```bash
./route53-extract-all-a-records.sh
```

### What it does
The script will:
1. Fetch all hosted zones from your Route 53 account
2. Extract all A-records from each zone (handles pagination automatically)
3. Export the records to a CSV file named `route53_a_records.csv`
4. Display a summary of records found and show the first 10 records

### Output Format
The generated CSV file contains three columns:
- `base_domain`: The root domain (e.g., example.com)
- `hostname`: The full hostname (e.g., www.example.com)
- `ip_address`: The IP address the record points to

### Example Output
```
========================================
Export complete!
Total A-records found: 25
Output saved to: route53_a_records.csv
========================================

First 10 records in the CSV:
base_domain   hostname           ip_address
example.com   example.com        192.168.1.1
example.com   www.example.com    192.168.1.1
example.com   api.example.com    192.168.1.10
```

### Prerequisites
- AWS CLI configured with permissions to:
  - `route53:ListHostedZones`
  - `route53:ListResourceRecordSets`
- `jq` installed for JSON processing

### Notes
- The script handles pagination automatically for zones with many records
- Root domain records and subdomains are both included
- The output file `route53_a_records.csv` will be overwritten on each run
- Only A-records are extracted (not AAAA, CNAME, MX, etc.)

***
