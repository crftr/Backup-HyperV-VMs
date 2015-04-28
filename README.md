Backup-HyperV-VMs
=========

Powershell offers convenient cmdlets to archive live Hyper-V instances with no interruption.  These scripts are wrappers around the basic cmdlets to quickly implement a simple backup strategy.

By default, 2 weekly and 2 monthly VM backups are retained.

## Compatibility
These scripts have only been tested on servers with Powershell 3.0+.  The Hyper-V module should also be available.