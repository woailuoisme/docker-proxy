#!/bin/sh
set -eu

SITE_ADDRESS="${SITE_ADDRESS:-test.local}"
PREFIX_SITE_DOZZLE="${PREFIX_SITE_DOZZLE:-dozzle}"
PREFIX_SITE_XUI_WEB="${PREFIX_SITE_XUI_WEB:-xui}"
PREFIX_SITE_XUI_SUB="${PREFIX_SITE_XUI_SUB:-sub}"
NO_PROXY_VALUE="${NO_PROXY:-localhost,127.0.0.1,.${SITE_ADDRESS},${PREFIX_SITE_DOZZLE}.${SITE_ADDRESS},${PREFIX_SITE_XUI_WEB}.${SITE_ADDRESS},${PREFIX_SITE_XUI_SUB}.${SITE_ADDRESS}}"

DOZZLE_URL="https://${PREFIX_SITE_DOZZLE}.${SITE_ADDRESS}/"
XUI_URL="https://${PREFIX_SITE_XUI_WEB}.${SITE_ADDRESS}/"
SUB_URL="https://${PREFIX_SITE_XUI_SUB}.${SITE_ADDRESS}/"

curl_no_proxy() {
	NO_PROXY="$NO_PROXY_VALUE" \
	no_proxy="$NO_PROXY_VALUE" \
	HTTP_PROXY='' HTTPS_PROXY='' ALL_PROXY='' \
	http_proxy='' https_proxy='' all_proxy='' \
	curl -k -sS -o /dev/null -w '%{http_code}' "$1"
}

check_proxy_status() {
	url="$1"
	status="$2"

	case "$status" in
		200|401) return 0 ;;
	esac

	echo "unexpected status for ${url}: ${status}" >&2
	exit 1
}

check_xui_status() {
	url="$1"
	status="$2"

	case "$status" in
		200|401|404) return 0 ;;
	esac

	echo "unexpected status for ${url}: ${status}" >&2
	exit 1
}

dozzle_status="$(curl_no_proxy "$DOZZLE_URL")"
xui_status="$(curl_no_proxy "$XUI_URL")"
sub_status="$(curl_no_proxy "$SUB_URL")"

check_proxy_status "$DOZZLE_URL" "$dozzle_status"
check_xui_status "$XUI_URL" "$xui_status"
check_xui_status "$SUB_URL" "$sub_status"

echo "ok: ${DOZZLE_URL}=${dozzle_status}, ${XUI_URL}=${xui_status}, ${SUB_URL}=${sub_status}"
