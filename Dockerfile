# Use Alpine Linux as the base image
FROM alpine:3.19

# Install Postfix and SASL dependencies
RUN apk add --no-cache \
    postfix \
    cyrus-sasl \
    cyrus-sasl-login \
    cyrus-sasl-crammd5 \
    ca-certificates \
    libsasl

# Create necessary directories and files
RUN mkdir -p /var/spool/postfix && \
    mkdir -p /var/log/postfix && \
    mkdir -p /etc/sasl2 && \
    mkdir -p /var/run/saslauthd && \
    chown root:root /var/spool/postfix && \
    chmod 755 /var/spool/postfix && \
    touch /etc/sasldb2 && \
    chown postfix:postfix /etc/sasldb2

# Copy the Postfix configuration file
COPY main.cf /etc/postfix/main.cf

# Create SASL configuration
RUN echo "pwcheck_method: auxprop" > /etc/sasl2/smtpd.conf && \
    echo "auxprop_plugin: sasldb" >> /etc/sasl2/smtpd.conf && \
    echo "mech_list: PLAIN LOGIN" >> /etc/sasl2/smtpd.conf && \
    echo "log_level: 7" >> /etc/sasl2/smtpd.conf && \
    echo "sasldb_path: /etc/sasldb2" >> /etc/sasl2/smtpd.conf

# Create runtime configuration script
RUN echo '#!/bin/sh' > /usr/local/bin/docker-entrypoint.sh && \
    echo 'set -e' >> /usr/local/bin/docker-entrypoint.sh && \
    echo '' >> /usr/local/bin/docker-entrypoint.sh && \
    echo '# Check required environment variables' >> /usr/local/bin/docker-entrypoint.sh && \
    echo 'if [ -z "${SMTP_USER}" ] || [ -z "${SMTP_PASSWORD}" ]; then' >> /usr/local/bin/docker-entrypoint.sh && \
    echo '  echo "Error: SMTP_USER and SMTP_PASSWORD must be set"' >> /usr/local/bin/docker-entrypoint.sh && \
    echo '  exit 1' >> /usr/local/bin/docker-entrypoint.sh && \
    echo 'fi' >> /usr/local/bin/docker-entrypoint.sh && \
    echo '' >> /usr/local/bin/docker-entrypoint.sh && \
    echo '# Set default values for optional environment variables' >> /usr/local/bin/docker-entrypoint.sh && \
    echo 'MYHOSTNAME=${MYHOSTNAME:-"localhost.localdomain"}' >> /usr/local/bin/docker-entrypoint.sh && \
    echo 'MYDOMAIN=${MYDOMAIN:-"localdomain"}' >> /usr/local/bin/docker-entrypoint.sh && \
    echo 'MYNETWORKS=${MYNETWORKS:-"127.0.0.0/8"}' >> /usr/local/bin/docker-entrypoint.sh && \
    echo '' >> /usr/local/bin/docker-entrypoint.sh && \
    echo '# Create SASL user database' >> /usr/local/bin/docker-entrypoint.sh && \
    echo 'rm -f /etc/sasldb2' >> /usr/local/bin/docker-entrypoint.sh && \
    echo 'echo "${SMTP_PASSWORD}" | saslpasswd2 -p -c -f /etc/sasldb2 -u "${MYDOMAIN}" "${SMTP_USER}"' >> /usr/local/bin/docker-entrypoint.sh && \
    echo 'chown postfix:postfix /etc/sasldb2' >> /usr/local/bin/docker-entrypoint.sh && \
    echo 'chmod 644 /etc/sasldb2' >> /usr/local/bin/docker-entrypoint.sh && \
    echo '' >> /usr/local/bin/docker-entrypoint.sh && \
    echo '# List SASL users for verification' >> /usr/local/bin/docker-entrypoint.sh && \
    echo 'echo "SASL users:" && sasldblistusers2 -f /etc/sasldb2' >> /usr/local/bin/docker-entrypoint.sh && \
    echo '' >> /usr/local/bin/docker-entrypoint.sh && \
    echo '# Configure Postfix' >> /usr/local/bin/docker-entrypoint.sh && \
    echo 'postconf -e myhostname="$MYHOSTNAME"' >> /usr/local/bin/docker-entrypoint.sh && \
    echo 'postconf -e mydomain="$MYDOMAIN"' >> /usr/local/bin/docker-entrypoint.sh && \
    echo 'postconf -e mynetworks="$MYNETWORKS"' >> /usr/local/bin/docker-entrypoint.sh && \
    echo 'postconf -e smtpd_sasl_auth_enable="yes"' >> /usr/local/bin/docker-entrypoint.sh && \
    echo 'postconf -e smtpd_sasl_path="smtpd"' >> /usr/local/bin/docker-entrypoint.sh && \
    echo 'postconf -e smtpd_sasl_type="cyrus"' >> /usr/local/bin/docker-entrypoint.sh && \
    echo 'postconf -e smtpd_sasl_security_options="noanonymous"' >> /usr/local/bin/docker-entrypoint.sh && \
    echo 'postconf -e smtpd_sasl_local_domain="$MYDOMAIN"' >> /usr/local/bin/docker-entrypoint.sh && \
    echo 'postconf -e broken_sasl_auth_clients="yes"' >> /usr/local/bin/docker-entrypoint.sh && \
    echo 'postconf -e smtpd_recipient_restrictions="permit_mynetworks,permit_sasl_authenticated,reject_unauth_destination"' >> /usr/local/bin/docker-entrypoint.sh && \
    echo '' >> /usr/local/bin/docker-entrypoint.sh && \
    echo '# Show current Postfix SASL settings' >> /usr/local/bin/docker-entrypoint.sh && \
    echo 'echo "Postfix SASL settings:" && postconf -n | grep "sasl"' >> /usr/local/bin/docker-entrypoint.sh && \
    echo '' >> /usr/local/bin/docker-entrypoint.sh && \
    echo '# Initialize aliases database' >> /usr/local/bin/docker-entrypoint.sh && \
    echo 'newaliases' >> /usr/local/bin/docker-entrypoint.sh && \
    echo '' >> /usr/local/bin/docker-entrypoint.sh && \
    echo '# Start Postfix' >> /usr/local/bin/docker-entrypoint.sh && \
    echo 'if [ "$1" = "postfix" ]; then' >> /usr/local/bin/docker-entrypoint.sh && \
    echo '  exec postfix start-fg' >> /usr/local/bin/docker-entrypoint.sh && \
    echo 'else' >> /usr/local/bin/docker-entrypoint.sh && \
    echo '  exec "$@"' >> /usr/local/bin/docker-entrypoint.sh && \
    echo 'fi' >> /usr/local/bin/docker-entrypoint.sh && \
    chmod +x /usr/local/bin/docker-entrypoint.sh

# Set correct permissions
RUN chmod 644 /etc/postfix/main.cf && \
    chmod 644 /etc/sasl2/smtpd.conf && \
    chmod 755 /usr/local/bin/docker-entrypoint.sh

# Create a non-root user for Postfix
#RUN adduser -S -D -H -h /var/spool/postfix -s /sbin/nologin -G postfix -u 1000 postfix

# Set working directory
WORKDIR /etc/postfix

# Expose SMTP port
EXPOSE 25

# Set entrypoint and default command
ENTRYPOINT ["/usr/local/bin/docker-entrypoint.sh"]
CMD ["postfix"]
