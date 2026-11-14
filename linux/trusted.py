"""Fixed, trusted values for the Linux runner (CM-042).

These values are application code, not plan data. A plan can only choose
steps from the catalog; it can never change a URL, path, key or package
name. The catalog file must repeat the source values below exactly, so a
changed catalog alone cannot redirect the runner to another source.
"""

TARGET_OS = "ubuntu-24.04"
TARGET_OS_ID = "ubuntu"
TARGET_VERSION_ID = "24.04"
TARGET_CODENAME = "noble"
TARGET_ARCHITECTURE = "amd64"
MIN_PYTHON = (3, 12)

# Official Docker APT repository for Ubuntu (docs.docker.com/engine/install/ubuntu).
DOCKER_REPOSITORY_URI = "https://download.docker.com/linux/ubuntu"
DOCKER_KEY_URL = "https://download.docker.com/linux/ubuntu/gpg"
DOCKER_KEY_HOST = "download.docker.com"
DOCKER_KEY_FINGERPRINT = "9DC858229FC7DD38854AE2D88D81803C0EBFCD88"
DOCKER_KEY_MAX_BYTES = 65536
DOCKER_KEYRING_DIR = "/etc/apt/keyrings"
DOCKER_KEY_PATH = "/etc/apt/keyrings/docker.asc"
DOCKER_SOURCES_PATH = "/etc/apt/sources.list.d/docker.sources"
# A legacy one-line source for the same repository would conflict with ours.
DOCKER_LEGACY_LIST_PATH = "/etc/apt/sources.list.d/docker.list"
DOCKER_SUITE = "noble"
DOCKER_COMPONENTS = "stable"

DOCKER_SOURCES_CONTENT = (
    "Types: deb\n"
    "URIs: https://download.docker.com/linux/ubuntu\n"
    "Suites: noble\n"
    "Components: stable\n"
    "Architectures: amd64\n"
    "Signed-By: /etc/apt/keyrings/docker.asc\n"
)

# unattended-upgrades: only enable the periodic run. The package default
# 50unattended-upgrades (security pockets only, Automatic-Reboot off) is
# never overwritten by the runner.
AUTO_UPGRADES_PATH = "/etc/apt/apt.conf.d/20auto-upgrades"
AUTO_UPGRADES_CONTENT = (
    'APT::Periodic::Update-Package-Lists "1";\n'
    'APT::Periodic::Unattended-Upgrade "1";\n'
)
UNATTENDED_UPGRADES_CONFIG_PATH = "/etc/apt/apt.conf.d/50unattended-upgrades"

# Packages the Docker documentation lists as conflicting ("Uninstall old
# versions"). The runner reports them as an error and never removes them.
DOCKER_CONFLICTING_PACKAGES = (
    "docker.io",
    "docker-compose",
    "docker-compose-v2",
    "docker-doc",
    "docker-buildx",
    "podman-docker",
    "containerd",
    "runc",
)

DOCKER_GROUP = "docker"

# Exact package names per catalog step. The catalog may pin Docker versions
# but cannot add, drop or rename packages.
STEP_PACKAGES = {
    "base-tools": ("ca-certificates", "curl", "git", "gnupg"),
    "docker-apt-repository": (),
    "docker-engine": (
        "docker-ce",
        "docker-ce-cli",
        "containerd.io",
        "docker-buildx-plugin",
        "docker-compose-plugin",
    ),
    "unattended-upgrades": ("unattended-upgrades",),
}

# Source of each step's packages. "ubuntu-archive" is never pinned,
# "docker-apt-repository" is always pinned exactly.
STEP_SOURCES = {
    "base-tools": "ubuntu-archive",
    "docker-apt-repository": "docker-apt-repository",
    "docker-engine": "docker-apt-repository",
    "unattended-upgrades": "ubuntu-archive",
}

# The catalog "sources" object must equal this value exactly.
CATALOG_SOURCES = {
    "ubuntu-archive": {
        "kind": "distribution-archive",
        "pinned": False,
    },
    "docker-apt-repository": {
        "kind": "apt-repository",
        "pinned": True,
        "uri": DOCKER_REPOSITORY_URI,
        "suite": DOCKER_SUITE,
        "components": DOCKER_COMPONENTS,
        "architecture": TARGET_ARCHITECTURE,
        "keyUrl": DOCKER_KEY_URL,
        "keyFingerprint": DOCKER_KEY_FINGERPRINT,
        "keyPath": DOCKER_KEY_PATH,
        "sourcesPath": DOCKER_SOURCES_PATH,
    },
}
