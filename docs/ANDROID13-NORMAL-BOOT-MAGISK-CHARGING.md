# S108 / W527 Android 13 — Normal-Boot Magisk Root and Powered-Off Charging

**Confirmed October 29, 2026:** one XTQ S108 / W527 / Unisoc UWS6152 running crDroid Android 13 and Magisk 30.7.

> **Advanced, device-specific firmware work.** This documents a successful **migration from an existing Android 13 recovery-root environment**. It is **not** a universal one-click rooting guide or a downloadable set of interchangeable signed firmware images. Different S108 variants may use different kernels, partition tables, signing keys, AVB chains, and loaders. Incorrect flashing can permanently impair boot and may require difficult BootROM repair.

## Verified result

**Magisk 30.7 runs from the normal boot partition**, with root surviving **two consecutive normal reboots** (Stage7S). The persistent recovery boot command was cleared from misc. The user subsequently confirmed **powered-off charging works without launching Android**. The formerly working recovery partition was kept unchanged as a fallback.

No deliberate writes to recovery, system, vendor, userdata, modem/NV, or U-Boot were made during the successful normal-root installation.

## Why recovery-root was needed originally

This legacy system-as-root (SAR) S108 originally used a **boot partition with zero ramdisk bytes** and a kernel argument containing **skip_initramfs**. The first working Magisk root was installed in **recovery**, with a persistent **boot-recovery** command in misc forcing recovery-root startup. It worked for root but interfered with the watch's charging-only startup path.

The working normal-root solution needed **four specific changes**:

1. **Kernel:** Replace the same-length string **skip_initramfs** with **want_initramfs** (only four changed bytes).
2. **Ramdisk:** Supply a **minimal, boot-specific Magisk 30.7 ramdisk**. Do **not** transplant the whole recovery ramdisk.
3. **AVB:** Authenticate the modified boot image with a valid **boot child signature** and matching **parent vbmeta**, while preserving the separate **Unisoc DHTB-wrapped vbmeta_bak** format.
4. **Boot mode:** Once the normal root configuration has been **successfully tested**, clear only the **13 bytes** spelling **boot-recovery** in misc, preserving every other byte in the full 1 MiB image.

## Proof through controlled experiments

| Test | Boot image | Result |
| --- | --- | --- |
| Stage7P | Stock kernel; no ramdisk | Normal Android 13 booted, no Magisk; previous recovery-root restored |
| Stage7Q | Four-byte patched kernel; no ramdisk | Normal Android 13 booted, no Magisk; previous recovery-root restored |
| Stage7R | **Same patched kernel plus minimal Magisk ramdisk** | **Normal Android 13 + Magisk root succeeded**; original recovery-root restored after proof |
| Stage7S | Exact Stage7R candidate made permanent | **Normal Android 13 + Magisk 30.7 on two consecutive reboots** |
| Charging test | Stage7S permanent normal root | **Charging while switched off succeeded, without starting Android** |

Earlier experiments with a **full recovery-derived ramdisk** hung at the Noemie logo. These controls show that the kernel patch itself was not the failure; the minimal boot ramdisk worked. They do not prove which individual recovery file caused the earlier hangs.

## Required preparation

This procedure assumes Android 13 is **already running rooted**, or another proven privileged entry point is available. It does **not** take a stock Android 9 watch directly to rooted Android 13.

- Identify the exact board, firmware, Android build and partition layout. **Never use S100 images on an S108**.
- Back up and hash-check **same-device** full **boot (35 MiB), recovery (40 MiB), vbmeta (1 MiB), vbmeta_bak (1 MiB), and misc (1 MiB)** before any change. Keep these backups private.
- Establish an **independently tested BootROM recovery path** with correct signed FDL1/FDL2, original GPT/partition XML and compatible flasher before writing. See [S108 Android 13 BootROM rescue](ANDROID13-BOOTROM-UNBRICK.md). On our device **LEFT/BACK while reconnecting USB** entered BootROM, and the x86 native SPRD flasher worked with the Windows driver. Other variants may differ.
- Verify both **boot child** and **parent vbmeta** public keys match the available private signing material. On this unit a recovered private key matched the current recovery **and boot** child keys, while its parent vbmeta used the matching AOSP test signing key. These are **not assumed universal**.
- Check battery, SHA-256, AVB signatures, the backup DHTB wrapper, device-specific partition mapping, and recovery toolchain. **Stage and verify all rollback images on the watch before the first firmware write.**

