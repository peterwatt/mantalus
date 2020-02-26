### Import environment variables
#include $(config)

define HELP_TEXT
Usage: make [TARGET]...
!!IMPORTANT!! before running make [TARGET], please make sure you are running suitable role in correct AWS account...
Available targets:
endef
export HELP_TEXT

help: ## This help
	@echo "$$HELP_TEXT"
	@awk 'BEGIN {FS = ":.*?## "} /^[a-zA-Z_-]+:.*?## / \
		{printf "\033[36m%-30s\033[0m  %s\n", $$1, $$2}' $(MAKEFILE_LIST)

### Requires aws-cli/1.16.312

Version=0.5.12
Component=arn:aws:imagebuilder:ap-southeast-2:90561999999:component/install-components/$(Version)/1
Recipe1=arn:aws:imagebuilder:ap-southeast-2:905619499999:image-recipe/windows-2016-server-custom-ami/$(Version)
Recipe2=arn:aws:imagebuilder:ap-southeast-2:905619999999:image-recipe/windows-2016-server-sql-custom-ami/$(Version)
Recipe3=arn:aws:imagebuilder:ap-southeast-2:9056194999999:image-recipe/windows-2019-server-custom-ami/$(Version)
Recipe4=arn:aws:imagebuilder:ap-southeast-2:90561949999:image-recipe/windows-2019-server-sql-custom-ami/$(Version)
Tag1=Windows_Server-2016-English-Full-Base
Tag2=Windows_Server-2016-English-Full-SQL_2019_Standard
Tag3=Windows_Server-2019-English-Full-Base
Tag4=Windows_Server-2019-English-Full-SQL_2019_Standard

cleanup: ## Tear down all components
	aws imagebuilder list-image-pipelines \
		--query imagePipelineList[].[arn] --output text \
		| xargs -I {} aws imagebuilder delete-image-pipeline --image-pipeline-arn {}
	
	aws imagebuilder list-infrastructure-configurations \
		--query infrastructureConfigurationSummaryList[].[arn] --output text \
		| xargs -I {} aws imagebuilder delete-infrastructure-configuration --infrastructure-configuration-arn {}	

	aws imagebuilder list-distribution-configurations \
		--query distributionConfigurationSummaryList[].[arn] --output text \
		| xargs -I {} aws imagebuilder delete-distribution-configuration --distribution-configuration-arn {}

	aws imagebuilder list-image-recipes \
		--query imageRecipeSummaryList[].[arn] --output text \
		| xargs -I {} aws imagebuilder delete-image-recipe --image-recipe-arn {}

	aws imagebuilder list-components \
		--owner Self \
		--query componentVersionList[].[arn] --output text \
		| xargs -I {} aws imagebuilder list-component-build-versions --component-version-arn {} \
		--query componentSummaryList[].[arn] --output text \
		| xargs -I {} aws imagebuilder delete-component --component-build-version-arn {}

	aws imagebuilder list-images \
		--owner Self \
		--query imageVersionList[].[arn] --output text \
		| xargs -I {} aws imagebuilder list-image-build-versions --image-version-arn {} \
		--query imageSummaryList[].[arn] --output text \
		| xargs -I {} aws imagebuilder delete-image --image-build-version-arn {}

	rm -f instances
	rm -f tags
	rm -f images
	rm -f x
	rm -f y
	rm -f z

prepare: ## Insert web proxy into AWS AMIs, needs to be run each time there are new AWS AMIs

	#aws ec2 describe-images --owners amazon --filters "Name=name,Values=Windows_Server-2016-English-Full*" --query 'sort_by(Images, &CreationDate)[].Name'

