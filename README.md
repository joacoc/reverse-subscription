# Reverse subscription

An OpenResty (Nginx) reverse proxy and backend for Materialize Cloud.

Features:

* Run queries or subscriptions
* Hide Materialize address and credentials
* Custom Authorization (WIP)
* Reuse JWT fields in SQL

## Steps

1. Clone the repository.
2. Set your config in `config.sh`
```bash
# Replace with your config
USER="<MATERIALIZE_USER>";
PASSWORD="<MATERIALIZE_PASSWORD>";
AUTHORIZATION="<MATERIALIZE_BASIC_AUTH>";
MATERIALIZE_IP="111.111.111.111";
QUERIES="{
    sub = \"SELECT $1 as sub\",  <- The backend will replace $1 with the JWT sub field.
    metrics = \"SELECT * FROM mz_internal.mz_cluster_replica_metrics\",
    a = \"mz_internal.mz_cluster_replica_metrics\"
}"
```
3. Run `config.sh`:
```bash
chmod +x config.sh

./config.sh
```
4. Build the image:
```bash
docker build -t reverse-materialize .
```
5. Run `docker-compose`:
```bash
docker run --rm \
           -it \
           -e JWT_SECRET=secret \
           -v `pwd`/nginx.conf:/nginx.conf \
           -v `pwd`/bearer.lua:/bearer.lua \
           -p 8080:8080 \
           reverse-materialize
```
6. Check using `curl`:
```bash
curl localhost:8080/?query=sub -I \
   -X POST \
   -H "Accept: application/json" \
   -H "Authorization: Bearer <TOKEN>"
```
7. Check using `websocat`:
```bash
websocat 'ws://localhost:8080/subscribe?query=metrics&token=<token>'
```

### Based

The project uses `ubergarm/openresty-nginx-jwt` as a base.