**Never upload private signing keys, original signed loaders, IMEI/serial, calibration/NV, private GPT backups, userdata, or personal crash logs to this public repository.** No boot images, private keys, or device-specific flash packages are distributed here.

## Reproduce the minimal Magisk ramdisk offline

The **successful Stage7R ramdisk** was a newc CPIO gzip with these entries only:

~~~text
dev/
proc/
sys/
data/
.backup/
overlay.d/
overlay.d/sbin/
init                        Magisk 30.7 magiskinit ELF, mode 0750
.backup/.magisk             Magisk config
overlay.d/sbin/magisk.xz
overlay.d/sbin/stub.xz
overlay.d/sbin/init-ld.xz
~~~

It **did not** include recovery init.rc, sbin/recovery, sbin/charger, other recovery files, or a backup init executable.

The **tested** config was:

~~~ini
KEEPVERITY=true
KEEPFORCEENCRYPT=true
RECOVERYMODE=true
VENDORBOOT=false
PREINITDEVICE=cache
SHA1=<your own original boot hash saved by Magisk>
~~~

**Important:** The working ramdisk used **RECOVERYMODE=true despite booting normally**. For the Magisk 30.7 legacy-SAR path on this S108, this setting affected Magisk's early-init selection; it did not force the bootloader into recovery. Do not generalize that config to other devices, and do not invent PREINITDEVICE or SHA1 values.

The public [offline-only CPIO builder](../scripts/Build-S108-Minimal-Magisk-Ramdisk.py) takes five files **extracted from your own compatible Magisk installation**. Example (one line in PowerShell or your terminal, after cloning this repository):

~~~powershell
python scripts/Build-S108-Minimal-Magisk-Ramdisk.py --magiskinit inputs/init --magisk-xz inputs/magisk.xz --stub-xz inputs/stub.xz --init-ld-xz inputs/init-ld.xz --config inputs/config --output minimal-boot-ramdisk.cpio.gz
~~~

It builds **only the compressed ramdisk**: it does **not** alter boot, create AVB signatures, flash, or contain private keys.

We retested the published builder offline with the actual verified source Magisk artifacts and reproduced the **exact ramdisk bytes inside the successful Stage7R/7S boot image**:

| Property | Test-unit reference |
| --- | --- |
| Uncompressed newc CPIO | 427,788 bytes |
| Compressed gzip ramdisk | **340,416 bytes** |
| Gzip SHA-256 | **17d00926fd2f84aca81ebae44c0d5a54f77380b4d94ae34dbaa0e37ae7a5fe12** |
| Magiskinit ELF SHA-256 | **383670a7ba3a6a4b79e5f3467e1da4b66a5df66a9b356ab9f70916854dd6b468** |

These SHA values are **provenance for this specific unit**, not universal requirements.

## Build and authenticate a normal boot image

**This section describes the verified engineering sequence, not a safe blind-flash command.** In addition to the builder, you need correct device-specific Android boot packaging and AVB signing tools, trusted matching keys, and a tested rollback procedure.

