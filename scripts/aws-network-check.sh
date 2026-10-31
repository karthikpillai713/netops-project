#!/bin/bash
LOG_FILE=$(mktemp)

trap 'rm -f "$LOG_FILE"' EXIT

exec > >(tee "$LOG_FILE") 2>&1

# NETOPS AWS Network Diagnostics

PROFILE="netops-lab"
REGION="us-east-1"
INSTANCE_ID="i-0c90eeba0433f0997"

# Execute AWS CLI commands and handle failures
aws_check() {
    local output
    local status

    output=$(aws "$@" --profile "$PROFILE" --region "$REGION")
    status=$?

    if [ "$status" -ne 0 ]; then
        echo "[ERROR] AWS CLI command failed" >&2
        return 2
    fi

    printf '%s\n' "$output"
}
echo "================================"
echo "    NETOPS AWS Diagnostics"
echo "================================"

echo ""
echo "[1] Checking EC2 instance state..."

STATE=$(aws_check ec2 describe-instances \
    --instance-ids "$INSTANCE_ID" \
    --query 'Reservations[0].Instances[0].State.Name' \
    --output text) || exit 2

if [ -z "$STATE" ] || [ "$STATE" = "None" ]; then
    echo "[FAIL] Unable to retrieve EC2 instance state"
    exit 1
fi

echo "[INFO] EC2 instance state: $STATE"
echo ""
echo "[2] Checking EC2 IP addresses..."

PRIVATE_IP=$(aws_check ec2 describe-instances \
    --instance-ids "$INSTANCE_ID" \
    --query 'Reservations[0].Instances[0].PrivateIpAddress' \
    --output text) || exit 2

PUBLIC_IP=$(aws_check ec2 describe-instances \
    --instance-ids "$INSTANCE_ID" \
    --query 'Reservations[0].Instances[0].PublicIpAddress' \
    --output text) || exit 2

if [ -n "$PRIVATE_IP" ] && [ "$PRIVATE_IP" != "None" ]; then
    echo "[PASS] Private IP: $PRIVATE_IP"
else
    echo "[FAIL] Private IP not found"
fi

if [ -n "$PUBLIC_IP" ] && [ "$PUBLIC_IP" != "None" ]; then
    echo "[PASS] Public IP: $PUBLIC_IP"
else
    echo "[INFO] No public IP assigned"
fi
echo ""
echo "[3] Checking security group rules..."

SG_ID="sg-03274415379ace17a"

HTTP_RULE=$(aws_check ec2 describe-security-groups \
    --group-ids "$SG_ID" \
    --query 'SecurityGroups[0].IpPermissions[?IpProtocol==`tcp` && FromPort<=`80` && ToPort>=`80`].IpRanges[].CidrIp' \
    --output text) || exit 2

if echo "$HTTP_RULE" | grep -Fqw "0.0.0.0/0"; then
    echo "[PASS] HTTP port 80 is allowed from the internet"
else
    echo "[FAIL] HTTP port 80 is not open to the internet"
fi

SSH_RULE=$(aws_check ec2 describe-security-groups \
    --group-ids "$SG_ID" \
    --query 'SecurityGroups[0].IpPermissions[?IpProtocol==`tcp` && FromPort<=`22` && ToPort>=`22`].IpRanges[].CidrIp' \
    --output text) || exit 2

if [ -n "$SSH_RULE" ] && [ "$SSH_RULE" != "None" ]; then
    echo "[PASS] SSH port 22 has an inbound rule: $SSH_RULE"
else
    echo "[FAIL] No SSH inbound rule found"
fi
echo ""
echo "[4] Checking public subnet internet route..."

PUBLIC_RT="rtb-051eddec291f70725"

IGW_ROUTE=$(aws_check ec2 describe-route-tables \
    --route-table-ids "$PUBLIC_RT" \
    --query 'RouteTables[0].Routes[?DestinationCidrBlock==`0.0.0.0/0` && State==`active`].GatewayId' \
    --output text) || exit 2

