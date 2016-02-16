#*******************************************************************
# Global Variables
#*******************************************************************
$Script:Version      = '1.0.0.1'
$Script:LogSeparator = '*******************************************************************************'
$Script:LogFile      = ""

#*******************************************************************
# Functions
#*******************************************************************
function Get-ScriptName(){
#
#    .SYNOPSIS
#        Extracts the script name
#    .DESCRIPTION
#        Extracts the script file name without extention
#    .NOTES
#        Author:    Dinh Tran, dinhtmore@gmail.com
#
    $tmp = $MyInvocation.ScriptName.Substring($MyInvocation.ScriptName.LastIndexOf('\') + 1)
    $tmp.Substring(0,$tmp.Length - 4)
}

function Write-Log($Msg, [System.Boolean]$LogTime=$true){
#
#    .SYNOPSIS
#        Creates a log entry
#    .DESCRIPTION
#        By default a time stamp will be logged too. This can be
#        disabled with the -LogTime $false parameter
#    .NOTES
#        Author:    Dinh Tran, dinhtmore@gmail.com
#    .EXAMPLE
#        Write-Log -Msg 'Log entry created successfull.' [-LogTime $false]
#
    if($LogTime){
        $date = Get-Date -format dd.MM.yyyy
        $time = Get-Date -format HH:mm:ss
       Add-Content -Path $LogFile -Value ($date + " " + $time + "   " + $Msg)
    }
    else{
        Add-Content -Path $LogFile -Value $Msg
    }
}

function Initialize-LogFile($File, [System.Boolean]$reset=$false){
#
#    .SYNOPSIS
#        Initializes the log file
#    .DESCRIPTION
#        Creates the log file header
#        Creates the folder structure on local drives if necessary
#        Resets existing log if used with -reset $true
#    .NOTES
#        Author:    Dinh Tran, dinhtmore@gmail.com
#    .EXAMPLE
#        Initialize-LogFile -File 'C:\Logging\events.log' [-reset $true]
#
try{
        #Check if file exists
        if(Test-Path -Path $File){
            #Check if file should be reset
            if($reset){
                Clear-Content $File -ErrorAction SilentlyContinue
            }
        }
        else{
            #Check if file is a local file
            if($File.Substring(1,1) -eq ':'){
                #Check if drive exists
                $driveInfo = [System.IO.DriveInfo]($File)
                if($driveInfo.IsReady -eq $false){
                    Write-Log -Msg ($driveInfo.Name + " not ready.")
                }

                #Create folder structure if necessary
                $Dir = [System.IO.Path]::GetDirectoryName($File)
                if(([System.IO.Directory]::Exists($Dir)) -eq $false){
                    $objDir = [System.IO.Directory]::CreateDirectory($Dir)
                    Write-Log -Msg ($Dir + " created.")
                }
            }
        }
        #Write header
        Write-Log -LogTime $false -Msg $LogSeparator
        Write-Log -LogTime $false -Msg (((Get-ScriptName).PadRight($LogSeparator.Length - ("   Version " + $Version).Length," ")) + "   Version " + $Version)
        Write-Log -LogTime $false -Msg $LogSeparator
    }
    catch{
        Write-Log -Msg $_
    }
}

function Read-Arguments($Values = $args) {
#
#    .SYNOPSIS
#        Reads named script arguments
#    .DESCRIPTION
#        Reads named script arguments separated by '=' and tagged with'-' character
#    .NOTES
#        Author:    Dinh Tran, dinhtmore@gmail.com
#
    foreach($value in $Values){

        #Change the character that separates the arguments here
        $arrTmp = $value.Split("=")

        switch ($arrTmp[0].ToLower()) {
            -log {
                $Script:LogFile = $arrTmp[1]
            }
        }
    }
}

#*******************************************************************
# Main Script
#*******************************************************************
if($args.Count -ne 0){
    #Read script arguments
    Read-Arguments
    if($LogFile.StartsWith("\\")){
        Write-Host "UNC"
    }
    elseif($LogFile.Substring(1,1) -eq ":"){
        Write-Host "Local"
    }
    else{
        $LogFile = [System.IO.Path]::Combine((Get-Location), $LogFile)
    }

    if($LogFile.EndsWith(".log") -eq $false){
        $LogFile += ".log"
    }
}

if($LogFile -eq ""){
    #Set log file
    $LogFile = [System.IO.Path]::Combine((Get-Location), (Get-ScriptName) + ".log")
}

#Write log header
Initialize-LogFile -File $LogFile -reset $false



#///////////////////////////////////
#/// Enter your script code here ///
#///////////////////////////////////
param($debug=$false, $wafonly=$false)
add-azureaccount
$subscriptions = Get-AzureSubscription | %{ $_.SubscriptionName} | sort
$i=0
$subscriptions | %{"[{0}]`t{1}" -f $i, $($subscriptions[$i]); $i++}

######
## Selecting your source VM to copy endpoints from
######
if($debug){
    $subscriptionname = "SourceSubscription"
}
else{
    $subscriptionname  = $subscriptions | sort | out-gridview -passthru -title "select source subscription" #| clip
}

Set-AzureSubscription -SubscriptionName $subscriptionname
Select-AzureSubscription -SubscriptionName $subscriptionname

$services = Get-AzureService | %{$_.ServiceName} | sort

if($debug){
    $servicename = "SourceServiceName1"
}
else {
    $servicename = $services |  out-gridview -passthru -title "select source service" # | clip
}
echo $servicename

if($debug){
    $vmname = "SourceVM"
}
else{
    if($wafonly){
        $vmname = Read-Host -prompt "these VMs are options"
    }
    else{
        $vmname = get-azurevm -servicename $servicename | sort | out-gridview -passthru -title "select source vm"
    }
}
write-host $vmname -f Yellow

$vm = Get-AzureVm -ServiceName $servicename -Name $vmname.Name
$endpoints = Get-Azureendpoint -VM $vm

######
## For humans to view these endpoints easily:
######
$date = get-date -f "yyyy-MM-dd"
$tableoutput = "$($vmname.Name)`_endpoints`_$($date).txt"
write-host "$tableoutput " -f red
$endpointlogs = gci . | sort name | ?{$_.Name -match "$($vmname.Name)`_endpoints"}
if($endpointlogs.Count -gt 5){ $endpointlogs | sort LastWriteTime -desc | select -last | remove-item }
ni $tableoutput -force -ItemType File
$endpoints | %{write-output "`r`n LB Name: $($_.LBSetName) `r`n Port: $($_.LocalPort) `r`n VIP: $($_.VIP)"; $_.acl | ft}  | out-file $tableoutput;
cat $tableoutput

#$endpoints > "$vmname.txt"
#$endpoints.ACLs >> "$vmname.txt"




######
## Selecting your target VM to transfer endpoints to
######
if($debug){
    $Targetsubscriptionname = "Targetsubscriptionname"
}
else{
    $Targetsubscriptionname  = $subscriptions | sort | out-gridview -passthru -title "select Target subscription" #| clip
}

## set the shell to target sub
Set-AzureSubscription -SubscriptionName $Targetsubscriptionname
Select-AzureSubscription -SubscriptionName $Targetsubscriptionname
$targetservices = Get-AzureService | %{$_.ServiceName} | sort

## set target service name
if($debug){
    $targetservicename = "TargetWebService1"
}
else {
    $targetservicename = $targetservices | sort | out-gridview -passthru -title "select a target service" # | clip
}

echo $targetservicename
if($debug){
    $targetvmname = "TargetVM"
}
else{
    if($wafonly){
        $targetvmname = Read-Host -prompt "These vms are possible options"
    }
    else{
        $targetvmname = get-azurevm -servicename $targetservicename | sort | out-gridview -passthru -title "select target vm"
    }
}
write-host $targetvmname -f Yellow

#####
## Creating the powershell to add the endpoints to another VM
#####

$wafAdd = "$($vmname.Name)`_TransferEndpointsTo`_$($targetvmname.Name)`_$($date).ps1" ; ni $wafAdd -force -itemType File

"Add-AzureAccount
Set-AzureSubscription -SubscriptionName `"$($Targetsubscriptionname)`"
Select-AzureSubscription -SubscriptionName `"$($Targetsubscriptionname)`"
"| out-file $wafAdd -append
"####  get the azure vm ####" | out-file $wafAdd -append
"`$targetvm = Get-AzureVM -ServiceName `"$($targetservicename)`" -Name `"$($targetvmname.Name)`"" | out-file $wafAdd -append
## get each endpoint from AP
foreach($endpoint in $endpoints){
    $i = 0; $acls = $endpoint.acl
    $name = $endpoint.LBSetName  ## will be the same as name and lbsetname
    "`$$($name -replace '-| ','')Newacl = New-AzureAclConfig" | out-file $wafAdd -append
    $vip = $endpoint.VIP
    $localport = $endpoint.LocalPort
#    $publicport = $endpoint.PublicPort
    write-host "~~~~~~~~~~~~"
    foreach($acl in $acls){
        $RemoteSubnet = $acl.RemoteSubnet
        $description = $acl.Description
        $order  = $acl.Order
        "Set-AzureAclConfig -AddRule -ACL `$$($name -replace '-| ','')Newacl -Order $($order) -Action Permit -RemoteSubnet `"$($RemoteSubnet)`" -Description `"$($description)`"" | out-file $wafAdd -append
        $i++
    }
    write-host "~~~~~~~~~~~~"
    ## add this endpoint info to BP
    "Add-AzureEndpoint -VM `$targetvm -Name `"$($name)`" -LBSetName `"$($name)`" -ACL `"($name -replace '-| ','')Newacl`" -Protocol TCP -LocalPort $($localport) -DefaultProbe" | out-file $wafAdd -append
}
    "`$targetvm | Update-AzureVM" | out-file $wafAdd -append


#Write log footer
Write-Log -LogTime $false -Msg $LogSeparator
Write-Log -LogTime $false -Msg ''


