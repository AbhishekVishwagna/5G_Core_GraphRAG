# 5G Core Network Knowledge Graph — Schema Documentation

## Overview

This knowledge graph models a 5G Core network topology in Neo4j, following the
class naming conventions of the G-SPEC paper (arXiv:2512.20275) which maps its
schema to 3GPP TS 28.623 (Generic Network Resource Model) and TS 28.541 (5G
Network Resource Model). The network topology and interface specifications are
grounded in 3GPP TS 23.501 (System Architecture for the 5G System).

---

## Node Schema

### Superclass Label
All network function nodes share the label `ManagedFunction`, replicating the
ontological inheritance pattern from 3GPP TS 28.623 where all managed objects
inherit from a generic `ManagedFunction` base class. This allows validation rules
to target `:ManagedFunction` once and automatically apply to all specific types.

### Network Function Labels and Properties

| Label | Represents | Properties |
|---|---|---|
| `AMFFunction` | Access and Mobility Management Function | id, name, ip, port, status, lastUpdated |
| `SMFFunction` | Session Management Function | id, name, ip, port, status, lastUpdated |
| `UPFFunction` | User Plane Function | id, name, ip, gtpu_port, status, lastUpdated |
| `NRFFunction` | Network Repository Function | id, name, ip, port, status, lastUpdated |
| `AUSFFunction` | Authentication Server Function | id, name, ip, port, status, lastUpdated |
| `UDMFunction` | Unified Data Management | id, name, ip, port, status, lastUpdated |
| `PCFFunction` | Policy Control Function | id, name, ip, port, status, lastUpdated |

### Property Descriptions

| Property | Type | Description |
|---|---|---|
| `id` | String | Unique identifier (e.g. 'AMF-01') |
| `name` | String | Display name (same as id) |
| `ip` | String | IP address of the network function |
| `port` | Integer | Control plane port number |
| `gtpu_port` | Integer | GTP-U port (UPF only, port 2152) |
| `status` | String | Current status: 'ACTIVE' or 'INACTIVE' |
| `lastUpdated` | DateTime | Timestamp of last configuration change |

---

## Relationship Schema

### Exactly Two Relationship Types

**1. `connectedTo`**
Represents a direct topological/operational link between two network functions,
carrying real control-plane or user-plane traffic. Maps to specific 3GPP-defined
interfaces.

Properties:
- `interfaceType` (String): the 3GPP interface name (e.g. 'N11', 'N4', 'N7')
- `timestamp` (DateTime): when the connection was established

**2. `registersWith`**
Represents service-discovery registration with NRF over the Service Based Interface.
All control-plane functions register with NRF so other functions can discover them.
UPF does NOT register with NRF — it is a user-plane-only function, controlled
directly by SMF via connectedTo, and does not participate in service-based
architecture registration.

Properties:
- `interfaceType` (String): always 'SBI' (Service Based Interface)
- `timestamp` (DateTime): when registration was established

---

## Interface Reference (3GPP TS 23.501)

| Interface | Between | Purpose |
|---|---|---|
| N11 | AMF → SMF | Session management signalling |
| N4 | SMF → UPF | Packet forwarding rules (PFCP) |
| N12 | AMF → AUSF | Authentication requests |
| N13 | AUSF → UDM | Subscriber data lookup |
| N7 | SMF → PCF | Policy enforcement |
| SBI | All CPs → NRF | Service discovery registration |

---

## Network Topology (13 Nodes)

### Shared/Centralised Functions (1 instance each)
These functions maintain a single consistent source of truth and are not
duplicated. NRF is the directory service; AUSF, UDM, PCF are centralised
control-plane functions where consistency is critical.

- NRF-01 (ip: 10.0.0.4, port: 7777)
- AUSF-01 (ip: 10.0.0.5, port: 7878)
- UDM-01 (ip: 10.0.0.6, port: 7979)
- PCF-01 (ip: 10.0.0.7, port: 7070)

### Redundant/Distributed Functions (3 instances each)
AMF, SMF, and UPF are stateful, traffic-bearing functions that scale with
the number of connected devices and data volume. 3GPP explicitly supports
multiple instances via AMF Sets and SMF Sets (TS 23.501 Section 5.21).

- AMF-01, AMF-02, AMF-03 (ip: 10.0.0.1, 10.0.0.11, 10.0.0.12)
- SMF-01, SMF-02, SMF-03 (ip: 10.0.0.2, 10.0.0.13, 10.0.0.14)
- UPF-01, UPF-02, UPF-03 (ip: 10.0.0.3, 10.0.0.15, 10.0.0.16)

### Deliberate Topology Asymmetry (for realistic SPOF/redundancy demonstration)

```
AMF-01 --> SMF-01  (N11)   AMF-01 also --> SMF-02 (redundancy)
AMF-02 --> SMF-02  (N11)   AMF-02 has only ONE SMF option (no redundancy)
AMF-03 --> SMF-02  (N11)   AMF-03 also --> SMF-03 (redundancy)

SMF-01 --> UPF-01  (N4)
SMF-02 --> UPF-01  (N4)    SMF-02 controls ALL three UPFs (overloaded)
SMF-02 --> UPF-02  (N4)
SMF-02 --> UPF-03  (N4)
SMF-03 --> UPF-03  (N4)
```

**SMF-02 is the deliberate Single Point of Failure:**
All three AMF instances depend on SMF-02 (directly or as a fallback),
and SMF-02 controls all three UPF instances. If SMF-02 fails, the
entire network is affected.

---

## Key Constraints (from G-SPEC paper, grounded in 3GPP TS 28.623)

1. **AMF must NEVER connect directly to UPF** — AMF-UPF communication must
   always be mediated by SMF. This is a hard constraint from the 5G Core
   architecture. A direct AMF→UPF `connectedTo` relationship is a policy violation.

2. **UPF does not register with NRF** — UPF has no `registersWith` relationship.
   This is correct behaviour, not a missing data error.

3. **Every control-plane function must register with NRF** — AMF, SMF, AUSF,
   UDM, PCF all require `registersWith` → NRF. Missing this means the function
   is invisible to service discovery.

---

## Schema Justification

| Design Choice | Justification |
|---|---|
| Node label naming (AMFFunction etc.) | Follows 3GPP TS 28.623/28.541 class naming conventions as used in G-SPEC (arXiv:2512.20275) |
| ManagedFunction superclass | Replicates ontological inheritance from 3GPP TS 28.623, enabling single policy rules to apply across all function types |
| Only AMF/SMF/UPF have multiple instances | Per 3GPP TS 23.501 Section 5.21 (AMF/SMF Sets); NRF/AUSF/UDM/PCF are centralised |
| Asymmetric, overlapping topology | Creates realistic redundancy gaps and SPOF scenarios not possible with symmetric 1:1 pairing |
| Two relationship types only | Mirrors G-SPEC's schema: operational links (connectedTo) vs service discovery (registersWith) |
| Timestamps on all relationships | Enables future temporal analysis of configuration changes |

---

## References

- G-SPEC: Vijay, D., Ethiraj, V. (2025). "Graph-Symbolic Policy Enforcement and Control." arXiv:2512.20275
- 3GPP TS 23.501 Release 18 (2024) — 5G System Architecture
- 3GPP TS 28.623 Release 20 (2024) — Generic Network Resource Model (NRM)
- 3GPP TS 28.541 Release 18 (2024) — 5G Network Resource Model (NRM)
