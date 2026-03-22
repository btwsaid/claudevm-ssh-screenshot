# claude-screenshot configuration
# Copy this file to: ~\.config\claude-screenshot\config.ps1

$VM_HOST = ""                    # VM IP address (bridged networking)
$VM_USER = ""                    # SSH username on VM
$VM_PORT = 22                    # SSH port
$REMOTE_PATH = ""                # e.g. /home/tokyo/screenshots
$LOCAL_SCREENSHOTS = [IO.Path]::Combine([Environment]::GetFolderPath('MyPictures'), "Screenshots")
$AUTO_DELETE = $false            # Delete local file after upload
$SSH_KEY = ""                    # Optional: path to SSH private key
