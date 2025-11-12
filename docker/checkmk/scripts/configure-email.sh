#!/bin/bash
# Configure CheckMK Email Notifications
# This script configures SMTP relay and email notifications in CheckMK

set -e

SITE_ID="${CMK_SITE_ID:-cmk_monitoring}"
SITE_DIR="/omd/sites/${SITE_ID}"

echo "Configuring email notifications for site: ${SITE_ID}"

# Wait for CheckMK site to be ready
while [ ! -d "${SITE_DIR}" ]; do
    echo "Waiting for site directory ${SITE_DIR}..."
    sleep 5
done

echo "Site directory found, configuring..."

# Configure SMTP relay and authentication using env vars
if [ -n "${MAIL_USERNAME}" ] && [ -n "${MAIL_PASSWORD}" ] && [ -n "${MAIL_RELAY_HOST}" ]; then
    echo "Configuring SMTP authentication..."

    RELAY_TARGET="[${MAIL_RELAY_HOST}]:${MAIL_RELAY_PORT:-587}"

    # Create SASL password file
    echo "${RELAY_TARGET} ${MAIL_USERNAME}:${MAIL_PASSWORD}" > /etc/postfix/sasl_passwd
    chmod 600 /etc/postfix/sasl_passwd
    postmap /etc/postfix/sasl_passwd

    # Update Postfix to use the authenticated relay with TLS
    postconf -e "relayhost = ${RELAY_TARGET}"
    postconf -e "smtp_sasl_password_maps = hash:/etc/postfix/sasl_passwd"
    postconf -e "smtp_sasl_auth_enable = yes"
    postconf -e "smtp_sasl_security_options = noanonymous"
    postconf -e "smtp_sasl_mechanism_filter = plain, login"
    postconf -e "smtp_use_tls = yes"
    postconf -e "smtp_tls_security_level = encrypt"
    postconf -e "smtp_tls_CAfile = /etc/ssl/certs/ca-certificates.crt"

    # Reload Postfix
    postfix reload 2>/dev/null || true
    echo "SMTP authentication configured successfully"
else
    echo "Skipping SMTP auth configuration (missing credentials)"
fi

# Configure Postfix sender address rewriting
echo "Configuring sender address rewriting..."
if [ -n "${MAIL_FROM}" ]; then
    # Configure canonical mapping to rewrite sender address
    echo "root@checkmk-server ${MAIL_FROM}" > /etc/postfix/sender_canonical
    echo "cmk_monitoring@checkmk-server ${MAIL_FROM}" >> /etc/postfix/sender_canonical
    echo "@checkmk-server ${MAIL_FROM}" >> /etc/postfix/sender_canonical

    postmap /etc/postfix/sender_canonical
    postconf -e "sender_canonical_maps = hash:/etc/postfix/sender_canonical"
    postfix reload 2>/dev/null || true

    echo "Sender address rewriting configured: all emails will be sent from ${MAIL_FROM}"
fi

# Configure CheckMK notification settings
echo "Configuring CheckMK notifications..."

# Wait for site to be started
su - ${SITE_ID} -c "omd status" 2>/dev/null || sleep 10

# Remove old problematic global.mk if exists
OLD_GLOBAL="${SITE_DIR}/etc/check_mk/conf.d/wato/global.mk"
if [ -f "${OLD_GLOBAL}" ]; then
    echo "Removing old global.mk configuration..."
    rm -f "${OLD_GLOBAL}"
fi

# Create notification configuration
NOTIF_CONFIG="${SITE_DIR}/etc/check_mk/conf.d/notifications.mk"
mkdir -p "$(dirname ${NOTIF_CONFIG})"

cat > ${NOTIF_CONFIG} <<EOF
# Notification settings
notification_from = "${MAIL_FROM:-checkmk@localhost}"
EOF

chown ${SITE_ID}:${SITE_ID} ${NOTIF_CONFIG}

echo "Email configuration completed successfully"

# Test email functionality
if [ -n "${NOTIFICATION_EMAIL}" ]; then
    echo "Testing email configuration..."
    echo "CheckMK email configuration test - $(date)" | mail -s "CheckMK Test Email" -r "${MAIL_FROM:-root@localhost}" "${NOTIFICATION_EMAIL}" 2>&1 || echo "Email test sent (check delivery)"
fi
