# Building ROS 2 Jazzy Debian packages for Debian / Raspberry Pi OS **Trixie (arm64)**

This document describes a **reproducible, buildfarm-style workflow** for building **ROS 2 Jazzy** Debian packages on **Debian Trixie / Raspberry Pi OS (arm64)**.

The approach mirrors how Debian and ROS build farms work:

* source packages generated via `bloom`
* clean binary builds via `sbuild`
* dependency resolution via a **local APT repository**
* multi-pass builds until the dependency graph converges
* **no ROS build dependencies installed on the host**

---

## Design goals

* ✔ clean host system (no ROS build-deps installed globally)
* ✔ reproducible builds
* ✔ dependency ordering handled automatically
* ✔ works offline once bootstrap packages are built
* ✔ compatible with future Debian buildd behavior

---

## 1. Install required tooling

```bash
sudo apt update
sudo apt install -y \
  git build-essential cmake \
  fakeroot devscripts debhelper dh-python \
  sbuild reprepro schroot debootstrap \
  python3-bloom python3-rosdep2 \
  python3-all
```

Notes:

* `python3-all` is required for many ROS Python packages
* `sbuild` + `schroot` provide clean, isolated builds
* `reprepro` manages the local APT repository

---

## 2. Set up a **local APT repository**

The local repo allows packages you build to become dependencies for later builds.

### 2.1 Create a repository signing key

Create a **user-owned** signing key (recommended):

```bash
sudo mkdir -p /etc/apt/keyrings

gpg --batch --yes \
  --passphrase '' \
  --quick-generate-key \
  "Local ROS Repo (trixie) <local-ros-repo@localhost>" \
  ed25519 default 0

gpg --batch --yes \
  --export "Local ROS Repo (trixie) <local-ros-repo@localhost>" \
  | sudo tee /etc/apt/keyrings/local-ros-repo.gpg >/dev/null

sudo chmod 0644 /etc/apt/keyrings/local-ros-repo.gpg
```

> Only the **public key** is exported to `/etc/apt/keyrings`.
> The **secret key stays in your GPG keyring** and is used by `reprepro` to sign metadata.

---

### 2.2 Prepare the repository layout

```bash
mkdir -p /srv/aptrepo/{conf,db,dists,pool,incoming}
```

Create the distributions file:

```bash
cat > /srv/aptrepo/conf/distributions <<'EOF'
Origin: local
Label: local
Suite: stable
Codename: trixie
Architectures: arm64
Components: main
Description: Local ROS Jazzy repository
SignWith: <YOUR_KEY_FPR>
EOF
```

Replace `<YOUR_KEY_FPR>` with your **full 40-hex fingerprint (no spaces)**:

```bash
gpg --list-secret-keys --with-fingerprint --keyid-format=long
```

Example:

```
SignWith: 36F8D7DD987CD72BFA880292EB72681050355E8F
```

Set ownership (important — avoids `sudo reprepro` problems):

```bash
sudo chown -R "$USER":"$USER" /srv/aptrepo
chmod -R go-w /srv/aptrepo
```

---

### 2.3 Add the repo to APT

```bash
sudo tee /etc/apt/sources.list.d/local-ros.list >/dev/null <<EOF
deb [arch=arm64 signed-by=/etc/apt/keyrings/local-ros-repo.gpg] file:/srv/aptrepo trixie main
EOF

sudo apt update
```

---

### 2.4 Initial export

```bash
reprepro -b /srv/aptrepo export
sudo apt update
```

> **Important:** after every publish, you must run `reprepro export`.

---

## 3. Configure `sbuild` (clean build environment)

### 3.1 Create a Trixie arm64 chroot

```bash
sudo sbuild-createchroot \
  --include=eatmydata,ccache \
  trixie /srv/chroot/trixie-arm64 \
  http://deb.debian.org/debian
```

Add yourself to the `sbuild` group:

```bash
sudo adduser "$USER" sbuild
newgrp sbuild
```

---

### 3.2 Make the local repo visible inside the chroot

Bind-mount the repo:

```bash
echo '/srv/aptrepo /srv/aptrepo none rw,bind 0 0' \
  | sudo tee -a /etc/schroot/sbuild/fstab
```

Ensure the chroot always has:

* the repo source list
* the repo public key

Edit:

```bash
sudo nano /etc/schroot/sbuild/copyfiles
```

Add:

```
/etc/apt/sources.list.d/local-ros.list
/etc/apt/keyrings/local-ros-repo.gpg
```

---

### 3.3 Pin sbuild to `schroot` backend