## Create instances from each AWS AMI that is required
	rm -f instances
	rm -f images

	aws ec2 run-instances \
		--image-id $$(aws ssm get-parameters --names /aws/service/ami-windows-latest/Windows_Server-2016-English-Full-Base --region ap-southeast-2 --query Parameters[].[Value] --output text) \
		--count 1 \
		--instance-type m5.large \
		--user-data file://InstanceUserData \
		--subnet-id subnet-0cc15b2ee9e51fa6a \
		--key-name PeterPacker \
		--iam-instance-profile Name=ImageBuilderInstanceProfile \
		--tag-specifications 'ResourceType=instance,Tags=[{Key=Name,Value=$(Tag1)}]' \
		--query Instances[].[InstanceId] \
		--output text \
		| xargs echo >> instances

	aws ec2 run-instances \
		--image-id $$(aws ssm get-parameters --names /aws/service/ami-windows-latest/Windows_Server-2016-English-Full-SQL_2019_Standard --region ap-southeast-2 --query Parameters[].[Value] --output text) \
		--count 1 \
		--instance-type m5.large \
		--user-data file://InstanceUserData \
		--subnet-id subnet-0cc15b2ee9e51fa6a \
		--key-name PeterPacker \
		--iam-instance-profile Name=ImageBuilderInstanceProfile \
		--tag-specifications 'ResourceType=instance,Tags=[{Key=Name,Value=$(Tag2)}]' \
		--query Instances[].[InstanceId] \
		--output text \
		| xargs echo >> instances 
		
	aws ec2 run-instances \
		--image-id $$(aws ssm get-parameters --names /aws/service/ami-windows-latest/Windows_Server-2019-English-Full-Base --region ap-southeast-2 --query Parameters[].[Value] --output text) \
		--count 1 \
		--instance-type m5.large \
		--user-data file://InstanceUserData \
		--subnet-id subnet-0cc15b2ee9e51fa6a \
		--key-name PeterPacker \
		--iam-instance-profile Name=ImageBuilderInstanceProfile \
		--tag-specifications 'ResourceType=instance,Tags=[{Key=Name,Value=$(Tag3)}]' \
		--query Instances[].[InstanceId] \
		--output text \
		| xargs echo >> instances

	aws ec2 run-instances \
		--image-id $$(aws ssm get-parameters --names /aws/service/ami-windows-latest/Windows_Server-2019-English-Full-SQL_2019_Standard --region ap-southeast-2 --query Parameters[].[Value] --output text) \
		--count 1 \
		--instance-type m5.large \
		--user-data file://InstanceUserData \
		--subnet-id subnet-0cc15b2ee9e51fa6a \
		--key-name PeterPacker \
		--iam-instance-profile Name=ImageBuilderInstanceProfile \
		--tag-specifications 'ResourceType=instance,Tags=[{Key=Name,Value=$(Tag4)}]' \
		--query Instances[].[InstanceId] \
		--output text \
		| xargs echo >> instances

	cat instances | tr "\n" ' ' | xargs -t aws ec2 wait instance-status-ok --instance-ids

	cat instances | tr "\n" ' ' | xargs -t aws ec2 stop-instances --instance-ids

	cat instances | tr "\n" ' ' | xargs -t aws ec2 wait instance-stopped --instance-ids

## Create images from the instances
	sed '1!d' instances | xargs -I % -t aws ec2 create-image --instance-id % --name $(Tag1)-with-web-proxy --query [ImageId] --output text | xargs echo >> images
	sed '2!d' instances | xargs -I % -t aws ec2 create-image --instance-id % --name $(Tag2)-with-web-proxy --query [ImageId] --output text | xargs echo >> images
	sed '3!d' instances | xargs -I % -t aws ec2 create-image --instance-id % --name $(Tag3)-with-web-proxy --query [ImageId] --output text | xargs echo >> images
	sed '4!d' instances | xargs -I % -t aws ec2 create-image --instance-id % --name $(Tag4)-with-web-proxy --query [ImageId] --output text | xargs echo >> images

	cat images | tr "\n" ' ' | xargs -t aws ec2 wait image-available --image-ids

## Terminate the working instances

#	cat instances | tr "\n" ' ' | xargs -t aws ec2 terminate-instances --instance-ids
#	cat instances | tr "\n" ' ' | xargs -t aws ec2 wait instance-terminated --instance-ids

