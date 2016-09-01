 <#ConfigureADFS.ps1
 Version 0.1
 Description: This Custom Script Extension will configure ADFS. It assumes ADFS Role has already been installed
 Changelog
 Date         Author           Comments
 01/09/16     Nivlesh          Initial Version (0.1)
 #>
 param (
    $DomainName,
    $DomainAdminUsername,
    $AdfsSvcUsername
 )

 #the domain admin and adfs service passwords are encrypted and stored in a local folder
 $localpath = "C:\Program Files\WindowsPowerShell\Modules\Certificates\"
 $Key = (3,4,2,3,56,34,254,222,1,1,2,23,42,54,33,233,1,34,2,7,6,5,35,43)

 #lets get the passwords and decrypt them

 #get the admin and adfs passwords first
 $adminpassword = Convertto-SecureString -String (Get-Content -Path $($localpath+"adminpass.key")) -key $key
              
 $adfspassword = Convertto-SecureString -String (Get-Content -Path $($localpath+"adfspass.key")) -key $key
               
 $DomainAdminCreds = New-Object System.Management.Automation.PSCredential($($DomainName+"\"+$DomainAdminUsername), $adminpassword)

 $AdfsSvcCreds = New-Object System.Management.Automation.PSCredential($($DomainName+"\"+$AdfsSvcUsername), $adfspassword)
            
 #install the certificate that will be used for ADFS Service
 Import-PfxCertificate -Exportable -Password $adminpassword -CertStoreLocation cert:\localmachine\my -FilePath $($localpath+"fs.nivlab.thecloudguy.info_full.pfx")
            
 #get thumbprint of certificate
 $cert = Get-ChildItem -Path Cert:\LocalMachine\my | ?{$_.Subject -eq "CN=fs.nivlab.thecloudguy.info, OU=Free SSL, OU=Domain Control Validated"} 


 #Configure ADFS
 Import-Module ADFS
 
 Install-AdfsFarm -CertificateThumbprint $cert.thumbprint -Credential $DomainAdminCreds `
 -FederationServiceName fs.nivlab.thecloudguy.info -FederationServiceDisplayName "Nivlab Federation Service" `
 -ServiceAccountCredential $AdfsSvcCreds -OverwriteConfiguration
