// ============================================================
// 5G Core Network — Validation Rule Queries
// ============================================================
// These queries implement the 10 validation rules for the
// 13-node 5G Core knowledge graph.
// Rules 1-5 apply to any single-instance OR multi-instance graph.
// Rules 6-10 specifically require multiple instances and exploit
// the graph's deliberate topology (SMF-02 SPOF, load imbalance).
//
// Run each rule independently in Neo4j Browser.
// A clean graph should PASS rules 1-5 and produce meaningful
// findings for rules 6-10.
// ============================================================


// ============================================================
// RULE 1 — NRF Registration Completeness
// Every control-plane function must register with NRF.
// A function without this relationship is invisible to service
// discovery and cannot be found by other network functions.
// UPF is explicitly excluded: it is user-plane only and does
// not participate in SBA registration (3GPP TS 23.501).
// Expected clean result: empty (no violations)
// ============================================================

MATCH (nf:ManagedFunction)
WHERE NOT (nf)-[:registersWith]->(:NRFFunction)
  AND NOT nf:NRFFunction
  AND NOT nf:UPFFunction
RETURN nf.name AS unregistered_function,
       [l IN labels(nf) WHERE l <> 'ManagedFunction'][0] AS function_type;


// ============================================================
// RULE 2 — UPF Control Coverage
// Every UPF must have at least one incoming connectedTo
// relationship from an SMF. An uncontrolled UPF means user-plane
// traffic has no session manager — data cannot flow.
// Expected clean result: empty (no orphaned UPFs)
// ============================================================

MATCH (upf:UPFFunction)
WHERE NOT (:SMFFunction)-[:connectedTo]->(upf)
RETURN upf.name AS orphaned_upf;


// ============================================================
// RULE 3 — AMF-UPF Direct Connection Block (G-SPEC Core Rule)
// AMF must NEVER connect directly to UPF. This is the key
// constraint from the G-SPEC paper (arXiv:2512.20275), grounded
// in 3GPP TS 28.623. AMF-UPF communication must always be
// mediated by SMF to preserve session management integrity.
// Expected clean result: empty (no direct AMF-UPF edges)
// To demo a violation: run the DEMO section below first.
// ============================================================

MATCH (amf:AMFFunction)-[:connectedTo]->(upf:UPFFunction)
RETURN amf.name AS violating_amf,
       upf.name AS violating_upf,
       'VIOLATION: AMF cannot connect directly to UPF — must be mediated by SMF' AS message;

// --- DEMO: Create the violation (run, then re-run Rule 3 above to catch it) ---
// MATCH (amf:AMFFunction {id: 'AMF-01'}), (upf:UPFFunction {id: 'UPF-01'})
// CREATE (amf)-[:connectedTo {interfaceType: 'N11', timestamp: datetime()}]->(upf);

// --- DEMO: Remove the violation (restore clean state) ---
// MATCH (amf:AMFFunction {id: 'AMF-01'})-[r:connectedTo]->(upf:UPFFunction {id: 'UPF-01'})
// DELETE r;


// ============================================================
// RULE 4 — Inactive Function Check
// Any function with status = 'INACTIVE' is flagged immediately.
// Active downstream functions depending on an inactive function
// are also identified.
// Expected clean result: empty (all functions ACTIVE)
// ============================================================

MATCH (nf:ManagedFunction {status: 'INACTIVE'})
RETURN nf.name AS inactive_function,
       [l IN labels(nf) WHERE l <> 'ManagedFunction'][0] AS function_type;


// ============================================================
// RULE 5 — Impact Analysis (Multi-Hop Dependency Traversal)
// Given any function, trace all downstream dependents up to
// 3 hops following connectedTo relationships.
// Change the {id: 'SMF-02'} to test different functions.
// SMF-02 should show the most impact (it's the SPOF).
// ============================================================

// Impact if SMF-02 fails (expected: many functions affected)
MATCH (nf:ManagedFunction {id: 'SMF-02'})-[*1..3]->(affected)
RETURN DISTINCT affected.name AS affected_function,
       [l IN labels(affected) WHERE l <> 'ManagedFunction'][0] AS type
ORDER BY type, affected_function;

// Impact if NRF-01 fails (expected: all registered functions lose discovery)
MATCH (nf:ManagedFunction {id: 'NRF-01'})<-[:registersWith]-(dependent)
RETURN dependent.name AS loses_service_discovery,
       [l IN labels(dependent) WHERE l <> 'ManagedFunction'][0] AS type
ORDER BY type;

// Impact if AMF-01 fails
MATCH (nf:ManagedFunction {id: 'AMF-01'})-[*1..3]->(affected)
RETURN DISTINCT affected.name AS affected_function,
       [l IN labels(affected) WHERE l <> 'ManagedFunction'][0] AS type;


