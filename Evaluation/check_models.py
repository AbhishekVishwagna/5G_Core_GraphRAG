# check_available_models.py
# To check the various models avaliable in Groq

import os
import requests
from dotenv import load_dotenv

load_dotenv()

api_key = os.getenv("GROQ_API_KEY")
url = "https://api.groq.com/openai/v1/models"
headers = {"Authorization": f"Bearer {api_key}"}

response = requests.get(url, headers=headers)
models = response.json()

print("Currently available Groq models:\n")
for model in models.get("data", []):
    print(model["id"])