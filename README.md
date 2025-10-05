# CloudFormation Nested Stacks Tutorial

This demo application teaches students how to host and manage AWS CloudFormation nested stacks. The project contains two versions of the same application stack, demonstrating an evolutionary approach to infrastructure as code.

## 📋 Prerequisites

- AWS CLI installed and configured
- AWS account with appropriate permissions
- `cfn_nag` installed (optional, for linting)
- Git installed (for version tracking)

## 🔑 Getting Account-Specific Parameters

Before you begin, you'll need to gather several account-specific parameters from your AWS environment. The Makefile will automatically detect most of these, but you should verify them and understand what they are.

### 1. AWS Account ID

Your 12-digit AWS account identifier.

**Command to get it:**
```bash
aws sts get-caller-identity --query Account --output text
```

**Example output:** `123456789012`

**Where it's used:**
- S3 bucket naming: `cloudformation.us-west-2.{ACCOUNT_ID}`
- Referenced in Makefile line 5

### 2. AWS Region

The region where you'll deploy your resources.

**Command to get current region:**
```bash
aws configure get region
```

**Alternative (from current credentials):**
```bash
aws ec2 describe-availability-zones --query 'AvailabilityZones[0].[RegionName]' --output text
```

**Example output:** `us-west-2`

**Where it's used:**
- S3 bucket creation and location
- CloudFormation stack deployment region
- Default in Makefile line 2: `AWS_REGION := us-west-2`

### 3. IAM Instance Profile ARN (if using existing roles)

The ARN of the IAM instance profile for EC2 instances.

**Command to list instance profiles:**
```bash
aws iam list-instance-profiles --query 'InstanceProfiles[].[InstanceProfileName,Arn]' --output table
```

**Command to get a specific instance profile:**
```bash
aws iam get-instance-profile --instance-profile-name bluejays-delivery-role --query 'InstanceProfile.Arn' --output text
```

**Example output:** `arn:aws:iam::123456789012:instance-profile/bluejays-delivery-role`

**Where it's used:**
- `mr-bluejays-parent.yml:72` - `!ImportValue bluejays-delivery-role`
- Note: This demo assumes a cross-stack export exists with this name

### 4. S3 Analytics Bucket ARN (from SSM Parameter Store)

The ARN of an S3 bucket for analytics data, stored in Parameter Store.

**Command to check if parameter exists:**
```bash
aws ssm get-parameter --name /bluejays/analyticsbucketarn --query 'Parameter.Value' --output text
```

**Command to create parameter if needed:**
```bash
# First, create or identify your analytics bucket
aws s3 mb s3://my-bluejays-analytics-bucket-123456

# Then store its ARN in Parameter Store
aws ssm put-parameter \
  --name /bluejays/analyticsbucketarn \
  --value "arn:aws:s3:::my-bluejays-analytics-bucket-123456" \
  --type String \
  --description "S3 bucket for BlueJays analytics data"
```

**Where it's used:**
- `mr-bluejays-parent.yml:73` - `{{resolve:ssm:/bluejays/analyticsbucketarn:1}}`

### 5. AMI ID for Your Region

The Amazon Machine Image ID for EC2 instances (region-specific).

**Command to find latest Amazon Linux 2 AMI:**
```bash
aws ec2 describe-images \
  --owners amazon \
  --filters "Name=name,Values=amzn2-ami-hvm-*-x86_64-gp2" \
  --query 'sort_by(Images, &CreationDate)[-1].[ImageId,Name,Description]' \
  --output table
```

**Command to check if specific AMI exists:**
```bash
aws ec2 describe-images --image-ids ami-03c0c92f8de739e34 --query 'Images[0].ImageId' --output text
```

**Example output:** `ami-03c0c92f8de739e34`

**Where it's used:**
- `mr-bluejays-parent.yml:69` - `BlueJaysAMI: "ami-03c0c92f8de739e34"`
- **Important:** This AMI ID is hardcoded and may need updating for your region

