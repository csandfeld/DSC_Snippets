<#
Problem:
When adding multiple NIC's to a VM, there is no telling how Windows enumerates them,
and thus setting names may prove difficult.

Solution:
It does seem that we can take for granted, that the first NIC added to a Hyper-V VM, will
have the lowest mac address, the 2nd NIC will have the 2nd lowest, and so forth.

This snippet use the script resource to rename NIC's ordered by their mac addresses, giving
the first name in the config, to the NIC with the lowest mac address, and so forth.

If you know a better way to handle this, please submit a pull request :-)

Test Setup:
Windows Server 2016 Standard Evaluation
Name                           Value
----                           -----
PSVersion                      5.1.14393.0
PSEdition                      Desktop
PSCompatibleVersions           {1.0, 2.0, 3.0, 4.0...}
BuildVersion                   10.0.14393.0
CLRVersion                     4.0.30319.42000
WSManStackVersion              3.0
PSRemotingProtocolVersion      2.3
SerializationVersion           1.1.0.1

Scenario:
A Hyper-V VM with two NIC's has been configured.
1st NIC is connected to an internal switch.
2nd NIC is connected to an external switch.
We want the name of the NIC's to reflect this.
#>


$configData = @{
    AllNodes = @(
        @{
            NodeName      = 'localhost'

            NetworkConfig = @(
                # Nic 0
                @{
                    Name = 'Internal'
                }
                ,
                # Nic 1
                @{
                    Name = 'External'
                }
            )
        }
    )
}


Configuration SetNetAdapterName {

    Import-DscResource –ModuleName PSDesiredStateConfiguration

    node $AllNodes.NodeName {

        Script SetNetAdapterName {

            # Get: Must return a hashtable with at least one key named 'Result' of type String
            GetScript = {
                @{
                    # Return current list of adapter names
                    Result = [string]((Get-NetAdapter | Select-Object -ExpandProperty Name) -join ', ')
                }
            }

            # Test: Must return a boolean: $true or $false
            TestScript = {
                # Get net adapters
                $netAdapters = Get-NetAdapter | Sort-Object -Property MacAddress

                # Get nodes desired network config
                $networkConfig = $using:node.NetworkConfig

                # Get lowest count of network adapters and network config to ensure
                # we only test against adapters and configs that are there
                $count = ($netAdapters.Count, $networkConfig.Count | Measure-Object -Minimum).Minimum

                # Test for matching names
                for ($i = 0; $i -lt $count; $i++) {
                    $status = $netAdapters[$i].Name -eq $networkConfig[$i].Name

                    if ($status -eq $false) {
                       break
                    }
                }
                $status
            }

            # Set: Returns nothing
            SetScript = {
                # Get net adapters
                $netAdapters = Get-NetAdapter | Sort-Object -Property MacAddress

                # Get nodes desired network config
                $networkConfig = $using:node.NetworkConfig

                # Get lowest count of network adapters and network config to ensure
                # we only work with adapters and configs that are there
                $count = ($netAdapters.Count, $networkConfig.Count | Measure-Object -Minimum).Minimum

                # Set net adapter names
                for ($i = 0; $i -lt $count; $i++) {
                    $netAdapters[$i] | Rename-NetAdapter -NewName $networkConfig[$i].Name
                }
            }
        }
    }
}


SetNetAdapterName -ConfigurationData $configData

Start-DscConfiguration .\SetNetAdapterName -Wait -Force -Verbose
