# AwsCliBashTools
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