### 6. Verify All Configuration

Run this command to see all current configuration:

```bash
make show-config
```

**Example output:**
```
Configuration:
  APPLICATION:     bluejays
  AWS_REGION:      us-west-2
  ACCOUNT_ID:      123456789012
  S3_BUCKET_NAME:  cloudformation.us-west-2.123456789012
  ENVIRONMENT:     testing
  V1_DIR:          nested-cloudformation-example
  V2_DIR:          nested-cloudformation-example-nginx
```

### 7. Check AWS CLI Authentication

Verify your AWS credentials are configured:

```bash
aws sts get-caller-identity
```

**Example output:**
```json
{
    "UserId": "AIDAI1234567890EXAMPLE",
    "Account": "123456789012",
    "Arn": "arn:aws:iam::123456789012:user/your-username"
}
```

### Parameters Summary Table

| Parameter | How to Get It | Example Value | Where Used |
|-----------|---------------|---------------|------------|
| Account ID | `aws sts get-caller-identity --query Account --output text` | `123456789012` | S3 bucket name |
| Region | `aws configure get region` | `us-west-2` | All resources |
| S3 Bucket | Auto-generated from Account ID + Region | `cloudformation.us-west-2.123456789012` | Template storage |
| Instance Profile ARN | `aws iam list-instance-profiles` | `arn:aws:iam::123456789012:instance-profile/bluejays-delivery-role` | EC2 stack |
| Analytics Bucket | `aws ssm get-parameter --name /bluejays/analyticsbucketarn` | `arn:aws:s3:::analytics-bucket` | SSM parameter |
| AMI ID | `aws ec2 describe-images` (region-specific) | `ami-03c0c92f8de739e34` | EC2 instances |

### Notes:
- The parent Makefile **automatically detects** Account ID and constructs the S3 bucket name
- You may need to **manually create** the IAM instance profile and SSM parameters before deploying
- The AMI ID is **hardcoded** in the CloudFormation templates and may need updating

## 🏗️ Project Structure

```
.
├── nested-cloudformation-example/          # Version 1: Basic nested stack
│   ├── mr-bluejays-parent.yml             # Parent stack orchestrating all nested stacks
│   ├── networking-stack.yml               # VPC, subnets, and networking resources
│   ├── security-group-stack.yml           # Security groups for ELB and instances
│   ├── ec2-stack.yml                      # EC2 instances and Auto Scaling Group
│   ├── iam-role.yml                       # IAM roles and policies
│   ├── s3-stack.yml                       # S3 buckets
│   └── Makefile                           # Build automation for v1
│
├── nested-cloudformation-example-nginx/    # Version 2: Enhanced with Nginx
│   ├── mr-bluejays-parent.yml             # Updated parent stack
│   ├── networking-stack.yml               # Same networking setup
│   ├── security-group-stack.yml           # Same security groups
│   ├── ec2-stack.yml                      # Modified with Nginx configuration
│   ├── iam-role.yml                       # Same IAM configuration
│   ├── s3-stack.yml                       # Same S3 configuration
│   └── Makefile                           # Build automation for v2
│
├── Makefile                                # Parent Makefile (you are here!)
└── README.md                               # This file
```

## 🚀 Quick Start Guide

### Step 0: Deploy Prerequisite Stacks

Before deploying the main application, you must deploy two prerequisite stacks in order. These stacks create shared resources that the main application depends on.

⚠️ **Important:** Deploy these in order: S3 Stack → IAM Role Stack

#### Step 0.1: Deploy the S3 Analytics Bucket Stack

This creates an S3 bucket for analytics data and stores its ARN in SSM Parameter Store.

```bash
# Navigate to version 1 directory
cd nested-cloudformation-example

# Deploy the S3 stack
aws cloudformation create-stack \
  --stack-name bluejays-analytics-bucket \
  --template-body file://s3-stack.yml \
  --region us-west-2

# Wait for stack to complete
aws cloudformation wait stack-create-complete \
  --stack-name bluejays-analytics-bucket \
  --region us-west-2

# Verify the SSM parameter was created
aws ssm get-parameter --name /bluejays/analyticsbucketarn --query 'Parameter.Value' --output text
```

