# Azure Network Labs

> A GitHub Actions powered IaC library for deploying Azure network topologies using Bicep.
> Built for hands-on learning and real-world reference architecture practice.

---

## Repository Structure

```
azure-network-labs/
├── .github/
│   └── workflows/
│       ├── test-auth.yml              # OIDC connectivity test
│       └── hub-spoke-deploy.yml       # Hub and Spoke deployment pipeline
│
└── labs/
    └── hub-spoke/
        ├── main.bicep                 # Entry point — subscription-scoped deployment
        ├── parameters/
        │   └── australiaeast.json     # Region-specific parameter values
        └── modules/
            ├── vnet.bicep             # Virtual Network
            ├── firewall.bicep         # Azure Firewall + Firewall Policy
            ├── peering.bicep          # VNet Peering (bidirectional)
            ├── routeTable.bicep       # Route table forcing traffic through firewall
            ├── linuxVm.bicep          # Linux VM with boot diagnostics
            └── storageAccount.bicep   # Diagnostics storage account
```

---

## Labs

### Hub and Spoke

A classic hub and spoke network topology with centralised security through Azure Firewall.

#### What gets deployed

| Resource | Details |
|---|---|
| Hub VNet | `10.0.0.0/16` — contains Firewall, Bastion and Gateway subnets |
| Spoke 1 VNet | `10.1.0.0/16` — two workload subnets |
| Spoke 2 VNet | `10.2.0.0/16` — two workload subnets |
| Azure Firewall | Standard tier with Firewall Policy, spoke-to-spoke rules |
| VNet Peerings | Hub ↔ Spoke 1, Hub ↔ Spoke 2 (both directions) |
| Route Tables | Forces all spoke traffic through Azure Firewall (`0.0.0.0/0 → NVA`) |
| Linux VMs | 2 x Ubuntu 22.04 in Spoke 1, 2 x Ubuntu 22.04 in Spoke 2 |
| Boot Diagnostics | Enabled on all VMs — unlocks Serial Console in Azure Portal |
| Storage Account | Dedicated diagnostics storage account |

#### Network topology

```
                        ┌─────────────────────────────┐
                        │         Hub VNet             │
                        │        10.0.0.0/16           │
                        │                              │
                        │   ┌──────────────────────┐   │
                        │   │   Azure Firewall      │   │
                        │   │   (Standard tier)     │   │
                        │   └──────────────────────┘   │
                        └──────────┬──────────┬────────┘
                                   │          │
                     VNet Peering  │          │  VNet Peering
                                   │          │
               ┌───────────────────┘          └────────────────────┐
               │                                                    │
   ┌───────────▼─────────────┐                    ┌────────────────▼────────┐
   │      Spoke 1 VNet       │                    │      Spoke 2 VNet       │
   │       10.1.0.0/16       │                    │       10.2.0.0/16       │
   │                         │                    │                         │
   │  vm-spk1-01  vm-spk1-02 │                    │  vm-spk2-01  vm-spk2-02 │
   │  10.1.0.x    10.1.0.x   │                    │  10.2.0.x    10.2.0.x   │
   └─────────────────────────┘                    └─────────────────────────┘
```

#### Address space

| Resource | CIDR |
|---|---|
| Hub VNet | `10.0.0.0/16` |
| AzureFirewallSubnet | `10.0.0.0/26` |
| AzureFirewallManagementSubnet | `10.0.0.64/26` |
| AzureBastionSubnet | `10.0.1.0/27` |
| GatewaySubnet | `10.0.2.0/27` |
| Spoke 1 VNet | `10.1.0.0/16` |
| Spoke 1 — snet-workload-1 | `10.1.0.0/24` |
| Spoke 1 — snet-workload-2 | `10.1.1.0/24` |
| Spoke 2 VNet | `10.2.0.0/16` |
| Spoke 2 — snet-workload-1 | `10.2.0.0/24` |
| Spoke 2 — snet-workload-2 | `10.2.1.0/24` |

