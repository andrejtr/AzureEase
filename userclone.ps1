[CmdletBinding()]
param(
    [Parameter(Mandatory=$true)]
    [string]$SourceUserAccount,

    [Parameter(Mandatory=$true)]
    [string]$TargetUserAccount,

    [Parameter(Mandatory=$true)]
    [string]$AdminUPN
)

# Connect to Azure AD
$credential = Get-Credential -UserName $AdminUPN -Message "Enter your Office 365 or Exchange Online administrator credentials"
Connect-AzureAD -Credential $credential

# Get the Source and Target users
$SourceUser = Get-AzureADUser -Filter "UserPrincipalName eq '$SourceUserAccount'"
$TargetUser = Get-AzureADUser -Filter "UserPrincipalName eq '$TargetUserAccount'"

# Check if source and Target users are valid
If($SourceUser -ne $Null -and $TargetUser -ne $Null)
{
    # Get All memberships of the Source user
    $SourceMemberships = Get-AzureADUserMembership -ObjectId $SourceUser.ObjectId | Where-object { $_.ObjectType -eq "Group" }

    # Loop through Each Group
    ForEach($Membership in $SourceMemberships)
    {
        # Check if the user is not part of the group
        $GroupMembers = (Get-AzureADGroupMember -ObjectId $Membership.ObjectId).UserPrincipalName
        If ($GroupMembers -notcontains $TargetUserAccount)
        {
            # Add Target user to the Source User's group
            Add-AzureADGroupMember -ObjectId $Membership.ObjectId -RefObjectId $TargetUser.ObjectId
            Write-Output "Added user to Group: $($Membership.DisplayName)"
        }
    }

    # Connect to Exchange Online PowerShell
    $UserCredential = Get-Credential -UserName $AdminUPN -Message "Enter your Office 365 or Exchange Online administrator credentials"
    $ExchangeSession = New-PSSession -ConfigurationName Microsoft.Exchange -ConnectionUri https://outlook.office365.com/powershell-liveid/ -Credential $UserCredential -Authentication Basic -AllowRedirection
    Import-PSSession $ExchangeSession -AllowClobber

    # Get the mail-enabled security groups for the source user
    $securityGroups = Get-DistributionGroup -RecipientTypeDetails SecurityEnabled -Member $SourceUser.UserPrincipalName

    # Add the security groups to the destination user
    foreach ($group in $securityGroups) {
        Add-DistributionGroupMember -Identity $group.Name -Member $TargetUser.UserPrincipalName
        Write-Output "Added user to Security Group: $($group.Name)"
    }

    # Disconnect from Exchange Online PowerShell
    Remove-PSSession $ExchangeSession
}
Else
{
    Write-Warning "Source or Target user is invalid!"
}
