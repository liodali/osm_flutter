#!/usr/bin/env python3
"""
Pre-release script for Flutter OSM packages

This script automates the publishing process for flutter_osm_interface and flutter_osm_web packages.
It checks if package versions exist on pub.dev, publishes them if they don't exist,
and waits for the publishing process to complete.

Usage:
    python pre_release.py [--mode {onlyinterface,onlyweb,all}]
    
Options:
    --mode: Specify which packages to process (default: all)
        - onlyinterface: Process only flutter_osm_interface
        - onlyweb: Process only flutter_osm_web
        - all: Process both packages
"""

# Import required modules for file operations, system operations, file input, and HTTP requests
import os  # Operating system interface for running shell commands
import sys  # System-specific parameters and functions
import fileinput  # Utilities for reading and processing files line by line
import time  # Time-related functions for sleep functionality
import requests  # HTTP library for making API requests
import argparse  # Command-line argument parsing

# API endpoint URLs for checking package versions on pub.dev
URL_VER_PACKAGE_OSM_INTERFACE = "https://pub.dartlang.org/api/packages/flutter_osm_interface/versions/"  # Base URL for flutter_osm_interface package versions
URL_VER_PACKAGE_WEB = "https://pub.dartlang.org/api/packages/flutter_osm_web/versions/"  # Base URL for flutter_osm_web package versions

# Git tag prefixes for different packages
PRE_TAG_INTERFACE="flutter_osm_interface-v"  # Prefix for flutter_osm_interface git tags
PRE_TAG_WEB="flutter_osm_web-v"  # Prefix for flutter_osm_web git tags

# File paths for pubspec.yaml files
FILE_PUBSEPEC_OSM_INTERFACE = "flutter_osm_interface/pubspec.yaml"  # Path to flutter_osm_interface pubspec.yaml
FILE_PUBSEPEC_OSM_WEB = "flutter_osm_web/pubspec.yaml"  # Path to flutter_osm_web pubspec.yaml

# Line number where version is defined in pubspec.yaml (0-indexed)
LINE_VERSION = 2  # Typically version is on line 3 (0-indexed as 2)
TIMEOUT_SECONDS = 120 # used to wait for the package to be published on pub.dev

def check_version_exist(url_package,version):
    """Check if a specific version of a package exists on pub.dev
    
    Args:
        url_package (str): Base URL for the package API endpoint
        version (str): Version number to check
    
    Returns:
        bool: True if version exists, False otherwise
    """
    url = f"{url_package}{version}"  # Construct full URL by appending version to base URL
    data = requests.get(url.strip())  # Make HTTP GET request to check if version exists
    if data.status_code == 200:  # HTTP 200 means the version exists
        return True
    else:  # Any other status code means version doesn't exist
        return False
def get_version_package(package):
    """Extract version number from a pubspec.yaml file
    
    Args:
        package (str): Path to the pubspec.yaml file
    
    Returns:
        str: Version number extracted from the file
    """
    with open(package, "r") as pub:  # Open the pubspec.yaml file for reading
        lines = pub.readlines()  # Read all lines from the file
        version_line = lines[LINE_VERSION]  # Get the line containing version info (LINE_VERSION should be defined)
        version = version_line.split(":")[-1]  # Split by colon and take the part after it (the version)
        version = version.replace(" ", "")  # Remove any spaces from the version string
        version = version.replace("\n", "")  # Remove newline characters from the version string
        return version  # Return the cleaned version string

def update_plugin_osm_interface():
    """Update and publish flutter_osm_interface package if version doesn't exist
    
    Returns:
        str: Version number of the flutter_osm_interface package
    """
    version = get_version_package(FILE_PUBSEPEC_OSM_INTERFACE)  # Get version from pubspec.yaml (FILE_PUBSEPEC_OSM_INTERFACE should be defined)
    print(f'version : {version}\n')  # Print the current version number
    isExist = check_version_exist(URL_VER_PACKAGE_OSM_INTERFACE,f"{version}")  # Check if this version already exists on pub.dev
    msg = "exist" if isExist else "doesn't exist"  # Create appropriate message based on existence
    print(f"the flutter_osm_interface with version :{version} {msg}\n")  # Print status message
    if isExist == False:  # If version doesn't exist on pub.dev
        print(f"publishing flutter_osm_interface : {version} ...\n")  # Print publishing message
        publish_osm_interface(version)  # Publish the new version
    return version  # Return the version number

