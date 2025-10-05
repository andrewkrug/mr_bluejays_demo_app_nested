APPLICATION := bluejays
AWS_REGION := us-west-2
ENVIRONMENT := testing
ACCOUNT_ID := $(shell aws sts get-caller-identity --query Account --output text)
S3_BUCKET_NAME := cloudformation.$(AWS_REGION).$(ACCOUNT_ID)

# Project directories
V1_DIR := nested-cloudformation-example
V2_DIR := nested-cloudformation-example-nginx

.PHONY: all
all:
	@echo 'Available make targets:'
	@echo ''
	@echo 'Setup Commands:'
	@echo '  setup-bucket         - Create S3 bucket for CloudFormation templates'
	@echo '  check-bucket         - Check if S3 bucket exists'
	@echo ''
	@echo 'Version 1 (Basic Stack) Commands:'
	@echo '  v1-publish           - Publish v1 templates to S3'
	@echo '  v1-create            - Create v1 CloudFormation stack'
	@echo '  v1-update            - Update v1 CloudFormation stack'
	@echo '  v1-changeset         - Create changeset for v1 stack'
	@echo '  v1-clean             - Delete v1 CloudFormation stack'
	@echo '  v1-lint              - Lint v1 CloudFormation templates'
	@echo ''
	@echo 'Version 2 (with Nginx) Commands:'
	@echo '  v2-publish           - Publish v2 templates to S3'
	@echo '  v2-create            - Create v2 CloudFormation stack'
	@echo '  v2-update            - Update v2 CloudFormation stack'
	@echo '  v2-changeset         - Create changeset for v2 stack'
	@echo '  v2-clean             - Delete v2 CloudFormation stack'
	@echo '  v2-lint              - Lint v2 CloudFormation templates'
	@echo ''
	@echo 'Predecessor Stack Commands:'
	@echo '  deploy-predecessors  - Deploy S3 and IAM role stacks in order'
	@echo ''
	@echo 'Current Configuration:'
	@echo '  AWS Region: $(AWS_REGION)'
	@echo '  Account ID: $(ACCOUNT_ID)'
	@echo '  S3 Bucket:  $(S3_BUCKET_NAME)'
	@echo '  Environment: $(ENVIRONMENT)'

.PHONY: setup-bucket
setup-bucket:
	@echo "Creating S3 bucket: $(S3_BUCKET_NAME)"
	@aws s3api create-bucket \
		--bucket $(S3_BUCKET_NAME) \
		--region $(AWS_REGION) \
		--create-bucket-configuration LocationConstraint=$(AWS_REGION) \
		2>/dev/null || echo "Bucket already exists or creation failed"
	@aws s3api put-bucket-versioning \
		--bucket $(S3_BUCKET_NAME) \
		--versioning-configuration Status=Enabled
	@aws s3api put-public-access-block \
		--bucket $(S3_BUCKET_NAME) \
		--public-access-block-configuration \
		"BlockPublicAcls=true,IgnorePublicAcls=true,BlockPublicPolicy=true,RestrictPublicBuckets=true"
	@echo "Bucket $(S3_BUCKET_NAME) is ready"

.PHONY: check-bucket
check-bucket:
	@echo "Checking bucket: $(S3_BUCKET_NAME)"
	@aws s3 ls s3://$(S3_BUCKET_NAME) && echo "Bucket exists and is accessible" || echo "Bucket does not exist or is not accessible"

# Version 1 targets
.PHONY: v1-publish
v1-publish:
	@echo "Publishing version 1 templates..."
	cd $(V1_DIR) && $(MAKE) publish S3_PROD_BUCKET_NAME=$(S3_BUCKET_NAME)

.PHONY: v1-create
v1-create:
	@echo "Creating version 1 stack..."
	cd $(V1_DIR) && $(MAKE) create-stack S3_PROD_BUCKET_NAME=$(S3_BUCKET_NAME) ENVIRONMENT=$(ENVIRONMENT)

