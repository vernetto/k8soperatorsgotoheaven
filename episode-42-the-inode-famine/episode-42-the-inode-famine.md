# Episode 42 — "The Inode Famine"
### *Inspector Ahmed and the disk that's full but isn't*

**Culprit:** Inode exhaustion — disk has space but can't create new files
**Difficulty:** ⭐⭐⭐ Advanced
**Tags:** `inodes` `disk` `ephemeral-storage` `eviction` `filesystem`

---

## OPENING — Crime scene

"The node showed DiskPressure. But `df -h` showed 40% disk usage. Plenty of space. Yet pods were being evicted. Yet new files couldn't be created. The disk was full — of something invisible."

```bash
kubectl describe node node-3 | grep DiskPressure
```

```
DiskPressure    True    KubeletHasDiskPressure
```

```bash
# SSH to node-3
df -h /
```

```
Filesystem      Size  Used Avail Use%
/dev/sda1        50G   20G   30G  40%
```

40% used. 30 GB free. But evictions are happening. Ahmed checks inodes:

```bash
df -i /
```

```
Filesystem     Inodes  IUsed  IFree IUse%
/dev/sda1      3276800 3276799     1  100%
```

**100% inode usage.** Zero inodes free. The disk has space — but no inode slots to create new files or directories. Every filesystem operation that creates a new file fails.

> **📚 Teaching moment — Inodes**
>
> Every file and directory on a Linux filesystem occupies an **inode** — a metadata entry tracking ownership, permissions, and data block pointers. The number of inodes is fixed at filesystem creation time (based on the `-i` parameter to `mkfs`).
>
> You can run out of inodes while having gigabytes of free space — if you have millions of tiny files. This causes the same symptoms as a full disk: no new files, no new containers, evictions.
>
> Common culprits: thousands of tiny log files, npm `node_modules` directories with millions of files, or a bug creating empty files in a loop.

---

## ACT II — Finding the inode hog

```bash
# Find the directory with the most files
find / -xdev -type f | awk -F'/' '{print NF, $0}' | sort -rn | head -20
```

That's slow. Ahmed uses a faster approach:

```bash
for dir in /var/lib/docker /var/log /tmp /home; do
  echo -n "$dir: "
  find $dir -xdev | wc -l
done
```

```
/var/lib/docker: 3100000
/var/log: 45000
/tmp: 120
/home: 3400
```

`/var/lib/docker` — 3.1 million files. Likely dangling Docker layers or overlay filesystem garbage from containers that weren't properly cleaned up.

```bash
docker system prune -a --volumes -f
```

Freed 2.8 million inodes. DiskPressure cleared. Evictions stopped.

---

## EPILOGUE

*"`df -h` shows space. `df -i` shows inodes. When DiskPressure exists but disk isn't full, always check inodes. The culprit is usually millions of tiny files in container overlay directories."*

> **Inspector Ahmed's Rule #42:** DiskPressure but disk looks fine? Run `df -i`. If inodes are at 100%, find the directory with the most files. Container overlay dirs are the usual suspect. `docker system prune` or `crictl` equivalent.