def publish_osm_interface(version):
    """Publish flutter_osm_interface package by creating and pushing a git tag
    
    Args:
        version (str): Version number to tag and publish
    """
    tag=f"{PRE_TAG_INTERFACE}{version}"  # Create git tag name by combining prefix with version
    stream = os.popen(f"git tag {tag} HEAD && git push --tags")  # Create git tag at HEAD and push all tags to remote
    lines = stream.readlines()  # Read the output from the git command
    for line in lines:  # Iterate through each line of output
        print(line)  # Print each line of the git command output
   
def publish_osm_web(version):
    """Publish flutter_osm_web package by creating and pushing a git tag
    
    Args:
        version (str): Version number to tag and publish
    """
    tag=f"{PRE_TAG_WEB}{version}"  # Create git tag name by combining prefix with version
    stream = os.popen(f"git tag {tag} HEAD && git push --tags")  # Create git tag at HEAD and push all tags to remote
    lines = stream.readlines()  # Read the output from the git command
    for line in lines:  # Iterate through each line of output
        print(line)  # Print each line of the git command output

def wait_interface_publish(version, timeout_seconds=None):
    """Wait for flutter_osm_interface package to be published on pub.dev
    
    Args:
        version (str): Version number to wait for
        timeout_seconds (int, optional): Maximum time to wait in seconds. If None, wait indefinitely.
    
    Returns:
        bool: True if published successfully, False if timeout occurred
    """
    start_time = time.time()
    while True:  # Loop until package is published or timeout
        isExist = check_version_exist(URL_VER_PACKAGE_OSM_INTERFACE,version)  # Check if version exists on pub.dev
        if isExist:  # If version is found on pub.dev
            print("flutter_osm_interface published successfully")  # Print success message when published
            return True
        
        # Check timeout if specified
        if timeout_seconds is not None:
            elapsed_time = time.time() - start_time
            if elapsed_time >= timeout_seconds:
                print(f"Timeout: flutter_osm_interface was not published within {timeout_seconds} seconds")
                return False
        
        time.sleep(1)  # Wait 1 seconds before checking again
        print("waiting for the flutter_osm_interface to be published ...")  # Print waiting message

def wait_web_publish(version, timeout_seconds=None):
    """Wait for flutter_osm_web package to be published on pub.dev
    
    Args:
        version (str): Version number to wait for
        timeout_seconds (int, optional): Maximum time to wait in seconds. If None, wait indefinitely.
    
    Returns:
        bool: True if published successfully, False if timeout occurred
    """
    start_time = time.time()
    while True:  # Loop until package is published or timeout
        isExist = check_version_exist(URL_VER_PACKAGE_WEB,version)  # Check if version exists on pub.dev
        if isExist:  # If version is found on pub.dev
            print("flutter_osm_web published successfully")  # Print success message when published
            return True
        
        # Check timeout if specified
        if timeout_seconds is not None:
            elapsed_time = time.time() - start_time
            if elapsed_time >= timeout_seconds:
                print(f"Timeout: flutter_osm_web was not published within {timeout_seconds} seconds")
                return False
        
        time.sleep(1)  # Wait 1 seconds before checking again
        print("waiting for the flutter_osm_web to be published ...")  # Print waiting message

def update_interface_in_plugin_osm_web(version):
    """Update the flutter_osm_interface dependency version in flutter_osm_web's pubspec.yaml
    
    Args:
        version (str): New version number to set for flutter_osm_interface dependency
    """
    with open(FILE_PUBSEPEC_OSM_WEB, "r") as pub:  # Open flutter_osm_web pubspec.yaml for reading
        lines = pub.readlines()  # Read all lines from the file
        # Find the line with flutter_osm_interface dependency and update it
        for i, line in enumerate(lines):
            if "flutter_osm_interface:" in line:
                lines[i] = f"  flutter_osm_interface: ^{version}\n"
                break
        with open(FILE_PUBSEPEC_OSM_WEB, "w") as pub:  # Open the same file for writing
            pub.writelines(lines)  # Write all lines back to the file

