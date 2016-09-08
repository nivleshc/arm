configuration CreateADFirstDC 
{ 
   <#v1.4
   ChangeLog
   Date       Author    Comments
   05/09/16   Nivlesh   Changed the DNS entries that will be added, so that its only for the ADFS LB.
   #>
   param 
   ( 
        [Parameter(Mandatory)]
        [String]$DomainName,

        [Parameter(Mandatory)]
        [System.Management.Automation.PSCredential]$Admincreds,

        [Parameter(Mandatory)]
        [string]$adfsLBip,

        [Parameter(Mandatory)]
        [System.Management.Automation.PSCredential]$AdfsSvcCreds,

        [Int]$RetryCount=20,
        [Int]$RetryIntervalSec=30
    ) 
    
    Import-DscResource -ModuleName xActiveDirectory, xNetworking, xPendingReboot
    [System.Management.Automation.PSCredential ]$DomainCreds = New-Object System.Management.Automation.PSCredential ("${DomainName}\$($Admincreds.UserName)", $Admincreds.Password)

    Node localhost
    {
        LocalConfigurationManager            
        {            
            ActionAfterReboot = 'ContinueConfiguration'            
            ConfigurationMode = 'ApplyOnly'            
            RebootNodeIfNeeded = $true            
        } 

        WindowsFeature DNS 
        { 
            Ensure = "Present" 
            Name = "DNS"
        }

        xDnsServerAddress DnsServerAddress 
        { 
            Address        = '127.0.0.1' 
            InterfaceAlias = 'Ethernet'
            AddressFamily  = 'IPv4'
            DependsOn = "[WindowsFeature]DNS"
        }

        WindowsFeature RSAT
        {
            Ensure = "Present"
            Name = "RSAT"
        }

        WindowsFeature ADDSInstall 
        { 
            Ensure = "Present" 
            Name = "AD-Domain-Services"
        }  

        xADDomain FirstDC 
        {
            DomainName = $DomainName
            DomainAdministratorCredential = $DomainCreds
            SafemodeAdministratorPassword = $DomainCreds
            DatabasePath = "C:\NTDS"
            LogPath = "C:\NTDS"
            SysvolPath = "C:\SYSVOL"
            DependsOn = "[WindowsFeature]ADDSInstall","[xDnsServerAddress]DnsServerAddress"
        }

        xWaitForADDomain DscForestWait
        {
            DomainName = $DomainName
            DomainUserCredential = $DomainCreds
            RetryCount = $RetryCount
            RetryIntervalSec = $RetryIntervalSec
            DependsOn = "[xADDomain]FirstDC"
        } 

        xADUser CreateADFSServiceAccount 
        { 
            DomainName = $DomainName 
            DomainAdministratorCredential = $DomainCreds 
            UserName = $ADFSSvcCreds.UserName 
            Password = $ADFSSvcCreds 
            Ensure = "Present" 
            DependsOn = "[xWaitForADDomain]DscForestWait" 
        } 

        xPendingReboot Reboot1
        { 
            Name = "RebootServer"
            DependsOn = "[xWaitForADDomain]DscForestWait"
        }

         Script addDNSRecords  #Add ADFS Server DNS Records
        {
            GetScript = { @{Result = {Get-DNSServerResourceRecord -Zone nivlab.thecloudguy.info -Name fs}}}
            SetScript = {
                #add the following records to DNS
                Add-DNSServerResourceRecord -Zonename $using:DomainName -ComputerName DC01 -IPv4Address $using:adfsLBip -Name fs -A

                #Query the DNS Entry and output to dns.txt to signal that DNS has been added
                Get-DNSServerResourceRecord -Zone $using:DomainName -Name fs > "C:\Packages\dns.txt"
            }

            #check if the ADFS DNS Records have been output to file. If yes then nothing to do
            TestScript = { Test-Path "C:\Packages\dns.txt" }
            DependsOn = "[xADUser]CreateADFSServiceAccount"
        }

   }
} 