.PHONY: v1-update
v1-update:
	@echo "Updating version 1 stack..."
	cd $(V1_DIR) && $(MAKE) update-stack S3_PROD_BUCKET_NAME=$(S3_BUCKET_NAME) ENVIRONMENT=$(ENVIRONMENT)

.PHONY: v1-changeset
v1-changeset:
	@echo "Creating changeset for version 1 stack..."
	cd $(V1_DIR) && $(MAKE) update-stack-with-changeset S3_PROD_BUCKET_NAME=$(S3_BUCKET_NAME) ENVIRONMENT=$(ENVIRONMENT)

.PHONY: v1-clean
v1-clean:
	@echo "Deleting version 1 stack..."
	cd $(V1_DIR) && $(MAKE) clean ENVIRONMENT=$(ENVIRONMENT)

.PHONY: v1-lint
v1-lint:
	@echo "Linting version 1 templates..."
	cd $(V1_DIR) && $(MAKE) lint

# Version 2 targets
.PHONY: v2-publish
v2-publish:
	@echo "Publishing version 2 templates..."
	cd $(V2_DIR) && $(MAKE) publish S3_PROD_BUCKET_NAME=$(S3_BUCKET_NAME)

.PHONY: v2-create
v2-create:
	@echo "Creating version 2 stack..."
	cd $(V2_DIR) && $(MAKE) create-stack S3_PROD_BUCKET_NAME=$(S3_BUCKET_NAME) ENVIRONMENT=$(ENVIRONMENT)

.PHONY: v2-update
v2-update:
	@echo "Updating version 2 stack..."
	cd $(V2_DIR) && $(MAKE) update-stack S3_PROD_BUCKET_NAME=$(S3_BUCKET_NAME) ENVIRONMENT=$(ENVIRONMENT)

.PHONY: v2-changeset
v2-changeset:
	@echo "Creating changeset for version 2 stack..."
	cd $(V2_DIR) && $(MAKE) update-stack-with-changeset S3_PROD_BUCKET_NAME=$(S3_BUCKET_NAME) ENVIRONMENT=$(ENVIRONMENT)

.PHONY: v2-clean
v2-clean:
	@echo "Deleting version 2 stack..."
	cd $(V2_DIR) && $(MAKE) clean ENVIRONMENT=$(ENVIRONMENT)

.PHONY: v2-lint
v2-lint:
	@echo "Linting version 2 templates..."
	cd $(V2_DIR) && $(MAKE) lint

# Predecessor stacks deployment
.PHONY: deploy-predecessors
deploy-predecessors:
	@echo "Deploying predecessor stacks in order..."
	@echo "Step 1: Deploying S3 stack..."
	aws cloudformation deploy \
		--template-file s3-stack.yml \
		--stack-name $(APPLICATION)-s3-stack \
		--region $(AWS_REGION) \
		--no-fail-on-empty-changeset
	@echo "Step 2: Deploying IAM role stack..."
	aws cloudformation deploy \
		--template-file iam-role.yml \
		--stack-name $(APPLICATION)-iam-role-stack \
		--region $(AWS_REGION) \
		--capabilities CAPABILITY_IAM \
		--parameter-overrides ApplicationName=$(APPLICATION) \
		--no-fail-on-empty-changeset
	@echo "Predecessor stacks deployed successfully"

# Utility targets
.PHONY: clean-all
clean-all: v1-clean v2-clean
	@echo "All stacks deleted"

.PHONY: show-config
show-config:
	@echo "Configuration:"
	@echo "  APPLICATION:     $(APPLICATION)"
	@echo "  AWS_REGION:      $(AWS_REGION)"
	@echo "  ACCOUNT_ID:      $(ACCOUNT_ID)"
	@echo "  S3_BUCKET_NAME:  $(S3_BUCKET_NAME)"
	@echo "  ENVIRONMENT:     $(ENVIRONMENT)"
	@echo "  V1_DIR:          $(V1_DIR)"
	@echo "  V2_DIR:          $(V2_DIR)"
