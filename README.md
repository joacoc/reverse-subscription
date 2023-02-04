# Reverse subscription
An OpenResty (Nginx) reverse proxy and backend for Materialize.

<img width="2212" alt="Nginx" src="https://user-images.githubusercontent.com/11491779/216778976-714b0737-7ce1-45fd-b484-088a7e3db172.png">

## Features

* Run queries or subscriptions
* Hide Materialize address and credentials
* Custom Authorization (WIP)
* Reuse JWT fields in SQL (WIP)

## Steps

1. Clone the repository.
2. Set your config in `config.sh`
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
