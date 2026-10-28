# S108 / W527 Android 13: BootROM unbrick and recovery restoration (tested case)

> **Advanced, high-risk, device-specific recovery.** This documents **one XTQ S108 / W527 Unisoc UWS6152** running Android 13 / crDroid and Magisk 30.7 recovery-root, October 27–28, 2026. This is **not** a universal firmware package, a safe one-command repair, or proof that another S108/W527 variant has compatible signed loaders, partitions, or images.
>
> **Minimize magnetic-USB reconnections.** The watch's cable/contacts were intermittent; repeatedly disconnecting added risk. When feasible, combine essential preflight, writes, and readbacks into **one FDL2 session**. Never disconnect during a partition write or repartition.

## Verified outcome and limitations

After restoring the previously working recovery/AVB configuration, **the watch started booting Android again**. The final independent read-only BootROM check failed *during FDL2 transfer*, before it could read the restored partitions. Android reaching the home screen and long-term stability were **not independently documented** in these rescue logs.

The successful, hash-verified work:

- **Stage 6K:** A complete **40 MiB Stage 5B recovery** write was acknowledged and independently read back **in the same session** in **10 × 4 MiB segments**; all ten SHA-256 comparisons matched.
- **Stage 6L:** Both **1 MiB AVB** partitions (vbmeta and vbmeta_bak) and the **original 1 MiB misc** were written and read back with exact SHA-256 matches. The recovery header matched too.
- **Stage 6I/6J:** The original **42-entry partition layout** was repaired after a temporary alias persisted. An **independent BootROM connection** confirmed the recovery name was back.
- There was **no full Android reflash and no intentional userdata wipe**.

This case does **not** establish which individual problem caused the no-boot state. The experimental Stage 5M recovery/AVB change was the initial trigger, but the earlier partition-name and boot-mode changes were also reversed before the successful boot attempt.

## What went wrong

1. The S108 was working with Android 13 and the earlier **Stage 5B** Magisk-patched recovery.
2. An experimental **Stage 5M** modification for offline charging changed recovery/AVB. Afterward the watch would not boot normally.
3. Repeated normal recovery writes failed or ended unsuccessfully, sometimes near the end of the 40 MiB transfer.
4. A newer flasher supported **w_force**, which can temporarily rename the selected GPT partition during a write. However, its **x64 Release** build could not open the PC's installed **SPRD U2S Diag COM14** interface.
5. The **x86 Release** build of the newer flasher worked with that Windows SPRD driver and completed BootROM, signed FDL1/FDL2 initialization, reads, and the eventual forced writes.
6. An earlier interrupted w_force operation left the 40 MiB recovery partition named **w_force** in GPT. The original partition layout had to be restored before the final recovery write.

## Windows USB driver / flasher compatibility

The tested Windows machine exposed the watch through **SPRD U2S Diag, COM14**.

| Executable | Observed result |
| --- | --- |
| Older stable native Windows SPRD spd_dump | Successfully established BootROM → signed FDL1 → FDL2 and read misc / GPT |
| Newer **x64 Release** build (libusb interface) | Failed before BootROM handshake: connection failure / libusb_open_device failed |
| Newer **x86 Release** build (native SPRD interface; supports w_force) | Successfully connected, read partitions, and completed Stage 6K and 6L writes/readback |

