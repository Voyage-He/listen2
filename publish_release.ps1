param($TAG_NAME,$LATEST)
$FILES_PATH = "./build/app/outputs/flutter-apk/*release.apk*"
$ErrorActionPreference = "Stop"

# bulid
flutter build apk --release --split-per-abi

# create draft release
gh release create $TAG_NAME --title "$TAG_NAME" --notes "" --draft

# upload one by one
Get-ChildItem -Path $FILES_PATH | ForEach-Object {
    $file = $_.FullName
    Write-Host "Uploading $file..."
    gh release upload $TAG_NAME $file
}

# publish release
if ($LATEST -eq $true) {
    gh release edit $TAG_NAME --draft=false --latest
} else {
    gh release edit $TAG_NAME --draft=false --prerelease
}

Write-Host "All files uploaded successfully."