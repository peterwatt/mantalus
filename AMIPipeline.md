# AMI pipeline for Windows Servers

The image pipeline is implemented using EC2 Image Builder in account  `customer-os-ondemand-services-mgmt`, account number `999999999999`.

## Component *Install customer Components*

1. Copies all source materials to C:\customer\Software on the target machine. Source materials for the SOE are kept in *s3://customer-ondemand/windows/Software/ami-prod.*

2. Installs *VCRuntime140_x86.exe* and *VCRuntime140_x64.exe*.
3. Installs the FlexNet Inventory agent.
4. Installs the PowerShell Active Directory module.
5. Installs the Microsoft Local Administrator Password Solution (LAPS).
6. Installs Symantec Endpoint Protection.
7. Installs a Splunk agent.
8. Sets the timezone to region *ap-southeast-2*.

## Recipe *Windows 2016 Server custom AMI for customer*

1. Runs build component *Install customer Components*.

2. Runs AWS-provided test components.

## Image pipeline *Pipeline070*

1. Implements recipe *Windows 2016 Server custom AMI for customer*.

> EC2 Image Builder does not at this time support configuring a web proxy. Therefore, it is first necessary to take the AWS AMIs and inject the Web Proxy with this userdata:

```
bitsadmin /util /setieproxy localsystem MANUAL_PROXY "10.123.123.123:8080" "169.254.169.254"
setx /m HTTP_PROXY http://10.123.123.123:8080
setx /m HTTPS_PROXY http://10.123.123.123:8080
setx /m NO_PROXY 169.254.169.254
```

> An AMI is then created using the *Create Image* function, and the resulting AMI is fed thru the image pipeline.

## Supported AMIs

* Windows_Server-2016-English-Full-Base
* Windows_Server-2016-English-Full-SQL_2016_SP2_Standard
* Windows_Server-2019-English-Full-Base
* Windows_Server-2019-English-Full-SQL_2019_Standard

