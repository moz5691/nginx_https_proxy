# NGINX HTTPS Forwarding Proxy

## HTTPS Forwarding Proxy with HTTP CONNECT
Most use of NGINX is probably for reverse proxies than forwarding proxies.   When NGINX is set for a reverse proxy, the reverse proxy handles termination of HTTPS encrypted traffic and forwards descrypted traffic to the target server.   

However, when NGINX is configured as an HTTPS forwarding proxy to process the traffic from the client, the NGINX proxy server cannot see the target URL as the traffic from the client is encrypted by TLS (in Session layer). 

One way to solve this problem is using ```HTTP CONNECT``` request by the client to set up an ```HTTP CONNECT``` tunnel between the client and the NGINX proxy server.   The key is that  ```HTTP CONNECT``` request by the client must specify the target's host and port that the client needs to access.  It means the NGINX forwarding proxy server will just have the target's host and port from the client without digging in the traffic.

The following is a good example of how the HTTPS forwarding proxy works in general and is almost identical to the NGINX Docker in here.  

![](https://parsiya.net/images/2016/thickclient-6/08.png)
Picture Source: https://parsiya.net/blog/2016-07-28-thick-client-proxying-part-6-how-https-proxies-work/


## Usage

### 1. Edit whitlist domains in nginx.conf/nginx_whitelist.conf
Domains not in the following will be denied with 400 error.
You must add the target server's domain in the following whitelist.
```sh
    # Whitelist google.com, httpbin.com, github.com
    server {
        listen 443;
        resolver 8.8.8.8 ipv6=off;
        server_name  google.com;
        server_name  *.google.com;
        server_name  httpbin.org;
        server_name  *.httpbin.org;
        server_name  github.com;
        server_name  *.github.com;
```


### 2. Bring up Docker 
```sh
docker-compose up -d
```

### 3. Test with CURL 
```sh
curl -X GET "https://google.com" -v -x http://127.0.0.1:443  
Note: Unnecessary use of -X or --request, GET is already inferred.
*   Trying 127.0.0.1:443...
* Connected to 127.0.0.1 (127.0.0.1) port 443 (#0)
* allocate connect buffer
* Establish HTTP proxy tunnel to google.com:443
> CONNECT google.com:443 HTTP/1.1
> Host: google.com:443
> User-Agent: curl/7.84.0
> Proxy-Connection: Keep-Alive
> 
< HTTP/1.1 200 Connection Established
< Proxy-agent: nginx
< 
* Proxy replied 200 to CONNECT request
* CONNECT phase completed
* ALPN: offers h2
* ALPN: offers http/1.1
*  CAfile: /etc/ssl/cert.pem
*  CApath: none
* (304) (OUT), TLS handshake, Client hello (1):
* (304) (IN), TLS handshake, Server hello (2):
* (304) (IN), TLS handshake, Unknown (8):
* (304) (IN), TLS handshake, Certificate (11):
* (304) (IN), TLS handshake, CERT verify (15):
* (304) (IN), TLS handshake, Finished (20):
* (304) (OUT), TLS handshake, Finished (20):
* SSL connection using TLSv1.3 / AEAD-CHACHA20-POLY1305-SHA256
* ALPN: server accepted h2
* Server certificate:
*  subject: CN=*.google.com
*  start date: Oct 17 08:16:44 2022 GMT
*  expire date: Jan  9 08:16:43 2023 GMT
*  subjectAltName: host "google.com" matched cert's "google.com"
*  issuer: C=US; O=Google Trust Services LLC; CN=GTS CA 1C3
*  SSL certificate verify ok.
* Using HTTP2, server supports multiplexing
* Copying HTTP/2 data in stream buffer to connection buffer after upgrade: len=0
* h2h3 [:method: GET]
* h2h3 [:path: /]
* h2h3 [:scheme: https]
* h2h3 [:authority: google.com]
* h2h3 [user-agent: curl/7.84.0]
* h2h3 [accept: */*]
* Using Stream ID: 1 (easy handle 0x13180a800)
> GET / HTTP/2
> Host: google.com
> user-agent: curl/7.84.0
> accept: */*
...
... <response header and data>
...
```

### 4. Explain the logs from CURL in 3. 

(1) The client sends an HTTP CONNECT request to NGINX forwaring proxy sever.  The NGNIX forwarding proxy server uses the host and port information in the HTTP CONNECT request which is used to establish a TCP connection with the target server.  

(2) The NGINX proxy server returns an HTTP 200 response to the client.

(3) The client establishes an HTTP CONNECT tunnel with the targer server throuhg the NGINX forwarding proxy sever.

(4) The client sends HTTPS traffic to the NGINX proxy server.  The NGINX proxy server only transparently transmits HTTPS traffic to the target server (i.e. google.com) without any modification or decryption of the traffic.

(5) The reverse direction is the same as (4).  The response HTTPS traffic is also transmitted to the client without any modification.



```
   CURL                      NGINX (forwarding_https_proxy)      GOOGLE.COM
    |                                  |                             |
(1) |---- CONNECT google.com:443  ---->|                             |
    |                                  |                             |
    |                                  |------[ TCP connection ]---->|
    |                                  |                             |
(2) |<-----  [ HTTP/1.1 200 ]  --------|                             |
    |   Connection Established         |                             |
    |                                  |                             |
    |                                  |                             |
    |=========== (3) CONNECT tunnel has been established. ===========|
    |                                  |                             |
    |                                  |                             |
    |                                  |                             |
    |     [ TLS stream       ]         |                             |
(4) |-----[ GET   / HTTP/1.1 ]-------->|     [ TLS stream       ]    |
    |     [ Host: google.com ]         |-----[ GET   / HTTP/1.1 ]--->|
    |                                  |     [ Host: google.com ]    |
    |                                  |                             |
    |                                  |                             |
    |                                  |                             |
    |                                  |     [ TLS stream       ]    |
    |     [ TLS stream       ]         |<----[ HTTP/1.1 200 OK  ]----|
(5) |<----[ HTTP/1.1 200 OK  ]---------|     [ < response data >]    |
    |     [ < response data >]         |                             |
    |                                  |                             |
```

