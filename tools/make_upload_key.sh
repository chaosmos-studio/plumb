#!/usr/bin/env bash
# Makes this game's Google Play upload key, keeps it outside the repo, and hands it to CI as repository secrets.
#
#   tools/make_upload_key.sh
#
# Run it once per game. It writes ~/.android-keys/<game>-upload.jks and, beside it, <game>-upload.txt with the
# alias and password (chmod 600), records the certificate's SHA-256 in ~/.android-keys/LEDGER.md, offers an
# encrypted backup of every key (tools/backup_upload_keys.sh), then asks before setting the secrets
# ANDROID_KEYSTORE_BASE64, ANDROID_KEYSTORE_ALIAS and ANDROID_KEYSTORE_PASSWORD that release-android.yml signs
# with, and the variable UPLOAD_KEY_SHA256 that pins releases to this key. An existing key is never
# overwritten: running it again reuses the key, so it can also re-send the secrets. It refuses to replace a
# pin that names a different key, because Play rejects any upload not signed with the key it already knows.
set -euo pipefail

for tool in keytool gh base64 gpg; do
	if ! command -v "$tool" > /dev/null; then
		echo "$tool not found (keytool comes with any JDK, gh is the GitHub CLI, gpg is gnupg)" >&2
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

# The ledger holds nothing secret: which key belongs to which game, to compare with Play Console's
# App integrity page and to know what a backup must contain.
package="$(sed -n 's/^package\/unique_name="\(.*\)"$/\1/p' export_presets.cfg 2>/dev/null | head -n 1)"
ledger="$dir/LEDGER.md"
if [[ ! -f "$ledger" ]]; then
	printf '%s\n\n%s\n%s\n' "# Google Play upload keys on this machine" \
		"| Game | Repository | Package | Alias | Certificate SHA-256 | Created |" "| --- | --- | --- | --- | --- | --- |" > "$ledger"
fi
created="$(sed -n 's/^created=//p' "$txt")"
grep -v "^| $game | " "$ledger" > "$ledger.new" || true
echo "| $game | $repo | ${package:-?} | $alias | $sha | ${created:-?} |" >> "$ledger.new"
mv "$ledger.new" "$ledger"
chmod 600 "$ledger"

cat <<MSG

  keystore  $jks
  alias     $alias
  password  in $txt
  SHA-256   $sha
  ledger    $ledger

  ##########################################################################
  #  This key signs every $game build that goes to Google Play. Lose it and
  #  the only way back is an upload key reset through Play support, which
  #  takes days. Never commit it: the repo ignores *.jks and *.keystore.
  ##########################################################################

MSG

backup="$(dirname "$0")/backup_upload_keys.sh"
read -r -p "Make an encrypted backup of every key in $dir now? [Y/n] " answer
if [[ "$answer" != [nN] ]]; then
	"$backup"
else
	echo "no backup made. Run $backup before you rely on this key."
fi

# A pin that names another key means Play may already know that one: replacing the key here would make
# every later upload fail, so say how to recover instead.
pinned="$(gh variable get UPLOAD_KEY_SHA256 -R "$repo" 2>/dev/null || true)"
if [[ -n "$pinned" && "$pinned" != "$sha" ]]; then
	cat >&2 <<MSG
$repo is pinned to the upload key $pinned,
but $jks is $sha.
If Play already has builds of $game signed with the pinned key, restore that key from your backup
(tools/backup_upload_keys.sh --restore <file>) and run this again. Only after Google approves an upload key
reset for $game, move the pin with: gh variable set UPLOAD_KEY_SHA256 -R $repo --body "$sha"
MSG
	exit 1
fi

read -r -p "Set ANDROID_KEYSTORE_BASE64, ANDROID_KEYSTORE_ALIAS, ANDROID_KEYSTORE_PASSWORD and UPLOAD_KEY_SHA256 on $repo? [y/N] " answer
if [[ "$answer" != [yY] ]]; then
	echo "no secrets set. Run this again to set them; it reuses the key."
	exit 0
fi
base64 -w0 "$jks" | gh secret set ANDROID_KEYSTORE_BASE64 -R "$repo"
printf '%s' "$alias" | gh secret set ANDROID_KEYSTORE_ALIAS -R "$repo"
printf '%s' "$KEY_PASSWORD" | gh secret set ANDROID_KEYSTORE_PASSWORD -R "$repo"
gh variable set UPLOAD_KEY_SHA256 -R "$repo" --body "$sha"
echo "secrets set and pinned: every Release Android run on $repo signs with this key ($sha) or stops."