if [[ "$IGW_ROUTE" == igw-* ]]; then
    echo "[PASS] Active internet route found: $IGW_ROUTE"
else
    echo "[FAIL] No active default route to an Internet Gateway"
fi
echo ""
echo "[5] Checking VPC DNS configuration..."

VPC_ID="vpc-024cd89821c483421"

# Check DNS resolution
DNS_SUPPORT=$(aws_check ec2 describe-vpc-attribute \
    --vpc-id "$VPC_ID" \
    --attribute enableDnsSupport \
    --query 'EnableDnsSupport.Value' \
    --output text) || exit 2

if [ "$DNS_SUPPORT" = "True" ] || [ "$DNS_SUPPORT" = "true" ]; then
    echo "[PASS] VPC DNS resolution is enabled"
else
    echo "[FAIL] VPC DNS resolution is disabled"
fi

# Check DNS hostnames
DNS_HOSTNAMES=$(aws_check ec2 describe-vpc-attribute \
    --vpc-id "$VPC_ID" \
    --attribute enableDnsHostnames \
    --query 'EnableDnsHostnames.Value' \
    --output text) || exit 2

if [ "$DNS_HOSTNAMES" = "True" ] || [ "$DNS_HOSTNAMES" = "true" ]; then
    echo "[PASS] VPC DNS hostnames are enabled"
elif [ "$DNS_HOSTNAMES" = "False" ] || [ "$DNS_HOSTNAMES" = "false" ]; then
    echo "[INFO] VPC DNS hostnames are disabled"
else
    echo "[FAIL] Unable to verify VPC DNS hostname setting"
fi

echo ""
echo "[6] Checking Network ACL rules..."

NACL_ID="acl-08944e4bf00cea68b"

INBOUND_ALLOW=$(aws_check ec2 describe-network-acls \
    --network-acl-ids "$NACL_ID" \
    --query 'NetworkAcls[0].Entries[?Egress==`false` && RuleAction==`allow` && Protocol==`"-1"` && CidrBlock==`0.0.0.0/0`].RuleNumber' \
    --output text) || exit 2

OUTBOUND_ALLOW=$(aws_check ec2 describe-network-acls \
    --network-acl-ids "$NACL_ID" \
    --query 'NetworkAcls[0].Entries[?Egress==`true` && RuleAction==`allow` && Protocol==`"-1"` && CidrBlock==`0.0.0.0/0`].RuleNumber' \
    --output text) || exit 2

if [ "$INBOUND_ALLOW" = "100" ]; then
    echo "[PASS] NACL inbound rule 100 allows all IPv4 traffic"
else
    echo "[FAIL] Expected inbound NACL rule not found"
fi

if [ "$OUTBOUND_ALLOW" = "100" ]; then
    echo "[PASS] NACL outbound rule 100 allows all IPv4 traffic"
else
    echo "[FAIL] Expected outbound NACL rule not found"
fi
echo ""
echo "================================"
echo "    NETOPS Diagnostic Summary"
echo "================================"

PASS_COUNT=$(grep -c '^\[PASS\]' "$LOG_FILE")
FAIL_COUNT=$(grep -c '^\[FAIL\]' "$LOG_FILE")
INFO_COUNT=$(grep -c '^\[INFO\]' "$LOG_FILE")
REQUIRED_CHECKS=7
TOTAL_CHECKS=$((PASS_COUNT + FAIL_COUNT))

if [ "$TOTAL_CHECKS" -lt "$REQUIRED_CHECKS" ]; then
    echo "[ERROR] Expected at least $REQUIRED_CHECKS checks, but only $TOTAL_CHECKS were completed"
    exit 2
fi

echo "Passed Checks : $PASS_COUNT"
echo "Failed Checks : $FAIL_COUNT"
echo "Info Messages : $INFO_COUNT"

echo ""

if [ "$FAIL_COUNT" -eq 0 ]; then
    echo "Overall Status: HEALTHY"
    exit 0
else
    echo "Overall Status: UNHEALTHY"
    exit 1
fi
