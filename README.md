
# Simple SMTP server

This is a simple smtp server that accepts authentication 

```
docker build -t kmarji/smtp-server .
```
```
docker run -d --rm \
  --name postfix-relay \
  -p 25:25 \
  -e SMTP_USER=user \
  -e SMTP_PASSWORD=pass \
  -e MYHOSTNAME=mail.your-domain.com \
  -e MYDOMAIN=your-domain.com \
  -e MYNETWORKS="127.0.0.0/8 192.168.1.0/24" \
  kmarji/smtp-server
```


