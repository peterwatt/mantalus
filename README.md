# mantalus
Code samples for Mantalus review

# Windows Server lifecycle for customer 
 
The Windows Server lifecycle has three stages: 
 
| Product | Description | 
| --- | --- | 
| Custom AMI pipeline | The pipeline used to build custom AMIs that meet customer standards. This has been implemented using `EC2 Image Builder`.| 
| Windows EC2 instance | CloudFormation templates and `cfn-init` scripts to allow DevOps engineers to consume and extend the customer custom AMIs. | 
| Windows termination | Orchestration to tidy up enterprise resources after a Windows Server EC2 instance is terminated. | 
 
### Custom AMI pipeline
Microsoft and Amazon have jointly developed a set of [Amazon Machine Images (AMIs)](https://aws.amazon.com/windows/resources/amis/). They are well documented, optimized, and configured based on best practices. 
 
New AMIs are [released at least every 30 days](https://docs.aws.amazon.com/AWSEC2/latest/WindowsGuide/windows-ami-version-history.html) with new security patches and enhancements. Our strategy is to push these new releases out into all of the AWS accounts that need Windows Servers, without delay. To allow this, we needed to develop a CI/CD pipeline for Windows Server images to allow us to incorporate customer specific agents and configuration settings. This has been developed using [EC2 Image Builder](https://aws.amazon.com/image-builder/). 
 
EC2 Image Builder was [announced at re:Invent on 1 December 2019](https://aws.amazon.com/about-aws/whats-new/2019/12/introducing-ec2-image-builder/). This product uses *Systems Manager Automation* to orchestrate the custom AMI build pipeline. It is being used because it: 
* consumes AWS cloud native value-added service

* implements a detailed orchestration framework, written and maintained by AWS 
* writes comprehensive logs
* allows multiple versions
* supports both Linux and Windows 
* comes with AWS supported build and test components 
* is fully extendible with customer build and test components 
* removes the need to use Docker, CodeBuild, and CodePipeline 
* provides extensive error handling, rollback and cleanup steps 
* integrates with *AWS Resource Access Manager* and *AWS Organizations* to enable sharing of automation scripts, recipes, and images across AWS accounts. 
* reduces customer code burden by at least 50% 
 
> Note: this orchestration was previously implemented using CodePipeline.
 
### Windows EC2 instance

The customer custom AMIs contain PowerShell scripts that need to execute on first boot. CloudFormation templates are provided that use `cfn-init` to orchestrate and sequence the first boot activities. 
  
### Windows termination
 
This product consists of: 
 
 1. A CloudWatch rule *EC2Termination* that fires when an EC2 instance is terminated and runs a Lambda function.

 2. A Lambda function *retrieveHostname* that gets the *hostname* tag from the terminated instance, adds it to the JSON event payload, and writes it to a SNS topic. 
 3. A listener on a Windows EC2 instance that takes workloads off the SQS queue and actions them.  
