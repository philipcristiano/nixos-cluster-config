# Telegraf

System and application collection and forwarding

Multiple Telegraf jobs are used

* `system` - runs as a system job on all Nomad clients, collecting system metrics
* `dc` - Single service job collecting metrics from Consul
* `influxdb-input` - Single service job hosting a `influxdb` service as a place to send metrics to from applications
* `prometheus` - Single service job for scraping `prometheus` tagged Consul services

All jobs forward to the Mimir service in the cluster
