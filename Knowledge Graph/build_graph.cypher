// ============================================================
// 5G Core Network Knowledge Graph — Build Script
// ============================================================
// Run these queries in Neo4j Browser in order, one section at a time.
// Schema follows G-SPEC (arXiv:2512.20275) and 3GPP TS 28.623/28.541/23.501.
//
// IMPORTANT: Run Section 0 first to ensure a clean starting state.
// Each section ends with a verification query — confirm it passes
// before moving to the next section.
// ============================================================


// ============================================================
// SECTION 0 — CLEAR EXISTING GRAPH (run once at the start)
// ============================================================
// WARNING: This deletes ALL nodes and relationships.
// Only run this if you want to rebuild from scratch.

MATCH (n) DETACH DELETE n;

// Verify: should return 0
MATCH (n) RETURN count(n) AS total_nodes;


// ============================================================
// SECTION 1 — CREATE SHARED/CENTRALISED FUNCTIONS (4 nodes)
// These functions have exactly 1 instance each.
// NRF, AUSF, UDM, PCF are centralised — they maintain a single
// consistent source of truth and are not duplicated.
// ============================================================

CREATE (:NRFFunction:ManagedFunction {
    id: 'NRF-01',
    name: 'NRF-01',
    ip: '10.0.0.4',
    port: 7777,
    status: 'ACTIVE',
    lastUpdated: datetime()
});

CREATE (:AUSFFunction:ManagedFunction {
    id: 'AUSF-01',
    name: 'AUSF-01',
    ip: '10.0.0.5',
    port: 7878,
    status: 'ACTIVE',
    lastUpdated: datetime()
});

CREATE (:UDMFunction:ManagedFunction {
    id: 'UDM-01',
    name: 'UDM-01',
    ip: '10.0.0.6',
    port: 7979,
    status: 'ACTIVE',
    lastUpdated: datetime()
});

CREATE (:PCFFunction:ManagedFunction {
    id: 'PCF-01',
    name: 'PCF-01',
    ip: '10.0.0.7',
    port: 7070,
    status: 'ACTIVE',
    lastUpdated: datetime()
});

// Verify: should return 4
MATCH (n:ManagedFunction) RETURN count(n) AS total_nodes;


// ============================================================
// SECTION 2 — CREATE AMF INSTANCES (3 nodes)
// AMF is a stateful, traffic-bearing function that scales with
// the number of connected devices. 3GPP TS 23.501 Section 5.21
// explicitly supports multiple AMF instances via AMF Sets.
// ============================================================

CREATE (:AMFFunction:ManagedFunction {
    id: 'AMF-01',
    name: 'AMF-01',
    ip: '10.0.0.1',
    port: 38412,
    status: 'ACTIVE',
    lastUpdated: datetime()
});

CREATE (:AMFFunction:ManagedFunction {
    id: 'AMF-02',
    name: 'AMF-02',
    ip: '10.0.0.11',
    port: 38412,
    status: 'ACTIVE',
    lastUpdated: datetime()
});

CREATE (:AMFFunction:ManagedFunction {
    id: 'AMF-03',
    name: 'AMF-03',
    ip: '10.0.0.12',
    port: 38412,
    status: 'ACTIVE',
    lastUpdated: datetime()
});

// Verify: should return 3
MATCH (n:AMFFunction) RETURN n.id, n.ip, n.status;


// ============================================================
// SECTION 3 — CREATE SMF INSTANCES (3 nodes)
// SMF manages PDU sessions and scales with active data sessions.
// Supports multiple instances via SMF Sets (3GPP TS 23.501).
// ============================================================

CREATE (:SMFFunction:ManagedFunction {
    id: 'SMF-01',
    name: 'SMF-01',
    ip: '10.0.0.2',
    port: 8805,
    status: 'ACTIVE',
    lastUpdated: datetime()
});

CREATE (:SMFFunction:ManagedFunction {
    id: 'SMF-02',
    name: 'SMF-02',
    ip: '10.0.0.13',
    port: 8805,
    status: 'ACTIVE',
    lastUpdated: datetime()
});