**What this creates:**
- An S3 bucket with public access for Reports folder (see `s3-stack.yml:8-12`)
- An SSM Parameter Store entry at `/bluejays/analyticsbucketarn` (see `s3-stack.yml:28-34`)
- A bucket policy allowing public read access to `/Reports/*` (see `s3-stack.yml:13-27`)

**Key Learning Points:**
- **Line 29**: `Type: AWS::SSM::Parameter` - Creates an SSM parameter
- **Line 31**: `Name: /bluejays/analyticsbucketarn` - Parameter name used by other stacks
- **Line 33**: `Value: !GetAtt AnalyticsBucket.Arn` - Stores the bucket ARN
- **Line 6**: `DeletionPolicy: Retain` - Bucket persists even if stack is deleted

#### Step 0.2: Deploy the IAM Role Stack

This creates IAM roles and instance profiles for EC2 instances. **This stack depends on the S3 stack** because it references the analytics bucket ARN from SSM Parameter Store.

```bash
# Still in nested-cloudformation-example directory
aws cloudformation create-stack \
  --stack-name bluejays-iam-roles \
  --template-body file://iam-role.yml \
  --capabilities CAPABILITY_IAM CAPABILITY_NAMED_IAM \
  --region us-west-2

# Wait for stack to complete
aws cloudformation wait stack-create-complete \
  --stack-name bluejays-iam-roles \
  --region us-west-2

# Verify the export was created
aws cloudformation list-exports \
  --query "Exports[?Name=='bluejays-delivery-role'].Value" \
  --output text
```

**What this creates:**
- An IAM role with EC2 assume role policy (see `iam-role.yml:9-23`)
- An instance profile that can be attached to EC2 instances (see `iam-role.yml:24-30`)
- IAM policies for CloudWatch Logs and S3 access (see `iam-role.yml:31-49`)
- A **CloudFormation Export** named `bluejays-delivery-role` (see `iam-role.yml:54-55`)

**Key Learning Points:**
- **Line 47**: `{{resolve:ssm:/bluejays/analyticsbucketarn:1}}` - References SSM parameter from S3 stack
- **Line 54-55**: `Export: Name:` - Creates a CloudFormation export for cross-stack references
- **Line 55**: `!Join ['', [!Ref ApplicationName, "-delivery-role"]]` - Constructs export name dynamically
- **Line 13**: `ManagedPolicyArns` - Attaches AWS-managed policy for SSM access

#### Understanding Output Mechanisms

This demo showcases **two different ways** to share resources between CloudFormation stacks:

##### 1. SSM Parameter Store (s3-stack.yml)

**How it works:**
- Stack creates an `AWS::SSM::Parameter` resource (lines 28-36)
- Parameter stores the S3 bucket ARN with a hierarchical name
- Other stacks/templates retrieve it using `{{resolve:ssm:...}}`

**Advantages:**
- ✅ Can be used across AWS accounts and regions
- ✅ Values can be updated independently of stacks
- ✅ Supports versioning (`:1` in the resolve syntax)
- ✅ Works outside CloudFormation (AWS CLI, SDKs, etc.)

**Usage example:**
```yaml
# In iam-role.yml line 47
Resource: '{{resolve:ssm:/bluejays/analyticsbucketarn:1}}'

# In mr-bluejays-parent.yml line 73
AnalyticsBucket: '{{resolve:ssm:/bluejays/analyticsbucketarn:1}}'
```

**Retrieve manually:**
```bash
aws ssm get-parameter --name /bluejays/analyticsbucketarn
```

##### 2. CloudFormation Exports (iam-role.yml)

