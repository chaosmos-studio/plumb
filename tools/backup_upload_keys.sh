#!/usr/bin/env bash
# Seals every Google Play upload key on this machine (~/.android-keys: each game's .jks, the .txt with its
# password, and LEDGER.md) into one encrypted file, then opens it again to prove the backup is whole. The file
# is AES-256 encrypted with a passphrase you choose, so it is safe to keep on a cloud drive; keep the
# passphrase in your password manager, never beside the file. Run it after every new key.
#
#   backup_upload_keys.sh [folder]            writes android-keys-<date>.tar.gz.gpg (default ~/android-keys-backups)
#   backup_upload_keys.sh --restore <file>    puts a backup's keys back into ~/.android-keys, never overwriting
#
# BACKUP_PASSPHRASE in the environment skips the prompts, for scripted checks only.
set -euo pipefail
command -v gpg > /dev/null || { echo "gpg not found (install gnupg)" >&2; exit 1; }
keys="$HOME/.android-keys"
umask 077

# gpg asks for the passphrase itself unless one is given, and then twice when sealing, so a typo cannot
# lock the backup.
crypt() {
	if [[ -n "${BACKUP_PASSPHRASE:-}" ]]; then
		gpg --batch --yes --quiet --pinentry-mode loopback --passphrase-fd 3 "$@" 3<<< "$BACKUP_PASSPHRASE"
	else
		gpg --quiet "$@"
	fi
}

if [[ "${1:-}" == "--restore" ]]; then
	file="${2:?usage: backup_upload_keys.sh --restore <file>}"
	work="$(mktemp -d)"
	trap 'rm -rf "$work"' EXIT
	crypt --decrypt "$file" | tar -xz -C "$work"
	mkdir -p "$keys"
	chmod 700 "$keys"
	restored=0
	for f in "$work"/.android-keys/*; do
		name="$(basename "$f")"
		if [[ -e "$keys/$name" ]]; then
			if cmp -s "$f" "$keys/$name"; then
				echo "already here, identical: $name"
			else
				echo "kept the existing $name: it differs from the backup's copy, so compare them by hand" >&2
			fi
			continue
		fi
		cp -p "$f" "$keys/$name"
		chmod 600 "$keys/$name"
		restored=$((restored + 1))
		echo "restored $name"
	done
	echo "$restored file(s) restored into $keys"
	exit 0
fi

shopt -s nullglob
jks=("$keys"/*.jks)
if (( ${#jks[@]} == 0 )); then
	echo "no upload keys in $keys yet: run tools/make_upload_key.sh in a game first" >&2
	exit 1
fi
for key in "${jks[@]}"; do
	if [[ ! -f "${key%.jks}.txt" ]]; then
		echo "$key has no ${key%.jks}.txt beside it, so its password is missing: a backup without it is useless" >&2
		exit 1
	fi
done
out="${1:-$HOME/android-keys-backups}"
mkdir -p "$out"
file="$out/android-keys-$(date -u +%Y%m%d-%H%M%S).tar.gz.gpg"
tar -C "$HOME" -czf - .android-keys | crypt --symmetric --cipher-algo AES256 --output "$file"

# Open what was just written and compare every file with the original.
work="$(mktemp -d)"
trap 'rm -rf "$work"' EXIT
echo "checking the backup opens (gpg asks for the passphrase once more)"
crypt --decrypt "$file" | tar -xz -C "$work"
for f in "$keys"/*; do
	if ! cmp -s "$f" "$work/.android-keys/$(basename "$f")"; then
		echo "the backup's copy of $(basename "$f") does not match: do not rely on $file" >&2
		exit 1
	fi
done
echo
echo "  backup   $file ($(du -h "$file" | cut -f1)), opened and checked"
echo "  keys     ${#jks[@]}: $(for key in "${jks[@]}"; do basename "$key" -upload.jks; done | paste -sd ' ')"
[[ -f "$keys/LEDGER.md" ]] && echo "  ledger   $keys/LEDGER.md lists each key's certificate SHA-256"
cat <<EOF

  Keep this file in two places off this machine (a cloud drive and a USB stick are fine: it is encrypted),
  and the passphrase in your password manager. Without the passphrase the file cannot be opened by anyone,
  you included. Make a new backup after every new game's key.
EOF
