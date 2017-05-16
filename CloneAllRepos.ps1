# Read configuration file
Get-Content "CloneAllRepos.config" | foreach-object -begin {$h=@{}} -process { 
    $k = [regex]::split($_,'='); 
    if(($k[0].CompareTo("") -ne 0) -and ($k[0].StartsWith("[") -ne $True)) { 
        $h.Add($k[0], $k[1]) 
    } 
}
$url = $h.Get_Item("Url")
$username = $h.Get_Item("Username")
$password = $h.Get_Item("Password")

# Retrieve list of all repositories
$base64AuthInfo = [Convert]::ToBase64String([Text.Encoding]::ASCII.GetBytes(("{0}:{1}" -f $username,$password)))
$headers = @{
    "Authorization" = ("Basic {0}" -f $base64AuthInfo)
    "Accept" = "application/json"
}

Add-Type -AssemblyName System.Web
$gitcred = ("{0}:{1}" -f  [System.Web.HttpUtility]::UrlEncode($username),$password)

$resp = Invoke-RestMethod -Headers $headers -Uri ("{0}/_apis/projects" -f $url)

# Clone or pull all repositories
$initpath = get-location
foreach ($entry in $resp.value) {         
    Write-Output '--------------------------------------------------------'
    Write-Output $entry.name

    #Write-Host $repository.name
    #Write-Host $repository.url

    if(!(Test-Path -Path $entry.name)){
        mkdir $entry.name
    }

    $uriReposGit = ("{0}/{1}/_apis/git/repositories" -f $url,$entry.id)    
    $repositories = Invoke-RestMethod -Headers $headers -Uri $uriReposGit

    foreach ($repository in $repositories.value)
    {
        Write-Output ("repository:{0}" -f $repository.name)
        $repoPath = $entry.name + '\' + $repository.name + '.git'
        $repositoryLink = $repository.remoteUrl -replace "://", ("://{0}@" -f $gitcred)            
        if(!(Test-Path -Path $repoPath)) {        
            git clone --mirror $repositoryLink $repoPath
        } 
        else {
            set-location $repoPath
            git remote set-url origin $repositoryLink
            git remote update --prune    
            set-location $initpath
        }
    }
}