**How it works:**
- Stack outputs a value with an `Export` name (lines 50-55)
- Other stacks in the **same region** import it using `!ImportValue`
- CloudFormation tracks dependencies between stacks

**Advantages:**
- ✅ CloudFormation prevents deletion if exports are in use
- ✅ Automatic dependency tracking
- ✅ Native CloudFormation feature
- ✅ No additional AWS service required

**Limitations:**
- ❌ Only works within the same region
- ❌ Export names must be unique per region
- ❌ Cannot delete exporting stack while imports exist

**Usage example:**
```yaml
# In iam-role.yml lines 50-55
Outputs:
  InstanceProfileArn:
    Value: !GetAtt DeliveryInstanceProfile.Arn
    Export:
      Name: !Join ['', [!Ref ApplicationName, "-delivery-role"]]

# In mr-bluejays-parent.yml line 72
InstanceProfileArn: !ImportValue bluejays-delivery-role
```

**Retrieve manually:**
```bash
aws cloudformation list-exports --query "Exports[?Name=='bluejays-delivery-role']"
```

##### When to Use Each Method

| Use Case | SSM Parameter Store | CloudFormation Exports |
|----------|---------------------|------------------------|
| Cross-region sharing | ✅ Yes | ❌ No |
| Cross-account sharing | ✅ Yes (with permissions) | ❌ No |
| Update value independently | ✅ Yes | ❌ No (must update stack) |
| Prevent accidental deletion | ⚠️ Manual policy needed | ✅ Automatic |
| Use outside CloudFormation | ✅ Yes | ❌ No |
| Cost | ~$0.05 per 10,000 requests | Free |

#### Step 0.3: Verify Prerequisites

Before proceeding, verify both prerequisite stacks are deployed:

```bash
# Check both stacks exist
aws cloudformation describe-stacks \
  --query "Stacks[?contains(StackName, 'bluejays')].{Name:StackName,Status:StackStatus}" \
  --output table

# Verify SSM parameter exists
aws ssm get-parameter --name /bluejays/analyticsbucketarn

# Verify CloudFormation export exists
aws cloudformation list-exports --query "Exports[?Name=='bluejays-delivery-role']"
```

Expected output should show:
- `bluejays-analytics-bucket` stack in `CREATE_COMPLETE` status
- `bluejays-iam-roles` stack in `CREATE_COMPLETE` status
- SSM parameter `/bluejays/analyticsbucketarn` with an S3 ARN value
- CloudFormation export `bluejays-delivery-role` with an instance profile ARN

### Step 1: Set Up Your S3 Bucket for Templates

Create an S3 bucket to store your CloudFormation templates. The bucket naming convention is `cloudformation.{region}.{account-id}`.

```bash
# Return to parent directory
cd ..

# Create the template storage bucket
make setup-bucket
```

This command will:
- Automatically detect your AWS account ID
- Create the bucket with the correct naming scheme
- Enable versioning on the bucket
- Configure public access block for security

To verify the bucket was created:

```bash
make check-bucket
```

### Step 2: Deploy Version 1 (Basic Stack)

#### 2.1 Publish Templates to S3

```bash
make v1-publish
```

This uploads all CloudFormation templates to S3 under:
- `s3://{bucket}/bluejays/{git-hash}/` (versioned)
- `s3://{bucket}/bluejays/latest/` (latest version)

#### 2.2 Create the Stack

```bash
make v1-create
```

This creates the CloudFormation stack named `mr-bluejays-latest-testing`.

#### 2.3 Monitor Stack Creation

Use the AWS Console or CLI to monitor:

```bash
aws cloudformation describe-stacks --stack-name mr-bluejays-latest-testing
```

### Step 3: Update to Version 2 (Nginx Enhanced)

#### 3.1 Publish Version 2 Templates

```bash
make v2-publish
```

#### 3.2 Update Using Changeset (Recommended)

Changesets let you preview changes before applying them:

```bash
make v2-changeset
```

Review the changeset in the AWS Console, then execute it when ready.

