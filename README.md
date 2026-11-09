# PowershellStorageManagement
Tool for managing storage on Windows desktop/server

`storage-maint` script

- With no switches it's **read-only**: free space, the drive model and type, and (when elevated) `Optimize-Volume -Analyze`.
- `-Optimize`, `-ComponentCleanup` (plus `-ResetBase`) and `-DiskCleanup` can be combined. Each run prints free space before and after.
- Without admin it refuses the changing switches and exits 1, so nothing half-runs.
- `-Drive D` works on another drive. DISM and Disk Cleanup always work on the Windows drive.