def update_plugin_osm_web(interface_version):
    """Update and publish flutter_osm_web package if version doesn't exist
    
    Args:
        interface_version (str): Version of flutter_osm_interface to use as dependency
    
    Returns:
        str: Version number of the flutter_osm_web package
    """
    # First update the interface dependency in web package
    update_interface_in_plugin_osm_web(interface_version)
    
    # Get the web package version
    version = get_version_package(FILE_PUBSEPEC_OSM_WEB)
    print(f'flutter_osm_web version : {version}\n')
    
    # Check if this version already exists on pub.dev
    isExist = check_version_exist(URL_VER_PACKAGE_WEB, f"{version}")
    msg = "exist" if isExist else "doesn't exist"
    print(f"the flutter_osm_web with version :{version} {msg}\n")
    
    # If version doesn't exist, publish it
    if isExist == False:
        print(f"publishing flutter_osm_web : {version} ...\n")
        publish_osm_web(version)
    
    return version

# Main execution block - runs only when script is executed directly (not imported)
if __name__ == "__main__":
    # Set up command-line argument parsing
    parser = argparse.ArgumentParser(
        description="Pre-release script for Flutter OSM packages",
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog="""Examples:
  python pre_release.py --mode onlyinterface
  python pre_release.py --mode onlyweb
  python pre_release.py --mode all
  python pre_release.py  # defaults to 'all'"""
    )
    
    parser.add_argument(
        "--mode",
        choices=["onlyinterface", "onlyweb", "all"],
        default="all",
        help="Specify which packages to process (default: all)"
    )
    
    # Parse command-line arguments
    args = parser.parse_args()
    
    print(f"Running pre-release script in '{args.mode}' mode...\n")
    
    version_interface = None
    version_web = None
    
    # Process based on selected mode
    if args.mode in ["onlyinterface", "all"]:
        print("=== Processing flutter_osm_interface ===")
        version_interface = update_plugin_osm_interface()  # Update and publish flutter_osm_interface package
        
        # Set timeout for single-package modes only
        timeout = TIMEOUT_SECONDS if args.mode == "onlyinterface" else None
        success = wait_interface_publish(version_interface, timeout)  # Wait for flutter_osm_interface to be published on pub.dev
        
        if not success:
            print("Failed to publish flutter_osm_interface within timeout period")
            sys.exit(1)
        
        print("flutter_osm_interface processing completed\n")
    
    # Add 3-second wait between packages when processing both
    if args.mode == "all" and version_interface is not None:
        print("Waiting 5 seconds before processing flutter_osm_web...")
        time.sleep(5)
        print("")
    
    if args.mode in ["onlyweb", "all"]:
        print("=== Processing flutter_osm_web ===")
        # If we didn't process interface, we need to get its current version
        if version_interface is None:
            version_interface = get_version_package(FILE_PUBSEPEC_OSM_INTERFACE)
            print(f"Using existing flutter_osm_interface version: {version_interface}\n")
        
        version_web = update_plugin_osm_web(version_interface)  # Update and publish flutter_osm_web package
        
        # Set timeout for single-package modes only
        timeout = TIMEOUT_SECONDS if args.mode == "onlyweb" else None
        success = wait_web_publish(version_web, timeout)  # Wait for flutter_osm_web to be published on pub.dev
        
        if not success:
            print("Failed to publish flutter_osm_web within timeout period")
            sys.exit(1)
        
        print("flutter_osm_web processing completed\n")
    
    print("=== Summary ===")
    if version_interface:
        print(f"flutter_osm_interface version: {version_interface}")
    if version_web:
        print(f"flutter_osm_web version: {version_web}")
    print("All operations completed successfully!")  # Print completion message
 