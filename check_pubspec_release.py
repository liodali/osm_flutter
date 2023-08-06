import os
import sys
import fileinput
import requests


FILE_PUBSEPEC_OSM_INTERFACE = "./flutter_osm_interface/pubspec.yaml"
FILE_PUBSEPEC_OSM_WEB = "./flutter_osm_web/pubspec.yaml"
FILE_PUBSEPEC_OSM = "./pubspec.yaml"
LINE_VERSION = 2

URL_VER_PACKAGE_OSM_INTERFACE = "https://pub.dartlang.org/api/packages/flutter_osm_interface/versions/"
URL_VER_PACKAGE_WEB = "https://pub.dartlang.org/api/packages/flutter_osm_web/versions/"


def check_version_exist(url_package,version):
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


def change_pubspec_osm_interface(version):
    with open(FILE_PUBSEPEC_OSM_INTERFACE, "r") as pub:
        pub.seek(0, 0)
        lines = pub.readlines()
        lines[LINE_VERSION] = f"version: {version}"
        pub.seek(0, 0)
        pub.writelines(lines)
        pub.truncate()

def change_pubspec_osm_web(version):
    with open(FILE_PUBSEPEC_OSM_WEB, "r") as pub:
        pub.seek(0, 0)
        lines = pub.readlines()
        lines[LINE_VERSION] = f"version: {version}"
        pub.seek(0, 0)
        pub.writelines(lines)
        pub.truncate()


def get_version_osm_interface():
    with open(FILE_PUBSEPEC_OSM_INTERFACE, "r") as pub:
        lines = pub.readlines()
        version_line = lines[LINE_VERSION]
        version = version_line.split(":")[-1]
        version = version.replace(" ", "")
        version = version.replace("\n", "")
        return version
def get_version_package(package):
    with open(package, "r") as pub:
        lines = pub.readlines()
        version_line = lines[LINE_VERSION]
        version = version_line.split(":")[-1]
        version = version.replace(" ", "")
        version = version.replace("\n", "")
        return version


def get_max_version(version):
    index_max = 3
    range_max = 1
    package_v = version
    if("+" in version):
        package_v = str(version).split("+")[0]
    if "-" in version:
        package_v = str(version).split("-")[0]

    listInnerVersionNumbers = str(package_v).split(".")
    x, y, z = [int(i) for i in listInnerVersionNumbers]
    z += 1
    if z > 99:
        y += 1
        z = 0
    if y > 99:
        z = 0
        y = 0
        x += 1
    max_version = str(x) + "." + str(y) + "."+str(z)
    return max_version


def change_dependencies_version(package,name, version, isLocal=False,skipMaxVersion=False,useDefault=False):
    mVersion = get_max_version(version=version)
    with open(package, "r+") as pub:
        pub.seek(0, 0)
        lines = []
        removeNext = False
        for line in pub.readlines():
            if(name in line):
                if skipMaxVersion :
                    v = f"\">={version} <{mVersion}\"".strip()
                elif useDefault == False :
                    v = f"\">={version}\"".strip()
                else :
                    v = f"^{version}".strip()
                lines.append(f"  {name} {v}")
                if(isLocal):
                    removeNext = True
            else:
                if(removeNext):
                    removeNext = False
                    lines.append("\n")
                else:
                    lines.append(line)

        pub.seek(0, 0)
        pub.writelines(lines)
        pub.truncate()




def update_plugin_osm_interface():
    version = get_version_package(FILE_PUBSEPEC_OSM_INTERFACE)
    print(f'version : {version}\n')
    isExist = check_version_exist(URL_VER_PACKAGE_OSM_INTERFACE,f"{version}")
    msg = "exist" if isExist else "doesn't exist"
    print(f"the flutter_osm_interface with version :{version} {msg}\n")
    if isExist == False:
        print(f"publishing flutter_osm_interface : {version} ...\n")
        publish_osm_interface()
    return version

def update_plugin_osm_web(version_interface):
    version = get_version_package(FILE_PUBSEPEC_OSM_WEB)
    print(f'version : {version}\n')
    isExist = check_version_exist(URL_VER_PACKAGE_WEB,f"{version}")
    msg = "exist" if isExist else "doesn't exist"
    print(f"the flutter_osm_web with version :{version} {msg}\n")
    # set version of osm interface in osm web plugin 
    change_dependencies_version(FILE_PUBSEPEC_OSM_WEB,
        "flutter_osm_interface:", version_interface, isLocal=True)
    if isExist == False:
        print(f"publishing flutter_osm_web : {version} ...\n")
        publish_osm_web()
    return version
if __name__ == "__main__":

    version_interface = update_plugin_osm_interface()
    version_web = update_plugin_osm_web(version_interface)
    change_dependencies_version(FILE_PUBSEPEC_OSM,"flutter_osm_interface:", version_interface, isLocal=True,useDefault=True)
    change_dependencies_version(FILE_PUBSEPEC_OSM,"flutter_osm_web:", version_web, isLocal=True,skipMaxVersion=True)