CREATE (:SMFFunction:ManagedFunction {
    id: 'SMF-03',
    name: 'SMF-03',
    ip: '10.0.0.14',
    port: 8805,
    status: 'ACTIVE',
    lastUpdated: datetime()
});

// Verify: should return 3
MATCH (n:SMFFunction) RETURN n.id, n.ip, n.status;


// ============================================================
// SECTION 4 — CREATE UPF INSTANCES (3 nodes)
// UPF forwards user-plane traffic and scales with data volume
// and geographic distribution. Deployed at edge locations.
// ============================================================

CREATE (:UPFFunction:ManagedFunction {
    id: 'UPF-01',
    name: 'UPF-01',
    ip: '10.0.0.3',
    gtpu_port: 2152,
    status: 'ACTIVE',
    lastUpdated: datetime()
});

CREATE (:UPFFunction:ManagedFunction {
    id: 'UPF-02',
    name: 'UPF-02',
    ip: '10.0.0.15',
    gtpu_port: 2152,
    status: 'ACTIVE',
    lastUpdated: datetime()
});

CREATE (:UPFFunction:ManagedFunction {
    id: 'UPF-03',
    name: 'UPF-03',
    ip: '10.0.0.16',
    gtpu_port: 2152,
    status: 'ACTIVE',
    lastUpdated: datetime()
});

// Verify: should return 3
MATCH (n:UPFFunction) RETURN n.id, n.ip, n.status;

// Full node count check: should return 13
MATCH (n:ManagedFunction) RETURN count(n) AS total_nodes;


// ============================================================
// SECTION 5 — CREATE AMF → SMF CONNECTIONS (N11 interface)
// Deliberate overlap: AMF-01 and AMF-03 have two SMF options
// (redundancy). AMF-02 has only one (SMF-02 — no failover).
// This creates the SPOF scenario: SMF-02 is shared by all AMFs.
// ============================================================

// AMF-01 connects to SMF-01 (primary) and SMF-02 (secondary/redundancy)
MATCH (amf:AMFFunction {id: 'AMF-01'}), (smf:SMFFunction {id: 'SMF-01'})
CREATE (amf)-[:connectedTo {interfaceType: 'N11', timestamp: datetime()}]->(smf);

MATCH (amf:AMFFunction {id: 'AMF-01'}), (smf:SMFFunction {id: 'SMF-02'})
CREATE (amf)-[:connectedTo {interfaceType: 'N11', timestamp: datetime()}]->(smf);

// AMF-02 connects to SMF-02 ONLY (single point of dependency — no redundancy)
MATCH (amf:AMFFunction {id: 'AMF-02'}), (smf:SMFFunction {id: 'SMF-02'})
CREATE (amf)-[:connectedTo {interfaceType: 'N11', timestamp: datetime()}]->(smf);

// AMF-03 connects to SMF-02 (primary) and SMF-03 (secondary/redundancy)
MATCH (amf:AMFFunction {id: 'AMF-03'}), (smf:SMFFunction {id: 'SMF-02'})
CREATE (amf)-[:connectedTo {interfaceType: 'N11', timestamp: datetime()}]->(smf);

MATCH (amf:AMFFunction {id: 'AMF-03'}), (smf:SMFFunction {id: 'SMF-03'})
CREATE (amf)-[:connectedTo {interfaceType: 'N11', timestamp: datetime()}]->(smf);

// Verify: all 3 AMFs depend on SMF-02 (the SPOF)
MATCH (amf:AMFFunction)-[:connectedTo]->(smf:SMFFunction {id: 'SMF-02'})
RETURN amf.name AS amf_depending_on_smf02;


// ============================================================
// SECTION 6 — CREATE SMF → UPF CONNECTIONS (N4 interface)
// SMF-02 is deliberately overloaded — controls all 3 UPFs.
// SMF-01 and SMF-03 each control 1 UPF only.
// UPF-01 is shared between SMF-01 and SMF-02.
// ============================================================