#### 3.3 Direct Update (Alternative)

For immediate updates without preview:

```bash
make v2-update
```

### Step 4: Clean Up

To delete the stack and all resources:

```bash
# Delete version 1
make v1-clean

# Delete version 2
make v2-clean

# Delete both
make clean-all
```

**Note:** The S3 bucket is NOT deleted by these commands. Delete it manually if needed.

## 🔍 Key Concepts and Line Numbers to Study

### Understanding Prerequisite Stacks and Output Mechanisms

**S3 Analytics Stack** (`s3-stack.yml`)

- **Line 6**: `DeletionPolicy: Retain` - Bucket persists after stack deletion for data safety
- **Lines 8-12**: `PublicAccessBlockConfiguration` - Explicitly allows public access (unusual, study carefully!)
- **Lines 13-27**: `AWS::S3::BucketPolicy` - Grants public read access to Reports folder only
- **Lines 28-36**: `AWS::SSM::Parameter` - **Creates SSM Parameter Store entry**
- **Line 31**: Parameter name `/bluejays/analyticsbucketarn` - Hierarchical naming convention
- **Line 33**: `!GetAtt AnalyticsBucket.Arn` - Dynamically stores bucket ARN in SSM
- **Lines 37-40**: Stack outputs (different from SSM parameter, used for CloudFormation only)

**IAM Role Stack** (`iam-role.yml`)

- **Lines 9-23**: `AWS::IAM::Role` - EC2 assume role policy allowing instances to use this role
- **Line 13**: `ManagedPolicyArns` - Attaches AWS-managed policy (best practice vs. inline)
- **Lines 24-30**: `AWS::IAM::InstanceProfile` - Wrapper that binds IAM role to EC2 instances
- **Line 26**: `DependsOn: DeliveryRole` - Explicit dependency (role must exist first)
- **Line 47**: `{{resolve:ssm:/bluejays/analyticsbucketarn:1}}` - **References SSM parameter** from S3 stack
- **Lines 50-55**: Output with `Export` - **Creates CloudFormation cross-stack export**
- **Line 55**: `!Join` to construct export name `bluejays-delivery-role` dynamically

### Understanding Nested Stacks

**Parent Stack Structure** (`mr-bluejays-parent.yml`)

- **Lines 33-46**: `NetworkingStack` - First nested stack, creates VPC and subnets
- **Lines 47-61**: `SecurityGroupStack` - Depends on networking via `!GetAtt NetworkingStack.Outputs.VpcId`
- **Lines 62-83**: `EC2Stack` - Uses outputs from both previous stacks
- **Line 46, 61, 83**: `TemplateURL` - Notice how nested templates are referenced from S3
- **Line 72**: `!ImportValue bluejays-delivery-role` - **Uses CloudFormation Export** from IAM stack
- **Line 73**: `{{resolve:ssm:/bluejays/analyticsbucketarn:1}}` - **Uses SSM Parameter** from S3 stack
- **Line 74**: `!Join` with `!GetAtt` - Complex output aggregation from nested stacks

### Three Methods of Sharing Data Between Stacks

| Method | Example Location | Use Case | Scope |
|--------|-----------------|----------|-------|
| **Nested Stack Outputs** | `mr-bluejays-parent.yml:53` | Parent accessing child stack outputs | Within same template hierarchy |
| **CloudFormation Exports** | `iam-role.yml:54-55` & `mr-bluejays-parent.yml:72` | Independent stacks in same region | Same region only |
| **SSM Parameter Store** | `s3-stack.yml:28-36` & `iam-role.yml:47` | Cross-region, cross-account, or external access | Global (with proper permissions) |

### Makefile Patterns

**Version 1 Makefile** (`nested-cloudformation-example/Makefile`)