Debian is moving to `unshare`, but `schroot` is recommended here for now.

Create:

```bash
mkdir -p ~/.config/sbuild
nano ~/.config/sbuild/config.pl
```

Add:

```perl
$chroot_mode = "schroot";
$schroot = "schroot";
```

---

### 3.4 Enable sbuild logging

Edit:

```bash
sudo nano /etc/sbuild/sbuild.conf
```

Ensure:

```perl
$log_dir = "/var/log/sbuild";
```

Create directory:

```bash
sudo mkdir -p /var/log/sbuild
sudo chown -R root:sbuild /var/log/sbuild
sudo chmod -R 2775 /var/log/sbuild
```

---

### 3.5 Speed up downloads with apt-cacher-ng (optional)

Install a cache on the host:

```bash
sudo apt install apt-cacher-ng
```

Allow localhost (or your subnet) in `/etc/apt-cacher-ng/acng.conf` via `AllowedHosts`, then restart:

```bash
sudo systemctl restart apt-cacher-ng
```

Point sbuild to the proxy:
```
sudo schroot -c source:trixie-arm64-sbuild -u root --directory / -- \
    bash -c 'echo "Acquire::http::Proxy \"http://127.0.0.1:3142\";" > /etc/apt/apt.conf.d/01proxy'
```

Warm the cache once:

```bash
sudo sbuild-update -ucar trixie-arm64-sbuild --update
```

Check hits/misses at `http://127.0.0.1:3142/acng-report.html`.

---

## 4. Retrieving the source packages

```
cd ros2_base/src
vcs import src --debug < ./ros2.repos
```

## 5. Configure rosdep for Debian Trixie

Copy:

* `10-debian-trixie.yaml`
* `10-debian-trixie.list`

into:

```bash
/etc/ros/rosdep/sources.list.d/
```

Then update rosdep:

```bash
rosdep update
```

The name of the files is important as they need to precede any other files in `/etc/ros/rosdep/sources.list.d/`.

---

## 6. Building packages

The build script:

* runs `bloom-generate`
* creates source packages **without installing build-deps on host**
* runs `sbuild` against `.dsc`
* publishes `.changes` into the local repo
* retries in multiple passes until dependencies are satisfied

### Run the script

```bash
ROS_SUBDIR=ros2_base     wip/build_all_repos.sh
ROS_SUBDIR=ros2_control wip/build_all_repos.sh
ROS_SUBDIR=ros2_vision  wip/build_all_repos.sh
```

Packages that fail due to missing dependencies are retried automatically in later passes once their dependencies have been built and published.

---

## 7. Reinitializing the repository (clean rebuild)

If you need to rebuild everything from scratch, reinitialize `/srv/aptrepo`:

```bash
rm -rf /srv/aptrepo/{db,dists,pool}/*
reprepro -b /srv/aptrepo export
sudo apt update
```

**Note:** This only clears the repository. Built `.deb` files in your workspace remain untouched. To force rebuilding packages, also remove the `debian/` directories from source packages or delete built `.deb` files.

---

## 8. Troubleshooting

### Package published but not visible to APT

Always re-export:

```bash
reprepro -b /srv/aptrepo export
sudo apt update
```

---

### Version mismatch in upstream package.xml

Sometimes upstream versions need nudging:

```bash
sed -i \
  's/<version>1.3.1<\/version>/<version>1.3.2<\/version>/' \
  ~/ros2_jazzy/ros2_base/src/eProsima/foonathan_memory_vendor/package.xml
```

---

### “Do we need these packages installed on the host?”

No — **not for building**.

The following packages are **runtime tools**, not required on the host when using `sbuild`:

```bash
ament-cmake
ament-cmake-copyright
ament-cmake-cppcheck
ament-cmake-cpplint
ament-cmake-flake8
ament-cmake-googletest
ament-cmake-lint-cmake
ament-cmake-pep257
ament-cmake-uncrustify
ament-cmake-xmllint
ament-lint
librcpputils-dev
```

`sbuild` installs everything it needs **inside the chroot**.

---

## 9. Mental model (important)

Think in passes:

> “Given what is currently published in APT, what can be built now?”

Failures due to missing dependencies are **expected and correct**.
The system converges automatically.

---

## Summary

You now have:

* a signed local ROS APT repo
* clean, reproducible Debian builds
* automatic dependency resolution
* a workflow that mirrors Debian + ROS build farms

This is the *right* way to build ROS on Debian Trixie.

If you want next steps, good follow-ons are:

* splitting repo into `staging → stable`
* switching from `file:` to HTTP
* migrating to `unshare` later
* CI automation