## Update SSM Parameter store with image ids

	sed '1!d' images | xargs -I % -t aws ssm put-parameter --name $(Tag1)-with-web-proxy --type String --overwrite --value %
	sed '2!d' images | xargs -I % -t aws ssm put-parameter --name $(Tag2)-with-web-proxy --type String --overwrite --value %
	sed '3!d' images | xargs -I % -t aws ssm put-parameter --name $(Tag3)-with-web-proxy --type String --overwrite --value %
	sed '4!d' images | xargs -I % -t aws ssm put-parameter --name $(Tag4)-with-web-proxy --type String --overwrite --value %

role: ## Create instance profile, only needs to be run once

## Create EC2 instance profile
	aws iam create-instance-profile \
		--instance-profile-name ImageBuilderInstanceProfile \
		--no-verify-ssl
	aws iam add-role-to-instance-profile \
		--instance-profile-name ImageBuilderInstanceProfile \
		--role-name Role_ImageBuilder_Full \
		--no-verify-ssl

env: ## Create build environment, only needs to be run once

## Create infrastucture configuration
	
	if [ ! -f x ]; then echo 0 > x; fi
	if [ ! -f y ]; then echo 0 > y; fi
	if [ ! -f z ]; then echo 0 > z; fi
	echo `cat x`"."`cat y`"."`cat z`

	aws imagebuilder create-infrastructure-configuration \
		--name "Windows 2016 Server custom AMI for CustomerX" \
		--description "Infrastructure Configuration used to build Windows 2016 Server custom AMIs for CustomerX" \
		--instance-profile-name ImageBuilderInstanceProfile \
		--subnet-id subnet-0cc15b2ee9e51fa6a \
		--security-group-ids sg-0da0eae6376f6f41f \
		--key-pair PeterPacker \
		--no-terminate-instance-on-failure \
		--sns-topic-arn arn:aws:sns:ap-southeast-2:99999999999:PeterTest2 \
		--logging s3Logs={s3BucketName=cf-imagebuilder}

## Create distribution configuration
	aws imagebuilder create-distribution-configuration \
		--name "Windows 2016 Server distribution" \
		--description "Distribution Configuration for Windows 2016 Server custom AMIs for customerX" \
		--distributions []

incrx:

	expr `cat x` + 1 > x
	echo 0 > y
	echo 0 > z
	echo `cat x`"."`cat y`"."`cat z`

incry:

	expr `cat y` + 1 > y
	echo 0 > z

	echo `cat x`"."`cat y`"."`cat z`

fix: ## Repair broken component

	aws imagebuilder create-image-pipeline \
		--name "Windows 2016 Server custom AMI for CustomerX" \
		--description "This pipeline builds a Windows Server custom AMI" \
		--image-recipe-arn $(Recipe) \
		--infrastructure-configuration-arn arn:aws:imagebuilder:ap-southeast-2:99999999999:infrastructure-configuration/windows-2016-server-custom-ami-for- \
		--distribution-configuration-arn arn:aws:imagebuilder:ap-southeast-2:99999999999:distribution-configuration/windows-2016-server-distribution

fixtwo: ## Fix issue

	aws imagebuilder list-image-pipelines --query imagePipelineList[].[arn] --output text  | grep -q arn:aws:imagebuilder:ap-southeast-2:99999999999:image-pipeline/windows-2016-server-custom-ami-for-; \
	if [ $$? -ne 0 ]; \
	then \
	aws imagebuilder create-image-pipeline \
		--name "Windows 2016 Server custom AMI for CustomerX" \
		--description "This pipeline builds a Windows Server custom AMI" \
		--image-recipe-arn $(Recipe) \
		--infrastructure-configuration-arn arn:aws:imagebuilder:ap-southeast-2:99999999999:infrastructure-configuration/windows-2016-server-custom-ami-for- \
		--distribution-configuration-arn arn:aws:imagebuilder:ap-southeast-2:99999999999:distribution-configuration/windows-2016-server-distribution; \
	fi