---

## Prerequisites

Before deploying, ensure the following are in place:

### Azure

- [ ] Azure subscription with Contributor access
- [ ] App Registration in Microsoft Entra ID
- [ ] Federated credential configured for this repository (`main` branch)
- [ ] Contributor role assigned to the App Registration at subscription scope

### GitHub

- [ ] Repository secrets configured (see below)
- [ ] GitHub Actions enabled

---

## GitHub Secrets Required

Go to **Settings → Secrets and variables → Actions** and add:

| Secret | Description |
|---|---|
| `AZURE_CLIENT_ID` | App Registration — Application (client) ID |
| `AZURE_TENANT_ID` | App Registration — Directory (tenant) ID |
| `AZURE_SUBSCRIPTION_ID` | Target Azure subscription ID |
| `VM_ADMIN_USERNAME` | Local admin username for all Linux VMs |
| `VM_ADMIN_PASSWORD` | Local admin password — must meet Azure complexity rules |

> **Password complexity:** minimum 12 characters, must include uppercase, lowercase, number and special character.

---

## Authentication — OIDC (No stored credentials)

This repository uses **OpenID Connect (OIDC)** to authenticate with Azure. No client secrets or long-lived credentials are stored anywhere.

How it works:

```
GitHub Actions run  →  generates short-lived JWT  →  Azure validates against
                                                       federated credential
                                                            ↓
                                                    Issues access token
                                                            ↓
                                                    Deployment runs
```

The `id-token: write` permission in each workflow is what enables this flow.

---

## Deploying

### Test authentication first

Go to **Actions → Test Azure auth → Run workflow**

This confirms OIDC is working before attempting any real deployment.

### Deploy Hub and Spoke

**Option 1 — Automatic trigger**
Push any change to a file under `labs/hub-spoke/` — the workflow triggers automatically.

**Option 2 — Manual trigger**
Go to **Actions → Hub-Spoke — Deploy → Run workflow**

### Workflow stages

```
Push to main
    │
    ▼
┌─────────────┐
│  Validate   │  az deployment sub what-if
│  (what-if)  │  Shows all changes before applying
└──────┬──────┘
       │ passes
       ▼
┌─────────────┐
│   Deploy    │  az deployment sub create
│             │  Creates all resources in Azure
└─────────────┘
```

---

## Serial Console Access

Serial Console is enabled on all VMs via boot diagnostics. To access:

1. Go to **Azure Portal → Virtual Machines → select VM**
2. In the left menu click **Serial console**
3. Log in with `VM_ADMIN_USERNAME` and `VM_ADMIN_PASSWORD`

No public IP or SSH access required.

---

## Cost Awareness

> Azure Firewall runs at approximately **$1.25 AUD/hour** in Australia East.
> Always destroy the lab when not in use.

Estimated hourly cost when running:

| Resource | Approx cost/hr |
|---|---|
| Azure Firewall (Standard) | ~$1.25 AUD |
| 4 x Standard_B1s VMs | ~$0.08 AUD |
| Storage account | negligible |
| **Total** | **~$1.33 AUD/hr** |

---

## Destroying the Lab

To avoid ongoing charges, delete the resource group when done:

```bash
az group delete --name rg-hs-lab-australiaeast --yes --no-wait
```

Or via Azure Portal → Resource Groups → `rg-hs-lab-australiaeast` → Delete.

> A dedicated destroy workflow will be added in a future update.

---

## Coming Soon

- [ ] vWAN library topology
- [ ] Destroy workflow (scheduled + manual)
- [ ] Drift detection workflow
- [ ] Azure Bastion for secure VM access
- [ ] VPN Gateway module
- [ ] NSG rules per subnet
- [ ] Azure Monitor + diagnostic settings

---

## Author

**techtalkdeepak**
Learning Azure networking through hands-on IaC labs.

---

## Tags

`azure` `bicep` `github-actions` `hub-spoke` `azure-firewall` `networking` `iac` `devops`