Upstream: [TomKing062/spreadtrum_flash](https://github.com/TomKing062/spreadtrum_flash) and [releases](https://github.com/TomKing062/spreadtrum_flash/releases). Check the exact version, Windows driver interface and supported commands; do not blindly change drivers or use the x64 binary against an existing COM-port-only setup.

The phrase **Waiting for dl_diag connection** is a generic message in the tool, including normal BootROM operations. The decisive progress was **CHECK_BAUD bootrom → CMD_CONNECT bootrom → EXEC FDL1 → EXEC FDL2**. Transient messages such as **CHECK_BAUD FAIL** at the transition, **FDL2: incompatible partition**, and **unexpected response (0x00fe)** also appeared in sessions that subsequently read and wrote successfully; check the entire sequence and confirmed result rather than assuming those isolated lines are fatal.

## Required preflight: exact-device backups

Before any write, preserve and verify local copies from the **same physical device and known-working configuration**:

- Tested signed **FDL1 and FDL2** files. In this case their load addresses were **0x5500** (FDL1) and **0x9efffe00** (FDL2). Neither address nor the loaders should be assumed to work on a different W527.
- A previously booting recovery (Stage 5B here) with its matching vbmeta and vbmeta_bak.
- A full original **misc** from before any bootonce-bootloader / BCB probe.
- A pre-modification **GPT capture and original partition XML**. Validate all 42 entries, names, order and sizes. Never borrow another device's layout.
- Separate boot-chain/Android/modem/NV backups where available; keep device identifiers, calibration data and userdata **private**.

Reference SHA-256 hashes from this *one unit* (provenance only, **not universally compatible files**):

| Local reference image | SHA-256 |
| --- | --- |
| Working Stage 5B recovery, 40 MiB | 5df1ae0addd0a1cceaec1b99293ff7867b63682701b968a3f98cafa58c5c93c5 |
| Matching vbmeta, 1 MiB | 85f46101d1696c0cf64b51c5f0d0046f77d2e145f01414d4f5131ed073d72b60 |
| Matching vbmeta_bak, 1 MiB | 04aa6691f1a930d4ca8b8aefbac7be8bceb5081c6bab49be6f11efeda78a7d29 |
| Original misc backup, 1 MiB | 1f9de044a95c443ed583ce79075b0329114395436645802e919b51ce4dc12aa9 |
| Pre-modification 32 KiB GPT readback | 753575b78dc4e1e2a6b132fb7480924936f14b51ca7f82aa2668c8b45965726a |

**No recovery, AVB, signed loader, NV, or userdata images are distributed in this repository.** This document is a case study, not a source of firmware for another watch.

## Tested repair sequence

### A. Verify BootROM storage access without a write

On this unit the successful BootROM entry involved **holding LEFT/BACK while reconnecting the magnetic USB data cable**. A tested native-driver flasher connected to COM14, loaded the matching signed FDL1/FDL2, displayed the 42-partition table and completed a small read of misc.

A completed **Read Part Done** means the operation reached storage. A watch powering off when unplugged while the OS does not boot is not, by itself, a new firmware failure. Avoid additional reconnects solely to repeat already successful checks.

### B. Repair GPT *only if* recovery is renamed

A failed forced write had temporarily renamed entry **#3** (the recovery partition, 40 MiB) to **w_force**. The newer tool warned:

~~~text
w_force self-repair: cannot determine original name at partition #2
~~~

The #2 wording is from the tool's zero-based internal index. On the watch's enumerated partition list, this is **partition #3**, originally **recovery**.

The tested Stage 6I operation used the **original device-specific 42-entry XML** and the tool's **repartition** operation to restore the expected names/sizes. Stage 6J then performed a **fresh read-only BootROM session** and independently confirmed normal partition names, including **recovery**, without a lingering w_force entry.

**Critical:** repartition is a high-risk GPT write. It can damage or erase the layout/data if the XML does not precisely match the device or the write is interrupted. **Never use generic XML; never repeat GPT repair if the current layout is already correct.**

### C. Restore the known-good 40 MiB recovery (Stage 6K)

After repairing GPT, one x86/native-driver BootROM/FDL2 session performed the following:

1. Checked the expected GPT layout and local file hashes.
2. Used **w_force recovery** with the **known-good Stage 5B image**, acknowledging temporary GPT renaming.
3. Received **Write Part Done: w_force, target: 0x2800000, written: 0x2800000** and **Force Write recovery Done**.
4. Explicitly restored the **original partition XML** afterward.
5. Read back **ten 4 MiB recovery chunks**, checking every chunk against the corresponding source SHA-256. **All ten matched.**
6. Exited the session normally.

**100% progress does not by itself establish success.** Require a completed write acknowledgment, restored partition names, and full byte/hash verification. If interrupted, inspect GPT before attempting any new write or normal boot.

### D. Restore AVB and the original misc (Stage 6L)

A separate one-connection session, **without rewriting recovery**, performed:

1. **w_force vbmeta** (1 MiB): completed and hash-verified.
2. **w_force vbmeta_bak** (1 MiB): completed and hash-verified.
3. Explicit **original GPT layout** restoration.
4. **write_part misc** using the original 1 MiB backup to undo an earlier bootloader/BCB probe.
5. Readback of both AVB partitions, misc, and the recovery header: **all exact SHA-256 matches**.

This is the known-good **recovery + paired AVB + original misc + correct GPT** configuration. No full Android/system reinstall was needed in the observed recovery.

### E. Final verification attempt and boot result

Stage 6M attempted an *independent read-only* verification after reconnecting the cable. It failed during **FDL2 transfer** with **timeout reached**, **before any partition read**.

Its script then printed several **MISMATCH** labels for absent files. These were **false classifications**: the proper status is **NOT READ / USB TRANSFER FAILED**, not a bad hash. The operator avoided another unnecessary BootROM connection and attempted a normal power-on; the watch **began booting again**.

There is no independent post-reboot hash verification from Stage 6M, but Stage 6K/6L same-session reads had already matched their source images.

## Lessons for rescue scripts

- **Minimize physical reconnects.** Do necessary preflight, writes, and same-session readback together where possible; avoid redundant separate check-only sessions when the magnetic contacts are unstable.
- **Verify PowerShell syntax, input files, exact-device firmware hashes and expected layout before connecting.**
- Display the flasher's **real native output live**, including COM selection, BootROM handshake, loader stages, writes, readbacks and exit status.
- Distinguish **pre-handshake connection failures** from partial writes. **Never blindly retry a potentially partial write.**
- After an interrupted **w_force**, inspect the GPT for a remaining **w_force** partition name.
- End noninteractive flasher command sequences with a real terminal command such as **poweroff** when supported; an earlier script omitted its exit and appeared stuck after completing reads.
- Do **not** label missing readback files **MISMATCH**. Use **NO READ / NOT VERIFIED** for a transfer that never reached the partition.
- Keep an original GPT/partition XML and the known-good recovery/AVB/misc together in private backups. **Do not publicly publish signed loaders, calibration/NV, modem identifiers, IMEI, or userdata.**
- After recovery boots, use **ADB/in-OS verification** where possible instead of reentering BootROM.

## Troubleshooting

| Symptom | Interpretation |
| --- | --- |
| Waiting for dl_diag connection | Generic message; monitor COM port and the BootROM handshake |
| New x64 libusb build fails while older flasher connects on COM14 | Likely build/driver interface mismatch; use the appropriate native-driver build |
| usb_send failed immediately after COM connection | Could be magnetic USB, driver or port instability; do not presume any partition write |
| w_force self-repair cannot determine original name | Inspect GPT; temporarily renamed partition may require original-device partition XML |
| Write Part Done / Force Write Done | Write acknowledged; still verify hash/readback and GPT names |
| Timeout while sending FDL2 | No partition read was completed; a subsequent missing file is not a hash mismatch |
| Script hangs after final Read Part Done | Missing interactive exit command is possible; confirm no write/repartition remains in progress before stopping it |

## Community use and scope

This page documents **observed technical evidence**, not a universally tested or turnkey recovery script. It involves flash and GPT operations that can destroy data or permanently impair another variant. For bug reports include the exact S108 variant/build, relevant flasher version and Windows driver, the last confirmed BootROM/FDL stage, and redacted logs. **Never include personal or device-unique data.**