// SMF-01 controls UPF-01
MATCH (smf:SMFFunction {id: 'SMF-01'}), (upf:UPFFunction {id: 'UPF-01'})
CREATE (smf)-[:connectedTo {interfaceType: 'N4', timestamp: datetime()}]->(upf);

// SMF-02 controls all three UPFs (overloaded — load imbalance scenario)
MATCH (smf:SMFFunction {id: 'SMF-02'}), (upf:UPFFunction {id: 'UPF-01'})
CREATE (smf)-[:connectedTo {interfaceType: 'N4', timestamp: datetime()}]->(upf);

MATCH (smf:SMFFunction {id: 'SMF-02'}), (upf:UPFFunction {id: 'UPF-02'})
CREATE (smf)-[:connectedTo {interfaceType: 'N4', timestamp: datetime()}]->(upf);

MATCH (smf:SMFFunction {id: 'SMF-02'}), (upf:UPFFunction {id: 'UPF-03'})
CREATE (smf)-[:connectedTo {interfaceType: 'N4', timestamp: datetime()}]->(upf);

// SMF-03 controls UPF-03 (shared with SMF-02)
MATCH (smf:SMFFunction {id: 'SMF-03'}), (upf:UPFFunction {id: 'UPF-03'})
CREATE (smf)-[:connectedTo {interfaceType: 'N4', timestamp: datetime()}]->(upf);

// Verify: check load distribution — SMF-02 should control 3, others 1
MATCH (smf:SMFFunction)-[:connectedTo]->(upf:UPFFunction)
RETURN smf.name AS smf, count(upf) AS upfs_controlled
ORDER BY upfs_controlled DESC;


// ============================================================
// SECTION 7 — CREATE AMF → AUSF CONNECTION (N12 interface)
// Authentication chain: AMF → AUSF → UDM
// AMF-01 handles authentication via AUSF (shared centralised function)
// ============================================================

MATCH (amf:AMFFunction {id: 'AMF-01'}), (ausf:AUSFFunction {id: 'AUSF-01'})
CREATE (amf)-[:connectedTo {interfaceType: 'N12', timestamp: datetime()}]->(ausf);

// AUSF queries UDM for subscriber data (N13 interface)
MATCH (ausf:AUSFFunction {id: 'AUSF-01'}), (udm:UDMFunction {id: 'UDM-01'})
CREATE (ausf)-[:connectedTo {interfaceType: 'N13', timestamp: datetime()}]->(udm);

// Verify: authentication chain
MATCH (amf:AMFFunction)-[:connectedTo]->(ausf:AUSFFunction)-[:connectedTo]->(udm:UDMFunction)
RETURN amf.name, ausf.name, udm.name;


// ============================================================
// SECTION 8 — CREATE SMF → PCF CONNECTIONS (N7 interface)
// All 3 SMF instances apply policy from the centralised PCF
// ============================================================

MATCH (smf:SMFFunction {id: 'SMF-01'}), (pcf:PCFFunction {id: 'PCF-01'})
CREATE (smf)-[:connectedTo {interfaceType: 'N7', timestamp: datetime()}]->(pcf);

MATCH (smf:SMFFunction {id: 'SMF-02'}), (pcf:PCFFunction {id: 'PCF-01'})
CREATE (smf)-[:connectedTo {interfaceType: 'N7', timestamp: datetime()}]->(pcf);

MATCH (smf:SMFFunction {id: 'SMF-03'}), (pcf:PCFFunction {id: 'PCF-01'})
CREATE (smf)-[:connectedTo {interfaceType: 'N7', timestamp: datetime()}]->(pcf);

// Verify: all SMFs connected to PCF
MATCH (smf:SMFFunction)-[:connectedTo]->(pcf:PCFFunction)
RETURN smf.name AS smf, pcf.name AS pcf;