- **Line 5**: `GITHASH` - Captures git commit for versioning
- **Line 9-10**: S3 bucket naming and URI construction
- **Lines 20-21**: Publishing templates with versioning (both git hash and latest)
- **Lines 27, 35, 44**: Template URL construction using HTTPS S3 URLs
- **Line 29**: `--disable-rollback` - Useful for debugging initial deployments
- **Line 42**: `--include-nested-stacks` - Required for changeset with nested stacks

**Parent Makefile** (`./Makefile`)

- **Line 5**: Dynamic account ID detection using AWS CLI
- **Line 6**: Automated bucket name construction
- **Lines 30-36**: S3 bucket creation with versioning and security
- **Lines 42-44, 54-56**: Pattern for delegating to child Makefiles with variable override

### CloudFormation Features

**Interesting CloudFormation Patterns:**

1. **Nested Stack Dependencies** (`mr-bluejays-parent.yml:53`)
   - `CustomVpcId: !GetAtt NetworkingStack.Outputs.VpcId`
   - Shows how outputs from one stack feed into another

2. **Cross-Stack References** (`mr-bluejays-parent.yml:72`)
   - `!ImportValue bluejays-delivery-role`
   - References resources from completely separate stacks

3. **Dynamic Parameter Resolution** (`mr-bluejays-parent.yml:73`)
   - `{{resolve:ssm:/bluejays/analyticsbucketarn:1}}`
   - Retrieves values from Parameter Store at deployment time

4. **Resource Tagging** (`mr-bluejays-parent.yml:39-45`)
   - Consistent tagging across all nested stacks
   - Enables cost tracking and resource management

5. **Capability Requirements** (`Makefile:29, 36, 45`)
   - `CAPABILITY_IAM CAPABILITY_NAMED_IAM`
   - Required when templates create IAM resources

## 📝 Learning Exercises

### Exercise 1: Understanding Output Mechanisms

**Goal:** Understand the difference between SSM Parameter Store and CloudFormation Exports

1. Deploy the prerequisite stacks (S3 and IAM)
2. Retrieve the analytics bucket ARN using SSM:
   ```bash
   aws ssm get-parameter --name /bluejays/analyticsbucketarn --query 'Parameter.Value'
   ```
3. Retrieve the instance profile ARN using CloudFormation exports:
   ```bash
   aws cloudformation list-exports --query "Exports[?Name=='bluejays-delivery-role']"
   ```
4. Try to delete the IAM role stack:
   ```bash
   aws cloudformation delete-stack --stack-name bluejays-iam-roles
   ```
   **Question:** What happens if you try to delete it before deploying the main stack? After?
5. **Challenge:** Modify the S3 stack to also export the bucket ARN as a CloudFormation export

### Exercise 2: Understanding the Flow

1. Review the parent stack at `nested-cloudformation-example/mr-bluejays-parent.yml`
2. Trace how VPC ID flows from NetworkingStack → SecurityGroupStack → EC2Stack
3. Identify all three data-sharing methods used:
   - Nested stack outputs (`!GetAtt`)
   - CloudFormation exports (`!ImportValue`)
   - SSM parameters (`{{resolve:ssm:...}}`)
4. Draw a dependency diagram showing:
   - Prerequisite stacks (S3, IAM)
   - Main nested stacks (Networking, SecurityGroup, EC2)
   - How data flows between them

### Exercise 3: Making Changes

1. Modify the `InstanceType` parameter default in the parent stack
2. Run `make v1-publish` to upload the change
3. Use `make v1-changeset` to see what would change
4. Execute the changeset

### Exercise 4: Version Comparison

1. Compare the two EC2 stack templates:
   ```bash
   diff nested-cloudformation-example/ec2-stack.yml \
        nested-cloudformation-example-nginx/ec2-stack.yml
   ```
2. Identify the Nginx-specific changes
3. Understand why these changes require a stack update

### Exercise 5: Cross-Stack Dependencies

**Goal:** Understand stack deletion order and dependencies

1. With all stacks deployed, try to delete stacks in the wrong order:
   ```bash
   # Try deleting IAM role stack first (should fail)
   aws cloudformation delete-stack --stack-name bluejays-iam-roles
   ```