fixthree: ## Fix issue

	aws ec2 run-instances \
		--image-id $$(aws ssm get-parameters --names /aws/service/ami-windows-latest/Windows_Server-2016-English-Full-Base --region ap-southeast-2 --query Parameters[].[Value] --output text) \
		--count 1 \
		--instance-type m4.large \
		--user-data file://InstanceUserData \
		--subnet-id subnet-0cc15b2ee9e51fa6a \
		--query Instances[].[InstanceId] \
		--output text | xargs echo >> it
	
		#aws ec2 run-instances \
		--image-id $$(aws ssm get-parameters --names /aws/service/ami-windows-latest/Windows_Server-2016-English-Full-Base --region ap-southeast-2 --query Parameters[].[Value] --output text) \
		--count 1 \
		--instance-type m4.large \
		--user-data file://InstanceUserData \
		--subnet-id subnet-0cc15b2ee9e51fa6a \
		--query Instances[].[InstanceId] \
		--output text | printenv
		# \
		#| xargs -I {} aws ec2 wait instance-status-ok --instance-ids {}
	
build: ## Modify and run build pipeline, needs to be run each time a base AMI, component, or recipe changes

	expr `cat z` + 1 > z
	rm -f imagebuilds

## Copy latest build document to S3
	aws s3 cp InstallComponents.yml s3://customerxS3/windows/Software/ami-prod/InstallComponents.yaml
	
## Create new version of customerX build component
	aws imagebuilder create-component \
		--name "Install Components" \
		--semantic-version $(Version) \
		--description "This build component installs packages required for each Windows Server custom AMI" \
		--change-description "Description of the change" \
		--platform Windows \
		--uri "s3://-ondemand/windows/Software/ami-prod/InstaComponents.yaml" \
		--query componentBuildVersionArn \
		--output text

## Create four new versions of image recipes
	aws imagebuilder create-image-recipe \
		--name "Windows 2016 Server custom AMI" \
		--semantic-version $(Version) \
		--components componentArn=$(Component) \
		             componentArn=arn:aws:imagebuilder:ap-southeast-2:aws:component/simple-boot-test-windows/1.0.0 \
					 componentArn=arn:aws:imagebuilder:ap-southeast-2:aws:component/reboot-test-windows/1.0.0 \
					 componentArn=arn:aws:imagebuilder:ap-southeast-2:aws:component/windows-is-ready-with-password-generation-test/1.0.0 \
					 componentArn=arn:aws:imagebuilder:ap-southeast-2:aws:component/ec2-network-route-test-windows/1.0.0 \
		--parent-image $$(aws ssm get-parameters --names $(Tag1)-with-web-proxy --region ap-southeast-2 --query Parameters[].[Value] --output text)

	aws imagebuilder create-image-recipe \
		--name "Windows 2016 Server SQL custom AMI" \
		--semantic-version $(Version) \
		--components componentArn=$(Component) \
		             componentArn=arn:aws:imagebuilder:ap-southeast-2:aws:component/simple-boot-test-windows/1.0.0 \
					 componentArn=arn:aws:imagebuilder:ap-southeast-2:aws:component/reboot-test-windows/1.0.0 \
					 componentArn=arn:aws:imagebuilder:ap-southeast-2:aws:component/windows-is-ready-with-password-generation-test/1.0.0 \
					 componentArn=arn:aws:imagebuilder:ap-southeast-2:aws:component/ec2-network-route-test-windows/1.0.0 \
		--parent-image $$(aws ssm get-parameters --names $(Tag2)-with-web-proxy --region ap-southeast-2 --query Parameters[].[Value] --output text)

	aws imagebuilder create-image-recipe \
		--name "Windows 2019 Server custom AMI" \
		--semantic-version $(Version) \
		--components componentArn=$(Component) \
		             componentArn=arn:aws:imagebuilder:ap-southeast-2:aws:component/simple-boot-test-windows/1.0.0 \
					 componentArn=arn:aws:imagebuilder:ap-southeast-2:aws:component/reboot-test-windows/1.0.0 \
					 componentArn=arn:aws:imagebuilder:ap-southeast-2:aws:component/windows-is-ready-with-password-generation-test/1.0.0 \
					 componentArn=arn:aws:imagebuilder:ap-southeast-2:aws:component/ec2-network-route-test-windows/1.0.0 \
		--parent-image $$(aws ssm get-parameters --names $(Tag3)-with-web-proxy --region ap-southeast-2 --query Parameters[].[Value] --output text)

	aws imagebuilder create-image-recipe \
		--name "Windows 2019 Server SQL custom AMI" \
		--semantic-version $(Version) \
		--components componentArn=$(Component) \
		             componentArn=arn:aws:imagebuilder:ap-southeast-2:aws:component/simple-boot-test-windows/1.0.0 \
					 componentArn=arn:aws:imagebuilder:ap-southeast-2:aws:component/reboot-test-windows/1.0.0 \
					 componentArn=arn:aws:imagebuilder:ap-southeast-2:aws:component/windows-is-ready-with-password-generation-test/1.0.0 \
					 componentArn=arn:aws:imagebuilder:ap-southeast-2:aws:component/ec2-network-route-test-windows/1.0.0 \
		--parent-image $$(aws ssm get-parameters --names $(Tag4)-with-web-proxy --region ap-southeast-2 --query Parameters[].[Value] --output text)

