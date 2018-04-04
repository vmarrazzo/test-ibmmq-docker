#!/bin/sh

# config section
ALIAS_NAME=my-alias
KEYSTORE_NAME=my-cert
VALIDITY_DAYS=365
PASSWORD=changeit

echo "#### Create a new Java keystore with public/private key pair"

# genkey in jks
keytool -genkey \
	-keyalg RSA \
	-keysize 2048 \
	-dname "CN=Vincenzo Marrazzo, OU=Java, O=Docker, L=Milano, S=Italia, C=IT" \
	-alias ${ALIAS_NAME} \
	-keystore ${KEYSTORE_NAME}.jks \
	-storepass ${PASSWORD} \
	-validity ${VALIDITY_DAYS} \
	-keypass ${PASSWORD}

echo "#### Convert Java keystore to PKCS #12 format"
	
# convert jks to pfx
keytool -importkeystore \
	-srckeypass ${PASSWORD} -destkeypass ${PASSWORD} \
	-srcstorepass ${PASSWORD} -deststorepass ${PASSWORD} \
	-srcalias ${ALIAS_NAME} -destalias ${ALIAS_NAME} \
	-srckeystore ${KEYSTORE_NAME}.jks -destkeystore ${KEYSTORE_NAME}.pfx \
	-deststoretype PKCS12