2. Check which stack is preventing deletion:
   ```bash
   aws cloudformation describe-stacks --stack-name bluejays-iam-roles \
     --query 'Stacks[0].StackStatus'
   ```
3. Determine the correct deletion order (reverse of creation order)
4. **Bonus:** What happens if you delete the S3 analytics bucket manually while stacks are still running?

## 🛠️ Available Make Commands

### Setup Commands
- `make setup-bucket` - Create S3 bucket for CloudFormation templates
- `make check-bucket` - Verify S3 bucket exists and is accessible
- `make show-config` - Display current configuration

### Version 1 Commands
- `make v1-publish` - Publish v1 templates to S3
- `make v1-create` - Create v1 CloudFormation stack
- `make v1-update` - Update v1 CloudFormation stack
- `make v1-changeset` - Create changeset for v1 stack (preview changes)
- `make v1-clean` - Delete v1 CloudFormation stack
- `make v1-lint` - Lint v1 CloudFormation templates

### Version 2 Commands
- `make v2-publish` - Publish v2 templates to S3
- `make v2-create` - Create v2 CloudFormation stack
- `make v2-update` - Update v2 CloudFormation stack
- `make v2-changeset` - Create changeset for v2 stack (preview changes)
- `make v2-clean` - Delete v2 CloudFormation stack
- `make v2-lint` - Lint v2 CloudFormation templates

### Utility Commands
- `make clean-all` - Delete all stacks
- `make all` - Show help menu (default)

## 🔐 Security Best Practices

The parent Makefile implements several security best practices:

1. **Public Access Block** - Prevents accidental public exposure of templates
2. **Bucket Versioning** - Maintains history of template changes
3. **Dynamic Account ID** - Prevents hardcoded account IDs in code
4. **IAM Capabilities** - Explicitly acknowledges IAM resource creation

## 🐛 Troubleshooting

### Stack Creation Fails

1. Check IAM permissions for CloudFormation
2. Verify all nested templates are published to S3
3. Review CloudFormation events in AWS Console:
   ```bash
   aws cloudformation describe-stack-events \
     --stack-name mr-bluejays-latest-testing --max-items 10
   ```

### Template Not Found Error

- Ensure you ran `make v1-publish` or `make v2-publish` before creating stacks
- Verify S3 bucket name matches account ID:
  ```bash
  make show-config
  ```

### Bucket Already Exists Error

- If the bucket exists in another region, delete it first or update `AWS_REGION` in the Makefile
- If the bucket name is taken globally, you'll need to choose a different naming convention

## 📚 Additional Resources

- [AWS CloudFormation Nested Stacks](https://docs.aws.amazon.com/AWSCloudFormation/latest/UserGuide/using-cfn-nested-stacks.html)
- [CloudFormation Best Practices](https://docs.aws.amazon.com/AWSCloudFormation/latest/UserGuide/best-practices.html)
- [cfn_nag for Template Linting](https://github.com/stelligent/cfn_nag)

## 🎯 Learning Objectives

By completing this tutorial, students will learn:

1. ✅ How to organize infrastructure as nested CloudFormation stacks
2. ✅ How to manage stack dependencies and deployment order
3. ✅ **Three methods for sharing data between stacks:**
   - Nested stack outputs using `!GetAtt`
   - CloudFormation exports using `!ImportValue`
   - SSM Parameter Store using `{{resolve:ssm:...}}`
4. ✅ When to use SSM Parameter Store vs. CloudFormation Exports
5. ✅ How to version and publish templates to S3
6. ✅ How to use changesets for safe updates
7. ✅ How to automate deployments with Makefiles
8. ✅ Best practices for CloudFormation stack organization
9. ✅ Understanding IAM roles, instance profiles, and policies
10. ✅ How to use DeletionPolicy and DependsOn in CloudFormation

---

**Happy Learning! 🚀**
