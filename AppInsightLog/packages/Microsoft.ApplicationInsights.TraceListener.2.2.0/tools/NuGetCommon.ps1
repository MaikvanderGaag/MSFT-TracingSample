# Common logic for NuGet installation scripts

[System.Reflection.Assembly]::LoadWithPartialName("System.Windows.Forms") 

function ReportError
{
Param(
  [string]$message
 )
	throw $message
}

function ReportInfo([string] $message, [string] $caption)
{
	Write-Host $message -background yellow

	[System.Windows.Forms.MessageBox]::Show($message, $caption)
}

function ReportApplicationInsightsConfigNotFound()
{
	ReportInfo "Add Application Insights to your project to send log data to the Application Insights portal." "Can’t find ApplicationInsights.config"
}

function GetOrCreateElement
{
	Param(
 		[System.Xml.Linq.XContainer] $container,
 		[System.Xml.Linq.XName] $name)
        
	$element = $container.Element($name)
	if (!$element)
	{
		$element = New-Object -TypeName System.Xml.Linq.XElement -ArgumentList $name
    	$container.Add($element)
	}

	return $element
}

function ValidateProject
{
	Param([Object]$project)
	
	if(!$project)
	{
		ReportError "The Application Insights logging adapter package can’t determine the project you want to apply it to."
	}
}

function GetAIConfigPath
{
	Param([Object] $project)
	
	$aiConfigProjectItem = $project.ProjectItems | where {$_.Name -eq "ApplicationInsights.config"}

	$aiConfigPath = $aiConfigProjectItem.Properties | where {$_.Name -eq "LocalPath"}
	
	if(!$aiConfigPath)
	{
		throw "Can’t find ApplicationInsights.config. Add Application Insights to your project and retry."
	}

	return $aiConfigPath.Value
}

function GetWebConfigPath
{
	Param([object] $project)
	
	$webConfigProjectItem = $project.ProjectItems | where {$_.Name -eq "Web.config"}

	$webConfigPath = $webConfigProjectItem.Properties | where {$_.Name -eq "LocalPath"}

	if(!$webConfigPath)
	{
		throw "Can't find Web.config. Make sure you are targetting an appropriate project type."
	}
	
	return $webConfigPath.Value
}

function LoadXml
{
	Param([string] $filePath)
	
	$fileStream = New-Object -TypeName System.IO.FileStream -ArgumentList $filePath, "Open", "Read"
	
	try
	{
		$xml = [System.Xml.Linq.XElement]::Load($fileStream, "None");	#PreserveWhitespace
	}
	catch
	{
		ReportError "Couldn't load XML from " + $filePath + " " + $_
		return
	}
	finally
	{
		if($fileStream)
		{
			$fileStream.Dispose()
		}
	}
	
	return $xml
}

function GetInstrumentationKey
{
	Param([Object] $aiConfigPath)
	
	$xml = LoadXml $aiConfigPath
	
	$xmlns = [System.Xml.Linq.XNamespace]::Get("http://schemas.microsoft.com/ApplicationInsights/2013/Settings")
	$instrumentationKeyElement = $xml.Element($xmlns + "InstrumentationKey")

	if(!$instrumentationKeyElement)
	{
		ReportError "Can’t find the InstrumentationKey element in ApplicationInsights.config. Create an Application Insights resource in Microsoft Azure, then get a key from the Quick Start tile."
		return
	}

	return $instrumentationKeyElement.Value
}

function DoesAIConfigExist([Object] $project)
{
	$aiConfigProjectItem = $project.ProjectItems | where {$_.Name -eq "ApplicationInsights.config"}

	if(!$aiConfigProjectItem)
	{
		return $false
	}

	return $true
}

function CreateAttribute
{
	Param([String] $name, [Object] $value)
	
	return New-Object -TypeName System.Xml.Linq.XAttribute -ArgumentList $name, $value
}

