# graphrag.py
# connects Neo4j knowledge graph with Groq via LangChain and answers the questions related to it

import os
from dotenv import load_dotenv
from langchain_groq import ChatGroq
from langchain_community.graphs import Neo4jGraph
from langchain_community.chains.graph_qa.cypher import GraphCypherQAChain
from langchain_core.prompts import PromptTemplate

load_dotenv()


# CONNECTING TO NEO4J DATABASE
print("Connecting to Neo4j...")

graph = Neo4jGraph(
    url=os.getenv("NEO4J_URI"),
    username=os.getenv("NEO4J_USER"),
    password=os.getenv("NEO4J_PASSWORD")
)


graph.refresh_schema()
print("Connected. Schema loaded.")
print()


# CONNECTING TO GROQ

print("Connecting to Groq")

llm = ChatGroq(
    model="llama-3.3-70b-versatile",
    temperature=0,
    api_key=os.getenv("GROQ_API_KEY")
)

print("Groq connected.")
print()


# CREATED A CUSTOM PROMPT FOR LLM

CYPHER_GENERATION_TEMPLATE = """
You are an expert in Neo4j Cypher query language and 5G Core network architecture.
You are working with a Neo4j graph database that models a 5G Core network.

The graph schema is:
{schema}

Important rules for this graph:
- Network functions are nodes with label :NetworkFunction
- Node names are: AMF-01, SMF-01, UPF-01, NRF-01, AUSF-01, UDM-01, PCF-01
- UPF does NOT register with NRF — it is controlled directly by SMF via CONTROLS relationship
- Relationship types are: CONNECTS_TO, CONTROLS, REGISTERS_WITH, AUTHENTICATES_VIA, QUERIES, APPLIES_POLICY
- Interface properties on relationships: N11, N4, N12, N13, N7, SBI
- NEVER use type() on a node — type() only works on relationships
- To get node labels use labels(node)[0] instead of type(node)
- Always use labels(node)[0] when you need the type of a node

Generate a Cypher query to answer this question:
{question}

Rules for your Cypher:
- Only use MATCH and RETURN, never DELETE or CREATE
- Always use DISTINCT to avoid duplicate results
- Return meaningful property names like nf.name not just nf
- Never use type() on nodes, use labels(node)[0] instead
"""

cypher_prompt = PromptTemplate(
    input_variables=["schema", "question"],
    template=CYPHER_GENERATION_TEMPLATE
)


# Answer prompt to tell the LLM how to form a response from the query results

ANSWER_GENERATION_TEMPLATE = """
You are a 5G Core network expert assistant.
You have been given the results of a Neo4j graph database query about a 5G Core network.

Original question: {question}
Database query results: {context}

Using ONLY the information in the query results above, give a clear and helpful answer.
Do not say "I don't know" if results are provided — always use the results to form an answer.
If the results are empty, say "No issues found" or "No results matched the query."

Answer:
"""

answer_prompt = PromptTemplate(
    input_variables=["question", "context"],
    template=ANSWER_GENERATION_TEMPLATE
)

chain = GraphCypherQAChain.from_llm(
    llm=llm,
    graph=graph,
    cypher_prompt=cypher_prompt,
    qa_prompt=answer_prompt,          
    verbose=True,
    allow_dangerous_requests=True,
    return_intermediate_steps=True
)


# QUESTION AND ANSWER FUNCTION

def ask(question):
    print(f"\n{'='*50}")
    print(f"Question: {question}")
    print(f"{'='*50}")
    
    try:
        response = chain.invoke({"query": question})
        
        steps = response.get("intermediate_steps", [])
        if steps:
            print(f"\nGenerated Cypher:")
            print(steps[0].get("query", "No Cypher found"))
        
        print(f"\nAnswer: {response['result']}")
        
    except Exception as e:
        print(f"Error: {e}")
        print("Try rephrasing the question.")


# Interactive Chat Loop
print("5G Core GraphRAG System")
print("Ask any question about your network in plain English.")
print("Type 'quit' to exit.")
print()

# Test questions to run first
test_questions = [
    "Which network functions are registered with NRF?",
    "What will be affected if AMF-01 fails?",
    "Is there any network function that is inactive?",
    "What does SMF-01 connect to?"
]

print("Running test questions first...")
for q in test_questions:
    ask(q)

# Open interactive mode
print("\n" + "="*50)
print("Now entering interactive mode.")
print("="*50)

while True:
    question = input("\nYour question: ").strip()
    
    if question.lower() == 'quit':
        print("Exiting.")
        break
    
    if question == "":
        print("Please type a question.")
        continue
    
    ask(question)