1. Start from the **verified original boot image of the same physical watch**. Patch exactly the four kernel bytes for **skip_initramfs → want_initramfs**, preserving all other kernel/header data. The **Stage7Q kernel-only normal boot** was tested before attempting root.
2. Add the generated gzip ramdisk at the correct page-aligned boot ramdisk location and set the Android boot header's **ramdisk size** to the actual length. Preserve the device-specific image layout and the full partition size. On the tested image the ramdisk began at **byte 17,385,472**; do not hardcode that offset elsewhere.
3. Recompute the **AVB boot hash descriptor** across the signed payload; retain descriptor salt, algorithm and partition name. Sign the boot child AVB with the **verified matching child private key** and validate its public key, signature, footer, offset and payload digest.
4. Verify that **parent vbmeta** chains to that child key. If you change child keys, the parent must be updated and re-signed with an appropriate trusted key. On our unit the same already-trusted child key was used so its parent remained valid.
5. Independently validate/build **vbmeta_bak**, including its Unisoc **DHTB** structure. It is **NOT** a byte-for-byte copy of primary vbmeta. Copying primary directly over backup previously contributed to a no-boot condition.
6. Verify all new full-image hashes and signatures **offline**, verify staging on the watch, and verify partition writes by full readback. **Never proceed** if key, image, padding, signature, or partition hashes disagree.

The public repository intentionally contains **no signed boot/vbmeta files or one-command generic flasher**. The private proven flash/rescue workflow depends on precise per-watch signing and FDL/GPT artifacts; reusing its raw images on other watches is not safe.

## Controlled test, permanent installation and rollback

**First, proof (Stage7R).** While the known-good recovery-root request was still present, flash and readback-check matching **boot, vbmeta, and vbmeta_bak**, then reboot and verify the old recovery-root still works. Only then clear the **13-byte misc recovery command** and attempt **one normal boot**. Verify Android 13, boot-completed, Magisk 30.7, and **su returning uid=0**. The Stage7R test then returned to recovery and restored all five baseline partitions, preserving a known-good starting point.

**Then, permanence (Stage7S).** Using the **identical signed Stage7R images** already proven on the watch, stage and hash-check all four candidate and rollback images, then write/readback-check **boot, vbmeta, vbmeta_bak, and misc**. Confirm rooted normal Android after **two successive reboots**, all five full partition hashes checked each time. **Do not restore** the old recovery BCB after a successful permanent installation; recovery itself remains untouched.

**Misc caution:** The tested normal-root misc image was byte-for-byte identical to the old 1 MiB misc **except for the first 13 bytes** previously containing **boot-recovery**. **Do not erase the misc partition**, clear unrelated fields, or use a misc image from another watch.

### Read-only post-install check

With authorized ADB:

~~~powershell
adb shell getprop ro.build.version.release
adb shell getprop sys.boot_completed
adb shell magisk -v
adb shell su -c id
~~~

The tested outputs were Android **13**, boot completion **1**, Magisk **30.7**, and **uid=0(root)**. These are useful checks but do not replace the **two-normal-reboot** and full partition-readback verification.

### Charging check

Once permanent normal root is confirmed, fully **power off**, then connect charging power. On the tested S108, the **charging screen appeared and Android stayed off**. USB already connected before shutdown may behave differently. Do not confuse this with charging while Android/ADB is running.

### If something fails

- **Noemie hang/no ADB:** stop, do **not** rerun an interrupted flash. Use the exact known-good, independently validated BootROM/FDL rescue and original backups; see [unbrick case study](ANDROID13-BOOTROM-UNBRICK.md). A physical LEFT/BACK reconnection may be needed; BootROM repair is not guaranteed.
- **ADB returns but no root:** use a guarded rollback to the old recovery-root boot/AVB/misc set and verify original hashes.
- **Charging still starts Android:** confirm the **recovery BCB request** is actually absent. Never blindly rewrite misc or recovery charger services.
- **LiteGapps Play Store crash:** on our unit, an updated Play Store APK repaired the missing original Phonesky path. It was a separate problem, not evidence of failure of Magisk normal root; see [Google Play notes](ANDROID13-GOOGLE-PLAY.md).

**Final tested state, October 29, 2026:** Android 13, **permanent Magisk 30.7 normal boot**, untouched working recovery image, and **powered-off charging**. Independent reproductions and sanitized reports are welcome.
