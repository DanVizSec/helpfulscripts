param (
	[Parameter(Mandatory=$true)][System.Net.IPAddress]$start,
	[Parameter(Mandatory=$true)][System.Net.IPAddress]$end,
	[Parameter(Mandatory=$true)][int[]]$ports=@()
)

function IPToInt {
	<#
		Convert a IPv4 System.Net.IPAddress object to a integer representation
	#>
	param(
		[Parameter(Mandatory=$true)]$addr
	)
	$ip = $addr.GetAddressBytes()

	$rslt = 0
	for ($i=0; $i -lt $ip.length; $i++) {
		$rslt += $ip[$i] * [math]::pow(256, 3 - $i)
	}
	$rslt
}

function IntToIP {
	<#
		Convert an IPV4 integer notation to a string dotted decimal
	#>
	param(
		[Parameter(Mandatory=$true)]$addr
	)
	$addr = [UInt32]$addr
	$DottedIP = $( 
		For ($i = 3; $i -gt -1; $i--) {
			$Remainder = $addr % [Math]::Pow(256, $i)
			($addr - $Remainder) / [Math]::Pow(256, $i)
			$addr = $Remainder
        } 
	)
	[String]::Join('.', $DottedIP)
}
 
function IPRange {
	<#
		Construct an array of integers from a start to an end integer
	#>
	param(
		[Parameter(Mandatory=$true)]$ip1,
		[Parameter(Mandatory=$true)]$ip2
	)
	$iplist = @()
	for ($x=(IPToInt $ip1); $x -le (IPToInt $ip2); $x++) {
		$iplist += (IntToIP $x)
	}
	$iplist
}

$iparray = IPRange $start $end

foreach ($ip in $iparray)
{
	if(Test-Connection -BufferSize 32 -Count 1 -Quiet -ComputerName $ip)
	{
		foreach ($p in $ports)
		{	Try{
				$socket = new-object System.Net.Sockets.TcpClient($ip, $p)
				If($socket.Connected)
				{
					
					Write-Output "$ip listening to port $p"
					$socket.Close() 
				}
			}
			Catch{}
		}
	}
}