## Create image pipelines (first time thru only)

	aws imagebuilder list-image-pipelines --query imagePipelineList[].[arn] --output text  | grep -q arn:aws:imagebuilder:ap-southeast-2:99999999999:image-pipeline/windows-2016-server-custom-ami-for-; \
	if [ $$? -ne 0 ]; \
	then \
	aws imagebuilder create-image-pipeline \
		--name "Windows 2016 Server custom AMI" \
		--description "This pipeline builds a Windows
    Server
    custom AMI" \
		--image-recipe-arn $(Recipe1) \
		--infrastructure-configuration-arn arn:aws:imagebuilder:ap-southeast-2:99999999999:infrastructure-configuration/windows-2016-server-custom-ami-for- \
		--distribution-configuration-arn arn:aws:imagebuilder:ap-southeast-2:99999999999:distribution-configuration/windows-2016-server-distribution; \
	fi

	aws imagebuilder list-image-pipelines --query imagePipelineList[].[arn] --output text  | grep -q arn:aws:imagebuilder:ap-southeast-2:99999999999:image-pipeline/windows-2016-server-sql-custom-ami-for-; \
	if [ $$? -ne 0 ]; \
	then \
	aws imagebuilder create-image-pipeline \
		--name "Windows 2016 Server SQL custom AMI" \
		--description "This pipeline builds a Windows Server custom AMI" \
		--image-recipe-arn $(Recipe2) \
		--infrastructure-configuration-arn arn:aws:imagebuilder:ap-southeast-2:99999999999:infrastructure-configuration/windows-2016-server-custom-ami-for- \
		--distribution-configuration-arn arn:aws:imagebuilder:ap-southeast-2:99999999999:distribution-configuration/windows-2016-server-distribution; \
	fi

	aws imagebuilder list-image-pipelines --query imagePipelineList[].[arn] --output text  | grep -q arn:aws:imagebuilder:ap-southeast-2:99999999999:image-pipeline/windows-2019-server-custom-ami-for-; \
	if [ $$? -ne 0 ]; \
	then \
	aws imagebuilder create-image-pipeline \
		--name "Windows 2019 Server custom AMI" \
		--description "This pipeline builds an Windows Server custom AMI" \
		--image-recipe-arn $(Recipe3) \
		--infrastructure-configuration-arn arn:aws:imagebuilder:ap-southeast-2:99999999999:infrastructure-configuration/windows-2016-server-custom-ami-for- \
		--distribution-configuration-arn arn:aws:imagebuilder:ap-southeast-2:99999999999:distribution-configuration/windows-2016-server-distribution; \
	fi

	aws imagebuilder list-image-pipelines --query imagePipelineList[].[arn] --output text  | grep -q arn:aws:imagebuilder:ap-southeast-2:99999999999:image-pipeline/windows-2019-server-sql-custom-ami-for-; \
	if [ $$? -ne 0 ]; \
	then \
	aws imagebuilder create-image-pipeline \
		--name "Windows 2019 Server SQL custom AMI" \
		--description "This pipeline builds a Windows Server custom AMI" \
		--image-recipe-arn $(Recipe4) \
		--infrastructure-configuration-arn arn:aws:imagebuilder:ap-southeast-2:99999999999:infrastructure-configuration/windows-2016-server-custom-ami-for- \
		--distribution-configuration-arn arn:aws:imagebuilder:ap-southeast-2:99999999999:distribution-configuration/windows-2016-server-distribution; \
	fi

