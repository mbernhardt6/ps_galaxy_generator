#Variables
$numSystems = 20
$minDistOrigin = 3
$maxDistOrigin = 10
$minDistSystem = 2.5
$maxDistSystem = 5
$maxDistLink = 4.5
$xOrigin = 10
$yOrigin = 10

#Data Structures
$System = @()

#Functions
Function CalculateDistance([int]$x1, [int]$y1, [int]$x2, [int]$y2)
	{
	$Distance = ([Math]::Sqrt(([Math]::Pow($x1 - $x2, 2)) + ([Math]::Pow($y1 - $y2, 2))))
	return $Distance
	}

Function CalculateLocalTable([int]$x)
	{
	$LocalLinks = @()
	Foreach ($y in 0 .. ($numSystems - 1))
		{
		If ($x -ne $y)
			{
			$LinkDist = (CalculateDistance $System[$x][0] $System[$x][1] $System[$y][0] $System[$y][1])
			If ($LinkDist -lt $maxDistLink)
				{
				#Own System, Destination, Distance, Interface
				$LocalLinks += ,($x,$y,$LinkDist,$y)
				}
			}
		}
	return $LocalLinks
	}
	
Function CollectNeighborTables ([int]$local, [int]$neigh, [int]$LID)
	{
	#$TempTable is the local table, accessed via Global Variable
	$Table = @()
	$NeighborTable = (Get-Variable -Name "RoutingTable$neigh" -ErrorAction SilentlyContinue).Value
	
	#Translate NeighborTable Values
	If ($NeighborTable -ne $null)
		{
		Foreach ($Link in $NeighborTable)
			{
			If ($Link[1] -ne $local)
				{
				$Table += ,($local, $Link[1], ($Link[2] + $TempTable[$LID][2]), $TempTable[$LID][3])
				}
			}
		}
	return $Table
	Remove-Variable Table
	}
	
	
#Build Map
Write-Host "Generating Map..."
Foreach ($x in 0 .. ($numSystems - 1))
	{
	#"Start System " + $x
	$ValidSystem1 = $false
	$try = 0
	While (!$ValidSystem1)
		{
		If ($try -gt 100)
			{
			"Unable to generate map."
			"Failed on " + $x
			return
			}
		
		$TestX = (Get-Random -Maximum ($xOrigin * 2))
		$TestY = (Get-Random -Maximum ($yOrigin * 2))
		
		$DistToOrigin = (CalculateDistance $TestX $TestY $xOrigin $yOrigin)
		
		#"Distance to Origin: " + $DistToOrigin
		
		If ($DistToOrigin -gt $minDistOrigin)
			{
			If ($DistToOrigin -lt $maxDistOrigin)
				{
				If ($x -eq 0)
					{
					$System += ,($TestX,$TestY)
					break
					}
				
				$ValidSystem2 = $true
				$ValidSystem3 = $false
				Foreach ($y in 0 .. ($x - 1))
					{
					$DistanceToSystem = (CalculateDistance $TestX $TestY $System[$y][0] $System[$y][1])
					
					#"Distance To System " + $y + ": " + $DistanceToSystem
					
					If ($DistanceToSystem -lt $maxDistSystem)
						{
						$ValidSystem3 = $true
						}
					
					If ($DistanceToSystem -lt $minDistSystem)
						{
						$ValidSystem2 = $false
						$try++
						break
						}
					}
				If ($ValidSystem2 -and $ValidSystem3)
					{
					$ValidSystem1 = $true
					$System += ,($TestX,$TestY)
					#"System " + $x + " accepted."
					}
				}
			}
		}
	}
#/Build Map


#Draw Map
Foreach ($y in 0 .. ($yOrigin * 2))
	{
	Foreach ($x in 0 .. ($xOrigin * 2))
		{
		$Empty = $true
		Foreach ($z in 0 .. ($numSystems - 1))
			{
			If ($System[$z][0] -eq $x)
				{
				If ($System[$z][1] -eq $y)
					{
					$z1 = "{0:D2}" -f $z
					Write-Host "$z1 " -NoNewline
					$Empty = $false
					}
				}
			}
		If ($x -eq $xOrigin -and $y -eq $yOrigin)
			{
			Write-Host " . " -NoNewline
			}
		ElseIf ($Empty)
			{
			Write-Host "   " -NoNewline
			}
		}
	Write-Host ""
	}
#/Draw Map


#Build Routing Tables
Write-Host "Building Routing Tables..."
#Start by building all local tables
Foreach ($x in 0 .. ($numSystems - 1))
	{
	Set-Variable -Name "RoutingTable$x" -Value @(CalculateLocalTable $x)
	}

#Cycle through all systems until all tables are complete
While ($CompleteTables -ne $true)
	{
	$CompleteTables = $true
	#Cycle through each system
	Foreach ($x in 0 .. ($numSystems - 1))
		{
		$WorkingTable = @()
		#Clear routing table to build everything from scratch
		Remove-Variable "RoutingTable$x" -ErrorAction SilentlyContinue
		#Set routing table variable in order to have it register as Array
		Set-Variable -Name "RoutingTable$x" -Value @()
		#Generate Working Set
		$WorkingTable = @(CalculateLocalTable $x)
		#Generate looping set
		$TempTable = @(CalculateLocalTable $x)
		Foreach ($n in 0 .. ($TempTable.Count - 1))
			{
			#Collect the routing table from each neighbor link by link
			$WorkingTable += @(CollectNeighborTables $x $TempTable[$n][3] $n)
			}
		#Sort the Working by link length in order to use the shortest for each system
		$WorkingTable = @($WorkingTable | Sort-Object @{Expression={$_[2]}})
		Foreach ($y in 0 .. ($numSystems - 1))
			{
			If ($x -ne $y)
				{
				Foreach ($Link in $WorkingTable)
					{
					If ($Link[1] -eq $y)
						{
						#Iterative loops to grap the first link for each system then break the loop
						Set-Variable -Name "RoutingTable$x" -Value ((Get-Variable -Name "RoutingTable$x").Value += ,$Link)
						break
						}
					}
				}
			}
		#Clean up variables to avoid cross contaminating future loops
		Remove-Variable Link
		Remove-Variable WorkingTable
		Remove-Variable TempTable
		#Sort Routing Table for ease of reading
		Set-Variable -Name "RoutingTable$x" -Value ((Get-Variable -Name "RoutingTable$x").Value | Sort-Object @{Expression={$_[1]}})
		#Check for Complete Tables
		If ((Get-Variable -Name "RoutingTable$x").Value.Count -ne ($numSystems - 1))
			{
			$CompleteTables = $false
			}
		}
	}
#/Build Routing Tables


#Output Routing Tables
Foreach ($Var in (Get-Variable | Where {$_.Name -like "RoutingTable*"}))
	{
	$Var.Name
	Foreach ($x in 0 .. ($Var.Value.Count - 1))
		{
		"System: " + $Var.Value[$x][1] + "  Distance: " + $Var.Value[$x][2] + " Interface: " + $Var.Value[$x][3]
		}
	""
	}
#/Output Routing Tables