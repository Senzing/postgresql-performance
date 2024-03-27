# Changelog (substantial only)
* (Mar 27, 2024) Documented new system
* (Jan 1, 2023) all testing moving forward leverages the sz_rabbit_consumer and sz_simple_redoer at https://github.com/brianmacy
* (Jan 1, 2023) moved RabbitMQ to it's own box with a faster CPU (i5-13600) since RabbitMQ is single thread performance centric.  This increased publish speeds from about 5k/s to 17k/s which is useful when re-running the same records.

# Overview
The performance system leverages 4 physical machines using a 10GE network and leverages docker-compose to orchestrate with RabbitMQ 3.x and PostgreSQL 14/16.  It also leverages a shared NAS for docker-compose yaml and shell scripts.

 - (1) Infrastructure servers for RabbitMQ, kibana, and loading JSON data into RabbitMQ
 - (2) Processing servers running consumers and redoers
 - (1) Database server running PostgreSQL 14 or 16

Only the DB server needs flash storage.  All systems are running Ubuntu Server 22.04 or newer.

*I regularly test load real-world datasources of >1B records in 8-10 days with a bufferpool of 384GB RAM.*
* RAID 6 is used on data to artificially limit write IO performance. *


# Specifications

## Infrastructure Server
 - Custom 2U
 - Intel i5-13600
 - 128GB RAM

## Process Server
 - PowerEdge R650XS
 - Intel Xeon Gold 6326 Processor 2x (32 cores, 64 threads)
 - 480GB M.2 SATA Solid State Drive [QTY : 2]
 - 32GB RDIMM, 3200MT/s, Dual Rank [QTY : 16]
 - Broadcom 57412 Dual Port 10GbE SFP+, OCP NIC 3.0

## Database Server
 - Supermicro X13DEM
 - (2) Intel Xeon Gold 6438Y+ Processor
 - (16) 64GB DDR5-4800 2Rx4 ECC RDIMM
 - (2) Micron 7450 PRO 1.9TB NVMe PCIe 4.0 M.2 22x110mm 3D TLC
 - (20) Micron 7450 PRO 1.9TB NVMe PCIe 4.0 3DTLC U.3 15mm,1DWPD
 - (1) GRAID RAID Lic, MUST bundle NVD A2000 GPU
 - (1) NVIDIA PNY Quadro RTX A2000 6 GB GDDR6 PCIe 4.0
 - (1) AIOM Dual-Port 10GbE SFP+,b/ on X710-BM2
 -  HW RAID 6 (data), HW RAID 1 (logs), LUKS encryption (4k sectors), ext4