// ============================================================
// RULE 6 — Redundancy Coverage Check (NEW — requires 13-node graph)
// Every critical function type (AMF, SMF, UPF) should have
// at least 2 instances for failover capability.
// Expected result: all three types show count >= 2.
// ============================================================

MATCH (nf:ManagedFunction)
WHERE nf:AMFFunction OR nf:SMFFunction OR nf:UPFFunction
WITH [l IN labels(nf) WHERE l <> 'ManagedFunction'][0] AS function_type,
     count(nf) AS instance_count
RETURN function_type,
       instance_count,
       CASE WHEN instance_count >= 2
            THEN 'PASS — Redundancy exists'
            ELSE 'FAIL — No redundancy, single point of failure'
       END AS redundancy_status
ORDER BY function_type;


// ============================================================
// RULE 7 — Single Point of Failure Detection (NEW)
// Find any function that ALL instances of a redundant function
// type share as a dependency — these are SPOFs.
// Expected result: SMF-02 should be flagged (all 3 AMFs depend on it).
// NRF-01 should also be flagged (all 9 registered functions depend on it).
// ============================================================

// SPOF via connectedTo (operational dependencies)
MATCH (amf:AMFFunction)-[:connectedTo]->(smf:SMFFunction)
WITH smf, collect(DISTINCT amf.name) AS dependent_amfs
WHERE size(dependent_amfs) = 3
RETURN smf.name AS single_point_of_failure,
       dependent_amfs,
       'All AMF instances depend on this SMF — if it fails, all AMFs lose session management' AS risk;

// SPOF via registersWith (service discovery dependencies)
MATCH (nf:ManagedFunction)-[:registersWith]->(nrf:NRFFunction)
WITH nrf, collect(DISTINCT nf.name) AS registered_functions
RETURN nrf.name AS registry_spof,
       size(registered_functions) AS functions_depending_on_it,
       registered_functions;


// ============================================================
// RULE 8 — Load Distribution Check (NEW)
// Check if UPF load is evenly distributed across SMF instances.
// Expected result: SMF-02 controlling 3 UPFs should be flagged
// as overloaded while SMF-01 and SMF-03 each control only 1.
// ============================================================

MATCH (smf:SMFFunction)
OPTIONAL MATCH (smf)-[:connectedTo]->(upf:UPFFunction)
WITH smf, count(upf) AS controlled_upfs
RETURN smf.name AS smf_instance,
       controlled_upfs,
       CASE WHEN controlled_upfs = 0 THEN 'WARNING — Idle SMF, no UPF assigned'
            WHEN controlled_upfs >= 3 THEN 'WARNING — Overloaded SMF, consider rebalancing'
            ELSE 'OK'
       END AS load_status
ORDER BY controlled_upfs DESC;


// ============================================================
// RULE 9 — Cross-Instance Isolation Check (NEW)
// Does failure of one AMF instance potentially cascade to another
// through shared dependencies?
// Identifies shared dependencies between AMF-01 and AMF-02.
// ============================================================

MATCH (amf1:AMFFunction {id: 'AMF-01'})-[*1..3]->(dep1)
MATCH (amf2:AMFFunction {id: 'AMF-02'})-[*1..3]->(dep2)
WHERE dep1.id = dep2.id
  AND dep1.id <> 'AMF-01'
  AND dep1.id <> 'AMF-02'
RETURN DISTINCT dep1.name AS shared_dependency,
       [l IN labels(dep1) WHERE l <> 'ManagedFunction'][0] AS type,
       'If this shared dependency fails, both AMF-01 and AMF-02 are affected' AS risk_note
ORDER BY type;


// ============================================================
// RULE 10 — AMF-02 Redundancy Gap Check (NEW)
// AMF-02 has only one SMF option (SMF-02), unlike AMF-01 and
// AMF-03 which each have two. This means AMF-02 has no failover
// if SMF-02 goes down. This rule specifically flags this gap.
// ============================================================

MATCH (amf:AMFFunction)-[:connectedTo]->(smf:SMFFunction)
WITH amf, count(smf) AS smf_options, collect(smf.name) AS connected_smfs
RETURN amf.name AS amf_instance,
       smf_options,
       connected_smfs,
       CASE WHEN smf_options = 1
            THEN 'FAIL — No SMF failover available for this AMF'
            ELSE 'PASS — Multiple SMF options available'
       END AS redundancy_status
ORDER BY smf_options;


// ============================================================
// BONUS — Full Network Health Summary
// Run this as a single overview query to get a snapshot of
// the entire network's health in one result set.
// ============================================================

// All active connections
MATCH (n:ManagedFunction)-[r]->(m:ManagedFunction)
WHERE n.status = 'ACTIVE' AND m.status = 'ACTIVE'
RETURN n.name AS from_function,
       type(r) AS relationship,
       r.interfaceType AS interface,
       m.name AS to_function
ORDER BY from_function, relationship;