// ============================================================
// SECTION 9 — CREATE registersWith RELATIONSHIPS (SBI)
// All control-plane functions register with NRF.
// NOTE: UPF instances do NOT register with NRF — this is correct.
// UPF is user-plane only and does not participate in SBA.
// ============================================================

// AMF instances register with NRF
MATCH (amf:AMFFunction {id: 'AMF-01'}), (nrf:NRFFunction {id: 'NRF-01'})
CREATE (amf)-[:registersWith {interfaceType: 'SBI', timestamp: datetime()}]->(nrf);

MATCH (amf:AMFFunction {id: 'AMF-02'}), (nrf:NRFFunction {id: 'NRF-01'})
CREATE (amf)-[:registersWith {interfaceType: 'SBI', timestamp: datetime()}]->(nrf);

MATCH (amf:AMFFunction {id: 'AMF-03'}), (nrf:NRFFunction {id: 'NRF-01'})
CREATE (amf)-[:registersWith {interfaceType: 'SBI', timestamp: datetime()}]->(nrf);

// SMF instances register with NRF
MATCH (smf:SMFFunction {id: 'SMF-01'}), (nrf:NRFFunction {id: 'NRF-01'})
CREATE (smf)-[:registersWith {interfaceType: 'SBI', timestamp: datetime()}]->(nrf);

MATCH (smf:SMFFunction {id: 'SMF-02'}), (nrf:NRFFunction {id: 'NRF-01'})
CREATE (smf)-[:registersWith {interfaceType: 'SBI', timestamp: datetime()}]->(nrf);

MATCH (smf:SMFFunction {id: 'SMF-03'}), (nrf:NRFFunction {id: 'NRF-01'})
CREATE (smf)-[:registersWith {interfaceType: 'SBI', timestamp: datetime()}]->(nrf);

// Shared functions register with NRF
MATCH (ausf:AUSFFunction {id: 'AUSF-01'}), (nrf:NRFFunction {id: 'NRF-01'})
CREATE (ausf)-[:registersWith {interfaceType: 'SBI', timestamp: datetime()}]->(nrf);

MATCH (udm:UDMFunction {id: 'UDM-01'}), (nrf:NRFFunction {id: 'NRF-01'})
CREATE (udm)-[:registersWith {interfaceType: 'SBI', timestamp: datetime()}]->(nrf);

MATCH (pcf:PCFFunction {id: 'PCF-01'}), (nrf:NRFFunction {id: 'NRF-01'})
CREATE (pcf)-[:registersWith {interfaceType: 'SBI', timestamp: datetime()}]->(nrf);

// Verify: 9 functions registered (all except UPF-01/02/03)
MATCH (nf:ManagedFunction)-[:registersWith]->(nrf:NRFFunction)
RETURN nf.name AS registered_function, nrf.name AS nrf
ORDER BY nf.name;


// ============================================================
// SECTION 10 — FINAL VERIFICATION
// Run these to confirm the complete graph is correctly built.
// ============================================================

// Full graph visual (paste in Neo4j Browser)
MATCH (n)-[r]->(m) RETURN n, r, m;

// Node count by type
MATCH (n)
WHERE n:ManagedFunction
RETURN DISTINCT [l IN labels(n) WHERE l <> 'ManagedFunction'][0] AS function_type,
       count(n) AS instance_count
ORDER BY function_type;
// Expected: AMFFunction(3), AUSFFunction(1), NRFFunction(1),
//           PCFFunction(1), SMFFunction(3), UDMFunction(1), UPFFunction(3)

// Relationship count by type
MATCH ()-[r]->()
RETURN type(r) AS relationship_type, count(r) AS count;
// Expected: connectedTo(15), registersWith(9)

// SPOF confirmation: all 3 AMFs depend on SMF-02
MATCH (amf:AMFFunction)-[:connectedTo]->(smf:SMFFunction {id: 'SMF-02'})
RETURN amf.name AS amf_depending_on_smf02;
// Expected: AMF-01, AMF-02, AMF-03
