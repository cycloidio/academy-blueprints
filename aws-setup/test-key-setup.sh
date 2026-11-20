# C2 setup FOR TESTING ONLY: Terraform state bucket and an access key for the Academy cluster
# Blueprint, before Cycloid's OIDC details are known (decision D3 keeps OIDC for the missions).
#
# Paste into AWS CloudShell, in the TEST account, after setting REGION. It creates:
#   - the S3 bucket cycloid-academy-tfstate-<account> (versioned, encrypted, no public access)
#   - the IAM user cycloid-academy, limited to EC2 in REGION, cycloid-academy-* roles and instance
#     profiles, cycloid-academy-* secrets in REGION and the state bucket
#   - one access key for that user, printed once: paste it into the `dev` Environment's
#     credentials in Cycloid (type AWS access key), never into a chat or a file.
# Run test-key-remove.sh to undo it. Running this twice is harmless; it never prints a second key
# while one exists.

REGION=eu-west-1

set -eu
ACCOUNT=$(aws sts get-caller-identity --query Account --output text)
BUCKET="cycloid-academy-tfstate-$ACCOUNT"
USER=cycloid-academy

# --- State bucket --------------------------------------------------------------------------------
if ! aws s3api head-bucket --bucket "$BUCKET" 2>/dev/null; then
  if [ "$REGION" = us-east-1 ]; then
    aws s3api create-bucket --bucket "$BUCKET" --region "$REGION"
  else
    aws s3api create-bucket --bucket "$BUCKET" --region "$REGION" \
      --create-bucket-configuration "LocationConstraint=$REGION"
  fi
fi
aws s3api put-public-access-block --bucket "$BUCKET" --public-access-block-configuration \
  BlockPublicAcls=true,IgnorePublicAcls=true,BlockPublicPolicy=true,RestrictPublicBuckets=true
aws s3api put-bucket-versioning --bucket "$BUCKET" --versioning-configuration Status=Enabled
aws s3api put-bucket-encryption --bucket "$BUCKET" --server-side-encryption-configuration \
  '{"Rules":[{"ApplyServerSideEncryptionByDefault":{"SSEAlgorithm":"AES256"}}]}'

# --- Test user and its permissions ---------------------------------------------------------------
aws iam get-user --user-name "$USER" >/dev/null 2>&1 || aws iam create-user --user-name "$USER" \
  --tags Key=cycloid-academy,Value=true >/dev/null

cat > /tmp/cycloid-academy-policy.json <<EOF
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Sid": "Ec2InOneRegion",
      "Effect": "Allow",
      "Action": "ec2:*",
      "Resource": "*",
      "Condition": { "StringEquals": { "aws:RequestedRegion": "$REGION" } }
    },
    {
      "Sid": "AcademyRolesAndProfiles",
      "Effect": "Allow",
      "Action": [
        "iam:CreateRole", "iam:DeleteRole", "iam:GetRole", "iam:TagRole", "iam:UntagRole",
        "iam:PutRolePolicy", "iam:GetRolePolicy", "iam:DeleteRolePolicy",
        "iam:ListRolePolicies", "iam:ListAttachedRolePolicies", "iam:ListInstanceProfilesForRole",
        "iam:CreateInstanceProfile", "iam:DeleteInstanceProfile", "iam:GetInstanceProfile",
        "iam:TagInstanceProfile", "iam:AddRoleToInstanceProfile", "iam:RemoveRoleFromInstanceProfile",
        "iam:PassRole"
      ],
      "Resource": [
        "arn:aws:iam::$ACCOUNT:role/cycloid-academy-*",
        "arn:aws:iam::$ACCOUNT:instance-profile/cycloid-academy-*"
      ]
    },
    {
      "Sid": "AcademySecrets",
      "Effect": "Allow",
      "Action": "secretsmanager:*",
      "Resource": "arn:aws:secretsmanager:$REGION:$ACCOUNT:secret:cycloid-academy-*"
    },
    {
      "Sid": "StateBucket",
      "Effect": "Allow",
      "Action": "s3:ListBucket",
      "Resource": "arn:aws:s3:::$BUCKET"
    },
    {
      "Sid": "StateObjects",
      "Effect": "Allow",
      "Action": ["s3:GetObject", "s3:PutObject", "s3:DeleteObject"],
      "Resource": "arn:aws:s3:::$BUCKET/cycloid-academy/*"
    }
  ]
}
EOF
aws iam put-user-policy --user-name "$USER" --policy-name cycloid-academy \
  --policy-document file:///tmp/cycloid-academy-policy.json
rm -f /tmp/cycloid-academy-policy.json

# --- Access key, printed once --------------------------------------------------------------------
if [ "$(aws iam list-access-keys --user-name "$USER" --query 'length(AccessKeyMetadata)' --output text)" = 0 ]; then
  echo "Paste these two values into Cycloid (dev Environment, credential of type AWS access key), then clear this screen:"
  aws iam create-access-key --user-name "$USER" \
    --query 'AccessKey.[AccessKeyId,SecretAccessKey]' --output text
else
  echo "$USER already has an access key; none printed. Run test-key-remove.sh first to get a new one."
fi
echo "State bucket: $BUCKET in $REGION. AWS account ID for the Blueprint form: $ACCOUNT"
