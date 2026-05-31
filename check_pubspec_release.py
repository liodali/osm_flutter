import os
import sys
import requests
import argparse
import update_versions


FILE_PUBSEPEC_OSM_INTERFACE = "./flutter_osm_interface/pubspec.yaml"
FILE_PUBSEPEC_OSM_WEB = "./flutter_osm_web/pubspec.yaml"
LINE_VERSION = 2

URL_VER_PACKAGE_OSM_INTERFACE = "https://pub.dartlang.org/api/packages/flutter_osm_interface/versions/"
URL_VER_PACKAGE_WEB = "https://pub.dartlang.org/api/packages/flutter_osm_web/versions/"


def check_version_exist(url_package, version):
    url = f"{url_package}{version}"
    data = requests.get(url.strip())
    if data.status_code == 200:
        return True
    else:
        return False


def publish_osm_interface():
    stream = os.popen("cd flutter_osm_interface && flutter pub publish -f && cd ..")
    lines = stream.readlines()
    for line in lines:
        print(line)


def publish_osm_web():
    stream = os.popen("cd flutter_osm_web && flutter pub publish -f && cd ..")
    lines = stream.readlines()
    for line in lines:
        print(line)


def get_version_package(package):
    with open(package, "r") as pub:
        lines = pub.readlines()
        version_line = lines[LINE_VERSION]
        version = version_line.split(":")[-1]
        version = version.replace(" ", "")
        version = version.replace("\n", "")
        return version


if __name__ == "__main__":
    parser = argparse.ArgumentParser(
        description="Check versions, optionally publish, and update pubspec dependencies"
    )
    parser.add_argument(
        "--publish",
        action="store_true",
        help="Publish inner packages (interface/web) if their versions don't exist on pub.dev"
    )
    args = parser.parse_args()

    version_interface = get_version_package(FILE_PUBSEPEC_OSM_INTERFACE)
    version_web = get_version_package(FILE_PUBSEPEC_OSM_WEB)

    print(f"flutter_osm_interface version: {version_interface}")
    print(f"flutter_osm_web version: {version_web}\n")

    interface_exists = check_version_exist(URL_VER_PACKAGE_OSM_INTERFACE, version_interface)
    web_exists = check_version_exist(URL_VER_PACKAGE_WEB, version_web)

    print(f"flutter_osm_interface {version_interface}: {'exists' if interface_exists else 'missing'}")
    print(f"flutter_osm_web {version_web}: {'exists' if web_exists else 'missing'}\n")

    if args.publish:
        if not interface_exists:
            print(f"Publishing flutter_osm_interface : {version_interface} ...\n")
            publish_osm_interface()
        if not web_exists:
            print(f"Publishing flutter_osm_web : {version_web} ...\n")
            publish_osm_web()
    else:
        if not interface_exists or not web_exists:
            print("ERROR: Some package versions don't exist on pub.dev.")
            print("Use --publish to publish them, or update the versions first.")
            sys.exit(1)

    print("\n=== Updating dependency versions ===\n")
    update_versions.update_web("caret")
    print()
    update_versions.update_osm("caret")

    print("\nAll done.")
