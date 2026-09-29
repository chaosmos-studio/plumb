#!/usr/bin/env bash
# Makes this game's Google Play upload key, keeps it outside the repo, and hands it to CI as repository secrets.
#
#   tools/make_upload_key.sh
#
# Run it once per game. It writes ~/.android-keys/<game>-upload.jks and, beside it, <game>-upload.txt with the
# alias and password (chmod 600), prints the certificate's SHA-256, then asks before setting the secrets
# ANDROID_KEYSTORE_BASE64, ANDROID_KEYSTORE_ALIAS and ANDROID_KEYSTORE_PASSWORD that release-android.yml signs
# with. An existing key is never overwritten: running it again reuses the key, so it can also re-send the secrets.
set -euo pipefail

for tool in keytool gh base64; do
	if ! command -v "$tool" > /dev/null; then
		echo "$tool not found (keytool comes with any JDK, gh is the GitHub CLI)" >&2
		exit 1
	fi
done

cd "$(dirname "$0")/.."
repo="$(gh repo view --json nameWithOwner --jq .nameWithOwner)"
game="${repo#*/}"
dir="$HOME/.android-keys"
jks="$dir/$game-upload.jks"
txt="$dir/$game-upload.txt"
alias="upload"

umask 077
mkdir -p "$dir"
chmod 700 "$dir"

if [[ -e "$jks" ]]; then
	if [[ ! -f "$txt" ]]; then
		echo "$jks exists but $txt, which holds its password, does not. Not touching either." >&2
		exit 1
	fi
	echo "reusing the existing key $jks"
	alias="$(sed -n 's/^alias=//p' "$txt")"
	KEY_PASSWORD="$(sed -n 's/^password=//p' "$txt")"
else
	# PKCS12 keeps one password for the store and the key, which is what Godot's Gradle build passes for both.
	KEY_PASSWORD="$(head -c 24 /dev/urandom | od -An -tx1 | tr -d ' \n')"
	export KEY_PASSWORD
	keytool -genkeypair -storetype PKCS12 -keystore "$jks" -alias "$alias" \
		-keyalg RSA -keysize 2048 -validity 10000 \
		-storepass:env KEY_PASSWORD -keypass:env KEY_PASSWORD \
		-dname "CN=$(git config user.name || echo "$game"), OU=$game"
	cat > "$txt" <<EOF
# Google Play upload key for $repo. Back this file up together with $game-upload.jks.
keystore=$jks
alias=$alias
password=$KEY_PASSWORD
created=$(date -u +%Y-%m-%d)
EOF
	chmod 600 "$jks" "$txt"
fi
export KEY_PASSWORD

sha="$(keytool -list -v -keystore "$jks" -alias "$alias" -storepass:env KEY_PASSWORD \
	| sed -n 's/^[[:space:]]*SHA256: //p')"
if [[ -z "$sha" ]]; then
	echo "could not read the certificate from $jks with the password in $txt" >&2
	exit 1
fi

cat <<EOF

  keystore  $jks
  alias     $alias
  password  in $txt
  SHA-256   $sha

  ##########################################################################
  #  BACK UP $dir NOW: a password manager or an encrypted drive, off this machine.
  #  This key signs every $game build that goes to Google Play. Lose it and the
  #  only way back is an upload key reset through Play support, which takes days.
  #  Never commit it. The repo ignores *.jks and *.keystore.
  ##########################################################################

EOF

read -r -p "Set ANDROID_KEYSTORE_BASE64, ANDROID_KEYSTORE_ALIAS and ANDROID_KEYSTORE_PASSWORD on $repo? [y/N] " answer
if [[ "$answer" != [yY] ]]; then
	echo "no secrets set. Run this again to set them; it reuses the key."
	exit 0
fi
base64 -w0 "$jks" | gh secret set ANDROID_KEYSTORE_BASE64 -R "$repo"
printf '%s' "$alias" | gh secret set ANDROID_KEYSTORE_ALIAS -R "$repo"
printf '%s' "$KEY_PASSWORD" | gh secret set ANDROID_KEYSTORE_PASSWORD -R "$repo"
echo "secrets set: the next Release Android run on $repo signs with this key ($sha)."
