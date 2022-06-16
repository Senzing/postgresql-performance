#Overview
The performance system leverages 5 physical machines using a 10GE private network and leverages docker-compose to orchestrate with RabbitMQ 3.9 and PostgreSQL 14.  It also leverages a shared NAS for docker-compose yaml and shell scripts.

 - (1) Infrastructure server for RabbitMQ, the redoer process, and loading JSON data into RabbitMQ
 - (3) Processing servers running stream-loader
 - (1) Database server running PostgreSQL 14

Each node does have 1TB of NVMe local but only the DB server needs flash storage.  All systems are running Ubuntu Server 20.04.

*I regularly test load real-world datasources of between 400M-500M records in 3-4 days with a bufferpool of 100GB RAM in order to intentionally become IO bound.*


#Specifications

##Infrastructure Server
 - Dell R820
 - (4) Intel(R) Xeon(R) CPU E5-4620 0 @ 2.20GHz
 - 256GB RAM

##Process Server
 - Dell R820
 - (4) Intel(R) Xeon(R) CPU E5-4650 0 @ 2.70GHz
 - 256GB RAM

##Database Server
 - Intel server (B888G4 motherboard)
 - (2) Intel(R) Xeon(R) Gold 6252 CPU @ 2.10GHz
 - 1.5TB RAM
 - 7T NVMe (4 Optane + 4 Samsung 980 Pro)
 - -  mdraid 0, LUKS encryption, ext4

