# Changelog (substantial only)
* (Jan 1, 2023) all testing moving forward leverages the sz_rabbit_consumer and sz_simple_redoer at https://github.com/brianmacy
* (Jan 1, 2023) moved RabbitMQ to it's own box with a faster CPU (i5-13600) since RabbitMQ is single thread performance centric.  This increased publish speeds from about 5k/s to 17k/s which is useful when re-running the same records.

# Overview
The performance system leverages 5 physical machines using a 10GE private network and leverages docker-compose to orchestrate with RabbitMQ 3.9 and PostgreSQL 14.  It also leverages a shared NAS for docker-compose yaml and shell scripts.

 - (2) Infrastructure servers for RabbitMQ, the redoers, and loading JSON data into RabbitMQ
 - (3) Processing servers running consumers
 - (1) Database server running PostgreSQL 14

Each node does have 1TB of NVMe local but only the DB server needs flash storage.  All systems are running Ubuntu Server 22.04.

*I regularly test load real-world datasources of between 400M-500M records in 3-4 days with a bufferpool of 100GB RAM in order to intentionally become IO bound.*


# Specifications

## Infrastructure Server
 - Custom 2U
 - Intel i5-13600
 - 128GB RAM

## Process Server
 - Dell R820
 - (4) Intel(R) Xeon(R) CPU E5-4650 0 @ 2.70GHz
 - 512GB RAM

## Database Server
 - Intel server (B888G4 motherboard)
 - (2) Intel(R) Xeon(R) Gold 6252 CPU @ 2.10GHz
 - 1.5TB RAM (bufferpool at 384GB hugepages)
 - 20T NVMe (4 Optane + 8 Samsung 9xx mixed 970/980)
 - -  mdraid 0, LUKS encryption (4k sectors), ext4
