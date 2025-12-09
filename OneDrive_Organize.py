import requests
import msal
import os
import json
from datetime import datetime
import webbrowser
from collections import defaultdict

# Configuration (replace with your Azure app details)
client_id = "YOUR_CLIENT_ID"
client_secret = "YOUR_CLIENT_SECRET"
tenant_id = "common"  # Use "common" for personal accounts
redirect_uri = "http://localhost:8080"
scopes = ["Files.Read", "User.Read"]
camera_roll_path = "Camera Roll"  # Path to Camera Roll folder in OneDrive
token_cache_file = "token_cache.json"

def save_token_cache(app, cache_file):
    with open(cache_file, "w") as f:
        json.dump(app.token_cache.serialize(), f)

def load_token_cache(app, cache_file):
    if os.path.exists(cache_file):
        with open(cache_file, "r") as f:
            app.token_cache.deserialize(json.load(f))

def get_access_token():
    app = msal.ConfidentialClientApplication(
        client_id,
        authority=f"https://login.microsoftonline.com/{tenant_id}",
        client_credential=client_secret
    )
    
    # Load token cache
    load_token_cache(app, token_cache_file)
    
    # Try to acquire token silently using refresh token
    accounts = app.get_accounts()
    if accounts:
        result = app.acquire_token_silent(scopes, account=accounts[0])
        if result and "access_token" in result:
            save_token_cache(app, token_cache_file)
            return result["access_token"]
    
    # If silent acquisition fails, perform interactive authentication
    auth_url = app.get_authorization_request_url(scopes, redirect_uri=redirect_uri)
    print(f"Please go to this URL and authenticate: {auth_url}")
    webbrowser.open(auth_url)
    
    # Prompt user to paste the redirect URL with code
    redirect_response = input("Paste the full redirect URL here: ")
    code = redirect_response.split("code=")[1].split("&")[0]
    
    # Exchange code for token
    result = app.acquire_token_by_authorization_code(
        code,
        scopes,
        redirect_uri=redirect_uri
    )
    
    if "access_token" in result:
        save_token_cache(app, token_cache_file)
        return result["access_token"]
    else:
        raise Exception("Authentication failed: ", result.get("error_description"))

def get_camera_roll_files(access_token):
    headers = {"Authorization": f"Bearer {access_token}"}
    url = f"https://graph.microsoft.com/v1.0/me/drive/root:/{camera_roll_path}:/children"
    files = []
    
    while url:
        response = requests.get(url, headers=headers)
        if response.status_code != 200:
            raise Exception(f"Error fetching files: {response.json()}")
        
        data = response.json()
        files.extend(data.get("value", []))
        url = data.get("@odata.nextLink")  # Handle pagination
    
    return files

def organize_files_by_date():
    try:
        access_token = get_access_token()
        files = get_camera_roll_files(access_token)
        
        # Dictionary to store files organized by year and month
        organized_files = defaultdict(lambda: defaultdict(list))
        
        for file in files:
            if file.get("file") and file["name"].lower().endswith(('.jpg', '.jpeg', '.png', '.mp4')):
                file_name = file["name"]
                creation_date = file.get("createdDateTime")
                
                if creation_date:
                    # Parse creation date
                    date_obj = datetime.strptime(creation_date, "%Y-%m-%dT%H:%M:%S.%fZ")
                    year = date_obj.strftime("%Y")
                    month = date_obj.strftime("%m")
                    
                    # Add file to organized dictionary
                    organized_files[year][month].append({
                        "name": file_name,
                        "id": file["id"],
                        "createdDateTime": creation_date
                    })
                else:
                    print(f"Skipping {file_name}: No creation date available")
        
        return organized_files
    
    except Exception as e:
        print(f"Error: {str(e)}")
        return None

def print_organized_files(organized_files):
    if not organized_files:
        print("No files found or an error occurred.")
        return
    
    for year in sorted(organized_files.keys()):
        print(f"\nYear: {year}")
        for month in sorted(organized_files[year].keys()):
            print(f"  Month: {month}")
            for file in organized_files[year][month]:
                print(f"    - {file['name']} (Created: {file['createdDateTime']})")

if __name__ == "__main__":
    organized_files = organize_files_by_date()
    print_organized_files(organized_files)