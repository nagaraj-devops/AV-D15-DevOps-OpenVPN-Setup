# Migration Guide: OpenVPN Marketplace Hourly → BYOL (Bring Your Own License)

## Summary
You are currently paying for OpenVPN Access Server via AWS Marketplace hourly licensing. This guide shows how to migrate to a BYOL license on a new EC2 instance (zero-downtime technique), reduce instance size, and terminate the Marketplace instance to stop hourly charges.

---

## Prerequisites
- OpenVPN BYOL license key (purchase from OpenVPN: https://openvpn.net)
- AWS IAM permissions to create EC2, Security Groups, Elastic IPs.
- SSH key pair created in the target region.
- Decide AMI for Ubuntu 22.04 (set AMI ID in Terraform variable `ami`).

---

## Step-by-step

### 1. Purchase BYOL license
- Buy appropriate license (50 devices) from OpenVPN and save the license key.

### 2. Launch new EC2 (recommended method)
- Use Terraform (provided) or AWS Console.
- Choose **t3.small** or **t3.medium**.
- Assign an Elastic IP (Terraform creates one).
- Open ports: 943 TCP, 1194 TCP/UDP, 443 TCP.

### 3. Install OpenVPN Access Server on new instance
- SSH to instance:
  ```
  sudo apt update && sudo apt upgrade -y
  wget https://openvpn.net/downloads/openvpn-as-latest-ubuntu22.amd_64.deb
  sudo apt install ./openvpn-as-latest-ubuntu22.amd_64.deb -y
  sudo passwd openvpn
  ```
- Admin UI: https://<public-ip>:943/admin

### 4. Apply BYOL license
- Admin UI → Configuration → License → Enter License Key → Save.
- Restart service:
  ```
  sudo systemctl restart openvpnas
  ```

### 5. Migrate configuration & users
- On old Marketplace server:
  ```
  sudo /usr/local/openvpn_as/scripts/confdba -o - > backup.conf
  ```
- Copy `backup.conf` to new server (`scp`).
- On new server:
  ```
  sudo /usr/local/openvpn_as/scripts/confdba -i - < backup.conf
  sudo systemctl restart openvpnas
  ```

### 6. Swap Elastic IP (zero-downtime)
Option A (recommended):
- Detach Elastic IP from old instance and attach to new BYOL instance.
Option B:
- Update DNS records to point to new IP and lower TTL before migration.

### 7. Test & verify
- Connect a subset of users and validate VPN connectivity, routes, and authentication.
- Check CPU, memory, and network throughput.

### 8. Terminate old Marketplace instance
- After verification, terminate the Marketplace EC2 to stop hourly billing.

---

## Optional: Scaling & Savings
- Use Reserved Instances or Savings Plans if long-term.
- For HA, deploy two BYOL nodes behind an NLB with health checks.
- Consider community OpenVPN or WireGuard if commercial features are not required.

---

## Terraform
A sample Terraform file `openvpn_byol_terraform.tf` is included next to this document.

---

## Notes & Troubleshooting
- If using LDAP/AD authentication, reconfigure LDAP settings in Admin UI.
- Keep a copy of `backup.conf` offline.
- If license activation fails, contact OpenVPN support with your license key and server FQDN/IP.