## Update image pipelines with the new recipes

	aws imagebuilder update-image-pipeline \
		--image-pipeline-arn arn:aws:imagebuilder:ap-southeast-2:99999999999:image-pipeline/windows-2016-server-custom-ami-for- \
		--image-recipe-arn $(Recipe1) \
		--infrastructure-configuration-arn arn:aws:imagebuilder:ap-southeast-2:99999999999:infrastructure-configuration/windows-2016-server-custom-ami-for-

	aws imagebuilder update-image-pipeline \
		--image-pipeline-arn arn:aws:imagebuilder:ap-southeast-2:99999999999:image-pipeline/windows-2016-server-sql-custom-ami-for- \
		--image-recipe-arn $(Recipe2) \
		--infrastructure-configuration-arn arn:aws:imagebuilder:ap-southeast-2:99999999999:infrastructure-configuration/windows-2016-server-custom-ami-for-

	aws imagebuilder update-image-pipeline \
		--image-pipeline-arn arn:aws:imagebuilder:ap-southeast-2:99999999999:image-pipeline/windows-2019-server-custom-ami-for- \
		--image-recipe-arn $(Recipe3) \
		--infrastructure-configuration-arn arn:aws:imagebuilder:ap-southeast-2:99999999999:infrastructure-configuration/windows-2016-server-custom-ami-for-

	aws imagebuilder update-image-pipeline \
		--image-pipeline-arn arn:aws:imagebuilder:ap-southeast-2:99999999999:image-pipeline/windows-2019-server-sql-custom-ami-for- \
		--image-recipe-arn $(Recipe4) \
		--infrastructure-configuration-arn arn:aws:imagebuilder:ap-southeast-2:99999999999:infrastructure-configuration/windows-2016-server-custom-ami-for-

## Update distribution configuration with current values
	aws imagebuilder update-distribution-configuration \
		--distribution-configuration-arn arn:aws:imagebuilder:ap-southeast-2:99999999999:distribution-configuration/windows-2016-server-distribution \
		--distributions []

## Run image pipelines fof all four Operating System versions
	aws imagebuilder start-image-pipeline-execution \
		--image-pipeline-arn arn:aws:imagebuilder:ap-southeast-2:99999999999:image-pipeline/windows-2016-server-custom-ami-for- \
		--query [imageBuildVersionArn] \
		--output text \
		| xargs echo >> imagebuilds

	aws imagebuilder start-image-pipeline-execution \
		--image-pipeline-arn arn:aws:imagebuilder:ap-southeast-2:99999999999:image-pipeline/windows-2016-server-sql-custom-ami-for- \
		--query [imageBuildVersionArn] \
		--output text \
		| xargs echo >> imagebuilds

	aws imagebuilder start-image-pipeline-execution \
		--image-pipeline-arn arn:aws:imagebuilder:ap-southeast-2:99999999999:image-pipeline/windows-2019-server-custom-ami-for- \
		--query [imageBuildVersionArn] \
		--output text \
		| xargs echo >> imagebuilds

	aws imagebuilder start-image-pipeline-execution \
		--image-pipeline-arn arn:aws:imagebuilder:ap-southeast-2:99999999999:image-pipeline/windows-2019-server-sql-custom-ami-for- \
		--query [imageBuildVersionArn] \
		--output text \
		| xargs echo >> imagebuilds

publish:

	sed '1!d' imagebuilds
	# | xargs -I % -t aws ssm put-parameter --name $(Tag1)-with-web-proxy --type String --overwrite --value %
#	sed '2!d' imagenuildss | xargs -I % -t aws ssm put-parameter --name $(Tag2)-with-web-proxy --type String --overwrite --value %
#	sed '3!d' images | xargs -I % -t aws ssm put-parameter --name $(Tag3)-with-web-proxy --type String --overwrite --value %
#	sed '4!d' images | xargs -I %
