<#
    The Get-GraphServicePrincipal function reworks work on service principals which was published by Justin Grote at
        https://github.com/JustinGrote/JustinGrote.Microsoft.Graph.Extensions/blob/main/src/Public/Get-MgO365ServicePrincipal.ps1
        https://github.com/JustinGrote/JustinGrote.Microsoft.Graph.Extensions/blob/main/src/Public/Get-MgManagedIdentity.ps1  and
        https://github.com/JustinGrote/JustinGrote.Microsoft.Graph.Extensions/blob/main/src/Public/Get-MgAppRole.ps1

    and licensed by him under the same MIT terms which apply to this module (see the LICENSE file for details)

    Portions of this file are Copyright 2021 Justin Grote @justinwgrote

    The remainder is Copyright 2018-2021 James O'Neill
#>

function Get-GraphServicePrincipal {
    <#
        .Description
            A replacement for the SDK's Get-MgServicePrincipal
            That has orderby which doesn't work - the it's in the Docs but the API errors if you try
            It doesn't have search my name, or select managedIDs or Applications.
    #>
    [OutputType([Microsoft.Graph.PowerShell.Models.MicrosoftGraphAppRole],ParameterSetName='AllRoles')]
    [OutputType([Microsoft.Graph.PowerShell.Models.MicrosoftGraphAppRole],ParameterSetName='FilteredRoles')]
    [OutputType([Microsoft.Graph.PowerShell.Models.MicrosoftGraphServicePrincipal])]
    [CmdletBinding(DefaultParameterSetName='List1')]
    param   (
        [Parameter(ParameterSetName='AllRoles',       Mandatory=$true, Position=0)]
        [Parameter(ParameterSetName='FilteredRoles',  Mandatory=$true, Position=0)]
        [Parameter(ParameterSetName='AllScopes',      Mandatory=$true, Position=0)]
        [Parameter(ParameterSetName='FilteredScopes', Mandatory=$true, Position=0)]
        [Parameter(ParameterSetName='Get2',           Mandatory=$true, Position=0)]
        # key: id of servicePrincipal
        [String[]]$ServicePrincipalId,

        [Parameter(ParameterSetName='List2')]
        [switch]$ManagedIdentity,

        [Parameter(ParameterSetName='List3')]
        [switch]$Application,

        [Parameter(ParameterSetName='List4')]
        [switch]$O365ServicePrincipals,

        # Select properties to be returned
        [Alias('Select')]
        [String[]]$Property,

        # Filter items by property values
        [Parameter(ParameterSetName='List1')]
        [String]$Filter,

        # Search items by search phrases
        [Parameter(ParameterSetName='List1')]
        [Parameter(ParameterSetName='List2')]
        [Parameter(ParameterSetName='List3')]
        [String]$Search,

        [Parameter(ParameterSetName='AllRoles', Mandatory=$true)]
        [switch]$ExpandAppRoles,

        [Parameter(ParameterSetName='FilteredRoles', Mandatory=$true)]
        [string]$AppRoleFilter,

        [Parameter(ParameterSetName='AllScopes', Mandatory=$true)]
        [switch]$ExpandScopes,

        [Parameter(ParameterSetName='FilteredScopes', Mandatory=$true)]
        [string]$ScopeFilter
    )
    begin   {
        [String]$managedIdentityFilter = @(
            '00000001-0000-0000-c000-000000000000' #Azure ESTS Service
            '00000007-0000-0000-c000-000000000000' #Common Data Service
            '0000000c-0000-0000-c000-000000000000' #Microsoft App Access Panel'
            '00000007-0000-0ff1-ce00-000000000000' #Microsoft Exchange Online Protection
            '00000003-0000-0000-c000-000000000000' #Microsoft Graph
            '00000006-0000-0ff1-ce00-000000000000' #Microsoft Office 365 Portal
            '00000012-0000-0000-c000-000000000000' #Microsoft Rights Management Services
            '00000008-0000-0000-c000-000000000000' #Microsoft.Azure.DataMarket
            '00000002-0000-0ff1-ce00-000000000000' #Office 365 Exchange Online
            '00000003-0000-0ff1-ce00-000000000000' #Office 365 SharePoint Online
            '00000009-0000-0000-c000-000000000000' #Power BI Service
            '00000004-0000-0ff1-ce00-000000000000' #Skype for Business Online
            '00000002-0000-0000-c000-000000000000' #Windows Azure Active Directory
        ).foreach{"appId eq '$PSItem'"} -join ' or '
    }
    process {
        if (-not $ServicePrincipalId) {
            if ($PSBoundParameters['Filter'] -and  $O365ServicePrincipals) {
                $PSBoundParameters['Filter'] ="( $($PSBoundParameters['Filter']) ) and $managedIdentityFilter"
            }
            elseif ($O365ServicePrincipals) {
                $PSBoundParameters['Filter'] =  $managedIdentityFilter
            }
            elseif ($ManagedIdentity) {
                $psboundParameters['Filter']="servicePrincipaltype eq 'ManagedIdentity'"
            }
            elseif ($Application) {
                $psboundParameters['Filter']="servicePrincipaltype eq 'Application'"
            }
            foreach ($param in @('Application', 'ManagedIdentity', 'O365ServicePrincipals')) {
                [void]$PSBoundParameters.Remove($param )
            }
            Microsoft.Graph.Applications.private\Get-MgServicePrincipal_List1 @PSBoundParameters -all -ConsistencyLevel Eventual | Sort-Object displayname
        }
        else {
            foreach ($param in @('ServicePrincipalId', 'ExpandAppRoles', 'ExpandScopes', 'AppRoleFilter', 'ScopeFilter')) {
                [void]$PSBoundParameters.Remove($param )
            }
            foreach    ($sp in $ServicePrincipalId) {
                if     ($sp -match $GUIDRegex) {
                      $result = Microsoft.Graph.Applications.private\Get-MgServicePrincipal_Get2 -ServicePrincipalId $sp @PSBoundParameters
                }
                else   {
                      [void]$PSBoundParameters.Remove('ServicePrincipalId')
                      $psboundParameters['Filter']="startswith(displayName,'$sp')"
                      $result = Microsoft.Graph.Applications.private\Get-MgServicePrincipal_List1 @PSBoundParameters -ConsistencyLevel Eventual | Sort-Object displayname
                }
                if     ($AppRoleFilter)  {
                      $result | Select-Object -ExpandProperty approles |
                                    Where-Object {$_.id -like $AppRoleFilter  -or $_.DisplayName -like $AppRoleFilter -or $_.value -like $AppRoleFilter } |
                                        Sort-Object -Property Value
                }
                elseif ($ExpandAppRoles) {
                      $result | Select-Object -ExpandProperty approles | Sort-Object -Property Value
                }
                elseif     ($ScopeFilter)  {
                      $result | Select-Object -ExpandProperty Oauth2PermissionScopes |
                                    Where-Object {$_.id -like $ScopeFilter  -or $_.AdminConsentDisplayName -like $ScopeFilter -or $_.value -like $ScopeFilter } |
                                        Sort-Object -Property Value
                }
                elseif ($ExpandScopes) {
                      $result | Select-Object -ExpandProperty Oauth2PermissionScopes | Sort-Object -Property Value
                }
                else {$result}
            }
        }
    }
}