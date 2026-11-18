# Removes what test-key-setup.sh created: the test user's access keys, its policy and the user.
# Paste into AWS CloudShell. Remove every Academy cluster first (Blueprint action "Remove the
# cluster"): the state bucket keeps their Terraform state. The bucket itself is removed only
# when you set REMOVE_BUCKET=yes.

REMOVE_BUCKET=no

set -eu
ACCOUNT=$(aws sts get-caller-identity --query Account --output text)
BUCKET="academy-tfstate-$ACCOUNT"
USER=academy-test-c3

if aws iam get-user --user-name "$USER" >/dev/null 2>&1; then
  for key in $(aws iam list-access-keys --user-name "$USER" --query 'AccessKeyMetadata[].AccessKeyId' --output text); do
    aws iam delete-access-key --user-name "$USER" --access-key-id "$key"
  done
  aws iam delete-user-policy --user-name "$USER" --policy-name academy-test-c3 2>/dev/null || true
  aws iam delete-user --user-name "$USER"
  echo "Removed $USER and its access keys."
fi

if [ "$REMOVE_BUCKET" = yes ]; then
  # A removed cluster leaves an empty state file behind; a cluster still running does not:
  # this deletes its state too, so remove every cluster before setting REMOVE_BUCKET=yes.
  # Versioned bucket: delete every version and delete marker, then the bucket.
  aws s3api list-object-versions --bucket "$BUCKET" --output json \
    --query '{Objects: [Versions, DeleteMarkers][][].{Key: Key, VersionId: VersionId}}' > /tmp/academy-versions.json
  if [ "$(python3 -c 'import json; print(len(json.load(open("/tmp/academy-versions.json"))["Objects"] or []))')" != 0 ]; then
    aws s3api delete-objects --bucket "$BUCKET" --delete file:///tmp/academy-versions.json >/dev/null
  fi
  rm -f /tmp/academy-versions.json
  aws s3api delete-bucket --bucket "$BUCKET"
  echo "Removed $BUCKET."
fi
