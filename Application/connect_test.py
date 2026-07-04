# connect_test.py
# To test the connection with the Neo4j Knowledge graph

from neo4j import GraphDatabase
from dotenv import load_dotenv

load_dotenv()

# Neo4j connection details
driver = GraphDatabase.driver(NEO4J_URI, auth=(NEO4J_USERNAME, NEO4J_PASSWORD))

# This function runs a simple test query
def test_connection():
    with driver.session() as session:
        result = session.run("MATCH (n:NetworkFunction) RETURN count(n) AS total")
        record = result.single()
        print(f"Connection successful! Found {record['total']} network functions in graph.")

test_connection()

driver.close()