function LoadWebConfig
{
	Param([Object] $project)
	
	$webConfigPath = GetWebConfigPath $project
	
	return LoadXml $webConfigPath
}

function SaveWebConfig
{
	Param([Object] $project, [Object] $xml)
	
	$filePath = GetWebConfigPath $project
	
	try
	{
		$xml.Save($filePath, "None");	#"DisableFormatting"
	}
	catch
	{
		ReportError "Couldn't write changes to web.config. Make sure that web.config is not open in Visual Studio and try again. " + $_
		return
	}
}

function RemoveIfNoChildren([System.Xml.Linq.XElement] $element)
{
	if([bool]$element.HasElements -eq $false)
	{
		$element.Remove()
	}
}
# SIG # Begin signature block
# MIIaqgYJKoZIhvcNAQcCoIIamzCCGpcCAQExCzAJBgUrDgMCGgUAMGkGCisGAQQB
# gjcCAQSgWzBZMDQGCisGAQQBgjcCAR4wJgIDAQAABBAfzDtgWUsITrck0sYpfvNR
# AgEAAgEAAgEAAgEAAgEAMCEwCQYFKw4DAhoFAAQUorE+1qtaMPZyEcF9l07yA46+
# UT6gghWDMIIEwzCCA6ugAwIBAgITMwAAALWsfW2HayYRRwAAAAAAtTANBgkqhkiG
# 9w0BAQUFADB3MQswCQYDVQQGEwJVUzETMBEGA1UECBMKV2FzaGluZ3RvbjEQMA4G
# A1UEBxMHUmVkbW9uZDEeMBwGA1UEChMVTWljcm9zb2Z0IENvcnBvcmF0aW9uMSEw
# HwYDVQQDExhNaWNyb3NvZnQgVGltZS1TdGFtcCBQQ0EwHhcNMTYwOTA3MTc1ODQ0
# WhcNMTgwOTA3MTc1ODQ0WjCBszELMAkGA1UEBhMCVVMxEzARBgNVBAgTCldhc2hp
# bmd0b24xEDAOBgNVBAcTB1JlZG1vbmQxHjAcBgNVBAoTFU1pY3Jvc29mdCBDb3Jw
# b3JhdGlvbjENMAsGA1UECxMETU9QUjEnMCUGA1UECxMebkNpcGhlciBEU0UgRVNO
# OkI4RUMtMzBBNC03MTQ0MSUwIwYDVQQDExxNaWNyb3NvZnQgVGltZS1TdGFtcCBT
# ZXJ2aWNlMIIBIjANBgkqhkiG9w0BAQEFAAOCAQ8AMIIBCgKCAQEApXwz2j7k2rDl
# 2QO9eyz1qUm3FyqD7dksbP5M3NCOq/j95vpOeHG2w0S1SyNmN8VEqjiHSeopO5b+
# VbOIbpqqG9PyfyDc0WdzIilufZOuwyZI15hI3uRgZ78E/cbljXUW5Me75jGGEOlr
# Gek41eOyGRUxkejFapqkiHCLxHSMHEpPdT95ylPhuLz7Bq01fsQSbclDoQye3EzO
# YFlqcFMYb3s61siEbpvKgf0qcQjPzAh3vsySXqzeeLc3Kzss74E9HDduQGO1ZZTZ
# FadL4bzwlgVhux25DZr0zqybZIBiy8/J9oyKCi2OuWLqxf+YgSWp0YMY9ktvKwGr
# VW7W8/UJVwIDAQABo4IBCTCCAQUwHQYDVR0OBBYEFIMd6iA083bzGHST2k2O6R6l
# XnyFMB8GA1UdIwQYMBaAFCM0+NlSRnAK7UD7dvuzK7DDNbMPMFQGA1UdHwRNMEsw
# SaBHoEWGQ2h0dHA6Ly9jcmwubWljcm9zb2Z0LmNvbS9wa2kvY3JsL3Byb2R1Y3Rz
# L01pY3Jvc29mdFRpbWVTdGFtcFBDQS5jcmwwWAYIKwYBBQUHAQEETDBKMEgGCCsG
# AQUFBzAChjxodHRwOi8vd3d3Lm1pY3Jvc29mdC5jb20vcGtpL2NlcnRzL01pY3Jv
# c29mdFRpbWVTdGFtcFBDQS5jcnQwEwYDVR0lBAwwCgYIKwYBBQUHAwgwDQYJKoZI
# hvcNAQEFBQADggEBAAez+vxJWgDsgMtouMLKUcbt+zRbXcxWm2HmTU7rhIVVyh2E
# IFS5ebVknSGsKoR1/xlEmnMo3fHtvWaDRo/2qXIg1jMnOQp1d4wqFh9hKfnDeCQA
# 9tCnM8C/mYu3axXxKmyxJXDOm2MqcoZ9CBlmk96o/hzV9QWo5c+Y94j7qEYpGRPG
# 6Adqoc/HNxnce3Ik0ZlpbD8TbmbIjDORxQ3Jjbn3AGXBQ+smsInwWFzut2EwpGPC
# 2xWhLjXLdzJReIM1geh3oM/wti4zZ4w7hr4CvedMnU29OkcnoyMEUAQnZfB7PsXm
# adKxnklsJCsr1UOu7g/nwX5/mcw7R9G3RSvrI0EwggTtMIID1aADAgECAhMzAAAB
# QJap7nBW/swHAAEAAAFAMA0GCSqGSIb3DQEBBQUAMHkxCzAJBgNVBAYTAlVTMRMw
# EQYDVQQIEwpXYXNoaW5ndG9uMRAwDgYDVQQHEwdSZWRtb25kMR4wHAYDVQQKExVN
# aWNyb3NvZnQgQ29ycG9yYXRpb24xIzAhBgNVBAMTGk1pY3Jvc29mdCBDb2RlIFNp
# Z25pbmcgUENBMB4XDTE2MDgxODIwMTcxN1oXDTE3MTEwMjIwMTcxN1owgYMxCzAJ
# BgNVBAYTAlVTMRMwEQYDVQQIEwpXYXNoaW5ndG9uMRAwDgYDVQQHEwdSZWRtb25k
# MR4wHAYDVQQKExVNaWNyb3NvZnQgQ29ycG9yYXRpb24xDTALBgNVBAsTBE1PUFIx
# HjAcBgNVBAMTFU1pY3Jvc29mdCBDb3Jwb3JhdGlvbjCCASIwDQYJKoZIhvcNAQEB
# BQADggEPADCCAQoCggEBANtLi+kDal/IG10KBTnk1Q6S0MThi+ikDQUZWMA81ynd
# ibdobkuffryavVSGOanxODUW5h2s+65r3Akw77ge32z4SppVl0jII4mzWSc0vZUx
# R5wPzkA1Mjf+6fNPpBqks3m8gJs/JJjE0W/Vf+dDjeTc8tLmrmbtBDohlKZX3APb
# LMYb/ys5qF2/Vf7dSd9UBZSrM9+kfTGmTb1WzxYxaD+Eaxxt8+7VMIruZRuetwgc
# KX6TvfJ9QnY4ItR7fPS4uXGew5T0goY1gqZ0vQIz+lSGhaMlvqqJXuI5XyZBmBre
# ueZGhXi7UTICR+zk+R+9BFF15hKbduuFlxQiCqET92ECAwEAAaOCAWEwggFdMBMG
# A1UdJQQMMAoGCCsGAQUFBwMDMB0GA1UdDgQWBBSc5ehtgleuNyTe6l6pxF+QHc7Z
# ezBSBgNVHREESzBJpEcwRTENMAsGA1UECxMETU9QUjE0MDIGA1UEBRMrMjI5ODAz
# K2Y3ODViMWMwLTVkOWYtNDMxNi04ZDZhLTc0YWU2NDJkZGUxYzAfBgNVHSMEGDAW
# gBTLEejK0rQWWAHJNy4zFha5TJoKHzBWBgNVHR8ETzBNMEugSaBHhkVodHRwOi8v
# Y3JsLm1pY3Jvc29mdC5jb20vcGtpL2NybC9wcm9kdWN0cy9NaWNDb2RTaWdQQ0Ff
# MDgtMzEtMjAxMC5jcmwwWgYIKwYBBQUHAQEETjBMMEoGCCsGAQUFBzAChj5odHRw
# Oi8vd3d3Lm1pY3Jvc29mdC5jb20vcGtpL2NlcnRzL01pY0NvZFNpZ1BDQV8wOC0z
# MS0yMDEwLmNydDANBgkqhkiG9w0BAQUFAAOCAQEAa+RW49cTHSBA+W3p3k7bXR7G
# bCaj9+UJgAz/V+G01Nn5XEjhBn/CpFS4lnr1jcmDEwxxv/j8uy7MFXPzAGtOJar0
# xApylFKfd00pkygIMRbZ3250q8ToThWxmQVEThpJSSysee6/hU+EbkfvvtjSi0lp
# DimD9aW9oxshraKlPpAgnPWfEj16WXVk79qjhYQyEgICamR3AaY5mLPuoihJbKwk
# Mig+qItmLPsC2IMvI5KR91dl/6TV6VEIlPbW/cDVwCBF/UNJT3nuZBl/YE7ixMpT
# Th/7WpENW80kg3xz6MlCdxJfMSbJsM5TimFU98KNcpnxxbYdfqqQhAQ6l3mtYDCC
# BbwwggOkoAMCAQICCmEzJhoAAAAAADEwDQYJKoZIhvcNAQEFBQAwXzETMBEGCgmS
# JomT8ixkARkWA2NvbTEZMBcGCgmSJomT8ixkARkWCW1pY3Jvc29mdDEtMCsGA1UE
# AxMkTWljcm9zb2Z0IFJvb3QgQ2VydGlmaWNhdGUgQXV0aG9yaXR5MB4XDTEwMDgz
# MTIyMTkzMloXDTIwMDgzMTIyMjkzMloweTELMAkGA1UEBhMCVVMxEzARBgNVBAgT
# Cldhc2hpbmd0b24xEDAOBgNVBAcTB1JlZG1vbmQxHjAcBgNVBAoTFU1pY3Jvc29m
# dCBDb3Jwb3JhdGlvbjEjMCEGA1UEAxMaTWljcm9zb2Z0IENvZGUgU2lnbmluZyBQ
# Q0EwggEiMA0GCSqGSIb3DQEBAQUAA4IBDwAwggEKAoIBAQCycllcGTBkvx2aYCAg
# Qpl2U2w+G9ZvzMvx6mv+lxYQ4N86dIMaty+gMuz/3sJCTiPVcgDbNVcKicquIEn0
# 8GisTUuNpb15S3GbRwfa/SXfnXWIz6pzRH/XgdvzvfI2pMlcRdyvrT3gKGiXGqel
# cnNW8ReU5P01lHKg1nZfHndFg4U4FtBzWwW6Z1KNpbJpL9oZC/6SdCnidi9U3RQw
# WfjSjWL9y8lfRjFQuScT5EAwz3IpECgixzdOPaAyPZDNoTgGhVxOVoIoKgUyt0vX
# T2Pn0i1i8UU956wIAPZGoZ7RW4wmU+h6qkryRs83PDietHdcpReejcsRj1Y8wawJ
# XwPTAgMBAAGjggFeMIIBWjAPBgNVHRMBAf8EBTADAQH/MB0GA1UdDgQWBBTLEejK
# 0rQWWAHJNy4zFha5TJoKHzALBgNVHQ8EBAMCAYYwEgYJKwYBBAGCNxUBBAUCAwEA
# ATAjBgkrBgEEAYI3FQIEFgQU/dExTtMmipXhmGA7qDFvpjy82C0wGQYJKwYBBAGC
# NxQCBAweCgBTAHUAYgBDAEEwHwYDVR0jBBgwFoAUDqyCYEBWJ5flJRP8KuEKU5VZ
# 5KQwUAYDVR0fBEkwRzBFoEOgQYY/aHR0cDovL2NybC5taWNyb3NvZnQuY29tL3Br
# aS9jcmwvcHJvZHVjdHMvbWljcm9zb2Z0cm9vdGNlcnQuY3JsMFQGCCsGAQUFBwEB
# BEgwRjBEBggrBgEFBQcwAoY4aHR0cDovL3d3dy5taWNyb3NvZnQuY29tL3BraS9j
# ZXJ0cy9NaWNyb3NvZnRSb290Q2VydC5jcnQwDQYJKoZIhvcNAQEFBQADggIBAFk5
# Pn8mRq/rb0CxMrVq6w4vbqhJ9+tfde1MOy3XQ60L/svpLTGjI8x8UJiAIV2sPS9M
# uqKoVpzjcLu4tPh5tUly9z7qQX/K4QwXaculnCAt+gtQxFbNLeNK0rxw56gNogOl
# VuC4iktX8pVCnPHz7+7jhh80PLhWmvBTI4UqpIIck+KUBx3y4k74jKHK6BOlkU7I
# G9KPcpUqcW2bGvgc8FPWZ8wi/1wdzaKMvSeyeWNWRKJRzfnpo1hW3ZsCRUQvX/Ta
# rtSCMm78pJUT5Otp56miLL7IKxAOZY6Z2/Wi+hImCWU4lPF6H0q70eFW6NB4lhhc
# yTUWX92THUmOLb6tNEQc7hAVGgBd3TVbIc6YxwnuhQ6MT20OE049fClInHLR82zK
# wexwo1eSV32UjaAbSANa98+jZwp0pTbtLS8XyOZyNxL0b7E8Z4L5UrKNMxZlHg6K
# 3RDeZPRvzkbU0xfpecQEtNP7LN8fip6sCvsTJ0Ct5PnhqX9GuwdgR2VgQE6wQuxO
# 7bN2edgKNAltHIAxH+IOVN3lofvlRxCtZJj/UBYufL8FIXrilUEnacOTj5XJjdib
# Ia4NXJzwoq6GaIMMai27dmsAHZat8hZ79haDJLmIz2qoRzEvmtzjcT3XAH5iR9HO
# iMm4GPoOco3Boz2vAkBq/2mbluIQqBC0N1AI1sM9MIIGBzCCA++gAwIBAgIKYRZo
# NAAAAAAAHDANBgkqhkiG9w0BAQUFADBfMRMwEQYKCZImiZPyLGQBGRYDY29tMRkw
# FwYKCZImiZPyLGQBGRYJbWljcm9zb2Z0MS0wKwYDVQQDEyRNaWNyb3NvZnQgUm9v
# dCBDZXJ0aWZpY2F0ZSBBdXRob3JpdHkwHhcNMDcwNDAzMTI1MzA5WhcNMjEwNDAz
# MTMwMzA5WjB3MQswCQYDVQQGEwJVUzETMBEGA1UECBMKV2FzaGluZ3RvbjEQMA4G
# A1UEBxMHUmVkbW9uZDEeMBwGA1UEChMVTWljcm9zb2Z0IENvcnBvcmF0aW9uMSEw
# HwYDVQQDExhNaWNyb3NvZnQgVGltZS1TdGFtcCBQQ0EwggEiMA0GCSqGSIb3DQEB
# AQUAA4IBDwAwggEKAoIBAQCfoWyx39tIkip8ay4Z4b3i48WZUSNQrc7dGE4kD+7R
# p9FMrXQwIBHrB9VUlRVJlBtCkq6YXDAm2gBr6Hu97IkHD/cOBJjwicwfyzMkh53y
# 9GccLPx754gd6udOo6HBI1PKjfpFzwnQXq/QsEIEovmmbJNn1yjcRlOwhtDlKEYu
# J6yGT1VSDOQDLPtqkJAwbofzWTCd+n7Wl7PoIZd++NIT8wi3U21StEWQn0gASkdm
# EScpZqiX5NMGgUqi+YSnEUcUCYKfhO1VeP4Bmh1QCIUAEDBG7bfeI0a7xC1Un68e
# eEExd8yb3zuDk6FhArUdDbH895uyAc4iS1T/+QXDwiALAgMBAAGjggGrMIIBpzAP
# BgNVHRMBAf8EBTADAQH/MB0GA1UdDgQWBBQjNPjZUkZwCu1A+3b7syuwwzWzDzAL
# BgNVHQ8EBAMCAYYwEAYJKwYBBAGCNxUBBAMCAQAwgZgGA1UdIwSBkDCBjYAUDqyC
# YEBWJ5flJRP8KuEKU5VZ5KShY6RhMF8xEzARBgoJkiaJk/IsZAEZFgNjb20xGTAX
# BgoJkiaJk/IsZAEZFgltaWNyb3NvZnQxLTArBgNVBAMTJE1pY3Jvc29mdCBSb290
# IENlcnRpZmljYXRlIEF1dGhvcml0eYIQea0WoUqgpa1Mc1j0BxMuZTBQBgNVHR8E
# STBHMEWgQ6BBhj9odHRwOi8vY3JsLm1pY3Jvc29mdC5jb20vcGtpL2NybC9wcm9k
# dWN0cy9taWNyb3NvZnRyb290Y2VydC5jcmwwVAYIKwYBBQUHAQEESDBGMEQGCCsG
# AQUFBzAChjhodHRwOi8vd3d3Lm1pY3Jvc29mdC5jb20vcGtpL2NlcnRzL01pY3Jv
# c29mdFJvb3RDZXJ0LmNydDATBgNVHSUEDDAKBggrBgEFBQcDCDANBgkqhkiG9w0B
# AQUFAAOCAgEAEJeKw1wDRDbd6bStd9vOeVFNAbEudHFbbQwTq86+e4+4LtQSooxt
# YrhXAstOIBNQmd16QOJXu69YmhzhHQGGrLt48ovQ7DsB7uK+jwoFyI1I4vBTFd1P
# q5Lk541q1YDB5pTyBi+FA+mRKiQicPv2/OR4mS4N9wficLwYTp2OawpylbihOZxn
# LcVRDupiXD8WmIsgP+IHGjL5zDFKdjE9K3ILyOpwPf+FChPfwgphjvDXuBfrTot/
# xTUrXqO/67x9C0J71FNyIe4wyrt4ZVxbARcKFA7S2hSY9Ty5ZlizLS/n+YWGzFFW
# 6J1wlGysOUzU9nm/qhh6YinvopspNAZ3GmLJPR5tH4LwC8csu89Ds+X57H2146So
# dDW4TsVxIxImdgs8UoxxWkZDFLyzs7BNZ8ifQv+AeSGAnhUwZuhCEl4ayJ4iIdBD
# 6Svpu/RIzCzU2DKATCYqSCRfWupW76bemZ3KOm+9gSd0BhHudiG/m4LBJ1S2sWo9
# iaF2YbRuoROmv6pH8BJv/YoybLL+31HIjCPJZr2dHYcSZAI9La9Zj7jkIeW1sMpj
# tHhUBdRBLlCslLCleKuzoJZ1GtmShxN1Ii8yqAhuoFuMJb+g74TKIdbrHk/Jmu5J
# 4PcBZW+JC33Iacjmbuqnl84xKf8OxVtc2E0bodj6L54/LlUWa8kTo/0xggSRMIIE
# jQIBATCBkDB5MQswCQYDVQQGEwJVUzETMBEGA1UECBMKV2FzaGluZ3RvbjEQMA4G
# A1UEBxMHUmVkbW9uZDEeMBwGA1UEChMVTWljcm9zb2Z0IENvcnBvcmF0aW9uMSMw
# IQYDVQQDExpNaWNyb3NvZnQgQ29kZSBTaWduaW5nIFBDQQITMwAAAUCWqe5wVv7M
# BwABAAABQDAJBgUrDgMCGgUAoIGqMBkGCSqGSIb3DQEJAzEMBgorBgEEAYI3AgEE
# MBwGCisGAQQBgjcCAQsxDjAMBgorBgEEAYI3AgEVMCMGCSqGSIb3DQEJBDEWBBSu
# OrdIIZcM7RtcMQgxCgkoAfw40DBKBgorBgEEAYI3AgEMMTwwOqAggB4ATgB1AEcA
# ZQB0AEMAbwBtAG0AbwBuAC4AcABzADGhFoAUaHR0cDovL21pY3Jvc29mdC5jb20w
# DQYJKoZIhvcNAQEBBQAEggEAvHSms8ivEb5Zrds+x2i1rC0uP+679xZ8cdGwxsyV
# EpKFqR7LLpI+VlGVKCrMEvo10saF5ZCCkBbzjToEX1tCD7ubdwbxeRG1pdrDDwMw
# cS9HNjDmdEct/DHkIbBAxQFwNzuSSIsMl/hAYU9cXadTOQYeUV6kAgHxPyNU1WNO
# B3q5VlNvG2AdQkvVWzX7VbsoUWcgqJf5sdoVcoO/U+7WtGHTVtnzp/SmvR/cobpH
# Bbk3yupRxmOTFXdKE6ShdzfVnvomb/oNu75jLDXMFJu6c3exQ29oH2jTBSpW8Nsf
# +lBNcTmAsklpfajwc7bmM8RLWR7ql2bYO0mpkpWAaB4Ff6GCAigwggIkBgkqhkiG
# 9w0BCQYxggIVMIICEQIBATCBjjB3MQswCQYDVQQGEwJVUzETMBEGA1UECBMKV2Fz
# aGluZ3RvbjEQMA4GA1UEBxMHUmVkbW9uZDEeMBwGA1UEChMVTWljcm9zb2Z0IENv
# cnBvcmF0aW9uMSEwHwYDVQQDExhNaWNyb3NvZnQgVGltZS1TdGFtcCBQQ0ECEzMA
# AAC1rH1th2smEUcAAAAAALUwCQYFKw4DAhoFAKBdMBgGCSqGSIb3DQEJAzELBgkq
# hkiG9w0BBwEwHAYJKoZIhvcNAQkFMQ8XDTE2MTIwODAyMjYxOFowIwYJKoZIhvcN
# AQkEMRYEFHFwRNA81XrhHihgAKdadQuQlALPMA0GCSqGSIb3DQEBBQUABIIBACvH
# wU76UaBwe3pFWKb3HFtzq/RYV8qdxZHBCUaB9JVCZqH9o3YZzz6Kpqs0n6q7/k6z
# r5KAsTGfCW8eMSSx8efrNhySrNKQSnlvhQ1lGCXnBuzLYF6riv+1N4Elxtds6xJ8
# Q+oRxX/i2EB/RMfGFqBXJHxrsFb3Y3BGxtyjaluSlAv4wr0X5LE+pN1DmmFp46z5
# fmMQ2eJsz4bKQ1duZjVm4VGkX4eSq8bZ3oWFd5zi3gphaEvxLwamfMy9L9FfMr3X
# jCLGzhh9VmoqtB4et3T28LCIJRrc0OFW0oCt7k0PgH6ucaN3GZsM3kzV+tEhr5ZX
# xi/kRNYO8fDjngcx+sM=
# SIG # End signature block
