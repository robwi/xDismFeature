$currentPath = Split-Path -Parent $MyInvocation.MyCommand.Path
Write-Debug -Message "CurrentPath: $currentPath"

# Load Common Code
Import-Module $currentPath\..\..\xDismFeatureHelper.psm1 -Verbose:$false -ErrorAction Stop

function Get-TargetResource
{
	[CmdletBinding()]
	[OutputType([System.Collections.Hashtable])]
	param
	(
		[parameter(Mandatory = $true)]
		[System.String]
		$Name,

		[System.Boolean]
		$SuppressReboot
	)

    $DismFeatures = Get-DismFeatures

    if($DismFeatures."$Name" -eq $null)
    {
        throw New-TerminatingError -ErrorType UnknownFeature 
    }
	
    if($DismFeatures."$Name" -eq "Enabled" -or ($SuppressReboot -and ($DismFeatures."$Name" -eq "Enable Pending")))
    {
	    $returnValue = @{
		    Ensure = "Present"
		    Name = $Name
	    }
    }
    else
    {
	    $returnValue = @{
		    Ensure = "Absent"
		    Name = $Name
	    }
    }

	$returnValue
}


function Set-TargetResource
{
	[CmdletBinding()]
	param
	(
		[ValidateSet("Present","Absent")]
		[System.String]
		$Ensure = "Present",

		[parameter(Mandatory = $true)]
		[System.String]
		$Name,

		[System.Boolean]
		$SuppressReboot
	)

    switch($Ensure)
    {
        "Present"
        {
            & dism.exe /Online /Enable-Feature /FeatureName:$Name /quiet /norestart
        }
        "Absent"
        {
            & dism.exe /Online /Disable-Feature /FeatureName:$Name /quiet /norestart
        }
    }

    if(Test-Path -Path 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Component Based Servicing\RebootPending')
    {
	    if(!($SuppressReboot))
        {
            $global:DSCMachineStatus = 1
        }
        else
        {
            Write-Verbose "Suppressing reboot"
        }
    }

    if(!(Test-TargetResource @PSBoundParameters))
    {
        throw New-TerminatingError -ErrorType TestFailedAfterSet -ErrorCategory InvalidResult
    }
}


function Test-TargetResource
{
	[CmdletBinding()]
	[OutputType([System.Boolean])]
	param
	(
		[ValidateSet("Present","Absent")]
		[System.String]
		$Ensure = "Present",

		[parameter(Mandatory = $true)]
		[System.String]
		$Name,

		[System.Boolean]
		$SuppressReboot
	)

	$result = ((Get-TargetResource -Name $Name -SuppressReboot $SuppressReboot).Ensure -eq $Ensure)
	
	$result
}


function Get-DismFeatures
{
    $DismGetFeatures = & dism.exe /Online /Get-Features
    $DismFeatures = @{}
    foreach($Line in $DismGetFeatures)
    {
        switch($Line.Split(":")[0].Trim())
        {
            "Feature Name"
            {
                $FeatureName = $Line.Split(":")[1].Trim()
            }
            "State"
            {
                $DismFeatures += @{$FeatureName = $Line.Split(":")[1].Trim()}         
            }
        }
    }

    $DismFeatures
}


Export-ModuleMember -Function *-TargetResource