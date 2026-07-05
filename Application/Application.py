# app.py

import streamlit as st
import os
from langchain_groq import ChatGroq
from langchain_neo4j import Neo4jGraph, GraphCypherQAChain
from langchain_core.prompts import PromptTemplate
from dotenv import load_dotenv

load_dotenv()

st.set_page_config(page_title="5G Core GraphRAG Assistant", page_icon="📡")
st.title("📡 5G Core Network Assistant")
st.caption("Ask questions about the 5G Core network configuration and dependencies")

# ─────────────────────────────────────────
# Cache the graph connection and chain so it's not rebuilt every message
# ─────────────────────────────────────────
@st.cache_resource
def get_chain(model_id):
    graph = Neo4jGraph(
        url=os.getenv("NEO4J_URI"),
        username=os.getenv("NEO4J_USER"),
        password=os.getenv("NEO4J_PASSWORD")
    )
    graph.refresh_schema()

    llm = ChatGroq(model=model_id, temperature=0, api_key=os.getenv("GROQ_API_KEY"))

    cypher_prompt = PromptTemplate(
        input_variables=["schema", "question"],
        template="""You are an expert in Neo4j Cypher and 5G Core network architecture.
Schema: {schema}
Rules:
- Labels: AMFFunction, SMFFunction, UPFFunction, NRFFunction, AUSFFunction, UDMFunction, PCFFunction (all share label ManagedFunction)
- Relationships: connectedTo (has property interfaceType), registersWith
- AMF must NEVER connect directly to UPF
- Never use type() on a node, use labels(node) instead
Question: {question}
Cypher query:"""
    )

    answer_prompt = PromptTemplate(
        input_variables=["question", "context"],
        template="""Question: {question}
Graph results: {context}
Answer clearly using ONLY the results above. If empty, say so.
Answer:"""
    )

    return GraphCypherQAChain.from_llm(
        llm=llm, graph=graph,
        cypher_prompt=cypher_prompt, qa_prompt=answer_prompt,
        verbose=False, allow_dangerous_requests=True,
        return_intermediate_steps=True
    )

# ─────────────────────────────────────────
# Sidebar — model picker 
# ─────────────────────────────────────────
model_choice = st.sidebar.selectbox(
    "Choose LLM",
    ["llama-3.3-70b-versatile", "openai/gpt-oss-120b", "qwen/qwen3-32b"]
)

with st.sidebar.expander("Show generated Cypher"):
    show_cypher = st.checkbox("Enable", value=True)

# ─────────────────────────────────────────
# Chat history
# ─────────────────────────────────────────
if "messages" not in st.session_state:
    st.session_state.messages = []

for msg in st.session_state.messages:
    with st.chat_message(msg["role"]):
        st.write(msg["content"])

# ─────────────────────────────────────────
# Chat input
# ─────────────────────────────────────────
if question := st.chat_input("Ask about the 5G Core network..."):
    st.session_state.messages.append({"role": "user", "content": question})
    with st.chat_message("user"):
        st.write(question)

    with st.chat_message("assistant"):
        with st.spinner("Querying knowledge graph..."):
            chain = get_chain(model_choice)
            try:
                response = chain.invoke({"query": question})
                answer = response["result"]

                if show_cypher:
                    steps = response.get("intermediate_steps", [])
                    if steps:
                        with st.expander("Generated Cypher"):
                            st.code(steps[0].get("query", ""), language="cypher")

                st.write(answer)
                st.session_state.messages.append({"role": "assistant", "content": answer})
            except Exception as e:
                st.error(f"Error: {e}")